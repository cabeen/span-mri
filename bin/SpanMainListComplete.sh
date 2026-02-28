#! /usr/bin/env bash
##############################################################################
#
#  SPAN Rodent MRI Analytics — List Completed Cases
#
#  Purpose:
#    Lists all subjects in source/ that have successfully completed the
#    full processing pipeline (determined by the presence of
#    process/<subject>/standard.map/volume.csv).
#
#  Usage: Run from the project root directory (containing source/ and process/)
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

  List all subjects in source/ that have completed the full processing
  pipeline (determined by presence of process/<subject>/standard.map/volume.csv).

Usage:

  ${name} [--help]

Author: Ryan Cabeen
"
    exit 1
}

if [ "${1:-}" == "--help" ] || [ "${1:-}" == "-h" ]; then usage; fi
if [ ! -e source ]; then echo "source directory not found!"; usage; fi

cd source
for s in */*/*; do 
  if [ -e ../process/${s}/standard.map/volume.csv ]; then 
    echo ${s}; 
  fi 
done
cd ..

################################################################################
# END
################################################################################
