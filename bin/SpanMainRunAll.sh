# ! /bin/bash
##############################################################################
#
#  SPAN Rodent MRI Analytics — Batch Processing
#
#  Purpose:
#    Submits SpanMainRun.sh jobs for all cases in the source/ directory.
#    Iterates over source/{mouse,rat}/{early,late}/* and submits each as
#    a grid computing job via qsubcmd. Skips cases that already have
#    completed standard.map output.
#
#  Expected directory layout:
#    source/{mouse,rat}/{early,late}/<subject_id>/  — DICOM source directories
#    process/{mouse,rat}/{early,late}/<subject_id>/ — Processing output
#    correct/{mouse,rat}/{early,late}/<subject_id>/ — Optional corrections
#
#  Dependencies: qsubcmd (grid job submission), SpanMainRun.sh
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

  Submit SpanMainRun.sh jobs for all cases in the source/ directory.
  Iterates over source/{mouse,rat}/{early,late}/* and submits each as
  a grid job via qsubcmd. Skips cases with completed standard.map output.

Usage:

  ${name} [--help]

Expected layout:

  source/{mouse,rat}/{early,late}/<subject_id>/   — DICOM source directories
  process/{mouse,rat}/{early,late}/<subject_id>/   — Processing output

Author: Ryan Cabeen
"
    exit 1
}

if [ "${1:-}" == "--help" ] || [ "${1:-}" == "-h" ]; then usage; fi

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
