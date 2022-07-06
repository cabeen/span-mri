#! /usr/bin/env bash 
##############################################################################
#
#  SPAN Rodent MRI Analytics 
#
#    A script for grouping results across individuals
#
#  Author: Ryan Cabeen
#
##############################################################################

mybin=$(cd $(dirname ${0}); pwd -P)
name=$(basename $0)

if [ ! -e process ]; then echo "process directory not found!"; exit; fi

input=process
output=group

function runit 
{
  $@
  if [ $? != 0 ]; then 
    echo "error encountered, please check the log"; 
    exit 1;
  fi
}

echo "started ${name}"
echo "  using input: ${input}"
echo "  using output: ${output}"

mkdir -p ${output}
mkdir -p ${output}/tables
mkdir -p ${output}/vis

echo "  making tables" 
rm -rf ${output}/sids.txt

echo "  ... collecting subject list" 
for sdir in ${input}/*/*/*; do
  if [ -e ${sdir}/standard.vis ]; then
		sid=$(basename ${sdir})
		echo ${sid} 
  fi
done > ${output}/sids.txt

cat ${output}/sids.txt | sort | uniq > ${output}/tmp \
  && mv ${output}/tmp ${output}/sids.txt

echo "  ... collecting scan data" 
echo "subject,species,site,date,timepoint,uid" > ${output}/tables/meta.csv
for sdir in ${input}/*/*/*; do
  if [ -e ${sdir}/standard.vis ]; then
		sid=$(basename ${sdir})
		tp=$(basename $(dirname ${sdir}))
		species=$(basename $(dirname $(dirname ${sdir})))
		site=$(cat ${sdir}/native.import/site.txt)
		date=$(cat ${sdir}/native.import/date.txt)

		echo "${sid},${species},${site},${date},${tp},${sid}_${tp}"
  fi
done >> ${output}/tables/meta.csv


echo "  ... grouping tables" 
qit --verbose MapCat \
  --pattern ${input}/%{species}/%{timepoint}/%{subject}/standard.map/%{metric}.csv \
  --vars species=rat,mouse timepoint=early,late subject=${output}/sids.txt metric=midline,adc_qa,adc_base_mean,adc_base_harm_mean,adc_rate_mean,adc_rate_harm_mean,adc_rate_std,adc_rate_harm_std,t2_base_mean,t2_base_harm_mean,t2_rate_mean,t2_rate_harm_mean,t2_rate_std,t2_rate_harm_std,t2_qa,conf_mean,volume,regions \
  --skip \
  --output ${output}/tables/metrics.csv

echo "  ... postprocessing tables" 
qit TableSelect \
  --cat uid=%{subject}_%{timepoint} \
  --input ${output}/tables/metrics.csv \
  --output ${output}/tables/metrics.csv

qit TableMerge \
  --left ${output}/tables/meta.csv \
  --right ${output}/tables/metrics.csv \
  --field uid \
  --output ${output}/table.csv

qit TableSelect \
  --cat measure=%{metric}_%{name} \
  --input ${output}/table.csv \
  --output ${output}/table.wide.csv

qit TableSelect \
  --input ${output}/table.wide.csv \
  --remove metric,name \
  --output ${output}/table.wide.csv

qit TableWiden \
  --input ${output}/table.wide.csv \
  --na 0 \
  --name measure \
  --output ${output}/table.wide.csv

cat ${output}/table.wide.csv | sed 's/volume_volume/volume/g' > ${output}/tmp \
 && mv ${output}/tmp ${output}/table.wide.csv

qit TableSelect \
  --input ${output}/table.wide.csv \
  --retain subject,species,site,timepoint,date,volume_csf,volume_tissue,volume_lesion,adc_rate_mean_tissue,adc_rate_mean_csf,adc_rate_mean_lesion,t2_rate_mean_tissue,t2_rate_mean_csf,t2_rate_mean_lesion,adc_qa_snr,t2_qa_snr,midline_shift_percent,midline_shift_ratio,midline_shift_index,midline_shift_left,midline_shift_right,midline_tissue_volume_left,midline_tissue_volume_right,midline_tissue_volume_index,regions_volume_lesion_striatum,regions_volume_lesion_cortex,regions_volume_lesion_thalamus,regions_volume_lesion_hippocampus \
  --output ${output}/table.wide.csv

bash ${mybin}/SpanAuxNormalizeTable.sh \
  ${output}/table.wide.csv ${output}/table.wide.csv

echo "  making metadata" 
python ${mybin}/SpanAuxSummarize.py \
  --input ${input} --output ${output}/tables/metadata.csv

echo "  making vis" 
for sdir in ${input}/*/*/*; do
  echo "  ... ${sdir}"
  if [ -e ${sdir}/standard.vis ]; then
		sid=$(basename ${sdir})
		tp=$(basename $(dirname ${sdir}))
		species=$(basename $(dirname $(dirname ${sdir})))
		site=$(cat ${sdir}/native.import/site.txt)
		date=$(cat ${sdir}/native.import/date.txt)

		for contrast in {adc,t2}_{rate,base}; do
		  for vis in anatomy brain lesion csf rois; do
		    infn=${input}/${species}/${tp}/${sid}/standard.vis/${contrast}_${vis}.png
		    if [ -e ${infn} ]; then
		       ln ${infn} ${output}/vis/${species}_${site}_${sid}_${tp}_${contrast}_${vis}.png
		    fi
		  done
		done
  fi
done

echo "finished"

################################################################################
# END
################################################################################
