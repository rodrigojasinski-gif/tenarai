#!/bin/ksh
echo "$Id: fileget.ksh,v 1.7 2020/08/28 00:48:12 pg2697 Exp $"
###############################################################################
#
#  fileget.ksh
#
#  Transfer files from Novell location to Unix ... and unzip if needed.
#
###############################################################################

INPUT_FILE=$1
OUTPUT_FILE=$2

if [ $# -lt 2 ]
then
   echo "fileget.ksh requires input parameters"
   echo "   1. INPUT_FILE"
   echo "   2. OUTPUT_FILE"
   oem_abndalrt.ksh fileget.ksh.parms.are.missing
fi

echo "\n*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*"
echo "Starting fileget.ksh\n"

export NOVELL_DIR=${NOVELL}oem
export STDOUT=${RACE}/tmp/${JOBNAME}_${INPUT_FILE}_stdout.tmp
export WORK_FILE=${RACE}/tmp/${JOBNAME}_${INPUT_FILE}_wrkout.tmp

rm -f ${STDOUT} ${WORK_FILE} ${OUTPUT_FILE}

echo "Input:  $NOVELL_DIR\$INPUT_FILE":
echo "Target: $WORK_FILE"
fileget.exp ${INPUT_FILE} ${WORK_FILE} ${NOVELL_DIR} | tee ${STDOUT}
if [ ! -s ${WORK_FILE} ]
then
   echo "UNIX file was empty when created !!\a"
   oem_abndalrt.ksh ftp_null_file
fi

SOURCE_COUNT="$(grep 'Information returned by' ${STDOUT} | awk '{print $1}')"
TARGET_COUNT="$(wc -c ${WORK_FILE} | awk '{print $1}')"
if [ ${SOURCE_COUNT} -eq ${TARGET_COUNT} ]
then
   echo " FTP of file ${INPUT_FILE} succeeded, byte count = ${SOURCE_COUNT} "
else
   echo " ***** error ***** ftp directory counts do not match "
   echo " NOVELL byte count = ${SOURCE_COUNT} "
   echo "   UNIX byte count = ${TARGET_COUNT} "
   oem_abndalrt.ksh ftp_get
fi

export FILETYPE=`print ${INPUT_FILE##*.}`
echo "FILETYPE --> ${FILETYPE}"

if [ "${FILETYPE}" = "zip" ] || [ "${FILETYPE}" = "Zip" ] || [ "${FILETYPE}" = "ZIP" ] || 
   [ "${FILETYPE}" = "zzz" ] || [ "${FILETYPE}" = "Zzz" ] || [ "${FILETYPE}" = "ZZZ" ] || 
   [ "${FILETYPE}" = "piz" ] || [ "${FILETYPE}" = "Piz" ] || [ "${FILETYPE}" = "PIZ" ] || 
   [ "${FILETYPE}" = "zzp" ] || [ "${FILETYPE}" = "Zzp" ] || [ "${FILETYPE}" = "ZZP" ] || 
   [ "${FILETYPE}" = "zpp" ] || [ "${FILETYPE}" = "Zpp" ] || [ "${FILETYPE}" = "ZPP" ]   
then
   mv ${WORK_FILE} ${WORK_FILE}.gz
   gunzip -c ${WORK_FILE}.gz > ${OUTPUT_FILE}
   reccnt1=$(wc -c ${OUTPUT_FILE} | awk '{print $1}')
   if [ reccnt1 -eq 0 ]
   then
      echo " unzipped file is empty "
      $( oem_abndalrt.ksh 911 )
   else
      echo " unzipped file is good "
   fi
else
   mv ${WORK_FILE} ${OUTPUT_FILE}
fi

echo "\nFinished fileget.ksh"
echo "*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*\n"

###############################################################################
#
#  end fileget.ksh
#
###############################################################################
