#!/bin/ksh
 . race_oem.ksh
#$Id: mptd005.ksh,v 1.2 2016/04/01 00:54:11 pg2697 Exp $
############################################################################
#  JOBNAME:  mptd005                                                       #
#     DESC:  Update Parts History                                          #
#                                                                          #
# Definition of PATH, RACE, local and remote hosts was performed above     #
# by: race_oem.ksh                                                         #
############################################################################
export RS=$1

    echo "    Start  ${JOBNAME}   "$(date)        >> $JOBLOGNAME
    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*     *Start "$(date)

    exec_restart.ksh mpt005.ksh $RS >> $JOBLOGNAME

    rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}    
    
    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*     *End "$(date)   
    echo "    End    ${JOBNAME}   "$(date)        >> $JOBLOGNAME

############################################################################
#  END                                                                     #
############################################################################
