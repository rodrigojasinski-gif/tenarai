#!/bin/ksh
echo "$Id: lbr010.ksh,v 1.2 2023/12/08 20:50:59 pg2697 Exp $"
############################################################################
#  PROCNAME:  lbr010                                                       #
#  PROC DESCRIPTION: LOAD US AUDI AND VW LABOR WARRANTY DATA               #
############################################################################
set -xv
export PROCNAME=$(basename $0 .ksh_run)
trap 'abndalrt.ksh $?' err
  
export SQL_RPT_PATH=$OBJ_RPTDIR
export SQL_DAT_PATH=$OBJ_TMPDIR
export SQL_LOG_PATH=$OBJ_LOGDIR
export SQL_LOG_FILE=${JOBLOGNAME}
export MPTUSERID=`cat $RACE/prm/zmptpass.prm`

export TEMPDIR=$RACE/tmp

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
#   Execute GetSftpFile.pl to get VW US zip file from their server
#**********************************************************************
    export SFTP_PARM=$RACE/prm/${JOBNAME}_ftp_vw_us.prm
	export REMOTE_FILE="APOS_DataExtract.zip"
    export LOCAL_FILE=$RACE/tmp/${JOBNAME}_vw_us_warranty.zip

    rm -f LOCAL_FILE
	
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
#*******************************************************************************
# Program: unzip                                                               *
#                                                                              * 
#   1) UNZIP FILE 1: sales models                                              *
#   2) ABORT JOB IF PROBLEM W/ UNZIPPED FILE                                   *
#   3) RENAME UNZIPPED FILE TO MITCHELL NAME                                   *
#                                                                              * 
# Usage: unzip [-Z] [-opts[modifiers]] file[.zip] [list] [-x xlist] [-d exdir] *
#    -j  => junk paths (do not make directories)                               *
#    -o  => overwrite files WITHOUT prompting                                  *
#    -u  => update files, create if necessary                                  *
#    -C  => match filenames case-insensitively                                 *
#    -LL => make all names lowercase                                           *
#    -d  => extract files into exdir                                           *
#                                                                              * 
# NOTE: file is NOT used. It contains more models than what is referenced in   *
#       labor file. Don't want to insert models for which there's no labor!    * 
#*******************************************************************************

    export ZIPFILE=$RACE/tmp/${JOBNAME}_vw_us_warranty.zip
    export OEMFILE1=smd_sale_mdl_extract.txt  
    export RAWFILE1=${JOBNAME}_vw_us_smd_sales_models.dat

    unzip -jouCLL $ZIPFILE $OEMFILE1 -d $TEMPDIR
     
    mv $TEMPDIR/$OEMFILE1 $TEMPDIR/$RAWFILE1

    reccnt1=$(wc -c $TEMPDIR/$RAWFILE1 | awk ' {print $1}' )

    if [ reccnt1 -eq 0 ]
        then echo " unzipped input file is no good "
             $( abndalrt.ksh 911 )
        else
             echo "unzipped file is good"
    fi


#STEP Step040R
    export STEPNAME=Step040R
    echo "    Start " ${STEPNAME} "    "$(date)
#*******************************************************************************
# Program: unzip                                                               *
#                                                                              * 
#   1) UNZIP FILE 2: part groups                                               *
#   2) ABORT JOB IF PROBLEM W/ UNZIPPED FILE                                   *
#   3) RENAME UNZIPPED FILE TO MITCHELL NAME                                   *
#                                                                              * 
# Usage: unzip [-Z] [-opts[modifiers]] file[.zip] [list] [-x xlist] [-d exdir] *
#    -j  => junk paths (do not make directories)                               *
#    -o  => overwrite files WITHOUT prompting                                  *
#    -u  => update files, create if necessary                                  *
#    -C  => match filenames case-insensitively                                 *
#    -LL => make all names lowercase                                           *
#    -d  => extract files into exdir                                           *
#*******************************************************************************

    export ZIPFILE=$RACE/tmp/${JOBNAME}_vw_us_warranty.zip
    export OEMFILE2=pid_descr.out
    export RAWFILE2=${JOBNAME}_vw_us_pid_part_groups.dat

    unzip -jouCLL $ZIPFILE $OEMFILE2 -d $TEMPDIR
     
    mv $TEMPDIR/$OEMFILE2 $TEMPDIR/$RAWFILE2

    reccnt1=$(wc -c $TEMPDIR/$RAWFILE2 | awk ' {print $1}' )

    if [ reccnt1 -eq 0 ]
        then echo " unzipped input file is no good "
             $( abndalrt.ksh 911 )
        else
             echo "unzipped file is good"
    fi


#STEP Step050R
    export STEPNAME=Step050R
    echo "    Start " ${STEPNAME} "    "$(date)
#*******************************************************************************
# Program: unzip                                                               *
#                                                                              * 
#   1) UNZIP FILE 3: lo2 - labor                                               *
#   2) ABORT JOB IF PROBLEM W/ UNZIPPED FILE                                   *
#   3) RENAME UNZIPPED FILE TO MITCHELL NAME                                   *
#                                                                              * 
# Usage: unzip [-Z] [-opts[modifiers]] file[.zip] [list] [-x xlist] [-d exdir] *
#    -j  => junk paths (do not make directories)                               *
#    -o  => overwrite files WITHOUT prompting                                  *
#    -u  => update files, create if necessary                                  *
#    -C  => match filenames case-insensitively                                 *
#    -LL => make all names lowercase                                           *
#    -d  => extract files into exdir                                           *
#*******************************************************************************

    export ZIPFILE=$RACE/tmp/${JOBNAME}_vw_us_warranty.zip
    export OEMFILE3=showlaboroperations_lo2_1.xml
    export RAWFILE3=${JOBNAME}_vw_us_lo2_labor_op_xml.dat

    unzip -jouCLL $ZIPFILE $OEMFILE3 -d $TEMPDIR
     
    mv $TEMPDIR/$OEMFILE3 $TEMPDIR/$RAWFILE3

    reccnt1=$(wc -c $TEMPDIR/$RAWFILE3 | awk ' {print $1}' )

    if [ reccnt1 -eq 0 ]
        then echo " unzipped input file is no good "
             $( abndalrt.ksh 911 )
        else
             echo "unzipped file is good"
    fi

#STEP Step060R
    export STEPNAME=Step060R
    echo "    Start " ${STEPNAME} "    "$(date)
#*******************************************************************************
# Program: unzip                                                               *
#                                                                              * 
#   1) UNZIP FILE 4: pid2 - parts information                                  *
#   2) ABORT JOB IF PROBLEM W/ UNZIPPED FILE                                   *
#   3) RENAME UNZIPPED FILE TO MITCHELL NAME                                   *
#                                                                              * 
# Usage: unzip [-Z] [-opts[modifiers]] file[.zip] [list] [-x xlist] [-d exdir] *
#    -j  => junk paths (do not make directories)                               *
#    -o  => overwrite files WITHOUT prompting                                  *
#    -u  => update files, create if necessary                                  *
#    -C  => match filenames case-insensitively                                 *
#    -LL => make all names lowercase                                           *
#    -d  => extract files into exdir                                           *
#*******************************************************************************

    export ZIPFILE=$RACE/tmp/${JOBNAME}_vw_us_warranty.zip
    export OEMFILE4=showlaboroperations_pid2_1.xml
    export RAWFILE4=${JOBNAME}_vw_us_pid_part_xml.dat

    unzip -jouCLL $ZIPFILE $OEMFILE4 -d $TEMPDIR
     
    mv $TEMPDIR/$OEMFILE4 $TEMPDIR/$RAWFILE4

    reccnt1=$(wc -c $TEMPDIR/$RAWFILE4 | awk ' {print $1}' )

    if [ reccnt1 -eq 0 ]
        then echo " unzipped input file is no good "
             $( abndalrt.ksh 911 )
        else
             echo "unzipped file is good"
    fi


# FILE 1 ############################################################
#
# NOTE: steps were removed. It was discovered that the Sales Model 
#       file contained more models than what was in Labor file (and 
#       there were some configs in labor file which weren't in the 
#       sales model file). So more reliable to insert models and 
#       configs during the Labor file processing
#********************************************************************

# FILE 2 ############################################################

#STEP Step200R
    export STEPNAME=Step200R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  EXECUTE PROCEDURE TO:                                            *
#  1. PARSE PID PART GROUP FILE                                     *
#  2. Insert/Update to WARR_GROUP                                   * 
#********************************************************************
export SQL_DAT_FILE=${JOBNAME}_vw_us_pid_part_groups.dat 
export SQL_RPT_NAME=${JOBNAME}_load_warr_group_summary.rpt

sqlplus << % 2>&1 > $LOG
$MPTUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec PKG_WARR_VW.P_LOAD_WARR_GROUP('$SQL_DAT_PATH','$SQL_DAT_FILE', '$SQL_RPT_PATH','$SQL_RPT_NAME','$SQL_LOG_PATH','$SQL_LOG_FILE');

QUIT;
%


# FILE 3 ############################################################

#STEP Step300R
    export STEPNAME=Step300R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  EXECUTE PROCEDURE TO:                                            *
#  1. PARSE LO2 XML FILE                                            *
#  2. Insert/Update/Delete:                                         * 
#     - WARR_LABOR_OPERATION                                        *
#     - WARR_LABOR_TIME                                             *
#     - WARR_RELATED_LABOR                                          *
#     - WARR_LABOR_RELATIONSHIP                                     *
#     - WARR_RELATED_QUALIFIER                                      *
#     - WARR_LABOR_QUALIFER                                         *
#  3. Add model configs to WARR_MODEL_CONFIG (where not found)      *
#********************************************************************
export SQL_XML_FILEIN=${JOBNAME}_vw_us_lo2_labor_op_xml.dat
export SQL_RPT_NAME=${JOBNAME}_load_warr_labor_summary.rpt

reccnt=$(wc -l ${RACE}/tmp/${SQL_XML_FILEIN} | awk ' {print $1}' )
echo "Number of records in Labor Operations file to be processed: = $reccnt" 

sqlplus << % 2>&1 > $LOG
$MPTUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec PKG_WARR_VW.P_LOAD_WARR_LABOR_TABLES('$SQL_DAT_PATH','$SQL_XML_FILEIN', '$SQL_RPT_PATH','$SQL_RPT_NAME','$SQL_LOG_PATH','$SQL_LOG_FILE');

QUIT;
%

# FILE 4 ############################################################

#STEP Step400R
    export STEPNAME=Step400R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  EXECUTE PROCEDURE TO:                                            *
#  1. PARSE PID XML FILE                                            *
#  2. LOAD WARR_PART TABLE                                          *
#********************************************************************
export SQL_XML_FILEIN=${JOBNAME}_vw_us_pid_part_xml.dat
export SQL_RPT_NAME=${JOBNAME}_load_warr_part_summary.rpt

reccnt=$(wc -l ${RACE}/tmp/${SQL_XML_FILEIN} | awk ' {print $1}' )
echo "Number of records in Part ID file to be processed: = $reccnt" 

sqlplus << % 2>&1 > $LOG
$MPTUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec PKG_WARR_VW.P_LOAD_WARR_PART_TABLES('$SQL_DAT_PATH','$SQL_XML_FILEIN','$SQL_RPT_PATH','$SQL_RPT_NAME','$SQL_LOG_PATH','$SQL_LOG_FILE');

QUIT;
%


#STEP Step700R
    export STEPNAME=Step700R
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

exec PKG_WARR_VW.p_log_oem_update;

QUIT;
%


#STEP Step800R
    export STEPNAME=Step800R
    echo "    Start " ${STEPNAME} "    "$(date)
#***************************************************************************
# Program: UNIX move                                                       *
#   Rename data and report files to gdg's for backup/review purposes       *
#   Since files are so large, only the zip file is saved as a GDG.         *
#   ---------------------------------------------------------------------  *
#   Should you want to see files within zip file, this command will unzip  *
#   them into the tmp directory. (Change where necessary.)                 *
#   ---------------------------------------------------------------------  *
#   unzip  /mdev/race/oem/dat/lbrr010_vw_us_warranty.zip.g03 -d /mdev/race/oem/tmp
#   ---------------------------------------------------------------------  *
#***************************************************************************
export ZIP_FILE=$RACE/tmp/${JOBNAME}_vw_us_warranty.zip
export ZIP_GDG=$(setgdg.ksh "$RACE/dat/${JOBNAME}_vw_us_warranty.zip(+1)" NEW 3)

export RPT1=${RACE}/rpt/${JOBNAME}_load_warr_group_summary.rpt
export RPT1_GDG=$(setgdg.ksh "$RACE/rpt/${JOBNAME}_load_warr_group_summary.rpt(+1)" NEW 3)

export RPT2=${RACE}/rpt/${JOBNAME}_load_warr_labor_summary.rpt
export RPT2_GDG=$(setgdg.ksh "$RACE/rpt/${JOBNAME}_load_warr_labor_summary.rpt(+1)" NEW 3)

export RPT3=${RACE}/rpt/${JOBNAME}_load_warr_part_summary.rpt
export RPT3_GDG=$(setgdg.ksh "$RACE/rpt/${JOBNAME}_load_warr_part_summary.rpt(+1)" NEW 3)

cp -p $ZIP_FILE $ZIP_GDG  
rm -f $ZIP_FILE 

cp -p $RPT1 $RPT1_GDG  
rm -f $RPT1 

cp -p $RPT2 $RPT2_GDG
rm -f $RPT2 

cp -p $RPT3 $RPT3_GDG
rm -f $RPT3 

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
    echo "RACE tables have been loaded with latest VW and Audi Warranty Data" > $MAIL_TEXT

    # send email notification
    
    if [ ${ACT_LVL} = prod ]
    then
      mailx -s "PROD - VW Warranty Update Notification" $MAIL_RECIP < $MAIL_TEXT
    else
      mailx -s "TEST - VW Warranty Update Notification" $MAIL_RECIP < $MAIL_TEXT
    fi 


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
