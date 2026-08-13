#!/bin/ksh

  echo "$Id: odm900.ksh,v 1.1 2019/04/23 23:46:13 pg2697 Exp $"
############################################################################
#  SUB-SCRIPT:  odm900                                                     #
#  OEM DOCUMENT MANAGEMENT - GMC_US: Build Service Navigation Tree         #
############################################################################

  set -xv
  export PROCNAME=$(basename $0 .ksh_run)
  trap 'abndalrt.ksh    $?' err

  export MPTUSERID=`cat $RACE/prm/zmptpass.prm`


 
#STEP Step010R
#*********************************************************************************************************************
#* 1. Step010R - Build Service Navigation Tree for GMC_US (based on flags set by Editors within RACE Online)
#*********************************************************************************************************************

sqlplus << % 2>&1 > $LOG
$MPTUSERID                                                                                                  

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec pkg_gen_service_navigation.p_ScheduledGenNavigation;

QUIT;
%


#* END-OF-SCRIPT ******************************************************
