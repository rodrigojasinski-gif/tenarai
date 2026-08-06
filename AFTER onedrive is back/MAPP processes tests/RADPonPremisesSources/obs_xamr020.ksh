#!/bin/ksh
 . race_altp.ksh
#$Id: xamr020.ksh,v 1.2 2008/10/15 23:23:02 pg2697 Exp $
############################################################################
#  JOBNAME:  xamr020                                                       #
#                                                                          #
#  ALTERNATE PARTS REPORTING - PRODUCE SUPPLIER ADDS AND DELETES FILES.    #
#  (USED BY DATA ANALYST TO UPDATE UM README FILE W/ SUPPLIER ACTIVITY FOR #
#   THE MONTH.)                                                            #
#                                                                          #
############################################################################

############################################################################
# Define PATH and RACE.
############################################################################

export RS=$1

    echo "    Start  ${JOBNAME}   "$(date)        >> $JOBLOGNAME

    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*     *Start "$(date)

    exec_restart.ksh xam020.ksh $RS      >> $JOBLOGNAME

    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*     *End "$(date)

    echo "    End    ${JOBNAME}   "$(date)        >> $JOBLOGNAME

############################################################################
#  END                                                                     #
############################################################################
