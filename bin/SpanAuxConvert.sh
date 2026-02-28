#! /usr/bin/env bash
##############################################################################
#
#  SPAN Rodent MRI Analytics — DICOM to NIfTI Conversion
#
#  Purpose:
#    Converts a directory of DICOM files to NIfTI format using dcm2niix.
#    Extracts the acquisition site name from DICOM JSON metadata and builds
#    a comprehensive image index CSV cataloging all scans with their DICOM
#    header fields (field strength, echo time, pixel spacing, etc.).
#
#  Inputs:
#    $1 — Input DICOM directory
#    $2 — Output directory
#
#  Outputs:
#    nifti/       — Converted NIfTI files (.nii.gz) and JSON sidecar files
#    site.txt     — Acquisition site name (from DICOM InstitutionName)
#    images.csv   — Index of all DICOM files with header metadata
#    log.txt      — Conversion log with path, site, date, and QIT version
#
#  Dependencies: dcm2niix, dcmdump (DCMTK), QIT, Python 3
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

  Convert a directory of DICOM files to NIfTI format using dcm2niix.
  Extracts the acquisition site name and builds an image index CSV.

Usage:

  ${name} <input_dir> <output_dir>

Inputs:

  input_dir   — Directory containing DICOM files
  output_dir  — Output directory for NIfTI files and metadata

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

function dicomQuery 
{
  cat ${1} | grep ${2} | cut -c 16- | sed -e 's/#.*//g' -e 's/\[//g' -e 's/\]//g' -e 's/\\0/_/g' | tr -s -c '[:alnum:]._-' '_' | sed -e 's/_$//g' -e 's/^_//g'  | awk '{print $0} END{if (NR==0) {print "Missing"}}'
}

function jsonQuery
{
  python3 -c "import sys, json; print(json.loads(open(\"${1}\", \"r\").read().replace(\"\\x10\", \"None\"))[\"${2}\"])" | sed 's/ /_/g'
}

echo "started ${name}"
echo "  using input: ${input}"
echo "  using output: ${output}"

dicomFields="InstitutionName Manufacturer ManufacturerModelName SoftwareVersions MagneticFieldStrength AcquisitionDate StudyID StudyDescription ProtocolName SeriesDescription SequenceName SliceThickness RepetitionTime EchoTime PixelSpacing AcquisitionMatrix"

if [ ! -e ${output} ]; then
  tmp=${output}.tmp.${RANDOM}
  mkdir -p ${tmp}/nifti
  dcm2niix -ba n -b y -z y -v y -f '%p_%s' -o ${tmp}/nifti ${input}
  if [ $? -ne 0 ]; then echo "error, failed to convert"; exit $?; fi 

  json=$(find ${tmp} -name "*json" -print -quit)
  echo "... querying site from ${json}"
  site=$(jsonQuery ${json} InstitutionName)
  echo ${site} > ${tmp}/site.txt

  echo "... building index"
  header="SliceCount,FilenameSeries,FilenameImage,FilenameDate,FilenameBase"
  for field in ${dicomFields}; do
    header="${header},Dicom${field}"
  done
  echo ${header} > ${tmp}/images.csv

  echo "... indexing dicoms"
  for filename in $(find ${input} -name "*dcm"); do 
    echo "... indexing ${filename}"
    filenameSeries=${filename##*_S}; filenameSeries=${filenameSeries%%_*}; 
    filenameImage=${filename##*_I}; filenameImage=${filenameImage%.dcm}; 
    filenameBase=$(basename ${filename%%_202*}); 
    filenameDate=${filename##*_2020}; filenameDate=2020${filenameDate%%_*}; filenameDate=${filenameDate:0:8}; 
    entry="${filenameSeries},${filenameImage},${filenameDate},${filenameBase}"

    dcmdump ${filename} > ${tmp}/dcmdump.txt
    for field in ${dicomFields}; do
      entry="${entry},$(dicomQuery ${tmp}/dcmdump.txt ${field})" 
    done
    rm ${tmp}/dcmdump.txt

    echo ${entry} >> ${tmp}/tmp.csv
  done

  echo ".. compiling index"
  cat ${tmp}/tmp.csv | sort | uniq -c | tr -s ' ' | sed -e 's/^ //g' -e 's/ /,/g' >> ${tmp}/images.csv
  rm ${tmp}/tmp.csv

  echo "path: $(cd ${tmp} && cd .. && pwd)" >> ${tmp}/log.txt
  echo "site: ${site}" >> ${tmp}/log.txt
  echo "today: $(date)" >> ${tmp}/log.txt
  echo "version: $(qit --version)" >> ${tmp}/log.txt
  echo "today: $(date)" >> ${tmp}/log.txt

  mv ${tmp} ${output}
else
  echo "output already exists, skipping conversion" 
fi

echo "finished"

################################################################################
# END
################################################################################
