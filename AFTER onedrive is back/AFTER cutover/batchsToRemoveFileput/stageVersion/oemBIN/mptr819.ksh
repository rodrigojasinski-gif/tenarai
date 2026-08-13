#!/bin/ksh
 . race_oem.ksh
#$Id: mptr819.ksh,v 1.1 2021/07/14 23:12:41 pg2697 Exp $
############################################################################
#  JOBNAME:  mptr819.ksh     US LKQ Truck  - FTP OF LATEST ZIP FILE        #
#                            ZIP contains xlsx used by Editorial and       #
#                            converted by macro to txt for use in Reformat.#
############################################################################
# Define PATH and RACE.
         
echo "    Start  ${JOBNAME}   "$(date)        >> $JOBLOGNAME
logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)

exec_restart.ksh oem_ref_mptr819_ftp_lkqt_source_file.ksh $1 >> $JOBLOGNAME

rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}

logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End   "$(date)
echo "    End    ${JOBNAME}   "$(date) >> ${JOBLOGNAME}
#***************************************************************************
# END
#***************************************************************************