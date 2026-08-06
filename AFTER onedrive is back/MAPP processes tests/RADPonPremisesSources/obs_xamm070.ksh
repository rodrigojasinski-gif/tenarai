#!/bin/ksh
 . race_altp.ksh
 . race_hosts.ksh 
#$Id: xamm070.ksh,v 1.2 2004/12/16 21:24:06 pg2697 Exp $
############################################################################
#  JOBNAME:  xamm070                                                       #
#     DESC:  Create Alternate Parts extract files for load to MAPP DBs.    #
############################################################################
#*
############################################################################
# Define PATH and RACE.
# and local and remote hosts.
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
    exec_restart.ksh xam070.ksh  $RS >> $LOGNAME
#*
    echo "    End    ${JOBNAME}   "$(date)        >> $LOGNAME
#*
    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*     *End "$(date)
#*
############################################################################
#  END                                                                     #
############################################################################
