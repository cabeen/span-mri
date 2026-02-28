#! /usr/bin/env bash
##############################################################################
#
#  SPAN Rodent MRI Analytics — Non-Local Means Denoising
#
#  Purpose:
#    Denoises a multi-echo NIfTI volume using non-local means (NLM) filtering.
#    Creates a foreground mask via Otsu thresholding, then applies slice-wise
#    NLM filtering with a relative noise level (h=0.1, estimated from the
#    Otsu mask). This reduces noise while preserving structural edges.
#
#  Inputs:
#    $1 — Input NIfTI volume (.nii.gz)
#    $2 — Output denoised NIfTI volume (.nii.gz)
#
#  Outputs:
#    Denoised NIfTI volume at the specified output path
#
#  Dependencies: QIT
#
#  Pipeline context: Called by SpanMainRun.sh as stage 4 (native.denoise)
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

  Denoise a multi-echo NIfTI volume using non-local means (NLM) filtering.
  Creates a foreground mask via Otsu thresholding, then applies slice-wise
  NLM filtering to reduce noise while preserving edges.

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

echo "using input: ${input}"
echo "using output: ${output}"

runit qit --verbose VolumeThresholdOtsu \
	--input ${input} \
	--output ${output}.mask.nii.gz

runit qit --verbose VolumeFilterNLM \
	--mode SliceJ --h 0.1 --hrel \
  --hrelMask ${output}.mask.nii.gz \
	--input ${input} \
	--output ${output}

rm ${output}.mask.nii.gz

echo "finished"

##############################################################################
