# ! /bin/bash
##############################################################################
#
#  SPAN Rodent MRI Analytics 
#
#    A script for running the analysis on all cases
#
#  Author: Ryan Cabeen
#
##############################################################################

mybin=$(cd $(dirname ${0}); pwd -P)

for s in source/{mouse,rat}/{early,late}/*; do 
  subd=$(echo ${s} | sed 's/source/process/g')
  cord=$(echo ${s} | sed 's/source/correct/g')
  logd=${subd}/log

  echo ${subd}

  if [ ! -e ${subd}/standard.map ]; then
    mkdir -p ${logd}
    qsubcmd --qlog ${logd} bash ${mybin}/SpanMainRun.sh \
      --source ${s} --correct ${cord} --case ${subd}
  fi
done

################################################################################
# END
################################################################################
