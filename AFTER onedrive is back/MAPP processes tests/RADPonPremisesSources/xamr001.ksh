#!/bin/ksh
 . race_altp.ksh
#$Id: xamr001.ksh,v 1.3 2016/04/27 20:05:11 pg2697 Exp $
############################################################################
#  JOBNAME:  xamr001                                                       #
#     DELETE PART_ALTPART_XREF (PARTS) ASSOCIATED TO ALTERNATE PART        #
#     SUPPLIER(S), AS SPECIFIED VIA PARM FILE.                             #
############################################################################
export RS=$1

    echo "    Start  ${JOBNAME}   "$(date)        >> $JOBLOGNAME

    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*     *Start "$(date)

    exec_restart.ksh xam001.ksh $RS  >> $JOBLOGNAME

    rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}

    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*     *End "$(date)

    echo "    End    ${JOBNAME}   "$(date)        >> $JOBLOGNAME

############################################################################
#  END                                                                     #
############################################################################
