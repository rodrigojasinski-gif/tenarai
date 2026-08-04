#!/bin/ksh
. race_ext.ksh
#$Id:
############################################################################
#  JOBNAME:  xexm630.ksh     MANHEIM DATA EXTRACT                          #
#  Modification: COSBatch Abend Notification                               #
#                2008/01/09 by Gail Walder                                 #
#                Add test for exit status of subscript.                    #
#                If find error status exit with error code.                #
############################################################################

## Note: Per Mike Herrera 09/12/07:
##       LIBPATH must be reset for the Perl production env.(ibm590a6)
##       due to ORA installation & newsid differences on a6 vs c6
##       a6: LIBPATH=/opt/microfocus/cobol/lib:/db_home/radp/lib:
##       c6: LIBPATH=/opt/microfocus/cobol/lib:
export LIBPATH=/opt/microfocus/cobol/lib:/db_home/listener/lib32

    echo "    Start  ${JOBNAME}   "$(date)        >> $JOBLOGNAME
    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)

## Note:  COSBatch Abend Notification
##        'exec_restart.ksh subscript $RS' is not used. 
##        The perl script called by the following script has built in restartability.
##        Test for exit status of subscript and return any error codes

    xex630.ksh $1 >> $JOBLOGNAME
    
    RET=$?
    if ! [ $RET = "0" ]
       then
         echo "   ** master script exit status $RET"  >> $JOBLOGNAME
         exit $RET
     fi    
 
    rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}
 
    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End   "$(date)
    echo "    End    ${JOBNAME}   "$(date)        >> $JOBLOGNAME

############################################################################
#  END                                                                     #
############################################################################
