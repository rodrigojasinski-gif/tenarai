#!/bin/ksh
 . race_oem.ksh
#$Id: mptr825.ksh,v 1.2 2023/06/27 22:29:26 pg2697 Exp $
#********************************************************************
# Job Description: RACE OEM Parts Price Reformat: LYNN 715 US (Lynn Truck Parts)
#********************************************************************
export RESTART=$1
export RESTART_FILE_SEQUENCE=$2

echo "    Start  ${JOBNAME}   "$(date) >> ${JOBLOGNAME}
logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)


# Pre-processor: Gets data file from NT and then puts a copy in Editorial NT directory.
#                If file already has .zip extension, bypasses add and continues on.
exec_restart.ksh oem_ref_mptr825_ftp_lynn_to_editorial.ksh ${RESTART} >> ${JOBLOGNAME}
RETURN_CODE=$?
if [ -n "${RESTART}" ] && [ "${RETURN_CODE}" = "0" ]
then
   echo "(1) Unset environment variable RESTART=${RESTART}\n\n\n" >> ${JOBLOGNAME}
   export RESTART=''
fi

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
