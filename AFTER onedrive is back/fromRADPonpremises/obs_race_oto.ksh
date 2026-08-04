#!/bin/ksh
#$Id: race_oto.ksh,v 1.4 2006/10/04 22:22:41 jw97143 Exp $
#==========================================================================
# race_oto.ksh
#
#   DESCRIPTION
#     The purpose of this script is to set the RACE and PATH
#     environment variables for the Editorial System 'OTO' subsystem.
#
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
   export RACE=/prod/race/oto
   export PATH=/prod/race/oto/bin:/prod/race/share/bin:$PATH
else
   export RACE=/$ACT_LVL/race/oto
   export PATH=$PATH:/$ACT_LVL/race/oto/bin:/stage/race/oto/bin
   echo "You are running in the OTO subsystem.  \007"
fi

export LOGDIR=$RACE/log
export COSREPORT=race
export NOVELL=$ACT_LVL/

#==========================================================================
#  END
#==========================================================================
