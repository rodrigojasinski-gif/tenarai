#!/bin/ksh
echo "RCS $Id: oem_rpt_service_records.ksh,v 1.5 2016/02/18 01:29:01 pg2697 Exp $"
set -xv
print ProcessId = $$
trap 'oem_abndalrt.ksh $?' err
#****************************************************************************************
#  Build environment variables for the job (based on jobname)
#****************************************************************************************
. oem_job.ksh
#****************************************************************************************


#STEP Step040R
STEPNAME=Step040R
echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
oem_job_status_update.ksh "R" "${STEPNAME} pkg_oem_rpt_service_records"
#****************************************************************************************
#                                          pkg_oem_rpt_service_records
#****************************************************************************************
REPORT_FILE=${JOBNAME}e_lst${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt

#----------------------------------------------------------------------------------------
(sqlplus -s << % 2>&1)
${MPTUSERID}
SET ECHO ON;
SET FEEDBACK OFF;
SET VERIFY ON;
SET LINESIZE 80;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode
    exec pkg_oem_rpt_service_records.p_main_procedure(p_reformat_job       => '${REFORMATJOB}',           \
                                                      p_log_directory      => '${OBJ_LOGDIR}',            \
                                                      p_log_filename       => '${LOGFILE}',               \
                                                      p_report_directory   => '${OBJ_RPTDIR}',            \
                                                      p_report_filename    => '${REPORT_FILE}',           \
                                                      p_debug_level        => '${RACE_DEBUG_LEVEL}',      \
                                                      p_dbms_profiler_flag => '${RACE_DBMS_PROFILER_FLAG}');
QUIT;
%
#----------------------------------------------------------------------------------------


#STEP Step041R
  export STEPNAME=Step041R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "P" "${STEPNAME} Report Distribution"
  #**************************************************************************************
  #  Emails and Handles Retention for Report(s) created in previous step  
  #**************************************************************************************
##uuencode ${RACE}/rpt/${REPORT_FILE} ${REPORT_FILE}|mailx -s "Report \""${JOBNAME}"\" - Service File Listing" Rpt.OEM.Srvc.Lst.Nis@mitchell.com  

  email_rpt.ksh "${JOBNAME}e" 
  rpt_log_retention.ksh "${JOBNAME}e" 

#****************************************************************************************
# END oem_rpt_service_records.ksh
#****************************************************************************************
