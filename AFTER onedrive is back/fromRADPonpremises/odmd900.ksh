#!/bin/ksh
 . race_oem.ksh
#$Id: odmd900.ksh,v 1.1 2019/04/23 23:45:18 pg2697 Exp $
#****************************************************************************
# Job Description: GMC_US - Build Service Navigation Tree
#****************************************************************************
export RESTART=$1

echo "    Start  ${JOBNAME}   "$(date) >> ${JOBLOGNAME}
logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)

exec_restart.ksh odm900.ksh ${RESTART} >> ${JOBLOGNAME}

rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}

logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End   "$(date)
echo "    End    ${JOBNAME}   "$(date) >> ${JOBLOGNAME}
#***************************************************************************
# END
#***************************************************************************
