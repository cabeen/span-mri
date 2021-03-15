#! /usr/bin/env bash 
##############################################################################
#
#  SPAN Rodent MRI Analytics 
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

# t2RateThreshLesion=0.80
t2RateThreshLesion=0.775
adcRateThreshLesion=1.25
adcBaseThreshLesion=0.75
sigmoidHighThreshLesion=0.5
sigmoidLowThreshLesion=0.25
numOpenLesion=2
numDilateLesion=2

t2RateThreshCsf=0.75
adcRateThreshCsf=1.65
sigmoidThreshCsf=0.5

input=""
output=""
posit=""

while [ "$1" != "" ]; do
    case $1 in
        --input)                   shift; input=$1 ;;
        --mask)                    shift; mask=$1 ;;
        --output)                  shift; output=$1 ;;
        --t2RateThreshLesion)      shift; t2RateThreshLesion=$1 ;;
        --adcRateThreshLesion)     shift; adcRateThreshLesion=$1 ;;
        --adcBaseThreshLesion)     shift; adcBaseThreshLesion=$1 ;;
        --sigmoidHighThreshLesion) shift; sigmoidHighThreshLesion=$1 ;;
        --sigmoidLowThreshLesion)  shift; sigmoidLowThreshLesion=$1 ;;
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

runit qit --verbose MaskErode --num 2 \
	 --input ${mask} \
	 --output ${tmp}/interior.mask.nii.gz

echo "segmenting lesion"

runit qit --verbose VolumeFilterSigmoid \
	--invert --thresh ${adcRateThreshLesion} \
	--input ${input}/adc_rate.nii.gz \
	--mask ${mask} \
	--output ${tmp}/lesion.prob.adc_rate.nii.gz

runit qit --verbose VolumeFilterSigmoid \
	--invert --thresh ${t2RateThreshLesion} \
	--input ${input}/t2_rate.nii.gz \
	--mask ${mask} \
	--output ${tmp}/lesion.prob.t2_rate.nii.gz

runit qit --verbose VolumeFilterSigmoid \
	--thresh ${adcBaseThreshLesion} \
	--input ${input}/adc_base.nii.gz \
	--mask ${mask} \
	--output ${tmp}/lesion.prob.adc_base.nii.gz

runit qit --verbose VolumeVoxelMathScalar \
	--a ${tmp}/lesion.prob.t2_rate.nii.gz \
	--b ${tmp}/lesion.prob.adc_rate.nii.gz \
	--c ${tmp}/lesion.prob.adc_base.nii.gz \
	--mask ${mask} \
	--expression "a*b*c" \
	--output ${tmp}/lesion.rawprob.nii.gz

runit qit --verbose VolumeFilterMedian \
	--input ${tmp}/lesion.rawprob.nii.gz \
	--output ${tmp}/lesion.medprob.nii.gz

runit qit --verbose VolumeThreshold \
	--input ${tmp}/lesion.medprob.nii.gz \
	--threshold ${sigmoidHighThreshLesion} \
	--output ${tmp}/lesion.high.mask.nii.gz

runit qit --verbose MaskOpen \
	--input ${tmp}/lesion.high.mask.nii.gz \
	--num ${numOpenLesion} \
	--output ${tmp}/lesion.open.mask.nii.gz

runit qit --verbose MaskDilate \
	--input ${tmp}/lesion.open.mask.nii.gz \
	--num ${numDilateLesion} \
	--output ${tmp}/lesion.dil.mask.nii.gz

runit qit --verbose VolumeThreshold \
	--input ${tmp}/lesion.medprob.nii.gz \
	--mask ${tmp}/lesion.dil.mask.nii.gz \
	--threshold ${sigmoidLowThreshLesion} \
	--output ${tmp}/lesion.mask.nii.gz

echo "segmenting csf"

runit qit --verbose VolumeFilterSigmoid \
	--thresh ${adcRateThreshCsf} \
	--input ${input}/adc_rate.nii.gz \
	--mask ${tmp}/interior.mask.nii.gz \
	--output ${tmp}/csf.prob.adc_rate.nii.gz

runit qit --verbose VolumeFilterSigmoid \
	--invert --thresh ${t2RateThreshCsf} \
	--input ${input}/t2_rate.nii.gz \
	--mask ${tmp}/interior.mask.nii.gz \
	--output ${tmp}/csf.prob.t2_rate.nii.gz

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
