#!/bin/ksh
echo "RCS $Id: oem_rpt_source_file_status.ksh,v 1.4 2016/02/18 01:29:05 pg2697 Exp $"
set -xv
export PROCNAME=$(basename $0 .ksh_run)
trap 'abndalrt.ksh $?' err
#############################################################################################
# SCRIPT NAME: oem_rpt_source_file_status.ksh
# SCRIPT DESC: Source File Status Report
#              Identify OEMs whose files have not been received since the last extract but
#              are expected.
#############################################################################################
export MPTUSERID=`cat ${RACE}/prm/zmptpass.prm`
export LOGFILE=$(basename ${JOBLOGNAME})

#STEP Step010R
export STEPNAME=Step010R
echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')
  ##########################################################################
  # STEP NAME:  Step010R
  # STEP DESC:  Execute pkg_oem_rpt_source_file_status
##########################################################################
export RPT_NAME=${JOBNAME}a_src_file_status_$(date +'%C%y%m%d%H%M%S').rpt

sqlplus << CODE_BLOCK 2>&1 > $LOG
$MPTUSERID
SET LINESIZE 120;
SET SERVEROUTPUT ON FORMAT WORD_WRAPPED; 
whenever sqlerror exit sql.sqlcode
    exec pkg_oem_rpt_source_file_status.p_main_procedure(p_in_report_directory   => '${OBJ_RPTDIR}',  \
                                                         p_in_report_filename    => '${RPT_NAME}');
QUIT;
CODE_BLOCK

email_rpt.ksh "${JOBNAME}a" 
rpt_log_retention.ksh "${JOBNAME}a"               

########################################################################################
# END oem_rpt_source_file_status.ksh
########################################################################################
