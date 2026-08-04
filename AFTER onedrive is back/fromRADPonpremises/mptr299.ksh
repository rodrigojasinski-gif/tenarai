#!/bin/ksh
 . race_oem.ksh
#$Id: mptr299.ksh,v 1.1 2019/12/13 03:06:28 pg2697 Exp $
############################################################################
#  JOBNAME:  mptr299.ksh     US/CA TESLA - SFTP OF LATEST ZIP FILE         #
#                            ZIP also includes files used by Editorial     #
############################################################################
# Define PATH and RACE.
         
echo "    Start  ${JOBNAME}   "$(date)        >> $JOBLOGNAME
logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)

exec_restart.ksh oem_ref_mptr299_ftp_tesla_source_file.ksh $1 >> $JOBLOGNAME

rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}

logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End   "$(date)
echo "    End    ${JOBNAME}   "$(date) >> ${JOBLOGNAME}
#***************************************************************************
# END
#***************************************************************************