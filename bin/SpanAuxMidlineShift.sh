#! /usr/bin/env bash
##############################################################################
#
#  SPAN Rodent MRI Analytics — Midline Shift (Legacy Bash Version)
#
#  Purpose:
#    Legacy bash implementation of midline shift computation. Computes shift
#    in mm and as a percentage of brain width using hardcoded atlas landmark
#    coordinates. The Python version (SpanAuxMidline.py) is the preferred
#    implementation as it computes additional metrics and hemisphere volumes.
#
#  Algorithm:
#    1. Find the centroid of the largest CSF component within the midline mask
#    2. Create landmark points at the centroid, anatomical center, and brain edges
#    3. Compute pairwise distances between landmarks
#    4. Shift_mm = distance from centroid to anatomical center
#    5. Shift_percent = 200 * shift_mm / brain_width
#
#  Inputs:
#    $1 — Brain mask in standard atlas space
#    $2 — CSF mask
#    $3 — Middle (midline) mask from atlas
#    $4 — Output directory
#
#  Outputs:
#    map.csv — Contains shift_mm and shift_percent (or NA if no CSF found)
#
#  Dependencies: QIT, Python 3 (for arithmetic)
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

  Legacy midline shift computation. Computes shift in mm and as a percentage
  of brain width using hardcoded atlas landmarks. The Python version
  (SpanAuxMidline.py) is preferred as it computes additional metrics.

Usage:

  ${name} <brain-mask> <csf-mask> <middle-mask> <output>

Inputs:

  brain-mask    — Brain mask in standard atlas space
  csf-mask      — CSF mask
  middle-mask   — Midline mask from atlas
  output        — Output directory (will contain map.csv)

Author: Ryan Cabeen
"
    exit 1
}

if [ "${1:-}" == "--help" ] || [ "${1:-}" == "-h" ]; then usage; fi
if [ $# -ne "4" ]; then usage; fi

function runit
{
  echo "    running: $@"
  $@
  if [ $? != 0 ]; then 
    echo "[error] command failed: $@"
    exit 1
  fi
}

echo "started"

brain=$1
csf=$2
middle=$3
output=$4

if [ ! -e ${brain} ]; then echo "Error: brain mask not found: ${brain}"; exit; fi
if [ ! -e ${csf} ]; then echo "Error: csf mask not found: ${csf}"; exit; fi
if [ ! -e ${middle} ]; then echo "Error: middle mask not found: ${middle}"; exit; fi

tmp=${output}.tmp.${RANDOM}
mkdir -p ${tmp}
mkdir -p ${tmp}/seg

echo "using brain: ${brain}"
echo "using csf: ${csf}"
echo "using middle: ${middle}"
echo "using output: ${output}"
echo "using intermediate: ${tmp}"

runit qit --verbose MaskCentroids \
  --input ${csf} \
  --mask ${middle} \
  --largest \
  --output ${tmp}/centroid.txt

if [ $(wc -l ${tmp}/centroid.txt | awk '{print $1}') == "0" ]; then 

  echo name,value > ${tmp}/map.csv
	echo shift_mm,NA >> ${tmp}/map.csv
	echo shift_percent,NA >> ${tmp}/map.csv

  touch ${tmp}/tag_none

else

	x=$(cat ${tmp}/centroid.txt | awk '{print $1}')
	y=$(cat ${tmp}/centroid.txt | awk '{print $2}')
	z=$(cat ${tmp}/centroid.txt | awk '{print $3}')

	mxc=7.42662
	mxl=2.49401
	mxr=12.3626
	mzc=8.10
	mzs=11.0
	mzi=5.2

	echo ${x} ${y} ${mzc}    > ${tmp}/landmarks.txt
	echo ${mxc} ${y} ${mzc} >> ${tmp}/landmarks.txt
	echo ${mxl} ${y} ${mzc} >> ${tmp}/landmarks.txt
	echo ${mxr} ${y} ${mzc} >> ${tmp}/landmarks.txt
	echo ${mxc} ${y} ${mzs} >> ${tmp}/landmarks.txt
	echo ${mxc} ${y} ${mzi} >> ${tmp}/landmarks.txt

	runit qit --verbose VectsDistances \
		--input ${tmp}/landmarks.txt \
		--output ${tmp}/distances.txt

	dc=$(cat ${tmp}/distances.txt | awk 'NR == 1 {print $2}')
	ds=$(cat ${tmp}/distances.txt | awk 'NR == 3 {print $4}')
	dr=$(python -c "print(200.0 * ${dc} / ${ds})")

	echo name,value > ${tmp}/map.csv
	echo shift_mm,${dc} >> ${tmp}/map.csv
	echo shift_percent,${dr} >> ${tmp}/map.csv

fi

if [ -e ${output} ]; then
  bck=${output}.bck.${RANDOM}
  echo "moving previous results to ${bck}"
  mv ${output} ${bck}
fi

echo cleaning up
mv ${tmp} ${output}

echo "finished"

##############################################################################
