#!/bin/ksh
 echo "$Id: xamrpt.ksh,v 1.17 2026/01/05 14:55:10 rd131153 Exp $JOBNAME.ksh,v 1.1 2004/10/30 05:48:01 pg2697 Exp $"
############################################################################
#  PROCNAME:  $JOBNAME                                                     #
#  DESC:      Alternate Parts Data Provider Reporting                      #
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
# 3. XFER_FILE    - Retrieved from parm zxamvbls.prm. Represents file to   #
#                   be ftp'd to unix. This file contains the names of      #
#                   Data Providers for which reports are to be produced.   #             
#                                                                          #
# Example of Parm:                                                         #
# DRIVER_JOB  NT FILENAME            QUALIFIER                             #
# ----------  ---------------------  ---------                             #
# xamr102     keystone_rpt_prov.txt  n/a                                   #
############################################################################

  export XAMUSERID=`cat $RACE/prm/zxampass.prm` 

# uses korne shell 'grep' command to get variable values from parm file

  XFER=` grep $JOBNAME $RACE/prm/zxamvbls.prm | awk '{print $2}'`
  QUALIFIER=` grep $JOBNAME $RACE/prm/zxamvbls.prm | awk '{print $3}'`
  EMAILFTP=` grep $JOBNAME $RACE/prm/zxamvbls.prm | awk '{print $4}'`
 
  export XFER_FILE=$XFER
  export RPTDATE=$(date +'%C%y%m%d%H%M%S')
  
# P. Becotte - 10/2017 added
  echo "${ACT_LVL} = " ${ACT_LVL}

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

  export NTFILE=$XFER_FILE
  export UNXFILE=$RACE/tmp/${JOBNAME}_rpt_prov.xfr
# Change rj132422 - 20260424 - Remove prod3nt dependency; use NFS-mounted path
  export NTDIR=${ALTP_DIR}
  export FTPLOG=$RACE/tmp/${JOBNAME}_rpt_prov_ftp.tmp

  rm -f $UNXFILE
# Copy from NFS, then strip CR to preserve the former 'ascii' fileget behavior (CRLF -> LF)
  cp ${NTDIR}/${NTFILE} ${UNXFILE} > $FTPLOG 2>&1
  tr -d '\r' < ${UNXFILE} > ${UNXFILE}.tmp && mv ${UNXFILE}.tmp ${UNXFILE}

  if [[ ! -s ${UNXFILE} ]]
    then
       echo " ***** error ***** file copy failed or source file is empty \n"
       print " SOURCE = ${NTDIR}/${NTFILE} "
       abndalrt.ksh ftp_get
  else
       unixcount=$(wc -c ${UNXFILE} | awk '{print $1}')
       echo " file copy is good - UNIX byte count = $unixcount "
  fi


#STEP Step200R
#***************************************************************************
#* STEP200R                                                                *
#* 1. MAKE SURE DATA IS VOID OF ASCII CONTROL CHARACTERS                   *
#***************************************************************************
  export STEPNAME=Step200R
  echo "    Start   ${STEPNAME}           "$(date)

  export DD_CLEANIN="$RACE/tmp/${JOBNAME}_rpt_prov.xfr"
  export DD_CLEANOU="$RACE/tmp/${JOBNAME}_rpt_prov_clean.tmp"

  rm -f $DD_CLEANOU

  cat $DD_CLEANIN | tr -d '\032' |\
  tr '\000-\011\013-\037\177' '[^*]' |\
  tr '\240' '[ *]' |\
  sed 's/\^$//' > $DD_CLEANOU


#STEP Step300R
#********************************************************************
#* STEP300R - PRODUCE REPORTS AND EMAIL LOOP AS FOLLOWS:            *
#* 1. GET PROVIDER NAME FROM PARM FILE                              *
#* 2. EXECUTE SQL PROGRAM TO REPORT SUPPLIER(S) ASSOC'D TO PROVIDER *
#* 3. EMAIL REPORT TO DATA PROVIDER CONTACT(S)                      *
#********************************************************************
  export STEPNAME=Step300R
  echo "    Start   ${STEPNAME}           "$(date)

  
  export SQL_PARM_PATH=$OBJ_TMPDIR
  export SQL_PROV_PARM=${JOBNAME}_rpt_prov_clean.tmp
  export SQL_EMAIL_PARM=${JOBNAME}_email_parm.tmp
  export SQL_RPTS_PATH=$OBJ_TMPDIR
  export SQL_SUM_PATH=$OBJ_RPTDIR
  export SQL_SUM_RPT=${JOBNAME}a_provrpts_${RPTDATE}.rpt
  

sqlplus << CODE_BLOCK 2>&1 > $LOG
$XAMUSERID
           
SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 250;
SET SERVEROUTPUT ON; 
whenever sqlerror exit sql.sqlcode
       
exec sp_provider_exception_rpts('$JOBNAME','$SQL_PARM_PATH','$SQL_PROV_PARM','$SQL_EMAIL_PARM','$SQL_RPTS_PATH','$SQL_SUM_PATH','$SQL_SUM_RPT');

QUIT;
CODE_BLOCK

email_rpt.ksh "${JOBNAME}a"
rpt_log_retention.ksh "${JOBNAME}a"

# P. Becotte - 10/2017 changed to restartable
#STEP Step700R
#********************************************************************
#* STEP700                                                          *
#* THIS STEP LOOPS UNTIL ALL DATA PROVIDERS FOR WHICH REPORTS WERE  *
#* PRODUCED, HAVE BEEN PROCESSED. (BASED ON EMAIL_PARM)             *
#* 1. GET RECIP INFO FROM EMAIL PARM FILE                           *
#* 2. ZIP PROVIDER'S REPORT FILES                                   *
#* 3. IF REPORTS ARE TO BE EMAILED, ISSUE MAILX COMMAND             *
#*    IF REPORTS ARE TO BE FTP'D, ISSUE SCP COMMAND                 *
#* 4. DELETE ZIP FILE.                                              *
#********************************************************************
  export STEPNAME=Step700R
  echo "    Start   ${STEPNAME}           "$(date)

export MAIL_LIST=$RACE/tmp/${JOBNAME}_email_parm.tmp
export MAIL_TEXT=$RACE/prm/zxamrptb.prm
export FTP_TEXT=$RACE/prm/zxamrptc.prm
export ZIP_FILE=$RACE/tmp/${JOBNAME}_mail.zip

# P. Becotte - changed .zzz to .zip
export FTPFILE=$FTP_SITE:$FTP_BUSINESS_PATH/$QUALIFIER/$ACT_LVL/outgoing/mitch_exc_rpts.zip
export PDF_FILE=$RACE/prm/AlternatePartPriceVerification.pdf

# P. Becotte - added FTPFILENAME
export FTPFILENAME=mitch_exc_rpts.zip

export CONST_DA="DATA_ANALYST"
export CONST_EMAIL="EMAIL"
export CONST_FTP="FTP"

# P. Becotte - added SFTP
export CONST_SFTP="SFTP"

cd $RACE/tmp

rm -f ${ZIP_FILE}

while read LINE
do 
    export PROVIDER=`echo $LINE | cut -f1 -d"|"`
    export RECIP=`echo $LINE | cut -f2 -d"|"`
    export ATTACH1=`echo $LINE | cut -f3 -d"|"` 
    export ATTACH2=`echo $LINE | cut -f4 -d"|"`
    export ATTACH3=`echo $LINE | cut -f5 -d"|"`
    
#Added in AES-3181: START
    #Get path for new log file to write the sqlplus values.
    LOG_FILE=$RACE/tmp/${JOBNAME}_validate_ftp_rpts_$(date +%Y%m%d_%H%M%S).log
#SQLPLUS block to call the procedure "sp_validate_ftp_rpts" which responds if the supplier should send their information to the Mitchell FTP(on a supplier specific forlder) or continue already existing normal process of sending through e-mail.
sqlplus << CODE_BLOCK 2>&1 > $LOG_FILE
    $XAMUSERID
               
    SET SERVEROUTPUT ON SIZE 1000000;
    SET HEADING OFF;
    SET FEEDBACK OFF;
    SET VERIFY OFF;
    SET LINESIZE 1000;
    SET PAGESIZE 0;
    SET TRIMSPOOL ON;
    SET TRIMOUT ON;
    WHENEVER SQLERROR EXIT SQL.SQLCODE;
    
    DECLARE
      v_xamrpt_ftp_reporting     VARCHAR2(1);
      v_mitchell_ftp_folder_name VARCHAR2(100);
    BEGIN
      sp_validate_ftp_rpts(pi_xamrpt_supplier_name        => '${PROVIDER}'
                         , po_xamrpt_ftp_reporting        => v_xamrpt_ftp_reporting
                         , po_mitchell_ftp_supp_fold_name => v_mitchell_ftp_folder_name
                          );
      
      -- Print the output values in a format it will be easily captured by shell
      DBMS_OUTPUT.PUT_LINE('FTP_REPORTING=' || NVL(v_xamrpt_ftp_reporting, 'N'));
      DBMS_OUTPUT.PUT_LINE('FOLDER_NAME=' || NVL(v_mitchell_ftp_folder_name, ''));
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR_CODE=' || SQLCODE);
        DBMS_OUTPUT.PUT_LINE('ERROR_MSG=' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('FTP_REPORTING=N');
        DBMS_OUTPUT.PUT_LINE('FOLDER_NAME=');
    END;
    /
    
    QUIT;
CODE_BLOCK
 
    # Check if there was an error during SQLPlus execution
    SQL_EXIT_CODE=$?
    if [ $SQL_EXIT_CODE -ne 0 ]; then
        echo "Error executing SQLPlus. Exit code: $SQL_EXIT_CODE"
        echo "Check log file for more details: $LOG_FILE"
        exit 1
    fi
    
    # Extract output values from the log file
    XAMRPT_FTP_REPORTING=$(grep "FTP_REPORTING=" $LOG_FILE | tail -1 | cut -d'=' -f2)
    PROVIDER_FOLDER_NAME=$(grep "FOLDER_NAME=" $LOG_FILE | tail -1 | cut -d'=' -f2)
    ERROR_CODE=$(grep "ERROR_CODE=" $LOG_FILE | cut -d'=' -f2)
    
    # Check if there was an error
    if [ -n "$ERROR_CODE" ]; then
        ERROR_MSG=$(grep "ERROR_MSG=" $LOG_FILE | cut -d'=' -f2-)
        echo "Error executing procedure: $ERROR_CODE - $ERROR_MSG"
    fi
    
    # Verify if values were captured correctly
    if [ -z "$XAMRPT_FTP_REPORTING" ]; then
        XAMRPT_FTP_REPORTING="N"
        echo "Warning: Could not retrieve FTP_REPORTING value. Using default value 'N'."
    fi
    
    # Display results
    echo "Validation Results:"
    echo "----------------------------------------"
    echo "Supplier: $PROVIDER"
    echo "FTP Reporting: $XAMRPT_FTP_REPORTING"
    echo "FTP Folder: ${PROVIDER_FOLDER_NAME:-'<Not defined>'}"
    echo "----------------------------------------"
    #AES-3181: END

    # Added in AES-3146 - Rafael Balen Deitos
    #PROVIDER_FOLDER_NAME=$(echo "${PROVIDER}" | tr -cd '[:alnum:] ' | tr ' ' '_' | tr '[:upper:]' '[:lower:]') #Commented in AES-3181 -Changing the process so this is not needed anymore
    FTPBIGFILE=$FTP_SITE:$FTP_BUSINESS_PATH/$PROVIDER_FOLDER_NAME/$ACT_LVL/outgoing/mitch_exc_rpts.zip

# P. Becotte - added 
    export ATTACH4=`echo $LINE | cut -f6 -d"|"`
    export ATTACH5=`echo $LINE | cut -f7 -d"|"`

# P. Becotte - added echo
    echo "PROVIDER =" $PROVIDER
    echo "ATTACH1 =" ${ATTACH1}  --'prov_suplr.txt';
    echo "ATTACH2 =" ${ATTACH2}  --'prov_excdtl.txt';
    echo "ATTACH3 =" ${ATTACH3}  --'prov_excsum.txt';
    echo "ATTACH4 =" ${ATTACH4}  --'prov_excdtl.xlsx';
    echo "ATTACH5 =" ${ATTACH5}  --'prov_excdtl_excel.txt'
  
    if [ ${RECIP} = ${CONST_DA} ] 
      then
        RECIP="$(head -n +1 ${RACE}/prm/zxamrpta.prm | awk '{print $1}')"
        # P. Becotte - added echo
        echo "RECIP =" ${RECIP}
    fi 
  
  #P. Becotte - added to determine how many worksheets to created
    export RECCNT=$(wc -l $RACE/tmp/${ATTACH5}  | awk '{print $1}')
    echo "RECCNT: " $RECCNT
    export NUMSHEETS=`expr $RECCNT / 1000000`
    echo "NUMSHEETS: " $NUMSHEETS
    export NUMSHEETSADD1=0
    NUMSHEETSADD1=`expr $NUMSHEETS + 1`

  #P. Becotte - need to set tempdir to perl script because used up more than 2GB
    export TMPDIR=/$ACT_LVL/race/share/tmp

  #P. Becotte - added execution of perl script to create excel file 
  # pass in source file, excel file, number of sheets to create, temporary directory 
    conv_txt_excel.pl $RACE/tmp/$ATTACH5 $RACE/tmp/$ATTACH4 $NUMSHEETSADD1 $TMPDIR

    echo "data/time: " $(date)
  #P. Becotte - removed -l  for zip below to not Translate the Unix end-of-line character LF into the MSDOS convention CR LF because this caused issue for excel file
    zip -j -P mapp -q $ZIP_FILE $ATTACH1 $ATTACH3 $ATTACH4
    echo "data/time: " $(date)
    
    echo "EMAILFTP = " ${EMAILFTP}
    
    #Added in AES-3181: Now it first verifies if the supplier is configured to receive the reports via FTP.
    if [ "$XAMRPT_FTP_REPORTING" = "Y" ]; then
       echo "This supplier is configured to receive reports via FTP."
       if [ -n "$PROVIDER_FOLDER_NAME" ]; then
         echo "FTP folder configured: $PROVIDER_FOLDER_NAME"
         
         scp $ZIP_FILE $FTPBIGFILE || {
               #IF the FTP errored out, it means something is erroring out. Maybe wrong permissions on supplier folder or the folder has the incorrect name.
               EMAIL=$(grep -i "@mitchell.com" "$FTP_TEXT" | tr -d ' ' | tail -1)
               
               echo "email = " $EMAIL
               (echo There was an error while generating the supplier file in the FTP. Please forward this e-mail to Editorial Systems team for them to verify what is causing the error.  Thank you. ) \
               | mailx -r production.control.mapp@mitchell.com -s "${PROVIDER} - Exception Reports" ${RECIP}
               #abort process so Responsible can restart at STEP700R again when FTP is set OR restart the whole process again.
               exit 1
            }
            #If the FTP worked, we just send a notification e-mail to supplier
            (echo 
            cat $FTP_TEXT) \
            | mailx -r production.control.mapp@mitchell.com -s "${PROVIDER} - Exception Reports" ${RECIP}
         
         echo "FTP Processing completed successfully."
       else
         echo "ERROR: Supplier configured to send file to FTP, but has no folder name defined."
         #abort process so Responsible can restart at STEP700R again when FTP is set OR restart the whole process again.
         exit 1
       fi
    else
      if [ ${EMAILFTP} = ${CONST_EMAIL} ]
      then  
        # Added in AES-3146 - Start
        # Verify attachment file size
        PDF_SIZE=$(stat -c %s "$PDF_FILE" 2>/dev/null || stat -f %z "$PDF_FILE")
        ZIP_SIZE=$(stat -c %s "$ZIP_FILE" 2>/dev/null || stat -f %z "$ZIP_FILE")
        TEXT_SIZE=$(stat -c %s "$MAIL_TEXT" 2>/dev/null || stat -f %z "$MAIL_TEXT")
        TOTAL_SIZE=$((PDF_SIZE + ZIP_SIZE + TEXT_SIZE + 1000))  # 1000 bytes for overhead
        
        # Validate File size limit approximately 25MB
        if [ $TOTAL_SIZE -gt 25876767 ]; then
            echo "Attachment File exceeds e-mail server output size limit. Starting FTP process."
            # Code to save files in FTP
            
            scp $ZIP_FILE $FTPBIGFILE || {
               #IF the FTP errored out, it means the path does not exist, so we must send e-mail for responsible of the process in Mitchell team.
               EMAIL=$(grep -i "@mitchell.com" "$FTP_TEXT" | tr -d ' ' | tail -1)
               
               echo "email = " $EMAIL
               (echo The file size is too big for and e-mail attachment. We have to sent it through FTP for the supplier. Please get in touch with Editorial Systems team for them to setup the supplier FTP access accordingly and also get in touch with the supplier to warn about the new process.  Thank you. ) \
               | mailx -r production.control.mapp@mitchell.com -s "${PROVIDER} - Exception Reports" ${RECIP}
               #abort process so Responsible can restart at STEP700R again when FTP is set OR restart the whole process again.
               exit 1
            }
            #If the FTP worked, we just send a notification e-mail to supplier
            (echo 
            cat $FTP_TEXT) \
            | mailx -r production.control.mapp@mitchell.com -s "${PROVIDER} - Exception Reports" ${RECIP}
        else
            # P. Becotte - changed .zzz to .zip
            (echo Please refer to the attached Readme.txt and the PDF file for information regarding the reports.  Thank you. ;uuencode $MAIL_TEXT Readme.txt;uuencode $PDF_FILE AlternatePartPriceVerification.pdf;uuencode $ZIP_FILE mitch_exc_rpts.zip) \
            | mailx -r production.control.mapp@mitchell.com -s "${PROVIDER} - Exception Reports" ${RECIP}
        fi
        # Added in AES-3146 - End
       elif [ ${EMAILFTP} = ${CONST_FTP} ]
        then
         scp $ZIP_FILE $FTPFILE
         (echo 
         cat $FTP_TEXT) \
         | mailx -r production.control.mapp@mitchell.com -s "${PROVIDER} - Exception Reports" ${RECIP}
      # P. Becotte - Added SFTP
      elif [ ${EMAILFTP} = ${CONST_SFTP} ]
        then
         export FTPLOGINPARM=$RACE/prm/zxamftp_napa.prm
         export USER=$(head -n1 $FTPLOGINPARM | awk '{print $1}')
         export PASSWD=$(head -n1 $FTPLOGINPARM  | awk '{print $2}')
         fileput_sftp.exp $USER $PASSWD $ZIP_FILE /$ACT_LVL/outgoing $FTPFILENAME
          (echo 
           cat $FTP_TEXT) \
       	| mailx -r production.control.mapp@mitchell.com -s "${PROVIDER} - Exception Reports" ${RECIP}
      else
         echo "ERROR WITH EMAIL, SFTP, OR FTP FILES"
         exit 1
      fi
    fi
  
  #* CLEAR ZIP FILE FOR NEXT SET OF REPORTS
  
# P. Becotte - changed $ATTACH3 to $ATTACH4
  zip -d $ZIP_FILE $ATTACH1 $ATTACH3 $ATTACH4
  
done<$MAIL_LIST


#STEP Step999R
#********************************************************************
#* STEP999R                                                         *
#* 1. REMOVE TEMP FILES                                             *
#********************************************************************
  export STEPNAME=Step999R
  echo "    Start   ${STEPNAME}           "$(date)
 
  rm -f $RACE/tmp/${JOBNAME}*

############################################################################
# END 
############################################################################
