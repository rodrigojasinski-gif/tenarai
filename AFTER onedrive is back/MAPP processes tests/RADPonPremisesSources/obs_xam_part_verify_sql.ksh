#!/bin/ksh
 set -vx
############################################################################
# PROGRAM:     xam_part_verify_sql.ksh
# AUTHOR:      Penny Genovese
# DESCRIPTION: Validate Part Supplier Part Numbers that were sent in
#              transactions by Altpart Data Providers.
# OVERVIEW: 1) Read parm file indicating which data files are to be verifyed.
#           2) Fetch acq_altpart_trans_parse row(s).
#           3) Using staged_part_number, perform part number lookup in RACE.
#              If found in Part table,
#              - update part_number with staged_part_number value
#              - calc variance between altpart_price and part price
#              - insert row in acq_altpart_trans_parse_error table, if
#                variance is close to or beyond 10% limit.
#           4) If not found in Part table, compress staged_part_number and
#              look for part in Part table.
#              If found,
#              - update part_number with part_number found in Part table
#              - calc variance between altpart_price and part price
#              - insert row in acq_altpart_trans_parse_error table, if
#                variance is close to or beyond 10% limit.
#           5) If not found in Part table, perform supersession lookup in
#              RACE, using compressed staged_part_number.
#              If found in Supersession table,
#              - follow chain to end
#              - lookup end-of-chain part in Part table
#              - If found in Part table,
#              - update part_number with superseding part number
#              - calc variance between altpart_price and part price
#              - insert row in acq_altpart_trans_parse_error table, if
#                variance is close to or beyond 10% limit.
#              - If not found in Part table,
#              - ??
#           6) If not found in Supersession table, perform supersession
#              lookup using compressed staged_part_number.
#              If found in Supersession table,
#              - follow chain to end
#              - lookup end-of-chain part in Part table
#              - If found in Part table,
#              - update part_number with superseding part number
#              - calc variance between altpart_price and part price
#              - insert row in acq_altpart_trans_parse_error table, if
#                variance is close to or beyond 10% limit.
#           6) If not found in Supersession table,
#              - insert row in acq_altpart_trans_parse_error table
#           7) At end of processing each file:
#              - write summary report record
############################################################################
# MODIFICATIONS:
#   2005/12/20 - PG2697 - Corrected check of fetched trans to previously
#                         fetched trans by adding check if altpart prices
#                         were also the same. 
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

define v_JOBNAME  = $ORA_JOBNAME  char(60);
define v_IN_DIR   = $ORA_IN_DIR   char(60);
define v_IN_FILE  = $ORA_IN_FILE  char(60);
define v_SUM_DIR  = $ORA_SUM_DIR  char(60);
define v_SUM_FILE = $ORA_SUM_FILE char(60);
define v_PRM_DIR  = $ORA_PRM_DIR  char(60);
define v_PRM_FILE = $ORA_PRM_FILE char(60);

DECLARE

---------  I/O FILE VARIABLES  ------------------------------------------

BAD_UPD_ALTP_TRANS_PARSE          exception;
BAD_INS_ALTP_TRANS_PARSE_ERROR    exception;
BAD_DEL_ALTP_TRANS_PARSE_ERROR    exception;
BAD_HEADER_ERROR                  exception;
INVALID_ERROR_CODE                exception;

v_in_fHandle                      UTL_FILE.FILE_TYPE;
v_sum_fHandle                     UTL_FILE.FILE_TYPE;
v_prm_fHandle                     UTL_FILE.FILE_TYPE;

vvc2_jobname                      varchar2(8);
vvc2_in_dirname                   varchar2(60);
vvc2_in_filename                  varchar2(60);
vvc2_in_rec                       varchar2(500);

vvc2_sum_dirname                  varchar2(60);
vvc2_sum_filename                 varchar2(60);

vvc2_prm_dirname                  varchar2(60);
vvc2_prm_filename                 varchar2(60);
vvc2_parm_rec                     varchar2(80);

---------  HEADER-RELATED VARIABLES  ------------------------------------

vvc2_in_data_provider_name        varchar2(80);
vvc2_in_file_name                 varchar2(80);
vc_in_process_flag                char(1);
vvc2_prev_data_provider_name      varchar2(80) := ' ';

vn_beg_provider_name              number :=10;
vn_end_provider_name              number :=0;
vn_len_provider_name              number :=0;

vn_beg_datafile_hdr               number :=0;
vn_beg_datafile_name              number :=0;
vn_end_datafile_name              number :=0;
vn_len_datafile_name              number :=0;

vn_beg_process_hdr                number :=0;
vn_beg_process_flag               number :=0;
vn_end_process_flag               number :=0;
vn_len_process_flag               number :=1;

vn_data_provider_skey             number;
vn_datafile_skey                  number;
vn_record_length                  number;
vvc2_datafile_country_abbr        varchar2(2);

---------  DATA-RELATED VARIABLES -------------------------------------
---------  aatp -> Acq_Altpart_Trans_Parse ----------------------------

vd_aatp_run_date                  date;
vvc2_aatpe_run_date               varchar2(19);
vn_aatp_row_sequence_number       number;
vvc2_aatp_part_supplier_number    varchar2(03);
vvc2_aatp_staged_part_number      varchar2(25);
vvc2_aatp_part_number             varchar2(25) :=NULL;
vn_aatp_altpart_price             number(15,4);

vc_part_number_type               char(1);
vvc2_compressed_part_number       varchar2(25);
vvc2_in_part_number               varchar2(25);
vvc2_out_part_number              varchar2(25);

vn_loop_ctr                       number;
vn_called_row_count               number(6);
vvc2_called_error_msg             varchar2(1000);

vn_provider_return_code           number(6);
vn_datafile_return_code           number(6);
vn_part_return_code               number(6);
vn_super_return_code              number(6);
vn_trans_parse_return_code        number(6);
vn_trans_parse_err_return_code    number(6);

vn_price_error_code               number(2);
vn_part_error_code                number(2);
vn_aatpe_error_code               number(2);

vvc2_prev_part_supplier_number    varchar2(03);
vvc2_prev_staged_part_number      varchar2(25);
vn_prev_altpart_price             number(15,4);

---------  REPORT VARIABLES  --------------------------------------------

vvc2_datafile_error_msg           varchar2(30);

vvc2_sum_line                     varchar2(145);
vd_date                           date;
vd_sys_date                       varchar2(10);
vvc2_run_date                     varchar2(19);

vn_sum_page_ctr                   number(3) :=0;
vn_sum_line_ctr                   number(2) :=0;
vn_datafile_trans_read            number(9) :=0;
vn_datafile_trans_for_updt        number(9) :=0;
vn_datafile_trans_error           number(9) :=0;
vn_datafile_trans_warning         number(9) :=0;
vn_tot_trans_read                 number(10):=0;
vn_tot_trans_for_updt             number(10):=0;
vn_tot_trans_error                number(10):=0;
vn_tot_trans_warning              number(10):=0;
vn_parm_recs_read                 number(10):=0;

vvc2_code_location                varchar2(50);

---------  CONSTANTS ----------------------------------------------------

con_dataprovider_keyword          char(9) :='PROVIDER=';
con_datafile_keyword              char(9) :='DATAFILE=';
con_process_keyword               char(8) :='PROCESS=';
con_data_provider_error           varchar2(30):='INVALID DATA PROVIDER IN PARM';
con_datafile_error                varchar2(30):='INVALID DATA FILE IN PARM';
con_bypass_error                  varchar2(30):='PROCESSING BYPASSED PER PARM';

con_compressed_part               char(1):='C';
con_formatted_part                char(1):='F';
con_price_near_limit              number(02):=19;
con_price_over_limit              number(02):=20;
con_price_is_zero                 number(02):=23;
con_five                          number(02):=05;
con_ten                           number(02):=10;

con_part_is_superseded            number(02):=24;
con_part_not_found                number(02):=14;

---------  REPORT CONSTANTS --------------------------------------------
con_newpage         number(2) :=40;
con_blankline       varchar2(145) :=' ';

con_header1         varchar2(145)
                    := lpad('MITCHELL INTERNATIONAL',52,' ')
                       || LPAD('PAGE NO: ',49,' ');

con_header2         varchar2(145)
                    := lpad('ALTERNATE PART - PART VERIFICATION SUMMARY',65,' ')
                       || LPAD('REPORT DATE: ',48,' ');

con_header3         varchar2(145)
                    := 'DATA PROVIDER (1st 30 CHARS)    '
                       || 'FILE NAME (1st 30 CHARS)        '
                       || 'PARSE READ  '
                       || 'FOR UPDATE  '
                       || 'IN ERROR    '
                       || 'PROCESSING MESSAGE              ';

con_header4         varchar2(145)
                    := '------------------------------  '
                       || '------------------------------  '
                       || '----------  '
                       || '----------  '
                       || '----------  '
                       || '------------------------------  ';

con_footnote1       varchar2(145) := 'NOTES:';

con_footnote2       varchar2(145)
                    := '  (1) PARSE READ = PARSED (IN LOAD SUMMARY REPORT)';
 
con_footnote3       varchar2(145)
                    := '  (2) PARSE READ = FOR UPDATE + IN ERROR';
 



-- Cursor to fetch acq_altpart_trans_parse rows -------------------------

CURSOR trans_parse_cur(data_provider_skey_in NUMBER, datafile_skey_in NUMBER) IS
  SELECT run_date, row_sequence_number, part_supplier_number, staged_part_number, altpart_price
  FROM acq_altpart_trans_parse
  WHERE data_provider_skey = data_provider_skey_in
    AND datafile_skey = datafile_skey_in
  ORDER BY part_supplier_number, staged_part_number, altpart_price;

---------  LOCAL PROCEDURES  --------------------------------------------

----------------------------------------------------------
-- WRITE_SUMMARY_REC:
--    This procedure writes summary report information. It
--    also writes a parm record, if the datafile contained
--    at least one valid record.
----------------------------------------------------------
PROCEDURE WRITE_SUMMARY_REC (vvc2_in_data_provider_name  IN varchar2,
                             vvc2_in_file_name           IN varchar2,
                             vn_datafile_trans_read      IN number,
                             vn_datafile_trans_for_updt  IN number,
                             vn_datafile_trans_error     IN number,
                             vvc2_datafile_error_msg     IN varchar2) IS


  con_process_keyword          char(9) :=';PROCESS=';
  vvc2_process_flag            char(1) :=' ';

  BEGIN

  -- Check for new page
    IF (vn_sum_line_ctr > con_newpage) OR (vn_sum_line_ctr = 0) THEN
       vn_sum_page_ctr := vn_sum_page_ctr+1;
       UTL_FILE.PUT_LINE(v_sum_fHandle,chr(12) || vvc2_jobname || con_header1 || to_char(vn_sum_page_ctr));
       UTL_FILE.PUT_LINE(v_sum_fHandle,con_header2 || vd_sys_date);
       UTL_FILE.PUT_LINE(v_sum_fHandle,con_blankline);
       UTL_FILE.PUT_LINE(v_sum_fHandle,con_header3);
       UTL_FILE.PUT_LINE(v_sum_fHandle,con_header4);
       vn_sum_line_ctr := 5;
    END IF;

  -- Write summary line
    vvc2_sum_line := RPAD(RTRIM(vvc2_in_data_provider_name,30),30,' ')
       || '  ' || RPAD(RTRIM(vvc2_in_file_name,30),30,' ')
       || '  ' || LPAD(vn_datafile_trans_read,10,' ')
       || '  ' || LPAD(vn_datafile_trans_for_updt,10,' ')
       || '  ' || LPAD(vn_datafile_trans_error,10,' ')
       || '  ' || RPAD(vvc2_datafile_error_msg,30,' ');

    UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_sum_line);
    vn_sum_line_ctr := vn_sum_line_ctr + 1;

  -------- COMMIT all work assoc'd to Data File before processing next
    BEGIN
      COMMIT;  ----   all changes
               -- WHILE TESTING, USE ROLLBACK (and comment out COMMIT)
               --  ROLLBACK;
    EXCEPTION
      WHEN OTHERS THEN
         ROLLBACK;  -- Rollback all changes made to the database. Unlock tables.
         DBMS_OUTPUT.PUT_LINE('Error in commit');
         DBMS_OUTPUT.PUT_LINE(SQLERRM);
         RETURN;  -- Stop execution.
    END;


END WRITE_SUMMARY_REC;

----------------------------------------------------------
-- PART_SELECT_AND_PRICE_CHECK:
--    This procedure calls routine to check if a part is
--    in the RACE Parts table. It also checks the price
--    against the Altpart Supplier's price.
----------------------------------------------------------
PROCEDURE PART_SELECT_AND_PRICE_CHECK (vvc2_aatp_part_supplier_number IN varchar2,
                       vvc2_datafile_country_abbr     IN varchar2,
                       vvc2_in_part_number            IN varchar2,
                       vc_part_number_type            IN char,
                       vn_aatp_altpart_price          IN number,
                       vvc2_out_part_number           IN OUT varchar2,
                       vn_price_error_code            IN OUT number,
                       vn_part_return_code            IN OUT number,
                       vn_called_row_count            IN OUT number,
                       vvc2_called_error_msg          IN OUT varchar2) IS

  vvc2_last_price_date              varchar2(10); --not needed but returned from call
  vi_last_price_date_ind            integer;      --not needed but returned from call
  vn_part_supplier_current_price    number(15,4);
  vn_calc_altpart_price             number(15,4);
  vn_calc_part_supplier_price       number(15,4);

BEGIN

  vvc2_out_part_number            := ' ';
  vn_part_return_code             := 0;
  vn_called_row_count             := 0;
  vvc2_called_error_msg           := ' ';
  vn_price_error_code             := 0;
  vn_part_supplier_current_price  := 0;

  IF vc_part_number_type = con_compressed_part THEN
    PKG_PART.P_PART_SEL_07
      (vvc2_aatp_part_supplier_number,
       vvc2_datafile_country_abbr,
       vvc2_in_part_number,
       vvc2_out_part_number,
       vn_part_supplier_current_price,
       vn_called_row_count,
       vvc2_called_error_msg,
       vn_part_return_code);
 ELSE
    PKG_PART.P_PART_SEL_01
       (vvc2_aatp_part_supplier_number,
        vvc2_datafile_country_abbr,
        vvc2_in_part_number,
        vvc2_out_part_number,
        vvc2_last_price_date,
        vi_last_price_date_ind,
        vn_part_supplier_current_price,
        vn_called_row_count,
        vvc2_called_error_msg,
        vn_part_return_code);
  END IF;

  -- exit if part not found
  IF vn_part_return_code <> 0 THEN
    return;
  END IF;

  -- part found, compare prices

  IF  vn_part_supplier_current_price = 0 THEN
    vn_price_error_code := con_price_is_zero;
    return;
  END IF;

  vn_calc_part_supplier_price := vn_part_supplier_current_price * con_ten;
  IF vn_aatp_altpart_price > vn_calc_part_supplier_price THEN
    vn_price_error_code := con_price_over_limit;
    return;
  END IF;

  vn_calc_part_supplier_price := vn_part_supplier_current_price * con_five;
  IF vn_aatp_altpart_price > vn_calc_part_supplier_price THEN
    vn_price_error_code := con_price_near_limit;
    return;
  END IF;

  vn_calc_altpart_price := vn_aatp_altpart_price * con_ten;
  IF  vn_part_supplier_current_price > vn_calc_altpart_price THEN
    vn_price_error_code := con_price_over_limit;
    return;
  END IF;

  vn_calc_altpart_price := vn_aatp_altpart_price * con_five;
  IF  vn_part_supplier_current_price > vn_calc_altpart_price THEN
    vn_price_error_code := con_price_near_limit;
    return;
  END IF;

END PART_SELECT_AND_PRICE_CHECK;

----------------------------------------------------------
-- UPDATE_TRANS_PARSE_ROW:
--    This procedure calls routine to update row w/i
--    ACQ_ALTPART_TRANS_PARSE table with part_number.
----------------------------------------------------------
PROCEDURE UPDATE_TRANS_PARSE_ROW (vn_data_provider_skey          IN number,
                                  vn_datafile_skey               IN number,
                                  vd_aatp_run_date               IN date,
                                  vn_aatp_row_sequence_number    IN number,
                                  vvc2_aatp_part_supplier_number IN varchar2,
                                  vvc2_aatp_part_number          IN varchar2) IS

BEGIN


  -- Call procedure to update transaction

  PKG_ALTERNATE_PARTS_DATAFILE.P_ACQ_ALTP_TRANS_PARSE_UPD_01
  (vn_data_provider_skey,
   vn_datafile_skey,
   vd_aatp_run_date,
   vn_aatp_row_sequence_number,
   vvc2_aatp_part_supplier_number,
   vvc2_aatp_part_number,
   vn_called_row_count,
   vvc2_called_error_msg,
   vn_trans_parse_return_code);

  -- Check if update successful ----------------------------------------------------------

  IF vn_trans_parse_return_code <> 0 THEN
    RAISE BAD_UPD_ALTP_TRANS_PARSE;
  END IF;

END UPDATE_TRANS_PARSE_ROW;

----------------------------------------------------------
-- WRITE_TRANS_PARSE_ERROR_ROW:
--    This procedure calls routine to insert error row w/i
--    ACQ_ALTPART_TRANS_PARSE_ERROR table.
----------------------------------------------------------
PROCEDURE WRITE_TRANS_PARSE_ERROR_ROW (vn_data_provider_skey            IN number,
                                         vn_datafile_skey               IN number,
                                         vvc2_aatpe_run_date            IN varchar2,
                                         vn_aatp_row_sequence_number    IN number,
                                         vvc2_aatp_part_supplier_number IN varchar2,
                                         vn_aatpe_error_code            IN number,
                                         vn_datafile_trans_error        IN OUT number,
                                         vn_tot_trans_error             IN OUT number,
                                         vn_datafile_trans_warning      IN OUT number,
                                         vn_tot_trans_warning           IN OUT number) IS

  vc_reject_flag        varchar(1) :=' ';
  vn_return_code        number(06);

BEGIN

  -- Validate error code and determine whether it classifies as a reject or warning
  PKG_ALTERNATE_PARTS_DATAFILE.P_ACQ_ERROR_SEL_01 (vn_aatpe_error_code,
                                                   vc_reject_flag,
                                                   vn_called_row_count,
                                                   vvc2_called_error_msg,
                                                   vn_return_code);

  -- Check if error code found
  IF vn_return_code <> 0 THEN
    RAISE INVALID_ERROR_CODE;
  END IF;

  -- Call procedure to insert transaction error
  PKG_ALTERNATE_PARTS_DATAFILE.P_ALTP_TRANS_PARSE_ERR_INS_01
  (vn_data_provider_skey,
   vn_datafile_skey,
   vvc2_aatpe_run_date,
   vn_aatp_row_sequence_number,
   vvc2_aatp_part_supplier_number,
   vn_aatpe_error_code,
   vn_called_row_count,
   vvc2_called_error_msg,
   vn_trans_parse_err_return_code);

  -- Check if insert successful
  IF vn_trans_parse_err_return_code <> 0 THEN
    RAISE BAD_INS_ALTP_TRANS_PARSE_ERROR;
  END IF;

  IF vc_reject_flag = 'Y' THEN
    vn_datafile_trans_error := vn_datafile_trans_error + 1;
    vn_tot_trans_error := vn_tot_trans_error + 1;
  ELSIF vc_reject_flag = 'N' THEN
    vn_datafile_trans_warning := vn_datafile_trans_warning + 1;
    vn_tot_trans_warning := vn_tot_trans_warning + 1;
  END IF;

END WRITE_TRANS_PARSE_ERROR_ROW;


---------  MAIN PROGRAM -------------------------------------------------

BEGIN

---------  INITIALIZE ALL VARIABLES   ---------------------------------------------------
  vvc2_code_location := 'INITIALIZE ALL';

  vvc2_jobname      :=UPPER('&v_JOBNAME');
  vvc2_in_dirname   :='&v_IN_DIR';
  vvc2_in_filename  :='&v_IN_FILE';
  vvc2_sum_dirname  :='&v_SUM_DIR';
  vvc2_sum_filename :='&v_SUM_FILE';
  vvc2_prm_dirname  :='&v_PRM_DIR';
  vvc2_prm_filename :='&v_PRM_FILE';

  select sysdate into vd_date from dual;
  vd_sys_date := to_char(vd_date,'MM/DD/YYYY');
  vvc2_run_date := to_char(vd_date,'MM/DD/YYYY HH24:MI:SS');

  DBMS_OUTPUT.ENABLE(1000000);
  DBMS_OUTPUT.NEW_LINE;
  DBMS_OUTPUT.PUT_LINE('Start: ' || vvc2_run_date);

---------  OPEN INPUT/OUTPUT FILE  -----------------------------------------------------
  vvc2_code_location := 'OPEN FILES';

  v_in_fHandle     := UTL_FILE.FOPEN(vvc2_in_dirname,vvc2_in_filename,'r',500);
  v_sum_fHandle    := UTL_FILE.FOPEN(vvc2_sum_dirname,vvc2_sum_filename,'w');
  v_prm_fHandle    := UTL_FILE.FOPEN(vvc2_prm_dirname,vvc2_prm_filename,'w');

---------  WRITE SUMMARY HEADING   -----------------------------------------------------

  vn_sum_page_ctr := vn_sum_page_ctr+1;
  UTL_FILE.PUT_LINE(v_sum_fHandle,chr(12) || vvc2_jobname || con_header1 || to_char(vn_sum_page_ctr));
  UTL_FILE.PUT_LINE(v_sum_fHandle,con_header2 || vd_sys_date);
  UTL_FILE.PUT_LINE(v_sum_fHandle,con_blankline);
  UTL_FILE.PUT_LINE(v_sum_fHandle,con_header3);
  UTL_FILE.PUT_LINE(v_sum_fHandle,con_header4);
  vn_sum_line_ctr := 5;

  LOOP  <<main_loop>>

---------  PROCESS INPUT RECORD  ----------------------------------------------------------
-- 1) read input parm file
-- 2) check if header record contains expected key phrases. If not, abend.
-- 3) call function to write summary line for previous datafile processed
-- 4) initialize header-related variables
-- 5) calc values needed for parsing info from header record
--         beginning position of datafile header
--         beginning position of datafile name
--         ending position of provider name
--         length of provider name
-- 5) check if record indicates datafile should be further processed
-- 6) parse out data provider name and datafile name from header
-- 7) call routine to verify data provider name and pickup skey
-- 8) call routine to verify datafile name and pickup skey and country_abbr
-- 9) call routine to delete any previously stored trans_parse_error rows
--10) fetch transactions. For each transaction:
--    o determine corresponding Mitchell part number, if it exists.
--    o calculate if difference between altpart and oem price is reasonable

  vvc2_code_location := 'PROCESS INPUT';

     BEGIN
       UTL_FILE.GET_LINE(v_in_fHandle,vvc2_in_rec);
     EXCEPTION
       WHEN NO_DATA_FOUND THEN
       EXIT;
     END;

     vn_parm_recs_read :=vn_parm_recs_read +1;


    IF UPPER(substr(vvc2_in_rec,1,9)) <> con_dataprovider_keyword THEN
      RAISE BAD_HEADER_ERROR;
    END IF;

    IF UPPER(vvc2_in_rec) not like '%DATAFILE=%' THEN
      RAISE BAD_HEADER_ERROR;
    END IF;

    IF UPPER(vvc2_in_rec) not like '%PROCESS=%' THEN
      RAISE BAD_HEADER_ERROR;
    END IF;

-- Write summary record and output parm with figures for previous datafile
    IF vn_parm_recs_read > 1 THEN
      WRITE_SUMMARY_REC  (vvc2_in_data_provider_name,
                          vvc2_in_file_name,
                          vn_datafile_trans_read,
                          vn_datafile_trans_for_updt,
                          vn_datafile_trans_error,
                          vvc2_datafile_error_msg);
      IF vvc2_in_data_provider_name <> vvc2_prev_data_provider_name THEN
        vvc2_parm_rec := vvc2_in_data_provider_name;
        UTL_FILE.PUT_LINE(v_prm_fHandle,vvc2_parm_rec);
        vvc2_prev_data_provider_name := vvc2_in_data_provider_name;
      END IF;
    END IF;


-- Initialize header-related variables -------------------------------------------------
  vvc2_code_location := 'INITIALIZE HEADER';

    vn_data_provider_skey          :=0;
    vn_provider_return_code        :=0;
    vn_datafile_return_code        :=0;
    vn_datafile_trans_read         :=0;
    vn_datafile_trans_for_updt      :=0;
    vn_datafile_trans_error        :=0;
    vn_datafile_trans_warning      :=0;
    vvc2_datafile_error_msg        :=' ';

    vn_beg_datafile_hdr  :=INSTR(vvc2_in_rec,con_datafile_keyword);
    vn_beg_process_hdr   :=INSTR(vvc2_in_rec,con_process_keyword);
    vn_end_provider_name :=vn_beg_datafile_hdr - 2;
    vn_len_provider_name :=(vn_end_provider_name - vn_beg_provider_name) + 1;
    vn_beg_datafile_name :=vn_beg_datafile_hdr + 9;
    vn_end_datafile_name :=vn_beg_process_hdr -2;
    vn_len_datafile_name :=(vn_end_datafile_name - vn_beg_datafile_name) + 1;
    vn_beg_process_flag  :=vn_beg_process_hdr + 8;

    vvc2_in_data_provider_name := UPPER(NVL(RTRIM(SUBSTR(vvc2_in_rec,vn_beg_provider_name,vn_len_provider_name)),' '));
    vvc2_in_file_name          := UPPER(NVL(RTRIM(SUBSTR(vvc2_in_rec,vn_beg_datafile_name,vn_len_datafile_name)),' '));
    vc_in_process_flag         := UPPER(NVL(RTRIM(SUBSTR(vvc2_in_rec,vn_beg_process_flag,vn_len_process_flag)),'N'));

-- Check if process flag indicates Yes, we should process trans assoc'd to datafile.
  vvc2_code_location := 'CHECK PROCESS FLAG';

     IF vc_in_process_flag = 'N' THEN
       vvc2_datafile_error_msg := con_bypass_error;
       GOTO main_loop;
     END IF;

-- Get data provider skey assoc'd with data provider name ------------------------------
  vvc2_code_location := 'GET DATA PROVIDER';

     PKG_ALTERNATE_PARTS_DATAFILE.P_ALTPART_DATA_PROVIDER_SEL_01
        (vvc2_in_data_provider_name,
         vn_data_provider_skey,
         vn_called_row_count,
         vvc2_called_error_msg,
         vn_provider_return_code);

     IF vn_provider_return_code <> 0 THEN
       vvc2_datafile_error_msg := con_data_provider_error;
       GOTO main_loop;
     END IF;

-- Get datafile skey assoc'd with datafile name -----------
  vvc2_code_location := 'GET DATAFILE';

     PKG_ALTERNATE_PARTS_DATAFILE.P_ALTPART_DATAFILE_SEL_01
        (vn_data_provider_skey,
         vvc2_in_file_name,
         vn_datafile_skey,
         vn_record_length,
         vvc2_datafile_country_abbr,
         vn_called_row_count,
         vvc2_called_error_msg,
         vn_datafile_return_code);

     IF vn_datafile_return_code <> 0 THEN
       vvc2_datafile_error_msg := con_datafile_error;
       GOTO main_loop;
     END IF;

-- Delete acq_altpart_trans_parse_errors that may exist from a prior run.
  vvc2_code_location := 'DELETE TRANS ERRORS';

  PKG_ALTERNATE_PARTS_DATAFILE.P_ALTP_TRANS_PARSE_ERR_DEL_01
  (vn_data_provider_skey,
   vn_datafile_skey,
   vn_called_row_count,
   vvc2_called_error_msg,
   vn_trans_parse_err_return_code);

-- Check if delete successful
  IF vn_trans_parse_err_return_code not in (000, 100) THEN
    RAISE BAD_DEL_ALTP_TRANS_PARSE_ERROR;
  END IF;

     <<fetch_loop>>
       vvc2_code_location := 'FETCH LOOP';

-- Initialize trans-related variables -------------------------------------------------
      vvc2_code_location := 'INITIALIZE TRANS';

      vn_trans_parse_return_code        :=0;
      vn_trans_parse_err_return_code    :=0;
      vvc2_aatp_part_number             :=NULL;
      vn_datafile_trans_read            :=0;
      vvc2_prev_part_supplier_number    :=NULL;
      vvc2_prev_staged_part_number      :=NULL;
      vn_prev_altpart_price             :=0;

     FOR trans_rec IN trans_parse_cur(vn_data_provider_skey, vn_datafile_skey)
       LOOP
         vvc2_code_location := 'TRANS FETCH';

         vn_datafile_trans_read := vn_datafile_trans_read + 1;
         vn_tot_trans_read :=vn_tot_trans_read + 1;

         vvc2_aatp_part_supplier_number := trans_rec.part_supplier_number;
         vd_aatp_run_date               := trans_rec.run_date;
         vvc2_aatpe_run_date            := to_char(vd_aatp_run_date,'MM/DD/YYYY HH24:MI:SS');
         vn_aatp_row_sequence_number    := trans_rec.row_sequence_number;
         vvc2_aatp_staged_part_number   := trans_rec.staged_part_number;
         vn_aatp_altpart_price          := trans_rec.altpart_price;
         vvc2_in_part_number            := ' ';

-- Check if staged_part_number equals staged part from previous fetch and prices are the same
-- If so, lookups have already been done. Go directly to update_trans routine.
         vvc2_code_location := 'PREV CHECK';

         IF vvc2_aatp_part_supplier_number = vvc2_prev_part_supplier_number
             AND vvc2_aatp_staged_part_number = vvc2_prev_staged_part_number
             AND vn_aatp_altpart_price = vn_prev_altpart_price THEN
           IF vn_part_error_code = con_part_not_found then
             GOTO write_error;
           ELSE
             GOTO update_trans;
           END IF;
         END IF;

         vvc2_prev_part_supplier_number    :=vvc2_aatp_part_supplier_number;
         vvc2_prev_staged_part_number      :=vvc2_aatp_staged_part_number;
         vn_prev_altpart_price             :=vn_aatp_altpart_price;
         vn_price_error_code               :=0;
         vn_part_error_code                :=0;

-- Check if staged_part_number is in Part Table
         vvc2_code_location := 'PART CHECK';

         vvc2_in_part_number := vvc2_aatp_staged_part_number;
         vc_part_number_type := 'F';
         PART_SELECT_AND_PRICE_CHECK (vvc2_aatp_part_supplier_number,
                                      vvc2_datafile_country_abbr,
                                      vvc2_in_part_number,
                                      vc_part_number_type,
                                      vn_aatp_altpart_price,
                                      vvc2_out_part_number,
                                      vn_price_error_code,
                                      vn_part_return_code,
                                      vn_called_row_count,
                                      vvc2_called_error_msg);

      -- part found; update trans_parse row
         IF vn_part_return_code = 0 THEN
           vvc2_aatp_part_number := vvc2_out_part_number;
           GOTO update_trans;
         END IF;

-- Compress staged_part_number and check if in Part Table
         vvc2_code_location := 'COMPRESSED PART CHECK';

         SP_COMP_PART (vvc2_aatp_staged_part_number, vvc2_compressed_part_number);

         vvc2_in_part_number := vvc2_compressed_part_number;
         vc_part_number_type := 'C';
         PART_SELECT_AND_PRICE_CHECK (vvc2_aatp_part_supplier_number,
                                      vvc2_datafile_country_abbr,
                                      vvc2_in_part_number,
                                      vc_part_number_type,
                                      vn_aatp_altpart_price,
                                      vvc2_out_part_number,
                                      vn_price_error_code,
                                      vn_part_return_code,
                                      vn_called_row_count,
                                      vvc2_called_error_msg);

     -- compressed part number found; update trans_parse row
         IF vn_part_return_code = 0 THEN
           vvc2_aatp_part_number := vvc2_out_part_number;
           GOTO update_trans;
         END IF;

-- Check if in Supersession Table, using compressed staged_part_number
         vvc2_code_location := 'SUPER CHECK';
         vn_called_row_count            := 0;
         vvc2_called_error_msg          := ' ';
         vn_super_return_code           := 0;

         PKG_SUPERSESSION.P_SUPERSESSION_SEL_09
            (vvc2_aatp_part_supplier_number,
             vvc2_datafile_country_abbr,
             vvc2_compressed_part_number,
             vvc2_out_part_number,
             vn_called_row_count,
             vvc2_called_error_msg,
             vn_super_return_code);

-- supersession not found; bypass update but insert error row
         IF vn_super_return_code <> 0 THEN
           vn_part_error_code := con_part_not_found;
           GOTO write_error;
         END IF;

-- supersession found; check if superseded part is in Part table
         vvc2_code_location := 'SUPER PART CHECK';
         vvc2_in_part_number := vvc2_out_part_number;
         vc_part_number_type := 'F';
         PART_SELECT_AND_PRICE_CHECK (vvc2_aatp_part_supplier_number,
                                      vvc2_datafile_country_abbr,
                                      vvc2_in_part_number,
                                      vc_part_number_type,
                                      vn_aatp_altpart_price,
                                      vvc2_out_part_number,
                                      vn_price_error_code,
                                      vn_part_return_code,
                                      vn_called_row_count,
                                      vvc2_called_error_msg);

     -- superseded part number found; update trans_parse row
         IF vn_part_return_code = 0 THEN
           vvc2_aatp_part_number := vvc2_out_part_number;
           vn_part_error_code := con_part_is_superseded;
           GOTO update_trans;
         END IF;

     -- superseded part number not found; bypass update but insert error row
         vn_part_error_code := con_part_not_found;
         GOTO write_error;

-- Update Part Number in acq_altpart_trans_parse table w/ part_number found
-- in either Part or Supersession Table.

   <<update_trans>>
         vvc2_code_location := 'UPDATE TRANS';

         UPDATE_TRANS_PARSE_ROW (vn_data_provider_skey,
                                 vn_datafile_skey,
                                 vd_aatp_run_date,
                                 vn_aatp_row_sequence_number,
                                 vvc2_aatp_part_supplier_number,
                                 vvc2_aatp_part_number);

-- Although part number was updated, don't add to trans_for_updt if
-- price was over limit as these trans will be bypassed in update
-- due to reject error. Ctrs are bypassed so that count reflects 
-- what will be processed in update (for balancing purposes).     
         IF vn_price_error_code <> con_price_over_limit THEN
           vn_datafile_trans_for_updt := vn_datafile_trans_for_updt + 1;
           vn_tot_trans_for_updt := vn_tot_trans_for_updt + 1;
         END IF;

-- Note: you may have two errors/warnings that require writing
--       One recording supersession lookup; one from price check.

   <<write_error>>
         vvc2_code_location := 'WRITE ERROR';

         IF vn_part_error_code > 0 THEN
           vn_aatpe_error_code := vn_part_error_code;
           WRITE_TRANS_PARSE_ERROR_ROW (vn_data_provider_skey,
                                        vn_datafile_skey,
                                        vvc2_aatpe_run_date,
                                        vn_aatp_row_sequence_number,
                                        vvc2_aatp_part_supplier_number,
                                        vn_aatpe_error_code,
                                        vn_datafile_trans_error,
                                        vn_tot_trans_error,
                                        vn_datafile_trans_warning,
                                        vn_tot_trans_warning);
         END IF;

         IF vn_price_error_code > 0 THEN
           vn_aatpe_error_code := vn_price_error_code;
           WRITE_TRANS_PARSE_ERROR_ROW (vn_data_provider_skey,
                                        vn_datafile_skey,
                                        vvc2_aatpe_run_date,
                                        vn_aatp_row_sequence_number,
                                        vvc2_aatp_part_supplier_number,
                                        vn_aatpe_error_code,
                                        vn_datafile_trans_error,
                                        vn_tot_trans_error,
                                        vn_datafile_trans_warning,
                                        vn_tot_trans_warning);
         END IF;

       END LOOP;



 END LOOP main_loop;

-------- FINAL PROCESSING -------------------------------------------------------------

-- Write summary record with figures for last datafile
 WRITE_SUMMARY_REC  (vvc2_in_data_provider_name,
                     vvc2_in_file_name,
                     vn_datafile_trans_read,
                     vn_datafile_trans_for_updt,
                     vn_datafile_trans_error,
                     vvc2_datafile_error_msg);
 IF vvc2_in_data_provider_name <> vvc2_prev_data_provider_name THEN
    vvc2_parm_rec := vvc2_in_data_provider_name;
    UTL_FILE.PUT_LINE(v_prm_fHandle,vvc2_parm_rec);
 END IF;

-- Write summary record containing totals.
  UTL_FILE.PUT_LINE(v_sum_fHandle,con_header4);

  vvc2_in_data_provider_name := ' ';
  vvc2_in_file_name          := ' ';
  vvc2_datafile_error_msg    := ' ';

  vvc2_sum_line := RPAD(RTRIM(vvc2_in_data_provider_name,30),30,' ')
        || '  ' || RPAD(RTRIM(vvc2_in_file_name,30),30,' ')
        || '  ' || LPAD(vn_tot_trans_read,10,' ')
        || '  ' || LPAD(vn_tot_trans_for_updt,10,' ')
        || '  ' || LPAD(vn_tot_trans_error,10,' ')
        || '  ' || RPAD(vvc2_datafile_error_msg,30,' ');
  UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_sum_line);

-- Write summary footnotes
  UTL_FILE.PUT_LINE(v_sum_fHandle,con_blankline);
  UTL_FILE.PUT_LINE(v_sum_fHandle,con_blankline);
  UTL_FILE.PUT_LINE(v_sum_fHandle,con_blankline);

  UTL_FILE.PUT_LINE(v_sum_fHandle,con_footnote1);
  UTL_FILE.PUT_LINE(v_sum_fHandle,con_footnote2);
  UTL_FILE.PUT_LINE(v_sum_fHandle,con_footnote3);

----------------- CLOSE INPUT / OUTPUT FILES --------------------------------------------

  UTL_FILE.FCLOSE(v_in_fHandle);
  UTL_FILE.FCLOSE(v_sum_fHandle);
  UTL_FILE.FCLOSE(v_prm_fHandle);

EXCEPTION

  WHEN UTL_FILE.INVALID_PATH THEN
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    RAISE_APPLICATION_ERROR(-20100,'Invalid Path');

  WHEN UTL_FILE.INVALID_MODE THEN
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    RAISE_APPLICATION_ERROR(-20101,'Invalid Mode');

  WHEN UTL_FILE.INVALID_FILEHANDLE then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    RAISE_APPLICATION_ERROR(-20102,'Invalid Filehandle');

   WHEN UTL_FILE.INVALID_OPERATION then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    RAISE_APPLICATION_ERROR(-20103,'Invalid Filehandle operation');

  WHEN UTL_FILE.READ_ERROR then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    RAISE_APPLICATION_ERROR(-20104,'Read Error');

  WHEN UTL_FILE.WRITE_ERROR then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    RAISE_APPLICATION_ERROR(-20105,'Write Error');

  WHEN UTL_FILE.INTERNAL_ERROR then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    RAISE_APPLICATION_ERROR(-20106,'Internal Error');

  WHEN BAD_HEADER_ERROR then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Error detected in header record');
    DBMS_OUTPUT.PUT_LINE('Record      : ' || vvc2_in_rec);
    DBMS_OUTPUT.PUT_LINE('Record Count: ' || vn_parm_recs_read);
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    RAISE_APPLICATION_ERROR(-20999,'Program Error');

  WHEN BAD_UPD_ALTP_TRANS_PARSE then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Error Updating ACQ_ALTPART_TRANS_PARSE Row');
    DBMS_OUTPUT.PUT_LINE('Returned from procedure: ' || vvc2_called_error_msg || '  ' || vn_trans_parse_return_code);
    DBMS_OUTPUT.PUT_LINE('Provider Skey : ' || vn_data_provider_skey);
    DBMS_OUTPUT.PUT_LINE('Datafile Skey : ' || vn_datafile_skey);
    DBMS_OUTPUT.PUT_LINE('Run Date (Key): ' || vd_aatp_run_date);
    DBMS_OUTPUT.PUT_LINE('Row Sequence  : ' || vn_aatp_row_sequence_number);
    DBMS_OUTPUT.PUT_LINE('Part Supplier : ' || vvc2_aatp_part_supplier_number);
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    RAISE_APPLICATION_ERROR(-20999,'Program Error');

  WHEN BAD_DEL_ALTP_TRANS_PARSE_ERROR then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Error Deleting ACQ_ALTPART_TRANS_PARSE_ERROR Rows');
    DBMS_OUTPUT.PUT_LINE('Returned from procedure: ' || vvc2_called_error_msg || '  ' || vn_trans_parse_return_code);
    DBMS_OUTPUT.PUT_LINE('Provider Skey : ' || vn_data_provider_skey);
    DBMS_OUTPUT.PUT_LINE('Datafile Skey : ' || vn_datafile_skey);
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    RAISE_APPLICATION_ERROR(-20999,'Program Error');

  WHEN BAD_INS_ALTP_TRANS_PARSE_ERROR then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Error Writing ACQ_ALTPART_TRANS_PARSE_ERROR Row');
    DBMS_OUTPUT.PUT_LINE('Returned from procedure: ' || vvc2_called_error_msg || '  ' || vn_trans_parse_return_code);
    DBMS_OUTPUT.PUT_LINE('Provider Skey : ' || vn_data_provider_skey);
    DBMS_OUTPUT.PUT_LINE('Datafile Skey : ' || vn_datafile_skey);
    DBMS_OUTPUT.PUT_LINE('Run Date (Key): ' || vvc2_aatpe_run_date);
    DBMS_OUTPUT.PUT_LINE('Row Sequence  : ' || vn_aatp_row_sequence_number);
    DBMS_OUTPUT.PUT_LINE('Part Supplier : ' || vvc2_aatp_part_supplier_number);
    DBMS_OUTPUT.PUT_LINE('Error Code    : ' || vn_aatpe_error_code);
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    RAISE_APPLICATION_ERROR(-20999,'Program Error');

  WHEN INVALID_ERROR_CODE then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Error Code not found in ACQ_ERROR');
    DBMS_OUTPUT.PUT_LINE('Provider Skey : ' || vn_data_provider_skey);
    DBMS_OUTPUT.PUT_LINE('Datafile Skey : ' || vn_datafile_skey);
    DBMS_OUTPUT.PUT_LINE('Run Date (Key): ' || vvc2_aatpe_run_date);
    DBMS_OUTPUT.PUT_LINE('Row Sequence  : ' || vn_aatp_row_sequence_number);
    DBMS_OUTPUT.PUT_LINE('Part Supplier : ' || vvc2_aatp_part_supplier_number);
    DBMS_OUTPUT.PUT_LINE('Error Code    : ' || vn_aatpe_error_code);
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    RAISE_APPLICATION_ERROR(-20999,'Program Error');

  WHEN OTHERS then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Unhandled Error at parm rec: ' || vn_parm_recs_read);
    DBMS_OUTPUT.PUT_LINE('Trans fetch count: ' || vn_datafile_trans_read);
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('Last valued SQL code and Error Message: ' ||
                         vvc2_called_error_msg || '  ' || vn_trans_parse_return_code);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    RAISE_APPLICATION_ERROR(-20999,'Unhandled Error Encountered');

END;

-- leave "/" it is required for pl/sql end block ----------------------------------------------------
/

quit;
--- leave "end_sql_block" it is required for sql end block -----
%
#END OF Script
