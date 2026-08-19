#!/bin/ksh
echo "RCS $Id: oem_ref_mptr809_ftp_bestfit_source_file.ksh,v 1.4 2021/03/16 01:16:35 pg2697 Exp rj132422 $"
set -xv
#*****************************************************************************************
# PROCNAME oem_ref_mptr809_ftp_bestfit_source_file.ksh                                            
# PURPOSE  Locate and Transfer the latest BestFit File from FTP Server
#          Unzip the file and build the required file (Price) as the Source Input File
#          for mptr810.
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
  oem_job_status_update.ksh "R" "${STEPNAME} oem_ref_mptr809_ftp_bestfit_source_file"
  #**************************************************************************************
  #  Transfer the file(s) defined in the oem_job_datafile table
  #**************************************************************************************
  . oem_job_datafile_prep.ksh                 


#STEP Step020R
  export STEPNAME=Step020R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n" 
  oem_job_status_update.ksh "R" "${STEPNAME} oem_ref_mptr809_ftp_bestfit_source_file"
  #**********************************************************************************************
  # Make sure the file exists to transfer to the Network... send email when it is sent
  #**********************************************************************************************
  FTP_LOGFILE=${RACE}/tmp/${JOBNAME}_${STEPNAME}_transfer_log.tmp
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
  # STEP DESC:  Unzip the source file into a job-specific tmp directory.
  #             Capture the price files (for reformat staging run in unix)  
  #             and the json file (for DB load process run in Windows).
  #
  # Usage: unzip [-Z] [-opts[modifiers]] file[.zip] [list] [-x xlist] [-d exdir] 
  #    -j  => junk paths (do not make directories)                               
  #    -o  => overwrite files WITHOUT prompting                                  
  #    -LL => make all names lowercase                                           
  #    -d  => extract files into exdir                                         
  ##########################################################################
 
   unzip -ojLL ${SOURCE_FILE} '*prices.txt' -d ${RACE}/tmp/${JOBNAME}
   unzip -ojLL ${SOURCE_FILE} '*prices_*.txt' -d ${RACE}/tmp/${JOBNAME}
   unzip -ojLL ${SOURCE_FILE} '*.json' -d ${RACE}/tmp/${JOBNAME} 

  
  #STEP Step040R
  export STEPNAME=Step040R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S') 
  ##########################################################################
  # STEP NAME:  Step040R
  # STEP DESC:  Copy the US Price file to the Network - for I/P to the reformat.
  # NOTE:
  # The US Price file (Mitchell_BestFit_prices.txt) MUST be found and transferred.
  # File name was dropped to all lowercase during unzip in previous step.
  # PRICE_NT must match the reformat job's (mptr810) INPUT_FILE_NAME.
  ##########################################################################
  PRICE_UX=${RACE}/tmp/${JOBNAME}/mitchell_bestfit_prices.txt
  PRICE_NT=mptr809_raw_bestfit_price_us.dat
  FTP_LOGFILE=${RACE}/tmp/${JOBNAME}_${STEPNAME}_transfer_log.tmp
  NT_DIR=${NOVELL}oem
  
  if [ -e ${PRICE_UX} ]
  then
    ########################################################################################
    # Copy the US price file to the Network      
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


  #STEP Step045R
  export STEPNAME=Step045R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S') 
  ##########################################################################
  # STEP NAME:  Step045R
  # STEP DESC:  Copy the CA Price file to the Network - for I/P to the reformat.
  # NOTE:
  # The CA Price file (Mitchell_BestFit_prices_Canada.txt) MUST be found and 
  # transferred. File name was dropped to all lowercase during unzip in previous step.
  # PRICE_NT must match the reformat job's (mptr810) INPUT_FILE_NAME.
  ##########################################################################
  PRICE_UX=${RACE}/tmp/${JOBNAME}/mitchell_bestfit_prices_canada.txt
  PRICE_NT=mptr809_raw_bestfit_price_ca.dat
  FTP_LOGFILE=${RACE}/tmp/${JOBNAME}_${STEPNAME}_transfer_log.tmp
  NT_DIR=${NOVELL}oem
  
  if [ -e ${PRICE_UX} ]
  then
    ########################################################################################
    # Copy the CA price file to the Network      
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


  #STEP Step050R
  export STEPNAME=Step050R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S') 
  ##########################################################################
  # STEP NAME:  Step050R
  # STEP DESC:  Copy the JSON file to the OEM Document Repository - 
  #             original and processed directories - for I/P to the DB Load.
  # NOTE:
  # The json file (mitchell_bestfit_all_parts_makes_models.json) MUST be found and transferred.
  # File name was dropped to all lowercase during unzip in previous step.
  ##########################################################################
  ORIGINAL_DIR=${RACE}/../../oem_doc_repository/BestFit/dat/original_source
  PROCESSED_DIR=${RACE}/../../oem_doc_repository/BestFit/dat/processed_source

  JSON_UX=${RACE}/tmp/${JOBNAME}/mitchell_bestfit_all_parts_makes_models.json
  JSON_WIN_ORIGINAL=$ORIGINAL_DIR/mptr809_mitchell_bestfit_all_parts_makes_models_$(date +'%C%y%m%d%H%M%S').json
  JSON_WIN_PROCESSED=$PROCESSED_DIR/mptr809_mitchell_bestfit_all_parts_makes_models.json

  LOGFILE=${RACE}/tmp/${JOBNAME}_${STEPNAME}_transfer_log.tmp
  
  if [ -e ${JSON_UX} ]
  then
      cp $JSON_UX $JSON_WIN_ORIGINAL >> $LOGFILE
      cp $JSON_UX $JSON_WIN_PROCESSED >> $LOGFILE    
  else
      echo "Step050R NOTE: No $FILE files to be copied." >> $ZIPSTATUS         
  fi

  #STEP Step060R
  export STEPNAME=Step060R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S') 
  ##########################################################################
  # STEP NAME:  Step060R
  # STEP DESC:  Send email notification that the file was transferred to 
  #             the Network and oem_doc_repository directory.
  # NOTE: There is intentional spacing between prod3 path and zip filename.
  #       Otherwise, when editor clicks on link in email, the zip file is
  #       displayed in zip editor (for extract) when editor needs to MOVE
  #       the actual .zip file.
  ##########################################################################
  
  if [ ${THISHOST} = ${TESTHOST} ]
   then
     #MDEV RUN
     MAIL_RECIP="Rpt.OEM.Developers@mitchell.com"
     #####################for testng MAIL_RECIP="penny.genovese@mitchell.com"
     MAIL_SUBJECT="TEST - ${JOBNAME} ${JOBOEMNAME} ${JOBOEM} US and CA: Transfer Source File to Network" 
     OEMDOC_SERVER="dev11nas"
   else
     #PROD RUN
     MAIL_RECIP="Rpt.OEM.Data.Analyst@Mitchell.com"
     MAIL_SUBJECT="${JOBNAME} ${JOBOEMNAME} ${JOBOEM} US and CA: Transfer Source File to Network" 
     OEMDOC_SERVER="prod4nt"
  fi

  export MAIL_TEXT=${RACE}/tmp/${JOBNAME}_email_text.tmp    
  echo '\n 1. The BestFit zip file has been transferred to the Network as: '${BACKUP_SOURCE_FILE_NAME}' ' > ${MAIL_TEXT}
  echo '      \\\prod3nt\\cdprod02\\ftp_data\\'${ACT_LVL}'\\oem_research\\' >> ${MAIL_TEXT}                                                                
  echo '\n    Editorial Content may now:' >> ${MAIL_TEXT}
  echo '      a. MOVE this file into:  \\\dept01nas\dept\PubTeams\BestFit\\' >> ${MAIL_TEXT}
  echo '      b. Unzip File' >> ${MAIL_TEXT}
  echo '      c. Use files, as needed.' >> ${MAIL_TEXT}  
  echo '\n 2. BestFit zip and json files have been transferred to the OEM Document Repository server:' >> ${MAIL_TEXT}
  echo '      \\\'${OEMDOC_SERVER}'\\oem_doc_rep_share\\oem_doc_repository\\BestFit\\dat\\' >> ${MAIL_TEXT}
  echo '\n    Editorial Systems may now: Run the BestFit process which loads json data into the RACE database for Editor use.' >> ${MAIL_TEXT}
  echo '\n 3. The BestFit price files have been transferred to the Network as: mptr809_raw_bestfit_price_us.dat and mptr809_raw_bestfit_price_ca.dat in' >> ${MAIL_TEXT}
  echo '      \\\prod3nt\\cdprod02\\ftp_data\\'${ACT_LVL}'\\oem\\' >> ${MAIL_TEXT}
  echo '\n    Editorial Systems may now: Run the US and CA BestFit reformat and update processes to apply pricing to the RACE Database.' >> ${MAIL_TEXT}   
   
  mailx -s "${MAIL_SUBJECT}" "${MAIL_RECIP}" < ${MAIL_TEXT}      
            


#STEP Step990R
#*********************************************************************************************************************
#* 1. Remove "original_source" files that are older than 183 days (6 months)
#*********************************************************************************************************************
#export STEPNAME=Step990R
#echo "    Start   ${STEPNAME}           "$(date)

trap '' err
find ${RACE}/../../oem_doc_repository/BestFit/dat/original_source -type f -mtime +183 -exec rm -f {} \;
trap 'abndalrt.ksh    $?' err
      
   
#STEP Step999R
  export STEPNAME=Step999R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')
  ##########################################################################
  # STEP NAME:  Step999R
  # STEP DESC:  Removes job-related temporary files including the 
  #             tmp/mptr809 directory. (NOTE: -r flag used with rm command.)
  ##########################################################################
  rm -rf ${RACE}/tmp/${JOBNAME}*
  

#*****************************************************************************************
# END oem_ref_mptr809_ftp_bestfit_source_file.ksh
#*****************************************************************************************
