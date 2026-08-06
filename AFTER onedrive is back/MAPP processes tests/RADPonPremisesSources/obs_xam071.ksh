#!/bin/ksh
 echo "$Id: xam071.ksh,v 1.1 2002/03/07 23:11:11 jn0132 Exp $"
############################################################################
#  RACE Conversion                                               09/23/96  #
#  PROCNAME:  xam071                                                       #
############################################################################
#*
set -xv
#*
export PROCNAME=$(basename $0 .ksh_run)   
#*
trap 'abndalrt.ksh $?' err    
#*
#**************************************************************
#*     ALT PART COMPRESSED PART FILE TAPE GENERATE FOR        *
#*     DATA TRANSFER TO LAN.                                  *
#*     DATA IS USED BY ALT PART SUPPORT GROUP FOR             *
#*     VALIDATION OF SUPPLIER PROVIDED OEM PART NUMBERS       *
#**************************************************************
#*
#STEP Step010R
#********************************************************************
#* STEP010R                                                         *
#*   EXTRACT ALTERNATE PARTS COMPRESSED PARTS FILE.                 *
#*   PROGRAM XAMZ006                                                *
#********************************************************************
    export STEPNAME=Step010R
    echo "    Start   ${STEPNAME}           "$(date)
#*               
#* export print file with report id
        printpipe -o $RACE/rpt/${JOBNAME}b_ctlcprt
    export DD_PRT006="$RACE/rpt/${JOBNAME}b_ctlcprt.pip"
        printpipe -r $RACE/rpt/${JOBNAME}b_ctlcprt rpt
#*
#* new report
        printpipe -o $RACE/rpt/${JOBNAME}c_xz06cnts
    export DD_RPT1="$RACE/rpt/${JOBNAME}c_xz06cnts.pip"
        printpipe -r $RACE/rpt/${JOBNAME}c_xz06cnts rpt
#*
 export DD_XAMF098=$RACE/prm/xam071b.prm
 export DD_XAMF099=$RACE/tmp/${JOBNAME}_compr_part.tmp
#*
#*
    xamz006  2>&1
#*
        printpipe -c $RACE/rpt/${JOBNAME}b_ctlcprt
        printpipe -c $RACE/rpt/${JOBNAME}c_xz06cnts
#*
#*
#STEP Step020R
#********************************************************************
#* STEP020R                                                         *
#*   SORT EXTRACTED COMPRESSED PARTS FILE AND DROP DUPLICATES       *
#*   TO A FTP FILE                                                  *
#********************************************************************
    export STEPNAME=Step020R
    echo "    Start   ${STEPNAME}           "$(date)
#*
#* SET SORT WORK AREA TO A LARGER SIZE
COBSW=-s100000000
export COBSW
    export DD_SORTIN2=$RACE/tmp/${JOBNAME}_compr_part.tmp
    export DD_SORTOUT2=$RACE/dat/${JOBNAME}_compr_part.ext
#*
#*    sort  -u  -k1.1,1.23 -o $DD_SORTOUT $DD_SORTIN
    xamc080    2>&1
#*
#*
#STEP Step030R 
#**********************************************************************
#*  STEP030r   FTP UNIX COMPRESSED PARTS FILE TO NOVELL DISK          *
#*                 FOR USE BY ALT. PARTS                              *
#**********************************************************************
    export STEPNAME=Step030R
    echo "    Start   ${STEPNAME}           "$(date)
#*
    export DD_SOURCE=$RACE/dat/${JOBNAME}_compr_part.ext
#*********************************************************************
    export DD_DISTIN=comp.dat
#***   make sure operators know to send this to mapp group   *****
#*********************************************************************
    export DD_NOVELDIR=${NOVELL}race
#*********************************************************************
#*
# check that DD_SOURCE file exists and is not null:
 if [ ! -s $DD_SOURCE ] 
 then
 echo "Error: no ALT. PARTS file to ftp!!\a"
 abndalrt ${JOBNAME} ${PROCNAME} ftp_null_file
 fi
#*
 fileput.exp $DD_SOURCE $DD_DISTIN $DD_NOVELDIR | tee $RACE/tmp/$JOBNAME_ftp.wrk
#*
 export GOODBYTECOUNT="$(wc -c $DD_SOURCE | awk '{print $1}')"
 export FTPBYTECOUNT="$(cat $RACE/tmp/$JOBNAME_ftp.wrk \
        | grep 'Information returned by' | awk '{print $1}')"
#*
 if [ $GOODBYTECOUNT -eq $FTPBYTECOUNT ]
 then
  echo "Succeeded ftp of file $DD_SOURCE, bytes =$GOODBYTECOUNT"
 else
 echo "ftp put of file $DD_SOURCE failed: ftp says $FTPBYTECOUNT,"
 echo "real count is $GOODBYTECOUNT"
 abndalrt ${JOBNAME} ${PROCNAME} ftp_null_file
 fi
#*
#STEP Step040R
    echo "    Start Step040R    "$(date)
#**********************************************************************
#*  STEP040r   delete tmp files                                       *
#**********************************************************************
#*
 rm -f  $RACE/tmp/$JOBNAME_ftp.wrk
 rm -f  $RACE/tmp/${JOBNAME}_compr_part.tmp
#*
############################################################################
#  END                                                                     #
############################################################################
