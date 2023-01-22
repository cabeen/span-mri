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
