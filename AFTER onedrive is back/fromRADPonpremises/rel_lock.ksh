#! /bin/ksh
#$Id: rel_lock.ksh,v 1.2 2021/07/03 01:46:09 pg2697 Exp $
##############################################################################
# rel_lock.ksh                                                    *08/07/97* #
#                                                                            #
#   This script will remove the lock from an RCS object.                     #
#                                                                            #
#   COMMAND LINE:                                                            #
#                                                                            #
#     filename subsys/component                                              #
#                                                                            #
#   ENVIRONMENT:                                                             #
#                                                                            #
#     RCSDIR - path of RCS system directory, i.e. race:/prod/race            #
#                                                                            #
# PG 2021/06/25 - replaced rsh/rcp with ssh/scp. Removed -e flag (not valid).#
#                                                                            #
##############################################################################

  trap 'exit -1' err

  if [ $# = "0" ]
    then
      echo  usage: rev_log filename subsys/component "\007" >&2
      exit -2
  fi

###
#
# Validate command line parameters
#
###
  if ! [ $(printenv RCSDIR) ]                    # test RCS default path
    then
      echo "error: need environment variable RCSDIR\007" >&2
      return -2
  fi

  SUBSYS=$(echo $2 | awk -F/ '{print $1}')
  if [[ -z $SUBSYS ]]
  then
    echo Invalid Subsys "\007"
    exit -2
  fi

  COMPN=$(echo $2 | awk -F/ '{print $2}')
  if [[ -z $COMPN ]]
  then
    echo Invalid Component "\007"
    exit -2
  fi

###
#
# Issue rlog command
#
###
  RCSHOST=$( echo $RCSDIR | awk -F: '/:/ { print $1 }' )
  if [[ -z $RCSHOST ]]                           # check for remote host
  then
    echo Remote host not defined "\007" >&2
    exit -2
  fi
  FILENAME=$( echo $1 | awk -F/ '{print $NF}' )

  RCSNAME=${RCSDIR#$RCSHOST":"}/$2/RCS/$FILENAME,v

  ssh $RCSHOST rcs -u $RCSNAME                # 

###
#
# END
#
##
