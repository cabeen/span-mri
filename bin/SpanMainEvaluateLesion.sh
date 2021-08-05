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

  The SPAN Rodent MRI Analysis.  This program evaluates the lesion segmention.
    
Usage: 

  $(basename $0) --subject subject_dir

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

subject=""
posit=""

while [ "$1" != "" ]; do
    case $1 in
        --subject)                 shift; subject=$1 ;;
        --help )                   usage ;;
        * )                        posit="${posit} $1" ;;
    esac
    shift
done

if [ $(echo ${posit} | wc -w) -ne 0 ]; then echo "unexpected positional arguments: ${posit}"; usage; fi
if [ ""${subject} == "" ]; then echo "no subject provided"; usage; fi

##############################################################################
# Processing 
##############################################################################

echo "started ${name}"

cd ${subject}

for mask in brain lesion; do
	for thresh in 300 350 400 450 500 550 600 650 700 750 760 770 775 780 785 790 795 \
                800 805 810 815 820 825 830 835 840 845 850 860 870 880 890 900 950; do

    outdir=evaluation/mask.${mask}.thresh.${thresh}

    if [ ! -e ${outdir}/standard.seg ]; then
    
      runit bash ${workflow}/SpanAuxSegmentLesion.sh \
         --input standard.harm \
         --t2RateThreshLesion 0.${thresh} \
         --mask standard.mask/brain.mask.nii.gz \
         --prior ${data}/${mask}.mask.nii.gz \
         --output ${outdir}/standard.seg
    
      runit ${qitcmd} MaskIntersection \
         --left ${data}/regions.nii.gz \
         --right ${outdir}/standard.seg/lesion.mask.nii.gz \
         --output ${outdir}/standard.seg/lesion.regions.nii.gz
      runit cp ${data}/lesion.regions.csv ${outdir}/standard.seg/lesion.regions.csv
    
    fi
    
    if [ ! -e ${outdir}/standard.midline ]; then
    
    	runit ${qitcmd} ${workflow}/SpanAuxMidline.py \
        standard.mask/brain.mask.nii.gz \
        ${outdir}/standard.seg/tissue.mask.nii.gz \
        ${outdir}/standard.seg/csf.mask.nii.gz \
        ${outdir}/standard.midline
    
    fi
    
    if [ ! -e ${outdir}/standard.map ]; then
      tmp=${outdir}/standard.map.tmp.${RANDOM}
      mkdir -p ${tmp}
    
      cp ${outdir}/standard.midline/map.csv ${tmp}/midline.csv
    
      runit ${qitcmd} MaskRegionsMeasure \
        --regions ${outdir}/standard.seg/rois.nii.gz \
        --lookup ${outdir}/standard.seg/rois.csv \
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
        --input ${outdir}/standard.seg/rois.nii.gz \
        --lookup ${outdir}/standard.seg/rois.csv \
        --output ${tmp}/volume.csv
    
      runit ${qitcmd} MaskMeasure \
        --input ${outdir}/standard.seg/lesion.regions.nii.gz \
        --lookup ${outdir}/standard.seg/lesion.regions.csv \
        --output ${tmp}/regions.csv
    
      mv ${tmp} ${outdir}/standard.map
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
    
    if [ ! -e ${outdir}/standard.vis ]; then
    
      tmp=${outdir}/standard.vis.tmp.${RANDOM}
      mkdir -p ${tmp}
    
      runit ${qitcmd} MaskShell \
        --mode Multi \
        --input ${outdir}/standard.seg/rois.nii.gz \
        --output ${tmp}/rois.nii.gz
    
      runit ${qitcmd} MaskShell \
        --input ${outdir}/standard.seg/lesion.mask.nii.gz \
        --output ${tmp}/lesion.nii.gz
    
      runit ${qitcmd} MaskShell \
        --input ${outdir}/standard.seg/csf.mask.nii.gz \
        --output ${tmp}/csf.nii.gz
    
      runit ${qitcmd} MaskShell \
        --input standard.mask/brain.mask.nii.gz \
        --output ${tmp}/brain.nii.gz
    
      runit ${qitcmd} MaskSet --clear \
        --input ${tmp}/brain.nii.gz \
        --output ${tmp}/anatomy.nii.gz
    
      #for labels in anatomy brain lesion csf rois; do 
      for labels in lesion; do 
        # for param in rare {adc,t2}_{rate,base}; do
        for param in rare {adc,t2}_rate; do
          visit standard.harm/${param}.nii.gz ${param} ${labels} ${tmp}
        done
      done
    
      rm ${tmp}/*.nii.gz
      mv ${tmp} ${outdir}/standard.vis
    
    fi
  done
done

echo "finished"

################################################################################
# END
################################################################################
