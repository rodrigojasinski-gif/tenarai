#!/bin/ksh
 . race_altp.ksh
#$Id: xamr081.ksh,v 1.1 2002/03/07 23:10:47 jn0132 Exp $
############################################################################
#  RACE Conversion                                               09/06/96  #
#  JOBNAME:  xamr081                                                       #
#                                                                          # 
#     ALTERNATE PARTS REQUEST SUPPLIER INPUT(S) UPDATE PROCESS.            #
#     UPDATE ALTERNATE PARTS ORACLE TABLES WITH INFORMATION SUPPLIED       #
#     VIA REQUEST NOVELL PC UPLOAD TRANSACTIONS.                           #
#                                                                          #
#                                                                          #
############################################################################
#*
############################################################################
# Define PATH and RACE.
############################################################################
#*
#*
export RS=$1
#*
export JOBNAME=$(basename $0 .ksh)   
export LOGNAME=$RACE/log/$(logname.ksh $JOBNAME $1)
#*
#*
#*
    echo "    Start  ${JOBNAME}   "$(date)        >> $LOGNAME
#*
    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*     *Start "$(date)
#*
    exec_restart.ksh xam081.ksh $RS  >> $LOGNAME
#*
    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*     *End "$(date)
#*
    echo "    End    ${JOBNAME}   "$(date)        >> $LOGNAME
#*
############################################################################
#  END                                                                     #
############################################################################
