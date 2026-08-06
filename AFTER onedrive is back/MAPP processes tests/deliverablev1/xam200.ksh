#!/bin/ksh
echo "$Id: xam200.ksh,v 1.9 2019/05/08 22:22:05 jl101765 Exp $"
############################################################################
#  PROCNAME:  xam200                                                       #
#  PROC DESCRIPTION: TRANSFER NAPA FILE(S) FROM MITCHELL SERVER AND        #
#                    PREPARE FOR TRANSACTION LOAD PROCESS.                 #
#                                                                          #
# MODIFIED:                                                                #
############################################################################

set -xv
export PROCNAME=$(basename $0 .ksh_run)
trap 'abndalrt.ksh $?' err

# Change rj132422 - 20260424 - MAPP/ALTP file paths now come from race_altp.ksh
# Replaces the legacy prod3nt / ${NOVELL} FTP dependency.

export RPTDATE=$(date +'%C%y%m%d%H%M%S')

#STEP Step010R
    export STEPNAME=Step010R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#   1) COPY napa'S ZIP FILE FROM MITCHELL'S FTP TO RACE SERVER      *
#   2) CHECK FOR EMPTY FTP FILE                                     *
#   3) ABORT JOB IF FTP FILE IS EMPTY                               *
#********************************************************************

    export FTPFILE=$FTP_SITE:$FTP_BUSINESS_PATH/NAPA/$ACT_LVL/incoming/Mitchell_CollisionFromNAPA*
    export ZIPFILE=$RACE/tmp/${JOBNAME}_napa.zip
    rm -f $ZIPFILE
    scp $FTPFILE $ZIPFILE
    # Verify that the file copied exists and that it contains data
    if [ ! -s ${ZIPFILE} ]
    then
# Change rj132422 - 20260424 - AIX->RHEL: use print for reliable \n handling on ksh93
       print "\n*********************************************************************************"
       print "File that was copied is empty or it does not exist!"
       print "Source: ${FTPFILE}"
       print "Target: ${ZIPFILE}"
       print "*********************************************************************************\n"
       $( abndalrt.ksh 911 )
    fi


#STEP Step011R
    export STEPNAME=Step011R
    echo "    Start " ${STEPNAME} "    "$(date)
##########################################################################
#  1. FTP zip file to NT server (for Data Analyst's copy)                #
##########################################################################

    export FTPFILE=$RACE/tmp/${JOBNAME}_napa.zip
    export NTFILE=CollisionFromNapa.zip
# Change rj132422 - 20260424 - Remove prod3nt dependency; use NFS-mounted path
    export NTDIR=${ALTP_NAPA_DIR}
    export FTPLOG=$RACE/tmp/${JOBNAME}_napa_zip_ftp.tmp

    cp $FTPFILE ${NTDIR}/${NTFILE} > $FTPLOG 2>&1

    if [[ ! -s ${NTDIR}/${NTFILE} ]]
    then
       print " ***** error ***** file copy failed - target missing or empty "
       print " SOURCE = $FTPFILE "
       cat $FTPLOG 2>/dev/null
       abndalrt.ksh ftp_get
    fi

    ntcount=$(wc -c ${NTDIR}/${NTFILE} 2>/dev/null | awk '{print $1}')
    unixcount=$(wc -c $FTPFILE 2>/dev/null | awk '{print $1}')

    if [[ -n "$ntcount" && "$ntcount" = "$unixcount" ]]
      then
       print " file copy counts are good "
    else
       print " ***** error ***** file copy counts do not match "
       print " SOURCE byte count = $unixcount "
       print " TARGET byte count = $ntcount "
       abndalrt.ksh ftp_get
    fi

#STEP Step020R
    export STEPNAME=Step020R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#   1) SAVE DIRECTORY THAT YOU'RE CURRENTLY IN                      *
#   2) CHANGE TO TMP DIRECTORY SO THAT YOU CAN EXTRACT FILE FROM ZIP*
#   3) UNZIP ALTPARTS FILE                                          *
#   4) ABORT JOB IF PROBLEM W/ UNZIPPED FILE                        *
#   5) RENAME UNZIPPED FILE TO MITCHELL NAME                        *
#   6) CHANGE BACK TO EXECUTION DIRECTORY                           *
#********************************************************************

    export ZIPFILE=${JOBNAME}_napa.zip
    export RAWFILE1=${JOBNAME}_napa_altparts.tmp

    export SAVEDIR=`pwd`
    export TEMPDIR=$RACE/tmp
    cd $TEMPDIR

    unzip -u $ZIPFILE pp_col_altparts*.txt

    mv pp_col_altparts*.txt $RAWFILE1

    reccnt1=$(wc -c $RAWFILE1 | awk ' {print $1}' )

# Change rj132422 - 20260424 - AIX->RHEL: quote vars and use [[ ]] for safe test
    if [[ "$reccnt1" -eq 0 ]]
        then echo " unzipped input file is no good "
             $( abndalrt.ksh 911 )
        else
             echo "unzipped file is good"
    fi

    cd $SAVEDIR

#STEP Step022R
    export STEPNAME=Step022R
    echo "    Start " ${STEPNAME} "    "$(date)
##########################################################################
#  make sure ALTPARTS file is void of ascii control characters           #
##########################################################################

    export INPUT_FILE=$RACE/tmp/${JOBNAME}_napa_altparts.tmp
    export OUTPUT_FILE=$RACE/tmp/${JOBNAME}_napa_altparts_clean.tmp
    export TEMP_FILE=$RACE/tmp/${JOBNAME}_napa_altparts_clean_checkit.tmp

    ascii_cleanup.ksh ${INPUT_FILE} ${OUTPUT_FILE} ${TEMP_FILE}

#STEP Step025R
    export STEPNAME=Step025R
    echo "    Start " ${STEPNAME} "    "$(date)
#*****************************************************************************
# Save ALTPARTS file to the dat directory to prepare for Oracle reformat.    *
#*****************************************************************************
    export TMPIN=$RACE/tmp/${JOBNAME}_napa_altparts_clean.tmp
    export DATOUT=$RACE/dat/${JOBNAME}_xtab_raw_napa_altparts.dat

    mv $TMPIN $DATOUT


#STEP Step030R
    export STEPNAME=Step030R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#   1) SAVE DIRECTORY THAT YOU'RE CURRENTLY IN                      *
#   2) CHANGE TO TMP DIRECTORY SO THAT YOU CAN EXTRACT FILE FROM ZIP*
#   3) UNZIP INSURANCE FILE                                         *
#   4) ABORT JOB IF PROBLEM W/ UNZIPPED FILE                        *
#   5) RENAME UNZIPPED FILE TO MITCHELL NAME                        *
#   6) CHANGE BACK TO EXECUTION DIRECTORY                           *
#********************************************************************

    export ZIPFILE=${JOBNAME}_napa.zip
    export RAWFILE2=${JOBNAME}_napa_insurance.tmp

    export SAVEDIR=`pwd`
    export TEMPDIR=$RACE/tmp
    cd $TEMPDIR

    unzip -u $ZIPFILE pp_col_insurance*.txt

    mv pp_col_insurance*.txt $RAWFILE2

    reccnt1=$(wc -c $RAWFILE2 | awk ' {print $1}' )

# Change rj132422 - 20260424 - AIX->RHEL: quote vars and use [[ ]] for safe test
    if [[ "$reccnt1" -eq 0 ]]
        then echo " unzipped input file is no good "
             $( abndalrt.ksh 911 )
        else
             echo "unzipped file is good"
    fi

    cd $SAVEDIR

#STEP Step032R
    export STEPNAME=Step032R
    echo "    Start " ${STEPNAME} "    "$(date)
##########################################################################
#  make sure INSURANCE file is void of ascii control characters          #
##########################################################################

    export INPUT_FILE=$RACE/tmp/${JOBNAME}_napa_insurance.tmp
    export OUTPUT_FILE=$RACE/tmp/${JOBNAME}_napa_insurance_clean.tmp
    export TEMP_FILE=$RACE/tmp/${JOBNAME}_napa_insurance_clean_checkit.tmp

    ascii_cleanup.ksh ${INPUT_FILE} ${OUTPUT_FILE} ${TEMP_FILE}

#STEP Step035R
    export STEPNAME=Step035R
    echo "    Start " ${STEPNAME} "    "$(date)
#*****************************************************************************
# Save INSURANCE file to the dat directory to prepare for Oracle reformat.   *
#*****************************************************************************
    export TMPIN=$RACE/tmp/${JOBNAME}_napa_insurance_clean.tmp
    export DATOUT=$RACE/dat/${JOBNAME}_xtab_raw_napa_insurance.dat

    mv $TMPIN $DATOUT


#STEP Step040R
    export STEPNAME=Step040R
    echo "    Start " ${STEPNAME} "    "$(date)
##########################################################################
#  using Oracle, create flat fixed width files                           #
##########################################################################

    export XAMUSERID=`cat $RACE/prm/zxampass.prm`
    export REFDIR=$OBJ_TMPDIR
    export REFFILE1=${JOBNAME}_ref_napa_altparts.tmp
    export REFFILE2=${JOBNAME}_ref_napa_insurance.tmp
    export RPTDIR=$OBJ_RPTDIR
    export RPTFILE=${JOBNAME}d_ref_NAPA_delim_${RPTDATE}.rpt

sqlplus << CODE_BLOCK 2>&1 > $LOG
$XAMUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 250;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec SP_REF_XAM200_NAPA_US('$REFDIR','$REFFILE1','$REFFILE2','$RPTDIR','$RPTFILE');

QUIT;
CODE_BLOCK

# manage report versions
rpt_log_retention.ksh "${JOBNAME}d"

#STEP Step045R
    export STEPNAME=Step045R
    echo "    Start " ${STEPNAME} "    "$(date)
##########################################################################
#  1. FTP altparts "ref" file to NT server (for Data Analyst's copy)     #
#     NOTE: can't do file count balancing on ascii transfers             #
##########################################################################

    export FTPFILE=$RACE/tmp/${JOBNAME}_ref_napa_altparts.tmp
    export NTFILE=col.txt
# Change rj132422 - 20260424 - Remove prod3nt dependency; use NFS-mounted path
    export NTDIR=${ALTP_NAPA_DIR}
    export FTPLOG=$RACE/tmp/${JOBNAME}_ref_napa_altparts_ftp.tmp

# sed adds CR to preserve the former 'ascii' fileput behavior (LF -> CRLF for Windows analysts)
    sed 's/\r*$/\r/' $FTPFILE > ${NTDIR}/${NTFILE} 2>$FTPLOG


#STEP Step048R
    export STEPNAME=Step048R
    echo "    Start " ${STEPNAME} "    "$(date)
##########################################################################
#  1. FTP insurance "ref" file to NT server (for Data Analyst's copy)    #
#     NOTE: can't do file count balancing on ascii transfers             #
##########################################################################

    export FTPFILE=$RACE/tmp/${JOBNAME}_ref_napa_insurance.tmp
    export NTFILE=colnw.txt
# Change rj132422 - 20260424 - Remove prod3nt dependency; use NFS-mounted path
    export NTDIR=${ALTP_NAPA_DIR}
    export FTPLOG=$RACE/tmp/${JOBNAME}_ref_napa_insurance_ftp.tmp

# sed adds CR to preserve the former 'ascii' fileput behavior (LF -> CRLF for Windows analysts)
    sed 's/\r*$/\r/' $FTPFILE > ${NTDIR}/${NTFILE} 2>$FTPLOG


#STEP Step050R
  export STEPNAME=Step050R
  echo "    Start   ${STEPNAME}           "$(date)
############################################################################
#  1. EXECUTE FILE GET TO TRANSFER FILE HEADERS FROM NT TO UNIX            #
#  2. CHECK DIRECTORY COUNTS ON BOTH SIDES TO VALIDATE THE TRANSFER        #
############################################################################

  export NTFILE=COL.hdr
  export UNXFILE=$RACE/tmp/${JOBNAME}_napa_col_hdr.xfr
# Change rj132422 - 20260424 - Remove prod3nt dependency; use NFS-mounted path
  export NTDIR=${ALTP_NAPA_DIR}
  export FTPLOG=$RACE/tmp/${JOBNAME}_napa_col_hdr_ftp.tmp

  rm -f $UNXFILE
  cp ${NTDIR}/${NTFILE} ${UNXFILE} > $FTPLOG 2>&1

  if [[ ! -s ${UNXFILE} ]]
  then
       print " ***** error ***** file copy failed - target missing or empty "
       print " SOURCE = ${NTDIR}/${NTFILE} "
       cat $FTPLOG 2>/dev/null
       abndalrt.ksh ftp_get
  fi

  ntcount=$(wc -c ${NTDIR}/${NTFILE} 2>/dev/null | awk '{print $1}')
  unixcount=$(wc -c ${UNXFILE} 2>/dev/null | awk '{print $1}')

  if [[ -n "$ntcount" && "$ntcount" = "$unixcount" ]]
    then
       print " file copy counts are good "
  else
       print " ***** error ***** file copy counts do not match "
       print " SOURCE byte count = $ntcount "
       print " TARGET byte count = $unixcount "
       abndalrt.ksh ftp_get
  fi

#STEP Step055R
  export STEPNAME=Step055R
  echo "    Start   ${STEPNAME}           "$(date)
#***************************************************************************
#* 1. MAKE SURE DATA IS VOID OF ASCII CONTROL CHARACTERS                   *
#***************************************************************************

  export INPUT_FILE="$RACE/tmp/${JOBNAME}_napa_col_hdr.xfr"
  export OUTPUT_FILE="$RACE/tmp/${JOBNAME}_napa_col_hdr_clean.tmp"
  export TEMP_FILE=$RACE/tmp/${JOBNAME}_napa_col_clean_checkit.tmp

  ascii_cleanup.ksh ${INPUT_FILE} ${OUTPUT_FILE} ${TEMP_FILE}


#STEP Step060R
  export STEPNAME=Step060R
  echo "    Start   ${STEPNAME}           "$(date)
############################################################################
#  1. EXECUTE FILE GET TO TRANSFER FILE HEADERS FROM NT TO UNIX            #
#  2. CHECK DIRECTORY COUNTS ON BOTH SIDES TO VALIDATE THE TRANSFER        #
############################################################################

  export NTFILE=COLNW.hdr
  export UNXFILE=$RACE/tmp/${JOBNAME}_napa_colnw_hdr.xfr
# Change rj132422 - 20260424 - Remove prod3nt dependency; use NFS-mounted path
  export NTDIR=${ALTP_NAPA_DIR}
  export FTPLOG=$RACE/tmp/${JOBNAME}_napa_colnw_hdr_ftp.tmp

  rm -f $UNXFILE
  cp ${NTDIR}/${NTFILE} ${UNXFILE} > $FTPLOG 2>&1

  if [[ ! -s ${UNXFILE} ]]
  then
       print " ***** error ***** file copy failed - target missing or empty "
       print " SOURCE = ${NTDIR}/${NTFILE} "
       cat $FTPLOG 2>/dev/null
       abndalrt.ksh ftp_get
  fi

  ntcount=$(wc -c ${NTDIR}/${NTFILE} 2>/dev/null | awk '{print $1}')
  unixcount=$(wc -c ${UNXFILE} 2>/dev/null | awk '{print $1}')

  if [[ -n "$ntcount" && "$ntcount" = "$unixcount" ]]
    then
       print " file copy counts are good "
  else
       print " ***** error ***** file copy counts do not match "
       print " SOURCE byte count = $ntcount "
       print " TARGET byte count = $unixcount "
       abndalrt.ksh ftp_get
  fi


#STEP Step065R
  export STEPNAME=Step065R
  echo "    Start   ${STEPNAME}           "$(date)
#***************************************************************************
#* 1. MAKE SURE DATA IS VOID OF ASCII CONTROL CHARACTERS                   *
#***************************************************************************


  export INPUT_FILE="$RACE/tmp/${JOBNAME}_napa_colnw_hdr.xfr"
  export OUTPUT_FILE="$RACE/tmp/${JOBNAME}_napa_colnw_hdr_clean.tmp"
  export TEMP_FILE=$RACE/tmp/${JOBNAME}_napa_colnw_clean_checkit.tmp

  ascii_cleanup.ksh ${INPUT_FILE} ${OUTPUT_FILE} ${TEMP_FILE}


#STEP Step070R
    export STEPNAME=Step070R
    echo "    Start " ${STEPNAME} "    "$(date)
##########################################################################
#  Create napa combined file by concatenating headers and flat files     #
##########################################################################

    export HDR1=$RACE/tmp/${JOBNAME}_napa_col_hdr_clean.tmp
    export DAT1=$RACE/tmp/${JOBNAME}_ref_napa_altparts.tmp
    export HDR2=$RACE/tmp/${JOBNAME}_napa_colnw_hdr_clean.tmp
    export DAT2=$RACE/tmp/${JOBNAME}_ref_napa_insurance.tmp
    export COMB=$RACE/tmp/${JOBNAME}_napa_combined.tmp

    cat $HDR1 $DAT1 $HDR2 $DAT2 > $COMB


#STEP Step075R
    export STEPNAME=Step075R
    echo "    Start " ${STEPNAME} "    "$(date)
##########################################################################
#  1. FTP "combined" file to NT server (for Data Analyst's copy and for  #
#     load processing.)                                                  #
#     NOTE: can't do file count balancing on ascii transfers             #
##########################################################################

    export FTPFILE=$RACE/tmp/${JOBNAME}_napa_combined.tmp
    export NTFILE=napa_combined.txt
# Change rj132422 - 20260424 - Remove prod3nt dependency; use NFS-mounted path
    export NTDIR=${ALTP_DIR}
    export FTPLOG=$RACE/tmp/${JOBNAME}_napa_combined_ftp.tmp

# sed adds CR to preserve the former 'ascii' fileput behavior (LF -> CRLF for Windows analysts)
    sed 's/\r*$/\r/' $FTPFILE > ${NTDIR}/${NTFILE} 2>$FTPLOG


#STEP Step098R
    export STEPNAME=Step098R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#   Delete file on Mitchell's ftp server                            *
#********************************************************************

    export FTPFILE=$FTP_BUSINESS_PATH/NAPA/$ACT_LVL/incoming/*.[Zz][Ii][Pp]
    ssh -nq $FTP_SITE rm -f $FTPFILE

#STEP Step099R
    export STEPNAME=Step099R
    echo "    Start " ${STEPNAME} "    "$(date)
#********************************************************************
#  removes job temporary files                                      *
#********************************************************************

    rm -f $RACE/tmp/${JOBNAME}*

############################################################################
#  END                                                                     #
############################################################################
