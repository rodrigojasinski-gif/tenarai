#!/bin/ksh
#$Id: race_ceg.ksh,v 1.7 2016/05/04 21:48:47 pg2697 Exp $
#==========================================================================
# race_ceg.ksh
#
#   DESCRIPTION
#     The purpose of this script is to set the RACE and PATH
#     environment variables for the Editorial System 'CEG' subsystem.
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
   export RACE=/prod/race/ceg
   export PATH=/prod/race/ceg/bin:/prod/race/share/bin:$PATH
else
   export RACE=/$ACT_LVL/race/ceg
   export PATH=$PATH:/$ACT_LVL/race/ceg/bin:/stage/race/ceg/bin
   echo "You are running in the CEG subsystem.  \007"
fi

export LOGDIR=$RACE/log
export NOVELL=$ACT_LVL/

export OBJ_DATDIR=RACE_CEG_DAT_DIR
export OBJ_LOGDIR=RACE_CEG_LOG_DIR
export OBJ_PRMDIR=RACE_CEG_PRM_DIR
export OBJ_RPTDIR=RACE_CEG_RPT_DIR
export OBJ_TMPDIR=RACE_CEG_TMP_DIR

export JOBNAME=$(basename $0 .ksh)
export JOBLOGNAME=${RACE}/log/$(logname.ksh ${JOBNAME} $1)

#==========================================================================
#  END
#==========================================================================
