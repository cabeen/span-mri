#! /usr/bin/env bash 
##############################################################################
#
#  SPAN Rodent MRI Analytics 
#
#    A script for skull stripping
#
#  Author: Ryan Cabeen
#
##############################################################################

if [ $# -lt "1" ]; then
    echo "Usage: ${name} <input> <output>"
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

tmp=$(echo ${output} | sed 's/.nii.gz//g').seg
mkdir -p ${tmp}

echo "using input: ${input}"
echo "using output: ${output}"
echo "using intermediate: ${tmp}"

runqit="runit qit --verbose"

runit cp ${input} ${tmp}/input.nii.gz

runit qit --verbose VolumeSegmentForeground \
  --largest \
  --input ${tmp}/input.nii.gz \
  --output ${tmp}/mask.fg.nii.gz

runit qit --verbose MaskErode \
  --input ${tmp}/mask.fg.nii.gz \
  --output ${tmp}/mask.fg.nii.gz

${runqit} VolumeEnhanceContrast \
  --input ${tmp}/input.nii.gz \
  --mask ${tmp}/mask.fg.nii.gz \
  --output ${tmp}/enhanced.nii.gz

${runqit} VolumeFilterNLM \
  --mode SliceI --h 0.15 \
  --input ${tmp}/enhanced.nii.gz \
  --output ${tmp}/smooth.nii.gz
${runqit} VolumeFilterNLM \
  --mode SliceJ --h 0.15 \
  --input ${tmp}/smooth.nii.gz \
  --output ${tmp}/smooth.nii.gz
${runqit} VolumeFilterNLM \
  --mode SliceK --h 0.15 \
  --input ${tmp}/smooth.nii.gz \
  --output ${tmp}/smooth.nii.gz

${runqit} VolumeFilterGradient \
  --sobel --mag \
  --input ${tmp}/smooth.nii.gz \
  --output ${tmp}/gradient.nii.gz

${runqit} VolumeFilterHessian \
  --mode Ridge \
  --input ${tmp}/smooth.nii.gz \
  --output ${tmp}/ridge.nii.gz

${runqit} VolumeFilterHessian \
  --mode Ridge \
  --input ${tmp}/smooth.nii.gz \
  --output ${tmp}/ridge.nii.gz

${runqit} VolumeThreshold \
  --threshold 0 --invert \
  --input ${tmp}/ridge.nii.gz \
  --output ${tmp}/half.nii.gz

${runqit} VolumeThreshold \
  --input ${tmp}/gradient.nii.gz \
  --input ${tmp}/half.nii.gz \
  --threshold 2.5 \
  --output ${tmp}/mask.edges.nii.gz

# ${runqit} MaskFilterMedian \
#   --input ${tmp}/mask.edges.nii.gz \
#   --window 2 \
#   --output ${tmp}/mask.edges.nii.gz

${runqit} MaskInvert \
  --input ${tmp}/mask.edges.nii.gz \
  --mask ${tmp}/mask.fg.nii.gz \
  --output ${tmp}/mask.islands.nii.gz

${runqit} VolumeSegmentGraph \
  --input ${tmp}/smooth.nii.gz \
  --mask ${tmp}/mask.islands.nii.gz \
  --threshold 0.5 --min 10 \
  --output ${tmp}/mask.clusters.nii.gz

${runqit} MaskFilter \
  --input ${tmp}/mask.clusters.nii.gz \
  --ref ${tmp}/smooth.nii.gz \
  --minvox 50000 --highest \
  --output ${tmp}/mask.cluster.nii.gz

${runqit} MaskOpen \
  --num 1 --largest \
  --input ${tmp}/mask.cluster.nii.gz \
  --output ${tmp}/mask.open.nii.gz

${runqit} MaskDilate \
  --num 3 --outside \
  --input ${tmp}/mask.open.nii.gz \
  --output ${tmp}/mask.dilate.nii.gz

${runqit} MaskPad \
  --pad 11 \
  --input ${tmp}/mask.dilate.nii.gz \
  --output ${tmp}/mask.closer.nii.gz
${runqit} MaskClose \
  --input ${tmp}/mask.closer.nii.gz \
  --num 10 --outside \
  --output ${tmp}/mask.closer.nii.gz
${runqit} MaskTransform \
  --input ${tmp}/mask.closer.nii.gz \
  --reference ${tmp}/smooth.nii.gz \
  --output ${tmp}/mask.closer.nii.gz

${runqit} MaskFill \
  --input ${tmp}/mask.closer.nii.gz \
  --output ${tmp}/mask.fill.nii.gz

${runqit} MaskFilterMedian \
  --window 2 \
  --input ${tmp}/mask.fill.nii.gz \
  --output ${tmp}/mask.median.nii.gz

${runqit} MaskShell \
  --input ${tmp}/mask.median.nii.gz \
  --num 2 --mode Inner \
  --output ${tmp}/mask.shell.nii.gz

${runqit} VolumeThreshold \
  --input ${tmp}/smooth.nii.gz \
  --mask ${tmp}/mask.shell.nii.gz \
  --threshold 0.5 --invert \
  --output ${tmp}/mask.rim.nii.gz

${runqit} MaskSet \
  --input ${tmp}/mask.median.nii.gz \
  --mask ${tmp}/mask.rim.nii.gz \
  --label 0 \
  --output ${tmp}/mask.derim.nii.gz

${runqit} MaskFilterMedian \
  --window 2 \
  --input ${tmp}/mask.derim.nii.gz \
  --output ${tmp}/mask.brain.nii.gz

${runqit} MaskFill \
  --input ${tmp}/mask.brain.nii.gz \
  --output ${tmp}/mask.brain.nii.gz

${runqit} MaskLargest \
  --input ${tmp}/mask.brain.nii.gz \
  --output ${tmp}/mask.brain.nii.gz

cp ${tmp}/mask.brain.nii.gz ${output}

echo "finished"

##############################################################################
