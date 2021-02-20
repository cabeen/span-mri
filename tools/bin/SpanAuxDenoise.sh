#! /usr/bin/env bash 
##############################################################################
#
#  SPAN Rodent MRI Analytics 
#
#    A script for image denoising 
#
#  Author: Ryan Cabeen
#
##############################################################################

if [ $# -lt "1" ]; then
    echo "Usage: ${name} <input.nii.gz> <output.nii.gz>"
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
