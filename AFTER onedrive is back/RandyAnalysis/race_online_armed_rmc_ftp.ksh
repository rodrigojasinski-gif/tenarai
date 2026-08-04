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

export DD_TWOTONEOUT=$RACE/dat/armed/twotone.txt
export DD_BASECOLOROUT=$RACE/dat/armed/base_color.txt
export DD_BLENDTABLEOUT=$RACE/dat/armed/blend_table.txt
export DD_COSTTABLEOUT=$RACE/dat/armed/cost_table.txt
export DD_MAKEMANOUT=$RACE/dat/armed/make_man.txt
export DD_MATERIALSOUT=$RACE/dat/armed/materials.txt
export DD_SERVICECODEOUT=$RACE/dat/armed/service_code_map.txt
export DD_DBINFO=$RACE/dat/armed/dbinfo.txt
export DD_RMCVALIDATIONFILE=$RACE/dat/armed/rmc_validation_file.txt

fileput.exp $DD_TWOTONEOUT twotone.txt $ACT_LVL/usrdat/armed | tee $RACE/tmp/${FILENAME}.twotone.ftp.wrk
fileput.exp $DD_BASECOLOROUT base_color.txt $ACT_LVL/usrdat/armed | tee $RACE/tmp/${FILENAME}.base_color.ftp.wrk
fileput.exp $DD_BLENDTABLEOUT blend_table.txt $ACT_LVL/usrdat/armed | tee $RACE/tmp/${FILENAME}.blend_table.ftp.wrk
fileput.exp $DD_COSTTABLEOUT cost_table.txt $ACT_LVL/usrdat/armed | tee $RACE/tmp/${FILENAME}.cost_table.ftp.wrk
fileput.exp $DD_MAKEMANOUT make_man.txt $ACT_LVL/usrdat/armed | tee $RACE/tmp/${FILENAME}.make_man.ftp.wrk
fileput.exp $DD_MATERIALSOUT materials.txt $ACT_LVL/usrdat/armed | tee $RACE/tmp/${FILENAME}.materials.ftp.wrk
fileput.exp $DD_SERVICECODEOUT service_code_map.txt $ACT_LVL/usrdat/armed | tee $RACE/tmp/${FILENAME}.service_code_map.ftp.wrk
fileput.exp $DD_DBINFO dbinfo.txt $ACT_LVL/usrdat/armed | tee $RACE/tmp/${FILENAME}.dbinfo.ftp.wrk
fileput.exp $DD_RMCVALIDATIONFILE rmc_validation_file.txt $ACT_LVL/usrdat/armed | tee $RACE/tmp/${FILENAME}.rmc_validation_file.ftp.wrk

rm -f $RACE/tmp/${FILENAME}*

############################################################################
#  END                                                                     #
############################################################################
