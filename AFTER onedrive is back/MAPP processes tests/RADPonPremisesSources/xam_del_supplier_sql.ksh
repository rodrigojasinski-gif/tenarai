#!/bin/ksh 
 set -vx  
############################################################################
# PROGRAM:     xam_del_supplier_sql.ksh                                              
# AUTHOR:      Penny Genovese
# DESCRIPTION: Delete Part_Altpart_XREF rows associated to supplier(s) that
#              are specified via a parm file.
#              Program can be run in TWO Modes:
#              1) VERIFY - reports suppliers to be deleted, associated part
#                          counts, and estimated CPU time.
#              2) DELETE - deletes part rows associated to supplier(s) that 
#                          are specified in parm file. Updates PART_COUNT 
#                          in Supplier Table to zero. Reports supplier(s)  
#                          and count of rows deleted.                                
#              Mode is specified as first record in parm file.
############################################################################
# MODIFICATIONS:                                                                
# 05/24/2004 - PAG - Added update of Delete_Reason_Code and Delete_Date.            
#                    Removed "Before end-of-loop" label. Not needed.                
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
define v_IN_PARM  = $ORA_IN_PARM  char(60); 
define v_RPT_DIR  = $ORA_RPT_DIR  char(60); 
define v_RPT_FILE = $ORA_RPT_FILE char(60); 
  
DECLARE
  
---------- I/O files definition -----------------------------------------
v_in_fHandle     UTL_FILE.FILE_TYPE;
v_rpt_fHandle    UTL_FILE.FILE_TYPE;

---------- local variables ----------------------------------------------
vvc2_in_dirname                   varchar2(60);
vvc2_in_parmfile                  varchar2(60);
vvc2_in_rec                       varchar2(20);
    
vvc2_rpt_dirname                  varchar2(60);
vvc2_rpt_filename                 varchar2(60);
vvc2_rpt_rec                      varchar2(145);
    
vvc2_in_run_mode                  varchar2(6);
vvc2_in_altp_supplier_number      varchar2(4);
vvc2_in_delete_reason_code        varchar2(10);
    
vvc2_rpt_altp_supplier_name       varchar2(80);
vvc2_rpt_price_program            varchar2(10);
vvc2_rpt_address1                 varchar2(80);
vvc2_rpt_address2                 varchar2(80);
vvc2_rpt_city                     varchar2(80);
vvc2_rpt_st                       varchar2(2);
vvc2_rpt_zip                      varchar2(80);
vn_rpt_part_count                 number;
  
vvc2_country_abbr                 varchar2(2);
vvc2_last_update_date             varchar2(10);
vvc2_delete_date                  varchar2(10);
vn_zip_range_count                number(3);
vvc2_primary_phone                varchar2(15);             
vvc2_secondary_phone              varchar2(15);
vn_row_count                      number(10);
vvc2_error_msg                    varchar2(120);
vn_return_code                    number(6);
    
vvc2_header1                      varchar2(145);
vvc2_header2                      varchar2(145);
vvc2_header3                      varchar2(145);
vvc2_header4                      varchar2(145);
vvc2_detail                       varchar2(145);
con_blankline                     varchar2(145) :=' ';

---------- counters and calculations ------------------------------------
vd_date 	                  date;
vd_sys_date                       varchar2(10);
vn_newpage                        number(2) :=58;
vn_page_ctr                       number(2) :=0;                 
vn_line_ctr                       number(2) :=0;
vn_tot_supplier_read              number(3) :=0;
vn_tot_supplier_proc              number(3) :=0;
vn_tot_part_count                 number(7) :=0;
vn_calc_elapsed_minutes           number(8);
vn_beg_day                        number(02);
vn_end_day                        number(02);
vn_beg_date_seconds               number(05); 
vn_end_date_seconds               number(05);
con_factor                        number(4,2) :=95.76; -- rows per second (delete time)
con_sec_per_minute                number(2) :=60;
con_sec_per_hour                  number(4) :=3600; 
 
---------  error messages -----------------------------------------------
con_supplier_notfnd_msg    varchar2(24):='SUPPLIER WAS NOT FOUND';
con_supplier_delete_msg    varchar2(24):='SUPPLIER ALREADY DELETED';
con_invalid_reason_msg     varchar2(24):='INVALID DELETE REASON';

--------------------------- MAIN PROGRAM --------------------------------
 
BEGIN  
  
---------   Initialize all variables   ---------------------------------------------------
 
  vvc2_in_dirname   :='&v_IN_DIR';
  vvc2_in_parmfile  :='&v_IN_PARM';
  vvc2_rpt_dirname  :='&v_RPT_DIR'; 
  vvc2_rpt_filename :='&v_RPT_FILE';
    
  select sysdate into vd_date from dual; 
     
  DBMS_OUTPUT.ENABLE(1000000); 
  DBMS_OUTPUT.NEW_LINE; 
  DBMS_OUTPUT.PUT_LINE('Start: ' || to_char(vd_date,'MM/DD/YYYY HH24:MI:SS'));   
  vn_beg_date_seconds :=to_number(to_char(vd_date,'SSSSS'));
  vn_beg_day :=to_char(vd_date,'DD');
   
------------ Open Input/Output File ------------------------------------------------------
   
  v_in_fHandle     := UTL_FILE.FOPEN(vvc2_in_dirname,vvc2_in_parmfile,'r');
  v_rpt_fHandle    := UTL_FILE.FOPEN(vvc2_rpt_dirname,vvc2_rpt_filename,'w');
    
--------- Get 1ST parm record to determine processing mode -------------------------------
    
  BEGIN
    UTL_FILE.GET_LINE(v_in_fHandle,vvc2_in_rec);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      UTL_FILE.FCLOSE(v_in_fHandle);
      UTL_FILE.FCLOSE(v_rpt_fHandle);
      RAISE_APPLICATION_ERROR(-20100,'***PGM ERROR: EMPTY DATA FILE ***');
  END;
 
--------- Parse input record ---------------------------------------------------------------------  
--------- Check for valid run mode value ---------------------------------------------------------
  
  vvc2_in_run_mode :=UPPER(substr(vvc2_in_rec,1,6)); 

  IF vvc2_in_run_mode not in ('VERIFY','DELETE') THEN
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_rpt_fHandle);
    RAISE_APPLICATION_ERROR(-20101,'***PGM ERROR: INVALID RUN MODE ***');
  END IF;
         
----------- Set Header and Subheader values and print first page's heading-----------------------
   
  vvc2_header1:= chr(12) || 'XAMR001' || lpad('MITCHELL INTERNATIONAL',72,' ')
          ||'                       ' 
          ||'PAGE NO. ';
        
  vvc2_header2:= lpad('DELETED SUPPLIER STATISTICS  (RUN MODE = ',83,' ')
          ||vvc2_in_run_mode 
          ||')            '
          ||'REPORT DATE:  ';
        
  vvc2_header3:= 'SPLR DEL REASON SUPPLIER_NAME            PROGRAM    '
              || 'ADDRESS 1            ADDRESS 2            '
              || 'CITY                 ST PART CNT'; 
                 
  vvc2_header4:= '---- ---------- ------------------------ ---------- ' 
              || '-------------------- -------------------- '
              || '-------------------- -- --------';
               
  vn_page_ctr:=vn_page_ctr + 1;
  UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_header1 || to_char(vn_page_ctr));   
  UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_header2 || vd_sys_date); 
  UTL_FILE.PUT_LINE(v_rpt_fHandle,con_blankline);
  UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_header3);
  UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_header4); 
  vn_line_ctr := 5;     
   
<<BEFORE_LOOP>>   
       
--------- Process remaining input record(s) from parm file   ------------------------------------
       
  LOOP  <<main_loop>>
       
     BEGIN
       UTL_FILE.GET_LINE(v_in_fHandle,vvc2_in_rec);
     EXCEPTION
       WHEN NO_DATA_FOUND THEN
       EXIT;
     END;
 
--------- Parse input record ---------------------------------------------------------------------  
 
     vvc2_in_altp_supplier_number :=UPPER(NVL(substr(vvc2_in_rec,1,4),' '));
     vvc2_in_delete_reason_code   :=UPPER(NVL(substr(vvc2_in_rec,8,10),' '));
     vn_tot_supplier_read         :=vn_tot_supplier_read + 1;
 
--------- Validate Altpart Supplier Number and pick-up database information ----------------------

--initialize values before call 
     vvc2_country_abbr            :=' ';
     vvc2_rpt_altp_supplier_name  :=' ';
     vvc2_rpt_price_program       :=' ';
     vvc2_last_update_date        :=' ';
     vvc2_delete_date             :=' ';  
     vn_rpt_part_count            :=0;
     vvc2_rpt_address1            :=' ';              
     vvc2_rpt_address2            :=' ';
     vvc2_rpt_city                :=' ';
     vvc2_rpt_st                  :=' ';
     vvc2_rpt_zip                 :=' ';
     vn_zip_range_count           :=0;
     vvc2_primary_phone           :=' ';
     vvc2_secondary_phone         :=' ';
     vn_row_count                 :=0;
     vvc2_error_msg               :=' ';
     vn_return_code               :=0;
    
--------- Call routine to select supplier info from database -------------------------------------

     PKG_ALTERNATE_PARTS.P_ALTPART_SUPPLIER_SEL_01
     (vvc2_in_altp_supplier_number,
      vvc2_country_abbr,
      vvc2_rpt_altp_supplier_name,
      vvc2_last_update_date,
      vvc2_delete_date, 
      vn_rpt_part_count,
      vvc2_rpt_address1,
      vvc2_rpt_address2,
      vvc2_rpt_city,
      vvc2_rpt_st,
      vvc2_rpt_zip,
      vn_zip_range_count,
      vvc2_primary_phone,
      vvc2_secondary_phone,
      vn_row_count,
      vvc2_error_msg,
      vn_return_code);

--check if select worked 
  
     IF vn_return_code <> 0 THEN
       vvc2_rpt_altp_supplier_name  := con_supplier_notfnd_msg;
     ELSIF vvc2_delete_date <> ' ' THEN
       vvc2_rpt_altp_supplier_name  := con_supplier_delete_msg; 
     END IF;       

--------- Call routine to check to validate reason code -----------------------------------------
     PKG_ALTERNATE_PARTS.P_SUPLR_DELETE_REASON_SEL_01
     (vvc2_in_delete_reason_code,
      vn_row_count,
      vvc2_error_msg,
      vn_return_code);

--check for valid delete reason 
     IF vn_return_code <> 0 THEN
       vvc2_rpt_altp_supplier_name  := con_invalid_reason_msg;
     END IF;

----------------- total part count --------------------------------------------------------------
  
     vn_tot_part_count    := vn_tot_part_count + vn_rpt_part_count;
  
 ---------------- print supplier info -----------------------------------------------------------
 
 --Check for new page     
     IF vn_line_ctr > vn_newpage THEN 
        vn_page_ctr:=vn_page_ctr+1;
        UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_header1 || to_char(vn_page_ctr));   
        UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_header2 || vd_sys_date); 
        UTL_FILE.PUT_LINE(v_rpt_fHandle,con_blankline);
        UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_header3);
        UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_header4); 
        vn_line_ctr := 5;     
     END IF;
   
     vvc2_detail:= ' ';
     vvc2_detail:= rpad(vvc2_in_altp_supplier_number,4,' ') 
           ||' '|| rpad(vvc2_in_delete_reason_code,10,' ') 
           ||' '|| rpad(vvc2_rpt_altp_supplier_name,24,' ')
           ||' '|| rpad(vvc2_rpt_price_program,10,' ')
           ||' '|| rpad(rtrim(vvc2_rpt_address1,20),20,' ')
           ||' '|| rpad(rtrim(vvc2_rpt_address2,20),20,' ') 
           ||' '|| rpad(rtrim(vvc2_rpt_city,20),20,' ')
           ||' '|| rpad(vvc2_rpt_st,2,' ')
           ||' '|| lpad(vn_rpt_part_count,8,0);
     UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_detail); 
     vvc2_detail:= ' ';
     UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_detail); 
             
     vn_line_ctr := vn_line_ctr + 2; 
     
--------- Bypass further database processing, if: ---------------------------------------------------
---------        this is VERIFY mode              ---------------------------------------------------
---------        the supplier was not found       ---------------------------------------------------
---------        the delete reason was invalid    ---------------------------------------------------
     IF vvc2_in_run_mode = 'VERIFY' THEN
       GOTO main_loop;             
     END IF;

     IF vvc2_rpt_altp_supplier_name = con_supplier_notfnd_msg THEN
       GOTO main_loop;             
     END IF;

     IF vvc2_rpt_altp_supplier_name = con_supplier_delete_msg THEN
       GOTO main_loop;             
     END IF;

     IF vvc2_rpt_altp_supplier_name = con_invalid_reason_msg THEN
       GOTO main_loop;             
     END IF;


--------- Call routine to delete parts assoc'd to supplier from database -------------------------

     PKG_ALTERNATE_PARTS.P_PART_ALTPART_XREF_DEL_03
     (vvc2_in_altp_supplier_number,
      vn_row_count,
      vvc2_error_msg,
      vn_return_code);

--check if delete was successful (or no rows found to delete)
  
     IF vn_return_code <> 000 AND vn_return_code <> 100 THEN
       UTL_FILE.FCLOSE(v_in_fHandle);
       UTL_FILE.FCLOSE(v_rpt_fHandle);
       RAISE_APPLICATION_ERROR(-20998,'***PGM ERROR: DELETE ERROR ***');
     END IF;

--------- Call routine to update part count, delete reason, and delete date w/i supplier table ---

     vn_rpt_part_count     := 0;
      --P. Becotte changed PKG_ALTERNATE_PARTS to PKG_ALTERNATE_PARTS_UPDATE.
     PKG_ALTERNATE_PARTS_UPDATE.P_ALTPART_SUPPLIER_UPD_02 
     (vvc2_in_altp_supplier_number,
      vn_rpt_part_count,
      vvc2_in_delete_reason_code,
      vd_date,
      vn_row_count,
      vvc2_error_msg,
      vn_return_code);

--check if update was successful
  
     IF vn_return_code <> 000 THEN
       UTL_FILE.FCLOSE(v_in_fHandle);
       UTL_FILE.FCLOSE(v_rpt_fHandle);
       RAISE_APPLICATION_ERROR(-20999,'***PGM ERROR: UPDATE ERROR ***');
     END IF;

     vn_tot_supplier_proc := vn_tot_supplier_proc + 1;

 -------- COMMIT changes assoc'd to supplier before processing next ---------------------------------------
     BEGIN
       COMMIT;  ----   all changes 
   -- WHILE TESTING, USE ROLLBACK (and comment out COMMIT)
   --  ROLLBACK; 
     EXCEPTION
       WHEN OTHERS THEN
          ROLLBACK;  -- Rollback all changes made to the database. Unlock tables.
          DBMS_OUTPUT.PUT_LINE('Error in commit deletion');
          DBMS_OUTPUT.PUT_LINE(SQLERRM);
          RETURN;  -- Stop execution.
     END;
  
 END LOOP main_loop;
  
 ------------------- Write end of report totals  ----------------------------------------------------------
 
  UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_header4); 
  vvc2_detail:= ' ';
  vvc2_detail:= lpad(lpad(vn_tot_part_count,8,0),126,' ');
  UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_detail); 
      
  UTL_FILE.PUT_LINE(v_rpt_fHandle,con_blankline);
  UTL_FILE.PUT_LINE(v_rpt_fHandle,con_blankline);
     
  vvc2_detail:= ' ';
  vvc2_detail:= 'REPORT TOTALS:'; 
  UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_detail); 

  vvc2_detail:= ' ';
  vvc2_detail:= lpad(vn_tot_supplier_read,3,0) 
            ||' SUPPLIERS READ';
  UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_detail); 
   
  vvc2_detail:= ' ';
  vvc2_detail:= lpad(vn_tot_supplier_proc,3,0) 
            ||' SUPPLIERS PROCESSED';
  UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_detail); 
 
------------------- Calc and Write Estimated versus Actual Time -------------------------------------------
 
  UTL_FILE.PUT_LINE(v_rpt_fHandle,con_blankline);
  UTL_FILE.PUT_LINE(v_rpt_fHandle,con_blankline);
     
  vn_calc_elapsed_minutes := ROUND(((vn_tot_part_count/con_factor)/con_sec_per_minute));
  vvc2_detail:= ' ';
  vvc2_detail:= 'ESTIMATED RUN TIME: ' 
            || vn_calc_elapsed_minutes || ' MINUTES';
  UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_detail); 

  Select sysdate into vd_date from dual;
  DBMS_OUTPUT.PUT_LINE('End: ' || to_char(vd_date,'MM/DD/YYYY HH24:MI:SS')); 
  vn_end_date_seconds :=to_number(to_char(vd_date,'SSSSS'));
  vn_end_day :=to_char(vd_date,'DD');
    
  IF vn_end_day = vn_beg_day THEN
    vn_calc_elapsed_minutes := (vn_end_date_seconds - vn_beg_date_seconds) / con_sec_per_minute;
  ELSE
    vn_calc_elapsed_minutes := (vn_end_date_seconds + (86400 - vn_beg_date_seconds)) / con_sec_per_minute;         
  END IF;
 
  vvc2_detail:= ' ';
  vvc2_detail:= '   ACTUAL RUN TIME: ' 
            || vn_calc_elapsed_minutes || ' MINUTES';
  UTL_FILE.PUT_LINE(v_rpt_fHandle,vvc2_detail); 

----------------- close  input / output files--------------------------------------------------------------

  UTL_FILE.FCLOSE(v_in_fHandle);
  UTL_FILE.FCLOSE(v_rpt_fHandle);

EXCEPTION
 
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_rpt_fHandle);
    RAISE_APPLICATION_ERROR(-20101,'Invalid Mode');

   WHEN UTL_FILE.INVALID_PATH THEN
    UTL_FILE.FCLOSE(v_rpt_fHandle);
    RAISE_APPLICATION_ERROR(-20100,'Invalid Path');
    
  WHEN UTL_FILE.INVALID_FILEHANDLE then
    UTL_FILE.FCLOSE(v_rpt_fHandle);
    RAISE_APPLICATION_ERROR(-20102,'Invalid Filehandle');
    
   WHEN UTL_FILE.INVALID_OPERATION then
    UTL_FILE.FCLOSE(v_rpt_fHandle);
    RAISE_APPLICATION_ERROR(-20103,'Invalid Filehandle operation');
    
  WHEN UTL_FILE.WRITE_ERROR then
    UTL_FILE.FCLOSE(v_rpt_fHandle);
    RAISE_APPLICATION_ERROR(-20104,'Write Error');
      
END;

-- leave "/" it is required for pl/sql end block ----------------------------------------------------
/
 
quit;
--- leave "end_sql_block" it is required for sql end block ----- 
%
#END OF Script
