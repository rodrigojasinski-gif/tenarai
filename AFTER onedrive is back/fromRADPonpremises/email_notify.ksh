#!/bin/ksh
#$Id: email_notify.ksh,v 1.4 2017/03/07 23:45:53 pb0690 Exp $
set -xv
##########################################################################
# JOB NAME: email_notify.ksh
# JOB DESC: Execute pkg_email_notify.p_send_email to email recipients
##########################################################################
# Modification History
# Date        User-id    Description
# ==========  ======     =========================================
# 2013/09/13  PB0690     Created script
# 2013/10/18  PB0690	    Changed email_abbr to email_name
# 2013/10/29  PB0690	    Added 2 parameters to attach file to email
# 2017/03/06  PB0690     Added SHAREUSERID
##########################################################################

export SHAREUSERID=`cat /$ACT_LVL/race/share/prm/zsharepass.prm`

# read in the 4 parameters into these values
JOBNAME=$1
EMAIL_NAME=$2
FILEDIR=$3
ATTACHFILE=$4

export HOST_NAME=$(hostname)

sqlplus << CODE_BLOCK 2>&1 > $LOG
$SHAREUSERID
SET SERVEROUTPUT ON FORMAT WRAPPED;
whenever sqlerror exit sql.sqlcode
    exec pkg_email_notify.p_send_email(p_in_process_name        => '${JOBNAME}',    \
                                       p_in_email_name          => '${EMAIL_NAME}',    \
                                       p_in_act_lvl             => '${ACT_LVL}',    \
					    p_in_host_name           => '${HOST_NAME}',    \
                                       p_in_file_dir            => '${FILEDIR}',    \
                                       p_in_attach_file         => '${ATTACHFILE}');
QUIT;
CODE_BLOCK

#########################################################################
#  END email_notify.ksh
#########################################################################
