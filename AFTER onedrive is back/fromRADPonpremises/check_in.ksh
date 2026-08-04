#!/bin/ksh 
#$Id: check_in.ksh,v 1.7 2021/07/03 01:20:51 pg2697 Exp $ 
###############################################################################
# SCRIPT NAME: check_in.ksh                                           
# SCRIPT DESC: 05/07/2013 pag - new check_in script for Oracle 11G and beyond. 
#             (Prior script was rcheck_in)   
#
#   This script will 'ci' an object to the designated RCS file.             
#   Stdin is used for the 'ci' source.                                       
#                                                                            
#   COMMAND LINE:                                                            
#                                                                            
#     [-d description] filename subsys/component_dir       
#                                                                            
#   ENVIRONMENT:                                                             
#                                                                            
#     RCSDIR - path of RCS system directory, i.e. race:/prod/race            
#     STGDIR - path of stage directory, i.e. /stage/race                     
#                                                                            
#   MODIFICATION LOG:                                                        
#   05/07/2013 pag - Removed compile of COBOL programs. Cleaned up code. 
#                    Changed commands to use environment variables rather than 
#                    $1 AND $2. 
#   2021/06/24 - PAG - AIX Migration; Chg'd rcp/rsh to scp/ssh.               
#########################################################################################
#set -xv
  trap 'exit -1' err

#echo "executing check_in.ksh \n"                       # For testing
#echo " $1     $2"                                        # For testing

#########################################################################################
# set permissions
# This subtracts 002 from the system defaults to give a default access permission for 
# files of 664 (rw-rw-r--) and for directories of 775 (rwxrwxr-x). 
#########################################################################################
  umask 002                                                

#########################################################################################
# verifies args; tests RCS path and STAGE path
#########################################################################################
  if ! [ $(printenv RCSDIR) ]                              # test RCS default path
  then
    echo "ERROR: need environment variable RCSDIR\007" >&2
    exit -1
  fi

  if ! [ $(printenv STGDIR) ]                              # test STAGE default path
  then
    echo "ERROR: need environment variable STGDIR\007" >&2
    exit -1
  fi

  if [ $# = "0" ]
  then
    echo  USAGE: race_chkin [-d \"change_description\"] filename subsys_name/component_name "\007" >&2
    exit -1
  fi

  DESC_ARG=""                                              # Description argument

  while getopts +"d:" ARG                                  # parse parameters
  do
    if [ $ARG = "d" ]                                    # set -d value
    then
      DESC_ARG=$OPTARG
    else
      echo Unknown parameter "\007" >&2
      exit -1                                            # invalid parameter - exit
    fi
  done

  SUBSYS=$(echo $FILEDIR | awk -F/ '{print $1}')
  if [[ -z $SUBSYS ]]
  then
    echo "ERROR: Invalid Subsystem name "
    exit -1
  fi

  COMPNT_DIR=$(echo $FILEDIR | awk -F/ '{print $2}')
  if [[ -z $COMPNT_DIR ]]
  then
    echo "ERROR: Invalid Component name "
    exit -1
  fi

#echo "RCSDIR: $RCSDIR"
#echo "SUBSYS: $SUBSYS"                                     # For testing
#echo "COMPNT_DIR: $COMPNT_DIR"                             # For testing
#echo "OBJECT_NAME: $FILENAME_EXT"                           # For testing: verify variable created and passed from main script
#echo "OBJECT_DIR: $FILEDIR"                                # For testing: verify variable created and passed from main script

#########################################################################################
# Get stdin
# Write copy of object file to mdev/tmp
# Change file permissions to rwxrwxr--
#########################################################################################
  cat > /tmp/$FILENAME_EXT.tmp
  chmod 774 /tmp/$FILENAME_EXT.tmp  

  #ls -l /tmp/$FILENAME_EXT.tmp                               # For testing: List tmp file on mdev server

#########################################################################################
# Check for remote host.
#########################################################################################
  RCSHOST=$( echo $RCSDIR | awk -F: '/:/ { print $1 }' )
  if [[ -z $RCSHOST ]]                                     
  then
    echo "ERROR: Remote host not defined " >&2
    exit -1
  fi

  RCSNAME=${RCSDIR#$RCSHOST":"}/$FILEDIR/RCS/$FILENAME_EXT,v

#echo "RCSNAME: $RCSNAME"                                  # For testing

#########################################################################################
# Remove remote tmp file (if exists).
# Copy source (in tmp directory on mdev server) to tmp directory on remote server
#########################################################################################

  ssh $RCSHOST rm -f /tmp/$FILENAME_EXT                  
  scp /tmp/$FILENAME_EXT.tmp $RCSHOST":"/tmp/$FILENAME_EXT 2>/dev/null   
  ssh $RCSHOST chmod +w /tmp/$FILENAME_EXT

#########################################################################################
# Determine if file is locked and changed
#removed -e :     if [[ -z $(ssh $RCSHOST rlog -L -R $RCSNAME) ]]
#removed -en: if [[ -z $(ssh $RCSHOST -en rcsdiff -q /tmp/$FILENAME_EXT $RCSNAME | head -5) ]]
#########################################################################################                
  if [[ -n $(ssh $RCSHOST ls $RCSNAME 2>/dev/null) ]]
  then                                                      # check for file 
    if [[ -z $(ssh $RCSHOST rlog -L -R $RCSNAME) ]]
    then                                                    # check for lock
       echo "ERROR: File not locked - $RCSNAME" >&2
       exit -1
    fi
    if [[ -z $(ssh $RCSHOST rcsdiff -q /tmp/$FILENAME_EXT $RCSNAME | head -5) ]]
    then                                                    # check for changes
      echo "ERROR: No changes in file ${FILENAME_EXT} - still checked out with lock." >&2
      exit -1
    fi
  fi

#########################################################################################
# Check In source from /prod/tmp directory
# ci = checkin; -u = unlock; -m = log modification msg -t = writes descriptive text into RCS file; 
#
# NOTE: tmp directory copy is also updated with latest version info during checkin
# It also produces 3 lines of messages:
#       rcs file path <-- tmp file
#       new revision: #.#; previous revision: #.#
#       done
#########################################################################################
  echo "\nRCS checkin started ************************************"
  echo "FILE to be checked in  : $FILENAME_EXT"
  echo "LOCATION for check in  : $RCSNAME"
  echo "MODIFICATION NOTE      : $DESC_ARG"

  ###rsh $RCSHOST -e /prod/util/share/bin/initci -u -m\"$DESC_ARG\" -t\"-$DESC_ARG\" /tmp/$FILENAME_EXT $RCSNAME

  ssh $RCSHOST ci -u -m\"$DESC_ARG\" -t\"-$DESC_ARG\" /tmp/$FILENAME_EXT $RCSNAME
  
#########################################################################################
# Remove rollback file in stage
# Backup previous stage file into stage rollback directory
# Remove previous stage file
# Remote copy prod tmp file (new checked_in version) into stage directory
# Change permissions of file in stage
#########################################################################################
  if [[ -a $STGDIR/$FILEDIR/$FILENAME_EXT ]]          # if object exists in stage directory                      
  then
    rm -f $STGDIR/$FILEDIR/rollback/$FILENAME_EXT
    #echo "\n Backup previous stage: copying $STGDIR/$FILEDIR/$FILENAME_EXT to $STGDIR/$FILEDIR/rollback"      
    cp -p $STGDIR/$FILEDIR/$FILENAME_EXT $STGDIR/$FILEDIR/rollback 2>/dev/null      # copy to rollback
    rm -f $STGDIR/$FILEDIR/$FILENAME_EXT
  fi
  #echo "\n Creating new stage from prod RCS: copying $RCSHOST":"/tmp/$FILENAME_EXT to $STGDIR/$FILENAME_EXT"   
  scp $RCSHOST":"/tmp/$FILENAME_EXT $STGDIR/$FILEDIR                                # copy remote source to stage
  chmod ug+wx $STGDIR/$FILEDIR/$FILENAME_EXT

#########################################################################################
# remove prod/tmp and mdev/tmp files
#########################################################################################
  ssh $RCSHOST rm -f /tmp/$FILENAME_EXT                # remove prod/tmp file
  rm  /tmp/$FILENAME_EXT.tmp                              # remove mdev tmp

#########################################################################################
# end of check_in.ksh
#########################################################################################
