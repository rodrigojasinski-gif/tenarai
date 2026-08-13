#!/bin/ksh
 . race_oem.ksh
#$Id: mptr149.ksh,v 1.3 2016/02/18 01:32:28 pg2697 Exp $
############################################################################
#  JOBNAME:  mptr149.ksh     (US & Canada Volvo FTP)                       #
############################################################################
# Define PATH and RACE.
         
echo "    Start  ${JOBNAME}   "$(date)        >> $JOBLOGNAME
logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)

exec_restart.ksh mpt149.ksh $1                >> $JOBLOGNAME

rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}

logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End   "$(date)
echo "    End    ${JOBNAME}   "$(date) >> ${JOBLOGNAME}
#***************************************************************************
# END
#***************************************************************************