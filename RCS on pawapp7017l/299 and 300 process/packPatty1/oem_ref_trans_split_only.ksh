#!/bin/ksh
echo "RCS $Id: oem_ref_trans_split_only.ksh,v 1.8 2020/08/26 00:54:59 pg2697 Exp $"
set -xv
print ProcessId = $$
#****************************************************************************************
#      NOTE:  This script is very similiar to oem_ref_trans_check_and_split.ksh
#             Changes should be considered in oem_ref_trans_check_and_split.ksh.
#****************************************************************************************
trap 'oem_abndalrt.ksh $?' err
export PROCNAME=$(basename $0 .ksh_run)
export MPTUSERID=`cat ${RACE}/prm/zmptpass.prm`
export LOGFILE=$(basename ${JOBLOGNAME})
#****************************************************************************************
#  Build environment variables for the job (based on jobname)
#****************************************************************************************
. oem_job.ksh
#****************************************************************************************

#****************************************************************************************
#  Two Reformat Jobs ran after another OEMs Reformat using that Reformat file as input:
#  1. Canada Lexus    (065 CA - mptr497) uses Canada Toyotas (044 CA - mptr495) file
#  2. Canada Infiniti (066 CA - mptr418) uses Canada Nissans (030 CA - mptr415) file
#****************************************************************************************
WORKFILE=${JOBNAME}_oem_job_datafile.tmp
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
    exec pkg_oem_job_datafile.p_oem_job_datafile_sel_03(p_reformat_job  => '${REFORMATJOB}', \
                                                        p_file_sequence => '1',              \
                                                        p_tmp_directory => '${OBJ_TMPDIR}',  \
                                                        p_tmp_filename  => '${WORKFILE}',    \
                                                        p_log_directory => '${OBJ_LOGDIR}',  \
                                                        p_log_filename  => '${LOGFILE}');
QUIT;
%
#----------------------------------------------------------------------------------------
WORKFILE=${RACE}/tmp/${WORKFILE}
export INPUT_FILE_NAME=`sed -n -e "1p" < ${WORKFILE}| cut -f1 -d"^"`


#**********************************************************************************************
#STEP Step250R
  export STEPNAME=Step250R
  echo "    Start " ${STEPNAME} "    "$(date)
  oem_job_status_update.ksh "R" "${STEPNAME} pkg_oem_upd_utilities.p_electronic_balancing_check"
  #********************************************************************************************
  # Check p_electronic_balancing_check
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
    exec pkg_oem_upd_utilities.p_electronic_balancing_check(p_jobtype         => 'R',            \
                                                            p_jobname         => '${JOBNAME}',   \
                                                            p_log_directory   => '${OBJ_LOGDIR}',\
                                                            p_log_filename    => '${LOGFILE}',   \
                                                            p_input_directory => '${OBJ_PRMDIR}',\
                                                            p_input_filename  => '${JOBPARM}.prm');
QUIT;
%
#----------------------------------------------------------------------------------------------


#STEP Step260R
  export STEPNAME=Step260R
  print "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Save 3 Generations of Reformat Transaction File"
  #**************************************************************************************
  #   Save 3 generations reformat file
  #**************************************************************************************
  INPUT_FILE=$(setgdg.ksh "${RACE}/dat/${INPUT_FILE_NAME}")
  OUTPUT_FILE=$(setgdg.ksh "${RACE}/dat/${JOBNAME}_ref_${JOBFILE_OEMCTRY}.dat(+01)" NEW 3)

  cp ${INPUT_FILE} ${OUTPUT_FILE}


#STEP Step300R
  export STEPNAME=Step300R
  print "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} mptz021 Transaction Split Processing"
  #**************************************************************************************
  #  Executes mptz021 - Transaction Split Program
  #                     Two reformat jobs alway ran after another OEMs reformat and use that OEMs
  #                     "ref" file as input.
  #                     Canada Lexus    uses Canada Toyotas file
  #                     Canada Infiniti uses Canada Nissans file
  #**************************************************************************************
  export DD_PARMSIN=${RACE}/prm/${JOBPARM}.prm
  export DD_TRANSIN=$(setgdg.ksh "${RACE}/dat/${JOBNAME}_ref_${JOBFILE_OEMCTRY}.dat(0)")

  export DD_ATRANS=${RACE}/dat/${JOBNAME}_atrans.tmp
  export DD_CTRANS=${RACE}/dat/${JOBNAME}_ctrans.tmp
  export DD_NTRANS=${RACE}/dat/${JOBNAME}_ntrans.tmp
  export DD_DTRANS=${RACE}/dat/${JOBNAME}_dtrans.tmp
  export DD_PTRANS=${RACE}/dat/${JOBNAME}_ptrans.tmp
  export DD_CNTLRPT=${RACE}/rpt/${JOBNAME}s_splt${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt
  
  mptz021 2>&1

  #STEP Step301R
  export STEPNAME=Step301R
  print "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Report Distribution"
  #**************************************************************************************
  #  Emails and Handles Retention for Report(s) created in previous step  
  #**************************************************************************************
  email_rpt.ksh "${JOBNAME}s"  
  rpt_log_retention.ksh "${JOBNAME}s" 
     
        
#STEP Step999R
  export STEPNAME=Step999R
  print "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "P" "${STEPNAME} Reformat Job Complete"
  #**************************************************************************************
  #  Removes job temporary files
  #**************************************************************************************
  rm -f ${RACE}/tmp/${JOBNAME}*


#****************************************************************************************
# END oem_ref_trans_split_only.ksh
#****************************************************************************************
