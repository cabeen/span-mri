#! /usr/bin/env bash
##############################################################################
#
#  SPAN Rodent MRI Analytics — Lesion and CSF Segmentation
#
#  Purpose:
#    Segments ischemic stroke lesions and cerebrospinal fluid (CSF) from
#    harmonized multi-modal MRI parameter maps in standard atlas space.
#    Uses sigmoid-based probability estimation with a two-threshold
#    seed-and-grow strategy for robust lesion delineation.
#
#  Algorithm — Lesion Segmentation:
#    1. Erode the brain mask to create an interior mask (avoids edge artifacts)
#    2. Compute per-voxel lesion probability from three sigmoid-filtered maps:
#       - ADC rate (inverted): elevated ADC rate indicates restricted diffusion
#       - T2 rate (inverted): elevated T2 rate indicates increased water content
#       - ADC base: low baseline signal suggests cytotoxic edema
#       The joint probability is the product: P = P(adc_rate) * P(t2_rate) * P(adc_base)
#    3. Median-filter the probability map to reduce noise
#    4. Two-threshold seed-and-grow:
#       a. Apply high threshold (0.5) to find confident lesion seeds
#       b. Morphological opening (remove small fragments)
#       c. Dilate seeds to create a search region
#       d. Apply low threshold (0.45) within the dilated region
#    5. Intersect with species-specific lesion prior mask (if provided)
#
#  Algorithm — CSF Segmentation:
#    1. Compute CSF probability from sigmoid-filtered maps within interior mask:
#       - ADC rate (non-inverted): high ADC rate indicates free water
#       - T2 rate (inverted): high T2 rate indicates long relaxation
#    2. Threshold the joint probability to obtain CSF mask
#
#  Output ROI Encoding:
#    The rois.nii.gz volume encodes: tissue=1, csf=2, lesion=3
#    Starting from the brain mask (all tissue=1), CSF regions are set to 2,
#    then lesion regions are set to 3 (lesion takes priority over CSF).
#
#  Threshold Parameters (can be overridden via command line):
#    --t2RateThreshLesion (0.80):  Sigmoid center for T2 rate lesion detection.
#       Values above this rate are more likely to be lesion tissue due to
#       increased water content from vasogenic/cytotoxic edema.
#    --adcRateThreshLesion (1.5):  Sigmoid center for ADC rate lesion detection.
#       Values above this rate indicate restricted diffusion in acute stroke.
#    --adcBaseThreshLesion (0.25): Sigmoid center for ADC baseline detection.
#       Low baseline signal suggests reduced cellularity or edema.
#    --sigmoidHighThreshLesion (0.5): High probability threshold for lesion seeds.
#    --sigmoidLowThreshLesion (0.45): Low probability threshold for seed growing.
#    --t2RateThreshCsf (0.75):    Sigmoid center for T2 rate CSF detection.
#    --adcRateThreshCsf (1.25):   Sigmoid center for ADC rate CSF detection.
#
#  Inputs:
#    --input <dir>   Directory containing harmonized parameter maps
#                    ({adc,t2}_{base,rate}.nii.gz)
#    --mask <file>   Brain mask in standard space
#    --prior <file>  Species-specific lesion prior mask (optional)
#    --output <dir>  Output directory
#
#  Outputs:
#    lesion.mask.nii.gz  — Binary lesion mask
#    csf.mask.nii.gz     — Binary CSF mask
#    tissue.mask.nii.gz  — Binary healthy tissue mask
#    rois.nii.gz         — Combined ROI label volume (tissue=1, csf=2, lesion=3)
#    rois.csv            — ROI label lookup table
#
#  Dependencies: QIT
#
#  Author: Ryan Cabeen
#
##############################################################################

usage()
{
    echo "
Name: $(basename $0)

Description:

  The SPAN lesion segmentation module.

Usage:

  $(basename $0) --input params --mask brain.mask.nii.gz --output seg_results

Author: Ryan Cabeen
"

exit 1
}

function check
{
  if [ ! -e $1 ]; then 
    "[error] required input not found: $1"
    exit 1
  fi
}

function runit
{
  echo "    running: $@"
  $@
  if [ $? != 0 ]; then 
    echo "[error] command failed: $@"
    exit; 
  fi
}

workflow="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
name=$(basename $0)

t2RateThreshLesion=0.80
adcRateThreshLesion=1.5
adcBaseThreshLesion=0.25
sigmoidHighThreshLesion=0.5
sigmoidLowThreshLesion=0.45

numErodeBrain=1
numOpenLesion=2
numDilateLesion=2

t2RateThreshCsf=0.75
adcRateThreshCsf=1.25
sigmoidThreshCsf=0.5

input=""
mask=""
prior=""
output=""
posit=""

while [ "$1" != "" ]; do
    case $1 in
        --input)                   shift; input=$1 ;;
        --mask)                    shift; mask=$1 ;;
        --prior)                   shift; prior=$1 ;;
        --output)                  shift; output=$1 ;;
        --t2RateThreshLesion)      shift; t2RateThreshLesion=$1 ;;
        --adcRateThreshLesion)     shift; adcRateThreshLesion=$1 ;;
        --adcBaseThreshLesion)     shift; adcBaseThreshLesion=$1 ;;
        --sigmoidHighThreshLesion) shift; sigmoidHighThreshLesion=$1 ;;
        --sigmoidLowThreshLesion)  shift; sigmoidLowThreshLesion=$1 ;;
        --numErodeBrain)           shift; numErodeBrain=$1 ;;
        --numOpenLesion)           shift; numOpenLesion=$1 ;;
        --numDilateLesion)         shift; numDilateLesion=$1 ;;
        --t2RateThreshCsf)         shift; t2RateThreshCsf=$1 ;;
        --sigmoidThreshCsf)        shift; sigmoidThreshCsf=$1 ;;
        --adcRateThreshCsf)        shift; adcRateThreshCsf=$1 ;;
        --help )                   usage ;;
        * )                        posit="${posit} $1" ;;
    esac
    shift
done

if [ "${posit}" != "" ]; then usage; exit; fi
if [ "${input}" == "" ]; then echo "no input found!"; usage; exit; fi
if [ "${mask}" == "" ]; then echo "no mask found!"; usage; exit; fi
if [ "${output}" == "" ]; then echo "no output found!"; usage; exit; fi

##############################################################################
# Processing 
##############################################################################

echo "started ${name}"

tmp=${output}.tmp.${RANDOM}
mkdir -p ${tmp}

# Erode brain mask to avoid edge artifacts at the brain boundary
runit qit --verbose MaskErode \
   --num ${numErodeBrain} \
	 --input ${mask} \
	 --output ${tmp}/interior.mask.nii.gz

echo "segmenting lesion"

# Step 1: Compute per-voxel lesion probability from three sigmoid-filtered maps.
# Each sigmoid maps parameter values to [0,1] probabilities centered at the threshold.
# ADC rate (inverted): high decay rates → restricted diffusion in acute ischemia
runit qit --verbose VolumeFilterSigmoid \
	--invert --thresh ${adcRateThreshLesion} \
	--input ${input}/adc_rate.nii.gz \
	--mask ${mask} \
	--output ${tmp}/lesion.prob.adc_rate.nii.gz

# T2 rate (inverted): high decay rates → increased water content from edema
runit qit --verbose VolumeFilterSigmoid \
	--invert --thresh ${t2RateThreshLesion} \
	--input ${input}/t2_rate.nii.gz \
	--mask ${mask} \
	--output ${tmp}/lesion.prob.t2_rate.nii.gz

# ADC base (non-inverted): low baseline signal → cytotoxic edema
runit qit --verbose VolumeFilterSigmoid \
	--thresh ${adcBaseThreshLesion} \
	--input ${input}/adc_base.nii.gz \
	--mask ${mask} \
	--output ${tmp}/lesion.prob.adc_base.nii.gz

# Combine probabilities: joint probability = product of individual probabilities.
# This enforces that all three modalities must agree for a voxel to be lesion.
runit qit --verbose VolumeVoxelMathScalar \
	--a ${tmp}/lesion.prob.t2_rate.nii.gz \
	--b ${tmp}/lesion.prob.adc_rate.nii.gz \
	--c ${tmp}/lesion.prob.adc_base.nii.gz \
	--mask ${mask} \
	--expression "a*b*c" \
	--output ${tmp}/lesion.rawprob.nii.gz

# Median filter to smooth the probability map and reduce noise
runit qit --verbose VolumeFilterMedian \
	--input ${tmp}/lesion.rawprob.nii.gz \
	--output ${tmp}/lesion.medprob.nii.gz

# Step 2: Two-threshold seed-and-grow strategy.
# First, apply a high threshold to find confident lesion seed voxels
runit qit --verbose VolumeThreshold \
	--input ${tmp}/lesion.medprob.nii.gz \
	--threshold ${sigmoidHighThreshLesion} \
	--output ${tmp}/lesion.high.mask.nii.gz

# Morphological opening removes small isolated fragments from the seeds
runit qit --verbose MaskOpen \
	--input ${tmp}/lesion.high.mask.nii.gz \
	--num ${numOpenLesion} \
	--output ${tmp}/lesion.open.mask.nii.gz

# Dilate the cleaned seeds to define a search region around confident lesion areas
runit qit --verbose MaskDilate \
	--input ${tmp}/lesion.open.mask.nii.gz \
	--num ${numDilateLesion} \
	--output ${tmp}/lesion.dil.mask.nii.gz

# Apply the lower threshold within the dilated region to capture lesion borders
runit qit --verbose VolumeThreshold \
	--input ${tmp}/lesion.medprob.nii.gz \
	--mask ${tmp}/lesion.dil.mask.nii.gz \
	--threshold ${sigmoidLowThreshLesion} \
	--output ${tmp}/lesion.penult.mask.nii.gz

# Optionally intersect with species-specific lesion prior mask to restrict
# the lesion to anatomically plausible regions
if [ "${prior}" != "" ]; then
	runit qit --verbose MaskIntersection \
	  --left ${tmp}/lesion.penult.mask.nii.gz \
		--right ${prior} \
		--output ${tmp}/lesion.mask.nii.gz
else
  cp ${tmp}/lesion.penult.mask.nii.gz ${tmp}/lesion.mask.nii.gz
fi

echo "segmenting csf"

# CSF segmentation uses the interior (eroded) brain mask to avoid
# misclassifying skull-edge voxels as CSF.
# ADC rate (non-inverted): high ADC rates indicate free water (CSF)
runit qit --verbose VolumeFilterSigmoid \
	--thresh ${adcRateThreshCsf} \
	--input ${input}/adc_rate.nii.gz \
	--mask ${tmp}/interior.mask.nii.gz \
	--output ${tmp}/csf.prob.adc_rate.nii.gz

# T2 rate (inverted): high T2 rates indicate long relaxation times (free water)
runit qit --verbose VolumeFilterSigmoid \
	--invert --thresh ${t2RateThreshCsf} \
	--input ${input}/t2_rate.nii.gz \
	--mask ${tmp}/interior.mask.nii.gz \
	--output ${tmp}/csf.prob.t2_rate.nii.gz

# Joint CSF probability: product of ADC and T2 probabilities
runit qit --verbose VolumeVoxelMathScalar \
	--a ${tmp}/csf.prob.adc_rate.nii.gz \
	--b ${tmp}/csf.prob.t2_rate.nii.gz \
	--mask ${mask} \
	--expression "a*b" \
	--output ${tmp}/csf.prob.nii.gz

runit qit --verbose VolumeThreshold \
	--input ${tmp}/csf.prob.nii.gz \
	--threshold ${sigmoidThreshCsf} \
	--output ${tmp}/csf.mask.nii.gz

echo ""

# Build the combined ROI volume: start with brain mask (tissue=1),
# then overlay CSF (label=2) and lesion (label=3).
# Lesion is applied last so it takes priority over CSF in overlapping regions.
runit qit --verbose MaskSet \
	--input ${mask} \
	--mask ${tmp}/csf.mask.nii.gz \
	--label 2 \
	--output ${tmp}/rois.nii.gz

runit qit --verbose MaskSet \
	--input ${tmp}/rois.nii.gz \
	--mask ${tmp}/lesion.mask.nii.gz \
	--label 3 \
	--output ${tmp}/rois.nii.gz

# Extract the final tissue mask (everything that is not CSF or lesion)
runit qit --verbose MaskExtract \
	--input ${tmp}/rois.nii.gz \
	--label 1 \
	--output ${tmp}/tissue.mask.nii.gz

# Write the ROI lookup table
echo "index,name" > ${tmp}/rois.csv
echo "1,tissue" >> ${tmp}/rois.csv
echo "2,csf" >> ${tmp}/rois.csv
echo "3,lesion" >> ${tmp}/rois.csv

echo "cleaning up"

if [ -e ${output} ]; then
	bck=${output}.bck.${RANDOM}
  echo "backing up results: ${bck}"
  mv ${output} ${bck}
fi

mv ${tmp} ${output}

echo "finished"

################################################################################
# END
################################################################################
