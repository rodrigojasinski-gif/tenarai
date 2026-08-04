#!/bin/ksh
echo "$Id: xex017.ksh,v 1.5 2009/07/07 17:26:54 pg2697 Exp $"
############################################################################
#  RACE Conversion                                               10/26/01  #
#  PROCNAME:  xex017                                                       #
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

PKG_ULTRAMATE_PARSE.ULTRAMATE_PARSE('$SQL_RUN_TYPE'
                                   ,'$OBJ_DATDIR_UMFULL'
                                   ,'$OBJ_DATDIR_UMMINI'
                                   ,null
                                   ,null
                                   ,'$SQL_FULL_PROC_NUM');
END;
/
QUIT;
%

############################################################################
#  END                                                                     #
###########################################################################
