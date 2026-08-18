#!/bin/ksh
echo "RCS $Id: oem_upd_price_pr_factor.ksh,v 1.6 2024/08/05 21:19:48 pg2697 Exp $"
set -xv
print ProcessId = $$
#****************************************************************************************
# OEM Batch Update Job for Puerto Rico
#****************************************************************************************
trap 'oem_abndalrt.ksh $?' err
export PROCNAME=$(basename $0 .ksh_run)
#****************************************************************************************
#  Build environment variables for the job (based on jobname)
#****************************************************************************************
. oem_job.ksh         
#****************************************************************************************


#STEP Step140R
  export STEPNAME=Step140R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Executes mptz026 - Pricing Update Program"
  #**************************************************************************************
  #                                          Executes mptz026 - Pricing Update Program
  #**************************************************************************************
  export DD_PARMSIN=${RACE}/prm/${JOBPARM}.prm
  export DD_TRANSIN=${RACE}/dat/${REFORMATJOB}_ptrans.tmp
  export DD_CNTLRPT=${RACE}/rpt/${JOBNAME}h_pupd${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt

    mptz026 2>&1

    email_rpt.ksh "${JOBNAME}h" 
    rpt_log_retention.ksh "${JOBNAME}h"   

    
#STEP Step200R
  export STEPNAME=Step200R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Executes mptz007 - Update Report Program"
  #**************************************************************************************
  #                                          Executes mptz007 - Update Report Program
  #**************************************************************************************
  export DD_PARMSIN=${RACE}/prm/${JOBPARM}.prm
   
  export DD_RPT01=${RACE}/rpt/${JOBNAME}i_err${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt
  export DD_RPT02A=${RACE}/rpt/${JOBNAME}j_cmlt${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt
  export DD_RPT02B=${RACE}/rpt/${JOBNAME}p_wmlt${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt
  export DD_RPT03=${RACE}/rpt/${JOBNAME}k_pvar${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt
  export DD_RPT04A=${RACE}/rpt/${JOBNAME}n_ctl${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt
  export DD_RPT04B=${RACE}/rpt/${JOBNAME}l_act${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt
  export DD_RPT05A=${RACE}/rpt/${JOBNAME}m_czpr${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt
  export DD_RPT05B=${RACE}/rpt/${JOBNAME}o_wzpr${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt

  mptz007 2>&1

  #STEP Step201R
  export STEPNAME=Step201R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Report Distribution"
  #**************************************************************************************
  #  Emails and Handles Retention for Report(s) created in previous step  
  #**************************************************************************************
    email_rpt.ksh "${JOBNAME}i" 
    rpt_log_retention.ksh "${JOBNAME}i" 

    email_rpt.ksh "${JOBNAME}j"
    rpt_log_retention.ksh "${JOBNAME}j"     

    email_rpt.ksh "${JOBNAME}p"
    rpt_log_retention.ksh "${JOBNAME}p" 

    email_rpt.ksh "${JOBNAME}k"
    rpt_log_retention.ksh "${JOBNAME}k" 

    email_rpt.ksh "${JOBNAME}n"
    rpt_log_retention.ksh "${JOBNAME}n" 

    email_rpt.ksh "${JOBNAME}l" 
    rpt_log_retention.ksh "${JOBNAME}l" 

    email_rpt.ksh "${JOBNAME}m" 
    rpt_log_retention.ksh "${JOBNAME}m" 
 
    email_rpt.ksh "${JOBNAME}o"
    rpt_log_retention.ksh "${JOBNAME}o"


#STEP Step205R
  export STEPNAME=Step205R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} pkg_oem_upd_price_pr_factor"
  #*****************************************************************************************
  #                                  Execute pkg_oem_upd_price_pr_factor
  #*****************************************************************************************
  INPUT_FILENAME=${RACE}/dat/${REFORMATJOB}_ptrans.tmp
  REPORT_FILENAME=/${JOBNAME}s_pf${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt

#----------------------------------------------------------------------------------------
(sqlplus -s << % 2>&1)
${MPTUSERID}
SET VERIFY OFF
SET FEEDBACK OFF
SET TAB OFF
SET LINESIZE 100
SET PAGES 0
SET TRIMSPOOL ON
whenever sqlerror exit sql.sqlcode
    exec pkg_oem_upd_price_pr_factor.p_main_procedure(p_update_job         => '${JOBNAME}',          \
                                                      p_log_directory      => '${OBJ_LOGDIR}',       \
                                                      p_log_filename       => '${LOGFILE}',          \
                                                      p_input_directory    => '${OBJ_DATDIR}',       \
                                                      p_input_filename     => '${INPUT_FILENAME}',   \
                                                      p_report_directory   => '${OBJ_RPTDIR}',       \
                                                      p_report_filename    => '${REPORT_FILENAME}',  \
                                                      p_debug_level        => '${RACE_DEBUG_LEVEL}', \
                                                      p_dbms_profiler_flag => '${RACE_DBMS_PROFILER_FLAG}');
QUIT;
%
#----------------------------------------------------------------------------------------

    email_rpt.ksh "${JOBNAME}s"
    rpt_log_retention.ksh "${JOBNAME}s" 

    
#STEP Step210R
   export STEPNAME=Step210R
   echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
   oem_job_status_update.ksh "R" "${STEPNAME} Delete workfiles"
   #*****************************************************************************************
   #                                          Delete workfiles
   #*****************************************************************************************
   rm -f ${RACE}/dat/${JOBNAME}*.tmp* &
   rm -f ${RACE}/tmp/${JOBNAME}*      &
   rm -f ${RACE}/dat/${REFORMATJOB}_*trans.tmp


#********************************************************************************************
# END oem_upd_price_pr_factor.ksh
#********************************************************************************************
