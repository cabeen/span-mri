#! /bin/bash
##############################################################################
#
#  SPAN Rodent MRI Analytics — Group Lesion/CSF Volume Fusion (Parallel)
#
#  Purpose:
#    Uses GNU parallel for fast computation of group-level mean and std
#    lesion/CSF probability maps across subjects, stratified by site and
#    timepoint. Similar to SpanMainFuse.sh but optimized for parallel
#    execution.
#
#  Dependencies: QIT (VolumeFuse), GNU parallel
#
#  Author: Ryan Cabeen
#
##############################################################################

name=$(basename $0)

usage()
{
    echo "
Name: ${name}

Description:

  Compute group-level mean and std lesion/CSF probability maps across
  subjects using GNU parallel, stratified by site and timepoint.

Usage:

  ${name} [--help]

Author: Ryan Cabeen
"
    exit 1
}

if [ "${1:-}" == "--help" ] || [ "${1:-}" == "-h" ]; then usage; fi

for d in $PWD/process/*/*; do \
  if [ -e ${d}/standard.vis ]; then 
    echo ${d} >> group/subsets/$(cat ${d}/native.import/site.txt)_$(cat ${d}/native.import/timepoint.txt).txt; 
  fi 
done

for s in {AG,JH,MG,UI,UT,YL}_{ERLY,LATE}; do 
  for p in rare {t2,adc}_{rate,base}; do 
    echo qit -Xmx24G --verbose VolumeFuse --input %s/standard.harm/${p}.nii.gz --pattern group/subsets/${s}.txt --skip --output-mean group/fuse/${s}.${p}.mean.nii.gz --output-std group/fuse/${s}.${p}.std.nii.gz; 
  done 
done | parallel -j 5

for s in {AG,JH,MG,UI,UT,YL}_{ERLY,LATE}; do 
  for p in lesion csf; do
    echo qit -Xmx24G --verbose VolumeFuse --input %s/standard.seg/${p}.mask.nii.gz --pattern group/subsets/${s}.txt --skip --output-mean group/fuse/${s}.${p}.mean.nii.gz --output-std group/fuse/${s}.${p}.std.nii.gz; 
  done 
done | parallel -j 5
