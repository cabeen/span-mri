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

for s in staging/*/*; do 
  subd=$(echo ${s} | sed 's/staging/process/g')
  cord=$(echo ${s} | sed 's/staging/correct/g')
  logd=${subd}/log

  echo ${subd}

  if [ ! -e ${subd}/standard.vis ]; then
    mkdir -p ${logd}
    qsubcmd --qlog ${logd} bash ${mybin}/SpanMainRun.sh \
      --source  ${s} --correct ${cord} --subject ${subd}
  fi
done

################################################################################
# END
################################################################################
