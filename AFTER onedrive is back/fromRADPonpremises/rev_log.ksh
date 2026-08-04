#! /bin/ksh 
#$Id: rev_log.ksh,v 1.2 2021/07/03 01:46:45 pg2697 Exp $
#########################################################################################
# rev_log.ksh                                                     *08/07/97*            #
#                                                                                       #
#   This script will return the version history of a selected object.                   #
#                                                                                       #
#   COMMAND LINE:                                                                       #
#                                                                                       #
#     filename subsys/component                                                         #
#                                                                                       #
#   ENVIRONMENT:                                                                        #
#                                                                                       #
#     RCSDIR - path of RCS system directory, i.e. race:/prod/race                       #
#                                                                                       #
#  PG 2021/06/25 - Replaced use of rcp/rsh with scp/ssh. Removed -e flag (invalid flag) #
#                                                                                       #
#########################################################################################

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

  ssh $RCSHOST rlog $RCSNAME                   

###
#
# END
#
##
