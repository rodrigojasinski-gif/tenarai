#!/bin/ksh
echo "RCS $Id: oem_ref_mptr839_ftp_tesla_semi_source_file.ksh,v 1.3 2024/02/16 23:03:25 pg2697 Exp $"
set -xv
#***************************************************************************************************
# PROCNAME oem_ref_mptr839_ftp_tesla_semi_source_file.ksh                                            
# PURPOSE  1. Locate and Transfer the latest Tesla Commercial Semi Zip from their External SFTP Site
#          2. Unzip the file and build the required files as the Source Input Files for mptr840.
#          3. Additionally, copy the zip file to the Network (for use by Editorial) and send an 
#             email notification.
#***************************************************************************************************
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

#STEP Step010R
  export STEPNAME=Step010R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} oem_ref_mptr839_ftp_tesla_semi_source_file"
  #**************************************************************************************
  #  Transfer the file(s) defined in the oem_job_datafile table
  #**************************************************************************************
  . oem_job_datafile_prep.ksh                 


#STEP Step020R
  export STEPNAME=Step020R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n" 
  oem_job_status_update.ksh "R" "${STEPNAME} oem_ref_mptr839_ftp_tesla_semi_source_file"
  #**********************************************************************************************
  # Make sure the file exists to transfer to the Network... send email when it is sent
  #**********************************************************************************************
  FTP_LOGFILE=${RACE}/tmp/${JOBNAME}_transfer_log.tmp
  if [ -e ${SOURCE_FILE} ]
  then
    # Copy the source file to the Network      
    fileput.exp ${SOURCE_FILE} ${BACKUP_SOURCE_FILE_NAME} ${NOVELL}oem_research | tee ${FTP_LOGFILE}
    # Verify the copy is good       
    GOODBYTECOUNT="$(wc -c ${SOURCE_FILE} | awk '{print $1}')"
    FTPBYTECOUNT="$(cat ${FTP_LOGFILE} | grep 'Information returned by' | awk '{print $1}')"    
    if [ ${GOODBYTECOUNT} -eq ${FTPBYTECOUNT} ]
    then
      echo "Successful ftp ${SOURCE_FILE}: ftp count = ${GOODBYTECOUNT}"
      # Send email notification that the file was transferred to the Network
      MAIL_RECIP="Rpt.OEM.Activ.Comm.Dom@Mitchell.com; Susan.Grimes@Mitchell.com"
      MAIL_SUBJECT="${JOBNAME} ${JOBOEMNAME} ${JOBOEM} ${JOBCTRY}: Transfer Source File to Network" 
      export MAIL_TEXT=${RACE}/tmp/${JOBNAME}_email_text.tmp    
      echo "\nThe Tesla zip file was transferred to the Network \n"               > ${MAIL_TEXT}
      echo '\\\prod3nt\\cdprod02\\ftp_data\\'${ACT_LVL}'\\oem_research\\' ${BACKUP_SOURCE_FILE_NAME} >> ${MAIL_TEXT}     
      echo "\nWhat to do?"                                                          >> ${MAIL_TEXT}
      echo "   1. MOVE this file into: " '\\\dept01nas\dept\PubTeams\Tesla_Semi\\'       >> ${MAIL_TEXT}
      echo "   2. Unzip File"                                                       >> ${MAIL_TEXT}
      echo "   3. Editors use files, as needed."                                    >> ${MAIL_TEXT}
      # For testing, set recipient to developers
      if [ ${THISHOST} = ${TESTHOST} ]
      then
        mailx -s "TEST - ${MAIL_SUBJECT}" "Rpt.OEM.Developers@mitchell.com" < ${MAIL_TEXT}
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
 

  #STEP Step030R
  export STEPNAME=Step030R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S') 
  ##########################################################################
  # STEP NAME:  Step030R
  # STEP DESC:  Unzip the source file into a job-specific tmp directory
  #             To save time, unzip only the .csv files
  #
  # Usage: unzip [-Z] [-opts[modifiers]] file[.zip] [list] [-x xlist] [-d exdir] 
  #    -j  => junk paths (do not make directories)                               
  #    -o  => overwrite files WITHOUT prompting                                  
  #    -LL => make all names lowercase                                           
  #    -d  => extract files into exdir                                         
  ##########################################################################
 
   unzip -ojLL ${SOURCE_FILE} *.csv -d ${RACE}/tmp/${JOBNAME}

  # PAG 2022/08/23 Added chmod. Later steps were failing on permission errors when referencing the unzipped .csv files.
  # set read permission on all unzipped files.
   echo "\n\nPermissions before: "
   ls -l ${RACE}/tmp/${JOBNAME}/*.*

   chmod +r ${RACE}/tmp/${JOBNAME}/*.*

   echo "\n\nPermissions after: "
   ls -l ${RACE}/tmp/${JOBNAME}/*.*


  
  #STEP Step040R
  export STEPNAME=Step040R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S') 
  ##########################################################################
  # STEP NAME:  Step040R
  # STEP DESC:  Copy the Price file to the Network - for I/P to the reformat.
  # NOTE:
  # The Price file (PartPrices_{date}.csv) MUST be found and transferred.
  # File name was dropped to all lowercase during unzip in prior step.
  # PRICE_NT must match the reformat job's (mptr300) INPUT_FILE_NAME.
  ##########################################################################
  PRICE_UX=${RACE}/tmp/${JOBNAME}/partprices*.csv
  PRICE_NT=${JOBNAME}_raw_tsem_price.dat
  FTP_LOGFILE=${RACE}/tmp/${JOBNAME}_${STEPNAME}_transfer_log.tmp
  NT_DIR=${NOVELL}oem
  
  if [ -e ${PRICE_UX} ]
  then
    ########################################################################################
    # Copy the price file to the Network      
    ########################################################################################
    fileput.exp ${PRICE_UX} ${PRICE_NT} ${NT_DIR} | tee ${FTP_LOGFILE}
    
    ########################################################################################
    # Verify the copy is good       
    ########################################################################################
    GOODBYTECOUNT="$(wc -c ${PRICE_UX} | awk '{print $1}')"
    FTPBYTECOUNT="$(cat ${FTP_LOGFILE} | grep 'Information returned by' | awk '{print $1}')"    
    if [ ${GOODBYTECOUNT} -eq ${FTPBYTECOUNT} ]
    then
      echo "File transfer to NT ${NT_DIR} successful. ${PRICE_UX} ftp count = ${GOODBYTECOUNT}"    
    else
      echo "File transfer of ${PRICE_UX} to NT ${NT_DIR} failed: ftp says ${FTPBYTECOUNT}, real count is ${GOODBYTECOUNT}"
      $(abndalrt.ksh 911)
    fi
  else
    echo "\n\nError: no ${PRICE_UX} file to ftp!!\n"
    $(abndalrt.ksh 911)
  fi  
 

  #STEP Step050R - super file processing - intentionally left out as Tesla Commercial Semi doesn't have supers (yet)
  
  #STEP Step060R
  export STEPNAME=Step060R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S') 
  ##########################################################################
  # STEP NAME:  Step060R
  # STEP DESC:  Concatenate the Catalog file(s) for all countries to one filename
  #             and then copy that file to the Network - for I/P to the reformat.
  # NOTE:
  # The Catalog file(s) (partscatalog_*.csv) MUST be found and transferred.
  # File name(s) was dropped to all lowercase during unzip in prior step.
  # CATLG_NT must match the reformat job's (mptr840) INPUT_FILE_NAME.
  ##########################################################################
  CATLG_ZIP=${RACE}/tmp/${JOBNAME}/partscatalog_*.csv
  CATLG_UX=${RACE}/tmp/${JOBNAME}/partscatalog_combined.csv
  CATLG_NT=${JOBNAME}_raw_tsem_catlg.dat
  FTP_LOGFILE=${RACE}/tmp/${JOBNAME}_${STEPNAME}_transfer_log.tmp
  NT_DIR=${NOVELL}oem
  
  if [ -e ${CATLG_ZIP} ]
  then
  
    ########################################################################################
    # Concatenate the country model-specific catalog file(s) into one combined file      
    ########################################################################################
    rm -f ${CATLG_UX}
	cat ${CATLG_ZIP} > ${CATLG_UX}

    ########################################################################################
    # Copy the catalog file to the Network      
    ########################################################################################
    fileput.exp ${CATLG_UX} ${CATLG_NT} ${NT_DIR} | tee ${FTP_LOGFILE}
    
    ########################################################################################
    # Verify the copy is good       
    ########################################################################################
    GOODBYTECOUNT="$(wc -c ${CATLG_UX} | awk '{print $1}')"
    FTPBYTECOUNT="$(cat ${FTP_LOGFILE} | grep 'Information returned by' | awk '{print $1}')"    
    if [ ${GOODBYTECOUNT} -eq ${FTPBYTECOUNT} ]
    then
      echo "File transfer to NT ${NT_DIR} successful. ${CATLG_UX} ftp count = ${GOODBYTECOUNT}"    
    else
      echo "File transfer of ${CATLG_UX} to NT ${NT_DIR} failed: ftp says ${FTPBYTECOUNT}, real count is ${GOODBYTECOUNT}"
      $(abndalrt.ksh 911)
    fi
  else
    #2024/02 PAG - temporarily commented out error message and abend execution. Changed to warning.
    #echo "\n\nError: no ${CATLG_UX} file to ftp!!\n"
	#$(abndalrt.ksh 911)
	echo "\n\nWarning: no ${CATLG_UX} file to ftp. Per Tesla, they are not planning to release the Semi parts catalog data until later this year.\n"
	echo "\n\nReformat will use last catalog file received.\n"  
  fi  

  
#STEP Step999R
  export STEPNAME=Step999R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')
  ##########################################################################
  # STEP NAME:  Step999R
  # STEP DESC:  Removes job-related temporary files including the 
  #             tmp/mptr839 directory. (NOTE: -r flag used with rm command.)
  ##########################################################################
  rm -rf ${RACE}/tmp/${JOBNAME}*
  

#*****************************************************************************************
# END oem_ref_mptr839_ftp_tesla_semi_source_file.ksh
#*****************************************************************************************
