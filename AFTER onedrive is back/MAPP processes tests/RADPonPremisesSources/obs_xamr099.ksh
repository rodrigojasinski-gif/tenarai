#!/bin/ksh
#$Id: xamr099.ksh,v 1.1 2002/03/07 23:10:50 jn0132 Exp $
############################################################################
#  RACE Conversion                                               03/05/97  #
#  JOBNAME:  xamr099                                                       #
############################################################################
 
# Define PATH and RACE.
 . race_altp.ksh
         
export JOBNAME=$(basename $0 .ksh)
export LOGNAME=$RACE/log/$(logname.ksh $JOBNAME $1)

set -xv

trap 'abndalrt.ksh ${JOBNAME}  JOB $?' err
 
export RS=$1                                
         
    echo "    Start  ${JOBNAME}   "$(date)        >> $LOGNAME
    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)

    export gdg01='+1'
     
    exec_restart.ksh xam099.ksh $RS           >> $LOGNAME

    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End   "$(date)
    echo "    End    ${JOBNAME}   "$(date)        >> $LOGNAME

############################################################################
#  END                                                                     #
############################################################################
