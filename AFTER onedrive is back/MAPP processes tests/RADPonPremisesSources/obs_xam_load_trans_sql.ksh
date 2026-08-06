#!/bin/ksh
 set -vx
############################################################################
# PROGRAM:     xam_load_trans_sql.ksh
# AUTHOR:      Penny Genovese
# DESCRIPTION: Parse data file(s) sent by Data Providers and load into
#              ACQ_ALTPART_TRANS table.
# OVERVIEW: 1) Read data provider record
#           2) Determine if record is a header or data record.
#           3) If header record:
#              - validate data provider and data file
#              - pickup corresponding database skeys
#              - pickup file layout information
#              - delete trans rows assoc'd to data provider, datafile.
#           4) If data record:
#              - validate record length
#              - parse out data and load into acq_altpart_trans table
#              - perform "level-1" verification and transformation
#           5) Write errors in acq_altpart_trans_error and trans_parse_error
#              tables. Also, write errors as comma-delimited file. (This
#              file will be ftp'd to NT for Data Analyst to review, if
#              further research of errors is needed.)
#           6) At end of processing each file:
#              - write summary report record
#              - write parm record so part checker program knows what
#                datafile(s) to check.
############################################################################
# MODIFICATIONS:
#   2010/04/20 - PG2697 - Added further valuing of vvc2_code_location and 
#                         added info displayed in unexpected error handling.
#   ------------------------------------------------------------------------  
#   2007/11/06 - PG2697 - Narrowed compressed part lookups to only valid 
#                         automotive parts OEMs (no test, marine, RV, or  
#                         motorcycle OEMs.
#   ------------------------------------------------------------------------
#   2007/06/05 - PG2697 - Changed factor used to calc estimated update time
#                         (due to move from old to new faster servers). 
#                          Old factor = 310.75. New factor = 675.25
#   ------------------------------------------------------------------------
#   2006/03/14 - PG2697 - Added logic to perform price variance checking.
#   ------------------------------------------------------------------------
#   2006/03/01 - PG2697 - Added restriction of part_supplier '010' (static)
#                         within compressed part and supersession lookups.
#                         (Was causing static parts to be added to
#                         non-static suppliers.)
#   ------------------------------------------------------------------------
#   2006/01/16 - PG2697 - Added logic to get row count for data files where
#                         prior trans are to be used for update. Moved calc
#                         of rows used for time calc to Write Summary rtn.
#   ------------------------------------------------------------------------
#   2005/10/19 - PG2697 - Changed error message associated to file layout.
#   ------------------------------------------------------------------------
#   2005/08/02 - PG2697 - Added BYPASS-REC logic to identify and bypass
#                         header-type recs within data file.
#   ------------------------------------------------------------------------
#   2005/07/21 - PG2697 - Added check for constraint violation as there are
#                         part rows and supersession rows that contain the
#                         same compressed part number (but formatted part
#                         numbers are different. Since part number isn't
#                         part of key, it was causing abend. New workaround
#                         is: If part-related trans has already been written,
#                         bypass supersession-related trans.
#   ------------------------------------------------------------------------
#   2005/06/14 - PG2697 - Changed lookup of compressed part number to only
#                         focus on parts having same country as datafile.
#                         Changed compress part lookup to look in both parts
#                         and supersession (rather than one or the other).
#   ------------------------------------------------------------------------
#   2005/04/12 - PG2697  - Changed factor used to calc estimated update time
#                          Old factor = 350.75. New factor = 310.75
#   ------------------------------------------------------------------------
#   2004/12/27 - PG2697  - Added replace of space with zero in price routine
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
define v_ERR_DIR  = $ORA_ERR_DIR  char(60);
define v_ERR_FILE = $ORA_ERR_FILE char(60);

DECLARE

---------  I/O FILE VARIABLES  ------------------------------------------

BAD_DEL_TRANS                     exception;
BAD_INS_ALTP_TRANS_ERROR          exception;
BAD_INS_ALTP_TRANS                exception;
BAD_INS_ALTP_TRANS_PARSE          exception;
BAD_INS_ALTP_TRANS_PARSE_ERROR    exception;
BAD_HEADER_ERROR                  exception;
SUPPLIER_COUNT_ERROR              exception;
INVALID_ERROR_CODE                exception;

v_in_fHandle                      UTL_FILE.FILE_TYPE;
v_sum_fHandle                     UTL_FILE.FILE_TYPE;
v_prm_fHandle                     UTL_FILE.FILE_TYPE;
v_err_fHandle                     UTL_FILE.FILE_TYPE;

vvc2_jobname                      varchar2(8);
vvc2_in_dirname                   varchar2(60);
vvc2_in_filename                  varchar2(60);
vvc2_in_rec                       varchar2(500);
vvc2_in_rec_hold                  varchar2(500);

vvc2_sum_dirname                  varchar2(60);
vvc2_sum_filename                 varchar2(60);
vvc2_sum_line                     varchar2(145);

vvc2_prm_dirname                  varchar2(60);
vvc2_prm_filename                 varchar2(60);
vvc2_parm_rec                     varchar2(300);

vvc2_err_dirname                  varchar2(60);
vvc2_err_filename                 varchar2(60);
vvc2_err_rec                      varchar2(200);

---------  HEADER-RELATED VARIABLES  ------------------------------------

vvc2_in_data_provider_name        varchar2(80);
vvc2_in_file_name                 varchar2(80);
vvc2_prev_data_provider_name      varchar2(80) :=' ';

vn_beg_datafile_hdr               number :=0;
vn_beg_datafile_name              number :=0;
vn_end_datafile_name              number :=0;

vn_beg_provider_hdr               number :=0;
vn_beg_provider_name              number :=10;
vn_end_provider_name              number :=0;
vn_len_provider_name              number :=0;

vn_max_text                       number :=80;

vn_data_provider_skey             number;
vn_datafile_skey                  number;
vn_record_length                  number;
vn_data_provider_filecount        number;
vn_data_provider_files_proc       number;

vn_desc_start_byte_1              number;
vn_desc_start_byte_2              number;
vn_desc_start_byte_3              number;
vn_desc_length_1                  number;
vn_desc_length_2                  number;
vn_desc_length_3                  number;
vn_desc_row_total                 number;
vn_altpart_num_start_byte_1       number;
vn_altpart_num_start_byte_2       number;
vn_altpart_num_start_byte_3       number;
vn_altpart_num_length_1           number;
vn_altpart_num_length_2           number;
vn_altpart_num_length_3           number;
vn_altpart_num_row_total          number;
vvc2_altp_price_fixed_value_1     varchar2(80);
vvc2_altp_price_fixed_value_2     varchar2(80);
vvc2_altp_price_fixed_value_3     varchar2(80);
vn_altp_price_start_byte_1        number;
vn_altp_price_start_byte_2        number;
vn_altp_price_start_byte_3        number;
vn_altp_price_length_1            number;
vn_altp_price_length_2            number;
vn_altp_price_length_3            number;
vc_altp_price_decimal_flag_1      char(1);
vc_altp_price_decimal_flag_2      char(1);
vc_altp_price_decimal_flag_3      char(1);
vc_altp_price_decimal_flag        char(1);
vn_altp_price_decimal_scale_1     number;
vn_altp_price_decimal_scale_2     number;
vn_altp_price_decimal_scale_3     number;
vn_altp_price_decimal_scale       number;
vn_altp_price_row_total           number;
vvc2_capa_fixed_value_1           varchar2(80);
vvc2_capa_fixed_value_2           varchar2(80);
vvc2_capa_fixed_value_3           varchar2(80);
vn_capa_start_byte_1              number;
vn_capa_start_byte_2              number;
vn_capa_start_byte_3              number;
vn_capa_length_1                  number;
vn_capa_length_2                  number;
vn_capa_length_3                  number;
vvc2_capa_search_string_1         varchar2(80);
vvc2_capa_search_string_2         varchar2(80);
vvc2_capa_search_string_3         varchar2(80);
vn_capa_row_total                 number;
vvc2_oem_disc_fixed_value_1       varchar2(80);
vvc2_oem_disc_fixed_value_2       varchar2(80);
vvc2_oem_disc_fixed_value_3       varchar2(80);
vn_oem_disc_start_byte_1          number;
vn_oem_disc_start_byte_2          number;
vn_oem_disc_start_byte_3          number;
vn_oem_disc_length_1              number;
vn_oem_disc_length_2              number;
vn_oem_disc_length_3              number;
vvc2_oem_disc_search_string_1     varchar2(80);
vvc2_oem_disc_search_string_2     varchar2(80);
vvc2_oem_disc_search_string_3     varchar2(80);
vn_oem_disc_row_total             number;
vn_part_num_start_byte_1          number;
vn_part_num_start_byte_2          number;
vn_part_num_start_byte_3          number;
vn_part_num_length_1              number;
vn_part_num_length_2              number;
vn_part_num_length_3              number;
vn_part_num_row_total             number;
vvc2_part_suplr_fixed_value_1     varchar2(80);
vvc2_part_suplr_fixed_value_2     varchar2(80);
vvc2_part_suplr_fixed_value_3     varchar2(80);
vn_part_suplr_start_byte_1        number;
vn_part_suplr_start_byte_2        number;
vn_part_suplr_start_byte_3        number;
vn_part_suplr_length_1            number;
vn_part_suplr_length_2            number;
vn_part_suplr_length_3            number;
vn_part_suplr_row_total           number;
vvc2_recond_fixed_value_1         varchar2(80);
vvc2_recond_fixed_value_2         varchar2(80);
vvc2_recond_fixed_value_3         varchar2(80);
vn_recond_start_byte_1            number;
vn_recond_start_byte_2            number;
vn_recond_start_byte_3            number;
vn_recond_length_1                number;
vn_recond_length_2                number;
vn_recond_length_3                number;
vvc2_recond_search_string_1       varchar2(80);
vvc2_recond_search_string_2       varchar2(80);
vvc2_recond_search_string_3       varchar2(80);
vn_recond_row_total               number;
vn_bypass_start_byte_1            number;
vn_bypass_start_byte_2            number;
vn_bypass_start_byte_3            number;
vn_bypass_length_1                number;
vn_bypass_length_2                number;
vn_bypass_length_3                number;
vvc2_bypass_search_string_1       varchar2(80);
vvc2_bypass_search_string_2       varchar2(80);
vvc2_bypass_search_string_3       varchar2(80);
vn_bypass_row_total               number;

---------  DATA-RELATED VARIABLES -------------------------------------
---------  aat  -> Acq_Altpart_Trans ----------------------------------
---------  aatp -> Acq_Altpart_Trans_Parse ----------------------------

vvc2_aat_part_supplier            varchar2(20);
vvc2_aat_part_number              varchar2(25);
vvc2_aat_altpart_number           varchar2(25);
vvc2_aat_altpart_price            varchar2(15);
vvc2_aat_altpart_reconditioned    varchar2(10);
vvc2_aat_altpart_capa             varchar2(10);
vvc2_aat_oem_discount             varchar2(25);
vvc2_aat_altpart_description      varchar2(80);
vn_aat_max_row_seq_number         number;

vvc2_aatp_part_supplier_number    varchar2(03);
vvc2_aatp_staged_part_number      varchar2(25);
vvc2_aatp_part_number             varchar2(25) :=NULL;
vvc2_aatp_altpart_number          varchar2(25);
vn_aatp_altpart_price             number(15,4);
vc_aatp_reconditioned_flag        char(01);
vc_aatp_capa_certified_flag       char(01);
vc_aatp_oem_discount_flag         char(01);

vvc2_prev_altpart_number          varchar2(25);  -- used for price variance checking

vvc2_compressed_part_number       varchar2(25);
vn_loop_ctr                       number;
vn_part_loop_ctr                  number;
vn_super_loop_ctr                 number;
vn_calc_record_length             number;
vn_called_row_count               number;
vvc2_called_error_msg             varchar2(1000);
vn_trans_del_return_code          number(6);
vn_provider_return_code           number(6);
vn_filecount_return_code          number(6);
vn_datafile_return_code           number(6);
vn_supplier_return_code           number(6);
vn_datafield_return_code          number(6);
vn_trans_return_code              number(6);
vn_trans_parse_return_code        number(6);
vn_trans_error_return_code        number(6);
vn_trans_parse_err_return_code    number(6);
vn_part_suplr_return_code         number(6);
vn_price_error_code               number(2);
vn_aate_error_code                number(2);
vn_aatpe_error_code               number(2);

vc_reject_switch                  char(1);
vvc2_datafile_country_abbr        varchar2(2);

---------  REPORT VARIABLES  --------------------------------------------

vvc2_header_save                  varchar2(180) :=' ';
vd_date                           date;
vvc2_sys_date                     varchar2(10);
vvc2_run_date                     varchar2(19);
vn_sum_page_ctr                   number(3) :=0;
vn_sum_line_ctr                   number(2) :=0;
vn_datafile_recs_read             number(8) :=0;
vn_datafile_trans_written         number(8) :=0;
vn_datafile_parse_written         number(8) :=0;
vn_datafile_recs_error            number(8) :=0;
vn_datafile_recs_bypass           number(8) :=0;
vn_datafile_suppliers             number(5) :=0;
vn_tot_recs_read                  number(8) :=0;
vn_tot_trans_written              number(8) :=0;
vn_tot_parse_written              number(8) :=0;
vn_tot_recs_error                 number(8) :=0;
vn_tot_recs_bypass                number(8) :=0;
vn_tot_suppliers                  number(5) :=0;

vn_time_tot_recs                  number(10) :=0; --total of (number of file trans * number of file suppliers)

vn_price_checked_ctr              number(2);
vn_variance_exceeded_ctr          number(2);

vvc2_sum_process_msg              varchar2(30);
vvc2_code_location                varchar2(50);
vn_calc_elapsed_minutes           number(10);

---------  CONSTANTS ----------------------------------------------------

con_dataprovider_keyword          char(9) :='PROVIDER=';
con_datafile_keyword              char(9) :='DATAFILE=';

con_data_provider_error           varchar2(30):='PROVIDER NAME NOT IN RACE';
con_datafile_error                varchar2(30):='DATAFILE NAME NOT IN RACE';
con_layout_missing_error          varchar2(30):='FILE LAYOUT MISSING OR IN ERR';
con_layout_error                  varchar2(30):='FIELD DEFINITION ERROR IN RACE';
con_price_var_error               varchar2(30):='FIRST 20 PRICE VARIANCES >=90%';
con_reclength_err_1               varchar2(25):='*** DEFINED REC LENGTH = ';
con_reclength_err_2               varchar2(20):='ACTUAL REC LENGTH = ';


con_invalid_rec_length            number(02):=04;
con_invalid_part_number           number(02):=07;
con_invalid_mfr_convert           number(02):=13;
con_invalid_altpart_num           number(02):=15;
con_part_supplier_derived         number(02):=28;

con_factor                        number(5,2) :=675.25; -- rows per second (update time)
con_sec_per_minute                number(2)   :=60;

---------  REPORT CONSTANTS ---------------------------------------------
con_header1     varchar2(145)
                := lpad('MITCHELL INTERNATIONAL',52,' ')
                   || LPAD('PAGE NO: ',49,' ');

con_header2     varchar2(145)
                := lpad('ALTERNATE PARTS DATA LOAD SUMMARY',66,' ')
                   || LPAD('REPORT DATE: ',47,' ');

con_header3     varchar2(145)
                := 'DATA PROVIDER (1st 30 CHARS)    '
                   || 'FILE (1st 20 CHARS)   '
                   || 'READ      '
                   || 'PROCESS   '
                   || 'PARSED    '
                   || 'IN ERROR  '
                   || 'BYPASSED  '
                   || 'SUPLR  '
                   || 'PROCESSING MESSAGE              ';

con_header4      varchar2(145)
                 := '------------------------------  '
                    || '--------------------  '
                    || '--------  '
                    || '--------  '
                    || '--------  '
                    || '--------  '
                    || '--------  '
                    || '-----  '
                    || '------------------------------  ';

con_footnote0    varchar2(145)
                 := 'NOTES: (*) FINAL Total Read represents all header and data records.';

con_footnote1    varchar2(145)
                 := '       (1) PARSED count may be greater than PROCESS count due to '
                    || 'Part Supplier Number Lookup based on compressed part number.';

con_footnote2    varchar2(145)
                 := '       (2) READ count = PROCESS + IN ERROR + BYPASS';

con_footnote3    varchar2(145)
                 := '       (3) BYPASS count = Blank records and those identified via BYPASS_REC info.';

con_footnote4    varchar2(145)
                 := 'ESTIMATED UPDATE TIME: ';

con_filecount_warning varchar2(145)
                 := '**Err: Number of Provider files defined in RACE does not match number '
                 || 'of files processed. Compare files processed to those defined in RACE.';

con_blank        varchar2(1) :=' ';
con_newpage      number(2) :=40;

---------  CURSORS ------------------------------------------------------

-- Cursor to fetch part_supplier_number(s) based on compressed_part_number
-- (Looks for both US and CA to allow for chance that parts isn't in the
-- preferred country now but could be before part check this evening.
CURSOR part_supplier_cur(compressed_part_number_in VARCHAR2, country_abbr_in VARCHAR2) IS
  SELECT distinct(part_supplier_number)
  FROM part
  WHERE compressed_part_number = RTRIM(compressed_part_number_in)
    AND part_supplier_number < '099'
    AND part_supplier_number not in ('005', '006', '007', '010', '011', '015', '027')  
    AND part_supplier_country_abbr = country_abbr_in;

CURSOR super_supplier_cur(compressed_part_number_in VARCHAR2, country_abbr_in VARCHAR2) IS
  SELECT distinct(part_supplier_number)
  FROM supersession
  WHERE compressed_part_number = RTRIM(compressed_part_number_in)
    AND part_supplier_number < '099'
    AND part_supplier_number not in ('005', '006', '007', '010', '011', '015', '027') 
    AND part_supplier_country_abbr = country_abbr_in;


---------  LOCAL PROCEDURES  --------------------------------------------

----------------------------------------------------------
-- WRITE_SUMMARY_REC:
--    This procedure writes summary report information. It
--    also writes a parm record, indicating whether datafile
--    s/b further processed.
----------------------------------------------------------
PROCEDURE WRITE_SUMMARY_REC (vvc2_in_data_provider_name  IN varchar2,
                             vvc2_in_file_name           IN varchar2,
                             vn_data_provider_skey       IN number,
                             vn_datafile_skey            IN number,
                             vvc2_run_date               IN varchar2,
                             vn_datafile_recs_read       IN number,
                             vn_datafile_trans_written   IN number,
                             vn_datafile_parse_written   IN number,
                             vn_datafile_recs_error      IN number,
                             vn_datafile_recs_bypass     IN number,
                             vn_datafile_suppliers       IN number,
                             vvc2_header_save            IN varchar2,
                             vn_time_tot_recs            IN OUT number,
                             vvc2_sum_process_msg        IN OUT varchar2,
                             vn_sum_line_ctr             IN OUT number,
                             vn_variance_exceeded_ctr    IN number,  
                             vn_price_checked_ctr        IN number) IS

con_process_keyword          char(9) :=';PROCESS=';
con_message_keyword          char(8) :=';REFMSG=';
vvc2_flag                    char(1) :=' ';

BEGIN
  vvc2_code_location := 'WRITE SUMMARY REC';

-- Delete transactions from prior run (only if data records
-- were processed in this run). Also, indicate whether datafile
-- should be processed further (ie. thru Part Checker).

-- In the case of an empty file, the previous trans data will be
-- processed further; therefore don't delete the previous trans rows.

-- To aid in calculating estimated update time, total "number of transactions read" is multiplied
-- by "suppliers associated to the transaction's datafile". All transactions are counted even if
-- they didn't make it through the edit. This is to offset database parts that won't be in the trans
-- file but will cause update processing to be performed. If no datafile records were read, the
-- number of transactions in the transaction table from the previous run is used (since these
-- transactions will be used for update). This is just a rough estimate.

  IF vn_datafile_recs_read = 0 AND vvc2_sum_process_msg = ' ' THEN
    vvc2_sum_process_msg := 'MISSING RECS; PREV TRANS USED';
    vvc2_flag := 'Y';
    -- Get count of transactions currently in database for this datafile (for time estimate).
    vvc2_called_error_msg  :=' ';
    vn_aat_max_row_seq_number :=0;
    vn_trans_return_code :=0;
    PKG_ALTERNATE_PARTS_DATAFILE.P_ACQ_ALTP_TRANS_SEL_01
       (vn_data_provider_skey,
        vn_datafile_skey,
        vn_aat_max_row_seq_number,
        vn_called_row_count,
        vvc2_called_error_msg,
        vn_trans_return_code);
    IF vn_trans_return_code = 0 THEN
      vn_time_tot_recs := vn_time_tot_recs + (vn_aat_max_row_seq_number * vn_datafile_suppliers);
    END IF;
-- In the case of other reject error messages (such as Invalid Data
-- Provider), there's no sense in processing further, and there's
-- no trans rows to delete.
  ELSIF vvc2_sum_process_msg <> ' ' THEN
    vvc2_flag := 'N';
-- If all the records were in error, don't process it further
-- but delete the previous trans rows so that error reporting will only show this run's transactions.
  ELSIF vn_datafile_trans_written = 0 THEN
    vvc2_sum_process_msg := 'ALL IN ERROR; NO DATA TO PROC';
    vvc2_flag := 'N';
    PKG_ALTERNATE_PARTS_DATAFILE.P_ACQ_ALTP_TRANS_DEL_01
       (vn_data_provider_skey,
        vn_datafile_skey,
        vvc2_run_date,
        vn_called_row_count,
        vvc2_called_error_msg,
        vn_trans_del_return_code);
    IF vn_trans_del_return_code not in (000, 100) THEN
      RAISE BAD_DEL_TRANS;
    END IF;
  ELSE
-- If some or no records were in error, process it further
-- by setting process flag and deleting the previous trans rows.
    vvc2_flag := 'Y';
    vn_time_tot_recs := vn_time_tot_recs + (vn_datafile_recs_read * vn_datafile_suppliers);
    PKG_ALTERNATE_PARTS_DATAFILE.P_ACQ_ALTP_TRANS_DEL_01
       (vn_data_provider_skey,
        vn_datafile_skey,
        vvc2_run_date,
        vn_called_row_count,
        vvc2_called_error_msg,
        vn_trans_del_return_code);
    IF vn_trans_del_return_code not in (000, 100) THEN
      RAISE BAD_DEL_TRANS;
    END IF;
  END IF;

-- Write parm record (for next job steps)
  vvc2_code_location := 'WRITE SUMMARY REC - 2';
  vvc2_parm_rec := (vvc2_header_save
                 || con_process_keyword || vvc2_flag
                 || con_message_keyword || vvc2_sum_process_msg);
  UTL_FILE.PUT_LINE(v_prm_fHandle,vvc2_parm_rec);

-- Check for new page
  vvc2_code_location := 'WRITE SUMMARY REC - 3';
  IF (vn_sum_line_ctr > con_newpage) THEN
     vn_sum_page_ctr := vn_sum_page_ctr+1;
     UTL_FILE.PUT_LINE(v_sum_fHandle,chr(12) || vvc2_jobname || con_header1 || to_char(vn_sum_page_ctr));
     UTL_FILE.PUT_LINE(v_sum_fHandle,con_header2 || vvc2_sys_date);
     UTL_FILE.PUT_LINE(v_sum_fHandle,RPAD(con_blank,145,' '));
     UTL_FILE.PUT_LINE(v_sum_fHandle,con_header3);
     UTL_FILE.PUT_LINE(v_sum_fHandle,con_header4);
     vn_sum_line_ctr := 5;
  END IF;

  vvc2_code_location := 'WRITE SUMMARY REC - 4';
  IF vn_price_checked_ctr > 0 THEN
    IF vn_price_checked_ctr = vn_variance_exceeded_ctr THEN
      vvc2_sum_process_msg := con_price_var_error;
    END IF;
  END IF;

-- Write summary line
  vvc2_code_location := 'WRITE SUMMARY REC - 5';
  vvc2_sum_line := RPAD(RTRIM(vvc2_in_data_provider_name,30),30,' ')
     || '  ' || RPAD(RTRIM(vvc2_in_file_name,20),20,' ')
     || '  ' || LPAD(vn_datafile_recs_read,8,' ')
     || '  ' || LPAD(vn_datafile_trans_written,8,' ')
     || '  ' || LPAD(vn_datafile_parse_written,8,' ')
     || '  ' || LPAD(vn_datafile_recs_error,8,' ')
     || '  ' || LPAD(vn_datafile_recs_bypass,8,' ')
     || '  ' || LPAD(vn_datafile_suppliers,5,' ')
     || '  ' || RPAD(vvc2_sum_process_msg,30,' ');

  vvc2_code_location := 'WRITE SUMMARY REC - 6';
  UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_sum_line);
  vn_sum_line_ctr := vn_sum_line_ctr + 1;

  -- COMMIT all work assoc'd to Data File before processing next
  vvc2_code_location := 'WRITE SUMMARY REC - COMMIT';
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
-- WRONG_LENGTH_REC:
--    This procedure handles inserting TRANS and TRANS ERROR
--    rows when a record having an invalid length is
--    encountered. There are two circumstances where this
--    can occur; hence the need for a procedure.
--
--    Example of 1: The first record is shorter than what's
--    expected. It has an end-of-record marker, so the next
--    record can be detected and processed successfully.
--    For this scenario, the invalid record is recorded as
--    an error and processing proceeds to get the next input
--    record.
--
--    123456789ABCDEFGEHIJ
--    989384934288327DSFSJIEURIUELCLSKJFLSURIER
--
--    Example of 2: The detail record is missing an end-of-
--    record marker and has merged with the next Header.
--    For this scenario, the invalid record is separated and
--    recorded as an error. The header record is then
--    re-aligned in the input record and processing proceeds
--    to evaluate the header record.
--
--    123456789ABCDEFGEHIJPROVIDER=1-800-RADIATOR;DATAFILE=MITCHELL
----------------------------------------------------------
PROCEDURE WRONG_LENGTH_REC (vn_data_provider_skey         IN number,
                            vn_datafile_skey              IN number,
                            vvc2_run_date                 IN varchar2,
                            vn_datafile_recs_read         IN number,
                            vn_datafile_recs_error        IN OUT number,
                            vn_tot_recs_error             IN OUT number,
                            vn_aate_error_code            IN OUT number) IS

BEGIN
  vvc2_code_location := 'WRONG LENGTH REC';

       vvc2_aat_altpart_description := con_reclength_err_1 || vn_record_length || '; '
                                    || con_reclength_err_2 || vn_calc_record_length;

       PKG_ALTERNATE_PARTS_DATAFILE.P_ACQ_ALTP_TRANS_INS_01
          (vn_data_provider_skey,
           vn_datafile_skey,
           vvc2_run_date,
           vn_datafile_recs_read,
           ' ',                                --vvc2_aat_part_supplier
           ' ',                                --vvc2_aat_part_number
           ' ',                                --vvc2_aat_altpart_number
           ' ',                                --vvc2_aat_altpart_price
           ' ',                                --vvc2_aat_altpart_reconditioned
           ' ',                                --vvc2_aat_altpart_capa
           ' ',                                --vvc2_aat_oem_discount
           vvc2_aat_altpart_description,
           vn_called_row_count,
           vvc2_called_error_msg,
           vn_trans_return_code);

       IF vn_trans_return_code <> 0 THEN
         RAISE BAD_INS_ALTP_TRANS;
       END IF;

       vn_aate_error_code := con_invalid_rec_length;
       vn_datafile_recs_error := vn_datafile_recs_error + 1;
       vn_tot_recs_error := vn_tot_recs_error + 1;

END WRONG_LENGTH_REC;

----------------------------------------------------------
-- WRITE_TRANS_ERROR_ROW:
--    This procedure calls routine to insert error row w/i
--    ACQ_ALTPART_TRANS_ERROR table. Also writes record in
--    errors file, if error_reject_type indicates reject.
----------------------------------------------------------
PROCEDURE WRITE_TRANS_ERROR_ROW (vvc2_in_data_provider_name  IN varchar2,
                                 vvc2_in_file_name           IN varchar2,
                                 vn_data_provider_skey       IN number,
                                 vn_datafile_skey            IN number,
                                 vvc2_run_date               IN varchar2,
                                 vn_datafile_recs_read       IN number,
                                 vn_aate_error_code          IN number,
                                 vc_reject_switch            IN OUT char) IS

  vn_return_code    number(06);
  vc_reject_flag    char(1) := ' ';

BEGIN

-- Call procedure to insert transaction error
  vvc2_code_location := 'WRITE_TRANS_ERROR_ROW';
  PKG_ALTERNATE_PARTS_DATAFILE.P_ACQ_ALTP_TRANS_ERROR_INS_01
  (vn_data_provider_skey,
   vn_datafile_skey,
   vvc2_run_date,
   vn_datafile_recs_read,
   vn_aate_error_code,
   vn_called_row_count,
   vvc2_called_error_msg,
   vn_trans_error_return_code);

-- Check if insert successful ----------------------------------------------------------

  IF vn_trans_error_return_code <> 0 THEN
    RAISE BAD_INS_ALTP_TRANS_ERROR;
  END IF;

-- Validate error code and determine whether it classifies as a reject or warning
  PKG_ALTERNATE_PARTS_DATAFILE.P_ACQ_ERROR_SEL_01 (vn_aate_error_code,
                                                   vc_reject_flag,
                                                   vn_called_row_count,
                                                   vvc2_called_error_msg,
                                                   vn_return_code);

  IF vn_return_code <> 0 THEN
    RAISE INVALID_ERROR_CODE;
  END IF;

-- If reject, write error record.                                   --------------------
-- Note reject_flag is revalued with each select error code (above) --------------------
--      reject_switch is reset at each trans.                       --------------------

  IF vc_reject_flag = 'Y' THEN
    vvc2_err_rec :=( vvc2_in_data_provider_name || '~' ||
                     vvc2_in_file_name          || '~' ||
                     vn_datafile_recs_read      || '~' ||
                     vn_aate_error_code);
    UTL_FILE.PUT_LINE(v_err_fHandle,vvc2_err_rec);
    vc_reject_switch := 'Y';
  END IF;

END WRITE_TRANS_ERROR_ROW;

----------------------------------------------------------
-- WRITE_TRANS_PARSE_ERROR_ROW:
--    This procedure calls routine to insert error row w/i
--    ACQ_ALTPART_TRANS_PARSE_ERROR table.
----------------------------------------------------------
PROCEDURE WRITE_TRANS_PARSE_ERROR_ROW (vn_data_provider_skey          IN number,
                                       vn_datafile_skey               IN number,
                                       vvc2_run_date                  IN varchar2,
                                       vn_datafile_recs_read          IN number,
                                       vvc2_aatp_part_supplier_number IN varchar2,
                                       vn_aatpe_error_code            IN number) IS

BEGIN
  vvc2_code_location := 'WRITE_TRANS_PARSE_ERROR_ROW';
-- Call procedure to insert transaction error
  PKG_ALTERNATE_PARTS_DATAFILE.P_ALTP_TRANS_PARSE_ERR_INS_01
  (vn_data_provider_skey,
   vn_datafile_skey,
   vvc2_run_date,
   vn_datafile_recs_read,
   vvc2_aatp_part_supplier_number,
   vn_aatpe_error_code,
   vn_called_row_count,
   vvc2_called_error_msg,
   vn_trans_parse_err_return_code);

-- Check if insert successful ----------------------------------------------------------

  IF vn_trans_parse_err_return_code <> 0 THEN
    RAISE BAD_INS_ALTP_TRANS_PARSE_ERROR;
  END IF;

END WRITE_TRANS_PARSE_ERROR_ROW;

----------------------------------------------------------
-- FORMAT_PRICE_FIELD:
--    This procedure changes the price information sent by
--    the provider (varchar2) into a numeric price that
--    will be used by the update program.
----------------------------------------------------------
PROCEDURE FORMAT_PRICE_FIELD (vvc2_aat_altpart_price       IN varchar2,
                              vc_altp_price_decimal_flag   IN char,
                              vn_altp_price_decimal_scale  IN number,
                              vn_aatp_altpart_price        IN OUT number,
                              vn_price_error_code          IN OUT number) IS

  vvc2_altpart_price_tmp        varchar2(15) := '';
  vvc2_altpart_price_tmp2       varchar2(15) := '';
  vvc2_altpart_price_tmp3       varchar2(15) := '';

  con_invalid_altpart_prc       number(02):=16;
  con_zero_altpart_prc          number(02):=26;
  con_price_contains_decimal    number(02):=27;

  vn_dec_pos                    number    := 0;
  vn_dec_scale                  number    := 0;
  vn_decimal_divisor            number    := 0;

  cn_price_length               number    := 15;
  cn_price_pos_neg              number    := -1;

BEGIN
  vvc2_code_location := 'FORMAT_PRICE_FIELD';
  vn_price_error_code          :=0;

-- Replace commas with NULL, replace space with zero, right-justify field, and prefix price with zeroes.
-- e.g. '     1,123.56  ' becomes '000000001123.56'
  vvc2_altpart_price_tmp := LPAD(RTRIM(REPLACE(REPLACE(vvc2_aat_altpart_price,','),' ','0')),cn_price_length,'0');

-- Determine decimal digits within price.
  vn_dec_pos := INSTR(vvc2_altpart_price_tmp,'.',cn_price_pos_neg);

-- If decimal point is hard-coded in price, calc decimal scale and then
-- strip decimal out (i.e. replace it with NULL).
  IF vc_altp_price_decimal_flag = 'Y' THEN
    vvc2_altpart_price_tmp2 := LPAD(REPLACE(vvc2_altpart_price_tmp,'.'),cn_price_length,'0');
    IF vn_dec_pos = 0 THEN
      vn_dec_scale := 0;
    ELSE
      vn_dec_scale := (cn_price_length - vn_dec_pos);
    END IF;
  ELSIF vn_dec_scale <> 0 THEN
    vn_price_error_code :=con_price_contains_decimal;
    RETURN;
  ELSE
    vvc2_altpart_price_tmp2 := vvc2_altpart_price_tmp;
    vn_dec_scale            := vn_altp_price_decimal_scale;
  END IF;

-- Based on found or implied decimal position, divide the price field by a figure
-- to obtain the numeric price that will be used in the update.
  IF vn_dec_scale = 0 THEN
    vn_decimal_divisor      := 1;
  ELSIF vn_dec_scale = 1 THEN
    vn_decimal_divisor      := 10;
  ELSIF vn_dec_scale = 2 THEN
    vn_decimal_divisor      := 100;
  ELSIF vn_dec_scale = 3 THEN
    vn_decimal_divisor      := 1000;
  ELSIF vn_dec_scale = 4 THEN
    vn_decimal_divisor      := 10000;
  ELSE
    vn_price_error_code := con_invalid_altpart_prc;
    RETURN;
  END IF;

  vn_aatp_altpart_price := ((to_number(vvc2_altpart_price_tmp2)) / vn_decimal_divisor);

  IF vn_aatp_altpart_price = 0 THEN
     vn_price_error_code := con_zero_altpart_prc;
  ELSIF vn_aatp_altpart_price is NULL THEN
     vn_price_error_code := con_invalid_altpart_prc;
  END IF;

EXCEPTION
   WHEN OTHERS THEN
     vn_price_error_code := con_invalid_altpart_prc;
     RETURN;

END FORMAT_PRICE_FIELD;

----------------------------------------------------------
-- CHECK_PRICE_VARIANCE:
--    This procedure checks the current transaction's
--    price against the prior run's price for the same 
--    aftermarket part. (Validity check to make sure that
--    price was defined correctly and that it hasn't
--    shifted in the file since it was defined.)
----------------------------------------------------------
PROCEDURE CHECK_PRICE_VARIANCE (vn_data_provider_skey          IN number,
                                vn_datafile_skey               IN number,
                                vvc2_run_date                  IN varchar2,
                                vvc2_aatp_part_supplier_number IN varchar2,
                                vvc2_aatp_staged_part_number   IN varchar2,
                                vvc2_aatp_altpart_number       IN varchar2,
                                vn_aatp_altpart_price          IN number, 
                                vn_variance_exceeded_ctr       IN OUT number,  
                                vn_price_checked_ctr           IN OUT number) IS

  vn_prev_altpart_price         number(15,4) :=0;
  vn_return_code                number(6)    :=0;
  con_ninety_pct                number(2)    :=90;
  vn_variance                   number(6)    :=0; 

BEGIN
  vvc2_code_location := 'CHECK_PRICE_VARIANCE';
  vn_called_row_count          :=0;
  vvc2_called_error_msg        :=' ';
 
PKG_ALTERNATE_PARTS_DATAFILE.P_ACQ_ALTP_TRANS_PARSE_SEL_01
   (vn_data_provider_skey,
    vn_datafile_skey,
    vvc2_run_date,
    vvc2_aatp_part_supplier_number,
    vvc2_aatp_staged_part_number,
    vvc2_aatp_altpart_number,
    vn_prev_altpart_price,
    vn_called_row_count,
    vvc2_called_error_msg,
    vn_return_code);

    IF vn_called_row_count = 0 THEN
      RETURN;
    END IF;

    vn_variance := ABS(ROUND(((vn_prev_altpart_price - vn_aatp_altpart_price) / vn_prev_altpart_price) * 100));

    IF vn_variance >= con_ninety_pct THEN
      vn_variance_exceeded_ctr := vn_variance_exceeded_ctr + 1;
    END IF;
    
    vn_price_checked_ctr := vn_price_checked_ctr + 1;

EXCEPTION
   WHEN OTHERS THEN
     RETURN;

END CHECK_PRICE_VARIANCE;

-------------------------------------------------------------------------
---------  MAIN PROGRAM -------------------------------------------------
-------------------------------------------------------------------------

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
  vvc2_err_dirname  :='&v_ERR_DIR';
  vvc2_err_filename :='&v_ERR_FILE';

  select sysdate into vd_date from dual;
  vvc2_sys_date := to_char(vd_date,'MM/DD/YYYY');
  vvc2_run_date := to_char(vd_date,'MM/DD/YYYY HH24:MI:SS');

  DBMS_OUTPUT.ENABLE(1000000);
  DBMS_OUTPUT.NEW_LINE;
  DBMS_OUTPUT.PUT_LINE('Start: ' || vvc2_run_date);

---------  OPEN INPUT/OUTPUT FILE  -----------------------------------------------------
  vvc2_code_location := 'OPEN FILES';

  v_in_fHandle     := UTL_FILE.FOPEN(vvc2_in_dirname,vvc2_in_filename,'r',500);
  v_sum_fHandle    := UTL_FILE.FOPEN(vvc2_sum_dirname,vvc2_sum_filename,'w');
  v_prm_fHandle    := UTL_FILE.FOPEN(vvc2_prm_dirname,vvc2_prm_filename,'w');
  v_err_fHandle    := UTL_FILE.FOPEN(vvc2_err_dirname,vvc2_err_filename,'w');

---------  WRITE HEADER REC IN ERROR FILE  ----------------

  vvc2_err_rec :=( 'DATA PROVIDER NAME' || '~' ||
                   'DATAFILE NAME'      || '~' ||
                   'RECORD IN ERROR'    || '~' ||
                   'ERROR CODE' );
  UTL_FILE.PUT_LINE(v_err_fHandle,vvc2_err_rec);

---------  WRITE HEADERS FOR SUMMARY REPORT  ----------------

  vn_sum_page_ctr := vn_sum_page_ctr+1;
  UTL_FILE.PUT_LINE(v_sum_fHandle,chr(12) || vvc2_jobname || con_header1 || to_char(vn_sum_page_ctr));
  UTL_FILE.PUT_LINE(v_sum_fHandle,con_header2 || vvc2_sys_date);
  UTL_FILE.PUT_LINE(v_sum_fHandle,RPAD(con_blank,135,' '));
  UTL_FILE.PUT_LINE(v_sum_fHandle,con_header3);
  UTL_FILE.PUT_LINE(v_sum_fHandle,con_header4);
  vn_sum_line_ctr := 5;


  LOOP  <<main_loop>>

---------  READ INPUT RECORD  ----------------------------------------------------------
  vvc2_code_location := 'READ INPUT';

    BEGIN
      UTL_FILE.GET_LINE(v_in_fHandle,vvc2_in_rec);
      vvc2_code_location := 'READ INPUT 1';
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
      EXIT;
    END;

    vvc2_code_location := 'READ INPUT 2';
    vn_tot_recs_read := vn_tot_recs_read + 1;

-- If you've read a blank record, bypass processing it.
    vvc2_code_location := 'READ INPUT 3'; 
    IF LTRIM(vvc2_in_rec) is NULL THEN
       vn_datafile_recs_bypass := vn_datafile_recs_bypass + 1;
       vn_tot_recs_bypass := vn_tot_recs_bypass + 1;
       vn_datafile_recs_read := vn_datafile_recs_read + 1;
       GOTO main_loop;
    END IF;

---------  CHECK IF HEADER RECORD  -----------------------------------------------------
---------  If so,
---------   1) call function to write summary line for previous datafile processed
---------   2) initialize header-related variables
---------   3) calc values needed for parsing info from header record
---------        beginning position of datafile header
---------        beginning position of datafile name
---------        ending position of provider name
---------        length of provider name
---------   4) check that header record contains datafile information. If not, abend.
---------   5) parse out data provider name and datafile name from header
---------   6) call routine to verify data provider name and pickup skey
---------   7) call routine to verify datafile name and pickup skey and reclength
---------   8) call routine to get associated fieldname positions and processing rules
    vvc2_code_location := 'READ INPUT 4'; 
    IF UPPER(substr(vvc2_in_rec,1,9)) <> con_dataprovider_keyword THEN
      IF vn_tot_recs_read = 1 THEN
        RAISE BAD_HEADER_ERROR;
      ELSIF UPPER(vvc2_in_rec) like '%DATAFILE=%' THEN
        IF UPPER(vvc2_in_rec) like '%PROVIDER=%' THEN
          vn_beg_provider_hdr  :=INSTR(vvc2_in_rec,con_dataprovider_keyword);
          vvc2_in_rec_hold := rtrim(substr(vvc2_in_rec,vn_beg_provider_hdr,(179 + vn_beg_provider_hdr)));
          vvc2_in_rec := rtrim(substr(vvc2_in_rec,1,(vn_beg_provider_hdr-1)));
          vn_datafile_recs_read := vn_datafile_recs_read + 1;
          vn_calc_record_length := LENGTH(vvc2_in_rec);
          WRONG_LENGTH_REC (vn_data_provider_skey,
                            vn_datafile_skey,
                            vvc2_run_date,
                            vn_datafile_recs_read,
                            vn_datafile_recs_error,
                            vn_tot_recs_error,
                            vn_aate_error_code);
          WRITE_TRANS_ERROR_ROW (vvc2_in_data_provider_name,
                                 vvc2_in_file_name,
                                 vn_data_provider_skey,
                                 vn_datafile_skey,
                                 vvc2_run_date,
                                 vn_datafile_recs_read,
                                 vn_aate_error_code,
                                 vc_reject_switch);
          vvc2_in_rec := vvc2_in_rec_hold;
        ELSE
          RAISE BAD_HEADER_ERROR;
        END IF;
      ELSE
        GOTO detail_rtn;
      END IF;
    END IF;


-- Write summary record with figures for previous datafile
    vvc2_code_location := 'READ INPUT 5'; 
    IF vn_tot_recs_read > 1 THEN
      WRITE_SUMMARY_REC  (vvc2_in_data_provider_name,
                          vvc2_in_file_name,
                          vn_data_provider_skey,
                          vn_datafile_skey,
                          vvc2_run_date,
                          vn_datafile_recs_read,
                          vn_datafile_trans_written,
                          vn_datafile_parse_written,
                          vn_datafile_recs_error,
                          vn_datafile_recs_bypass,
                          vn_datafile_suppliers,
                          vvc2_header_save,
                          vn_time_tot_recs,
                          vvc2_sum_process_msg,
                          vn_sum_line_ctr,
                          vn_variance_exceeded_ctr,  
                          vn_price_checked_ctr);
    END IF;

    vvc2_code_location := 'READ INPUT 6'; 
    vvc2_header_save := rtrim(substr(vvc2_in_rec,1,179));

-- Initialize header-related variables -------------------------------------------------
  vvc2_code_location := 'INITIALIZE HEADER';

    vn_provider_return_code           :=0;
    vn_filecount_return_code          :=0;
    vn_datafile_return_code           :=0;
    vn_supplier_return_code           :=0;
    vn_trans_del_return_code          :=0;
    vn_datafield_return_code          :=0;
    vn_datafile_recs_read             :=0;
    vn_datafile_trans_written         :=0;
    vn_datafile_parse_written         :=0;
    vn_datafile_recs_error            :=0;
    vn_datafile_recs_bypass           :=0;
    vn_price_checked_ctr              :=0;
    vn_variance_exceeded_ctr          :=0;
    vn_datafile_suppliers             :=0;
    vvc2_sum_process_msg              :=' ';
    vn_desc_start_byte_1              :=0;
    vn_desc_start_byte_2              :=0;
    vn_desc_start_byte_3              :=0;
    vn_desc_length_1                  :=0;
    vn_desc_length_2                  :=0;
    vn_desc_length_3                  :=0;
    vn_desc_row_total                 :=0;
    vn_altpart_num_start_byte_1       :=0;
    vn_altpart_num_start_byte_2       :=0;
    vn_altpart_num_start_byte_3       :=0;
    vn_altpart_num_length_1           :=0;
    vn_altpart_num_length_2           :=0;
    vn_altpart_num_length_3           :=0;
    vn_altpart_num_row_total          :=0;
    vvc2_altp_price_fixed_value_1     :=' ';
    vvc2_altp_price_fixed_value_2     :=' ';
    vvc2_altp_price_fixed_value_3     :=' ';
    vn_altp_price_start_byte_1        :=0;
    vn_altp_price_start_byte_2        :=0;
    vn_altp_price_start_byte_3        :=0;
    vn_altp_price_length_1            :=0;
    vn_altp_price_length_2            :=0;
    vn_altp_price_length_3            :=0;
    vc_altp_price_decimal_flag_1      :=' ';
    vc_altp_price_decimal_flag_2      :=' ';
    vc_altp_price_decimal_flag_3      :=' ';
    vn_altp_price_decimal_scale_1     :=0;
    vn_altp_price_decimal_scale_2     :=0;
    vn_altp_price_decimal_scale_3     :=0;
    vn_altp_price_row_total           :=0;
    vvc2_capa_fixed_value_1           :=' ';
    vvc2_capa_fixed_value_2           :=' ';
    vvc2_capa_fixed_value_3           :=' ';
    vn_capa_start_byte_1              :=0;
    vn_capa_start_byte_2              :=0;
    vn_capa_start_byte_3              :=0;
    vn_capa_length_1                  :=0;
    vn_capa_length_2                  :=0;
    vn_capa_length_3                  :=0;
    vvc2_capa_search_string_1         :=' ';
    vvc2_capa_search_string_2         :=' ';
    vvc2_capa_search_string_3         :=' ';
    vn_capa_row_total                 :=0;
    vvc2_oem_disc_fixed_value_1       :=' ';
    vvc2_oem_disc_fixed_value_2       :=' ';
    vvc2_oem_disc_fixed_value_3       :=' ';
    vn_oem_disc_start_byte_1          :=0;
    vn_oem_disc_start_byte_2          :=0;
    vn_oem_disc_start_byte_3          :=0;
    vn_oem_disc_length_1              :=0;
    vn_oem_disc_length_2              :=0;
    vn_oem_disc_length_3              :=0;
    vvc2_oem_disc_search_string_1     :=' ';
    vvc2_oem_disc_search_string_2     :=' ';
    vvc2_oem_disc_search_string_3     :=' ';
    vn_oem_disc_row_total             :=0;
    vn_part_num_start_byte_1          :=0;
    vn_part_num_start_byte_2          :=0;
    vn_part_num_start_byte_3          :=0;
    vn_part_num_length_1              :=0;
    vn_part_num_length_2              :=0;
    vn_part_num_length_3              :=0;
    vn_part_num_row_total             :=0;
    vvc2_part_suplr_fixed_value_1     :=' ';
    vvc2_part_suplr_fixed_value_2     :=' ';
    vvc2_part_suplr_fixed_value_3     :=' ';
    vn_part_suplr_start_byte_1        :=0;
    vn_part_suplr_start_byte_2        :=0;
    vn_part_suplr_start_byte_3        :=0;
    vn_part_suplr_length_1            :=0;
    vn_part_suplr_length_2            :=0;
    vn_part_suplr_length_3            :=0;
    vn_part_suplr_row_total           :=0;
    vvc2_recond_fixed_value_1         :=' ';
    vvc2_recond_fixed_value_2         :=' ';
    vvc2_recond_fixed_value_3         :=' ';
    vn_recond_start_byte_1            :=0;
    vn_recond_start_byte_2            :=0;
    vn_recond_start_byte_3            :=0;
    vn_recond_length_1                :=0;
    vn_recond_length_2                :=0;
    vn_recond_length_3                :=0;
    vvc2_recond_search_string_1       :=' ';
    vvc2_recond_search_string_2       :=' ';
    vvc2_recond_search_string_3       :=' ';
    vn_recond_row_total               :=0;
    vn_bypass_start_byte_1            :=0;
    vn_bypass_start_byte_2            :=0;
    vn_bypass_start_byte_3            :=0;
    vn_bypass_length_1                :=0;
    vn_bypass_length_2                :=0;
    vn_bypass_length_3                :=0;
    vvc2_bypass_search_string_1       :=' ';
    vvc2_bypass_search_string_2       :=' ';
    vvc2_bypass_search_string_3       :=' ';
    vn_bypass_row_total               :=0;
    vvc2_prev_altpart_number          :=' ';
    vn_beg_datafile_hdr  :=INSTR(vvc2_in_rec,con_datafile_keyword);
    vn_beg_datafile_name :=vn_beg_datafile_hdr + 9;
    vn_end_provider_name :=vn_beg_datafile_hdr - 2;
    vn_len_provider_name :=(vn_end_provider_name - vn_beg_provider_name) + 1;

    IF vn_beg_datafile_hdr = 0 THEN
       vvc2_sum_process_msg := con_datafile_error;
       vn_datafile_return_code := 100;
       GOTO main_loop;
    END IF;

    vvc2_in_data_provider_name := UPPER(NVL(RTRIM(SUBSTR(vvc2_in_rec,vn_beg_provider_name,vn_len_provider_name)),' '));
    vvc2_in_file_name          := UPPER(NVL(RTRIM(SUBSTR(vvc2_in_rec,vn_beg_datafile_name,vn_max_text)),' '));

-- If new data provider, compare number of files processed for prev against number defined in database.
-- This makes sure that all providers data files are accounted for.
    IF vn_tot_recs_read > 1 THEN
       IF vvc2_in_data_provider_name <> vvc2_prev_data_provider_name THEN
          IF vn_data_provider_files_proc <> vn_data_provider_filecount THEN
             vvc2_sum_line := con_filecount_warning;
             UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_sum_line);
          END IF;
       END IF;
    END IF;

    DBMS_OUTPUT.PUT_LINE('data_provider_name: ' ||  vvc2_in_data_provider_name
                    || '  data_file_name: ' ||  vvc2_in_file_name);

-- Get data provider skey assoc'd with data provider name ------------------------------
-- Get Number of files defined in the database for this data provider. -----------------
  vvc2_code_location := 'GET DATA PROVIDER';

     IF vvc2_in_data_provider_name <> vvc2_prev_data_provider_name THEN
       PKG_ALTERNATE_PARTS_DATAFILE.P_ALTPART_DATA_PROVIDER_SEL_01
          (vvc2_in_data_provider_name,
           vn_data_provider_skey,
           vn_called_row_count,
           vvc2_called_error_msg,
           vn_provider_return_code);
-- Check if select worked
       IF vn_provider_return_code <> 0 THEN
         vvc2_sum_process_msg := con_data_provider_error;
         GOTO main_loop;
       END IF;
       vvc2_prev_data_provider_name := vvc2_in_data_provider_name;
       vn_data_provider_files_proc := 0;
-- Get Number of files defined in the database for this data provider. -----------------
       PKG_ALTERNATE_PARTS_DATAFILE.P_ALTPART_DATAFILE_SEL_02
          (vn_data_provider_skey,
           vn_data_provider_filecount,
           vn_called_row_count,
           vvc2_called_error_msg,
           vn_filecount_return_code);
       IF vn_filecount_return_code <> 0 THEN
         vvc2_sum_process_msg := con_data_provider_error;
         GOTO main_loop;
       END IF;
     END IF;

-- Get datafile skey (and expected record_length) assoc'd with datafile name -----------
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

-- Check if select worked --------------------------------------------------------------

     IF vn_datafile_return_code <> 0 THEN
       vvc2_sum_process_msg := con_datafile_error;
       GOTO main_loop;
     END IF;

     vn_data_provider_files_proc := vn_data_provider_files_proc + 1;

-- Get count of associated suppliers (i.e. Suppliers that will be updated) -------------
  vvc2_code_location := 'GET SUPPLIER COUNT';

     PKG_ALTERNATE_PARTS_DATAFILE.P_ALTP_SUPLR_DATAFILE_SEL_01
        (vn_datafile_skey,
         vn_datafile_suppliers,
         vn_called_row_count,
         vvc2_called_error_msg,
         vn_supplier_return_code);

-- Check if select worked --------------------------------------------------------------

     IF vn_supplier_return_code not in ('000', '100') THEN
       RAISE SUPPLIER_COUNT_ERROR;
     END IF;

     vn_tot_suppliers := vn_tot_suppliers + vn_datafile_suppliers;

-- Get field layout definitions and search values assoc'd with datafile name -----------
  vvc2_code_location := 'GET LAYOUTS';

     PKG_ALTERNATE_PARTS_DATAFILE.P_ALTP_DATAFILE_LAYOUT_SEL_01
        (vn_datafile_skey,
         vn_desc_start_byte_1, vn_desc_start_byte_2, vn_desc_start_byte_3,
         vn_desc_length_1, vn_desc_length_2, vn_desc_length_3,
         vn_desc_row_total,
         vn_altpart_num_start_byte_1, vn_altpart_num_start_byte_2, vn_altpart_num_start_byte_3,
         vn_altpart_num_length_1, vn_altpart_num_length_2, vn_altpart_num_length_3,
         vn_altpart_num_row_total,
         vvc2_altp_price_fixed_value_1, vvc2_altp_price_fixed_value_2, vvc2_altp_price_fixed_value_3,
         vn_altp_price_start_byte_1, vn_altp_price_start_byte_2, vn_altp_price_start_byte_3,
         vn_altp_price_length_1, vn_altp_price_length_2, vn_altp_price_length_3,
         vc_altp_price_decimal_flag_1, vc_altp_price_decimal_flag_2, vc_altp_price_decimal_flag_3,
         vn_altp_price_decimal_scale_1, vn_altp_price_decimal_scale_2, vn_altp_price_decimal_scale_3,
         vn_altp_price_row_total,
         vvc2_capa_fixed_value_1, vvc2_capa_fixed_value_2, vvc2_capa_fixed_value_3,
         vn_capa_start_byte_1, vn_capa_start_byte_2, vn_capa_start_byte_3,
         vn_capa_length_1, vn_capa_length_2, vn_capa_length_3,
         vvc2_capa_search_string_1, vvc2_capa_search_string_2, vvc2_capa_search_string_3,
         vn_capa_row_total,
         vvc2_oem_disc_fixed_value_1, vvc2_oem_disc_fixed_value_2, vvc2_oem_disc_fixed_value_3,
         vn_oem_disc_start_byte_1, vn_oem_disc_start_byte_2, vn_oem_disc_start_byte_3,
         vn_oem_disc_length_1, vn_oem_disc_length_2, vn_oem_disc_length_3,
         vvc2_oem_disc_search_string_1, vvc2_oem_disc_search_string_2, vvc2_oem_disc_search_string_3,
         vn_oem_disc_row_total,
         vn_part_num_start_byte_1, vn_part_num_start_byte_2, vn_part_num_start_byte_3,
         vn_part_num_length_1, vn_part_num_length_2, vn_part_num_length_3,
         vn_part_num_row_total,
         vvc2_part_suplr_fixed_value_1, vvc2_part_suplr_fixed_value_2, vvc2_part_suplr_fixed_value_3,
         vn_part_suplr_start_byte_1, vn_part_suplr_start_byte_2, vn_part_suplr_start_byte_3,
         vn_part_suplr_length_1, vn_part_suplr_length_2, vn_part_suplr_length_3,
         vn_part_suplr_row_total,
         vvc2_recond_fixed_value_1, vvc2_recond_fixed_value_2, vvc2_recond_fixed_value_3,
         vn_recond_start_byte_1, vn_recond_start_byte_2, vn_recond_start_byte_3,
         vn_recond_length_1, vn_recond_length_2, vn_recond_length_3,
         vvc2_recond_search_string_1, vvc2_recond_search_string_2, vvc2_recond_search_string_3,
         vn_recond_row_total,
         vn_bypass_start_byte_1, vn_bypass_start_byte_2, vn_bypass_start_byte_3,
         vn_bypass_length_1, vn_bypass_length_2, vn_bypass_length_3,
         vvc2_bypass_search_string_1, vvc2_bypass_search_string_2, vvc2_bypass_search_string_3,
         vn_bypass_row_total,
         vn_called_row_count,
         vvc2_called_error_msg,
         vn_datafield_return_code);

-- Check if datafile layout found and if all the necessary fields were defined. --------
     IF vn_datafield_return_code <> 0 THEN
       vvc2_sum_process_msg := con_layout_missing_error;
       GOTO main_loop;
     ELSE
       GOTO main_loop;
     END IF;

<<detail_rtn>>
  vvc2_code_location := 'PROCESS DTL';

---------  PROCESS DETAIL RECORD  ------------------------------------------------------
---------   1) bypass processing detail record if header info was invalid
---------   2) initialize detail-related variables
---------   3) check record's length against expected record_length
---------   4) using record layout info,
---------      4a) skip processing header-type records identified by "bypass-rec" info.
---------      4b) parse thru supplier's data to obtain all info needed for
---------          acq_altpart_trans and acq_altpart_trans_parse records.
---------          "raw" data values are placed in acq_altpart_trans (aat) fields.
---------          "reformatted" values are placed in acq_altpart_trans_parse (aatp) fields.
---------   5) write acq_altpart_trans
---------   6) if no part supplier provided, determine assoc'd part supplier(s) by using
---------      compressed part number. (This is done after write of acq_altpart_trans
---------      because it can cause multiple acq_altpart_trans_parse records to be written.)
---------   7) write acq_altpart_trans_parse records.

     vn_datafile_recs_read := vn_datafile_recs_read + 1;

--     vn_time_tot_recs := vn_time_tot_recs + (1 * vn_datafile_suppliers);

     IF vn_provider_return_code <> 0 OR vn_datafile_return_code <> 0 OR vn_datafield_return_code <> 0 THEN
       vn_datafile_recs_error := vn_datafile_recs_error + 1;
       GOTO main_loop;
     END IF;

-- Initialize detail-related variables -------------------------------------------------
  vvc2_code_location := 'INITIALIZE DTL';

     vc_reject_switch                  :='N';
     vn_price_error_code               :=0;
     vn_aate_error_code                :=0;
     vn_aatpe_error_code               :=0;
     vn_trans_return_code              :=0;
     vn_trans_parse_return_code        :=0;
     vn_trans_error_return_code        :=0;
     vn_trans_parse_err_return_code    :=0;
     vn_part_suplr_return_code         :=0;
     vvc2_aat_part_supplier            :=' ';
     vvc2_aat_part_number              :=' ';
     vvc2_aat_altpart_number           :=' ';
     vvc2_aat_altpart_price            :=' ';
     vvc2_aat_altpart_reconditioned    :=' ';
     vvc2_aat_altpart_capa             :=' ';
     vvc2_aat_oem_discount             :=' ';
     vvc2_aat_altpart_description      :=' ';
     vvc2_aatp_part_supplier_number    :=' ';
     vvc2_aatp_staged_part_number      :=' ';
     vvc2_aatp_altpart_number          :=' ';
     vn_aatp_altpart_price             :=0;
     vc_aatp_reconditioned_flag        :=' ';
     vc_aatp_capa_certified_flag       :=' ';
     vc_aatp_oem_discount_flag         :=' ';
     vvc2_aatp_part_supplier_number    :=' ';

-- Validate record length ------------------------------------------------------------
-- This is done before parsing activity because record could be shorter than ---------
-- expected and cause parsing errors. Trans row will contain blank or zero   ---------
-- in all of the columns pertaining to data parsing.                         ---------
-- NOTE: use part description in trans row to note est'd vs act'l reclength. ---------

  vvc2_code_location := 'VALIDATE REC LENGTH';

     vn_calc_record_length := LENGTH(vvc2_in_rec);

     IF vn_record_length <> vn_calc_record_length THEN
       WRONG_LENGTH_REC (vn_data_provider_skey,
                         vn_datafile_skey,
                         vvc2_run_date,
                         vn_datafile_recs_read,
                         vn_datafile_recs_error,
                         vn_tot_recs_error,
                         vn_aate_error_code);
       WRITE_TRANS_ERROR_ROW (vvc2_in_data_provider_name,
                              vvc2_in_file_name,
                              vn_data_provider_skey,
                              vn_datafile_skey,
                              vvc2_run_date,
                              vn_datafile_recs_read,
                              vn_aate_error_code,
                              vc_reject_switch);
       GOTO main_loop;
     END IF;

-- Check if record to be bypassed ----------------------------------------------------
  vvc2_code_location := 'BYPASS HEADER RECS';

     vn_loop_ctr := 1;

     <<bypass_loop>>

          WHILE (vn_loop_ctr <= vn_bypass_row_total) LOOP

            IF vn_loop_ctr = 1 THEN
              IF UPPER(substr(vvc2_in_rec,vn_bypass_start_byte_1,vn_bypass_length_1)) = UPPER(vvc2_bypass_search_string_1) THEN
                vn_datafile_recs_bypass := vn_datafile_recs_bypass + 1;
                vn_tot_recs_bypass :=vn_tot_recs_bypass + 1;
                GOTO main_loop;
              END IF;
            ELSIF vn_loop_ctr = 2 THEN
               IF UPPER(substr(vvc2_in_rec,vn_bypass_start_byte_2,vn_bypass_length_2)) = UPPER(vvc2_bypass_search_string_2) THEN
                 vn_datafile_recs_bypass := vn_datafile_recs_bypass + 1;
                 vn_tot_recs_bypass :=vn_tot_recs_bypass + 1;
                 GOTO main_loop;
               END IF;
            ELSIF UPPER(substr(vvc2_in_rec,vn_bypass_start_byte_3,vn_bypass_length_3)) = UPPER(vvc2_bypass_search_string_3) THEN
                 vn_datafile_recs_bypass := vn_datafile_recs_bypass + 1;
                 vn_tot_recs_bypass :=vn_tot_recs_bypass + 1;
                 GOTO main_loop;
            END IF;

            vn_loop_ctr := vn_loop_ctr + 1;

          END LOOP bypass_loop;

-- Value Altpart Description ---------------------------------------------------------
-- Note: There is no aatp desciption field, only aat.  -------------------------------
  vvc2_code_location := 'VALUE ALTP DESCRIPTION';

     vn_loop_ctr := 1;

   <<part_desc_loop>>

        WHILE (vn_loop_ctr <= vn_desc_row_total) AND (rtrim(vvc2_aat_altpart_description) is NULL) LOOP

          IF vn_loop_ctr = 1 THEN
            IF vn_desc_row_total = 0 THEN
              vvc2_aat_altpart_description := ' ';
              RETURN;
            ELSE
              vvc2_aat_altpart_description := substr(vvc2_in_rec,vn_desc_start_byte_1,vn_desc_length_1);
            END IF;
          ELSIF vn_loop_ctr = 2 THEN
              vvc2_aat_altpart_description := substr(vvc2_in_rec,vn_desc_start_byte_2,vn_desc_length_2);
          ELSE
              vvc2_aat_altpart_description := substr(vvc2_in_rec,vn_desc_start_byte_3,vn_desc_length_3);
          END IF;

          vn_loop_ctr := vn_loop_ctr + 1;

        END LOOP part_desc_loop;


-- Value Reconditioned Flag ----------------------------------------------------------
-- When reformatting,                                  -------------------------------
--  (1) apply fixed value, if provided.                -------------------------------
--  (2) change to Y or N based on string search value  -------------------------------
  vvc2_code_location := 'VALUE RECOND FLAG';

     vn_loop_ctr := 1;

     <<reconditioned_loop>>

          WHILE (vn_loop_ctr <= vn_recond_row_total) AND (vc_aatp_reconditioned_flag = ' ') LOOP

           IF vn_loop_ctr = 1 THEN
              IF vvc2_recond_fixed_value_1 > ' ' THEN
                vvc2_aat_altpart_reconditioned := vvc2_recond_fixed_value_1;
                vc_aatp_reconditioned_flag := vvc2_recond_fixed_value_1;
              ELSE
                vvc2_aat_altpart_reconditioned := substr(vvc2_in_rec,vn_recond_start_byte_1,vn_recond_length_1);
                IF UPPER(vvc2_aat_altpart_reconditioned) = vvc2_recond_search_string_1 THEN
                  vc_aatp_reconditioned_flag := 'Y';
                END IF;
              END IF;
           ELSIF vn_loop_ctr = 2 THEN
              IF vvc2_recond_fixed_value_2 > ' ' THEN
                vvc2_aat_altpart_reconditioned := vvc2_recond_fixed_value_2;
                vc_aatp_reconditioned_flag := vvc2_recond_fixed_value_2;
              ELSE
                vvc2_aat_altpart_reconditioned := substr(vvc2_in_rec,vn_recond_start_byte_2,vn_recond_length_2);
                IF UPPER(vvc2_aat_altpart_reconditioned) = vvc2_recond_search_string_2 THEN
                  vc_aatp_reconditioned_flag := 'Y';
                END IF;
              END IF;
           ELSIF vvc2_recond_fixed_value_3 > ' ' THEN
                vvc2_aat_altpart_reconditioned := vvc2_recond_fixed_value_3;
                vc_aatp_reconditioned_flag := vvc2_recond_fixed_value_3;
              ELSE
                vvc2_aat_altpart_reconditioned := substr(vvc2_in_rec,vn_recond_start_byte_3,vn_recond_length_3);
                IF UPPER(vvc2_aat_altpart_reconditioned) = vvc2_recond_search_string_3 THEN
                  vc_aatp_reconditioned_flag := 'Y';
                END IF;
           END IF;
           vn_loop_ctr := vn_loop_ctr + 1;

          END LOOP reconditioned_loop;

          IF vc_aatp_reconditioned_flag = ' ' THEN
            vc_aatp_reconditioned_flag := 'N';
          END IF;

-- Value Capa Certified Flag ---------------------------------------------------------
-- When reformatting,                                  -------------------------------
--  (1) apply fixed value, if provided.                -------------------------------
--  (2) change to Y or N based on string search value  -------------------------------
  vvc2_code_location := 'VALUE CAPA FLAG';

     vn_loop_ctr := 1;

     <<altpart_capa_loop>>

          WHILE (vn_loop_ctr <= vn_capa_row_total) AND (vc_aatp_capa_certified_flag = ' ') LOOP

           IF vn_loop_ctr = 1 THEN
              IF vvc2_capa_fixed_value_1 > ' ' THEN
                vvc2_aat_altpart_capa := vvc2_capa_fixed_value_1;
                vc_aatp_capa_certified_flag := vvc2_capa_fixed_value_1;
              ELSE
                vvc2_aat_altpart_capa := substr(vvc2_in_rec,vn_capa_start_byte_1,vn_capa_length_1);
                IF UPPER(vvc2_aat_altpart_capa) = vvc2_capa_search_string_1 THEN
                  vc_aatp_capa_certified_flag := 'Y';
                END IF;
              END IF;
           ELSIF vn_loop_ctr = 2 THEN
              IF vvc2_capa_fixed_value_2 > ' ' THEN
                vvc2_aat_altpart_capa := vvc2_capa_fixed_value_2;
                vc_aatp_capa_certified_flag := vvc2_capa_fixed_value_2;
              ELSE
                vvc2_aat_altpart_capa := substr(vvc2_in_rec,vn_capa_start_byte_2,vn_capa_length_2);
                IF UPPER(vvc2_aat_altpart_capa) = vvc2_capa_search_string_2 THEN
                  vc_aatp_capa_certified_flag := 'Y';
                END IF;
              END IF;
           ELSIF vvc2_capa_fixed_value_3 > ' ' THEN
                vvc2_aat_altpart_capa := vvc2_capa_fixed_value_3;
                vc_aatp_capa_certified_flag := vvc2_capa_fixed_value_3;
              ELSE
                vvc2_aat_altpart_capa := substr(vvc2_in_rec,vn_capa_start_byte_3,vn_capa_length_3);
                IF UPPER(vvc2_aat_altpart_capa) = vvc2_capa_search_string_3 THEN
                  vc_aatp_capa_certified_flag := 'Y';
                END IF;
           END IF;

           vn_loop_ctr := vn_loop_ctr + 1;

          END LOOP altpart_capa_loop;

          IF vc_aatp_capa_certified_flag = ' ' THEN
            vc_aatp_capa_certified_flag := 'N';
          END IF;


-- Value Oem Discount Flag -----------------------------------------------------------
-- When reformatting,                                  -------------------------------
--  (1) apply fixed value, if provided.                -------------------------------
--  (2) change to Y or N based on string search value  -------------------------------
  vvc2_code_location := 'VALUE OEM DISC FLAG';

     vn_loop_ctr := 1;

     <<oem_discount_loop>>

          WHILE (vn_loop_ctr <= vn_oem_disc_row_total) AND (vc_aatp_oem_discount_flag = ' ') LOOP

           IF vn_loop_ctr = 1 THEN
              IF vvc2_oem_disc_fixed_value_1 > ' ' THEN
                vvc2_aat_oem_discount := vvc2_oem_disc_fixed_value_1;
                vc_aatp_oem_discount_flag := vvc2_oem_disc_fixed_value_1;
              ELSE
                vvc2_aat_oem_discount := substr(vvc2_in_rec,vn_oem_disc_start_byte_1,vn_oem_disc_length_1);
                IF UPPER(vvc2_aat_oem_discount) = vvc2_oem_disc_search_string_1 THEN
                  vc_aatp_oem_discount_flag := 'Y';
                END IF;
              END IF;
           ELSIF vn_loop_ctr = 2 THEN
              IF vvc2_oem_disc_fixed_value_2 > ' ' THEN
                vvc2_aat_oem_discount := vvc2_oem_disc_fixed_value_2;
                vc_aatp_oem_discount_flag := vvc2_oem_disc_fixed_value_2;
              ELSE
                vvc2_aat_oem_discount := substr(vvc2_in_rec,vn_oem_disc_start_byte_2,vn_oem_disc_length_2);
                IF UPPER(vvc2_aat_oem_discount) = vvc2_oem_disc_search_string_2 THEN
                  vc_aatp_oem_discount_flag := 'Y';
                END IF;
              END IF;
           ELSIF vvc2_oem_disc_fixed_value_3 > ' ' THEN
                vvc2_aat_oem_discount := vvc2_oem_disc_fixed_value_3;
                vc_aatp_oem_discount_flag := vvc2_oem_disc_fixed_value_3;
              ELSE
                vvc2_aat_oem_discount := substr(vvc2_in_rec,vn_oem_disc_start_byte_3,vn_oem_disc_length_3);
                IF UPPER(vvc2_aat_oem_discount) = vvc2_oem_disc_search_string_3 THEN
                  vc_aatp_oem_discount_flag := 'Y';
                END IF;
           END IF;

           vn_loop_ctr := vn_loop_ctr + 1;

          END LOOP oem_discount_loop;

          IF vc_aatp_oem_discount_flag = ' ' THEN
            vc_aatp_oem_discount_flag := 'N';
          END IF;

-- Value Altpart Price ---------------------------------------------------------------
-- When reformatting,                                  -------------------------------
--  (1) apply fixed value, if provided.                -------------------------------
--  (2) call routine to right-justify, remove commas   -------------------------------
--      and decimal-point, and convert to number.      -------------------------------
  vvc2_code_location := 'VALUE ALTPART PRICE';

     vn_loop_ctr := 1;

   <<altpart_price_loop>>

        WHILE (vn_loop_ctr <= vn_altp_price_row_total) AND (vn_aatp_altpart_price = 0) LOOP

          vc_altp_price_decimal_flag        :=' ';
          vn_altp_price_decimal_scale       :=0;
          IF vn_loop_ctr = 1 THEN
            vc_altp_price_decimal_flag   := vc_altp_price_decimal_flag_1;
            vn_altp_price_decimal_scale  := vn_altp_price_decimal_scale_1;
            IF vvc2_altp_price_fixed_value_1 > ' ' THEN
              vvc2_aat_altpart_price := vvc2_altp_price_fixed_value_1;
            ELSE
              vvc2_aat_altpart_price := substr(vvc2_in_rec,vn_altp_price_start_byte_1,vn_altp_price_length_1);
            END IF;
          ELSIF vn_loop_ctr = 2 THEN
            vc_altp_price_decimal_flag   := vc_altp_price_decimal_flag_2;
            vn_altp_price_decimal_scale  := vn_altp_price_decimal_scale_2;
            IF vvc2_altp_price_fixed_value_2 > ' ' THEN
               vvc2_aat_altpart_price := vvc2_altp_price_fixed_value_2;
            ELSE
              vvc2_aat_altpart_price := substr(vvc2_in_rec,vn_altp_price_start_byte_2,vn_altp_price_length_2);
            END IF;
          ELSIF vvc2_altp_price_fixed_value_3 > ' ' THEN
            vc_altp_price_decimal_flag   := vc_altp_price_decimal_flag_3;
            vn_altp_price_decimal_scale  := vn_altp_price_decimal_scale_3;
            IF vvc2_altp_price_fixed_value_3 > ' ' THEN
              vvc2_aat_altpart_price := vvc2_altp_price_fixed_value_3;
            ELSE
              vvc2_aat_altpart_price := substr(vvc2_in_rec,vn_altp_price_start_byte_3,vn_altp_price_length_3);
            END IF;
          END IF;

          FORMAT_PRICE_FIELD (vvc2_aat_altpart_price,
                              vc_altp_price_decimal_flag,
                              vn_altp_price_decimal_scale,
                              vn_aatp_altpart_price,
                              vn_price_error_code);

          vn_loop_ctr := vn_loop_ctr + 1;

        END LOOP altpart_price_loop;


-- Value Altpart Number --------------------------------------------------------------
-- When reformatting,                                  -------------------------------
--  (1) force to uppercase                             -------------------------------
--  (2) change 2 spaces to 1 space within field        -------------------------------
--  (3) left-justify                                   -------------------------------
  vvc2_code_location := 'VALUE ALTPART NUMBER';

     vn_loop_ctr := 1;

   <<altpart_num_loop>>

        WHILE (vn_loop_ctr <= vn_altpart_num_row_total) AND (vvc2_aatp_altpart_number = ' ') LOOP

          IF vn_loop_ctr = 1 THEN
            vvc2_aat_altpart_number := substr(vvc2_in_rec,vn_altpart_num_start_byte_1,vn_altpart_num_length_1);
          ELSIF vn_loop_ctr = 2 THEN
            vvc2_aat_altpart_number := substr(vvc2_in_rec,vn_altpart_num_start_byte_2,vn_altpart_num_length_2);
          ELSE
            vvc2_aat_altpart_number := substr(vvc2_in_rec,vn_altpart_num_start_byte_3,vn_altpart_num_length_3);
          END IF;

          vn_loop_ctr := vn_loop_ctr + 1;

          vvc2_aatp_altpart_number := RTRIM(LTRIM(REPLACE(UPPER(vvc2_aat_altpart_number),'  ',' ')));

        END LOOP altpart_num_loop;


-- Value Part Number -----------------------------------------------------------------
-- When reformatting,                                  -------------------------------
--  (1) force to uppercase                             -------------------------------
--  (2) left-justify                                   -------------------------------
  vvc2_code_location := 'VALUE PART NUMBER';

     vn_loop_ctr := 1;

   <<part_num_loop>>

        WHILE (vn_loop_ctr <= vn_part_num_row_total) AND (vvc2_aatp_staged_part_number = ' ') LOOP

          IF vn_loop_ctr = 1 THEN
            vvc2_aat_part_number := substr(vvc2_in_rec,vn_part_num_start_byte_1,vn_part_num_length_1);
          ELSIF vn_loop_ctr = 2 THEN
            vvc2_aat_part_number := substr(vvc2_in_rec,vn_part_num_start_byte_2,vn_part_num_length_2);
          ELSE
            vvc2_aat_part_number := substr(vvc2_in_rec,vn_part_num_start_byte_3,vn_part_num_length_3);
          END IF;

          vn_loop_ctr := vn_loop_ctr + 1;

          vvc2_aatp_staged_part_number := RTRIM(LTRIM(UPPER(vvc2_aat_part_number)));

        END LOOP part_num_loop;


-- Value Part Supplier ---------------------------------------------------------------
-- When reformatting,                                  -------------------------------
--  (1) force to uppercase                             -------------------------------
--  (2) change 2 spaces to 1 space within field        -------------------------------
--  (3) left-justify                                   -------------------------------
--  Note - this is further examined after write of     -------------------------------
--         ACQ_ALTPART_TRANS file.                     -------------------------------

  vvc2_code_location := 'VALUE PART SUPPLIER';

     vn_loop_ctr := 1;

     <<part_suplr_loop>>

          WHILE (vn_loop_ctr <= vn_part_suplr_row_total) AND (rtrim(vvc2_aat_part_supplier) is NULL) LOOP

           IF vn_loop_ctr = 1 THEN
              IF vvc2_part_suplr_fixed_value_1 > ' ' THEN
                vvc2_aat_part_supplier := vvc2_part_suplr_fixed_value_1;
              ELSE
                vvc2_aat_part_supplier := substr(vvc2_in_rec,vn_part_suplr_start_byte_1,vn_part_suplr_length_1);
              END IF;
           ELSIF vn_loop_ctr = 2 THEN
              IF vvc2_part_suplr_fixed_value_2 > ' ' THEN
                vvc2_aat_part_supplier := vvc2_part_suplr_fixed_value_2;
              ELSE
                vvc2_aat_part_supplier := substr(vvc2_in_rec,vn_part_suplr_start_byte_2,vn_part_suplr_length_2);
              END IF;
           ELSIF vvc2_part_suplr_fixed_value_3 > ' ' THEN
                vvc2_aat_part_supplier := vvc2_part_suplr_fixed_value_3;
              ELSE
              vvc2_aat_part_supplier := substr(vvc2_in_rec,vn_part_suplr_start_byte_3,vn_part_suplr_length_3);
           END IF;

            vn_loop_ctr := vn_loop_ctr + 1;

          END LOOP part_suplr_loop;


--  Write ACQ_ALTPART_TRANS
  vvc2_code_location := 'WRITE TRANS ROW';

     PKG_ALTERNATE_PARTS_DATAFILE.P_ACQ_ALTP_TRANS_INS_01
        (vn_data_provider_skey,
         vn_datafile_skey,
         vvc2_run_date,
         vn_datafile_recs_read,
         vvc2_aat_part_supplier,
         vvc2_aat_part_number,
         vvc2_aat_altpart_number,
         vvc2_aat_altpart_price,
         vvc2_aat_altpart_reconditioned,
         vvc2_aat_altpart_capa,
         vvc2_aat_oem_discount,
         vvc2_aat_altpart_description,
         vn_called_row_count,
         vvc2_called_error_msg,
         vn_trans_return_code);

-- Check if insert worked --------------------------------------------------------------

     IF vn_trans_return_code <> 0 THEN
       RAISE BAD_INS_ALTP_TRANS;
     END IF;

--------- Error checking           ---------------------------------------------------------------
-- Check if any errors have been detected thus far.
-- If so, write error record(s) and bypass further processing.
  vvc2_code_location := 'CHECK ERRORS';

     IF vn_price_error_code <> 0 THEN
       vn_aate_error_code := vn_price_error_code;
       WRITE_TRANS_ERROR_ROW (vvc2_in_data_provider_name,
                              vvc2_in_file_name,
                              vn_data_provider_skey,
                              vn_datafile_skey,
                              vvc2_run_date,
                              vn_datafile_recs_read,
                              vn_aate_error_code,
                              vc_reject_switch);
     END IF;

     IF vvc2_aatp_staged_part_number in (' ', 'N.A.', 'NA', 'N/A', 'N A', 'N.A')
        OR vvc2_aatp_staged_part_number is NULL THEN
       vn_aate_error_code := con_invalid_part_number;
       WRITE_TRANS_ERROR_ROW (vvc2_in_data_provider_name,
                              vvc2_in_file_name,
                              vn_data_provider_skey,
                              vn_datafile_skey,
                              vvc2_run_date,
                              vn_datafile_recs_read,
                              vn_aate_error_code,
                              vc_reject_switch);
     END IF;

-- Bypass scenarios such as 'N/A-OSW' (found in Keystone file)
-- or other ways data providers designate "Not Available" or "Non Applicable"
    IF substr(vvc2_aatp_altpart_number,1,3) = 'N/A' THEN
       vn_aate_error_code := con_invalid_altpart_num;
       WRITE_TRANS_ERROR_ROW (vvc2_in_data_provider_name,
                              vvc2_in_file_name,
                              vn_data_provider_skey,
                              vn_datafile_skey,
                              vvc2_run_date,
                              vn_datafile_recs_read,
                              vn_aate_error_code,
                              vc_reject_switch);
     ELSIF vvc2_aatp_altpart_number in (' ', 'N.A.', 'NA', 'N/A', 'N A', 'N.A')
        OR vvc2_aatp_altpart_number is NULL THEN
       vn_aate_error_code := con_invalid_altpart_num;
       WRITE_TRANS_ERROR_ROW (vvc2_in_data_provider_name,
                              vvc2_in_file_name,
                              vn_data_provider_skey,
                              vn_datafile_skey,
                              vvc2_run_date,
                              vn_datafile_recs_read,
                              vn_aate_error_code,
                              vc_reject_switch);

     END IF;

     IF vc_reject_switch = 'Y' THEN
      GOTO processing_tally;
     END IF;

--------- Call routine to lookup Mitchell Part Supplier Number -----------------------------------
--  Make sure part supplier is valued and valid.                                   -----
--  If valued, call routine to find Mitchell equivalent to Data Provider's value   -----
--  (Routine looks for "generic" as well as Data Provider specific value.)         -----
--                                                                                 -----
--  If not valued, compress part number, perform part lookup to determine part     -----
--  supplier(s), and write 1-to-many ACQ_ALTPART_TRANS_PARSE row(s).               -----
--  (NOTE: Could be many, if compressed part assoc'd to more than one supplier     -----
--         e.g. Acura and Honda, Toyota and Lexus, Chrysler and Mitsubishi)        -----

   vvc2_code_location := 'PART SUPPLIER LOOKUP';

     IF RTRIM(vvc2_aat_part_supplier) is NULL THEN
       GOTO supplier_lookup_by_part;
     END IF;

     vvc2_called_error_msg  :=' ';
     PKG_ALTERNATE_PARTS_DATAFILE.P_ACQ_PART_SUPLR_LOOKUP_SEL_01
        (vn_data_provider_skey,
         vvc2_aat_part_supplier,
         vvc2_aatp_part_supplier_number,
         vn_called_row_count,
         vvc2_called_error_msg,
         vn_part_suplr_return_code);

-- Check if select worked and if so, write ACQ_ALTPART_TRANS_PARSE row.
-- If part_supplier not found, drop into logic that determines part supplier
-- by compressed part number.

     IF vn_part_suplr_return_code = 0 THEN
       PKG_ALTERNATE_PARTS_DATAFILE.P_ACQ_ALTP_TRANS_PARSE_INS_01
          (vn_data_provider_skey,
           vn_datafile_skey,
           vvc2_run_date,
           vn_datafile_recs_read,
           vvc2_aatp_part_supplier_number,
           vvc2_aatp_staged_part_number,
           vvc2_aatp_part_number,
           vvc2_aatp_altpart_number,
           vn_aatp_altpart_price,
           vc_aatp_reconditioned_flag,
           vc_aatp_capa_certified_flag,
           vc_aatp_oem_discount_flag,
           vn_called_row_count,
           vvc2_called_error_msg,
           vn_trans_parse_return_code);
       IF vn_trans_parse_return_code <> 0 THEN
         RAISE BAD_INS_ALTP_TRANS_PARSE;
       ELSE
       vn_datafile_parse_written := vn_datafile_parse_written + 1;
       vn_tot_parse_written := vn_tot_parse_written + 1;
       GOTO processing_tally;
       END IF;
     END IF;


-------- Compress part and check in parts table for assoc'd Part Supplier(s) -------------------
-------- If found, write ACQ_ALTP_TRANS_PARSE row for each one.              -------------------
   <<supplier_lookup_by_part>>
   vvc2_code_location := 'COMPRESSED PART LOOKUP';

     SP_COMP_PART (vvc2_aatp_staged_part_number, vvc2_compressed_part_number);

     vn_part_loop_ctr := 0;
     FOR partrec in part_supplier_cur(vvc2_compressed_part_number, vvc2_datafile_country_abbr)
       LOOP
         vvc2_aatp_part_supplier_number := partrec.part_supplier_number;
         PKG_ALTERNATE_PARTS_DATAFILE.P_ACQ_ALTP_TRANS_PARSE_INS_01
            (vn_data_provider_skey,
             vn_datafile_skey,
             vvc2_run_date,
             vn_datafile_recs_read,
             vvc2_aatp_part_supplier_number,
             vvc2_aatp_staged_part_number,
             vvc2_aatp_part_number,
             vvc2_aatp_altpart_number,
             vn_aatp_altpart_price,
             vc_aatp_reconditioned_flag,
             vc_aatp_capa_certified_flag,
             vc_aatp_oem_discount_flag,
             vn_called_row_count,
             vvc2_called_error_msg,
             vn_trans_parse_return_code);
         IF vn_trans_parse_return_code <> 0 THEN
           RAISE BAD_INS_ALTP_TRANS_PARSE;
         ELSE
           vn_datafile_parse_written := vn_datafile_parse_written + 1;
           vn_tot_parse_written := vn_tot_parse_written + 1;
           vn_part_loop_ctr := vn_part_loop_ctr + 1;
           vn_aatpe_error_code := con_part_supplier_derived;
           WRITE_TRANS_PARSE_ERROR_ROW (vn_data_provider_skey,
                                   vn_datafile_skey,
                                   vvc2_run_date,
                                   vn_datafile_recs_read,
                                   vvc2_aatp_part_supplier_number,
                                   vn_aatpe_error_code);
         END IF;
     END LOOP;

-------- Check compressed part in super table for assoc'd Part Supplier(s)   -------------------
-------- If found, write ACQ_ALTP_TRANS_PARSE row for each one.              -------------------
   <<supplier_lookup_by_super>>
   vvc2_code_location := 'COMPRESSED SUPER LOOKUP';

     vn_super_loop_ctr := 0;
     FOR suprec in super_supplier_cur(vvc2_compressed_part_number, vvc2_datafile_country_abbr)
       LOOP
         vvc2_aatp_part_supplier_number := suprec.part_supplier_number;
         PKG_ALTERNATE_PARTS_DATAFILE.P_ACQ_ALTP_TRANS_PARSE_INS_01
            (vn_data_provider_skey,
             vn_datafile_skey,
             vvc2_run_date,
             vn_datafile_recs_read,
             vvc2_aatp_part_supplier_number,
             vvc2_aatp_staged_part_number,
             vvc2_aatp_part_number,
             vvc2_aatp_altpart_number,
             vn_aatp_altpart_price,
             vc_aatp_reconditioned_flag,
             vc_aatp_capa_certified_flag,
             vc_aatp_oem_discount_flag,
             vn_called_row_count,
             vvc2_called_error_msg,
            vn_trans_parse_return_code);
         IF vvc2_called_error_msg <> 'ORA-00001: unique constraint (RACE.ACQ_ALTPART_TRANS_PARSE_PK) violated' THEN
           IF vn_trans_parse_return_code <> 0 THEN
             RAISE BAD_INS_ALTP_TRANS_PARSE;
           ELSE
             vn_datafile_parse_written := vn_datafile_parse_written + 1;
             vn_tot_parse_written := vn_tot_parse_written + 1;
             vn_super_loop_ctr := vn_super_loop_ctr + 1;
             vn_aatpe_error_code := con_part_supplier_derived;
             WRITE_TRANS_PARSE_ERROR_ROW (vn_data_provider_skey,
                                          vn_datafile_skey,
                                          vvc2_run_date,
                                          vn_datafile_recs_read,
                                          vvc2_aatp_part_supplier_number,
                                          vn_aatpe_error_code);
           END IF;
         END IF;
     END LOOP;

-------- If part_supplier not found from compressed part routines then     -------------------
-------- write trans error row.                                            -------------------
     IF vn_part_loop_ctr = 0 and vn_super_loop_ctr = 0 THEN
       vn_aate_error_code := con_invalid_mfr_convert;
       WRITE_TRANS_ERROR_ROW (vvc2_in_data_provider_name,
                              vvc2_in_file_name,
                              vn_data_provider_skey,
                              vn_datafile_skey,
                              vvc2_run_date,
                              vn_datafile_recs_read,
                              vn_aate_error_code,
                              vc_reject_switch);
     END IF;

-- Check if any error(s) encountered for this data record. If so, add to counter.
-- Also, perform price variance check.
<<processing_tally>>
  vvc2_code_location := 'PROCESSING TALLY';

     IF vc_reject_switch = 'Y' THEN
       vn_datafile_recs_error := vn_datafile_recs_error + 1;
       vn_tot_recs_error :=vn_tot_recs_error + 1;
     ELSE
       IF vn_price_checked_ctr < 20 THEN
         IF vvc2_aatp_altpart_number <> vvc2_prev_altpart_number THEN
           CHECK_PRICE_VARIANCE (vn_data_provider_skey,
                                 vn_datafile_skey,
                                 vvc2_run_date,
                                 vvc2_aatp_part_supplier_number,
                                 vvc2_aatp_staged_part_number,
                                 vvc2_aatp_altpart_number, 
                                 vn_aatp_altpart_price, 
                                 vn_variance_exceeded_ctr,  
                                 vn_price_checked_ctr);
            vvc2_prev_altpart_number := vvc2_aatp_altpart_number;
         END IF;
       END IF;
       vn_datafile_trans_written := vn_datafile_trans_written + 1;
       vn_tot_trans_written := vn_tot_trans_written + 1;
     END IF;

 END LOOP main_loop;

-------- FINAL PROCESSING -------------------------------------------------------------

 vvc2_code_location := 'FINAL PROCESSING';
-- Write summary record with figures for last datafile
 WRITE_SUMMARY_REC  (vvc2_in_data_provider_name,
                     vvc2_in_file_name,
                     vn_data_provider_skey,
                     vn_datafile_skey,
                     vvc2_run_date,
                     vn_datafile_recs_read,
                     vn_datafile_trans_written,
                     vn_datafile_parse_written,
                     vn_datafile_recs_error,
                     vn_datafile_recs_bypass,
                     vn_datafile_suppliers,
                     vvc2_header_save,
                     vn_time_tot_recs,
                     vvc2_sum_process_msg,
                     vn_sum_line_ctr,
                     vn_variance_exceeded_ctr,  
                     vn_price_checked_ctr);

-- Check last processed provider's file counts
 IF vn_data_provider_files_proc <> vn_data_provider_filecount THEN
   vvc2_sum_line := con_filecount_warning;
   UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_sum_line);
 END IF;

-- Write summary record containing totals.
 UTL_FILE.PUT_LINE(v_sum_fHandle,con_header4);

 vvc2_sum_line := RPAD(con_blank,30,' ')
       || '  ' || RPAD(con_blank,20,' ')
       || '  ' || LPAD(vn_tot_recs_read,8,' ')
       || '* ' || LPAD(vn_tot_trans_written,8,' ')
       || '  ' || LPAD(vn_tot_parse_written,8,' ')
       || '  ' || LPAD(vn_tot_recs_error,8,' ')
       || '  ' || LPAD(vn_tot_recs_bypass,8,' ')
       || '  ' || LPAD(vn_tot_suppliers,5,' ')
       || '  ' || RPAD(con_blank,30,' ');
 UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_sum_line);


-- Write footnotes
 vvc2_sum_line := RPAD(con_blank,145,' ');
 UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_sum_line);
 UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_sum_line);
 UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_sum_line);

 vvc2_sum_line := con_footnote0;
 UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_sum_line);

 vvc2_sum_line := con_footnote1;
 UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_sum_line);

 vvc2_sum_line := con_footnote2;
 UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_sum_line);

 vvc2_sum_line := con_footnote3;
 UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_sum_line);

-- Write estimated update time line
 vn_calc_elapsed_minutes := ROUND(((vn_time_tot_recs/con_factor)/con_sec_per_minute));

 vvc2_sum_line := RPAD(con_blank,145,' ');
 UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_sum_line);
 UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_sum_line);

 vvc2_sum_line := con_footnote4 || LPAD(vn_calc_elapsed_minutes,10,' ') || ' MINUTES';
 UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_sum_line);


----------------- CLOSE INPUT / OUTPUT FILES --------------------------------------------

  UTL_FILE.FCLOSE(v_in_fHandle);
  UTL_FILE.FCLOSE(v_sum_fHandle);
  UTL_FILE.FCLOSE(v_prm_fHandle);
  UTL_FILE.FCLOSE(v_err_fHandle);

EXCEPTION

  WHEN UTL_FILE.INVALID_PATH THEN
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('Oracle error code and message: ' || SQLCODE || ' - ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    UTL_FILE.FCLOSE(v_err_fHandle);
    RAISE_APPLICATION_ERROR(-20100,'Invalid Path');

  WHEN UTL_FILE.INVALID_MODE THEN
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('Oracle error code and message: ' || SQLCODE || ' - ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    UTL_FILE.FCLOSE(v_err_fHandle);
    RAISE_APPLICATION_ERROR(-20101,'Invalid Mode');

  WHEN UTL_FILE.INVALID_FILEHANDLE then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('Oracle error code and message: ' || SQLCODE || ' - ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    UTL_FILE.FCLOSE(v_err_fHandle);
    RAISE_APPLICATION_ERROR(-20102,'Invalid Filehandle');

   WHEN UTL_FILE.INVALID_OPERATION then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('Oracle error code and message: ' || SQLCODE || ' - ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    UTL_FILE.FCLOSE(v_err_fHandle);
    RAISE_APPLICATION_ERROR(-20103,'Invalid Filehandle operation');

  WHEN UTL_FILE.READ_ERROR then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('Oracle error code and message: ' || SQLCODE || ' - ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    UTL_FILE.FCLOSE(v_err_fHandle);
    RAISE_APPLICATION_ERROR(-20104,'Read Error');

  WHEN UTL_FILE.WRITE_ERROR then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('Oracle error code and message: ' || SQLCODE || ' - ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    UTL_FILE.FCLOSE(v_err_fHandle);
    RAISE_APPLICATION_ERROR(-20105,'Write Error');

  WHEN UTL_FILE.INTERNAL_ERROR then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('Oracle error code and message: ' || SQLCODE || ' - ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    UTL_FILE.FCLOSE(v_err_fHandle);
    RAISE_APPLICATION_ERROR(-20106,'Internal Error');

  WHEN BAD_HEADER_ERROR then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Error detected in header record');
    DBMS_OUTPUT.PUT_LINE('Record: ' || vvc2_in_rec);
    DBMS_OUTPUT.PUT_LINE('Record Count: ' || vn_tot_recs_read);
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('Oracle error code and message: ' || SQLCODE || ' - ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    UTL_FILE.FCLOSE(v_err_fHandle);
    RAISE_APPLICATION_ERROR(-20900,'Error in Header Record');

  WHEN BAD_DEL_TRANS then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Error deleting transaction rows');
    DBMS_OUTPUT.PUT_LINE('Returned from procedure: ' || vvc2_called_error_msg || '  ' || vn_trans_del_return_code);
    DBMS_OUTPUT.PUT_LINE('Provider Skey: ' || vn_data_provider_skey);
    DBMS_OUTPUT.PUT_LINE('Datafile Skey: ' || vn_datafile_skey);
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('Oracle error code and message: ' || SQLCODE || ' - ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    UTL_FILE.FCLOSE(v_err_fHandle);
    RAISE_APPLICATION_ERROR(-20900,'Error Deleting Transaction Rows');

  WHEN BAD_INS_ALTP_TRANS then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Error Writing ACQ_ALTPART_TRANS Row ' || vn_tot_recs_read);
    DBMS_OUTPUT.PUT_LINE('Returned from procedure: ' || vvc2_called_error_msg || '  ' || vn_trans_return_code);
    DBMS_OUTPUT.PUT_LINE('Provider Skey: ' || vn_data_provider_skey);
    DBMS_OUTPUT.PUT_LINE('Datafile Skey: ' || vn_datafile_skey);
    DBMS_OUTPUT.PUT_LINE('Datafile Record: ' || vn_datafile_recs_read);
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('Oracle error code and message: ' || SQLCODE || ' - ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    UTL_FILE.FCLOSE(v_err_fHandle);
    RAISE_APPLICATION_ERROR(-20900,'Error Writing ACQ_ALTPART_TRANS Row');

  WHEN BAD_INS_ALTP_TRANS_ERROR then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Error Writing ACQ_ALTPART_TRANS_ERROR Row ' || vn_tot_recs_read);
    DBMS_OUTPUT.PUT_LINE('Returned from procedure: ' || vvc2_called_error_msg || '  ' || vn_trans_return_code);
    DBMS_OUTPUT.PUT_LINE('Provider Skey: ' || vn_data_provider_skey);
    DBMS_OUTPUT.PUT_LINE('Datafile Skey: ' || vn_datafile_skey);
    DBMS_OUTPUT.PUT_LINE('Datafile Record: ' || vn_datafile_recs_read);
    DBMS_OUTPUT.PUT_LINE('Error Code: ' || vn_aate_error_code);
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('Oracle error code and message: ' || SQLCODE || ' - ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    UTL_FILE.FCLOSE(v_err_fHandle);
    RAISE_APPLICATION_ERROR(-20900,'Error Writing ACQ_ALTPART_TRANS_ERROR Row');

  WHEN BAD_INS_ALTP_TRANS_PARSE then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Error Writing ACQ_ALTPART_TRANS_PARSE Row ' || vn_tot_recs_read);
    DBMS_OUTPUT.PUT_LINE('Returned from procedure: ' || vvc2_called_error_msg || '  ' || vn_trans_parse_return_code);
    DBMS_OUTPUT.PUT_LINE('Provider Skey: ' || vn_data_provider_skey);
    DBMS_OUTPUT.PUT_LINE('Datafile Skey: ' || vn_datafile_skey);
    DBMS_OUTPUT.PUT_LINE('Datafile Record: ' || vn_datafile_recs_read);
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('Oracle error code and message: ' || SQLCODE || ' - ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    UTL_FILE.FCLOSE(v_err_fHandle);
    RAISE_APPLICATION_ERROR(-20900,'Error Writing ACQ_ALTPART_TRANS_PARSE Row');

  WHEN BAD_INS_ALTP_TRANS_PARSE_ERROR then
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    UTL_FILE.FCLOSE(v_err_fHandle);
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Error Writing ACQ_ALTPART_TRANS_PARSE_ERROR Row ' || vn_tot_recs_read);
    DBMS_OUTPUT.PUT_LINE('Returned from procedure: ' || vvc2_called_error_msg || '  ' || vn_trans_parse_return_code);
    DBMS_OUTPUT.PUT_LINE('Provider Skey: ' || vn_data_provider_skey);
    DBMS_OUTPUT.PUT_LINE('Datafile Skey: ' || vn_datafile_skey);
    DBMS_OUTPUT.PUT_LINE('Datafile Record: ' || vn_datafile_recs_read);
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('Oracle error code and message: ' || SQLCODE || ' - ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    RAISE_APPLICATION_ERROR(-20900,'Error Writing ACQ_ALTPART_TRANS_PARSE_ERROR Row');

  WHEN INVALID_ERROR_CODE then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Error code not found in ACQ_ERROR ');
    DBMS_OUTPUT.PUT_LINE('Provider Skey: ' || vn_data_provider_skey);
    DBMS_OUTPUT.PUT_LINE('Datafile Skey: ' || vn_datafile_skey);
    DBMS_OUTPUT.PUT_LINE('Error Code   : ' || vn_aate_error_code);
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('Oracle error code and message: ' || SQLCODE || ' - ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    UTL_FILE.FCLOSE(v_err_fHandle);
    RAISE_APPLICATION_ERROR(-20900,'Error Writing ACQ_ALTPART_TRANS_PARSE_ERROR Row');

  WHEN SUPPLIER_COUNT_ERROR then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Error attempting to get count from ALTPART_SUPPLIER_DATAFILE table ' || vn_tot_recs_read);
    DBMS_OUTPUT.PUT_LINE('Returned from procedure: ' || vvc2_called_error_msg || '  ' || vn_supplier_return_code);
    DBMS_OUTPUT.PUT_LINE('Provider Skey: ' || vn_data_provider_skey);
    DBMS_OUTPUT.PUT_LINE('Datafile Skey: ' || vn_datafile_skey);
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('Oracle error code and message: ' || SQLCODE || ' - ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    UTL_FILE.FCLOSE(v_err_fHandle);
    RAISE_APPLICATION_ERROR(-20900,'Error Writing ACQ_ALTPART_TRANS_PARSE_ERROR Row');

  WHEN OTHERS then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Unhandled Error at rec:' || vn_tot_recs_read);
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('Oracle error code and message: ' || SQLCODE || ' - ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('---');
    DBMS_OUTPUT.PUT_LINE('in rec: ' || vvc2_in_rec);
    DBMS_OUTPUT.PUT_LINE('vn_sum_page_ctr : ' || vn_sum_page_ctr );
    DBMS_OUTPUT.PUT_LINE('vn_sum_line_ctr : ' || vn_sum_line_ctr );
    DBMS_OUTPUT.PUT_LINE('vn_datafile_recs_read : ' || vn_datafile_recs_read);
    DBMS_OUTPUT.PUT_LINE('vn_datafile_trans_written : ' || vn_datafile_trans_written );
    DBMS_OUTPUT.PUT_LINE('vn_datafile_parse_written : ' || vn_datafile_parse_written);
    DBMS_OUTPUT.PUT_LINE('vn_datafile_recs_error : ' || vn_datafile_recs_error);
    DBMS_OUTPUT.PUT_LINE('vn_datafile_recs_bypass : ' || vn_datafile_recs_bypass);
    DBMS_OUTPUT.PUT_LINE('vn_datafile_suppliers : ' || vn_datafile_suppliers);
    DBMS_OUTPUT.PUT_LINE('vn_tot_recs_read : ' || vn_tot_recs_read);
    DBMS_OUTPUT.PUT_LINE('vn_tot_trans_written : ' || vn_tot_trans_written);
    DBMS_OUTPUT.PUT_LINE('vn_tot_parse_written : ' || vn_tot_parse_written );
    DBMS_OUTPUT.PUT_LINE('vn_tot_recs_error : ' || vn_tot_recs_error );
    DBMS_OUTPUT.PUT_LINE('vn_tot_recs_bypass : ' || vn_tot_recs_bypass );
    DBMS_OUTPUT.PUT_LINE('vn_tot_suppliers : ' || vn_tot_suppliers );
    DBMS_OUTPUT.PUT_LINE('vn_price_checked_ctr : ' || vn_price_checked_ctr);
    DBMS_OUTPUT.PUT_LINE('vn_variance_exceeded_ctr : ' || vn_variance_exceeded_ctr );
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    UTL_FILE.FCLOSE(v_prm_fHandle);
    UTL_FILE.FCLOSE(v_err_fHandle);
    RAISE_APPLICATION_ERROR(-20999,'Unhandled Error Encountered');

END;

-- leave "/" it is required for pl/sql end block ----------------------------------------------------
/

quit;
--- leave "end_sql_block" it is required for sql end block -----
%
#END OF Script
