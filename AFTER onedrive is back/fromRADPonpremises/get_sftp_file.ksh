#!/bin/ksh
## get_sftp_file.ksh GW 5/31/2012
## bypass trap in child script and abend in parent script - see notes below
##trap 'oem_abndalrt.ksh $?' err


########################################################################################
# OEM Job to sftp Files from An OEM External FTP Site
#
# There is no text file transfer mode with sftp. All files are transferred in binary mode.
#
# $1 is the OEM sftp parm file for the file to be downloaded.
# For multiple OEM files, the file names and parms are listed in the oem_job_datafile table by File Sequence Number.
#    Parm Values
#    a.  FTP SITE Passwordless Login using sftp Authentication Keys.
#    b.  FTP Site Host Directory when it exists.
#
# $2 are the literals or UNIX cmds used to search for the file on the FTP site.
# $3 is the Mitchell UNIX destination file name.
#
# Note: To run manually you must be logged in as race_b1 for Authentication Keys to work.
#       When logged in as race_b1 the job in ..../share/bin/ is executed first.
##########################################################################################

echo "\nEXECUTING get_sftp_file.ksh"
print ProcessId = $$


FTP_PARM_FILE=$1
SEARCH_STRING=$2
FTP_PULL_TARGET=$3

echo "\nFTP_PARM_FILE:    ${FTP_PARM_FILE}"
echo "SEARCH_STRING:    ${SEARCH_STRING}"
echo "FTP_PULL_TARGET:  ${FTP_PULL_TARGET}\n"

export OEM_FTP_SITE="$(head -n1 $FTP_PARM_FILE| awk '{print $1}' FS=",")"
export HOST_DIR="$(head -n1 $FTP_PARM_FILE | awk '{print $2}' FS=",")"

echo "OEM_FTP_SITE:     ${OEM_FTP_SITE}"
echo "HOST_DIR:         ${HOST_DIR}\n"

export TMP_DIR=${RACE}/tmp

		## create a list of the files on the ftp site.
		## the output always logs/includes the sftp statements executed
echo "Start FTP Site Filelist Creation   $(date)"

 if [ -n "${HOST_DIR}" ]
    then
         echo "sftp ${OEM_FTP_SITE} >> ${SFTP_LOG} <<EOF\n"
	`sftp ${OEM_FTP_SITE} >> ${SFTP_LOG} <<EOF
	  cd ${HOST_DIR}
	  ls -1 *${SEARCH_STRING}* | tail -1
	  bye
	  EOF`
     else
        echo "sftp ${OEM_FTP_SITE} >> ${SFTP_LOG} <<EOF\n"
       `sftp ${OEM_FTP_SITE} >> ${SFTP_LOG} <<EOF
       	 ls -1 *${SEARCH_STRING}* | tail -1
      	 bye
	 EOF`
  fi

               ## On ftp error write to MAIL_TEXT and exit 0 to bypass abndalrt trap in calling script
               ## the calling script tests if FTP_PULL target exists and if not -> ABENDS & emails errors
export sftp_status=$?
if ! [ "${sftp_status}" = "0" ]
then
  echo "\nABEND IN JOB: get_sftp_file.ksh During List Files ${FTP_SITE_FILE} Status=${sftp_status} See sftp log in tmp\n" >> ${MAIL_TEXT}
  echo "\nABEND IN JOB: get_sftp_file.ksh During List Files ${FTP_SITE_FILE} Status=${sftp_status} See sftp log in tmp\n"
  exit 0
fi

##echo "Status Logon & List Files: ${sftp_status}\n"
echo "\nEnd Create FTP Site Filelist    $(date)\n"

		## Get the latest file name that meets the search criteria from the log
		## bypass the 'sftp' statements in the log
export FTP_SITE_FILE=`grep ${SEARCH_STRING} ${SFTP_LOG}|grep -v sftp|sort|tail -1`
echo "Latest FTP_SITE_FILE: ${FTP_SITE_FILE}"

		## get the file from the ftp site and copy it to UNIX.
		## the output includes logging the sftp statements executed
echo "\nStart to get the Latest FTP Site File   $(date)\n"
if [ -n "${HOST_DIR}" ]
    then
        echo "sftp ${OEM_FTP_SITE} >> ${SFTP_LOG} <<EOF\n"
	`sftp ${OEM_FTP_SITE} >> ${SFTP_LOG} <<EOF
	  lcd ${RACE}/tmp
	  cd ${HOST_DIR}
	  get ${FTP_SITE_FILE} ${FTP_PULL_TARGET}
	  bye
	  EOF`
     else
         echo "sftp ${OEM_FTP_SITE} >> ${SFTP_LOG} <<EOF\n"
    	`sftp ${OEM_FTP_SITE} >> ${SFTP_LOG} <<EOF
    	  lcd ${RACE}/tmp
    	  get ${FTP_SITE_FILE} ${FTP_PULL_TARGET}
   	  bye
    	  EOF`
 fi

               ## On ftp error write to MAIL_TEXT and exit 0 to bypass abndalrt trap in calling script
               ## the calling script tests if FTP_PULL target exists and if not -> ABENDS
export sftp_status=$?
if ! [ "${sftp_status}" = "0" ]
then
  echo "\nABEND IN JOB: get_sftp_file.ksh During get ${FTP_SITE_FILE} Status=${sftp_status} See sftp lOG\n" >> ${MAIL_TEXT}
  echo "\nABEND IN JOB: get_sftp_file.ksh During get ${FTP_SITE_FILE} Status=${sftp_status} See sftp lOG\n"
  exit 0
fi

##echo "Status Get Files: ${sftp_status}"
echo "\nEnd get the Latest FTP Site File   $(date)\n"
