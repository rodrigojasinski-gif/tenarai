#!/bin/ksh

echo "RCS $Id: oem_ref_mptr425_ftp_clean_files.ksh,v 1.4 2022/10/20 18:49:07 pg2697 Exp $"

#*****************************************************************************************
# PROCNAME oem_ref_mptr425_ftp_clean_files.ksh                                              
# PURPOSE  Get the files that are later than or earlier than the file modified date of Ford CANCOMPPRICE* file
#          Delete these files. 
#          The process abends
#            1. When no file with prefix CANOBS exists for the same date as the files with prefix CANCOMPPRICE
#            2. When no CANOBS files exist
#            3. When there are no files on FTP server
#*****************************************************************************************
trap 'oem_abndalrt.ksh $?' err
export LOGFILE=$(basename ${JOBLOGNAME})

set -xv

#*****************************************************************************************
#  Build environment variables for the job (based on jobname)
#*****************************************************************************************
. oem_job.ksh         
. oem_job_datafile.ksh

#*****************************************************************************************

PROCNAME=oem_ref_mptr425_ftp_clean_files.ksh
echo "\n\nSTART ---> ${PROCNAME} " $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n" 

#**********************************************************************************************
# ???
#**********************************************************************************************
  
  # get the complete and incremental file prefixes
  while IFS= read -r line; do
   
     POSITION=`echo $line|cut -f1  -d"^"`
   
     # When group ID is 1, it represents CANCOMPRICE file that is a complete load
     # and is received only once in a month
     if [ "${POSITION}" = 1 ]
     then
	    COMPLETE_LOAD_FILE=`echo $line|cut -f2  -d"^"i|cut -f1 -d '*'`
     fi
   
     # When group ID is 2, it represents CANOBS file that is received at least 4 times in a month and
     # is incremental
     if [ "${POSITION}" = 2 ]
     then
        INCREMENTAL_LOAD_FILE=`echo $line| cut -f2  -d"^"|cut -f1 -d '*'`  

     fi
  done < ${WORKFILE}

  echo "*** Complete Load File ${COMPLETE_LOAD_FILE}"
  echo "*** Incremental Load File ${INCREMENTAL_LOAD_FILE}"

  # set temporary FTP files that will be created duribg this process
  FTP_FILELIST=${RACE}/tmp/${JOBNAME}_ftplist.tmp
  FTP_FILELIST_STAGE=${RACE}/tmp/${JOBNAME}_ftpliststage.tmp
  FTP_DELETE_FILELIST=${RACE}/tmp/${JOBNAME}_ftpdeletelist.tmp
   
  # get FTP Directory
  if [ "${JOBCTRY}" = "PR" ]
  then
     FTPSITE_DIRECTORY=${FTP_BUSINESS_PATH}/puerto_rico/${ACT_LVL}/incoming
  else
     FTPSITE_DIRECTORY=${FTP_BUSINESS_PATH}/${JOBFILE_OEMCTRY}/${ACT_LVL}/incoming
  fi

  # Get list of all files from SFTP Ford site
  FILES_COUNT=`ssh -nq ${FTP_SITE} ls -lt ${FTPSITE_DIRECTORY}/${COMPLETE_LOAD_FILE}* ${FTPSITE_DIRECTORY}/${INCREMENTAL_LOAD_FILE}* |grep -v '^total' > ${FTP_FILELIST}; wc -l ${FTP_FILELIST}|awk '{print $1}'`

  if [ "${FILES_COUNT}" = "0" ]
  then
      echo "************************************************"
      echo " ***** error ***** No files present on ${FTP_SITE}"
      echo "************************************************"

      oem_abndalrt.ksh  "No_files_present_on_"${FTP_SITE}
  fi

  # Show list of files detected
  more ${FTP_FILELIST}

  # Local variables
  CURRENT_YEAR=`date +"%Y"`  # Current Year
  PREV_YEAR=`expr $(date +"%Y") - 1`  # Previous Year
  CURRENT_MTH=`date +"%b"`  # Current_month in Mon format
  MONTHS="  JanFebMarAprMayJunJulAugSepOctNovDec" # Enum defined to convert month name to month number

  # create a stage file that will have a modified date of the file converted in YYYY-MM-DD format. In case files
  # are not 6 months old, UNIX do not store the year. The below command will derive the year for such files

  awk -v current_year="$CURRENT_YEAR" -v mm="$MONTHS" -v prev_year="$PREV_YEAR" -v current_month="$CURRENT_MTH" -v OFS='\t' ' \
       {if ($0 ~ /:/ && index(mm,$6)/3 > index(mm, current_month)/3)  print $9 "\t" prev_year "-" index(mm,$6)/3 "-" $7 "\t" $8; \
        else if ($0 ~ /:/ && index(mm,$6)/3 <= index(mm, current_month)/3)  print $9 "\t" current_year "-" index(mm,$6)/3 "-" $7 "\t" $8; \
       else print $9"\t"$8"-"index(mm,$6)/3"-"$7"\t00:00";}' ${FTP_FILELIST} > ${FTP_FILELIST_STAGE}

  # Get the date of the latest CANCOMPRICE file
  LATEST_PRICE_DATE=`grep ${COMPLETE_LOAD_FILE} ${FTP_FILELIST_STAGE}|head -1|awk '{print $2}'`
  echo "*** Latest Price File Date ${LATEST_PRICE_DATE}"

  # abend if no complete file exists
  if [[ -z "${LATEST_PRICE_DATE}" ]]
  then
      echo "********************************************************"
      echo " ***** error ***** No ${COMPLETE_LOAD_FILE} files exist"
      echo "********************************************************"
      oem_abndalrt.ksh  "No_"${COMPLETE_LOAD_FILE}"_file_exists"
  fi

  # Show staged file list
  more ${FTP_FILELIST_STAGE}

  # Get all the files that are later or earlier than the latest Complete load file
  awk -v date="$LATEST_PRICE_DATE" -v ftpdir="$FTPSITE_DIRECTORY" '{if ($2 < date || $2 > date) print "rm -f " $1 ;}' ${FTP_FILELIST_STAGE} > ${FTP_DELETE_FILELIST}

  # List and then Delete all the files that are earlier or latter than complete load file
  more ${FTP_DELETE_FILELIST}
  ssh -T ${FTP_SITE} < ${FTP_DELETE_FILELIST}

  
  # Check if there is an incremental file as of the same date of the complete load file. If not abend
  FILE_EXIST_FLAG=`awk -v date="$LATEST_PRICE_DATE" '$2 <= date' ${FTP_FILELIST_STAGE} \
                | grep ${INCREMENTAL_LOAD_FILE}|head -1| \
                  awk -v date="$LATEST_PRICE_DATE" '{if ($2 == date) print "obs_found"; else print "abend";}'`

  if [[ -z "${FILE_EXIST_FLAG}" ]] # if no incremental file exists, abend
  then
      echo "********************************************************"
      echo " ***** error ***** No ${INCREMENTAL_LOAD_FILE} files exist"	  
      echo "********************************************************"
      oem_abndalrt.ksh  "No_"${INCREMENTAL_LOAD_FILE}"_file_exists"
  else 
    # if incremental file exists but not of the same date as complete load file, abend
    if [ ${FILE_EXIST_FLAG} == "abend" ]
    then
      echo "********************************************************"
      echo " ***** error ***** file ${INCREMENTAL_LOAD_FILE} not exists for : ${LATEST_PRICE_DATE}"	  
      echo "********************************************************"
      oem_abndalrt.ksh  ${INCREMENTAL_LOAD_FILE}"_file_not_exists_for_"${LATEST_PRICE_DATE}
    fi
  fi


  # House keeping
  rm -f ${FTP_DELETE_FILELIST}
  rm -f ${FTP_FILELIST}
  rm -f ${FTP_FILELIST_STAGE}

echo "\n\nEND ---> ${PROCNAME} " $(date +'%m/%d/%y %H:%M:%S')  " <--- END\n\n" 
#**********************************************************************************************      
#*****************************************************************************************
#END oem_ref_mptr425_ftp_clean_files.ksh
#*****************************************************************************************
