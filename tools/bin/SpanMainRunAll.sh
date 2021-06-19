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

for s in source/*/*; do 
  subd=$(echo ${s} | sed 's/source/process/g')
  logd=$(echo ${s} | sed 's/source/log/g') 

  if [ ! -e ${subd}/standard.vis ] || [ ! -e ${subd}/standard.map ]; then
    mkdir -p ${logd}
    qsubcmd --qlog ${logd} bash ${mybin}/SpanMainRun.sh \
      --source  ${s} \
      --correct $(echo ${s} | sed 's/source/correct/g') \
      --subject $(echo ${s} | sed 's/source/process/g')
  fi
done

################################################################################
# END
################################################################################
