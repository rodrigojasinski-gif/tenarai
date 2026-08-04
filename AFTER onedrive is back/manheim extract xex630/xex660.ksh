#!/bin/ksh
#$Id:
############################################################################
#  JOBNAME:  xex660.ksh     MITCHELL DATA EXTRACT                          #
############################################################################
set -xv
trap 'abndalrt.ksh $?' err

if [[ $# = "0" ]]                  # test for restart argument
then 
 mitchell_extract.pl 2>&1 >> $JOBLOGNAME                                                          
else
 mitchell_extract.pl -restart $1  2>&1 >> $JOBLOGNAME
fi

############################################################################
#  END                                                                     #
############################################################################
