#!/bin/ksh
#$Id: race_parts.ksh,v 1.4 2006/10/04 21:55:55 jw97143 Exp $
#==========================================================================
#
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
   export RACE=/prod/race/parts
   export PATH=/prod/race/parts/bin:/prod/race/share/bin:$PATH
else
   export RACE=/mdev/race/parts
   export PATH=$PATH:/$ACT_LVL/race/parts/bin:/stage/race/parts/bin
   echo "You are running in the PARTS subsystem.  \007"
   export MFConnect=''
fi

export LOGDIR=$RACE/log
export COSREPORT=race
export NOVELL=$ACT_LVL/

export RACE_DEBUG_LEVEL=0
export RACE_DBMS_PROFILER_FLAG="N"

export OBJ_DATDIR=RACE_OEM_DAT_DIR
export OBJ_LOGDIR=RACE_OEM_LOG_DIR
export OBJ_RPTDIR=RACE_OEM_RPT_DIR
export OBJ_TMPDIR=RACE_OEM_TMP_DIR
export OBJ_PRMDIR=RACE_OEM_PRM_DIR

#==========================================================================
#  END
#==========================================================================
