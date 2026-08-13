#!/bin/ksh
 . race_oem.ksh
#$Id: mptr289.ksh,v 1.3 2016/11/02 23:53:57 pg2697 Exp $
############################################################################
#  JOBNAME:  mptr289.ksh     US KAWASAKI 290 - Quarterly File FTP          #
#                            Also, includes files used by Editorial        #
############################################################################
# Define PATH and RACE.
         
echo "    Start  ${JOBNAME}   "$(date)        >> $JOBLOGNAME
logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)

exec_restart.ksh oem_ref_mptr289_ftp_kaw_source_file.ksh $1 >> $JOBLOGNAME

rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}

logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End   "$(date)
echo "    End    ${JOBNAME}   "$(date) >> ${JOBLOGNAME}
#***************************************************************************
# END
#***************************************************************************