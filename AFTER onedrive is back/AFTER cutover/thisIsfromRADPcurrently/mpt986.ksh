#!/bin/ksh
echo "RCS $Id: mpt986.ksh,v 1.3 2026/08/11 00:06:16 rj132422 Exp $"
set -xv
#*****************************************************************************************
# PROC NAME: mpt986.ksh                                              
# PROC DESC: Clean-up files that were created by a reformat job.
# STEPS: 
#     1) Read parm that contains JOBNAME and NUM_DAYS since files were created. 
#     2) Remove unix files.
#*****************************************************************************************

  trap 'abndalrt.ksh $?' err
  export PROCNAME=$(basename $0 .ksh_run)

  #**************************************************************************************
  # Process parm file and setup the Environment Variables 
  #************************************************************************************** 
  export PARM_FILE=${RACE}/prm/mpt986_remove_unix_files.prm

  export REFORMAT_JOB=`grep "REFORMAT_JOB=" ${PARM_FILE} | cut -f2 -d"="`
  export NUMDAYS=`grep "NUM_DAYS=" ${PARM_FILE}| cut -f2 -d"="` 
  
#STEP Step010
  export STEPNAME=Step010
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  #**************************************************************************************
  #  Unix file removal:
  #  1. If parm created in p_fix_process indicates "YES", remove associated unix files.
  #  2. Check if files were removed and if not, abend. If so, remove tmp files.
  #**************************************************************************************
  export REMOVAL_LIST=${RACE}/tmp/${JOBNAME}_files_for_removal.tmp
  export MAIL_TEXT=${RACE}/tmp/${JOBNAME}_email_text.tmp

  find ${RACE}/rpt/ -type f -name ${REFORMAT_JOB}\* -mtime -${NUMDAYS} -exec ls -l {} \;
  find ${RACE}/rpt/ -type f -name ${REFORMAT_JOB}\* -mtime -${NUMDAYS} -exec rm -f {} \;
  find ${RACE}/tmp/ -type f -name ${REFORMAT_JOB}\* -mtime -${NUMDAYS} -exec ls -l {} \;
  find ${RACE}/tmp/ -type f -name ${REFORMAT_JOB}\* -mtime -${NUMDAYS} -exec rm -f {} \;
  find ${RACE}/log/ -type f -name ${REFORMAT_JOB}\* -mtime -${NUMDAYS} -exec ls -l {} \;
  find ${RACE}/log/ -type f -name ${REFORMAT_JOB}\* -mtime -${NUMDAYS} -exec rm -f {} \;
  find ${RACE}/dat/ -type f -name ${REFORMAT_JOB}\* -mtime -${NUMDAYS} -exec ls -l {} \;
  find ${RACE}/dat/ -type f -name ${REFORMAT_JOB}\* -mtime -${NUMDAYS} -exec rm -f {} \;

  find ${RACE}/rpt/ -type f -name ${REFORMAT_JOB}\* -mtime -7 -exec ls -l {} \; > ${REMOVAL_LIST}
  find ${RACE}/tmp/ -type f -name ${REFORMAT_JOB}\* -mtime -7 -exec ls -l {} \; >> ${REMOVAL_LIST}
  find ${RACE}/log/ -type f -name ${REFORMAT_JOB}\* -mtime -7 -exec ls -l {} \; >> ${REMOVAL_LIST}
  find ${RACE}/dat/ -type f -name ${REFORMAT_JOB}\* -mtime -7 -exec ls -l {} \; >> ${REMOVAL_LIST}

  if [ ! -s "${REMOVAL_LIST}" ];
  then   
    echo "Unix files successfully deleted.\n" > ${MAIL_TEXT}   
    if [ ${THISHOST} = ${TESTHOST} ];
    then
      MAIL_TO="RACEBatchDL@mitchell.com"
      mailx -s "Test - ${JOBNAME} Completed" ${MAIL_TO} < ${MAIL_TEXT}
    else
      MAIL_TO="RaceDataOps@Mitchell.com,Rpt.OEM.Developers@Mitchell.com"
      mailx -s "Production - ${JOBNAME} Completed" ${MAIL_TO} < ${MAIL_TEXT}
    fi
    rm -f ${RACE}/tmp/${JOBNAME}*
  else
    echo "ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR\n" > ${MAIL_TEXT}
    echo "There are unix files that were created within the past 7 days still on the server.\n" >> ${MAIL_TEXT}
    echo "Verify if these files are the ones that you wished to remove.\n" >> ${MAIL_TEXT}
    echo "If they are, increase NUM_DAYS in param file and rerun job.\n" >> ${MAIL_TEXT}
    if [ ${THISHOST} = ${TESTHOST} ];
    then
      MAIL_TO="RACEBatchDL@mitchell.com"
      mailx -s "Test - ${JOBNAME}: Unix files not removed!" ${MAIL_TO} < ${MAIL_TEXT}
      $(abndalrt.ksh 986)
    else
      MAIL_TO="RaceDataOps@Mitchell.com,Rpt.OEM.Developers@Mitchell.com"
      mailx -s "Production - ${JOBNAME}: Unix files not removed!" ${MAIL_TO} < ${MAIL_TEXT}
      $(abndalrt.ksh 986)
    fi
  fi

#*****************************************************************************************
# END mpt986.ksh
#*****************************************************************************************