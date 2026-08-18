#!/bin/ksh
set -xv
#*****************************************************************************************
# PROCNAME xpt960.ksh                                            
# PURPOSE: Update MX part in lines where different from the VALUE_FROM country part
#           This is done for every MFR for which the assoc'd MX Part Supplier does 
#           not send supersessions.
#*****************************************************************************************
trap 'abndalrt.ksh $?' err
export PROCNAME=$(basename $0 .ksh_run)
export LOGFILE=$(basename ${JOBLOGNAME})
export MPTUSERID=`cat ${RACE}/prm/zmptpass.prm`

#STEP Step010R
  export STEPNAME=Step010R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n" 
  ##########################################################################
  # STEP NAME:  Step010R
  # STEP DESC:  Execute Oracle procedure to analyze and update part lines                                   
  ##########################################################################

 DTLREPORT_FILE=${JOBNAME}a_mx_part_sync_dtl_$(date +'%C%y%m%d%H%M%S').rpt
 SUMREPORT_FILE=${JOBNAME}b_mx_part_sync_sum_$(date +'%C%y%m%d%H%M%S').rpt

(sqlplus -s << CODE_BLOCK 2>&1)
${MPTUSERID}

SET ECHO ON;
SET FEEDBACK OFF;
SET VERIFY ON;
SET LINESIZE 200;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

  exec pkg_oem_mx_part_sync.p_main(p_dtlreport_directory => '${OBJ_RPTDIR}', \
        p_dtlreport_filename     => '${DTLREPORT_FILE}', \
        p_sumreport_directory    => '${OBJ_RPTDIR}', \
        p_sumreport_filename     => '${SUMREPORT_FILE}' );

QUIT;
CODE_BLOCK

	 
#STEP Step020R
  export STEPNAME=Step020R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME} - Report Distribution - " $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  #**************************************************************************************
  #  Emails and Handles Retention for Report(s) created in previous step  
  #**************************************************************************************
  email_rpt.ksh "${JOBNAME}a"               
  rpt_log_retention.ksh "${JOBNAME}a" 
 
  email_rpt.ksh "${JOBNAME}b"               
  rpt_log_retention.ksh "${JOBNAME}b"  


     
#STEP Step999R
  export STEPNAME=Step999R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')
  ##########################################################################
  # STEP NAME:  Step999R
  # STEP DESC:  Removes job-related temporary files
  ##########################################################################
  rm -rf ${RACE}/tmp/${JOBNAME}*
  

#*****************************************************************************************
# END xpt960.ksh
#*****************************************************************************************
