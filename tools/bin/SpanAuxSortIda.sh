#! /usr/bin/env bash 
##############################################################################
#
#  SPAN Rodent MRI Analytics 
#
#    A script for sorting data downloaded from the LONI IDA
#
#  Author: Ryan Cabeen
#
##############################################################################

workflow=$(cd $(dirname ${0}); cd ..; pwd -P)

name=$(basename $0)

if [ $# -ne "2" ]; then
    echo "Usage: ${name} <input_dir> <output_dir>"
    exit 1
fi

input=${1}
output=${2}

function runit 
{
  $@
  if [ $? != 0 ]; then 
    echo "error encountered, please check the log"; 
    exit 1
  fi
}

mkdir -p ${output}

for d in ${input}/*; do
  if [ $(echo $(basename ${d}) | sed 's/_/ /g' | wc -w) -gt 2 ]; then
    sid=$(echo $(basename ${d}) | cut -d_ -f2)
    mkdir -p ${output}/${sid}
    mv ${d} ${output}/${sid}
  else
    "warning: skipping ${d}"
  fi
done

echo "finished"

################################################################################
# END
################################################################################
