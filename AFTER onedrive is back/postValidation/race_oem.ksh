#!/bin/ksh
#$Id: race_oem.ksh,v 1.4 2016/05/04 21:48:55 pg2697 Exp $
#==========================================================================
#
# 2016/05/03 PAG Removed COSREPORT export statement. (CosReport is no longer used.)
# 2008/10/07 JLW Moved valuing of jobname and joblogname from job script to 
#                this shared script. (AIX upgrade made "logname" no longer valid.)
# 2007/01/19 JLW Copied from race_parts.ksh
# 2006/10/24 JLW Changed /parts to /oem as part of the IBM migration project.
# 2006/10/04 JLW Remove path from raceftp.ksh
#                Include the subsystem in the path.  This is needed when
#                testing from toolbx via rsh_wrapper.
# 2006/09/22 JLW Script modified to permit race_b1 run suites in test system
# 2006/09/04 JLW Script modified to include "Parm" Directory Object
# 2006/08/09 JLW Script modified to include Directory Object values
# 2004/09/27 JLW Script modified to run on either PROD or MDEV
#                Merged the b8400/prod/race/share/bin/race_parts.ksh
#                  with the es40x/mdev/race/share/bin/race_parts.ksh
#
#==========================================================================

. raceftp.ksh

if [ $THISHOST = $PRODHOST ]
then
   # Production is production, so put those libraries first
   export RACE=/prod/race/oem
   export PATH=/prod/race/oem/bin:/prod/race/share/bin:$PATH
else
   export RACE=/mdev/race/oem
   export PATH=$PATH:/$ACT_LVL/race/oem/bin:/stage/race/oem/bin
   echo "You are running in the OEM subsystem.  \007"
   export MFConnect=''
fi

export LOGDIR=$RACE/log
export NOVELL=$ACT_LVL/

export RACE_DEBUG_LEVEL=0
export RACE_DBMS_PROFILER_FLAG="N"

export OBJ_DATDIR=RACE_OEM_DAT_DIR
export OBJ_LOGDIR=RACE_OEM_LOG_DIR
export OBJ_RPTDIR=RACE_OEM_RPT_DIR
export OBJ_TMPDIR=RACE_OEM_TMP_DIR
export OBJ_PRMDIR=RACE_OEM_PRM_DIR

export JOBNAME=$(basename $0 .ksh)
export JOBLOGNAME=${RACE}/log/$(logname.ksh ${JOBNAME} $1)
export LOG=${RACE}/log/${JOBNAME}_$$.sqlout   # rj132422 - default sqlplus capture log (empty $LOG aborts the redirect on RHEL)
#==========================================================================
#  END
#==========================================================================
