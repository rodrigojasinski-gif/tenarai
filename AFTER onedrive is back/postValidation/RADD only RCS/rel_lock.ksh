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
# rj132422      - Linux migration: RCSDIR may now be a local path (no host)  #
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
# Issue rcs -u command
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

# rj132422 - use the race_rcs wrapper (like race_co/race_ci): it strips @domain from SUDO_USER
#            so RCS accepts the identity and records the real developer as the lock owner
# rj132422 - LogLevel=ERROR drops the login banner the prod host prints on every connection, but keeps real errors
# rj132422 - an empty RCSHOST means the repo is on this host, so run rcs -u locally
  if [[ -z $RCSHOST ]]
  then
    $RCSBIN/rcs -u $RCSNAME
  else
    ssh -o LogLevel=ERROR $RCSHOST "sudo -u $RCSSVC $RCSBIN/race_rcs -u $RCSNAME"
  fi

###
#
# END
#
##
