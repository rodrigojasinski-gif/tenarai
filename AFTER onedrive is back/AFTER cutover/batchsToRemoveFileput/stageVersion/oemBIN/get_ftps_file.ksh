#!/bin/ksh
echo "$Id: get_ftps_file.ksh,v 1.1 2018/09/12 23:02:13 pg2697 Exp $"
##################################################################################
#
#  get_ftps_file.ksh
#
#   Retrieves a file from an external ftp server indicated in the parm file using
#   ftps protocol (NOT ftp and NOT sftp).
#
#   Three Input Parameters
#         1) ftps account file
#               - space delimited file containing
#                       - user id
#                       - password
#                       - server name
#                       - target directory (or DefaultDir)
#                       - port  (not needed for curl)
#                       - encryption type (not needed for curl)
#         2) filename to be retrieved  (remote filename)
#         3) output file name and path (local filename)
#
##################################################################################
trap 'oem_abndalrt.ksh $?' err
LOGFILE=$(basename ${JOBLOGNAME})

#set -xv

PARM_FILE=$1
INPUT_FILE=$2
OUTPUT_FILE=$3

if [ $# -lt 3 ]
then
   echo "get_ftps_file.ksh requires input parameters"
   echo "   1. PARM_FILE"
   echo "   2. INPUT_FILE"
   echo "   3. OUTPUT_FILE"
   oem_abndalrt.ksh get_ftps_file.ksh.parms.are.missing
fi

echo "\n*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*"
echo "Starting get_ftps_file.ksh\n"


# Get values from parm file
USERID=`   awk '{print $1}' ${PARM_FILE}`
PASS=`     awk '{print $2}' ${PARM_FILE}`
SERVER=`   awk '{print $3}' ${PARM_FILE}`
TARGETDIR=`awk '{print $4}' ${PARM_FILE}`

# Build server/path string
   
if [ "${TARGETDIR}" = "DefaultDir" ]
then
   echo "file expected in default directory\n"
   SRVRPATH=${SERVER}   
else
   echo "file expected in subdirectory noted in parm"
   SRVRPATH=${SERVER} || "/" || ${TARGETDIR}  
fi
   
    
# Connect and download the file
# -k  By default, every SSL connection curl makes is verified to be secure. This option allows 
#     curl to proceed and operate even for server connections otherwise considered insecure.
#
# -s  Silent mode
#
# -u  Specify the user name and password to use for server authentication. 
#

echo "Input : $SRVRPATH"
echo "File  : $INPUT_FILE"
echo "Target: $OUTPUT_FILE"
FTP_LOGFILE=$RACE/tmp/${JOBNAME}_ftp_transfer_log.tmp


rm -f ${FTP_LOGFILE} ${OUTPUT_FILE}

RUNMSG=$(curl -k -s -u ${USERID}:${PASS} ftps://$SRVRPATH/$INPUT_FILE > $OUTPUT_FILE || echo ERROR)
if [ "${RUNMSG}" = "ERROR" ]
then
   echo "\n *** ERROR GETTING FILE: $INPUT_FILE ***\n"
   oem_abndalrt.ksh ftps_file_error
   
else
   echo "file transfer successful"  
fi

echo "\nFinished get_ftps_file.ksh"
echo "*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*\n"

###############################################################################
#
#  end get_ftps_file.ksh
#
###############################################################################

