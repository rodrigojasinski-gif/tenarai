#!/bin/ksh
#$Id: oem_job_status_update.ksh,v 1.4 2008/10/09 22:18:44 jw97143 Exp $
#*****************************************************************************************
#     oem_job_status_update.ksh
#*****************************************************************************************
JOB_STATUS_INDICATOR=$1
JOB_STEP_DESCRIPTION=$2
if [ $# -lt 2 ]
then
  echo "oem_job_status_update.ksh requires input parameters"
  echo "   1. JOB_STATUS_INDICATOR"
  echo "   2. JOB_STEP_DESCRIPTION"
  oem_abndalrt.ksh oem_job_status_update.ksh.parms.are.missing
fi
#*****************************************************************************************
trap 'oem_abndalrt.ksh $?' err
MPTUSERID=`cat ${RACE}/prm/zmptpass.prm`
LOGFILE=$(basename ${JOBLOGNAME})
#*****************************************************************************************

#-----------------------------------------------------------------------------------------
(sqlplus -s << % 2>&1)
${MPTUSERID}
SET ECHO ON;
SET FEEDBACK OFF;
SET VERIFY ON;
SET LINESIZE 80;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode
    exec pkg_oem_job.p_oem_job_upd_01                                \
               (p_jobname              => '${JOBNAME}',              \
                p_log_directory        => '${OBJ_LOGDIR}',           \
                p_log_filename         => '${LOGFILE}',              \
                p_job_status_indicator => '${JOB_STATUS_INDICATOR}', \
                p_job_step_description => '${JOB_STEP_DESCRIPTION}');
QUIT;
%
#-----------------------------------------------------------------------------------------

#*****************************************************************************************
# END oem_job_status_update.ksh
#*****************************************************************************************
