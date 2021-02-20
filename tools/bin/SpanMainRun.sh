#! /usr/bin/env bash 
##############################################################################
#
#  SPAN Rodent MRI Analytics 
#

usage()
{
    echo "
Name: $(basename $0)

Description:

  The SPAN Rodent MRI Analysis.  This program performs lesion segment and 
  quantification.  The input should be a dicom directory.
    
Usage: 

  $(basename $0) [input_dicom_dir] subject_dir

Author: Ryan Cabeen
"

exit 1
}

function check
{
  if [ ! -e $1 ]; then 
    "[error] required input not found: $1"
    exit 1
  fi
}

function runit
{
  echo "    running: $@"
  $@
  if [ $? != 0 ]; then 
    echo "[error] command failed: $@"
    exit; 
  fi
}

workflow="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
name=$(basename $0)

input=""
posit=""

while [ "$1" != "" ]; do
    case $1 in
        --input)                   shift; input=$1 ;;
        --help )                   usage ;;
        * )                        posit="${posit} $1" ;;
    esac
    shift
done

if [ $(echo ${posit} | wc -w)  -ne 1 ]; then usage; fi

subject=${posit}

##############################################################################
# Processing 
##############################################################################

echo "started ${name}"

if [ ""${input} != "" ]; then
  if [ ! -e ${subject}/native.dicom ]; then
    echo "  using dicom: ${input}"
    mkdir -p ${subject}
	  tmp=${subject}/native.dicom.tmp.${RANDOM}
    cp -r ${input} ${tmp}
    chmod -R u+w ${tmp}
	  runit bash ${workflow}/SpanAuxDicomFix.sh ${tmp}
    mv ${tmp} ${subject}/native.dicom
  fi
fi

cd ${subject}
echo "  using subject: ${PWD}"
check native.dicom

if [ -e native.dicom ] && [ ! -e native.convert ]; then

  tmp=native.convert.tmp.${RANDOM}
  runit bash ${workflow}/SpanAuxConvert.sh native.dicom ${tmp}
  mv ${tmp} native.convert

fi

if [ -e native.convert ] && [ ! -e native.import ]; then

  tmp=native.import.tmp.${RANDOM}
  runit bash ${workflow}/SpanAuxImport.sh native.convert ${tmp}
  mv ${tmp} native.import

fi

if [ ! -e native.denoise ]; then

  tmp=native.denoise.tmp.${RANDOM}
  mkdir -p ${tmp}

  for p in adc t2 rare; do
    runit bash ${workflow}/SpanAuxDenoise.sh \
			 native.import/${p}.nii.gz  ${tmp}/${p}.nii.gz
  done

  runit cp native.import/t2.txt ${tmp}
  runit cp native.import/adc.txt ${tmp}

  mv ${tmp} native.denoise

fi

if [ ! -e native.fit ]; then

  tmp=native.fit.tmp.${RANDOM}
  mkdir -p ${tmp}

  for m in adc t2; do
		runit qit --verbose VolumeExpDecayFit \
			--input       native.denoise/${m}.nii.gz \
			--varying     native.denoise/${m}.txt \
			--outputAlpha ${tmp}/${m}_base.nii.gz \
			--outputBeta  ${tmp}/${m}_rate.nii.gz \
			--outputError ${tmp}/${m}_rmse.nii.gz \
			--outputSnr   ${tmp}/${m}_snr.nii.gz
		runit qit --verbose VolumeReduce \
      --method Mean \
			--input  native.denoise/${m}.nii.gz \
			--output ${tmp}/${m}_mean.nii.gz
		for p in mean; do
			runit N4BiasFieldCorrection \
				-i ${tmp}/${m}_${p}.nii.gz \
				-w ${tmp}/${m}_${p}.nii.gz \
				-o ${tmp}/${m}_${p}.nii.gz
		done
		runit qit --verbose VolumeSegmentForeground \
			--input  native.denoise/${m}.nii.gz \
			--output ${tmp}/${m}_mask.nii.gz \
			--report ${tmp}/${m}_report.csv
  done

	cp native.denoise/rare.nii.gz ${tmp}/rare.nii.gz
  mv ${tmp} native.fit

fi

if [ ! -e native.mask/brain.mask.nii.gz ]; then

  tmp=native.mask.tmp.${RANDOM}
  mkdir -p ${tmp}

  runit bash ${workflow}/SpanAuxSegmentBrainLearn.sh \
    native.fit ${tmp}/brain.mask.nii.gz

  mv ${tmp} native.mask

fi

if [ ! -e native.harm ]; then

  tmp=native.harm.tmp.${RANDOM}
  mkdir -p ${tmp}

  for p in {adc,t2}_{base,rate} rare; do
    runit qit --verbose VolumeHarmonize \
      --input native.fit/${p}.nii.gz \
      --inputStatMask native.mask/brain.mask.nii.gz \
      --output ${tmp}/${p}.nii.gz
  done

  mv ${tmp} native.harm

fi

if [ ! -e native.seg ]; then

  runit bash ${workflow}/SpanAuxSegmentLesion.sh \
     --input native.harm \
     --mask native.mask/brain.mask.nii.gz \
     --output native.seg

fi

if [ ! -e native.midline ]; then

	runit bash ${workflow}/SpanAuxMidlineShift.sh \
    native.harm/t2_rate.nii.gz \
    native.mask/brain.mask.nii.gz \
    native.seg/csf.mask.nii.gz \
    native.midline

fi

if [ ! -e native.map ]; then
  tmp=native.map.tmp.${RANDOM}
  mkdir -p ${tmp}

  cp native.midline/map.csv ${tmp}/midline.csv

  for f in adc t2; do
    cp native.fit/${f}_report.csv ${tmp}/${f}_qa.csv
  done

  runit qit --verbose MaskRegionsMeasure \
    --regions native.seg/rois.nii.gz \
    --lookup native.seg/rois.csv \
    --volume adc_rate=native.fit/adc_rate.nii.gz \
             t2_rate=native.fit/t2_rate.nii.gz \
             adc_base=native.fit/adc_base.nii.gz \
             t2_base=native.fit/t2_base.nii.gz \
             adc_rate_harm=native.harm/adc_rate.nii.gz \
             t2_rate_harm=native.harm/t2_rate.nii.gz \
             adc_base_harm=native.harm/adc_base.nii.gz \
             t2_base_harm=native.harm/t2_base.nii.gz \
    --mask native.mask/brain.mask.nii.gz \
    --output ${tmp}

  runit qit --verbose MaskMeasure \
    --input native.seg/rois.nii.gz \
    --lookup native.seg/rois.csv \
    --output ${tmp}/volume.csv

  mv ${tmp} native.map
fi

function visit 
{
  runit qit --verbose VolumeRender \
    --bghigh 3.0 \
    --alpha 1.0 \
    --discrete pastel \
    --background ${1} \
    --labels ${4}/${3}.nii.gz \
    --output ${4}/${2}_${3}.nii.gz

  runit qit --verbose VolumeMosaic \
    --crop :,start:2:end,: \
    --rgb --axis j \
    --input ${4}/${2}_${3}.nii.gz \
    --output ${4}/${2}_${3}.png
  rm ${4}/${2}_${3}.nii.gz
}

if [ ! -e native.vis ]; then

  tmp=native.vis.tmp.${RANDOM}
  mkdir -p ${tmp}

  runit qit --verbose MaskShell \
    --mode Multi \
    --input native.seg/rois.nii.gz \
    --output ${tmp}/rois.nii.gz

  runit qit --verbose MaskShell \
    --input native.seg/lesion.mask.nii.gz \
    --output ${tmp}/lesion.nii.gz

  runit qit --verbose MaskShell \
    --input native.seg/csf.mask.nii.gz \
    --output ${tmp}/csf.nii.gz

  runit qit --verbose MaskShell \
    --input native.mask/brain.mask.nii.gz \
    --output ${tmp}/brain.nii.gz

  runit qit --verbose MaskSet --clear \
    --input ${tmp}/brain.nii.gz \
    --output ${tmp}/anatomy.nii.gz

  for labels in anatomy brain lesion csf rois; do 
    for param in rare {adc,t2}_{rate,base}; do
      visit native.harm/${param}.nii.gz ${param} ${labels} ${tmp}
    done
  done

  rm ${tmp}/*.nii.gz
  mv ${tmp} native.vis

fi

echo "finished"

################################################################################
# END
################################################################################
