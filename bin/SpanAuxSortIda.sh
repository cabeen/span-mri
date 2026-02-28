#! /usr/bin/env bash
##############################################################################
#
#  SPAN Rodent MRI Analytics — LONI IDA Data Sorting
#
#  Purpose:
#    Sorts LONI IDA-imported data by subject ID. Parses subject IDs from
#    underscore-delimited directory names and reorganizes files into
#    per-subject subdirectories.
#
#  Inputs:
#    $1 — Input directory with IDA-format subdirectories
#    $2 — Output directory organized by subject ID
#
#  Author: Ryan Cabeen
#
##############################################################################

workflow=$(cd $(dirname ${0}); cd ..; pwd -P)

name=$(basename $0)

usage()
{
    echo "
Name: ${name}

Description:

  Sort LONI IDA-imported data by subject ID. Parses subject IDs from
  underscore-delimited directory names and reorganizes files into
  per-subject subdirectories.

Usage:

  ${name} <input_dir> <output_dir>

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
