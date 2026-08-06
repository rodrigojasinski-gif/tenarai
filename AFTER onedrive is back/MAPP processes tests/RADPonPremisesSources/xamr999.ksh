#!/bin/ksh
 . race_altp.ksh
#$Id: xamr999.ksh,v 1.3 2016/04/27 20:05:54 pg2697 Exp $
############################################################################
#  JOBNAME:  xamr999                                                       #
#     DESC:  ALTERNATE PARTS PROVIDER REPORTING - FOR MITCHELL DATA ANALYST#
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