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

  $(basename $0) [options} --case case_dir

Optional Parameters:

  --source <dicom_dir>: specify the input dicom directory (required first time)
  --species <mouse|rat>: specify the species of the case (default=auto)
  --correct <correct_dir>: specify the correction directory (advanced)

Author: Ryan Cabeen
"

exit 1
}

function check
{
  if [ ! -e $1 ]; then 
    "[error] required data not found: $1"
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
qitcmd="qit --verbose --debug"

species=""
source=""
correct=""
case=""
posit=""

while [ "$1" != "" ]; do
    case $1 in
        --source)                  shift; source=$1 ;;
        --correct)                 shift; correct=$1 ;;
        --case)                 shift; case=$1 ;;
        --species)                 shift; species=$1 ;;
        --help )                   usage ;;
        * )                        posit="${posit} $1" ;;
    esac
    shift
done

if [ $(echo ${posit} | wc -w) -ne 0 ]; then echo "unexpected positional arguments: ${posit}"; usage; fi
if [ ""${case} == "" ]; then echo "no case provided"; usage; fi

if [[ "${species}" == "" ]]; then
  abscase="$(cd "$(dirname ${case})" && pwd)/$(basename ${case})"
  echo "  detecting species from case path"
  if [[ "${case}" == *rat* ]]; then species="rat"; fi
  if [[ "${case}" == *mouse* ]]; then species="mouse"; fi
  if [[ "${species}" == "" ]]; then
    echo "  no species detected, defaulting to mouse"
    species="mouse"
  fi
fi

##############################################################################
# Processing 
##############################################################################

echo "started ${name}"

if [ ""${source} != "" ]; then
  if [ ! -e ${case}/native.dicom ]; then
    echo "  using source: ${source}"
    mkdir -p ${case}
	  tmp=${case}/native.dicom.tmp.${RANDOM}
    cp -r ${source} ${tmp}
    chmod -R u+w ${tmp}
	  runit bash ${workflow}/SpanAuxDicomFix.sh ${tmp}
    mv ${tmp} ${case}/native.dicom
  fi
fi

flips=""
for c in flipi flipj flipk; do
  if [ -e ${correct}/${c} ]; then
    flips="${flips} ${c}"
  fi
done

cd ${case}
echo "  using case: ${PWD}"
echo "  using species: ${species}"
check native.dicom

if [ -e native.dicom ] && [ ! -e native.convert ]; then

  tmp=native.convert.tmp.${RANDOM}
  runit bash ${workflow}/SpanAuxConvert.sh native.dicom ${tmp}
  mv ${tmp} native.convert

fi

if [ -e native.convert ] && [ ! -e native.import ]; then

  tmp=native.import.tmp.${RANDOM}
  runit bash ${workflow}/SpanAuxImport.sh native.convert ${tmp}

  for c in ${flips}; do
    for v in adc t2; do
      echo "  correcting ${v} with ${c}"
      runit mv ${tmp}/${v}.nii.gz ${tmp}/${v}.raw.nii.gz
      runit ${qitcmd} VolumeReorder \
        --${c} \
        --input ${tmp}/${v}.raw.nii.gz \
        --output ${tmp}/${v}.nii.gz
    done
  done
 
  mv ${tmp} native.import

fi

if [ ! -e native.denoise ]; then

  tmp=native.denoise.tmp.${RANDOM}
  mkdir -p ${tmp}

  for p in adc t2; do
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
		runit ${qitcmd} VolumeExpDecayFit \
			--input       native.denoise/${m}.nii.gz \
			--varying     native.denoise/${m}.txt \
			--outputAlpha ${tmp}/${m}_base.nii.gz \
			--outputBeta  ${tmp}/${m}_rate.nii.gz \
			--outputError ${tmp}/${m}_rmse.nii.gz \
			--outputSnr   ${tmp}/${m}_snr.nii.gz
		runit ${qitcmd} VolumeReduce \
      --method Mean \
			--input  native.denoise/${m}.nii.gz \
			--output ${tmp}/${m}_mean.nii.gz
		for p in mean; do
			runit N4BiasFieldCorrection \
				-i ${tmp}/${m}_${p}.nii.gz \
				-w ${tmp}/${m}_${p}.nii.gz \
				-o ${tmp}/${m}_${p}.nii.gz
		done
		runit ${qitcmd} VolumeSegmentForeground \
			--input  native.denoise/${m}.nii.gz \
			--output ${tmp}/${m}_mask.nii.gz \
			--report ${tmp}/${m}_report.csv
  done

  mv ${tmp} native.fit

fi

if [ ! -e native.mask/brain.mask.nii.gz ]; then

  tmp=native.mask.tmp.${RANDOM}
  mkdir -p ${tmp}

  # We only have a deep learning brain extractor for mice
  if [ ${species} == "mouse" ]; then
		runit bash ${workflow}/SpanAuxSegmentBrainLearn.sh \
			native.fit ${tmp}/brain.mask.nii.gz
  else
		runit bash ${workflow}/SpanAuxSegmentBrainRule.sh \
			native.fit ${tmp}/brain.mask.nii.gz
  fi

  mv ${tmp} native.mask

fi

if [ ! -e native.harm ]; then

  tmp=native.harm.tmp.${RANDOM}
  mkdir -p ${tmp}

  for p in {adc,t2}_{base,rate}; do
    runit ${qitcmd} VolumeHarmonize \
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
	runit ${qitcmd} VolumeMask \
		--input native.harm/t2_rate.nii.gz \
		--mask native.mask/brain.mask.nii.gz \
		--output ${tmp}/native.nii.gz

	echo "performing registration"
	runit ${qitcmd} VolumeRegisterLinearAnts \
		--rigid \
		--input ${tmp}/native.nii.gz \
		--ref ${data}/${species}/brain.nii.gz \
		--output ${tmp}/work

	mv ${tmp}/work/* ${tmp}
	rm -rf ${tmp}/work

  mv ${tmp} native.reg

fi

for p in fit harm; do

	if [ ! -e standard.${p} ]; then

		tmp=standard.${p}.tmp.${RANDOM}
		mkdir -p ${tmp}

		for m in {t2,adc}_{base,rate}; do

			runit ${qitcmd} VolumeTransform \
				--input native.${p}/${m}.nii.gz \
				--affine native.reg/xfm.txt \
				--reference ${data}/${species}/brain.nii.gz \
				--output ${tmp}/${m}.nii.gz 

		done

		mv ${tmp} standard.${p}

	fi
done

if [ ! -e standard.mask ]; then

  tmp=standard.mask.tmp.${RANDOM}
  mkdir -p ${tmp}

	runit ${qitcmd} MaskTransform \
		--input native.mask/brain.mask.nii.gz \
		--affine native.reg/xfm.txt \
		--reference ${data}/${species}/brain.nii.gz \
		--output ${tmp}/raw.mask.nii.gz

	runit ${qitcmd} MaskFilterMode \
		--input ${tmp}/raw.mask.nii.gz \
		--output ${tmp}/filter.mask.nii.gz

	runit ${qitcmd} MaskIntersection \
		--left ${tmp}/filter.mask.nii.gz \
		--right ${data}/${species}/restrict.mask.nii.gz \
		--output ${tmp}/brain.mask.nii.gz

  mv ${tmp} standard.mask

fi

if [ ! -e standard.seg ]; then

  runit bash ${workflow}/SpanAuxSegmentLesion.sh \
     --input standard.harm \
     --mask standard.mask/brain.mask.nii.gz \
     --prior ${data}/${species}/lesion.mask.nii.gz \
     --output standard.seg

  runit ${qitcmd} MaskIntersection \
     --left ${data}/${species}/regions.nii.gz \
     --right standard.seg/lesion.mask.nii.gz \
     --output standard.seg/lesion.regions.nii.gz
  runit cp ${data}/${species}/lesion.regions.csv \
     standard.seg/lesion.regions.csv

fi

if [ ! -e standard.midline ]; then

	runit ${qitcmd} ${workflow}/SpanAuxMidline.py \
    standard.mask/brain.mask.nii.gz \
    standard.seg/tissue.mask.nii.gz \
    standard.seg/csf.mask.nii.gz \
    ${data}/${species} \
    standard.midline

fi

if [ ! -e standard.map ]; then

  tmp=standard.map.tmp.${RANDOM}
  mkdir -p ${tmp}

  for f in adc t2; do
    cp native.fit/${f}_report.csv ${tmp}/${f}_qa.csv
  done

  cp standard.midline/map.csv ${tmp}/midline.csv

  runit ${qitcmd} MaskRegionsMeasure \
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

  runit ${qitcmd} MaskMeasure \
    --input standard.seg/rois.nii.gz \
    --lookup standard.seg/rois.csv \
    --output ${tmp}/volume.csv

  runit ${qitcmd} MaskMeasure \
    --input standard.seg/lesion.regions.nii.gz \
    --lookup standard.seg/lesion.regions.csv \
    --output ${tmp}/regions.csv

  mv ${tmp} standard.map

fi

function visit 
{
  runit ${qitcmd} VolumeRender \
    --bghigh 3.0 \
    --alpha 1.0 \
    --discrete pastel \
    --background ${1} \
    --labels ${4}/${3}.nii.gz \
    --output ${4}/${2}_${3}.nii.gz

  runit ${qitcmd} VolumeMosaic \
    --crop :,start:2:end,: \
    --rgb --axis j \
    --input ${4}/${2}_${3}.nii.gz \
    --output ${4}/${2}_${3}.png
  rm ${4}/${2}_${3}.nii.gz
}

if [ ! -e standard.vis ]; then

  tmp=standard.vis.tmp.${RANDOM}
  mkdir -p ${tmp}

  runit ${qitcmd} MaskShell \
    --mode Multi \
    --input standard.seg/rois.nii.gz \
    --output ${tmp}/rois.nii.gz

  runit ${qitcmd} MaskShell \
    --input standard.seg/lesion.mask.nii.gz \
    --output ${tmp}/lesion.nii.gz

  runit ${qitcmd} MaskShell \
    --input standard.seg/csf.mask.nii.gz \
    --output ${tmp}/csf.nii.gz

  runit ${qitcmd} MaskShell \
    --input standard.mask/brain.mask.nii.gz \
    --output ${tmp}/brain.nii.gz

  runit ${qitcmd} MaskSet --clear \
    --input ${tmp}/brain.nii.gz \
    --output ${tmp}/anatomy.nii.gz

  for labels in anatomy brain lesion csf rois; do 
    for param in {adc,t2}_{rate,base}; do
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
