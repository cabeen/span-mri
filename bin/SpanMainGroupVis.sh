#! /usr/bin/env bash
##############################################################################
#
#  SPAN Rodent MRI Analytics — Group Visualization Collection
#
#  Purpose:
#    Creates hard links to all subject visualization PNGs in a single flat
#    directory for easy group-level review. Organizes by species, site,
#    subject, timepoint, contrast, and label overlay type.
#
#  Expected directory layout:
#    process/{mouse,rat}/{early,late}/<subject_id>/standard.vis/*.png
#
#  Outputs:
#    group/vis/<species>_<site>_<sid>_<tp>_<contrast>_<vis>.png
#
#  Author: Ryan Cabeen
#
##############################################################################

mybin=$(cd $(dirname ${0}); pwd -P)
name=$(basename $0)

usage()
{
    echo "
Name: ${name}

Description:

  Collect subject visualization PNGs into a single flat directory for
  group-level review. Organizes by species, site, subject, timepoint,
  contrast, and label overlay type.

Usage:

  ${name} [--help]

Outputs:

  group/vis/<species>_<site>_<sid>_<tp>_<contrast>_<vis>.png

Author: Ryan Cabeen
"
    exit 1
}

if [ "${1:-}" == "--help" ] || [ "${1:-}" == "-h" ]; then usage; fi
if [ ! -e process ]; then echo "process directory not found!"; usage; fi

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

mkdir -p ${output}/vis

echo "  making vis" 
for sdir in ${input}/*/*/*; do
  echo "  ... ${sdir}"
  if [ -e ${sdir}/standard.vis ]; then
		sid=$(basename ${sdir})
		tp=$(basename $(dirname ${sdir}))
		species=$(basename $(dirname $(dirname ${sdir})))
		site=$(cat ${sdir}/native.import/site.txt)
		date=$(cat ${sdir}/native.import/date.txt)

		for contrast in {adc,t2}_rate; do
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
