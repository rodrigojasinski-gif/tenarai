#!/bin/ksh
#$Id: mpt950.ksh,v 1.10 2024/08/05 21:03:48 pg2697 Exp $
############################################################################
#  JOBNAME:  mpt950.ksh   SPECIAL PARTS FIX JOB TO:
#                          1) REVERSE SUPERSESSIONS
#                          2) PROCESS MISSING SUPERSESSIONS
#                          3) PRICE PARTS
#  NOTE:  ONLY TO BE REQUESTED BY OEM RESEARCH PROGRAMMER! 
#         (ANALYSIS AND SETUP REQUIRED FIRST)
#                                               
#  11/12/2007 - (PG)  Removed historical steps. Super update reprocesses N
#                     transactions if old part is found.
#
#  02/21/2008 - (JW)  Update oem_job.validate_supersessions_flag to 'Y' and 
#                     call mpt940.ksh the "On Demand" Supersession Analysis 
#                     which runs pkg_oem_rpt_validate_supers.
#
#  05/06/2022 - (PG)  Changed execution of COBOL pgm mptz014 to Oracle
#                     pkg_
############################################################################
export PROCNAME=$(basename $0 .ksh_run)
trap 'abndalrt.ksh $?' err
set -vx
echo "$Id: mpt950.ksh,v 1.10 2024/08/05 21:03:48 pg2697 Exp $"


#STEP Step010
  export STEPNAME=Step010
  echo "    Start " ${STEPNAME} "    "$(date)
  #********************************************************************
  #* Step010 -  DELETE TEMPORARY DATASETS                            *
  #********************************************************************
  rm -f $RACE/dat/${JOBNAME}*.tmp*
  rm -f $RACE/tmp/${JOBNAME}*                              


#STEP Step020
  export STEPNAME=Step020
  echo "    Start " ${STEPNAME} "    "$(date)
  #***********************************************************************
  #* Step020 - EXECUTES UNIX 'grep'  - TO CREATE                         *      
  #*                            *rtrans*  FOR REVERSE SUPERSESSION TRANS *
  # ${JOBNAME}_spec_trans.dat:                                           *
  # RACE VERSION:  PART NUMBER = 25 CHARACTERS;                          * 
  #                DESCRIPTION = 80 CHARACTERS; PRICE = 15 CHARACTERS    *
  #                END OF RECORD MARKER 'X' MUST NOT GO BEYOND POSITION  *
  #                187. AT POSITION 188+, THE 'X' WILL BE INTERPRETED    *
  #                AS A NEW RECORD                                       *
  #                                                                      *
  #                THE BEST METHOD TO POPULATE ${JOBNAME}_spec_trans.dat *
  #                IS TO CUT AND PASTE TRANSACTIONS FROM A RACE REFORMAT *
  #                FILE.                                                 *
  #                                                                      *
  # TO CONVERT CARS DATA: CREATE A TEMPORARY FILE WITH CARS REFORMAT     * 
  #    TRANSACTIONS.  CONVERT THE TEMP FILE USING sedref_convert.ksh.    *
  #    TO POPULATE ${JOBNAME}_spec_trans.dat CUT AND PASTE THE CONVERTED * 
  #    TRANSACTIONS.                                                     *
  #*                                                                     *
  #***********************************************************************
  export DD_TRANSIN=/$ACT_LVL/race/specfix/dat/${JOBNAME}_spec_trans.dat
  export DD_TRANSOUT=$RACE/dat/${JOBNAME}_grep_rtrans.tmp

  grep  '^R' $DD_TRANSIN | cat > $DD_TRANSOUT                      
          
  # check that DD_TRANSOUT exists and is not null:
  if [ ! -s $DD_TRANSOUT ] 
  then
    echo "Error: no reverse trans data in rtrans file !!\a"
    abndalrt.ksh  grep_failed
  fi
                                                  
                                                      
#STEP Step030
  export STEPNAME=Step030
  echo "    Start " ${STEPNAME} "    "$(date)
  #**************************************************************************
  #* Step030 - EXECUTES UNIX 'grep'  - TO CREATE *nptrans* FOR:             *     
  #*                                   SUPERSESSION TRANS AND PRICE TRANS   *
  #**************************************************************************
  export DD_TRANSIN=/$ACT_LVL/race/specfix/dat/${JOBNAME}_spec_trans.dat
  export DD_TRANSOUT=$RACE/dat/${JOBNAME}_grep_nptrans.tmp

  egrep  '^N|^P'  $DD_TRANSIN | cat > $DD_TRANSOUT   
        
  # check that DD_TRANSOUT exists and is not null:
  if [ ! -s $DD_TRANSOUT ] 
  then
    echo "Error: no N or P trans data in nptrans file !!\a"
    abndalrt.ksh  grep_failed
  fi
    
    
#STEP Step050R
  export STEPNAME=Step050R
  echo "    Start " ${STEPNAME} "    "$(date)
  #**************************************************************
  #* STEP050R  - EXECUTES mptz021 - TRANSACTION SPLIT PROGRAM   *
  #*                                                            *
  #**************************************************************
  #* PROGRAM USED FILES
  export DD_PARMSIN=/$ACT_LVL/race/specfix/dat/${JOBNAME}_spec_cntl.dat
  export DD_TRANSIN=$RACE/dat/${JOBNAME}_grep_nptrans.tmp

  export DD_CNTLRPT=${RACE}/rpt/${JOBNAME}a_spltfix_$(date +'%C%y%m%d%H%M%S').rpt

  export DD_ATRANS=$RACE/dat/${JOBNAME}_atrans.tmp
  export DD_CTRANS=$RACE/dat/${JOBNAME}_ctrans.tmp
  export DD_NTRANS=$RACE/dat/${JOBNAME}_ntrans.tmp
  export DD_DTRANS=$RACE/dat/${JOBNAME}_dtrans.tmp
  export DD_PTRANS=$RACE/dat/${JOBNAME}_ptrans.tmp

  mptz021  2>&1
 
#STEP Step051R
  export STEPNAME=Step051R
  echo "    Start " ${STEPNAME} "    "$(date)
  #**************************************************************************************
  #  Emails and Handles Retention for Report(s) created in previous step  
  #**************************************************************************************
  email_rpt.ksh "${JOBNAME}a"  
  rpt_log_retention.ksh "${JOBNAME}a" 


#STEP Step060R
  export STEPNAME=Step060R
  echo "    Start " ${STEPNAME} "    "$(date)
  #**************************************************************
  #* Step060R - EXECUTES pkg_oem_line_assoc_report
  #*          - REPORT LINES ASSOCIATED TO PARTS SPECIFIED IN  *
  #*                                IN TRANSIN   *
  #*                               FOR NEW PARTS - ALL DETAILS  *
  #**************************************************************
  export MPTUSERID=`cat ${RACE}/prm/zmptpass.prm`

  export TRANSIN=$RACE/dat/${JOBNAME}_grep_rtrans.tmp
  export XTAB_TRANS=$RACE/dat/mptr950_xtab_oem_ref_trans.tmp

  export PARMIN=mpt950b.prm               
  export DETAILRPT=${JOBNAME}t_lnfixdtl_$(date +'%C%y%m%d%H%M%S').csv
  export SUMMARYRPT=${JOBNAME}s_lnfixsum_$(date +'%C%y%m%d%H%M%S').rpt
 
  # copy tmp trans file to name assoc'd to xtab definition
  cp $TRANSIN $XTAB_TRANS 
  
  # run pkg              

(sqlplus -s << CODE_BLOCK 2>&1)
${MPTUSERID}
SET ECHO ON;
SET FEEDBACK OFF;
SET VERIFY ON;
SET LINESIZE 150;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode
   exec pkg_oem_line_assoc_report.p_main(p_cntlprm_directory   => 'RACE_OEM_PRM_DIR', \
        p_cntlprm_filename    => '$PARMIN', \
        p_detail_directory    => 'RACE_OEM_RPT_DIR', \
        p_detail_filename     => '$DETAILRPT', \
        p_summary_directory   => 'RACE_OEM_RPT_DIR', \
        p_summary_filename    => '$SUMMARYRPT');

QUIT;
CODE_BLOCK

  
#STEP Step061R
  export STEPNAME=Step061R
  echo "    Start " ${STEPNAME} "    "$(date)
  #**************************************************************************************
  #  Emails and Handles Retention for Report(s) created in previous step  
  #**************************************************************************************
  email_rpt.ksh "${JOBNAME}t"  
  rpt_log_retention.ksh "${JOBNAME}t"  

  email_rpt.ksh "${JOBNAME}s"  
  rpt_log_retention.ksh "${JOBNAME}s"  



#STEP Step070R
  export STEPNAME=Step070R
  echo "    Start " ${STEPNAME} "    "$(date)
  #*************************************************************
  #* Step070R - EXECUTES mptz013 - REVERSE SUPERSESSION UPDATE *
  #*                                                           *
  #*************************************************************
  #* PROGRAM USED FILES
  export DD_PARMSIN=/$ACT_LVL/race/specfix/dat/${JOBNAME}_spec_cntl.dat
  export DD_TRANSIN=$RACE/dat/${JOBNAME}_grep_rtrans.tmp
  export DD_PARTSFL=$RACE/tmp/${JOBNAME}_parts_file.tmp
  export DD_CNTLRPT=${RACE}/rpt/${JOBNAME}d_rupdfix_$(date +'%C%y%m%d%H%M%S').rpt  
  
  mptz013 2>&1

#STEP Step071R
  export STEPNAME=Step071R
  echo "    Start " ${STEPNAME} "    "$(date)
  #**************************************************************************************
  #  Emails and Handles Retention for Report(s) created in previous step  
  #**************************************************************************************
  email_rpt.ksh "${JOBNAME}d"  
  rpt_log_retention.ksh "${JOBNAME}d"  


#STEP Step080R
  export STEPNAME=Step080R
  echo "    Start " ${STEPNAME} "    "$(date)
  #*************************************************************
  #* Step080R - EXECUTES mptz024 - SUPERSESSION UPDATE         *
  #*                                                           *
  #*************************************************************
  #* PROGRAM USED FILES
  export DD_PARMSIN=/$ACT_LVL/race/specfix/dat/${JOBNAME}_spec_cntl.dat
  export DD_TRANSIN=$RACE/dat/${JOBNAME}_ntrans.tmp

  export DD_CNTLRPT=${RACE}/rpt/${JOBNAME}f_supdfix_$(date +'%C%y%m%d%H%M%S').rpt 

  mptz024 2>&1
 
 
#STEP Step081R
  export STEPNAME=Step081R
  echo "    Start " ${STEPNAME} "    "$(date)
  #**************************************************************************************
  #  Emails and Handles Retention for Report(s) created in previous step  
  #**************************************************************************************
  email_rpt.ksh "${JOBNAME}f"  
  rpt_log_retention.ksh "${JOBNAME}f"   

  
#STEP Step085R
  export STEPNAME=Step085R
  echo "    Start " ${STEPNAME} "    "$(date)
  #*************************************************************
  #* Step085R - EXECUTES mptz028 - SUPPLEMENTAL PRICE UPDATE   *
  #*************************************************************
  #* PROGRAM USED FILES
  export DD_PARMSIN=/$ACT_LVL/race/specfix/dat/${JOBNAME}_spec_cntl.dat
  export DD_TRANSIN=$RACE/dat/${JOBNAME}_ptrans.tmp

  export DD_CNTLRPT=${RACE}/rpt/${JOBNAME}r_spupfix_$(date +'%C%y%m%d%H%M%S').rpt 

  mptz028  2>&1

  
  #STEP Step086R
  export STEPNAME=Step086R
  echo "    Start " ${STEPNAME} "    "$(date)
  #**************************************************************************************
  #  Emails and Handles Retention for Report(s) created in previous step  
  #**************************************************************************************
  email_rpt.ksh "${JOBNAME}r"  
  rpt_log_retention.ksh "${JOBNAME}r"   

    
#STEP Step090R
  export STEPNAME=Step090R
  echo "    Start " ${STEPNAME} "    "$(date)
  #*************************************************************
  #* Step090R - EXECUTES mptz007 - UPDATE REPORT PROGRAM       *
  #*************************************************************
  #* PROGRAM USED FILES
  #* (NOTE - SUPPLEMENTAL RUNS DO NOT PRODUCE RPTS 02A,02B AND 05A, 05B:)    
  #* ( RPT 02= MULTIPLE SUPERSESSION RPTS; RPT 05 = REGULAR PRICE UPDATES)
  export DD_PARMSIN=/$ACT_LVL/race/specfix/dat/${JOBNAME}_spec_cntl.dat

  export DD_RPT01=${RACE}/rpt/${JOBNAME}i_errfix_$(date +'%C%y%m%d%H%M%S').rpt 
  export DD_RPT02A=${RACE}/rpt/${JOBNAME}j_cmltfix_$(date +'%C%y%m%d%H%M%S').rpt 
  export DD_RPT02B=${RACE}/rpt/${JOBNAME}p_wmltfix_$(date +'%C%y%m%d%H%M%S').rpt 
  export DD_RPT03=${RACE}/rpt/${JOBNAME}k_pvarfix_$(date +'%C%y%m%d%H%M%S').rpt 
  export DD_RPT04A=${RACE}/rpt/${JOBNAME}n_ctlfix_$(date +'%C%y%m%d%H%M%S').rpt 
  export DD_RPT04B=${RACE}/rpt/${JOBNAME}l_actfix_$(date +'%C%y%m%d%H%M%S').rpt 
  export DD_RPT05A=${RACE}/rpt/${JOBNAME}m_czprfix_$(date +'%C%y%m%d%H%M%S').rpt 
  export DD_RPT05B=${RACE}/rpt/${JOBNAME}o_wzprfix_$(date +'%C%y%m%d%H%M%S').rpt 

  mptz007 2>&1

#STEP Step091R
  export STEPNAME=Step091R
  echo "    Start " ${STEPNAME} "    "$(date)
  #**************************************************************************************
  #  Emails and Handles Retention for Report(s) created in previous step  
  #**************************************************************************************
  email_rpt.ksh "${JOBNAME}o" 
  email_rpt.ksh "${JOBNAME}m" 
  email_rpt.ksh "${JOBNAME}l" 
  email_rpt.ksh "${JOBNAME}n" 
  email_rpt.ksh "${JOBNAME}k" 
  email_rpt.ksh "${JOBNAME}p" 
  email_rpt.ksh "${JOBNAME}j" 
  email_rpt.ksh "${JOBNAME}i" 
  
  rpt_log_retention.ksh "${JOBNAME}o"  
  rpt_log_retention.ksh "${JOBNAME}m" 
  rpt_log_retention.ksh "${JOBNAME}l"   
  rpt_log_retention.ksh "${JOBNAME}n"   
  rpt_log_retention.ksh "${JOBNAME}k"   
  rpt_log_retention.ksh "${JOBNAME}p"   
  rpt_log_retention.ksh "${JOBNAME}j"   
  rpt_log_retention.ksh "${JOBNAME}i"     
  

#STEP Step140R
  export STEPNAME=Step140R
  echo "    Start " ${STEPNAME} "    "$(date)
  #********************************************************************
  #* Step140R - Copy SPECIAL FIX DATA FILE to GDG 
  #********************************************************************
  #*
  export DD_FILEIN=/$ACT_LVL/race/specfix/dat/${JOBNAME}_spec_trans.dat
  export DD_FILEOUT=$( setgdg.ksh "/$ACT_LVL/race/specfix/dat/${JOBNAME}_spec_trans.dat(+01)" NEW 12 )

  cp $DD_FILEIN $DD_FILEOUT 2>&1
  
  
#STEP Step150R
  export STEPNAME=Step150R
  echo "    Start " ${STEPNAME} "    "$(date)
  #********************************************************************************
  #* Step150R - OK, Loops should be fixed now.  Let's find out!
  #*            Update oem_job.validate_supersessions_flag (based on OEM and Country)
  #*            and call the "On Demand" Supersession Analysis process
  #********************************************************************************
  export MPTUSERID=`cat ${RACE}/prm/zmptpass.prm`

  WORKFILE=/$ACT_LVL/race/specfix/dat/${JOBNAME}_spec_cntl.dat
  export JOBOEM=`sed -n -e 1p < ${WORKFILE}  | cut -c5-7`
  export JOBCTRY=`sed -n -e 1p < ${WORKFILE} | cut -c14-15`
  
#------------------------------------------------------------------------------------------------
# Set the flag to 'Y' based on OEM and Country in the special control parm card
(sqlplus -s << % 2>&1)
${MPTUSERID}
SET ECHO ON;
SET FEEDBACK OFF;
SET VERIFY ON;
SET LINESIZE 80;
SET SERVEROUTPUT ON;
whenever sqlerror exit sql.sqlcode
    exec pkg_oem_job.p_oem_job_upd_03(p_jobname                    => '${JOBNAME}',    \
                                      p_part_supplier_number       => '${JOBOEM}',     \
                                      p_part_supplier_country_abbr => '${JOBCTRY}',    \
                                      p_log_directory              => '${OBJ_LOGDIR}', \
                                      p_log_filename               => '${JOBLOGNAME}', \
                                      p_validate_super_flag        => 'Y' );
QUIT;
%
#------------------------------------------------------------------------------------------------
  
  export MASTER_JOBNAME=${JOBNAME}
  export MASTER_LOGNAME=${JOBLOGNAME}

  mpt940.ksh
 
  
#STEP Step999R
  export STEPNAME=Step999R
  echo "    Start " ${STEPNAME} "    "$(date)
  #********************************************************************
  #* Step999R -  DELETE TRANSACTION WORK DATASETS                     *
  #********************************************************************
  rm -f $RACE/dat/${JOBNAME}*.tmp*
  rm -f $RACE/tmp/${JOBNAME}*                              
                                                                               
#####################################################################
# End Script
#####################################################################
