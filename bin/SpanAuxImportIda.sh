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

if [ $# -ne "6" ]; then
    echo "Usage: ${name} <early.zip> <late.zip> <rat.csv> <mouse.csv> <cases> <source>"
    exit 1
fi

echo "started"

earlyzip=${1}
latezip=${2}
ratcsv=${3}
mousecsv=${4}
casesdir=${5}
sourcedir=${6}

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
  echo ${casesdir}/early/* > ${casesdir}/early.txt
fi

if [ ! -e ${casesdir}/late ]; then
  echo "... importing late timepoint data"
  unzip ${latezip} -d ${casesdir}/late-tmp
  mv ${casesdir}/late-tmp/SPAN* ${casesdir}/late
  rm -rf ${casesdir}/late-tmp
  echo ${casesdir}/late/* > ${casesdir}/late.txt
fi

if [ ! -e ${casesdir}/rat.txt ]; then
  cat ${ratcsv} | awk -F, '{if (NR > 1) {print $1}}' > ${casesdir}/rat.txt
fi

if [ ! -e ${casesdir}/mouse.txt ]; then
  cat ${mousecsv} | awk -F, '{if (NR > 1) {print $1}}' > ${casesdir}/mouse.txt
fi

for s in mouse rat; do
  for t in early late; do
    for c in $(cat ${casesdir}/${s}.txt); do
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
