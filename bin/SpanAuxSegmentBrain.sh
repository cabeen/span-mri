#! /usr/bin/env bash
##############################################################################
#
#  SPAN Rodent MRI Analytics — Rule-Based Brain Extraction (Legacy)
#
#  Purpose:
#    Legacy version of the rule-based brain extraction script.
#    Superseded by SpanAuxSegmentBrainRule.sh, which operates on the ADC
#    baseline from the fit directory rather than a single input image.
#    Uses the same multi-step morphological pipeline: foreground detection,
#    contrast enhancement, NLM smoothing, gradient edge detection, graph
#    segmentation, morphological refinement, and MRF-EM cleanup.
#
#  Inputs:
#    $1 — Input NIfTI volume (single image)
#    $2 — Output brain mask path
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

  Legacy rule-based brain extraction. Superseded by SpanAuxSegmentBrainRule.sh.
  Uses a multi-step morphological pipeline for brain segmentation.

Usage:

  ${name} <input.nii.gz> <output.nii.gz>

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

tmp=$(echo ${output} | sed 's/.nii.gz//g').seg
mkdir -p ${tmp}

echo "using input: ${input}"
echo "using output: ${output}"
echo "using intermediate: ${tmp}"

runit cp ${input} ${tmp}/input.nii.gz

runit qit --verbose VolumeSegmentForeground \
  --largest \
  --input ${tmp}/input.nii.gz \
  --output ${tmp}/mask.foreground.nii.gz

runit qit --verbose VolumeEnhanceContrast \
  --input ${tmp}/input.nii.gz \
  --mask ${tmp}/mask.foreground.nii.gz \
  --output ${tmp}/enhanced.nii.gz

runit qit --verbose VolumeFilterNLM \
  --mode SliceJ --h 0.15 \
  --input ${tmp}/enhanced.nii.gz \
  --output ${tmp}/smooth.nii.gz

runit qit --verbose VolumeFilterGradient \
  --sobel --mag \
  --input ${tmp}/smooth.nii.gz \
  --mask ${tmp}/mask.foreground.nii.gz \
  --output ${tmp}/gradient.nii.gz

runit qit --verbose VolumeThreshold \
  --input ${tmp}/gradient.nii.gz \
  --threshold 2.5 \
  --output ${tmp}/mask.edges.nii.gz

runit qit --verbose MaskInvert \
  --input ${tmp}/mask.edges.nii.gz \
  --mask ${tmp}/mask.foreground.nii.gz \
  --output ${tmp}/mask.islands.nii.gz

runit qit --verbose VolumeSegmentGraph \
  --input ${tmp}/smooth.nii.gz \
  --mask ${tmp}/mask.islands.nii.gz \
  --threshold 0.5 --min 10 \
  --output ${tmp}/mask.cluster.nii.gz

runit qit --verbose MaskFilter \
  --input ${tmp}/mask.cluster.nii.gz \
  --ref ${tmp}/smooth.nii.gz \
  --minvox 30000 --highest \
  --output ${tmp}/mask.isolate.nii.gz

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

runit qit --verbose MaskMRFEM \
  --input ${tmp}/mask.brain.nii.gz \
  --volume ${tmp}/smooth.nii.gz \
  --mask ${tmp}/mask.foreground.nii.gz \
  --distance 0.5 --mrfEmIters 2 --mrfGamma 10 \
  --output ${tmp}/mask.brain.nii.gz

runit qit --verbose MaskIntersection \
  --left ${tmp}/mask.brain.nii.gz \
  --right ${tmp}/mask.foreground.nii.gz \
  --output ${tmp}/mask.brain.nii.gz

cp ${tmp}/mask.brain.nii.gz ${output}

echo "finished"

##############################################################################
