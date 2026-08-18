#!/bin/ksh
echo "RCS $Id: oem_ref_chr_fia_alf_ftp_prep.ksh,v 1.1 2022/07/11 23:42:02 pg2697 Exp $"

#*****************************************************************************************
# PROCNAME oem_ref_chr_fia_alf_ftp_prep.ksh                                              
# PURPOSE  For any of the Chrysler-related files, ensure the filename on our sftp server has a .zip extension
# PROCESS FLOW:
#            1. Get datafile name that is expected for pickup
#            2. Strip ".zip" from that name (because Chrysler omits the extension).
#            3. Check if file exists on the server with the ".zip" extension. If so, bypass any other processing
#            4. Check if file exists on the server without the ".zip" extension. If so, rename file to include extension.
#            5. If no file exists at all, send email noting file has not been staged and abend.
#*****************************************************************************************
trap 'oem_abndalrt.ksh $?' err
export LOGFILE=$(basename ${JOBLOGNAME})
PROCNAME=oem_ref_chr_fia_alf_ftp_prep.ksh
echo "\n\nSTART ---> ${PROCNAME} " $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n" 
export MPTUSERID=`cat ${RACE}/prm/zmptpass.prm`

#*****************************************************************************************
#  Build environment variables (based on jobname)
#*****************************************************************************************
echo "\n\n Build environment variables"
. oem_job.ksh         
. oem_job_datafile.ksh
#-----------------------------------------------------------------------------------------

#STEP Step005R
  export STEPNAME=Step005R
  echo "\n\n START ---> ${PROCNAME} ${STEPNAME} - Determine expected file name - " $(date +'%m/%d/%y %H:%M:%S') " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} oem_ref_chr_fia_alf_ftp_prep.ksh"

 
  #**********************************************************************************************
  # Get filename for FILE_SEQUENCE=1. (Chrysler/Fiat/Alfa only have one file each.)
  #**********************************************************************************************
  
    FILE_SEQUENCE=1
    export INPUT_FILE_NAME_EXT=`sed -n -e "${FILE_SEQUENCE}p" < ${WORKFILE}| cut -f2  -d"^"`
    echo "\n INPUT_FILE_NAME_EXT is: ${INPUT_FILE_NAME_EXT}"

  #**********************************************************************************************
  # Strip extension from INPUT_FILE_NAME_EXT to create name without extension
  #**********************************************************************************************
    export EXTENSION=$(echo $INPUT_FILE_NAME_EXT | awk -F. '{print $(NF)}') 
    export DOT=.
    export INPUT_FILE_NAME_NOEXT=$(basename $INPUT_FILE_NAME_EXT $DOT$EXTENSION)  
    echo " INPUT_FILE_NAME_NOEXT is: ${INPUT_FILE_NAME_NOEXT} \n"

  #**********************************************************************************************
  # 1) Check on server for filename without extension. If found, rename with extension. 
  # 2) If not found, check on server for filename with extension. If found, continue on. (This has already been run. Possible restart?)
  # 3) If not found, abend with No File Present error.
  # NOTE about ls commands: 2>/dev/null restricts warning "ls: cannot access {filename}: No such file or directory" from appearing in log.
  #                         Checks of FILES_COUNT handles the file checking.
  #**********************************************************************************************
    FTPSITE_DIRECTORY=${FTP_BUSINESS_PATH}/${JOBFILE_OEMCTRY}/${ACT_LVL}/incoming
    
    FTP_FILELIST=${RACE}/tmp/${JOBNAME}_ftplist.tmp

    # check filename WITHOUT extension
    FILES_COUNT=`ssh -nq ${FTP_SITE} ls -lt ${FTPSITE_DIRECTORY}/${INPUT_FILE_NAME_NOEXT} 2>/dev/null|grep -v '^total' > ${FTP_FILELIST}; wc -l ${FTP_FILELIST}|awk '{print $1}'`
    if [ "${FILES_COUNT}" = "1" ]
    then
      echo "************************************************"
      echo " ***** ${INPUT_FILE_NAME_NOEXT} found on ${FTP_SITE}"
      echo " ***** renamed to ${INPUT_FILE_NAME_EXT}"
      echo "************************************************"
      ssh -nq ${FTP_SITE} mv ${FTPSITE_DIRECTORY}/${INPUT_FILE_NAME_NOEXT} ${FTPSITE_DIRECTORY}/${INPUT_FILE_NAME_EXT}
    else
      # check filename with extension
      FILES_COUNT=`ssh -nq ${FTP_SITE} ls -lt ${FTPSITE_DIRECTORY}/${INPUT_FILE_NAME_EXT} 2>/dev/null|grep -v '^total' > ${FTP_FILELIST}; wc -l ${FTP_FILELIST}|awk '{print $1}'`
      if [ "${FILES_COUNT}" = "1" ]
      then
        echo "************************************************"
        echo "***** NOTE: ***** ${INPUT_FILE_NAME_EXT} already found on ${FTP_SITE}"
        echo "************************************************"
      else
        echo "************************************************"
        echo "***** ERROR ***** ${INPUT_FILE_NAME_EXT} is not on ${FTP_SITE}"
        echo "************************************************"
        oem_abndalrt.ksh  "No_file_present_on_"${FTP_SITE}
      fi
    fi


echo "\n\nEND ---> ${PROCNAME} " $(date +'%m/%d/%y %H:%M:%S')  " <--- END\n\n" 
#*****************************************************************************************
#END oem_ref_chr_fia_alf_ftp_prep.ksh 
#*****************************************************************************************
