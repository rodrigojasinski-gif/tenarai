#!/bin/ksh
# Define PATH and RACE. 
. race_oem.ksh
#$Id: mptr839.ksh,v 1.1 2023/01/05 02:10:11 pg2697 Exp $
#################################################################################
#  JOBNAME:  mptr839.ksh     US TESLA COMMERCIAL SEMI - SFTP OF LATEST ZIP FILE #
#                            ZIP also includes files used by Editorial.         #
#################################################################################
         
echo "    Start  ${JOBNAME}   "$(date)        >> $JOBLOGNAME
logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)

exec_restart.ksh oem_ref_mptr839_ftp_tesla_semi_source_file.ksh $1 >> $JOBLOGNAME

rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}

logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End   "$(date)
echo "    End    ${JOBNAME}   "$(date) >> ${JOBLOGNAME}
#***************************************************************************
# END
#***************************************************************************