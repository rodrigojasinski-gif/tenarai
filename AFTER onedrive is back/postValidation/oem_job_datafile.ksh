#!/bin/ksh
echo "RCS $Id: oem_job_datafile.ksh,v 1.7 2008/10/09 22:16:34 jw97143 Exp $"
#*****************************************************************************************
# PROCNAME oem_job_datafile.ksh
# PURPOSE  Retreive and build UNIX Environment Variables from Oracle Tables
#*****************************************************************************************
trap 'oem_abndalrt.ksh $?' err
MPTUSERID=`cat ${RACE}/prm/zmptpass.prm`
LOGFILE=$(basename ${JOBLOGNAME})
#*****************************************************************************************
WORKFILE=${JOBNAME}_oem_job_datafile.tmp
#-----------------------------------------------------------------------------------------
(sqlplus -s << % 2>&1)
${MPTUSERID}
SET VERIFY OFF
SET FEEDBACK OFF
SET TAB OFF
SET LINESIZE 100
SET PAGES 0
SET TRIMSPOOL ON
whenever sqlerror exit sql.sqlcode
    exec pkg_oem_job_datafile.p_oem_job_datafile_sel_04(p_reformat_job  => '${REFORMATJOB}', \
                                                        p_tmp_directory => '${OBJ_TMPDIR}',  \
                                                        p_tmp_filename  => '${WORKFILE}',    \
                                                        p_log_directory => '${OBJ_LOGDIR}',  \
                                                        p_log_filename  => '${LOGFILE%.log}.db.log');
QUIT;
%

# rj132422 - This code was added to avoid race condition between db and shell due the nfs
DB_LOG=${OBJ_TMPDIR}/${LOGFILE%.log}.db.log
if [ -s "$DB_LOG" ]; then
    cat "$DB_LOG" >> "${OBJ_TMPDIR}/${LOGFILE}"
    rm  "$DB_LOG"
fi

#-----------------------------------------------------------------------------------------
export WORKFILE=${RACE}/tmp/${WORKFILE}
#*****************************************************************************************
# END oem_job_datafile.ksh
#*****************************************************************************************
