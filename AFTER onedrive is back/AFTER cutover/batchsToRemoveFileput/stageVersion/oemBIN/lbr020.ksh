#!/bin/ksh
echo "$Id: lbr020.ksh,v 1.7 2022/03/21 19:58:18 pg2697 Exp $"
############################################################################
#  PROCNAME:  lbr020                                                       #
#  PROC DESCRIPTION: LOAD US Honda LABOR WARRANTY DATA                     #
############################################################################
set -xv
export PROCNAME=$(basename $0 .ksh_run)
trap 'abndalrt.ksh $?' err
  
export FILEDATE=$(date +'%C%y%m%d')
export MPTUSERID=`cat $RACE/prm/zmptpass.prm`
export DAT_DIR=$RACE/dat
export SQL_JOBNAME=$JOBNAME
export SQL_TMP_PATH=$OBJ_TMPDIR
export SQL_LOG_PATH=$OBJ_LOGDIR
export SQL_LOGFILE=${JOBLOGNAME}
export RPT_PATH=$OBJ_RPTDIR
export MFILE1=$RACE/dat/${JOBNAME}_flatrate.dat
export MFILE2=$RACE/dat/${JOBNAME}_laborop.dat
export MFILE3=$RACE/dat/${JOBNAME}_model.dat
export MFILE4=$RACE/dat/${JOBNAME}_section.dat
export MFILE5=$RACE/dat/${JOBNAME}_subsect.dat
export ZIPDATFILES=$RACE/dat/${JOBNAME}_honda_warranty_alldata.zip
export RPT_NAME1=$RACE/rpt/${JOBNAME}_load_warr_upd_summary.rpt
export RPT_NAME2=$RACE/rpt/${JOBNAME}_model_config_upd_summary.rpt
export RPT_NAME3=$RACE/rpt/${JOBNAME}_labor_operation_upd_summary.rpt
export RPT_NAME4=$RACE/rpt/${JOBNAME}_labor_time_upd_summary.rpt

#**********************************************************************
# Set SFTP parm based on environment in which you are running
#**********************************************************************
if [ $ACT_LVL = "prod" ]; then
  print "using PROD sftp_prm"
  export export SFTP_PARM=$RACE/prm/${JOBNAME}_ftp_hon_us_prod.prm
else
  print "using QA sftp_prm"
  export SFTP_PARM=$RACE/prm/${JOBNAME}_ftp_hon_us_mdev.prm
fi

#STEP Step010R
     export STEPNAME=Step010R
     echo "    Start " ${STEPNAME} "    "$(date)
#**********************************************************************
# Program: Delete temp files                                          *
#**********************************************************************
     rm -f $RACE/tmp/${JOBNAME}*  


#STEP Step020R
    export STEPNAME=Step020R
    echo "    Start " ${STEPNAME} "    "$(date)
#**********************************************************************
#   get flatrate file
#**********************************************************************
    export REMOTE_FILE="mitchell.flatrate.txt"
    export LOCAL_FILE=$DAT_DIR/${JOBNAME}_flatrate.dat

    get_sftp_file.pl $SFTP_PARM $REMOTE_FILE $LOCAL_FILE

    # Verify file copy successful and copied file contains data
    if [ ! -s ${LOCAL_FILE} ]
    then
       echo "\n*****************************************************************"
       echo "      ERROR: $LOCAL_FILE is empty or does not exist"
       echo "             File copied from: ${REMOTE_FILE}"
       echo "*****************************************************************\n"
       $( abndalrt.ksh 911 )
    fi


#STEP Step030R
    export STEPNAME=Step030R
    echo "    Start " ${STEPNAME} "    "$(date)
#**********************************************************************
#   get labor operations file
#**********************************************************************
    export REMOTE_FILE="mitchell.laborop.txt"  
    export LOCAL_FILE=$DAT_DIR/${JOBNAME}_laborop.dat

    get_sftp_file.pl $SFTP_PARM $REMOTE_FILE $LOCAL_FILE

    # Verify file copy successful and copied file contains data
    if [ ! -s ${LOCAL_FILE} ]
    then
       echo "\n*****************************************************************"
       echo "      ERROR: $LOCAL_FILE is empty or does not exist"
       echo "             File copied from: ${REMOTE_FILE}"
       echo "*****************************************************************\n"
       $( abndalrt.ksh 911 )
    fi


#STEP Step040R
    export STEPNAME=Step040R
    echo "    Start " ${STEPNAME} "    "$(date)
#**********************************************************************
#   get model file
#**********************************************************************
    export REMOTE_FILE="mitchell.model.txt"  
    export LOCAL_FILE=$DAT_DIR/${JOBNAME}_model.dat

    get_sftp_file.pl $SFTP_PARM $REMOTE_FILE $LOCAL_FILE

    # Verify file copy successful and copied file contains data
    if [ ! -s ${LOCAL_FILE} ]
    then
       echo "\n*****************************************************************"
       echo "      ERROR: $LOCAL_FILE is empty or does not exist"
       echo "             File copied from: ${REMOTE_FILE}"
       echo "*****************************************************************\n"
       $( abndalrt.ksh 911 )
    fi
	

#STEP Step050R
    export STEPNAME=Step050R
    echo "    Start " ${STEPNAME} "    "$(date)
#**********************************************************************
#   get section file
#**********************************************************************
    export REMOTE_FILE="mitchell.section.txt"  
    export LOCAL_FILE=$DAT_DIR/${JOBNAME}_section.dat

    get_sftp_file.pl $SFTP_PARM $REMOTE_FILE $LOCAL_FILE

    # Verify file copy successful and copied file contains data
    if [ ! -s ${LOCAL_FILE} ]
    then
       echo "\n*****************************************************************"
       echo "      ERROR: $LOCAL_FILE is empty or does not exist"
       echo "             File copied from: ${REMOTE_FILE}"
       echo "*****************************************************************\n"
       $( abndalrt.ksh 911 )
    fi

#STEP Step060R
    export STEPNAME=Step060R
    echo "    Start " ${STEPNAME} "    "$(date)
#**********************************************************************
#   get subsection file
#**********************************************************************
    export REMOTE_FILE="mitchell.subsect.txt"  
    export LOCAL_FILE=$DAT_DIR/${JOBNAME}_subsect.dat

    get_sftp_file.pl $SFTP_PARM $REMOTE_FILE $LOCAL_FILE

    # Verify file copy successful and copied file contains data
    if [ ! -s ${LOCAL_FILE} ]
    then
       echo "\n*****************************************************************"
       echo "      ERROR: $LOCAL_FILE is empty or does not exist"
       echo "             File copied from: ${REMOTE_FILE}"
       echo "*****************************************************************\n"
       $( abndalrt.ksh 911 )
    fi



#STEP Step070R
    export STEPNAME=Step070R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  RUN FILE THRU ASCII CLEANUP TO CHG TABS TO PIPE                  *
#********************************************************************
    export FILE_IN=$DAT_DIR/${JOBNAME}_flatrate.dat
    export FILE_OUT=$RACE/tmp/${JOBNAME}_flatrate.tmp
    export FILE_TMP=$RACE/tmp/${JOBNAME}_flatrate_clean.tmp

    ascii_cleanup.ksh ${FILE_IN} ${FILE_OUT} ${FILE_TMP}

    rm -f $FILE_TMP

#STEP Step080R
    export STEPNAME=Step080R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  RUN FILE THRU ASCII CLEANUP TO CHG TABS TO PIPE                  *
#********************************************************************
    export FILE_IN=$DAT_DIR/${JOBNAME}_laborop.dat
    export FILE_OUT=$RACE/tmp/${JOBNAME}_laborop.tmp
    export FILE_TMP=$RACE/tmp/${JOBNAME}laborop_clean.tmp

    ascii_cleanup.ksh ${FILE_IN} ${FILE_OUT} ${FILE_TMP}

    rm -f $FILE_TMP


#STEP Step090R
    export STEPNAME=Step090R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  RUN FILE THRU ASCII CLEANUP TO CHG TABS TO PIPE                  *
#********************************************************************
    export FILE_IN=$DAT_DIR/${JOBNAME}_model.dat
    export FILE_OUT=$RACE/tmp/${JOBNAME}_model.tmp
    export FILE_TMP=$RACE/tmp/${JOBNAME}model_clean.tmp

    ascii_cleanup.ksh ${FILE_IN} ${FILE_OUT} ${FILE_TMP}

    rm -f $FILE_TMP


#STEP Step100R
    export STEPNAME=Step100R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  RUN FILE THRU ASCII CLEANUP TO CHG TABS TO PIPE                  *
#********************************************************************
    export FILE_IN=$DAT_DIR/${JOBNAME}_section.dat
    export FILE_OUT=$RACE/tmp/${JOBNAME}_section.tmp
    export FILE_TMP=$RACE/tmp/${JOBNAME}section_clean.tmp

    ascii_cleanup.ksh ${FILE_IN} ${FILE_OUT} ${FILE_TMP}

    rm -f $FILE_TMP


#STEP Step110R
    export STEPNAME=Step110R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  RUN FILE THRU ASCII CLEANUP TO CHG TABS TO PIPE                  *
#********************************************************************

    export FILE_IN=$DAT_DIR/${JOBNAME}_subsect.dat
    export FILE_OUT=$RACE/tmp/${JOBNAME}_subsect.tmp
    export FILE_TMP=$RACE/tmp/${JOBNAME}_subsect_clean.tmp

    ascii_cleanup.ksh ${FILE_IN} ${FILE_OUT} ${FILE_TMP}

    rm -f $FILE_TMP

#STEP Step115R
    export STEPNAME=Step115R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  EXECUTE PROCEDURE TO TRUNCATE WARR_HONDA tables                      *
#********************************************************************

sqlplus << % 2>&1 > $LOG
$MPTUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec pkg_warr_honda.p_truncate_warr_honda_tables;

QUIT;
%

#**********************************************************************
#   Load data to Oracle Tables
#**********************************************************************

#STEP Step120R
    export STEPNAME=Step120R
    echo "    Start " ${STEPNAME} "    "$(date)
#**********************************************************************
#   Load Flatrate file to Oracle Staging Table                         
#**********************************************************************
     
    export SQL_CTL=$RACE/prm/lbr020_flatrate.ctl
    export SQL_LOG=$RACE/tmp/${JOBNAME}_flatrate_log.tmp
    export SQL_IN=$RACE/tmp/${JOBNAME}_flatrate.tmp
    export SQL_BAD=$DAT_DIR/${JOBNAME}_flatrate.bad
    export SQL_DSC=$RACE/tmp/${JOBNAME}_flatrate.dsc

    sqlldr userid=$MPTUSERID control=$SQL_CTL log=$SQL_LOG

    cat $SQL_LOG


#STEP Step130R
    export STEPNAME=Step130R
    echo "    Start " ${STEPNAME} "    "$(date)
#**********************************************************************
#   Load Labor Ops file to Oracle Staging Table                        
#**********************************************************************

    export SQL_CTL=$RACE/prm/lbr020_laborop.ctl
    export SQL_LOG=$RACE/tmp/${JOBNAME}_laborop_log.tmp
    export SQL_IN=$RACE/tmp/${JOBNAME}_laborop.tmp
    export SQL_BAD=$DAT_DIR/${JOBNAME}_laborop.bad
    export SQL_DSC=$RACE/tmp/${JOBNAME}_laborop.dsc

    sqlldr userid=$MPTUSERID control=$SQL_CTL log=$SQL_LOG

    cat $SQL_LOG

#STEP Step140R
    export STEPNAME=Step140R
    echo "    Start " ${STEPNAME} "    "$(date)
#**********************************************************************
#   Load Model file to Oracle Staging Table                            
#**********************************************************************

    export SQL_CTL=$RACE/prm/lbr020_model.ctl
    export SQL_LOG=$RACE/tmp/${JOBNAME}_model_log.tmp
    export SQL_IN=$RACE/tmp/${JOBNAME}_model.tmp
    export SQL_BAD=$DAT_DIR/${JOBNAME}_model.bad
    export SQL_DSC=$RACE/tmp/${JOBNAME}_model.dsc

    sqlldr userid=$MPTUSERID control=$SQL_CTL log=$SQL_LOG

    cat $SQL_LOG

#STEP Step150R
    export STEPNAME=Step150R
    echo "    Start " ${STEPNAME} "    "$(date)
#**********************************************************************
#   Load Section file to Oracle Staging Table                         
#**********************************************************************

    export SQL_CTL=$RACE/prm/lbr020_section.ctl
    export SQL_LOG=$RACE/tmp/${JOBNAME}_section_log.tmp
    export SQL_IN=$RACE/tmp/${JOBNAME}_section.tmp
    export SQL_BAD=$DAT_DIR/${JOBNAME}_section.bad
    export SQL_DSC=$RACE/tmp/${JOBNAME}_section.dsc

    sqlldr userid=$MPTUSERID control=$SQL_CTL log=$SQL_LOG

    cat $SQL_LOG

#STEP Step160R
    export STEPNAME=Step160R
    echo "    Start " ${STEPNAME} "    "$(date)
#**********************************************************************
#   Load Sub Section file to Oracle Staging Table                         
#**********************************************************************

    export SQL_CTL=$RACE/prm/lbr020_subsect.ctl
    export SQL_LOG=$RACE/tmp/${JOBNAME}_subsect_log.tmp
    export SQL_IN=$RACE/tmp/${JOBNAME}_subsect.tmp
    export SQL_BAD=$DAT_DIR/${JOBNAME}_subsect.bad
    export SQL_DSC=$RACE/tmp/${JOBNAME}_subsect.dsc

    sqlldr userid=$MPTUSERID control=$SQL_CTL log=$SQL_LOG

    cat $SQL_LOG

#STEP Step170R
    export STEPNAME=Step170R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  EXECUTE PROCEDURE TO UPDATE WARR_HONDA tables                      *
#********************************************************************

sqlplus << % 2>&1 > $LOG
$MPTUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec pkg_warr_honda.p_load_warr_upd('$RPT_PATH','$RPT_NAME1','$SQL_JOBNAME','$SQL_LOG_PATH','$SQL_LOGFILE');

QUIT;
%

#STEP Step180R
    export STEPNAME=Step180R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  EXECUTE PROCEDURE TO UPDATE WARR_MODEL_CONFIG table                      *
#********************************************************************

sqlplus << % 2>&1 > $LOG
$MPTUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec pkg_warr_honda.p_model_config_upd('$RPT_PATH','$RPT_NAME2','$SQL_JOBNAME','$SQL_LOG_PATH','$SQL_LOGFILE');

QUIT;
%


#STEP Step190R
    export STEPNAME=Step190R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  EXECUTE PROCEDURE TO UPDATE WARR_LABOR_OPERATION table                      *
#********************************************************************

sqlplus << % 2>&1 > $LOG
$MPTUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec pkg_warr_honda.p_labor_operation_upd('$RPT_PATH','$RPT_NAME3','$SQL_JOBNAME','$SQL_LOG_PATH','$SQL_LOGFILE');

QUIT;
%

#STEP Step200R
    export STEPNAME=Step200R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  EXECUTE PROCEDURE TO UPDATE WARR_LABOR_TIME table                      *
#********************************************************************

sqlplus << % 2>&1 > $LOG
$MPTUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec pkg_warr_honda.p_labor_time_upd('$RPT_PATH','$RPT_NAME4','$SQL_JOBNAME','$SQL_LOG_PATH','$SQL_LOGFILE');

QUIT;
%

#STEP Step205R
    export STEPNAME=Step205R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  EXECUTE PROCEDURE TO:                                            *
#  1. UPDATE WARR_OEM TABLE (LAST_PROCESSED_DATE)                   *
#********************************************************************
sqlplus << % 2>&1 > $LOG
$MPTUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec pkg_warr_honda.p_log_oem_update;

QUIT;
%

#STEP Step210R
    export STEPNAME=Step210R
    echo "    Start " ${STEPNAME} "    "$(date)
#**********************************************************************
#   Zip All Warranty Data Files 
#**********************************************************************


   rm -f $ZIPDATFILES

   #zip the comma delimited text file: -j = don't retain direcotry structure; 
   #                                   -l = translate UNIX LF to DOS CR/LF; 
   #zipped file can be opened on DOS by WINZIP or PKZIP

   zip -jl $ZIPDATFILES $MFILE1 $MFILE2 $MFILE3 $MFILE4 $MFILE5

   rm $MFILE1 $MFILE2 $MFILE3 $MFILE4 $MFILE5

#STEP Step220R
    export STEPNAME=Step220R
    echo "    Start " ${STEPNAME} "    "$(date)
#**********************************************************************
#   Retain 3 Copies of the Zip File
#**********************************************************************
   
   export GDGFILE=$( setgdg.ksh "$ZIPDATFILES(+01)" NEW 3 )
   mv $ZIPDATFILES $GDGFILE

#STEP Step230R
    export STEPNAME=Step230R
    echo "    Start " ${STEPNAME} "    "$(date)
#**********************************************************************
#   Retain 3 Copies of the Report Files
#**********************************************************************
   
   export GDGFILE=$( setgdg.ksh "$RPT_NAME1(+01)" NEW 3 )
   mv $RPT_NAME1 $GDGFILE

   export GDGFILE=$( setgdg.ksh "$RPT_NAME2(+01)" NEW 3 )
   mv $RPT_NAME2 $GDGFILE

   export GDGFILE=$( setgdg.ksh "$RPT_NAME3(+01)" NEW 3 )
   mv $RPT_NAME3 $GDGFILE

   export GDGFILE=$( setgdg.ksh "$RPT_NAME4(+01)" NEW 3 )
   mv $RPT_NAME4 $GDGFILE

#STEP Step900R
    export STEPNAME=Step900R
    echo "    Start " ${STEPNAME} "    "$(date)
#***************************************************************************
# Program: UNIX mailx                                                      *
#   Send email notification to Prod Cntl, users, and DBA that files are    *
#   loaded to RACE.                                                        *
#***************************************************************************
    export MAIL_PARM=$RACE/prm/zlbr_warr_email_recips.prm
    export MAIL_TEXT=$RACE/tmp/${JOBNAME}_email_text.tmp

    # get email addresses from parm file (must be on one line, separated by !)
    MAIL_RECIP="$(head -n +1 $MAIL_PARM | awk '{print}')"

    # create text message for mail
    echo "RACE tables have been loaded with latest Honda Warranty Data" > $MAIL_TEXT

    # send email notifications
    #echo $FTP_TEXT | mailx -s "MAPP ODD Extract - PRODUCTION"  ${RECIP}

  if [ ${ACT_LVL} = prod ]
  then
    mailx -s "PROD - Honda Warranty Update Notification" $MAIL_RECIP < $MAIL_TEXT
  else
    mailx -s "TEST - Honda Warranty Update Notification" $MAIL_RECIP < $MAIL_TEXT
  fi 


#STEP Step991R
    export STEPNAME=Step991R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#   Delete flatrate file on Honda's sftp server                     *
#********************************************************************
    export REMOTE_FILE="mitchell.flatrate.txt"

    delete_sftp_file.pl $SFTP_PARM $REMOTE_FILE 


#STEP Step992R
    export STEPNAME=Step992R
    echo "    Start " ${STEPNAME} "    "$(date)
#**********************************************************************
#   Delete labor operations file on Honda's sftp server               *
#**********************************************************************
    export REMOTE_FILE="mitchell.laborop.txt"  
 
    delete_sftp_file.pl $SFTP_PARM $REMOTE_FILE 

 
#STEP Step993R
    export STEPNAME=Step993R
    echo "    Start " ${STEPNAME} "    "$(date)
#**********************************************************************
#   Delete model file  on Honda's sftp server                         *
#**********************************************************************
    export REMOTE_FILE="mitchell.model.txt"  
   
    delete_sftp_file.pl $SFTP_PARM $REMOTE_FILE 

	

#STEP Step994R
    export STEPNAME=Step994R
    echo "    Start " ${STEPNAME} "    "$(date)
#**********************************************************************
#   Delete section file  on Honda's sftp server                       *
#**********************************************************************
    export REMOTE_FILE="mitchell.section.txt"  
 
    delete_sftp_file.pl $SFTP_PARM $REMOTE_FILE 


#STEP Step995R
    export STEPNAME=Step995R
    echo "    Start " ${STEPNAME} "    "$(date)
#**********************************************************************
#   Delete subsection file  on Honda's sftp server                    *
#**********************************************************************
    export REMOTE_FILE="mitchell.subsect.txt"  
    
    delete_sftp_file.pl $SFTP_PARM $REMOTE_FILE 


#STEP Step999R
    export STEPNAME=Step999R
    echo "    Start " ${STEPNAME} "    "$(date)
#**********************************************************************
# Program: Delete temp files                                          *
#**********************************************************************
   rm -f $RACE/tmp/${JOBNAME}*
    
#########################################################################
#  END                                                                  #
#########################################################################
