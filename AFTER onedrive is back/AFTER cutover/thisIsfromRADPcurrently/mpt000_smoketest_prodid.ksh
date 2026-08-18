#!/bin/ksh
 echo "$Id: mpt000_smoketest_prodid.ksh,v 1.0 2021/07/19 01:07:39 pg2697 Exp $"
#######################################################################################
#  PROCNAME:  RACE Smoke Test Script
#             Tests commands / connections associated to various RACE jobs.
#
#             1) Run this as a developer before and after a server / OS Migration.
#                (e.g. pg2697)
#             2) Run this as race_b1 before and after a server / OS Migration.
#             3) Pay attention to the step, what it's doing, and it's outcome.
#                Based on the environment (mdev or prod), the results could be different. 
#             4) Compare to what the "expected" outcome should be.
#             5) If it abends, restart after fix has been performed (if a fix
#                is needed) or restart at next step (if an abend was expected).
#
#######################################################################################

set -v
export PROCNAME=$(basename $0 .ksh_run)
trap 'abndalrt.ksh    $?' err

export MPTUSERID=`cat $RACE/prm/zmptpass.prm`
export SQL_TMP_PATH=$OBJ_TMPDIR

#STEP Step001R
#**********************************************************************
#* Check if smoketest file(s) are in pre-test location
#*       $RACE/dat/mptr000_smoketest_file1_keep.dat

#**********************************************************************
export STEPNAME=Step001R
echo "    Start   ${STEPNAME}           "$(date)

export SMOKETEST1=$RACE/dat/mptr000_smoketest_file1_keep.dat

if [ ! -s $SMOKETEST1 ]
  then
    echo "\n-------------------------------------------------------------------------------------"
    echo "---> Step001R: SmokeTest File 1 is missing. Please place file in expected location!"
    echo "-------------------------------------------------------------------------------------"

  else
    echo "\n-------------------------------------------------------------------------------------"
    echo "---> Step001R: SmokeTest File 1 is found."
    echo "-------------------------------------------------------------------------------------"
fi



#STEP Step010R
#*************************************************************************
#* Check connection to RACE ORACLE DB
#*
#*************************************************************************
export STEPNAME=Step010R       
echo "    Start   ${STEPNAME}           "$(date)

##start sqlplus 
sqlplus << % 2>&1 > $LOG 
$MPTUSERID
set serveroutput on;
set feedback on;
set termout on;
set trimspool on;
set arraysize 100;  
whenever sqlerror exit sql.sqlcode

 
DECLARE

v_date 	                date;

BEGIN  
  
 select sysdate into v_date from dual; 
  DBMS_OUTPUT.ENABLE(1000000); 
  DBMS_OUTPUT.NEW_LINE; 
  DBMS_OUTPUT.NEW_LINE; 
  DBMS_OUTPUT.PUT_LINE('Step010R - Start: ' || to_char(v_date,'MM/DD/YYYY HH24:MI:SS'));   
 
 select sysdate into v_date from dual; 
  DBMS_OUTPUT.ENABLE(1000000); 
  DBMS_OUTPUT.NEW_LINE; 
  DBMS_OUTPUT.PUT_LINE('Step010R - End: ' || to_char(v_date,'MM/DD/YYYY HH24:MI:SS'));   
      
END;

-- leave "/" it is required for pl/sql end block ----------------------------------------------------
/
 
quit;

--- leave "end_sql_block" it is required for sql end block ----- 
%

#END OF STEP

#STEP Step020R
#*************************************************************************
#* Check connection to CIFS-shared directory (dev11nas / prod10nas - ODDShare)
#*************************************************************************
export STEPNAME=Step020R
echo "    Start   ${STEPNAME}           "$(date)

export SMOKETEST_IN=$RACE/dat/${JOBNAME}_smoketest_file1_keep.dat
export SMOKETEST_OUT=$RACE/../../odd/oem/archive/dat/${JOBNAME}_smoketest_file1.dat

cp $SMOKETEST_IN $SMOKETEST_OUT 2>&1

if [ ! -s $SMOKETEST_OUT ]
  then
    echo "\n-------------------------------------------------------------------------------------"
    echo "---> Step020R: SmokeTest File not found in oddshare directory!"
    echo "-------------------------------------------------------------------------------------"
  else
    echo "\n-------------------------------------------------------------------------------------"
    echo "---> Step020R: SmokeTest File found in oddshare directory. Check date."
    ls -lt ${SMOKETEST_OUT}
    echo "-------------------------------------------------------------------------------------"
fi


#STEP Step030R
#*************************************************************************
#* Check connection to mappd/mappp server
#*************************************************************************
export STEPNAME=Step030R
echo "    Start   ${STEPNAME}           "$(date)

export RMT_FILE=$RACE/dat/${JOBNAME}_smoketest_file1_keep.dat
export LOC_FILE=/${ACT_LVL}/geis/ftpvm/dat/${JOBNAME}_smoketest_file1_keep.dat

ssh -nq ${MAPP_HOST} rm -f ${LOC_FILE}
scp -q ${RMT_FILE} ${MAPP_HOST}:${LOC_FILE}

echo "\n-------------------------------------------------------------------------------------"
echo "---> Step030R: Was the file copied? (Check the date.)"
ssh -q ${MAPP_HOST} ls -lt ${LOC_FILE}
echo "-------------------------------------------------------------------------------------"


#STEP Step040R
#**********************************************************************
#* Check expect utility and ftp connection to prod3nt/cdprod02
#**********************************************************************
export STEPNAME=Step040R
echo "    Start   ${STEPNAME}           "$(date)

export FTP_FILE=$RACE/dat/${JOBNAME}_smoketest_file1_keep.dat
export FTP_LOG=$RACE/tmp/${JOBNAME}_ftplog_smoketest.tmp

fileput.exp $FTP_FILE smoketest.txt ${NOVELL}misc ascii | tee $FTP_LOG

#STEP Step050R
#**********************************************************************
#* Check connection to opposite RACE service.
#* If running on radd, check connection to radp
#* If running on radp, check connection to radd
#**********************************************************************
export STEPNAME=Step050R
echo "    Start   ${STEPNAME}           "$(date)

if [ ${THISHOST} != ${TESTHOST} ]
     then
        scp radp:/prod/race/oem/dat/mptr000_smoketest_file1_keep.dat /mdev/race/oem/tmp
else
        scp radd:/mdev/race/oem/dat/mptr000_smoketest_file1_keep.dat /prod/race/oem/tmp
fi


#STEP Step060R
#**********************************************************************
#* Check connection to opposite RACE service.
#* If running on radd, check connection to radp
#* If running on radp, check connection to radd
#**********************************************************************
export STEPNAME=Step060R
echo "    Start   ${STEPNAME}           "$(date)

export FTPSITE_DIRECTORY=${FTP_BUSINESS_PATH}/puerto_rico/${ACT_LVL}/incoming
export FTP_FILELIST=${RACE}/tmp/${JOBNAME}_smoketest_sftplist.tmp 

ssh -nq ${FTP_SITE} "ls -1 ${FTPSITE_DIRECTORY}/*.*" > ${FTP_FILELIST}

echo "\n-------------------------------------------------------------------------------------"
echo "---> Step060R: Check ${RACE}/tmp/${JOBNAME}_smoketest_sftplist.tmp "
echo "-------------------------------------------------------------------------------------"

#end of mpt000_smoketest_prodid.ksh
