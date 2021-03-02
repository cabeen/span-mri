#! /usr/bin/env bash 
##############################################################################
#
#  SPAN Rodent MRI Analytics 
#
#    A script for grouping results across individuals
#
#  Author: Ryan Cabeen
#
##############################################################################

mybin=$(cd $(dirname ${0}); pwd -P)
name=$(basename $0)

if [ ! -e process ]; then echo "process directory not found!"; exit; fi

function runit 
{
  $@
  if [ $? != 0 ]; then 
    echo "error encountered, please check the log"; 
    exit 1;
  fi
}

echo "started ${name}"

mkdir -p group/fuse/lists
rm -rf group/fuse/lists/*

for d in process/*/*; do \
  if [ -e ${d}/standard.vis ]; then 
    echo ${d} >> group/fuse/lists/$(cat ${d}/native.import/site.txt)_$(cat ${d}/native.import/timepoint.txt).txt; 
  fi 
done

for s in {AG,JH,MG,UI,UT,YL}_{ERLY,LATE}; do 
  for p in rare {t2,adc}_{rate,base}; do 
    echo qit -Xmx12G --verbose VolumeFuse --input %s/standard.harm/${p}.nii.gz --pattern group/subsets/${s}.txt --skip --output-mean group/fuse/${s}.${p}.mean.nii.gz --output-std group/fuse/${s}.${p}.std.nii.gz; 
  done 
done | parallel -j 10

for s in {AG,JH,MG,UI,UT,YL}_{ERLY,LATE}; do 
  for p in lesion csf; do
    echo qit -Xmx12G --verbose VolumeFuse --input %s/standard.seg/${p}.mask.nii.gz --pattern group/subsets/${s}.txt --skip --output-mean group/fuse/${s}.${p}.mean.nii.gz --output-std group/fuse/${s}.${p}.std.nii.gz; 
  done 
done | parallel -j 10

echo "finished"

################################################################################
# END
################################################################################
