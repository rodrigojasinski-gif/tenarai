#!/bin/ksh
# "$Id$"
#==========================================================================#
#
# 2005/11/13 JLW Script modified to run on either PROD or MDEV
#                Merged the b8400/prod/race/share/bin/race_altp.ksh
#                  with the es40x/mdev/race/share/bin/race_altp.ksh
#
#==========================================================================#
. /$ACT_LVL/race/share/bin/raceftp.ksh

if [ $THISHOST = $PRODHOST ]
then
   export RACE=/prod/race/parts
   export PATH=/prod/race/parts/bin:/prod/race/share/bin:$PATH
else
   echo "You are running in the ALTP subsystem.  \007"
   export MFConnect=''
fi

export LOGDIR=$RACE/log
export COSREPORT=race
export NOVELL=$ACT_LVL/

#==========================================================================#
#  END                                                                     #
#==========================================================================#
