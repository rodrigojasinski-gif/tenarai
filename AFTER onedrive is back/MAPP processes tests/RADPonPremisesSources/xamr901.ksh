#!/bin/ksh
 . race_altp.ksh
#$Id: xamr901.ksh,v 1.3 2016/04/27 20:05:46 pg2697 Exp $
############################################################################
#  JOBNAME:  xamr901                                                       #
#     DESC: ALTERNATE PARTS DATA UPDATE - MULTIPLE PROVIDERS               #
############################################################################
export RS=$1

    echo "    Start  ${JOBNAME}   "$(date)        >> $JOBLOGNAME

    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*     *Start "$(date)

    exec_restart.ksh xamupd.ksh $RS      >> $JOBLOGNAME
        
    rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}
    
    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*     *End "$(date)

    echo "    End    ${JOBNAME}   "$(date)        >> $JOBLOGNAME

############################################################################
#  END                                                                     #
############################################################################
