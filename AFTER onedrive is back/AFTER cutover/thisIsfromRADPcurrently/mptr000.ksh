#!/bin/ksh
 . race_oem.ksh
 . race_hosts.ksh
#$Id: mptr000.ksh,v 1.9 2021/07/19 01:29:24 pg2697 Exp $
#*****************************************************************************
# Job Description: RACE Smoke Test Script
#                  Use to test various commands after a server / OS migration
#                  There are separate scripts for user types because there 
#                  are certain connections that only apply to certain users.
#                  admin  => prod_move command and ssh/scp from radp to radd.
#                  devlpr => ssh/scp from radd to radp and vice versa.
#                            ssh/scp from radd to mappd and to sftp-corp.
#                            copy to CIFS-share dev11nas from radd
#                  prodid => ssh/scp from radd to radp and vice versa. 
#                            ssh/scp from radd to mappd and to sftp-corp.
#                            ssh/scp from radp to mappq and to sftp-corp. 
#                            copy to CIFS-share dev11nas from radd  
#                            copy to CIFS-share prod10nas from radp             
#*****************************************************************************
#set -xv
export RESTART=$1
export RESTART_FILE_SEQUENCE=$2

echo "    Start  ${JOBNAME}   "$(date) >> ${JOBLOGNAME}
logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *Start "$(date)

RETURN_CODE=$?

if [ "${USER}" == "race_b1" ]                                                        # race_b1 smoke_test 
then     
		exec_restart.ksh mpt000_smoketest_prodid.ksh ${RESTART} >> ${JOBLOGNAME}
        RETURN_CODE=$?
		if [ -n "${RESTART}" ] && [ "${RETURN_CODE}" = "0" ]
		then
		   echo "Unset environment variable RESTART=${RESTART}\n\n\n" >> ${JOBLOGNAME}
		   export RESTART=''
		fi     
else                                                                                 # developer smoke_test
        exec_restart.ksh mpt000_smoketest_prodid.ksh ${RESTART} >> ${JOBLOGNAME}
        RETURN_CODE=$?
		if [ -n "${RESTART}" ] && [ "${RETURN_CODE}" = "0" ]
		then
		   echo "Unset environment variable RESTART=${RESTART}\n\n\n" >> ${JOBLOGNAME}
		   export RESTART=''
		fi
fi

#rpt_log_retention.ksh "${JOBNAME}_" >> ${JOBLOGNAME}

logger -p user.info "OPCOM*I*PROCES*${JOBNAME}*        *End   "$(date)
echo "    End    ${JOBNAME}   "$(date) >> ${JOBLOGNAME}
#***************************************************************************
# END
#***************************************************************************
