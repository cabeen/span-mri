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
  --vars species=rat,mouse timepoint=early,late subject=${output}/sids.txt metric=midline,adc_qa,hemis_classes_adc_rate_mean,hemis_classes_adc_rate_harm_mean,hemis_classes_adc_rate_std,hemis_classes_adc_rate_harm_std,hemis_classes_t2_rate_mean,hemis_classes_t2_rate_harm_mean,hemis_classes_t2_rate_std,hemis_classes_t2_rate_harm_std,t2_qa,volumetrics_by_hemis_classes,volumetrics_by_classes,volumetrics_by_hemis_classes_regions,bbb \
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

qit TableSelect \
  --input ${output}/table.wide.csv \
  --retain uid,subject,species,site,date,timepoint,bbb_lesion_ki,bbb_contra_ki,adc_qa_snr,t2_qa_snr,midline_shift_percent,midline_shift_ratio,midline_shift_index,midline_shift_left,midline_shift_right,midline_tissue_volume_left,midline_tissue_volume_right,midline_tissue_volume_index,midline_brain_volume_left,midline_brain_volume_right,midline_brain_volume_index,volumetrics_by_hemis_classes_volume_left_tissue,volumetrics_by_hemis_classes_volume_right_tissue,volumetrics_by_hemis_classes_volume_left_csf,volumetrics_by_hemis_classes_volume_right_csf,volumetrics_by_hemis_classes_volume_left_lesion,volumetrics_by_hemis_classes_volume_right_lesion,volumetrics_by_classes_volume_tissue,volumetrics_by_classes_volume_csf,volumetrics_by_classes_volume_lesion,hemis_classes_adc_rate_mean_left_tissue,hemis_classes_adc_rate_mean_right_tissue,hemis_classes_adc_rate_mean_left_csf,hemis_classes_adc_rate_mean_right_csf,hemis_classes_adc_rate_mean_left_lesion,hemis_classes_adc_rate_mean_right_lesion,hemis_classes_adc_rate_harm_mean_left_tissue,hemis_classes_adc_rate_harm_mean_right_tissue,hemis_classes_adc_rate_harm_mean_left_csf,hemis_classes_adc_rate_harm_mean_right_csf,hemis_classes_adc_rate_harm_mean_left_lesion,hemis_classes_adc_rate_harm_mean_right_lesion,hemis_classes_adc_rate_std_left_tissue,hemis_classes_adc_rate_std_right_tissue,hemis_classes_adc_rate_std_left_csf,hemis_classes_adc_rate_std_right_csf,hemis_classes_adc_rate_std_left_lesion,hemis_classes_adc_rate_std_right_lesion,hemis_classes_adc_rate_harm_std_left_tissue,hemis_classes_adc_rate_harm_std_right_tissue,hemis_classes_adc_rate_harm_std_left_csf,hemis_classes_adc_rate_harm_std_right_csf,hemis_classes_adc_rate_harm_std_left_lesion,hemis_classes_adc_rate_harm_std_right_lesion,hemis_classes_t2_rate_mean_left_tissue,hemis_classes_t2_rate_mean_right_tissue,hemis_classes_t2_rate_mean_left_csf,hemis_classes_t2_rate_mean_right_csf,hemis_classes_t2_rate_mean_left_lesion,hemis_classes_t2_rate_mean_right_lesion,hemis_classes_t2_rate_harm_mean_left_tissue,hemis_classes_t2_rate_harm_mean_right_tissue,hemis_classes_t2_rate_harm_mean_left_csf,hemis_classes_t2_rate_harm_mean_right_csf,hemis_classes_t2_rate_harm_mean_left_lesion,hemis_classes_t2_rate_harm_mean_right_lesion,hemis_classes_t2_rate_std_left_tissue,hemis_classes_t2_rate_std_right_tissue,hemis_classes_t2_rate_std_left_csf,hemis_classes_t2_rate_std_right_csf,hemis_classes_t2_rate_std_left_lesion,hemis_classes_t2_rate_std_right_lesion,hemis_classes_t2_rate_harm_std_left_tissue,hemis_classes_t2_rate_harm_std_right_tissue,hemis_classes_t2_rate_harm_std_left_csf,hemis_classes_t2_rate_harm_std_right_csf,hemis_classes_t2_rate_harm_std_left_lesion,hemis_classes_t2_rate_harm_std_right_lesion,volumetrics_by_hemis_classes_regions_volume_left_cortex_tissue,volumetrics_by_hemis_classes_regions_volume_right_cortex_tissue,volumetrics_by_hemis_classes_regions_volume_left_striatum_tissue,volumetrics_by_hemis_classes_regions_volume_right_striatum_tissue,volumetrics_by_hemis_classes_regions_volume_left_hippocampus_tissue,volumetrics_by_hemis_classes_regions_volume_right_hippocampus_tissue,volumetrics_by_hemis_classes_regions_volume_left_thalamus_tissue,volumetrics_by_hemis_classes_regions_volume_right_thalamus_tissue,volumetrics_by_hemis_classes_regions_volume_left_cortex_csf,volumetrics_by_hemis_classes_regions_volume_right_cortex_csf,volumetrics_by_hemis_classes_regions_volume_left_striatum_csf,volumetrics_by_hemis_classes_regions_volume_right_striatum_csf,volumetrics_by_hemis_classes_regions_volume_left_hippocampus_csf,volumetrics_by_hemis_classes_regions_volume_right_hippocampus_csf,volumetrics_by_hemis_classes_regions_volume_left_thalamus_csf,volumetrics_by_hemis_classes_regions_volume_right_thalamus_csf,volumetrics_by_hemis_classes_regions_volume_left_cortex_lesion,volumetrics_by_hemis_classes_regions_volume_right_cortex_lesion,volumetrics_by_hemis_classes_regions_volume_left_striatum_lesion,volumetrics_by_hemis_classes_regions_volume_right_striatum_lesion,volumetrics_by_hemis_classes_regions_volume_left_hippocampus_lesion,volumetrics_by_hemis_classes_regions_volume_right_hippocampus_lesion,volumetrics_by_hemis_classes_regions_volume_left_thalamus_lesion,volumetrics_by_hemis_classes_regions_volume_right_thalamus_lesion \
  --output ${output}/table.wide.csv

bash ${mybin}/SpanAuxNormalizeTable.sh \
 ${output}/table.wide.csv ${output}/table.wide.csv

# echo "  making metadata" 
# python ${mybin}/SpanAuxSummarize.py \
#   --input ${input} --output ${output}/tables/metadata.csv

################################################################################
# END
################################################################################
