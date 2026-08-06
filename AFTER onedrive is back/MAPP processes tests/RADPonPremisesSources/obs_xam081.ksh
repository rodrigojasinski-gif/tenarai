#!/bin/ksh
 echo "$Id: xam081.ksh,v 1.4 2004/07/28 16:45:00 gw8440 Exp $"
############################################################################
#  RACE Conversion                                               09/24/96  #
#  PROCNAME:  xam081                                                       #
############################################################################

set -xv
export PROCNAME=$(basename $0 .ksh_run)   
trap 'abndalrt.ksh $?' err    


#STEP Step005R                                                             
    export STEPNAME=Step005R
    echo "    Start   ${STEPNAME}           "$(date)
############################################################################
#STEP Step005R                                                             #
#  make sure data is void of ascii control characters.                     #
############################################################################

    export DD_CLEANIN=$( setgdg.ksh "$RACE/dat/xamr076_trans02.dat(+0)" )
    export DD_CLEANTM=$RACE/tmp/${JOBNAME}_work4.tmp
    export DD_CLEANOU=$RACE/tmp/${JOBNAME}_work5.tmp

    cat $DD_CLEANIN | tr -d '\032' | \
        tr '\000-\011\013-\037\177' '[^*]' | \
        tr '\240' '[ *]' |\
        sed 's/\^$//' > $DD_CLEANTM

    cut -b 1-160 $DD_CLEANTM > $DD_CLEANOU


#STEP Step010R
    export STEPNAME=Step010R
    echo "    Start   ${STEPNAME}           "$(date)
#********************************************************************
#* STEP010R                (XAMC003)                                *
#*   REFORMAT ALT SUPPLIER INFORMATION UPLOADED FROM REQUEST        *
#*   PC FILE VIA NOVELL FOR FOLLOWING SORTS.                        *
#*   STEP010, 020, 030, 040, 050 REQUIRED TO ARRANGE DATA IN MOST   *
#*   EFFICIENT SEQUENCE FOR THE ALT PART "PART" UPDATE STEP.        *
#********************************************************************

        printpipe -o $RACE/rpt/${JOBNAME}a_refsupl
    export DD_PRINTER1="$RACE/rpt/${JOBNAME}a_refsupl.pip"
        printpipe -r $RACE/rpt/${JOBNAME}a_refsupl rpt

    export DD_XAMTRAN=$RACE/tmp/${JOBNAME}_work5.tmp
    export DD_OUTTRAN=$RACE/tmp/${JOBNAME}_ref_trans02.tmp

    xamc003 2>&1

        printpipe -c $RACE/rpt/${JOBNAME}a_refsupl


#STEP Step020R
    export STEPNAME=Step020R
    echo "    Start   ${STEPNAME}           "$(date)
#********************************************************************
#* STEP020R                                                         *
#*   SORT REFORMATTED ALT PART INFORMATION INTO SUPPLIER NUMBER,    *
#*   AND RECORD TYPE CODE.  OUTPUT FILE IS INPUT TO STEP060R.       *
#*   OUTPUT SORT FILE CARRIES RECORD CODES "A", "B" AND "C".        *
#*      RECORD CODE "D" IS DROPPED IN THIS SORT.                    *
#*   SORT RETAINS SORT KEY ADDED IN STEP010 PROGRAM.                *
#********************************************************************

    export DD_SORTIN=$RACE/tmp/${JOBNAME}_ref_trans02.tmp
    export DD_SORTOUT=$RACE/tmp/${JOBNAME}_ref_trans02_abc.tmp 

    awk 'substr($0,5,1) != "D" && substr($0,1,4) != "    "' $DD_SORTIN \
    |  sort  -k1.1,1.5 -k1.165,1.166 -k1.5,1.5 -o $DD_SORTOUT

#STEP Step030R
    export STEPNAME=Step030R
    echo "    Start   ${STEPNAME}           "$(date)
#********************************************************************
#* STEP030R                                                         *
#*   SORT REFORMATTED ALT PART INFORMATION INTO MFR NUMBER, OEM     *
#*      PART NUMBER SEQUENCE FOR USE IN FOLLOWING COMPRESSED PART   *
#*      LOOKUP PROGRAM.                                             *
#*   OUTPUT SORT FILE CARRIES ONLY RECORD CODE "D" (PARTS)          *
#*      RECORD CODE "A", "B", AND "C" ARE DROPPED IN THIS SORT.     *
#********************************************************************

    export DD_SORTIN=$RACE/tmp/${JOBNAME}_ref_trans02.tmp
    export DD_SORTOUT=$RACE/tmp/${JOBNAME}_ref_trans02_d.tmp

    awk 'substr($0,5,1) != "A" &&\
         substr($0,5,1) != "B" &&\
         substr($0,5,1) != "C" &&\
         substr($0,1,4) != "    "' $DD_SORTIN \
    |   sort  -k1.31,1.33 -k1.6,1.30 -o $DD_SORTOUT

#STEP Step040R
    export STEPNAME=Step040R
    echo "    Start   ${STEPNAME}           "$(date)
#********************************************************************
#* STEP040R                                                         *
#*     ACCESS PARTS ORACLE TABLE, SUPERSESSION ORACLE TABLE, AND/OR *
#*     COMPRESSED PARTS FILE WITH ALT PART SUPPLIER PROVIDED OEM    *
#*     PART NUMBER TO GET DATABASE FORMATTED PART NUMBER.           *
#*     PROGRAM XAMZ009                                              *
#********************************************************************

        printpipe -o $RACE/rpt/${JOBNAME}d_xz09cnts
    export DD_RPTOUT="$RACE/rpt/${JOBNAME}d_xz09cnts.pip"
        printpipe -r $RACE/rpt/${JOBNAME}d_xz09cnts rpt

    export DD_XAMF012B=$RACE/tmp/${JOBNAME}_ref_trans02_d.tmp
    export DD_XAMF012C=$RACE/tmp/${JOBNAME}_altparts_compr.tmp

    xamz009  2>&1

        printpipe -c $RACE/rpt/${JOBNAME}d_xz09cnts


#STEP Step050R
    export STEPNAME=Step050R
    echo "    Start   ${STEPNAME}           "$(date)
#********************************************************************
#* STEP050R                                                         *
#*   SORT REFORMATTED ALT PART INFORMATION INTO SUPPLIER LOCATION,  *
#*      OEM NUMBER, OEM DATABASE PART NUMBER, SUPPLIER PART,        *
#*      AND NEW/USED CODE SEQUENCE.  OUTPUT FILE INPUT TO STEP070R. *
#*   OUTPUT SORT FILE CARRIES ONLY RECORD CODE "D" (PARTS)          *
#*   DUPS DROPPED - 07/23/2004 PG                                   *
#********************************************************************

    export DD_SORTIN=$RACE/tmp/${JOBNAME}_altparts_compr.tmp
    export DD_SORTOUT=$RACE/tmp/${JOBNAME}_altparts_compr.srt

    sort -T /tmp -u -k1.1,1.4 -k1.192,1.194 -k1.167,1.191 -k1.34,1.58 -k1.155,1.155 -k1.154,1.154 -k1.6,1.25 -o\
     $DD_SORTOUT $DD_SORTIN

#STEP Step055R
    export STEPNAME=Step055R
    echo "    Start   ${STEPNAME}           "$(date)
#********************************************************************
#* STEP055R                                                         *
#*   SAVE A GDG COPY OF THE EDITTED/MANIPULATED FILE (TO SEE WHAT   *
#*   COMPRESSION ROUTINE AND EDIT PROGRAM DID TO TRANSACTIONS.)     *
#********************************************************************

    export DD_FILEIN=$RACE/tmp/${JOBNAME}_altparts_compr.srt
    export DD_FILEOUT=$( setgdg.ksh "$RACE/dat/${JOBNAME}_altparts_compr.dat(+01)" NEW 1)

    mv $DD_FILEIN $DD_FILEOUT


#STEP Step060R
    export STEPNAME=Step060R
    echo "    Start   ${STEPNAME}           "$(date)
#********************************************************************
#* STEP060R                                                         *
#*   UPDATE ALTERNATE PARTS ORACLE TABLES WITH SUPPLIER ADMIN DATA  *
#*   UPLOADED FROM PC VIA NOVELL.                                   *
#*   WRITE REPORT DATA TO ORACLE TABLE FOR LATER REPORTING          *
#*   PROGRAM XAMZ010                                                *
#********************************************************************
 
    export DD_XAMF012=$RACE/tmp/${JOBNAME}_ref_trans02_abc.tmp
    export DD_ADMINOUT=$RACE/tmp/${JOBNAME}_admin_suplr.tmp
 
    xamz010 2>&1
 
#STEP Step070R
    export STEPNAME=Step070R
    echo "    Start   ${STEPNAME}           "$(date)
#********************************************************************
#* STEP070R                                                         *
#*   UPDATE ALTERNATE PARTS ORACLE TABLES WITH SUPPLIER PART INFO   *
#*   UPLOADED FROM PC VIA NOVELL.                                   *
#*   PROGRAM XAMZ001                                                *
#********************************************************************
 
    export DD_XAMF012=$( setgdg.ksh "$RACE/dat/${JOBNAME}_altparts_compr.dat(+01)" )
    export DD_ADMININ=$RACE/tmp/${JOBNAME}_admin_suplr.tmp
 
    xamz001  2>&1
 
 
#STEP Step080R
    export STEPNAME=Step080R
    echo "    Start   ${STEPNAME}           "$(date)
#********************************************************************
#* STEP080R                                                         *
#*   PRODUCE ALTERNATE PART UPDATE REPORTS FOR SUPPLIER ADMIN       *
#*   DATA AND SUPPLIER PARTS DATA.                                  *
#*   DELETE REPORT INFORMATION FROM ORACLE TABLE WHEN REPORT        *
#*   PRINTING IS COMPLETED.                                         *
#*    PROGRAM XAMZ011                                               *
#********************************************************************
 
        printpipe -o $RACE/rpt/${JOBNAME}b_excsupl
    export DD_PRT005="$RACE/rpt/${JOBNAME}b_excsupl.pip"
        printpipe -r $RACE/rpt/${JOBNAME}b_excsupl rpt
 
        printpipe -o $RACE/rpt/${JOBNAME}c_ctlsupl
    export DD_PRT006="$RACE/rpt/${JOBNAME}c_ctlsupl.pip"
        printpipe -r $RACE/rpt/${JOBNAME}c_ctlsupl rpt
 
    xamz011  2>&1
 
        printpipe -c $RACE/rpt/${JOBNAME}c_ctlsupl
        printpipe -c $RACE/rpt/${JOBNAME}b_excsupl
 
 
#STEP Step999R
    export STEPNAME=Step090R
    echo "    Start   ${STEPNAME}           "$(date)
#********************************************************************
#* STEP999R - RUN REMOVE       - DELETE DATASETS THAT WERE CREATED  *
#*                               IN THIS JOB.                       *
#********************************************************************
    export STEPNAME=Step999R
    echo "    Start   ${STEPNAME}           "$(date)
 
 
    rm -f  $RACE/tmp/${JOBNAME}*
 
############################################################################
#  END                                                                     #
############################################################################
