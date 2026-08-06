#!/bin/ksh
 echo "$Id: xam075.ksh,v 1.1 2002/03/07 23:10:19 jn0132 Exp $"
############################################################################
#  RACE Conversion                                               09/06/96  #
#  PROCNAME:  xam075                                                       #
############################################################################

set -xv
export PROCNAME=$(basename $0 .ksh_run)   
trap 'abndalrt.ksh      $?' err    

#STEP Step005R                                                              
     export STEPNAME=Step005R
     echo "    Start   ${STEPNAME}           "$(date)
#*---------------------------------------------------------------
#  EXECUTE FILE GET AND PASS THE NOVELL FILE TO UNIX                      
#  THEN CHECK DIRECTORY COUNTS ON BOTH SIDES TO VALIDATE THE TRANSFER      
#*---------------------------------------------------------------

     export DD_NOVELDSK=mapp01.dat
     export DD_UNXDISK=$RACE/dat/${JOBNAME}_trans01.xfr 
     export DD_NOVELDIR=${NOVELL}race
     export DD_STDOUT=$RACE/tmp/${JOBNAME}_work1.tmp

     fileget.exp $DD_NOVELDSK $DD_UNXDISK $DD_NOVELDIR \
     | tee   $DD_STDOUT

   novelcount=$( grep 'Information ret' $DD_STDOUT | awk '{print $1}') 
   unixcount=$(wc -c $DD_UNXDISK | awk '{print $1}') 

#* ******* ???????? maybe check here for an empty file and abend if empty *****
   if [ novelcount -eq unixcount ]
       then
          echo " ftp directory counts are good "
       else
          echo " ***** error ***** ftp directory counts do not match "
          echo " UNIX byte count = $unixcount "
          abndalrt.ksh ftp_get
   fi

#STEP Step010R 
    export STEPNAME=Step010R
    echo "    Start   ${STEPNAME}           "$(date)
#*---------------------------------------------------------------
#*   STEP010R COPY NORMAL MAPP UPLOAD TRANSACTIONS FILE
#*   TO GDG    
#*---------------------------------------------------------

    export DD_SYSUT1=$RACE/dat/${JOBNAME}_trans01.xfr
    export DD_CATUT1=$RACE/tmp/${JOBNAME}_trans01.tmp
    export DD_SYSUT2=$RACE/tmp/${JOBNAME}_work2.tmp

#* remove carriage return from file
    cat $DD_SYSUT1 | tr -d "\r" > $DD_CATUT1

    cp $DD_CATUT1 $DD_SYSUT2 2>&1


#STEP Step020R
    export STEPNAME=Step020R
    echo "    Start   ${STEPNAME}           "$(date)
#*---------------------------------------------------------
#*       STEP020R   Remove Invalid Transactions
#*---------------------------------------------------------

    export DD_FILEIN=$RACE/tmp/${JOBNAME}_work2.tmp
    export DD_FILEOUT=$( setgdg.ksh \
           "$RACE/dat/${JOBNAME}_trans01.dat(+1)" NEW 6 )

        printpipe -o $RACE/rpt/${JOBNAME}a_err_rpt
    export DD_PRINTER1="$RACE/rpt/${JOBNAME}a_err_rpt.pip"
        printpipe -r $RACE/rpt/${JOBNAME}a_err_rpt rpt

    export DD_INTRAN=$RACE/tmp/${JOBNAME}_work2.tmp
    export DD_OUTTRAN=$( setgdg.ksh \
           "$RACE/dat/${JOBNAME}_trans01.dat(+1)" NEW 4 )

    xamc004 2>&1

        printpipe -c $RACE/rpt/${JOBNAME}a_err_rpt


#STEP Step999R
    export STEPNAME=Step999R
    echo "    Start   ${STEPNAME}           "$(date)
#*---------------------------------------------------------
#*       STEP999R   delete tmp datasets
#*---------------------------------------------------------

    rm -f $RACE/tmp/${JOBNAME}*

############################################################################
#  END                                                                     #
############################################################################
