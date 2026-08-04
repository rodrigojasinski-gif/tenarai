#!/bin/ksh
#$Id: logname.ksh,v 1.1 2006/08/10 21:53:45 jw97143 Exp $
#-----------------------------------------------------------
#  logname.ksh                                  *05/20/97* -
#                                                          -
#    This script will return a log name depending on       -
#    the state of the restart variable.                    -
#                                                          -
#    $1 contains the job name.                             -
#                                                          -
#    $2 contains the restart step name(optional).          -
#                                                          -
#-----------------------------------------------------------

  if [[ -z $1 ]]            # set job name
  then
    JOBNAME=$USER
  else
    JOBNAME=$1
  fi

  if [[ ! -z $2 ]]          # if restart - search for log
  then
    cd $LOGDIR
    ls -r ${JOBNAME}_*.log |&
    if  read -p a
    then
      if [[ -a $a ]]
      then
        echo $a
        exit 0
      fi
    fi
  fi
  
  echo ${JOBNAME}_$(date +'%C%y%m%d%H%M%S').log

