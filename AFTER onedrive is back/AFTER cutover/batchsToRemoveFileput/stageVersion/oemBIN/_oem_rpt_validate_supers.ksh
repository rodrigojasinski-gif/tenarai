#!/bin/ksh
echo "RCS $Id: oem_rpt_validate_supers.ksh,v 1.14 2020/08/26 00:55:48 pg2697 Exp $"
#set -xv
print ProcessId = $$
#****************************************************************************************
#  Description: Run process to validate supersessions and create reports
#****************************************************************************************
trap 'oem_abndalrt.ksh $?' err
export PROCNAME=$(basename $0 .ksh_run)
#****************************************************************************************
#  Build environment variables for the job (based on jobname)
#****************************************************************************************
. oem_job.ksh
#****************************************************************************************

#STEP Step510
  export STEPNAME=Step510
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Extract the P and N records"
  #**************************************************************************************
  #                                          Extract the P and N records
  #**************************************************************************************
  REFORMAT_WORKOUT=${RACE}/tmp/${JOBNAME}_step510_oemrecs.tmp
  if [ ${JOBNAME} = ${REFORMATJOB} ]
  then
     #**************************************************************************************
     # Reformat Job? Only extract N records (From Step216R)
     #**************************************************************************************
     REFORMAT_FILEIN=${RACE}/tmp/${JOBNAME}_step216_ref_${JOBFILE_OEMCTRY}.tmp
     awk '{ if (substr($0,1,1)=="N") print $0 }' ${REFORMAT_FILEIN} > ${REFORMAT_WORKOUT}
  else
     #**************************************************************************************
     # Update Job? Only extract N and P records
     #**************************************************************************************
     REFORMAT_FILEIN=$(setgdg.ksh "${RACE}/dat/${REFORMATJOB}_ref_${JOBFILE_OEMCTRY}.dat(0)")
     awk '{ if (substr($0,1,1)=="P") print $0 }' ${REFORMAT_FILEIN} >  ${REFORMAT_WORKOUT}
     awk '{ if (substr($0,1,1)=="N") print $0 }' ${REFORMAT_FILEIN} >> ${REFORMAT_WORKOUT}
  fi


#STEP Step515
  export STEPNAME=Step515
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Sort unique"
  #**************************************************************************************
  #                                          Sort unique 
  #**************************************************************************************
  SORTFILE_FILEIN=${RACE}/tmp/${JOBNAME}_step510_oemrecs.tmp
  SORT_FILEOUT=${RACE}/tmp/${JOBNAME}_step515_oemrecs_sort.tmp
  rm -f $SORT_FILEOUT
  #      +----------+
  #      |OLD & NEW |
  #      +----------+
  sort -u -k1.7,1.56 -o ${SORT_FILEOUT} ${SORTFILE_FILEIN}


#STEP Step530
  export STEPNAME=Step530
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} pkg_oem_rpt_validate_supers"
  #**************************************************************************************
  #                                          pkg_oem_rpt_validate_supers
  #  Execute Supersession Validation Program - Check the chains for loops
  #                                            and for "middle" parts with pricing
  #**************************************************************************************
  INPUT_FILENAME=${JOBNAME}_step515_oemrecs_sort.tmp
  OUTPUT_HTRANS=${JOBNAME}_step530_htrans_${JOBFILE_OEMCTRY}.tmp
  OUTPUT_PTRANS=${JOBNAME}_step530_ptrans_${JOBFILE_OEMCTRY}.tmp
  OUTPUT_RTRANS=${JOBNAME}_step530_rtrans_${JOBFILE_OEMCTRY}.tmp
  OUTPUT_NTRANS=${JOBNAME}_step530_ntrans_${JOBFILE_OEMCTRY}.tmp    # Used when checking for loops OEM Reformat File

  if [ ${JOBNAME} = ${REFORMATJOB} ]
  then
    REPORT_FILENAME=${JOBNAME}n_sup${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt
  else
    REPORT_FILENAME=${JOBNAME}a_sup${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt
  fi

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
    exec pkg_oem_rpt_validate_supers.p_main_procedure(p_this_job           => '${JOBNAME}',          \
                                                      p_reformat_job       => '${REFORMATJOB}',      \
                                                      p_log_directory      => '${OBJ_LOGDIR}',       \
                                                      p_log_filename       => '${LOGFILE}',          \
                                                      p_input_directory    => '${OBJ_TMPDIR}',       \
                                                      p_input_filename     => '${INPUT_FILENAME}',   \
                                                      p_output_directory   => '${OBJ_TMPDIR}',       \
                                                      p_output_htrans      => '${OUTPUT_HTRANS}',    \
                                                      p_output_ptrans      => '${OUTPUT_PTRANS}',    \
                                                      p_output_rtrans      => '${OUTPUT_RTRANS}',    \
                                                      p_output_ntrans      => '${OUTPUT_NTRANS}',    \
                                                      p_report_directory   => '${OBJ_RPTDIR}',       \
                                                      p_report_filename    => '${REPORT_FILENAME}',  \
                                                      p_debug_level        => '${RACE_DEBUG_LEVEL}', \
                                                      p_dbms_profiler_flag => '${RACE_DBMS_PROFILER_FLAG}');
QUIT;
%
#----------------------------------------------------------------------------------------


#STEP Step531R
  export STEPNAME=Step531R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Report Distribution"
  #**************************************************************************************
  #  Emails and Handles Retention for Report(s) created in previous step  
  #**************************************************************************************
  if [ ${JOBNAME} = ${REFORMATJOB} ]
  then
    email_rpt.ksh "${JOBNAME}n"
    rpt_log_retention.ksh "${JOBNAME}n" 
    
  else
    email_rpt.ksh "${JOBNAME}a" 
    rpt_log_retention.ksh "${JOBNAME}a" 
  fi


#STEP Step570
  export STEPNAME=Step570
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Save files"
  #**************************************************************************************
  #   REFORMAT - Save ntrans
  #   UPDATE   - Save rtrans, htrans, and ptrans files
  #**************************************************************************************
  if [ ${JOBNAME} = ${REFORMATJOB} ]
  then
               cp ${RACE}/tmp/${JOBNAME}_step530_ntrans_${JOBFILE_OEMCTRY}.tmp \
    $(setgdg.ksh "${RACE}/dat/${JOBNAME}_looping_oem_ntrans_${JOBFILE_OEMCTRY}.dat(+1)" NEW 3)
  else
               cp ${RACE}/tmp/${JOBNAME}_step530_htrans_${JOBFILE_OEMCTRY}.tmp \
    $(setgdg.ksh "${RACE}/dat/${JOBNAME}_validate_htrans_${JOBFILE_OEMCTRY}.dat(+1)" NEW 3)
               cp ${RACE}/tmp/${JOBNAME}_step530_rtrans_${JOBFILE_OEMCTRY}.tmp \
    $(setgdg.ksh "${RACE}/dat/${JOBNAME}_validate_rtrans_${JOBFILE_OEMCTRY}.dat(+1)" NEW 3)
               cp ${RACE}/tmp/${JOBNAME}_step530_ptrans_${JOBFILE_OEMCTRY}.tmp \
    $(setgdg.ksh "${RACE}/dat/${JOBNAME}_validate_ptrans_${JOBFILE_OEMCTRY}.dat(+1)" NEW 3)
  fi


#STEP Step599
  export STEPNAME=Step599
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  #************************************************************************************************
  #  Delete temporary datasets 
  #************************************************************************************************
  if [ ${JOBNAME} = ${REFORMATJOB} ]
  then
    rm -f ${RACE}/tmp/${JOBNAME}_step5*
  else
    rm -f ${RACE}/tmp/${JOBNAME}*
  fi
  
#**************************************************************************************************
# END oem_rpt_validate_supers.ksh
#**************************************************************************************************
