#!/bin/ksh
#$Id: xam099.ksh,v 1.1 2002/03/07 23:10:28 jn0132 Exp $
############################################################################
#  RACE Conversion                                               03/05/97  #
#  PROCNAME:  xam099                                                       #
############################################################################

export PROCNAME=$(basename $0 .ksh)

set -xv

trap 'abndalrt.ksh $?' err

 echo "$Id: xam099.ksh,v 1.1 2002/03/07 23:10:28 jn0132 Exp $"

#STEP Step010 
    export STEPNAME=Step010
    echo "    Start " ${STEPNAME} "    "$(date)
#*********************************************                         
#* THIS STEP CHECK FOR INPUT FILE AND ABORT  *                         
#* JOB IF NOT EXISTS                         *                         
#*********************************************                         
 
    if ! [ -s $RACE/dat/xamx098_acdelco.dat ]
    then                                                         
        trap 'abndalrt.ksh $?' err
    fi
     
#STEP Step020R
    export STEPNAME=Step020R
    echo "    Start " ${STEPNAME} "    "$(date)
#*********************************************                         
#* CONVERT ACDELCO FILE FROM ebcdic TO ascii *                         
#*********************************************                         
 
    export DD_FILEIN=$RACE/dat/xamx098_acdelco.dat 
    export DD_FILEOUT=$RACE/tmp/${JOBNAME}_acdelco.tmp 
     
    ebcdic2a $DD_FILEIN >  $DD_FILEOUT 
     
#STEP Step030R
    export STEPNAME=Step030R
    echo "    Start " ${STEPNAME} "    "$(date)
#*******************************************************               
#* EXTRACT PART INFO FROM AC DELCO TAPE FOR DOWNLOADING*               
#*******************************************************               
 
    export DD_ACDRAW=$RACE/tmp/${JOBNAME}_acdelco.tmp 
    export DD_ACDEXT=$(setgdg.ksh "$RACE/dat/${JOBNAME}_acdelco.ext($gdg01)" NEW 2)
        printpipe -o $RACE/rpt/${JOBNAME}a_cntl
    export DD_CNTLRPT="$RACE/rpt/${JOBNAME}a_cntl.pip"
        printpipe -r $RACE/rpt/${JOBNAME}a_cntl rpt
                                                                       
    xamc010     2>&1
     
        printpipe -c $RACE/rpt/${JOBNAME}a_cntl

#STEP Step040R
    export STEPNAME=Step040R
    echo "    Start " ${STEPNAME} "    "$(date)
#***************************************************************************
#*      STEP030R: FTP ACDELCO FILE TO NOVELL                               *
#*                CHECK I/O BYTE COUNT                                     *                   
#**************************************************************************

    export DD_OUTFILE=$(setgdg.ksh "$RACE/dat/${JOBNAME}_acdelco.ext($gdg01)" )
  
# check that DD_OUTFILE file exists and is not null:
	if [ ! -s $DD_OUTFILE ] 
	then
		echo "Error: no acdelco file to ftp!!\a"
        abndalrt.ksh ftp_null_file
	fi

	fileput.exp $DD_OUTFILE acdelco.dat ${NOVELL}race | tee $RACE/tmp/$JOBNAME.ftp.wrk

	export GOODBYTECOUNT="$(wc -c $DD_OUTFILE | awk '{print $1}')"
	export FTPBYTECOUNT="$(cat $RACE/tmp/$JOBNAME.ftp.wrk | grep 'Information returned by' | awk '{print $1}')"

	echo; date

	if [ $GOODBYTECOUNT -eq $FTPBYTECOUNT ]
	then
		echo "Succeeded ftp of file $DD_OUTFILE, bytes =$GOODBYTECOUNT"
	else
		echo "ftp put of file $DD_OUTFILE failed: ftp says $FTPBYTECOUNT, real count is $GOODBYTECOUNT"
        abndalrt.ksh ftp_put
	fi
     
#STEP Step999R 
    export STEPNAME=Step999R
    echo "    Start " ${STEPNAME} "    "$(date)
#*********************************************                         
#* REMOVE TEMP FILES                         *                         
#*********************************************                         
 
  rm -f $RACE/tmp/${JOBNAME}_acdelco.tmp 
   
#*******************************************************               
#* END                                                 *               
#*******************************************************               
