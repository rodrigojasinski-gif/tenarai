#!/bin/ksh
echo $Id: oem_ref_mptr710_saa_gmc_xref_drop_recs.ksh,v 1.1 2007/12/17 23:08:33 jw97143 Exp $
#***************************************************************************
#
#  NAME: oem_ref_mptr710_saa_gmc_xref_drop_recs.ksh
#
#        Sorting Supplemental Reformat file:  
#        Sort the source file old part number, descending new part number. 
#        Then sort again by by old part number dropping duplicates.  
#        This is done to get the greater of the two 305 numbers in the new part number field.
#
#        This preprocess script does the following:
#            1. Copy RAW source file to "raw_raw" file
#            3. Backs up the "raw_raw" file
#
#EXAMPLE:
#3001500      16  30559714
#3001500      45  30547292
#
#Keep: 3001500      16  30559714
#
#***************************************************************************

#***************************************************************************
set -xv
trap 'oem_abndalrt.ksh $?' err

echo "\nCalling .oem_job_datafile.ksh " $(date)
. oem_job_datafile.ksh

#STEP Step040S
STEPNAME=Step040S
echo "\n\n\n    Start   ${STEPNAME}           "$(date)
oem_job_status_update.ksh "R" "${STEPNAME} pkg_oem_ref_mptr710_saa_gmc_xref_drop_recs"
#************************************************************************
# 1. Copy RAW source file to "raw_raw" file
#************************************************************************
XTAB_FILE_NAME=mptr710_xtab_oem_ref_mptr710_saa_xref_raw.dat
XTAB_FILE_NAME_RAW=mptr710_xtab_oem_ref_mptr710_saa_xref_raw_raw.dat
cp ${RACE}/dat/${XTAB_FILE_NAME} ${RACE}/dat/${XTAB_FILE_NAME_RAW}

#************************************************************************
# 2. Sort by old_part_number and new_part_number (descending)
#    create table XTAB_OEM_REF_MPTR710_SAA_XREF
#  OLD_PART_NUMBER VARCHAR2(12),
#  FILLER1         VARCHAR2(1),
#  PART_TYPE       VARCHAR2(2),
#  FILLER2         VARCHAR2(2),
#  NEW_PART_NUMBER VARCHAR2(8)
#
SORTIN=${RACE}/dat/${XTAB_FILE_NAME}
SORTOUT=${RACE}/tmp/${JOBNAME}_${STEPNAME}_workfile.tmp

sort -k1.1,1.12 -k1.18,1.25r -o ${SORTOUT} ${SORTIN}

#********************************************************************
# 3. Sort by old_part_number and drop duplicates
#********************************************************************
SORTIN=${RACE}/tmp/${JOBNAME}_${STEPNAME}_workfile.tmp
SORTOUT=${RACE}/dat/${XTAB_FILE_NAME}

sort -um -k1.1,1.12 -o ${SORTOUT} ${SORTIN}

#************************************************************************
# 4. Backs up the "raw_raw" file
#************************************************************************
XTAB_FILE_NAME_RAW_GDG=$( setgdg.ksh "${RACE}/dat/${XTAB_FILE_NAME_RAW}(+01)" NEW 4 )
cp ${RACE}/dat/${XTAB_FILE_NAME_RAW} ${XTAB_FILE_NAME_RAW_GDG}

#*****************************************************************************************************************
# END oem_ref_mptr710_saa_gmc_xref_drop_recs.ksh
#*****************************************************************************************************************
