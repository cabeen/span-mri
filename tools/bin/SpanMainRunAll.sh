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

for s in level0/*/*; do 
  qsubcmd bash ${mybin}/SpanMainRun.sh --input ${s} $(echo ${s} | sed 's/level0/level1/g')
done

################################################################################
# END
################################################################################
