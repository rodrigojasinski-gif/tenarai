#!/bin/ksh
 . race_oem.ksh
#$Id: mptr799.ksh,v 1.2 2023/06/21 00:15:45 pg2697 Exp $
#################################################################################
#  JOBNAME:  mptr799.ksh    SFTP of US TRP file for use by Editorial.        #
#################################################################################      
echo "    Start  ${JOBNAME}   "$(date)        >> $JOBLOGNAME
logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)

exec_restart.ksh oem_ref_mptr799_ftp_trp_source_file.ksh $1 >> $JOBLOGNAME

rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}

logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End   "$(date)
echo "    End    ${JOBNAME}   "$(date) >> ${JOBLOGNAME}
#***************************************************************************
# END
#***************************************************************************