#!/bin/ksh
 . race_altp.ksh

#$Id: xamw080.ksh,v 1.1 2017/03/16 17:21:28 pb0690 Exp $
#############################################################################################
# Job Name: xamr080
# Job Desc: Alternate Part extract for uParts
#############################################################################################

#Modification History
#Date        User ID   Description
#==========  =======   ==============================================
#2017/03/01  pb0690    Intial Version
#
#############################################################################################

############################################################################
# NOTE: Definition of PATH, RACE, local and remote hosts was performed 
# above by: race_altp.ksh and race_hosts.ksh
#
# $RESTART ---> restart step within sub-script (can be blank)
############################################################################

export RESTART=$1
export START_TIME=`date +%c`

echo "    Start  ${JOBNAME}   "$(date) >> ${JOBLOGNAME}
logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)

exec_restart.ksh xam080.ksh ${RESTART} >> ${JOBLOGNAME}

if [ -z "$RESTART"  ]
then
     log_job_run.ksh >> ${JOBLOGNAME}
fi

rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}

logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End   "$(date)
echo "    End    ${JOBNAME}   "$(date)        >> ${JOBLOGNAME}

#############################################################################################
#  END                                                                     
#############################################################################################
