#!/bin/ksh
echo "RCS $Id: mpt149.ksh,v 1.6 2012/05/22 01:40:38 pg2697 Exp $"
set -xv
#*****************************************************************************************
# PROCNAME mpt149.ksh                                              
# PURPOSE  US & Canada Volvo - Check FTP Site for input files     
#          Send an email to RACEDataOps on the status of the files      
#*****************************************************************************************
trap 'oem_abndalrt.ksh $?' err
export PROCNAME=$(basename $0 .ksh_run)
export MPTUSERID=`cat ${RACE}/prm/zmptpass.prm`
export LOGFILE=$(basename ${JOBLOGNAME})
#*****************************************************************************************

#STEP Step010R
  export STEPNAME=Step010R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  #**************************************************************************************
  #  Retrieve the table values to setup the Environment Variables 
  #**************************************************************************************
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
    exec pkg_oem_job_datafile.p_oem_job_datafile_sel_05_vol(p_reformat_job  => '${REFORMATJOB}', \
                                                            p_tmp_directory => '${OBJ_TMPDIR}',  \
                                                            p_tmp_filename  => '${WORKFILE}',    \
                                                            p_log_directory => '${OBJ_LOGDIR}',  \
                                                            p_log_filename  => '${LOGFILE}');
QUIT;
%
#----------------------------------------------------------------------------------------
  WORKFILE=${RACE}/tmp/${WORKFILE}
  MAIL_RECIP="$(awk '{print $1}' ${RACE}/prm/oem_job_datafile_prep_xftp_email_address.prm)"
  MAIL_SUBJECT="${JOBNAME} File Status"
  MAIL_TEXT=${RACE}/tmp/${JOBNAME}_email_text.tmp    
  echo "\nFile status" > ${MAIL_TEXT}
   
  # For each "row" (i.e. file) found in oem_job_datafile (written into the ${WORKFILE} file)
  export FILE_SEQUENCE=1
  while true
  do
    #**********************************************************************************************************
    #   When ${FTP_PROGRAM_NAME} has no length,then FILE_SEQUENCE exceeds the number of lines in file... get out!
        export FTP_PROGRAM_NAME=`sed -n -e "${FILE_SEQUENCE}p" < ${WORKFILE}| cut -f1 -d"^"`
    if [ -z "${FTP_PROGRAM_NAME}" ]
    then
      break
    else
      export FTP_SOURCE_FILE_NAME=`sed -n -e "${FILE_SEQUENCE}p" < ${WORKFILE}| cut -f2 -d"^"`
      export INPUT_FILE_NAME=`sed -n -e "${FILE_SEQUENCE}p"      < ${WORKFILE}| cut -f3 -d"^"`     
      export FTP_PARM_FILE_NAME=`sed -n -e "${FILE_SEQUENCE}p"   < ${WORKFILE}| cut -f4 -d"^"`
      eval FTP_SOURCE_FILE_NAME=${FTP_SOURCE_FILE_NAME}
      FTP_PULL_TARGET=${RACE}/tmp/${INPUT_FILE_NAME}    
      rm -f ${FTP_PULL_TARGET}
      #  Run the customized program to logon to OEM's FTP site and retrieve file
      #  This information is maintained in oem_job_datafile.ftp_program_name
      #                             and in oem_job_datafile.ftp_source_file_name        
      ${FTP_PROGRAM_NAME} ${RACE}/prm/${FTP_PARM_FILE_NAME} ${FTP_SOURCE_FILE_NAME} ${FTP_PULL_TARGET}
      if [ ! -s ${FTP_PULL_TARGET} ]
      then
        #****************************************************************************************
        # Send email notification
        #****************************************************************************************
        MAIL_SUBJECT="${JOBNAME} File Status - Error During File Status Check"
        echo "\nThis file was NOT retrieved from the External FTP Site: ${FTP_SOURCE_FILE_NAME}\n" >> ${MAIL_TEXT}
      else
        echo "\nThis file OK. FROM: ${FTP_SOURCE_FILE_NAME} TO: ${FTP_PULL_TARGET}\n" >> ${MAIL_TEXT}
      fi
      FILE_SEQUENCE=`expr ${FILE_SEQUENCE} + 1`
    fi
  done

  if [ ${THISHOST} = ${TESTHOST} ]
  then
     mailx -s "TEST - ${MAIL_SUBJECT}" "Janet.Wilson@Mitchell.com" < ${MAIL_TEXT}
  else
     mailx -s "${MAIL_SUBJECT}" ${MAIL_RECIP} < ${MAIL_TEXT}      
  fi          


#STEP Step999R
  export STEPNAME=Step999R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  #**************************************************************************************
  # Delete tmp files
  #**************************************************************************************
  rm -f $RACE/tmp/${JOBNAME}*.tmp

#*****************************************************************************************
# END mptr149.ksh
#*****************************************************************************************
