#!/bin/ksh
#$Id: mpt916.ksh,v 1.3 2014/02/14 18:52:33 pb0690 Exp $
set -xv
#*****************************************************************************************
# PROC NAME: mpt916.ksh                                              
# PROC DESC: Rename files to obs_ for /stage files
# STEPS: 
#     1) Read parm that contains JOBNAME, OEM, and CNTRY that need to obsoleted.
#     2) Verify information and perform database fixes.
#     3) Remove unix files, if parameter file created by Step2 designates to do so.
#*****************************************************************************************

  trap 'abndalrt.ksh $?' err
  export PROCNAME=$(basename $0 .ksh_run)

  #**************************************************************************************
  # Process parm file and setup the Environment Variables 
  #************************************************************************************** 
  export PARM_FILE=${RACE}/prm/mpt916_oem_obsolete.prm
  export RACE=/stage/race/oem

  export REFORMAT_JOB=`grep "REFORMAT_JOB=" ${PARM_FILE} | cut -f2 -d"="`
  export UPDATE_JOB=`grep "UPDATE_JOB=" ${PARM_FILE} | cut -f2 -d"="`
  export ZPARM=`grep "ZPARM=" ${PARM_FILE} | cut -f2 -d"="`
  export PARMS=`grep "PARMS=" ${PARM_FILE} | cut -f2 -d"="`
  
  export MPTUSERID=`cat ${RACE}/prm/zmptpass.prm`

#STEP Step020R
  export STEPNAME=Step020R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  #**************************************************************************************
  #  Unix file rename:
  #  1. Rename files to be removed at a later time
  #**************************************************************************************
  export REMOVAL_LIST=${RACE}/tmp/${JOBNAME}_files_for_removal.tmp

  if [[ -n $REFORMAT_JOB ]]
  then
    find ${RACE}/bin/ -type f -name ${REFORMAT_JOB}\* -exec ls {} \; > ${REMOVAL_LIST}
    find ${RACE}/dat/ -type f -name ${REFORMAT_JOB}\* -exec ls {} \; >> ${REMOVAL_LIST}
    find ${RACE}/log/ -type f -name ${REFORMAT_JOB}\* -exec ls {} \; >> ${REMOVAL_LIST}
    find ${RACE}/rpt/ -type f -name ${REFORMAT_JOB}\* -exec ls {} \; >> ${REMOVAL_LIST}
    find ${RACE}/bin/ -type f -name ${UPDATE_JOB}\* -exec ls {} \; >> ${REMOVAL_LIST}
    find ${RACE}/dat/ -type f -name ${UPDATE_JOB}\* -exec ls {} \; >> ${REMOVAL_LIST}
    find ${RACE}/log/ -type f -name ${UPDATE_JOB}\* -exec ls {} \; >> ${REMOVAL_LIST}
    find ${RACE}/rpt/ -type f -name ${UPDATE_JOB}\* -exec ls {} \; >> ${REMOVAL_LIST}
    find ${RACE}/prm/ -type f -name ${ZPARM}\* -exec ls {} \; >> ${REMOVAL_LIST}
    find ${RACE}/prm/ -type f -name ${PARMS}\* -exec ls {} \; >> ${REMOVAL_LIST}
  fi

#STEP Step030R
  export STEPNAME=Step030R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  #**************************************************************************************
  #  Rename file to obs_
  #  1. Read .tmp file and move file
  #**************************************************************************************
export REMOVAL_LIST=${RACE}/tmp/${JOBNAME}_files_for_removal.tmp
  while read LINE
  do
     export REMOVELINE=`echo $LINE | cut -f1`
     export DIR1=`echo $LINE | cut -f1 -d /`
     export DIR2=`echo $LINE | cut -f2 -d /`
     export DIR3=`echo $LINE | cut -f3 -d /`
     export DIR4=`echo $LINE | cut -f4 -d /`
     export DIR5=`echo $LINE | cut -f5 -d /`
     export DIR6=`echo $LINE | cut -f6 -d /`
     export DIR7=`echo $LINE | cut -f7 -d /`
     export DIRROLLBACK=`echo $LINE | cut -f1,2,3,4,5`
     export FILENAME=`echo $LINE | cut -f6 -d /`
     export ROLLBACK=`echo $LINE | cut -f7 -d /`
     echo $ROLLBACK
          
        if [ $DIR6 = "rollback" ] 
          then
	     export OBS=obs_$ROLLBACK
            echo mv $REMOVELINE /$DIR2/$DIR3/$DIR4/$DIR5/$DIR6/$OBS
            mv $REMOVELINE /$DIR2/$DIR3/$DIR4/$DIR5/$DIR6/$OBS
        else
            export OBS=obs_$FILENAME
            echo mv $REMOVELINE /$DIR2/$DIR3/$DIR4/$DIR5/$OBS
            mv $REMOVELINE /$DIR2/$DIR3/$DIR4/$DIR5/$OBS
        fi

     
  done<$REMOVAL_LIST

#STEP Step999R
  export STEPNAME=Step999R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  #**************************************************************************************
  #  Remove tmp file
  #**************************************************************************************
   rm ${RACE}/tmp/${JOBNAME}_files_for_removal.tmp

#*****************************************************************************************
# END mpt916.ksh
#*****************************************************************************************