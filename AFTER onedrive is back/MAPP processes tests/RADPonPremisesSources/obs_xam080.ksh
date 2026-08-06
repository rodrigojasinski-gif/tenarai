#!/bin/ksh     
 echo "$Id: xam080.ksh,v 1.1 2002/03/07 23:10:24 jn0132 Exp $"
############################################################################
#  RACE Conversion                                               09/24/96  #
#  PROCNAME:  xam080                                                       #
############################################################################
  
set -xv
  
export PROCNAME=$(basename $0 .ksh_run)   
  
trap 'abndalrt.ksh $?' err    
  
############################################################################
#STEP Step005R                                                             #
#  make sure data is void of ascii control characters.                     #
############################################################################
    export STEPNAME=Step005R
    echo "    Start   ${STEPNAME}           "$(date)
  
    export DD_CLEANIN=$( setgdg.ksh "$RACE/dat/xamd075_trans01.dat(+0)" )
    export DD_CLEANOU=$RACE/tmp/${JOBNAME}_work5.tmp
  
 cat $DD_CLEANIN | tr -d '\032' | \
     tr '\000-\011\013-\037\177' '[^*]' | \
     sed 's/\^$//' > $DD_CLEANOU

#STEP Step010R
#********************************************************************
#* STEP010R                (XAMC003)                                *
#*   REFORMAT ALT SUPPLIER INFORMATION UPLOADED FROM NORMAL         *
#*   PC FILE VIA NOVELL FOR FOLLOWING SORTS.                        *
#*   STEP010, 020, 030, 040, 050 REQUIRED TO ARRANGE DATA IN MOST   *
#*   EFFICIENT SEQUENCE FOR THE ALT PART "PART" UPDATE STEP.        *
#********************************************************************
    export STEPNAME=Step010R
    echo "    Start   ${STEPNAME}           "$(date)
  
        printpipe -o $RACE/rpt/${JOBNAME}a_refsuplr
    export DD_PRINTER1="$RACE/rpt/${JOBNAME}a_refsuplr.pip"
        printpipe -r $RACE/rpt/${JOBNAME}a_refsuplr rpt
  
    export DD_XAMTRAN=$RACE/tmp/${JOBNAME}_work5.tmp
    export DD_OUTTRAN=$RACE/tmp/${JOBNAME}_ref_trans01.tmp
  
    xamc003 2>&1
  
        printpipe -c $RACE/rpt/${JOBNAME}a_refsuplr

#STEP Step020R
#********************************************************************
#* STEP020R                                                         *
#*   SORT REFORMATTED ALT PART INFORMATION INTO SUPPLIER NUMBER,    *
#*   AND RECORD TYPE CODE.  OUTPUT FILE IS INPUT TO STEP060R.       *
#*   OUTPUT SORT FILE CARRIES RECORD CODES "A", "B" AND "C".        *
#*      RECORD CODE "D" IS DROPPED IN THIS SORT.                    *
#*   SORT RETAINS SORT KEY ADDED IN STEP010 PROGRAM                 *
#********************************************************************
    export STEPNAME=Step020R
    echo "    Start   ${STEPNAME}           "$(date)
  
    export DD_SORTIN=$RACE/tmp/${JOBNAME}_ref_trans01.tmp
    export DD_SORTOUT=$RACE/tmp/${JOBNAME}_ref_trans01_abc.srt
  
    awk 'substr($0,5,1) != "D" && substr($0,1,4) != "    "' $DD_SORTIN \
    |  sort  -k1.1,1.5 -k1.165,1.166 -k1.5,1.5 -o $DD_SORTOUT 
  
#STEP Step030R
#********************************************************************
#* STEP030R                                                         *
#*   SORT REFORMATTED ALT PART INFORMATION INTO MFR NUMBER, OEM     *
#*      PART NUMBER SEQUENCE FOR USE IN FOLLOWING COMPRESSED PART   *
#*      LOOKUP PROGRAM.                                             *
#*   OUTPUT SORT FILE CARRIES ONLY RECORD CODE "D" (PARTS)          *
#*      RECORD CODE "A", "B", AND "C" ARE DROPPED IN THIS SORT.     *
#*   SORT RETAINS SORT KEY ADDED IN STEP010 DYL280 PROGRAM.         *
#********************************************************************
    export STEPNAME=Step030R
    echo "    Start   ${STEPNAME}           "$(date)
  
    export DD_SORTIN=$RACE/tmp/${JOBNAME}_ref_trans01.tmp
    export DD_SORTOUT=$RACE/tmp/${JOBNAME}_ref_trans01_d.tmp
  
    awk 'substr($0,5,1) != "A" &&\
         substr($0,5,1) != "B" &&\
         substr($0,5,1) != "C" &&\
         substr($0,1,4) != "    "' $DD_SORTIN \
    |   sort  -k1.31,1.33 -k1.6,1.30 -o $DD_SORTOUT 
  
#STEP Step040R
#********************************************************************
#* STEP040R                                                         *
#*     ACCESS PARTS ORACLE TABLE, SUPERSESSION  TABLE, AND/OR       *
#*     COMPRESSED PARTS FILE WITH ALT PART SUPPLIER PROVIDED OEM    *
#*     PART NUMBER TO GET DATABASE FORMATTED PART NUMBER.           *
#*     PROGRAM XAMZ009                                              *
#********************************************************************
    export STEPNAME=Step040R
    echo "    Start   ${STEPNAME}           "$(date)
   
        printpipe -o $RACE/rpt/${JOBNAME}d_xz09cnts    
    export DD_RPTOUT="$RACE/rpt/${JOBNAME}d_xz09cnts.pip"
        printpipe -r $RACE/rpt/${JOBNAME}d_xz09cnts rpt
  
    export DD_XAMF012B=$RACE/tmp/${JOBNAME}_ref_trans01_d.tmp
    export DD_XAMF012C=$RACE/tmp/${JOBNAME}_altparts_compr.tmp
  
    xamz009  2>&1
  
        printpipe -c $RACE/rpt/${JOBNAME}d_xz09cnts 

#STEP Step050R
#********************************************************************
#*   SORT REFORMATTED ALT PART INFORMATION INTO SUPPLIER LOCATION,  *
#*      OEM NUMBER, OEM DATABASE PART NUMBER, SUPPLIER PART,        *
#*      AND NEW/USED CODE SEQUENCE.  OUTPUT FILE INPUT TO STEP070R. *
#*   OUTPUT SORT FILE CARRIES ONLY RECORD CODE "D" (PARTS)          *
#********************************************************************
    export STEPNAME=Step050R
    echo "    Start   ${STEPNAME}           "$(date)
  
    export DD_SORTIN=$RACE/tmp/${JOBNAME}_altparts_compr.tmp
    export DD_SORTOUT=$RACE/tmp/${JOBNAME}_altparts_compr.srt
  
    sort  -k1.1,1.4 -k1.192,1.194 -k1.165,1.189 -k1.34,1.58 -k1.155,1.155 -o\
     $DD_SORTOUT $DD_SORTIN

#STEP Step060R
#********************************************************************
#* STEP060R                                                         *
#*   UPDATE ALTERNATE PARTS ORACLE TABLES WITH SUPPLIER ADMIN DATA  *
#*   UPLOADED FROM PC VIA NOVELL.                                   *
#*   WRITE REPORT DATA TO ORACLE TABLE FOR LATER REPORTING          *
#*   PROGRAM XAMZ010                                                *
#********************************************************************
    export STEPNAME=Step060R
    echo "    Start   ${STEPNAME}           "$(date)
  
    export DD_XAMF012=$RACE/tmp/${JOBNAME}_ref_trans01_abc.srt
    export DD_ADMINOUT=$RACE/tmp/${JOBNAME}_admin_suplr.tmp
  
    xamz010  2>&1

#STEP Step070R
#********************************************************************
#* STEP070R                                                         *
#*   UPDATE ALTERNATE PARTS ORACLE TABLES WITH SUPPLIER PART INFO   *
#*   UPLOADED FROM PC VIA NOVELL.                                   *
#*   PROGRAM XAMZ001                                                *
#********************************************************************
    export STEPNAME=Step070R
    echo "    Start   ${STEPNAME}           "$(date)
   
    export DD_ADMININ=$RACE/tmp/${JOBNAME}_admin_suplr.tmp
    export DD_XAMF012=$RACE/tmp/${JOBNAME}_altparts_compr.srt
  
    xamz001  2>&1

#STEP Step080R
#********************************************************************
#* STEP080R                                                         *
#*   PRODUCE ALTERNATE PART UPDATE REPORTS FOR SUPPLIER ADMIN       *
#*   DATA AND SUPPLIER PARTS DATA.                                  *
#*   DELETE REPORT INFORMATION FROM ORACLE TABLE WHEN REPORT        *
#*   PRINTING IS COMPLETED.                                         *
#*   PROGRAM XAMZ011                                                *
#********************************************************************
    export STEPNAME=Step080R
    echo "    Start   ${STEPNAME}           "$(date)
   
        printpipe -o $RACE/rpt/${JOBNAME}b_excsuplr
    export DD_PRT005="$RACE/rpt/${JOBNAME}b_excsuplr.pip"
        printpipe -r $RACE/rpt/${JOBNAME}b_excsuplr rpt
   
        printpipe -o $RACE/rpt/${JOBNAME}c_ctlsuplr
    export DD_PRT006="$RACE/rpt/${JOBNAME}c_ctlsuplr.pip"
        printpipe -r $RACE/rpt/${JOBNAME}c_ctlsuplr rpt
  
    xamz011  2>&1
  
        printpipe -c $RACE/rpt/${JOBNAME}c_ctlsuplr
        printpipe -c $RACE/rpt/${JOBNAME}b_excsuplr
  
#STEP Step999R
#********************************************************************
#* STEP999R - DELETE TMP DATASETS CREATED IN THIS JOB               *
#********************************************************************
    export STEPNAME=Step999R
    echo "    Start   ${STEPNAME}           "$(date)
   
    rm -f  $RACE/tmp/${JOBNAME}_ref_trans01.tmp
    rm -f  $RACE/tmp/${JOBNAME}_ref_trans01_abc.srt
    rm -f  $RACE/tmp/${JOBNAME}_ref_trans01_d.tmp
    rm -f  $RACE/tmp/${JOBNAME}_altparts_compr.tmp
    rm -f  $RACE/tmp/${JOBNAME}_altparts_compr.srt
    rm -f  $RACE/tmp/${JOBNAME}_admin_suplr.tmp
    rm -f  $RACE/tmp/${JOBNAME}_work5.tmp
     
############################################################################
#  END                                                                     #
############################################################################
