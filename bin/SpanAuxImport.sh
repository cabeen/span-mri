#! /usr/bin/env bash
##############################################################################
#
#  SPAN Rodent MRI Analytics — Image Import and Organization
#
#  Purpose:
#    Organizes converted NIfTI images into a standardized format for the
#    pipeline. Identifies ADC, T2, and RARE modalities by filename patterns,
#    fuses multi-file acquisitions, applies site-specific image orientation
#    (from params/<site>/orient.json), and resamples to a common geometry.
#
#  Inputs:
#    $1 — Input directory (native.convert, containing nifti/ and site.txt)
#    $2 — Output directory
#
#  Outputs:
#    rare.nii.gz  — T2-weighted anatomical image (if available)
#    adc.nii.gz   — Multi-echo ADC volume (sorted by b-value, reversed)
#    t2.nii.gz    — Multi-echo T2 volume (parsed from echo times)
#    adc.txt      — ADC echo/b-value parameters
#    t2.txt       — T2 echo time parameters
#    site.txt     — Site identifier
#    sid.txt      — Subject ID
#    timepoint.txt — Timepoint (early/late)
#    date.txt     — Acquisition date
#
#  Dependencies: QIT
#
#  Pipeline context: Called by SpanMainRun.sh as stage 3 (native.import)
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

  Organize converted NIfTI images into a standardized format. Identifies
  ADC, T2, and RARE modalities, applies site-specific orientation, and
  resamples to a common geometry.

Usage:

  ${name} <input_dir> <output_dir>

Inputs:

  input_dir   — native.convert directory (containing nifti/ and site.txt)
  output_dir  — Output directory for organized modalities

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

rare="$(find ${nifti} \( -path '*RARE*.nii.gz' -or -path '*T2_anatomy*.nii.gz' \) -print -quit)"
if [ ! -e ${output}/rare.nii.gz ] && [ -e ${rare} ] && [ "${rare}" != "" ]; then
  echo "  using rare:"
  echo "${rare}"
	echo "  organizing rare"

  runit cp ${rare} ${output}/rare.nii.gz

  if [ ! ${ref} ]; then 
     runit qit --load ${workflow}/params/Common/resample.json \
       --input ${output}/rare.nii.gz --output ${output}/rare.nii.gz
     ref=${output}/rare.nii.gz
  fi
fi

adc="$(find ${nifti} \( -path '*ADC*.nii.gz' -or -path '*Diffusion*.nii.gz' -or -path '*DtiStandard*.nii.gz' -or -path '*DWI*.nii.gz' \) -print -quit)"
if [ ! -e ${output}/adc.nii.gz ] && [ -e ${adc} ]; then
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

t2map="$(find ${nifti} \( -path '*T2_SurfaceCoil*.nii.gz' -or -path '*T2_map*.nii.gz' -or -path '*T2map*.nii.gz' -or -path '*T2MAP*.nii.gz' \) -print -quit)"
if [ ! -e ${output}/t2.nii.gz ] && [ -e ${at2map} ]; then
  t2map="$(find ${nifti} \( -path '*T2_SurfaceCoil*.nii.gz' -or -path '*T2_map*.nii.gz' -or -path '*T2map*.nii.gz' -or -path '*T2MAP*.nii.gz' \))"
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

for f in ${output}/*.nii.gz; do
  echo "  orienting ${f}"
	runit qit --load ${params}/orient.json --input ${f} --output ${f}
done

echo "finished"

################################################################################
# END
################################################################################
