#!/bin/ksh 
 set -vx  
############################################################################
# PROGRAM:     xam_reformat_capa_sql.ksh                                              
# AUTHOR:      Penny Genovese
# DESCRIPTION: Reformat CAPA-supplied parts file for input to PART_CAPA_XREF
#              load.
# OVERVIEW: 1) Read CAPA record and parse into fields.
#           2) Using CAPA-supplied part_supplier_text, lookup assoc'd 
#              Mitchell part_supplier_number.                          
#           3) Using CAPA-supplied part_number and Mitchell part_supplier
#              number, lookup Mitchell-formatted part number.
#           4) If either lookup fails, produce an error report.
#           5) If successful, write an output record.                       
#           6) At end of processing, produce a summary report.
############################################################################
# MODIFICATIONS:                                                                
#   yyyy/mm/dd - author - description                                                 
############################################################################
##start sqlplus 
sqlplus << % 2>&1 > $LOG 
$XAMUSERID 
set serveroutput on;
set feedback on;
set termout on;
set trimspool on;
set arraysize 200;  
whenever sqlerror exit sql.sqlcode

define v_IN_DIR   = $ORA_IN_DIR   char(60); 
define v_IN_FILE  = $ORA_IN_FILE  char(60); 
define v_OUT_DIR  = $ORA_OUT_DIR  char(60); 
define v_OUT_FILE = $ORA_OUT_FILE char(60); 
define v_RPT_DIR  = $ORA_RPT_DIR  char(60); 
define v_RPT_FILE = $ORA_RPT_FILE char(60); 
define v_SUM_DIR  = $ORA_SUM_DIR  char(60); 
define v_SUM_FILE = $ORA_SUM_FILE char(60); 
  
DECLARE
  
---------- I/O files definition -----------------------------------------
v_in_fHandle     UTL_FILE.FILE_TYPE;
v_out_fHandle    UTL_FILE.FILE_TYPE;
v_rpt_fHandle    UTL_FILE.FILE_TYPE;
v_sum_fHandle    UTL_FILE.FILE_TYPE;

---------- local variables ----------------------------------------------
vvc2_in_dirname                   varchar2(60);
vvc2_in_filename                  varchar2(60);
vvc2_in_rec                       varchar2(45);
    
vvc2_out_dirname                  varchar2(60);
vvc2_out_filename                 varchar2(60);
vvc2_out_rec                      varchar2(45);
    
vvc2_rpt_dirname                  varchar2(60);
vvc2_rpt_filename                 varchar2(60);
    
vvc2_sum_dirname                  varchar2(60);
vvc2_sum_filename                 varchar2(60);
    
vvc2_in_acq_part_number           varchar2(25);
vvc2_in_acq_part_supplier         varchar2(20);
  
vvc2_out_part_number              varchar2(25);
vvc2_out_part_supplier_number     varchar2(03);
  
vvc2_error_msg                    varchar2(27);
  
vvc2_country_abbr                 varchar2(2);
vn_part_supplier_current_price    number(15,4);  --not used (passed back from pkg)
vn_row_count                      number(6);
vn_return_code                    number(6);
vvc2_called_error_msg             varchar2(1000);
    
vvc2_header1                      varchar2(130);
vvc2_header2a                     varchar2(130);
vvc2_header2b                     varchar2(130);
vvc2_header3                      varchar2(130);
vvc2_header4                      varchar2(130);
vvc2_blankline                    varchar2(130) :=' ';
vvc2_detail                       varchar2(130);

---------- counters and calculations ------------------------------------
vd_date 	                  date;
vd_sys_date                       varchar2(10);
vn_newpage                        number(2) :=58;
vn_page_ctr                       number(2) :=0;                 
vn_line_ctr                       number(2) :=0;
vn_tot_recs_read                  number(6) :=0;
vn_tot_recs_written               number(6) :=0;
vn_tot_recs_error                 number(6) :=0;
vn_data_provider_skey             number    :=0;
vvc2_data_provider_name           varchar2(80) :='CAPA';
vvc2_code_location                varchar2(80); 

 
---------  error messages -----------------------------------------------
vvc2_supplier_notfnd_msg    varchar2(27):='*SUPPLIER WAS NOT FOUND*';
vvc2_part_notfnd_msg        varchar2(27):='*PART NUMBER WAS NOT FOUND*';

--------------------------- MAIN PROGRAM --------------------------------
 
BEGIN  
  
---------   Initialize all variables   ---------------------------------------------------

  vvc2_in_dirname   :='&v_IN_DIR';
  vvc2_in_filename  :='&v_IN_FILE';
  vvc2_out_dirname  :='&v_OUT_DIR'; 
  vvc2_out_filename :='&v_OUT_FILE';
  vvc2_rpt_dirname  :='&v_RPT_DIR'; 
  vvc2_rpt_filename :='&v_RPT_FILE';
  vvc2_sum_dirname  :='&v_SUM_DIR'; 
  vvc2_sum_filename :='&v_SUM_FILE';
    
  select sysdate into vd_date from dual; 
  vd_sys_date := to_char(vd_date,'MM/DD/YYYY');
   
  DBMS_OUTPUT.ENABLE(1000000); 
  DBMS_OUTPUT.NEW_LINE; 
  DBMS_OUTPUT.PUT_LINE('Start: ' || to_char(vd_date,'MM/DD/YYYY HH24:MI:SS'));   
   
------------ Open Input/Output File ------------------------------------------------------
  vvc2_code_location := 'OPEN FILES';
  
  v_in_fHandle     := UTL_FILE.FOPEN(vvc2_in_dirname,vvc2_in_filename,'r');
  v_out_fHandle    := UTL_FILE.FOPEN(vvc2_out_dirname,vvc2_out_filename,'w');
  v_rpt_fHandle    := UTL_FILE.FOPEN(vvc2_rpt_dirname,vvc2_rpt_filename,'w');
  v_sum_fHandle    := UTL_FILE.FOPEN(vvc2_sum_dirname,vvc2_sum_filename,'w');
    
----------- Set Header and Subheader values and print first page's heading-----------------------
  vvc2_code_location := 'HEADINGS';
   
  vvc2_header1:= chr(12) || 'XAMR069' || lpad('MITCHELL INTERNATIONAL',52,' ')
          ||'                       ' 
          ||'PAGE NO. ';
        
  vvc2_header2a:= lpad('CAPA FILE REFORMAT ERRORS',60,' ') 
          ||'                      ' 
          ||'REPORT DATE:  ';
        
  vvc2_header2b:= lpad('CAPA FILE REFORMAT SUMMARY',62,' ') 
          ||'                     ' 
          ||'REPORT DATE:  ';
        
  vvc2_header3:= 'CAPA SUPPLIER TEXT    MITCHELL SUPPLIER #  '
              || 'CAPA PART NUMBER           ERROR MESSAGE';
                 
  vvc2_header4:= '--------------------  -------------------  ' 
              || '-------------------------  ---------------------------';
                
  vn_page_ctr:=vn_page_ctr+1;
  UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_header1 || to_char(vn_page_ctr));   
  UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_header2a || vd_sys_date); 
  UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_blankline);
  UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_header3);
  UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_header4); 
  vn_line_ctr := 5;     

   
--------- Get Data Provider Skey assoc'd with CAPA (for select of Data Provider specific search strings)
  vvc2_code_location := 'PROVIDER SELECT';
   
     PKG_ALTERNATE_PARTS_DATAFILE.P_ALTPART_DATA_PROVIDER_SEL_01
     (vvc2_data_provider_name,
      vn_data_provider_skey,
      vn_row_count,
      vvc2_called_error_msg,
      vn_return_code);

--check if select worked 
  
     IF vn_return_code <> 0 THEN
       UTL_FILE.FCLOSE(v_in_fHandle);
       UTL_FILE.FCLOSE(v_out_fHandle);
       UTL_FILE.FCLOSE(v_rpt_fHandle);
       UTL_FILE.FCLOSE(v_sum_fHandle);
       RAISE_APPLICATION_ERROR(-20105,'Unable to locate skey associated to CAPA Data Provider');
     END IF;

       
--------- Read input record ---------------------------------------------------------------------
       
  LOOP  <<main_loop>>
     vvc2_code_location := 'MAIN LOOP';
       
     BEGIN
       UTL_FILE.GET_LINE(v_in_fHandle,vvc2_in_rec);
     EXCEPTION
       WHEN NO_DATA_FOUND THEN
       EXIT;
     END;
 
--------- Bypass Header Record -------------------------------------------------------------------  
     vvc2_code_location := 'BYPASS HEADER';
 
     IF UPPER(substr(vvc2_in_rec,1,3)) = 'OEM' THEN
       GOTO main_loop;             
     END IF;
 
--------- Parse input record ---------------------------------------------------------------------  
     vvc2_code_location := 'PARSE INPUT';
 
     vvc2_in_acq_part_number      :=UPPER(NVL(substr(vvc2_in_rec,1,25),' '));
     vvc2_in_acq_part_supplier    :=UPPER(NVL(substr(vvc2_in_rec,26,20),' '));
     vn_tot_recs_read             :=vn_tot_recs_read +1;
 
--------- Validate Altpart Supplier Number and pick-up database information ----------------------

--initialize values before call 
   
     vvc2_out_part_number          :=' ';
     vvc2_out_part_supplier_number :=' '; 
     vvc2_error_msg                :=' ';
     vvc2_country_abbr             :=' ';
     vn_return_code                :=0;
    
--------- Call routine to lookup Mitchell Part Supplier Number -----------------------------------
--Routine looks for "generic" as well as Data Provider specific value 
     vvc2_code_location := 'PART SUPPLIER LOOKUP';
                 
     PKG_ALTERNATE_PARTS_DATAFILE.P_ACQ_PART_SUPLR_LOOKUP_SEL_01
     (vn_data_provider_skey,
      vvc2_in_acq_part_supplier,
      vvc2_out_part_supplier_number,
      vn_row_count,
      vvc2_called_error_msg,
      vn_return_code);


--check if select worked 
  
     IF vn_return_code <> 0 THEN
       vvc2_error_msg :=vvc2_supplier_notfnd_msg;
       GOTO output_rec;
     END IF;


--------- Call routine to check format associated to compressed part number --------------------
--------- First try it with country of US ------------------------------------------------------
     vvc2_code_location := 'COMPRESSED PART LOOKUP';
  
     vvc2_country_abbr :='US';
       
     PKG_PART.P_PART_SEL_07                 
     (vvc2_out_part_supplier_number,
      vvc2_country_abbr,
      vvc2_in_acq_part_number,
      vvc2_out_part_number,
      vn_part_supplier_current_price,
      vn_row_count,
      vvc2_called_error_msg,
      vn_return_code);

--check for successful lookup

     IF vn_return_code = 0 THEN
       GOTO output_rec;
     END IF;

--------- Now try it with country of CA ------------------------------------------------------
     vvc2_country_abbr :='CA';
       
     PKG_PART.P_PART_SEL_07                 
     (vvc2_out_part_supplier_number,
      vvc2_country_abbr,
      vvc2_in_acq_part_number,
      vvc2_out_part_number,
      vn_part_supplier_current_price,
      vn_row_count,
      vvc2_called_error_msg,
      vn_return_code);

--check for unsuccessful lookup
     IF vn_return_code <> 0 THEN
       vvc2_error_msg :=vvc2_part_notfnd_msg;
     END IF;

  <<output_rec>>

 -------- If error encountered, write a report record noting reformat error ---------
     vvc2_code_location := 'WRITE ERROR REPORT';

 --Check for new page     
     IF (vn_line_ctr > vn_newpage) THEN 
        vn_page_ctr:=vn_page_ctr+1;
        UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_header1 || to_char(vn_page_ctr));   
        UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_header2a || vd_sys_date); 
        UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_blankline);
        UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_header3);
        UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_header4); 
        vn_line_ctr := 5;     
     END IF;
  
     IF vvc2_error_msg <> ' ' THEN
       vvc2_detail := rpad(NVL(vvc2_in_acq_part_supplier,' '),20,' ') 
           ||'  '|| rpad(NVL(vvc2_out_part_supplier_number,' '),19,' ') 
           ||'  '|| rpad(NVL(vvc2_in_acq_part_number,' '),25,' ')
           ||'  '|| rpad(vvc2_error_msg,27,' ');  
       UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_detail); 
       vn_line_ctr := vn_line_ctr + 1;
       vn_tot_recs_error :=vn_tot_recs_error + 1;       
       GOTO main_loop;             
     END IF;
          
 -------- Write a reformatted record ---
     vvc2_code_location := 'WRITE REFORMAT RECORD';
             
     vvc2_out_rec := rpad(vvc2_out_part_supplier_number,03,' ') 
         ||'  '|| rpad(vvc2_out_part_number,25,' ') 
         ||'  '|| 'Y';
     UTL_FILE.PUT_LINE(v_out_fHandle,vvc2_out_rec); 
     vn_tot_recs_written :=vn_tot_recs_written + 1;       
           
 END LOOP main_loop;
           
 -------- END OF PROCESSING - WRITE FINAL TOTALS ---------------------------------------
  vvc2_code_location := 'WRITE FINAL TOTALS';
          
  vn_page_ctr:=1;
  UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_header1 || to_char(vn_page_ctr));   
  UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_header2b || vd_sys_date); 
  UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_blankline);
  UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_blankline);
  UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_blankline);
     
  vvc2_detail:= lpad(vn_tot_recs_read,6,0)  || ' RECORDS READ';
  UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_detail); 
    
  vvc2_detail:= ' ';
  vvc2_detail:= '-----';
  UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_detail); 
    
  vvc2_detail:= ' ';
  vvc2_detail:= lpad(vn_tot_recs_error,6,0) || ' RECORDS IN ERROR';
  UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_detail); 
    
  vvc2_detail:= ' ';
  vvc2_detail:= '-----';
  UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_detail); 
    
  vvc2_detail:= ' ';
  vvc2_detail:= lpad(vn_tot_recs_written,6,0) || ' TOTAL RECORDS WRITTEN';
  UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_detail); 
                                                                                                                                
  vvc2_detail:= ' ';
  UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_detail); 
  UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_detail); 
  UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_detail); 
  vvc2_detail:= 'NOTE: duplicate records to be dropped in subsequent sort,'
             || ' therefore RECORDS WRITTEN does not reflect records to be loaded';
  UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_detail); 
                                                                                                                       
    
----------------- close  input / output files--------------------------------------------------------------

  UTL_FILE.FCLOSE(v_in_fHandle);
  UTL_FILE.FCLOSE(v_out_fHandle);
  UTL_FILE.FCLOSE(v_rpt_fHandle);
  UTL_FILE.FCLOSE(v_sum_fHandle);

EXCEPTION
 
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_out_fHandle);
    UTL_FILE.FCLOSE(v_rpt_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    RAISE_APPLICATION_ERROR(-20101,'Invalid Mode');

   WHEN UTL_FILE.INVALID_PATH THEN
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_out_fHandle);
    UTL_FILE.FCLOSE(v_rpt_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    RAISE_APPLICATION_ERROR(-20100,'Invalid Path');
    
  WHEN UTL_FILE.INVALID_FILEHANDLE then
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_out_fHandle);
    UTL_FILE.FCLOSE(v_rpt_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    RAISE_APPLICATION_ERROR(-20102,'Invalid Filehandle');
    
   WHEN UTL_FILE.INVALID_OPERATION then
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_out_fHandle);
    UTL_FILE.FCLOSE(v_rpt_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    RAISE_APPLICATION_ERROR(-20103,'Invalid Filehandle operation');
    
  WHEN UTL_FILE.WRITE_ERROR then
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_out_fHandle);
    UTL_FILE.FCLOSE(v_rpt_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    RAISE_APPLICATION_ERROR(-20104,'Write Error');

  WHEN OTHERS then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ***************************************');
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('Record Count: ' || vn_tot_recs_read);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_out_fHandle);
    UTL_FILE.FCLOSE(v_rpt_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);

    RAISE_APPLICATION_ERROR(-20999,'Unhandled Error Encountered');      
END;

-- leave "/" it is required for pl/sql end block ----------------------------------------------------
/
 
quit;
--- leave "end_sql_block" it is required for sql end block ----- 
%
#END OF Script
