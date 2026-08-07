#!/bin/ksh
 echo "$Id: xamref.ksh,v 1.4 2016/04/27 20:05:04 pg2697 Exp $JOBNAME.ksh,v 1.1 2004/10/30 05:48:01 pg2697 Exp $"
############################################################################
#  PROCNAME:  $JOBNAME                                                     #
#  DESC:      Alternate Parts Data Reformat                                #
############################################################################

  set -xv
  export PROCNAME=$(basename $0 .ksh_run)
  trap 'abndalrt.ksh $?' err

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
# 3. XFER_FILE    - Retrieved from parm zxamvbls.prm. Represents file to be#
#                   transferred from NT server to UNIX environment.        #
# 4. QUALIFIER    - Retrieved from parm zxamvbls.prm. Represents name to   #
#                   be included in file and reports that are created.      #
#                                                                          #
# Example of Parm:                                                         #
# DRIVER_JOB  NT FILENAME            QUALIFIER                             #
# ----------  ---------------------  ---------                             #
# xamr100     keystone_combined.txt  keystone                              #
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
############################################################################
  export STEPNAME=Step100R
  echo "    Start   ${STEPNAME}           "$(date)

  export NTFILE=$XFER_FILE
  export UNXFILE=$RACE/tmp/${JOBNAME}_${QUALIFIER}.xfr
# Change rj132422 - 20260424 - Remove prod3nt dependency; use NFS-mounted path
  export NTDIR=${ALTP_DIR}
  export FTPLOG=$RACE/tmp/${JOBNAME}_${QUALIFIER}_ftp.tmp

  rm -f $UNXFILE
  cp ${NTDIR}/${NTFILE} ${UNXFILE} > $FTPLOG 2>&1

# Verify the copy produced a non-empty file BEFORE comparing counts
  if [[ ! -s ${UNXFILE} ]]
  then
       print " ***** error ***** file copy failed - target missing or empty "
       print " SOURCE = ${NTDIR}/${NTFILE} "
       cat $FTPLOG 2>/dev/null
       abndalrt.ksh ftp_get
  fi

# Verify byte counts between source and destination (both local NFS now)
  ntcount=$(wc -c ${NTDIR}/${NTFILE} 2>/dev/null | awk '{print $1}')
  unixcount=$(wc -c ${UNXFILE} 2>/dev/null | awk '{print $1}')

  if [[ -n "$ntcount" && "$ntcount" = "$unixcount" ]]
    then
       print " file copy counts are good "
  else
       print " ***** error ***** file copy counts do not match "
       print " SOURCE byte count = $ntcount "
       print " TARGET byte count = $unixcount "
       abndalrt.ksh ftp_get
  fi

#STEP Step200R
#***************************************************************************
#* STEP200R                                                                *
#* 1. MAKE SURE DATA IS VOID OF ASCII CONTROL CHARACTERS                   *
#***************************************************************************
  export STEPNAME=Step200R
  echo "    Start   ${STEPNAME}           "$(date)

  export CLEANIN="$RACE/tmp/${JOBNAME}_${QUALIFIER}.xfr"
  export CLEANOU="$RACE/tmp/${JOBNAME}_${QUALIFIER}_clean.tmp"

  rm -f $CLEANOU

  cat $CLEANIN | tr -d '\032' |\
  tr '\000-\011\013-\037\177' '[^*]' |\
  tr '\240' '[ *]' |\
  sed 's/\^$//' > $CLEANOU


#STEP Step300R
#********************************************************************
#* STEP300R                                                         *
#* 1. EXECUTE SQL PROGRAM TO LOAD AND REFORMAT TRANSACTIONS INTO DB *
#********************************************************************
  export STEPNAME=Step300R
  echo "    Start   ${STEPNAME}           "$(date)

  export ORA_JOBNAME=${JOBNAME}
  export ORA_IN_DIR=$OBJ_TMPDIR
  export ORA_IN_FILE=${JOBNAME}_${QUALIFIER}_clean.tmp
  export ORA_SUM_DIR=$OBJ_RPTDIR
  export ORA_SUM_FILE=${JOBNAME}a_${QUALIFIER}_refsum_${RPTDATE}.rpt
  export ORA_PRM_DIR=$OBJ_TMPDIR
  export ORA_PRM_FILE=${JOBNAME}_${QUALIFIER}_refproc_files.tmp
  export ORA_ERR_DIR=$OBJ_TMPDIR
  export ORA_ERR_FILE=${JOBNAME}_${QUALIFIER}_referrs.tmp

  export SQL_JOBNAME=$JOBNAME
  export SQL_TMP_PATH=$OBJ_TMPDIR
  export SQL_RPT_PATH=$OBJ_RPTDIR
  
sqlplus << CODE_BLOCK 2>&1 > $LOG
$XAMUSERID
set serveroutput on;
set feedback on;
set termout on;
set trimspool on;
set arraysize 200;
whenever sqlerror exit sql.sqlcode

exec PKG_ALTERNATE_PARTS_LOAD_TRANS.ALTP_REFORMAT_PROCESS('$SQL_JOBNAME','$SQL_TMP_PATH','$SQL_RPT_PATH','$ORA_IN_FILE','$ORA_SUM_FILE','$ORA_PRM_FILE','$ORA_ERR_FILE');

QUIT;
CODE_BLOCK

# email and manage report versions
email_rpt.ksh "${JOBNAME}a"
rpt_log_retention.ksh "${JOBNAME}a"

#STEP Step400R
#********************************************************************
#* STEP400R                                                         *
#* 1. SAVE COPY OF PARM FILE TO PERMANENT GDG                       *
#********************************************************************
  export STEPNAME=Step400R
  echo "    Start   ${STEPNAME}           "$(date)

  export TMPFILE=$RACE/tmp/${JOBNAME}_${QUALIFIER}_refproc_files.tmp
  export PERMFILE=$( setgdg.ksh "$RACE/dat/${JOBNAME}_${QUALIFIER}_refproc_files.dat(+1)" NEW 3)

  mv $TMPFILE $PERMFILE

#STEP Step450R
#********************************************************************
#* STEP450R                                                         *
#* 1. SAVE COPY OF ERROR FILE TO PERMANENT GDG                      *
#********************************************************************
  export STEPNAME=Step450R
  echo "    Start   ${STEPNAME}           "$(date)

  export TMPFILE=$RACE/tmp/${JOBNAME}_${QUALIFIER}_referrs.tmp
  export PERMFILE=$( setgdg.ksh "$RACE/dat/${JOBNAME}_${QUALIFIER}_referrs.dat(+1)" NEW 3)

  mv $TMPFILE $PERMFILE


#STEP Step500R
#********************************************************************
#* STEP500R                                                         *
#* 1. FTP PARM FILE TO NT DIRECTORY                                 *
#*    (File is ftp'd in the event Data Analyst wants to modify it   *
#*    prior to update.)                                             *
#*    NOTE: It MUST be transferred in ascii mode so that each record*
#*    remains separate (i.e. CRLF is applied). Otherwise binary     *
#*    transfer wraps the data.                                      *
#********************************************************************
  export STEPNAME=Step500R
  echo "    Start   ${STEPNAME}           "$(date)

  export FTPFILE=$( setgdg.ksh "$RACE/dat/${JOBNAME}_${QUALIFIER}_refproc_files.dat(0)")
  export FTPLOG=$RACE/tmp/${JOBNAME}_ftp_refproc.tmp
# Change rj132422 - 20260424 - Remove prod3nt dependency; use NFS-mounted path
# sed adds CR to preserve the former 'ascii' fileput behavior (LF -> CRLF for Windows analysts)
  sed 's/\r*$/\r/' $FTPFILE > ${ALTP_DIR}/${QUALIFIER}_refproc.txt 2>$FTPLOG


#STEP Step550R
#********************************************************************
#* STEP550R                                                         *
#* 1. FTP ERROR FILE TO NT DIRECTORY                                *
#*    (File is ftp'd in the event Data Analyst needs to research    *
#*    errors, and due to unknown file size it's better to ftp it    *
#*    than email it.)                                               *
#*    NOTE: It MUST be transferred in ascii mode so that each record*
#*    remains separate (i.e. CRLF is applied). Otherwise binary     *
#*    transfer wraps the data.                                      *
#********************************************************************
  export STEPNAME=Step550R
  echo "    Start   ${STEPNAME}           "$(date)

  export FTPFILE=$( setgdg.ksh "$RACE/dat/${JOBNAME}_${QUALIFIER}_referrs.dat(0)")
  export FTPLOG=$RACE/tmp/${JOBNAME}_ftp_referrs.tmp
# Change rj132422 - 20260424 - Remove prod3nt dependency; use NFS-mounted path
# sed adds CR to preserve the former 'ascii' fileput behavior (LF -> CRLF)
  sed 's/\r*$/\r/' $FTPFILE > ${ALTP_INTRPT_DIR}/${QUALIFIER}_referrs.txt 2>$FTPLOG


#STEP Step560
#********************************************************************
#* STEP560                                                         *
#* 1. FTP SUMMARY RPT TO NT DIRECTORY                               *
#*    NOTE: It MUST be transferred in ascii mode so that each record*
#*    remains separate (i.e. CRLF is applied). Otherwise binary     *
#*    transfer wraps the data.                                      *
#********************************************************************
  export STEPNAME=Step560
  echo "    Start   ${STEPNAME}           "$(date)

  export FTPFILE=$RACE/rpt/${JOBNAME}a_${QUALIFIER}_refsum_${RPTDATE}.rpt
  export FTPLOG=$RACE/tmp/${JOBNAME}_ftp_refsum.tmp
# Change rj132422 - 20260424 - Remove prod3nt dependency; use NFS-mounted path
# sed adds CR to preserve the former 'ascii' fileput behavior (LF -> CRLF for Windows analysts)
  sed 's/\r*$/\r/' $FTPFILE > ${ALTP_INTRPT_DIR}/${QUALIFIER}_refsum.txt 2>$FTPLOG


#STEP Step600R
#********************************************************************
#* STEP600R                                                          *
#* 1. EMAIL DATA ANALYST THAT REPORTS ARE AVAILABLE FOR REVIEW.     *
#********************************************************************
# export STEPNAME=Step600R
# echo "    Start   ${STEPNAME}           "$(date)

  export MAIL_LIST=$RACE/prm/zxamrefa.prm 
  export MAIL_TEXT=$RACE/prm/zxamrefb.prm

# set email address from parm card and mail

  for VARLIST in `cat $MAIL_LIST`
    do
      set $VARLIST
      export RECIP=$1
      mailx -s "${JOBNAME} - Reformat" ${RECIP} < $MAIL_TEXT
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