#!/bin/ksh
 set -vx
############################################################################
# PROGRAM:     xam_update_sql.ksh
# AUTHOR:      Penny Genovese
# DESCRIPTION: Update all suppliers associated to a specific Data Provider.
# OVERVIEW: 1) Loop 1 - Read parm file indicating Data Provider(s) to be
#              processed.
#           2) Loop 2 - Fetch supplier(s) associated to the Data Provider
#           3) Loop 3 - Fetch existing part_altpart_xref rows associated to
#              supplier and fetch transactions associated to datafile(s)
#              associated to supplier.
#              Perform file match as follows:
#              DB = Trans: Update price, flag, and last update info.
#              DB < Trans: Insert new DB row
#              DB > Trans: Delete DB row.
#              Note - only transactions having no reject errors are proc'd.
#           4) At end of processing each Data Provider:
#              - write summary report record
############################################################################
# MODIFICATIONS:
#   2009_11_09 - GNW - Increased vn_supplier_read counter to number(4)
#   ------------------------------------------------------------------------
#   2006/03/30 - PAG - Corrected calc of part_count to include bypass nochg.
#   ------------------------------------------------------------------------
#   2006/03/20 - PAG - Changed so that update only occurs if price and/or
#                      flags are different than what's in the database.
#   ------------------------------------------------------------------------
#   2005/10/08 - PAG - Added commit to database after completion of each
#                      supplier. Also added use of rbs_large01 rollback seg.
#   ------------------------------------------------------------------------
#   2005/04/29 - PAG - Changed processing msg for con_no_trans_data_error
#                      from: 'NO DATAFILE ASSOC TO SUPPLIER'
#                      to:   'NO VALID TRANS FOUND FOR SUPLR' 
############################################################################
##start sqlplus
sqlplus << % 2>&1 > $LOG
$XAMUSERID
set serveroutput on;
set feedback on;
set termout on;
set trimspool on;
set arraysize 200;
set transaction use rollback segment rbs_large01;
whenever sqlerror exit sql.sqlcode

define v_JOBNAME  = $ORA_JOBNAME  char(60);
define v_IN_DIR   = $ORA_IN_DIR   char(60);
define v_IN_FILE  = $ORA_IN_FILE  char(60);
define v_SUM_DIR  = $ORA_SUM_DIR  char(60);
define v_SUM_FILE = $ORA_SUM_FILE char(60);

DECLARE

---------  I/O FILE VARIABLES  ------------------------------------------
BAD_INS_PART_ALTPART_XREF         exception;
BAD_UPD_PART_ALTPART_XREF         exception;
BAD_DEL_PART_ALTPART_XREF         exception;
BAD_UPD_ALTPART_SUPPLIER          exception;

v_in_fHandle                      UTL_FILE.FILE_TYPE;
v_sum_fHandle                     UTL_FILE.FILE_TYPE;

vvc2_jobname                      varchar2(8);
vvc2_in_dirname                   varchar2(60);
vvc2_in_filename                  varchar2(60);
vvc2_in_rec                       varchar2(100);

vvc2_sum_dirname                  varchar2(60);
vvc2_sum_filename                 varchar2(60);

---------  HEADER-RELATED VARIABLES  ------------------------------------

vvc2_in_data_provider_name        varchar2(80);
vc_in_process_flag                char(1);

vn_data_provider_skey             number;

---------  DATA-RELATED VARIABLES  ------------------------------------

vvc2_altp_supplier_country        varchar2(2);
vvc2_altpart_supplier_number      varchar2(4);
vvc2_altpart_supplier_name        varchar2(30);

vn_aatp_datafile_skey             number;
vd_aatp_run_date                  date;
vn_aatp_row_sequence_number       number;
vvc2_aatp_part_supplier_number    varchar2(03);
vvc2_aatp_part_number             varchar2(25);
vvc2_aatp_altpart_number          varchar2(25);
vn_aatp_altpart_price             number(15,4);
vc_aatp_altpart_recond_flag       char(1);
vc_aatp_capa_certified_flag       char(1);
vc_aatp_oem_discount_flag         char(1);
vc_valid_aatp_found_sw            char(1);

vvc2_pax_part_supplier_number     varchar2(03);
vvc2_pax_part_number              varchar2(25);
vvc2_pax_altpart_number           varchar2(25);
vc_pax_altpart_recond_flag        char(1);
vn_pax_altpart_price              number(15,4);
vc_pax_capa_certified_flag        char(1);
vc_pax_oem_discount_flag          char(1);
vn_pax_part_skey                  number;
vc_valid_pax_found_sw             char(1);

vvc2_aatp_key_values              varchar2(54);
vvc2_pax_key_values               varchar2(54);
vvc2_prev_key_values              varchar2(54);

vn_called_row_count               number(6);
vvc2_called_error_msg             varchar2(1000);

vn_provider_return_code           number(6);
vn_supplier_return_code           number(6);
vn_xref_return_code               number(6);



---------  REPORT VARIABLES  --------------------------------------------

vvc2_processing_error_msg         varchar2(30);
vvc2_header1                      varchar2(140);
vvc2_header2s                     varchar2(140);
vvc2_header3s                     varchar2(140);
vvc2_header4s                     varchar2(140);
vvc2_sum_line                     varchar2(140);
vvc2_footnote1                    varchar2(140);
vvc2_footnote2                    varchar2(140); 
vvc2_footnote3                    varchar2(140); 
vvc2_footnote4                    varchar2(140); 
vvc2_footnote5                    varchar2(140); 
vvc2_footnote6                    varchar2(140); 
vd_date                           date;
vvc2_run_date                     varchar2(19);
vn_newpage                        number(2) :=58;
vn_sum_page_ctr                   number(3) :=0;
vn_sum_line_ctr                   number(2) :=0;
vn_supplier_read                  number(4) :=0;
vn_supplier_trans_read            number(8) :=0;
vn_supplier_part_ins              number(8) :=0;
vn_supplier_part_upd              number(8) :=0;
vn_supplier_part_del              number(8) :=0;
vn_supplier_part_byp_nochg        number(8) :=0;
vn_supplier_part_byp_dup          number(8) :=0;
vn_tot_part_ins                   number(9):=0;
vn_tot_part_upd                   number(9):=0;
vn_tot_part_del                   number(9):=0;
vn_tot_part_byp_nochg             number(9):=0;
vn_tot_part_byp_dup               number(9):=0;
vn_parm_recs_read                 number(10):=0;

vvc2_code_location                varchar2(50);

---------  CONSTANTS ----------------------------------------------------

con_data_provider_error           varchar2(30):='PROVIDER NAME NOT IN DATABASE';
con_data_provider_error2          varchar2(30):='DUPLICATE PROVIDER IN PARM';
con_supplier_error                varchar2(30):='NO SUPPLIER ASSOC TO PROVIDER';
con_no_trans_data_error           varchar2(30):='NO VALID TRANS FOUND FOR SUPLR';

con_part_insert_error             number(02):=22;
con_blank                         varchar2(1) :=' ';

con_high_key_values varchar2(54) := 'ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ';

-- Cursor to fetch altpart_supplier rows -------------------------

CURSOR supplier_cur(data_provider_skey_in NUMBER) IS
  SELECT asu.altpart_supplier_number,
         asu.altpart_supplier_name,
         asu.country_abbr
  FROM altpart_supplier asu
  WHERE asu.data_provider_skey = data_provider_skey_in
    AND asu.delete_date is null
  ORDER BY asu.altpart_supplier_number;

-- Cursor to fetch acq_altpart_trans_parse rows -------------------------

CURSOR trans_parse_cur IS
  SELECT aatp.datafile_skey, aatp.run_date, aatp.row_sequence_number,         
         aatp.part_supplier_number, aatp.part_number, aatp.altpart_number, 
         aatp.altpart_reconditioned_flag, aatp.altpart_price, 
         aatp.capa_certified_flag, aatp.oem_discount_flag
  FROM acq_altpart_trans_parse aatp
  WHERE aatp.data_provider_skey = vn_data_provider_skey
    AND aatp.datafile_skey in
        (SELECT asd.datafile_skey
         FROM altpart_supplier_datafile asd
         WHERE asd.altpart_supplier_number = vvc2_altpart_supplier_number)
  ORDER BY aatp.part_supplier_number, aatp.part_number, aatp.altpart_number, aatp.altpart_reconditioned_flag; 

-- Cursor to fetch part_altpart_xref ------------------------------------

CURSOR part_altpart_cur IS
  SELECT p.part_supplier_number, p.part_number, pax.altpart_number, 
         pax.altpart_reconditioned_flag, pax.part_skey,
         pax.altpart_price, pax.capa_certified_flag, pax.oem_discount_flag
  FROM part_altpart_xref pax, part p
  WHERE pax.altpart_supplier_number = vvc2_altpart_supplier_number
    AND pax.part_skey = p.part_skey
  ORDER BY p.part_supplier_number, p.part_number, pax.altpart_number, pax.altpart_reconditioned_flag;

---------  LOCAL PROCEDURES  --------------------------------------------
----------------------------------------------------------
-- WRITE_SUMMARY_REC:
--    This procedure writes summary report information. It
--    also calls updates the part count in the Altpart 
--    Supplier's table.
----------------------------------------------------------
PROCEDURE WRITE_SUMMARY_REC (vvc2_in_data_provider_name  IN varchar2,
                             vvc2_altpart_supplier_number IN varchar2,
                             vvc2_altpart_supplier_name  IN varchar2, 
                             vd_date                     IN date, 
                             vn_supplier_part_ins        IN number,
                             vn_supplier_part_upd        IN number,
                             vn_supplier_part_del        IN number,
                             vn_supplier_part_byp_nochg  IN number,
                             vn_supplier_part_byp_dup    IN number,
                             vvc2_processing_error_msg   IN varchar2) IS

vn_supplier_part_count       number(10)   := 0;
pvc2_delete_reason_code      varchar2(10) := ' ';

  BEGIN

     vn_supplier_part_count := (vn_supplier_part_ins + vn_supplier_part_upd + vn_supplier_part_byp_nochg);

     IF vvc2_processing_error_msg = ' ' THEN
        PKG_ALTERNATE_PARTS.P_ALTPART_SUPPLIER_UPD_02 (vvc2_altpart_supplier_number,
                                                       vn_supplier_part_count,
                                                       pvc2_delete_reason_code,
                                                       vd_date,
                                                       vn_called_row_count,
                                                       vvc2_called_error_msg,
                                                       vn_supplier_return_code);
        IF vn_supplier_return_code <> 0 THEN
          RAISE BAD_UPD_ALTPART_SUPPLIER;
        END IF;
     END IF;

-- Check for new page
     IF (vn_sum_line_ctr > vn_newpage) OR (vn_sum_line_ctr = 0) THEN
        vn_sum_page_ctr := vn_sum_page_ctr+1;
        UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_header1 || to_char(vn_sum_page_ctr));
        UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_header2s || to_char(vd_date,'MM/DD/YYYY'));
        UTL_FILE.PUT_LINE(v_sum_fHandle,RPAD(con_blank,140,' '));
        UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_header3s);
        UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_header4s);
        vn_sum_line_ctr := 5;
     END IF;

-- Write summary line
     vvc2_sum_line := RPAD(RTRIM(vvc2_in_data_provider_name,27),27,' ')
           || ' '  || vvc2_altpart_supplier_number
           || ' '  || RPAD(RTRIM(vvc2_altpart_supplier_name,24),24,' ')
           || '  ' || LPAD(vn_supplier_part_ins,9,' ')
           || ' '  || LPAD(vn_supplier_part_upd,9,' ')
           || ' '  || LPAD(vn_supplier_part_del,9,' ')
           || ' '  || LPAD(vn_supplier_part_byp_nochg,9,' ')
           || ' '  || LPAD(vn_supplier_part_byp_dup,9,' ')
           || ' '  || RPAD(vvc2_processing_error_msg,30,' ');

     UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_sum_line);
     vn_sum_line_ctr := vn_sum_line_ctr + 1;

  -------- COMMIT all work assoc'd to Data File before processing next
    BEGIN
      COMMIT;  -- all changes
               -- WHILE TESTING, USE ROLLBACK (and comment out COMMIT)
--        ROLLBACK;
    EXCEPTION
       WHEN OTHERS THEN
          ROLLBACK;  -- Rollback all changes made to the database. Unlock tables.
          DBMS_OUTPUT.PUT_LINE('Error in commit');
          DBMS_OUTPUT.PUT_LINE(SQLERRM);
          RETURN;  -- Stop execution.
    END;


END WRITE_SUMMARY_REC;

----------------------------------------------------------
-- FETCH_TRANS:
--    This procedure handles all logic associated with 
--    fetching acq_altpart_trans-parse rows from the 
--    database.
--    1) parse row is fetched
--    2) check if any associated "reject" errors. If so, 
--       bypass further processing of this trans.
--    3) check if key values are the same as the previously
--       processed transaction. If so, bypass further
--       processing.   
----------------------------------------------------------
PROCEDURE FETCH_TRANS (vn_data_provider_skey          IN     number,
                       vn_aatp_datafile_skey          IN OUT number,       
                       vd_aatp_run_date               IN OUT date, 
                       vn_aatp_row_sequence_number    IN OUT number,  
                       vvc2_aatp_part_supplier_number IN OUT varchar2,
                       vvc2_aatp_part_number          IN OUT varchar2, 
                       vvc2_aatp_altpart_number       IN OUT varchar2,
                       vc_aatp_altpart_recond_flag    IN OUT char,
                       vn_aatp_altpart_price          IN OUT number,
                       vc_aatp_capa_certified_flag    IN OUT char,
                       vc_aatp_oem_discount_flag      IN OUT char,
                       vvc2_aatp_key_values           IN OUT varchar2,
                       vvc2_prev_key_values           IN OUT varchar2, 
                       vn_supplier_trans_read         IN OUT number, 
                       vc_valid_aatp_found_sw         IN OUT char,
                       vvc2_called_error_msg          IN OUT varchar2) IS


  vn_aatp_return_code        number(6);
  vn_aatp_row_count          number(6);

  vn_aatpe_return_code       number(6);
  vn_aatpe_row_count         number(6);

  vn_reject_error_count      number;
   
  BEGIN

    vc_valid_aatp_found_sw := 'N';

    LOOP
       EXIT WHEN trans_parse_cur%NOTFOUND OR vc_valid_aatp_found_sw = 'Y'; 

       vn_aatp_return_code := 0;
       vn_aatp_row_count   := 0;
       vvc2_called_error_msg := ' ';
       vn_aatpe_return_code := 0;
       vn_aatpe_row_count   := 0;
       vn_reject_error_count := 0;


       FETCH trans_parse_cur into vn_aatp_datafile_skey, 
                                  vd_aatp_run_date, 
                                  vn_aatp_row_sequence_number,
                                  vvc2_aatp_part_supplier_number,
                                  vvc2_aatp_part_number, 
                                  vvc2_aatp_altpart_number,
                                  vc_aatp_altpart_recond_flag,
                                  vn_aatp_altpart_price,
                                  vc_aatp_capa_certified_flag,
                                  vc_aatp_oem_discount_flag;

-- If reached the end of the trans file, set the key values to "high_values"  
       IF trans_parse_cur%NOTFOUND THEN
          vvc2_aatp_key_values := con_high_key_values;
       ELSE
          vvc2_aatp_key_values := LPAD(vvc2_aatp_part_supplier_number,3,'0') 
                               || RPAD(vvc2_aatp_part_number,25,' ')
                               || RPAD(vvc2_aatp_altpart_number,25,' ')
                               || vc_aatp_altpart_recond_flag;
       END IF;

-- Check if any associated "reject" errors. If so, don't count it as read and bypass it.
-- If not, add 1 to counter. Also, check if the same key values have been previously
-- processed. If so, prepare to do another fetch. If not, set the flag for update
-- processing.    
       IF trans_parse_cur%FOUND THEN
          SELECT count(*)
          INTO vn_reject_error_count
          FROM ACQ_ALTPART_TRANS_PARSE_ERROR aatpe
          WHERE aatpe.data_provider_skey = vn_data_provider_skey
            AND aatpe.datafile_skey = vn_aatp_datafile_skey
            AND aatpe.run_date = vd_aatp_run_date
            AND aatpe.row_sequence_number = vn_aatp_row_sequence_number
            AND aatpe.part_supplier_number = vvc2_aatp_part_supplier_number
            AND aatpe.acq_error_code in
                (SELECT acq_error.acq_error_code
                 FROM acq_error
                 WHERE acq_error.reject_flag = 'Y');
          vn_aatpe_row_count   := SQL%RowCount;
          vvc2_called_error_msg := SQLERRM(SQLCODE);
          vn_aatpe_return_code := SQLCODE;
          IF vn_reject_error_count = 0 THEN
             vn_supplier_trans_read := vn_supplier_trans_read + 1;
             IF vvc2_aatp_key_values <> vvc2_prev_key_values THEN 
               vc_valid_aatp_found_sw := 'Y'; 
             END IF;
          END IF;
       END IF;               
     
   END LOOP;

   vvc2_prev_key_values := vvc2_aatp_key_values;

      
END FETCH_TRANS;

----------------------------------------------------------
-- FETCH_XREF_PARTS:
--    This procedure handles all logic associated with 
--    fetching part_altpart_xref rows from the 
--    database.
--    1) parse row is fetched
--    2) set key values
----------------------------------------------------------
PROCEDURE FETCH_XREF_PARTS (vvc2_altpart_supplier_number  IN     varchar2,
                            vvc2_pax_part_supplier_number IN OUT varchar2,
                            vvc2_pax_part_number          IN OUT varchar2, 
                            vvc2_pax_altpart_number       IN OUT varchar2,
                            vc_pax_altpart_recond_flag    IN OUT varchar2,
                            vn_pax_part_skey              IN OUT number,
                            vn_pax_altpart_price          IN OUT number,
                            vc_pax_capa_certified_flag    IN OUT char,
                            vc_pax_oem_discount_flag      IN OUT char,
                            vvc2_pax_key_values           IN OUT varchar2, 
                            vc_valid_pax_found_sw         IN OUT char,
                            vvc2_called_error_msg         IN OUT varchar2) IS

  BEGIN

    vc_valid_pax_found_sw := 'N';
 
    FETCH  part_altpart_cur into vvc2_pax_part_supplier_number,
                                 vvc2_pax_part_number,
                                 vvc2_pax_altpart_number,
                                 vc_pax_altpart_recond_flag,
                                 vn_pax_part_skey,
                                 vn_pax_altpart_price,
                                 vc_pax_capa_certified_flag,
                                 vc_pax_oem_discount_flag;

-- if reached the end of the part_altpart_xref table, set the key values to "high_values"
   IF part_altpart_cur%NOTFOUND THEN
      vvc2_pax_key_values := con_high_key_values;
   ELSE 
      vvc2_pax_key_values := LPAD(vvc2_pax_part_supplier_number,3,'0')
                             || RPAD(vvc2_pax_part_number,25,' ')
                             || RPAD(vvc2_pax_altpart_number,25,' ')
                             || vc_pax_altpart_recond_flag;
      vc_valid_pax_found_sw := 'Y';
   END IF;

   vvc2_called_error_msg := SQLERRM(SQLCODE);
 
END FETCH_XREF_PARTS;
----------------------------------------------------------
-- DELETE_ROUTINE:
--    This procedure handles all logic associated with 
--    deleting a part_altpart_xref row from the database.
----------------------------------------------------------
PROCEDURE DELETE_ROUTINE (vn_pax_part_skey               IN number,
                          vvc2_pax_altpart_number        IN varchar2,
                          vvc2_altpart_supplier_number   IN varchar2,
                          vvc_pax_altpart_recond_flag    IN char,
                          vn_supplier_part_del           IN OUT number,
                          vn_tot_part_del                IN OUT number) IS

  BEGIN
     PKG_ALTERNATE_PARTS.P_PART_ALTPART_XREF_DEL_02 (vn_pax_part_skey,
                                                     vvc2_pax_altpart_number,
                                                     vvc2_altpart_supplier_number,
                                                     vvc_pax_altpart_recond_flag,
                                                     vn_called_row_count,
                                                     vvc2_called_error_msg,
                                                     vn_xref_return_code);

     IF vn_xref_return_code <> 0 THEN
       RAISE BAD_DEL_PART_ALTPART_XREF;
     END IF;
 
     vn_supplier_part_del := vn_supplier_part_del + 1;
     vn_tot_part_del := vn_tot_part_del + 1;
     
END DELETE_ROUTINE;

----------------------------------------------------------
-- INSERT_ROUTINE:
--    This procedure handles all logic associated with 
--    inserting a part_altpart_xref row into the database.
----------------------------------------------------------
PROCEDURE INSERT_ROUTINE (vvc2_aatp_part_supplier_number IN varchar2,
                          vvc2_altp_supplier_country     IN varchar2,
                          vvc2_aatp_part_number          IN varchar2,
                          vvc2_aatp_altpart_number       IN varchar2,
                          vvc2_altpart_supplier_number   IN varchar2,
                          vc_aatp_altpart_recond_flag    IN char,
                          vn_aatp_altpart_price          IN number,
                          vc_aatp_capa_certified_flag    IN char,
                          vc_aatp_oem_discount_flag      IN char,
                          vn_supplier_part_ins           IN OUT number,
                          vn_tot_part_ins                IN OUT number) IS

  BEGIN
     PKG_ALTERNATE_PARTS.P_PART_ALTPART_XREF_INS_01 (vvc2_aatp_part_supplier_number,
                                                     vvc2_altp_supplier_country,
                                                     vvc2_aatp_part_number,
                                                     vvc2_aatp_altpart_number,
                                                     vvc2_altpart_supplier_number,
                                                     vc_aatp_altpart_recond_flag,
                                                     vn_aatp_altpart_price,
                                                     vc_aatp_capa_certified_flag,
                                                     vc_aatp_oem_discount_flag,
                                                     vn_called_row_count,
                                                     vvc2_called_error_msg,
                                                     vn_xref_return_code);

     IF vn_xref_return_code <> 0 THEN
       RAISE BAD_INS_PART_ALTPART_XREF;
     END IF;
 
     vn_supplier_part_ins := vn_supplier_part_ins + 1;
     vn_tot_part_ins := vn_tot_part_ins + 1;
     
END INSERT_ROUTINE;

----------------------------------------------------------
-- UPDATE_ROUTINE:
--    This procedure handles all logic associated with 
--    updating a part_altpart_xref row in the database.
----------------------------------------------------------
PROCEDURE UPDATE_ROUTINE (vn_pax_part_skey               IN NUMBER,
                          vvc2_pax_altpart_number        IN varchar2,
                          vvc2_altpart_supplier_number   IN varchar2,
                          vc_pax_altpart_recond_flag     IN char,
                          vn_pax_altpart_price           IN number,
                          vc_pax_capa_certified_flag     IN char,
                          vc_pax_oem_discount_flag       IN char,
                          vn_aatp_altpart_price          IN number,
                          vc_aatp_capa_certified_flag    IN char,
                          vc_aatp_oem_discount_flag      IN char,
                          vn_supplier_part_upd           IN OUT number,
                          vn_tot_part_upd                IN OUT number,
                          vn_supplier_part_byp_nochg     IN OUT number,
                          vn_tot_part_byp_nochg          IN OUT number) IS

  BEGIN
-- Bypass performing an update if nothing has changed.
     IF vn_aatp_altpart_price = vn_pax_altpart_price THEN
       IF vc_aatp_capa_certified_flag = vc_pax_capa_certified_flag THEN
         IF vc_aatp_oem_discount_flag = vc_pax_oem_discount_flag THEN
           vn_supplier_part_byp_nochg := vn_supplier_part_byp_nochg + 1;
           vn_tot_part_byp_nochg := vn_tot_part_byp_nochg + 1;
           RETURN;
         END IF;
       END IF;
     END IF;

-- Update the database if price or the flags have changed.     
     PKG_ALTERNATE_PARTS.P_PART_ALTPART_XREF_UPD_02 (vn_pax_part_skey,
                                                     vvc2_pax_altpart_number,
                                                     vvc2_altpart_supplier_number,
                                                     vc_pax_altpart_recond_flag,
                                                     vn_aatp_altpart_price,
                                                     vc_aatp_capa_certified_flag,
                                                     vc_aatp_oem_discount_flag,
                                                     vn_called_row_count,
                                                     vvc2_called_error_msg,
                                                     vn_xref_return_code);

     IF vn_xref_return_code <> 0 THEN
       RAISE BAD_UPD_PART_ALTPART_XREF;
     END IF;
 
     vn_supplier_part_upd := vn_supplier_part_upd + 1;
     vn_tot_part_upd := vn_tot_part_upd + 1;
     
END UPDATE_ROUTINE;

---------  MAIN PROGRAM -------------------------------------------------

BEGIN

---------  INITIALIZE ALL VARIABLES   ---------------------------------------------------
  vvc2_code_location := 'INITIALIZE ALL';

  vvc2_jobname      :=UPPER('&v_JOBNAME');
  vvc2_in_dirname   :='&v_IN_DIR';
  vvc2_in_filename  :='&v_IN_FILE';
  vvc2_sum_dirname  :='&v_SUM_DIR';
  vvc2_sum_filename :='&v_SUM_FILE';

  select sysdate into vd_date from dual;
  vvc2_run_date := to_char(vd_date,'MM/DD/YYYY HH24:MI:SS');

  DBMS_OUTPUT.ENABLE(1000000);
  DBMS_OUTPUT.NEW_LINE;
  DBMS_OUTPUT.PUT_LINE('Start: ' || vvc2_run_date);

---------  OPEN INPUT/OUTPUT FILE  -----------------------------------------------------
  vvc2_code_location := 'OPEN FILES';

  v_in_fHandle := UTL_FILE.FOPEN(vvc2_in_dirname,vvc2_in_filename,'r',100);
  v_sum_fHandle := UTL_FILE.FOPEN(vvc2_sum_dirname,vvc2_sum_filename,'w');

---------  SET HEADER AND SUBHEADER VALUES  --------------------------------------------
  vvc2_code_location := 'SET HEADERS';

  vvc2_header1 := chr(12) || vvc2_jobname || lpad('MITCHELL INTERNATIONAL',52,' ')
               || LPAD('PAGE NO: ',49,' ');

  vvc2_header2s := lpad('ALTERNATE PARTS - UPDATE SUMMARY',65,' ')
               || LPAD('REPORT DATE: ',48,' ');

  vvc2_header3s := 'DATA PROVIDER (1st 27 CHAR) '
                || 'SUPPLIER NAME                  '
                || 'INSERT    '
                || 'UPDATE    '
                || 'DELETE    '
                || 'BYP NOCHG ' 
                || 'BYP DUP   ' 
                || 'PROCESSING MESSAGE            ';

  vvc2_header4s := '--------------------------- '
                || '------------------------------ '
                || '--------- '
                || '--------- '
                || '--------- '
                || '--------- '
                || '--------- '
                || '------------------------------';

  vvc2_footnote1 := 'NOTE: INSERT + UPDATE + BYP NOCHG + BYP DUP = FOR UPDATE (IN PART VERIFICATION SUMMARY)';
  vvc2_footnote2 := '      INSERT    => NEW PART FOR THE SUPPLER; INSERTED IN DATABASE';
  vvc2_footnote3 := '      UPDATE    => EXISTING PART IN DATABASE WHOSE PRICE AND/OR FLAGS CHANGED; DATABASE UPDATED';
  vvc2_footnote4 := '      DELETE    => PART NO LONGER SENT IN FILE; THEREFORE REMOVED FROM DATABASE';
  vvc2_footnote5 := '      BYP NOCHG => EXISTING PART IN DATABASE BUT PRICE AND/OR FLAGS HAVE NOT CHANGED; UPDATE BYPASSED'; 
  vvc2_footnote6 := '      BYP DUP   => DUPLICATE OF AN EXISTING PART IN DATABASE THAT WAS ALREADY PROCESSED; UPDATE BYPASSED';                  

  LOOP  <<main_loop>>

---------  PROCESS INPUT RECORD  ----------------------------------------------------------
-- 1) read input parm file
-- 2) check if header record contains expected key phrase. If not, abend.
-- 3) initialize header-related variables
-- 4) calc values needed for parsing info from header record
--         ending position of provider name
--         length of provider name
-- 5) parse out data provider name
-- 6) call routine to verify data provider name and pickup skey
-- 7) Enter into 2nd loop to fetch all assoc'd suppliers.
-- 8) Enter 3rd loop to perform file match / update between transactions
--    and part_altpart_xref rows assoc'd to supplier.
-- 9) When all parts assoc'd to supplier have been processed, write summary rec.
--10) at end, produce summary totals.   

    vvc2_code_location := 'PROCESS INPUT';
    vn_data_provider_skey          :=0;
    vn_provider_return_code        :=0;
    vn_supplier_read               :=0;
    vvc2_processing_error_msg := ' ';

    BEGIN
      UTL_FILE.GET_LINE(v_in_fHandle,vvc2_in_rec);
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
      EXIT;
    END;

    vn_parm_recs_read :=vn_parm_recs_read +1;

    vvc2_in_data_provider_name := UPPER(NVL(RTRIM(SUBSTR(vvc2_in_rec,1,80)),' '));


-- Get data provider skey assoc'd with data provider name ------------------------------
  vvc2_code_location := 'GET DATA PROVIDER';

     PKG_ALTERNATE_PARTS_DATAFILE.P_ALTPART_DATA_PROVIDER_SEL_01
        (vvc2_in_data_provider_name,
         vn_data_provider_skey,
         vn_called_row_count,
         vvc2_called_error_msg,
         vn_provider_return_code);

     IF vn_provider_return_code <> 0 THEN
       vvc2_processing_error_msg := con_data_provider_error;
       vvc2_altpart_supplier_name   := ' ';
       vvc2_altpart_supplier_number := ' ';
       vvc2_sum_line := RPAD(RTRIM(vvc2_in_data_provider_name,27),27,' ')
             || ' '  || RPAD(con_blank,4,' ')
             || ' '  || RPAD(con_blank,24,' ')
             || '  ' || LPAD(0,9,' ')
             || ' '  || LPAD(0,9,' ')
             || ' '  || LPAD(0,9,' ')
             || ' '  || LPAD(0,9,' ')
             || ' '  || LPAD(0,9,' ')
             || ' '  || RPAD(vvc2_processing_error_msg,30,' ');
       UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_sum_line);
       GOTO main_loop;
     END IF;

     DBMS_OUTPUT.PUT_LINE('Provider: ' || vvc2_in_data_provider_name || ' - ' || vn_data_provider_skey);

-- Fetch suppliers associated to data provider           ------------------------------
     FOR supplier_rec IN supplier_cur(vn_data_provider_skey)
        LOOP
           vvc2_code_location := 'SUPPLIER FETCH';

           vvc2_altpart_supplier_number := supplier_rec.altpart_supplier_number;
           vvc2_altpart_supplier_name := SUBSTR(supplier_rec.altpart_supplier_name,1,30);
           vvc2_altp_supplier_country := supplier_rec.country_abbr;

           vn_supplier_trans_read := 0;
           vn_supplier_part_ins := 0;
           vn_supplier_part_upd := 0;
           vn_supplier_part_del := 0;
           vn_supplier_part_byp_nochg := 0;
           vn_supplier_part_byp_dup := 0;
           vvc2_processing_error_msg := ' ';
           vvc2_prev_key_values := ' ';
           vn_supplier_read := vn_supplier_read + 1;


-- Open cursor to fetch supplier's transactions.                -----------------------
-- Fetch 1st row to prepare for file match.                     -----------------------
-- If no transactions found, set error message                  -----------------------
           vvc2_code_location := 'OPEN TRANS';
           OPEN trans_parse_cur;
           FETCH_TRANS (vn_data_provider_skey,
                        vn_aatp_datafile_skey,       
                        vd_aatp_run_date, 
                        vn_aatp_row_sequence_number,  
                        vvc2_aatp_part_supplier_number,
                        vvc2_aatp_part_number, 
                        vvc2_aatp_altpart_number,
                        vc_aatp_altpart_recond_flag,
                        vn_aatp_altpart_price,
                        vc_aatp_capa_certified_flag,
                        vc_aatp_oem_discount_flag,
                        vvc2_aatp_key_values,
                        vvc2_prev_key_values, 
                        vn_supplier_trans_read, 
                        vc_valid_aatp_found_sw,
                        vvc2_called_error_msg);
  
           IF vc_valid_aatp_found_sw = 'N' THEN
              vvc2_processing_error_msg := con_no_trans_data_error;
           END IF;

-- Open cursor to fetch supplier's part info in part_altpart_xref. --------------------
-- Fetch 1st row to prepare for file match.                     -----------------------
           vvc2_code_location := 'OPEN PARTS';
           OPEN part_altpart_cur;
           FETCH_XREF_PARTS (vvc2_altpart_supplier_number,
                             vvc2_pax_part_supplier_number,
                             vvc2_pax_part_number, 
                             vvc2_pax_altpart_number,
                             vc_pax_altpart_recond_flag,
                             vn_pax_part_skey,
                             vn_pax_altpart_price,
                             vc_pax_capa_certified_flag,
                             vc_pax_oem_discount_flag,
                             vvc2_pax_key_values,
                             vc_valid_pax_found_sw,
                             vvc2_called_error_msg);

-- Perform supplier's part update by fetching transactions and existing ---------------
-- part_altpart_xref rows, checking for match, and based on check       ---------------
-- performing either an insert, update, or delete.                      ---------------
-- If no transactions were found at first fetch then this is bypassed.  ---------------
           <<part_loop>>  
           LOOP
              vvc2_code_location := 'PARTS FETCH LOOP';
              EXIT WHEN (vvc2_processing_error_msg = con_no_trans_data_error) 
                     OR (vc_valid_aatp_found_sw = 'N' AND vc_valid_pax_found_sw = 'N');

              IF vvc2_aatp_key_values = vvc2_pax_key_values THEN
                 vvc2_code_location := 'EQUAL LOGIC';
                 UPDATE_ROUTINE (vn_pax_part_skey,
                                 vvc2_pax_altpart_number,
                                 vvc2_altpart_supplier_number,
                                 vc_pax_altpart_recond_flag,
                                 vn_pax_altpart_price,
                                 vc_pax_capa_certified_flag,
                                 vc_pax_oem_discount_flag,
                                 vn_aatp_altpart_price,
                                 vc_aatp_capa_certified_flag,
                                 vc_aatp_oem_discount_flag,
                                 vn_supplier_part_upd,
                                 vn_tot_part_upd,
                                 vn_supplier_part_byp_nochg,
                                 vn_tot_part_byp_nochg);
                 FETCH_TRANS (vn_data_provider_skey,
                              vn_aatp_datafile_skey,       
                              vd_aatp_run_date, 
                              vn_aatp_row_sequence_number,  
                              vvc2_aatp_part_supplier_number,
                              vvc2_aatp_part_number, 
                              vvc2_aatp_altpart_number,
                              vc_aatp_altpart_recond_flag,
                              vn_aatp_altpart_price,
                              vc_aatp_capa_certified_flag,
                              vc_aatp_oem_discount_flag,
                              vvc2_aatp_key_values,
                              vvc2_prev_key_values, 
                              vn_supplier_trans_read, 
                              vc_valid_aatp_found_sw,
                              vvc2_called_error_msg);
                FETCH_XREF_PARTS (vvc2_altpart_supplier_number,
                                  vvc2_pax_part_supplier_number,
                                  vvc2_pax_part_number, 
                                  vvc2_pax_altpart_number,
                                  vc_pax_altpart_recond_flag,
                                  vn_pax_part_skey,
                                  vn_pax_altpart_price,
                                  vc_pax_capa_certified_flag,
                                  vc_pax_oem_discount_flag,
                                  vvc2_pax_key_values,
                                  vc_valid_pax_found_sw,
                                  vvc2_called_error_msg); 
              ELSIF vvc2_aatp_key_values > vvc2_pax_key_values THEN
                 vvc2_code_location := 'GREATER THAN LOGIC';
                 DELETE_ROUTINE (vn_pax_part_skey,
                                 vvc2_pax_altpart_number,
                                 vvc2_altpart_supplier_number,
                                 vc_pax_altpart_recond_flag,
                                 vn_supplier_part_del,
                                 vn_tot_part_del);
                 FETCH_XREF_PARTS (vvc2_altpart_supplier_number,
                                   vvc2_pax_part_supplier_number,
                                   vvc2_pax_part_number, 
                                   vvc2_pax_altpart_number,
                                   vc_pax_altpart_recond_flag,
                                   vn_pax_part_skey,
                                   vn_pax_altpart_price,
                                   vc_pax_capa_certified_flag,
                                   vc_pax_oem_discount_flag,
                                   vvc2_pax_key_values,
                                   vc_valid_pax_found_sw,
                                   vvc2_called_error_msg); 
              ELSIF vvc2_aatp_key_values < vvc2_pax_key_values THEN
                 vvc2_code_location := 'LESS THAN LOGIC';
                 INSERT_ROUTINE (vvc2_aatp_part_supplier_number,
                                 vvc2_altp_supplier_country,
                                 vvc2_aatp_part_number,
                                 vvc2_aatp_altpart_number,
                                 vvc2_altpart_supplier_number,
                                 vc_aatp_altpart_recond_flag,
                                 vn_aatp_altpart_price,
                                 vc_aatp_capa_certified_flag,
                                 vc_aatp_oem_discount_flag,
                                 vn_supplier_part_ins,
                                 vn_tot_part_ins);
                 FETCH_TRANS (vn_data_provider_skey,
                              vn_aatp_datafile_skey,       
                              vd_aatp_run_date, 
                              vn_aatp_row_sequence_number,  
                              vvc2_aatp_part_supplier_number,
                              vvc2_aatp_part_number, 
                              vvc2_aatp_altpart_number,
                              vc_aatp_altpart_recond_flag,
                              vn_aatp_altpart_price,
                              vc_aatp_capa_certified_flag,
                              vc_aatp_oem_discount_flag,
                              vvc2_aatp_key_values,
                              vvc2_prev_key_values, 
                              vn_supplier_trans_read, 
                              vc_valid_aatp_found_sw,
                              vvc2_called_error_msg);                 
              END IF;
              
           END LOOP part_loop; -- parts loop

        vvc2_code_location := 'AFTER PART LOOP'; 

        CLOSE trans_parse_cur;
        CLOSE part_altpart_cur;

-- Commit changes for this supplier to the database -----------------------------------
    BEGIN
       COMMIT;      -- Commit everything for this supplier 
         
       EXCEPTION
         WHEN OTHERS THEN
           ROLLBACK;  -- Rollback all changes made to the database. Unlock tables.
           DBMS_OUTPUT.PUT_LINE('Error in commit of altpart supplier: ' ||
                                vvc2_altpart_supplier_number || ' - ' || vvc2_altpart_supplier_name);
           DBMS_OUTPUT.PUT_LINE(SQLERRM);
           RETURN;  -- Stop execution.
    END;

        vn_supplier_part_byp_dup := vn_supplier_trans_read - (vn_supplier_part_ins + vn_supplier_part_upd + vn_supplier_part_byp_nochg);
        DBMS_OUTPUT.PUT_LINE('Supplier: ' || vvc2_altpart_supplier_number || ' - ' || vvc2_altpart_supplier_name);
        DBMS_OUTPUT.PUT_LINE('Part Counts: ' || vn_supplier_trans_read || ' - ' ||
                                                vn_supplier_part_ins || ' - ' ||
                                                vn_supplier_part_upd || ' - ' ||
                                                vn_supplier_part_del || ' - ' ||
                                                vn_supplier_part_byp_nochg || ' - ' ||
                                                vn_supplier_part_byp_dup);

        WRITE_SUMMARY_REC (vvc2_in_data_provider_name,
                           vvc2_altpart_supplier_number,
                           vvc2_altpart_supplier_name, 
                           vd_date,
                           vn_supplier_part_ins,
                           vn_supplier_part_upd,
                           vn_supplier_part_del,
                           vn_supplier_part_byp_nochg,
                           vn_supplier_part_byp_dup,
                           vvc2_processing_error_msg);

        vn_tot_part_byp_dup := vn_tot_part_byp_dup + vn_supplier_part_byp_dup;

     END LOOP;  -- supplier loop

     vvc2_code_location := 'AFTER SUPPLIER LOOP'; 

-- Check if no suppliers found for this Data Provider

     IF vn_supplier_read = 0 THEN 
        vvc2_processing_error_msg := con_supplier_error;
        vvc2_sum_line := RPAD(RTRIM(vvc2_in_data_provider_name,27),27,' ')
              || ' '  || RPAD(con_blank,4,' ')
              || ' '  || RPAD(con_blank,24,' ')
              || '  ' || LPAD(0,9,' ')
              || ' '  || LPAD(0,9,' ')
              || ' '  || LPAD(0,9,' ')
              || ' '  || LPAD(0,9,' ')
              || ' '  || LPAD(0,9,' ')
              || ' '  || RPAD(vvc2_processing_error_msg,30,' ');
        UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_sum_line);
     END IF;

  END LOOP main_loop;

-------- FINAL PROCESSING -------------------------------------------------------------
vvc2_code_location := 'FINAL PROCESSING'; 


-- Write summary record containing totals.

  vvc2_processing_error_msg := ' ';
  vvc2_sum_line := vvc2_header4s;
  UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_sum_line);

  vvc2_sum_line := RPAD(con_blank,27,' ')
                   || ' '  || RPAD(con_blank,4,' ')
                   || ' '  || RPAD(con_blank,24,' ')
                   || '  ' || LPAD(vn_tot_part_ins,9,' ')
                   || ' '  || LPAD(vn_tot_part_upd,9,' ')
                   || ' '  || LPAD(vn_tot_part_del,9,' ')
                   || ' '  || LPAD(vn_tot_part_byp_nochg,9,' ')
                   || ' '  || LPAD(vn_tot_part_byp_dup,9,' ')
                   || ' '  || RPAD(vvc2_processing_error_msg,30,' ');

  UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_sum_line);

-- Write footnotes
  UTL_FILE.PUT_LINE(v_sum_fHandle,RPAD(con_blank,140,' '));
  UTL_FILE.PUT_LINE(v_sum_fHandle,RPAD(con_blank,140,' '));
  UTL_FILE.PUT_LINE(v_sum_fHandle,RPAD(con_blank,140,' '));

  UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_footnote1);
  UTL_FILE.PUT_LINE(v_sum_fHandle,RPAD(con_blank,140,' '));

  UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_footnote2);
  UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_footnote3);
  UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_footnote4);
  UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_footnote5);
  UTL_FILE.PUT_LINE(v_sum_fHandle,vvc2_footnote6);

----------------- CLOSE INPUT / OUTPUT FILES --------------------------------------------

  UTL_FILE.FCLOSE(v_in_fHandle);
  UTL_FILE.FCLOSE(v_sum_fHandle);

EXCEPTION

  WHEN UTL_FILE.INVALID_PATH THEN
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    RAISE_APPLICATION_ERROR(-20100,'Invalid Path');

  WHEN UTL_FILE.INVALID_MODE THEN
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    RAISE_APPLICATION_ERROR(-20101,'Invalid Mode');

  WHEN UTL_FILE.INVALID_FILEHANDLE then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    RAISE_APPLICATION_ERROR(-20102,'Invalid Filehandle');

   WHEN UTL_FILE.INVALID_OPERATION then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    RAISE_APPLICATION_ERROR(-20103,'Invalid Filehandle operation');

  WHEN UTL_FILE.READ_ERROR then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    RAISE_APPLICATION_ERROR(-20104,'Read Error');

  WHEN UTL_FILE.WRITE_ERROR then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    RAISE_APPLICATION_ERROR(-20105,'Write Error');

  WHEN UTL_FILE.INTERNAL_ERROR then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    RAISE_APPLICATION_ERROR(-20106,'Internal Error');

  WHEN BAD_UPD_ALTPART_SUPPLIER then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Error attempting to update altpart_supplier row');
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('Altpart Supplier  : ' || vvc2_altpart_supplier_number);
    DBMS_OUTPUT.PUT_LINE('Last valued Error Message: ' || vvc2_called_error_msg );
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    RAISE_APPLICATION_ERROR(-20999,'Program Error');

  WHEN BAD_INS_PART_ALTPART_XREF then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Error attempting to insert part_altpart_xref row');
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('Part Supplier     : ' || vvc2_aatp_part_supplier_number);
    DBMS_OUTPUT.PUT_LINE('Supplier Country  : ' || vvc2_altp_supplier_country);
    DBMS_OUTPUT.PUT_LINE('Part Number       : ' || vvc2_aatp_part_number);
    DBMS_OUTPUT.PUT_LINE('Altpart Number    : ' || vvc2_aatp_altpart_number);
    DBMS_OUTPUT.PUT_LINE('Altpart Supplier  : ' || vvc2_altpart_supplier_number);
    DBMS_OUTPUT.PUT_LINE('Reconditioned Flag: ' || vc_aatp_altpart_recond_flag);
    DBMS_OUTPUT.PUT_LINE('Last valued Error Message: ' || vvc2_called_error_msg );
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    RAISE_APPLICATION_ERROR(-20999,'Program Error');

  WHEN BAD_UPD_PART_ALTPART_XREF then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Error attempting to update part_altpart_xref row');
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('Part Supplier     : ' || vvc2_pax_part_supplier_number);
    DBMS_OUTPUT.PUT_LINE('Part Number       : ' || vvc2_pax_part_number);
    DBMS_OUTPUT.PUT_LINE('Part Skey         : ' || vn_pax_part_skey);
    DBMS_OUTPUT.PUT_LINE('Altpart Number    : ' || vvc2_pax_altpart_number);
    DBMS_OUTPUT.PUT_LINE('Altpart Supplier  : ' || vvc2_altpart_supplier_number);
    DBMS_OUTPUT.PUT_LINE('Reconditioned Flag: ' || vc_pax_altpart_recond_flag);
    DBMS_OUTPUT.PUT_LINE('Last valued Error Message: ' || vvc2_called_error_msg );
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    RAISE_APPLICATION_ERROR(-20999,'Program Error');

  WHEN BAD_DEL_PART_ALTPART_XREF then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Error attempting to delete part_altpart_xref row');
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('Part Supplier     : ' || vvc2_pax_part_supplier_number);
    DBMS_OUTPUT.PUT_LINE('Part Number       : ' || vvc2_pax_part_number);
    DBMS_OUTPUT.PUT_LINE('Part Skey         : ' || vn_pax_part_skey);
    DBMS_OUTPUT.PUT_LINE('Altpart Number    : ' || vvc2_pax_altpart_number);
    DBMS_OUTPUT.PUT_LINE('Altpart Supplier  : ' || vvc2_altpart_supplier_number);
    DBMS_OUTPUT.PUT_LINE('Reconditioned Flag: ' || vc_pax_altpart_recond_flag);
    DBMS_OUTPUT.PUT_LINE('Last valued Error Message: ' || vvc2_called_error_msg );
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    RAISE_APPLICATION_ERROR(-20999,'Program Error');

  WHEN OTHERS then
    DBMS_OUTPUT.PUT_LINE('**************** EXCEPTION ERROR ****************************************');
    DBMS_OUTPUT.PUT_LINE('Unhandled Error at parm rec: ' || vn_parm_recs_read);
    DBMS_OUTPUT.PUT_LINE('Code last executed: ' || vvc2_code_location);
    DBMS_OUTPUT.PUT_LINE('Last valued Error Message: ' || vvc2_called_error_msg );
    DBMS_OUTPUT.PUT_LINE('*************************************************************************');
    ROLLBACK;
    UTL_FILE.FCLOSE(v_in_fHandle);
    UTL_FILE.FCLOSE(v_sum_fHandle);
    RAISE_APPLICATION_ERROR(-20999,'Unhandled Error Encountered');

END;

-- leave "/" it is required for pl/sql end block ----------------------------------------------------
/

quit;
--- leave "end_sql_block" it is required for sql end block -----
%
#END OF Script
