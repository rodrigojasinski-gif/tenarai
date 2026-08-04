#!/bin/ksh
#$Id: abndalrt.ksh,v 1.5 2016/06/16 16:19:02 jl101765 Exp $
#####################################################################################
#
#   DESCRIPTION
#     Format and write error message to 'stdout' and 'logger'. Kills parent process.
#
#   EXAMPLE
#     abndalrt <scriptname> <stepname> <errorcode>
#        i.e abndalrt mfr141 Step010 9
#                       or
#     abndalrt <errorcode>
#        i.e abndalrt 9  (uses environmental variables)
#
#   ENVIRONMENT VARIABLES
#     JOBNAME           - name of job
#     PROCNAME optional - name of subscript(if used)
#     STEPNAME          - name of step within script
#     ABNDMSG           - urgent message(clear after)
#
#   FILES
#     ../prm/abendmsg   - Message for display.
#
#   RETURN
#
#   HISTORY
#   2006/08/09 JLW Script modified to run on either PROD or MDEV using $ACT_LVL
#
#####################################################################################

# set environment

  JNAME=$USER                                      # defaults
  PNAME=""
  SNAME=JOB
  JRC=99

  if [[ -z $SYSDIR ]]                             # set SYSDIR directory
  then
    SYSDIR=/$ACT_LVL/race/share/prm
  fi

  if [[ $# = 1 ]]                                 # for one parameter only
  then
    if [[ -n $JOBNAME ]]                          # set JNAME to $JOBNAME
    then
      JNAME=$JOBNAME
    fi
    if [[ -n $STEPNAME ]]                         # set SNAME to $STEPNAME
    then
      SNAME=$STEPNAME
    fi
    if [[ -n $PROCNAME ]]
    then
      SNAME=$PROCNAME"["$SNAME"]"
    fi
    JRC=$1                                        # set JRC to $1
  else
    if [[ -n $1 ]]                                # set JNAME to $1
    then
      JNAME=$1
    fi
    if [[ -n $2 ]]                                # set SNAME to $2
    then
      SNAME=$2
    fi
    if [[ -n $3 ]]                                # set JRC to $3
    then
      JRC=$3
    fi
  fi

# display message
  echo
  cat $SYSDIR/abendmsg                            # display abendmsg

  if [[ -n ${ABNDMSG} ]]
  then
     echo '   ** '${JNAME}':'${SNAME}' failed, '${ABNDMSG} $(date +'%m/%d/%y %H:%M:%S')
     if [ ${THISHOST} != ${TESTHOST} ]
     then
         logger -p user.info "OPCOM*I*ABEND*"${JNAME}"*"${SNAME}"*"${ABNDMSG} $(date +'%m/%d/%y %H:%M:%S')
     fi
  else
     echo '   ** '${JNAME}':'${SNAME}' failed, rc = '${JRC}' **'  $(date +'%m/%d/%y %H:%M:%S')
     if [ ${THISHOST} != ${TESTHOST} ]
     then
        logger -p user.info "OPCOM*I*ABEND*"${JNAME}"*"${SNAME}"*Script failed -"${JRC}"-"  $(date +'%m/%d/%y %H:%M:%S')
     fi
  fi

  kill -9 $PPID                                   # kill parent process

#####################################################################################
# END abndalrt.ksh
#####################################################################################
