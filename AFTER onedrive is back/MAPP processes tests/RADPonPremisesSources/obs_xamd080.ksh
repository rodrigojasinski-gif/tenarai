#!/bin/ksh
 . race_altp.ksh
#$Id: xamd080.ksh,v 1.1 2002/03/07 23:10:33 jn0132 Exp $
############################################################################
#  RACE Conversion                                               09/05/96  #
#  JOBNAME:  xamd080                                                       #
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
    exec_restart.ksh xam080.ksh $RS  >> $LOGNAME
#*
    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*     *End "$(date)
#*
    echo "    End    ${JOBNAME}   "$(date)        >> $LOGNAME
#*
############################################################################
#  END                                                                     #
############################################################################
