#!/bin/ksh
echo "RCS $Id: oem_ref_trans_check_and_split.ksh,v 1.15 2020/08/26 00:54:25 pg2697 Exp $"
set -xv
print ProcessId = $$
#****************************************************************************************
#      NOTE:  This script is very similiar to oem_ref_trans_split_only.ksh
#   Changes here should also be considered in oem_ref_trans_split_only.ksh.
#****************************************************************************************
trap 'oem_abndalrt.ksh $?' err
export PROCNAME=$(basename $0 .ksh_run)
#****************************************************************************************
#  Build environment variables for the job (based on jobname)
#****************************************************************************************
. oem_job.ksh 
#****************************************************************************************


#STEP Step200R
 export STEPNAME=Step200R
 echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
 oem_job_status_update.ksh "R" "${STEPNAME} Sort RTRANS if file exists"
 #***************************************************************************************
 #  Program: SORT  - Sorts "R" TRANS if file exists
 #  Move RTRANS file to location expected by oem_upd.ksh
 #***************************************************************************************
 RTRANS_SORTIN=${RACE}/tmp/${JOBNAME}_step050_rtransout.tmp
 RTRANS_SORTOUT=${RACE}/dat/${JOBNAME}_rtrans.tmp
 if [ -f ${RTRANS_SORTIN} ]
 then     
   #      +------------+------------+----------+-----------+
   #      | YYYY desc  | MM/DD desc | Old Part | New Part  |
   #      +------------+------------+----------+-----------+
   sort -u -k1.63,1.66r -k1.57,1.61r -k1.7,1.31 -k1.32,1.56 -o ${RTRANS_SORTOUT} ${RTRANS_SORTIN}
 fi


#STEP Step205R
  export STEPNAME=Step205R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} pkg_oem_ref_trans_dupes_rpt"
  #**************************************************************************************
  #  Program: pkg_oem_ref_trans_dupes_rpt
  #**************************************************************************************
  INPUT_FILENAME=${JOBNAME}_step050_transout.tmp
  OUTPUT_FILENAME=${JOBNAME}_step205_transout.tmp
#----------------------------------------------------------------------------------------
(sqlplus -s << % 2>&1)
${MPTUSERID}
SET ECHO ON;
SET FEEDBACK OFF;
SET VERIFY ON;
SET LINESIZE 80;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode
    exec pkg_oem_ref_fix_trans_cleanup.p_main_procedure(p_reformat_job       => '${REFORMATJOB}',      \
                                                        p_log_directory      => '${OBJ_LOGDIR}',       \
                                                        p_log_filename       => '${LOGFILE}',          \
                                                        p_input_directory    => '${OBJ_TMPDIR}',       \
                                                        p_input_filename     => '${INPUT_FILENAME}',   \
                                                        p_output_directory   => '${OBJ_TMPDIR}',       \
                                                        p_output_filename    => '${OUTPUT_FILENAME}',  \
                                                        p_debug_level        => '${RACE_DEBUG_LEVEL}', \
                                                        p_dbms_profiler_flag => '${RACE_DBMS_PROFILER_FLAG}');
QUIT;
%
#----------------------------------------------------------------------------------------


#STEP Step210R
  export STEPNAME=Step210R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} pkg_oem_ref_trans_dupes_rpt"
  #**************************************************************************************
  #  Program: pkg_oem_ref_trans_dupes_rpt
  #**************************************************************************************
  INPUT_FILENAME=${JOBNAME}_step205_transout.tmp

  REPORT_FILE=${JOBNAME}y_dup${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt

#----------------------------------------------------------------------------------------
(sqlplus -s << % 2>&1)
${MPTUSERID}
SET ECHO ON;
SET FEEDBACK OFF;
SET VERIFY ON;
SET LINESIZE 80;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode
    exec pkg_oem_ref_trans_dupes_rpt.p_main_procedure(p_reformat_job       => '${REFORMATJOB}',      \
                                                      p_log_directory      => '${OBJ_LOGDIR}',       \
                                                      p_log_filename       => '${LOGFILE}',          \
                                                      p_input_directory    => '${OBJ_TMPDIR}',       \
                                                      p_input_filename     => '${INPUT_FILENAME}',   \
                                                      p_report_directory   => '${OBJ_RPTDIR}',       \
                                                      p_report_filename    => '${REPORT_FILE}', \
                                                      p_debug_level        => '${RACE_DEBUG_LEVEL}', \
                                                      p_dbms_profiler_flag => '${RACE_DBMS_PROFILER_FLAG}');
QUIT;
%
#----------------------------------------------------------------------------------------

#STEP Step211R
  export STEPNAME=Step211R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Report Distribution"
  #**************************************************************************************
  #  Emails and Handles Retention for Report(s) created in previous step  
  #**************************************************************************************
  email_rpt.ksh "${JOBNAME}y"              
  rpt_log_retention.ksh "${JOBNAME}y"

  
#STEP Step215R
  export STEPNAME=Step215R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Sort by Transcode, Old Part, New Part, Price desc, Description desc"
  #**************************************************************************************
  #  Program: Sort
  #**************************************************************************************
  TRANS_SORTIN=${RACE}/tmp/${JOBNAME}_step205_transout.tmp
  TRANS_SORTOUT=${RACE}/tmp/${JOBNAME}_step215_transout_sorted.tmp
  #           +---------+----------+-----------+------------+-----------------+
  #           |Transcode| Old Part |  New Part | Price Desc | Description Desc|
  #           +---------+----------+-----------+------------+-----------------+
  sort -T /tmp -k1.1,1.1 -k1.7,1.31 -k1.32,1.56 -k1.57,1.71r -k1.88,1.167r -o ${TRANS_SORTOUT} ${TRANS_SORTIN}


#STEP Step216R
  export STEPNAME=Step216R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} mpt_elim_dup_old_new_part.awk"
  #**************************************************************************************
  #  Program: mpt_elim_dup_old_new_part.awk
  #**************************************************************************************
  SORTED_FILEIN=${RACE}/tmp/${JOBNAME}_step215_transout_sorted.tmp
  REFORMAT_FILEOUT=${RACE}/tmp/${JOBNAME}_step216_ref_${JOBFILE_OEMCTRY}.tmp
  
  if [ "${DUPLICATE_PARTS_EXPECTED_FLAG}" = "Y" ]
  then
    export sort_type=tcd_old_part_new_part
    cat ${SORTED_FILEIN} | awk -f ${RACE}/bin/mpt_elim_dup_old_new_part.awk > ${REFORMAT_FILEOUT}
  else
     cp ${SORTED_FILEIN} ${REFORMAT_FILEOUT}
  fi 


#STEP Step220R
  export STEPNAME=Step220R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Extract the P and N transaction records"
  #**************************************************************************************
  #  Check the newly reformated transaction file for looping supersessions - remove loops
  #**************************************************************************************

  . oem_rpt_validate_supers.ksh
  

#STEP Step222R
  export STEPNAME=Step222R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Drop supersessions reported by pkg_oem_rpt_validate_supers"
  #*************************************************************************************************
  #    *** Drop identified looping supersessions from Reformat File using these 6 steps          ***
  #    *** NOTE: at the end of this step, the REFORMAT_FILEIN is OVERLAYED                       ***
  #*************************************************************************************************
  # 1. awk to create subset of all Reformat Transactions EXCEPT for the ntrans in the Reformat File
  # 2. awk to create subset of all ntrans records in the Reformat
  # 3. cat to combine Reformat ntrans with LOOPING Ntrans (identified by pkg_oem_rpt_validate_supers)
  # 4. awk the 1st 56 bytes of the combined file to identify "duplicated" 'N' supersession records.
  #    *** This will get rid of BOTH duplicate records from the combined file which is effectively 
  #        eliminating the identifiable loops from being sent to the Update Job!
  # 5. sort "other trans" and "reduced ntrans" together to rebuild the "complete" Reformat transaction file
  #*************************************************************************************************
  SUPLOOPS_FILEIN=$(setgdg.ksh "${RACE}/dat/${REFORMATJOB}_looping_oem_ntrans_${JOBFILE_OEMCTRY}.dat(0)") 
  REFORMAT_FILEIN=${RACE}/tmp/${JOBNAME}_step216_ref_${JOBFILE_OEMCTRY}.tmp                            
  REFORMAT_FILEOUT=${RACE}/tmp/${JOBNAME}_step222_ref_${JOBFILE_OEMCTRY}.tmp
  #*************************************************************************************************
  # 1. Subset for REFORMAT File of all NON-supersession records ('A','C','D','P',etc)
  MAINREF_OTHERS=${RACE}/tmp/${JOBNAME}_step222_ref_others_${JOBFILE_OEMCTRY}.tmp
  awk '{ if (substr($0,1,1)!="N") print $0 }' ${REFORMAT_FILEIN} > ${MAINREF_OTHERS}
  #*************************************************************************************************
  # 2. Subset for REFORMAT File of all supersession 'N' records
  MAINREF_NTRANS=${RACE}/tmp/${JOBNAME}_step222_ref_ntrans_${JOBFILE_OEMCTRY}.tmp
  awk '{ if (substr($0,1,1)=="N") print $0 }' ${REFORMAT_FILEIN} > ${MAINREF_NTRANS}
  #*************************************************************************************************
  # 3. cat to Combine Reformat Ntrans with LOOPING Ntrans (identified by pkg_oem_rpt_validate_supers)
  MERGED_NTRANS=${RACE}/tmp/${JOBNAME}_step222_ntrans_merged_${JOBFILE_OEMCTRY}.tmp
  cat ${SUPLOOPS_FILEIN} ${MAINREF_NTRANS} > ${MERGED_NTRANS}   
  #*************************************************************************************************
  # 4. awk the 1st 56 bytes of the combined file to identify "duplicate" 'N' supersession records.
  #    This will get rid of BOTH duplicate records from the combined file (effectively eliminating the identifiable loops)
  REDUCED_NTRANS=${RACE}/tmp/${JOBNAME}_step222_reduced_ntrans_${JOBFILE_OEMCTRY}.tmp
  awk '{ k=substr($0,1,56) ; line[k]=$0 ; freq[k]++ } END { for (x in freq) if (freq[x]==1) print line[x]}' ${MERGED_NTRANS} > ${REDUCED_NTRANS}
  #*************************************************************************************************
  # 5. sort "other trans" and "reduced ntrans" together to rebuild the "complete" Reformat transaction file
  #                  +---------+----------+-----------+------------+-----------------+
  #                  |Transcode| Old Part |  New Part |Price Revrsd| Descrip Reversed|
  #                  +---------+----------+-----------+------------+-----------------+                  
  SORTIN_BOTH="${MAINREF_OTHERS} ${REDUCED_NTRANS}"
  
  sort -T ${RACE}/tmp -k1.1,1.1 -k1.7,1.31 -k1.32,1.56 -k1.57,1.71r -k1.88,1.167r -o ${REFORMAT_FILEOUT} ${SORTIN_BOTH}  


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
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Save 3 generations of Reformat Trans File"
  #**************************************************************************************
  #  Save 3 generations of the reformated transaction file
  #**************************************************************************************
  REFORMAT_FILEIN=${RACE}/tmp/${JOBNAME}_step222_ref_${JOBFILE_OEMCTRY}.tmp
  REFORMAT_GDG_OUT=$(setgdg.ksh "${RACE}/dat/${JOBNAME}_ref_${JOBFILE_OEMCTRY}.dat(+01)" NEW 3 )

  cp ${REFORMAT_FILEIN} ${REFORMAT_GDG_OUT}
  
  
#STEP Step270R
  export STEPNAME=Step270R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} pkg_oem_ref_part_number_check"
  #**************************************************************************************
  #  Program: pkg_oem_ref_part_number_check
  #**************************************************************************************
  INPUT_FILEPATH=$(setgdg.ksh "${RACE}/dat/${JOBNAME}_ref_${JOBFILE_OEMCTRY}.dat(0)")
  INPUT_FILENAME=$(basename ${INPUT_FILEPATH})

  REPORT_FILE_D=${JOBNAME}d_edt${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt
  REPORT_FILE_C=${JOBNAME}c_cmp${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt
  REPORT_FILE_X=${JOBNAME}x_dup${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt

#----------------------------------------------------------------------------------------
(sqlplus -s << % 2>&1)
${MPTUSERID}
SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 80;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode
    exec pkg_oem_ref_part_number_check.p_main_procedure(p_reformat_job                => '${REFORMATJOB}',      \
                                                        p_log_directory               => '${OBJ_LOGDIR}',       \
                                                        p_log_filename                => '${LOGFILE}',          \
                                                        p_input_directory             => '${OBJ_DATDIR}',       \
                                                        p_input_filename              => '${INPUT_FILENAME}',   \
                                                        p_report_directory            => '${OBJ_RPTDIR}',       \
                                                        p_report_file_mask            => '${REPORT_FILE_D}', \
                                                        p_report_file_comp            => '${REPORT_FILE_C}', \
                                                        p_report_file_dups            => '${REPORT_FILE_X}', \
                                                        p_format_part_supplier_number => '${FORMATOEM}',        \
                                                        p_format_country_abbr         => '${FORMATCTRY}',       \
                                                        p_debug_level                 => '${RACE_DEBUG_LEVEL}', \
                                                        p_dbms_profiler_flag          => '${RACE_DBMS_PROFILER_FLAG}');
QUIT;
%
#----------------------------------------------------------------------------------------


#STEP Step271R
  export STEPNAME=Step271R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Report Distribution"
  #**************************************************************************************
  #  Emails and Handles Retention for Report(s) created in previous step  
  #**************************************************************************************
    
  email_rpt.ksh "${JOBNAME}d" 
  rpt_log_retention.ksh "${JOBNAME}d"  

  email_rpt.ksh "${JOBNAME}c"
  rpt_log_retention.ksh "${JOBNAME}c"  

  email_rpt.ksh "${JOBNAME}x" 
  rpt_log_retention.ksh "${JOBNAME}x"   

  
  
#STEP Step280R
  export STEPNAME=Step280R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} pkg_oem_ref_actrans_preprocess"
  #**************************************************************************************
  #  Program: pkg_oem_ref_actrans_preprocess
  #           Read old ACTRANS records and compare against the new Reformat records
  #           ACTRANS Old Part Numbers found in Reformat file are processed:
  #           Transaction type 'N' or 'P' --> drop ACTRANS
  #                            'A' or 'C' --> and new part number match rewrite ACTRANS
  #                                           otherwise, drop ACTRANS
  #                                   'D' --> rewrite ACTRANS
  #**************************************************************************************
  ACTRANS_FILEPATH=$(setgdg.ksh "${RACE}/dat/${UPDATEJOB}_actrans_${JOBFILE_OEMCTRY}.dat(0)")              
  INPUT_FILE_ACTRANS=$( basename ${ACTRANS_FILEPATH} )                               

  INPUT_FILEPATH=$(setgdg.ksh "${RACE}/dat/${JOBNAME}_ref_${JOBFILE_OEMCTRY}.dat(0)")
  INPUT_FILE_REF=$( basename ${INPUT_FILEPATH} )     

  OUTPUT_FILE_ACTRANS=${JOBNAME}_step280_actrans_${JOBFILE_OEMCTRY}.tmp

  REPORT_FILE_COUNTS=${JOBNAME}t_act${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt
 
  
#----------------------------------------------------------------------------------------
(sqlplus -s << % 2>&1)
${MPTUSERID}
SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 80;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode
    exec pkg_oem_ref_actrans_preprocess.p_main_procedure(p_reformat_job        => '${REFORMATJOB}',         \
                                                         p_log_directory       => '${OBJ_LOGDIR}',          \
                                                         p_log_filename        => '${LOGFILE}',             \
                                                         p_input_directory     => '${OBJ_DATDIR}',          \
                                                         p_input_file_ref      => '${INPUT_FILE_REF}',      \
                                                         p_input_file_actrans  => '${INPUT_FILE_ACTRANS}',  \
                                                         p_output_directory    => '${OBJ_TMPDIR}',          \
                                                         p_output_file_actrans => '${OUTPUT_FILE_ACTRANS}', \
                                                         p_report_directory    => '${OBJ_RPTDIR}',          \
                                                         p_report_file_counts  => '${REPORT_FILE_COUNTS}',  \
                                                         p_debug_level         => '${RACE_DEBUG_LEVEL}',    \
                                                         p_dbms_profiler_flag  => '${RACE_DBMS_PROFILER_FLAG}');
QUIT;
%
#----------------------------------------------------------------------------------------

#STEP Step281R
  export STEPNAME=Step281R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Report Distribution"
  #**************************************************************************************
  #  Emails and Handles Retention for Report(s) created in previous step  
  #**************************************************************************************
  email_rpt.ksh "${JOBNAME}t" 
  rpt_log_retention.ksh "${JOBNAME}t" 

  
#STEP Step290R
  export STEPNAME=Step290R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  if [ ${JOBNAME} = ${REFORMATJOB} ]
  then
    oem_job_status_update.ksh "R" "${STEPNAME} Drop duplicated ACtrans"
    #*************************************************************************************************
    #    *** Isolate "new" actrans and merge with "previous" actrans records ... elimiate duplicates
    # 1. awk to create subset of all transactions except for 'A' and 'C')
    # 2. awk to create subset of all atrans and all ctrans records in the Reformat File 
    # 3. sort -u to remove duplicate actrans creating "reduced" actrans
    # 4. merge and sort NON-actrans with "reduced" actrans 
    #*************************************************************************************************
    REFORMAT_FILEIN=$(setgdg.ksh "${RACE}/dat/${JOBNAME}_ref_${JOBFILE_OEMCTRY}.dat(0)")   #From Step260R
    TEMP_ACTRANS=${RACE}/tmp/${JOBNAME}_step280_actrans_${JOBFILE_OEMCTRY}.tmp             #From Step280R
    #*************************************************************************************************
    # 1. awk to create subset of all transaction except for 'A' and 'C'
    REFTRANS_NOT_ACTRANS=${RACE}/tmp/${JOBNAME}_step290_not_actrans_${JOBFILE_OEMCTRY}.tmp
    awk '{ if (substr($0,1,1)!="A" && substr($0,1,1)!="C") print $0 }' ${REFORMAT_FILEIN} > ${REFTRANS_NOT_ACTRANS}
    #*************************************************************************************************
    # 2. awk to create subset of all ACTrans
    REFTRANS_ACTRANS=${RACE}/tmp/${JOBNAME}_step290_ref_actrans_${JOBFILE_OEMCTRY}.tmp
    awk '{ if (substr($0,1,1)=="A" || substr($0,1,1)=="C") print $0 }' ${REFORMAT_FILEIN} > ${REFTRANS_ACTRANS}
    #*************************************************************************************************
    # 3. UNIQUE sort together actrans files (this may drop records which is the desired result)
    SORTIN_BOTH1="${REFTRANS_ACTRANS} ${TEMP_ACTRANS}"
    ACTRANS_REDUCED=${RACE}/tmp/${JOBNAME}_step290_actrans_reduced_${JOBFILE_OEMCTRY}.tmp
    #                     +---------+----------+-----------+
    #                     |Transcode| Old Part | New Part  |
    #                     +---------+----------+-----------+
    sort -T ${RACE}/tmp -u -k1.1,1.1 -k1.7,1.31 -k1.32,1.56 -o ${ACTRANS_REDUCED} ${SORTIN_BOTH1}
    #*************************************************************************************************
    # 4. sort together actrans and the "other" transactions
    SORTIN_BOTH2="${ACTRANS_REDUCED} ${REFTRANS_NOT_ACTRANS}"
    REFORMAT_SORTOUT=${RACE}/tmp/${JOBNAME}_step290_ref_${JOBFILE_OEMCTRY}_sorted.tmp
    #                  +---------+----------+-----------+------------+-----------------+
    #                  |Transcode| Old Part |  New Part |Price Revrsd| Descrip Reversed|
    #                  +---------+----------+-----------+------------+-----------------+                      
    sort -T ${RACE}/tmp -k1.1,1.1 -k1.7,1.31 -k1.32,1.56 -k1.57,1.71r -k1.88,1.167r -o ${REFORMAT_SORTOUT} ${SORTIN_BOTH2}      
  fi


#STEP Step300R
  export STEPNAME=Step300R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} mptz021 Transaction Split Processing"
  #**************************************************************************************
  #  Executes mptz021 - Transaction Split Program
  #**************************************************************************************
  export DD_PARMSIN=${RACE}/prm/${JOBPARM}.prm

  # NOTE: Use this "tmp" file because it contains the correct actrans records...
  #       It is tempting to use the new "ref" (0) file but don't do it.
  export DD_TRANSIN=${RACE}/tmp/${JOBNAME}_step290_ref_${JOBFILE_OEMCTRY}_sorted.tmp

  export DD_ATRANS=${RACE}/dat/${JOBNAME}_atrans.tmp
  export DD_CTRANS=${RACE}/dat/${JOBNAME}_ctrans.tmp
  export DD_NTRANS=${RACE}/dat/${JOBNAME}_ntrans.tmp
  export DD_DTRANS=${RACE}/dat/${JOBNAME}_dtrans.tmp
  export DD_PTRANS=${RACE}/dat/${JOBNAME}_ptrans.tmp
  export DD_CNTLRPT=${RACE}/rpt/${JOBNAME}s_splt${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt

  mptz021 2>&1

#STEP Step301R
  export STEPNAME=Step301R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Report Distribution"
  #**************************************************************************************
  #  Emails and Handles Retention for Report(s) created in previous step  
  #**************************************************************************************
  email_rpt.ksh "${JOBNAME}s"  
  rpt_log_retention.ksh "${JOBNAME}s" 

#STEP Step999R
  export STEPNAME=Step999R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "P" "${STEPNAME} Reformat Job Complete"
  #**************************************************************************************
  #  Removes job temporary files
  #**************************************************************************************
  rm -f ${RACE}/tmp/${JOBNAME}*


#****************************************************************************************
# END oem_ref_trans_check_and_split.ksh
#****************************************************************************************
