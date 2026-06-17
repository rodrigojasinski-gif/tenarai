#! /bin/ksh
#$Id: check_out.ksh,v 1.3 2021/07/03 01:21:48 pg2697 Exp $
##############################################################################
# check_out.ksh                                                              #
#                                                                            #
#   This script will 'co' an object from the designated RCS file with        #
#   the option to 'lock' or select by 'revision'. The 'co' object is         #
#   written to stdout.                                                       #
#                                                                            #
#   COMMAND LINE:                                                            #
#                                                                            #
#     [-l] [-r number] [-v label] file_name subsys/component                 #
#                                                                            #
#   ENVIRONMENT:                                                             #
#                                                                            #
#     RCSDIR - path of RCS system directory, i.e. race:/prod/race            #
#                                                                            #
#   NOTE:                                                                    #
#                                                                            #
#     MM: Currently using 'rcp' and 'rsh' in place of proposed 'nfs' support.#
#     '-v' is currently not supported.                                       #
#                                                                            #
# 2014/09/15 - PAG - Oracle 11G Migration                                    #
# 2021/06/24 - PAG - AIX Migration; Chg'd rcp/rsh to scp/ssh.                #
##############################################################################
#PG: next two line for my testing
#echo "====================================================check_out.ksh in mdev directory========================================"
#set -xv

  trap 'exit -1' err

  if [ $# = "0" ]                                # test for parameters
    then
      echo  usage: check_out.ksh [-l] [-r number] \
            file_name subsys_name/component_name "\007" >&2
      exit -2
  fi

  LARG=""                                        # lock argument
  RARG=""                                        # revision number argument
  VARG=" "                                       # version label argument

  if ! [ $(printenv RCSDIR) ]                    # test RCS default path
    then
       echo "error: missing environmental variable RCSDIR\007" >&2
       return -1
  fi

#################################################################################
# Validate command line parameters
#################################################################################
  while getopts "lr:v:" ARG                      # parse parmeters
    do
      if [ $ARG = "l" ]                          # set -l value
        then
          LARG="-l"
      elif [ $ARG = "r" ]                         # set -r value
        then
          RARG="-r"$OPTARG
      elif [ $ARG = "v" ]                       # set -v value
        then
          VARG=$OPTARG
      else
          echo Unknown parameter "\007" >&2
          exit -1                              # invalid parameter - exit
      fi
       
  done

  shift 'OPTIND - 1'                             # set $1 to filename

#################################################################################
# Check if file exists file and whether it's already locked.
#PAG 2021/06: chg'd to ssh. Removed -e flag (invalid for rsh as well) 
#################################################################################
  RCSHOST=$( echo $RCSDIR | awk -F: '/:/ { print $1 }' )
  if [[ -z $RCSHOST ]]                           # check for remote host
  then
    echo Remote host not defined "\007" >&2
    exit -1
  fi

  RCSSVC=${RCSSVC:-svc-apd-race-prd@production.int}   # prod service account that owns the RCS files
  RCSSUDO="sudo -u $RCSSVC"                            # run remote RCS cmds as the service account

  RCSNAME=${RCSDIR#$RCSHOST":"}/$2/RCS/$1,v      # set RCS file name

  if [[ -z $( ssh $RCSHOST "$RCSSUDO ls $RCSNAME" 2>/dev/null ) ]]
    then                                         # check for file
      echo "\007File not found -" $RCSNAME >&2
      exit -1
  fi

  if [[ $LARG = "-l" ]]                          # check for lock
  then
    if [[ -n $(ssh $RCSHOST "$RCSSUDO rlog -L -R $RCSNAME") ]]
      then
        echo File already locked - $RCSNAME"\007" >&2
        exit -1
    fi
  fi

#################################################################################
# Check Out source
#PAG 2021/06: chg'd to ssh. Removed -e flag (invalid for rsh as well)
#2026/06: run remote RCS cmd as service account via 'ssh host sudo -u svc ...'
#################################################################################
  ssh $RCSHOST "$RCSSUDO co -p -q $LARG $RARG $RCSNAME"

#################################################################################
# END
#################################################################################
