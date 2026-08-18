#!/bin/ksh
#Id: oem_job_process_mitchell_ftp_file.ksh,v 1.3 2007/08/17 22:55:29 jw97143 Exp jw97143 $
#**************************************************************************************************
#    oem_job_process_mitchell_ftp_file.ksh
#**************************************************************************************************
echo "\n\n*** Begin oem_job_process_mitchell_ftp_file.ksh ${INPUT_FILE_NAME} ***\n\n"
trap 'oem_abndalrt.ksh $?' err
FILE_ACTION=$1
if [ $# -lt 1 ]
then
  echo "oem_job_process_mitchell_ftp_file.ksh requires input parameters"
  echo "   1. FILE_ACTION (GETIT or BACKUP)"
  oem_abndalrt.ksh oem_job_process_mitchell_ftp_file.ksh.parm.missing
fi
#**************************************************************************************************

if [ "${JOBCTRY}" = "PR" ]
then
   FTPSITE_DIRECTORY=${FTP_BUSINESS_PATH}/puerto_rico/${ACT_LVL}/incoming
else
   FTPSITE_DIRECTORY=${FTP_BUSINESS_PATH}/${JOBFILE_OEMCTRY}/${ACT_LVL}/incoming
fi

#**************************************************************************************************
# Retrieving files migrated from Novell process - rj132422 - 20251022 
if [ "${FILE_ACTION}" = "GETMIT" ]
then
    echo "Using Fixed Folder for Novell/NT to Mitchell FTP."

    export FTP_BUSINESS_PATH=${FTP_MITCHELL_BUSINESS_PATH}/${ACT_LVL}/oem/incoming

    FTPSITE_DIRECTORY=${FTP_BUSINESS_PATH}
	FILE_ACTION="GETIT"

fi
# **************************************************************************************************

###################################################################################################
#  Determine if the input file is using any wildcards, if so don't worry about the search
#  for UPPER and/or lower case filenames.
echo "\nDoes the input file name contain a wildcard?\n"
if expr "${INPUT_FILE_NAME}" : '.*[?*]'
then
  echo "${INPUT_FILE_NAME} contains wildcard."
  WORK_FTP_XFR_FILE_NAME=${INPUT_FILE_NAME}
else
  #  Build a temporary file containing all of the directory/filenames found in the OEM's incoming directory
  FTP_FILELIST=${RACE}/tmp/${JOBNAME}_${INPUT_FILE_NAME}_ftplist.tmp
  ssh -nq ${FTP_SFTP_USER}${FTP_SITE} "ls -1 ${FTPSITE_DIRECTORY}/*.*" > ${FTP_FILELIST}
  #  Point to the 1st record in the temporary file
  RECORD_NUMBER=1
  while true
  do
    #  Determine the directory/filename contained in the current record
    WORK_FTP_DIR_FILE_NAME=`sed -n -e "${RECORD_NUMBER}p" < ${FTP_FILELIST} | cut -f1`
    # If WORK_FTP_DIR_FILE_NAME has no length,
    # then the value of RECORD_NUMBER exceeds the number of records in the file ... get out!
    if [ -z "${WORK_FTP_DIR_FILE_NAME}" ]
    then
      break
    fi
    WORK_FTP_XFR_FILE_NAME=$(basename ${WORK_FTP_DIR_FILE_NAME})
    WORK_FTP_XFR_FILE_NAME_LOWER="`echo ${WORK_FTP_XFR_FILE_NAME} | sed \
    "/.*/y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/"`"
    WORK_INP_FILE_NAME=${INPUT_FILE_NAME}
    WORK_INP_FILE_NAME_LOWER="`echo ${WORK_INP_FILE_NAME} | sed \
    "/.*/y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/"`"

    if [ "${WORK_FTP_XFR_FILE_NAME_LOWER}" = "${WORK_INP_FILE_NAME_LOWER}" ]
    then
      export INPUT_FILE_NAME=${WORK_FTP_XFR_FILE_NAME}
      break
    fi
    
    echo "\nFile names do not match . . . increment record number"
    RECORD_NUMBER=`expr ${RECORD_NUMBER} + 1`
  done
fi
###################################################################################################

###################################################################################################
if [ "${FILE_ACTION}" = "GETIT" ]
then
  if [ "${INPUT_FILE_NAME}" = "${WORK_FTP_XFR_FILE_NAME}" ]
  then
    FTP_XFR_FILE_NAME=${RACE}/tmp/${JOBNAME}_${INPUT_FILE_NAME}
    # If the file to be transferred already exists, remove it
    rm -f ${FTP_XFR_FILE_NAME}
    echo "\nPreparing to scp file to ${FTP_XFR_FILE_NAME}\n"
    scp ${FTP_SFTP_USER}${FTP_SITE}:${FTPSITE_DIRECTORY}/${INPUT_FILE_NAME} ${FTP_XFR_FILE_NAME}
    # Verify that the file copied exists and that it contains data
    if [ ! -s ${FTP_XFR_FILE_NAME} ]
    then
      echo "\n*********************************************************************************"
      echo "File that was copied is empty or it does not exist!"
      echo "Source: ${FTP_SFTP_USER}${FTP_SITE}:${FTPSITE_DIRECTORY}/${INPUT_FILE_NAME}"
      echo "Target: ${FTP_XFR_FILE_NAME}"
      echo "*********************************************************************************\n"
      $(abndalrt.ksh 911)
    else
      echo "\nInput file pulled from Mitchell FTP Site is good\n"
    fi

    # Determine if the FTP'd file is zipped (or ZIPped)
    if [[ $( echo $INPUT_FILE_NAME | awk -F "." '{ print $NF }' ) = "g01" ]]
    then
       exit 0                           # exit if first g01
    fi
      
    export FILE_SUFFIX="."$( echo ${INPUT_FILE_NAME} | awk -F "." '{ print $NF }' )
    echo "\nFILE_SUFFIX: ${FILE_SUFFIX}\n"
    if [[ "${FILE_SUFFIX}" = ".zip" || "${FILE_SUFFIX}" = ".ZIP" ]]
    then
      echo "gunzip -c ${FTP_XFR_FILE_NAME} > ${STEP010_FILEOUT}"
      gunzip -c ${FTP_XFR_FILE_NAME} > ${STEP010_FILEOUT}
    else
      cp ${FTP_XFR_FILE_NAME} ${STEP010_FILEOUT}
    fi

    RECCNT1=$(wc -c ${STEP010_FILEOUT} | awk ' {print $1}' )
    if [ "${RECCNT1}" = "0" ]
    then
      echo "\n*************************************************"
      echo "copied or gunzip'd file ${STEP010_FILEOUT} is bad"
      echo "*************************************************\n"
      $(oem_abndalrt.ksh 911)
    else
      echo "\nCopied or gunzip'd file ${STEP010_FILEOUT} is good\n"
    fi
  else
    echo "\n************************************************************************"
    echo "Requested FTP File NOT Found: ${FTPSITE_DIRECTORY}/${INPUT_FILE_NAME}"
    echo "************************************************************************\n"
    $(oem_abndalrt.ksh ftp_file_not_found)
  fi
fi
###################################################################################################


###################################################################################################
# Remove the Production File
if [ "${FILE_ACTION}" = "BACKUP" ]
then
  if [ "${INPUT_FILE_NAME}" = "${WORK_FTP_XFR_FILE_NAME}" ]
  then
    export FTP_SITE_FILE_NAME=${FTPSITE_DIRECTORY}/${INPUT_FILE_NAME}
    if [ ${THISHOST} = ${PRODHOST} ]
    then
      echo "\nPreparing to remove file: ${FTP_SITE_FILE_NAME}\n"
      ssh -nq ${FTP_SFTP_USER}${FTP_SITE} rm -f ${FTP_SITE_FILE_NAME}
    fi
  else
    echo "\n************************************************************************"
    echo "Requested Site FTP File NOT Found: ${FTP_SITE_FILE_NAME}"
    echo "************************************************************************\n"
  fi
  ###################################################################################################
  # At this point, a transferred FTP file is sitting in /tmp
  # Back it up to /dat (WITHOUT the '*' because Novell backup fails with the '*')
  # Remove the Mitchell FTP Site files
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # Make the file name lower case   
  INPUT_FILE_NAME_LOWER="`echo ${INPUT_FILE_NAME} | sed \
  "/.*/y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/"`"
  # Remove the '*' 
  WORK_FTP_FILE_NAME="`echo ${JOBNAME}_${INPUT_FILE_NAME_LOWER} | sed s/*/./`"

  BACKUP_FTP_FILE=${RACE}/dat/${WORK_FTP_FILE_NAME}  
  EXISTING_FTP_FILE=$( setgdg.ksh "${BACKUP_FTP_FILE}(0)" )
  NEW_XFR_FTP_FILE=$( setgdg.ksh "${BACKUP_FTP_FILE}(+1)" NEW 2)
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # Backup the existing FTP'd file
  # rj132422 - prod3nt backup disabled (prod3nt decommissioned); local /dat GDG backup already covers it
  if false   # was: if [ -e ${EXISTING_FTP_FILE} ]
  then
    # Copy to ftp_data on 'Prod3nt\Cdprod02' bkup directory 
    FTP_LOGFILE=$RACE/tmp/${JOBNAME}_ftp_transfer_log.tmp
    fileput.exp ${EXISTING_FTP_FILE} ${WORK_FTP_FILE_NAME} ${NOVELL}oem/bkup | tee ${FTP_LOGFILE}
    # Verify the copy      
    GOODBYTECOUNT="$(wc -c ${EXISTING_FTP_FILE} | awk '{print $1}')"
    FTPBYTECOUNT="$(cat ${FTP_LOGFILE} | grep 'Information returned by' | awk '{print $1}')"   
    if [ ${GOODBYTECOUNT} -eq ${FTPBYTECOUNT} ]
    then
      echo "Successful ftp ${EXISTING_FTP_FILE}: ftp count = ${GOODBYTECOUNT}"
    else
      echo "ftp ${EXISTING_FTP_FILE} failed: ftp says ${FTPBYTECOUNT}, real count is ${GOODBYTECOUNT}"
      oem_abndalrt.ksh ftp_put
    fi
  fi
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # Backup the newly transferred file from /tmp to /dat
  #P. Becotte added below:
  echo "INPUT_FILE_NAME= ${INPUT_FILE_NAME}"
  echo "FTP_XFR_FILE_NAME before re-valuing= ${FTP_XFR_FILE_NAME}"
  FTP_XFR_FILE_NAME=${RACE}/tmp/${JOBNAME}_${INPUT_FILE_NAME}
  echo "FTP_XFR_FILE_NAME= ${FTP_XFR_FILE_NAME}"
  #P. Becotted end of change
  cp ${FTP_XFR_FILE_NAME} ${NEW_XFR_FTP_FILE}
  # rj132422 - prod3nt backup disabled (prod3nt decommissioned); the local /dat backup above already covers it
  if false; then
  # Copy to ftp_data on 'Prod3nt\Cdprod02' bkup directory 
  FTP_LOGFILE=$RACE/tmp/${JOBNAME}_ftp_transfer_log_new.tmp   
  fileput.exp ${NEW_XFR_FTP_FILE} ${WORK_FTP_FILE_NAME} ${NOVELL}oem | tee ${FTP_LOGFILE}
  GOODBYTECOUNT="$(wc -c ${NEW_XFR_FTP_FILE} | awk '{print $1}')"
  FTPBYTECOUNT="$(cat ${FTP_LOGFILE} | grep 'Information returned by' | awk '{print $1}')" 
  if [ ${GOODBYTECOUNT} -eq ${FTPBYTECOUNT} ]
  then
    echo "Successful ftp ${NEW_XFR_FTP_FILE}: ftp count = ${GOODBYTECOUNT}"
  else
    echo "ftp ${NEW_XFR_FTP_FILE} failed: ftp says ${FTPBYTECOUNT}, real count is ${GOODBYTECOUNT}"
    oem_abndalrt.ksh ftp_put
  fi
  fi
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -   
fi
###################################################################################################   

#**************************************************************************************************
# END oem_job_process_mitchell_ftp_file.ksh
#**************************************************************************************************
