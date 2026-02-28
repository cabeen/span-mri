#! /usr/bin/env bash
##############################################################################
#
#  SPAN Rodent MRI Analytics — Eye Segmentation
#
#  Purpose:
#    Detects and segments the eyes from a T2 baseline image using blob
#    detection. Eyes appear as dark spherical structures in T2-weighted
#    images. Uses Gaussian smoothing, Hessian-based dark blob detection,
#    Otsu thresholding, and selects the two largest connected components.
#    Outputs the centroids of detected eyes.
#
#  Inputs:
#    $1 — Input T2 baseline NIfTI volume (.nii.gz)
#    $2 — Output eye centroid coordinates (.txt)
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

  Detect and segment eyes from a T2 baseline image using blob detection.
  Uses Gaussian smoothing, Hessian-based dark blob detection, and Otsu
  thresholding to identify the two largest connected components (eyes).

Usage:

  ${name} <input.nii.gz> <output.txt>

Inputs:

  input.nii.gz  — T2 baseline NIfTI volume
  output.txt    — Output eye centroid coordinates

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

tmp=$(echo ${output} | sed 's/.nii.gz//g').eyeseg
mkdir -p ${tmp}

echo "using input: ${input}"
echo "using output: ${output}"
echo "using intermediate: ${tmp}"

runit cp ${input} ${tmp}/input.nii.gz

runit qit --verbose VolumeFilterGaussian \
  --support 3 \
  --sigma 0.5 \
  --num 3 \
  --input ${tmp}/input.nii.gz \
  --output ${tmp}/gauss.nii.gz

runit qit --verbose VolumeFilterHessian \
  --input ${tmp}/gauss.nii.gz \
  --mode DarkBlob \
  --output ${tmp}/blob.nii.gz

runit qit --verbose VolumeThresholdOtsu \
  --input ${tmp}/blob.nii.gz \
  --output ${tmp}/eyes.nii.gz

runit qit --verbose MaskFilter \
  --input ${tmp}/eyes.nii.gz \
  --largestn 2 \
  --output ${tmp}/eyes.nii.gz

runit qit --verbose MaskComponents \
  --input ${tmp}/eyes.nii.gz \
  --output ${tmp}/eyes.nii.gz

runit qit --verbose MaskCentroids \
  --input ${tmp}/eyes.nii.gz \
  --output ${tmp}/eyes.txt

cp ${tmp}/eyes.txt ${output}

echo "finished"

##############################################################################
