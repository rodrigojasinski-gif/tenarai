#!/bin/ksh
 . race_oem.ksh
#$Id: mptr950.ksh,v 1.4 2016/04/01 01:00:38 pg2697 Exp $
############################################################################
#  JOBNAME:  mptr950.ksh   SPECIAL PARTS FIX JOB TO:
#                          1) REVERSE SUPERSESSIONS
#                          2) PROCESS MISSING SUPERSESSIONS
#                          3) PRICE PARTS
#  NOTE:  ONLY TO BE REQUESTED BY OEM RESEARCH PROGRAMMER! 
#         (ANALYSIS AND SETUP REQUIRED FIRST)
############################################################################

    echo "    Start  ${JOBNAME}   "$(date)        >> $JOBLOGNAME
    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)

    exec_restart.ksh mpt950.ksh $1                >> $JOBLOGNAME

    rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}    

    logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End   "$(date)
    echo "    End    ${JOBNAME}   "$(date)        >> $JOBLOGNAME

############################################################################
#  END
############################################################################
