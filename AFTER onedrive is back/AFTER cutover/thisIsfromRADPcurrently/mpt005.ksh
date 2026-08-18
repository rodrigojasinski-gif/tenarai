#!/bin/ksh
 echo "$Id: mpt005.ksh,v 1.2 2009/03/23 19:06:25 jw97143 Exp $"
############################################################################
#  PROCNAME:  mpt005                                                       #
#  OEM PARTS HISTORY UPDATE                                                #
############################################################################
set -xv
export PROCNAME=$(basename $0 .ksh_run)
trap 'abndalrt.ksh    $?' err

export MPTUSERID=`cat $RACE/prm/zmptpass.prm`

#STEP Step005R
#*********************************************************************************************
#* Update race.part_history_update rows and then insert those rows into ext.part_price_history
#*********************************************************************************************
export STEPNAME=Step005R
echo "    Start   ${STEPNAME}           "$(date)

sqlplus << % 2>&1 > $LOG
$MPTUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec EXT.PKG_HISTORICAL_PART_SEARCH.UPDATE_PART_HISTORY;

QUIT;
%

#STEP Step006R
#*********************************************************************************************
#* Truncate race.part_history_update 
#*********************************************************************************************
export STEPNAME=Step006R
echo "    Start   ${STEPNAME}           "$(date)

sqlplus << % 2>&1 > $LOG
$MPTUSERID

SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode

exec pkg_part_history_update.p_part_history_update_trunc_01;

QUIT;
%

#* END-OF-SCRIPT ****************************************************************************
