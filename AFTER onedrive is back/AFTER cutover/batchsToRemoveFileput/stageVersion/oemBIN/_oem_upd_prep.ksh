#!/bin/ksh
#$Id: oem_upd_prep.ksh,v 1.4 2008/12/08 23:23:36 jw97143 Exp $"
#**********************************************************************************************
#  oem_upd_prep.ksh
#**********************************************************************************************
set -xv
trap 'oem_abndalrt.ksh $?' err
export PROCNAME=$(basename $0 .ksh_run)
#**********************************************************************************************
#  Build environment variables for the job (based on jobname)
#**********************************************************************************************
. oem_job.ksh        
#**********************************************************************************************
#STEP Step001R
  export STEPNAME=Step001R
  echo "    Start " ${STEPNAME} "    "$(date)
  oem_job_status_update.ksh "R" "${STEPNAME} pkg_oem_upd_utilities.p_electronic_balancing_check"
  #********************************************************************************************
  # Check for correct a) Effective Date,b) Balance Comment,c) Verified Date,d) Replacement Flag
  #********************************************************************************************

#----------------------------------------------------------------------------------------------
(sqlplus -s << % 2>&1)
${MPTUSERID}
SET VERIFY OFF
SET FEEDBACK OFF
SET TAB OFF
SET LINESIZE 100
SET PAGES 0
SET TRIMSPOOL ON
whenever sqlerror exit sql.sqlcode
    exec pkg_oem_upd_utilities.p_electronic_balancing_check(p_jobtype         => 'U',            \
                                                            p_jobname         => '${JOBNAME}',   \
                                                            p_log_directory   => '${OBJ_LOGDIR}',\
                                                            p_log_filename    => '${LOGFILE}',   \
                                                            p_input_directory => '${OBJ_PRMDIR}',\
                                                            p_input_filename  => '${JOBPARM}.prm');
QUIT;
%
#----------------------------------------------------------------------------------------------

#**********************************************************************************************
# END
#**********************************************************************************************
