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

if [ $# -ne "3" ]; then
    echo "Usage: $(basename $0) <brain-mask> <csf-mask> <output>"
    exit 1
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"

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
output=$3

if [ ! -e ${brain} ]; then echo "Error: brain mask not found: ${brain}"; exit; fi
if [ ! -e ${csf} ]; then echo "Error: csf mask not found: ${csf}"; exit; fi

tmp=${output}.tmp.${RANDOM}
mkdir -p ${tmp}
mkdir -p ${tmp}/seg

echo "using brain: ${brain}"
echo "using csf: ${csf}"
echo "using output: ${output}"
echo "using intermediate: ${tmp}"

runit qit --verbose MaskCentroids \
  --input ${csf} \
  --mask ${root}/data/middle.mask.nii.gz \
  --largest \
  --output ${tmp}/seg/centroid.txt

if [ $(wc -l ${tmp}/seg/centroid.txt | awk '{print $1}') == "0" ]; then 

  echo name,value > ${tmp}/map.csv
	echo shift_mm,NA >> ${tmp}/map.csv
	echo shift_percent,NA >> ${tmp}/map.csv

  touch ${tmp}/tag_none

else

	x=$(cat ${tmp}/seg/centroid.txt | awk '{print $1}')
	y=$(cat ${tmp}/seg/centroid.txt | awk '{print $2}')
	z=$(cat ${tmp}/seg/centroid.txt | awk '{print $3}')

	mxc=7.42662
	mxl=2.49401
	mxr=12.3626
	mzc=8.10
	mzs=11.0
	mzi=5.2

	echo ${x} ${y} ${mzc}    > ${tmp}/seg/atlas.landmarks.txt
	echo ${mxc} ${y} ${mzc} >> ${tmp}/seg/atlas.landmarks.txt
	echo ${mxl} ${y} ${mzc} >> ${tmp}/seg/atlas.landmarks.txt
	echo ${mxr} ${y} ${mzc} >> ${tmp}/seg/atlas.landmarks.txt
	echo ${mxc} ${y} ${mzs} >> ${tmp}/seg/atlas.landmarks.txt
	echo ${mxc} ${y} ${mzi} >> ${tmp}/seg/atlas.landmarks.txt

	runit qit --verbose VectsDistances \
		--input ${tmp}/seg/atlas.landmarks.txt \
		--output ${tmp}/seg/atlas.distances.txt

	runit qit --verbose VectsTransform \
		--affine ${tmp}/reg/xfm.txt \
		--input ${tmp}/seg/atlas.landmarks.txt \
		--output ${tmp}/seg/native.landmarks.txt

	runit qit --verbose VectsDistances \
		--input ${tmp}/seg/native.landmarks.txt \
		--output ${tmp}/seg/native.distances.txt

	dc=$(cat ${tmp}/seg/native.distances.txt | awk 'NR == 1 {print $2}')
	ds=$(cat ${tmp}/seg/native.distances.txt | awk 'NR == 3 {print $4}')
	dr=$(python -c "print(200.0 * ${dc} / ${ds})")

	echo name,value > ${tmp}/map.csv
	echo shift_mm,${dc} >> ${tmp}/map.csv
	echo shift_percent,${dr} >> ${tmp}/map.csv

	cp ${tmp}/seg/native.landmarks.txt ${tmp}/landmarks.txt

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
