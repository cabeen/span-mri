#! /usr/bin/env bash
##############################################################################
#
#  SPAN Rodent MRI Analytics — Batch DICOM Conversion
#
#  Purpose:
#    Batch wrapper that calls SpanAuxConvert.sh for each subject directory
#    within the input directory. Converts all subjects from DICOM to NIfTI.
#
#  Inputs:
#    $1 — Input directory containing subject subdirectories with DICOM data
#    $2 — Output directory (subject subdirectories will be created)
#
#  Dependencies: dcm2niix, dcmdump, SpanAuxConvert.sh
#
#  Author: Ryan Cabeen
#
##############################################################################

mybin=$(cd $(dirname ${0}); pwd -P)

name=$(basename $0)

usage()
{
    echo "
Name: ${name}

Description:

  Batch DICOM conversion. Calls SpanAuxConvert.sh for each subject
  subdirectory within the input directory.

Usage:

  ${name} <input_dir> <output_dir>

Inputs:

  input_dir   — Directory containing subject subdirectories with DICOM data
  output_dir  — Output directory (subject subdirectories will be created)

Author: Ryan Cabeen
"
    exit 1
}

if [ "${1:-}" == "--help" ] || [ "${1:-}" == "-h" ]; then usage; fi
if [ $# -ne "2" ]; then usage; fi

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
