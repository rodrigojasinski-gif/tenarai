#!/bin/ksh
 echo "$Id: xam020.ksh,v 1.2 2007/04/09 20:48:30 pg2697 Exp $"
#***************************************************************************
#  PROCNAME:  xam020                                                       *
#  ALTERNATE PARTS REPORTING - PRODUCE SUPPLIER ADDS AND DELETES FILES.    *
#  (USED BY DATA ANALYST TO UPDATE UM README FILE W/ SUPPLIER ACTIVITY FOR *
#   THE MONTH.)                                                            *
#***************************************************************************
  
set -xv
export PROCNAME=$(basename $0 .ksh_run)   
trap 'abndalrt.ksh    $?' err    


#STEP Step010R
#***************************************************************************
#* STEP010R  - TRANSFER FILE CONTAINING LAST UM EXTRACT DATE               *
#  1. EXECUTE FILE GET AND PASS THE NT FILE TO UNIX.                       *
#  2. CHECK DIRECTORY COUNTS ON BOTH SIDES TO VALIDATE THE TRANSFER        *
#***************************************************************************
  export STEPNAME=Step010R
  echo "    Start   ${STEPNAME}           "$(date)

  export NTFILE=Add_Dlet_Date.txt
  export UNXFILE=$RACE/tmp/${JOBNAME}_umdate_parm.xfr
  export NTDIR=${NOVELL}altp
  export FTPLOG=$RACE/tmp/${JOBNAME}_umdate_ftplog.tmp

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

#STEP Step020R
#***************************************************************************
#* STEP020R                                                                *
#* 1. MAKE SURE FILE IS VOID OF ASCII CONTROL CHARACTERS                   *
#***************************************************************************
  export STEPNAME=Step020R
  echo "    Start   ${STEPNAME}           "$(date)

  export CLEANIN="$RACE/tmp/${JOBNAME}_umdate_parm.xfr"
  export CLEANOU="$RACE/tmp/${JOBNAME}_umdate_clean.tmp"

  rm -f $CLEANOU

  cat $CLEANIN | tr -d '\032' |\
  tr '\000-\011\013-\037\177' '[^*]' |\
  tr '\240' '[ *]' |\
  sed 's/\^$//' > $CLEANOU


#STEP Step030
#***************************************************************************
#* STEP030                                                                 *
# 1) ASSOCIATE UM DATE TO VARIABLE                                         *
# 2) CREATE ALTPART SUPPLIER ADD AND DELETE LIST FILES                     *
#                                                                          *
# Example of Parm:                                                         *
# xamr020 2004/11/05   <---Enter UM last extract date in YYYY/MM/DD format *
#***************************************************************************
  export STEPNAME=Step030
  echo "    Start   ${STEPNAME}           "$(date)

  UMDATE=` grep $JOBNAME $RACE/tmp/${JOBNAME}_umdate_clean.tmp | awk '{print $2}'`


  export SQL_UMDATE=$UMDATE
  export XAMUSERID=`cat $RACE/prm/zxampass.prm`
  export SQL_JOBNAME=$JOBNAME
  export SQL_TMP_PATH=$OBJ_TMPDIR
  export SQL_ADDS='_adds.tmp'
  export SQL_DLETS='_dlets.tmp'

sqlplus << % 2>&1 > $LOG
$XAMUSERID
SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 80;
SET SERVEROUTPUT ON; 
whenever sqlerror exit sql.sqlcode

exec SP_ADD_DELETE_SUPLR_RPTS('$SQL_TMP_PATH','$SQL_TMP_PATH','$SQL_JOBNAME','$SQL_UMDATE','$SQL_DLETS','$SQL_ADDS')

QUIT;
%
 
                                                            
#STEP Step040R
#**********************************************************************
#*  FTP SUPPLIER ADD FILE TO NT SERVER FOR USE BY MAPP DATA ANALYST.  *
#**********************************************************************
export STEPNAME=Step040R
echo "    Start   ${STEPNAME}           "$(date)
  
export FTP_FILE=$RACE/tmp/${JOBNAME}_adds.tmp
export FTP_LOG=$RACE/tmp/${JOBNAME}_ftplog_adds.tmp         
                                                                  
fileput.exp $FTP_FILE supplier_adds.txt ${NOVELL}altp/Internal_Rpts ascii | tee $FTP_LOG


#STEP Step050R
#**********************************************************************
#*  FTP SUPPLIER DLETS FILE TO NT SERVER FOR USE BY MAPP DATA ANALYST.*
#**********************************************************************
export STEPNAME=Step050R
echo "    Start   ${STEPNAME}           "$(date)
  
export FTP_FILE=$RACE/tmp/${JOBNAME}_dlets.tmp
export FTP_LOG=$RACE/tmp/${JOBNAME}_ftplog_dlets.tmp         
                                                                  
fileput.exp $FTP_FILE supplier_deletes.txt ${NOVELL}altp/Internal_Rpts ascii | tee $FTP_LOG

#STEP Step999R
#**********************************************************************
#*   REMOVE TEMP DATASETS                                             *
#**********************************************************************
export STEPNAME=Step999R
echo "    Start   ${STEPNAME}           "$(date)

rm -f  $RACE/tmp/${JOBNAME}*

#**********************************************************************