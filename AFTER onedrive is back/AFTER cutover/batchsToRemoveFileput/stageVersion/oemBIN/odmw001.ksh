#!/bin/ksh
 . race_oem.ksh
#$Id: odmw001.ksh,v 1.2 2016/04/01 01:05:30 pg2697 Exp $
#****************************************************************************
# Job Description: RACE OEM Document Management Repository Update for VW_Audi
#****************************************************************************
export RESTART=$1

echo "    Start  ${JOBNAME}   "$(date) >> ${JOBLOGNAME}
logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)

exec_restart.ksh odm001.ksh ${RESTART} >> ${JOBLOGNAME}

rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}    

logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End   "$(date)
echo "    End    ${JOBNAME}   "$(date) >> ${JOBLOGNAME}

#***************************************************************************
# END
#***************************************************************************
