#!/bin/ksh
 . race_oem.ksh
#$Id: lbrr010.ksh,v 1.2 2016/04/01 00:51:14 pg2697 Exp $
############################################################################
#  JOBNAME:  lbrr010                                                       #
#  DESC:     US Audi and VW Labor Warranty Data Load                       #
############################################################################
# Define PATH and RACE.
export RESTART=$1

echo "    Start  ${JOBNAME}   "$(date)        >> ${JOBLOGNAME}
logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)

exec_restart.ksh lbr010.ksh ${RESTART}        >> ${JOBLOGNAME}

rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}    

logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End   "$(date)
echo "    End    ${JOBNAME}   "$(date)        >> ${JOBLOGNAME}

############################################################################
#  END                                                                     #
############################################################################
