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

if [ ! -e cases/process ]; then echo "process directory not found!"; exit; fi

function runit 
{
  $@
  if [ $? != 0 ]; then 
    echo "error encountered, please check the log"; 
    exit 1;
  fi
}

echo "started ${name}"

#qitrun="qsubcmd --qbigmem"
qitrun=""

mkdir -p group/fuse/lists
rm -rf group/fuse/lists/*

for d in cases/process/*/*; do \
  if [ -e ${d}/standard.vis ]; then 
    site=$(cat ${d}/native.import/site.txt)
    tp=$(cat ${d}/native.import/timepoint.txt)
    echo ${d} >> group/fuse/lists/${site}_${tp}.txt
  fi 
done

for p in rare {t2,adc}_{rate,base}; do 
  for s in {AG,JH,MG,UI,UT,YL}_{ERLY,LATE}; do 
    if [ ! -e group/fuse/${s}.${p}.mean.nii.gz ]; then
      ${qitrun} qit -Xmx12G --verbose VolumeFuse \
        --input %s/standard.harm/${p}.nii.gz \
        --pattern group/fuse/lists/${s}.txt \
        --skip \
        --output-mean group/fuse/${s}.${p}.mean.nii.gz \
        --output-std group/fuse/${s}.${p}.std.nii.gz
    fi
  done 
done 

for p in lesion csf; do
  for s in {AG,JH,MG,UI,UT,YL}_{ERLY,LATE}; do 
    if [ ! -e group/fuse/${s}.${p}.mean.nii.gz ]; then
      ${qitrun} qit -Xmx12G --verbose VolumeFuse \
        --input %s/standard.seg/${p}.mask.nii.gz \
        --pattern group/fuse/lists/${s}.txt \
        --skip \
        --output-mean group/fuse/${s}.${p}.mean.nii.gz \
        --output-std group/fuse/${s}.${p}.std.nii.gz
    fi
  done 
done

echo "finished"

################################################################################
# END
################################################################################
