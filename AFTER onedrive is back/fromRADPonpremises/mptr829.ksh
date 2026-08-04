#!/bin/ksh
 . race_oem.ksh
#$Id: mptr829.ksh,v 1.1 2022/11/08 03:39:56 pg2697 Exp $
#################################################################################
#  JOBNAME:  mptr829.ksh    SFTP of US Truck Shroud file for use by Editorial.  #
#################################################################################      
echo "    Start  ${JOBNAME}   "$(date)        >> $JOBLOGNAME
logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)

exec_restart.ksh oem_ref_mptr829_ftp_tshr_source_file.ksh $1 >> $JOBLOGNAME

rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}

logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End   "$(date)
echo "    End    ${JOBNAME}   "$(date) >> ${JOBLOGNAME}
#***************************************************************************
# END
#***************************************************************************