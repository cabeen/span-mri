#! /usr/bin/env bash 
##############################################################################
#
#  SPAN Rodent MRI Analytics 
#
#    A script for importing data downloaded from the LONI IDA
#
#  Author: Ryan Cabeen
#
##############################################################################

workflow=$(cd $(dirname ${0}); cd ..; pwd -P)

name=$(basename $0)

if [ $# -ne "5" ]; then
    echo "Usage: ${name} <early.zip> <late.zip> <meta> <cases> <source>"
    exit 1
fi

echo "started"

earlyzip=${1}
latezip=${2}
metadir=${3}
casesdir=${4}
sourcedir=${5}

function runit 
{
  $@
  if [ $? != 0 ]; then 
    echo "error encountered, please check the log"; 
    exit 1
  fi
}

mkdir -p ${casesdir}

if [ ! -e ${casesdir}/early ]; then
  echo "... importing early timepoint data"
  unzip ${earlyzip} -d ${casesdir}/early-tmp
  mv ${casesdir}/early-tmp/SPAN* ${casesdir}/early
  rm -rf ${casesdir}/early-tmp
fi

if [ ! -e ${casesdir}/late ]; then
  echo "... importing late timepoint data"
  unzip ${latezip} -d ${casesdir}/late-tmp
  mv ${casesdir}/late-tmp/SPAN* ${casesdir}/late
  rm -rf ${casesdir}/late-tmp
fi

for s in mouse rat; do
  for t in early late; do
    for c in $(cat ${metadir}/${s}.txt); do
      ind=${casesdir}/${t}/${c}
      outd=${sourcedir}/${s}/${t}/${c}
      if [ -e ${ind} ] && [ ! -e ${outd} ]; then
        echo "... moving ${ind} to ${outd}"
        mv ${ind} ${outd}
      fi
    done
  done
done

echo "finished"

################################################################################
# END
################################################################################
