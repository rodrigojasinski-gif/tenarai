#!/bin/ksh
echo "$Id: xex010.ksh,v 1.8 2022/08/11 19:07:51 pg2697 Exp $JOBNAME.ksh,v 1.1 2001/10/26 09:09:09 jn0132 Exp $"
############################################################################
#  RACE                                                          10/26/01  #
#  PROCNAME:  $JOBNAME                                                     #
#  PROC FOR ULTRAMATE RACE TO EXT COPY                                     #
############################################################################
set -vx
export PROCNAME=$(basename $0 .ksh_run)
trap 'abndalrt.ksh $?' err

############################################################################
# Initialize variables.                                                    #
#                                                                          #
# NOTE: No Step number here since this process should be performed each    #
#       time the script is run.                                            #
#                                                                          #
# Get JOB parm file values from zxex000.prm                                #
#  a) set parm file name                                                   #
#  b) set restart flag (T=restart, F=start from beginning)                 #
#  c) set parmfile subdirectory                                            #
#  d) set ftp machine                                                      #
#  e) set ftp directory                                                    #
############################################################################

#   use Korn shell 'grep' command to get job parm values
    PARMFILE=`      grep $JOBNAME.ksh $RACE/prm/zxex000.prm |awk '{print $2}'`
    VERSION=`       grep $JOBNAME.ksh $RACE/prm/zxex000.prm |awk '{print $3}'`
    XFER_FILE=`     grep $JOBNAME.ksh $RACE/prm/zxex000.prm |awk '{print $7}'`
    RUN_TYPE=`      grep $JOBNAME.ksh $RACE/prm/zxex000.prm |awk '{print $8}'`
    SYS_DATE=`date +%EY%Om%d%H%M%OS`

    export SQL_JOBNAME=$JOBNAME
    export SQL_PARMFILE=$PARMFILE
    export SQL_PARMFILE_PATH=$OBJ_PRMDIR
    export SQL_VERSION=$VERSION
    export SQL_SYS_DATE=$SYS_DATE

    export EXTUSERID=`cat $RACE/prm/zxexpass.prm`

#STEP Step010R
   export STEPNAME=Step010R
    echo "    Start " ${STEPNAME} "    "$(date)
#*******************************************************************
#* Step010R: REMOVE ANY PREVIOUSLY CREATED DATASET                 *
#*           UPLOAD NOVELL MFR/SRVC: mprod/race/bcsprod.prm        *
#*******************************************************************

    if [ $XFER_FILE != "N/A" ]
    then

# RM -F any previous .tmp file(s):
         rm -f $RACE/tmp/${JOBNAME}_bcswrk.tmp
         rm -f $RACE/tmp/${JOBNAME}_bcsxfr.tmp

# Declare Novell, UX  disk file variable & Novell Source Directory:
         export DD_NOVELDSK=$XFER_FILE
         export DD_UNIXDSK=$RACE/tmp/${JOBNAME}_bcswrk.tmp
         export DD_NOVELDIR=${NOVELL}usrdat
         export DD_FTPLOG=$RACE/tmp/${JOBNAME}_bcsxfr.tmp

         fileget.exp $DD_NOVELDSK $DD_UNIXDSK $DD_NOVELDIR \
         | tee $DD_FTPLOG

         echo; date

        #Check that DD_UNIXDSK exists and is not Null:
         if [ ! -s $DD_UNIXDSK ]
         then
              echo "Error: Unix file was not created !!\a"
              abndalrt.ksh ftp_null_file
         fi

         novelcount="$(grep 'Information returned by' $DD_FTPLOG | awk '{print $1}')"
         unixcount="$(wc -c $DD_UNIXDSK | awk ' {print $1}')"

         if [ novelcount -eq unixcount ]
         then
            echo "Succeeded ftp of file $DD_NOVELDSK, bytes =$novelcount"
         else
            echo "ftp get of file $DD_NOVELDSK failed: ftp says $novelcount, Unix count is $unixcount"
            abndalrt.ksh ftp_get
         fi
    else
        echo "continuing to extract......."
    fi

#*******************************************************************
#* TRANSLATE   : REMOVE CARRIAGE RETURNS AND LAST LINE WITH ^Z     *
#*               BEFORE USING FILE IN UNIX                         *
#*               RENAME TRANSFER WORK FILE TO bcsprod.xfr          *
#*******************************************************************
  if [ $XFER_FILE != "N/A" ]
  then
     cat $DD_UNIXDSK | tr -d '\015' | sed -e '$d' > $RACE/dat/${JOBNAME}_bcsprod.xfr
     rm -f $RACE/prm/$PARMFILE
     mv $RACE/dat/${JOBNAME}_bcsprod.xfr $RACE/prm/$PARMFILE
  else
        echo "no translate performed ......."
  fi

#STEP Step020R
    export STEPNAME=Step020R
    echo "    Start ${STEPNAME}    "$(date)
#######################################################################
#  Step020R   1. Execute procedure sp_forward_pointer_purge to remove #
#                pointed lines more than a year old prior to extract  #
#             2. Execute procedure sp_race_to_ext to copy Race to Ext #
#######################################################################
export LOG="$(basename $0 .sql)".log

sqlplus << CODE_BLOCK 2>&1 > $LOG
$EXTUSERID
SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 80;
SET SERVEROUTPUT ON; 
whenever sqlerror exit sql.sqlcode


/* 2022/08/10 (AES-2674)-------------------------------
-- Comment out execution of Forward Pointer Purge procedure.
-- It's causing issue with UM/MCE Claims, where they can no longer find part line.

-- exec sp_forward_pointer_purge;

-- 2022/08/10 (AES-2674)-------------------------------*/              

exec sp_race_to_ext('$SQL_PARMFILE_PATH','$SQL_PARMFILE','$SQL_VERSION','$RUN_TYPE');

QUIT;
CODE_BLOCK


#STEP Step030R
    export STEPNAME=Step030R
    echo "    Start ${STEPNAME}    "$(date)
#######################################################################
#  Step030R   1. Execute procedure sp_update_special_graphics to
#                update Special_Material_Graphic table with new png
#                filenames.
#             2. Email ADD report to recipients.
#######################################################################
export LOG="$(basename $0 .sql)".log
export ADD_RPT_NAME=${JOBNAME}a_spec_graphic_add_$(date +'%C%y%m%d%H%M%S').rpt
export ALL_RPT_NAME=${JOBNAME}b_spec_graphic_all_$(date +'%C%y%m%d%H%M%S').rpt
export SOURCE_FILE=${RACE}/rpt/${ALL_RPT_NAME}
export NT_FILE=${JOBNAME}b_spec_graphic_all_rpt.txt
export FTP_LOGFILE=${RACE}/tmp/${JOBNAME}_rptxfer.tmp

if [ $RUN_TYPE = "FULL" ]
  then

sqlplus << CODE_BLOCK 2>&1 > $LOG
$EXTUSERID
SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 80;
SET SERVEROUTPUT ON; 
whenever sqlerror exit sql.sqlcode

exec sp_update_special_graphics(p_in_run_type => '${RUN_TYPE}', \
                           p_in_rptpath  => '${OBJ_RPTDIR}', \
                           p_in_add_rpt  => '${ADD_RPT_NAME}', \
                           p_in_all_rpt  => '${ALL_RPT_NAME}');

QUIT;
CODE_BLOCK

#email report a
email_rpt.ksh "${JOBNAME}a" 
rpt_log_retention.ksh "${JOBNAME}a"

#report b is not emailed. It is transfered to NT.
rpt_log_retention.ksh "${JOBNAME}b"

# Copy the "ALL" report to the Network
fileput.exp ${SOURCE_FILE} ${NT_FILE} ${NOVELL}usrdat ascii | tee ${FTP_LOGFILE}

# With ASCII transfer, you cannot compare unix byte count to FTPBYTECOUNT to determine successful transfer
FTPBYTECOUNT="$(cat ${FTP_LOGFILE} | grep 'Information returned by' | awk '{print $1}')"

fi

#STEP Step999R
    export STEPNAME=Step999R
    echo "    Start ${STEPNAME}    "$(date)
#############################################################################
# Step999R    1. Remove all temp files                                      #
#############################################################################

    rm -f $RACE/tmp/$JOBNAME*

############################################################################
#  END                                                                     #
###########################################################################
