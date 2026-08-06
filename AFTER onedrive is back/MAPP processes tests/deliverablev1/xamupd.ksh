#!/bin/ksh
 echo "$Id: xamupd.ksh,v 1.5 2016/04/27 20:26:41 pg2697 Exp $JOBNAME.ksh,v 1.1 2004/10/30 05:48:01 pg2697 Exp $"
############################################################################
#  PROCNAME:  $JOBNAME                                                     #
#  DESC:      Alternate Parts Update                                       #
############################################################################

  set -xv
  export PROCNAME=$(basename $0 .ksh_run)
  trap 'abndalrt.ksh $?' err

# Change rj132422 - 20260424 - MAPP/ALTP file paths now come from race_altp.ksh
# Replaces the legacy prod3nt / ${NOVELL} FTP dependency.

############################################################################
# INITIALIZE VARIABLES PASSED TO AND USED BY THIS PROC SUB-SCRIPT.         #
#                                                                          #
# NOTE - THERE'S NO STEP NUMBER FOR THIS STEP AS IT SHOULD BE PERFORMED    #
#        EACH TIME THE SCRIPT IS RUN.                                      #
#                                                                          #
# STEP GETS/SETS THE FOLLOWING VARIABLES:                                  #
# 1. JOBNAME      - Passed from main script. Used to save files and get    #
#                   other variables from parm file.                        #
# 2. XAMUSERID    - Retrieved from parm zxampass.prm. Logon information    #
#                   needed for Oracle SQL processes.                       #
# 3. QUALIFIER    - Retrieved from parm zxamvbls.prm. Represents name to   #
#                   be included in file and reports that are created.      #
#                                                                          #
# Example of Parm:                                                         #
# DRIVER_JOB  NT FILENAME            QUALIFIER                             #
# ----------  ---------------------  ---------                             #
# xamr101     n/a                    keystone                              #
############################################################################

  export XAMUSERID=`cat $RACE/prm/zxampass.prm`

# uses korne shell 'grep' command to get variable values from parm file

  XFER=` grep $JOBNAME $RACE/prm/zxamvbls.prm | awk '{print $2}'`
  QUAL=` grep $JOBNAME $RACE/prm/zxamvbls.prm | awk '{print $3}'`

  export XFER_FILE=$XFER
  export QUALIFIER=$QUAL

  export RPTDATE=$(date +'%C%y%m%d%H%M%S')


#STEP Step100R
############################################################################
#* STEP100R                                                                #
#  1. EXECUTE FILE GET AND PASS THE NT FILE TO UNIX.                       #
#  2. CHECK DIRECTORY COUNTS ON BOTH SIDES TO VALIDATE THE TRANSFER        #
#  NOTE - Due to ascii transfer and difference between NT and unix records,#
#         balance check must subtract CR's associated to NT file before    #
#         checking byte counts.                                            #  
############################################################################
  export STEPNAME=Step100R
  echo "    Start   ${STEPNAME}           "$(date)

  export NTFILE=${QUALIFIER}_refproc.txt
  export UNXFILE=$RACE/tmp/${JOBNAME}_${QUALIFIER}_refproc.xfr
# Change rj132422 - 20260424 - Remove prod3nt dependency; use NFS-mounted path
  export NTDIR=${ALTP_DIR}
  export FTPLOG=$RACE/tmp/${JOBNAME}_${QUALIFIER}_ftp.tmp

  rm -f $UNXFILE
# Copy from NFS, then strip CR to preserve the former 'ascii' fileget behavior (CRLF -> LF)
  cp ${NTDIR}/${NTFILE} ${UNXFILE} > $FTPLOG 2>&1
  tr -d '\r' < ${UNXFILE} > ${UNXFILE}.tmp && mv ${UNXFILE}.tmp ${UNXFILE}

  if [[ ! -s ${UNXFILE} ]]
    then
       print " ***** error ***** file copy failed or source file is empty "
       print " SOURCE = ${NTDIR}/${NTFILE} "
       abndalrt.ksh ftp_get
  else
       unixcount=$(wc -c ${UNXFILE} | awk '{print $1}')
       print " file copy is good - UNIX byte count = $unixcount "
  fi


#STEP Step200R
#***************************************************************************
#* STEP200R                                                                *
#* 1. MAKE SURE DATA IS VOID OF ASCII CONTROL CHARACTERS                   *
#***************************************************************************
  export STEPNAME=Step200R
  echo "    Start   ${STEPNAME}           "$(date)

  export DD_CLEANIN="$RACE/tmp/${JOBNAME}_${QUALIFIER}_refproc.xfr"
  export DD_CLEANOU="$RACE/tmp/${JOBNAME}_${QUALIFIER}_refproc_clean.tmp"

  rm -f $DD_CLEANOU

  cat $DD_CLEANIN | tr -d '\032' |\
  tr '\000-\011\013-\037\177' '[^*]' |\
  tr '\240' '[ *]' |\
  sed 's/\^$//' > $DD_CLEANOU


#STEP Step300R
#********************************************************************
#* STEP300R - PART NUMBER VALUATION                                 *
#* 1. EXECUTE SQL PROGRAM TO VERIFY/REFORMAT PART SUPPLIER PART     *
#*    NUMBERS IN TRANSACTION DATA AGAINST MITCHELL PART AND SUPER   *
#*    TABLES. I/P PARM FILE DESIGNATES WHICH DATAFILE TRANSACTIONS  *
#*    SHOULD BE PROCESSED.                                          *
#* 2. A PARM FILE IS CREATED THAT DESIGNATES WHICH DATA PROVIDER(S) *
#*    ARE TO BE PROCESSED IN THE UPDATE AND FOR LATER REPORTING.    *
#* 3. A REPORT IS PRODUCED INDICATING PARSING AND CHECKING SUCCESS. *
#********************************************************************
  export STEPNAME=Step300R
  echo "    Start   ${STEPNAME}           "$(date)

  export ORA_JOBNAME=${JOBNAME}
  export ORA_IN_DIR=$OBJ_TMPDIR
  export ORA_RPT_DIR=$OBJ_RPTDIR
  export ORA_IN_FILE=${JOBNAME}_${QUALIFIER}_refproc_clean.tmp 
  export ORA_SUM_FILE=${JOBNAME}a_${QUALIFIER}_partver_${RPTDATE}.rpt
  export ORA_PRM_FILE=${JOBNAME}_${QUALIFIER}_partver_proc.tmp

  
sqlplus << CODE_BLOCK 2>&1 > $LOG
$XAMUSERID
set serveroutput on;
set feedback on;
set termout on;
set trimspool on;
set arraysize 200;
whenever sqlerror exit sql.sqlcode

exec PKG_ALTERNATE_PARTS_VERIFY.ALTP_PART_VERIFY_PROCESS('$ORA_JOBNAME','$ORA_IN_DIR','$ORA_RPT_DIR','$ORA_IN_FILE','$ORA_SUM_FILE','$ORA_PRM_FILE');

QUIT;
CODE_BLOCK

# email and manage report versions
email_rpt.ksh "${JOBNAME}a"
rpt_log_retention.ksh "${JOBNAME}a"

#STEP Step400R
#********************************************************************
#* STEP400R - UPDATE                                                *
#* 1. EXECUTE SQL PROGRAM TO UPDATE PART_ALTPART_XREF TABLE.        *
#*    A PARM FILE DESIGNATES WHICH DATA PROVIDERS SHOULD BE         *
#*    PROCESSED.                                                    *
#********************************************************************
  export STEPNAME=Step400R
  echo "    Start   ${STEPNAME}           "$(date)

  export ORA_JOBNAME=${JOBNAME}
  export ORA_IN_DIR=$OBJ_TMPDIR
  export ORA_IN_FILE=${JOBNAME}_${QUALIFIER}_partver_proc.tmp
  export ORA_SUM_DIR=$OBJ_RPTDIR
  export ORA_SUM_FILE=${JOBNAME}b_${QUALIFIER}_updtsum_${RPTDATE}.rpt

  
sqlplus << CODE_BLOCK 2>&1 > $LOG
$XAMUSERID
set serveroutput on;
set feedback on;
set termout on;
set trimspool on;
set arraysize 200;
set transaction use rollback segment rbs_large01;
whenever sqlerror exit sql.sqlcode

exec PKG_ALTERNATE_PARTS_UPDATE.ALTP_UPDATE_PROCESS('$ORA_JOBNAME','$ORA_IN_DIR','$ORA_SUM_DIR','$ORA_IN_FILE','$ORA_SUM_FILE');

QUIT;
CODE_BLOCK

# email and manage report versions
email_rpt.ksh "${JOBNAME}b"
rpt_log_retention.ksh "${JOBNAME}b"

#STEP Step500R
#********************************************************************
#* STEP500R                                                         *
#* 1. SAVE COPY OF PARM FILE TO PERMANENT GDG                       *
#********************************************************************
  export STEPNAME=Step500R
  echo "    Start   ${STEPNAME}           "$(date)

  export TMPFILE=$RACE/tmp/${JOBNAME}_${QUALIFIER}_partver_proc.tmp
  export PERMFILE=$( setgdg.ksh "$RACE/dat/${JOBNAME}_${QUALIFIER}_partver_proc.dat(+1)" NEW 3)

  mv $TMPFILE $PERMFILE


#STEP Step600R
#********************************************************************
#* STEP600R                                                         *
#* 1. FTP PARM FILE TO NT DIRECTORY                                 *
#*    (File is ftp'd in the event Data Analyst wants to modify it   *
#*    prior to reporting.)                                          *
#*    NOTE: It MUST be transferred in ascii mode so that each record*
#*    remains separate (i.e. CRLF is applied). Otherwise binary     *
#*    transfer wraps the data.                                      *
#********************************************************************
  export STEPNAME=Step600R
  echo "    Start   ${STEPNAME}           "$(date)

  export FTPFILE=$( setgdg.ksh  "$RACE/dat/${JOBNAME}_${QUALIFIER}_partver_proc.dat(0)")
  export FTPLOG=$RACE/tmp/${JOBNAME}_ftp_partver_proc.tmp
# Change rj132422 - 20260424 - Remove prod3nt dependency; use NFS-mounted path
# sed adds CR to preserve the former 'ascii' fileput behavior (LF -> CRLF for Windows analysts)
  sed 's/\r*$/\r/' $FTPFILE > ${ALTP_DIR}/${QUALIFIER}_rpt_prov.txt 2>$FTPLOG


#STEP Step700
#********************************************************************
#* STEP700                                                          *
#* 1. FTP PART VERIFICATION REPORT TO NT DIRECTORY FOR DATA         *
#*    ANALYST'S REVIEW.                                             *
#*    NOTE: It MUST be transferred in ascii mode so that each record*
#*    remains separate (i.e. CRLF is applied). Otherwise binary     *
#*    transfer wraps the data.                                      *
#********************************************************************
  export STEPNAME=Step700
  echo "    Start   ${STEPNAME}           "$(date)

  export FTPFILE=$RACE/rpt/${JOBNAME}a_${QUALIFIER}_partver_${RPTDATE}.rpt
  export FTPLOG=$RACE/tmp/${JOBNAME}_ftp_partver_sum.tmp
# Change rj132422 - 20260424 - Remove prod3nt dependency; use NFS-mounted path
# sed adds CR to preserve the former 'ascii' fileput behavior (LF -> CRLF for Windows analysts)
  sed 's/\r*$/\r/' $FTPFILE > ${ALTP_INTRPT_DIR}/${QUALIFIER}_partver_sum.txt 2>$FTPLOG


#STEP Step800
#********************************************************************
#* STEP800                                                          *
#* 1. FTP UPDATE SUMMARY REPORT TO NT DIRECTORY FOR DATA ANALYST'S  *
#*    REVIEW.                                                       *
#*    NOTE: It MUST be transferred in ascii mode so that each record*
#*    remains separate (i.e. CRLF is applied). Otherwise binary     *
#*    transfer wraps the data.                                      *
#********************************************************************
  export STEPNAME=Step800
  echo "    Start   ${STEPNAME}           "$(date)

  export FTPFILE=$RACE/rpt/${JOBNAME}b_${QUALIFIER}_updtsum_${RPTDATE}.rpt
  export FTPLOG=$RACE/tmp/${JOBNAME}_ftp_updtsum.tmp
# Change rj132422 - 20260424 - Remove prod3nt dependency; use NFS-mounted path
# sed adds CR to preserve the former 'ascii' fileput behavior (LF -> CRLF for Windows analysts)
  sed 's/\r*$/\r/' $FTPFILE > ${ALTP_INTRPT_DIR}/${QUALIFIER}_updt_sum.txt 2>$FTPLOG


#STEP Step900R
#********************************************************************
#* STEP900R                                                         *
#* 1. EMAIL DATA ANALYST THAT REPORTS ARE AVAILABLE FOR REVIEW.     *
#********************************************************************
  export STEPNAME=Step900R
  echo "    Start   ${STEPNAME}           "$(date)

  export MAIL_LIST=$RACE/prm/zxamupda.prm 
  export MAIL_TEXT=$RACE/prm/zxamupdb.prm

# set email address from parm card and mail

  for VARLIST in `cat $MAIL_LIST`
     do
      set $VARLIST
      export RECIP=$1
      mailx -s "${JOBNAME} - Update" ${RECIP} < $MAIL_TEXT
  done


#STEP Step999R
#********************************************************************
#* STEP999R                                                         *
#* 1. REMOVE TEMP FILES                                             *
#********************************************************************
  export STEPNAME=Step999R
  echo "    Start   ${STEPNAME}           "$(date)
 
  rm -f $RACE/tmp/${JOBNAME}*
 
############################################################################
#  END                                                                     #
############################################################################
