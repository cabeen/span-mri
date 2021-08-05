#! /usr/bin/env bash 
##############################################################################
#
#  SPAN Rodent MRI Analytics 
#
#    A script for computing midline shift
#
#  Author: Ryan Cabeen
#
##############################################################################

if [ $# -ne "4" ]; then
    echo "Usage: $(basename $0) <brain-mask> <csf-mask> <middle-mask> <output>"
    exit 1
fi

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
