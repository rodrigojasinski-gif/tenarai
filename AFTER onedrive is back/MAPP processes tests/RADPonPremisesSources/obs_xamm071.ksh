#!/bin/ksh
 . race_altp.ksh
#$Id: xamm071.ksh,v 1.1 2002/03/07 23:10:40 jn0132 Exp $
############################################################################
#  RACE Conversion                                               09/20/96  #
#  JOBNAME:  xamm071                                                       #
############################################################################
#*
############################################################################
# Define PATH and RACE.
############################################################################
#*
export RS=$1
#*
export JOBNAME=$(basename $0 .ksh)   
export LOGNAME=$RACE/log/$(logname.ksh $JOBNAME $1)
#*
#*
    echo "    Start  ${JOBNAME}   "$(date)        >> $LOGNAME
#*
    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*     *Start "$(date)
#*
    exec_restart.ksh xam071.ksh $RS  >> $LOGNAME
#*
    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*     *End "$(date)
#*
    echo "    End    ${JOBNAME}   "$(date)        >> $LOGNAME
#*
############################################################################
#  END                                                                     #
############################################################################
