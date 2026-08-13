#!/bin/ksh
 . race_oem.ksh
#$Id: mptr916.ksh,v 1.2 2016/04/01 00:59:12 pg2697 Exp $
############################################################################
# JOB NAME: mptr916
# JOB DESC: Rename files to obs_ for /stage files
#
# NOTE: $1, if provided, is the step to restart in. 
#       If not provided, null is assigned and has no effect.
############################################################################

export RESTART=$1
         
echo "    Start  ${JOBNAME}   "$(date)        >> ${JOBLOGNAME}
logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)

exec_restart.ksh mpt916.ksh ${RESTART} >> ${JOBLOGNAME}

rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}    

logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End   "$(date)
echo "    End    ${JOBNAME}   "$(date)        >> ${JOBLOGNAME}

############################################################################
#  END                                                                    
############################################################################
