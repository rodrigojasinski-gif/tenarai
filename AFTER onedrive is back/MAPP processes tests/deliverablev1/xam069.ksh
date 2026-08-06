#!/bin/ksh
 echo "$Id: xam069.ksh,v 1.12 2021/08/24 21:24:32 pg2697 Exp $"
############################################################################
#  PROCNAME:  xam069                                                       #
#  DESC:      Load PART_CAPA_XREF table using CAPA-supplied data file.     #
#                                                                          #
#  NOTE: Audit logging is not turned on/off for this job as PART_CAPA_XREF #
#        has no assoc'd trigger.                                           #
############################################################################

  set -xv
  export PROCNAME=$(basename $0 .ksh_run )
  trap 'abndalrt.ksh   $?' err

# Change rj132422 - 20260424 - MAPP/ALTP file paths now come from race_altp.ksh
# Replaces the legacy prod3nt / ${NOVELL} FTP dependency.

  export XAMUSERID=`cat $RACE/prm/zxampass.prm`

  export ORA_RPT_DIR=$OBJ_RPTDIR
  export ORA_TMP_DIR=$OBJ_TMPDIR
  export ORA_MAIL_LIST=${JOBNAME}_email_recips.tmp

  export ORA_ERR1_RPT=${JOBNAME}a_errcapa.csv
  export ORA_ERR2_RPT=${JOBNAME}d_errcapa.txt
  export ORA_SUM_RPT=${JOBNAME}b_sumcapa.txt
  export ORA_VER_RPT=${JOBNAME}c_vercapa.txt


#STEP Step010R 
############################################################################
#* STEP010R                                                                #
#  1. EXECUTE FILE GET AND PASS THE NT FILE TO UNIX.                       #
#  2. CHECK DIRECTORY COUNTS ON BOTH SIDES TO VALIDATE THE TRANSFER        #
############################################################################
  export STEPNAME=Step010R
  echo "    Start   ${STEPNAME}           "$(date)

  export DD_NOVELDSK=capacert.prn
  export DD_UNXDISK=$RACE/tmp/${JOBNAME}_capacert.xfr
# Change rj132422 - 20260424 - Remove prod3nt dependency; use NFS-mounted path
  export DD_NOVELDIR=${ALTP_DIR}
  export DD_STDOUT=$RACE/tmp/${JOBNAME}_work1.tmp

  rm -f $DD_UNXDISK
  cp ${DD_NOVELDIR}/${DD_NOVELDSK} ${DD_UNXDISK} > $DD_STDOUT 2>&1

  if [[ ! -s ${DD_UNXDISK} ]]
  then
       print " ***** error ***** file copy failed - target missing or empty "
       print " SOURCE = ${DD_NOVELDIR}/${DD_NOVELDSK} "
       cat $DD_STDOUT 2>/dev/null
       abndalrt.ksh ftp_get
  fi

  novelcount=$(wc -c ${DD_NOVELDIR}/${DD_NOVELDSK} 2>/dev/null | awk '{print $1}')
  unixcount=$(wc -c $DD_UNXDISK 2>/dev/null | awk '{print $1}')

  if [[ -n "$novelcount" && "$novelcount" = "$unixcount" ]]
    then
       print " file copy counts are good "
  else
       print " ***** error ***** file copy counts do not match "
       print " SOURCE byte count = $novelcount "
       print " TARGET byte count = $unixcount "
       abndalrt.ksh ftp_get
  fi


#STEP Step020R 
#*********************************************************************
#* STEP020R                                                          *
#* 1. MAKE SURE DATA IS VOID OF ASCII CONTROL CHARACTERS             *
#*********************************************************************
  export STEPNAME=Step020R
  echo "    Start   ${STEPNAME}           "$(date)

  export DD_CLEANIN="$RACE/tmp/${JOBNAME}_capacert.xfr"
  export DD_CLEANOU="$RACE/dat/${JOBNAME}_xtab_raw_capa.dat"

  cat $DD_CLEANIN | tr -d '\032' |\
  tr '\000-\011\013-\037\177' '[^*]' |\
  sed 's/\^$//' > $DD_CLEANOU

#STEP Step030R
#********************************************************************
#* STEP030R                                                         *
#* 1.  SORT STATIC CAPA RECORDS AND DROP DUPLICATES, IF ANY.        *
#*     SORT KEYS:                                                   *
#*               PART SUPPLIER NUMBER pos 01 - 03                   *
#*               PART NUMBER          pos 06 - 30                   *
#* 2.  DROP DUPLICATES                                              *
#********************************************************************
  export STEPNAME=Step030R
  echo "    Start   ${STEPNAME}           "$(date)

  export DD_SORTIN=$RACE/dat/${JOBNAME}_static_capa.dat
  export DD_SORTOUT="$RACE/dat/${JOBNAME}_xtab_raw_static_capa.dat" 

  sort -u -k1.1,1.3 -k1.6,1.30 -o $DD_SORTOUT $DD_SORTIN


#STEP Step040R
#********************************************************************
#* STEP040R                                                         *
#* 1. EXECUTE PROCEDURE TO REFORMAT CAPA DATA, LOAD CAPA AND STATIC *
#*    DATA TO DB TABLE part_capa_xref, AND PRODUCE 3 REPORTS.       *
#*    CAPA FILE   = ${JOBNAME}_xtab_raw_capa.dat                    *
#*    STATIC FILE = ${JOBNAME}_xtab_raw_static.dat                  *
#********************************************************************
  export STEPNAME=Step040R
  echo "    Start   ${STEPNAME}           "$(date)


sqlplus << % 2>&1 > $LOG
$XAMUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec PKG_ALTERNATE_PARTS_CERTFILE.P_REFORMAT_CAPA_FILE(pv_data_provider => 'CAPA', \
                                                       pv_rpt_dir   => '$ORA_RPT_DIR', \
                                                       pv_err1_file  => '$ORA_ERR1_RPT', \
                                                       pv_err2_file  => '$ORA_ERR2_RPT', \
                                                       pv_sum_file  => '$ORA_SUM_RPT', \
                                                       pv_ver_file  => '$ORA_VER_RPT', \
                                                       pv_mail_dir  => '$ORA_TMP_DIR', \
                                                       pv_mail_file => '$ORA_MAIL_LIST' );



QUIT;
%

  
#STEP Step050R
#********************************************************************
#* STEP050R                                                         *
#* 2.  CREATE GDG OF CAPA FILE                                      *
#********************************************************************
  export STEPNAME=Step050R
  echo "    Start   ${STEPNAME}           "$(date)

  export DD_FILEIN=$RACE/dat/${JOBNAME}_xtab_raw_capa.dat
  export DD_FILEOUT=$(setgdg.ksh "$RACE/dat/${JOBNAME}_xtab_raw_capa.dat(+1)"  NEW 3)

  cp $DD_FILEIN $DD_FILEOUT


#STEP Step055R 
#********************************************************************
#* STEP055R                                                          *
#* 1. EMAIL REPORTS TO CAPA CONTACT (detail csv and summary only)   *
#*    AND ALTPART DATA ANALYST (all 3)                              *
#* ---------------------------------------------------------------- *
#* mailx optons:                                                    *
#*  -r   Sender ("FROM" name and address.)                          *
#*  -s   Subject                                                    *
#*  -a /path/to/attachmentfile                                      *
#*  message is retrieved and echoed from a prm file                 *
#********************************************************************
  export STEPNAME=Step055R 
  echo "    Start   ${STEPNAME}           "$(date)

  export MAIL_LIST=$RACE/tmp/${JOBNAME}_email_recips.tmp
  export MAIL_TEXT=$RACE/prm/xam069b_email_text.prm
  export CONST_DATA_ANALYST="Rpt.Altpart.Updates@mitchell.com"
  
# add Mitchell (static) email address to CAPA (dynamic) recip list
  cat $RACE/prm/xam069a.prm >> $RACE/tmp/${JOBNAME}_email_recips.tmp

  while read LINE
  do 
    export RECIP=`echo $LINE | cut -f1 -d"|"`  
    
    if [ ${RECIP} = ${CONST_DATA_ANALYST} ] 
      then
       # Mitchell gets all 3 reports
       (echo "$(<${MAIL_TEXT})";uuencode $RACE/rpt/${ORA_ERR1_RPT} err_capa.csv;uuencode $RACE/rpt/${ORA_ERR2_RPT} err_capa.txt;uuencode $RACE/rpt/${ORA_SUM_RPT} sum_capa.txt;\
        uuencode $RACE/rpt/${ORA_VER_RPT} ver_capa.txt)\
        | mailx -v -r production.control.mapp@mitchell.com -s "CAPA File Processing Reports" ${RECIP}
    else
       # CAPA gets only 2 reports
       (echo "$(<${MAIL_TEXT})";uuencode $RACE/rpt/${ORA_ERR1_RPT} err_capa.csv;uuencode $RACE/rpt/${ORA_ERR2_RPT} err_capa.txt;uuencode $RACE/rpt/${ORA_SUM_RPT} sum_capa.txt)\
        | mailx -v -r production.control.mapp@mitchell.com -s "CAPA File Processing Reports" ${RECIP}

    fi

  done<$MAIL_LIST

#STEP Step060   
#********************************************************************
#* STEP060                                                          *
#* 1. SAVE REPORTS WITH DATE                                        *
#********************************************************************
  export STEPNAME=Step060
  echo "    Start   ${STEPNAME}           "$(date)
 
 
export PERM_ERR1_RPT=${JOBNAME}a_errcapa_$(date +'%C%y%m%d%H%M%S').csv
export PERM_ERR2_RPT=${JOBNAME}d_errcapa_$(date +'%C%y%m%d%H%M%S').txt
export PERM_SUM_RPT=${JOBNAME}b_sumcapa_$(date +'%C%y%m%d%H%M%S').txt
export PERM_VER_RPT=${JOBNAME}c_vercapa_$(date +'%C%y%m%d%H%M%S').txt

mv $RACE/rpt/${ORA_ERR1_RPT} $RACE/rpt/${PERM_ERR1_RPT}
mv $RACE/rpt/${ORA_ERR2_RPT} $RACE/rpt/${PERM_ERR2_RPT}
mv $RACE/rpt/${ORA_SUM_RPT} $RACE/rpt/${PERM_SUM_RPT}
mv $RACE/rpt/${ORA_VER_RPT} $RACE/rpt/${PERM_VER_RPT}
 
#STEP Step065R 
#********************************************************************
#* STEP065R                                                         *
#* 1. "Cull" REPORTS ACCORDING TO RETENTION SETUP                   *
#********************************************************************
  export STEPNAME=Step065R
  echo "    Start   ${STEPNAME}           "$(date)

  rpt_log_retention.ksh "${JOBNAME}a"
  rpt_log_retention.ksh "${JOBNAME}b"
  rpt_log_retention.ksh "${JOBNAME}c"
  rpt_log_retention.ksh "${JOBNAME}d"


  
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
