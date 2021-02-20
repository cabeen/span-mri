#! /usr/bin/env bash 
##############################################################################
#
#  SPAN Rodent MRI Analytics 
#
#    A script for converting a directory of subjects from dicom to nifti.  
#    This assumes that dcm2niix is on the path
#
#  Author: Ryan Cabeen
#
##############################################################################

mybin=$(cd $(dirname ${0}); pwd -P)

name=$(basename $0)

if [ $# -ne "2" ]; then
    echo "Usage: ${name} <input_dir> <output_dir>"
    exit 1;
fi

input=${1}
output=${2}

function runit 
{
  $@
  if [ $? != 0 ]; then 
    echo "error encountered, please check the log"; 
    exit 1; 
  fi
}

echo "started ${name}"
echo "  using input: ${input}"
echo "  using output: ${output}"

mkdir -p ${output}

for d in ${input}/*; do
  base=$(basename ${d})
  echo ".. converting ${base}"
  bash ${mybin}/SpanAuxConvert.sh ${input}/${base} ${output}/${base} 
done

echo "finished"

################################################################################
# END
################################################################################
