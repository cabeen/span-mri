#! /usr/bin/env bash
##############################################################################
#
#  SPAN Rodent MRI Analytics — DICOM Header Fix
#
#  Purpose:
#    Fixes DICOM headers by merging ProtocolName and SeriesDescription into
#    a single combined tag value. This ensures dcm2niix produces consistent,
#    informative filenames during conversion, regardless of how different
#    scanner vendors populate these fields. Works on individual files or
#    entire directories.
#
#  Inputs:
#    $1 — Input DICOM file or directory
#    $2 — Optional: output location (copies input before modifying)
#
#  Dependencies: dcmdump, dcmodify (DCMTK)
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

  Fix DICOM headers by merging ProtocolName and SeriesDescription into
  a combined tag value for consistent dcm2niix filenames.

Usage:

  ${name} <input> [output]

Inputs:

  input   — DICOM file or directory
  output  — Optional: output location (copies input before modifying)

Author: Ryan Cabeen
"
    exit 1
}

if [ "${1:-}" == "--help" ] || [ "${1:-}" == "-h" ]; then usage; fi
if [ $# -lt "1" ]; then usage; fi

function fixit
{
  file=$1
	protocol=$(dcmdump ${file} | grep ProtocolName | sed 's/.*\[//g' | sed 's/\].*//g' | tr -s -c '[:alnum:]._-' _)
	seriesdesc=$(dcmdump ${file} | grep SeriesDescription | sed 's/.*\[//g' | sed 's/\].*//g' | tr -s -c '[:alnum:]._-' _)
  combined=$(echo ${protocol}_${seriesdesc} | tr -s '_' | sed -e 's/_$//g' -e 's/^_//g')

	echo "  detected ProcotolName: ${protocol}"
	echo "  detected SeriesDescription: ${seriesdesc}"
	echo "  combined tag value: ${combined}"

	echo "  updating dicom"
	dcmodify --no-backup -i "(0018,1030)=${combined}" -i "(0008,103e)=${combined}" ${file} 
}

echo "started $(basename $0)"

if [[ -d $1 ]]; then
  echo "  detected dir mode"
  mydir=$1
	if [ $# -gt "1" ]; then
		cp -r ${mydir} $2
		mydir=$2
	fi

  for myfile in $(find ${mydir} -name "*dcm"); do
    echo " processing: ${myfile}"
    fixit ${myfile}
  done
else
  echo "  detected file mode"
  myfile=$1
	if [ $# -gt "1" ]; then
		cp ${myfile} $2
		myfile=$2
	fi

  fixit ${myfile}
fi

echo "finished"

##############################################################################
