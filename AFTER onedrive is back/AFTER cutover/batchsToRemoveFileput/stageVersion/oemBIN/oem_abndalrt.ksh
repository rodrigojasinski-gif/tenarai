#!/bin/ksh
#$Id: oem_abndalrt.ksh,v 1.4 2016/06/16 16:19:31 jl101765 Exp $
#===========================================================================================#
#
#   DESCRIPTION
#     This is a "copy" of the shared version of abndalrt.ksh customized for RACE OEM Parts
#     to update the oem_job table with the "abend" messages.
#     Format and write error message to 'stdout' and 'logger'
#     Kills parent process
#
#   EXAMPLE
#     oem_abndalrt <scriptname> <stepname> <errorcode>
#        i.e oem_abndalrt mfr141 Step010 9
#                       or
#     oem_abndalrt <errorcode>
#        i.e oem_abndalrt 9  (uses environmental variables)
#
#   ENVIRONMENT VARIABLES
#     JOBNAME           - name of job
#     PROCNAME optional - name of subscript(if used)
#     STEPNAME          - name of step within script
#     ABNDMSG           - urgent message(clear after)
#
#===========================================================================================#

echo "\n\n*** Begin oem_abndalrt.ksh ***\n\n"

#******************************************************************************************
# set environment
JNAME=${USER}                                   # defaults
PNAME=""
SNAME=JOB
JRC=99

if [[ -z ${SYSDIR} ]]                           # set SYSDIR directory
then
   SYSDIR=/${ACT_LVL}/race/share/prm
fi

if [[ $# = 1 ]]                                 # for one parameter only
then
   if [[ -n ${JOBNAME} ]]                        # set JNAME to ${JOBNAME}
   then
      JNAME=${JOBNAME}
   fi
   if [[ -n ${STEPNAME} ]]                       # set SNAME to ${STEPNAME}
   then
      SNAME=${STEPNAME}
   fi
   if [[ -n ${PROCNAME} ]]
   then
      SNAME=${PROCNAME}"["${SNAME}"]"
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

env | sort

#***************************************************************************
# Display Abend Message
echo
cat ${SYSDIR}/abendmsg                          # display abendmsg

if [[ -n ${ABNDMSG} ]]
then
   echo '   ** '${JNAME}':'${SNAME}' failed, '${ABNDMSG}
   if [ ${THISHOST} != ${TESTHOST} ]
   then
       logger -p user.info "OPCOM*I*ABEND*"${JNAME}"*"${SNAME}"*"${ABNDMSG}
   fi
else
   echo '   ** '${JNAME}':'${SNAME}' failed, rc = '${JRC}' **'
   if [ ${THISHOST} != ${TESTHOST} ]
   then
      logger -p user.info "OPCOM*I*ABEND*"${JNAME}"*"${SNAME}"*Script failed -"${JRC}"-"
   fi
fi

#***************************************************************************
# Update race table with ABEND status
oem_job_status_update.ksh "A" " "
echo "\n\n***  End  oem_abndalrt.ksh ***\n\n"

kill -9 ${PPID}                                 # kill parent process

#***************************************************************************
# END
#***************************************************************************
