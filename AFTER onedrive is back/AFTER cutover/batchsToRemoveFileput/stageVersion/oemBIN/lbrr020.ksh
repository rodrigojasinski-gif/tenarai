#!/bin/ksh
 . race_oem.ksh
#$Id: lbrr020.ksh,v 1.2 2016/04/01 00:51:49 pg2697 Exp $
############################################################################
#  JOBNAME:  lbrr020                                                       #
#  DESC:     US Honda Warranty Data Load                                   #
############################################################################
# Define PATH and RACE.
export RESTART=$1

echo "    Start  ${JOBNAME}   "$(date)        >> ${JOBLOGNAME}
logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)

exec_restart.ksh lbr020.ksh ${RESTART}        >> ${JOBLOGNAME}

rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}    

logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End   "$(date)
echo "    End    ${JOBNAME}   "$(date)        >> ${JOBLOGNAME}

############################################################################
#  END                                                                     #
############################################################################
