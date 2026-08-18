#!/bin/ksh
 . race_oem.ksh
#$Id: mptr809.ksh,v 1.1 2020/04/03 23:16:46 pg2697 Exp $
############################################################################
#  JOBNAME:  mptr809.ksh     US BestFit  - FTP OF LATEST ZIP FILE          #
#                            ZIP also includes files used by Editorial     #
############################################################################
# Define PATH and RACE.
         
echo "    Start  ${JOBNAME}   "$(date)        >> $JOBLOGNAME
logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)

exec_restart.ksh oem_ref_mptr809_ftp_bestfit_source_file.ksh $1 >> $JOBLOGNAME

rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}

logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End   "$(date)
echo "    End    ${JOBNAME}   "$(date) >> ${JOBLOGNAME}
#***************************************************************************
# END
#***************************************************************************