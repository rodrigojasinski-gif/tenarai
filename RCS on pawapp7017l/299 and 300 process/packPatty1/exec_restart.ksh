#!/bin/ksh
# $Id: exec_restart.ksh,v 1.8 2022/10/20 18:51:44 pg2697 Exp $
###########################################################################
#
#   DESCRIPTION
#     This script will provide for STEP restartability.
#
#   EXAMPLE
#     exec_restart.ksh <script> [stepnumber]
#        i.e exec_restart mfrr141 STEP020R
#
#   FILES
#     exec_restart.awk  - awk support file
#
#   RETURN
#     none
#
#   HISTORY
#   2021/03/17 PAG Added display of restart step value, if passed in.
#   2016/05/03 PAG Removed printpipe.ksh from cat statements. (We no longer use printpipe.)
#   2008/10/07 JLW Temporary code to build JOBLOGNAME from LOGNAME 
#                  (AIX upgrade made "logname" no longer valid.)
#   2006/09/22 JLW Script modified to remove the temporary script in test system.
#   2006/09/01 JLW Script modified ignore the case when looking for the restart step
#                  (the exec_restart.awk script is case sensitive, so this should be too).
#                  Also keep the temporary script if the job should fail.
#   2006/08/09 JLW Script modified to run on either PROD or MDEV using $ACT_LVL
#
###########################################################################

#setup environment

BINDIR=/$ACT_LVL/race/share/bin               # set BINDIR to 'shared' path
AWK=$BINDIR/exec_restart.awk                  # set AWK to 'exec_restart.awk'
PNAME=$(echo $1 | awk -F'/' '{print $NF}')    # set PNAME to script - the path
SCRIPT=$(echo $PNAME | awk -F. '{print $1}')  # set script name
TSCRIPT=/tmp/${JOBNAME}_${PNAME}_run

#check parms

THE_PROC=$(whence $1)                         # locate the proc script

if [ $# = "1" ] || [ $# = "2" ]               # for 1 or 2 parameters
then
  if [ -e $THE_PROC ]                         # check existance of the proc script
  then
    if [ $# = "2" ]                           # check for restart step value
    then
	  #PAG: 2021/03 - added display of restart step, if passed in
      print "\n\n**********************************************************************************"
      echo "Restart Step $2 has been included in the job execution."
      print "**********************************************************************************\n\n"

      #-----------------------------------------------------------------------------
      #08/31/2006 JLW Do NOT ignore case when looking for the restart step!
      #if [[ $( grep -i -c $2 $THE_PROC ) = "0" ]] # check for restart step
      #-----------------------------------------------------------------------------
      if [[ $( grep -c $2 $THE_PROC ) = "0" ]] # check for restart step
      then
        print "\n\n**********************************************************************************"
        echo "Step $2 is not found in script: $THE_PROC"
        echo "Restart stepname is case sensitive (step010r will fail - use Step010R)"
        print "**********************************************************************************\n\n"
        exit 2                                # exit error 2
      fi

      #2016/05/03 cat $BINDIR/printpipe.ksh $THE_PROC | awk -f$AWK -vRESTART=$2 > $TSCRIPT
      cat $THE_PROC | awk -f$AWK -vRESTART=$2 > $TSCRIPT
    else
	  #PAG: 2021/03 - added display that NO restart step was passed in
      print "\n\n**********************************************************************************"
      echo "Restart Step was NOT included in the job execution. Job will run from the beginning."
      print "**********************************************************************************\n\n"

      #2016/05/03 cat $BINDIR/printpipe.ksh $THE_PROC > $TSCRIPT
      cat $THE_PROC > $TSCRIPT
    fi

    if [ -z "${JOBLOGNAME}" ]
    then
       JOBLOGNAME=${LOGNAME}
       echo "JOBLOGNAME did not exist"
    fi

    # run script
    chmod a+rwx $TSCRIPT                         # change run file permissions
    if [[ -a ${JOBLOGNAME} ]]                    # add SCRIPT start time to log
    then
       print "\n\n**************************************************************************************************************"
       echo "Calling:  $PNAME $2   Datetime: $(date +'%m/%d/%y %H:%M:%S')   Script: $TSCRIPT"
       print "**************************************************************************************************************\n\n"
    fi

    ksh -x $TSCRIPT 2>>${JOBLOGNAME}                         # !!! EXECUTE !!!
    RET=$?                                    # save return code

    if [ ${THISHOST} = ${TESTHOST} ]
    then
       rm $TSCRIPT                            # remove temp script file from test system
    fi

    # check return
    if ! [ $RET = "0" ]
    then
     # kill -9 $PPID
      echo "ERROR: Script returned non-zero exit code: $RET"
      exit $RET
      #exit 2
    fi

    if [[ -a ${JOBLOGNAME} ]]                 # add SCRIPT finish time to log
    then
       print "\n\n**************************************************************************************************************"
       echo "Finished: $PNAME $2   Datetime: $(date +'%m/%d/%y %H:%M:%S')   Script: $TSCRIPT"
       print "**************************************************************************************************************\n\n"
    fi

    exit 0
  fi
fi

print "Usage: exec_restart jobname <restart-step>"
exit -1

#####################################################################################
# END exec_restart.ksh
#####################################################################################
