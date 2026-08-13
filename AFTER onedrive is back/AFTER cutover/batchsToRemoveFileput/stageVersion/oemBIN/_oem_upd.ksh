#!/bin/ksh
echo "RCS $Id: oem_upd.ksh,v 1.19 2024/08/05 21:19:07 pg2697 Exp $"
set -xv
print ProcessId = $$
#*************************************************************************************************
# PROCNAME oem_upd.ksh   OEM Update Job Script
#*************************************************************************************************
trap 'oem_abndalrt.ksh $?' err
export PROCNAME=$(basename $0 .ksh_run)
export MPTUSERID=`cat ${RACE}/prm/zmptpass.prm`
export LOGFILE=$(basename ${JOBLOGNAME})
#*************************************************************************************************
#  Build environment variables for the job (based on jobname)
#*************************************************************************************************
. oem_job.ksh
. oem_job_notify.ksh
#*************************************************************************************************

#STEP Step010R
  export STEPNAME=Step010R
  echo "    Start " ${STEPNAME} "    "$(date)
  oem_job_status_update.ksh "R" "${STEPNAME} Delete datasets"
  #***************************************************************************************
  #  Step010R - Delete datasets that will be created in future steps
  #***************************************************************************************
  rm -f ${RACE}/dat/${JOBNAME}*.tmp*
  rm -f ${RACE}/tmp/${JOBNAME}*
  

#*****************************************************************************************
#  Steps 041 thru 085 are ONLY run for jobs which require "Reverse Analysis" processing. 
#*****************************************************************************************

#STEP Step041R
  export STEPNAME=Step041R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  if [ -z "${REVERSE_SUPER_JOBPARM}" ]
  then
    echo "                Skipping ${STEPNAME} Executes pkg_oem_upd_rtrans_1_generate - Supersession Analysis Program"
  else
    oem_job_status_update.ksh "R" "${STEPNAME} Executes pkg_oem_upd_rtrans_1_generate - Supersession Analysis Program"
    #*********************************************************************************************
    #  Step041R - Executes pkg_oem_upd_rtrans_1_generate
    #             Note:  The HTRANS file doesn't go anywhere.
    #*********************************************************************************************    
    NTRANSIN=${REFORMATJOB}_ntrans.tmp
    RTRANSOUT=${JOBNAME}_rtrans_1_generate.tmp
    HTRANSOUT=${JOBNAME}_htrans_1_generate.tmp  
    REPORT_FILENAME=${JOBNAME}b_sana${REPORTSUFFIX}.rpt

#----------------------------------------------------------------------------------------
(sqlplus -s << % 2>&1)
${MPTUSERID}
SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode
    exec pkg_oem_upd_rtrans_1_generate.p_main_procedure(p_update_job           => '${JOBNAME}',          \
                                                        p_log_directory        => '${OBJ_LOGDIR}',       \
                                                        p_log_filename         => '${LOGFILE}',          \
                                                        p_ntrans_in_directory  => '${OBJ_DATDIR}',       \
                                                        p_ntrans_in_filename   => '${NTRANSIN}',         \
                                                        p_rtrans_out_directory => '${OBJ_DATDIR}',       \
                                                        p_rtrans_out_filename  => '${RTRANSOUT}',        \
                                                        p_htrans_out_directory => '${OBJ_DATDIR}',       \
                                                        p_htrans_out_filename  => '${HTRANSOUT}',        \
                                                        p_report_directory     => '${OBJ_RPTDIR}',       \
                                                        p_report_filename      => '${REPORT_FILENAME}',  \
                                                        p_debug_level          => '1',                   \
                                                        p_dbms_profiler_flag   => '${RACE_DBMS_PROFILER_FLAG}');
QUIT;
%
#----------------------------------------------------------------------------------------
    
    REPORT=$(basename $REPORT_FILENAME .rpt) 
    mv ${RACE}/rpt/${REPORT_FILENAME} ${RACE}/rpt/${REPORT}_$(date +'%C%y%m%d%H%M%S').rpt
    email_rpt.ksh "${JOBNAME}b"
    rpt_log_retention.ksh "${JOBNAME}b" 
    
  fi


#STEP Step050R
  export STEPNAME=Step050R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  if [ -z "${REVERSE_SUPER_JOBPARM}" ]
  then
    echo "                Skipping ${STEPNAME} Sort RTRANS by old part number and new part number"
  else
    oem_job_status_update.ksh "R" "${STEPNAME} Sort RTRANS by old part number and new part number"
    #*********************************************************************************************
    #  Step050R - Sort RTRANS by old part number, new part number, reason
    #             and create backup files
    #*********************************************************************************************
    SORTIN_FILE=${RACE}/dat/${JOBNAME}_rtrans_1_generate.tmp
    SORTOUT_FILE=${RACE}/dat/${JOBNAME}_rtrans_1_generate_sort.tmp
    #   +----------|-----------|-----------|
    #   | OLD PART | NEW PART  | REASON    |
    #   +----------|-----------|-----------|
    sort -k1.7,1.31 -k1.32,1.56 -k1.67,1.91r -o ${SORTOUT_FILE} ${SORTIN_FILE}
    mv               ${RACE}/dat/${JOBNAME}_rtrans_1_generate_sort.tmp \
       $(setgdg.ksh "${RACE}/dat/${JOBNAME}_rtrans_1_generate_${JOBFILE_OEMCTRY}.dat(+1)" NEW 3)
    
  fi


#STEP Step060R
  export STEPNAME=Step060R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  if [ -z "${REVERSE_SUPER_JOBPARM}" ]
  then
    echo " Skipping ${STEPNAME} Builds Combo File for loading Global Temp Table"
  else
    oem_job_status_update.ksh "R" "${STEPNAME} Builds Combo File for loading Global Temp Table"
    #*********************************************************************************************
    #  Step060R -                              Builds Combo File for loading Global Temp Table
    #             mpt_elim_dup_tran.awk keeps ONE transaction per old part number in the above order
    #*********************************************************************************************
    SORTIN_FILE="${RACE}/dat/${REFORMATJOB}_atrans.tmp \
                 ${RACE}/dat/${REFORMATJOB}_ctrans.tmp \
                 ${RACE}/dat/${REFORMATJOB}_ntrans.tmp \
                 ${RACE}/dat/${REFORMATJOB}_ptrans.tmp "
    SORTOUT_FILE=${RACE}/dat/${JOBNAME}_trans_comb.tmp
    #   +----------+               +------------------------------------------------------------+
    #   | OLD PART |               |Keep ONE Transaction per OLD Part                           |
    #   +----------+               +------------------------------------------------------------+
    sort -k1.7,1.31 ${SORTIN_FILE} | awk -f ${RACE}/bin/mpt_elim_dup_tran.awk > ${SORTOUT_FILE}
  fi


#STEP Step080R
  export STEPNAME=Step080R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  if [ -z "${REVERSE_SUPER_JOBPARM}" ]
  then
    echo "                Skipping ${STEPNAME} Delete data file"
  else
    oem_job_status_update.ksh "R" "${STEPNAME} Delete data file"
    #*********************************************************************************************
    #  Step080R -  Deletes rtrans_2 file
    #*********************************************************************************************
    rm -f ${RACE}/dat/${JOBNAME}_rtrans_2_adjust.tmp
  fi


#STEP Step085R
  export STEPNAME=Step085R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  if [ -z "${REVERSE_SUPER_JOBPARM}" ]
  then
    echo "                Skipping ${STEPNAME} - pkg_oem_upd_rtrans_2_adjust"
  else
    oem_job_status_update.ksh "R" "${STEPNAME} - pkg_oem_upd_rtrans_2_adjust"
    #*********************************************************************************************
    #  Step085R - Executes pkg_oem_upd_rtrans_2_adjust - Reverse Super Pre-Processor Program
    #*********************************************************************************************
    RTRANS_FILEPATH=$(setgdg.ksh "${RACE}/dat/${JOBNAME}_rtrans_1_generate_${JOBFILE_OEMCTRY}.dat(0)")    
    RTRANSIN=$( basename ${RTRANS_FILEPATH} )     
    NON_RTRANSIN=${JOBNAME}_trans_comb.tmp
    RTRANSOUT=${JOBNAME}_rtrans_2_adjust.tmp   
    REPORT_FILENAME=${JOBNAME}r_spre${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt

#----------------------------------------------------------------------------------------
(sqlplus -s << % 2>&1)
${MPTUSERID}
SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode
    exec pkg_oem_upd_rtrans_2_adjust.p_main_procedure(p_update_job              => '${JOBNAME}',          \
                                                      p_log_directory           => '${OBJ_LOGDIR}',       \
                                                      p_log_filename            => '${LOGFILE}',          \
                                                      p_rtrans_in_directory     => '${OBJ_DATDIR}',       \
                                                      p_rtrans_in_filename      => '${RTRANSIN}',         \
                                                      p_non_rtrans_in_directory => '${OBJ_DATDIR}',       \
                                                      p_non_rtrans_in_filename  => '${NON_RTRANSIN}',     \
                                                      p_rtrans_out_directory    => '${OBJ_DATDIR}',       \
                                                      p_rtrans_out_filename     => '${RTRANSOUT}',        \
                                                      p_report_directory        => '${OBJ_RPTDIR}',       \
                                                      p_report_filename         => '${REPORT_FILENAME}',  \
                                                      p_debug_level             => '9', \
                                                      p_dbms_profiler_flag      => '${RACE_DBMS_PROFILER_FLAG}');                            
QUIT;
%
#----------------------------------------------------------------------------------------
   
    email_rpt.ksh "${JOBNAME}r" 
    rpt_log_retention.ksh "${JOBNAME}r" 
  fi


#****************************************************************************************************
# End of Steps 041 thru 085 which are ONLY run for jobs which require "Reverse Analysis" processing. 
#****************************************************************************************************


#STEP Step105R
  export STEPNAME=Step105R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Check for rtrans file"
  #*********************************************************************************************
  #  Step105R - Check for rtrans file
  #             If not found, create it (there are some OEMs which do not send rtrans
  #             and do not run the Reverse Analysis steps which would create rtrans.)
  #*********************************************************************************************
  REFORMAT_RTRANS_FILE=${RACE}/dat/${REFORMATJOB}_rtrans.tmp
  UPDATE_RTRANS_FILE=${RACE}/dat/${JOBNAME}_rtrans_2_adjust.tmp
  ##############################################################################################
  #  Hey, something is wrong if an rtrans was created by
  #  BOTH the Reformat Program AND the Supersession Analysis program.
  ##############################################################################################
  if [ -e ${REFORMAT_RTRANS_FILE} ]
  then
    if [ -e ${UPDATE_RTRANS_FILE} ]
    then
      oem_abndalrt.ksh oem_upd_TWO_rtrans_files_found
    fi
  fi
  ##############################################################################################
  #  Use the Reformat RTRANS if found -- copy it to the Update Job's JOBNAME
  #  Use the Update RTRANS if found, otherwise, create one.
  ###############################################################################################
  if [ -e ${REFORMAT_RTRANS_FILE} ]
  then
    echo "Using RTRANS created by Reformat Program(s): ${PACKAGE_NAME_1}  ${PACKAGE_NAME_2}"
    mv ${REFORMAT_RTRANS_FILE} ${UPDATE_RTRANS_FILE}
  else
    if [ -e ${UPDATE_RTRANS_FILE} ]
    then
      echo "Using RTRANS created by Supersession Analysis/Reverse Super Pre-Processor"
    else
      echo "Creating an empty RTRANS file"
      touch ${UPDATE_RTRANS_FILE}
    fi
  fi


#STEP Step110R
  export STEPNAME=Step110R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Sorts R TRANS by: SUPR-EFF-DT Descend and OLD PART NUMBER Ascend"
  #*********************************************************************************************
  #   Step110R - Sorts R TRANS by: SUPR-EFF-DT Descend and OLD PART NUMBER Ascend.
  #              Save 3 generations reformat RTRANS.
  #*********************************************************************************************
  SORT_FILEIN=${RACE}/dat/${JOBNAME}_rtrans_2_adjust.tmp
  SORT_FILEOUT=${RACE}/dat/${JOBNAME}_rtrans_2_adjust_sort.tmp
  #   +------------+------------+------------+----------+
  #   |            |    YYYY    |   MMDD     | OLD PART |
  #   +------------+------------+------------+----------+
  sort -k1.67,1.74r -k1.63,1.66r -k1.57,1.61r -k1.7,1.31 -o ${SORT_FILEOUT} ${SORT_FILEIN}
  mv               ${RACE}/dat/${JOBNAME}_rtrans_2_adjust_sort.tmp \
     $(setgdg.ksh "${RACE}/dat/${JOBNAME}_rtrans_2_adjust_${JOBFILE_OEMCTRY}.dat(+1)" NEW 3)


#STEP Step120R
  export STEPNAME=Step120R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} mptz013 - Reverse Supersession Update Program"
  #*********************************************************************************************
  #  Step120R - Execute mptz013 - Reverse Supersession Update Program
  #*********************************************************************************************
  export DD_PARMSIN=${RACE}/prm/${JOBPARM}.prm
  export DD_TRANSIN=$(setgdg.ksh "${RACE}/dat/${JOBNAME}_rtrans_2_adjust_${JOBFILE_OEMCTRY}.dat(0)")
  export DD_PARTSFL=${RACE}/tmp/${JOBNAME}_parts_file.tmp
  export DD_CNTLRPT=${RACE}/rpt/${JOBNAME}d_rupd${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt
 
  mptz013 2>&1

    email_rpt.ksh "${JOBNAME}d"  
    rpt_log_retention.ksh "${JOBNAME}d" 

#STEP Step125R
  export STEPNAME=Step125R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Sorts N TRANS by: SUPR-EFF-DT (YYYY, MM/DD) Ascend"
  #*********************************************************************************************
  # Step125R - Sorts N TRANS by: SUPR-EFF-DT (YYYY, MM/DD) Ascend
  #*********************************************************************************************
  SORT_FILEIN=${RACE}/dat/${REFORMATJOB}_ntrans.tmp
  SORT_FILEOUT=${RACE}/dat/${JOBNAME}_ntrans_sort.tmp
  #   +-----------|-----------|
  #   |    YYYY   |   MMDD    |
  #   +-----------|-----------|
  sort -k1.63,1.66 -k1.57,1.61 -o ${SORT_FILEOUT} ${SORT_FILEIN}


#STEP Step130R
  export STEPNAME=Step130R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Executes mptz024 - Supersession Update Program"
  #*********************************************************************************************
  # Step130R - Executes mptz024 - Supersession Update Program
  #*********************************************************************************************
  export DD_PARMSIN=${RACE}/prm/${JOBPARM}.prm
  export DD_TRANSIN=${RACE}/dat/${JOBNAME}_ntrans_sort.tmp
  export DD_CNTLRPT=${RACE}/rpt/${JOBNAME}f_supd${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt

  mptz024 2>&1

    email_rpt.ksh "${JOBNAME}f" 
    rpt_log_retention.ksh "${JOBNAME}f" 

    
#STEP Step140R
  export STEPNAME=Step140R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Executes mptz026 - Pricing update program"
  #*********************************************************************************************
  # Step140R - Executes mptz026 - Pricing update program
  #*********************************************************************************************
  export DD_PARMSIN=${RACE}/prm/${JOBPARM}.prm
  export DD_TRANSIN=${RACE}/dat/${REFORMATJOB}_ptrans.tmp
  export DD_CNTLRPT=${RACE}/rpt/${JOBNAME}h_pupd${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt

  mptz026 2>&1

    email_rpt.ksh "${JOBNAME}h"
    rpt_log_retention.ksh "${JOBNAME}h" 


#STEP Step150R
  export STEPNAME=Step150R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}"  $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Executes mptz025 - Discontinue Update Program"
  #*********************************************************************************************
  # Step150R - Executes mptz025 - Discontinue Update Program
  #*********************************************************************************************
  export DD_PARMSIN=${RACE}/prm/${JOBPARM}.prm
  export DD_TRANSIN=${RACE}/dat/${REFORMATJOB}_dtrans.tmp
  export DD_CNTLRPT=${RACE}/rpt/${JOBNAME}g_dupd${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt

  mptz025 2>&1

    email_rpt.ksh "${JOBNAME}g"  
    rpt_log_retention.ksh "${JOBNAME}g" 

    
#STEP Step160R
  export STEPNAME=Step160R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Executes SORT - Sorts A TRANS by: OLD PART NUMBER"
  #*********************************************************************************************
  # Step160R - Executes SORT - Sorts A TRANS by: OLD PART NUMBER
  #*********************************************************************************************
  SORT_FILEIN=${RACE}/dat/${REFORMATJOB}_atrans.tmp
  SORT_FILEOUT=${RACE}/dat/${JOBNAME}_atrans_sort.tmp
  #   +----------+
  #   | OLD PART |
  #   +----------+
  sort -k1.7,1.31 -o ${SORT_FILEOUT} ${SORT_FILEIN}


#STEP Step170R
  export STEPNAME=Step170R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Executes mptz022 - Assembly-to-Component Update Program"
  #*********************************************************************************************
  # Step170R - Executes mptz022 - Assembly-to-Component Update Program
  #*********************************************************************************************
  export DD_PARMSIN=${RACE}/prm/${JOBPARM}.prm
  export DD_TRANSIN=${RACE}/dat/${JOBNAME}_atrans_sort.tmp
  export DD_CNTLRPT=${RACE}/rpt/${JOBNAME}c_aupd${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt

  mptz022 2>&1

    email_rpt.ksh "${JOBNAME}c"
    rpt_log_retention.ksh "${JOBNAME}c" 

    
#STEP Step180R
  export STEPNAME=Step180R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Executes SORT - Sorts C Trans by: NEW PART NUMBER"
  #*********************************************************************************************
  # Step180R - Executes SORT - Sorts C Trans by: NEW PART NUMBER
  #*********************************************************************************************
  SORT_FILEIN=${RACE}/dat/${REFORMATJOB}_ctrans.tmp
  SORT_FILEOUT=${RACE}/dat/${JOBNAME}_ctrans_sort.tmp
  #   +-----------|
  #   | NEW PART  |
  #   +-----------|
  sort -k1.32,1.56 -o ${SORT_FILEOUT} ${SORT_FILEIN}


#STEP Step190R
  export STEPNAME=Step190R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Executes mptz023 - Component-to-Assembly Update Program"
  #*********************************************************************************************
  # Step190R - Executes mptz023 - Component-to-Assembly Update Program
  #***********************O*********************************************************************
  export DD_PARMSIN=${RACE}/prm/${JOBPARM}.prm
  export DD_TRANSIN=${RACE}/dat/${JOBNAME}_ctrans_sort.tmp
  export DD_CNTLRPT=${RACE}/rpt/${JOBNAME}e_cupd${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt

  mptz023 2>&1

    email_rpt.ksh "${JOBNAME}e"  
    rpt_log_retention.ksh "${JOBNAME}e" 

    
#STEP Step200R
  export STEPNAME=Step200R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Executes mptz007 - Update Report Program"
  #*********************************************************************************************
  # Step200R - Executes mptz007 - Update Report Program
  #*********************************************************************************************
  export DD_PARMSIN=${RACE}/prm/${JOBPARM}.prm

  export DD_RPT01=${RACE}/rpt/${JOBNAME}i_err${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt
  export DD_RPT02A=${RACE}/rpt/${JOBNAME}j_cmlt${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt
  export DD_RPT02B=${RACE}/rpt/${JOBNAME}p_wmlt${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt
  export DD_RPT03=${RACE}/rpt/${JOBNAME}k_pvar${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').csv
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
  #  Step201R - Emails and Handles Retention for Report(s) created in previous step  
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
   oem_job_status_update.ksh "R" "${STEPNAME} cat ATRANS and CTRANS to GDG disk"
   #*********************************************************************************************
   #  Step205R - Create ACTRANS gdg
   #*********************************************************************************************
   ATRANS_IN=${RACE}/dat/${JOBNAME}_atrans_sort.tmp
   CTRANS_IN=${RACE}/dat/${JOBNAME}_ctrans_sort.tmp
   ACTRANS_OUT=$(setgdg.ksh "${RACE}/dat/${JOBNAME}_actrans_${JOBFILE_OEMCTRY}.dat(+1)" NEW 3)
   cat ${ATRANS_IN} ${CTRANS_IN} > ${ACTRANS_OUT}


#STEP Step210R
  export STEPNAME=Step210R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Delete temp files for update and reformat"
  #*********************************************************************************************
  # Step210R - Delete temporary file created in update and reformat jobs
  #*********************************************************************************************
  rm -f ${RACE}/dat/${JOBNAME}*.tmp* &
  rm -f ${RACE}/tmp/${JOBNAME}*      &
  rm -f ${RACE}/dat/${REFORMATJOB}_atrans.tmp
  rm -f ${RACE}/dat/${REFORMATJOB}_ctrans.tmp
  rm -f ${RACE}/dat/${REFORMATJOB}_ntrans.tmp
  rm -f ${RACE}/dat/${REFORMATJOB}_dtrans.tmp
  rm -f ${RACE}/dat/${REFORMATJOB}_ptrans.tmp
  rm -f ${RACE}/dat/${REFORMATJOB}_rtrans.tmp
  rm -f ${RACE}/tmp/${REFORMATJOB}*.*
  



#*********************************************************************************************
# END oem_upd.ksh
#*********************************************************************************************
