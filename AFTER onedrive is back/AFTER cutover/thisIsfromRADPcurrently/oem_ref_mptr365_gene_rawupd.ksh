#!/bin/ksh
#$Id: oem_ref_mptr365_gene_rawupd.ksh,v 1.1 2018/10/16 20:21:42 pg2697 Exp $
#*******************************************************************************************
#
#        This preprocess script does the following:
#            1. Copy RAW source file to "raw_raw" file
#            2. Use a customized package (pkg_oem_ref_utilities_hyu.p_main_procedure_raw_file_upd)
#               to add the part number into all output records
#                    input:  mptr365_xtab_oem_ref_mptr365_gene_raw_raw.dat
#                    output: mptr365_xtab_oem_ref_mptr365_gene_raw.dat
#            3. Backs up the "raw_raw" file
#
#EXAMPLE:
#Input Records:
#1 00208-14100      BLOCK HEATER-ENGINE (4CYL)    MC2A001000307000026100001750Y   043
#7                  Use 00208-16100       @      1    000000000000000000000000    000
#1 00208-16100      BLOCK HEATER-ENG-4 CYL        SB1A001000310000026350001750Y   043
#4                  P/B 2-4-5-6-7-8-I-1279            000000000000000000000000    000
#4                  TSB ENGINE MECH 02-20-007         000000000000000000000000    000
#4                  TSB ENGINE MECH 03-20-003         000000000000000000000000    000
#1 00208-19100      BLOCK HEATER-ENG-4CYL MDLS '92MC2A001000307000026100001750Y   043
#3                  Use 00208-14100                   000000000000000000000000    000
#1 00210-S6100      STARTER-EXCEL/SCOUPE MTM REMANSC1P001001315300107300007500Y   038
#2                  CORE VALUE                        001000300000030000003000    000
#3                  Use 00228-S6100                   000000000000000000000000    000
#Output Records:
#1 00208-14100      BLOCK HEATER-ENGINE (4CYL)    MC2A001000307000026100001750Y   043
#7 00208-14100      Use 00208-16100       @      1    000000000000000000000000    000
#1 00208-16100      BLOCK HEATER-ENG-4 CYL        SB1A001000310000026350001750Y   043
#4 00208-16100      P/B 2-4-5-6-7-8-I-1279            000000000000000000000000    000
#4 00208-16100      TSB ENGINE MECH 02-20-007         000000000000000000000000    000
#4 00208-16100      TSB ENGINE MECH 03-20-003         000000000000000000000000    000
#1 00208-19100      BLOCK HEATER-ENG-4CYL MDLS '92MC2A001000307000026100001750Y   043
#3 00208-19100      Use 00208-14100                   000000000000000000000000    000
#1 00210-S6100      STARTER-EXCEL/SCOUPE MTM REMANSC1P001001315300107300007500Y   038
#2 00210-S6100      CORE VALUE                        001000300000030000003000    000
#3 00210-S6100      Use 00228-S6100                   000000000000000000000000    000
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
echo "\n\nSTART ---> ${PROCNAME} ${STEPNAME}" $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n"
oem_job_status_update.ksh "R" "${STEPNAME} pkg_oem_ref_mptr365_gene_rawupd"

#*******************************************************************************************
# 1. Copy RAW source file to "raw_raw" file
#*******************************************************************************************
XTAB_FILE_NAME_RAW=mptr365_xtab_oem_ref_mptr365_gene_raw_raw.dat
XTAB_FILE_NAME=mptr365_xtab_oem_ref_mptr365_gene_raw.dat
cp ${RACE}/dat/${XTAB_FILE_NAME} ${RACE}/dat/${XTAB_FILE_NAME_RAW}

#*******************************************************************************************
# 2. Use a customized package (pkg_oem_ref_mptr065_hyu_rawupd)
#    to add part number into all record types for use by the Reformat Program
#       input:  mptr365_xtab_oem_ref_mptr365_gene_raw_raw.dat
#       output: mptr365_xtab_oem_ref_mptr365_gene_raw.dat
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
    exec pkg_oem_ref_mptr065_hyu_rawupd.p_main_procedure(p_reformat_job       => '${REFORMATJOB}',          \
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
# 3. Backs up the raw_raw file
#*******************************************************************************************
XTAB_FILE_NAME_RAW_GDG=$(setgdg.ksh "${RACE}/dat/${XTAB_FILE_NAME_RAW}(+01)" NEW 4)
cp ${RACE}/dat/${XTAB_FILE_NAME_RAW} ${XTAB_FILE_NAME_RAW_GDG}

#*******************************************************************************************
# END oem_ref_mptr365_gene_rawupd.ksh
#*******************************************************************************************
