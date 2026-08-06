#!/bin/ksh
 . race_altp.ksh
 . race_hosts.ksh 
#$Id: xamr010.ksh,v 1.3 2015/01/20 23:23:58 pg2697 Exp $
############################################################################
#  JOBNAME:  xamr010                                                       #
#     DESC:  Create Alternate Parts ODD extract files.                     #
############################################################################

############################################################################
# NOTE: Definition of PATH, RACE, local and remote hosts was performed 
# above by: race_altp.ksh and race_hosts.ksh
#
# $RESTART ---> restart step within sub-script (can be blank)
# $PKG_RS  ---> restart step within PKG_MAPP_ODD.SP_MAIN (can be blank)
############################################################################

export RESTART=$1
export PKG_RS=$2

echo "    Start  ${JOBNAME}   "$(date) >> ${JOBLOGNAME}

logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)

exec_restart.ksh xam010.ksh ${RESTART} >> ${JOBLOGNAME}

rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}

logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End   "$(date)

echo "    End    ${JOBNAME}   "$(date)        >> ${JOBLOGNAME}

############################################################################
#  END                                                                     #
############################################################################
