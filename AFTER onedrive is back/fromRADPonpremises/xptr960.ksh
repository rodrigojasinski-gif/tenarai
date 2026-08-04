#!/bin/ksh
 . race_oem.ksh
#$Id: xptr960.ksh,v 1.1 2022/02/16 03:44:07 pg2697 Exp $
#####################################################################################
# JOB NAME: xptr960
# JOB DESC: Update MX part in lines where different from the VALUE_FROM country part
#           This is done for every MFR for which the assoc'd MX Part Supplier does 
#           not send supersessions.
#
# NOTE: $1, if provided, is the step to restart in. 
#       If not provided, null is assigned and has no effect.
#####################################################################################

export RESTART=$1
         
echo "    Start  ${JOBNAME}   "$(date)        >> ${JOBLOGNAME}
logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)

exec_restart.ksh xpt960.ksh ${RESTART} >> ${JOBLOGNAME}

rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}    

logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End   "$(date)
echo "    End    ${JOBNAME}   "$(date)        >> ${JOBLOGNAME}

############################################################################
#  END                                                                    
############################################################################