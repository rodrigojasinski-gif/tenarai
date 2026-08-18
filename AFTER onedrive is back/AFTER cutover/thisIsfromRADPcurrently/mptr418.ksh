#!/bin/ksh
 . race_oem.ksh
#$Id: mptr418.ksh,v 1.5 2016/02/18 01:35:03 pg2697 Exp $
#***************************************************************************
# Job Description: RACE OEM Parts Update: INF 066 CA
#***************************************************************************
#***************************************************************************
#   This UPDATE process is comprised of several shell scripts.
#   When a restart is required, the Restart Stepname is passed in as $1.
#   RESTART=$1  When provided, it is the name of the step to RESTART in.
#          If not provided, null is assigned and has no effect.
#   Once the restart step is found, the return code will be 0 AND
#   subsequent shells need to have all of their steps run.  To do this, the
#   RESTART value is set to null in the environment.
#
export RESTART=$1
echo "    Start  ${JOBNAME}   "$(date) >> ${JOBLOGNAME}
logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)
#---------------------------------------------------------------------------------------------
exec_restart.ksh oem_upd_prep.ksh ${RESTART} >> ${JOBLOGNAME}
RETURN_CODE=$?
if [ -n "${RESTART}" ] && [ "${RETURN_CODE}" = "0" ]
then
   echo "Unset environment variable RESTART=${RESTART}\n\n" >> ${JOBLOGNAME}
   export RESTART=''
fi
exec_restart.ksh oem_upd.ksh ${RESTART} >> ${JOBLOGNAME}
RETURN_CODE=$?
if [ -n "${RESTART}" ] && [ "${RETURN_CODE}" = "0" ]
then
   echo "Unset environment variable RESTART=${RESTART}\n\n" >> ${JOBLOGNAME}
   export RESTART=''
fi
#---------------------------------------------------------------------------------------------
#---------------------------------  Supersession Validation  ---------------------------------
oem_job_status_update.ksh "R" "${JOBNAME}  Begin oem_rpt_validate_supers.ksh" >> ${JOBLOGNAME}
exec_restart.ksh oem_rpt_validate_supers.ksh ${RESTART} >> ${JOBLOGNAME}
RETURN_CODE=$?
if [ "${RETURN_CODE}" = "0" ]
then
   oem_job_status_update.ksh "C" "${JOBNAME}  Supersession Validation Complete" >> ${JOBLOGNAME}
fi
#---------------------------------------------------------------------------------------------
rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}

logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End   "$(date)
echo "    End    ${JOBNAME}   "$(date) >> ${JOBLOGNAME}
#***************************************************************************
# END
#***************************************************************************