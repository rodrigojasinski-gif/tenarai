#!/bin/ksh
 . race_oem.ksh
#$Id: mptd001.ksh,v 1.4 2016/04/01 00:53:30 pg2697 Exp $
############################################################################
#  JOBNAME:  mptd001                                                       #
#     DESC:  Create OEM Parts ODD extract files.                           #
############################################################################
export RS=$1

    echo "    Start  ${JOBNAME}   "$(date)        >> $JOBLOGNAME
    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*     *Start "$(date)

    exec_restart.ksh mpt001.ksh $RS >> $JOBLOGNAME

    rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}    

    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*     *End "$(date)
    echo "    End    ${JOBNAME}   "$(date)        >> $JOBLOGNAME
    
############################################################################
#  END                                                                     #
############################################################################
