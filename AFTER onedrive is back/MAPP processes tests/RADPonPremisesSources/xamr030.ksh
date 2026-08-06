#!/bin/ksh
 . race_altp.ksh
#$Id: xamr030.ksh,v 1.2 2016/04/27 20:05:15 pg2697 Exp $
############################################################################
#  JOBNAME:  xamr030                                                       #
#  DESC:     ALTERNATE PARTS SUPPLIER COPY                                 #
#            USED BY DATA ANALYST TO COPY SUPPLIER                         #
############################################################################
export RS=$1

    echo "    Start  ${JOBNAME}   "$(date)        >> $JOBLOGNAME

    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*     *Start "$(date)

    exec_restart.ksh xam030.ksh $RS      >> $JOBLOGNAME

    rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}    

    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*     *End "$(date)

    echo "    End    ${JOBNAME}   "$(date)        >> $JOBLOGNAME

############################################################################
#  END                                                                     #
############################################################################
