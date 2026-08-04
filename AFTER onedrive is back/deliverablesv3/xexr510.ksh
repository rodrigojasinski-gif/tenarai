#!/bin/ksh
 . race_ext.ksh
#$Id: xexr510.ksh,v 1.3 2016/05/03 00:53:23 pg2697 Exp $
############################################################################
#  RACE                                                          10/26/01  #
#  JOBNAME:  xexr510 ULTRAMATE MINI EXTRACT - WIP SERVICES                 #
############################################################################

if ! [ $(printenv RACE) ]
then
  return -1
fi
    echo "    Start  ${JOBNAME}   "$(date)        >> $JOBLOGNAME
    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)

    exec_restart.ksh xex015.ksh $1            >> $JOBLOGNAME

    rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}
    
    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End "$(date)
    echo "    End    ${JOBNAME}   "$(date)        >> $JOBLOGNAME

############################################################################
#  END                                                                     #
############################################################################
