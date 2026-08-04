#!/bin/ksh
#$Id: get_previous_quarter.ksh,v 1.1 2009/07/17 22:30:58 jw97143 Exp $
#####################################################################################
#
#   DESCRIPTION
#     Based upon the current month, determine what the previous quarter was 
#
#####################################################################################
THIS_MONTH=$(date +'%m')

if [ ${THIS_MONTH} -ge 1 -a ${THIS_MONTH} -le 3 ] 
then
  PREV_QTR=4
else
  if [ ${THIS_MONTH} -ge 4 -a ${THIS_MONTH} -le 6 ] 
  then
    PREV_QTR=1
  else 
    if [ ${THIS_MONTH} -ge 7 -a ${THIS_MONTH} -le 9 ] 
    then
      PREV_QTR=2
    else 
      if [ ${THIS_MONTH} -ge 10 -a ${THIS_MONTH} -le 12 ]
      then
        PREV_QTR=3
      fi
    fi
  fi
fi  
print ${PREV_QTR}
exit 0
#####################################################################################
# END get_previous_quarter.ksh
#####################################################################################
