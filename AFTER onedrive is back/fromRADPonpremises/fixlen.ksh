#!/bin/ksh
#$Id: fixlen.ksh,v 1.2 2006/08/10 23:15:03 jw97143 Exp $
#####################################################################################
#
#   DESCRIPTION
#   Modify the record length to a fixed length of nn.
#
#   HISTORY
#   2006/08/09 JLW Script modified to run on either PROD or MDEV using $ACT_LVL
#
#####################################################################################

if [ $# = 1 ]
then
   awk -f/$ACT_LVL/race/share/bin/fixlen.awk -vLEN=$1
else
   echo "Usage: fixlen <length> ..."
fi

#####################################################################################
# END fixlen.ksh
#####################################################################################
