#! /usr/bin/env bash 
##############################################################################
#
#  SPAN Rodent MRI Analytics 
#
#    A script for checking which cases have not be completely processed.
#    This will identify cases which have source data but have not completed
#    running through the entire pipeline.  This could be due to a hardware
#    failure, or some problem with the data, e.g. a missing scan.  You
#    will have to look at the incomplete cases to figure out exactly what
#    the problem is (or simply try re-running them to see if that helps!)
#
#  Author: Ryan Cabeen
#
##############################################################################

mybin=$(cd $(dirname ${0}); pwd -P)
name=$(basename $0)

if [ ! -e source ]; then echo "source directory not found!"; exit; fi

cd source
for s in */*/*; do 
  if [ ! -e ../process/${s}/standard.map/volume.csv ]; then 
    echo ${s}; 
  fi 
done
cd ..

################################################################################
# END
################################################################################
