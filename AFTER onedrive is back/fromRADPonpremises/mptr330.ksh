#!/bin/ksh
 . race_oem.ksh
#$Id: mptr330.ksh,v 1.1 2026/06/25 13:46:02 rd131153 Exp $
#***************************************************************************
# Job Description: RACE OEM Parts Price Reformat: LUC 085 US
#***************************************************************************
export RESTART=$1
export RESTART_FILE_SEQUENCE=$2

echo "    Start  ${JOBNAME}   "$(date) >> ${JOBLOGNAME}
logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)

exec_restart.ksh oem_ref.ksh ${RESTART} >> ${JOBLOGNAME}
RETURN_CODE=$?
if [ -n "${RESTART}" ] && [ "${RETURN_CODE}" = "0" ]
then
   echo "Unset environment variable RESTART=${RESTART}\n\n\n" >> ${JOBLOGNAME}
   export RESTART=''
fi

exec_restart.ksh oem_ref_trans_check_and_split.ksh ${RESTART} >> ${JOBLOGNAME}

rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}

logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End   "$(date)
echo "    End    ${JOBNAME}   "$(date) >> ${JOBLOGNAME}
#***************************************************************************
# END
#***************************************************************************