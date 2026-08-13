#!/bin/ksh
set -xv
#*****************************************************************************************
# PROCNAME oem_ref_mptr249_ftp_hdmus_source_file.ksh                                            
# PURPOSE  Transfer harley davidson zip file from NT to Unix
#          Remove all xlsx files from zip file and stage on NT server for pickup by reformat script
#*****************************************************************************************
trap 'oem_abndalrt.ksh $?' err
export PROCNAME=$(basename $0 .ksh_run)
export LOGFILE=$(basename ${JOBLOGNAME})

#*****************************************************************************************
#  Build environment variables for the job (based on jobname)
#*****************************************************************************************
. oem_job.ksh         
. oem_job_notify.ksh
. oem_job_datafile.ksh

OEM_JOB_DATAFILE_INFO=${RACE}/tmp/${JOBNAME}_oem_job_datafile.tmp       
INPUT_FILE_NAME=`sed -n -e "1p"         < ${OEM_JOB_DATAFILE_INFO}| cut -f2  -d"^"` #Pricebook*.zip
BACKUP_SOURCE_FILE_NAME=`sed -n -e "1p" < ${OEM_JOB_DATAFILE_INFO}| cut -f10 -d"^"` #mptr249_araw_hdmus.zip
SOURCE_FILE=${RACE}/dat/${BACKUP_SOURCE_FILE_NAME}

#*****************************************************************************************

#STEP Step010R
  export STEPNAME=Step010R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} oem_ref_mptr249_ftp_hdmus_source_file"

  export NT_DIR=${FTP_MITCHELL_BUSINESS_PATH}/${ACT_LVL}/oem/incoming  # rj132422 prod3nt sunset: Mitchell SFTP incoming (was: NOVELL_DIR=${NOVELL}oem)
  export STDOUT=${RACE}/tmp/${JOBNAME}_${INPUT_FILE_NAME}_log.tmp

  scp ${FTP_SFTP_USER}${FTP_SITE}:${NT_DIR}/${INPUT_FILE_NAME} ${SOURCE_FILE} | tee ${STDOUT}  # rj132422 scp get from Mitchell (was: fileget.exp ${INPUT_FILE_NAME} ${SOURCE_FILE} ${NOVELL_DIR})


  #Check that SOURCE_FILE exists and is not Null:
  if [ ! -s $SOURCE_FILE ]
  then
		echo "Error: Unix file was not created !!\a"
		abndalrt.ksh ftp_null_file
  fi

  novelcount="$(ssh -nq ${FTP_SFTP_USER}${FTP_SITE} "wc -c < ${NT_DIR}/${INPUT_FILE_NAME}")"  # rj132422 remote byte-count via ssh (was: grep 'Information returned by' $STDOUT)
  unixcount="$(wc -c $SOURCE_FILE | awk ' {print $1}')"

  if [ novelcount -eq unixcount ]
  then
      echo "Succeeded ftp of file $INPUT_FILE_NAME, bytes =$novelcount"
  else
      echo "ftp get of file $INPUT_FILE_NAME failed: ftp says $novelcount, real count is $unixcount"
      abndalrt.ksh ftp_get
  fi
 

#STEP Step020R
  export STEPNAME=Step020R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n" 
  ##########################################################################
  # STEP NAME:  Step020R
  # STEP DESC:  Remove all the xls files from the zip file
  #
  # Usage: zip [-d] file[.zip] [files to remove]                                         
  #    -d  => delete the specified files                                      
  ##########################################################################
  
  zip -d ${SOURCE_FILE} "*.xls*"  

  # Get number of files inside zip file. Zip file should have only 1 file
  reccnt=`unzip -Z1 ${SOURCE_FILE}|wc -l`

  if [ reccnt -eq 1 ]
  then echo "unzipped file is good"
  else  
	 echo " unzipped input file is no good "
	 $( abndalrt.ksh 911 )
  fi	
	
#STEP Step030R
  export STEPNAME=Step030R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S') 
  ##########################################################################
  # STEP NAME:  Step030R
  # STEP DESC:  Copy the modified zip file to Network
  #                                        
  ##########################################################################
 
  PRICE_UX=${SOURCE_FILE}
  PRICE_NT=${BACKUP_SOURCE_FILE_NAME}
  FTP_LOGFILE=${RACE}/tmp/${JOBNAME}_${STEPNAME}_transfer_log.tmp
  NT_DIR=${FTP_MITCHELL_BUSINESS_PATH}/${ACT_LVL}/oem/outgoing  # rj132422 prod3nt sunset: Mitchell SFTP outgoing (was: ${NOVELL}oem)

  if [ -e ${PRICE_UX} ]
  then
    ########################################################################################
    # Copy the price file to the Network
    ########################################################################################
    scp ${PRICE_UX} ${FTP_SFTP_USER}${FTP_SITE}:${NT_DIR}/${PRICE_NT} | tee ${FTP_LOGFILE}  # rj132422 scp put to Mitchell (was: fileput.exp ${PRICE_UX} ${PRICE_NT} ${NT_DIR})

    ########################################################################################
    # Verify the copy is good
    ########################################################################################
    GOODBYTECOUNT="$(wc -c ${PRICE_UX} | awk '{print $1}')"
    FTPBYTECOUNT="$(ssh -nq ${FTP_SFTP_USER}${FTP_SITE} "wc -c < ${NT_DIR}/${PRICE_NT}")"  # rj132422 remote byte-count via ssh (was: grep 'Information returned by' ${FTP_LOGFILE})
    if [ ${GOODBYTECOUNT} -eq ${FTPBYTECOUNT} ]
    then
      echo "File transfer to NT ${NT_DIR} successful. ${PRICE_UX} ftp count = ${GOODBYTECOUNT}"    
	  
	  # remove the file from UNIX
      rm -rf ${PRICE_UX}
    else
      echo "File transfer of ${PRICE_UX} to NT ${NT_DIR} failed: ftp says ${FTPBYTECOUNT}, real count is ${GOODBYTECOUNT}"
      $(abndalrt.ksh 911)
    fi
  else
    echo "\n\nError: no ${PRICE_UX} file to ftp!!\n"
    $(abndalrt.ksh 911)
  fi  

     
#STEP Step999R
  export STEPNAME=Step999R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')
  ##########################################################################
  # STEP NAME:  Step999R
  # STEP DESC:  Removes job-related temporary files including the 
  #             tmp/mptr249 directory. (NOTE: -r flag used with rm command.)
  ##########################################################################
  rm -rf ${RACE}/tmp/${JOBNAME}*
  

#*****************************************************************************************
# END oem_ref_mptr249_hdmus_source_file.ksh
#*****************************************************************************************
