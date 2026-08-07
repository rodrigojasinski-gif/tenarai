#!/bin/ksh
#$Id: race_altp.ksh,v 1.9 2026/08/05 11:44:35 rj132422 Exp $
#==========================================================================
# race_altp.ksh
#
#   DESCRIPTION
#     The purpose of this script is to set the RACE and PATH
#     environment variables for the Editorial System 'ALTP' subsystem.
#
# Change rj132422 - 20260424 - Define MAPP/ALTP NFS file-exchange paths replacing the decommissioned prod3nt/${NOVELL} FTP dependency
# 2016/05/03 PAG Removed COSREPORT export statement. (CosReport is no longer used.)
# 2008/08/29 PAG Moved valueing of jobname and joblogname from job script to 
#                this shared script. (AIX upgrade made "logname" no longer valid.)
# 2006/02/23 JLW Environment variables for standard directory objects.
# 2006/10/04 JLW Remove path from raceftp.ksh
#                Include the subsystem in the path.  This is needed when
#                testing from toolbx via rsh_wrapper.
# 2006/09/05 JLW Removed script from PVCS and added to RCS
# 2005/11/21 PAG Script modified to run on either PROD or MDEV.
#                Also, added execute of raceftp.ksh
#==========================================================================

. raceftp.ksh

if [ $THISHOST = $PRODHOST ]
then
   export RACE=/prod/race/altp
   export PATH=/prod/race/altp/bin:/prod/race/share/bin:$PATH
   export ALTP_FTP_DATA=/nas/prod/OEM_Repair_Doc_Repository/ftpdata/prod
else
   export RACE=/$ACT_LVL/race/altp
   export PATH=$PATH:/$ACT_LVL/race/altp/bin:/stage/race/altp/bin
   echo "You are running in the altp subsystem.  \007"
   export MFConnect=''
   export ALTP_FTP_DATA=/nas/mdev/OEM_Repair_Doc_Repository/ftpdata/mdev
fi

# MAPP/ALTP file-exchange sub-paths derived from ALTP_FTP_DATA (NFS-mounted) - rj132422
export ALTP_DIR=${ALTP_FTP_DATA}/altp
export ALTP_NAPA_DIR=${ALTP_FTP_DATA}/altp/NAPA
export ALTP_INTRPT_DIR=${ALTP_FTP_DATA}/altp/Internal_Rpts
export ALTP_CUSTRPT_DIR=${ALTP_FTP_DATA}/altp/Customer_Rpts

export LOGDIR=$RACE/log
export NOVELL=$ACT_LVL/

export OBJ_DATDIR=RACE_ALTP_DAT_DIR
export OBJ_LOGDIR=RACE_ALTP_LOG_DIR
export OBJ_RPTDIR=RACE_ALTP_RPT_DIR
export OBJ_TMPDIR=RACE_ALTP_TMP_DIR
export OBJ_PRMDIR=RACE_ALTP_PRM_DIR

export JOBNAME=$(basename $0 .ksh)
export JOBLOGNAME=${RACE}/log/$(logname.ksh ${JOBNAME} $1)
export LOG=${RACE}/tmp/${JOBNAME}_$$.sqlout   # rj132422 - default sqlplus capture log (empty $LOG aborts the redirect on RHEL)
export PATH=$HOME:$PATH   # TEST ONLY 

#==========================================================================
#  END
#==========================================================================
