#!/bin/ksh
# "$Id: geis_ftpux.ksh,v 1.3 2006/10/04 22:21:10 jw97143 Exp $"
#==========================================================================
# geis_ftpux.ksh
#
#   DESCRIPTION
#     The purpose of this script is to set the GEIS and PATH
#     environment variables for the GEIS ftpux subsystem.
#
# 2006/10/04 JLW Remove path from raceftp.ksh
#                Include the subsystem in the path.  This is needed when
#                testing from toolbx via rsh_wrapper.
# 2006/09/05 JLW Run from either PROD or MDEV. Added execute of raceftp.ksh
#
#==========================================================================

. raceftp.ksh

if [ $THISHOST = $PRODHOST ]
then
   export GEIS=/prod/geis/ftpux
   export PATH=/prod/geis/ftpux/bin:/prod/race/share/bin:$PATH
else
   export GEIS=/mdev/geis/ftpux
   export PATH=$PATH:/$ACT_LVL/geis/ftpux/bin:/mdev/race/share/bin
   echo "You are running in the GEIS FTPUX subsystem.  \007"
fi

export LOGDIR=$GEIS/log
export COSREPORT=geis
export NOVELL=$ACT_LVL/

#==========================================================================
#  END
#==========================================================================
