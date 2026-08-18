#!/bin/ksh
echo "$Id: lbr030.ksh,v 1.8 2017/04/03 21:12:02 pb0690 Exp $"
############################################################################
#  PROCNAME:  lbr030                                                       #
#  PROC DESCRIPTION: LOAD US GM LABOR WARRANTY DATA                        #
#  2016/08 PAG - use lowercsae "_us"; rather than uppercase that is used   #
#                in actual filename. Otherwise, unzip changes tmp file to  #
#                all lowercase and wc -c checks later on will fail on FILE #
#                NOT FOUND causing abend further down in loads.            #
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
export ZIPFILE=$RACE/dat/${JOBNAME}_gmc_us_warranty.zip
export OEMFILE1=addtime.dat
export OEMFILE2=basenote.dat
export OEMFILE3=basetime.dat
export OEMFILE4=laborop_en_us.dat    
export OEMFILE5=mktgdiv.dat
export OEMFILE6=pubpsdvh.dat
export OEMFILE7=pubsection_en_us.dat
export OEMFILE8=pubsubsection_en_us.dat
export OEMFILE9=vehicle.dat
export RPT_NAME1=$RACE/rpt/${JOBNAME}_load_warr_upd_summary.rpt
export RPT_NAME2=$RACE/rpt/${JOBNAME}_model_config_upd_summary.rpt
export RPT_NAME3=$RACE/rpt/${JOBNAME}_labor_operation_upd_summary.rpt
export RPT_NAME4=$RACE/rpt/${JOBNAME}_labor_time_upd_summary.rpt
export RPT_NAME5=$RACE/rpt/${JOBNAME}_related_labor_upd_summary.rpt
export RPT_NAME6=$RACE/rpt/${JOBNAME}_related_qualifier_upd_summary.rpt

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
#**************************************************************************
# Program: fileget                                                        *
# File: Tablefull.zip (renamed to gmc_us_warranty.zip by ProdCtrl)        *
# 1. Pull NT stored file to UNIX                                          *
# 2. Check directory counts to validate transfer                          *
#**************************************************************************

    export DD_NTFILE=gmc_us_warranty.zip
    export DD_UNIXFILE=$RACE/dat/${JOBNAME}_gmc_us_warranty.zip
    export DD_NTDIR=${NOVELL}oem
    export DD_FTPOUT=$RACE/tmp/${JOBNAME}_gmc_us_warr_workdata.tmp

    rm -f $DD_UNIXFILE $DD_FTPOUT

    fileget.exp $DD_NTFILE $DD_UNIXFILE $DD_NTDIR | tee $DD_FTPOUT

# check for empty UNIX data file
    if [ ! -s $DD_UNIXFILE ]
    then
        echo "UNIX file was empty when created !!\a"
        abndalrt.ksh ftp_null_file
    fi

    ntcount="$(grep 'Information returned by' $DD_FTPOUT | awk '{print $1}')"
    unixcount="$(wc -c $DD_UNIXFILE | awk '{print $1}')"

    if [ $ntcount -eq $unixcount ]
    then
        echo " ftp of file $DD_NTFILE succeeded, byte count = $ntcount "
    else
        echo " ***** error ***** ftp directory counts do not match "
        echo " NOVELL byte count = $ntcount "
        echo "   UNIX byte count = $unixcount "
        abndalrt.ksh ftp_get
    fi


#STEP Step030R
    export STEPNAME=Step030R
    echo "    Start " ${STEPNAME} "    "$(date)
#*******************************************************************************
# Program: unzip                                                               *
#                                                                              * 
#   1) UNZIP FILE 1: lbrr030_gmc_us_warranty.zip                               *
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

    unzip -jouCLL $ZIPFILE $OEMFILE1 $OEMFILE2 $OEMFILE3 $OEMFILE4 $OEMFILE5 $OEMFILE6 $OEMFILE7 $OEMFILE8 $OEMFILE9 -d $RACE/tmp

    reccnt1=$(wc -c $RACE/tmp/$OEMFILE1 | awk ' {print $1}' )

    if [ reccnt1 -eq 0 ]
        then echo " unzipped input file is no good "
             $( abndalrt.ksh 911 )
        else
             echo "unzipped file is good"
             mv $RACE/tmp/$OEMFILE1 $RACE/tmp/${JOBNAME}_$OEMFILE1
    fi

    reccnt2=$(wc -c $RACE/tmp/$OEMFILE2 | awk ' {print $1}' )

    if [ reccnt2 -eq 0 ]
        then echo " unzipped input file is no good "
             $( abndalrt.ksh 911 )
        else
             echo "unzipped file is good"
             mv $RACE/tmp/$OEMFILE2 $RACE/tmp/${JOBNAME}_$OEMFILE2
    fi

    reccnt3=$(wc -c $RACE/tmp/$OEMFILE3 | awk ' {print $1}' )

    if [ reccnt3 -eq 0 ]
        then echo " unzipped input file is no good "
             $( abndalrt.ksh 911 )
        else
             echo "unzipped file is good"
             mv $RACE/tmp/$OEMFILE3 $RACE/tmp/${JOBNAME}_$OEMFILE3
    fi

    reccnt4=$(wc -c $RACE/tmp/$OEMFILE4 | awk ' {print $1}' )

    if [ reccnt4 -eq 0 ]
        then echo " unzipped input file is no good "
             $( abndalrt.ksh 911 )
        else
             echo "unzipped file is good"
             mv $RACE/tmp/$OEMFILE4 $RACE/tmp/${JOBNAME}_$OEMFILE4
    fi

    reccnt5=$(wc -c $RACE/tmp/$OEMFILE5 | awk ' {print $1}' )

    if [ reccnt5 -eq 0 ]
        then echo " unzipped input file is no good "
             $( abndalrt.ksh 911 )
        else
             echo "unzipped file is good"
             mv $RACE/tmp/$OEMFILE5 $RACE/tmp/${JOBNAME}_$OEMFILE5
    fi

    reccnt6=$(wc -c $RACE/tmp/$OEMFILE6 | awk ' {print $1}' )

    if [ reccnt6 -eq 0 ]
        then echo " unzipped input file is no good "
             $( abndalrt.ksh 911 )
        else
             echo "unzipped file is good"
             mv $RACE/tmp/$OEMFILE6 $RACE/tmp/${JOBNAME}_$OEMFILE6
    fi

    reccnt7=$(wc -c $RACE/tmp/$OEMFILE7 | awk ' {print $1}' )

    if [ reccnt7 -eq 0 ]
        then echo " unzipped input file is no good "
             $( abndalrt.ksh 911 )
        else
             echo "unzipped file is good"
             mv $RACE/tmp/$OEMFILE7 $RACE/tmp/${JOBNAME}_$OEMFILE7
    fi

    reccnt8=$(wc -c $RACE/tmp/$OEMFILE8 | awk ' {print $1}' )

    if [ reccnt8 -eq 0 ]
        then echo " unzipped input file is no good "
             $( abndalrt.ksh 911 )
        else
             echo "unzipped file is good"
             mv $RACE/tmp/$OEMFILE8 $RACE/tmp/${JOBNAME}_$OEMFILE8
    fi

    reccnt9=$(wc -c $RACE/tmp/$OEMFILE9 | awk ' {print $1}' )

    if [ reccnt9 -eq 0 ]
        then echo " unzipped input file is no good "
             $( abndalrt.ksh 911 )
        else
             echo "unzipped file is good"
             mv $RACE/tmp/$OEMFILE9 $RACE/tmp/${JOBNAME}_$OEMFILE9
    fi


#STEP Step040R
    export STEPNAME=Step040R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  RUN FILE THRU ASCII CLEANUP TO CHG TABS TO PIPE                  *
#********************************************************************
    export FILE_IN=$RACE/tmp/${JOBNAME}_$OEMFILE1
    export FILE_OUT=$RACE/tmp/${JOBNAME}_us_gm_addtime_clean.dat
    export FILE_TMP=$RACE/tmp/${JOBNAME}_us_gm_addtime_clean.tmp

    ascii_cleanup.ksh ${FILE_IN} ${FILE_OUT} ${FILE_TMP}

    rm -f $FILE_TMP

#STEP Step050R
    export STEPNAME=Step050R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  RUN FILE THRU ASCII CLEANUP TO CHG TABS TO PIPE                  *
#********************************************************************
    export FILE_IN=$RACE/tmp/${JOBNAME}_$OEMFILE2
    export FILE_OUT=$RACE/tmp/${JOBNAME}_us_gm_basenote_clean.dat
    export FILE_TMP=$RACE/tmp/${JOBNAME}_us_gm_basenote_clean.tmp

    ascii_cleanup.ksh ${FILE_IN} ${FILE_OUT} ${FILE_TMP}

    rm -f $FILE_TMP

#STEP Step060R
    export STEPNAME=Step060R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  RUN FILE THRU ASCII CLEANUP TO CHG TABS TO PIPE                  *
#********************************************************************
    export FILE_IN=$RACE/tmp/${JOBNAME}_$OEMFILE3
    export FILE_OUT=$RACE/tmp/${JOBNAME}_us_gm_basetime_clean.dat
    export FILE_TMP=$RACE/tmp/${JOBNAME}_us_gm_basetime_clean.tmp

    ascii_cleanup.ksh ${FILE_IN} ${FILE_OUT} ${FILE_TMP}

    rm -f $FILE_TMP

#STEP Step070R
    export STEPNAME=Step070R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  RUN FILE THRU ASCII CLEANUP TO CHG TABS TO PIPE                  *
#********************************************************************
    export FILE_IN=$RACE/tmp/${JOBNAME}_$OEMFILE4
    export FILE_OUT=$RACE/tmp/${JOBNAME}_us_gm_laborop_en_clean.dat
    export FILE_TMP=$RACE/tmp/${JOBNAME}_us_gm_laborop_en_clean.tmp

    ascii_cleanup.ksh ${FILE_IN} ${FILE_OUT} ${FILE_TMP}

    rm -f $FILE_TMP


#STEP Step080R
    export STEPNAME=Step080R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  RUN FILE THRU ASCII CLEANUP TO CHG TABS TO PIPE                  *
#********************************************************************
    export FILE_IN=$RACE/tmp/${JOBNAME}_$OEMFILE5
    export FILE_OUT=$RACE/tmp/${JOBNAME}_us_gm_mktgdiv_clean.dat
    export FILE_TMP=$RACE/tmp/${JOBNAME}_us_gm_mktgdiv_clean.tmp

    ascii_cleanup.ksh ${FILE_IN} ${FILE_OUT} ${FILE_TMP}

    rm -f $FILE_TMP


#STEP Step090R
    export STEPNAME=Step090R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  RUN FILE THRU ASCII CLEANUP TO CHG TABS TO PIPE                  *
#********************************************************************

    export FILE_IN=$RACE/tmp/${JOBNAME}_$OEMFILE6
    export FILE_OUT=$RACE/tmp/${JOBNAME}_us_gm_pubpsdvh_clean.dat
    export FILE_TMP=$RACE/tmp/${JOBNAME}_us_gm_pubpsdvh_clean.tmp

    ascii_cleanup.ksh ${FILE_IN} ${FILE_OUT} ${FILE_TMP}

    rm -f $FILE_TMP

#STEP Step100R
    export STEPNAME=Step100R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  RUN FILE THRU ASCII CLEANUP TO CHG TABS TO PIPE                  *
#********************************************************************

    export FILE_IN=$RACE/tmp/${JOBNAME}_$OEMFILE7
    export FILE_OUT=$RACE/tmp/${JOBNAME}_us_gm_pubsection_en_clean.dat
    export FILE_TMP=$RACE/tmp/${JOBNAME}_us_gm_pubsection_en_clean.tmp

    ascii_cleanup.ksh ${FILE_IN} ${FILE_OUT} ${FILE_TMP}

    rm -f $FILE_TMP

#STEP Step110R
    export STEPNAME=Step110R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  RUN FILE THRU ASCII CLEANUP TO CHG TABS TO PIPE                  *
#********************************************************************

    export FILE_IN=$RACE/tmp/${JOBNAME}_$OEMFILE8
    export FILE_OUT=$RACE/tmp/${JOBNAME}_us_gm_pubsubsection_en_clean.dat
    export FILE_TMP=$RACE/tmp/${JOBNAME}_us_gm_pubsubsection_en_clean.tmp

    ascii_cleanup.ksh ${FILE_IN} ${FILE_OUT} ${FILE_TMP}

    rm -f $FILE_TMP

#STEP Step120R
    export STEPNAME=Step120R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  RUN FILE THRU ASCII CLEANUP TO CHG TABS TO PIPE                  *
#********************************************************************

    export FILE_IN=$RACE/tmp/${JOBNAME}_$OEMFILE9
    export FILE_OUT=$RACE/tmp/${JOBNAME}_us_gm_vehicle_clean.dat
    export FILE_TMP=$RACE/tmp/${JOBNAME}_us_gm_vehicle_clean.tmp

    ascii_cleanup.ksh ${FILE_IN} ${FILE_OUT} ${FILE_TMP}

    rm -f $FILE_TMP

#STEP Step130R
    export STEPNAME=Step130R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  EXECUTE PROCEDURE TO TRUNCATE WARR_GM tables                     *
#********************************************************************

sqlplus << % 2>&1 > $LOG
$MPTUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec pkg_warr_gmc.p_truncate_warr_gmc_tables;

QUIT;
%

#STEP Step140R
    export STEPNAME=Step140R
    echo "    Start " ${STEPNAME} "    "$(date)
#**********************************************************************
#   Load addtime file to Oracle Staging Table                          
#**********************************************************************
     
    export SQL_CTL=$RACE/prm/lbr030_addtime.ctl
    export SQL_LOG=$RACE/tmp/${JOBNAME}_addtime_log.tmp
    export SQL_IN=$RACE/tmp/${JOBNAME}_us_gm_addtime_clean.dat
    export SQL_BAD=$DAT_DIR/${JOBNAME}_addtime.bad
    export SQL_DSC=$RACE/tmp/${JOBNAME}_addtime.dsc

    trap - err
    sqlldr userid=$MPTUSERID control=$SQL_CTL log=$SQL_LOG
    trap 'abndalrt.ksh $?' err

    cat $SQL_LOG

#STEP Step150R
    export STEPNAME=Step150R
    echo "    Start " ${STEPNAME} "    "$(date)
#**********************************************************************
#   Load basetime file to Oracle Staging Table                          
#**********************************************************************
     
    export SQL_CTL=$RACE/prm/lbr030_basetime.ctl
    export SQL_LOG=$RACE/tmp/${JOBNAME}_basetime_log.tmp
    export SQL_IN=$RACE/tmp/${JOBNAME}_us_gm_basetime_clean.dat
    export SQL_BAD=$DAT_DIR/${JOBNAME}_basetime.bad
    export SQL_DSC=$RACE/tmp/${JOBNAME}_basetime.dsc
    trap - err
    sqlldr userid=$MPTUSERID control=$SQL_CTL log=$SQL_LOG
    trap 'abndalrt.ksh $?' err
    cat $SQL_LOG

#STEP Step160R
    export STEPNAME=Step160R
    echo "    Start " ${STEPNAME} "    "$(date)
#**********************************************************************
#   Load laborop file to Oracle Staging Table                          
#**********************************************************************
     
    export SQL_CTL=$RACE/prm/lbr030_laborop.ctl
    export SQL_LOG=$RACE/tmp/${JOBNAME}_laborop_en_log.tmp
    export SQL_IN=$RACE/tmp/${JOBNAME}_us_gm_laborop_en_clean.dat
    export SQL_BAD=$DAT_DIR/${JOBNAME}_laborop_en.bad
    export SQL_DSC=$RACE/tmp/${JOBNAME}_laborop_en.dsc
    trap - err
    sqlldr userid=$MPTUSERID control=$SQL_CTL log=$SQL_LOG
    trap 'abndalrt.ksh $?' err
    cat $SQL_LOG

#STEP Step170R
    export STEPNAME=Step170R
    echo "    Start " ${STEPNAME} "    "$(date)
#**********************************************************************
#   Load mktgdiv file to Oracle Staging Table                          
#**********************************************************************
     
    export SQL_CTL=$RACE/prm/lbr030_mktgdiv.ctl
    export SQL_LOG=$RACE/tmp/${JOBNAME}_mktgdiv_log.tmp
    export SQL_IN=$RACE/tmp/${JOBNAME}_us_gm_mktgdiv_clean.dat
    export SQL_BAD=$DAT_DIR/${JOBNAME}_mktgdiv.bad
    export SQL_DSC=$RACE/tmp/${JOBNAME}_mktgdiv.dsc
    trap - err
    sqlldr userid=$MPTUSERID control=$SQL_CTL log=$SQL_LOG
    trap 'abndalrt.ksh $?' err
    cat $SQL_LOG

#STEP Step180R
    export STEPNAME=Step180R
    echo "    Start " ${STEPNAME} "    "$(date)
#**********************************************************************
#   Load pubpsdvh file to Oracle Staging Table                          
#**********************************************************************
     
    export SQL_CTL=$RACE/prm/lbr030_pubpsdvh.ctl
    export SQL_LOG=$RACE/tmp/${JOBNAME}_pubpsdvh_log.tmp
    export SQL_IN=$RACE/tmp/${JOBNAME}_us_gm_pubpsdvh_clean.dat
    export SQL_BAD=$DAT_DIR/${JOBNAME}_pubpsdvh.bad
    export SQL_DSC=$RACE/tmp/${JOBNAME}_pubpsdvh.dsc
    trap - err
    sqlldr userid=$MPTUSERID control=$SQL_CTL log=$SQL_LOG
    trap 'abndalrt.ksh $?' err
    cat $SQL_LOG

#STEP Step190R
    export STEPNAME=Step190R
    echo "    Start " ${STEPNAME} "    "$(date)
#**********************************************************************
#   Load pubsection file to Oracle Staging Table                          
#**********************************************************************
     
    export SQL_CTL=$RACE/prm/lbr030_pubsection.ctl
    export SQL_LOG=$RACE/tmp/${JOBNAME}_pubsection_en_log.tmp
    export SQL_IN=$RACE/tmp/${JOBNAME}_us_gm_pubsection_en_clean.dat
    export SQL_BAD=$DAT_DIR/${JOBNAME}_pubsection_en.bad
    export SQL_DSC=$RACE/tmp/${JOBNAME}_pubsection_en.dsc
    trap - err
    sqlldr userid=$MPTUSERID control=$SQL_CTL log=$SQL_LOG
    trap 'abndalrt.ksh $?' err
    cat $SQL_LOG

#STEP Step200R
    export STEPNAME=Step200R
    echo "    Start " ${STEPNAME} "    "$(date)
#**********************************************************************
#   Load pubsubsection file to Oracle Staging Table                          
#**********************************************************************
     
    export SQL_CTL=$RACE/prm/lbr030_pubsubsection.ctl
    export SQL_LOG=$RACE/tmp/${JOBNAME}_pubsubsection_en_log.tmp
    export SQL_IN=$RACE/tmp/${JOBNAME}_us_gm_pubsubsection_en_clean.dat
    export SQL_BAD=$DAT_DIR/${JOBNAME}_pubsubsection_en.bad
    export SQL_DSC=$RACE/tmp/${JOBNAME}_pubsubsection_en.dsc
    trap - err
    sqlldr userid=$MPTUSERID control=$SQL_CTL log=$SQL_LOG
    trap 'abndalrt.ksh $?' err
    cat $SQL_LOG

#STEP Step210R
    export STEPNAME=Step210R
    echo "    Start " ${STEPNAME} "    "$(date)
#**********************************************************************
#   Load vehicle file to Oracle Staging Table                          
#**********************************************************************
     
    export SQL_CTL=$RACE/prm/lbr030_vehicle.ctl
    export SQL_LOG=$RACE/tmp/${JOBNAME}_vehicle_log.tmp
    export SQL_IN=$RACE/tmp/${JOBNAME}_us_gm_vehicle_clean.dat
    export SQL_BAD=$DAT_DIR/${JOBNAME}_vehicle.bad
    export SQL_DSC=$RACE/tmp/${JOBNAME}_vehicle.dsc
    trap - err
    sqlldr userid=$MPTUSERID control=$SQL_CTL log=$SQL_LOG
    trap 'abndalrt.ksh $?' err
    cat $SQL_LOG

#STEP Step220R
    export STEPNAME=Step220R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  EXECUTE PROCEDURE TO INSERT DATA IN TEMP_WARR_GMC_BASENOTE                    *
#********************************************************************

sqlplus << % 2>&1 > $LOG
$MPTUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec pkg_warr_gmc.p_load_temp_warr_gmc_basenote;

QUIT;
%

#STEP Step230R
    export STEPNAME=Step230R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  EXECUTE PROCEDURE TO UPDATE WARR_ tables                      *
#********************************************************************

sqlplus << % 2>&1 > $LOG
$MPTUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec pkg_warr_gmc.p_load_warr_upd('$RPT_PATH','$RPT_NAME1','$SQL_JOBNAME','$SQL_LOG_PATH','$SQL_LOGFILE');

QUIT;
%

#STEP Step240R
    export STEPNAME=Step240R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  EXECUTE PROCEDURE TO UPDATE WARR_ tables                      *
#********************************************************************

sqlplus << % 2>&1 > $LOG
$MPTUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec pkg_warr_gmc.p_model_config_upd('$RPT_PATH','$RPT_NAME2','$SQL_JOBNAME','$SQL_LOG_PATH','$SQL_LOGFILE');

QUIT;
%


#STEP Step250R
    export STEPNAME=Step250R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  EXECUTE PROCEDURE TO UPDATE WARR_ tables                      *
#********************************************************************

sqlplus << % 2>&1 > $LOG
$MPTUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec pkg_warr_gmc.p_labor_operation_upd('$RPT_PATH','$RPT_NAME3','$SQL_JOBNAME','$SQL_LOG_PATH','$SQL_LOGFILE');

QUIT;
%

#STEP Step260R
    export STEPNAME=Step260R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  EXECUTE PROCEDURE TO UPDATE WARR_ tables                      *
#********************************************************************

sqlplus << % 2>&1 > $LOG
$MPTUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec pkg_warr_gmc.p_labor_time_upd('$RPT_PATH','$RPT_NAME4','$SQL_JOBNAME','$SQL_LOG_PATH','$SQL_LOGFILE');

QUIT;
%


#STEP Step270R
    export STEPNAME=Step270R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  EXECUTE PROCEDURE TO UPDATE WARR_ tables                      *
#********************************************************************

sqlplus << % 2>&1 > $LOG
$MPTUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec pkg_warr_gmc.p_related_labor_upd('$RPT_PATH','$RPT_NAME5','$SQL_JOBNAME','$SQL_LOG_PATH','$SQL_LOGFILE');

QUIT;
%


#STEP Step280R
    export STEPNAME=Step280R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  EXECUTE PROCEDURE TO UPDATE WARR_ tables                      *
#********************************************************************

sqlplus << % 2>&1 > $LOG
$MPTUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec pkg_warr_gmc.p_related_qualifier_upd('$RPT_PATH','$RPT_NAME6','$SQL_JOBNAME','$SQL_LOG_PATH','$SQL_LOGFILE');

QUIT;
%


#STEP Step290R
    export STEPNAME=Step290R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  EXECUTE PROCEDURE TO UPDATE WARR_ tables                      *
#********************************************************************

sqlplus << % 2>&1 > $LOG
$MPTUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec pkg_warr_gmc.p_log_oem_upd;

QUIT;
%

#STEP Step310R
    export STEPNAME=Step310R
    echo "    Start " ${STEPNAME} "    "$(date)
#**********************************************************************
#   Retain 3 Copies of the Zip File
#**********************************************************************
   
   export GDGFILE=$( setgdg.ksh "$ZIPFILE(+01)" NEW 3 )
   mv $ZIPFILE $GDGFILE

#STEP Step320R
    export STEPNAME=Step320R
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

   export GDGFILE=$( setgdg.ksh "$RPT_NAME5(+01)" NEW 3 )
   mv $RPT_NAME5 $GDGFILE

   export GDGFILE=$( setgdg.ksh "$RPT_NAME6(+01)" NEW 3 )
   mv $RPT_NAME6 $GDGFILE

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
    #MAIL_RECIP="$(head -n +1 $MAIL_PARM | awk '{print $1}')"
    MAIL_RECIP="$(head -n +1 $MAIL_PARM | awk '{print}')"


    # create text message for mail
    echo "RACE tables have been loaded with latest GMC Warranty Data" > $MAIL_TEXT

  if [ ${ACT_LVL} = prod ]
  then
    mailx -s "PROD - GMC Warranty Update Notification" $MAIL_RECIP < $MAIL_TEXT
  else
    mailx -s "TEST - GMC Warranty Update Notification" $MAIL_RECIP < $MAIL_TEXT
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
