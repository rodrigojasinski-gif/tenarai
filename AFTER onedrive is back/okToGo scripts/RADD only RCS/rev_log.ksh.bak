#! /bin/ksh 
#$Id: rev_log.ksh,v 1.1 2007/03/13 00:13:07 gw8440 Exp $
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
#  rj132422      - Linux migration: RCSDIR may now be a local path (no host prefix)     #
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
  FILENAME=$( echo $1 | awk -F/ '{print $NF}' )

  RCSNAME=${RCSDIR#$RCSHOST":"}/$2/RCS/$FILENAME,v

# rj132422 - service account that owns the RCS repo on the prod host
  RCSSVC=${RCSSVC:-svc-apd-race-prd@production.int}

# rj132422 - RCS binaries live in /usr/local/bin, which is outside sudo's secure_path,
#            so the sudoers rule only matches when the full path is given
  RCSBIN=${RCSBIN:-/usr/local/bin}

# rj132422 - LogLevel=ERROR drops the login banner the prod host prints on every connection, but keeps real errors
# rj132422 - an empty RCSHOST means the repo is on this host, so run rlog locally
  if [[ -z $RCSHOST ]]
  then
    $RCSBIN/rlog $RCSNAME
  else
    ssh -o LogLevel=ERROR $RCSHOST "sudo -u $RCSSVC $RCSBIN/rlog $RCSNAME"
  fi

###
#
# END
#
##
