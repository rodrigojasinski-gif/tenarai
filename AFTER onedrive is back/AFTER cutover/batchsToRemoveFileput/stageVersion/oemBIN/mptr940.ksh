#!/bin/ksh
 . race_oem.ksh
#$Id: mptr940.ksh,v 1.3 2016/04/01 01:00:00 pg2697 Exp $
#********************************************************************
# Job Description:  Run On Demand Supersession Analysis
#********************************************************************
export MASTER_JOBNAME=$(basename $0 .ksh)
export MASTER_LOGNAME=${RACE}/log/$(logname.ksh ${MASTER_JOBNAME} $1)

echo "   Start   ${MASTER_JOBNAME}   "$(date) >> ${MASTER_LOGNAME}
logger -p user.info "OPCOM*I*PROCES*${MASTER_JOBNAME}*        *Start "$(date)

exec_restart.ksh mpt940.ksh ${RESTART} >> ${MASTER_LOGNAME}

rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}    

logger -p user.info "OPCOM*I*PROCES*${MASTER_JOBNAME}*        *End   "$(date)
echo "    End    ${MASTER_JOBNAME}   "$(date) >> ${MASTER_LOGNAME}
#***************************************************************************
# END
#***************************************************************************

