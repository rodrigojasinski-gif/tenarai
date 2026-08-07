#!/bin/ksh
 . race_altp.ksh
#$Id: xamr902.ksh,v 1.3 2016/04/27 20:05:50 pg2697 Exp $
############################################################################
#  JOBNAME:  xamr902                                                       #
#     DESC:  ALTERNATE PARTS PROVIDER REPORTING - MULTIPLE DATA PROVIDER   #
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
