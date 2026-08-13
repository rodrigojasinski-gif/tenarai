#!/bin/ksh
echo "RCS $Id: mpt999.ksh,v 1.4 2017/03/09 22:28:36 pg2697 Exp $"
set -xv
export PROCNAME=$(basename $0 .ksh_run)
trap 'abndalrt.ksh $?' err
#############################################################################################
# SCRIPT NAME: mpt999.ksh 
# SCRIPT DESC: Change effective date from one value to another value in various database 
#              tables to correct wrong date used for reformat (and update) runs.
#############################################################################################
  export MPTUSERID=`cat ${RACE}/prm/zmptpass.prm`
  export LOGFILE=$(basename ${JOBLOGNAME})
  
#STEP Step010R 
  export STEPNAME=Step010R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S') 
  ##########################################################################
  # STEP NAME:  Step010R
  # STEP DESC:  FIX DATES AFFECTED BY OEM UPDATE 
  ##########################################################################
  export MPTUSERID=`cat ${RACE}/prm/zmptpass.prm`    
    
  export PARMFILE=mpt999_oem_fix_date.prm
  export CNTLRPT=${JOBNAME}a_fixdates_$(date +'%C%y%m%d%H%M%S').rpt    
    
sqlplus << CODE_BLOCK 2>&1 > $LOG
$MPTUSERID
SET LINESIZE 120;
SET SERVEROUTPUT ON FORMAT WRAPPED;
whenever sqlerror exit sql.sqlcode
    exec pkg_oem_fix_run.p_fix_eff_dates(p_in_prm_dirname  => '${OBJ_PRMDIR}', \
                                            p_in_prm_filename => '${PARMFILE}', \
                                            p_in_rpt_dirname  => '${OBJ_RPTDIR}', \
                                            p_in_rpt_filename => '${CNTLRPT}');   
QUIT;
CODE_BLOCK

#STEP Step020R 
  export STEPNAME=Step020R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S') 
  ##########################################################################
  # STEP NAME:  Step020R
  # STEP DESC:  Email report and retain copies
  ##########################################################################

  email_rpt.ksh "${JOBNAME}a"  
  rpt_log_retention.ksh "${JOBNAME}a" 
    
#####################################################################
# End Script
#####################################################################
