#!/bin/ksh
echo "RCS $Id: oem_ref_mptr825_ftp_lynn_to_editorial.ksh,v 1.1 2023/06/27 23:17:48 pg2697 Exp $"
set -xv
#*****************************************************************************************
# PROCNAME oem_ref_mptr825_ftp_lynn_to_editorial.ksh                                            
# PURPOSE  Pick-up the latest LYNN File from NT oem staging directory, put a copy on NT 
#          editorial directory (for use by Editors), and send email notification.
#*****************************************************************************************
trap 'oem_abndalrt.ksh $?' err
export PROCNAME=$(basename $0 .ksh_run)
export MPTUSERID=`cat ${RACE}/prm/zmptpass.prm`
export LOGFILE=$(basename ${JOBLOGNAME})

#*****************************************************************************************
#  Build environment variables for the job (based on jobname)
#*****************************************************************************************
. oem_job.ksh         
. oem_job_notify.ksh
. oem_job_datafile.ksh

OEM_JOB_DATAFILE_INFO=${RACE}/tmp/${JOBNAME}_oem_job_datafile.tmp
#XTAB_FILE_NAME=`sed -n -e "1p"          < ${OEM_JOB_DATAFILE_INFO}| cut -f3  -d"^"`
#XTAB_TABLE_NAME=`sed -n -e "1p"         < ${OEM_JOB_DATAFILE_INFO}| cut -f4  -d"^"`
#FORMAT_INDICATOR=`sed -n -e "1p"        < ${OEM_JOB_DATAFILE_INFO}| cut -f7  -d"^"`
#SOURCE_FIELD_DELIMITER=`sed -n -e "1p"  < ${OEM_JOB_DATAFILE_INFO}| cut -f8  -d"^"`
#TARGET_FIELD_SIZE=`sed -n -e "1p"       < ${OEM_JOB_DATAFILE_INFO}| cut -f9  -d"^"`         
INPUT_FILE_NAME=`sed -n -e "1p"         < ${OEM_JOB_DATAFILE_INFO}| cut -f2  -d"^"`
FTP_PROGRAM_NAME=`sed -n -e "1p"        < ${OEM_JOB_DATAFILE_INFO}| cut -f5  -d"^"`
FTP_LOCATION_CODE=`sed -n -e "1p"       < ${OEM_JOB_DATAFILE_INFO}| cut -f6  -d"^"`
BACKUP_SOURCE_FILE_NAME=`sed -n -e "1p" < ${OEM_JOB_DATAFILE_INFO}| cut -f10 -d"^"`
SOURCE_FILE=${RACE}/dat/${BACKUP_SOURCE_FILE_NAME}
FTP_SOURCE_FILE_NAME=`sed -n -e "1p"    < ${OEM_JOB_DATAFILE_INFO}| cut -f11 -d"^"`

# Some file names contain executable commands -- flush them out
eval FTP_SOURCE_FILE_NAME=${FTP_SOURCE_FILE_NAME} 
FTP_PARM_FILE_NAME=`sed -n -e "1p"      < ${OEM_JOB_DATAFILE_INFO}| cut -f14  -d"^"`         
#*****************************************************************************************

#STEP Step001R
  export STEPNAME=Step001R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} oem_ref_mptr825_ftp_lynn_to_editorial"
  #**************************************************************************************
  #  Transfer the file(s) defined in the oem_job_datafile table
  #**************************************************************************************
  . oem_job_datafile_prep.ksh                 


#STEP Step002R
  export STEPNAME=Step002R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n" 
  oem_job_status_update.ksh "R" "${STEPNAME} oem_ref_mptr825_ftp_lynn_to_editorial"
  #**********************************************************************************************
  # Make sure the file exists to transfer to the Network... send email when it is sent
  # Use same file name as you picked up. (i.e. $INPUT_FILE_NAME) 
  #**********************************************************************************************
  FTP_LOGFILE=${RACE}/tmp/${JOBNAME}_transfer_log.tmp
  
  if [ -e ${SOURCE_FILE} ]
  then
    # Copy the source file to the Network      
    # rj132422 - prod3nt sunset: deliver to Mitchell oem_research via scp (was: fileput.exp ${INPUT_FILE_NAME} to ${NOVELL}oem_research)
    RESEARCH_DIR=${FTP_MITCHELL_BUSINESS_PATH}/${ACT_LVL}/oem_research
    scp ${SOURCE_FILE} ${FTP_SFTP_USER}${FTP_SITE}:${RESEARCH_DIR}/${INPUT_FILE_NAME} | tee ${FTP_LOGFILE}
    # Verify the copy is good       
    GOODBYTECOUNT="$(wc -c ${SOURCE_FILE} | awk '{print $1}')"
    FTPBYTECOUNT="$(ssh -nq ${FTP_SFTP_USER}${FTP_SITE} "wc -c < ${RESEARCH_DIR}/${INPUT_FILE_NAME}")"  # rj132422 remote byte-count via ssh
    if [ ${GOODBYTECOUNT} -eq ${FTPBYTECOUNT} ]
    then
      echo "Successful ftp ${SOURCE_FILE}: ftp count = ${GOODBYTECOUNT}"
      # Send email notification that the file was transferred to the Network
      MAIL_RECIP="Rpt.OEM.Data.Analyst@Mitchell.com"
      MAIL_SUBJECT="${JOBNAME} ${JOBOEMNAME} ${JOBOEM} ${JOBCTRY}: Transfer Source File to Network for Editor Use" 
      export MAIL_TEXT=${RACE}/tmp/${JOBNAME}_email_text.tmp    
      echo "\nThe LYNN Truck Parts file has been transferred to the Network \n"               > ${MAIL_TEXT}
      echo '\\\prod3nt\\cdprod02\\ftp_data\\'"$ACT_LVL"'\\oem_research\\' as "$INPUT_FILE_NAME" >> ${MAIL_TEXT}     
      echo "\nWhat to do?"   >> ${MAIL_TEXT}
      echo "\nEditorial Parts: "  >> ${MAIL_TEXT}
      echo "   1. MOVE this file into: '\\\dept01nas\\dept\\PubTeams\\Editorial Research\\COMMERCIAL\\LYNN\\' " >> ${MAIL_TEXT}
      echo "   2. Use Excel to view file as it is pipe-delimited. (i.e. Open EXCEL; Get Data; select file; note delimiter as '|')" >> ${MAIL_TEXT}
      echo "   3. Editors use files, as needed."                                         >> ${MAIL_TEXT}
      if [ ${THISHOST} = ${TESTHOST} ]
      then
        ##mailx -s "TEST - ${MAIL_SUBJECT} " "Rpt.OEM.Developers@mitchell.com" < ${MAIL_TEXT}
        mailx -s "TEST - ${MAIL_SUBJECT} " "penny.genovese@mitchell.com" < ${MAIL_TEXT}
      else
        mailx -s "${MAIL_SUBJECT}" ${MAIL_RECIP} < ${MAIL_TEXT}      
      fi          
    else
      echo "ftp ${SOURCE_FILE} failed: ftp says ${FTPBYTECOUNT}, real count is ${GOODBYTECOUNT}"
      oem_abndalrt.ksh ftp_put
    fi
  else
    echo "Error: no file to ftp!!\a"
    oem_abndalrt.ksh ftp_file_no_file_found
  fi
 
#*****************************************************************************************
# END oem_ref_mptr825_ftp_lynn_to_editorial.ksh
#*****************************************************************************************
