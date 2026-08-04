#!/bin/ksh
# "$Id: race_ext.ksh,v 1.7 2016/05/04 21:48:51 pg2697 Exp $"
#==========================================================================
# race_ext.ksh
#
#   DESCRIPTION
#     The purpose of this script is to set the RACE and PATH
#     environment variables for the Editorial System 'EXT' subsystem.
#
# 2016/05/03 PAG Removed COSREPORT export statement. (CosReport is no longer used.)
# 2008/08/29 PAG Moved valueing of jobname and joblogname from job script to 
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
   export RACE=/prod/race/ext
   export PATH=/prod/race/ext/bin:/prod/race/share/bin:$PATH
else
   export RACE=/$ACT_LVL/race/ext
   export PATH=$PATH:/$ACT_LVL/race/ext/bin:/stage/race/ext/bin
   echo "You are running in the EXT subsystem.  \007"
fi

export LOGDIR=$RACE/log
export NOVELL=$ACT_LVL/

export OBJ_DATDIR=RACE_EXT_DAT_DIR
export OBJ_LOGDIR=RACE_EXT_LOG_DIR
export OBJ_RPTDIR=RACE_EXT_RPT_DIR
export OBJ_TMPDIR=RACE_EXT_TMP_DIR
export OBJ_PRMDIR=RACE_EXT_PRM_DIR

export OBJ_DATDIR_UMFULL=RACE_EXT_DAT_UMFULL_DIR
export OBJ_DATDIR_UMMINI=RACE_EXT_DAT_UMMINI_DIR
export OBJ_DATDIR_UMFULL_CAFREE=RACE_EXT_DAT_UMFULL_CAFRE_DIR

export JOBNAME=$(basename $0 .ksh)
export JOBLOGNAME=${RACE}/log/$(logname.ksh ${JOBNAME} $1)

#==========================================================================
#  END
#==========================================================================
