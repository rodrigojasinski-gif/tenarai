#!/bin/ksh
#$Id: race_misc.ksh,v 1.1 1997/08/08 20:50:26 raceadm Exp $
#==========================================================================#
# race_misc.ksh                                                           #
#                                                                          #
#   DESCRIPTION                                                            #
#     The purpose of this script is to set the RACE and PATH              #
#     environment variables for the Editorial System 'misc' subsystem.     #
#                                                                          #
#==========================================================================#

# set environment

# echo "                   set RACE environment"
  export RACE=/prod/race/misc

# echo "                   set NOVELL environment"
  export NOVELL=prod/

# echo "                   set LOGDIR environment"
  export LOGDIR=$RACE/log

# echo "                   set COSREPORT environment"
  export COSREPORT=race

# echo "                   set PATH environment"
  export PATH=/prod/race/misc/bin:/prod/race/share/bin:$PATH

#  export MFConnect="TRACE=ON"

#==========================================================================#
#  END                                                                     #
#==========================================================================#
