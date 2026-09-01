#!/bin/ksh
#$Id: oem_job_datafile_prep.ksh,v 1.13 2025/11/12 16:02:19 rj132422 Exp rj132422 $
#**************************************************************************************************
#     oem_job_datafile_prep.ksh
#**************************************************************************************************
## from Wikipedia: When a child process is created, it inherits all the environment variables
##                 and their values from the parent process. e.g. from oem_ref.ksh set -vx

echo "\n*** Begin oem_job_datafile_prep.ksh ${INPUT_FILE_NAME} ***\n"
trap 'oem_abndalrt.ksh $?' err

###################################################################################################
# Determine where the Input File is located and transfer it to Unix
#   Option 1 Input File is on external FTP site and a special program has been written
#   Option 2 Input File found in the RACE data directory
#   Option 3 Input File is on the Mitchell FTP Site
#   Option 4 None of the above?  Then Input File HAS TO BE on the Novell directory.
###################################################################################################

STEP010_FILEOUT=${RACE}/dat/${BACKUP_SOURCE_FILE_NAME}

if [ ! -z "${FTP_PROGRAM_NAME}" ]
then
		  #################################################################################################
		  #
		  #         Option 1 Input File is on external FTP site and a special program has been written

  echo "\n*** Option 1 Input File is on external FTP site and a special program has been written\n"

  FTP_PULL_TARGET=${RACE}/tmp/${INPUT_FILE_NAME}
  rm -f ${FTP_PULL_TARGET}

		  #  Run the customized program parameters to logon to OEM's FTP site and retrieve file
		  #  This information is maintained in oem_job_datafile.ftp_program_name
		  #                             and in oem_job_datafile.ftp_parm_file_name

                     #set up MAIL_TEXT to capture any error msgs in the subscript that gets the file from the External Site
    export MAIL_TEXT=${RACE}/tmp/${JOBNAME}_email_text.tmp
    rm -f ${MAIL_TEXT}

                     ## Log sftp processing
   export SFTP_LOG=${RACE}/tmp/${JOBNAME}_sftp_${FILE_SEQUENCE}_log_$(date +'%Y%m%d%H%M%S').tmp
   ${FTP_PROGRAM_NAME} ${RACE}/prm/${FTP_PARM_FILE_NAME} ${FTP_SOURCE_FILE_NAME} ${FTP_PULL_TARGET}

		     # Verify that the file copied exists and that it contains data
  if [ ! -s ${FTP_PULL_TARGET} ]
  then

	 	     #**********************************************************************************************
		     # Send email notification
		     #**********************************************************************************************
    MAIL_RECIP="$(awk '{print $1}' ${RACE}/prm/oem_job_datafile_prep_xftp_email_address.prm)"
    MAIL_SUBJECT="Error in job ${JOBNAME} ${JOBOEMNAME} ${JOBOEM} ${JOBCTRY}: An external FTP file was NOT retrieved"
    echo "\nThis file ${FTP_PULL_TARGET} was NOT retrieved from the External FTP Site:\n"                >> ${MAIL_TEXT}
    echo "      ${FTP_SOURCE_FILE_NAME}\n"                                            >> ${MAIL_TEXT}
    echo "What to do?\n"                                                              >> ${MAIL_TEXT}
    echo "   1. Has the data provider placed their input file on the FTP site?"       >> ${MAIL_TEXT}
    echo "      Yes - Determine if the filename is correct (case matters in Unix)"    >> ${MAIL_TEXT}
    echo "       No - Request that the data provider update their FTP site.\n"        >> ${MAIL_TEXT}
    echo "   2. Did the filename change?"                                             >> ${MAIL_TEXT}
    echo "      Yes - Request update to Oracle table: oem_job.ftp_program_name"       >> ${MAIL_TEXT}
    echo "       No - Forward this email to Rpt.OEM.Developers for programming support!\n" >> ${MAIL_TEXT}
    echo "When ready, it is OK to restart this job: ${JOBNAME} ${STEPNAME}"           >> ${MAIL_TEXT}

    if [ ${THISHOST} = ${TESTHOST} ]
    then
      mailx -s "TEST - $MAIL_SUBJECT" "Gail.Walder@Mitchell.com" < ${MAIL_TEXT}
    else
      mailx -s "$MAIL_SUBJECT" ${MAIL_RECIP} < ${MAIL_TEXT}
    fi
    $(oem_abndalrt.ksh FTP.file.error)
  else
      if [ -s ${SFTP_LOG} ]
      then
         cat ${SFTP_LOG}
      fi
      echo "\nSource File Successfully Pulled to ${FTP_PULL_TARGET}\n"
  fi

		    # Determine if the FTP'd file is zipped (or ZIPped)
  export FILE_SUFFIX=`echo ${INPUT_FILE_NAME} | cut -f2  -d"."`
  if [[ "${FILE_SUFFIX}" = "zip" || "${FILE_SUFFIX}" = "ZIP" ]]
  then
     gunzip -c ${FTP_PULL_TARGET} > ${STEP010_FILEOUT}
  else
    cp ${FTP_PULL_TARGET} ${STEP010_FILEOUT}
  fi

  RECCNT1=$(wc -c ${STEP010_FILEOUT} | awk ' {print $1}' )
  if [ "${RECCNT1}" = "0" ]
  then
    echo "\n*****************************************************************"
    echo "Copied or gunzip'd file ${STEP010_FILEOUT} is bad. Record Count = 0"
    echo "********************************************************************\n"
    $(oem_abndalrt.ksh 911)
  else
    echo "\nCopied or gunzip'd file ${STEP010_FILEOUT} is good\n"
  fi

  rm -f ${FTP_PULL_TARGET}

                    # End Option 1
		    #################################################################################################
else
   if [[ $(echo ${INPUT_FILE_NAME} | awk -F "." '{ print $NF }') = "dat(0)" ]]
   then
     export INPUT_FILE_NAME_EXPANDED=$(setgdg.ksh "${RACE}/dat/${INPUT_FILE_NAME}")
   else
     export INPUT_FILE_NAME_EXPANDED=${RACE}/dat/${INPUT_FILE_NAME}
   fi


  if [ -s ${INPUT_FILE_NAME_EXPANDED} ]
  then
		      ###############################################################################################
 		      #
		      #           Option 2 Input File found in the RACE data directory

    echo "\n*** Option 2 Input File ${INPUT_FILE_NAME_EXPANDED} found in the RACE data directory.\n"

    cp ${INPUT_FILE_NAME_EXPANDED} ${STEP010_FILEOUT}

                      # End Option 2
		      ###############################################################################################
  else
    if [ "${FTP_LOCATION_CODE}" = "M" ]
    then
		      #############################################################################################
		      #
		      #           Option 3 Input File is on the Mitchell FTP Site

      echo "\n*** Option 3 Input File ${INPUT_FILE_NAME_EXPANDED} is on the Mitchell FTP Site.\n"

      . oem_job_process_mitchell_ftp_file.ksh "GETIT"

                      # End Option 3
		      #############################################################################################
    else
		      #############################################################################################
		      #
		      #           Option 4 None of the above?  Then Input File HAS TO BE on the Novell directory.

      echo "\n*** Option 4 None of the above?  Then Input File ${INPUT_FILE_NAME_EXPANDED} HAS TO BE on the Novell directory."

      . oem_job_process_mitchell_ftp_file.ksh "GETMIT" # Change rj132422 20251023

                      # End OPtion 4
		      #############################################################################################
    fi
  fi
fi

#**************************************************************************************************
# END oem_job_datafile_prep.ksh
#**************************************************************************************************
