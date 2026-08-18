#!/bin/ksh
echo "RCS $Id: oem_job_notify.ksh,v 1.2 2008/10/09 22:17:44 jw97143 Exp $"
#*****************************************************************************************
# PROCNAME oem_job_notify.ksh
# PURPOSE  Check oem_job_notify table to see an email should be sent
#          and update/reset values when an email is sent
#*****************************************************************************************
trap 'oem_abndalrt.ksh $?' err
MPTUSERID=`cat ${RACE}/prm/zmptpass.prm`
LOGFILE=$(basename ${JOBLOGNAME})
#*****************************************************************************************

WORKFILE=${JOBNAME}_oem_job_notify.tmp
#-----------------------------------------------------------------------------------------
(sqlplus -s << % 2>&1)
${MPTUSERID}
SET VERIFY OFF
SET FEEDBACK OFF
SET TAB OFF
SET LINESIZE 100
SET PAGES 0
SET TRIMSPOOL ON
whenever sqlerror exit sql.sqlcode
    exec pkg_oem_job_notify.p_oem_job_notify_sel_01(p_job  =>          '${JOBNAME}',    \
                                                    p_tmp_directory => '${OBJ_TMPDIR}', \
                                                    p_tmp_filename  => '${WORKFILE}',   \
                                                    p_log_directory => '${OBJ_LOGDIR}', \
                                                    p_log_filename  => '${LOGFILE}');
QUIT;
%
#-----------------------------------------------------------------------------------------
WORKFILE=${RACE}/tmp/${WORKFILE}

SEND_EMAIL_FLAG=`cat ${WORKFILE}       | cut -f2  -d"^"`
EMAIL_ADDRESS_LIST=`cat ${WORKFILE}    | cut -f3  -d"^"`
EMAIL_BODY=`cat ${WORKFILE}            | cut -f4  -d"^"`
RESET_SEND_EMAIL_FLAG=`cat ${WORKFILE} | cut -f5  -d"^"`

# Is notification required?
if [ -z "${SEND_EMAIL_FLAG}" ]
then
  echo "Notification NOT Required"
  echo " "
else
  if [ "${SEND_EMAIL_FLAG}" = "Y" ]
  then
    #************************************************************************************
    # Send email notification
    #************************************************************************************
    MAIL_SUBJECT="Notification that Job: ${JOBNAME} is Running" 
    EMAIL_BODY_FILE=${RACE}/tmp/${JOBNAME}_email_body.tmp    
    echo ${JOBNAME} ": " ${EMAIL_BODY} > ${EMAIL_BODY_FILE}
      
    # Build the list of email addresses 
    EMAIL_ADDRESS_LIST="${EMAIL_ADDRESS_LIST} NOMORE"
    EMAIL_ADDRESS_PTR=1
    # Extract the email address based on EMAIL_ADDRESS_PTR value - delimited by a space. 
    # -f flag points to the field number
    # -d flag is the delimiter
    EMAIL_ADDRESS=`echo ${EMAIL_ADDRESS_LIST} | cut -f${EMAIL_ADDRESS_PTR} -d" "`
    while [ ! -z "${EMAIL_ADDRESS}" ]
    do
      if [ "${EMAIL_ADDRESS}" = "NOMORE" ]
      then
         break
      fi
      if [ ${THISHOST} = ${TESTHOST} ]
      then
         mailx -s "TEST - ${MAIL_SUBJECT}" "${EMAIL_ADDRESS}" < "${EMAIL_BODY_FILE}"
      else
         mailx -s "${MAIL_SUBJECT}" "${EMAIL_ADDRESS}" < "${EMAIL_BODY_FILE}"
      fi          
      EMAIL_ADDRESS_PTR=`expr $EMAIL_ADDRESS_PTR + 1`
      EMAIL_ADDRESS=`echo ${EMAIL_ADDRESS_LIST} | cut -f${EMAIL_ADDRESS_PTR} -d" "`
    done

#----------------------------------------------------------------------------------------
# Set the email sent date AND reset the send email flag if it needs to be reset
(sqlplus -s << % 2>&1)
${MPTUSERID}
SET VERIFY OFF
SET FEEDBACK OFF
SET TAB OFF
SET LINESIZE 100
SET PAGES 0
SET TRIMSPOOL ON
whenever sqlerror exit sql.sqlcode
    exec pkg_oem_job_notify.p_oem_job_notify_upd_01(p_job           => '${JOBNAME}',    \
                                                    p_log_directory => '${OBJ_LOGDIR}', \
                                                    p_log_filename  => '${LOGFILE}');
QUIT;
%
#----------------------------------------------------------------------------------------

  fi
fi

#*****************************************************************************************
# END oem_job_notify.ksh
#*****************************************************************************************
