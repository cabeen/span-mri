#! /usr/bin/env bash 
##############################################################################
#
#  SPAN Rodent MRI Analytics 
#
#    A script for importing images in a standard format.
#
#  Author: Ryan Cabeen
#
##############################################################################

workflow=$(cd $(dirname ${0}); cd ..; pwd -P)

name=$(basename $0)

if [ $# -ne "2" ]; then
    echo "Usage: ${name} <input_dir> <output_dir>"
    exit 1
fi

input=${1}
output=${2}

function runit 
{
  echo "    running: $@"
  $@
  if [ $? != 0 ]; then 
    echo "error encountered, please check the log"; 
    exit 1; 
  fi
}

echo "started ${name}"
echo "  using input: ${input}"
echo "  using output: ${output}"

site=$(cat ${input}/site.txt)
nifti=${input}/nifti
params=${workflow}/params/${site}
ref=""

mkdir -p ${output}

cp ${params}/site.txt ${output}/site.txt
echo $(basename $(cd ${input} && cd .. && pwd)) > ${output}/sid.txt
cp ${workflow}/params/Common/$(basename $(cd ${input} && cd ../.. && pwd)).txt ${output}/timepoint.txt

cat ${input}/images.csv | awk -vcol=DicomAcquisitionDate 'BEGIN{FS=","}(NR==1){colnum=-1;for(i=1;i<=NF;i++)if($(i)==col)colnum=i;}{print $(colnum)}' | tail -n 1 > ${output}/date.txt

mgelow=""
mgehigh=""
mgeFirst="$(find ${nifti} \( -path '*MGE_2echo_15_timePoints_*_e1.nii.gz' \) -print -quit)"
mgeSecond="$(find ${nifti} \( -path '*MGE_2echo_15_timePoints_*_e1a.nii.gz' \) -print -quit)"

if [ -e ${mgeFirst} ] && [ -e ${mgeSecond} ]; then
  echo found MGE scans
  mgeFirstMeta="$(find ${nifti} \( -path '*MGE_2echo_15_timePoints_*_e1.json' \) -print -quit)"
  mgeSecondMeta="$(find ${nifti} \( -path '*MGE_2echo_15_timePoints_*_e1a.json' \) -print -quit)"

  teFirst=$(grep EchoTime ${mgeFirstMeta} | sed 's/.*: //g' | sed 's/,//g')
  teSecond=$(grep EchoTime ${mgeSecondMeta} | sed 's/.*: //g' | sed 's/,//g')
  if [ ${teFirst} == "0.002" ] && [ ${teSecond} == "0.007" ]; then 
    mgelow=${mgeFirst}
    mgehigh=${mgeSecond}
  else
    mgehigh=${mgeFirst}
    mgelow=${mgeSecond}
  fi 
fi

if [ ! -e ${output}/mgelow.nii.gz ] && [ -e ${mgelow} ] && [ "${mgelow}" != "" ]; then
  echo "  using mgelow:"
  echo "${mgelow}"
	echo "  organizing mgelow"

  runit cp ${mgelow} ${output}/mgelow.nii.gz

  if [ ! ${ref} ]; then 
     runit qit --load ${workflow}/params/Common/resample.json \
       --input ${output}/mgelow.nii.gz --output ${output}/mgelow.nii.gz
     ref=${output}/mgelow.nii.gz
  else
     echo "    using ref: ${ref}"
     runit qit --load ${workflow}/params/Common/transform.json \
       --reference ${ref} --input ${output}/mgelow.nii.gz --output ${output}/mgelow.nii.gz
  fi
  
  runit cp $(echo ${mgelow} | sed 's/nii.gz/json/g') ${output}/mgelow.json
else
  echo "no mgelow found!"
fi

if [ ! -e ${output}/mgehigh.nii.gz ] && [ -e ${mgehigh} ] && [ "${mgehigh}" != "" ]; then
  echo "  using mgehigh:"
  echo "${mgehigh}"
	echo "  organizing mgehigh"

  runit cp ${mgehigh} ${output}/mgehigh.nii.gz

  if [ ! ${ref} ]; then 
     runit qit --load ${workflow}/params/Common/resample.json \
       --input ${output}/mgehigh.nii.gz --output ${output}/mgehigh.nii.gz
     ref=${output}/mgehigh.nii.gz
  else
     echo "    using ref: ${ref}"
     runit qit --load ${workflow}/params/Common/transform.json \
       --reference ${ref} --input ${output}/mgehigh.nii.gz --output ${output}/mgehigh.nii.gz
  fi

  runit cp $(echo ${mgehigh} | sed 's/nii.gz/json/g') ${output}/mgehigh.json
else
  echo "no mgehigh found!"
fi

t1rare="$(find ${nifti} \( -path '*T1map_RARE*.nii.gz' \) -print -quit)"
if [ ! -e ${output}/t1rare.nii.gz ] && [ -e ${t1rare} ] && [ "${t1rare}" != "" ]; then
  echo "  using t1rare:"
  echo "${t1rare}"
	echo "  organizing t1rare"

  runit cp ${t1rare} ${output}/t1rare.nii.gz

  if [ ! ${ref} ]; then 
     runit qit --load ${workflow}/params/Common/resample.json \
       --input ${output}/t1rare.nii.gz --output ${output}/t1rare.nii.gz
     ref=${output}/t1rare.nii.gz
  else
     echo "    using ref: ${ref}"
     runit qit --load ${workflow}/params/Common/transform.json \
       --reference ${ref} --input ${output}/t1rare.nii.gz --output ${output}/t1rare.nii.gz
  fi
fi

adc="$(find ${nifti} \( -path '*ADC*.nii.gz' -or -path '*Diffusion*.nii.gz' -or -path '*DtiStandard*.nii.gz' \) -print -quit)"
if [ ! -e ${output}/adc.nii.gz ] && [ -e "${adc}" ]; then
  adc="$(find ${nifti} \( -path '*ADC*.nii.gz' -or -path '*Diffusion*.nii.gz' -or -path '*DtiStandard*.nii.gz' \) )"
  echo "  using adc:"
  echo "${adc}"
	echo "  organizing adc"
  runit qit VolumeFuse --exmulti \
    --input ${adc} --output-cat ${output}/adc.nii.gz
  runit qit VolumeSortChannels --reverse \
    --input ${output}/adc.nii.gz --output ${output}/adc.nii.gz
  runit cp ${workflow}/params/Common/adc.txt ${output}/adc.txt

  if [ ! ${ref} ]; then 
     runit qit --load ${workflow}/params/Common/resample.json \
       --input ${output}/adc.nii.gz --output ${output}/adc.nii.gz
     ref=${output}/adc.nii.gz
  else
     echo "    using ref: ${ref}"
     runit qit --load ${workflow}/params/Common/transform.json \
       --reference ${ref} --input ${output}/adc.nii.gz --output ${output}/adc.nii.gz
  fi
fi

t2map="$(find ${nifti} \( -path '*T2_map*.nii.gz' \) -print -quit)"
if [ ! -e ${output}/t2.nii.gz ] && [ -e "${at2map}" ]; then
  t2map="$(find ${nifti} \( -path '*T2_map*.nii.gz' \))"
	echo "  using t2maps:"
	echo "${t2map}"
	echo "  organizing t2"
  runit qit VolumeParseEchoes \
    --input ${t2map} --output-volume ${output}/t2.nii.gz --output-echoes ${output}/t2.txt

  if [ ! ${ref} ]; then 
     runit qit --load ${workflow}/params/Common/resample.json \
       --input ${output}/t2.nii.gz --output ${output}/t2.nii.gz
     ref=${output}/t2.nii.gz
  else
     echo "    using ref: ${ref}"
     runit qit --load ${workflow}/params/Common/transform.json \
       --reference ${ref} --input ${output}/t2.nii.gz --output ${output}/t2.nii.gz
  fi
fi

t2star="$(find ${nifti} \( -path '*T2star_map*.nii.gz' \) -print -quit)"
if [ ! -e ${output}/t2star.nii.gz ] && [ -e "${t2star}" ]; then
  t2star="$(find ${nifti} \( -path '*T2star_map*.nii.gz' \))"
	echo "  using t2star:"
	echo "${t2star}"
	echo "  organizing t2star"
  runit qit VolumeParseEchoes \
    --input ${t2star} --output-volume ${output}/t2star.nii.gz --output-echoes ${output}/t2star.txt

  if [ ! ${ref} ]; then 
     runit qit --load ${workflow}/params/Common/resample.json \
       --input ${output}/t2star.nii.gz --output ${output}/t2star.nii.gz
     ref=${output}/t2star.nii.gz
  else
     echo "    using ref: ${ref}"
     runit qit --load ${workflow}/params/Common/transform.json \
       --reference ${ref} --input ${output}/t2star.nii.gz --output ${output}/t2star.nii.gz
  fi
fi

for f in ${output}/*.nii.gz; do
  echo "  orienting ${f}"
	runit qit --load ${params}/orient.json --input ${f} --output ${f}
done

echo "finished"

################################################################################
# END
################################################################################
