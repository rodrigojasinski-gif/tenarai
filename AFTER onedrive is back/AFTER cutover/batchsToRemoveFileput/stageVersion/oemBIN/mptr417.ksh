#!/bin/ksh
 . race_oem.ksh
#$Id: mptr417.ksh,v 1.5 2016/02/18 01:34:59 pg2697 Exp $
#***************************************************************************
# Job Description: RACE OEM Parts Price Reformat: INF 066 CA
#***************************************************************************
export RESTART=$1
export RESTART_FILE_SEQUENCE=$2

echo "    Start  ${JOBNAME}   "$(date) >> ${JOBLOGNAME}
logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)

exec_restart.ksh oem_ref_trans_split_only.ksh ${RESTART} >> ${JOBLOGNAME}

rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}

logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End   "$(date)
echo "    End    ${JOBNAME}   "$(date) >> ${JOBLOGNAME}
#***************************************************************************
# END
#***************************************************************************