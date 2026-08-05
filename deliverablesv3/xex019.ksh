#!/bin/ksh
echo "$Id: xex019.ksh,v 1.1 2014/06/16 15:01:50 mm5095 Exp $"
############################################################################
#  RACE Conversion                                               05/20/14  #
#  PROCNAME:  xex019                                                       #
############################################################################
set -vx
export PROCNAME=$(basename $0 .ksh_run)
trap 'abndalrt.ksh $?' err

sqlplus <<%
$EXTUSERID
SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 80;
SET SERVEROUTPUT ON SIZE UNLIMITED;
whenever sqlerror exit sql.sqlcode

BEGIN

PKG_ULTRAMATE_COMMON.MAPP_EXTRACT('$OBJ_DATDIR_UMFULL');
END;
/
QUIT;
%

############################################################################
#  END                                                                     #
###########################################################################
