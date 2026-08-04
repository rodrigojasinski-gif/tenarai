#!/bin/ksh
# $Id: log_job_run.ksh,v 1.1 2017/03/09 22:33:00 pg2697 Exp $
echo "RCS $Id: log_job_run.ksh,v 1.1 2017/03/09 22:33:00 pg2697 Exp $"
##set -xv                #comment out for shared utilites
trap 'abndalrt.ksh $?' err
#############################################################################################
# SCRIPT NAME: log_job_run.ksh
# SCRIPT DESC: Logs job start and end times
#     1) Execute procedure(s) to log job start and end times.
#
#############################################################################################
  export SHAREUSERID=`cat /$ACT_LVL/race/share/prm/zsharepass.prm`
  ##export LOG=$(basename ${JOBLOGNAME})

sqlplus << CODE_BLOCK 2>&1 >> $JOBLOGNAME 
$SHAREUSERID
SET SERVEROUTPUT ON FORMAT WRAPPED;
spool $JOBLOGNAME APPEND
whenever sqlerror exit sql.sqlcode
    exec pkg_job_run_log.p_log_job_run(p_in_jobname      => '${JOBNAME}', \
                        p_in_start_time   => '${START_TIME}');
QUIT;
CODE_BLOCK

#################################################################################################
# END log_job_run.ksh
#################################################################################################
