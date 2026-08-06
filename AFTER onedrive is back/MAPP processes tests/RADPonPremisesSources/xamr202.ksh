#!/bin/ksh
 . race_altp.ksh
#$Id: xamr202.ksh,v 1.5 2016/04/27 20:05:39 pg2697 Exp $
############################################################################
#  JOBNAME:  xamr202                                                       #
#     DESC:  ALTERNATE PARTS PROVIDER REPORTING - NAPA                     #
############################################################################

export RS=$1

    echo "    Start  ${JOBNAME}   "$(date)        >> $JOBLOGNAME

    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*     *Start "$(date)

    exec_restart.ksh xamrpt.ksh $RS      >> $JOBLOGNAME
    
    rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}
    
    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*     *End "$(date)

    echo "    End    ${JOBNAME}   "$(date)        >> $JOBLOGNAME

############################################################################
#  END                                                                     #
############################################################################
