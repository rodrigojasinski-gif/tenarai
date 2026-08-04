#!/bin/ksh
############################################################################
#  PHOTOCOMP EXTRACT using RACE ONLINE                                     #
#  Called from pkg_authoring.print_photocomp                               #
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
export RACE=$ACT_LVL/race/ceg
export FILENAME=$1

GRAPHIC_EXT='_gx.txt'
PC_EXT='_.sgm'

export DD_FOTOCMP=$RACE/dat/${FILENAME}_fotocomp1.tmp
export DD_GRAPHIC=$RACE/dat/${FILENAME}_gx.tmp

mv $DD_GRAPHIC $RACE/dat/${FILENAME}$GRAPHIC_EXT 
mv $DD_FOTOCMP $RACE/dat/${FILENAME}$PC_EXT 

export DD_FOTOCMPOUT=$RACE/dat/${FILENAME}$PC_EXT
export DD_GRAPHICOUT=$RACE/dat/${FILENAME}$GRAPHIC_EXT


fileput.exp $DD_FOTOCMPOUT ${FILENAME}_.sgm $ACT_LVL/race | tee $RACE/tmp/${FILENAME}.foto.ftp.wrk
fileput.exp $DD_GRAPHICOUT ${FILENAME}_gx.txt $ACT_LVL/race | tee $RACE/tmp/${FILENAME}.graphic.ftp.wrk

rm -f $RACE/tmp/${FILENAME}*

############################################################################
#  END                                                                     #
############################################################################
