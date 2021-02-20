#! /usr/bin/env bash 
##############################################################################
#
#  SPAN Rodent MRI Analytics 
#
#    A script for eye segmentation.  The input should be a T2 baseline.
#
#  Author: Ryan Cabeen
#
##############################################################################

if [ $# -lt "1" ]; then
    echo "Usage: ${name} <input.nii.gz> <output.txt>"
    exit 1
fi

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
