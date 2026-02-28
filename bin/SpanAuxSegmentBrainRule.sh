#! /usr/bin/env bash
##############################################################################
#
#  SPAN Rodent MRI Analytics — Rule-Based Brain Extraction (Rats)
#
#  Purpose:
#    Extracts the brain from rodent MRI using a multi-step morphological
#    pipeline. Designed for rat brain images where the U-Net model is not
#    available. Operates on the ADC baseline image from exponential decay
#    fitting.
#
#  Algorithm:
#    1. Foreground detection — Otsu-based thresholding to separate tissue
#       from background, keeping only the largest connected component
#    2. Contrast enhancement — Histogram equalization within the foreground
#    3. NLM smoothing — Non-local means filtering (h=0.15) to reduce noise
#       while preserving edges, applied slice-by-slice in the J axis
#    4. Gradient edge detection — Sobel gradient magnitude to find tissue
#       boundaries; threshold at 2.5 to create an edge mask
#    5. Island detection — Invert edges within foreground to find connected
#       tissue regions separated by edges
#    6. Graph segmentation — Felzenszwalb graph-based segmentation within
#       the island mask (threshold=0.5, min component size=10 voxels)
#    7. Size filtering — Keep only components with >=30000 voxels that have
#       the highest mean intensity (selects the brain over muscle/fat)
#    8. Morphological refinement:
#       a. Pad by 5 voxels → close with sphere(2) → resample back
#       b. Open with sphere(3), keeping largest component
#       c. Pad by 20 voxels → close with sphere(4) → resample back
#       d. Dilate → fill holes
#    9. MRF-EM cleanup — Markov Random Field Expectation-Maximization
#       refinement (2 iterations, gamma=10) to smooth the boundary
#       using both spatial context and image intensity
#   10. Final intersection with the foreground mask
#
#  Inputs:
#    $1 — Directory containing native.fit results (uses adc_base.nii.gz)
#    $2 — Output brain mask path (brain.mask.nii.gz)
#
#  Outputs:
#    Brain mask NIfTI file at the specified output path
#    Intermediate results in a .seg directory alongside the output
#
#  Dependencies: QIT
#
#  Author: Ryan Cabeen
#
##############################################################################

name=$(basename $0)

usage()
{
    echo "
Name: ${name}

Description:

  Extract the brain from rat MRI using a multi-step morphological pipeline.
  Operates on the ADC baseline image from exponential decay fitting.
  Steps include Otsu thresholding, NLM smoothing, gradient edge detection,
  graph segmentation, morphological refinement, and MRF-EM cleanup.

Usage:

  ${name} <input_fit_dir> <output.nii.gz>

Inputs:

  input_fit_dir   — Directory containing native.fit results (uses adc_base.nii.gz)
  output.nii.gz   — Output brain mask path

Author: Ryan Cabeen
"
    exit 1
}

if [ "${1:-}" == "--help" ] || [ "${1:-}" == "-h" ]; then usage; fi
if [ $# -lt "2" ]; then usage; fi

function runit
{
  echo "    running: $@"
  $@
  if [ $? != 0 ]; then 
    echo "[error] command failed: $@"
    exit 1
  fi
}

echo "started"

input=$1
output=$2

if [ ! -e ${input} ]; then
    echo "Error: input file not found: ${input}"
    exit
fi

if [ ! -e ${input}/adc_base.nii.gz ]; then
    echo "Error: input file not found: ${input}/adc_base.nii.gz"
    exit
fi

tmp=$(echo ${output} | sed 's/.nii.gz//g').seg
mkdir -p ${tmp}

echo "using input: ${input}"
echo "using output: ${output}"
echo "using intermediate: ${tmp}"

runit cp ${input}/adc_base.nii.gz ${tmp}/input.nii.gz

# Step 1: Foreground detection — separate tissue from air/background
runit qit --verbose VolumeSegmentForeground \
  --largest \
  --input ${tmp}/input.nii.gz \
  --output ${tmp}/mask.foreground.nii.gz

# Step 2: Contrast enhancement within the foreground mask
runit qit --verbose VolumeEnhanceContrast \
  --input ${tmp}/input.nii.gz \
  --mask ${tmp}/mask.foreground.nii.gz \
  --output ${tmp}/enhanced.nii.gz

# Step 3: Non-local means smoothing to reduce noise while preserving edges
runit qit --verbose VolumeFilterNLM \
  --mode SliceJ --h 0.15 \
  --input ${tmp}/enhanced.nii.gz \
  --output ${tmp}/smooth.nii.gz

# Step 4: Sobel gradient magnitude to detect tissue boundaries
runit qit --verbose VolumeFilterGradient \
  --sobel --mag \
  --input ${tmp}/smooth.nii.gz \
  --mask ${tmp}/mask.foreground.nii.gz \
  --output ${tmp}/gradient.nii.gz

# Step 5: Threshold gradient to find edges, invert to find connected islands
runit qit --verbose VolumeThreshold \
  --input ${tmp}/gradient.nii.gz \
  --threshold 2.5 \
  --output ${tmp}/mask.edges.nii.gz

runit qit --verbose MaskInvert \
  --input ${tmp}/mask.edges.nii.gz \
  --mask ${tmp}/mask.foreground.nii.gz \
  --output ${tmp}/mask.islands.nii.gz

# Step 6: Graph-based segmentation to cluster connected tissue regions
runit qit --verbose VolumeSegmentGraph \
  --input ${tmp}/smooth.nii.gz \
  --mask ${tmp}/mask.islands.nii.gz \
  --threshold 0.5 --min 10 \
  --output ${tmp}/mask.cluster.nii.gz

# Step 7: Keep only large components (>=30000 voxels) with highest intensity
runit qit --verbose MaskFilter \
  --input ${tmp}/mask.cluster.nii.gz \
  --ref ${tmp}/smooth.nii.gz \
  --minvox 30000 --highest \
  --output ${tmp}/mask.isolate.nii.gz

# Step 8: Morphological refinement — pad, close, open, fill holes
runit qit --verbose MaskPad \
  --pad 5 \
  --input ${tmp}/mask.isolate.nii.gz \
  --output ${tmp}/mask.brain.nii.gz
runit qit --verbose MaskClose \
  --input ${tmp}/mask.brain.nii.gz \
  --num 1 --outside --element 'sphere{2}' \
  --output ${tmp}/mask.brain.nii.gz
runit qit MaskTransform \
  --input ${tmp}/mask.brain.nii.gz \
  --reference ${tmp}/smooth.nii.gz \
  --output ${tmp}/mask.brain.nii.gz

runit qit --verbose MaskOpen \
  --input ${tmp}/mask.brain.nii.gz \
  --num 1 --largest --element 'sphere{3}' \
  --output ${tmp}/mask.brain.nii.gz

runit qit --verbose MaskPad \
  --pad 20 \
  --input ${tmp}/mask.brain.nii.gz \
  --output ${tmp}/mask.brain.nii.gz
runit qit --verbose MaskClose \
  --input ${tmp}/mask.brain.nii.gz \
  --num 4 --outside --element 'sphere{4}' \
  --output ${tmp}/mask.brain.nii.gz
runit qit MaskTransform \
  --input ${tmp}/mask.brain.nii.gz \
  --reference ${tmp}/smooth.nii.gz \
  --output ${tmp}/mask.brain.nii.gz

runit qit --verbose MaskDilate \
  --input ${tmp}/mask.brain.nii.gz \
  --output ${tmp}/mask.brain.nii.gz

runit qit --verbose MaskFill \
  --input ${tmp}/mask.brain.nii.gz \
  --output ${tmp}/mask.brain.nii.gz

# Step 9: MRF-EM refinement — uses spatial context and intensity to smooth boundary
runit qit --verbose MaskMRFEM \
  --input ${tmp}/mask.brain.nii.gz \
  --volume ${tmp}/smooth.nii.gz \
  --mask ${tmp}/mask.foreground.nii.gz \
  --distance 0.5 --mrfEmIters 2 --mrfGamma 10 \
  --output ${tmp}/mask.brain.nii.gz

# Step 10: Final intersection with foreground mask
runit qit --verbose MaskIntersection \
  --left ${tmp}/mask.brain.nii.gz \
  --right ${tmp}/mask.foreground.nii.gz \
  --output ${tmp}/mask.brain.nii.gz

cp ${tmp}/mask.brain.nii.gz ${output}

echo "finished"

##############################################################################
