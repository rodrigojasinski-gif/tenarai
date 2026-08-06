#!/bin/ksh

set -xv
#$Id: xam080.ksh,v 1.10 2017/04/11 20:15:34 pb0690 Exp $
export PROCNAME=$(basename $0 .ksh_run)
trap 'abndalrt.ksh $?' err
#############################################################################################
# SCRIPT NAME: xam080.ksh
# SCRIPT DESC:  Alternate Part extract for uParts
#  1) Pull data from RACE for Alternate parts, zip code range, and part supplier data provider price program information
#     NOTE: Spool was used verses execute PL/SQL procedure because it only took 25 minutes to produce the part file will spooling
#           verses utl_file took 1 hour and 15 minutes.
#  2) Remove SQL statements in file and put in /tmp, then move back to /dat
#  3) Zip files
#  4) Create GDG to save versions of 3 data file
#  5) FTP
#  6) Email notification
#############################################################################################
#Modification History
#Date        User ID   Description
#==========  =======   ==============================================
#2017/03/01  pb0690    Intial Version
#2017/03/17  pb0690    Changed to spool to /tmp then remove SQL lines and create file in /dat
#                      Also broke up step to create GDG's in case restart is needed
#                      Added Step999R to remove /tmp files
#2017/03/28  pb0690	   Added code to check if data files were produced, if not abend
#                      Added FTP logic
#2017/04/03  pb0690    Fixed special character issue in Step010R
#                      There was this error:  sqlplus </tmp/xamw080_xam080.ksh_run[71]: syntax error at line 97 : `<' unexpected
#2017/04/11  pb0690    Changed code to .pipe to file and generate .gz file and added steps to remove 'SQL> '
#############################################################################################
print ProcessId = $$

export XAMUSERID=`cat $RACE/prm/zxampass.prm`

export PART_FILENAME=mapp_parts_upart.txt
export ZIPRANGE_FILENAME=mapp_ziprange_upart.txt
export SUPLR_PRVDR_PRGRM_FILENAME=mapp_suplrprvdprgrm_upart.txt

export PART_PIPE_FILE=${PART_FILENAME}.pipe
export PART_SPOOL_FILE=${PART_FILENAME}.gz
export ZIP_PIPE_FILE=${ZIPRANGE_FILENAME}.pipe
export ZIP_SPOOL_FILE=${ZIPRANGE_FILENAME}.gz
export SUPLR_PIPE_FILE=${SUPLR_PRVDR_PRGRM_FILENAME}.pipe
export SUPLR_SPOOL_FILE=${SUPLR_PRVDR_PRGRM_FILENAME}.gz

#STEP Step010R
  export STEPNAME=Step010R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S') 
##########################################################################
# STEP NAME:  Step010R
# STEP DESC:  Run SQL to get part data
#             NOTE: A spool was done verses the SQL code in a PL/ SQL procedure
#                   because it took about 66% faster.  Also, the sqlplus information 
#                   is in this script because the spool was causing all the output
#                   records to be put in the log file.
##########################################################################

mknod $RACE/tmp/${JOBNAME}_$PART_PIPE_FILE p
gzip < $RACE/tmp/${JOBNAME}_$PART_PIPE_FILE > $RACE/tmp/${JOBNAME}_$PART_SPOOL_FILE &

sqlplus << CODE_BLOCK 2>&1 > $LOG
$XAMUSERID

SET FEEDBACK OFF;
SET ECHO OFF;
SET VERIFY OFF;
SET PAGESIZE 0;
SET HEADING OFF;
SET TERM OFF;
SET WRAP OFF;
SET TRIMSPOOL ON;
SET LINESIZE 250;
SET ARRAYSIZE 100;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

spool $RACE/tmp/${JOBNAME}_$PART_PIPE_FILE
@$RACE/bin/xam_part_altpart_xref_sql.ksh
spool off
 
QUIT;
CODE_BLOCK

#STEP Step015R
  export STEPNAME=Step015R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S') 
##########################################################################
# STEP NAME:  Step015R
# STEP DESC:  Remove the 'SQL> ' lines from .gz file
##########################################################################

# take /tmp/*.gz from put in /dat/*.gz
gzip -cd $RACE/tmp/${JOBNAME}_${PART_SPOOL_FILE} | grep -v -F 'SQL> ' | gzip > $RACE/dat/${JOBNAME}_${PART_SPOOL_FILE}

if [ -f $RACE/dat/${JOBNAME}_${PART_SPOOL_FILE} ];
then
   echo "File $RACE/dat/${JOBNAME}_${PART_SPOOL_FILE} exists"
   cnt=$(gzip -cd $RACE/dat/${JOBNAME}_${PART_SPOOL_FILE}  | wc -l)  
   if [ $cnt -lt 4 ] ; 
   then
          echo "$RACE/dat/${JOBNAME}_${PART_SPOOL_FILE} is less than 4 lines"
          $(abndalrt.ksh 911)
   fi
else
   echo "File $RACE/dat/${JOBNAME}_${PART_SPOOL_FILE} does not exist"
   $(abndalrt.ksh 911)
fi

#STEP Step020R
  export STEPNAME=Step020R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S') 
##########################################################################
# STEP NAME:  Step020R
# STEP DESC:  Run SQL to get zip code range data
#             NOTE: A spool was done verses the SQL code in a PL/ SQL procedure
#                   because it took about 66% faster.  Also, the sqlplus information 
#                   is in this script because the spool was causing all the output
#                   records to be put in the log file.
##########################################################################

mknod $RACE/tmp/${JOBNAME}_$ZIP_PIPE_FILE p
gzip < $RACE/tmp/${JOBNAME}_$ZIP_PIPE_FILE > $RACE/tmp/${JOBNAME}_$ZIP_SPOOL_FILE &

sqlplus << CODE_BLOCK 2>&1 > $LOG
$XAMUSERID

SET FEEDBACK OFF;
SET ECHO OFF;
SET VERIFY OFF;
SET PAGESIZE 0;
SET HEADING OFF;
SET TERM OFF;
SET WRAP OFF;
SET TRIMSPOOL ON;
SET LINESIZE 60;
SET ARRAYSIZE 100;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

spool $RACE/tmp/${JOBNAME}_$ZIP_PIPE_FILE
@$RACE/bin/xam_zip_code_range_sql.ksh
spool off
  
QUIT;
CODE_BLOCK

#STEP Step025R
  export STEPNAME=Step025R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S') 
##########################################################################
# STEP NAME:  Step025R
# STEP DESC:  Remove the 'SQL> ' lines from .gz file
##########################################################################

gzip -cd $RACE/tmp/${JOBNAME}_${ZIP_SPOOL_FILE} | grep -v -F 'SQL> ' | gzip > $RACE/dat/${JOBNAME}_${ZIP_SPOOL_FILE}

if [ -f $RACE/dat/${JOBNAME}_${ZIP_SPOOL_FILE} ];
then
   echo "File $RACE/dat/${JOBNAME}_${ZIP_SPOOL_FILE} exists"
   cnt=$(cat $RACE/dat/${JOBNAME}_${ZIP_SPOOL_FILE}  | wc -l)  
   if [ $cnt -lt 4 ] ; 
   then
          echo "$RACE/dat/${JOBNAME}_${ZIP_SPOOL_FILE} is less than 4 lines"
          $(abndalrt.ksh 911)
   fi
else
   echo "File $RACE/dat/${JOBNAME}_${ZIP_SPOOL_FILE} does not exist"
   $(abndalrt.ksh 911)
fi

#STEP Step030R
  export STEPNAME=Step030R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S') 
##########################################################################
# STEP NAME:  Step030R
# STEP DESC:  Run SQL to get part supplier, data provider and price program data
#             NOTE: A spool was done verses the SQL code in a PL/ SQL procedure
#                   because it took about 66% faster.  Also, the sqlplus information 
#                   is in this script because the spool was causing all the output
#                   records to be put in the log file.
##########################################################################

mknod $RACE/tmp/${JOBNAME}_$SUPLR_PIPE_FILE p
gzip < $RACE/tmp/${JOBNAME}_$SUPLR_PIPE_FILE > $RACE/tmp/${JOBNAME}_$SUPLR_SPOOL_FILE &

sqlplus << CODE_BLOCK 2>&1 > $LOG
$XAMUSERID

SET FEEDBACK OFF;
SET ECHO OFF;
SET VERIFY OFF;
SET PAGESIZE 0;
SET HEADING OFF;
SET TERM OFF;
SET WRAP OFF;
SET TRIMSPOOL ON;
SET LINESIZE 300;
SET ARRAYSIZE 100;
SET SERVEROUTPUT OFF;
whenever sqlerror exit sql.sqlcode

spool $RACE/tmp/${JOBNAME}_$SUPLR_PIPE_FILE
@$RACE/bin/xam_altpart_data_supplier_sql.ksh
spool off

QUIT;
CODE_BLOCK

#STEP Step035R
  export STEPNAME=Step035R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S') 
##########################################################################
# STEP NAME:  Step035R
# STEP DESC:  Remove the 'SQL> ' lines from .gz file
##########################################################################

# take /tmp/*.gz from put in /dat/*.gz
gzip -cd $RACE/tmp/${JOBNAME}_${SUPLR_SPOOL_FILE} | grep -v -F 'SQL> ' | gzip > $RACE/dat/${JOBNAME}_${SUPLR_SPOOL_FILE}

if [ -f $RACE/dat/${JOBNAME}_${SUPLR_SPOOL_FILE} ];
then
   echo "File $RACE/dat/${JOBNAME}_${SUPLR_SPOOL_FILE} exists"
   cnt=$(gzip -cd $RACE/dat/${JOBNAME}_${SUPLR_SPOOL_FILE}  | wc -l)  
   if [ $cnt -lt 4 ] ; 
   then
          echo "$RACE/dat/${JOBNAME}_${SUPLR_SPOOL_FILE} is less than 4 lines"
          $(abndalrt.ksh 911)
   fi
else
   echo "File $RACE/dat/${JOBNAME}_${SUPLR_SPOOL_FILE} does not exist"
   $(abndalrt.ksh 911)
fi

#STEP Step070R
  export STEPNAME=Step070R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S') 
##########################################################################
# STEP NAME:  Step070R
# STEP DESC:  Build GDG file for Alternate Part file
##########################################################################

export DD_FILE1=$RACE/dat/${JOBNAME}_${PART_SPOOL_FILE}
export DD_FILE2=$( setgdg.ksh \
                "$RACE/dat/${JOBNAME}_${PART_SPOOL_FILE}(+1)" NEW 3)

cp $DD_FILE1 $DD_FILE2 2>&1

#STEP Step071R
  export STEPNAME=Step071R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S') 
##########################################################################
# STEP NAME:  Step071R
# STEP DESC:  Build GDG file for Zip Code Range File
##########################################################################

export DD_FILE1=$RACE/dat/${JOBNAME}_${ZIP_SPOOL_FILE}
export DD_FILE2=$( setgdg.ksh \
                "$RACE/dat/${JOBNAME}_${ZIP_SPOOL_FILE}(+1)" NEW 3)

cp $DD_FILE1 $DD_FILE2 2>&1

#STEP Step072
  export STEPNAME=Step072R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S') 
##########################################################################
# STEP NAME:  Step072R
# STEP DESC:  Build GDG file for Alternate Part Supplier, data provider, and price program
##########################################################################

export DD_FILE1=$RACE/dat/${JOBNAME}_${SUPLR_SPOOL_FILE}
export DD_FILE2=$( setgdg.ksh \
                "$RACE/dat/${JOBNAME}_${SUPLR_SPOOL_FILE}(+1)" NEW 3)

cp $DD_FILE1 $DD_FILE2 2>&1

#STEP Step080R
  export STEPNAME=Step080R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S') 
##########################################################################
# STEP NAME:  Step080R
# STEP DESC:  FTP files (Note: Ensure binary is set prior to sending)
##########################################################################

#Retrieve the following from parm file:
#1) user id
#2) password
#3) ftp server name
#4) remote directory (DefaultDir if no change required)
#5) file type (defaults to binary)

export FTPLOGINPARM=$RACE/prm/xam080_ftp_uparts.prm

if [[ ! -s ${FTPLOGINPARM} ]]
then
  echo "ABEND JOB: ${JOBNAME}.ksh on ${SERVER_NAME}"  > $ABEND_TEXT
  echo "NO FTPLOGINPARM FILE FOUND" >> $ABEND_TEXT
  echo "FTPLOGINPARM: ${FTPLOGINPARM}"  >> $ABEND_TEXT
  echo " " >> $ABEND_TEXT
  $( abndalrt.ksh 911 )
fi

export USER=$(head -n1 $FTPLOGINPARM | awk '{print $1}')
export PASSWD=$(head -n1 $FTPLOGINPARM  | awk '{print $2}')
export HOST=$(head -n1 $FTPLOGINPARM  | awk '{print $3}')
export REMOTEDIR=$(head -n1 $FTPLOGINPARM  | awk '{print $4}')
export FILETYPE=$(head -n1 $FTPLOGINPARM  | awk '{print $5}')

cd $RACE/dat
export JOBRUNUSERID=$(whoami)
echo "JOBRUNUSERID: " $JOBRUNUSERID

if [ "${JOBRUNUSERID}" = "race_b1" ]
then
 export RSAKEYPATH=/${ACT_LVL}/race/altp/prm/.ssh/mitchell_to_uparts_sftp_rsa
else
 export RSAKEYPATH=/home/${JOBRUNUSERID}/.ssh/mitchell_to_uparts_sftp_rsa
fi

sftp  -oIdentityFile=${RSAKEYPATH} ${USER}@${HOST} <<EOF
put $RACE/dat/${PART_FILENAME}.gz
put $RACE/dat/${ZIPRANGE_FILENAME}.gz
put $RACE/dat/${SUPLR_PRVDR_PRGRM_FILENAME}.gz
bye
EOF

#STEP Step090R
  export STEPNAME=Step090R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S') 
##########################################################################
# STEP NAME:  Step090R
# STEP DESC:  Send job email notification if email information exists in:
#             email_address, email_message, email_xref
#  4 parameters are read in:
#  - There are 2 parameters required: PROCESS_NAME and EMAIL_NAME
#  - There are 2 optional parameters: FILEDIR and ATTACHFILE
##########################################################################

export PROCESS_NAME=${JOBNAME}
export EMAIL_NAME=${JOBNAME}_
export FILEDIR=''
export ATTACHFILE=''

email_notify.ksh ${PROCESS_NAME} ${EMAIL_NAME} ${FILEDIR} ${ATTACHFILE} 

#STEP Step999R
  export STEPNAME=Ste999R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S') 
##########################################################################
# STEP NAME:  Step999R
# STEP DESC:  Remove /tmp files
##########################################################################

rm $RACE/tmp/${JOBNAME}_*

############################################################################
#  END                                                                     
############################################################################
