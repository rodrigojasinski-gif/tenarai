#!/bin/ksh
echo "RCS $Id: oem_ref.ksh,v 1.39 2024/01/17 23:23:23 pg2697 Exp $"
#*****************************************************************************************
# For testing, change set cammand to:  set -xv
#   -v  Print shell input lines as they are read.
#   -x  Print commands and their arguments as they are executed.
#*****************************************************************************************
set -x

print ProcessId = $$
#*****************************************************************************************
# OEM Reformat Job Script
#*****************************************************************************************
trap 'oem_abndalrt.ksh $?' err
export PROCNAME=$(basename $0 .ksh_run)
export MPTUSERID=`cat ${RACE}/prm/zmptpass.prm`
export LOGFILE=$(basename ${JOBLOGNAME})

#*****************************************************************************************
#  Build environment variables for the job (based on jobname)
#*****************************************************************************************
echo "\n\n Build environment variables"
. oem_job.ksh         
. oem_job_notify.ksh
. oem_job_datafile.ksh
#-----------------------------------------------------------------------------------------


#STEP Step010R
  export STEPNAME=Step010R
  echo "\n\n START ---> ${PROCNAME} ${STEPNAME} - Locate and transfer ALL Input Files - " $(date +'%m/%d/%y %H:%M:%S') " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} oem_job_datafile_prep.ksh"
  #**************************************************************************************
  #
  # Step010R - Locate and transfer ALL Input Files
  #
  #**************************************************************************************
  #  Determine where files are located and get them into UNIX temp area
  #  Is file on the OEM's ftp site?   (Determined by ${FTP_PROGRAM_NAME} being populated)
  #  No.  Is file already in the "dat" file (Determined by -s size of file in directory)
  #       Yes.
  #       No. Use fileget to pull the file from Novell
  #  Yes. Run the customized program to logon to OEM's FTP and retrieve file
  #**************************************************************************************
 

  #**************************************************************************************
  #  Restart Step/File Checking
  #  When step restarting at THIS step, determine if a file sequence was requested.
  #**************************************************************************************
  export FILE_SEQUENCE=1
  if [ "${RESTART}" = "${STEPNAME}" ] && [ ! -z "${RESTART_FILE_SEQUENCE}" ]
   then
    export FILE_SEQUENCE=${RESTART_FILE_SEQUENCE}
  fi
  #--------------------------------------------------------------------------------------

  while true
  do
    #***********************************************************************************
    #   When ${INPUT_FILE_NAME} has no length,
    #   then FILE_SEQUENCE exceeds the number of lines in file... get out!
    #**************************************************************************************
    export INPUT_FILE_NAME=`sed -n -e "${FILE_SEQUENCE}p" < ${WORKFILE}| cut -f2  -d"^"`
    if [ -z "${INPUT_FILE_NAME}" ]
    then
      break
    else
      export XTAB_FILE_NAME=`sed -n -e "${FILE_SEQUENCE}p"          < ${WORKFILE}| cut -f3  -d"^"`
      export XTAB_TABLE_NAME=`sed -n -e "${FILE_SEQUENCE}p"         < ${WORKFILE}| cut -f4  -d"^"`
      export FTP_PROGRAM_NAME=`sed -n -e "${FILE_SEQUENCE}p"        < ${WORKFILE}| cut -f5  -d"^"`
      export FTP_LOCATION_CODE=`sed -n -e "${FILE_SEQUENCE}p"       < ${WORKFILE}| cut -f6  -d"^"`
      export FORMAT_INDICATOR=`sed -n -e "${FILE_SEQUENCE}p"        < ${WORKFILE}| cut -f7  -d"^"`
      export SOURCE_FIELD_DELIMITER=`sed -n -e "${FILE_SEQUENCE}p"  < ${WORKFILE}| cut -f8  -d"^"`
      export TARGET_FIELD_SIZE=`sed -n -e "${FILE_SEQUENCE}p"       < ${WORKFILE}| cut -f9  -d"^"`
      export BACKUP_SOURCE_FILE_NAME=`sed -n -e "${FILE_SEQUENCE}p" < ${WORKFILE}| cut -f10 -d"^"`
      export FTP_SOURCE_FILE_NAME=`sed -n -e "${FILE_SEQUENCE}p"    < ${WORKFILE}| cut -f11 -d"^"`
      # Some file names contain executable commands -- flush them out
      eval   FTP_SOURCE_FILE_NAME=${FTP_SOURCE_FILE_NAME} 
      export FTP_PARM_FILE_NAME=`sed -n -e "${FILE_SEQUENCE}p"      < ${WORKFILE}| cut -f14 -d"^"`         
      export ENCODING_CHARSET=`sed -n -e "${FILE_SEQUENCE}p"        < ${WORKFILE}| cut -f16 -d"^"`
     
      . oem_job_datafile_prep.ksh         
         
      FILE_SEQUENCE=`expr ${FILE_SEQUENCE} + 1`
    fi
    #-----------------------------------------------------------------------------------------
  done


#STEP Step020R
  export STEPNAME=Step020R
  echo "\n\n START ---> ${PROCNAME} ${STEPNAME} - ASCII Cleanup - " $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} ASCII Cleanup"
  #**************************************************************************************
  #
  # Step020R - ALL Input Files have been prepped, now do ASCII Cleanup for ALL Input files
  #
  #**************************************************************************************
  #     INPUT:  ${STEP010_FILEOUT}
  #     OUTPUT: ${STEP020_FILEOUT}
  #     Make sure file is void of ASCII control characters and of unprintable
  #     characters in the Extended ASCII Character Set
  #**************************************************************************************

  #**************************************************************************************
  #  Restart Step/File Checking
  #  When step restarting at THIS step, determine if a file sequence was requested.
  #**************************************************************************************
  export FILE_SEQUENCE=1
  if [ "${RESTART}" = "${STEPNAME}" ] && [ ! -z "${RESTART_FILE_SEQUENCE}" ]
   then
    export FILE_SEQUENCE=${RESTART_FILE_SEQUENCE}
  fi
  #--------------------------------------------------------------------------------------

  while true
  do
    #************************************************************************************
    #   When ${INPUT_FILE_NAME} has no length,
    #   then FILE_SEQUENCE exceeds the number of lines in file... get out!
    #************************************************************************************
      export INPUT_FILE_NAME=`sed -n -e "${FILE_SEQUENCE}p" < ${WORKFILE}| cut -f2  -d"^"`
    if [ -z "${INPUT_FILE_NAME}" ]
    then
      break
    else
      export XTAB_FILE_NAME=`sed -n -e "${FILE_SEQUENCE}p"          < ${WORKFILE}| cut -f3  -d"^"`
      export XTAB_TABLE_NAME=`sed -n -e "${FILE_SEQUENCE}p"         < ${WORKFILE}| cut -f4  -d"^"`
      export FTP_PROGRAM_NAME=`sed -n -e "${FILE_SEQUENCE}p"        < ${WORKFILE}| cut -f5  -d"^"`
      export FTP_LOCATION_CODE=`sed -n -e "${FILE_SEQUENCE}p"       < ${WORKFILE}| cut -f6  -d"^"`
      export FORMAT_INDICATOR=`sed -n -e "${FILE_SEQUENCE}p"        < ${WORKFILE}| cut -f7  -d"^"`
      export SOURCE_FIELD_DELIMITER=`sed -n -e "${FILE_SEQUENCE}p"  < ${WORKFILE}| cut -f8  -d"^"`
      export TARGET_FIELD_SIZE=`sed -n -e "${FILE_SEQUENCE}p"       < ${WORKFILE}| cut -f9  -d"^"`
      export BACKUP_SOURCE_FILE_NAME=`sed -n -e "${FILE_SEQUENCE}p" < ${WORKFILE}| cut -f10 -d"^"`
      export ENCODING_CHARSET=`sed -n -e "${FILE_SEQUENCE}p"        < ${WORKFILE}| cut -f16 -d"^"`

       
      ###STEP020_FILEIN=${STEP010_FILEOUT}
      export STEP020_FILEIN=${RACE}/dat/${BACKUP_SOURCE_FILE_NAME}
      export STEP020_FILEOUT=${RACE}/tmp/${JOBNAME}_step020_${JOBFILE_OEMCTRY}_file_${FILE_SEQUENCE}.tmp
      export STEP020_FILEIN_CONV=${RACE}/dat/${JOBNAME}_araw_${JOBFILE_OEMCTRY}_conv.dat
      export STEP020_FILETMP=${RACE}/tmp/${JOBNAME}_step020_${JOBFILE_OEMCTRY}_filetmp_${FILE_SEQUENCE}.tmp      
      
      echo "\n\n Input File:  ${STEP020_FILEIN}"
      echo "\n\n Output File: ${STEP020_FILEOUT}"
      
      #************************************************************************************
      # if ascii file and encoding_charset variable is valued, convert the raw file from one 
      # encoding charset to our unix charset and then do the ascii cleanup. 
      # if ascii file and encoding_charset variable is not valued, just do the ascii cleanup.         
      #************************************************************************************
      if [ "${FORMAT_INDICATOR}" = "A" ]
      then 
        if [ ! -z "${ENCODING_CHARSET}" ]
        then  
          # turn trap off since iconv will return a '2' if I/P file contains invalid chars
          # -c param changes the bad chars to blank but still returns '2'
          # "invalid character found" means it found bad chars but with "-c", it converted them (OK)
          # "truncated character found" means file isn't in the encoding charset you have designated (NOT OK) 

          trap - err
          echo "\n\n Converting raw file to different character encoding."
          iconv -c -f ${ENCODING_CHARSET} -t ISO8859-1 ${STEP020_FILEIN} > ${STEP020_FILEIN_CONV} 
          
          # was file created?
          RECCNT=$(wc -l ${STEP020_FILEIN_CONV} | awk ' {print $1}' )
          if [ "${RECCNT}" = "0" ]
          then
               echo "\n\n
                     ********** E R R O R ******************************************
                     Error encountered during character encoding conversion (iconv).
                     ***************************************************************"
               oem_abndalrt.ksh 99
          else
               echo "\n\n Character encoding conversion (iconv) successful."          
          fi
          # trap is turned back on 
          trap 'oem_abndalrt.ksh $?' err

          echo "\n\n Running ascii_cleanup.ksh ${STEP020_FILEIN_CONV} ${STEP020_FILEOUT} ${STEP020_FILETMP}"
          ascii_cleanup.ksh ${STEP020_FILEIN_CONV} ${STEP020_FILEOUT} ${STEP020_FILETMP} 
        else
          echo "\n\n Running ascii_cleanup.ksh ${STEP020_FILEIN} ${STEP020_FILEOUT} ${STEP020_FILETMP}"
          ascii_cleanup.ksh ${STEP020_FILEIN} ${STEP020_FILEOUT} ${STEP020_FILETMP}
        fi
      else        
        #************************************************************************************
        # Translate the EBCDIC input file into ASCII using a C program (ebcdic2a)
        # Note: The STEP020_MASK is optional, it is required when only part of 
        #       the record is to be translated like the comp fields in input records.
        #************************************************************************************
        export STEP020_MASK=${RACE}/prm/mpt495m.prm
        echo "\n\n Running ebcdic2a  ${STEP020_FILEIN}  ${STEP020_MASK} > ${STEP020_FILETMP}"
        ebcdic2a  ${STEP020_FILEIN}  ${STEP020_MASK} > ${STEP020_FILETMP}
        echo "\n\n Running dataclean ${STEP020_FILETMP} ${STEP020_MASK} > ${STEP020_FILEOUT}"
        dataclean ${STEP020_FILETMP} ${STEP020_MASK} > ${STEP020_FILEOUT}
      fi
      #------------------------------------------------------------------------------------

      FILE_SEQUENCE=`expr ${FILE_SEQUENCE} + 1`
    fi
    #-----------------------------------------------------------------------------------------
  done

#STEP Step030R
  export STEPNAME=Step030R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME} - delimit to fixed file conversion and xtab creation - " $(date +'%m/%d/%y %H:%M:%S') " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} dlmt2fxd Process"
  #************************************************************************************************
  #
  # ALL Input Files have been ASCII Cleaned now. If needed, run dlmt2fxd.pl against input files.
  #
  #************************************************************************************************
  #     INPUT:  ${STEP020_FILEOUT}
  #     OUTPUT: ${XTAB_FILE_NAME}
  #             dlmt2fxd.pl is a utility program converting delimited files to fixed length.
  #             Default delimeter is ','
  #             Default field length is 25
  #************************************************************************************************

  #************************************************************************************************
  #  Restart Step/File Checking
  #  When step restarting at THIS step, determine if a file sequence was requested.
  #************************************************************************************************
  export FILE_SEQUENCE=1
  if [ "${RESTART}" = "${STEPNAME}" ] && [ ! -z "${RESTART_FILE_SEQUENCE}" ]
  then
    export FILE_SEQUENCE=${RESTART_FILE_SEQUENCE}
  fi
  #------------------------------------------------------------------------------------------------

  while true
  do
    #*********************************************************************************************
    #   When ${INPUT_FILE_NAME} has no length,
    #   then FILE_SEQUENCE exceeds the number of lines in file... get out!
    #************************************************************************************************
    export INPUT_FILE_NAME=`sed -n -e "${FILE_SEQUENCE}p" < ${WORKFILE}| cut -f2  -d"^"`
    if [ -z "${INPUT_FILE_NAME}" ]
    then
      break
    else
      export XTAB_FILE_NAME=`sed -n -e "${FILE_SEQUENCE}p"               < ${WORKFILE}| cut -f3  -d"^"`
      export XTAB_TABLE_NAME=`sed -n -e "${FILE_SEQUENCE}p"              < ${WORKFILE}| cut -f4  -d"^"`
      export FTP_PROGRAM_NAME=`sed -n -e "${FILE_SEQUENCE}p"             < ${WORKFILE}| cut -f5  -d"^"`
      export FTP_LOCATION_CODE=`sed -n -e "${FILE_SEQUENCE}p"            < ${WORKFILE}| cut -f6  -d"^"`
      export FORMAT_INDICATOR=`sed -n -e "${FILE_SEQUENCE}p"             < ${WORKFILE}| cut -f7  -d"^"`
      export SOURCE_FIELD_DELIMITER=`sed -n -e "${FILE_SEQUENCE}p"       < ${WORKFILE}| cut -f8  -d"^"`
      export TARGET_FIELD_SIZE=`sed -n -e "${FILE_SEQUENCE}p"            < ${WORKFILE}| cut -f9  -d"^"`
      export BACKUP_SOURCE_FILE_NAME=`sed -n -e "${FILE_SEQUENCE}p"      < ${WORKFILE}| cut -f10 -d"^"`
      export FTP_SOURCE_FILE_NAME=`sed -n -e "${FILE_SEQUENCE}p"         < ${WORKFILE}| cut -f11 -d"^"`
      eval   FTP_SOURCE_FILE_NAME=${FTP_SOURCE_FILE_NAME} 
      export SOURCE_FILE_UPDATE_FREQUENCY=`sed -n -e "${FILE_SEQUENCE}p" < ${WORKFILE}| cut -f12 -d"^"`
      export SOURCE_FILE_UPDATE_DATE=`sed -n -e "${FILE_SEQUENCE}p"      < ${WORKFILE}| cut -f13 -d"^"`
      export FTP_PARM_FILE_NAME=`sed -n -e "${FILE_SEQUENCE}p"           < ${WORKFILE}| cut -f14 -d"^"`     

      export STEP030_FILEIN=${RACE}/tmp/${JOBNAME}_step020_${JOBFILE_OEMCTRY}_file_${FILE_SEQUENCE}.tmp
      export STEP030_FILEOUT=${RACE}/dat/${XTAB_FILE_NAME}
      export STEP030_PREVRAW=${RACE}/dat/${XTAB_FILE_NAME}_prevraw.dat
 #### used? export STEP030_FILETMP=${RACE}/tmp/${JOBNAME}_step030_${JOBFILE_OEMCTRY}_filetmp_${FILE_SEQUENCE}.tmp
      #******************************************************************************************
      # Create backups for the PREVIOUS external table input file (aka raw files) before
      # creating a new external table input file
      #******************************************************************************************
      echo "\n\n Create previous raw from last run's raw.dat file"
      if [ -f "${STEP030_FILEOUT}" ]
      then
        cp -p ${STEP030_FILEOUT} ${STEP030_PREVRAW}
      fi
      #------------------------------------------------------------------------------------------------
      
      echo "\n\n Input File:  ${STEP030_FILEIN}"
      echo "\n\n Output File: ${STEP030_FILEOUT}"
      if [ ! -z "${TARGET_FIELD_SIZE}" ]
      then
        echo "\n\n Replacing all grave accents with apostrophes and converting delimited to fixed to create new xtab dat."
        echo "\n\n Running perl -pi.bak.grave -e ""s/\`/'/g;"" ${STEP030_FILEIN}"
                      perl -pi.bak.grave -e  "s/\`/'/g;"  ${STEP030_FILEIN}
        echo "\n\n Running dlmt2fxd.pl ${STEP030_FILEIN} ${SOURCE_FIELD_DELIMITER} ${TARGET_FIELD_SIZE} > ${STEP030_FILEOUT}"
                      dlmt2fxd.pl ${STEP030_FILEIN} ${SOURCE_FIELD_DELIMITER} ${TARGET_FIELD_SIZE} > ${STEP030_FILEOUT}
      else
        echo "Copy input file to output file to create new xtab dat."
        cp ${STEP030_FILEIN} ${STEP030_FILEOUT}
      fi 
                    
      #******************************************************************************************
      # Is there a PREVIOUS Input file and is it the same as the CURRENT input file?
      # If so, send a warning email.
    # If not, update oem_job table (source_file_update_date)
      #******************************************************************************************
      DIFF_FILE=${RACE}/tmp/${JOBNAME}_step030_${REPORTSUFFIX}.diff
      echo "\n\n"
      echo "Current  Input File: ${STEP030_FILEOUT}"
      echo "Previous Input File: ${STEP030_PREVRAW}"
      if [ -f "${STEP030_PREVRAW}" ]
      then
        # Needed to turn trap off since "diff" will return a 1 if files are different
        # trap is turned back on after the "if"
        trap - err        
        diff ${STEP030_PREVRAW} ${STEP030_FILEOUT} > ${DIFF_FILE}         
        #************************************************************************************************
        # When there are NO differences, email warning that same file is being processed. 
        #************************************************************************************************
        if [ ! -s ${DIFF_FILE} ]
        then
           . oem_job_email_same_file_msg.ksh
        else     
          echo "Update source_file_update_date"

#-----------------------------------------------------------------------------------------------
(sqlplus -s << % 2>&1)
${MPTUSERID}
SET ECHO ON;
SET FEEDBACK OFF;
SET VERIFY ON;
SET LINESIZE 80;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode
    exec pkg_oem_job_datafile.p_oem_job_datafile_upd_01(p_reformat_job  => '${JOBNAME}',       \
                                                        p_file_sequence => '${FILE_SEQUENCE}', \
                                                        p_log_directory => '${OBJ_LOGDIR}',    \
                                                        p_log_filename  => '${LOGFILE}');
QUIT;
%
#------------------------------------------------------------------------------------------------

        fi
        trap 'oem_abndalrt.ksh $?' err
      else
        echo "No previous file found"

#------------------------------------------------------------------------------------------------
(sqlplus -s << % 2>&1)
${MPTUSERID}
SET ECHO ON;
SET FEEDBACK OFF;
SET VERIFY ON;
SET LINESIZE 80;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode
    exec pkg_oem_job_datafile.p_oem_job_datafile_upd_01(p_reformat_job  => '${JOBNAME}',       \
                                                        p_file_sequence => '${FILE_SEQUENCE}', \
                                                        p_log_directory => '${OBJ_LOGDIR}',    \
                                                        p_log_filename  => '${LOGFILE}');
QUIT;
%
#------------------------------------------------------------------------------------------------

      fi
      #******************************************************************************************
      FILE_SEQUENCE=`expr ${FILE_SEQUENCE} + 1`
    fi
  done


#STEP Step040R
  export STEPNAME=Step040R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME} - Check for Preprocess Script - " $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Check for Preprocess Script"
  #**********************************************************************************************
  #  Step040R - Preprocessing Required?
  #**********************************************************************************************
  if [ -z "${PREPROCESS_SCRIPT_NAME}" ]
  then
    break
  else
    ${PREPROCESS_SCRIPT_NAME}
  fi


#STEP Step049R
  export STEPNAME=Step049R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME} - Price Format Checker - " $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} p_oem_ref_price_check"
  #**********************************************************************************************
  #  Step049R - Review format of prices
  #**********************************************************************************************

#------------------------------------------------------------------------------------------------
(sqlplus -s << % 2>&1)
${MPTUSERID}
SET ECHO ON;
SET FEEDBACK OFF;
SET VERIFY ON;
SET LINESIZE 80;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode
    exec pkg_oem_ref_price_check.p_main_price_check(p_reformat_job       => '${REFORMATJOB}',      \
                                                    p_log_directory      => '${OBJ_LOGDIR}',       \
                                                    p_log_filename       => '${LOGFILE}',          \
                                                    p_debug_level        => '${RACE_DEBUG_LEVEL}', \
                                                    p_dbms_profiler_flag => '${RACE_DBMS_PROFILER_FLAG}');
QUIT;
%
#------------------------------------------------------------------------------------------------

#STEP Step050R
  export STEPNAME=Step050R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME} - 1st reformat - " $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} ${PACKAGE_NAME_1}"
  #**********************************************************************************************
  #  Step050R - Run 1st Reformat for this OEM job
  #**********************************************************************************************
  TRANS_FILE=${JOBNAME}_step050_transout.tmp
  RTRANS_FILE=${JOBNAME}_step050_rtransout.tmp
  REPORT_FILE=${JOBNAME}a_ref${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt
  
  # Remove xtab bad, dis, and log files that may have been left behind from a prior execution
  rm -f ${RACE}/tmp/${JOBNAME}_xtab_oem_ref_*.bad
  rm -f ${RACE}/tmp/${JOBNAME}_xtab_oem_ref_*.dis
  rm -f ${RACE}/tmp/${JOBNAME}_xtab_oem_ref_*.log

#------------------------------------------------------------------------------------------------
(sqlplus -s << % 2>&1)
${MPTUSERID}
SET ECHO ON;
SET FEEDBACK OFF;
SET VERIFY ON;
SET LINESIZE 80;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode
    exec ${PACKAGE_NAME_1}.p_main_reformat_records(p_reformat_job       => '${REFORMATJOB}',      \
                                                   p_log_directory      => '${OBJ_LOGDIR}',       \
                                                   p_log_filename       => '${LOGFILE}',          \
                                                   p_trans_directory    => '${OBJ_TMPDIR}',       \
                                                   p_trans_filename     => '${TRANS_FILE}',       \
                                                   p_rtrans_directory   => '${OBJ_TMPDIR}',       \
                                                   p_rtrans_filename    => '${RTRANS_FILE}',      \
                                                   p_report_directory   => '${OBJ_RPTDIR}',       \
                                                   p_report_filename    => '${REPORT_FILE}',      \
                                                   p_debug_level        => '${RACE_DEBUG_LEVEL}', \
                                                   p_dbms_profiler_flag => '${RACE_DBMS_PROFILER_FLAG}');
QUIT;
%
#------------------------------------------------------------------------------------------------


#STEP Step051R
  export STEPNAME=Step051R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME} - Report Distribution - " $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Report Distribution"
  #**************************************************************************************
  #  Emails and Handles Retention for Report(s) created in previous step  
  #**************************************************************************************
  email_rpt.ksh "${JOBNAME}a"               
  rpt_log_retention.ksh "${JOBNAME}a"  


#STEP Step055R
  export STEPNAME=Step055R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME} - 2nd reformat, if needed - " $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} ${PACKAGE_NAME_2}"
  #**********************************************************************************************
  #   Step055R - If found in oem_job table, execute the 2nd package for this OEM job
  #**********************************************************************************************
  if [ ! -z "${PACKAGE_NAME_2}" ]
  then
    TRANS_FILE=${JOBNAME}_step050_transout.tmp
    RTRANS_FILE=${JOBNAME}_step050_rtransout.tmp
    REPORT_FILE=${JOBNAME}b_ref${REPORTSUFFIX}_$(date +'%C%y%m%d%H%M%S').rpt

#------------------------------------------------------------------------------------------------
(sqlplus -s << % 2>&1)
${MPTUSERID}
SET ECHO ON;
SET FEEDBACK OFF;
SET VERIFY ON;
SET LINESIZE 80;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode
    exec ${PACKAGE_NAME_2}.p_main_reformat_records(p_reformat_job       => '${REFORMATJOB}',      \
                                                   p_log_directory      => '${OBJ_LOGDIR}',       \
                                                   p_log_filename       => '${LOGFILE}',          \
                                                   p_trans_directory    => '${OBJ_TMPDIR}',       \
                                                   p_trans_filename     => '${TRANS_FILE}',       \
                                                   p_rtrans_directory   => '${OBJ_TMPDIR}',       \
                                                   p_rtrans_filename    => '${RTRANS_FILE}',      \
                                                   p_report_directory   => '${OBJ_RPTDIR}',       \
                                                   p_report_filename    => '${REPORT_FILE}',      \
                                                   p_debug_level        => '${RACE_DEBUG_LEVEL}', \
                                                   p_dbms_profiler_flag => '${RACE_DBMS_PROFILER_FLAG}');
QUIT;
%
#------------------------------------------------------------------------------------------------

  email_rpt.ksh "${JOBNAME}b"              
  rpt_log_retention.ksh "${JOBNAME}b"
  
 fi 

#STEP Step060R
  export STEPNAME=Step060R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME} - XTAB Bad File Checker" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  #**********************************************************************************************
  #  Step060R - Query the oem_job_data table finding all External Tables 
  #             and create a temporary work file containing the External Table name(s)
  #**********************************************************************************************
  FILE_OF_XTABNAME=${REFORMATJOB}_xtabname.tmp

#------------------------------------------------------------------------------------------------
(sqlplus -s << % 2>&1)
${MPTUSERID}
SET VERIFY OFF
SET FEEDBACK OFF
SET TAB OFF
SET LINESIZE 100
SET PAGES 0
SET TRIMSPOOL ON
whenever sqlerror exit sql.sqlcode
    exec pkg_oem_job_datafile.p_oem_job_datafile_sel_02(p_reformat_job  => '${REFORMATJOB}',      \
                                                        p_tmp_directory => '${OBJ_TMPDIR}',       \
                                                        p_tmp_filename  => '${FILE_OF_XTABNAME}', \
                                                        p_log_directory => '${OBJ_LOGDIR}',       \
                                                        p_log_filename  => '${LOGFILE}');
QUIT;
%
#------------------------------------------------------------------------------------------------

  #**********************************************************************************************
  # For each External Table for this job, check to see if a "bad" file was generated.
  # If so, send an email notification (currently, 500 bad records are acceptable).
  #**********************************************************************************************
  export XTABNAME_FILE_ROW=1
  while true
  do
    export XTABNAME=`sed -n -e "${XTABNAME_FILE_ROW}p" < ${RACE}/tmp/${FILE_OF_XTABNAME}| cut -f1  -d"^"`
    #**********************************************************************************************
    # If ${XTABNAME} has no length, 
    # then XTABNAME_FILE_ROW exceeds the number of lines in file... get out!
    #**********************************************************************************************
    if [ -z "${XTABNAME}" ]
    then
      break
    else
      # Determine the name of the badfile based upon the table name
      BADFILE_NAME=${RACE}/tmp/${REFORMATJOB}_${XTABNAME}.bad
      if [ -s ${BADFILE_NAME} ]
      then
        echo "WARNING! ${XTABNAME} has a BAD file found: ${BADFILE_NAME}" 
        if [ ${THISHOST} = ${TESTHOST} ]
        then
          MAIL_TO="Rpt.OEM.Developers@Mitchell.com"
        else
          MAIL_TO="Rpt.OEM.Developers@Mitchell.com"
        fi         
        mailx -s "Warning! ${XTABNAME} generated BAD file!" ${MAIL_TO} < ${BADFILE_NAME}
      fi
      XTABNAME_FILE_ROW=`expr ${XTABNAME_FILE_ROW} + 1`
    fi
  done


#STEP Step100R
  export STEPNAME=Step100R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME} - Create XTAB backup(s) - " $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} Backup External Table Flat Files"
  #**********************************************************************************************
  #  Restart Step/File Checking
  #  When step restarting at THIS step, determine if a file sequence was requested.
  #**********************************************************************************************
  export FILE_SEQUENCE=1
  if [ "${RESTART}" = "${STEPNAME}" ] && [ ! -z "${RESTART_FILE_SEQUENCE}" ]
  then
    export FILE_SEQUENCE=${RESTART_FILE_SEQUENCE}
  fi
  #------------------------------------------------------------------------------------------------

  while true
  do
    #**********************************************************************************************
    # When ${INPUT_FILE_NAME} has no length, 
    # then FILE_SEQUENCE exceeds the number of lines in file... get out!
    #**********************************************************************************************
    export INPUT_FILE_NAME=`sed -n -e "${FILE_SEQUENCE}p" < ${WORKFILE}| cut -f2  -d"^"`
    if [ -z "${INPUT_FILE_NAME}" ]
    then
      break
    else
      export XTAB_FILE_NAME=`sed -n -e "${FILE_SEQUENCE}p"          < ${WORKFILE}| cut -f3  -d"^"`
      export XTAB_TABLE_NAME=`sed -n -e "${FILE_SEQUENCE}p"         < ${WORKFILE}| cut -f4  -d"^"`
      export FTP_PROGRAM_NAME=`sed -n -e "${FILE_SEQUENCE}p"        < ${WORKFILE}| cut -f5  -d"^"`
      export FTP_LOCATION_CODE=`sed -n -e "${FILE_SEQUENCE}p"       < ${WORKFILE}| cut -f6  -d"^"`
      export FORMAT_INDICATOR=`sed -n -e "${FILE_SEQUENCE}p"        < ${WORKFILE}| cut -f7  -d"^"`
      export SOURCE_FIELD_DELIMITER=`sed -n -e "${FILE_SEQUENCE}p"  < ${WORKFILE}| cut -f8  -d"^"`
      export TARGET_FIELD_SIZE=`sed -n -e "${FILE_SEQUENCE}p"       < ${WORKFILE}| cut -f9  -d"^"`
      export BACKUP_SOURCE_FILE_NAME=`sed -n -e "${FILE_SEQUENCE}p" < ${WORKFILE}| cut -f10 -d"^"`
      export FTP_SOURCE_FILE_NAME=`sed -n -e "${FILE_SEQUENCE}p"    < ${WORKFILE}| cut -f11 -d"^"`
      eval   FTP_SOURCE_FILE_NAME=${FTP_SOURCE_FILE_NAME} 
      export FTP_PARM_FILE_NAME=`sed -n -e "${FILE_SEQUENCE}p"      < ${WORKFILE}| cut -f14 -d"^"`     
      export DELETE_PROGRAM_NAME=`sed -n -e "${FILE_SEQUENCE}p"     < ${WORKFILE}| cut -f15 -d"^"`

      #******************************************************************************************
      # IF found, create GDG backup of the PREVIOUS "held" external table input file (aka raw file)
      #******************************************************************************************
      PREVRAW_FILE=${RACE}/dat/${XTAB_FILE_NAME}_prevraw.dat
      if [ -f "${PREVRAW_FILE}" ]
      then
        BACKUP_FILE=$(setgdg.ksh "${RACE}/dat/${XTAB_FILE_NAME}(+01)" NEW 3)
        cp -p ${PREVRAW_FILE} ${BACKUP_FILE}
        rm ${PREVRAW_FILE}
      fi
      #******************************************************************************************
      # If the source FTP file is on Mitchell's ftp server delete it.
      #******************************************************************************************
      if [ "${FTP_LOCATION_CODE}" = "M" ]
      then
         . oem_job_process_mitchell_ftp_file.ksh "BACKUP"
      else
        if [ "${DELETE_PROGRAM_NAME}" = "delete_sftp_file.pl" ]
        then
         delete_sftp_file.pl ${RACE}/prm/${FTP_PARM_FILE_NAME} ${FTP_SOURCE_FILE_NAME}
        fi
      fi

      FILE_SEQUENCE=`expr ${FILE_SEQUENCE} + 1`
    fi
  done

#************************************************************************************************
# END oem_ref.ksh
#************************************************************************************************
