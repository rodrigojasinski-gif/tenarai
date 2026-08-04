#!/bin/ksh
echo "RCS $Id: email_rpt.ksh,v 1.7 2021/11/02 19:13:13 pg2697 Exp $"
trap 'abndalrt.ksh $?' err

#set -xv                 #uncomment for testing               
###############################################################################
# SCRIPT NAME: email_rpt.ksh
# 
# EXECUTION: email_rpt.ksh <reportid> 
#       e.g. email_rpt.ksh "${JOBNAME}a"  
#            
# SCRIPT DESC: Send email with report attached (based on race.email_xref table).   
###############################################################################
# Modification History
# Date        User-id    Description
# ==========  ======     =========================================
# 2014/06/01  pg2697     Replacement for CosReport and PrintPipe.
# 2016/02/08  pg2697     1. Changed input to be reportid (not report name)
#                        2. Added check and bypass of email if rpt size = 0
#                        3. Added code to derive reportname using ls -1t
#                           so that email could be invoked in the step following
#                           an abended step. (If file is dated, restart step would
#                           not know filename/date.)
# 2016/03/31 pg2697      1. Added calc of TMP_RPT to include extension of txt.
#                        2. Added calc and pass in of RPT_DIRECTORY to procedure. 
# 2021/10/28 pg2697      Changed awk that precedes email pkg to copy. 
#                        awk was inserting extra lines in COBOL-created rpts   
#                        and not needed for Oracle-created rpts. Also, don't
#                        rename csv files to txt.
###############################################################################

  export SHAREUSERID=`cat /$ACT_LVL/race/share/prm/zsharepass.prm`

###############################################################################
# check for passed in values
###############################################################################
if [ $# = 1 ]                                 
then
  REPORT_ID=$1    
else
  echo "\n***ERROR! Reportid not passed to email_rpt.ksh"
  $(abndalrt.ksh 911)
fi

###############################################################################
# 1. obtain full filename using passed-in reportid and get most recently 
#    created file (ORIG_RPT) 
#    e.g. /mdev/race/oem/rpt/mptd001c_extrsums_odd_ca_en_20160330110713.rpt
# 2. get just rpt's filename without the path and .rpt extension  (RPT_FILENAME)
#    e.g. mptd001c_extrsums_odd_ca_en_20160330110713
# 3. create the tmp file name to be used for emailing windows-version (TMP_RPT)
#    by stripping off directory path and extension; then adding .txt extension
#    e.g. mptd001c_extrsums_odd_ca_en_20160330110713.txt
# 4. NOTE: sql tmp directory object is used to pass into procedure (not path)
###############################################################################

ORIG_RPT=`ls -1t ${RACE}/rpt/${REPORT_ID}* | head -1`

EXTENSION=$(echo $ORIG_RPT | awk -F. '{print $(NF)}') 

# keep csv file extension; otherwise change emailed file to txt extension
if [ $EXTENSION = "csv" ]
  then 
    RPT_FILENAME=$(basename $ORIG_RPT .csv).csv
  else
    RPT_FILENAME=$(basename $ORIG_RPT .rpt).txt
fi

RPT_DIRECTORY=${RACE}/tmp
TMP_RPT=${RPT_DIRECTORY}/${RPT_FILENAME}

echo LATEST REPORT TO BE EMAILED: ${RPT_FILENAME} from ${RPT_DIRECTORY}.

###############################################################################
# check if report file exists and has a size greater than 0
# if it doesn't exist or is empty, skip emailing it. 
#    (p_email_report will abend otherwise)
# if it's valid, 
#    -> chg tmp version to windows-readable format
#       (2021/10/28 pag - chg'd to a copy.)                       
#    -> email it
#    -> remove tmp version
###############################################################################
if [ ! -s ${ORIG_RPT} ] 
then
  echo "Report is empty or does not exist. Report will not be distributed."
else 
  #(2021/10/28 pag)#awk 'sub("$", "\r")' ${ORIG_RPT} > ${TMP_RPT} 
  cp ${ORIG_RPT} ${TMP_RPT}

sqlplus << CODE_BLOCK 2>&1 > $LOG
$SHAREUSERID
SET LINESIZE 132;
SET SERVEROUTPUT ON FORMAT WRAPPED;
whenever sqlerror exit sql.sqlcode

    exec pkg_report_mgmt.p_email_report(p_in_activity_level => '${ACT_LVL}', \
                                        p_in_report_filename => '${RPT_FILENAME}', \
                                        p_in_report_directory => '${OBJ_TMPDIR}');

QUIT;
CODE_BLOCK

rm -f ${TMP_RPT} 
 
fi

###############################################################################
# end of email_rpt.ksh
###############################################################################