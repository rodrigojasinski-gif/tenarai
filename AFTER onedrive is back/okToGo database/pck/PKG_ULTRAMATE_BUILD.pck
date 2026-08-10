CREATE OR REPLACE Package EXT.PKG_ULTRAMATE_BUILD
authid current_user is

PROCEDURE ULTRAMATE_MAIN(parm_path varchar2, run_type varchar2, parm_file varchar2,
unix_full_dir varchar2, unix_mini_dir varchar2, version varchar2, restart_flag char,
ftp_machine_name varchar2 DEFAULT NULL, ftp_dest_path varchar2 DEFAULT NULL);
END;
/
CREATE OR REPLACE PACKAGE BODY EXT.pkg_ultramate_build IS
  /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
  *  $Workfile:$
  *    $Author:$
  *  $Revision:$
  *   $Modtime:$
  *
  *   PL/SQL name:                 PKG_ULTRAMATE_BUILD                    *
  *   Author:                      mm5095                                 *
  *   Description:                 Stored Functions to perform DDL        *
  *   Modifications:                                                      *
  *   2008/12/31 PAG - Pulled all functions and procedures from this pkg  *
  *                    and built PKG_ULTRAMATE_COMMON. Changed execs to   *
  *                    reference PKG_ULTRAMATE_COMMON. Added logic for    *
  *                    Msrine Engine Configs and Service Concatenation.   *
  *   04/05/2018 pb0690 - MCE Mini changes                                *
  *   08/2020    pb0690  Add PRTC For Specialty
	*   03/2021    pb0690  Specialty Changes
	*   03/2021    rs7649  Super Cat Changes
  * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

  -- ftp global variables
  ftp_on_flag BOOLEAN; -- controls whether data ftp'd to NT system. (see code after sf_getDirectoryPath for set of value)
  --test_flag boolean := false; -- 2008/12/31 pg2697 => moved to pkg_ultranate_common.extract_overlap

  ftp_ret_code        BINARY_INTEGER := 0;
  my_ftp_dest_path    VARCHAR2(80);
  my_ftp_machine_name VARCHAR2(10);

  bconsecutive_graphics BOOLEAN;

  --  test_fhandle UTL_FILE.FILE_TYPE;

  -- 10/20/08 mm5095 => bell and howell no longer supported
  --  bell_howell_fhandle UTL_FILE.FILE_TYPE;
  --  bell_howell_flag boolean := false;
  -- 10/20/08 mm5095 => bell and howell no longer supported

  gcountryabbr    VARCHAR2(2);
  glowerdate      DATE;
  gupperdate      DATE;
  gparallelnumber CHAR(1) := '0'; --parallel runs not used for Mini, but parm needed for some of the common routines

  service_barcode_in NUMBER;

  -- 10/24/2006 mm5095 => added support for extract_date
  extract_fhandle utl_file.file_type;
  -- 10/24/2006 mm5095 => added support for extract_date

  -- 10/24/2006 mm5095 => added support for special material qualifiers
  CURSOR special_cur IS
    SELECT /*+ special_cur */
     c.qualifier_skey, c.qualifier_name
      FROM qualifier_type_xref a, qualifier_type b, qualifier c
     WHERE b.description = 'Special Material'
       AND b.qualifier_type_skey = a.qualifier_type_skey
       AND c.qualifier_skey = a.qualifier_skey;

  TYPE special_table_type IS TABLE OF special_cur%ROWTYPE INDEX BY BINARY_INTEGER;
  special_table special_table_type;

  last_special_row INTEGER;
  vehicle_type     INTEGER;

  -- 10/24/2006 mm5095 => added support for special material qualifiers
  PROCEDURE sp_populatespecialmaterialtbl IS
  BEGIN
    last_special_row := 0;
    FOR rec IN special_cur LOOP
      last_special_row := last_special_row + 1;
      special_table(last_special_row).qualifier_skey := rec.qualifier_skey;

      IF (substr(rec.qualifier_name, 1, 1) != '(') THEN
        special_table(last_special_row).qualifier_name := '(' ||
                                                          rec.qualifier_name || ')';
      ELSE
        special_table(last_special_row).qualifier_name := rec.qualifier_name;
      END IF;
    END LOOP;
  END;

  FUNCTION sf_getspecialqualifier(skey_in NUMBER) RETURN VARCHAR2 IS
    CURSOR qualifier_cur(skey_in NUMBER) IS
      SELECT /*+ qualifier_cur */
       qualifier_skey
        FROM qgroup_qualifier
       WHERE qgroup_skey = skey_in;

    vvc2_return VARCHAR2(80) := NULL;
  BEGIN

    FOR rec IN qualifier_cur(skey_in) LOOP
      FOR n IN 1 .. last_special_row LOOP
        IF rec.qualifier_skey = special_table(n).qualifier_skey THEN
          RETURN special_table(n).qualifier_name;
        END IF;
      END LOOP;
    END LOOP;

    RETURN vvc2_return;
  END;
  -- 10/24/2006 mm5095 => added support for special material qualifiers

  PROCEDURE ext_price(version_in VARCHAR2,
                      country_in VARCHAR2,
                      path       VARCHAR2) IS
    CURSOR price_cur(version_in      VARCHAR2,
                     country_in      VARCHAR2,
                     product_code_in VARCHAR2) IS
      SELECT '9' || e.barcode service,
             b.barcode,
             CASE
               WHEN substr(b.prtc, 10, 1) = 'A' THEN
                'ORDER FROM DEALER'
               WHEN d.part_supplier_number = '000' AND
                    substr(d.part_number, 1, 2) = 'C ' AND
                    substr(d.part_number, 3, 1) IN ('D', 'F') THEN
                substr(d.part_number, 3)
             -- 02/19/2016 mm5095 => no longer necessary
             /*                       WHEN part_supplier_number IN ('001', '034', '038')
                                         AND length(rtrim(d.part_number)) < 13
                                         AND substr(part_number, 1, 4) != 'N.A.' THEN
                                     substr(rpad(d.part_number, 20, ' '), 1, 13) ||
                                     'GM PART'
             */
               ELSE
                d.part_number
             END part_number,
             round(d.current_price * 100) price1,
             to_char(d.current_effective_date, 'MM/DD/YYYY') curr_date,
             round(d.previous_price * 100) price2,
             to_char(d.previous_effective_date, 'MM/DD/YYYY') prev_date,
             decode(d.discontinued_date, NULL, 'N', 'Y') disc_flag,
             decode(d.new_or_reman_flag, 'Y', 'R', 'N') reman_flag
        FROM product_service a
       INNER JOIN service_category_detail b
          ON b.mfr_number = a.mfr_number
         AND b.service_number = a.service_number
         AND b.delete_flag_date IS NULL
         AND b.barcode IS NOT NULL
         AND b.version_type = version_in
       INNER JOIN detail_part_xref c
          ON c.unique_row_id = b.unique_row_id
         AND c.version_type = b.version_type
       INNER JOIN part d
          ON d.part_skey = c.part_skey
         AND d.part_supplier_country_abbr = country_in
         AND d.current_effective_date IS NOT NULL
       INNER JOIN service e
          ON e.mfr_number = a.mfr_number
         AND e.service_number = a.service_number
         AND e.version_type = b.version_type
       WHERE a.product_code = product_code_in;

    product_code_in VARCHAR2(6);
    bfirsttime      BOOLEAN := TRUE;
    out_fhandle     utl_file.file_type;

  BEGIN
    IF version_in = 'PR' THEN
      product_code_in := 'PT0990';
    ELSE
      product_code_in := 'TT0990';
    END IF;

    FOR rec IN price_cur(version_in, country_in, product_code_in) LOOP
      IF (bfirsttime) THEN
        bfirsttime  := FALSE;
/* -- File generation disabled: DI[barcode].txt fopen (FTP sunset)
        out_fhandle := utl_file.fopen(path,
                                      'price_' || lower(country_in) ||
                                      '.txt',
                                      'w');
-- end commented block */
      END IF;

/* -- File generation disabled: DI[barcode].txt write (FTP sunset)
      utl_file.put_line(out_fhandle,
                        rec.service || ',' || rec.barcode || ',' || '"' ||
                        rec.part_number || '"' || ',' || rec.price1 || ',' ||
                        rec.curr_date || ',' || rec.price2 || ',' ||
                        rec.prev_date || ',' || rec.disc_flag || ',' ||
                        rec.reman_flag);
-- end commented block */
    END LOOP;

/* -- File generation disabled: DI[barcode].txt is_open check (FTP sunset)
    IF utl_file.is_open(out_fhandle) THEN
      utl_file.fclose(out_fhandle);
    END IF;
-- end commented block */
    /*
               pkg_ultramate_common.sp_update_globaltxt_semaphore(path,
                                                                  'global.txt',
                                                                  'a',
                                                                  'price_' ||
                                                                  lower(country_in) || '.txt');
    */
  END;

  PROCEDURE ext_mapp(path VARCHAR2) IS
    CURSOR mapp_cur IS
      SELECT service,
             barcode,
             a.altpart_supplier_number,
             decode(reconditioned_flag, 'Y', '1', '0') reconditioned_flag,
             category_cd,
             price * 100 my_price,
             extract_cert_flag,
             REPLACE(altpart_number, ',') altpart_number,
             oem_discount_flag
        FROM ext.mapp_part_current a
       WHERE a.altpart_supplier_number = 'ZA50'
         AND rownum < 2;

    bfirsttime       BOOLEAN := TRUE;
    out_fhandle      utl_file.file_type;
    altpart_supplier mapp_part_current.altpart_supplier_number%TYPE;

  BEGIN
    FOR rec IN mapp_cur LOOP
      IF (bfirsttime) THEN
        bfirsttime       := FALSE;
/* -- File generation disabled: DI[barcode].txt fopen (FTP sunset)
        out_fhandle      := utl_file.fopen(path,
                                           rec.altpart_supplier_number ||
                                           '.txt',
                                           'w');
-- end commented block */
        altpart_supplier := rec.altpart_supplier_number;
      END IF;

/* -- File generation disabled: DI[barcode].txt write (FTP sunset)
      utl_file.put_line(out_fhandle,
                        rec.service || ',' || rec.barcode || ',' || '"' ||
                        altpart_supplier || '"' || ',' ||
                        rec.reconditioned_flag || ',' || rec.category_cd || ',' ||
                        rec.my_price || ',' || rec.extract_cert_flag || ',' || '"' ||
                        rec.altpart_number || '"' || ',' ||
                        rec.oem_discount_flag);
-- end commented block */
    END LOOP;

/* -- File generation disabled: DI[barcode].txt is_open check (FTP sunset)
    IF utl_file.is_open(out_fhandle) THEN
      utl_file.fclose(out_fhandle);
    END IF;
-- end commented block */
    /*
               pkg_ultramate_common.sp_update_globaltxt_semaphore(path,
                                                                  'global.txt',
                                                                  'a',
                                                                  altpart_supplier || '.txt');
    */
  END;

  /************************************************************************/
  /* Program Name: ext_service                                            */
  /* Author:       MM5095                                                 */
  /* Last Modified: 10/10/2001                                            */
  /* Description: Creates service flat files                              */
  /************************************************************************/
  PROCEDURE ext_service(path       VARCHAR2,
                        edsys_path VARCHAR2,
                        run_type   VARCHAR2)
  --PROCEDURE EXT_SERVICE(path varchar2, full_flag char, restart_flag char)
   IS

    --2008/12/31 PAG - Service Concatenation
    CURSOR service_cur IS
      SELECT /*+ service_cur */
      DISTINCT um.mfr_number,
               um.service_number,
               um.version_type,
               um.country_abbr,
               um.barcode,
               nvl((SELECT c.first_mfr_number
                     FROM race.product_service_concatenation c
                    WHERE c.product_service_barcode =
                          substr(um.barcode, 2, 5)),
                   um.mfr_number) AS mfr1,
               nvl((SELECT c.first_service_number
                     FROM race.product_service_concatenation c
                    WHERE c.product_service_barcode =
                          substr(um.barcode, 2, 5)),
                   um.service_number) AS service1,
               nvl((SELECT c.second_mfr_number
                     FROM race.product_service_concatenation c
                    WHERE c.product_service_barcode =
                          substr(um.barcode, 2, 5)),
                   um.mfr_number) AS mfr2,
               nvl((SELECT c.second_service_number
                     FROM race.product_service_concatenation c
                    WHERE c.product_service_barcode =
                          substr(um.barcode, 2, 5)),
                   um.service_number) AS service2
        FROM tmp_um_extract um
       WHERE um.extract_date IS NULL;

    /*
      cursor service_cur is
      select distinct mfr_number, service_number, version_type, country_abbr
      from tmp_um_extract
      where extract_date is null;
    */

    --2008/12/31 PAG - Service Concatenation

    CURSOR product_cur(mfr_in     VARCHAR2,
                       service_in VARCHAR2,
                       version_in VARCHAR2) IS
      SELECT /*+ product_cur */
       product_code
        FROM tmp_um_extract
       WHERE mfr_number = mfr_in
         AND service_number = service_in
         AND version_type = version_in;
    product_rec product_cur%ROWTYPE;

    -- 07/08/02 mm5095 => note_group_xref fix
    CURSOR note_cur(row_id IN NUMBER, version_in IN VARCHAR2) IS
      SELECT /*+ note_cur */
      DISTINCT a.note_group_skey, b.note_symbol
        FROM note_group_xref a, note_sequence b
       WHERE unique_row_id = row_id
         AND a.note_group_skey = b.note_group_skey
         AND b.version_type = version_in;
    note_rec note_cur%ROWTYPE;

    CURSOR note_cur_wip(row_id IN NUMBER, version_in IN VARCHAR2) IS
      SELECT /*+ note_cur_wip */
      DISTINCT a.note_group_skey, b.note_symbol
        FROM note_group_xref_wip a, note_sequence b
       WHERE unique_row_id = row_id
         AND a.note_group_skey = b.note_group_skey
         AND b.version_type = version_in;
    -- 07/08/02 mm5095 => note_group_xref fix

    CURSOR version_cur(mfr_in     VARCHAR2,
                       service_in VARCHAR2,
                       version_in VARCHAR2) IS
      SELECT /*+ version_cur */
       checkout_date, version_number
        FROM version
       WHERE mfr_number = mfr_in
         AND service_number = service_in
         AND version_type = version_in
       ORDER BY version_number DESC;
    version_rec version_cur%ROWTYPE;

     -- 12/30/2020 rs7649 => added support aftermarket commercial trucks parts
     CURSOR CheckPart (row_id IN NUMBER, version_in IN VARCHAR2) IS
      SELECT 'X' FROM detail_part_xref
       WHERE unique_row_id = row_id
         AND version_type = version_in;

      CURSOR GetAftermarketFlag (row_id IN NUMBER, version_in IN VARCHAR2) IS
       SELECT c.aftermarket_flag
         FROM detail_part_xref a, part b, part_supplier c
        WHERE a.unique_row_id = row_id
         AND a.version_type = version_in
         AND a.part_skey = b.part_skey
         AND c.part_supplier_number = b.part_supplier_number;
          -- 12/30/2020 rs7649 => added support aftermarket commercial trucks parts

    CURSOR s_cur(mfr_in VARCHAR2, service_in VARCHAR2, version_in VARCHAR2) IS
      SELECT /*+ s_cur */
       version_type,
       line_sequence_number * 1000 line_seq,
       category_skey,
       subcategory_skey,
       subcategory_qgroup_skey,
       lower_effectivity_date,
       upper_effectivity_date,
       unique_row_id,
       wip_tran_code,
       0 component_skey,
       substr(sf_getlinetype(subcategory_skey, subcategory_qgroup_skey),
              1,
              1) line_type,
       ' ' indent_level,
       0 detail_qgroup_skey,
       0 qgroup_skey,
       0 note_group_skey,
       ' ' note_symbol,
       0 inline_note_skey,
       ' ' graphic_file_name,
       ' ' callout_number,
       0 labor_operation_skey,
       0 labor_verb_skey,
       ' ' order_by_app_flag,
       ' ' right_left_code,
       ' ' quad_year_range,
       ' ' paint_to_match_flag,
       ' ' shop_materials_required_flag,
       ' ' clearcoat_flag,
       ' ' barcode,
       ' ' prtc,
       'N' delete_flag,
       0 forward_pointer_row_id,
       -- 10/11/2004 mm5095 => added support for hidden lines
       suppression_reason_code,
       -- 10/11/2004 mm5095 => added support for hidden lines
       -- 05/09/2008 mm5095 => added support for mixed case text
       0 component_category_skey,
       -- 12/30/2020 rs7649 => added support aftermarket commercial trucks parts
       0 part_type_id
      -- 05/09/2008 mm5095 => added support for mixed case text
        FROM ext.service_category
       WHERE mfr_number = mfr_in
         AND service_number = service_in
         AND version_type = version_in
         AND (mfr_number, service_number, category_skey)
            -- 11/04/2011 mm5095 => added support for mtd/htd concatenation
             NOT IN (SELECT mfr_number, service_number, category_skey
                       FROM service_category_substitution)
      -- 11/04/2011 mm5095 => added support for mtd/htd concatenation
      -- 12/05/2004 mm5095 => temporarily suppress hidden lines
      --    and bitAnd(suppression_reason_code,1) = 1
      -- 12/05/2004 mm5095 => temporarily suppress hidden lines
      UNION
      SELECT version_type,
             sf_getlinesequencenumber(mfr_in,
                                      service_in,
                                      version_in,
                                      category_skey,
                                      subcategory_skey,
                                      subcategory_qgroup_skey,
                                      line_sequence_number) * 1000 line_seq,
             category_skey,
             subcategory_skey,
             subcategory_qgroup_skey,
             lower_effectivity_date,
             upper_effectivity_date,
             unique_row_id,
             wip_tran_code,
             component_skey,
             line_type,
             indent_level,
             detail_qgroup_skey,
             qgroup_skey,
             note_group_skey,
             note_symbol,
             inline_note_skey,
             graphic_file_name,
             callout_number,
             labor_operation_skey,
             labor_verb_skey,
             order_by_app_flag,
             right_left_code,
             quad_year_range,
             paint_to_match_flag,
             shop_materials_required_flag,
             clearcoat_flag,
             barcode,
             prtc,
             sf_getdeleteflag(delete_flag_date) delete_flag,
             forward_pointer_row_id,
             -- 10/11/2004 mm5095 => added support for hidden lines
             suppression_reason_code,
             -- 10/11/2004 mm5095 => added support for hidden lines
             -- 05/09/2008 mm5095 => added support for mixed case text
             component_category_skey,
             -- 12/30/2020 rs7649 => added support aftermarket commercial trucks parts
             0 part_type_id
      -- 05/09/2008 mm5095 => added support for mixed case text
        FROM ext.service_category_detail
       WHERE mfr_number = mfr_in
         AND service_number = service_in
         AND version_type = version_in
         AND line_type NOT IN ('F', 'L')
            -- 11/04/2011 mm5095 => added support for mtd/htd concatenation
         AND (mfr_number, service_number, category_skey) NOT IN
             (SELECT mfr_number, service_number, category_skey
                FROM service_category_substitution)
      -- 11/04/2011 mm5095 => added support for mtd/htd concatenation
      -- 12/05/2004 mm5095 => temporarily suppress hidden lines
      --    and bitAnd(suppression_reason_code,1) = 1
      -- 12/05/2004 mm5095 => temporarily suppress hidden lines
      -- 11/04/2011 mm5095 => added support for mtd/htd concatenation
      UNION
      SELECT b.version_type,
             c.line_sequence_number * 1000 + b.line_sequence_number line_seq,
             b.category_skey,
             b.subcategory_skey,
             b.subcategory_qgroup_skey,
             b.lower_effectivity_date,
             b.upper_effectivity_date,
             b.unique_row_id,
             b.wip_tran_code,
             0 component_skey,
             substr(sf_getlinetype(b.subcategory_skey,
                                   b.subcategory_qgroup_skey),
                    1,
                    1) line_type,
             ' ' indent_level,
             0 detail_qgroup_skey,
             0 qgroup_skey,
             0 note_group_skey,
             ' ' note_symbol,
             0 inline_note_skey,
             ' ' graphic_file_name,
             ' ' callout_number,
             0 labor_operation_skey,
             0 labor_verb_skey,
             ' ' order_by_app_flag,
             ' ' right_left_code,
             ' ' quad_year_range,
             ' ' paint_to_match_flag,
             ' ' shop_materials_required_flag,
             ' ' clearcoat_flag,
             ' ' barcode,
             ' ' prtc,
             'N' delete_flag,
             0 forward_pointer_row_id,
             -- 10/11/2004 mm5095 => added support for hidden lines
             b.suppression_reason_code,
             -- 10/11/2004 mm5095 => added support for hidden lines
             -- 05/09/2008 mm5095 => added support for mixed case text
             0 component_category_skey,
             -- 12/30/2020 rs7649 => added support aftermarket commercial trucks parts
             0 part_type_id
      -- 05/09/2008 mm5095 => added support for mixed case text
        FROM service_category_substitution a
       INNER JOIN service_category b
          ON b.mfr_number = a.substitute_mfr_number
         AND b.service_number = a.substitute_service_number
         AND b.version_type = version_in
       INNER JOIN service_category c
          ON c.mfr_number = a.mfr_number
         AND c.service_number = a.service_number
         AND c.version_type = version_in
         AND c.category_skey = a.category_skey
         AND c.subcategory_skey = 0
         AND c.subcategory_qgroup_skey = 0
       WHERE a.mfr_number = mfr_in
         AND a.service_number = service_in
         AND b.category_skey = a.substitute_category_skey
         AND ((b.subcategory_skey = 0 OR
             b.subcategory_skey = a.substitute_subcategory_skey) OR
             a.all_subcategory_flag = 'Y')
      -- 12/05/2004 mm5095 => temporarily suppress hidden lines
      --    and bitAnd(suppression_reason_code,1) = 1
      -- 12/05/2004 mm5095 => temporarily suppress hidden lines
      UNION
      SELECT b.version_type,
             c.line_sequence_number * 1000 +
             sf_getlinesequencenumber(b.mfr_number,
                                      b.service_number,
                                      b.version_type,
                                      b.category_skey,
                                      b.subcategory_skey,
                                      b.subcategory_qgroup_skey,
                                      b.line_sequence_number),
             b.category_skey,
             b.subcategory_skey,
             b.subcategory_qgroup_skey,
             b.lower_effectivity_date,
             b.upper_effectivity_date,
             b.unique_row_id,
             b.wip_tran_code,
             component_skey,
             line_type,
             indent_level,
             detail_qgroup_skey,
             qgroup_skey,
             note_group_skey,
             note_symbol,
             inline_note_skey,
             graphic_file_name,
             callout_number,
             labor_operation_skey,
             labor_verb_skey,
             order_by_app_flag,
             right_left_code,
             quad_year_range,
             paint_to_match_flag,
             shop_materials_required_flag,
             clearcoat_flag,
             barcode,
             prtc,
             sf_getdeleteflag(delete_flag_date) delete_flag,
             forward_pointer_row_id,
             -- 10/11/2004 mm5095 => added support for hidden lines
             b.suppression_reason_code,
             -- 10/11/2004 mm5095 => added support for hidden lines
             -- 05/09/2008 mm5095 => added support for mixed case text
             component_category_skey,
             -- 12/30/2020 rs7649 => added support aftermarket commercial trucks parts
             0 part_type_id
      -- 05/09/2008 mm5095 => added support for mixed case text
        FROM service_category_substitution a
       INNER JOIN service_category_detail b
          ON b.mfr_number = a.substitute_mfr_number
         AND b.service_number = a.substitute_service_number
         AND b.version_type = version_in
       INNER JOIN service_category c
          ON c.mfr_number = a.mfr_number
         AND c.service_number = a.service_number
         AND c.version_type = version_in
         AND c.category_skey = a.category_skey
         AND c.subcategory_skey = 0
         AND c.subcategory_qgroup_skey = 0
       WHERE a.mfr_number = mfr_in
         AND a.service_number = service_in
         AND b.category_skey = a.substitute_category_skey
         AND ((b.subcategory_skey = 0 OR
             b.subcategory_skey = a.substitute_subcategory_skey) OR
             a.all_subcategory_flag = 'Y')
            -- 12/05/2004 mm5095 => temporarily suppress hidden lines
            --    and bitAnd(suppression_reason_code,1) = 1
            -- 12/05/2004 mm5095 => temporarily suppress hidden lines
         AND line_type NOT IN ('F', 'L')
      -- 11/04/2011 mm5095 => added support for mtd/htd concatenation
       ORDER BY line_seq;

    TYPE service_table_type IS TABLE OF s_cur%ROWTYPE INDEX BY BINARY_INTEGER;
    service_table       service_table_type;
    empty_service_table service_table_type;

    resequence NUMBER;
    note_type  NUMBER;
    note_id    NUMBER;

    nheader      INTEGER;
    nsection     INTEGER;
    npart        INTEGER;
    npart_detail INTEGER;
    nimage       INTEGER;
    nimage_pre   INTEGER;

    start_date            VARCHAR2(8);
    end_date              VARCHAR2(8);
    graphic_file_name     VARCHAR2(255) := ' ';
    graphic_file_name_pre VARCHAR2(255);
    callout_number_pre    VARCHAR2(3) := ' ';
    --  indent_level_pre varchar2(2) := ' ';
    --  labor_verb_skey_pre number := 0;
    --  component_skey_pre number := 0;
    --  part_inline_note_skey number := 0;
    savedetailnote VARCHAR2(12);
    bdummysection  BOOLEAN;

    labor_time        NUMBER(5, 2);
    rightoverhaultime NUMBER(5, 2);
    leftoverhaultime  NUMBER(5, 2);

    header_fhandle        utl_file.file_type;
    section_fhandle       utl_file.file_type;
    part_fhandle          utl_file.file_type;
    detail_fhandle        utl_file.file_type;
    hotspot_fhandle       utl_file.file_type;
    color_hotspot_fhandle utl_file.file_type;
    pnote_fhandle         utl_file.file_type;
    dtnote_fhandle        utl_file.file_type;
    graphic_fhandle       utl_file.file_type;
    color_graphic_fhandle utl_file.file_type;
    out_fhandle           utl_file.file_type;

    -- 11/16/2004 mm5095 => added support for rr_vs_repair
    rr_fhandle utl_file.file_type;
    -- 11/16/2004 mm5095 => added support for rr_vs_repair

    service_barcode     VARCHAR2(6);
    vvc2_procedure_name VARCHAR2(40);

    -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
    header_sequence NUMBER := 0;
    header_offset   NUMBER := 0;
    ceg_offset      NUMBER := 0;
    -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5

    -- 12/30/2020 rs7649 => added support aftermarket commercial trucks parts
    PartCheck       VARCHAR2(1);
    Aftermarket_flag       VARCHAR2(1);
    -- 12/30/2020 rs7649 => added support aftermarket commercial trucks parts

    -- 2008/12/31 PAG - Older commented sections of code removed
    --                 to reduce package size and improve readability.
    --                 Check prior PVCS version, if you want to view this code.
    /*
    *  Per meeting with Greg McDowell, Genie Young, Auden Miller and Penny Genovese on March 5, 2003,
    *  capa certified flag assignment rules are as follows:
    *
    *  if the part_supplier_number and part_number are found in part_capa_xref table with capa_certified_flag = 'Y'
    *    and the alternate_part capa_certified_flag = 'Y'
    *    and the category_code, found using prtc_body and reconditioned_code, has capa_certified_flag = 'Y'
    *    and the alternate_part reconditioned_flag = 'N' then
    *    capa_certified_flag = 'Y'
    *  else
    *    capa_certified_flag = 'N'
    *  end if;
    */
    -- 2008/12/31 PAG - Older commented sections of code removed

    FUNCTION getqualifiernotestring(n           INTEGER,
                                    current_row INTEGER,
                                    indent_in   VARCHAR2,
                                    bpartflag   BOOLEAN) RETURN VARCHAR2 IS
      vvc2_return VARCHAR2(160);
    BEGIN
      vvc2_return := pkg_ultramate_common.sf_getqualifierstring(service_table(n).qgroup_skey,
                                                                indent_in,
                                                                bpartflag);

      IF nvl(service_table(n).inline_note_skey, 0) > 0 AND
         nvl(service_table(current_row).inline_note_skey, 0) !=
         nvl(service_table(n).inline_note_skey, 0) THEN
        vvc2_return := rtrim(vvc2_return ||
                             pkg_ultramate_common.sf_getnote_by_skey(service_table(n).inline_note_skey));
      END IF;

      RETURN vvc2_return;
    END;

    FUNCTION inpartset(n INTEGER, current_row INTEGER) RETURN BOOLEAN IS
    BEGIN
      IF service_table(n)
       .line_type NOT IN ('A', 'G', 'F') OR
          nvl(service_table(n).category_skey, 0) !=
          nvl(service_table(current_row).category_skey, 0) OR
          nvl(service_table(n).subcategory_skey, 0) !=
          nvl(service_table(current_row).subcategory_skey, 0) OR
          nvl(service_table(n).subcategory_qgroup_skey, 0) !=
          nvl(service_table(current_row).subcategory_qgroup_skey, 0) OR
          (nvl(service_table(n).indent_level, ' ') = '0' AND
           (nvl(service_table(n).component_skey, 0) !=
            nvl(service_table(current_row).component_skey, 0) OR
            nvl(service_table(n).qgroup_skey, 0) !=
            nvl(service_table(current_row).qgroup_skey, 0)))
         -- 08/06/02 mm5095 fix: not outputing all detail lines
         --      or ( nvl(service_table(n).indent_level,' ') = nvl(service_table(current_row).indent_level,' ')
         --          and ( nvl(service_table(n).component_skey,0) != nvl(service_table(current_row).component_skey,0)
         --               or nvl(service_table(n).qgroup_skey,0) != nvl(service_table(current_row).qgroup_skey,0) ) )
         -- 08/06/02 mm5095 fix: not outputing all detail lines
         OR (n != current_row AND
             nvl(service_table(n).callout_number, ' ') != ' ') OR
          (n != current_row AND
           nvl(service_table(n).indent_level, ' ') =
           nvl(service_table(current_row).indent_level, ' ') AND
           (nvl(service_table(current_row).inline_note_skey, 0) > 0 OR
           nvl(service_table(n).inline_note_skey, 0) > 0)) THEN
        RETURN FALSE;
      ELSE
        RETURN TRUE;
      END IF;
    END;

    FUNCTION inlaborset(n INTEGER, current_row INTEGER) RETURN BOOLEAN IS
    BEGIN
      -- 01/07/03 mm5095: fix 'C' lines not showing after 'N' lines
      IF service_table(n)
       .line_type NOT IN ('L', 'N')
         --    if service_table(n).line_type not in ('C','L','N')
         -- 01/07/03 mm5095: fix 'C' lines not showing after 'N' lines
         OR nvl(service_table(n).category_skey, 0) !=
          nvl(service_table(current_row).category_skey, 0) OR
          nvl(service_table(n).subcategory_skey, 0) !=
          nvl(service_table(current_row).subcategory_skey, 0) OR
          nvl(service_table(n).subcategory_qgroup_skey, 0) !=
          nvl(service_table(current_row).subcategory_qgroup_skey, 0) OR
          (nvl(service_table(n).indent_level, ' ') = '0' AND
           (nvl(service_table(n).labor_verb_skey, 0) !=
            nvl(service_table(current_row).labor_verb_skey, 0) OR
            nvl(service_table(n).component_skey, 0) !=
            nvl(service_table(current_row).component_skey, 0) OR
            nvl(service_table(n).qgroup_skey, 0) !=
            nvl(service_table(current_row).qgroup_skey, 0))) THEN
        RETURN FALSE;
      ELSE
        RETURN TRUE;
      END IF;
    END;

    -- 2008/12/31 pg2697 => getLaborVerb is not used
    --  FUNCTION getLaborVerb(row_in integer, bFlag boolean)
    --  RETURN varchar2
    --  IS
    --    vvc2_return varchar2(200);
    --  BEGIN
    --    if nvl(service_table(row_in).labor_verb_skey,0) > 0 then
    --      vvc2_return := PKG_ULTRAMATE_COMMON.sf_getLaborVerbString(service_table(row_in).labor_verb_skey);
    --    end if;

    --    if bFlag and nvl(service_table(row_in).inline_note_skey,0) > 0 then
    --      if vvc2_return is not null then
    --        vvc2_return := rtrim(vvc2_return) || PKG_ULTRAMATE_COMMON.sf_getNote_by_Skey(service_table(row_in).inline_note_skey);

    --      else
    --        vvc2_return := PKG_ULTRAMATE_COMMON.sf_getNote_by_Skey(service_table(row_in).inline_note_skey);
    --      end if;
    --    end if;
    --    return rtrim(vvc2_return);
    --  END getLaborVerb;

    -- 2008/12/31 pg2697 => getComponent is not used
    --  FUNCTION getComponent(row_in integer, bFlag boolean)
    --  RETURN varchar2
    --  IS
    --    vvc2_return varchar2(200);
    --  BEGIN
    --    if nvl(service_table(row_in).component_skey,0) > 0 then
    --      vvc2_return := PKG_ULTRAMATE_COMMON.sf_getReverseString(PKG_ULTRAMATE_COMMON.sf_getComponentString(service_table(row_in).component_skey));
    --    end if;

    --    if bFlag and nvl(service_table(row_in).inline_note_skey,0) > 0 then
    --      if vvc2_return is not null then
    --        vvc2_return := rtrim(vvc2_return) || PKG_ULTRAMATE_COMMON.sf_getNote_by_Skey(service_table(row_in).inline_note_skey);
    --      else
    --        vvc2_return := PKG_ULTRAMATE_COMMON.sf_getNote_by_Skey(service_table(row_in).inline_note_skey);
    --      end if;
    --    end if;

    --    return rtrim(vvc2_return);
    --  END getComponent;

    FUNCTION getcomponentqualifier(row_in INTEGER, bflag BOOLEAN)
      RETURN VARCHAR2 IS
      vvc2_return VARCHAR2(200);
    BEGIN
      IF nvl(service_table(row_in).component_skey, 0) > 0 THEN
        vvc2_return := pkg_ultramate_common.sf_getcomponentstring(service_table(row_in).component_skey);
      END IF;

      IF nvl(service_table(row_in).qgroup_skey, 0) > 0 THEN
        IF vvc2_return IS NOT NULL THEN
          vvc2_return := rtrim(vvc2_return) || ' ' ||
                         pkg_ultramate_common.sf_getqualifierstring(service_table(row_in).qgroup_skey,
                                                                    '1',
                                                                    FALSE);
        ELSE
          vvc2_return := pkg_ultramate_common.sf_getqualifierstring(service_table(row_in).qgroup_skey,
                                                                    '1',
                                                                    FALSE);
        END IF;
      END IF;

      IF bflag AND nvl(service_table(row_in).inline_note_skey, 0) > 0 THEN
        IF vvc2_return IS NOT NULL THEN
          vvc2_return := rtrim(vvc2_return) ||
                         pkg_ultramate_common.sf_getnote_by_skey(service_table(row_in).inline_note_skey);
        ELSE
          vvc2_return := pkg_ultramate_common.sf_getnote_by_skey(service_table(row_in).inline_note_skey);
        END IF;
      END IF;

      RETURN rtrim(vvc2_return);
    END;

    FUNCTION getlaborverbcomponent(row_in INTEGER, bflag BOOLEAN)
      RETURN VARCHAR2 IS
      vvc2_return VARCHAR2(200);
    BEGIN

      IF nvl(service_table(row_in).labor_verb_skey, 0) > 0 THEN
        vvc2_return := pkg_ultramate_common.sf_getlaborverbstring(service_table(row_in).labor_verb_skey);
      END IF;

      IF nvl(service_table(row_in).component_skey, 0) > 0 THEN
        IF vvc2_return IS NOT NULL THEN
          vvc2_return := rtrim(vvc2_return) || ' ' ||
                         pkg_ultramate_common.sf_getcomponentstring(service_table(row_in).component_skey);
        ELSE
          vvc2_return := pkg_ultramate_common.sf_getcomponentstring(service_table(row_in).component_skey);
        END IF;
      END IF;

      IF bflag AND nvl(service_table(row_in).inline_note_skey, 0) > 0 THEN
        IF vvc2_return IS NOT NULL THEN
          vvc2_return := rtrim(vvc2_return) ||
                         pkg_ultramate_common.sf_getnote_by_skey(service_table(row_in).inline_note_skey);
        ELSE
          vvc2_return := pkg_ultramate_common.sf_getnote_by_skey(service_table(row_in).inline_note_skey);
        END IF;
      END IF;

      RETURN rtrim(vvc2_return);
    END;

    FUNCTION getparttext(row_in          INTEGER,
                         indent_level_in VARCHAR2,
                         bnoteflag       BOOLEAN,
                         byear           BOOLEAN := FALSE) RETURN VARCHAR2 IS
      vvc2_return VARCHAR2(200);
      vvc2_temp   VARCHAR2(200);
    BEGIN
      IF nvl(service_table(row_in).component_skey, 0) > 0 THEN
        vvc2_return := pkg_ultramate_common.sf_getreversestring(pkg_ultramate_common.sf_getcomponentstring(service_table(row_in).component_skey));
      END IF;

      IF nvl(service_table(row_in).qgroup_skey, 0) > 0 THEN
        vvc2_temp := pkg_ultramate_common.sf_getqualifierstring(service_table(row_in).qgroup_skey,
                                                                indent_level_in,
                                                                byear);
        IF vvc2_return IS NOT NULL THEN
          IF substr(vvc2_temp, 1, 1) = '(' THEN
            vvc2_return := rtrim(vvc2_return) || vvc2_temp;
          ELSE
            vvc2_return := rtrim(vvc2_return) || ' ' || vvc2_temp;
          END IF;
        ELSE
          vvc2_return := vvc2_temp;
        END IF;
      END IF;

      IF bnoteflag AND nvl(service_table(row_in).inline_note_skey, 0) > 0 THEN
        IF vvc2_return IS NOT NULL THEN
          vvc2_return := rtrim(vvc2_return) ||
                         pkg_ultramate_common.sf_getnote_by_skey(service_table(row_in).inline_note_skey);
        ELSE
          vvc2_return := pkg_ultramate_common.sf_getnote_by_skey(service_table(row_in).inline_note_skey);
        END IF;
      END IF;

      RETURN rtrim(vvc2_return);
    END;

    PROCEDURE addpointdelete(out_fhandle     IN OUT utl_file.file_type,
                             barcode         IN VARCHAR2,
                             resequence      IN NUMBER,
                             note_text       IN VARCHAR2,
                             smartprtc       IN NUMBER,
                             header_sequence NUMBER) AS
      --  PROCEDURE addPointDelete(out_fhandle in out utl_file.file_type, barcode in varchar2,
      --              resequence in number, note_text in varchar2, smartprtc in number) as
      -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
      -- 09/28/2015 mm5095
      line_text_skey number;
      -- 09/28/2015 mm5095

    BEGIN
      -- 09/28/2015 mm5095
      line_text_skey := sf_get_line_text_skey(upper(note_text), note_text);
      -- 09/28/2015 mm5095

/* -- File generation disabled: DI[barcode].txt write (FTP sunset)
      utl_file.put_line(out_fhandle,
                        0 || '|' || 0 || '|' || 0 || '|' || barcode || '|' ||
                         resequence || '|' || 'F' || '|' || '' || '|' || '' || '|' || 1 || '|' || 0 || '|' || 1 || '|' || 48 || '|' || '' || '|' || '' || '|' || '' || '|' ||
                         note_text || '|' || 0 || '|' || 0 || '|' || 0 || '|' || 0 || '|' || 0 || '|' || 0 || '|' || 0 || '|' || 0 || '|' || 0 || '|' ||
                         smartprtc
                        -- 10/11/2004 mm5095 => added support for hidden lines
                         || '|1'
                        -- 10/11/2004 mm5095 => added support for hidden lines
                        -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
                         || '|' || header_sequence
                        -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
                        -- 2008/12/31 PG => added special material qualifier support that MM added in parse routine 08/17/2007
                         || '|' || note_text
                        -- 2008/12/31 PG => added special material qualifier support that MM added in parse routine 08/17/2007
                        -- 09/28/2015 mm5095
                         || '|0' --special_material_flag
                         || '|' ||
                         pkg_ultramate_common.sf_getmixedcase(note_text) || '|' ||
                         line_text_skey || '|' || line_text_skey
                        -- 09/28/2015 mm5095
                        -- 03/04/2017 mm5095
                         || '|'
                        -- 03/04/2017 mm5095
                        -- 02/09/2017 mm5095
                         || '|' ||
                         pkg_ultramate_common.sf_getfrench(line_text_skey,
                                                           pkg_ultramate_common.sf_getmixedcase(note_text))
                        -- 02/09/2017 mm5095
                        );
-- end commented block */
    END;

    -- 09/22/2009 mm5095: added to support color graphics
    PROCEDURE addgraphic(graphic_file_name_in VARCHAR2,
                         callout_number_in    VARCHAR2,
                         nimage_in            NUMBER) IS
      CURSOR graphic_cur(graphic_in   VARCHAR2,
                         extension_in VARCHAR2,
                         callout_in   VARCHAR2) IS
        SELECT /*+ graphic_cur */
         *
          FROM hotspot
         WHERE graphic_file_name = graphic_in || extension_in
           AND callout_number = callout_in;
      graphic_rec graphic_cur%ROWTYPE;

      CURSOR graphic_png_cur(graphic_in   VARCHAR2,
                             extension_in VARCHAR2,
                             callout_in   VARCHAR2) IS
        SELECT /*+ graphic_cur */
         a.*
          FROM hotspot a, special_material_graphic b
         WHERE a.graphic_file_name = graphic_in || extension_in
           AND callout_number = callout_in
           AND b.graphic_file_name = a.graphic_file_name;

    BEGIN
      IF callout_number_in != callout_number_pre THEN
        OPEN graphic_cur(graphic_file_name_in, '.tif', callout_number_in);
        FETCH graphic_cur
          INTO graphic_rec;
        IF graphic_cur%FOUND THEN
          WHILE graphic_cur%FOUND LOOP
/* -- File generation disabled: DE[barcode].txt write (FTP sunset)
            utl_file.put_line(hotspot_fhandle,
                              nheader || '|' || nsection || '|' || npart || '|' ||
                              nimage_in || '|' || callout_number_in || '|' ||
                              graphic_rec.x_coordinate || '|' ||
                              graphic_rec.y_coordinate || '|' ||
                              graphic_rec.x_extent || '|' ||
                              graphic_rec.y_extent);
-- end commented block */
            -- 04/05/2018 pb0690 => added
            pkg_ultramate_common.insert_um_data_de(to_char(service_barcode_in),
                                                   nheader,
                                                   nsection,
                                                   npart,
                                                   nimage_in,
                                                   callout_number_in,
                                                   graphic_rec.x_coordinate,
                                                   graphic_rec.y_coordinate,
                                                   graphic_rec.x_extent,
                                                   graphic_rec.y_extent);

            FETCH graphic_cur
              INTO graphic_rec;
          END LOOP;
          CLOSE graphic_cur;
        ELSE
          CLOSE graphic_cur;
          IF bconsecutive_graphics THEN
            -- check if callout number found in previous graphic_file_name
            OPEN graphic_cur(graphic_file_name_pre,
                             '.tif',
                             callout_number_in);
            FETCH graphic_cur
              INTO graphic_rec;
            IF graphic_cur%FOUND THEN
              WHILE graphic_cur%FOUND LOOP
/* -- File generation disabled: DE[barcode].txt write (FTP sunset)
                utl_file.put_line(hotspot_fhandle,
                                  nheader || '|' || nsection || '|' ||
                                  npart || '|' || nimage_pre || '|' ||
                                  callout_number_in || '|' ||
                                  graphic_rec.x_coordinate || '|' ||
                                  graphic_rec.y_coordinate || '|' ||
                                  graphic_rec.x_extent || '|' ||
                                  graphic_rec.y_extent);
-- end commented block */
                -- 04/05/2018 pb0690 => added
                pkg_ultramate_common.insert_um_data_de(to_char(service_barcode_in),
                                                       nheader,
                                                       nsection,
                                                       npart,
                                                       nimage_pre,
                                                       callout_number_in,
                                                       graphic_rec.x_coordinate,
                                                       graphic_rec.y_coordinate,
                                                       graphic_rec.x_extent,
                                                       graphic_rec.y_extent);

                FETCH graphic_cur
                  INTO graphic_rec;
              END LOOP;
            END IF;
            CLOSE graphic_cur;
          ELSE
            -- create dummy hotspot
/* -- File generation disabled: DE[barcode].txt write (FTP sunset)
            utl_file.put_line(hotspot_fhandle,
                              nheader || '|' || nsection || '|' || npart || '|' ||
                              nimage_in || '|' || callout_number_in || '|' || -100 || '|' || -100 || '|' || 0 || '|' || 0);
-- end commented block */

            -- 04/05/2018 pb0690 => added
            pkg_ultramate_common.insert_um_data_de(to_char(service_barcode_in),
                                                   nheader,
                                                   nsection,
                                                   npart,
                                                   nimage_in,
                                                   callout_number_in,
                                                   -100,
                                                   -100,
                                                   0,
                                                   0);
          END IF;
        END IF;
      END IF;

      IF callout_number_in != callout_number_pre THEN
        OPEN graphic_png_cur(graphic_file_name_in,
                             '.png',
                             callout_number_in);
        FETCH graphic_png_cur
          INTO graphic_rec;
        IF graphic_png_cur%FOUND THEN
          WHILE graphic_png_cur%FOUND LOOP
/* -- File generation disabled: DN[barcode].txt write (FTP sunset)
            utl_file.put_line(color_hotspot_fhandle,
                              nheader || '|' || nsection || '|' || npart || '|' ||
                              nimage_in || '|' || callout_number_in || '|' ||
                              graphic_rec.x_coordinate || '|' ||
                              graphic_rec.y_coordinate || '|' ||
                              graphic_rec.x_extent || '|' ||
                              graphic_rec.y_extent);
-- end commented block */
            FETCH graphic_png_cur
              INTO graphic_rec;
          END LOOP;
          CLOSE graphic_png_cur;
        ELSE
          CLOSE graphic_png_cur;
          IF bconsecutive_graphics THEN
            -- check if callout number found in previous graphic_file_name
            OPEN graphic_png_cur(graphic_file_name_pre,
                                 '.png',
                                 callout_number_in);
            FETCH graphic_png_cur
              INTO graphic_rec;
            IF graphic_png_cur%FOUND THEN
              WHILE graphic_png_cur%FOUND LOOP
/* -- File generation disabled: DN[barcode].txt write (FTP sunset)
                utl_file.put_line(color_hotspot_fhandle,
                                  nheader || '|' || nsection || '|' ||
                                  npart || '|' || nimage_pre || '|' ||
                                  callout_number_in || '|' ||
                                  graphic_rec.x_coordinate || '|' ||
                                  graphic_rec.y_coordinate || '|' ||
                                  graphic_rec.x_extent || '|' ||
                                  graphic_rec.y_extent);
-- end commented block */
                FETCH graphic_png_cur
                  INTO graphic_rec;
              END LOOP;
            END IF;
            CLOSE graphic_png_cur;
          ELSE
            -- color graphic not found, use black and white
            OPEN graphic_cur(graphic_file_name_in,
                             '.tif',
                             callout_number_in);
            FETCH graphic_cur
              INTO graphic_rec;
            IF graphic_cur%FOUND THEN
              WHILE graphic_cur%FOUND LOOP
/* -- File generation disabled: DN[barcode].txt write (FTP sunset)
                utl_file.put_line(color_hotspot_fhandle,
                                  nheader || '|' || nsection || '|' ||
                                  npart || '|' || nimage_in || '|' ||
                                  callout_number_in || '|' ||
                                  graphic_rec.x_coordinate || '|' ||
                                  graphic_rec.y_coordinate || '|' ||
                                  graphic_rec.x_extent || '|' ||
                                  graphic_rec.y_extent);
-- end commented block */
                FETCH graphic_cur
                  INTO graphic_rec;
              END LOOP;
              CLOSE graphic_cur;
            ELSE
              CLOSE graphic_cur;
              IF bconsecutive_graphics THEN
                -- check if callout number found in previous graphic_file_name
                OPEN graphic_cur(graphic_file_name_pre,
                                 '.tif',
                                 callout_number_in);
                FETCH graphic_cur
                  INTO graphic_rec;
                IF graphic_cur%FOUND THEN
                  WHILE graphic_cur%FOUND LOOP
/* -- File generation disabled: DN[barcode].txt write (FTP sunset)
                    utl_file.put_line(color_hotspot_fhandle,
                                      nheader || '|' || nsection || '|' ||
                                      npart || '|' || nimage_pre || '|' ||
                                      callout_number_in || '|' ||
                                      graphic_rec.x_coordinate || '|' ||
                                      graphic_rec.y_coordinate || '|' ||
                                      graphic_rec.x_extent || '|' ||
                                      graphic_rec.y_extent);
-- end commented block */
                    FETCH graphic_cur
                      INTO graphic_rec;
                  END LOOP;
                END IF;
                CLOSE graphic_cur;
              ELSE
                -- create dummy hotspot
/* -- File generation disabled: DN[barcode].txt write (FTP sunset)
                utl_file.put_line(color_hotspot_fhandle,
                                  nheader || '|' || nsection || '|' ||
                                  npart || '|' || nimage_in || '|' ||
                                  callout_number_in || '|' || -100 || '|' || -100 || '|' || 0 || '|' || 0);
-- end commented block */
                NULL; -- FTP sunset: placeholder for disabled put_line
              END IF;
            END IF;
          END IF;
        END IF;
      END IF;
      callout_number_pre := callout_number_in;
    EXCEPTION
      WHEN OTHERS THEN
        dbms_output.put_line('Error code ' || SQLCODE || ': ' ||
                             substr(SQLERRM, 1, 64));
    END;

    /*
      PROCEDURE AddGraphic(graphic_file_name_in varchar2, callout_number_in varchar2, nimage_in number)
      IS
        cursor graphic_cur (graphic_in varchar2, callout_in varchar2) is
        select *
        from hotspot
        where graphic_file_name = graphic_in
        and callout_number = callout_in;
        graphic_rec graphic_cur%ROWTYPE;
      BEGIN
        if callout_number_in != callout_number_pre then
          open graphic_cur(graphic_file_name_in, callout_number_in);
          fetch graphic_cur into graphic_rec;
          if graphic_cur%FOUND then
            while graphic_cur%FOUND LOOP
              utl_file.put_line(hotspot_fhandle, nheader || '|' || nsection || '|' || npart || '|'
                ||  nimage_in || '|' || callout_number_in || '|'
                || graphic_rec.x_coordinate || '|' || graphic_rec.y_coordinate || '|' || graphic_rec.x_extent || '|' || graphic_rec.y_extent);
              fetch graphic_cur into graphic_rec;
            END LOOP;
            close graphic_cur;
          else
            close graphic_cur;
            if bConsecutive_graphics then
              -- check if callout number found in previous graphic_file_name
              open graphic_cur(graphic_file_name_pre, callout_number_in);
              fetch graphic_cur into graphic_rec;
              if graphic_cur%FOUND then
                while graphic_cur%FOUND LOOP
                  utl_file.put_line(hotspot_fhandle, nheader || '|' || nsection || '|' || npart || '|'
                    ||  nimage_pre || '|' || callout_number_in || '|'
                    || graphic_rec.x_coordinate || '|' || graphic_rec.y_coordinate || '|' || graphic_rec.x_extent || '|' || graphic_rec.y_extent);
                  fetch graphic_cur into graphic_rec;
                END LOOP;
              end if;
              close graphic_cur;
            else
              -- create dummy hotspot
              utl_file.put_line(hotspot_fhandle, nheader || '|' || nsection || '|' || npart || '|'
                || nimage_in || '|' || callout_number_in || '|'
                || -100 || '|' || -100 || '|' || 0 || '|' || 0);
            end if;
          end if;
        end if;
        callout_number_pre := callout_number_in;
      END;
    */
    -- 09/22/2009 mm5095: added to support color graphics

    PROCEDURE addsection(row_in      NUMBER,
                         subcat_text VARCHAR2,
                         bdateflag   BOOLEAN := FALSE) IS
      start_date_ret VARCHAR2(8) := -1;
      end_date_ret   VARCHAR2(8) := -1;
      -- 04/05/2018 pb0690 => added these 2 variables
      local_start_date DATE;
      local_end_date   DATE;

      -- 05/09/2008 mm5095 => added support for mixed case Category description
      mc_subcategory subcat_description.mixed_case_subcat_name%TYPE;
      -- 05/09/2008 mm5095 => added support for mixed case Category description

      -- 09/28/2015 mm5095
      line_text_skey number;
      -- 09/28/2015 mm5095

    BEGIN
      nsection := nsection + 1;
      -- 09/04/02 mm5095 => commented out to fix VCI problem
      --    npart := 0;
      -- 09/04/02 mm5095 => commented out to fix VCI problem
      rightoverhaultime  := 0;
      leftoverhaultime   := 0;
      callout_number_pre := ' ';

      -- 05/09/2008 mm5095 => added support for mixed case Category description
      mc_subcategory := pkg_ultramate_common.sf_getmixedcasesubcategory(rtrim(subcat_text));
      -- 05/09/2008 mm5095 => added support for mixed case Category description

      IF bdateflag THEN
        pkg_ultramate_common.getstartenddate(service_table (row_in).lower_effectivity_date,
                                             service_table (row_in).upper_effectivity_date,
                                             start_date_ret,
                                             end_date_ret);
        --      getStartEndDate(service_table(row_in).lower_effectivity_date, service_table(row_in).upper_effectivity_date, start_date_ret, end_date_ret, false);
        -- 04/05/2018 pb0690 => added to values these 2 variables
        local_start_date := service_table(row_in).lower_effectivity_date;
        local_end_date   := service_table(row_in).upper_effectivity_date;

      END IF;

      line_text_skey := sf_get_line_text_skey(rtrim(subcat_text),
                                              mc_subcategory);

/* -- File generation disabled: DB[barcode].txt write (FTP sunset)
      utl_file.put_line(section_fhandle,
                        nheader || '|' || nsection || '|' || start_date_ret || '|' ||
                         end_date_ret || '|' || rtrim(subcat_text) || '|' || service_table(row_in).suppression_reason_code
                        -- 05/09/2008 mm5095 => added support for mixed case Category description
                         || '|' || mc_subcategory
                        -- 05/09/2008 mm5095 => added support for mixed case Category description
                        -- 09/28/2015 mm5095
                         || '|' || line_text_skey
                        -- 09/28/2015 mm5095
                        -- 02/09/2017 mm5095
                         || '|' ||
                         pkg_ultramate_common.sf_getfrench(line_text_skey,
                                                           mc_subcategory)
                        -- 02/09/2017 mm5095
                        );
-- end commented block */

      -- 04/05/2018 pb0690 => added
      BEGIN
        INSERT /*+ EXT_REFSHEET.um_data_db_insert */
        INTO um_data_db
          (service,
           category_skey,
           subcategory_skey,
           start_date,
           end_date,
           subcategory,
           suppression_code,
           last_update_user,
           last_update_date)
        VALUES
          (to_char(service_barcode_in),
           nheader,
           nsection,
           local_start_date, --service_table(row_in).lower_effectivity_date,
           local_end_date, --service_table(row_in).upper_effectivity_date,
           rtrim(subcat_text),
           service_table(row_in).suppression_reason_code,
           USER,
           SYSDATE);
      EXCEPTION
        WHEN OTHERS THEN
          dbms_output.put_line('Pre-parse error inserting into um_data_db');
      END;
    END;

    PROCEDURE addpart(callout_number_in       VARCHAR2,
                      text_in                 VARCHAR2,
                      row_in                  INTEGER,
                      suppression_reason_code INTEGER) IS
      my_text VARCHAR2(200);

      -- 09/28/2015 mm5095
      line_text_skey number;
      -- 09/28/2015
    BEGIN
      my_text := rtrim(ltrim(text_in));

      IF nsection = 0 THEN
        -- add dummy section
        bdummysection := TRUE;
        addsection(row_in,
                   pkg_ultramate_common.sf_getcategorystring(service_table(row_in).category_skey));
      END IF;

      npart := npart + 1;

      line_text_skey := sf_get_line_text_skey(my_text, my_text);

/* -- File generation disabled: DC[barcode].txt write (FTP sunset)
      utl_file.put_line(part_fhandle,
                        nheader || '|' || nsection || '|' || npart || '|' ||
                         my_text || '|' || suppression_reason_code
                        -- 09/28/2015 mm5095
                         || '|' || line_text_skey
                        -- 09/28/2015 mm5095
                        -- 02/09/2017 mm5095
                         || '|' ||
                         pkg_ultramate_common.sf_getfrench(line_text_skey,
                                                           my_text)
                        -- 02/09/2017 mm5095
                        );
-- end commented block */
      -- 04/05/2018 pb0690 => added
      pkg_ultramate_common.insert_um_data_dc(to_char(service_barcode_in),
                                             nheader,
                                             nsection,
                                             npart,
                                             my_text,
                                             suppression_reason_code,
                                             --2012/08/02 mm5095 => next gen requirement
                                             'P');

      IF nvl(callout_number_in, ' ') != ' ' THEN
        addgraphic(graphic_file_name, callout_number_in, nimage);
      END IF;

      savedetailnote := nvl(service_table(row_in).note_symbol, ' ');
      -- 07/08/02 mm5095 => note_group_xref fix
      IF service_table(row_in).version_type = 'PR' THEN
        OPEN note_cur(service_table(row_in).unique_row_id,
                      service_table(row_in).version_type);
        FETCH note_cur
          INTO note_rec;
        WHILE note_cur%FOUND LOOP
          IF note_rec.note_symbol != '#' THEN
            pkg_ultramate_common.getnoteid_by_skey(note_rec.note_group_skey,
                                                   note_type,
                                                   note_id,
                                                   run_type,
                                                   gparallelnumber);
/* -- File generation disabled: DH[barcode].txt write (FTP sunset)
            utl_file.put_line(pnote_fhandle,
                              nheader || '|' || nsection || '|' || npart || '|' ||
                              note_type || '|' || note_id);
-- end commented block */
            -- 04/05/2018 pb0690 => added
            pkg_ultramate_common.insert_um_data_dh(service_barcode_in,
                                                   nheader,
                                                   nsection,
                                                   npart,
                                                   note_type,
                                                   note_id);

          END IF;
          FETCH note_cur
            INTO note_rec;
        END LOOP;
        CLOSE note_cur;
      ELSE
        OPEN note_cur_wip(service_table(row_in).unique_row_id,
                          service_table(row_in).version_type);
        FETCH note_cur_wip
          INTO note_rec;
        WHILE note_cur_wip%FOUND LOOP
          IF note_rec.note_symbol != '#' THEN
            pkg_ultramate_common.getnoteid_by_skey(note_rec.note_group_skey,
                                                   note_type,
                                                   note_id,
                                                   run_type,
                                                   gparallelnumber);
/* -- File generation disabled: DH[barcode].txt write (FTP sunset)
            utl_file.put_line(pnote_fhandle,
                              nheader || '|' || nsection || '|' || npart || '|' ||
                              note_type || '|' || note_id);
-- end commented block */
            -- 04/05/2018 pb0690 => added
            pkg_ultramate_common.insert_um_data_dh(service_barcode_in,
                                                   nheader,
                                                   nsection,
                                                   npart,
                                                   note_type,
                                                   note_id);

          END IF;
          FETCH note_cur_wip
            INTO note_rec;
        END LOOP;
        CLOSE note_cur_wip;
      END IF;
      -- 07/08/02 mm5095 => note_group_xref fix
    END;

    PROCEDURE addpartdetail(row_in       INTEGER,
                            text_in      VARCHAR2,
                            baddpartnote BOOLEAN) IS
      CURSOR labor_cur(prtc_in VARCHAR2) IS
        SELECT /*+ labor_cur */
         labor_rate_code
          FROM prtc_body
         WHERE prtc_body = prtc_in;

      ceg_labor_time NUMBER;
      ioh_flag       CHAR(1);
      labor_type     CHAR(1);
      --    labor_operation char(1);
      my_right_left_code NUMBER(1);
      my_labor_type      NUMBER(1);
      labor_op           NUMBER(1);
      discontinued_flag  CHAR(1);
      new_flag           CHAR(1);
      special_flag       CHAR(1);
      us_part_number     VARCHAR2(25);
      us_effdt1          DATE;
      us_price1          NUMBER;
      us_effdt2          DATE;
      us_price2          NUMBER;
      can_part_number    VARCHAR2(25);
      can_effdt1         DATE;
      can_price1         NUMBER;
      can_effdt2         DATE;
      can_price2         NUMBER;
      start_date         VARCHAR2(8);
      end_date           VARCHAR2(8);
      my_text            VARCHAR2(200);
      my_prtc_desc       VARCHAR2(80);
      my_labor_rate      VARCHAR2(2);
      smartprtc          NUMBER;
      --    npos number;
      quad_flag CHAR(1);

      -- 10/24/2006 mm5095 => added support for special material qualifiers
      expanded_prtc_desc VARCHAR2(80);
      special_qualifier  VARCHAR2(80);
      -- 10/24/2006 mm5095 => added support for special material qualifiers

      -- 02/05/2008 jr6600 => added support for special material flag
      special_material_flag CHAR(1);
      -- 02/05/2008 jr6600 => added support for special material flag

      -- 05/09/2008 mm5095 => added support for mixed case text
      mc_prtc_desc prtc_description.mixed_case_descr%TYPE;
      -- 05/09/2008 mm5095 => added support for mixed case text

      -- 09/28/2015 mm5095
      line_text_skey     number;
      expanded_text_skey number;
      -- 09/28/2015 mm5095

    BEGIN
      IF substr(service_table(row_in).prtc, 4, 4) = 'TEXT' THEN
        RETURN;
      END IF;

      my_right_left_code := 0;

      -- 02/05/2008 jr6600 => added support for special material flag
      special_material_flag := '0';
      -- 02/05/2008 jr6600 => added support for special material flag

      -- 04/12/04 mm5095 => to support Right/Left Side qualifier
      --  moved this ahead of the right_left_code check
      my_text := rtrim(ltrim(text_in));
      pkg_ultramate_common.sp_striptext(my_text, my_right_left_code);
      -- 04/12/04 mm5095 => to support Right Side qualifier

      IF service_table(row_in).right_left_code = 'R' THEN
        my_right_left_code := 1;
      ELSIF service_table(row_in).right_left_code = 'L' THEN
        my_right_left_code := 2;
      END IF;

      -- 04/12/04 mm5095 => to support Right Side qualifier
      --    my_text := rtrim(ltrim(text_in));
      --    striptext(my_text,my_right_left_code);
      -- 04/12/04 mm5095 => to support Right Side qualifier

      resequence := resequence + 1;

      pkg_ultramate_common.sp_getlaborinfo(service_table(row_in).labor_operation_skey,
                                           ceg_labor_time,
                                           ioh_flag,
                                           labor_type);

      IF gcountryabbr NOT IN ('CA', 'US') THEN
        pkg_ultramate_common.sp_getpartinfo(service_table    (row_in).unique_row_id,
                                            service_table    (row_in).version_type,
                                            gcountryabbr,
                                            us_part_number,
                                            us_effdt1,
                                            us_price1,
                                            us_effdt2,
                                            us_price2,
                                            discontinued_flag,
                                            new_flag,
                                            special_flag);
      ELSE
        pkg_ultramate_common.sp_getpartinfo(service_table    (row_in).unique_row_id,
                                            service_table    (row_in).version_type,
                                            'CA',
                                            can_part_number,
                                            can_effdt1,
                                            can_price1,
                                            can_effdt2,
                                            can_price2,
                                            discontinued_flag,
                                            new_flag,
                                            special_flag);

        pkg_ultramate_common.sp_getpartinfo(service_table    (row_in).unique_row_id,
                                            service_table    (row_in).version_type,
                                            'US',
                                            us_part_number,
                                            us_effdt1,
                                            us_price1,
                                            us_effdt2,
                                            us_price2,
                                            discontinued_flag,
                                            new_flag,
                                            special_flag);
      END IF;

      IF substr(service_table(row_in).prtc, 10, 1) = 'A' THEN
        -- 10/20/08 mm5095 => bell and howell no longer supported
        --  if bell_howell_flag then
        --    utl_file.put_line(bell_howell_fhandle, '"' || service_barcode_in || '","'
        --      || service_table(row_in).barcode || '","' || us_part_number || '"');
        --  end if;
        -- 10/20/08 mm5095 => bell and howell no longer supported
        can_part_number := 'ORDER FROM DEALER';
        us_part_number  := 'ORDER FROM DEALER';
      END IF;

      --    my_labor_type := 0;

      OPEN labor_cur(substr(service_table(row_in).prtc, 4, 4));
      FETCH labor_cur
        INTO my_labor_rate;
      CLOSE labor_cur;

      my_labor_type := to_number(my_labor_rate);

      IF labor_type = 'M' THEN
        my_labor_type := 4;
      ELSIF labor_type = 'F' THEN
        my_labor_type := 3;
      END IF;

      labor_op := 1;
      -- 10/02/2006 mm5095 => added support for 'NA' as refinish
      -- 08/13/2020 - pb0690 - added FC and FD
      IF substr(service_table(row_in).prtc, 4, 2) in ('FA', 'FC', 'FD') OR
         substr(service_table(row_in).prtc, 4, 2) = 'NA' THEN
        --    if substr(service_table(row_in).prtc,4,2) = 'FA' then
        -- 10/02/2006 mm5095 => added support for 'NA' as refinish
        labor_op := 6;
        -- 08/13/2020 - pb0690 - added IB and IC
      ELSIF substr(service_table(row_in).prtc, 4, 2) in ('IA', 'IB', 'IC') THEN
        labor_op := 2;
      ELSIF substr(service_table(row_in).prtc, 4, 2) = 'OA' THEN
        labor_op := 5;
      ELSIF substr(service_table(row_in).prtc, 4, 2) = 'AD' THEN
        labor_op := 8;
      ELSIF substr(service_table(row_in).prtc, 4, 2) = 'AL' THEN
        labor_op := 4;
        -- 05/11/2023 - RS7649 - added to assign RE to labor_op 9
      ELSIF substr(service_table(row_in).prtc, 4, 2) = 'RE' THEN
        labor_op := 9;
      END IF;

      my_prtc_desc := pkg_build_prtc_desc.full_description(service_table(row_in).prtc);

      IF labor_type IS NOT NULL THEN
        my_prtc_desc := rpad(my_prtc_desc, 40, ' ');
        IF substr(my_prtc_desc, 39, 2) = '  ' THEN
          my_prtc_desc := substr(my_prtc_desc, 1, 38) || '-' || labor_type;
        END IF;
      END IF;

      -- 10/24/2006 mm5095 => added support for special material qualifiers
      special_qualifier := NULL;

      IF service_table(row_in).qgroup_skey IS NOT NULL THEN
        special_qualifier := sf_getspecialqualifier(service_table(row_in).qgroup_skey);

        expanded_prtc_desc := pkg_build_prtc_desc.full_description(service_table(row_in).prtc);

        IF special_qualifier IS NOT NULL AND
           length(special_qualifier) + length(expanded_prtc_desc) + 1 < 41 THEN
          expanded_prtc_desc := pkg_build_prtc_desc.full_description(service_table(row_in).prtc) || ' ' ||
                                special_qualifier;

          -- 02/05/2008 jr6600 => added support for special material flag
          special_material_flag := '1';
          -- 02/05/2008 jr6600 => added support for special material flag

          IF labor_type IS NOT NULL THEN
            expanded_prtc_desc := rpad(expanded_prtc_desc, 40, ' ');
            IF substr(expanded_prtc_desc, 39, 2) = '  ' THEN
              expanded_prtc_desc := substr(expanded_prtc_desc, 1, 38) || '-' ||
                                    labor_type;
            END IF;
          END IF;

        ELSE
          expanded_prtc_desc := my_prtc_desc;
        END IF;
      ELSE
        expanded_prtc_desc := my_prtc_desc;
      END IF;
      -- 10/24/2006 mm5095 => added support for special material qualifiers

      IF ioh_flag = 'Y' THEN
        pkg_ultramate_common.getnoteid_by_text('Included in Overhaul',
                                               2,
                                               note_id,
                                               run_type,
                                               gparallelnumber);
        IF baddpartnote THEN
/* -- File generation disabled: DH[barcode].txt write (FTP sunset)
          utl_file.put_line(pnote_fhandle,
                            nheader || '|' || nsection || '|' || npart ||
                            '|2|' || note_id);
-- end commented block */
          -- 04/05/2018 pb0690 => added
          pkg_ultramate_common.insert_um_data_dh(service_barcode_in,
                                                 nheader,
                                                 nsection,
                                                 npart,
                                                 2,
                                                 note_id);

        ELSE
/* -- File generation disabled: DJ[barcode].txt write (FTP sunset)
          utl_file.put_line(dtnote_fhandle,
                            service_table(row_in)
                            .barcode || '|2|' || note_id);
-- end commented block */
          -- 04/05/2018 pb0690 => added
          pkg_ultramate_common.insert_um_data_dj(service_barcode_in,
                                                 service_table(row_in).barcode,
                                                 2,
                                                 note_id);

        END IF;

        -- check for overhaul labor value
        IF substr(service_table(row_in).prtc, 1, 1) = 'R' OR
           substr(service_table(row_in).prtc, 2, 1) = 'R' OR
           substr(service_table(row_in).prtc, 3, 1) = 'R' THEN
          ceg_labor_time := rightoverhaultime;
        ELSIF substr(service_table(row_in).prtc, 1, 1) = 'L' OR
              substr(service_table(row_in).prtc, 2, 1) = 'L' OR
              substr(service_table(row_in).prtc, 3, 1) = 'L' THEN
          ceg_labor_time := leftoverhaultime;
        ELSE
          -- RightOverhaulTime applies to both when no differentiation
          ceg_labor_time := rightoverhaultime;
        END IF;
      END IF;

      pkg_ultramate_common.getstartenddate(service_table(row_in).lower_effectivity_date,
                                           service_table(row_in).upper_effectivity_date,
                                           start_date,
                                           end_date);
      --    getStartEndDate(service_table(row_in).lower_effectivity_date, service_table(row_in).upper_effectivity_date, start_date, end_date, true);

      IF nvl(service_table(row_in).quad_year_range, ' ') != ' ' OR
         nvl(service_table(row_in).lower_effectivity_date,
             to_date('01/01/2099', 'MM/DD/YYYY')) != glowerdate OR
         nvl(service_table(row_in).upper_effectivity_date,
             to_date('01/01/2099', 'MM/DD/YYYY')) != gupperdate THEN
        quad_flag := 'T';
      ELSE
        quad_flag := 'F';
      END IF;

      smartprtc := pkg_ultramate_common.sf_getsmartprtcid(sf_transformprtc(service_table(row_in).prtc,
                                                                           'SERVICE'),
                                                          run_type);

      -- 05/09/2008 mm5095 => added support for mixed case text

      mc_prtc_desc := pkg_ultramate_common.sf_getmixedcaseprtc(service_table(row_in).component_category_skey,
                                                               expanded_prtc_desc);
      -- 05/09/2008 mm5095 => added support for mixed case text

      -- 09/28/2015 mm5095
      line_text_skey     := sf_get_line_text_skey(upper(my_text), my_text);
      expanded_text_skey := sf_get_line_text_skey(expanded_prtc_desc,
                                                  mc_prtc_desc);
      -- 09/28/2015 mm5095

/* -- File generation disabled: DD[barcode].txt write (FTP sunset)
      utl_file.put_line(detail_fhandle,
                        nheader || '|' || nsection || '|' || npart_detail || '|' || service_table(row_in).barcode || '|' ||
                         resequence || '|' || quad_flag || '|' || start_date || '|' ||
                         end_date || '|' || my_right_left_code || '|' ||
                         my_labor_type || '|' || labor_op || '|' || service_table(row_in).part_type_id || '|' ||
--                         my_labor_type || '|' || labor_op || '|' || 48 || '|' ||
                         substr(us_part_number, 1, 20) || '|' ||
                         substr(can_part_number, 1, 20) || '|' || my_text || '|' ||
                         my_prtc_desc || '|' ||
                         to_char(us_effdt1, 'MMDDYYYY') || '|' ||
                         us_price1 * 100 || '|' ||
                         to_char(can_effdt1, 'MMDDYYYY') || '|' ||
                         can_price1 * 100 || '|' ||
                         to_char(us_effdt2, 'MMDDYYYY') || '|' ||
                         us_price2 * 100 || '|' ||
                         to_char(can_effdt2, 'MMDDYYYY') || '|' ||
                         can_price2 * 100 || '|' || ceg_labor_time * 10 || '|' ||
                         smartprtc || '|' || service_table(row_in).suppression_reason_code
                        -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
                         || '|' || header_sequence
                        -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
                        -- 10/24/2006 mm5095 => added support for special material qualifiers
                         || '|' || expanded_prtc_desc
                        -- 10/24/2006 mm5095 => added support for special material qualifiers
                        -- 02/05/2008 jr6600 => added support for special material flag
                         || '|' || special_material_flag
                        -- 02/05/2008 jr6600 => added support for special material flag
                        -- 05/09/2008 mm5095 => added support for mixed case text
                         || '|' || mc_prtc_desc
                        -- 05/09/2008 mm5095 => added support for mixed case text
                        -- 09/28/2015 mm5095
                         || '|' || line_text_skey || '|' ||
                         expanded_text_skey
                        -- 09/28/2015 mm5095
                        -- 02/09/2017 mm5095
                         || '|' ||
                         pkg_ultramate_common.sf_getfrench(line_text_skey,
                                                           my_text) || '|' ||
                         pkg_ultramate_common.sf_getfrench(expanded_text_skey,
                                                           mc_prtc_desc)
                        -- 02/09/2017 mm5095
                        );
-- end commented block */
      -- 04/05/2018 pb0690 => added
      pkg_ultramate_common.insert_um_data_dd(to_char(service_barcode_in),
                                             nheader,
                                             nsection,
                                             npart_detail,
                                             service_table(row_in).barcode,
                                             resequence,
                                             quad_flag,
                                             service_table(row_in).lower_effectivity_date,
                                             service_table(row_in).upper_effectivity_date,
                                             my_right_left_code,
                                             my_labor_type,
                                             labor_op,
                                             -- 12/30/2020 rs7649 => added support aftermarket commercial trucks parts
                                             service_table(row_in).part_type_id,
--                                             48,
                                             substr(us_part_number, 1, 20),
                                             substr(can_part_number, 1, 20),
                                             my_text,
                                             my_prtc_desc,
                                             us_effdt1,
                                             us_price1 * 100,
                                             can_effdt1,
                                             can_price1 * 100,
                                             us_effdt2,
                                             us_price2 * 100,
                                             can_effdt2,
                                             can_price2 * 100,
                                             ceg_labor_time * 10,
                                             smartprtc,
                                             service_table(row_in).suppression_reason_code,
                                             header_sequence,
                                             mc_prtc_desc,
                                             special_material_flag,
                                             service_table(row_in).unique_row_id,
                                             service_table(row_in).component_skey);

      -- 07/08/02 mm5095 => note_group_xref fix
      IF service_table(row_in).version_type = 'PR' THEN
        OPEN note_cur(service_table(row_in).unique_row_id,
                      service_table(row_in).version_type);
        FETCH note_cur
          INTO note_rec;
        WHILE note_cur%FOUND LOOP
          IF instr(savedetailnote, note_rec.note_symbol) = 0 OR
             note_rec.note_symbol = '#' THEN
            pkg_ultramate_common.getnoteid_by_skey(note_rec.note_group_skey,
                                                   note_type,
                                                   note_id,
                                                   run_type,
                                                   gparallelnumber);
/* -- File generation disabled: DJ[barcode].txt write (FTP sunset)
            utl_file.put_line(dtnote_fhandle,
                              service_table(row_in)
                              .barcode || '|' || note_type || '|' || note_id);
-- end commented block */
            -- 04/05/2018 pb0690 => added
            pkg_ultramate_common.insert_um_data_dj(service_barcode_in,
                                                   service_table(row_in).barcode,
                                                   note_type,
                                                   note_id);

          END IF;
          FETCH note_cur
            INTO note_rec;
        END LOOP;
        CLOSE note_cur;
      ELSE
        OPEN note_cur_wip(service_table(row_in).unique_row_id,
                          service_table(row_in).version_type);
        FETCH note_cur_wip
          INTO note_rec;
        WHILE note_cur_wip%FOUND LOOP
          IF instr(savedetailnote, note_rec.note_symbol) = 0 OR
             note_rec.note_symbol = '#' THEN
            pkg_ultramate_common.getnoteid_by_skey(note_rec.note_group_skey,
                                                   note_type,
                                                   note_id,
                                                   run_type,
                                                   gparallelnumber);
/* -- File generation disabled: DJ[barcode].txt write (FTP sunset)
            utl_file.put_line(dtnote_fhandle,
                              service_table(row_in)
                              .barcode || '|' || note_type || '|' || note_id);
-- end commented block */
            -- 04/05/2018 pb0690 => added
            pkg_ultramate_common.insert_um_data_dj(service_barcode_in,
                                                   service_table(row_in).barcode,
                                                   note_type,
                                                   note_id);

          END IF;
          FETCH note_cur_wip
            INTO note_rec;
        END LOOP;
        CLOSE note_cur_wip;
      END IF;
      -- 07/08/02 mm5095 => note_group_xref fix

      IF discontinued_flag = 'Y' THEN
        note_type := 3;
        pkg_ultramate_common.getnoteid_by_text('Discontinued by the Manufacturer',
                                               note_type,
                                               note_id,
                                               run_type,
                                               gparallelnumber);
/* -- File generation disabled: DJ[barcode].txt write (FTP sunset)
        utl_file.put_line(dtnote_fhandle,
                          service_table(row_in)
                          .barcode || '|' || note_type || '|' || note_id);
-- end commented block */
        -- 04/05/2018 pb0690 => added
        pkg_ultramate_common.insert_um_data_dj(service_barcode_in,
                                               service_table(row_in).barcode,
                                               note_type,
                                               note_id);

      ELSIF new_flag = 'Y' THEN
        note_type := 5;
        pkg_ultramate_common.getnoteid_by_text('Remanufactured Part',
                                               note_type,
                                               note_id,
                                               run_type,
                                               gparallelnumber);
/* -- File generation disabled: DJ[barcode].txt write (FTP sunset)
        utl_file.put_line(dtnote_fhandle,
                          service_table(row_in)
                          .barcode || '|' || note_type || '|' || note_id);
-- end commented block */
        -- 04/05/2018 pb0690 => added
        pkg_ultramate_common.insert_um_data_dj(service_barcode_in,
                                               service_table(row_in).barcode,
                                               note_type,
                                               note_id);

      END IF;
    END;

    FUNCTION getlabortext(row_in INTEGER, bflag BOOLEAN) RETURN VARCHAR2 IS
      vvc2_return VARCHAR2(200);
      --    vvc2_qualifier varchar2(160);
    BEGIN

      IF nvl(service_table(row_in).labor_verb_skey, 0) > 0 THEN
        vvc2_return := pkg_ultramate_common.sf_getlaborverbstring(service_table(row_in).labor_verb_skey);
      END IF;

      IF nvl(service_table(row_in).component_skey, 0) > 0 THEN
        IF vvc2_return IS NOT NULL THEN
          vvc2_return := rtrim(vvc2_return) || ' ' ||
                         pkg_ultramate_common.sf_getcomponentstring(service_table(row_in).component_skey);
        ELSE
          vvc2_return := pkg_ultramate_common.sf_getcomponentstring(service_table(row_in).component_skey);
        END IF;
      END IF;

      IF nvl(service_table(row_in).qgroup_skey, 0) > 0 THEN
        IF vvc2_return IS NOT NULL THEN
          vvc2_return := rtrim(vvc2_return) || ' ' ||
                         pkg_ultramate_common.sf_getqualifierstring(service_table(row_in).qgroup_skey,
                                                                    '1',
                                                                    FALSE);
        ELSE
          vvc2_return := pkg_ultramate_common.sf_getqualifierstring(service_table(row_in).qgroup_skey,
                                                                    '1',
                                                                    FALSE);
        END IF;
      END IF;

      IF bflag AND nvl(service_table(row_in).inline_note_skey, 0) > 0 THEN
        IF vvc2_return IS NOT NULL THEN
          vvc2_return := rtrim(vvc2_return) ||
                         pkg_ultramate_common.sf_getnote_by_skey(service_table(row_in).inline_note_skey);
        ELSE
          vvc2_return := pkg_ultramate_common.sf_getnote_by_skey(service_table(row_in).inline_note_skey);
        END IF;
      END IF;

      RETURN rtrim(vvc2_return);
    END;

    PROCEDURE addlaborpart(text_in                 VARCHAR2,
                           row_in                  INTEGER,
                           last_row_in             INTEGER,
                           suppression_reason_code INTEGER)
    --  PROCEDURE AddLaborPart(text_in varchar2, row_in integer, last_row_in integer, version_in varchar2, bFlag boolean, suppression_reason_code integer)
     IS
      part_text VARCHAR2(160);
      --    part_text2 varchar2(160);
      ncount          INTEGER;
      bremovecomplete BOOLEAN;

      -- 09/28/2015 mm5095
      line_text_skey number;
      -- 09/28/2015 mm5095

    BEGIN
      vvc2_procedure_name := 'AddLaborPart';

      part_text := rtrim(ltrim(text_in));

      IF nsection = 0 THEN
        -- add dummy section
        bdummysection := TRUE;
        addsection(row_in,
                   pkg_ultramate_common.sf_getcategorystring(service_table(row_in).category_skey));
      END IF;

      -- skip dual quarter overhaul's
      IF substr(service_table(row_in).prtc, 4, 2) = 'RZ' THEN
        RETURN;
      END IF;

      -- skip dual quarter overhaul's that wrap across multiple lines
      FOR n IN row_in .. last_row_in - 1 LOOP
        IF inlaborset(n, row_in) THEN
          IF substr(service_table(n).prtc, 4, 4) = 'TEXT' THEN
            IF substr(service_table(n + 1).prtc, 4, 2) = 'RZ' THEN
              RETURN;
            END IF;
          ELSE
            EXIT;
          END IF;
        ELSE
          EXIT;
        END IF;
      END LOOP;

      IF substr(part_text, 1, 8) = 'Refinish' AND
         substr(part_text, length(part_text) - 6, 7) = 'Outside' THEN
        FOR n IN row_in + 1 .. last_row_in LOOP
          IF NOT inlaborset(n, row_in) THEN
            EXIT;
          END IF;

          IF nvl(service_table(n).indent_level, ' ') = '0' AND
             (nvl(service_table(n).labor_verb_skey, 0) !=
              nvl(service_table(row_in).labor_verb_skey, 0) OR
              nvl(service_table(n).component_skey, 0) !=
              nvl(service_table(row_in).component_skey, 0)) THEN
            EXIT;
          END IF;

          IF substr(pkg_ultramate_common.sf_getlaborverbstring(service_table(n).labor_verb_skey),
                    1,
                    3) = 'Add' THEN
            part_text := substr(part_text, 1, length(part_text) - 8);
            EXIT;
          END IF;
        END LOOP;
        -- 05/23/02 mm5095 => Editorial enhancement
        --  if Refinish...Complete
        --    if Not R/L or more than 1 detail line remove 'Complete'
      ELSIF substr(part_text, 1, 8) = 'Refinish' AND
            substr(part_text, length(part_text) - 7, 8) = 'Complete' THEN
        ncount          := 0;
        bremovecomplete := FALSE;
        FOR n IN row_in + 1 .. last_row_in LOOP
          IF inlaborset(n, row_in) THEN
            IF nvl(service_table(n).right_left_code, ' ') = ' ' THEN
              bremovecomplete := TRUE;
              EXIT;
            END IF;
            ncount := ncount + 1;
            IF ncount > 1 THEN
              bremovecomplete := TRUE;
              EXIT;
            END IF;
          ELSE
            EXIT;
          END IF;
        END LOOP;

        IF bremovecomplete THEN
          part_text := substr(part_text, 1, length(part_text) - 9);
        END IF;

        -- 05/23/02 mm5095 => Editorial enhancement
      END IF;

      npart := npart + 1;

      -- 09/28/2015 mm5095
      line_text_skey := sf_get_line_text_skey(part_text, part_text);
      -- 09/28/2015 mm5095

/* -- File generation disabled: DC[barcode].txt write (FTP sunset)
      utl_file.put_line(part_fhandle,
                        nheader || '|' || nsection || '|' || npart || '|' ||
                         part_text || '|' || suppression_reason_code
                        -- 09/28/2015 mm5095
                         || '|' || line_text_skey
                        -- 09/28/2015 mm5095
                        -- 02/09/2017 mm5095
                         || '|' ||
                         pkg_ultramate_common.sf_getfrench(line_text_skey,
                                                           part_text)
                        -- 02/09/2017 mm5095
                        );
-- end commented block */
      -- 04/05/2018 pb0690 => added
      pkg_ultramate_common.insert_um_data_dc(to_char(service_barcode_in),
                                             nheader,
                                             nsection,
                                             npart,
                                             part_text,
                                             suppression_reason_code,
                                             -- 2012/08/09 mm5095 => next gen requirement
                                             'L'
                                             -- 2012/08/09 mm5095 => next gen requirement
                                             );

      savedetailnote := nvl(service_table(row_in).note_symbol, ' ');
      -- 07/08/02 mm5095 => note_group_xref fix
      IF service_table(row_in).version_type = 'PR' THEN
        OPEN note_cur(service_table(row_in).unique_row_id,
                      service_table(row_in).version_type);
        FETCH note_cur
          INTO note_rec;
        WHILE note_cur%FOUND LOOP
          IF note_rec.note_symbol != '#' THEN
            pkg_ultramate_common.getnoteid_by_skey(note_rec.note_group_skey,
                                                   note_type,
                                                   note_id,
                                                   run_type,
                                                   gparallelnumber);
/* -- File generation disabled: DH[barcode].txt write (FTP sunset)
            utl_file.put_line(pnote_fhandle,
                              nheader || '|' || nsection || '|' || npart || '|' ||
                              note_type || '|' || note_id);
-- end commented block */
            -- 04/05/2018 pb0690 => added
            pkg_ultramate_common.insert_um_data_dh(service_barcode_in,
                                                   nheader,
                                                   nsection,
                                                   npart,
                                                   note_type,
                                                   note_id);

          END IF;
          FETCH note_cur
            INTO note_rec;
        END LOOP;
        CLOSE note_cur;
      ELSE
        OPEN note_cur_wip(service_table(row_in).unique_row_id,
                          service_table(row_in).version_type);
        FETCH note_cur_wip
          INTO note_rec;
        WHILE note_cur_wip%FOUND LOOP
          IF note_rec.note_symbol != '#' THEN
            pkg_ultramate_common.getnoteid_by_skey(note_rec.note_group_skey,
                                                   note_type,
                                                   note_id,
                                                   run_type,
                                                   gparallelnumber);
/* -- File generation disabled: DH[barcode].txt write (FTP sunset)
            utl_file.put_line(pnote_fhandle,
                              nheader || '|' || nsection || '|' || npart || '|' ||
                              note_type || '|' || note_id);
-- end commented block */
            -- 04/05/2018 pb0690 => added
            pkg_ultramate_common.insert_um_data_dh(service_barcode_in,
                                                   nheader,
                                                   nsection,
                                                   npart,
                                                   note_type,
                                                   note_id);

          END IF;
          FETCH note_cur_wip
            INTO note_rec;
        END LOOP;
        CLOSE note_cur_wip;
      END IF;
      -- 07/08/02 mm5095 => note_group_xref fix
    END;

    PROCEDURE addlabordetail(row_in INTEGER, text_in VARCHAR2) IS
      CURSOR labor_cur(prtc_in VARCHAR2) IS
        SELECT /*+ labor_cur 2 */
         labor_rate_code
          FROM prtc_body
         WHERE prtc_body = prtc_in;

      ceg_labor_time NUMBER;
      ioh_flag       CHAR(1);
      labor_type     CHAR(1);
      --    labor_operation char(1);
      my_right_left_code NUMBER(1);
      my_labor_type      NUMBER(1);
      labor_op           NUMBER(1);
      start_date         VARCHAR2(8);
      end_date           VARCHAR2(8);
      my_text            VARCHAR2(200);
      my_prtc_desc       VARCHAR2(80);
      my_labor_rate      VARCHAR2(2);
      smartprtc          NUMBER;
      my_header          NUMBER;
      my_section         NUMBER;
      my_part            NUMBER;
      quad_flag          CHAR(1);
      -- 05/09/2008 mm5095 => added support for mixed case text
      mc_prtc_desc prtc_description.mixed_case_descr%TYPE;
      -- 05/09/2008 mm5095 => added support for mixed case text

      -- 09/28/2015 mm5095
      line_text_skey number;
      prtc_text_skey number;
      -- 09/28/2105 mm5095

    BEGIN
      IF substr(service_table(row_in).prtc, 4, 4) = 'TEXT' THEN
        RETURN;
      END IF;

      pkg_ultramate_common.sp_getlaborinfo(service_table(row_in).labor_operation_skey,
                                           ceg_labor_time,
                                           ioh_flag,
                                           labor_type);

      my_right_left_code := 0;

      IF service_table(row_in).right_left_code = 'R' THEN
        my_right_left_code := 1;
      ELSIF service_table(row_in).right_left_code = 'L' THEN
        my_right_left_code := 2;
      END IF;

      --    my_labor_type := 0;

      OPEN labor_cur(substr(service_table(row_in).prtc, 4, 4));
      FETCH labor_cur
        INTO my_labor_rate;
      CLOSE labor_cur;

      my_labor_type := to_number(my_labor_rate);

      IF labor_type = 'M' THEN
        my_labor_type := 4;
      ELSIF labor_type = 'F' THEN
        my_labor_type := 3;
      END IF;

      labor_op := 1;
      -- 10/02/2006 mm5095 => added support for 'NA' as refinish
      -- 08/13/2020 - pb0690 - added FC and FD
      IF substr(service_table(row_in).prtc, 4, 2) in ('FA', 'FC', 'FD') OR
         substr(service_table(row_in).prtc, 4, 2) = 'NA' THEN
        --    if substr(service_table(row_in).prtc,4,2) = 'FA' then
        -- 10/02/2006 mm5095 => added support for 'NA' as refinish
        labor_op := 6;
        -- 08/13/2020 - pb0690 - added IC and IB
      ELSIF substr(service_table(row_in).prtc, 4, 2) in ('IA', 'IC', 'IB') THEN
        labor_op := 2;
      ELSIF substr(service_table(row_in).prtc, 4, 2) = 'OA' THEN
        labor_op := 5;
      ELSIF substr(service_table(row_in).prtc, 4, 2) = 'AD' THEN
        labor_op := 8;
      ELSIF substr(service_table(row_in).prtc, 4, 2) = 'AL' THEN
        labor_op := 4;
        -- 05/11/2023 - RS7649 - added to assign RE to labor_op 9
      ELSIF substr(service_table(row_in).prtc, 4, 2) = 'RE' THEN
        labor_op := 9;
      END IF;

      my_text := rtrim(ltrim(text_in));
      pkg_ultramate_common.sp_striptext(my_text, my_right_left_code);

      IF substr(service_table(row_in).prtc, 4, 2) = 'RZ' THEN
        -- suppress overhaul lines
        my_header  := 0;
        my_section := 0;
        my_part    := 0;
      ELSE
        my_header  := nheader;
        my_section := nsection;
        my_part    := npart_detail;
      END IF;

      resequence := resequence + 1;

      my_prtc_desc := pkg_build_prtc_desc.full_description(service_table(row_in).prtc);

      IF labor_type IS NOT NULL THEN
        my_prtc_desc := rpad(my_prtc_desc, 40, ' ');
        IF substr(my_prtc_desc, 39, 2) = '  ' THEN
          my_prtc_desc := substr(my_prtc_desc, 1, 38) || '-' || labor_type;
        END IF;
      END IF;

      pkg_ultramate_common.getstartenddate(service_table(row_in).lower_effectivity_date,
                                           service_table(row_in).upper_effectivity_date,
                                           start_date,
                                           end_date);
      --    getStartEndDate(service_table(row_in).lower_effectivity_date, service_table(row_in).upper_effectivity_date, start_date, end_date, true);

      IF nvl(service_table(row_in).quad_year_range, ' ') != ' ' OR
         nvl(service_table(row_in).lower_effectivity_date,
             to_date('01/01/2099', 'MM/DD/YYYY')) != glowerdate OR
         nvl(service_table(row_in).upper_effectivity_date,
             to_date('01/01/2099', 'MM/DD/YYYY')) != gupperdate THEN
        quad_flag := 'T';
      ELSE
        quad_flag := 'F';
      END IF;

      smartprtc := pkg_ultramate_common.sf_getsmartprtcid(sf_transformprtc(service_table(row_in).prtc,
                                                                           'SERVICE'),
                                                          run_type);

      -- 05/09/2008 mm5095 => added support for mixed case text
      mc_prtc_desc := pkg_ultramate_common.sf_getmixedcaseprtc(service_table(row_in).component_category_skey,
                                                               my_prtc_desc);
      -- 05/09/2008 mm5095 => added support for mixed case text

      -- 09/28/2015 mm5095
      line_text_skey := sf_get_line_text_skey(upper(my_text), my_text);
      prtc_text_skey := sf_get_line_text_skey(my_prtc_desc,
                                              pkg_ultramate_common.sf_getmixedcaseprtc(service_table(row_in).component_category_skey,
                                                                                       my_prtc_desc));
      -- 09/28/2015 mm5095

/* -- File generation disabled: DD[barcode].txt write (FTP sunset)
      utl_file.put_line(detail_fhandle,
                        my_header || '|' || my_section || '|' || my_part || '|' || service_table(row_in).barcode || '|' ||
                         resequence || '|' || quad_flag || '|' || start_date || '|' ||
                         end_date || '|' || my_right_left_code || '|' ||
                         my_labor_type || '|' || labor_op || '|' || 48 || '|' || '' || '|' || '' || '|' ||
                         rtrim(my_text) || '|' || my_prtc_desc || '|' || '' || '|' || '' || '|' || '' || '|' || '' || '|' || '' || '|' || '' || '|' || '' || '|' || '' || '|' ||
                         ceg_labor_time * 10 || '|' || smartprtc || '|' || service_table(row_in).suppression_reason_code
                        -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
                         || '|' || header_sequence
                        -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
                        -- 10/24/2006 mm5095 => added support for special material qualifiers
                         || '|' || my_prtc_desc
                        -- 10/24/2006 mm5095 => added support for special material qualifiers
                        -- 02/05/2008 jr6600 => added support for special material flag
                         || '|0' -- special_material_flag
                        -- 02/05/2008 jr6600 => added support for special material flag
                        -- 05/09/2008 mm5095 => added support for mixed case text
                         || '|' || mc_prtc_desc
                        -- 05/09/2008 mm5095 => added support for mixed case text
                        -- 09/28/2015 mm5095
                         || '|' || line_text_skey || '|' || prtc_text_skey
                        -- 02/09/2017 mm5095
                         || '|' ||
                         pkg_ultramate_common.sf_getfrench(line_text_skey,
                                                           my_text) || '|' ||
                         pkg_ultramate_common.sf_getfrench(prtc_text_skey,
                                                           mc_prtc_desc)
                        -- 02/09/2017 mm5095
                        );
-- end commented block */
      -- 04/05/2018 pb0690 => added
      pkg_ultramate_common.insert_um_data_dd(to_char(service_barcode_in),
                                             nheader,
                                             nsection,
                                             npart_detail,
                                             service_table(row_in).barcode,
                                             resequence,
                                             quad_flag,
                                             service_table(row_in).lower_effectivity_date,
                                             service_table(row_in).upper_effectivity_date,
                                             my_right_left_code,
                                             my_labor_type,
                                             labor_op,
                                             48,
                                             NULL,
                                             NULL,
                                             rtrim(my_text),
                                             my_prtc_desc,
                                             NULL,
                                             NULL,
                                             NULL,
                                             NULL,
                                             NULL,
                                             NULL,
                                             NULL,
                                             NULL,
                                             ceg_labor_time * 10,
                                             smartprtc,
                                             service_table(row_in).suppression_reason_code,
                                             header_sequence,
                                             mc_prtc_desc,
                                             '0',
                                             service_table(row_in).unique_row_id,
                                             service_table(row_in).component_skey);

      IF service_table(row_in).clearcoat_flag = 'C' THEN
        note_type := 4;
        pkg_ultramate_common.getnoteid_by_text('Part Included in Clear Coat Application',
                                               note_type,
                                               note_id,
                                               run_type,
                                               gparallelnumber);
/* -- File generation disabled: DJ[barcode].txt write (FTP sunset)
        utl_file.put_line(dtnote_fhandle,
                          service_table(row_in)
                          .barcode || '|' || note_type || '|' || note_id);
-- end commented block */
        -- 04/05/2018 pb0690 => added
        pkg_ultramate_common.insert_um_data_dj(to_char(service_barcode_in),
                                               service_table(row_in).barcode,
                                               note_type,
                                               note_id);

      END IF;

      -- 07/08/02 mm5095 => note_group_xref fix
      IF service_table(row_in).version_type = 'PR' THEN
        OPEN note_cur(service_table(row_in).unique_row_id,
                      service_table(row_in).version_type);
        FETCH note_cur
          INTO note_rec;
        WHILE note_cur%FOUND LOOP
          IF instr(savedetailnote, note_rec.note_symbol) = 0 OR
             note_rec.note_symbol = '#' THEN
            pkg_ultramate_common.getnoteid_by_skey(note_rec.note_group_skey,
                                                   note_type,
                                                   note_id,
                                                   run_type,
                                                   gparallelnumber);
/* -- File generation disabled: DJ[barcode].txt write (FTP sunset)
            utl_file.put_line(dtnote_fhandle,
                              service_table(row_in)
                              .barcode || '|' || note_type || '|' || note_id);
-- end commented block */
            -- 04/05/2018 pb0690 => added
            pkg_ultramate_common.insert_um_data_dj(service_barcode_in,
                                                   service_table(row_in).barcode,
                                                   note_type,
                                                   note_id);

          END IF;
          FETCH note_cur
            INTO note_rec;
        END LOOP;
        CLOSE note_cur;
      ELSE
        OPEN note_cur_wip(service_table(row_in).unique_row_id,
                          service_table(row_in).version_type);
        FETCH note_cur_wip
          INTO note_rec;
        WHILE note_cur_wip%FOUND LOOP
          IF instr(savedetailnote, note_rec.note_symbol) = 0 OR
             note_rec.note_symbol = '#' THEN
            pkg_ultramate_common.getnoteid_by_skey(note_rec.note_group_skey,
                                                   note_type,
                                                   note_id,
                                                   run_type,
                                                   gparallelnumber);
/* -- File generation disabled: DJ[barcode].txt write (FTP sunset)
            utl_file.put_line(dtnote_fhandle,
                              service_table(row_in)
                              .barcode || '|' || note_type || '|' || note_id);
-- end commented block */
            -- 04/05/2018 pb0690 => added
            pkg_ultramate_common.insert_um_data_dj(service_barcode_in,
                                                   service_table(row_in).barcode,
                                                   note_type,
                                                   note_id);

          END IF;
          FETCH note_cur_wip
            INTO note_rec;
        END LOOP;
        CLOSE note_cur_wip;
      END IF;
      -- 07/08/02 mm5095 => note_group_xref fix

      -- get overhaul time, if any
      IF nvl(service_table(row_in).labor_verb_skey, 0) > 0 THEN
        IF pkg_ultramate_common.sf_getlaborverbstring(service_table(row_in).labor_verb_skey) =
           'O/H' THEN
          IF substr(service_table(row_in).prtc, 4, 2) = 'OA' THEN
            IF substr(service_table(row_in).prtc, 6, 2) != '**' THEN
              labor_time := pkg_ultramate_common.sf_getlabortime(service_table(row_in).labor_operation_skey);
              IF labor_time > 0 THEN
                IF rightoverhaultime = 0 AND leftoverhaultime = 0 AND
                   nvl(service_table(row_in).right_left_code, ' ') = ' ' THEN
                  rightoverhaultime := labor_time;
                  leftoverhaultime  := labor_time;
                ELSIF nvl(service_table(row_in).right_left_code, ' ') = 'R' THEN
                  rightoverhaultime := labor_time;
                ELSE
                  leftoverhaultime := labor_time;
                END IF;
              END IF;
            END IF;
          END IF;
        END IF;
      END IF;
    END;

    PROCEDURE create_chassis_notes(row_in INTEGER, last_row_in INTEGER) IS
      my_note_id  NUMBER;
      my_text     VARCHAR2(100);
      out_fhandle utl_file.file_type;
      -- 09/28/2015 mm5095
      line_text_skey number;
      -- 09/28/2015 mm5095
    BEGIN
      BEGIN
        SELECT /*+ max note */
         MAX(note_id)
          INTO my_note_id
          FROM tmp_um_note;
      EXCEPTION
        WHEN no_data_found THEN
          my_note_id := 0;
      END;

/* -- File generation disabled: DI[barcode].txt fopen (FTP sunset)
      out_fhandle := utl_file.fopen(path,
                                    'DI' || service_barcode || '.txt',
                                    'a');
-- end commented block */

      FOR n IN row_in .. last_row_in LOOP
        IF NOT inlaborset(n, row_in) THEN
          EXIT;
        END IF;

        IF service_table(n).line_type = 'N' THEN

          my_text := getlaborverbcomponent(n, FALSE);

          IF my_text IS NOT NULL THEN
            my_text := my_text || ' ' ||
                       pkg_ultramate_common.sf_getqualifierstring(service_table(n).detail_qgroup_skey,
                                                                  '1',
                                                                  FALSE);
          ELSE
            my_text := pkg_ultramate_common.sf_getqualifierstring(service_table(n).detail_qgroup_skey,
                                                                  '1',
                                                                  FALSE);
          END IF;

          -- 09/28/2015 mm5095
          line_text_skey := sf_get_line_text_skey(my_text, my_text);
          -- 09/28/2015 mm5095

          my_note_id := my_note_id + 1;

/* -- File generation disabled: DI[barcode].txt write (FTP sunset)
          utl_file.put_line(out_fhandle,
                            my_note_id
                            -- 02/09/2017 mm5095
                             || '|1|'
                            -- 02/09/2017 mm5095
                             || '1|' || my_text
                            -- 09/28/2015 mm5095
                             || '|' || line_text_skey);
-- end commented block */
          -- 09/28/2015 mm5095

          -- 04/05/2018 pb0690 => added
          pkg_ultramate_common.update_um_di(service_barcode_in,
                                            my_note_id,
                                            1,
                                            my_text);

          -- 02/09/2017 mm5095
/* -- File generation disabled: DI[barcode].txt write (FTP sunset)
          utl_file.put_line(out_fhandle,
                            my_note_id || '|2|' || '1|' ||
                            pkg_ultramate_common.sf_getfrench(line_text_skey,
                                                              my_text) || '|' ||
                            line_text_skey);
-- end commented block */
          -- 02/09/2017 mm5095
          -- 04/05/2018 pb0690 => added
          pkg_ultramate_common.update_um_di(service_barcode_in,
                                            my_note_id,
                                            1,
                                            pkg_ultramate_common.sf_getfrench(line_text_skey,
                                                                              my_text));

          IF bdummysection THEN
/* -- File generation disabled: DH[barcode].txt write (FTP sunset)
            utl_file.put_line(pnote_fhandle,
                              nheader || '|0|0|0|' || my_note_id);
-- end commented block */
            -- 04/05/2018 pb0690 => added
            pkg_ultramate_common.insert_um_data_dh(service_barcode_in,
                                                   nheader,
                                                   0,
                                                   0,
                                                   0,
                                                   -- 03/21/2017 mm5095 => bug fix
                                                   my_note_id);

          ELSE
/* -- File generation disabled: DH[barcode].txt write (FTP sunset)
            utl_file.put_line(pnote_fhandle,
                              nheader || '|' || nsection || '|0|0|' ||
                              my_note_id);
-- end commented block */
            -- 04/05/2018 pb0690 => added
            pkg_ultramate_common.insert_um_data_dh(service_barcode_in,
                                                   nheader,
                                                   0,
                                                   0,
                                                   0,
                                                   -- 03/21/2017 mm5095 => bug fix
                                                   my_note_id);

          END IF;
        END IF;
      END LOOP;

/* -- File generation disabled: DI[barcode].txt is_open check (FTP sunset)
      IF utl_file.is_open(out_fhandle) THEN
        utl_file.fclose(out_fhandle);
      END IF;
-- end commented block */
    END;

    FUNCTION hashotspot(graphic_in VARCHAR2) RETURN BOOLEAN IS
      my_callout hotspot.callout_number%TYPE;
    BEGIN
      SELECT a.callout_number
        INTO my_callout
        FROM hotspot a
       WHERE a.graphic_file_name = graphic_in || '.tif'
            -- 12/29/2011 mm5095 = bug fix
         AND a.callout_number != '0'
            -- 12/29/2011 mm5095 = bug fix
         AND rownum = 1;
      RETURN TRUE;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN FALSE;
    END;

    PROCEDURE create_main(service_barcode VARCHAR2,
                          mfr_in          VARCHAR2,
                          service_in      VARCHAR2,
                          version_in      VARCHAR2) IS
      CURSOR deleteandpoint_cur IS
        SELECT /*+ deleteandpoint_cur */
         delete_message_prtc_body prtc_body, note_text
          FROM note
         WHERE note_type = 'D';

      current_row    INTEGER;
      last_row       INTEGER;
      last_line_type CHAR(1) := ' ';

      CLASS            VARCHAR2(3);
      labor_verb_skey  NUMBER := 0;
      component_skey   NUMBER := 0;
      qgroup_skey      NUMBER := 0;
      inline_note_skey NUMBER := 0;
      --    country_abbr varchar2(2);
      my_category VARCHAR2(80);
      my_text     VARCHAR2(200);
      --    bFirstTime boolean;
      barcode_row INTEGER;
      prefix_row  INTEGER;
      temp_text   VARCHAR2(200);
      pre_text    VARCHAR2(200);

      blaborverbset     BOOLEAN;
      bcomponentset     BOOLEAN;
      blaborverbdetail  BOOLEAN;
      bcomponentdetail  BOOLEAN;
      bqualifierdetail  BOOLEAN;
      ncount            INTEGER;
      part_indent_level VARCHAR2(2);
      last_indent_level VARCHAR2(2);

      -- 10/11/2004 mm5095 => added support for hidden lines
      d_code INTEGER := 0;
      -- 10/11/2004 mm5095 => added support for hidden lines

      -- 12/10/2004 mm5095 => optimized query
      -- 11/16/2004 mm5095 => added support for rr_vs_repair
      CURSOR rr_cur(mfr_in     VARCHAR2,
                    service_in VARCHAR2,
                    version_in VARCHAR2) IS
        SELECT /*+ rr_cur */
         b.barcode rr_barcode, c.barcode ri_barcode
          FROM labor_ri_rr                 a,
               ext.service_category_detail b,
               ext.service_category_detail c
         WHERE b.unique_row_id = a.rr_row_id
           AND b.version_type = a.version_type
           AND b.mfr_number = mfr_in
           AND b.service_number = service_in
           AND b.version_type = version_in
           AND c.unique_row_id = a.ri_row_id
           AND c.mfr_number = mfr_in
           AND c.service_number = service_in
           AND c.version_type = version_in
              -- 02/04/2005 mm5095 => fix
           AND b.barcode IS NOT NULL
           AND c.barcode IS NOT NULL
        UNION
           SELECT /*+ rr_cur */
                b.barcode rr_barcode,
                c.barcode ri_barcode
            FROM labor_ri_rr             a,
                 service_category_detail b,
                 service_category_detail c,
                 race.service_category_substitution d
            WHERE d.mfr_number = mfr_in
              AND d.service_number = service_in
              AND b.unique_row_id = a.rr_row_id
              AND b.version_type = a.version_type
              AND b.mfr_number = d.substitute_mfr_number
              AND b.service_number = d.substitute_service_number
              AND b.version_type = version_in
              AND c.unique_row_id = a.ri_row_id
              AND c.mfr_number = d.substitute_mfr_number
              AND c.service_number = d.substitute_service_number
              AND c.version_type = version_in
                      -- 02/04/2005 mm5095 => fix
              AND b.barcode IS NOT NULL
              AND c.barcode IS NOT NULL;
      -- 02/04/2005 mm5095 => fix
      -- 12/10/2004 mm5095 => optimized query
      -- 11/16/2004 mm5095 => added support for rr_vs_repair

      -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
      vehicle_type_skey    NUMBER;
      bcheckheadersequence BOOLEAN;
      -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5

      -- 05/09/2008 mm5095 => added support for mixed case Category description
      mc_category category_description.mixed_case_category_name%TYPE;
      -- 05/09/2008 mm5095 => added support for mixed case Category description

      tmp_graphic_file_name service_category_detail.graphic_file_name%TYPE;

      -- 09/28/2015 mm5095
      line_text_skey number;
      -- 09/28/2015 mm5095

    BEGIN
      vvc2_procedure_name := 'create_main';

      service_barcode_in := to_number(service_barcode);

      -- open output files
/* -- File generation disabled: DA[barcode].txt fopen (FTP sunset)
      header_fhandle  := utl_file.fopen(path,
                                        'DA' || service_barcode || '.txt',
                                        'w');
-- end commented block */
/* -- File generation disabled: DB[barcode].txt fopen (FTP sunset)
      section_fhandle := utl_file.fopen(path,
                                        'DB' || service_barcode || '.txt',
                                        'w');
-- end commented block */
/* -- File generation disabled: DC[barcode].txt fopen (FTP sunset)
      part_fhandle    := utl_file.fopen(path,
                                        'DC' || service_barcode || '.txt',
                                        'w');
-- end commented block */
/* -- File generation disabled: DD[barcode].txt fopen (FTP sunset)
      detail_fhandle  := utl_file.fopen(path,
                                        'DD' || service_barcode || '.txt',
                                        'w');
-- end commented block */

      -- 04/12/2006 mm5095 => add support for atg graphics UM 6.5
      --    if mfr_in != '006' then  -- ignore ATG graphics
/* -- File generation disabled: DK[barcode].txt fopen (FTP sunset)
      graphic_fhandle       := utl_file.fopen(path,
                                              'DK' || service_barcode ||
                                              '.txt',
                                              'w');
-- end commented block */
/* -- File generation disabled: DE[barcode].txt fopen (FTP sunset)
      hotspot_fhandle       := utl_file.fopen(path,
                                              'DE' || service_barcode ||
                                              '.txt',
                                              'w');
-- end commented block */
/* -- File generation disabled: DM[barcode].txt fopen (FTP sunset)
      color_graphic_fhandle := utl_file.fopen(path,
                                              'DM' || service_barcode ||
                                              '.txt',
                                              'w');
-- end commented block */
/* -- File generation disabled: DN[barcode].txt fopen (FTP sunset)
      color_hotspot_fhandle := utl_file.fopen(path,
                                              'DN' || service_barcode ||
                                              '.txt',
                                              'w');
-- end commented block */
      --    end if;
      -- 04/12/2006 mm5095 => add support for atg graphics UM 6.5

/* -- File generation disabled: DH[barcode].txt fopen (FTP sunset)
      pnote_fhandle  := utl_file.fopen(path,
                                       'DH' || service_barcode || '.txt',
                                       'w');
-- end commented block */
/* -- File generation disabled: DJ[barcode].txt fopen (FTP sunset)
      dtnote_fhandle := utl_file.fopen(path,
                                       'DJ' || service_barcode || '.txt',
                                       'w');
-- end commented block */

      -- initialize variables
      nheader           := 0;
      nsection          := 0;
      npart             := 0;
      resequence        := 0;
      nimage            := 0;
      part_indent_level := ' ';


      -- get product class
      CLASS := 'CEG';
      -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
      --    resequence := 10000;
      -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5

      -- 09/21/2020 pg2697 => added support for CMT/CHT
      -- 01/14/2005 mm5095 => added ppage support for motorcycles and RVs
      IF mfr_in > '700' and mfr_in <= '799' THEN
        CLASS := 'CHT';
      ELSIF mfr_in > '200' and mfr_in <= '699' THEN
        CLASS := 'MCS';
      ELSIF mfr_in >= '100' and mfr_in <= '199' THEN
        CLASS := 'RVS';
        -- 01/14/2005 mm5095 => added ppage support for motorcycles and RVs
      ELSIF mfr_in = '006' THEN
        CLASS := 'ATG';
        -- 04/21/2011 mm5095 => add support for mtd/htd
      ELSE
        CLASS := pkg_ultramate_common.sf_getclass(mfr_in, service_in);
        -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
        --      resequence := 0;
        -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
      END IF;

      -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
      vehicle_type_skey    := pkg_ultramate_common.sf_get_vehicle_type(service_barcode,
                                                                       mfr_in);
      bcheckheadersequence := pkg_ultramate_common.sf_get_check_header(vehicle_type_skey);
      -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5

      -- 04/21/2011 mm5095 => add support for mtd/htd
      IF CLASS IN ('MTD', 'HTD') THEN
        vehicle_type_skey := 7;
      END IF;
      -- 04/21/2011 mm5095 => add support for mtd/htd

      --2020/07 PAG - FOR TESTING
      --DBMS_OUTPUT.put_line(mfr_in || '-' || service_in || ' ' ||
      --                     'class = ' || CLASS || 'vehicle_type = ' ||
      --                     vehicle_type_skey);

      -- load pl/sql table
      service_table := empty_service_table;
      last_row      := 0;

      FOR rec IN s_cur(mfr_in, service_in, version_in) LOOP
        -- if valid line, add to table
        IF NOT (nvl(rec.wip_tran_code, ' ') = 'D' OR rec.delete_flag != 'N' OR
            nvl(rec.forward_pointer_row_id, 0) > 0) THEN
          -- 10/11/2004 mm5095 => added support for hidden lines
          -- 07/12/04 mm5095 => added support for hidden lines
          --         if suppression_flag = 'N' or not isSuppressedCategory(rec.category_skey, rec.subcategory_skey) then
          -- 07/12/04 mm5095 => added support for hidden lines

           -- 12/30/2020 rs7649 => added support aftermarket commercial trucks parts
           IF rec.line_type IN ('A','G') THEN

               OPEN CheckPart(rec.unique_row_id, rec.version_type);
               FETCH CheckPart INTO PartCheck;
               CLOSE CheckPart;

               IF PartCheck IS NOT NULL THEN

                  OPEN GetAftermarketFlag(rec.unique_row_id, rec.version_type);
                  FETCH GetAftermarketFlag INTO Aftermarket_flag;
                  CLOSE GetAftermarketFlag;

                  IF Aftermarket_flag = 'Y' THEN
                     rec.part_type_id := 2;
                  ELSE
                     rec.part_type_id := 48;
                  END IF;

               END IF;
          END IF;
          -- 12/30/2020 rs7649 => added support aftermarket commercial trucks parts

          last_row := last_row + 1;
          service_table(last_row) := rec;
          --         end if;
          -- 10/11/2004 mm5095 => added support for hidden lines
        END IF;
      END LOOP;

      IF last_row > 0 THEN

        -- 12/05/2004 mm5095 => fixed bug in pkg_post_checkin (this is no longer needed)
        -- 10/11/2004 mm5095 => added support for hidden lines
        --    FOR n in reverse 1 .. last_row LOOP
        --      if service_table(n).line_type not in('H','S') then
        --        d_code := power(2,nvl(service_table(n).suppression_reason_code,0));
        --        service_table(n).suppression_reason_code := d_code;
        --      end if;
        --    END LOOP;
        -- 10/11/2004 mm5095 => added support for hidden lines
        -- 12/05/2004 mm5095 => fixed bug in pkg_post_checkin (this is no longer needed)

        current_row           := 1;
        bconsecutive_graphics := FALSE;
        LOOP
          BEGIN
            IF service_table(current_row).line_type IN ('A', 'G') THEN
              IF nvl(service_table(current_row).indent_level, ' ') = '0' OR
                 (nvl(service_table(current_row).indent_level, ' ') != '0' AND
                  (service_table(current_row)
                   .callout_number IS NOT NULL OR
                    nvl(service_table(current_row).inline_note_skey, 0) > 0)) THEN
                bcomponentset    := TRUE;
                bcomponentdetail := TRUE;
                bqualifierdetail := TRUE;
                ncount           := 0;
                barcode_row      := NULL;

                -- 10/11/2004 mm5095 => added support for hidden lines
                d_code := 0;
                -- 10/11/2004 mm5095 => added support for hidden lines
                FOR n IN current_row .. last_row LOOP
                  IF NOT inpartset(n, current_row) THEN
                    EXIT;
                  END IF;
                  -- 10/11/2004 mm5095 => added support for hidden lines
                  d_code := (d_code + service_table(n).suppression_reason_code) -
                            bitand(d_code,
                                   service_table(n).suppression_reason_code);
                  -- 10/11/2004 mm5095 => added support for hidden lines

                  IF service_table(n).line_type IN ('A', 'G') THEN
                    IF nvl(service_table(n).component_skey, 0) !=
                       nvl(service_table(current_row).component_skey, 0) THEN
                      bcomponentset := FALSE;
                    END IF;

                    IF nvl(service_table(n).barcode, ' ') != ' ' THEN
                      IF barcode_row IS NULL THEN
                        barcode_row := n;
                      END IF;

                      IF nvl(service_table(n).component_skey, 0) !=
                         nvl(service_table(barcode_row).component_skey, 0) THEN
                        bcomponentdetail := FALSE;
                      END IF;

                      IF nvl(service_table(n).qgroup_skey, 0) !=
                         nvl(service_table(barcode_row).qgroup_skey, 0) THEN
                        bqualifierdetail := FALSE;
                      END IF;

                      ncount := ncount + 1;
                    END IF;
                  END IF;
                END LOOP;

                IF ncount = 0 THEN
                  -- part inline note only line
                  IF nvl(service_table(current_row).inline_note_skey, 0) > 0 THEN
                    -- 10/11/2004 mm5095 => added support for hidden lines
                    addpart(nvl(service_table(current_row).callout_number,
                                ' '),
                            getparttext(current_row, '1', TRUE, TRUE),
                            current_row,
                            d_code);
                    --              AddPart(nvl(service_table(current_row).callout_number,' '),getPartText(current_row,'1',true, true), current_row);
                    -- 10/11/2004 mm5095 => added support for hidden lines
                  ELSE
                    -- 10/11/2004 mm5095 => added support for hidden lines
                    d_code := 0;
                    -- 10/11/2004 mm5095 => added support for hidden lines
                    FOR n IN current_row .. last_row LOOP
                      IF NOT inpartset(n, current_row) THEN
                        current_row := n - 1;
                        EXIT;
                      END IF;

                      -- 10/11/2004 mm5095 => added support for hidden lines
                      d_code := (d_code + service_table(n).suppression_reason_code) -
                                bitand(d_code,
                                       service_table(n).suppression_reason_code);
                      -- 10/11/2004 mm5095 => added support for hidden lines
                      IF nvl(service_table(n).inline_note_skey, 0) > 0 THEN
                        IF nvl(service_table(n).callout_number, ' ') != ' ' THEN
                          -- 10/11/2004 mm5095 => added support for hidden lines
                          addpart(nvl(service_table(n).callout_number, ' '),
                                  getparttext(n, '1', TRUE, TRUE),
                                  n,
                                  d_code);
                          d_code := 0;
                          --                    AddPart(nvl(service_table(n).callout_number,' '),getPartText(n,'1',true, true), n);
                          -- 10/11/2004 mm5095 => added support for hidden lines
                        ELSE
                          -- 10/11/2004 mm5095 => added support for hidden lines
                          addpart(nvl(service_table(current_row).callout_number,
                                      ' '),
                                  getparttext(n, '1', TRUE, TRUE),
                                  n,
                                  d_code);
                          d_code := 0;
                          --                    AddPart(nvl(service_table(current_row).callout_number,' '),getPartText(n,'1',true,true), n);
                          -- 10/11/2004 mm5095 => added support for hidden lines
                        END IF;
                        current_row := n;
                        EXIT;
                      END IF;
                    END LOOP;
                  END IF;
                ELSE
                  IF bcomponentset THEN
                    IF ncount = 1 THEN
                      -- 07/11/02 mm5095 => fix single detail preceded by detail line with inline note
                      -- 10/11/2004 mm5095 => added support for hidden lines
                      d_code := 0;
                      -- 10/11/2004 mm5095 => added support for hidden lines
                      FOR n IN current_row .. barcode_row LOOP
                        IF NOT inpartset(n, current_row) THEN
                          EXIT;
                        END IF;

                        -- 10/11/2004 mm5095 => added support for hidden lines
                        d_code := (d_code + service_table(n).suppression_reason_code) -
                                  bitand(d_code,
                                         service_table(n).suppression_reason_code);
                        -- 10/11/2004 mm5095 => added support for hidden lines
                        IF nvl(service_table(n).barcode, ' ') = ' ' AND
                           nvl(service_table(n).indent_level, ' ') != '0' AND
                           nvl(service_table(n).inline_note_skey, 0) > 0 THEN
                          -- part inline note only detail line
                          -- 10/11/2004 mm5095 => added support for hidden lines
                          addpart(nvl(service_table(n).callout_number, ' '),
                                  getparttext(n, '1', TRUE, TRUE),
                                  n,
                                  d_code);
                          d_code := 0;
                          --                    AddPart(nvl(service_table(n).callout_number,' '),getPartText(n,'1',true,true), n);
                          -- 10/11/2004 mm5095 => added support for hidden lines
                        END IF;
                      END LOOP;
                      -- 07/11/02 mm5095 => fix single detail preceded by detail line with inline note

                      IF nvl(service_table(current_row).callout_number, ' ') != ' ' THEN
                        -- 10/11/2004 mm5095 => added support for hidden lines
                        IF d_code = 0 THEN
                          d_code := service_table(barcode_row).suppression_reason_code;
                        END IF;

                        addpart(service_table(current_row).callout_number,
                                getparttext(barcode_row, '1', TRUE, TRUE),
                                barcode_row,
                                d_code);
                        --                  AddPart(service_table(current_row).callout_number,getPartText(barcode_row,'1',true,true), barcode_row);
                        -- 10/11/2004 mm5095 => added support for hidden lines
                        IF nvl(service_table(current_row).indent_level, 'Q') != 'Q' THEN
                          part_indent_level := service_table(current_row).indent_level;
                        END IF;
                      ELSE
                        -- 10/11/2004 mm5095 => added support for hidden lines
                        IF d_code = 0 THEN
                          d_code := service_table(barcode_row).suppression_reason_code;
                        END IF;

                        addpart(nvl(service_table(barcode_row).callout_number,
                                    ' '),
                                getparttext(barcode_row, '1', TRUE, TRUE),
                                barcode_row,
                                d_code);
                        --                  AddPart(nvl(service_table(barcode_row).callout_number,' '),getPartText(barcode_row,'1',true,true), barcode_row);
                        -- 10/11/2004 mm5095 => added support for hidden lines
                        IF nvl(service_table(barcode_row).indent_level, 'Q') != 'Q' THEN
                          part_indent_level := service_table(barcode_row).indent_level;
                        END IF;
                      END IF;
                      npart_detail := npart;
                      addpartdetail(barcode_row,
                                    getparttext(barcode_row, '1', TRUE),
                                    TRUE);
                      current_row := barcode_row;
                    ELSE
                      IF bqualifierdetail THEN
                        IF nvl(service_table(barcode_row).qgroup_skey, 0) > 0 THEN
                          -- 10/11/2004 mm5095 => added support for hidden lines
                          addpart(nvl(service_table(current_row).callout_number,
                                      ' '),
                                  getparttext(barcode_row, '1', TRUE),
                                  barcode_row,
                                  d_code);
                          --                    AddPart(nvl(service_table(current_row).callout_number,' '),getPartText(barcode_row,'1',true), barcode_row);
                          -- 10/11/2004 mm5095 => added support for hidden lines
                          IF nvl(service_table(current_row).indent_level,
                                 'Q') != 'Q' THEN
                            part_indent_level := service_table(current_row).indent_level;
                          END IF;
                        ELSE
                          IF nvl(service_table(current_row).callout_number,
                                 ' ') != ' ' THEN
                            -- 10/11/2004 mm5095 => added support for hidden lines
                            addpart(nvl(service_table(current_row).callout_number,
                                        ' '),
                                    getparttext(barcode_row, '1', TRUE),
                                    barcode_row,
                                    d_code);
                            --                      AddPart(nvl(service_table(current_row).callout_number,' '),getPartText(barcode_row,'1',true), barcode_row);
                            -- 10/11/2004 mm5095 => added support for hidden lines
                            IF nvl(service_table(current_row).indent_level,
                                   'Q') != 'Q' THEN
                              part_indent_level := service_table(current_row).indent_level;
                            END IF;
                          ELSE
                            -- 10/11/2004 mm5095 => added support for hidden lines
                            addpart(nvl(service_table(barcode_row).callout_number,
                                        ' '),
                                    getparttext(barcode_row, '1', TRUE),
                                    barcode_row,
                                    d_code);
                            --                      AddPart(nvl(service_table(barcode_row).callout_number,' '),getPartText(barcode_row,'1',true), barcode_row);
                            -- 10/11/2004 mm5095 => added support for hidden lines
                            IF nvl(service_table(barcode_row).indent_level,
                                   'Q') != 'Q' THEN
                              part_indent_level := service_table(barcode_row).indent_level;
                            END IF;
                          END IF;
                        END IF;

                        npart_detail := npart;

                        -- 10/11/2004 mm5095 => added support for hidden lines
                        d_code := 0;
                        -- 10/11/2004 mm5095 => added support for hidden lines
                        FOR n IN current_row .. last_row LOOP
                          IF NOT inpartset(n, current_row) THEN
                            current_row := n - 1;
                            EXIT;
                          END IF;

                          -- 10/11/2004 mm5095 => added support for hidden lines
                          d_code := (d_code + service_table(n).suppression_reason_code) -
                                    bitand(d_code,
                                           service_table(n).suppression_reason_code);
                          -- 10/11/2004 mm5095 => added support for hidden lines
                          IF nvl(service_table(n).barcode, ' ') != ' ' THEN
                            IF nvl(service_table(n).qgroup_skey, 0) > 0 THEN
                              addpartdetail(n,
                                            getqualifiernotestring(n,
                                                                   current_row,
                                                                   part_indent_level + 2,
                                                                   FALSE),
                                            ncount = 1);
                            ELSE
                              addpartdetail(n, NULL, ncount = 1);
                            END IF;
                          ELSE
                            IF nvl(service_table(n).indent_level, ' ') != '0' AND
                               nvl(service_table(n).inline_note_skey, 0) > 0 THEN
                              -- part inline note only detail line
                              -- 10/11/2004 mm5095 => added support for hidden lines
                              addpart(nvl(service_table(n).callout_number,
                                          ' '),
                                      getparttext(n, '1', TRUE, TRUE),
                                      n,
                                      d_code);
                              d_code := 0;
                              --                        AddPart(nvl(service_table(n).callout_number,' '),getPartText(n,'1',true,true), n);
                              -- 10/11/2004 mm5095 => added support for hidden lines
                            END IF;
                          END IF;

                          IF n = last_row THEN
                            current_row := last_row;
                            EXIT;
                          END IF;
                        END LOOP;
                      ELSE
                        -- component same, qualifiers differ
                        -- 10/11/2004 mm5095 => added support for hidden lines
                        addpart(nvl(service_table(current_row).callout_number,
                                    ' '),
                                getparttext(current_row, '1', TRUE),
                                current_row,
                                d_code);
                        --                  AddPart(nvl(service_table(current_row).callout_number,' '),getPartText(current_row,'1',true), current_row);
                        -- 10/11/2004 mm5095 => added support for hidden lines
                        IF nvl(service_table(current_row).indent_level, 'Q') != 'Q' THEN
                          part_indent_level := service_table(current_row).indent_level;
                        END IF;
                        npart_detail := npart;
                        -- 10/11/2004 mm5095 => added support for hidden lines
                        d_code := 0;
                        -- 10/11/2004 mm5095 => added support for hidden lines
                        FOR n IN current_row .. last_row LOOP
                          IF NOT inpartset(n, current_row) THEN
                            current_row := n - 1;
                            EXIT;
                          END IF;

                          -- 10/11/2004 mm5095 => added support for hidden lines
                          d_code := (d_code + service_table(n).suppression_reason_code) -
                                    bitand(d_code,
                                           service_table(n).suppression_reason_code);
                          -- 10/11/2004 mm5095 => added support for hidden lines
                          IF nvl(service_table(n).indent_level, 'Q') != 'Q' THEN
                            last_indent_level := service_table(n).indent_level;
                          END IF;

                          IF nvl(service_table(current_row).indent_level,
                                 ' ') != '0' AND
                             last_indent_level <
                             nvl(service_table(current_row).indent_level,
                                 ' ') THEN
                            -- 10/11/2004 mm5095 => added support for hidden lines
                            addpart(nvl(service_table(n).callout_number,
                                        ' '),
                                    getparttext(n, '1', TRUE),
                                    n,
                                    d_code);
                            d_code := 0;
                            --                      AddPart(nvl(service_table(n).callout_number,' '),getPartText(n,'1',true),n);
                            -- 10/11/2004 mm5095 => added support for hidden lines
                            part_indent_level := last_indent_level;
                            npart_detail      := npart;
                            current_row       := n;
                            -- 08/06/02 mm5095 fix: not outputing all detail lines
                            IF nvl(service_table(n).barcode, ' ') != ' ' THEN
                              addpartdetail(n,
                                            pkg_ultramate_common.sf_getqualifierstring(service_table(n).qgroup_skey,
                                                                                       part_indent_level + 2,
                                                                                       FALSE),
                                            ncount = 1);
                            END IF;
                            -- 08/06/02 mm5095 fix: not outputing all detail lines
                          ELSIF n != current_row AND
                                nvl(service_table(n).indent_level, ' ') = '0' AND
                                n > 1 AND service_table(n - 1).line_type IN
                                ('A', 'G') AND
                                nvl(service_table(n - 1).indent_level, 'Q') = 'Q' THEN
                            -- 10/11/2004 mm5095 => added support for hidden lines
                            addpart(nvl(service_table(n).callout_number,
                                        ' '),
                                    getparttext(n, '1', TRUE),
                                    n,
                                    d_code);
                            d_code := 0;
                            --                      AddPart(nvl(service_table(n).callout_number,' '),getPartText(n,'1',true),n);
                            -- 10/11/2004 mm5095 => added support for hidden lines
                            IF nvl(service_table(n).indent_level, 'Q') != 'Q' THEN
                              part_indent_level := service_table(n).indent_level;
                            END IF;
                            npart_detail := npart;
                            current_row  := n;
                            -- 08/06/02 mm5095 fix: not outputing all detail lines
                            IF nvl(service_table(n).barcode, ' ') != ' ' THEN
                              addpartdetail(n,
                                            pkg_ultramate_common.sf_getqualifierstring(service_table(n).qgroup_skey,
                                                                                       part_indent_level + 2,
                                                                                       FALSE),
                                            ncount = 1);
                            END IF;
                            -- 08/06/02 mm5095 fix: not outputing all detail lines
                          ELSIF nvl(service_table(current_row).indent_level,
                                    ' ') != '0' AND
                                nvl(service_table(current_row).callout_number,
                                    ' ') != ' ' AND
                                nvl(service_table(n).indent_level, ' ') =
                                nvl(service_table(current_row).indent_level,
                                    ' ')
                               -- 08/06/02 mm5095
                               --                      and nvl(service_table(n).qgroup_skey,0) != nvl(service_table(current_row).qgroup_skey,0) then
                                AND nvl(service_table(n).qgroup_skey, 0) !=
                                nvl(service_table(current_row).qgroup_skey,
                                        0) AND
                                nvl(service_table(n).barcode, ' ') != ' ' THEN
                            -- 08/06/02 mm5095

                            -- 10/11/2004 mm5095 => added support for hidden lines
                            addpart(nvl(service_table(n).callout_number,
                                        ' '),
                                    getparttext(n, '1', TRUE),
                                    n,
                                    d_code);
                            d_code := 0;
                            --                        AddPart(nvl(service_table(n).callout_number,' '),getPartText(n,'1',true),n);
                            -- 10/11/2004 mm5095 => added support for hidden lines
                            IF nvl(service_table(n).indent_level, 'Q') != 'Q' THEN
                              part_indent_level := service_table(n).indent_level;
                            END IF;

                            npart_detail := npart;
                            current_row  := n;
                            -- 08/06/02 mm5095
                            addpartdetail(n,
                                          pkg_ultramate_common.sf_getqualifierstring(service_table(n).qgroup_skey,
                                                                                     part_indent_level + 2,
                                                                                     FALSE),
                                          ncount = 1);
                            -- 08/06/02 mm5095
                          ELSIF nvl(service_table(n).barcode, ' ') = ' ' THEN
                            IF nvl(service_table(n).indent_level, ' ') != '0' AND
                               nvl(service_table(n).inline_note_skey, 0) > 0 THEN
                              -- part inline note only detail line
                              -- 10/11/2004 mm5095 => added support for hidden lines
                              -- 08/22/2006 => correct hidden line inline note error
                              addpart(nvl(service_table(n).callout_number,
                                          ' '),
                                      getparttext(n, '1', TRUE, TRUE),
                                      n,
                                      service_table(n).suppression_reason_code);
                              --                        AddPart(nvl(service_table(n).callout_number,' '),getPartText(n,'1',true,true), n, d_code);
                              -- 08/22/2006 => correct hidden line inline note error
                              d_code := 0;
                              --                        AddPart(nvl(service_table(n).callout_number,' '),getPartText(n,'1',true,true), n);
                              -- 10/11/2004 mm5095 => added support for hidden lines
                            END IF;
                          ELSE
                            addpartdetail(n,
                                          pkg_ultramate_common.sf_getqualifierstring(service_table(n).qgroup_skey,
                                                                                     part_indent_level + 2,
                                                                                     FALSE),
                                          ncount = 1);
                          END IF;

                          IF n = last_row THEN
                            current_row := last_row;
                            EXIT;
                          END IF;
                        END LOOP;
                      END IF;
                    END IF;
                  ELSE
                    -- component and/or qualifiers are different
                    -- 10/11/2004 mm5095 => added support for hidden lines
                    addpart(nvl(service_table(current_row).callout_number,
                                ' '),
                            getparttext(current_row, '1', TRUE),
                            current_row,
                            d_code);
                    --              AddPart(nvl(service_table(current_row).callout_number,' '),getPartText(current_row,'1',true), current_row);
                    -- 10/11/2004 mm5095 => added support for hidden lines
                    IF nvl(service_table(current_row).indent_level, 'Q') != 'Q' THEN
                      part_indent_level := service_table(current_row).indent_level;
                    END IF;
                    npart_detail := npart;

                    FOR n IN current_row .. last_row LOOP
                      IF NOT inpartset(n, current_row) THEN
                        EXIT;
                      END IF;

                      IF nvl(service_table(n).barcode, ' ') != ' ' THEN
                        addpartdetail(n,
                                      getparttext(n,
                                                  part_indent_level + 2,
                                                  nvl(service_table(n).inline_note_skey,
                                                      0) != nvl(service_table(current_row).inline_note_skey,
                                                                0)),
                                      ncount = 1);
                      END IF;

                      IF n = last_row THEN
                        current_row := last_row;
                        EXIT;
                      END IF;
                    END LOOP;
                  END IF;
                END IF;
              END IF;
            ELSIF service_table(current_row).line_type IN ('C', 'K', 'R') THEN
              pkg_ultramate_common.getnoteid_by_skey(service_table(current_row).note_group_skey,
                                                     note_type,
                                                     note_id,
                                                     run_type,
                                                     gparallelnumber);
              IF bdummysection THEN
/* -- File generation disabled: DH[barcode].txt write (FTP sunset)
                utl_file.put_line(pnote_fhandle,
                                  nheader || '|0|0|' || note_type || '|' ||
                                  note_id);
-- end commented block */
                -- 04/05/2018 pb0690 => added
                pkg_ultramate_common.insert_um_data_dh(service_barcode_in,
                                                       nheader,
                                                       0,
                                                       note_type,
                                                       0,
                                                       note_id);

              ELSE
/* -- File generation disabled: DH[barcode].txt write (FTP sunset)
                utl_file.put_line(pnote_fhandle,
                                  nheader || '|' || nsection || '|0|' ||
                                  note_type || '|' || note_id);
-- end commented block */
                -- 04/05/2018 pb0690 => added
                pkg_ultramate_common.insert_um_data_dh(service_barcode_in,
                                                       nheader,
                                                       nsection,
                                                       0,
                                                       note_type,
                                                       note_id);

              END IF;
            ELSIF service_table(current_row).line_type = 'H' THEN
              nheader           := nheader + 1;
              nsection          := 0;
              npart             := 0;
              rightoverhaultime := 0;
              leftoverhaultime  := 0;
              bdummysection     := FALSE;
              my_category       := pkg_ultramate_common.sf_getcategorystring(service_table(current_row).category_skey);
              -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
              IF bcheckheadersequence THEN
                header_sequence := pkg_ultramate_common.sf_get_header_sequence(vehicle_type_skey,
                                                                               mfr_in,
                                                                               service_table(current_row).category_skey,
                                                                               header_offset,
                                                                               ceg_offset);
              ELSE
                header_sequence := 0;
              END IF;

              -- 05/09/2008 mm5095 => added support for mixed case Category description
              mc_category := pkg_ultramate_common.sf_getmixedcasecategory(my_category);
              -- 05/09/2008 mm5095 => added support for mixed case Category description

              -- 09/28/2015 mm5095
              line_text_skey := sf_get_line_text_skey(my_category,
                                                      mc_category);
              -- 09/28/2015 mm5095

              -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
/* -- File generation disabled: DA[barcode].txt write (FTP sunset)
              utl_file.put_line(header_fhandle,
                                nheader || '|' || rtrim(my_category)
                                -- 10/11/2004 mm5095 => added support for hidden lines
                                 || '|' || service_table(current_row).suppression_reason_code
                                -- 10/11/2004 mm5095 => added support for hidden lines
                                -- 05/09/2008 mm5095 => added support for mixed case Category description
                                 || '|' || mc_category
                                -- 05/09/2008 mm5095 => added support for mixed case Category description
                                -- 09/28/2015 mm5095
                                 || '|' || line_text_skey
                                -- 09/28/2015 mm5095
                                -- 02/09/2017 mm5095
                                 || '|' ||
                                 pkg_ultramate_common.sf_getfrench(line_text_skey,
                                                                   mc_category)
                                -- 02/09/2017 mm5095
                                );
-- end commented block */

              -- 04/05/2018 pb0690 => added
              BEGIN
                INSERT /*+ insert_um_data_da */
                INTO um_data_da
                  (service,
                   category_skey,
                   category,
                   last_update_user,
                   last_update_date,
                   suppression_reason_code)
                VALUES
                  (to_char(service_barcode_in),
                   nheader,
                   rtrim(my_category),
                   USER,
                   SYSDATE,
                   service_table(current_row).suppression_reason_code);
              EXCEPTION
                WHEN OTHERS THEN
                  dbms_output.put_line('pkg_ultramate_build - Pre-parse error inserting into um_data_da' ||
                                       ' Error : ' || SQLCODE ||
                                       ': trying to insert' ||
                                       to_char(service_barcode_in) || ' ' ||
                                       nheader || ' ' ||
                                       rtrim(my_category) || ' ' || service_table(current_row).suppression_reason_code || ' ' ||
                                       substr(SQLERRM, 1, 120));
              END;

              glowerdate := nvl(service_table(current_row).lower_effectivity_date,
                                to_date('01/01/2099', 'MM/DD/YYYY'));
              gupperdate := nvl(service_table(current_row).upper_effectivity_date,
                                to_date('01/01/2099', 'MM/DD/YYYY'));

              -- get ppage text
              my_text := sf_getppagetext(CLASS,
                                         mfr_in,
                                         service_in,
                                         version_in,
                                         service_table(current_row).category_skey);
              IF my_text IS NOT NULL THEN
                pkg_ultramate_common.getnoteid_by_text(my_text,
                                                       215,
                                                       note_id,
                                                       run_type,
                                                       gparallelnumber);
/* -- File generation disabled: DH[barcode].txt write (FTP sunset)
                utl_file.put_line(pnote_fhandle,
                                  nheader || '|0|0|215|' || note_id);
-- end commented block */
                -- 04/05/2018 pb0690 => added
                pkg_ultramate_common.insert_um_data_dh(to_char(service_barcode_in),
                                                       nheader,
                                                       0,
                                                       0,
                                                       215,
                                                       note_id);

              END IF;
              -- 04/12/2006 mm5095 => add support for atg graphics UM 6.5
            ELSIF service_table(current_row).line_type = 'I' THEN
              --        elsif service_table(current_row).line_type = 'I' and mfr_in != '006' then -- ignore ATG graphics
              -- 04/12/2006 mm5095 => add support for atg graphics UM 6.5
              -- save previous graphic info just in case 2 graphics before part details

              graphic_file_name_pre := graphic_file_name;

              nimage_pre := nimage;

              graphic_file_name := service_table(current_row).graphic_file_name;

              -- 09/25/02 mm5095 => unique graphic fix
              BEGIN
                SELECT /*+ tmp_um_graphic select */
                 graphic_id
                  INTO nimage
                  FROM tmp_um_graphic
                 WHERE graphic_name = graphic_file_name;
              EXCEPTION
                WHEN no_data_found THEN
                  SELECT MAX(graphic_id) INTO nimage FROM tmp_um_graphic;

                  IF nimage IS NULL THEN
                    nimage := 0;
                  END IF;

                  nimage := nimage + 1;
                  INSERT INTO tmp_um_graphic
                  VALUES
                    (nimage, graphic_file_name);

                  --          nimage := nimage + 1;
/* -- File generation disabled: DK[barcode].txt write (FTP sunset)
                  utl_file.put_line(graphic_fhandle,
                                    nimage || '|' || service_table(current_row).graphic_file_name ||
                                    '.tif');
-- end commented block */

                  -- 09/22/2009 mm5095: added to support color graphics
                  BEGIN
                    SELECT a.graphic_file_name
                      INTO tmp_graphic_file_name
                    -- 02/24/2011 mm5095 => limit color graphics to special materials
                      FROM graphic a, special_material_graphic b
                     WHERE a.graphic_file_name = service_table(current_row)
                          .graphic_file_name || '.png'
                       AND b.graphic_file_name = a.graphic_file_name;
                    --              FROM graphic a
                    --              WHERE a.graphic_file_name = service_table(current_row).graphic_file_name || '.png';
                    -- 02/24/2011 mm5095 => limit color graphics to special materials
/* -- File generation disabled: DM[barcode].txt write (FTP sunset)
                    utl_file.put_line(color_graphic_fhandle,
                                      nimage || '|' || graphic_file_name ||
                                      '.png');
-- end commented block */
                  EXCEPTION
                    WHEN OTHERS THEN
/* -- File generation disabled: DM[barcode].txt write (FTP sunset)
                      utl_file.put_line(color_graphic_fhandle,
                                        nimage || '|' || graphic_file_name ||
                                        '.tif');
-- end commented block */
                      NULL; -- FTP sunset: placeholder for disabled put_line
                  END;
                  -- 09/22/2009 mm5095: added to support color graphics
                  -- 04/05/2018 pb0690 => added
                  IF run_type = 'MINI' THEN
                    BEGIN
                      INSERT /*+ insert_um_data_dk */
                      INTO um_data_dk
                        (service, image_skey, graphic_file_name)
                      VALUES
                        (to_char(service_barcode_in),
                         nimage,
                         service_table(current_row).graphic_file_name);
                    EXCEPTION
                      WHEN OTHERS THEN
                        dbms_output.put_line('pkg_ultramate_build - Parse error inserting into um_data_dk');
                        dbms_output.put_line('Error : ' || SQLCODE || ': ' ||
                                             substr(SQLERRM, 1, 120));
                    END;
                  END IF;
              END;
              -- 09/25/02 mm5095 => unique graphic fix

              -- 04/21/2011 mm5095 => add support for mtd/htd
              IF mfr_in = '006' OR my_category = 'UNDERHOOD DIMENSIONS' OR
                 NOT hashotspot(graphic_file_name) THEN
                -- 04/12/2006 mm5095 => add support for atg graphics UM 6.5
                --          if mfr_in = '006' or my_category = 'UNDERHOOD DIMENSIONS' then
                -- 04/21/2011 mm5095 => add support for mtd/htd
                --          if my_category = 'UNDERHOOD DIMENSIONS' then
                -- 04/12/2006 mm5095 => add support for atg graphics UM 6.5
                IF bdummysection THEN
/* -- File generation disabled: DE[barcode].txt write (FTP sunset)
                  utl_file.put_line(hotspot_fhandle,
                                    nheader || '|0|0|' || nimage ||
                                    '|0|0|0|0|0');
-- end commented block */

                  -- 04/05/2018 pb0690 => added
                  pkg_ultramate_common.insert_um_data_de(to_char(service_barcode_in),
                                                         nheader,
                                                         0,
                                                         0,
                                                         nimage,
                                                         0,
                                                         0,
                                                         0,
                                                         0,
                                                         0);

                  -- 09/22/2009 mm5095: added to support color graphics
/* -- File generation disabled: DN[barcode].txt write (FTP sunset)
                  utl_file.put_line(color_hotspot_fhandle,
                                    nheader || '|0|0|' || nimage ||
                                    '|0|0|0|0|0');
-- end commented block */
                  -- 09/22/2009 mm5095: added to support color graphics
                ELSE
/* -- File generation disabled: DE[barcode].txt write (FTP sunset)
                  utl_file.put_line(hotspot_fhandle,
                                    nheader || '|' || nsection || '|0|' ||
                                    nimage || '|0|0|0|0|0');
-- end commented block */
                  -- 09/22/2009 mm5095: added to support color graphics
/* -- File generation disabled: DN[barcode].txt write (FTP sunset)
                  utl_file.put_line(color_hotspot_fhandle,
                                    nheader || '|' || nsection || '|0|' ||
                                    nimage || '|0|0|0|0|0');
-- end commented block */
                  -- 09/22/2009 mm5095: added to support color graphics
                  -- 04/05/2018 pb0690 => added
                  pkg_ultramate_common.insert_um_data_de(to_char(service_barcode_in),
                                                         nheader,
                                                         nsection,
                                                         0,
                                                         nimage,
                                                         0,
                                                         0,
                                                         0,
                                                         0,
                                                         0);

                END IF;
              END IF;
            ELSIF service_table(current_row)
             .line_type = 'N' AND
                   nvl(service_table(current_row).indent_level, ' ') = '0' THEN

              blaborverbset    := TRUE;
              bcomponentset    := TRUE;
              blaborverbdetail := TRUE;
              bcomponentdetail := TRUE;
              bqualifierdetail := TRUE;
              ncount           := 0;
              barcode_row      := NULL;

              -- 10/11/2004 mm5095 => added support for hidden lines
              d_code := 0;
              -- 10/11/2004 mm5095 => added support for hidden lines

              FOR n IN current_row .. last_row LOOP
                IF NOT inlaborset(n, current_row) THEN
                  EXIT;
                END IF;

                -- 10/11/2004 mm5095 => added support for hidden lines
                d_code := (d_code + service_table(n).suppression_reason_code) -
                          bitand(d_code,
                                 service_table(n).suppression_reason_code);
                -- 10/11/2004 mm5095 => added support for hidden lines

                IF service_table(n).line_type = 'N' THEN
                  IF nvl(service_table(n).labor_verb_skey, 0) !=
                     nvl(service_table(current_row).labor_verb_skey, 0) THEN
                    blaborverbset := FALSE;
                  END IF;

                  IF nvl(service_table(n).component_skey, 0) !=
                     nvl(service_table(current_row).component_skey, 0) THEN
                    bcomponentset := FALSE;
                  END IF;

                  IF nvl(service_table(n).barcode, ' ') != ' ' THEN
                    IF barcode_row IS NULL THEN
                      barcode_row := n;
                    END IF;

                    IF nvl(service_table(n).labor_verb_skey, 0) !=
                       nvl(service_table(barcode_row).labor_verb_skey, 0) THEN
                      blaborverbdetail := FALSE;
                    END IF;

                    IF nvl(service_table(n).component_skey, 0) !=
                       nvl(service_table(barcode_row).component_skey, 0) THEN
                      bcomponentdetail := FALSE;
                    END IF;

                    IF nvl(service_table(n).qgroup_skey, 0) !=
                       nvl(service_table(barcode_row).qgroup_skey, 0) THEN
                      bqualifierdetail := FALSE;
                    END IF;

                    ncount := ncount + 1;
                  END IF;
                END IF;
              END LOOP;

              IF ncount = 0 THEN
                IF pkg_ultramate_common.sf_getcategorystring(service_table(current_row).category_skey) =
                   'CHASSIS TYPE' THEN
                  create_chassis_notes(current_row, last_row);
                ELSE
                  dbms_output.put_line('N line nCount is null at: ' ||
                                       service_barcode || ' ' || mfr_in || ' ' ||
                                       service_in || ' ' || version_in || ' ' || service_table(current_row).unique_row_id);
                END IF;
              ELSE
                IF blaborverbset AND bcomponentset THEN
                  IF ncount = 1 THEN
                    IF nvl(service_table(current_row).barcode, ' ') = ' ' THEN
                      -- 10/11/2004 mm5095 => added support for hidden lines
                      addlaborpart(getlabortext(barcode_row, TRUE),
                                   current_row,
                                   last_row,
                                   d_code);
                      --                  AddLaborPart(getLaborText(barcode_row,true),current_row,last_row,version_in,false,d_code);
                      --                  AddLaborPart(getLaborText(barcode_row,true),current_row,last_row,version_in,false);
                      -- 10/11/2004 mm5095 => added support for hidden lines
                    ELSE
                      -- 10/11/2004 mm5095 => added support for hidden lines
                      addlaborpart(getlabortext(current_row, TRUE),
                                   current_row,
                                   last_row,
                                   d_code);
                      --                  AddLaborPart(getLaborText(current_row,true),current_row,last_row,version_in,false,d_code);
                      --                  AddLaborPart(getLaborText(current_row,true),current_row,last_row,version_in,false);
                      -- 10/11/2004 mm5095 => added support for hidden lines
                    END IF;
                    -- 10/11/2004 mm5095 => added support for hidden lines
                    d_code := 0;
                    -- 10/11/2004 mm5095 => added support for hidden lines
                    npart_detail := npart;
                    IF nvl(service_table(barcode_row).detail_qgroup_skey, 0) > 0 THEN
                      addlabordetail(barcode_row,
                                     getqualifiernotestring(barcode_row,
                                                            current_row,
                                                            '1',
                                                            FALSE));
                    ELSE
                      addlabordetail(barcode_row,
                                     getlabortext(barcode_row, TRUE));
                    END IF;
                  ELSE
                    IF bqualifierdetail THEN
                      -- 10/11/2004 mm5095 => added support for hidden lines
                      addlaborpart(getlabortext(barcode_row, TRUE),
                                   current_row,
                                   last_row,
                                   d_code);
                      --                  AddLaborPart(getLaborText(barcode_row,true),current_row,last_row,version_in,false,d_code);
                      --                  AddLaborPart(getLaborText(barcode_row,true),current_row,last_row,version_in,false);
                      -- 10/11/2004 mm5095 => added support for hidden lines
                      npart_detail := npart;
                      FOR n IN current_row .. last_row LOOP
                        IF NOT inlaborset(n, current_row) THEN
                          current_row := n - 1;
                          EXIT;
                        END IF;

                        IF nvl(service_table(n).barcode, ' ') != ' ' THEN
                          addlabordetail(n, NULL);
                        END IF;

                        IF n = last_row THEN
                          current_row := last_row;
                          EXIT;
                        END IF;
                      END LOOP;
                    ELSE
                      -- labor verb and component same, qualifiers differ
                      -- 10/11/2004 mm5095 => added support for hidden lines
                      addlaborpart(getlaborverbcomponent(current_row, TRUE),
                                   current_row,
                                   last_row,
                                   d_code);
                      --                  AddLaborPart(getLaborVerbComponent(current_row,true),current_row,last_row,version_in,false, d_code);
                      --                  AddLaborPart(getLaborVerbComponent(current_row,true),current_row,last_row,version_in,false);
                      -- 10/11/2004 mm5095 => added support for hidden lines
                      npart_detail := npart;
                      FOR n IN current_row .. last_row LOOP
                        IF NOT inlaborset(n, current_row) THEN
                          current_row := n - 1;
                          EXIT;
                        END IF;

                        IF nvl(service_table(n).barcode, ' ') != ' ' THEN
                          addlabordetail(n,
                                         pkg_ultramate_common.sf_getqualifierstring(service_table(n).qgroup_skey,
                                                                                    '1',
                                                                                    FALSE));
                        END IF;

                        IF n = last_row THEN
                          current_row := last_row;
                          EXIT;
                        END IF;
                      END LOOP;
                    END IF;
                  END IF;
                ELSIF blaborverbset THEN
                  -- 10/11/2004 mm5095 => added support for hidden lines
                  addlaborpart(getlaborverbcomponent(current_row, TRUE),
                               current_row,
                               last_row,
                               d_code);
                  --              AddLaborPart(getLaborVerbComponent(current_row,true),current_row,last_row,version_in,false,d_code);
                  --              AddLaborPart(getLaborVerbComponent(current_row,true),current_row,last_row,version_in,false);
                  -- 10/11/2004 mm5095 => added support for hidden lines
                  npart_detail := npart;
                  FOR n IN current_row .. last_row LOOP
                    IF NOT inlaborset(n, current_row) THEN
                      current_row := n - 1;
                      EXIT;
                    END IF;

                    IF nvl(service_table(n).barcode, ' ') != ' ' THEN
                      addlabordetail(n,
                                     getlabortext(n,
                                                  nvl(service_table(n).inline_note_skey,
                                                      0) != nvl(service_table(current_row).inline_note_skey,
                                                                0)));
                    END IF;

                    IF n = last_row THEN
                      current_row := last_row;
                      EXIT;
                    END IF;
                  END LOOP;
                ELSE
                  -- labor verb, component and/or qualifiers are different
                  IF nvl(service_table(current_row).barcode, ' ') = ' ' THEN
                    IF blaborverbdetail AND bcomponentdetail AND
                       bqualifierdetail THEN
                      barcode_row := NULL;
                      FOR n IN current_row .. last_row LOOP
                        IF NOT inlaborset(n, current_row) THEN
                          current_row := n - 1;
                          EXIT;
                        END IF;

                        -- 10/11/2004 mm5095 => added support for hidden lines
                        d_code := (d_code + service_table(n).suppression_reason_code) -
                                  bitand(d_code,
                                         service_table(n).suppression_reason_code);
                        -- 10/11/2004 mm5095 => added support for hidden lines
                        IF nvl(service_table(n).barcode, ' ') != ' ' THEN
                          barcode_row := n;
                          EXIT;
                        END IF;
                      END LOOP;

                      IF barcode_row IS NULL THEN
                        dbms_output.put_line('Error, no barcode row found at: ' || service_table(current_row).unique_row_id);
                      ELSE
                        IF nvl(service_table(current_row).labor_verb_skey,
                               0) != nvl(service_table(barcode_row).labor_verb_skey,
                                         0) THEN
                          temp_text := getlabortext(barcode_row, TRUE);
                          IF substr(temp_text, 1, 3) = 'To ' OR
                             substr(temp_text, 1, 4) = 'For ' OR
                             substr(temp_text, 1, 4) = 'Aim ' THEN
                            -- 10/11/2004 mm5095 => added support for hidden lines
                            addlaborpart(getlabortext(current_row, FALSE) || ' ' ||
                                         temp_text,
                                         current_row,
                                         last_row,
                                         d_code);
                            --                        AddLaborPart(getLaborText(current_row,false) || ' ' || temp_text, current_row, last_row,version_in,false,d_code);
                            d_code := 0;
                            --                        AddLaborPart(getLaborText(current_row,false) || ' ' || temp_text, current_row, last_row,version_in,false);
                            -- 10/11/2004 mm5095 => added support for hidden lines
                          ELSE
                            -- 10/11/2004 mm5095 => added support for hidden lines
                            addlaborpart(getlabortext(current_row, FALSE) ||
                                         ' to ' || temp_text,
                                         current_row,
                                         last_row,
                                         d_code);
                            --                        AddLaborPart(getLaborText(current_row,false) || ' to ' || temp_text, current_row, last_row,version_in,false,d_code);
                            d_code := 0;
                            --                        AddLaborPart(getLaborText(current_row,false) || ' to ' || temp_text, current_row, last_row,version_in,false);
                            -- 10/11/2004 mm5095 => added support for hidden lines
                          END IF;
                        ELSE
                          -- 10/11/2004 mm5095 => added support for hidden lines
                          addlaborpart(getlabortext(barcode_row, TRUE),
                                       barcode_row,
                                       last_row,
                                       d_code);
                          --                      AddLaborPart(getLaborText(barcode_row,true),barcode_row,last_row,version_in,false,d_code);
                          d_code := 0;
                          --                      AddLaborPart(getLaborText(barcode_row,true),barcode_row,last_row,version_in,false);
                          -- 10/11/2004 mm5095 => added support for hidden lines
                        END IF;
                      END IF;
                    ELSE
                      -- 10/11/2004 mm5095 => added support for hidden lines
                      addlaborpart(getlabortext(current_row, TRUE),
                                   current_row,
                                   last_row,
                                   d_code);
                      d_code := 0;
                      --                  AddLaborPart(getLaborText(current_row,true),current_row,last_row,version_in,false);
                      -- 10/11/2004 mm5095 => added support for hidden lines
                    END IF;
                  ELSE
                    -- 10/11/2004 mm5095 => added support for hidden lines
                    addlaborpart(getlabortext(current_row, TRUE),
                                 current_row,
                                 last_row,
                                 d_code);
                    d_code := 0;
                    --                AddLaborPart(getLaborText(current_row,true),current_row,last_row,version_in,false);
                    -- 10/11/2004 mm5095 => added support for hidden lines
                  END IF;

                  npart_detail := npart;
                  prefix_row   := NULL;
                  FOR n IN current_row .. last_row LOOP
                    IF NOT inlaborset(n, current_row) THEN
                      current_row := n - 1;
                      EXIT;
                    END IF;

                    IF nvl(service_table(n).barcode, ' ') != ' ' THEN
                      IF nvl(service_table(current_row).barcode, ' ') = ' ' AND
                         nvl(service_table(n).labor_verb_skey, 0) =
                         nvl(service_table(current_row).labor_verb_skey, 0) AND
                         nvl(service_table(n).component_skey, 0) =
                         nvl(service_table(current_row).component_skey, 0) THEN
                        addlabordetail(n,
                                       pkg_ultramate_common.sf_getqualifierstring(service_table(n).qgroup_skey,
                                                                                  '1',
                                                                                  FALSE));
                      ELSIF nvl(service_table(current_row).barcode, ' ') = ' ' AND
                            nvl(service_table(n).labor_verb_skey, 0) =
                            nvl(service_table(current_row).labor_verb_skey,
                                0) THEN
                        addlabordetail(n, getcomponentqualifier(n, FALSE));
                      ELSE
                        IF (blaborverbdetail AND bcomponentdetail) OR
                           prefix_row IS NULL OR
                           nvl(service_table(n).indent_level, ' ') =
                           nvl(service_table(prefix_row).indent_level, ' ') OR
                           (nvl(service_table(n).labor_verb_skey, 0) =
                           nvl(service_table(prefix_row).labor_verb_skey,
                                0)) OR
                           (prefix_row = current_row AND
                           nvl(service_table(current_row).barcode, ' ') = ' ') THEN
                          addlabordetail(n,
                                         getlabortext(n,
                                                      nvl(service_table(n).inline_note_skey,
                                                          0) !=
                                                      nvl(service_table(current_row).inline_note_skey,
                                                          0)));
                        ELSIF blaborverbdetail THEN
                          addlabordetail(n,
                                         getlabortext(n,
                                                      nvl(service_table(n).inline_note_skey,
                                                          0) !=
                                                      nvl(service_table(current_row).inline_note_skey,
                                                          0)));
                        ELSE
                          temp_text := getlabortext(n,
                                                    nvl(service_table(n).inline_note_skey,
                                                        0) !=
                                                    nvl(service_table(current_row).inline_note_skey,
                                                        0));
                          IF nvl(service_table(n).indent_level, ' ') >
                             nvl(service_table(prefix_row).indent_level,
                                 ' ') THEN
                            IF substr(temp_text, 1, 3) = 'To ' OR
                               substr(temp_text, 1, 4) = 'For ' OR
                               substr(temp_text, 1, 4) = 'Aim ' THEN
                              addlabordetail(n,
                                             getlabortext(prefix_row, FALSE) || ' ' ||
                                             temp_text);
                            ELSE
                              pre_text := getlabortext(prefix_row, FALSE);
                              IF length(pre_text || ' to ' || temp_text) > 61 THEN
                                addlabordetail(n, temp_text);
                              ELSE
                                addlabordetail(n,
                                               pre_text || ' to ' ||
                                               temp_text);
                              END IF;
                            END IF;
                          ELSE
                            addlabordetail(n, temp_text);
                          END IF;
                        END IF;
                      END IF;
                    ELSE
                      prefix_row := n;
                    END IF;

                    IF n = last_row THEN
                      current_row := last_row;
                      EXIT;
                    END IF;
                  END LOOP;
                END IF;
              END IF;
            ELSIF service_table(current_row).line_type = 'S' THEN
              glowerdate := nvl(service_table(current_row).lower_effectivity_date,
                                to_date('01/01/2099', 'MM/DD/YYYY'));
              gupperdate := nvl(service_table(current_row).upper_effectivity_date,
                                to_date('01/01/2099', 'MM/DD/YYYY'));

              IF current_row <
                 last_row AND service_table(current_row + 1).line_type = 'S' AND service_table(current_row).category_skey = service_table(current_row + 1).category_skey AND service_table(current_row).subcategory_skey = service_table(current_row + 1).subcategory_skey AND service_table(current_row).subcategory_qgroup_skey = 0 THEN
                -- skip placeholder category/subcategory/qgroup = 0 when followed by same category/subcategory/qgroup != 0
                NULL;
              ELSE
                addsection(current_row,
                           pkg_ultramate_common.sf_getsubcategorytext(service_table(current_row).subcategory_skey,
                                                                      service_table(current_row).subcategory_qgroup_skey),
                           TRUE);
                bdummysection := FALSE;
              END IF;
            END IF;
          EXCEPTION
            WHEN OTHERS THEN
              dbms_output.put_line('ERROR: ' || mfr_in || ' ' ||
                                   service_in || ' ' || version_in || ' ' || service_table(current_row).unique_row_id);
          END;

          IF service_table(current_row).line_type != 'N' THEN
            labor_verb_skey  := 0;
            component_skey   := 0;
            qgroup_skey      := 0;
            inline_note_skey := 0;
          END IF;

          IF service_table(current_row).line_type = 'I' THEN
            IF last_line_type = 'I' THEN
              bconsecutive_graphics := TRUE;
            ELSE
              bconsecutive_graphics := FALSE;
            END IF;
          END IF;

          last_line_type := service_table(current_row).line_type;

          IF current_row < last_row THEN
            current_row := current_row + 1;
          ELSE
            EXIT;
          END IF;
        END LOOP;

        -- add point and delete entries into last detail table
        -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
        IF bcheckheadersequence THEN
          header_sequence := pkg_ultramate_common.sf_get_max_header_sequence(vehicle_type_skey,
                                                                             header_offset);
        ELSE
          header_sequence := 0;
        END IF;
        -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
        FOR rec IN deleteandpoint_cur LOOP
          resequence := resequence + 1;
          addpointdelete(detail_fhandle,
                         substr(service_barcode, 3, 1) || '9' ||
                         rec.prtc_body,
                         -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
                         resequence,
                         rec.note_text,
                         pkg_ultramate_common.sf_getsmartprtcid('***' ||
                                                                rec.prtc_body ||
                                                                '***',
                                                                run_type),
                         header_sequence);
          --          resequence, rec.note_text, sf_getSmartPRTCId('***' || rec.prtc_body || '***'));
        -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
        END LOOP;

        -- close files, if open
/* -- File generation disabled: DA[barcode].txt close (FTP sunset)
        utl_file.fclose(header_fhandle);
-- end commented block */
/* -- File generation disabled: DB[barcode].txt close (FTP sunset)
        utl_file.fclose(section_fhandle);
-- end commented block */
/* -- File generation disabled: DC[barcode].txt close (FTP sunset)
        utl_file.fclose(part_fhandle);
-- end commented block */
/* -- File generation disabled: DD[barcode].txt close (FTP sunset)
        utl_file.fclose(detail_fhandle);
-- end commented block */

        -- 04/12/2006 mm5095 => add support for atg graphics UM 6.5
        --      if mfr_in != '006' then
/* -- File generation disabled: DK[barcode].txt close (FTP sunset)
        utl_file.fclose(graphic_fhandle);
-- end commented block */
/* -- File generation disabled: DE[barcode].txt close (FTP sunset)
        utl_file.fclose(hotspot_fhandle);
-- end commented block */

        -- 09/22/2009 mm5095: added to support color graphics
/* -- File generation disabled: DM[barcode].txt close (FTP sunset)
        utl_file.fclose(color_graphic_fhandle);
-- end commented block */
/* -- File generation disabled: DN[barcode].txt close (FTP sunset)
        utl_file.fclose(color_hotspot_fhandle);
-- end commented block */
        -- 09/22/2009 mm5095: added to support color graphics

        --      end if;
        -- 04/12/2006 mm5095 => add support for atg graphics UM 6.5

/* -- File generation disabled: DH[barcode].txt close (FTP sunset)
        utl_file.fclose(pnote_fhandle);
-- end commented block */
/* -- File generation disabled: DJ[barcode].txt close (FTP sunset)
        utl_file.fclose(dtnote_fhandle);
-- end commented block */

        -- 04/21/2011 mm5095 => add support for mtd/htd
        IF NOT (CLASS = 'HTD' OR CLASS = 'MTD') THEN
          -- 11/16/2004 mm5095 => added support for rr_vs_repair
/* -- File generation disabled: DR[barcode].txt fopen (FTP sunset)
          rr_fhandle := utl_file.fopen(path,
                                       'DR' || service_barcode || '.txt',
                                       'w');
-- end commented block */

          FOR rec IN rr_cur(mfr_in, service_in, version_in) LOOP
/* -- File generation disabled: DR[barcode].txt write (FTP sunset)
            utl_file.put_line(rr_fhandle,
                              rec.rr_barcode || '|' || rec.ri_barcode);
-- end commented block */
            -- 04/05/2018 pb0690 => added
            IF run_type = 'MINI' THEN
              IF rec.rr_barcode IS NOT NULL AND rec.ri_barcode IS NOT NULL THEN
                BEGIN
                  INSERT /*+ insert_um_data_dr */
                  INTO um_data_dr
                    (service, rr_barcode, ri_barcode)
                  VALUES
                    (service_barcode_in, rec.rr_barcode, rec.ri_barcode);
                EXCEPTION
                  WHEN OTHERS THEN
                    --null;  --NEED TO FIX!!!
                    dbms_output.put_line('pkg_ultramaste_build - Parse error inserting into um_data_dr' ||
                                         ' Error : ' || SQLCODE ||
                                         ': trying to insert ' ||
                                         service_barcode_in || ' ' ||
                                         rec.rr_barcode || ' ' ||
                                         rec.ri_barcode || ' ' ||
                                         substr(SQLERRM, 1, 120));
                    --RAISE;
                END;

              END IF;
            END IF;

          END LOOP;

/* -- File generation disabled: DR[barcode].txt close (FTP sunset)
          utl_file.fclose(rr_fhandle);
-- end commented block */
          -- 11/16/2004 mm5095 => added support for rr_vs_repair
        END IF;
        -- 04/21/2011 mm5095 => add support for mtd/htd

        -- update semaphore file
  /* -- File generation disabled: [barcode].txt semaphore append calls DA..DN (FTP sunset)
        pkg_ultramate_common.sp_output_barcode_semaphore(path,
                                                         service_barcode,
                                                         'DA' ||
                                                         service_barcode ||
                                                         '.txt',
                                                         'a');
        pkg_ultramate_common.sp_output_barcode_semaphore(path,
                                                         service_barcode,
                                                         'DB' ||
                                                         service_barcode ||
                                                         '.txt',
                                                         'a');
        pkg_ultramate_common.sp_output_barcode_semaphore(path,
                                                         service_barcode,
                                                         'DC' ||
                                                         service_barcode ||
                                                         '.txt',
                                                         'a');
        pkg_ultramate_common.sp_output_barcode_semaphore(path,
                                                         service_barcode,
                                                         'DD' ||
                                                         service_barcode ||
                                                         '.txt',
                                                         'a');
        pkg_ultramate_common.sp_output_barcode_semaphore(path,
                                                         service_barcode,
                                                         'DH' ||
                                                         service_barcode ||
                                                         '.txt',
                                                         'a');
        pkg_ultramate_common.sp_output_barcode_semaphore(path,
                                                         service_barcode,
                                                         'DJ' ||
                                                         service_barcode ||
                                                         '.txt',
                                                         'a');
        -- 04/21/2011 mm5095 => add support for mtd/htd
        IF NOT (CLASS = 'HTD' OR CLASS = 'MTD') THEN
          -- 11/16/2004 mm5095 => added support for rr_vs_repair
          pkg_ultramate_common.sp_output_barcode_semaphore(path,
                                                           service_barcode,
                                                           'DR' ||
                                                           service_barcode ||
                                                           '.txt',
                                                           'a');
          -- 11/16/2004 mm5095 => added support for rr_vs_repair
        END IF;
        -- 04/21/2011 mm5095 => add support for mtd/htd

        -- 04/12/2006 mm5095 => add support for atg graphics UM 6.5
        --      if mfr_in != '006' then  -- ignore ATG graphics
        pkg_ultramate_common.sp_output_barcode_semaphore(path,
                                                         service_barcode,
                                                         'DK' ||
                                                         service_barcode ||
                                                         '.txt',
                                                         'a');
        pkg_ultramate_common.sp_output_barcode_semaphore(path,
                                                         service_barcode,
                                                         'DE' ||
                                                         service_barcode ||
                                                         '.txt',
                                                         'a');
        --      end if;
        -- 04/12/2006 mm5095 => add support for atg graphics UM 6.5

        -- 09/22/2009 mm5095: added to support color graphics
        pkg_ultramate_common.sp_output_barcode_semaphore(path,
                                                         service_barcode,
                                                         'DM' ||
                                                         service_barcode ||
                                                         '.txt',
                                                         'a');
        pkg_ultramate_common.sp_output_barcode_semaphore(path,
                                                         service_barcode,
                                                         'DN' ||
                                                         service_barcode ||
                                                         '.txt',
                                                         'a');
        -- 09/22/2009 mm5095: added to support color graphics
  -- end commented block */ 

      ELSE
        dbms_output.put_line('ERROR - no data for: ' || mfr_in || ' ' ||
                             service_in || ' ' || version_in);
      END IF;
    END;

    -- 10/11/2004 mm5095 => added support for hidden lines
    -- 07/12/04 mm5095 => added support for hidden lines
    -- 2008/12/31 PAG - Older commented sections of code removed
    --                 to reduce package size and improve readability.
    --                 Check prior PVCS version, if you want to view this code.
    -- 2008/12/31 PAG - Older commented sections of code removed
    -- 07/12/04 mm5095 => added support for hidden lines
    -- 10/11/2004 mm5095 => added support for hidden lines

    -- MAIN ROUTINE
  BEGIN

    -- 10/02/02 mm5095 => added per request from Tim Mcfarland/Editorial
    -- Disable trigger on LAST_UPATE_USER and LAST_UPDATE_DATE.
    BEGIN
      auditlog.disable_udstamp; -- Execute stored procedure to disable trigger on LUU and LUD.
    EXCEPTION
      WHEN OTHERS THEN
        auditlog.enable_udstamp; -- Execute stored procedure to ensable trigger on LUU and LUD.
        dbms_output.put_line('Problem with DISABLING the UDStamp trigger');
        RETURN; -- Stop execution.
    END;

    vvc2_procedure_name := 'main loop';

    -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
    pkg_ultramate_common.sp_get_header_offset(header_offset, ceg_offset);
    -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5

    FOR s_rec IN service_cur LOOP

      -- 09/25/02 mm5095 => change to support unique_graphics
      DELETE /*+ tmp_um_graphic delete */
      FROM tmp_um_graphic;
      -- 09/25/02 mm5095 => change to support unique_graphics

      gcountryabbr := s_rec.country_abbr;

      -- 2008/12/31 PAG - Service concatenation.
      -- (Don't need to execute sf_getServiceBarcode. Picked up barcode during service_cur.)
      -- get service barcode
      -- service_barcode := sf_getServiceBarcode(s_rec.mfr_number, s_rec.service_number);
      service_barcode := s_rec.barcode;
      -- 2008/12/31 PAG - Service concatenation. Picked up barcode during service_cur.

      -- output semaphore
  /* -- File generation disabled: [barcode].txt semaphore initial write (FTP sunset)
      pkg_ultramate_common.sp_output_barcode_semaphore(path,
                                                       service_barcode,
                                                       NULL,
                                                       'w');
  -- end commented block */ 

      -- 04/21/2011 mm5095 => add support for mtd/htd
      vehicle_type := pkg_ultramate_common.sf_get_vehicle_type(s_rec.barcode,
                                                               s_rec.mfr_number);
      /*
      04/08/2014 mm5095 => rarely use alternate parts for MINI - commented out for performance
                  -- 11/19/2012 mm5095 => prevent RVs from getting alternate parts to save disk space
                  IF NOT (s_rec.mfr_number = '006' OR vehicle_type = 7 OR
                      vehicle_type = 9 OR s_rec.mfr_number > '099')
                  THEN
                      --    if not (s_rec.mfr_number = '006' or vehicle_type = 7 or vehicle_type = 9) then
                      -- 11/19/2012 mm5095 => prevent RVs from getting alternate parts to save disk space
                      --    if s_rec.mfr_number != '006' then
                      pkg_ultramate_common.create_altpart(service_barcode,
                                                          s_rec.mfr_number,
                                                          s_rec.service_number,
                                                          s_rec.version_type,
                                                          path,
                                                          run_type);
                  END IF;

      04/08/2014 mm5095 => rarely use alternate parts for MINI - commented out for performance
      */


      IF NOT (vehicle_type = 7 OR vehicle_type = 9) THEN
        -- 2008/12/31 PAG - Service concatenation.
        pkg_ultramate_common.create_overlap(service_barcode,
                                            s_rec.mfr_number,
                                            s_rec.service_number,
                                            s_rec.version_type,
                                            s_rec.mfr1,
                                            s_rec.service1,
                                            s_rec.mfr2,
                                            s_rec.service2,
                                            run_type,
                                            path);
        --    create_overlap(service_barcode, s_rec.mfr_number, s_rec.service_number, s_rec.version_type);
        -- 2008/12/31 PAG - Service concatenation.

        pkg_ultramate_common.create_matrix(service_barcode,
                                           s_rec.mfr_number,
                                           s_rec.service_number,
                                           s_rec.version_type,
                                           run_type,
                                           path);

        pkg_ultramate_common.create_options(service_barcode,
                                            s_rec.mfr_number,
                                            s_rec.service_number,
                                            s_rec.version_type,
                                            path,
                                            run_type);
      END IF;

      -- 04/21/2011 mm5095 => add support for mtd/htd

      pkg_ultramate_common.create_notes(service_barcode,
                                        s_rec.mfr_number,
                                        s_rec.service_number,
                                        s_rec.version_type,
                                        run_type,
                                        path,
                                        gparallelnumber);

      -- 07/12/04 mm5095 => added support for hidden lines
      -- retrieve product id
      OPEN product_cur(s_rec.mfr_number,
                       s_rec.service_number,
                       s_rec.version_type);
      FETCH product_cur
        INTO product_rec;
      CLOSE product_cur;

      -- 10/11/2004 mm5095 => added support for hidden lines
      /*
          suppression_flag := getSuppressionFlag(product_rec.product_code);
      -- 07/12/04 mm5095 => added support for hidden lines
      */
      -- 10/11/2004 mm5095 => added support for hidden lines

      create_main(service_barcode,
                  s_rec.mfr_number,
                  s_rec.service_number,
                  s_rec.version_type);

      -- retrieve version number and checkout date
      OPEN version_cur(s_rec.mfr_number,
                       s_rec.service_number,
                       s_rec.version_type);
      FETCH version_cur
        INTO version_rec;
      CLOSE version_cur;

      -- 07/12/04 mm5095 => added support for hidden lines
      -- retrieve product id
      --    open product_cur(s_rec.mfr_number, s_rec.service_number, s_rec.version_type);
      --    fetch product_cur into product_rec;
      --    close product_cur;
      -- 07/12/04 mm5095 => added support for hidden lines

      -- update product history
      INSERT /*+ product_history insert */
      INTO product_history
        (mfr_number,
         service_number,
         version_type,
         version_number,
         checkout_date,
         product_code,
         product_extract_date,
         last_update_user,
         last_update_date)
      VALUES
        (s_rec.mfr_number,
         s_rec.service_number,
         s_rec.version_type,
         version_rec.version_number,
         version_rec.checkout_date,
         product_rec.product_code,
         SYSDATE,
         USER,
         SYSDATE);

      -- if WP, clear post checkin process date in version
      IF s_rec.version_type = 'WP' THEN
        UPDATE /*+ version update */ version
           SET post_checkin_process_date = NULL
         WHERE mfr_number = s_rec.mfr_number
           AND service_number = s_rec.service_number
           AND version_type = s_rec.version_type;
      END IF;

  /* -- File generation disabled: zz[barcode].txt creation (FTP sunset)
      out_fhandle := utl_file.fopen(path,
                                    'zz' || service_barcode || '.txt',
                                    'w');
      utl_file.fclose(out_fhandle);
  -- end commented block */ 

      -- ftp to NT
  /* -- FTP send disabled: [barcode].txt sp_ftp_command (FTP sunset)
      pkg_ultramate_common.sp_ftp_command(service_barcode || '.txt',
                                          edsys_path,
                                          my_ftp_dest_path,
                                          my_ftp_machine_name,
                                          ftp_on_flag,
                                          ftp_ret_code);
  -- end commented block */ 
      --    FTP_COMMAND(service_barcode || '.txt', path, full_flag);

    END LOOP;

    -- 10/02/02 mm5095 => added per request from Tim Mcfarland/Editorial
    -- Enable trigger on LUU and LUD.
    BEGIN
      auditlog.enable_udstamp; -- Execute stored procedure to ensable trigger on LUU and LUD.
    EXCEPTION
      WHEN OTHERS THEN
        dbms_output.put_line('Problem with ENABLING the UDStamp trigger');
        RETURN; -- Stop execution.
    END;
    -- 10/02/02 mm5095 => added per request from Tim Mcfarland/Editorial

  EXCEPTION
    WHEN utl_file.invalid_path THEN
      utl_file.fclose_all;
      raise_application_error(-20100,
                              vvc2_procedure_name || ': INVALID PATH');
    WHEN utl_file.invalid_mode THEN
      utl_file.fclose_all;
      raise_application_error(-20101,
                              vvc2_procedure_name || ': INVALID MODE');
    WHEN utl_file.invalid_operation THEN
      utl_file.fclose_all;
      raise_application_error(-20102,
                              vvc2_procedure_name || ': INVALID OPERATION');
    WHEN utl_file.invalid_filehandle THEN
      utl_file.fclose_all;
      raise_application_error(-20103,
                              vvc2_procedure_name || ': INVALID FILEHANDLE');
    WHEN utl_file.write_error THEN
      utl_file.fclose_all;
      raise_application_error(-20104,
                              vvc2_procedure_name || ': WRITE ERROR');
    WHEN utl_file.read_error THEN
      utl_file.fclose_all;
      raise_application_error(-20105,
                              vvc2_procedure_name || ': READ ERROR');
    WHEN utl_file.internal_error THEN
      utl_file.fclose_all;
      raise_application_error(-20106,
                              vvc2_procedure_name || ': INTERNAL ERROR');
      --  WHEN OTHERS THEN
    --    UTL_FILE.FCLOSE_ALL;
    --    RAISE_APPLICATION_ERROR(-20107,vvc2_procedure_name || ': UNKNOWN ERROR');
  END;

  ---------------------------------------------------------------------------------------------------------------------
  ---------------------------------------------------------------------------------------------------------------------
  --                                          MAIN PROCESSING BLOCK FOR ULTRAMATE_BUILD                              --
  ---------------------------------------------------------------------------------------------------------------------
  ---------------------------------------------------------------------------------------------------------------------
  -- 01/25/2007 mm5095 => added Oracle directory support
  PROCEDURE ultramate_main(parm_path        VARCHAR2,
                           run_type         VARCHAR2,
                           parm_file        VARCHAR2,
                           unix_full_dir    VARCHAR2,
                           unix_mini_dir    VARCHAR2,
                           version          VARCHAR2,
                           restart_flag     CHAR,
                           ftp_machine_name VARCHAR2,
                           ftp_dest_path    VARCHAR2)
  --PROCEDURE ULTRAMATE_MAIN(parm_path varchar2, run_type varchar2, parm_file varchar2, unix_path varchar2, version varchar2, restart_flag char,
    --ftp_machine_name varchar2, ftp_dest_path varchar2)
   IS
    my_edsys_path VARCHAR2(100);
    edsys_path    VARCHAR2(100);
    full_flag     CHAR(1);
    n_services    INTEGER;
    out_fhandle   utl_file.file_type;

  BEGIN
    dbms_output.enable(1000000);
    dbms_output.put_line('---');

    my_ftp_machine_name := ftp_machine_name;
    my_ftp_dest_path    := ftp_dest_path;

    IF run_type = 'FULL' THEN
      full_flag := 'T';
      -- 10/20/08 mm5095 => bell and howell no longer supported
      --bell_howell_flag := true;
      -- 10/20/08 mm5095 => bell and howell no longer supported
      my_edsys_path := unix_full_dir; -- 01/25/2007 mm5095 => added Oracle directory support
    ELSE
      full_flag := 'F';
      -- 10/20/08 mm5095 => bell and howell no longer supported
      --bell_howell_flag := false;
      -- 10/20/08 mm5095 => bell and howell no longer supported
      my_edsys_path := unix_mini_dir; -- 01/25/2007 mm5095 => added Oracle directory support
    END IF;

    -- 2008/12/31 pg2697 => edsys_path is used to determine ftp_on_flag value (based on whether this is running in prod versus mdev).
    -- 01/25/2007 mm5095 => added Oracle directory support
    edsys_path := sf_getdirectorypath(my_edsys_path);
    IF edsys_path IS NULL THEN
      dbms_output.put_line('Invalid directory path. ftp_on_flag set to false.');
      ftp_on_flag := FALSE;
    ELSIF substr(edsys_path, 2, 4) = 'prod' THEN
      dbms_output.put_line('Running in prod environment. ftp_on_flag set to true.');
      ftp_on_flag := TRUE;
    ELSE
      dbms_output.put_line('Running in mdev environment. ftp_on_flag set to false.');
      ftp_on_flag := FALSE;
    END IF;
    -- 01/25/2007 mm5095 => added Oracle directory support
    -- 2008/12/31 pg2697 => edsys_path is used to determine ftp_on_flag value (based on whether this is running in prod versus mdev).

    -- 10/24/2006 mm5095 => added support for special material qualifiers
    sp_populatespecialmaterialtbl;
    -- 10/24/2006 mm5095 => added support for special material qualifiers

    -- 10/31/2012 mm5095 => added support for MAPP Supplier Xref
    pkg_ultramate_common.sp_update_mapp_supplier_xref(my_edsys_path);
    -- 10/31/2012 mm5095 => added support for MAPP Supplier Xref

    pkg_ultramate_common.extract_service_barcodes(parm_path,
                                                  parm_file,
                                                  version,
                                                  full_flag,
                                                  restart_flag);

    SELECT /*+ count tmp_um_extract */
     COUNT(*)
      INTO n_services
      FROM tmp_um_extract
     WHERE extract_date IS NULL;

    IF n_services > 0 THEN
      -- 08/09/02 mm5095 => rebuild index for performance
      IF (version = 'PR' AND
         race.pkg_race_ddl.sf_rbld_note_grp_xref_idxs != 0) OR
         (version = 'WP' AND
         race.pkg_race_ddl.sf_rbld_note_grp_xref_wip_idxs != 0) THEN
        dbms_output.put_line('NOTE_GROUP_XREF rebuild index failed');
      ELSE
        -- 08/09/02 mm5095 => rebuild index for performance

        pkg_ultramate_common.extract_service_group(my_edsys_path,
                                                   full_flag,
                                                   restart_flag,
                                                   run_type);

        pkg_ultramate_common.build_user_refinish_complete;
        --      BUILD_USER_REFINISH_COMPLETE(version);
        pkg_ultramate_common.extract_alternate_parts(my_edsys_path);
        pkg_ultramate_common.extract_disclaimer(my_edsys_path);
        pkg_ultramate_common.extract_disclosure(my_edsys_path);
        pkg_ultramate_common.extract_mmcatg(my_edsys_path);
        pkg_ultramate_common.extract_overlap(parm_path,
                                             my_edsys_path,
                                             full_flag,
                                             restart_flag,
                                             version);

        -- 05/02/05 mm5095 => added support for PDR
        pkg_ultramate_common.extract_pdr(my_edsys_path);
        -- 05/02/05 mm5095 => added support for PDR

        -- 04/18/2006 mm5095 => added support for RV_Matrices um6.5
        pkg_ultramate_common.extract_rv_matrices(my_edsys_path);
        -- 04/18/2006 mm5095 => added support for RV_Matrices um6.5

        -- 08/01/2007 jr6600 => added support for Marine_Matrices UM6.7
        pkg_ultramate_common.extract_marine_matrices(my_edsys_path);
        -- 08/01/2007 jr6600 => added support for Marine_Matrices UM6.7

        -- 08/03/2006 jr6600 => added support for qualification exclusion um6.0
        pkg_ultramate_common.extract_qualification_exclude(my_edsys_path);
        -- 08/03/2006 jr6600 => added support for qualification exclusion um6.0

        -- 04/03/14 mm5095 => added support for side body prtc extract
        pkg_ultramate_common.extract_side_body(my_edsys_path);
        -- 04/03/14 mm5095 => added support for side body prtc extract

        -- create permanent version in case we need to restart full build
        -- 11/08/11 mm5095 => for incremental, um_smartprtc values need to remain constant
        --      if full_flag = 'T' and restart_flag = 'F' then
        -- 11/08/11 mm5095 => for incremental, um_smartprtc values need to remain constant

        -- 04/05/2018 pb0690 => Replaced execute immediate truncates with use of procedure.
        sp_truncate_table('EXT',
                          'um_body, um_smartprtc, um_service_prtc',
                          FALSE);

        INSERT /*+ um_body_insert */
        INTO um_body
          SELECT * FROM tmp_um_body;

        INSERT /*+ um_service_prtc_insert */
        INTO um_service_prtc
          SELECT * FROM tmp_um_service_prtc;

        INSERT /*+ um_smartprtc_insert */
        INTO um_smartprtc
          SELECT * FROM tmp_um_smartprtc;
        -- 11/08/11 mm5095 => for incremental, um_smartprtc values need to remain constant
        --      end if;
        -- 11/08/11 mm5095 => for incremental, um_smartprtc values need to remain constant

        -- 04/05/2018 pb0690 => added for Nextgen/MCE mini
        IF run_type = 'MINI' THEN
          pkg_ultramate_common.truncate_um_extm_tables;
        end if;

        -- 07/02/04 tmc => All processing now uses PR only
        pkg_ultramate_common.extract_cegatgqrp(my_edsys_path, run_type);

        /***** -- 07/02/04 tmc => WIP tables removed - All processing now uses PR only
              if version = 'PR' then
                EXTRACT_CEGATGQRP(my_edsys_path);
              else
                EXTRACT_CEGATGQRP_WIP(my_edsys_path);
              end if;
        *****/

        pkg_ultramate_common.ext_refinish_complete(my_edsys_path);

        -- 10/24/2006 mm5095 => added support for extract_date
        extract_fhandle := utl_file.fopen(my_edsys_path,
                                          'extract_date.txt',
                                          'w');
        utl_file.put_line(extract_fhandle, to_char(SYSDATE, 'MM/DD/YYYY'));

        -- close files, if open
        IF utl_file.is_open(extract_fhandle) THEN
          utl_file.fclose(extract_fhandle);
        END IF;

  /* -- File generation disabled: global.txt semaphore for extract_date (FTP sunset)
        pkg_ultramate_common.sp_update_globaltxt_semaphore(my_edsys_path,
                                                           'global.txt',
                                                           'a',
                                                           'extract_date.txt');
  -- end commented block */ 
        -- 2016/06/21 mm5095 => moved dictionary extract to after service processing
        /*                -- 09/28/2105 mm5095
                        pkg_ultramate_common.dictionary_extract(my_edsys_path);

                        pkg_ultramate_common.sp_ftp_command('dictionary_eng.txt',
                                                            my_edsys_path,
                                                            my_ftp_dest_path,
                                                            my_ftp_machine_name,
                                                            ftp_on_flag,
                                                            ftp_ret_code);

                        pkg_ultramate_common.sp_ftp_command('dictionary_fre.txt',
                                                            my_edsys_path,
                                                            my_ftp_dest_path,
                                                            my_ftp_machine_name,
                                                            ftp_on_flag,
                                                            ftp_ret_code);
        */
        -- 2016/06/21 mm5095 => moved dictionary extract to after service processing

        -- 10/24/2006 mm5095 => added support for extract_date

        -- 2011/03/14 mm5095 => create color_services.txt
        pkg_ultramate_common.extract_color_services(my_edsys_path);
        -- 2011/03/14 mm5095 => create color_services.txt

        -- 2014/07/22 mm5095 => create cieca_code_xref.txt
        pkg_ultramate_common.cieca_code_extract(my_edsys_path);
        -- 2014/07/22 mm5095 => create cieca_code_xref.txt

        -- 2015/05/05 mm5095 => create dynamicprice file
        pkg_ultramate_common.dynamic_price_extract(my_edsys_path);
        -- 2015/05/05 mm5095 => create dynamicprice file

  /* -- File generation disabled: zzglobal.txt via sp_output_zzglobal_done_files (FTP sunset)
        pkg_ultramate_common.sp_output_zzglobal_done_files(my_edsys_path,
                                                           'global',
                                                           full_flag,
                                                           restart_flag);
  -- end commented block */ 
        -- 2014/04/08 mm5095 => added support for 7.1 incremental
        -- create price_us file
  /* -- File generation disabled: price_us.txt / price_ca.txt - feeds price.txt which is disabled (FTP sunset)
        ext_price(version, 'US', my_edsys_path);

        -- create pirce_ca file
        ext_price(version, 'CA', my_edsys_path);
  -- end commented block */

  /* -- File generation disabled: price.txt manifest file (FTP sunset)
        out_fhandle := utl_file.fopen(my_edsys_path, 'price.txt', 'w');

        utl_file.put_line(out_fhandle, 'price_us.txt');
        utl_file.put_line(out_fhandle, 'price_ca.txt');

        IF utl_file.is_open(out_fhandle) THEN
          utl_file.fclose(out_fhandle);
        END IF;
  -- end commented block */ 

  /* -- File generation disabled: zzprice.txt semaphore (FTP sunset)
        out_fhandle := utl_file.fopen(my_edsys_path, 'zzprice.txt', 'w');
        IF utl_file.is_open(out_fhandle) THEN
          utl_file.fclose(out_fhandle);
        END IF;
  -- end commented block */ 

  /* -- FTP send disabled: price.txt sp_ftp_command (FTP sunset)
        pkg_ultramate_common.sp_ftp_command('price.txt',
                                            edsys_path,
                                            my_ftp_dest_path,
                                            my_ftp_machine_name,
                                            ftp_on_flag,
                                            ftp_ret_code);
  -- end commented block */ 

  /* -- FTP send disabled: zzprice.txt sp_ftp_command (FTP sunset)
        pkg_ultramate_common.sp_ftp_command('zzprice.txt',
                                            edsys_path,
                                            my_ftp_dest_path,
                                            my_ftp_machine_name,
                                            ftp_on_flag,
                                            ftp_ret_code);
  -- end commented block */ 
        -- create single MAPP supplier file
  /* -- File generation disabled: ZA50.txt via ext_mapp - feeds mapp.txt which is disabled (FTP sunset)
        ext_mapp(my_edsys_path);
  -- end commented block */

  /* -- File generation disabled: mapp.txt manifest file (FTP sunset)
        out_fhandle := utl_file.fopen(my_edsys_path, 'mapp.txt', 'w');

        utl_file.put_line(out_fhandle, 'ZA50.txt');

        IF utl_file.is_open(out_fhandle) THEN
          utl_file.fclose(out_fhandle);
        END IF;
  -- end commented block */ 

  /* -- File generation disabled: zzmapp.txt semaphore (FTP sunset)
        out_fhandle := utl_file.fopen(my_edsys_path, 'zzmapp.txt', 'w');
        IF utl_file.is_open(out_fhandle) THEN
          utl_file.fclose(out_fhandle);
        END IF;
  -- end commented block */ 

  /* -- FTP send disabled: mapp.txt sp_ftp_command (FTP sunset)
        pkg_ultramate_common.sp_ftp_command('mapp.txt',
                                            edsys_path,
                                            my_ftp_dest_path,
                                            my_ftp_machine_name,
                                            ftp_on_flag,
                                            ftp_ret_code);
  -- end commented block */ 

  /* -- FTP send disabled: zzmapp.txt sp_ftp_command (FTP sunset)
        pkg_ultramate_common.sp_ftp_command('zzmapp.txt',
                                            edsys_path,
                                            my_ftp_dest_path,
                                            my_ftp_machine_name,
                                            ftp_on_flag,
                                            ftp_ret_code);
  -- end commented block */ 
        -- 2014/04/08 mm5095 => added support for 7.1 incremental

        -- 2016/06/22 mm5095 => moved ftp global.txt to after dictionary processing
        -- ftp global information to NT
        /*                pkg_ultramate_common.sp_ftp_command('global.txt',
                                                            edsys_path,
                                                            my_ftp_dest_path,
                                                            my_ftp_machine_name,
                                                            ftp_on_flag,
                                                            ftp_ret_code);
        */ -- 2016/06/22 mm5095 => moved ftp global.txt to after dictionary processing
        --      FTP_COMMAND('global.txt', my_edsys_path, full_flag);

        -- process list of services
        -- 10/20/08 mm5095 => bell and howell no longer supported
        -- if full build, open bell and howell UTL file
        --if bell_howell_flag then
        --  if restart_flag = 'T' then
        --    bell_howell_fhandle := UTL_FILE.FOPEN(my_edsys_path, 'ceg_belhow.ext','a');
        --  else
        --    bell_howell_fhandle := UTL_FILE.FOPEN(my_edsys_path, 'ceg_belhow.ext','w');
        --  end if;
        --end if;

        ext_service(my_edsys_path, edsys_path, run_type);
        --      EXT_SERVICE(my_edsys_path, full_flag, restart_flag);

        -- 10/20/08 mm5095 => bell and howell no longer supported
        --      if bell_howell_flag and UTL_FILE.IS_OPEN(bell_howell_fhandle) then
        --        UTL_FILE.FCLOSE(bell_howell_fhandle);
        --      end if;
        -- 10/20/08 mm5095 => bell and howell no longer supported

        -- 2008/12/31 pg2697 => added parms to support execute of sp_ftp_command and support of mixed case category descriptions
        pkg_ultramate_common.ext_refsheet(parm_path,
                                          my_edsys_path,
                                          edsys_path,
                                          my_ftp_dest_path,
                                          my_ftp_machine_name,
                                          ftp_on_flag,
                                          ftp_ret_code,
                                          run_type);
        --      EXT_REFSHEET(parm_path, my_edsys_path);
        -- 2008/12/31 pg2697 => added parms to support execute of sp_ftp_command and support of mixed case category descriptions

        -- 2016/06/21 mm5095 => moved dictionary extract to after service processing
  /* -- File generation disabled: dictionary_extract call (FTP sunset)
        pkg_ultramate_common.dictionary_extract(my_edsys_path);
  -- end commented block */ 

  /* -- FTP send disabled: dictionary_eng.txt sp_ftp_command (FTP sunset)
        pkg_ultramate_common.sp_ftp_command('dictionary_eng.txt',
                                            my_edsys_path,
                                            my_ftp_dest_path,
                                            my_ftp_machine_name,
                                            ftp_on_flag,
                                            ftp_ret_code);
  -- end commented block */ 

  /* -- FTP send disabled: dictionary_fre.txt sp_ftp_command (FTP sunset)
        pkg_ultramate_common.sp_ftp_command('dictionary_fre.txt',
                                            my_edsys_path,
                                            my_ftp_dest_path,
                                            my_ftp_machine_name,
                                            ftp_on_flag,
                                            ftp_ret_code);
  -- end commented block */ 
        -- 2016/06/21 mm5095 => moved dictionary extract to after service processing

        -- 2016/06/22 mm5095 => moved ftp global.txt to after dictionary processing
  /* -- FTP send disabled: global.txt sp_ftp_command (FTP sunset)
        pkg_ultramate_common.sp_ftp_command('global.txt',
                                            edsys_path,
                                            my_ftp_dest_path,
                                            my_ftp_machine_name,
                                            ftp_on_flag,
                                            ftp_ret_code);
  -- end commented block */ 
        -- 2016/06/22 mm5095 => moved ftp global.txt to after dictionary processing

  /* -- File generation disabled: zzdone.txt / done.txt via sp_output_zzglobal_done_files (FTP sunset)
        pkg_ultramate_common.sp_output_zzglobal_done_files(my_edsys_path,
                                                           'done',
                                                           full_flag,
                                                           restart_flag);
  -- end commented block */ 

        -- ftp done status to NT
  /* -- FTP send disabled: done.txt sp_ftp_command (FTP sunset)
        pkg_ultramate_common.sp_ftp_command('done.txt',
                                            edsys_path,
                                            my_ftp_dest_path,
                                            my_ftp_machine_name,
                                            ftp_on_flag,
                                            ftp_ret_code);
  -- end commented block */ 
        --      ftp_command('done.txt', my_edsys_path, full_flag);

-- 04/05/2018 pb0690 => Added check for RUN_TYPE.
        IF run_type = 'FULL' THEN
          -- 2015/10/23 mm5095 => update table used by svg graphics team
          pkg_next_gen_extract.update_svg_graphics;
        END IF;
        -- 2015/10/23 mm5095 => update table used by svg graphics team

      END IF;
    END IF;
-- 04/05/2018 pb0690 => Added commit.
    COMMIT;
  END;
END;
/
