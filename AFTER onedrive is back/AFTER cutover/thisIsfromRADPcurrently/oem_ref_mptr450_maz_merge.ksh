#!/bin/ksh
#$Id: oem_ref_mptr450_maz_merge.ksh,v 1.3 2008/02/12 01:14:43 jw97143 Exp $
#*******************************************************************************************
#
#        The RAW source input file has up to 3 records for each part.
#            1. Base record         - required
#            2. Core record         - optional
#            3. Supersession record - optional
#
#        This preprocess script does the following:
#            1. Copy RAW source file to "raw_raw" file
#            2. Use a customized package (pkg_oem_ref_mptr450_maz_merge)
#               to merge the 3 records into 1 record for use by the Reformat Program
#                    input:  mptr450_xtab_oem_ref_mptr450_maz_raw_raw.dat
#                    output: mptr450_xtab_oem_ref_mptr450_maz_raw.dat
#            3. Backs up the "raw_raw" file
#
#EXAMPLE:
#Three Input Records:
#                E L3H5-02-000R-0A        ENGINE, CO   6750.85   5940.74   5400.68 00     4S4P      G1    1    MOTEUR COMPLET 2.3LM
#                   CORE CHARGE      1000.00
#                   USE    ZZCA-02-000R-00             6750.85             5400.68
#One Output Record:
#L3H5-02-000R-0A|ENGINE, CO|6750.85|ZZCA-02-000R-00|1000.00|
#
#*******************************************************************************************
set -xv
trap 'oem_abndalrt.ksh $?' err
#*******************************************************************************************
#  Build environment variables for the job (based on jobname)
#*******************************************************************************************
. oem_job_datafile.ksh
#*******************************************************************************************

#STEP Step040S
STEPNAME=Step040S
echo "\n\n\n    Start   ${STEPNAME}           "$(date)
oem_job_status_update.ksh "R" "${STEPNAME} pkg_oem_ref_mptr450_maz_merge"
#*******************************************************************************************
# 1. Copy RAW source file to "raw_raw" file
#*******************************************************************************************
XTAB_FILE_NAME_RAW=mptr450_xtab_oem_ref_mptr450_maz_raw_raw.dat
XTAB_FILE_NAME=mptr450_xtab_oem_ref_mptr450_maz_raw.dat
cp ${RACE}/dat/${XTAB_FILE_NAME} ${RACE}/dat/${XTAB_FILE_NAME_RAW}

#*******************************************************************************************
# 2. Use a customized package (pkg_oem_ref_mptr450_maz_merge)
#    to merge the 3 records into 1 record for use by the Reformat Program
#       input:  mptr450_xtab_oem_ref_mptr450_maz_raw_raw.dat
#       output: mptr450_xtab_oem_ref_mptr450_maz_raw.dat
#*******************************************************************************************
#-------------------------------------------------------------------------------------------
(sqlplus -s << % 2>&1)
${MPTUSERID}
SET VERIFY OFF
SET FEEDBACK OFF
SET TAB OFF
SET LINESIZE 100
SET PAGES 0
SET TRIMSPOOL ON
whenever sqlerror exit sql.sqlcode
    exec pkg_oem_ref_mptr450_maz_merge.p_main_procedure(p_reformat_job       => '${REFORMATJOB}',           \
                                                        p_log_directory      => '${OBJ_LOGDIR}',            \
                                                        p_log_filename       => '${LOGFILE}',               \
                                                        p_input_directory    => '${OBJ_DATDIR}',            \
                                                        p_input_filename     => '${XTAB_FILE_NAME_RAW}',    \
                                                        p_output_directory   => '${OBJ_DATDIR}',            \
                                                        p_output_filename    => '${XTAB_FILE_NAME}',        \
                                                        p_debug_level        => '${RACE_DEBUG_LEVEL}',      \
                                                        p_dbms_profiler_flag => '${RACE_DBMS_PROFILER_FLAG}');
QUIT;
%
#-------------------------------------------------------------------------------------------

#*******************************************************************************************
# 3. Backs up the "raw_raw" file
#*******************************************************************************************
XTAB_FILE_NAME_RAW_GDG=$( setgdg.ksh "${RACE}/dat/${XTAB_FILE_NAME_RAW}(+01)" NEW 4 )
cp ${RACE}/dat/${XTAB_FILE_NAME_RAW} ${XTAB_FILE_NAME_RAW_GDG}

#*******************************************************************************************
# END oem_ref_mptr450_maz_merge.ksh
#*******************************************************************************************
