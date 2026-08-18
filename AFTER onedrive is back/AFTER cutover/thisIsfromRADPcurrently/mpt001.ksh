#!/bin/ksh
 echo "$Id: mpt001.ksh,v 1.5 2016/04/01 01:07:39 pg2697 Exp $"
############################################################################
#  PROCNAME:  mpt001                                                       #
#  OEM PARTS ODD EXTRACT PROCESS                                           #
#  CREATE OEM PARTS RELATED FILES FOR DELIVERY TO:                         #
#  1. OEM ODD DIRECTORIES (PRODUCT, ARCHIVE, and UAT)                      #
#     UAT -> USER ACCEPTANCE TESTING (CUSTOMER)                            #
############################################################################

set -xv
export PROCNAME=$(basename $0 .ksh_run)
trap 'abndalrt.ksh    $?' err

export MPTUSERID=`cat $RACE/prm/zmptpass.prm`
export SQL_TMP_PATH=$OBJ_TMPDIR

export RPTDATE=$(date +'%C%y%m%d%H%M%S')
export FILEDATE=$(date +'%C%y%m%d')

export US_COUNTRY_ABBR='us'
export CA_COUNTRY_ABBR='ca'
export EN_LANG_CODE='en'


#STEP Step005R
#*********************************************************************************************************************
#* FOR US: EXECUTE EXT.PKG_OEM_ODD.sp_extract_oem_delta to create OEM ODD extract file.
#*********************************************************************************************************************
export STEPNAME=Step005R
echo "    Start   ${STEPNAME}           "$(date)

sqlplus << % 2>&1 > $LOG
$MPTUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec PKG_OEM_ODD.SP_EXTRACT_OEM_DELTA('$US_COUNTRY_ABBR','$EN_LANG_CODE','$SQL_TMP_PATH','$JOBNAME');

QUIT;
%

#STEP Step010R
#**********************************************************************
#*   COPY EXTRACT SUMMARY REPORT TO OEM ODD ARCHIVE DIRECTORY         *
#**********************************************************************
export STEPNAME=Step010R
echo "    Start   ${STEPNAME}           "$(date)

export DD_FILE1=$RACE/tmp/${JOBNAME}s_extrsums_odd_${US_COUNTRY_ABBR}_${EN_LANG_CODE}.tmp
export DD_FILE2=$RACE/../../odd/oem/archive/dat/extrsums_odd_${US_COUNTRY_ABBR}_${EN_LANG_CODE}_${FILEDATE}.rpt

cp $DD_FILE1 $DD_FILE2 2>&1


#STEP Step015R
#**********************************************************************
#*   COPY EXTRACT SUMMARY REPORT TO PERMANENT RACE REPORT DIRECTORY   *
#**********************************************************************
export STEPNAME=Step015R
echo "    Start   ${STEPNAME}           "$(date)

export DD_FILE1=$RACE/tmp/${JOBNAME}s_extrsums_odd_${US_COUNTRY_ABBR}_${EN_LANG_CODE}.tmp
export DD_FILE2=$RACE/rpt/${JOBNAME}u_extrsums_odd_${US_COUNTRY_ABBR}_${EN_LANG_CODE}_${RPTDATE}.rpt

cp $DD_FILE1 $DD_FILE2 2>&1

rpt_log_retention.ksh "${JOBNAME}u"


#STEP Step020R
#**********************************************************************
#*  IF AN INCREMENTAL OEM ODD FILE WAS CREATED IN STEP005R, THEN:     *
#*  1. BUILD OEM ODD GDG                                              *
#**********************************************************************
export STEPNAME=Step020R
echo "    Start   ${STEPNAME}           "$(date)

export DD_FILE1=$RACE/tmp/${JOBNAME}_odd_${US_COUNTRY_ABBR}_${EN_LANG_CODE}.ttt
export DD_FILE2=$( setgdg.ksh \
       "$RACE/dat/${JOBNAME}_odd_${US_COUNTRY_ABBR}_${EN_LANG_CODE}.dat(+1)" NEW 8)

if [ ! -s $DD_FILE1 ]
  then
    echo "Step020R NOTE: No OEM ODD created this time for COUNTRY: ${US_COUNTRY_ABBR} REGION: ${EN_LANG_CODE}.\a"
  else
    cp $DD_FILE1 $DD_FILE2 2>&1
fi

#STEP Step025R
#**********************************************************************
#*  IF AN INCREMENTAL OEM ODD FILE WAS CREATED IN STEP005R, THEN:     *
#*  1. COPY OEM ODD FILE TO THE PRODUCT DIRECTORY                     *
#*  2. RENAME THE "ttt" FILE TO A "txt" FILE SO THAT ODD MECHANISM    *
#*     CAN PICK IT UP.                                                *
#**********************************************************************
export STEPNAME=Step025R
echo "    Start   ${STEPNAME}           "$(date)

export DD_FILE1=$RACE/tmp/${JOBNAME}_odd_${US_COUNTRY_ABBR}_${EN_LANG_CODE}.ttt
export TTT_FILE=$RACE/../../odd/oem/product/dat/${FILEDATE}-R${US_COUNTRY_ABBR}_L${EN_LANG_CODE}.ttt
export TXT_FILE=$RACE/../../odd/oem/product/dat/${FILEDATE}_${US_COUNTRY_ABBR}_${EN_LANG_CODE}-R${US_COUNTRY_ABBR}_L${EN_LANG_CODE}.txt

if [ ! -s $DD_FILE1 ]
  then
    echo "Step025R NOTE: No OEM ODD created this time for COUNTRY: ${US_COUNTRY_ABBR} REGION: ${EN_LANG_CODE}.\a"
  else
    cp ${DD_FILE1} ${TTT_FILE}
    mv ${TTT_FILE} ${TXT_FILE}
fi

#STEP Step026R
#**********************************************************************
#*  IF AN INCREMENTAL OEM ODD FILE WAS CREATED IN STEP005R, THEN:     *
#*  1. COPY OEM ODD FILE TO THE UAT DIRECTORY                         *
#*  2. RENAME THE "ttt" FILE TO A "txt" FILE SO THAT ODD MECHANISM    *
#*     CAN PICK IT UP.                                                *
#**********************************************************************
export STEPNAME=Step026R
echo "    Start   ${STEPNAME}           "$(date)

export DD_FILE1=$RACE/tmp/${JOBNAME}_odd_${US_COUNTRY_ABBR}_${EN_LANG_CODE}.ttt
export TTT_FILE=$RACE/../../odd/oem/uat/dat/${FILEDATE}-R${US_COUNTRY_ABBR}_L${EN_LANG_CODE}.ttt
export TXT_FILE=$RACE/../../odd/oem/uat/dat/${FILEDATE}_${US_COUNTRY_ABBR}_${EN_LANG_CODE}-R${US_COUNTRY_ABBR}_L${EN_LANG_CODE}.txt

if [ ! -s $DD_FILE1 ]
  then
    echo "Step026R NOTE: No OEM ODD created this time for COUNTRY: ${US_COUNTRY_ABBR} REGION: ${EN_LANG_CODE}.\a"
  else
    cp ${DD_FILE1} ${TTT_FILE}
    mv ${TTT_FILE} ${TXT_FILE}
fi


#STEP Step027R
#**********************************************************************
#*  IF AN INCREMENTAL OEM ODD FILE WAS CREATED IN STEP005R, THEN:     *
#*  1. COPY OEM ODD FILE TO THE ARCHIVE DIRECTORY                     *
#*  2. RENAME THE "ttt" FILE TO A "txt" FILE                          *
#**********************************************************************
export STEPNAME=Step027R
echo "    Start   ${STEPNAME}           "$(date)

export DD_FILE1=$RACE/tmp/${JOBNAME}_odd_${US_COUNTRY_ABBR}_${EN_LANG_CODE}.ttt
export TTT_FILE=$RACE/../../odd/oem/archive/dat/${FILEDATE}-R${US_COUNTRY_ABBR}_L${EN_LANG_CODE}.ttt
export TXT_FILE=$RACE/../../odd/oem/archive/dat/${FILEDATE}_${US_COUNTRY_ABBR}_${EN_LANG_CODE}-R${US_COUNTRY_ABBR}_L${EN_LANG_CODE}.txt

if [ ! -s $DD_FILE1 ]
  then
    echo "Step027R NOTE: No OEM ODD created this time for COUNTRY: ${US_COUNTRY_ABBR} REGION: ${EN_LANG_CODE}.\a"
  else
    cp ${DD_FILE1} ${TTT_FILE}
    mv ${TTT_FILE} ${TXT_FILE}
fi


#STEP Step030R
#**********************************************************************
#*   SEND EMAIL TO VARIOUS RECIPIENTS RE: SUCCESSFUL FILE CREATION    *
#**********************************************************************
export STEPNAME=Step030R
echo "    Start   ${STEPNAME}           "$(date)

export MAIL_LIST=$RACE/prm/mpt001r.prm
export DD_FILE1=$RACE/tmp/${JOBNAME}_odd_${US_COUNTRY_ABBR}_${EN_LANG_CODE}.ttt

if [ ! -s $DD_FILE1 ]
then
   export FTP_TEXT=$(more $RACE/prm/mpt001v.prm  | awk '{print}' )
   echo "\n**********************************************************
         \n Step030R: No OEM ODD File was created in this run for COUNTRY: ${US_COUNTRY_ABBR} REGION: ${EN_LANG_CODE}.   
         \n**********************************************************"
else 
   export FTP_TEXT=$(more $RACE/prm/mpt001u.prm  | awk '{print}' )
   echo "\n********************************************************** 
         \n Step030R: OEM ODD File was created in this run for COUNTRY: ${US_COUNTRY_ABBR} REGION: ${EN_LANG_CODE}. 
         \n**********************************************************"
fi

while read LINE
do 
  export RECIP=`echo $LINE | cut -f1`
  if [ ${ACT_LVL} = prod ]
  then
    echo $FTP_TEXT | mailx -s "US OEM ODD Extract - PRODUCTION"  ${RECIP}
  else
    echo $FTP_TEXT | mailx -s "US OEM ODD Extract - TEST (DEV)"  ${RECIP}
  fi    
done<$MAIL_LIST

#STEP Step040R
#**************************************************************************
#*   REMOVE US TEMP FILES (tmp and ttt)                                   *
#*   Note - this is done prior to CA to allow for more available tmp space* 
#**************************************************************************
#export STEPNAME=Step040R
#echo "    Start   ${STEPNAME}           "$(date)

trap '' err
find $RACE/tmp/ -type f -name $JOBNAME\* -exec rm {} \; 2> /dev/null
trap 'abndalrt.ksh    $?' err

#* WARNING!! Do NOT insert a space between the "2" and the ">" as this could hose up 
#* the /dev/null file! The find command was structured this way to avoid hitting the 
#* tags directory and to avoid getting an arglist too long error message.


#STEP Step105R
#***************************************************************************************
#* FOR CA: EXECUTE EXT.PKG_OEM_ODD.sp_extract_oem_delta to create OEM ODD extract file.* 
#***************************************************************************************
export STEPNAME=Step105R
echo "    Start   ${STEPNAME}           "$(date)

sqlplus << % 2>&1 > $LOG
$MPTUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec PKG_OEM_ODD.SP_EXTRACT_OEM_DELTA('$CA_COUNTRY_ABBR','$EN_LANG_CODE','$SQL_TMP_PATH','$JOBNAME');

QUIT;
%

#STEP Step110R
#**********************************************************************
#*   COPY EXTRACT SUMMARY REPORT TO OEM ODD ARCHIVE DIRECTORY         *
#**********************************************************************
export STEPNAME=Step110R
echo "    Start   ${STEPNAME}           "$(date)

export DD_FILE1=$RACE/tmp/${JOBNAME}s_extrsums_odd_${CA_COUNTRY_ABBR}_${EN_LANG_CODE}.tmp
export DD_FILE2=$RACE/../../odd/oem/archive/dat/extrsums_odd_${CA_COUNTRY_ABBR}_${EN_LANG_CODE}_${FILEDATE}.rpt

cp $DD_FILE1 $DD_FILE2 2>&1


#STEP Step115R
#**********************************************************************
#*   COPY EXTRACT SUMMARY REPORT TO PERMANENT RACE REPORT DIRECTORY   *
#**********************************************************************
export STEPNAME=Step115R
echo "    Start   ${STEPNAME}           "$(date)

export DD_FILE1=$RACE/tmp/${JOBNAME}s_extrsums_odd_${CA_COUNTRY_ABBR}_${EN_LANG_CODE}.tmp
export DD_FILE2=$RACE/rpt/${JOBNAME}c_extrsums_odd_${CA_COUNTRY_ABBR}_${EN_LANG_CODE}_${RPTDATE}.rpt

cp $DD_FILE1 $DD_FILE2 2>&1

rpt_log_retention.ksh "${JOBNAME}c"


#STEP Step120R
#**********************************************************************
#*  IF AN INCREMENTAL OEM ODD FILE WAS CREATED IN STEP005R, THEN:     *
#*  1. BUILD OEM ODD GDG                                              *
#**********************************************************************
export STEPNAME=Step120R
echo "    Start   ${STEPNAME}           "$(date)

export DD_FILE1=$RACE/tmp/${JOBNAME}_odd_${CA_COUNTRY_ABBR}_${EN_LANG_CODE}.ttt
export DD_FILE2=$( setgdg.ksh \
       "$RACE/dat/${JOBNAME}_odd_${CA_COUNTRY_ABBR}_${EN_LANG_CODE}.dat(+1)" NEW 8)

if [ ! -s $DD_FILE1 ]
  then
    echo "Step120R NOTE: No OEM ODD created this time for COUNTRY: ${CA_COUNTRY_ABBR} REGION: ${EN_LANG_CODE}.\a"
  else
    cp $DD_FILE1 $DD_FILE2 2>&1
fi

#STEP Step125R
#**********************************************************************
#*  IF AN INCREMENTAL OEM ODD FILE WAS CREATED IN STEP005R, THEN:     *
#*  1. COPY OEM ODD FILE TO THE PRODUCT DIRECTORY                     *
#*  2. RENAME THE "ttt" FILE TO A "txt" FILE SO THAT ODD MECHANISM    *
#*     CAN PICK IT UP.                                                *
#**********************************************************************
export STEPNAME=Step125R
echo "    Start   ${STEPNAME}           "$(date)

export DD_FILE1=$RACE/tmp/${JOBNAME}_odd_${CA_COUNTRY_ABBR}_${EN_LANG_CODE}.ttt
export TTT_FILE=$RACE/../../odd/oem/product/dat/${FILEDATE}-R${CA_COUNTRY_ABBR}_L${EN_LANG_CODE}.ttt
export TXT_FILE=$RACE/../../odd/oem/product/dat/${FILEDATE}_${CA_COUNTRY_ABBR}_${EN_LANG_CODE}-R${CA_COUNTRY_ABBR}_L${EN_LANG_CODE}.txt

if [ ! -s $DD_FILE1 ]
  then
    echo "Step125R NOTE: No OEM ODD created this time for COUNTRY: ${CA_COUNTRY_ABBR} REGION: ${EN_LANG_CODE}.\a"
  else
    cp ${DD_FILE1} ${TTT_FILE}
    mv ${TTT_FILE} ${TXT_FILE}
fi


#STEP Step126R
#**********************************************************************
#*  IF AN INCREMENTAL OEM ODD FILE WAS CREATED IN STEP005R, THEN:     *
#*  1. COPY OEM ODD FILE TO THE UAT DIRECTORY                         *
#**********************************************************************
export STEPNAME=Step126R
echo "    Start   ${STEPNAME}           "$(date)

export DD_FILE1=$RACE/tmp/${JOBNAME}_odd_${CA_COUNTRY_ABBR}_${EN_LANG_CODE}.ttt
export TTT_FILE=$RACE/../../odd/oem/uat/dat/${FILEDATE}-R${CA_COUNTRY_ABBR}_L${EN_LANG_CODE}.ttt
export TXT_FILE=$RACE/../../odd/oem/uat/dat/${FILEDATE}_${CA_COUNTRY_ABBR}_${EN_LANG_CODE}-R${CA_COUNTRY_ABBR}_L${EN_LANG_CODE}.txt

if [ ! -s $DD_FILE1 ]
  then
    echo "Step126R NOTE: No OEM ODD created this time for COUNTRY: ${CA_COUNTRY_ABBR} REGION: ${EN_LANG_CODE}.\a"
  else
    cp ${DD_FILE1} ${TTT_FILE}
    mv ${TTT_FILE} ${TXT_FILE}
fi


#STEP Step127R
#**********************************************************************
#*  IF AN INCREMENTAL OEM ODD FILE WAS CREATED IN STEP005R, THEN:     *
#*  1. COPY OEM ODD FILE TO THE ARCHIVE DIRECTORY                     *
#**********************************************************************
export STEPNAME=Step127R
echo "    Start   ${STEPNAME}           "$(date)

export DD_FILE1=$RACE/tmp/${JOBNAME}_odd_${CA_COUNTRY_ABBR}_${EN_LANG_CODE}.ttt
export TTT_FILE=$RACE/../../odd/oem/archive/dat/${FILEDATE}-R${CA_COUNTRY_ABBR}_L${EN_LANG_CODE}.ttt
export TXT_FILE=$RACE/../../odd/oem/archive/dat/${FILEDATE}_${CA_COUNTRY_ABBR}_${EN_LANG_CODE}-R${CA_COUNTRY_ABBR}_L${EN_LANG_CODE}.txt

if [ ! -s $DD_FILE1 ]
  then
    echo "Step127R NOTE: No OEM ODD created this time for COUNTRY: ${CA_COUNTRY_ABBR} REGION: ${EN_LANG_CODE}.\a"
  else
    cp ${DD_FILE1} ${TTT_FILE}
    mv ${TTT_FILE} ${TXT_FILE}
fi


#STEP Step130R
#**********************************************************************
#*   SEND EMAIL TO VARIOUS RECIPIENTS RE: SUCCESSFUL FILE CREATION    *
#**********************************************************************
export STEPNAME=Step130R
echo "    Start   ${STEPNAME}           "$(date)

export MAIL_LIST=$RACE/prm/mpt001r.prm
export DD_FILE1=$RACE/tmp/${JOBNAME}_odd_${CA_COUNTRY_ABBR}_${EN_LANG_CODE}.ttt

if [ ! -s $DD_FILE1 ]
then
   export FTP_TEXT=$(more $RACE/prm/mpt001d.prm  | awk '{print}' )
   echo "\n************************************************************************
         \n Step130R: No OEM ODD File was created in this run for COUNTRY: ${CA_COUNTRY_ABBR} REGION: ${EN_LANG_CODE}.   
         \n************************************************************************"
else 
   export FTP_TEXT=$(more $RACE/prm/mpt001c.prm  | awk '{print}' )
   echo "\n************************************************************************ 
         \n Step130R: OEM ODD File was created in this run for COUNTRY: ${CA_COUNTRY_ABBR} REGION: ${EN_LANG_CODE}. 
         \n************************************************************************"
fi

while read LINE
do 
  export RECIP=`echo $LINE | cut -f1`
  if [ ${ACT_LVL} = prod ]
  then
    echo $FTP_TEXT | mailx -s "CA OEM ODD Extract - PRODUCTION"  ${RECIP}
  else
    echo $FTP_TEXT | mailx -s "CA OEM ODD Extract - TEST (DEV)"  ${RECIP}
  fi    
done<$MAIL_LIST

#STEP Step140R
#**************************************************************************
#*   REMOVE CA TEMP FILES (tmp and ttt)                                   *
#**************************************************************************
#export STEPNAME=Step140R
#echo "    Start   ${STEPNAME}           "$(date)

trap '' err
find $RACE/tmp/ -type f -name $JOBNAME\* -exec rm {} \; 2> /dev/null
trap 'abndalrt.ksh    $?' err

#* WARNING!! Do NOT insert a space between the "2" and the ">" as this could hose up 
#* the /dev/null file! The find command was structured this way to avoid hitting the 
#* tags directory and to avoid getting an arglist too long error message.


#STEP Step900R
#**********************************************************************
#*   REMOVE FILES OLDER THAN 76 DAYS FROM OEM ODD ARCHIVE DIRECTORY   *
#**********************************************************************
export STEPNAME=Step900R
echo "    Start   ${STEPNAME}           "$(date)

find $RACE/../../odd/oem/archive/dat -type f -mtime +76 -exec rm {} \;


#* END-OF-SCRIPT ******************************************************
