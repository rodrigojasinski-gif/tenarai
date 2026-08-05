#!/bin/ksh
#$Id: race_qrp.ksh,v 1.8 2016/05/04 21:48:59 pg2697 Exp $
#==========================================================================
# race_qrp.ksh
#
#   DESCRIPTION
#     The purpose of this script is to set the RACE and PATH
#     environment variables for the Editorial System 'QRP' subsystem.
#
# 2016/05/03 PAG Removed COSREPORT export statement. (CosReport is no longer used.)
# 2008/10/07 JLW Moved valuing of jobname and joblogname from job script to 
#                this shared script. (AIX upgrade made "logname" no longer valid.)
# 2006/10/04 JLW Remove path from raceftp.ksh
#                Include the subsystem in the path.  This is needed when
#                testing from toolbx via rsh_wrapper.
# 2006/09/05 JLW Modified to include raceftp.ksh to setup THISHOST and PRODHOST
# 2006/08/18 JLW Script modified to run on either PROD or MDEV
#
#==========================================================================

. raceftp.ksh

if [ $THISHOST = $PRODHOST ]
then
   export RACE=/prod/race/qrp
   export PATH=/prod/race/qrp/bin:/prod/race/share/bin:$PATH
else
   export RACE=/$ACT_LVL/race/qrp
   export PATH=$PATH:/$ACT_LVL/race/qrp/bin:/stage/race/qrp/bin
   echo "You are running in the QRP subsystem.  \007"
fi

export LOGDIR=$RACE/log
export NOVELL=$ACT_LVL/

export OBJ_DATDIR=RACE_QRP_DAT_DIR
export OBJ_LOGDIR=RACE_QRP_LOG_DIR
export OBJ_RPTDIR=RACE_QRP_RPT_DIR
export OBJ_TMPDIR=RACE_QRP_TMP_DIR
export OBJ_PRMDIR=RACE_QRP_PRM_DIR

export JOBNAME=$(basename $0 .ksh)
export JOBLOGNAME=${RACE}/log/$(logname.ksh ${JOBNAME} $1)
export LOG=${RACE}/tmp/${JOBNAME}_$$.sqlout   # rj132422 - default sqlplus capture log (empty $LOG aborts the redirect on RHEL)

#==========================================================================
#  END
#==========================================================================
