#!/bin/ksh
 . race_oem.ksh
#$Id: mptr095.ksh,v 1.5 2016/02/18 01:31:24 pg2697 Exp $
#***************************************************************************
# Job Description: RACE OEM Parts Price Reformat: MIT 057 US
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
