echo "begin of oem_job_email_same_file_msg.ksh"

############################################################################################################################################################
# Sub-Script: oem_job_email_same_file_msg.ksh
#             Creates and sends email message when current file matched prior file 
############################################################################################################################################################ 

export MAIL_TEXT=${RACE}/tmp/${JOBNAME}_email_text.tmp
export TEST_MAIL_TO="Rpt.OEM.Developers@Mitchell.com"
#export TEST_MAIL_TO="Penny.Genovese@Mitchell.com"
export PROD_MAIL_TO="Rpt.OEM.Developers@Mitchell.com; RaceDataOps@Mitchell.com; Rpt.OEM.Data.Analyst@Mitchell.com; Susan.Grimes@mitchell.com"


# Format mail message   -----------------------------------------------------------------------------------------------
printf "No difference found between current data file and previous one. \n"                               > ${MAIL_TEXT}                                     
printf "${FTP_SOURCE_FILE_NAME}   --> ${INPUT_FILE_NAME} \n"                                             >> ${MAIL_TEXT}
printf "\n"                                                                                              >> ${MAIL_TEXT}

printf "NOTE: This is an expected email for a job that is being rerun. \n"                               >> ${MAIL_TEXT}
printf "\n"                                                                                              >> ${MAIL_TEXT}

printf "Files used in comparison:\n"                                                                     >> ${MAIL_TEXT}
printf "-->  Current:  ${STEP030_FILEOUT} \n"                                                            >> ${MAIL_TEXT}
printf "--> Previous:  ${STEP030_PREVRAW} \n"                                                            >> ${MAIL_TEXT}
printf "\n"                                                                                              >> ${MAIL_TEXT}

printf "Additional info: \n"                                                                             >> ${MAIL_TEXT}                                                                                                                                          
printf "--> File Location:  ${FTP_LOCATION_CODE} \n"                                                     >> ${MAIL_TEXT}
printf "--> Frequency this file is expected to change is: ${SOURCE_FILE_UPDATE_FREQUENCY} months. \n"    >> ${MAIL_TEXT}
printf "--> Date that the input file last changed was:  ${SOURCE_FILE_UPDATE_DATE} \n"                   >> ${MAIL_TEXT}
printf "\n"                                                                                              >> ${MAIL_TEXT}

printf "Next Steps: \n"                                                                                  >> ${MAIL_TEXT}
printf "1. Was the correct job executed? \n"                                                             >> ${MAIL_TEXT}
printf "\n"                                                                                              >> ${MAIL_TEXT}

printf "2. Does Provider send more than one file? If so, are ALL files resulting in same file warning? \n" >> ${MAIL_TEXT}
printf "   (e.g. Tesla sends price and super file. The prices are changed frequently. "                  >> ${MAIL_TEXT}
printf "Supersessions rarely change.) \n"                                                                >> ${MAIL_TEXT}   
printf "   --> If ALL triggered same file warning, send email to OEM contact noting: \n"                 >> ${MAIL_TEXT}
printf "       o While processing your recently staged files, our process detected that the files are "  >> ${MAIL_TEXT}
printf "exactly the same as the ones that you last provided. (i.e. No price changes, no parts added or " >> ${MAIL_TEXT}
printf "dropped.) \n"                                                                                    >> ${MAIL_TEXT}
printf "       o Is this to be expected or have the wrong files been staged? \n"                         >> ${MAIL_TEXT}
printf "   --> If one file of multiple files triggered same file warning but other file(s) did not, "    >> ${MAIL_TEXT}
printf "this means that 'as a whole', the data DID change for the run. It is probably OKAY to proceed, " >> ${MAIL_TEXT}
printf "with the update although contacting the OEM is still recommended should the file remain the "    >> ${MAIL_TEXT}
printf "same for a long period of time. \n"                                                              >> ${MAIL_TEXT}
printf "\n"                                                                                              >> ${MAIL_TEXT}

printf "3. If file location = ‘  ’, this job is using another reformat’s file. Was THAT job run prior "  >> ${MAIL_TEXT}
printf "to this? \n"                                                                                     >> ${MAIL_TEXT} 
printf "\n"                                                                                              >> ${MAIL_TEXT}

printf "4. If file location = ‘N’, was file saved to prod3nt directory and named correctly? Also, "      >> ${MAIL_TEXT}
printf "check the date of the file to what is on prod3nt. \n"                                            >> ${MAIL_TEXT}
printf "\n"                                                                                              >> ${MAIL_TEXT}

printf "5. If file location = ‘X’, does the file on the OEMs server have correct name and has date of "  >> ${MAIL_TEXT}  
printf "this runs file changed from the date of the last runs file? \n"                                  >> ${MAIL_TEXT}
printf "\n"                                                                                              >> ${MAIL_TEXT}

printf "6. If file location = ‘M’, does the file on Mitchells server have correct name and has date of " >> ${MAIL_TEXT}
printf "this runs file changed from the date of the last runs file? \n"                                  >> ${MAIL_TEXT}
printf "   --> If so, send email to OEM contact noting: \n"                                              >> ${MAIL_TEXT}
printf "       o While processing your recently staged price file, our process detected that this file " >> ${MAIL_TEXT}
printf "is exactly the same as the one that you last provided. (i.e. No price changes, no parts added "  >> ${MAIL_TEXT}
printf "or dropped.) \n"                                                                                 >> ${MAIL_TEXT} 
printf "       o Is this to be expected or has the wrong file been staged? \n"                           >> ${MAIL_TEXT}
printf "   --> If not correct name, send email to OEM requesting new file be staged: \n"                 >> ${MAIL_TEXT}
printf "       o We are noticing the name associated to your file does not match what our process is "   >> ${MAIL_TEXT} 
printf "expecting: ${FTP_SOURCE_FILE_NAME} --> ${INPUT_FILE_NAME} \n"                                    >> ${MAIL_TEXT}
printf "   --> If not recent date, send email to OEM requesting new file be staged: \n"                  >> ${MAIL_TEXT}
printf "       o We are noticing the date associated to your file is not current. Has the proper file "  >> ${MAIL_TEXT}
printf "been staged? \n" >> ${MAIL_TEXT}
printf "\n"                                                                                              >> ${MAIL_TEXT}

printf "NOTE: If OEM confirms no change in data file, proceed with update. \n "                          >> ${MAIL_TEXT}
printf "      If OEM says file should contain changes, \n"                                               >> ${MAIL_TEXT}
printf "      o Verify the file they provided contains changes they're aware of. \n"                     >> ${MAIL_TEXT}
printf "      o Make sure we staged/processed the new file correctly. \n"                                >> ${MAIL_TEXT}
printf "      o You may need to request they restage/resend their file, if you don't see the changes. "  >> ${MAIL_TEXT}       
printf "Mark 1st run as bad. Reorder file. Mark file received. Rerun job from top. \n"                   >> ${MAIL_TEXT}
printf "\n"                                                                                              >> ${MAIL_TEXT}

# Send email    -------------------------------------------------------------------------------------------------------
          if [ ${THISHOST} = ${TESTHOST} ]
          then
            mailx -s "Test system warning! ${JOBNAME}: Same input file being processed!" ${TEST_MAIL_TO} < ${MAIL_TEXT}
          else          
            if [ "${SOURCE_FILE_UPDATE_FREQUENCY}" = "1" ]
            then
              mailx -s "Production ERROR! ${JOBNAME}: Same input file being processed!" ${PROD_MAIL_TO} < ${MAIL_TEXT}
            else
              mailx -s "Production Warning! ${JOBNAME}: Same input file being processed!" ${PROD_MAIL_TO} < ${MAIL_TEXT}
            fi
          fi  
#-------------------------------------------------------------------------------------

printf "end of oem_job_email_same_file_msg.ksh"