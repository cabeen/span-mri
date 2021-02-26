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
  qsubcmd bash ${mybin}/SpanMainRun.sh --input ${s} $(echo ${s} | sed 's/source/process/g')
done

################################################################################
# END
################################################################################
