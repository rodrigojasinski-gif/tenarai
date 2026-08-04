#!/bin/ksh
############################################################################
#  ARMED FTP using RACE ONLINE		                                   #
#  Called from ARMED Data Extract screen (MEDP366.FMB)                     #
# 10/26/2021: pag - Change prod3nt domain name                             #
############################################################################

if [[ -d /prod/race/share/bin ]];then
    export ACT_LVL=/prod
else
    export ACT_LVL=/mdev
fi

set -vx

export PATH=$PATH:/usr/bin:/usr/local/bin:$ACT_LVL/race/share/bin
export FTP_SERVER=prod3nt.production.int
export RACE=$ACT_LVL/race/ext
export FILENAME=armed

export DD_SECTION2OUT=$RACE/dat/armed/rmc_section2.sgm
export DD_SECTION3OUT=$RACE/dat/armed/rmc_section3.sgm

fileput.exp $DD_SECTION2OUT rmc_section2.sgm $ACT_LVL/usrdat/armed | tee $RACE/tmp/${FILENAME}.rmc_section2.ftp.wrk
fileput.exp $DD_SECTION3OUT rmc_section3.sgm $ACT_LVL/usrdat/armed | tee $RACE/tmp/${FILENAME}.rmc_section3.ftp.wrk

rm -f $RACE/tmp/${FILENAME}*

############################################################################
#  END                                                                     #
############################################################################
