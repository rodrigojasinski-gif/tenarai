#!/bin/ksh
 . race_oem.ksh
#$Id: mptr170.ksh,v 1.6 2022/07/11 23:43:49 pg2697 Exp $
#***************************************************************************
# Job Description: RACE OEM Parts Price Reformat: CHR 004 US
#***************************************************************************
export RESTART=$1
export RESTART_FILE_SEQUENCE=$2

echo "    Start  ${JOBNAME}   "$(date) >> ${JOBLOGNAME}
logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)

# Pre-processor: Adds .zip extension to filename without extension on SFTP server.
#                If file already has .zip extension, bypasses add and continues on.
exec_restart.ksh oem_ref_chr_fia_alf_ftp_prep.ksh ${RESTART} >> ${JOBLOGNAME}
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
   echo "(2) Unset environment variable RESTART=${RESTART}\n\n\n" >> ${JOBLOGNAME}
   export RESTART=''
fi

exec_restart.ksh oem_ref_trans_check_and_split.ksh ${RESTART} >> ${JOBLOGNAME}

rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}

logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End   "$(date)
echo "    End    ${JOBNAME}   "$(date) >> ${JOBLOGNAME}
#***************************************************************************
# END
#***************************************************************************