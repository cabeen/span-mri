#! /usr/bin/env bash
##############################################################################
#
#  SPAN Rodent MRI Analytics — Single-Case Processing Pipeline
#
#  Purpose:
#    Main entry point for processing a single rodent brain MRI case through
#    the full SPAN analysis pipeline. Converts raw DICOM data into
#    quantitative stroke metrics including lesion volumes, midline shift,
#    and regional anatomical measurements.
#
#  Pipeline stages (each is idempotent — skipped if output already exists):
#    1. native.dicom    — Copy and fix DICOM headers (merge ProtocolName/SeriesDescription)
#    2. native.convert  — Convert DICOM to NIfTI using dcm2niix; extract site metadata
#    3. native.import   — Identify modalities (ADC, T2, RARE); apply site-specific orientation
#    4. native.denoise  — Non-local means denoising (Otsu mask, slice-wise NLM)
#    5. native.fit      — Exponential decay fitting (S(TE) = alpha * exp(-beta * TE))
#    6. native.mask     — Brain extraction (U-Net for mice, rule-based morphology for rats)
#    7. native.harm     — Statistical harmonization of fitted parameter maps
#    8. native.reg      — Rigid registration to species-specific atlas using ANTs
#    9. standard.fit/harm — Transform fitted/harmonized maps to atlas space
#   10. standard.mask   — Transform brain mask to atlas space; intersect with restriction mask
#   11. standard.seg    — Lesion and CSF segmentation using multi-modal thresholding
#   12. standard.midline — Midline shift analysis (mm, percent, laterality indices)
#   13. standard.label  — Anatomical labeling (hemispheres, regions, tissue classes)
#   14. standard.map    — Compute quantitative metrics (volumes, intensities by region)
#   15. standard.vis    — Generate mosaic visualizations of segmentation overlays
#
#  Inputs:
#    --case <dir>       Case output directory (required; created if it doesn't exist)
#    --source <dir>     DICOM source directory (required on first run)
#    --species <str>    Species: "mouse" or "rat" (default: auto-detected from path)
#    --correct <dir>    Correction directory containing flipi/flipj/flipk flags (optional)
#
#  Outputs:
#    Populates the case directory with subdirectories for each pipeline stage.
#    Key outputs include:
#      standard.map/*.csv  — Quantitative metric tables
#      standard.vis/*.png  — Mosaic visualization images
#
#  Dependencies:
#    dcm2niix, ANTs (N4BiasFieldCorrection), QIT, Python 3 + PyTorch (mice only)
#
#  Author: Ryan Cabeen
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
        --case)                    shift; case=$1 ;;
        --species)                 shift; species=$1 ;;
        --help )                   usage ;;
        * )                        posit="${posit} $1" ;;
    esac
    shift
done

if [ $(echo ${posit} | wc -w) -ne 0 ]; then echo "unexpected positional arguments: ${posit}"; usage; fi
if [ ""${case} == "" ]; then echo "no case provided"; usage; fi

# Auto-detect species from the case directory path. The standard directory
# layout uses process/{mouse,rat}/{early,late}/subject_id, so a path
# containing "rat" or "mouse" indicates the species. Falls back to mouse.
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

# Stage 1: Copy DICOM source into the case directory and fix headers.
# The header fix merges ProtocolName and SeriesDescription fields so that
# dcm2niix can produce consistent, informative filenames during conversion.
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

# Check for axis-flip corrections. If the correction directory contains
# files named flipi, flipj, or flipk, the corresponding axis will be
# flipped during import to correct acquisition orientation errors.
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

# Stage 2: Convert DICOM to NIfTI format using dcm2niix.
# Extracts site name from DICOM JSON metadata and builds an image index
# CSV cataloging all scans with their acquisition parameters.
# Output: native.convert/nifti/*.nii.gz, native.convert/site.txt, native.convert/images.csv
if [ -e native.dicom ] && [ ! -e native.convert ]; then

  tmp=native.convert.tmp.${RANDOM}
  runit bash ${workflow}/SpanAuxConvert.sh native.dicom ${tmp}
  mv ${tmp} native.convert

fi

# Stage 3: Import and organize converted images into a standardized format.
# Identifies ADC, T2, and RARE modalities by filename patterns. Applies
# site-specific image orientation (from params/<site>/orient.json) and
# resamples to a common geometry. Applies any axis-flip corrections.
# Output: native.import/{adc,t2,rare}.nii.gz, native.import/{adc,t2}.txt (echo times)
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

# Stage 4: Denoise the multi-echo ADC and T2 volumes.
# Uses Otsu thresholding to create a foreground mask, then applies non-local
# means (NLM) filtering slice-by-slice (h=0.1, relative mode) to reduce
# noise while preserving edges. Echo time files are copied through unchanged.
# Output: native.denoise/{adc,t2}.nii.gz, native.denoise/{adc,t2}.txt
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

# Stage 5: Fit exponential decay model to multi-echo data.
# For each modality (ADC, T2), fits S(TE) = alpha * exp(-beta * TE) where:
#   alpha (base) = signal amplitude at TE=0
#   beta  (rate) = decay rate (related to tissue relaxation/diffusion)
#   rmse  = root mean square fitting error
#   snr   = signal-to-noise ratio of the fit
# The --skipFirstThresh 7 parameter skips the first echo if its intensity
# exceeds 7x the second echo, which handles T2* contamination artifacts.
# Also computes the mean across echoes (with N4 bias field correction)
# and a foreground mask with QA report for each modality.
# Output: native.fit/{adc,t2}_{base,rate,rmse,snr,mean,mask}.nii.gz
if [ ! -e native.fit ]; then

  tmp=native.fit.tmp.${RANDOM}
  mkdir -p ${tmp}

  for m in adc t2; do
		runit ${qitcmd} VolumeExpDecayFit \
      --skipFirstThresh 7 \
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

# Stage 6: Brain extraction (skull stripping).
# Uses species-specific strategies:
#   Mouse: Tri-planar 2D U-Net deep learning model that fuses T2 and ADC
#          parameter maps (4 channels: t2_base, t2_rate, adc_base, adc_rate)
#   Rat:   Rule-based morphological pipeline on ADC baseline image (foreground
#          detection → contrast enhancement → gradient edges → graph
#          segmentation → morphological cleanup → MRF-EM refinement)
# Output: native.mask/brain.mask.nii.gz
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

# Stage 7: Statistical harmonization of fitted parameter maps.
# Normalizes each parameter map (adc_base, adc_rate, t2_base, t2_rate) to
# have zero mean and unit variance within the brain mask. This reduces
# inter-site and inter-scanner variability in the quantitative maps.
# Output: native.harm/{adc,t2}_{base,rate}.nii.gz
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

# Stage 8: Register native-space brain to species-specific atlas.
# Extracts the brain-masked harmonized T2 rate map as the registration
# target, then performs rigid registration to the atlas brain template
# using ANTs. The rigid transform preserves brain shape while aligning
# orientation and position.
# Output: native.reg/xfm.txt (affine transform matrix)
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

# Stage 9: Transform fitted and harmonized parameter maps to standard atlas space.
# Applies the rigid transform from registration to warp each parameter map
# (t2_base, t2_rate, adc_base, adc_rate) into the atlas coordinate system.
# Output: standard.fit/{t2,adc}_{base,rate}.nii.gz, standard.harm/{t2,adc}_{base,rate}.nii.gz
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

# Stage 10: Transform brain mask to standard atlas space.
# Warps the native brain mask using the registration transform, applies
# a mode filter to clean up interpolation artifacts, then intersects with
# the atlas restriction mask to remove any regions outside the expected
# brain boundary.
# Output: standard.mask/brain.mask.nii.gz
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

# Stage 11: Segment lesion and CSF in standard atlas space.
# Uses multi-modal sigmoid thresholding on harmonized T2 rate, ADC rate,
# and ADC base maps to estimate lesion probability. Applies a two-threshold
# seed-and-grow strategy (high threshold → morphological cleanup → dilate →
# low threshold) for robust lesion delineation. CSF is segmented separately.
# Results are intersected with the species-specific lesion prior mask.
# Output: standard.seg/{lesion,tissue,csf}.mask.nii.gz, standard.seg/rois.nii.gz
if [ ! -e standard.seg ]; then

  runit bash ${workflow}/SpanAuxSegmentLesion.sh \
     --input standard.harm \
     --mask standard.mask/brain.mask.nii.gz \
     --prior ${data}/${species}/lesion.mask.nii.gz \
     --output standard.seg

fi

# Stage 12: Compute midline shift metrics.
# Identifies the centroid of CSF in the midline region, then measures
# the displacement from the anatomical center. Computes shift in mm,
# as a percentage of brain width, and laterality indices for tissue
# and brain volumes. Splits the brain into hemispheres.
# Output: standard.midline/map.csv, standard.midline/{brain,tissue}.hemis.mask.nii.gz
if [ ! -e standard.midline ]; then

	runit ${qitcmd} ${workflow}/SpanAuxMidline.py \
    standard.mask/brain.mask.nii.gz \
    standard.seg/tissue.mask.nii.gz \
    standard.seg/csf.mask.nii.gz \
    ${data}/${species} \
    standard.midline

fi

# Stage 13: Create anatomical label volumes by combining tissue classes,
# hemispheres, and atlas regions. Produces combinatorial label volumes:
#   classes           — tissue(1), csf(2), lesion(3)
#   hemis             — left(1), right(2) hemispheres
#   hemis_classes     — hemisphere × tissue class
#   classes_regions   — tissue class × anatomical region (cortex, striatum, etc.)
#   hemis_classes_regions — hemisphere × tissue class × region
# Output: standard.label/{classes,hemis,hemis_classes,...}.nii.gz and .csv
if [ ! -e standard.label ]; then

  tmp=standard.label.tmp.${RANDOM}
  mkdir -p ${tmp}

  runit cp standard.seg/rois.nii.gz ${tmp}/classes.nii.gz
  runit cp standard.seg/rois.csv ${tmp}/classes.csv

  runit cp standard.midline/brain.hemis.mask.nii.gz ${tmp}/hemis.nii.gz
  runit cp ${data}/${species}/hemis.csv ${tmp}/hemis.csv

  runit ${qitcmd} MaskProduct\
     --left ${data}/${species}/regions.nii.gz \
     --right ${tmp}/classes.nii.gz \
     --output ${tmp}/classes_regions.nii.gz

  runit ${qitcmd} MaskProduct\
     --left ${tmp}/hemis.nii.gz \
     --right ${tmp}/classes_regions.nii.gz \
     --output ${tmp}/hemis_classes_regions.nii.gz

  runit ${qitcmd} MaskProduct\
     --left ${tmp}/hemis.nii.gz \
     --right ${tmp}/classes.nii.gz \
     --output ${tmp}/hemis_classes.nii.gz

  mv ${tmp} standard.label
fi

# Stage 14: Compute quantitative metric tables.
# Copies QA reports (SNR) from native fitting, midline shift metrics, and
# computes regional statistics: mean/std of each parameter map within each
# label combination (hemisphere × tissue class × region). Also computes
# volumetric measurements for each label combination.
# Output: standard.map/{midline,adc_qa,t2_qa,volumetrics_by_*,...}.csv
if [ ! -e standard.map ]; then

  tmp=standard.map.tmp.${RANDOM}
  mkdir -p ${tmp}

  for f in adc t2; do
    cp native.fit/${f}_report.csv ${tmp}/${f}_qa.csv
  done

  cp standard.midline/map.csv ${tmp}/midline.csv

  for label in classes hemis_classes; do
		runit ${qitcmd} MaskRegionsMeasure \
			--basic \
			--regions standard.label/${label}.nii.gz \
			--lookup standard.label/${label}.csv \
			--volume ${label}_adc_rate=standard.fit/adc_rate.nii.gz \
							 ${label}_t2_rate=standard.fit/t2_rate.nii.gz \
							 ${label}_adc_base=standard.fit/adc_base.nii.gz \
							 ${label}_t2_base=standard.fit/t2_base.nii.gz \
							 ${label}_adc_rate_harm=standard.harm/adc_rate.nii.gz \
							 ${label}_t2_rate_harm=standard.harm/t2_rate.nii.gz \
							 ${label}_adc_base_harm=standard.harm/adc_base.nii.gz \
							 ${label}_t2_base_harm=standard.harm/t2_base.nii.gz \
			--mask standard.mask/brain.mask.nii.gz \
			--output ${tmp}
  done

  for n in classes hemis hemis_classes classes_regions hemis_classes_regions; do
		runit ${qitcmd} MaskMeasure \
			--input standard.label/${n}.nii.gz \
			--lookup standard.label/${n}.csv \
			--output ${tmp}/volumetrics_by_${n}.csv
  done

  mv ${tmp} standard.map

fi

# Helper function for generating label overlay visualizations.
# Renders a label mask on top of a background parameter map using pastel
# colors, then creates a coronal mosaic image (every other slice) as a PNG.
# Args: $1=background volume, $2=param name, $3=label name, $4=output dir
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

# Stage 15: Generate mosaic visualizations.
# Creates edge-outlined versions of brain, lesion, CSF, ROI, and hemisphere
# labels (MaskShell), then overlays each on the harmonized ADC and T2 rate
# maps as coronal mosaic PNGs for quality control review.
# Output: standard.vis/{adc,t2}_rate_{anatomy,brain,lesion,csf,rois,hemis}.png
if [ ! -e standard.vis ]; then

  tmp=standard.vis.tmp.${RANDOM}
  mkdir -p ${tmp}

  runit ${qitcmd} MaskShell \
    --mode Multi \
    --input standard.label/hemis.nii.gz \
    --output ${tmp}/hemis.nii.gz

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

  for labels in anatomy brain lesion csf rois hemis; do 
    for param in {adc,t2}_rate; do
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
