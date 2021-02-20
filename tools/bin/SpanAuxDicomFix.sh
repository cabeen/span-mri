#! /usr/bin/env bash 
##############################################################################
#
#  SPAN Rodent MRI Analytics 
#
#    A script for fixing dicom headers to merge header values for 
#    ProtocolName and SeriesDescription. 
#
#  Author: Ryan Cabeen
#
##############################################################################

if [ $# -lt "1" ]; then
    echo "Usage: $(basename $0) <input> [optional_output]"
    exit 1
fi

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
