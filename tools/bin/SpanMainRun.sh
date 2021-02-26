#! /usr/bin/env bash 
##############################################################################
#
#  SPAN Rodent MRI Analytics 
#
##############################################################################

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

data="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../data && pwd)"
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

if [ ! -e native.reg ]; then

  tmp=native.reg.tmp.${RANDOM}
  mkdir -p ${tmp}

	echo "extracting registration target"
	runit qit --verbose VolumeMask \
		--input native.harm/t2_rate.nii.gz \
		--mask native.mask/brain.mask.nii.gz \
		--output ${tmp}/native.nii.gz

	echo "performing registration"
	runit qit --verbose VolumeRegisterLinearAnts \
		--rigid \
		--input ${tmp}/native.nii.gz \
		--ref ${data}/brain.nii.gz \
		--output ${tmp}/work

	mv ${tmp}/work/* ${tmp}
	rm -rf ${tmp}/work

  mv ${tmp} native.reg

fi

for p in fit harm; do

	if [ ! -e standard.${p} ]; then

		tmp=standard.${p}.tmp.${RANDOM}
		mkdir -p ${tmp}

		for m in {t2,adc}_{base,rate} rare; do

			runit qit --verbose VolumeTransform \
				--input native.${p}/${m}.nii.gz \
				--affine native.reg/xfm.txt \
				--reference ${data}/brain.nii.gz \
				--output ${tmp}/${m}.nii.gz 

		done

		mv ${tmp} standard.${p}

	fi
done

if [ ! -e standard.mask ]; then

  tmp=standard.mask.tmp.${RANDOM}
  mkdir -p ${tmp}

	runit qit --verbose MaskTransform \
		--input native.mask/brain.mask.nii.gz \
		--affine native.reg/xfm.txt \
		--reference ${data}/brain.nii.gz \
		--output ${tmp}/raw.mask.nii.gz

	runit qit --verbose MaskFilterMode \
		--input ${tmp}/raw.mask.nii.gz \
		--output ${tmp}/brain.mask.nii.gz

  mv ${tmp} standard.mask

fi

if [ ! -e standard.seg ]; then

  runit bash ${workflow}/SpanAuxSegmentLesion.sh \
     --input standard.harm \
     --mask standard.mask/brain.mask.nii.gz \
     --output standard.seg

fi

if [ ! -e standard.midline ]; then

	runit qit --verbose ${workflow}/SpanAuxMidline.py \
    standard.mask/brain.mask.nii.gz \
    standard.seg/csf.mask.nii.gz \
    standard.midline

fi

if [ ! -e standard.map ]; then
  tmp=standard.map.tmp.${RANDOM}
  mkdir -p ${tmp}

  for f in adc t2; do
    cp native.fit/${f}_report.csv ${tmp}/${f}_qa.csv
  done

  cp standard.midline/map.csv ${tmp}/midline.csv

  runit qit --verbose MaskRegionsMeasure \
    --regions standard.seg/rois.nii.gz \
    --lookup standard.seg/rois.csv \
    --volume adc_rate=standard.fit/adc_rate.nii.gz \
             t2_rate=standard.fit/t2_rate.nii.gz \
             adc_base=standard.fit/adc_base.nii.gz \
             t2_base=standard.fit/t2_base.nii.gz \
             adc_rate_harm=standard.harm/adc_rate.nii.gz \
             t2_rate_harm=standard.harm/t2_rate.nii.gz \
             adc_base_harm=standard.harm/adc_base.nii.gz \
             t2_base_harm=standard.harm/t2_base.nii.gz \
    --mask standard.mask/brain.mask.nii.gz \
    --output ${tmp}

  runit qit --verbose MaskMeasure \
    --input standard.seg/rois.nii.gz \
    --lookup standard.seg/rois.csv \
    --output ${tmp}/volume.csv

  mv ${tmp} standard.map
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

if [ ! -e standard.vis ]; then

  tmp=standard.vis.tmp.${RANDOM}
  mkdir -p ${tmp}

  runit qit --verbose MaskShell \
    --mode Multi \
    --input standard.seg/rois.nii.gz \
    --output ${tmp}/rois.nii.gz

  runit qit --verbose MaskShell \
    --input standard.seg/lesion.mask.nii.gz \
    --output ${tmp}/lesion.nii.gz

  runit qit --verbose MaskShell \
    --input standard.seg/csf.mask.nii.gz \
    --output ${tmp}/csf.nii.gz

  runit qit --verbose MaskShell \
    --input standard.mask/brain.mask.nii.gz \
    --output ${tmp}/brain.nii.gz

  runit qit --verbose MaskSet --clear \
    --input ${tmp}/brain.nii.gz \
    --output ${tmp}/anatomy.nii.gz

  for labels in anatomy brain lesion csf rois; do 
    for param in rare {adc,t2}_{rate,base}; do
      visit standard.harm/${param}.nii.gz ${param} ${labels} ${tmp}
    done
  done

  rm ${tmp}/*.nii.gz
  mv ${tmp} standard.vis

fi

echo "finished"

################################################################################
# END
################################################################################
