#!/bin/ksh
 . race_altp.ksh
#$Id: xamr069.ksh,v 1.4 2014/11/07 23:58:48 pg2697 Exp $
############################################################################
#  JOBNAME:  xamr069                                                       #
#                                                                          #
#  LOAD CAPA-CERTIFIED OVERRIDE PARTS INTO PART_CAPA_XREF TABLE. (THIS     #   
#  DATA IS USED IN THE MAPP AND UM EXTRACTS TO DETERMINE CAPA FLAG VALUES.)#
#                                                                          #
############################################################################
  
############################################################################
# Define PATH and RACE.
############################################################################
  
export RS=$1
  
    echo "    Start  ${JOBNAME}   "$(date)        >> $JOBLOGNAME
  
    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*     *Start "$(date)
  
    exec_restart.ksh xam069.ksh $RS  >> $JOBLOGNAME
  
    rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}
  
    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*     *End "$(date)
  
    echo "    End    ${JOBNAME}   "$(date)        >> $JOBLOGNAME
  
############################################################################
#  END                                                                     #
############################################################################
