#! /usr/bin/env bash
##############################################################################
#
#  SPAN Rodent MRI Analytics — Result Export
#
#  Purpose:
#    Exports processed SPAN results from all subjects into a flat directory
#    structure for external use. Copies brain masks, lesion masks, fused
#    parameter maps, and visualization mosaics with standardized naming.
#
#  Inputs:
#    --input <dir>   Root project directory (containing process/)
#    --output <dir>  Export output directory
#    --grid          Optional: use qsubcmd for grid/cluster job submission
#
#  Outputs:
#    images/         — Fused 4-channel parameter maps per subject
#    labels/brain/   — Brain masks per subject
#    labels/lesion/  — Lesion masks per subject
#    mosaics/brain/  — Brain overlay PNGs per subject
#    mosaics/lesion/ — Lesion overlay PNGs per subject
#    names.txt       — List of exported subject UIDs
#
#  Dependencies: QIT
#
#  Author: Ryan Cabeen
#
##############################################################################

usage()
{
    echo "
Name: $(basename $0)

Description:

  Export processed SPAN results into a flat directory structure for
  external use. Copies brain masks, lesion masks, fused parameter maps,
  and visualization mosaics with standardized naming.

Usage:

  $(basename $0) --input <dir> --output <dir> [--grid]

Options:

  --input <dir>   Root project directory (containing process/)
  --output <dir>  Export output directory
  --grid          Use qsubcmd for grid/cluster job submission

Author: Ryan Cabeen
"
    exit 1
}

function runit
{
  echo "    running: $@"
  $@
  if [ $? != 0 ]; then 
    echo "[error] command failed: $@"; exit 
  fi
}

input=""
output=""
rungrid=""
posit=""

while [ "$1" != "" ]; do
    case $1 in
        --input)                   shift; input=$1;;
        --output)                  shift; output=$1;;
        --grid)                    rungrid=qsubcmd ;;
        --help|-h)                 usage ;;
        * )                        posit="${posit} $1" ;;
    esac; shift
done

echo ${posit}

if [ $(echo ${posit} | wc -w) -ne 0 ]; then usage; fi
if [ "${output}" == "" ]; then echo "Error: output is required"; exit 1; fi
if [ ! -e ${input} ]; then echo "Error: input file not found: ${input}"; exit 1; fi
if [ ! -e ${input}/process ]; then echo "Error: input is invalid: ${input}"; exit 1; fi

echo "started"

echo "using input: ${input}"
echo "using output: ${output}"

mkdir -p ${output}

for subject in ${input}/process/*/*; do

  if [ ! -e ${subject}/standard.vis ]; then continue; fi

		site=$(cat ${subject}/native.import/site.txt)
		sid=$(cat ${subject}/native.import/sid.txt)
		timepoint=$(cat ${subject}/native.import/timepoint.txt)
		date=$(cat ${subject}/native.import/date.txt)

		uid=${site}_${sid}_${timepoint}_${date}

		echo "... processing ${uid}"
		mkdir -p ${output}/{images,labels,mosaics}
		mkdir -p ${output}/{labels,mosaics}/{brain,lesion}
		echo ${uid} >> ${output}/names.txt

		runit ${rungrid} qit VolumeFuse \
			--input ${subject}/native.fit/{t2,adc}_{base,rate}.nii.gz \
			--output-cat ${output}/images/${uid}.nii.gz

		runit cp ${subject}/native.mask/brain.mask.nii.gz \
			${output}/labels/brain/${uid}.nii.gz

		runit cp ${subject}/native.seg/lesion.mask.nii.gz \
			${output}/labels/lesion/${uid}.nii.gz

		runit cp ${subject}/native.vis/t2_rate_lesion.png \
			${output}/mosaics/lesion/${uid}.png

		runit cp ${subject}/native.vis/t2_rate_brain.png \
			${output}/mosaics/brain/${uid}.png

	done

echo "finished"

##############################################################################
