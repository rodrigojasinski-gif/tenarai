#!/bin/ksh
 . race_oem.ksh
#$Id: mptr905.ksh,v 1.1 2021/11/03 22:28:31 pg2697 Exp $
############################################################################
# JOB NAME: mptr905
# JOB DESC: Produce OEM Batch Setup Information Report
#
# NOTE: $1, if provided, is the step to restart in. 
#       If not provided, null is assigned and has no effect.
############################################################################

export RESTART=$1
         
echo "    Start  ${JOBNAME}   "$(date)        >> ${JOBLOGNAME}
logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)

exec_restart.ksh mpt905.ksh ${RESTART} >> ${JOBLOGNAME}

rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}    

logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End   "$(date)
echo "    End    ${JOBNAME}   "$(date)        >> ${JOBLOGNAME}

############################################################################
#  END                                                                    
############################################################################