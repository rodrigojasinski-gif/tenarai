#!/bin/ksh
. race_ext.ksh
#$Id:
############################################################################
#  JOBNAME:  xexm660.ksh     MITCHELL DATA EXTRACT                         #
#  Modification: COSBatch Abend Notification                               #

export LIBPATH=/opt/microfocus/cobol/lib:/db_home/listener/lib32

    echo "    Start  ${JOBNAME}   "$(date)        >> $JOBLOGNAME
    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}* *Start "$(date)

## Note:  COSBatch Abend Notification
##  
##        'exec_restart.ksh subscript $RS' is not used. 
##        The perl script called by the following script has built in restartability.
##        Test for exit status of subscript and return any error codes

    xex660.ksh $1 >> $JOBLOGNAME
    
    RET=$?
    if ! [ $RET = "0" ]
       then
         echo "   ** master script exit status $RET"  >> $JOBLOGNAME
         exit $RET
     fi    
 
    rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}
 
    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}* *End   "$(date)
    echo "    End    ${JOBNAME}   "$(date) >> $JOBLOGNAME

############################################################################
#  END                                                                     #
############################################################################
