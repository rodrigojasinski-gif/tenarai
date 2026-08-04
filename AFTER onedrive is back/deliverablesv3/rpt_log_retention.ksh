#!/bin/ksh
#echo "RCS $Id: rpt_log_retention.ksh,v 1.1 2014/11/07 23:56:50 pg2697 Exp $"
echo "\n Begin rpt_log_retention.ksh \n"
#set -xv        # uncomment for debugging; commented out for shared utilities                                                                  
###############################################################################
# SCRIPT NAME: rpt_log_retention.ksh                                             
# SCRIPT DESC: Report and Log Management utility
#              1) process arg passed in (REPORT_ID)
#                 E.G. for rpt:  mptr050a
#                      for log:  mptr050_
#              2) get file retention information from RACE report_mgmt table 
#              3) create tmp list of all files having REPORT_ID passed in.
#              4) loop thru list, counting files.
#                 when file number if greater than retention number, remove file
#              5) remove tmp file containing list of files 
###############################################################################
# Modification History
# Date        User-id    Description
# ==========  ======     =========================================
# 2014/08/01  pg2697     Created to replace CosReport file culling.
###############################################################################
trap 'abndalrt.ksh $?' err
export SHAREUSERID=`cat /$ACT_LVL/race/share/prm/zsharepass.prm`

#********************************************************************
#* process arg passed in - report ID                                *
#********************************************************************
if [[ $# = "0" ]]                            # test for no arguments
then
  echo "ERROR! No arguement passed into rpt_log_retention.ksh"
  echo "----------------------------------------------------------------- "
  echo "execution consists of: "
  echo "   ==>  rpt_log_retention.ksh REPORT_ID "
  echo "----------------------------------------------------------------- "
  exit -1
else                                                              
   REPORTID=$1
   echo "Processing REPORTID=${REPORTID}"
fi

#********************************************************************
#* get directory and retention associated with report ID  from DB,  *
#* place in tmp file and then parse it into unix env variables.     *      
#********************************************************************
export RPT_TMPFILE=${REPORTID}_retention_info.tmp

# rj132422 - AIX->Linux fix
export LOG=/tmp/rpt_log_retention_$$.sqlout
: > $LOG

sqlplus << CODE_BLOCK 2>&1 > $LOG
$SHAREUSERID
SET SERVEROUTPUT ON FORMAT WRAPPED;
whenever sqlerror exit sql.sqlcode
    exec pkg_report_mgmt.p_get_retention_info(p_in_reportid       => '${REPORTID}', \
                                              p_in_tmp_dir        => '${OBJ_TMPDIR}', \
                                              p_in_tmp_filename   => '${RPT_TMPFILE}');

QUIT;
CODE_BLOCK

# rj132422 - Cat-back the captured sqlplus output
[ -s "$LOG" ] && cat "$LOG"
rm -f "$LOG"

export DIRNAME=`cat ${RACE}/tmp/${RPT_TMPFILE} | cut -f1  -d"|"`
export RETENTION=`cat ${RACE}/tmp/${RPT_TMPFILE} | cut -f2  -d"|"`

#********************************************************************
#* create list of all files having REPORT_ID passed in.             *
#* list is sorted by newest file first to oldest file.              *
#********************************************************************
export FILE_LIST=$RACE/tmp/${REPORTID}_filelist.tmp
rm -f ${FILE_LIST}
ls -1t ${DIRNAME}/${REPORTID}* > ${FILE_LIST}

#********************************************************************
#* loop thru list, counting files. When filectr is greater than     *
#* retention number, remove file.                                   *
#********************************************************************
filectr=0
while read LINE
do  
  export FILE=`echo $LINE | cut -f1 `
  ((filectr=filectr+1)) 
  if [[ filectr -gt $RETENTION ]]
    then
      echo "oldest file removed: $FILE (due to retention)"    
      rm -f $FILE                     
  fi
done<$FILE_LIST

#********************************************************************
#* remove temp file                                                 *
#********************************************************************
rm -f $RACE/tmp/${REPORTID}_filelist.tmp
rm -f $RACE/tmp/${REPORTID}_retention_info.tmp

echo "\n End rpt_log_retention.ksh"
############################################################################
# END 
############################################################################