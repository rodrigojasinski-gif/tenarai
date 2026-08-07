#!/bin/ksh
 . race_altp.ksh
#$Id: xamr900.ksh,v 1.3 2016/04/27 20:05:43 pg2697 Exp $
############################################################################
#  JOBNAME:  xamr900                                                       #
#     DESC:  ALTERNATE PARTS DATA REFORMAT - MULTIPLE PROVIDERS            #
############################################################################
export RS=$1

    echo "    Start  ${JOBNAME}   "$(date)        >> $JOBLOGNAME

    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*     *Start "$(date)

    exec_restart.ksh xamref.ksh $RS      >> $JOBLOGNAME
    
    rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}
    
    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*     *End "$(date)

    echo "    End    ${JOBNAME}   "$(date)        >> $JOBLOGNAME

############################################################################
#  END                                                                     #
############################################################################
