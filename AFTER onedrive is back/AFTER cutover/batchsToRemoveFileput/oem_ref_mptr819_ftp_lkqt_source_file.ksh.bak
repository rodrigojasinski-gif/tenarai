#!/bin/ksh
echo "RCS $Id: oem_ref_mptr819_ftp_lkqt_source_file.ksh,v 1.2 2022/11/08 03:46:00 pg2697 Exp $"
set -xv
#*****************************************************************************************
# PROCNAME oem_ref_mptr819_ftp_lkqt_source_file.ksh                                            
# PURPOSE  Locate and Transfer the latest LKQ Truck File from SFTP Server
#          Unzip the file and save xlsx in NT so that it can be converted to txt for the 
#          Source Input File for mptr820.
#          Additionally, move the zipped file to the Network and send email notification.
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

#STEP Step010R
  export STEPNAME=Step010R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  oem_job_status_update.ksh "R" "${STEPNAME} oem_ref_mptr819_ftp_lkqt_source_file"
  #**************************************************************************************
  #  Transfer the file(s) defined in the oem_job_datafile table
  #**************************************************************************************
  . oem_job_datafile_prep.ksh                 


#STEP Step020R
  export STEPNAME=Step020R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n" 
  oem_job_status_update.ksh "R" "${STEPNAME} oem_ref_mptr819_ftp_lkqt_source_file"
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
      MAIL_RECIP="Rpt.OEM.Data.Analyst@Mitchell.com"
      MAIL_SUBJECT="${JOBNAME} ${JOBOEMNAME} ${JOBOEM} ${JOBCTRY}: Transfer Source File to Network for Editor Use" 
      export MAIL_TEXT=${RACE}/tmp/${JOBNAME}_email_text.tmp    
      echo "\nThe LKQ Truck zip file has been transferred to the Network \n"               > ${MAIL_TEXT}
      echo '\\\prod3nt\\cdprod02\\ftp_data\\'"$ACT_LVL"'\\oem_research\\' as "$BACKUP_SOURCE_FILE_NAME" >> ${MAIL_TEXT}     
      echo "\nWhat to do?"   >> ${MAIL_TEXT}
      echo "\nEditorial Parts: "  >> ${MAIL_TEXT}
      echo "   1. MOVE this file into: " '\\\dept01nas\\dept\\PubTeams\\LKQ_Truck\\'   >> ${MAIL_TEXT}
      echo "   2. Unzip File"                                                       >> ${MAIL_TEXT}
      echo "   3. Editors use files, as needed."                                    >> ${MAIL_TEXT}
      if [ ${THISHOST} = ${TESTHOST} ]
      then
        mailx -s "TEST - ${MAIL_SUBJECT} " "Rpt.OEM.Developers@mitchell.com" < ${MAIL_TEXT}
        ##mailx -s "TEST - ${MAIL_SUBJECT} " "penny.genovese@mitchell.com" < ${MAIL_TEXT}
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
  # 
  # Usage: unzip [-Z] [-opts[modifiers]] file[.zip] [list] [-x xlist] [-d exdir] 
  #    -j  => junk paths (do not make directories)                               
  #    -o  => overwrite files WITHOUT prompting                                  
  #    -LL => make all names lowercase                                           
  #    -d  => extract files into exdir                                         
  ##########################################################################
 
   unzip -ojLL ${SOURCE_FILE} '*xlsx' -d ${RACE}/tmp/${JOBNAME}

  
  #STEP Step040R
  export STEPNAME=Step040R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S') 
  ##########################################################################
  # STEP NAME:  Step040R
  # STEP DESC:  Copy the xlsx file to the Network - so that RACE DataOps can
  #             run Excel Conversion Macro to create txt file.
  # NOTE:
  # The xls file (mitchell_est_static_catalog*.xlsx) MUST be found and transferred.
  # File name was dropped to all lowercase during unzip in previous step.
  # PRICE_NT will NOT match the reformat job's (mptr820) INPUT_FILE_NAME because
  # it is further converted by RACE_DataOps using an Excel Macro.
  ##########################################################################
  PRICE_UX=${RACE}/tmp/${JOBNAME}/mitchell_est_static_catalog*.xlsx
  PRICE_NT=lkq_us_mitchell_est_static_catalog.xlsx
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
      # Send email notification that the file was transferred to the Network
      MAIL_RECIP="RACEDataOps@Mitchell.com"
      MAIL_SUBJECT="${JOBNAME} ${JOBOEMNAME} ${JOBOEM} ${JOBCTRY}: Transfer Source File to Network for Reformat Prep" 
      export MAIL_TEXT=${RACE}/tmp/${JOBNAME}_email_text.tmp    
      echo "\nThe LKQ Truck xlsx file has been transferred to NT directory \n" > ${MAIL_TEXT}
      echo '\\\prod3nt\\cdprod02\\ftp_data\\'${ACT_LVL}'\\oem\\' as ${PRICE_NT} >> ${MAIL_TEXT}     
      echo "\nWhat to do? "  >> ${MAIL_TEXT}
      echo "\n RACE DataOps: " >> ${MAIL_TEXT}
      echo "Run Excel Conversion Macro: LKQ_US_file_conversion.xlsm " >> ${MAIL_TEXT}
      echo "This macro creates the txt file which is needed for the Reformat." >>  ${MAIL_TEXT}
      echo "Note: Further info can be found in the macro and in Keep_OEM_Excel_Macros.docx "  >> ${MAIL_TEXT}     
      if [ ${THISHOST} = ${TESTHOST} ]
      then
        mailx -s "TEST - ${MAIL_SUBJECT} " "Rpt.OEM.Developers@mitchell.com" < ${MAIL_TEXT}
        ##mailx -s "TEST - ${MAIL_SUBJECT} " "penny.genovese@mitchell.com" < ${MAIL_TEXT}
      else
        mailx -s "${MAIL_SUBJECT}" ${MAIL_RECIP} < ${MAIL_TEXT}      
      fi         
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
  #             tmp/mptr819 directory. (NOTE: -r flag used with rm command.)
  ##########################################################################
  rm -rf ${RACE}/tmp/${JOBNAME}*
  

#*****************************************************************************************
# END oem_ref_mptr819_ftp_lkqt_source_file.ksh
#*****************************************************************************************
