#!/bin/ksh
#$Id: get_current_quarter.ksh,v 1.1 2015/03/26 22:29:01 pg2697 Exp $
#####################################################################################
#
#   DESCRIPTION: get_current_quarter.ksh
#     Based upon the current month, determine what the current quarter is 
#
#   NOTE: This is an alternate procedure to get_previous_quarter.ksh. 
#     Both can be alternately used by US Kawasaki job mptr289. Procedure that you want
#     to use must be defined in RACE oem_job_datafile.ftp_source_file_name. 
#####################################################################################
THIS_MONTH=$(date +'%m')

if [ ${THIS_MONTH} -ge 1 -a ${THIS_MONTH} -le 3 ] 
then
  CURR_QTR=1
else
  if [ ${THIS_MONTH} -ge 4 -a ${THIS_MONTH} -le 6 ] 
  then
    CURR_QTR=2
  else 
    if [ ${THIS_MONTH} -ge 7 -a ${THIS_MONTH} -le 9 ] 
    then
      CURR_QTR=3
    else 
      if [ ${THIS_MONTH} -ge 10 -a ${THIS_MONTH} -le 12 ]
      then
        CURR_QTR=4
      fi
    fi
  fi
fi  
print ${CURR_QTR}
exit 0
#####################################################################################
# END get_curr_quarter.ksh
#####################################################################################
