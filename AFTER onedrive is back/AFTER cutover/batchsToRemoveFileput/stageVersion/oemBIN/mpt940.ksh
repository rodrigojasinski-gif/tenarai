#!/bin/ksh
echo "RCS $Id: mpt940.ksh,v 1.4 2008/10/09 22:41:25 jw97143 Exp $"
set -xv
######################################################################################
#  "On Demand" Supersession Analysis running pkg_oem_rpt_validate_supers
#  This shell has 3 steps:
#       1.  Query the oem_job table finding validate_supersessions_flag = 'Y'
#           and create a temporary work file containing Reformat Job, Update Job, and
#           OEM_Country.
#       2a. For each requested Update Job, run oem_rpt_validate_supers.ksh.
#       2b. Set the validate_supersessions_flag to 'N' 
#       3.  Remove temporary files
#
#######################################################################################
trap 'oem_abndalrt.ksh $?' err
export PROCNAME=$(basename $0 .ksh_run)
export MPTUSERID=`cat ${RACE}/prm/zmptpass.prm`
export JOBLOGNAME=${RACE}/log/$(logname.ksh ${JOBNAME}_validate_supers_${MASTER_JOBNAME} $1)
#######################################################################################


#STEP Step010
  export STEPNAME=Step010
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  #************************************************************************************
  #  1. Query the oem_job table finding validate_supersessions_flag = 'Y'
  #     and create a temporary work file containing Reformat Job, Update Job, and
  #     OEM_Country.
  #************************************************************************************
  WORKFILE_VALIDATION_JOBS=${MASTER_JOBNAME}_validate_supers_list.tmp

#--------------------------------------------------------------------------------------
(sqlplus -s << % 2>&1)
${MPTUSERID}
SET VERIFY OFF
SET FEEDBACK OFF
SET TAB OFF
SET LINESIZE 100
SET PAGES 0
SET TRIMSPOOL ON
whenever sqlerror exit sql.sqlcode
    exec pkg_oem_job.p_oem_job_sel_02(p_reformat_job  => '${MASTER_JOBNAME}',           \
                                      p_tmp_directory => '${OBJ_TMPDIR}',               \
                                      p_tmp_filename  => '${WORKFILE_VALIDATION_JOBS}', \
                                      p_log_directory => '${OBJ_LOGDIR}',               \
                                      p_log_filename  => '${MASTER_LOGNAME}');
QUIT;
%
#--------------------------------------------------------------------------------------

#STEP Step020
  export STEPNAME=Step020
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  #************************************************************************************
  #  2a. For each requested Update Job, run oem_rpt_validate_supers.ksh.
  #  2b. Set the validate_supersessions_flag to 'N'
  #************************************************************************************
  export VALIDATION_JOBS_FILE_SEQUENCE=1
  while true
  do
    #**********************************************************************************************************
    # When ${UPDATEJOB} has no length,then VALIDATION_JOBS_FILE_SEQUENCE exceeds the number of lines in file... get out!
    export REFORMATJOB=`sed -n -e "${VALIDATION_JOBS_FILE_SEQUENCE}p"     < ${RACE}/tmp/${WORKFILE_VALIDATION_JOBS}| cut -f1  -d"^"`
    export UPDATEJOB=`sed -n -e "${VALIDATION_JOBS_FILE_SEQUENCE}p"       < ${RACE}/tmp/${WORKFILE_VALIDATION_JOBS}| cut -f2  -d"^"`
    export JOBFILE_OEMCTRY=`sed -n -e "${VALIDATION_JOBS_FILE_SEQUENCE}p" < ${RACE}/tmp/${WORKFILE_VALIDATION_JOBS}| cut -f3  -d"^"`
    if [ -z "${UPDATEJOB}" ]
    then
      break
    else
      export JOBNAME=${UPDATEJOB}
      REFORMAT_FILEIN=$(setgdg.ksh "${RACE}/dat/${REFORMATJOB}_ref_${JOBFILE_OEMCTRY}.dat(0)")
      if [ -f ${REFORMAT_FILEIN} ]
      then
        export JOBLOGNAME=${RACE}/log/$(logname.ksh ${JOBNAME}_validate_supers_${MASTER_JOBNAME} $1)
        echo "\n\n**********************************************************************************************"
        #---------------------------------------------------------------------------------------------
        echo "\n\nSTART ---> ${JOBNAME} Launched by ${MASTER_JOBNAME} "$(date +'%m/%d/%y %H:%M:%S') >> ${JOBLOGNAME}        
        exec_restart.ksh oem_rpt_validate_supers.ksh >> ${JOBLOGNAME}        
        echo " END  ---> ${JOBNAME} Launched by ${MASTER_JOBNAME} "$(date +'%m/%d/%y %H:%M:%S') >> ${JOBLOGNAME}
        #---------------------------------------------------------------------------------------------
        echo "**********************************************************************************************\n\n"
      else
        echo "\n\n**********************************************************************************************"     
        echo "  Unable to Validate Supersessions for ${UPDATEJOB} File was NOT found: ${REFORMAT_FILEIN}"       
        echo "**********************************************************************************************\n\n"
      fi
#------------------------------------------------------------------------------------------------
# Set the flag to 'N' after the validation is complete
(sqlplus -s << % 2>&1)
${MPTUSERID}
SET ECHO ON;
SET FEEDBACK OFF;
SET VERIFY ON;
SET LINESIZE 80;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode
    exec pkg_oem_job.p_oem_job_upd_02(p_update_job          => '${UPDATEJOB}',      \
                                      p_log_directory       => '${OBJ_LOGDIR}',     \
                                      p_log_filename        => '${MASTER_LOGNAME}', \
                                      p_validate_super_flag => 'N' );
QUIT;
%
#------------------------------------------------------------------------------------------------
      VALIDATION_JOBS_FILE_SEQUENCE=`expr ${VALIDATION_JOBS_FILE_SEQUENCE} + 1`
    fi
  done


#STEP Step999R
  export STEPNAME=Step999R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  #**************************************************************************************
  #  3.  Remove temporary files
  #**************************************************************************************
  rm -f ${RACE}/tmp/${MASTER_JOBNAME}*


#****************************************************************************************
# END mpt940.ksh
#****************************************************************************************
