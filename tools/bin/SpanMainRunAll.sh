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


for s in cases/source/*/*; do 
  logd=$(echo ${s} | sed 's/source/log/g') 
  mkdir -p ${logd}
  qsubcmd --qlog ${logd} bash ${mybin}/SpanMainRun.sh \
    --source  ${s} $(echo ${s} | sed 's/source/process/g') \
    --correct ${s} $(echo ${s} | sed 's/source/correct/g') \
    --source  ${s} $(echo ${s} | sed 's/source/process/g')
done

################################################################################
# END
################################################################################
