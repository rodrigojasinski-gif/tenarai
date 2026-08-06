#!/bin/ksh
 . race_altp.ksh
#$Id: xamr200.ksh,v 1.5 2016/04/27 20:05:31 pg2697 Exp $
############################################################################
#  JOBNAME:  xamr200                                                       #
#  DESC: ALTERNATE PARTS DATA REFORMAT - NAPA                              #
############################################################################
export RS=$1

    echo "    Start  ${JOBNAME}   "$(date)        >> $JOBLOGNAME

    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*     *Start "$(date)

    exec_restart.ksh xam200.ksh $RS      >> $JOBLOGNAME

    RETURN_CODE=$?
    if [ -n "${RS}" ] && [ "${RETURN_CODE}" = "0" ]
    then
    echo "Unset environment variable RS=${RS} to prepare for execute of next subscript\n\n" >> $JOBLOGNAME
    export RS=''
    fi

    exec_restart.ksh xamref.ksh $RS      >> $JOBLOGNAME
    
    rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}
    
    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*     *End "$(date)

    echo "    End    ${JOBNAME}   "$(date)        >> $JOBLOGNAME

############################################################################
#  END                                                                     #
############################################################################
