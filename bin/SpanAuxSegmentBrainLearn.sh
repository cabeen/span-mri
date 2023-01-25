#! /usr/bin/bash 
##############################################################################
#
#  SPAN Rodent MRI Analytics 
#
#    A script for skull stripping using deep learning
#
#  Author: Ryan Cabeen
#
##############################################################################

if [ $# -lt "1" ]; then
    echo "Usage: $(basename ${0}) <input> <output>"
    exit 1
fi

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )"
source ~/.bash_profile

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

echo "fusing images"
qit VolumeFuse \
    --input ${input}/{t2,adc}_{base,rate}.nii.gz \
    --output-cat ${output}.fuse.nii.gz \

conda activate spanenv
echo "using python: $(which python)"

echo "running inference"
python ${ROOT}/lib/unetseg/predict.py \
  --model ${ROOT}/lib/brain-model \
  --image ${output}.fuse.nii.gz \
  --output ${output}

rm ${output}.fuse.nii.gz

echo "finished"

##############################################################################
# End
##############################################################################
