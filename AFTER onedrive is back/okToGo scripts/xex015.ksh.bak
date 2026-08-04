#!/bin/ksh
 echo "$Id: xex015.ksh,v 1.16 2020/11/19 18:06:16 pb0690 Exp $"
############################################################################
#  RACE Conversion                                               10/26/01  #
#  PROCNAME:  xex015                                                       #
#  PROC FOR ULTRAMATE BUILD                                                #
############################################################################
set -xv
export PROCNAME=$(basename $0 .ksh_run)
trap 'abndalrt.ksh $?' err
print ProcessId = $$

############################################################################
# Initialize variables.                                                    #
#                                                                          #
# NOTE: No Step number here since this process should be performed each    #
#       time the script is run.                                            #
#                                                                          #
# Get JOB parm file values from zxex000.prm                                #
#  a) set parm file name                                                   #
#  b) set version flag (PR or WP)                                          #
#  c) set restart flag (T=restart, F=start from beginning)                 #
#  d) set unix_subdir subdirectory                                         #
############################################################################

#   use Korn shell '  grep' command to get job parm values
    PARMFILE=`        grep $JOBNAME.ksh $RACE/prm/zxex000.prm |awk '{print $2}'`
    VERSION=`         grep $JOBNAME.ksh $RACE/prm/zxex000.prm |awk '{print $3}'`
    RESTART_FLAG=`    grep $JOBNAME.ksh $RACE/prm/zxex000.prm |awk '{print $4}'`
    RUN_TYPE=`        grep $JOBNAME.ksh $RACE/prm/zxex000.prm |awk '{print $8}'`
    SYS_DATE=`date +%EY%Om%d%H%M%OS`

    export SQL_JOBNAME=$JOBNAME
    export SQL_PARMFILE=$PARMFILE
    export SQL_PARMFILE_PATH=$OBJ_PRMDIR
    export SQL_VERSION=$VERSION
    export SQL_RESTART_FLAG=$RESTART_FLAG
    export SQL_RUN_TYPE=$RUN_TYPE
    export SQL_SYS_DATE=$SYS_DATE

    export EXTUSERID=`cat $RACE/prm/zxexpass.prm`
    export EXTMUSERID=`cat $RACE/prm/zxexmini_pass.prm`

    export FULL_LOG1=$RACE/log/${JOBNAME}_full_1_${SYS_DATE}.log1
    export FULL_LOG2=$RACE/log/${JOBNAME}_full_2_${SYS_DATE}.log2


# rj132422 - AIX->Linux fix: $LOG is set to an absolute temp file
    export LOG=/tmp/${JOBNAME}_$(basename $0 .ksh_run)_$$.sqlout
    : > $LOG


#STEP Step010R
     export STEPNAME=Step010R
     echo "    Start ${STEPNAME}    "$(date)
#######################################################################
#  Step010R   1. Execute SqlPlus script to create error report        #
#                Prefix of ${JOBNAME}a_ is added by report pgm.       #
#######################################################################

    set -

    export SQL_ERR_RPT='xtrsum'
    export SQL_ERR_RPT_PATH=$OBJ_RPTDIR

    xex900.ksh
    # Replay xex900.ksh sqlplus output into the job log (matches AIX behavior).
    [ -s "$LOG" ] && cat "$LOG"
    : > $LOG

    set -xv

    email_rpt.ksh "${JOBNAME}a"
    # email_rpt.ksh may overwrite $LOG (env leak observed: 'LOG=/dev/null').
    # Force the path back to ours so the next sqlplus call uses the real file.
    export LOG=/tmp/${JOBNAME}_$(basename $0 .ksh_run)_$$.sqlout
    : > $LOG

    rpt_log_retention.ksh "${JOBNAME}a"



#STEP Step020R
    export STEPNAME=Step020R
    echo "    Start ${STEPNAME}    "$(date)
#######################################################################
#  Step020R   1. Execute package PKG_ULTRAMATE_BUILD to create UM file#
#######################################################################

if [ ${RUN_TYPE} = MINI ]
then

    sqlplus << % 2>&1 > $LOG
    $EXTMUSERID

    SET ECHO ON;
    SET FEEDBACK ON;
    SET VERIFY ON;
    SET LINESIZE 80;
    SET SERVEROUTPUT ON size unlimited;
    whenever sqlerror exit sql.sqlcode


BEGIN
   PKG_ULTRAMATE_BUILD.ULTRAMATE_MAIN('$OBJ_PRMDIR'
                                      ,'$SQL_RUN_TYPE'
                                      ,'$SQL_PARMFILE'
                                      ,'$OBJ_DATDIR_UMFULL'
                                      ,'$OBJ_DATDIR_UMMINI'
                                      ,'$SQL_VERSION'
                                      ,'$SQL_RESTART_FLAG');
END;
/
QUIT;
%
    [ -s "$LOG" ] && cat "$LOG"
    : > $LOG

else
    sqlplus << % 2>&1 > $LOG
    $EXTUSERID

    SET ECHO ON;
    SET FEEDBACK ON;
    SET VERIFY ON;
    SET LINESIZE 80;
    SET SERVEROUTPUT ON size unlimited;
    whenever sqlerror exit sql.sqlcode

BEGIN
   PKG_ULTRAMATE_PREPARSE.ULTRAMATE_PREPARSE('$SQL_PARMFILE_PATH'
                                      ,'$SQL_RUN_TYPE'
                                      ,'$SQL_PARMFILE'
                                      ,'$OBJ_DATDIR_UMFULL'
                                      ,'$OBJ_DATDIR_UMMINI'
                                      ,'$SQL_VERSION'
                                      ,'$SQL_RESTART_FLAG');
END;
/
QUIT;
%
    [ -s "$LOG" ] && cat "$LOG"
    : > $LOG

fi

#STEP Step030R
    export STEPNAME=Step030R
    echo "    Start ${STEPNAME}    "$(date)
########################################################################
#  Step030R   Mini Processes complete; Exit script.                    #
#             Following steps are only processed for FULL builds       #
########################################################################

if [ ${RUN_TYPE} = MINI ]
then
    echo "MINI processes complete..."
    rm -f "$LOG"
    exit;
else
    export SQL_FULL_PROC_NUM=1
    xex017.ksh  > ${FULL_LOG1} 2>&1 &

    export SQL_FULL_PROC_NUM=2
    xex017.ksh  > ${FULL_LOG2} 2>&1 &

    wait

    xex018.ksh >> ${FULL_LOG1} 2>&1 &

    xex019.ksh >> ${FULL_LOG2} 2>&1 &

    wait
fi

#   use Korn shell '  grep' command to check if either of the xex017 executes abended
#   NOTE: you cannot have spaces before and after the = sign! in the export statement

export FOUND_FLG1=`grep -c 'ORA-' ${FULL_LOG1}`
export FOUND_FLG2=`grep -c 'ORA-' ${FULL_LOG2}`

if [ ${FOUND_FLG1} = "0" ] && [ ${FOUND_FLG2} = "0" ]
then
    xex999.ksh
else
    echo "ERROR OCCURRED DURING BACKGROUND EXECUTION OF xex017. CHECK LOG1 AND LOG2 FILES FOR ORACLE ERROR MSG."
    exit 1;
fi

#STEP Step999R
    export STEPNAME=Step999R
    echo "    Start ${STEPNAME}    "$(date)
#############################################################################
# Step999R    1. Remove all temp files                                      #
#############################################################################

    rm -f $RACE/tmp/$JOBNAME*
    rm -f "$LOG"

############################################################################
# END                                                                     #
############################################################################
