#!/bin/ksh
set -xv
#*****************************************************************************************
# PROCNAME mpt905.ksh                                            
# PURPOSE  Create DataOps Report from oem_job and oem_job_datafile tables.
#          Report info assists in file staging and reformat setup of OEM Part Price files.
#*****************************************************************************************
trap 'abndalrt.ksh $?' err
export PROCNAME=$(basename $0 .ksh_run)
export LOGFILE=$(basename ${JOBLOGNAME})
export MPTUSERID=`cat ${RACE}/prm/zmptpass.prm`

#STEP Step010R
  export STEPNAME=Step010R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n" 
  ##########################################################################
  # STEP NAME:  Step010R
  # STEP DESC:  Execute Oracle procedure to create report                                 
  ##########################################################################

(sqlplus -s << CODE_BLOCK 2>&1)
${MPTUSERID}

SET ECHO ON;
SET FEEDBACK OFF;
SET VERIFY ON;
SET LINESIZE 80;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

    exec pkg_oem_parts_batch_setup_rpt.p_create_report(p_rpt_dir  => '${OBJ_RPTDIR}', \
         p_rpt_file => '${JOBNAME}a_setup.rpt');

QUIT;
CODE_BLOCK

	
#STEP Step020R
  export STEPNAME=Step020R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S') 
  ##########################################################################
  # STEP NAME:  Step020R
  # STEP DESC:  Copy the report file to Network                                      
  ##########################################################################
 
  REPORT_UX=${RACE}/rpt/${JOBNAME}a_setup.rpt
  REPORT_NT=${JOBNAME}a_setup.rpt
  FTP_LOGFILE=${RACE}/tmp/${JOBNAME}_${STEPNAME}_transfer_log.tmp
  NT_DIR=${FTP_MITCHELL_BUSINESS_PATH}/${ACT_LVL}/oem/outgoing  # rj132422 prod3nt sunset: Mitchell outgoing (was: ${NOVELL}oem)
  
  if [ -e ${REPORT_UX} ]
  then
    ########################################################################################
    # Copy the report file to the Network      
    ########################################################################################
    # rj132422 - prod3nt sunset: scp to Mitchell outgoing (was: fileput.exp ${REPORT_UX} ${REPORT_NT} ${NT_DIR})
    scp ${REPORT_UX} ${FTP_SFTP_USER}${FTP_SITE}:${NT_DIR}/${REPORT_NT} | tee ${FTP_LOGFILE}
    
    ########################################################################################
    # Verify the copy is good       
    ########################################################################################
    GOODBYTECOUNT="$(wc -c ${REPORT_UX} | awk '{print $1}')"
    FTPBYTECOUNT="$(ssh -nq ${FTP_SFTP_USER}${FTP_SITE} "wc -c < ${NT_DIR}/${REPORT_NT}")"  # rj132422 remote byte-count via ssh
    if [ ${GOODBYTECOUNT} -eq ${FTPBYTECOUNT} ]
    then
      echo "Successful File transfer to NT ${NT_DIR}. ${REPORT_UX} ftp count = ${GOODBYTECOUNT}" 
      # Send email notification that the file was transferred to the Network
      PROD_MAIL_RECIP="Rpt.OEM.Developers@Mitchell.com, RACEDataOps@Mitchell.com"  # rj132422 s-nail: comma, not ; between addresses
      TEST_MAIL_RECIP="Penny.Genovese@Mitchell.com, Sarika.Gupta@Mitchell.com"  # rj132422 s-nail: comma, not ; between addresses
      MAIL_SUBJECT="${JOBNAME}: OEM Batch Setup Information Report has been generated." 
      export MAIL_TEXT=${RACE}/tmp/${JOBNAME}_email_text.tmp    
      echo "\nThe OEM Batch Setup Information Report has been generated and transferred to the Network \n" > ${MAIL_TEXT}
      echo '\\\prod3nt\\cdprod02\\ftp_data\\'${ACT_LVL}'\\oem\\'${REPORT_NT}   >> ${MAIL_TEXT}     
      echo "\nWhat to do?"                                                      >> ${MAIL_TEXT}
      echo "   1. Use report information, as needed to setup / research OEMs."  >> ${MAIL_TEXT}
      echo "\nNote: This report is produced on a weekly basis (and upon request)." >> ${MAIL_TEXT}
      if [ ${THISHOST} = ${TESTHOST} ]
      then
        mailx -s "TEST - ${MAIL_SUBJECT}" ${TEST_MAIL_RECIP} < ${MAIL_TEXT}
      else
        mailx -s "${MAIL_SUBJECT}" ${PROD_MAIL_RECIP} < ${MAIL_TEXT}      
      fi            
    else
      echo "File transfer of ${REPORT_UX} to NT ${NT_DIR} failed: ftp says ${FTPBYTECOUNT}, real count is ${GOODBYTECOUNT}"
      $(abndalrt.ksh 911)
    fi
  else
    echo "\n\nError: no ${REPORT_UX} file to ftp!!\n"
    $(abndalrt.ksh 911)
  fi  

     
#STEP Step999R
  export STEPNAME=Step999R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')
  ##########################################################################
  # STEP NAME:  Step999R
  # STEP DESC:  Removes job-related temporary files
  ##########################################################################
  rm -rf ${RACE}/tmp/${JOBNAME}*
  

#*****************************************************************************************
# END mpt905.ksh
#*****************************************************************************************
