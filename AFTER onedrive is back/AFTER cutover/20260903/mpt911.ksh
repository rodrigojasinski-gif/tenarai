#!/bin/ksh
echo "RCS $Id: mpt911.ksh,v 1.5 2026/08/10 17:44:02 rj132422 Exp $"
set -xv
#*****************************************************************************************
# PROC NAME: mpt911.ksh                                              
# PROC DESC: Clean-up files and database rows that were created when the wrong reformat
#            job has been run.
# STEPS: 
#     1) Read parm that contains JOBNAME, OEM, CNTRY, and EFFECTIVE DATE that was 
#        incorrectly processed. While some of this could be "calculated" from the database,
#        we want it entered by DataOps. This is a powerful job so extreme caution should be
#        taken when entering parameter info. We don't want the wrong OEM's data backed out.
#     2) Verify information and perform database fixes.
#     3) Remove unix files, if parameter file created by Step2 designates to do so.
#*****************************************************************************************

  trap 'abndalrt.ksh $?' err
  export PROCNAME=$(basename $0 .ksh_run)

  #**************************************************************************************
  # Process parm file and setup the Environment Variables 
  #************************************************************************************** 
  export PARM_FILE=${RACE}/prm/mpt911_oem_cleanup_info.prm

  export MEDIA_STATUS=`grep "MEDIA_STATUS=" ${PARM_FILE} | cut -f2 -d"="`
  export PART_SUPPLIER=`grep "PART_SUPPLIER=" ${PARM_FILE}| cut -f2 -d"="`
  export COUNTRY=`grep "COUNTRY=" ${PARM_FILE}| cut -f2 -d"="`
  export EFF_DATE=`grep "EFF_DATE=" ${PARM_FILE}| cut -f2 -d"="`
  export REPL_FLAG=`grep "REPLACE=" ${PARM_FILE}| cut -f2 -d"="` 

  export REFORMAT_STATUS=`grep "REFORMAT_STATUS=" ${PARM_FILE} | cut -f2 -d"="`
  export REFORMAT_JOB=`grep "REFORMAT_JOB=" ${PARM_FILE} | cut -f2 -d"="`
  export NUMDAYS=`grep "NUM_DAYS=" ${PARM_FILE}| cut -f2 -d"="` 
  
  export MPTUSERID=`cat ${RACE}/prm/zmptpass.prm`

#STEP Step010R
  export STEPNAME=Step010R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  #**************************************************************************************
  #  Execute procedure to cleanup database tables and determine if unix files require cleanup. 
  #  1. Verify parm values
  #  2. Perform database cleanup based on parm values.
  #  3. Log all database activity in tmp file, as well as indicator whether unix files
  #     should be removed.
  #  4. Display what was logged in tmp file so that job log contains info as well.
  #**************************************************************************************

  sqlplus << CODE_BLOCK 2>&1 > $LOG
$MPTUSERID
SET VERIFY OFF;
SET FEEDBACK OFF;
SET LINESIZE 100;
SET ECHO ON;
SET SERVEROUTPUT ON FORMAT WRAPPED;
whenever sqlerror exit sql.sqlcode

    exec pkg_oem_fix_run.p_fix_process(p_in_media_status          => '${MEDIA_STATUS}', \
                                       p_in_part_supplier_number  => '${PART_SUPPLIER}',  \
                                       p_in_part_supplier_country => '${COUNTRY}', \
                                       p_in_effective_date        => '${EFF_DATE}', \
                                       p_in_replacement_run_flag  => '${REPL_FLAG}', \
                                       p_in_reformat_status       => '${REFORMAT_STATUS}', \
                                       p_in_reformat_job          => '${REFORMAT_JOB}', \
                                       p_in_prm_dirname           => '${OBJ_TMPDIR}', \
                                       p_in_prm_filename          => '${JOBNAME}_process_info.tmp');
QUIT;
CODE_BLOCK

  echo ${RACE}/tmp/${JOBNAME}_process_info.tmp   

#STEP Step020R
  export STEPNAME=Step020R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  #**************************************************************************************
  #  Unix file removal:
  #  1. If parm created in p_fix_process indicates "YES", remove associated unix files.
  #  2. Check if files were removed.
  #     If NOT removed, abend.
  #     If successfully removed (or not removal needed), remove tmp files created by fix.
  #**************************************************************************************
  export PROCESS_INFO=${RACE}/tmp/${JOBNAME}_process_info.tmp
  export DELETE_IND=`grep "DELETE=" ${PROCESS_INFO}| cut -f2 -d"="` 
  export REMOVAL_LIST=${RACE}/tmp/${JOBNAME}_files_for_removal.tmp
  export MAIL_TEXT=${RACE}/tmp/${JOBNAME}_email_text.tmp

  if [ "${DELETE_IND}" == "YES" ];
  then 
    find ${RACE}/rpt/ -type f -name ${REFORMAT_JOB}\* -mtime -${NUMDAYS} -exec ls -l {} \;
    find ${RACE}/rpt/ -type f -name ${REFORMAT_JOB}\* -mtime -${NUMDAYS} -exec rm -f {} \;
    find ${RACE}/tmp/ -type f -name ${REFORMAT_JOB}\* -mtime -${NUMDAYS} -exec ls -l {} \;
    find ${RACE}/tmp/ -type f -name ${REFORMAT_JOB}\* -mtime -${NUMDAYS} -exec rm -f {} \;
    find ${RACE}/log/ -type f -name ${REFORMAT_JOB}\* -mtime -${NUMDAYS} -exec ls -l {} \;
    find ${RACE}/log/ -type f -name ${REFORMAT_JOB}\* -mtime -${NUMDAYS} -exec rm -f {} \;
    find ${RACE}/dat/ -type f -name ${REFORMAT_JOB}\* -mtime -${NUMDAYS} -exec ls -l {} \;
    find ${RACE}/dat/ -type f -name ${REFORMAT_JOB}\* -mtime -${NUMDAYS} -exec rm -f {} \;
  fi

  find ${RACE}/rpt/ -type f -name ${REFORMAT_JOB}\* -mtime -7 -exec ls -l {} \; > ${REMOVAL_LIST}
  find ${RACE}/tmp/ -type f -name ${REFORMAT_JOB}\* -mtime -7 -exec ls -l {} \; >> ${REMOVAL_LIST}
  find ${RACE}/log/ -type f -name ${REFORMAT_JOB}\* -mtime -7 -exec ls -l {} \; >> ${REMOVAL_LIST}
  find ${RACE}/dat/ -type f -name ${REFORMAT_JOB}\* -mtime -7 -exec ls -l {} \; >> ${REMOVAL_LIST}

  if [ "${REFORMAT_STATUS}" == "NOTRUN" ];
  then   
    cat ${PROCESS_INFO} > ${MAIL_TEXT}
    echo " \n" >> ${MAIL_TEXT}
    echo "Since OEM_Reformat was not run, there was no request made for unix file removal.\n" >> ${MAIL_TEXT}   
    if [ ${THISHOST} = ${TESTHOST} ];
    then
      MAIL_TO="RACEBatchDL@mitchell.com"
      mailx -s "Test - ${JOBNAME} Completed" ${MAIL_TO} < ${MAIL_TEXT}
    else
      MAIL_TO="RaceDataOps@Mitchell.com Rpt.OEM.Developers@Mitchell.com"  # rj132422 - space-separated for RHEL s-nail (was: ',' separator)
      mailx -s "Production - ${JOBNAME} Completed" ${MAIL_TO} < ${MAIL_TEXT}
    fi
    rm -f ${RACE}/tmp/${JOBNAME}*
  elif [ ! -s "${REMOVAL_LIST}" ] ;
  then   
      cat ${PROCESS_INFO} > ${MAIL_TEXT}
      echo " \n" >> ${MAIL_TEXT}
      echo "Unix files successfully deleted.\n" >> ${MAIL_TEXT}   
      if [ ${THISHOST} = ${TESTHOST} ];
      then
        MAIL_TO="RACEBatchDL@mitchell.com"
        mailx -s "Test - ${JOBNAME} Completed" ${MAIL_TO} < ${MAIL_TEXT}
      else
        MAIL_TO="RaceDataOps@Mitchell.com Rpt.OEM.Developers@Mitchell.com"  # rj132422 - space-separated for RHEL s-nail (was: ',' separator)
        mailx -s "Production - ${JOBNAME} Completed" ${MAIL_TO} < ${MAIL_TEXT}
      fi
      rm -f ${RACE}/tmp/${JOBNAME}*
  else
      cat ${PROCESS_INFO} > ${MAIL_TEXT}
      echo " \n" >> ${MAIL_TEXT}
      echo " \n" >> ${MAIL_TEXT}
      echo "ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR\n" >> ${MAIL_TEXT}
      echo "There are unix files that were created within the past 7 days still on the server.\n" >> ${MAIL_TEXT}
      echo "Verify if these files are associated to the BAD run.\n" >> ${MAIL_TEXT}
      echo "If they are, increase NUM_DAYS in param file and restart job at ${STEPNAME}.\n" >> ${MAIL_TEXT}
      if [ ${THISHOST} = ${TESTHOST} ];
      then
        MAIL_TO="RACEBatchDL@mitchell.com"
        mailx -s "Test - ${JOBNAME}: Unix files not removed!" ${MAIL_TO} < ${MAIL_TEXT}
        $(abndalrt.ksh 911)
      else
        MAIL_TO="RaceDataOps@Mitchell.com Rpt.OEM.Developers@Mitchell.com"  # rj132422 - space-separated for RHEL s-nail (was: ',' separator)
        mailx -s "Production - ${JOBNAME}: Unix files not removed!" ${MAIL_TO} < ${MAIL_TEXT}
        $(abndalrt.ksh 911)
      fi
  fi
 

#*****************************************************************************************
# END mpt911.ksh
#*****************************************************************************************
