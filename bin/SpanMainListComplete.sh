#! /usr/bin/env bash 
##############################################################################
#
#  SPAN Rodent MRI Analytics 
#
#    A script for checking which cases have been completely processed.
#
#  Author: Ryan Cabeen
#
##############################################################################

mybin=$(cd $(dirname ${0}); pwd -P)
name=$(basename $0)

if [ ! -e source ]; then echo "source directory not found!"; exit; fi

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
