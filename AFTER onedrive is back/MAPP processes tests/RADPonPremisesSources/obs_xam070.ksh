#!/bin/ksh
 echo "$Id: xam070.ksh,v 1.5 2005/02/11 00:29:39 pg2697 Exp $"
############################################################################
#  PROCNAME:  xam070                                                       #
#  ALTERNATE PARTS EXTRACT PROCESS                                         #
#  CREATE ADMIN FILE, CAT_HDRS, ALTPARTS FILE FOR DELIVERY TO GEIS AND     #
#  LOAD INTO MAPP MATRIX DATABASES (MAPP-Q AND MAPP-P)                     #
#  ALSO, CREATE MMSUPPL AND DISCLAIMER FILES USED BY UM/MAPP HOST REPORTING# 
############################################################################
  
set -xv
export PROCNAME=$(basename $0 .ksh_run)   
trap 'abndalrt.ksh    $?' err    

export XAMUSERID=`cat $RACE/prm/zxampass.prm`
export SQL_JOBNAME=$JOBNAME
export SQL_TMP_PATH=$RACE/tmp
export SQL_RPT_PATH=$RACE/rpt

export RPTDATE=$(date +'%C%y%m%d%H%M%S')


#STEP Step005R
#*********************************************************************
#* 1 EXTRACT STATE DISCLAIMER FILE (FROM DISCLAIMER TABLE)           *
#*********************************************************************
export STEPNAME=Step005R
echo "    Start   ${STEPNAME}           "$(date)

export SQL_EXTRACT='_disclaim.tmp'

sqlplus << %                    
$XAMUSERID
           
SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON; 
whenever sqlerror exit sql.sqlcode
       
exec SP_CREATE_DISCLAIMER_HOST('$SQL_TMP_PATH','$SQL_JOBNAME','$SQL_EXTRACT');  

QUIT;
%

#STEP Step010R
#*********************************************************************
#* 1 EXTRACT MAPP CATEGORY HDR FILE (FROM ALTPART_CLASS TABLE)       *
#* 2 PRODUCE CATEGORY HEADER DETAIL & SUMMARY RPTS (FOR INTERNAL USE)*
#* 3 CREATE DATAFILE TO BE USED FOR CLIENT REPORT (LATER STEP)       *
#*********************************************************************
export STEPNAME=Step010R
echo "    Start   ${STEPNAME}           "$(date)

export SQL_EXTRACT='_cat_hdrs.tmp'
export SQL_DTL1RPT=d_catcdi_${RPTDATE}.rpt
export SQL_SUMRPT=e_cathdrs_${RPTDATE}.rpt
export SQL_RPTEXTR='_cat_hdrs_dtl_cust.tmp'

sqlplus << %                    
$XAMUSERID
           
SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON; 
whenever sqlerror exit sql.sqlcode
       
exec SP_CREATE_ALTPART_CLASS_GEIS('$SQL_TMP_PATH','$SQL_RPT_PATH','$SQL_JOBNAME','$SQL_EXTRACT','$SQL_DTL1RPT','$SQL_RPTEXTR','$SQL_SUMRPT');  

QUIT;
%

#STEP Step011
#**********************************************************************
#*  FTP CATEGORY DETAIL REPORT TO DATA ANALYST'S REPORT DIRECTORY     *
#**********************************************************************
export STEPNAME=Step011
echo "    Start   ${STEPNAME}           "$(date)
  
export FTP_FILE=$RACE/rpt/${JOBNAME}d_catcdi_${RPTDATE}.rpt
export FTP_LOG=$RACE/tmp/${JOBNAME}_ftplog_catcdi.tmp         
                                                                  
fileput.exp $FTP_FILE cat_dtl.rpt ${NOVELL}altp/Internal_Rpts ascii | tee $FTP_LOG 
 

#STEP Step015R
#*********************************************************************
#* 1 SORT CATEGORY HEADER DATA BY: MM_SEQ_NUM            pos 1-3     *
#*                                 PRTC DESCRIPTION      pos 75-200  *
#* 2 DROP DUPLICATES                                                 *
#*********************************************************************
export STEPNAME=Step015R
echo "    Start   ${STEPNAME}           "$(date)
 
export DD_SORTIN=$RACE/tmp/${JOBNAME}_cat_hdrs_dtl_cust.tmp
export DD_SORTOUT=$RACE/tmp/${JOBNAME}_cat_hdrs_dtl_cust.srt
   
sort -u -T /tmp -k1.1,1.3 -k1.45,1.100 -o $DD_SORTOUT $DD_SORTIN
   
   
#STEP Step020R
#*********************************************************************
#* 1 CREATE CATEGORY HEADER REPORT (FOR EXTERNAL CLIENTS)            *
#*********************************************************************
export STEPNAME=Step020R
echo "    Start   ${STEPNAME}           "$(date)

export SQL_FILEIN='_cat_hdrs_dtl_cust.srt'
export SQL_DTL1RPT=f_cathdrc_${RPTDATE}.rpt

sqlplus << %                    
$XAMUSERID
           
SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON; 
whenever sqlerror exit sql.sqlcode
       
exec SP_ALTPART_CLASS_CLIENT_RPT('$SQL_TMP_PATH','$SQL_RPT_PATH','$SQL_JOBNAME','$SQL_FILEIN','$SQL_DTL1RPT');  

QUIT;
%

              
#STEP Step021
#**********************************************************************
#*  FTP EXTERNAL CUSTOMER'S CATEGORY HEADER REPORT TO SPECIAL DIRECTORY
#**********************************************************************
export STEPNAME=Step021
echo "    Start   ${STEPNAME}           "$(date)
  
export FTP_FILE=$RACE/rpt/${JOBNAME}f_cathdrc_${RPTDATE}.rpt
export FTP_LOG=$RACE/tmp/${JOBNAME}_ftplog_cathdrc.tmp         
                                                                  
fileput.exp $FTP_FILE category.rpt ${NOVELL}altp/Customer_Rpts ascii | tee $FTP_LOG 

 
#STEP Step025R
#**********************************************************************
#*   CREATE ALTPART SUPPLIER ADMIN FILE                               *
#**********************************************************************
export STEPNAME=Step025R
echo "    Start   ${STEPNAME}           "$(date)

export SQL_EXTRACT='_admin.tmp'
export SQL_HOST_EXTR='_mmsuppl.tmp'
export SQL_SUMRPT=b_adminsum_$(date +'%C%y%m%d%H%M%S').rpt

sqlplus << % 2>&1 > $LOG
$XAMUSERID
SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 80;
SET SERVEROUTPUT ON; 
whenever sqlerror exit sql.sqlcode

exec SP_CREATE_ALTPART_SUPLR_GEIS('$SQL_TMP_PATH','$SQL_RPT_PATH','$SQL_JOBNAME','$SQL_EXTRACT','$SQL_HOST_EXTR','$SQL_SUMRPT')

QUIT;
%
 
 
#STEP Step030R
#*********************************************************************
#* 1 EXTRACT ALTPART SUPPLIER PARTS INFO AND LINE INFO               *
#* 2 CREATE DATAFILE TO BE USED FOR "PRTC NOT DEFINED IN CATEGORY"   *
#*   REPORT (PRODUCED IN LATER STEP).                                *
#* 3 PRODUCE SUMMARY REPORT INDICATING RECS WRITTEN                  *
#*********************************************************************
export STEPNAME=Step030R
echo "    Start   ${STEPNAME}           "$(date)
   
export SQL_EXTRACT='_altparts.tmp'
export SQL_RPTDATA='_altparts_cat00.tmp'
export SQL_SUMRPT=a_altpsum_${RPTDATE}.rpt

sqlplus << % 2>&1 > $LOG
$XAMUSERID
SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 80;
SET SERVEROUTPUT ON; 
whenever sqlerror exit sql.sqlcode

exec SP_CREATE_ALTPART_GEIS('$SQL_TMP_PATH','$SQL_RPT_PATH','$SQL_JOBNAME','$SQL_EXTRACT','$SQL_RPTDATA','$SQL_SUMRPT');  

QUIT;
%


#STEP Step040R
#*********************************************************************
#*   SORT PRTC/CATEGORY DATA BY: PRTC_BODY               pos 45-48   *
#*                               SERVICE & LINE BARCODE  pos 01-12   *
#*                               ALTP SUPPLIER & PART #  pos 14-37   *
#*                                                                   *
#*   NOTE: RECORDS IN FILE SHOULD ONLY HAVE CATEGORY 000             *
#*********************************************************************
export STEPNAME=Step040R
echo "    Start   ${STEPNAME}           "$(date)
  
export DD_SORTIN=$RACE/tmp/${JOBNAME}_altparts_cat00.tmp
export DD_SORTOUT=$RACE/tmp/${JOBNAME}_altparts_cat00.srt
   
sort -T /tmp -k1.45,1.48 -k1.1,1.12 -k1.14,1.37 -o $DD_SORTOUT $DD_SORTIN
   
   
#STEP Step050R
#*********************************************************************
#*   GENERATES 2 REPORTS:                                            *
#*   1. PRTC NOT ASSIGNED TO CLASS SUMMARY REPORT                    *
#*   2. PRTC NOT ASSIGNED TO CLASS DETAIL REPORT                     *
#*********************************************************************
export STEPNAME=Step050R
echo "    Start   ${STEPNAME}           "$(date)
   
export SQL_FILEIN='_altparts_cat00.srt'
export SQL_DTLRPT=g_noclsdtl_${RPTDATE}.rpt
export SQL_SUMRPT=c_noclssum_${RPTDATE}.rpt

sqlplus << %                    
$XAMUSERID
           
SET ECHO ON;
SET FEEDBACK ON;
SET VERIFY ON;
SET LINESIZE 132;
SET SERVEROUTPUT ON; 
whenever sqlerror exit sql.sqlcode
       
exec SP_ALTPART_PRTC_NOCLASS_RPT('$SQL_TMP_PATH','$SQL_RPT_PATH','$SQL_JOBNAME','$SQL_FILEIN','$SQL_DTLRPT','$SQL_SUMRPT');  

QUIT;
%
 

#STEP Step051
#**********************************************************************
#*  FTP PRTC NOT ASSIGNED SUMMARY REPORT TO DATA ANALYST'S RPT DIR    *
#**********************************************************************
export STEPNAME=Step051
echo "    Start   ${STEPNAME}           "$(date)
  
export FTP_FILE=$RACE/rpt/${JOBNAME}c_noclssum_${RPTDATE}.rpt
export FTP_LOG=$RACE/tmp/${JOBNAME}_ftplog_noclssum.tmp         
                                                                  
fileput.exp $FTP_FILE noclssum.rpt ${NOVELL}altp/Internal_Rpts ascii | tee $FTP_LOG 


#STEP Step055
#**********************************************************************
#*  FTP PRTC NOT ASSIGNED DETAIL REPORT TO DATA ANALYST'S RPT DIR     *
#**********************************************************************
export STEPNAME=Step055
echo "    Start   ${STEPNAME}           "$(date)
  
export FTP_FILE=$RACE/rpt/${JOBNAME}g_noclsdtl_${RPTDATE}.rpt
export FTP_LOG=$RACE/tmp/${JOBNAME}_ftplog_noclsdtl.tmp         
                                                                  
fileput.exp $FTP_FILE noclsdtl.rpt ${NOVELL}altp/Internal_Rpts ascii | tee $FTP_LOG 

 
#STEP Step060R
#**********************************************************************
#*   SORT EXTRACTED PARTS DATA BY CATEGORY CODE AND SUPPLIER TO       *
#*   PREPARE TO DROP DUPLICATES. SORT BY:                             *
#*        SUPPLIER NUMBER     POS 14 - 17                             *
#*        CATEGORY CODE       POS 49 - 51                             *
#**********************************************************************
export STEPNAME=Step060R
echo "    Start   ${STEPNAME}           "$(date)

export DD_SORTIN=$RACE/tmp/${JOBNAME}_altparts.tmp
export DD_SORTOUT=$RACE/tmp/${JOBNAME}_altparts_2.tmp

sort -T $RACE/tmp -k1.14,1.17 -k1.49,1.51 -o $DD_SORTOUT $DD_SORTIN 

#STEP Step070R
#**********************************************************************
#*   SORT EXTRACTED PARTS DATA BY CATEGORY CODE AND SUPPLIER, AND     *
#*   DROP DUPLICATES. SORT BY:                                        *
#*        SUPPLIER NUMBER     POS 14 - 17                             *
#*        CATEGORY CODE       POS 49 - 51                             *
#*   (THIS CREATES A FILE THAT CAN BE USED TO LOAD THE MAPP DATABASE  *
#*    PARTS_AVAILABLE TABLE. SINCE SUPPLIER ID AND CATEGORY CODE ARE  *
#*    THE ONLY TWO FIELDS USED BY THE MAPP LOAD PROCESS, THEY ARE THE *
#*    ONLY TWO TAKEN INTO CONSIDERATION BY THIS SORT.)                *
#**********************************************************************
export STEPNAME=Step070R
echo "    Start   ${STEPNAME}           "$(date)

export DD_SORTIN=$RACE/tmp/${JOBNAME}_altparts_2.tmp
export DD_SORTOUT=$RACE/tmp/${JOBNAME}_altparts.srt

sort -T $RACE/tmp -um -k1.14,1.17 -k1.49,1.51 -o $DD_SORTOUT $DD_SORTIN
 

#STEP Step090R
#**********************************************************************
#*   BUILD DISCLAIM FILE GDG                                          *
#**********************************************************************
export STEPNAME=Step090R
echo "    Start   ${STEPNAME}           "$(date)
 
export DD_SYST1=$RACE/tmp/${JOBNAME}_disclaim.tmp
export DD_SYST2=$( setgdg.ksh \
                "$RACE/dat/${JOBNAME}_disclaim.dat(+1)" NEW 2)
 
cp $DD_SYST1 $DD_SYST2 2>&1

 
#STEP Step100R
#**********************************************************************
#*   BUILD ADMIN FILE GDG                                             *
#**********************************************************************
export STEPNAME=Step100R
echo "    Start   ${STEPNAME}           "$(date)
 
export DD_SYST1=$RACE/tmp/${JOBNAME}_admin.tmp
export DD_SYST2=$( setgdg.ksh \
                "$RACE/dat/${JOBNAME}_admin.dat(+1)" NEW 2)
 
cp $DD_SYST1 $DD_SYST2 2>&1
 

#STEP Step105R
#**********************************************************************
#*   BUILD SUPPL FILE GDG                                             *
#**********************************************************************
export STEPNAME=Step105R
echo "    Start   ${STEPNAME}           "$(date)
 
export DD_SYST1=$RACE/tmp/${JOBNAME}_mmsuppl.tmp
export DD_SYST2=$( setgdg.ksh \
                "$RACE/dat/${JOBNAME}_mmsuppl.dat(+1)" NEW 2)
 
cp $DD_SYST1 $DD_SYST2 2>&1
 
#STEP Step110R
#**********************************************************************
#*   BUILD "COMPLETE" ALTPARTS FILE GDG (FOR RESEARCH PURPOSES).      *
#*   I.E. DATA AS EXTRACTED.                                          *
#**********************************************************************
export STEPNAME=Step110R
echo "    Start   ${STEPNAME}           "$(date)
 
export DD_SYST1=$RACE/tmp/${JOBNAME}_altparts.tmp
export DD_SYST2=$( setgdg.ksh \
       "$RACE/dat/${JOBNAME}_altparts_full.dat(+1)" NEW 2)
  
cp $DD_SYST1 $DD_SYST2 2>&1

  
#STEP Step115R
#**********************************************************************
#*   BUILD "SORTED" ALTPARTS FILE GDG (FOR MAPP PROCESS BACKUP).      *
#*   I.E. DATA THAT HAS BEEN SORTED DOWN TO UNIQUE SUPPLIER/CATEGORY  *
#*   COMBINATIONS FOR LOAD INTO MAPP DATABASES.                       *
#**********************************************************************
export STEPNAME=Step115R
echo "    Start   ${STEPNAME}           "$(date)
 
export DD_SYST1=$RACE/tmp/${JOBNAME}_altparts.srt
export DD_SYST2=$( setgdg.ksh \
       "$RACE/dat/${JOBNAME}_altparts.dat(+1)" NEW 2)
  
cp $DD_SYST1 $DD_SYST2 2>&1


#STEP Step120R
#**********************************************************************
#*   BUILD CAT_HDRS FILE GDG                                          *
#**********************************************************************
export STEPNAME=Step120R
echo "    Start   ${STEPNAME}           "$(date)

export DD_SYST1=$RACE/tmp/${JOBNAME}_cat_hdrs.tmp
export DD_SYST2=$( setgdg.ksh \
       "$RACE/dat/${JOBNAME}_cat_hdrs.dat(+1)" NEW 2)

cp $DD_SYST1 $DD_SYST2 2>&1
   
 
#STEP Step130R
#**********************************************************************
#*  REMOTE COPY SUPPLIER ADMIN FILE                                   *
#**********************************************************************
export STEPNAME=Step130R
echo "    Start   ${STEPNAME}           "$(date)
  
export RMT_FILE=$( setgdg.ksh "$RACE/dat/${JOBNAME}_admin.dat(0)" )
export LOC_FILE=$RACE/../../geis/ftpvm/dat/${JOBNAME}_admin_geis.dat         
                                                                  
rcp  $RMT_FILE ${GEI_HOST}:${LOC_FILE}                       
                                                                   

#STEP Step140R
#**********************************************************************
#*  REMOTE COPY ALTPARTS FILE.                                        *
#**********************************************************************
export STEPNAME=Step140R
echo "    Start   ${STEPNAME}           "$(date)
                 
export RMT_FILE=$( setgdg.ksh "$RACE/dat/${JOBNAME}_altparts.dat(0)" )
export LOC_FILE=$RACE/../../geis/ftpvm/dat/${JOBNAME}_altparts_geis.dat        
                                                                   
rcp $RMT_FILE ${GEI_HOST}:${LOC_FILE}                       


#STEP Step150R
#**********************************************************************
#*  REMOTE COPY CAT HDRS FILE.                                        *
#**********************************************************************
export STEPNAME=Step150R
echo "    Start   ${STEPNAME}           "$(date)
               
export RMT_FILE=$( setgdg.ksh "$RACE/dat/${JOBNAME}_cat_hdrs.dat(0)" )
export LOC_FILE=$RACE/../../geis/ftpvm/dat/${JOBNAME}_cat_hdrs_geis.dat        
                                                                     
rcp $RMT_FILE ${GEI_HOST}:${LOC_FILE}                       
                                                                     
#STEP Step200R
#**********************************************************************
#*  FTP SUPPLIER MMSUPPL FILE TO NT SERVER FOR USE BY UM HOST RPTING. *
#*  NOTE: Use binary ftp so that <CR> not included in file.           *
#**********************************************************************
export STEPNAME=Step200R
echo "    Start   ${STEPNAME}           "$(date)
  
export FTP_FILE=$( setgdg.ksh "$RACE/dat/${JOBNAME}_mmsuppl.dat(0)" )
export FTP_LOG=$RACE/tmp/${JOBNAME}_ftplog_mmsuppl.tmp         
                                                                  
fileput.exp $FTP_FILE mmsuppl.seq ${NOVELL}race | tee $FTP_LOG                                                                   

#STEP Step210R
#**********************************************************************
#*  FTP STATE DISCLAIMER FILE TO NT SERVER FOR USE BY UM HOST RPTING. *
#*  NOTE: Use binary ftp so that <CR> not included in file.           *
#**********************************************************************
export STEPNAME=Step210R
echo "    Start   ${STEPNAME}           "$(date)
  
export FTP_FILE=$( setgdg.ksh "$RACE/dat/${JOBNAME}_disclaim.dat(0)" )
export FTP_LOG=$RACE/tmp/${JOBNAME}_ftplog_disclaim.tmp         
                                                                  
fileput.exp $FTP_FILE disclaim.seq ${NOVELL}race | tee $FTP_LOG 

#STEP Step999R
#**********************************************************************
#*   REMOVE TEMP DATASETS                                             *
#**********************************************************************
export STEPNAME=Step999R
echo "    Start   ${STEPNAME}           "$(date)

rm -f  $RACE/tmp/${JOBNAME}*