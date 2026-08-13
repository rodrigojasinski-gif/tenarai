#!/bin/ksh
. race_oem.ksh
#$Id: mptr999.ksh,v 1.5 2017/03/09 22:27:35 pg2697 Exp $
#####################################################################
# Job Name: mptr999 NEW VERSION
# Job Desc: OEM Fix Effective Dates
#
# Scenario: OEM sent file which we processed with 01/01/2016 date.
#           OEM later sends email noting that the file is really 
#           effective 01/10/2016. 
#
# START_TIME is captured for use in log_job_run.ksh
#####################################################################
export RESTART=$1
export START_TIME=`date +%c`                                         

echo "    Start  ${JOBNAME}   "$(date) >> ${JOBLOGNAME}
logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)
         
exec_restart.ksh mpt999.ksh ${RESTART} >> ${JOBLOGNAME}

if [ -z "$RESTART"  ]
then
     log_job_run.ksh >> ${JOBLOGNAME}
fi

rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}

logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End   "$(date)
echo "    End    ${JOBNAME}   "$(date) >> ${JOBLOGNAME}

############################################################################
#  END                                                                     #
############################################################################
