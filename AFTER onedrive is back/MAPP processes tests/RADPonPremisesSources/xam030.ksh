#!/bin/ksh
#$Id: xam030.ksh,v 1.1 2012/01/12 21:39:42 pb0690 Exp $  
 echo "$Id: xam030.ksh,v 1.1 2012/01/12 21:39:42 pb0690 Exp $"
#***************************************************************************
#  PROCNAME:  xam030.ksh                                               *
#  ALTERNATE PARTS SUPPLIER COPY                              *
#  (USED BY DATA ANALYST TO COPY SUPPLIER               *
#***************************************************************************
  
set -xv
export PROCNAME=$(basename $0 .ksh_run)   
trap 'abndalrt.ksh    $?' err    
  
  export XAMUSERID=`cat $RACE/prm/zxampass.prm`

#STEP Step100R
############################################################################
#* STEP100R                                                                #
#  1. EXECUTE FILE GET AND PASS THE NT FILE TO UNIX.                       #
#  2. CHECK DIRECTORY COUNTS ON BOTH SIDES TO VALIDATE THE TRANSFER        #
############################################################################
  export STEPNAME=Step100R
  echo "    Start   ${STEPNAME}           "$(date)

  export NTFILE=copy_supplier.txt
  export UNXFILE=$RACE/tmp/${JOBNAME}_copy.xfr
  export NTDIR=${NOVELL}altp
  export FTPLOG=$RACE/tmp/${JOBNAME}_copy_ftp.tmp

  fileget.exp $NTFILE $UNXFILE $NTDIR \
  | tee $FTPLOG

  ntcount=$( grep 'Information ret' $FTPLOG | awk '{print $1}')
  unixcount=$(wc -c $UNXFILE | awk '{print $1}')

  if [ ntcount -eq unixcount ]
    then
       echo " ftp directory counts are good "
  else
       echo " ***** error ***** ftp directory counts do not match "
       echo " UNIX byte count = $unixcount "
       abndalrt.ksh ftp_get
  fi

#STEP Step200R
#***************************************************************************
#* STEP200R                                                                *
#* 1. MAKE SURE DATA IS VOID OF ASCII CONTROL CHARACTERS                   *
#***************************************************************************
  export STEPNAME=Step200R
  echo "    Start   ${STEPNAME}           "$(date)

  export CLEANIN="$RACE/tmp/${JOBNAME}_copy.xfr"
  export CLEANOU="$RACE/tmp/${JOBNAME}_copy_supplier.tmp"

  rm -f $CLEANOU

  cat $CLEANIN | tr -d '\032' |\
  tr '\000-\011\013-\037\177' '[^*]' |\
  tr '\240' '[ *]' |\
  sed 's/\^$//' > $CLEANOU


#STEP Step300R
#********************************************************************
#* STEP300R                                                         *
#* 1. EXECUTE SQL PROGRAM TO COPY PART SUPPLIER INFORMATION TO NEW  *
#********************************************************************
  export STEPNAME=Step300R
  echo "    Start   ${STEPNAME}           "$(date)

  export ORA_JOBNAME=${JOBNAME}
  export ORA_IN_DIR=$OBJ_TMPDIR
  export ORA_IN_FILE=${JOBNAME}_copy_supplier.tmp
  export ORA_OUT_FILE=${JOBNAME}_copy_email.tmp

export SQL_JOBNAME=$JOBNAME
export SQL_TMP_PATH=$OBJ_TMPDIR

sqlplus << % 2>&1 > $LOG
$XAMUSERID
set serveroutput on;
set feedback on;
set termout on;
set trimspool on;
set arraysize 200;
whenever sqlerror exit sql.sqlcode

exec SP_ALTP_SUPPLIER_DATA_COPY('$SQL_TMP_PATH','$ORA_IN_FILE','$ORA_OUT_FILE');

QUIT;
%

#STEP Step400R
#********************************************************************
#* STEP400R                                                          *
#* 1. EMAIL DATA ANALYST THE RESULTS OF COPY.     *
#********************************************************************
# export STEPNAME=Step400R
# echo "    Start   ${STEPNAME}           "$(date)

  export MAIL_LIST=$RACE/prm/xam030a_email.prm 
  export MAIL_TEXT="$RACE/tmp/${JOBNAME}_copy_email.tmp"

# set email address from parm card and mail

  for VARLIST in `cat $MAIL_LIST`
    do
      set $VARLIST
      export RECIP=$1
      mailx -s "${JOBNAME} - Copy" ${RECIP} < $MAIL_TEXT
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