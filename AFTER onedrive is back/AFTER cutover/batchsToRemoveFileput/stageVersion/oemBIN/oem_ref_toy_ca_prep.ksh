#!/bin/ksh
echo "RCS $Id: oem_ref_toy_ca_prep.ksh,v 1.1 2024/07/17 00:53:22 pg2697 Exp $"

#*****************************************************************************************
# PROCNAME oem_ref_toy_ca_prep.ksh                                              
# PURPOSE  CA Toyota does not identify their supersessions (singular and multiple) 
#          as well as US Toyota; therefore the CA Toyota and CA Lexus reformats validate
#          the created supersessions against the US ones. In order to achieve this, the 
#          latest US Toyota and US Lexus ACTRANS gdg files are copied to a non-GDG version 
#          for use in the reformat program.
# 
# PROCESS FLOW:
#            1. Remove prior ACTRANS xtab dat file
#            2. Concatenate latest US Toyota ACTRANS GDG and latest US Lexus ACTRANS GDG to create a US Toyota/Lexus xtab name.
#*****************************************************************************************
trap 'oem_abndalrt.ksh $?' err
export LOGFILE=$(basename ${JOBLOGNAME})
PROCNAME=oem_ref_toy_ca_prep.ksh
echo "\n\nSTART ---> ${PROCNAME} " $(date +'%m/%d/%y %H:%M:%S')  " <--- START\n\n" 

#-----------------------------------------------------------------------------------------
#STEP Step005R
  export STEPNAME=Step005R
  echo "\n\n START ---> ${PROCNAME} ${STEPNAME} - Remove prior ACTRANS dat - " $(date +'%m/%d/%y %H:%M:%S') " <--- START\n\n"
   
  #**********************************************************************************************
  # Remove prior ACTRANS
  #**********************************************************************************************
  
    export ACTRANS_COMBINED=${RACE}/dat/${JOBNAME}_xtab_oem_toylex_us_actrans_combined.dat
    echo "\n Removing prior ACTRANS_XTAB: ${ACTRANS_XTAB}"

	rm -f ${ACTRANS_COMBINED}

  #**********************************************************************************************
  # Create new ACTRANS using latest US Toyota and US Lexus ACTRANS gdgs
  #**********************************************************************************************
    export ACTRANS_LEX_US=$(setgdg.ksh "${RACE}/dat/mptr081_actrans_lex_us.dat(0)") 
    export ACTRANS_TOY_US=$(setgdg.ksh "${RACE}/dat/mptr146_actrans_toy_us.dat(0)")     
	
	cat $ACTRANS_LEX_US $ACTRANS_TOY_US > $ACTRANS_COMBINED
	

echo "\n\nEND ---> ${PROCNAME} " $(date +'%m/%d/%y %H:%M:%S')  " <--- END\n\n" 
#*****************************************************************************************
#END oem_ref_toy_ca_prep.ksh   
#*****************************************************************************************
