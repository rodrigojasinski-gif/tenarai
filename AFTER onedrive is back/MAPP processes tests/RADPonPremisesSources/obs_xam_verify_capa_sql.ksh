#!/bin/ksh 
 set -vx  
############################################################################
# PROGRAM:     xam_verify_capa_sql.ksh                                              
# AUTHOR:      Penny Genovese
# DESCRIPTION: Produce report showing row counts per Part_Supplier_Number
#              within PART_CAPA_XREF table.
############################################################################
# MODIFICATIONS:                                                                
# mm/dd/yyyy - ini - description                                                    
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

define v_RPT_DIR  = $ORA_RPT_DIR  char(60); 
define v_RPT_FILE = $ORA_RPT_FILE char(60); 
  
DECLARE
  
---------- I/O files definition -----------------------------------------
v_rpt_fHandle    UTL_FILE.FILE_TYPE;

---------- local variables ----------------------------------------------
vvc2_rpt_dirname                  varchar2(60);
vvc2_rpt_filename                 varchar2(60);
vvc2_rpt_rec                      varchar2(130);
    
vvc2_rpt_part_supplier_number     varchar2(03);
vvc2_rpt_part_supplier_name       varchar2(30);
vn_rpt_part_count                 number;
  
vvc2_header1                      varchar2(130);
vvc2_header2                      varchar2(130);
vvc2_header3                      varchar2(130);
vvc2_header4                      varchar2(130);
vvc2_total                        varchar2(130);
vvc2_blankline                    varchar2(130) :=' ';
vvc2_detail                       varchar2(130);
    
---------- counters and calculations ------------------------------------
vn_row_count                      number;
vd_date 	                         date;
vd_sys_date                       varchar2(10);
vn_newpage                        number(2) :=58;
vn_page_ctr                       number(2) :=0;                 
vn_line_ctr                       number(2) :=0;
vn_tot_part_count                 number :=0;

---------- cursors ------------------------------------------------------

CURSOR c_part_capa_xref IS
    SELECT part_capa_xref.part_supplier_number  
          ,RTRIM(part_supplier_name,30)    
          ,count(*)
    FROM part_capa_xref, part_supplier
    WHERE part_capa_xref.part_supplier_number = part_supplier.part_supplier_number
    GROUP BY part_capa_xref.part_supplier_number, part_supplier_name 
    ORDER BY part_capa_xref.part_supplier_number, part_supplier_name;
 
BEGIN  
  
---------   Initialize all variables   ---------------------------------------------------
  
  vvc2_rpt_dirname  :='&v_RPT_DIR'; 
  vvc2_rpt_filename :='&v_RPT_FILE';
    
  select sysdate into vd_date from dual; 
  vd_sys_date := to_char(vd_date,'MM/DD/YYYY');
   
  DBMS_OUTPUT.ENABLE(1000000);
  DBMS_OUTPUT.NEW_LINE;
  DBMS_OUTPUT.PUT_LINE('Start: ' || to_char(vd_date,'MM/DD/YYYY HH24:MI:SS'));
     
------------ Open Input/Output File ------------------------------------------------------
     
  v_rpt_fHandle    := UTL_FILE.FOPEN(vvc2_rpt_dirname,vvc2_rpt_filename,'w');
    
----------- Set Header and Subheader values and print first page's heading-----------------------
    
  vvc2_header1:= chr(12) || 'XAMR069' || lpad('MITCHELL INTERNATIONAL',41,' ')
              || lpad('PAGE NO. ',26,' ');
                   
  vvc2_header2:= lpad('CAPA LOAD VERIFICATION REPORT',53,' ')
              || lpad('RUN DATE: ',22,' ');
    
  vvc2_header3:= 'SUPPLIER   PART SUPPLIER NAME                CAPA RECS';
               
  vvc2_header4:= '--------   ------------------------------    ---------';
       
  vvc2_total :=  '                                             ---------';       
       
  vn_page_ctr:=vn_page_ctr+1;       
  UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_header1 || to_char(vn_page_ctr));       
  UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_header2 || vd_sys_date);       
  UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_blankline);       
  UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_header3);       
  UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_header4);       
  vn_line_ctr := 5;       
       
----------- Open cursor to begin fetch of counts -----------------------------------------------       
       
  vvc2_rpt_part_supplier_name   :=' ';
  vvc2_rpt_part_supplier_name   :=' ';
  vvc2_rpt_part_supplier_number :=' ';
  vn_rpt_part_count             :=0;
  vn_row_count                  :=0;
      
  OPEN c_part_capa_xref;      
      
--------- Process remaining input record(s) from parm file   ------------------------------------      
<<MAIN_LOOP>>      
      
  LOOP
       
--------- Fetch count from database --------------------------------------------------------------       
       
     vn_row_count  := vn_row_count +1;       
       
     FETCH c_part_capa_xref into 
           vvc2_rpt_part_supplier_number 
          ,vvc2_rpt_part_supplier_name 
          ,vn_rpt_part_count;
 
     IF c_part_capa_xref%NOTFOUND THEN         
       EXIT; 
     END IF;
 
     vn_tot_part_count := vn_tot_part_count + vn_rpt_part_count; 
 
---------------- print supplier info -----------------------------------------------------------
        
 --Check for new page
     IF (vn_line_ctr > vn_newpage) THEN
        vn_page_ctr:=vn_page_ctr+1;
        UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_header1 || to_char(vn_page_ctr));
        UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_header2 || vd_sys_date);
        UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_blankline);
        UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_header3);
        UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_header4);
        vn_line_ctr := 5;
     END IF;
        
     vvc2_detail:= rpad(vvc2_rpt_part_supplier_number,11,' ')        
                || rpad(vvc2_rpt_part_supplier_name,33,' ')        
                || lpad(vn_rpt_part_count,10,' ');      
     UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_detail);        
     vn_line_ctr := vn_line_ctr + 1;        
        
  END LOOP main_loop;        
        
------------------- Close cursor -------------------------------------------------------------------------        
        
  CLOSE c_part_capa_xref;        
        
------------------- Write end of report totals  ----------------------------------------------------------        
       
  IF vn_tot_part_count = 0 THEN
     vvc2_detail:= ('WARNING: CAPA LOAD FAILURE. DB TABLE IS EMPTY!');
     UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_detail);
  END IF;
          
    
  UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_blankline);
  UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_total);
        
  vvc2_detail:= ' ';
  vvc2_detail:= rpad('TOTAL CAPA RECS: ',44,' ') || lpad(vn_tot_part_count,10,' ');      
  UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_detail);
        
  Select sysdate into vd_date from dual;        
  DBMS_OUTPUT.PUT_LINE('End: ' || to_char(vd_date,'MM/DD/YYYY HH24:MI:SS'));        
        
---------------- close  input / output files--------------------------------------------------------------
        
 UTL_FILE.FCLOSE(v_rpt_fHandle);
        
EXCEPTION
 
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_rpt_fHandle);
    RAISE_APPLICATION_ERROR(-20101,'Invalid Mode');
 
  WHEN UTL_FILE.INVALID_PATH THEN
    UTL_FILE.FCLOSE(v_rpt_fHandle);
    RAISE_APPLICATION_ERROR(-20100,'Invalid Path');
 
  WHEN UTL_FILE.INVALID_FILEHANDLE THEN
    UTL_FILE.FCLOSE(v_rpt_fHandle);
    RAISE_APPLICATION_ERROR(-20102,'Invalid Filehandle');
 
  WHEN UTL_FILE.INVALID_OPERATION THEN
    UTL_FILE.FCLOSE(v_rpt_fHandle);
    RAISE_APPLICATION_ERROR(-20103,'Invalid Filehandle operation');
 
  WHEN UTL_FILE.WRITE_ERROR THEN
    UTL_FILE.FCLOSE(v_rpt_fHandle);
    RAISE_APPLICATION_ERROR(-20104,'Write Error');
 
END;
 
-- leave "/" it is required for pl/sql end block ----------------------------------------------------
/
  
quit;
--- leave "end_sql_block" it is required for sql end block ----- 
%
#END OF Script
