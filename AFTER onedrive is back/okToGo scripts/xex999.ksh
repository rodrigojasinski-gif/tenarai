#!/bin/ksh
#$Id: xex999.ksh,v 1.3 2020/06/08 23:20:50 pb0690 Exp $JOBNAME.ksh,v 1.1 2001/10/26 06:06:06 jn0132 Exp $
############################################################################
#  RACE Conversion                                               10/26/01  #
#  PROCNAME:  $JOBNAME                                                     #
############################################################################
export PROCNAME=$(basename $0 .ksh_run)

trap 'abndalrt.ksh $?' err
set -vx
echo "$Id: xex999.ksh,v 1.3 2020/06/08 23:20:50 pb0690 Exp $JOBNAME.ksh,v 1.1 2001/10/26 09:09:09 jn0132 Exp $"

sqlplus <<%
$EXTUSERID
SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 80;
SET SERVEROUTPUT ON; 
whenever sqlerror exit sql.sqlcode

BEGIN

PKG_ULTRAMATE_DONE.ULTRAMATE_DONE('$SQL_PARMFILE_PATH'
                                 ,'$SQL_RUN_TYPE'
                                 ,'$SQL_PARMFILE'
                                 ,'$OBJ_DATDIR_UMFULL'
                                 ,'$OBJ_DATDIR_UMMINI'
                                 ,'$SQL_VERSION'
                                 ,'$SQL_RESTART_FLAG');
END;
/
QUIT;
%

############################################################################
#  END                                                                     #
###########################################################################
