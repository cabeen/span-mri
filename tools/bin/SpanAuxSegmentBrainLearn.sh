#! /usr/bin/env bash 
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

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/usr/local/anaconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/usr/local/anaconda3/etc/profile.d/conda.sh" ]; then
        . "/usr/local/anaconda3/etc/profile.d/conda.sh"
    else
        export PATH="/usr/local/anaconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

conda activate spanenv

qit VolumeFuse \
    --input ${input}/{t2,adc}_{base,rate}.nii.gz \
    --output-cat ${output}.fuse.nii.gz \

python ${ROOT}/lib/unetseg/predict.py \
  --model ${ROOT}/lib/brain-model \
  --image ${output}.fuse.nii.gz \
  --output ${output}

rm ${output}.fuse.nii.gz

echo "finished"

##############################################################################
# End
##############################################################################
