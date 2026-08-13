#!/bin/ksh
#$Id: mpt915.ksh,v 1.6 2014/02/28 00:39:42 pb0690 Exp $
set -xv
export PROCNAME=$(basename $0 .ksh_run)
trap 'abndalrt.ksh $?' err
#*****************************************************************************************
# PROC NAME: mpt915.ksh                                              
# PROC DESC: Rename files to obs_ and update database rows 
# STEPS: 
#     1) Read parm that contains JOBNAME, OEM, and CNTRY that need to obsoleted.
#     2) Verify information and perform database fixes.
#     3) Remove unix files, if parameter file created by Step2 designates to do so.
#*****************************************************************************************

  #**************************************************************************************
  # Process parm file and setup the Environment Variables 
  #************************************************************************************** 
  export PARM_FILE=${RACE}/prm/mpt915_oem_obsolete.prm
  
  export REFORMAT_JOB=`grep "REFORMAT_JOB=" ${PARM_FILE} | cut -f2 -d"="`
  export UPDATE_JOB=`grep "UPDATE_JOB=" ${PARM_FILE} | cut -f2 -d"="`
  export ZPARM=`grep "ZPARM=" ${PARM_FILE} | cut -f2 -d"="`
  export PARMS=`grep "PARMS=" ${PARM_FILE} | cut -f2 -d"="`
  export REMOVAL_LIST=${RACE}/tmp/${JOBNAME}_files_for_removal.tmp
  export EMAIL_RCS_LIST=${RACE}/tmp/${JOBNAME}_RCS_files.txt

  export MPTUSERID=`cat ${RACE}/prm/zmptpass.prm`
  export HOST_NAME=$(hostname)

#STEP Step010R
  export STEPNAME=Step010R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  #**************************************************************************************
  #  Execute procedure to update database tables and determine if unix files require cleanup. 
  #  1. Verify parm values
  #  2. Perform database cleanup based on parm values.
  #  3. Log all database activity in tmp file, as well as indicator whether unix files
  #     should be removed.
  #  4. Display what was logged in tmp file so that job log contains info as well.
  #**************************************************************************************

  sqlplus << CODE_BLOCK 2>&1 > $LOG
$MPTUSERID
SET SERVEROUTPUT ON FORMAT WRAPPED;
whenever sqlerror exit sql.sqlcode

    exec sp_oem_obsolete(p_in_reformat_job          => '${REFORMAT_JOB}');

QUIT;
CODE_BLOCK

#STEP Step020R
  export STEPNAME=Step020R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  #**************************************************************************************
  #  Unix file rename:
  #  1. Rename files to be removed at a later time
  #**************************************************************************************

  # check if $REFORMAT_JOB is not null, then find information
  if [[ -n $REFORMAT_JOB ]]
  then
    find ${RACE}/bin/ -type f -name ${REFORMAT_JOB}\* -exec ls {} \; > ${REMOVAL_LIST}
    find ${RACE}/dat/ -type f -name ${REFORMAT_JOB}\* -exec ls {} \; >> ${REMOVAL_LIST}
    find ${RACE}/log/ -type f -name ${REFORMAT_JOB}\* -exec ls {} \; >> ${REMOVAL_LIST}
    find ${RACE}/prm/ -type f -name ${REFORMAT_JOB}\* -exec ls {} \; >> ${REMOVAL_LIST}
    find ${RACE}/rpt/ -type f -name ${REFORMAT_JOB}\* -exec ls {} \; >> ${REMOVAL_LIST}
    find ${RACE}/bin/ -type f -name ${UPDATE_JOB}\* -exec ls {} \; >> ${REMOVAL_LIST}
    find ${RACE}/dat/ -type f -name ${UPDATE_JOB}\* -exec ls {} \; >> ${REMOVAL_LIST}
    find ${RACE}/log/ -type f -name ${UPDATE_JOB}\* -exec ls {} \; >> ${REMOVAL_LIST}
    find ${RACE}/prm/ -type f -name ${UPDATE_JOB}\* -exec ls {} \; >> ${REMOVAL_LIST}
    find ${RACE}/rpt/ -type f -name ${UPDATE_JOB}\* -exec ls {} \; >> ${REMOVAL_LIST}
    find ${RACE}/prm/ -type f -name ${ZPARM}\* -exec ls {} \; >> ${REMOVAL_LIST}
    find ${RACE}/prm/ -type f -name ${PARMS}\* -exec ls {} \; >> ${REMOVAL_LIST}

  fi

#STEP Step030R
  export STEPNAME=Step030R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  #**************************************************************************************
  #  Rename file to obs_
  #  1. Read .tmp file and move file or if RCS file then write to file
  #**************************************************************************************


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
     export ROLLBACKRCS=`echo $LINE | cut -f7 -d /`

     # echo will print to file
     if [[ $DIR6 = "RCS" ]] 
       then
          export OBS=obs_$ROLLBACKRCS
          echo "mv $REMOVELINE /$DIR2/$DIR3/$DIR4/$DIR5/$DIR6/$OBS"  >> $EMAIL_RCS_LIST
     else     
     if [[ $DIR6 = "rollback" ]] 
	then 
         export OBS=obs_$ROLLBACKRCS
         echo mv $REMOVELINE /$DIR2/$DIR3/$DIR4/$DIR5/$DIR6/$OBS
         mv $REMOVELINE /$DIR2/$DIR3/$DIR4/$DIR5/$DIR6/$OBS
	else 
         if [[ $DIR5 = "bin" || $DIR5 = "dat" || $DIR5 = "log" || $DIR5 = "rpt" || $DIR5 = "prm"  ]] 
           then
		if [[ ! -n $DIR7 ]]
                # $DIR7 is null
		  then
		    export OBS=obs_$FILENAME
		    echo mv $REMOVELINE /$DIR2/$DIR3/$DIR4/$DIR5/$OBS
		    mv $REMOVELINE /$DIR2/$DIR3/$DIR4/$DIR5/$OBS
                else
                  export OBS=obs_$ROLLBACKRCS
                  echo mv $REMOVELINE /$DIR2/$DIR3/$DIR4/$DIR5/$DIR6/$OBS
                  mv $REMOVELINE /$DIR2/$DIR3/$DIR4/$DIR5/$DIR6/$OBS
		fi
	  fi
       fi
     fi
     
  done<$REMOVAL_LIST

#STEP Step040R
  export STEPNAME=Step040R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  #**************************************************************************************
  #  Check if RCS file exists
  #**************************************************************************************
  # read in the 4 parameters into these values
  export JOBNAME=${JOBNAME}
  export EMAIL_NAME=obsolete
  export FILEDIR=RACE_OEM_TMP_DIR
  export ATTACHFILE=${JOBNAME}_RCS_files.txt
  
  # if the file does not exist, null out the variables
  if [ ! -e ${RACE}/tmp/$ATTACHFILE ]
    then 
	FILEDIR=''  
	ATTACHFILE=''
  else
      # awk won't create file in /tmp dir, so where it is created it is moved to /tmp
      # awk to convert from UNIX file to windows file
      awk 'sub("$", "\r")' $EMAIL_RCS_LIST > $ATTACHFILE
      mv $ATTACHFILE ${RACE}/tmp
  fi

  sqlplus << CODE_BLOCK 2>&1 > $LOG
$MPTUSERID
SET SERVEROUTPUT ON FORMAT WRAPPED;
whenever sqlerror exit sql.sqlcode

     exec pkg_email_notify.p_send_email(p_in_process_name        => '${JOBNAME}',    \
                                        p_in_email_name          => '${EMAIL_NAME}',    \
                                        p_in_act_lvl             => '${ACT_LVL}',    \
                                        p_in_host_name           => '${HOST_NAME}',    \
                                        p_in_file_dir            => '${FILEDIR}',    \
                                        p_in_attach_file         => '${ATTACHFILE}');

QUIT;
CODE_BLOCK

#STEP Step999R
  export STEPNAME=Step999R
  echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
  #**************************************************************************************
  #  Remove tmp file
  #**************************************************************************************
   
  rm -f $EMAIL_RCS_LIST
  rm -f $REMOVAL_LIST

#*****************************************************************************************
# END mpt915.ksh
#*****************************************************************************************