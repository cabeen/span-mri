#! /usr/bin/env bash
##############################################################################
#
#  SPAN Rodent MRI Analytics — LONI IDA Data Import
#
#  Purpose:
#    Imports data downloaded from the LONI Image & Data Archive (IDA).
#    Unzips early and late timepoint archives, identifies mouse and rat
#    subjects from CSV manifests, and organizes files into the standard
#    source/{mouse,rat}/{early,late}/<subject_id>/ directory structure.
#
#  Inputs:
#    $1 — Early timepoint ZIP archive
#    $2 — Late timepoint ZIP archive
#    $3 — Rat subject list CSV
#    $4 — Mouse subject list CSV
#    $5 — Cases directory (working directory for extraction)
#    $6 — Source directory (final organized output)
#
#  Dependencies: unzip
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

  Import data downloaded from the LONI Image & Data Archive (IDA).
  Unzips early and late timepoint archives, identifies mouse and rat
  subjects, and organizes into the standard directory structure.

Usage:

  ${name} <early.zip> <late.zip> <rat.csv> <mouse.csv> <cases_dir> <source_dir>

Author: Ryan Cabeen
"
    exit 1
}

if [ "${1:-}" == "--help" ] || [ "${1:-}" == "-h" ]; then usage; fi
if [ $# -ne "6" ]; then usage; fi

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
