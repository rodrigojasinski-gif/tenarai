#!/bin/ksh
 . race_ext.ksh
#$Id: xexr500.ksh,v 1.3 2016/05/03 00:53:20 pg2697 Exp $
############################################################################
#  RACE                                                          10/26/01  #
#  JOBNAME:  xexr500 RACE to EXT MINI - WIP SERVICES                       #
############################################################################

if ! [ $(printenv RACE) ]
then
  return -1
fi
    echo "    Start  ${JOBNAME}   "$(date)        >> $JOBLOGNAME
    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)

    exec_restart.ksh xex010.ksh $1            >> $JOBLOGNAME

    rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}
    
    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End "$(date)
    echo "    End    ${JOBNAME}   "$(date)        >> $JOBLOGNAME

############################################################################
#  END                                                                     #
############################################################################
