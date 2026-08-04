#!/bin/ksh
# "$Id: race_hosts.ksh,v 1.5 2015/01/20 23:21:30 pg2697 Exp $"
#==========================================================================#
# race_hosts.ksh                                                           #
#                                                                          #
#   DESCRIPTION                                                            #
#     The purpose of this script is to set the Application Server host     #
#     RMT_HOST, and the Media Conversion Server (i.e. Tape Read Jobs Host) #
#     LOC_HOST environment variables for the Editorial System.             #
#                                                                          #
#==========================================================================#
# 2015/01/07 PAG Added MAPP_HOST (for transfer of altparts data for MAPP DB load)
# 2006/10/04 JLW Remove path from raceftp.ksh
#                Include the subsystem in the path.  This is needed when
#                testing from toolbx via rsh_wrapper.
# 2006/09/05 JLW Modified to include raceftp.ksh to setup THISHOST and PRODHOST
# 2006/08/18 JLW Script modified to run on either PROD or MDEV
#
#==========================================================================

. raceftp.ksh

  export RSH_FILEEXIST="/$ACT_LVL/race/share/bin/fileexist.ksh"

  if [ ${THISHOST} = ${PRODHOST} ]
  then
     export GEI_HOST="race"
     export RMT_HOST="media1"
     export LOC_HOST="race"
     export MAPP_HOST="mappq"
  else
     export GEI_HOST="raced"
     export RMT_HOST="media2"
     export LOC_HOST="raced"
     export MAPP_HOST="mappd"
  fi

#==========================================================================
#  END
#==========================================================================
