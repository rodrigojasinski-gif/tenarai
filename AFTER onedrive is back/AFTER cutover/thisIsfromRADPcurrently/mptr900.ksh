#!/bin/ksh
. race_oem.ksh
#$Id: mptr900.ksh,v 1.3 2016/01/12 00:15:23 pg2697 Exp $
#####################################################################
# Job Name: mptr900
# Job Desc: OEM Source File Status Report
#####################################################################
export RESTART=$1
export START_TIME=`date +%c`

echo "    Start  ${JOBNAME}   "$(date) >> ${JOBLOGNAME}
logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)

exec_restart.ksh oem_rpt_source_file_status.ksh ${RESTART} >> ${JOBLOGNAME}

#turn on after NextGen Deployment#########
#if [ -z "$RESTART"  ]
#then
#     log_job_run.ksh >> ${JOBLOGNAME}
#fi

rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}

logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End   "$(date)
echo "    End    ${JOBNAME}   "$(date) >> ${JOBLOGNAME}

#####################################################################
# END
#####################################################################