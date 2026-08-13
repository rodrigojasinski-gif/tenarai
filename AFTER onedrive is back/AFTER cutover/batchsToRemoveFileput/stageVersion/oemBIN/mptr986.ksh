#!/bin/ksh
 . race_oem.ksh
#$Id: mptr986.ksh,v 1.2 2016/04/01 01:02:34 pg2697 Exp $
############################################################################
# JOB NAME: mptr986
# JOB DESC: Remove files (in tmp, rpt, dat, and log) created by reformat job.
#
# NOTE: $1, if provided, is the step to restart in. 
#       If not provided, null is assigned and has no effect.
############################################################################

export RESTART=$1
         
echo "    Start  ${JOBNAME}   "$(date)        >> ${JOBLOGNAME}
logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)

exec_restart.ksh mpt986.ksh ${RESTART} >> ${JOBLOGNAME}

rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}    

logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End   "$(date)
echo "    End    ${JOBNAME}   "$(date)        >> ${JOBLOGNAME}

############################################################################
#  END                                                                    
############################################################################
