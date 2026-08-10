CREATE OR REPLACE PACKAGE EXT."PKG_ULTRAMATE_PARSE" IS

PROCEDURE ULTRAMATE_PARSE(run_type varchar2, unix_full_dir varchar2, unix_mini_dir varchar2,
                          ftp_machine_name varchar2 DEFAULT NULL, ftp_dest_path varchar2 DEFAULT NULL, parallel_run char);

END;
/
CREATE OR REPLACE PACKAGE BODY EXT.pkg_ultramate_parse IS
    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
    *  $Workfile:$
    *    $Author:$
    *  $Revision:$
    *   $Modtime:$
    *
    *   PL/SQL name:     PKG_ULTRAMATE_PARSE                                          *
    *   Author:          mm5095                                                       *
    *   Description:
		*   2020/08  pb0690  Add PRTC For Specialty                                       *
    *   2020/08  pb0690  Add graphic_extension                                        *
    *   2021/03  pb0690  pg2697 Add to support Commercial truck
		*   2021/03  pb0690  rs7649 Added support aftermarket commercial trucks parts                                                        *
    * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

    -- ftp global variables
    ftp_on_flag BOOLEAN; -- controls whether data ftp'd to NT system. (see code after sf_getDirectoryPath for set of value)

    --test_flag boolean := false; -- 2008/12/31 pg2697 => moved to pkg_ultranate_common.extract_overlap

    ftp_ret_code        BINARY_INTEGER := 0;
    my_ftp_dest_path    VARCHAR2(80);
    my_ftp_machine_name VARCHAR2(10);

    bconsecutive_graphics BOOLEAN;

    -- 10/20/08 mm5095 => bell and howell no longer supported
    --  bell_howell_fhandle UTL_FILE.FILE_TYPE;
    --  bell_howell_flag boolean := false;
    -- 10/20/08 mm5095 => bell and howell no longer supported

    gcountryabbr    VARCHAR2(2);
    glowerdate      DATE;
    gupperdate      DATE;
    gparallelnumber CHAR(1);

    service_barcode_in NUMBER;

    -- 10/24/2006 mm5095 => added support for special material qualifiers
    CURSOR special_cur IS
        SELECT /*+ special_cur */
         c.qualifier_skey,
         c.qualifier_name
          FROM qualifier_type_xref a,
               qualifier_type      b,
               qualifier           c
         WHERE b.description = 'Special Material'
           AND b.qualifier_type_skey = a.qualifier_type_skey
           AND c.qualifier_skey = a.qualifier_skey;

    TYPE special_table_type IS TABLE OF special_cur%ROWTYPE INDEX BY BINARY_INTEGER;
    special_table special_table_type;

    last_special_row INTEGER;

    -- 10/24/2006 mm5095 => added support for special material qualifiers
    PROCEDURE sp_populatespecialmaterialtbl IS
    BEGIN
        last_special_row := 0;
        FOR rec IN special_cur
        LOOP
            last_special_row := last_special_row + 1;
            special_table(last_special_row).qualifier_skey := rec.qualifier_skey;

            IF (substr(rec.qualifier_name, 1, 1) != '(')
            THEN
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

        FOR rec IN qualifier_cur(skey_in)
        LOOP
            FOR n IN 1 .. last_special_row
            LOOP
                IF rec.qualifier_skey = special_table(n).qualifier_skey
                THEN
                    RETURN special_table(n).qualifier_name;
                END IF;
            END LOOP;
        END LOOP;

        RETURN vvc2_return;
    END;
    -- 10/24/2006 mm5095 => added support for special material qualifiers

    /************************************************************************/
    /* Program Name: ext_service.sql                                        */
    /* Author:       MM5095                                                 */
    /* Last Modified: 10/10/2001                                            */
    /* Description: Creates service flat files                              */
    /************************************************************************/
    -- 01/25/2007 mm5095 => added Oracle directory support
    -- 2007/02/09 mm5095 => removed not used arguments
    PROCEDURE ext_service
    (
        path     VARCHAR2,
        ftp_path VARCHAR2,
        run_type VARCHAR2
    )
    --PROCEDURE EXT_SERVICE(path varchar2, full_flag char, restart_flag char, ftp_path varchar2)
        -- 2007/02/09 mm5095 => removed not used arguments
        --PROCEDURE EXT_SERVICE(path varchar2, full_flag char, restart_flag char)
        -- 01/25/2007 mm5095 => added Oracle directory support
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
              FROM um_extract um
             WHERE um.extract_date IS NULL
                  -- 2013/02/25 mm5095 performance enhancement
               AND um.mfr_number <= '024';
        -- 2013/02/01 mm5095 performance enhancement
        --    and um.mfr_number <= '043';
        -- 2011/06/29 mm5095 => performance enhancement
        --    and um.mfr_number <= '031';
        -- 2012/03/05 mm5095 performance enhancement
        --    and um.mfr_number <= '006';
        -- 2011/06/29 mm5095 => performance enhancement

        CURSOR service_cur2 IS
            SELECT /*+ service_cur2 */
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
              FROM um_extract um
             WHERE um.extract_date IS NULL
                  -- 2013/02/25 mm5095 performance enhancement
               AND um.mfr_number > '024';
        -- 2013/02/01 mm5095 performance enhancement
        --    and um.mfr_number > '043';
        -- 2011/06/29 mm5095 => performance enhancement
        --    and um.mfr_number > '031';
        -- 2012/03/05 mm5095 performance enhancement
        --    and um.mfr_number > '006';
        -- 2011/06/29 mm5095 => performance enhancement
        /*
          cursor service_cur is
          select distinct mfr_number, service_number, version_type, country_abbr
          from um_extract
          where extract_date is null
          and mfr_number <= '006';

          cursor service_cur2 is
          select distinct mfr_number, service_number, version_type, country_abbr
          from um_extract
          where extract_date is null
          and mfr_number > '006';
        */
        --2008/12/31 PAG - Service Concatenation
        -- 2012/10/30 mm5095 => bug fix to prevent segment rollback time out
        TYPE service_rec_table_type IS TABLE OF service_cur%ROWTYPE INDEX BY BINARY_INTEGER;
        service_loop_table  service_rec_table_type;
        service_loop2_table service_rec_table_type;

        last_service_row  INTEGER;
        last_service2_row INTEGER;
        -- 2012/10/30 mm5095 => bug fix to prevent segment rollback time out

        CURSOR product_cur
        (
            mfr_in     VARCHAR2,
            service_in VARCHAR2,
            version_in VARCHAR2
        ) IS
            SELECT /*+ product_cur */
             product_code
              FROM um_extract
             WHERE mfr_number = mfr_in
               AND service_number = service_in
               AND version_type = version_in;
        product_rec product_cur%ROWTYPE;

        -- 07/08/02 mm5095 => note_group_xref fix
        CURSOR note_cur
        (
            row_id     IN NUMBER,
            version_in IN VARCHAR2
        ) IS
            SELECT /*+ note_cur */
            DISTINCT a.note_group_skey,
                     b.note_symbol
              FROM note_group_xref a,
                   note_sequence   b
             WHERE unique_row_id = row_id
               AND a.note_group_skey = b.note_group_skey
               AND b.version_type = version_in;
        note_rec note_cur%ROWTYPE;

        CURSOR note_cur_wip
        (
            row_id     IN NUMBER,
            version_in IN VARCHAR2
        ) IS
            SELECT /*+ note_cur_wip */
            DISTINCT a.note_group_skey,
                     b.note_symbol
              FROM note_group_xref_wip a,
                   note_sequence       b
             WHERE unique_row_id = row_id
               AND a.note_group_skey = b.note_group_skey
               AND b.version_type = version_in;
        -- 07/08/02 mm5095 => note_group_xref fix

        CURSOR version_cur
        (
            mfr_in     VARCHAR2,
            service_in VARCHAR2,
            version_in VARCHAR2
        ) IS
            SELECT /*+ version_cur */
             checkout_date,
             version_number
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

        CURSOR s_cur
        (
            mfr_in     VARCHAR2,
            service_in VARCHAR2,
            version_in VARCHAR2
        ) IS
        -- 04/19/05 mm5095 => added to prevent rv and motorcycle info from getting to bell and howell
            SELECT /*+ s_cur */
             mfr_number,
             version_type,
             -- 04/19/05 mm5095 => added to prevent rv and motorcycle info from getting to bell and howell
             --    select version_type,
             line_sequence_number * 1000 line_seq,
             category_skey,
             subcategory_skey,
             subcategory_qgroup_skey,
             lower_effectivity_date,
             upper_effectivity_date,
             unique_row_id,
             wip_tran_code,
             0 component_skey,
             substr(sf_getlinetype(subcategory_skey,
                                   subcategory_qgroup_skey),
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
                  -- 11/04/2011 mm5095 => added support for mtd/htd concatenation
               AND (mfr_number, service_number, category_skey) NOT IN
                   (SELECT mfr_number,
                           service_number,
                           category_skey
                      FROM service_category_substitution)
            -- 11/04/2011 mm5095 => added support for mtd/htd concatenation
            UNION ALL
            -- 04/19/05 mm5095 => added to prevent rv and motorcycle info from getting to bell and howell
            SELECT mfr_number,
                   version_type,
                   -- 04/19/05 mm5095 => added to prevent rv and motorcycle info from getting to bell and howell
                   --    select version_type,
                   sf_getlinesequencenumber(mfr_in,
                                            service_in,
                                            version_in,
                                            category_skey,
                                            subcategory_skey,
                                            subcategory_qgroup_skey,
                                            line_sequence_number) * 1000 line_sequence_number,
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
                   (SELECT mfr_number,
                           service_number,
                           category_skey
                      FROM service_category_substitution)
            -- 11/04/2011 mm5095 => added support for mtd/htd concatenation
            -- 11/04/2011 mm5095 => added support for mtd/htd concatenation
            UNION
            SELECT a.mfr_number,
                   b.version_type,
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
            SELECT a.mfr_number,
                   b.version_type,
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


        FUNCTION getqualifiernotestring
        (
            n           INTEGER,
            current_row INTEGER,
            indent_in   VARCHAR2,
            bpartflag   BOOLEAN
        ) RETURN VARCHAR2 IS
            vvc2_return VARCHAR2(160);
        BEGIN
            vvc2_return := pkg_ultramate_common.sf_getqualifierstring(service_table(n)
                                                                      .qgroup_skey,
                                                                      indent_in,
                                                                      bpartflag);

            IF nvl(service_table(n).inline_note_skey, 0) > 0
               AND nvl(service_table(current_row).inline_note_skey, 0) !=
               nvl(service_table(n).inline_note_skey, 0)
            THEN
                vvc2_return := rtrim(vvc2_return ||
                                     pkg_ultramate_common.sf_getnote_by_skey(service_table(n)
                                                                             .inline_note_skey));
            END IF;

            RETURN vvc2_return;
        END;

        FUNCTION inpartset
        (
            n           INTEGER,
            current_row INTEGER
        ) RETURN BOOLEAN IS
        BEGIN
            IF service_table(n)
             .line_type NOT IN ('A', 'G', 'F')
                OR nvl(service_table(n).category_skey, 0) !=
                nvl(service_table(current_row).category_skey, 0)
                OR nvl(service_table(n).subcategory_skey, 0) !=
                nvl(service_table(current_row).subcategory_skey, 0)
                OR
                nvl(service_table(n).subcategory_qgroup_skey, 0) !=
                nvl(service_table(current_row).subcategory_qgroup_skey, 0)
                OR (nvl(service_table(n).indent_level, ' ') = '0' AND
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
                    nvl(service_table(n).callout_number, ' ') != ' ')
                OR (n != current_row AND
                    nvl(service_table(n).indent_level, ' ') =
                    nvl(service_table(current_row).indent_level, ' ') AND
                    (nvl(service_table(current_row).inline_note_skey, 0) > 0 OR
                    nvl(service_table(n).inline_note_skey, 0) > 0))
            THEN
                RETURN FALSE;
            ELSE
                RETURN TRUE;
            END IF;
        END;

        FUNCTION inlaborset
        (
            n           INTEGER,
            current_row INTEGER
        ) RETURN BOOLEAN IS
        BEGIN
            IF service_table(n)
             .line_type NOT IN ('L', 'N')
                OR nvl(service_table(n).category_skey, 0) !=
                nvl(service_table(current_row).category_skey, 0)
                OR nvl(service_table(n).subcategory_skey, 0) !=
                nvl(service_table(current_row).subcategory_skey, 0)
                OR
                nvl(service_table(n).subcategory_qgroup_skey, 0) !=
                nvl(service_table(current_row).subcategory_qgroup_skey, 0)
                OR (nvl(service_table(n).indent_level, ' ') = '0' AND
                    (nvl(service_table(n).labor_verb_skey, 0) !=
                     nvl(service_table(current_row).labor_verb_skey, 0) OR
                     nvl(service_table(n).component_skey, 0) !=
                     nvl(service_table(current_row).component_skey, 0) OR
                     nvl(service_table(n).qgroup_skey, 0) !=
                     nvl(service_table(current_row).qgroup_skey, 0)))
            THEN
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
        --      vvc2_return := sf_getReverseString(PKG_ULTRAMATE_COMMON.sf_getComponentString(service_table(row_in).component_skey));
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

        FUNCTION getcomponentqualifier
        (
            row_in INTEGER,
            bflag  BOOLEAN
        ) RETURN VARCHAR2 IS
            vvc2_return VARCHAR2(200);
        BEGIN
            IF nvl(service_table(row_in).component_skey, 0) > 0
            THEN
                vvc2_return := pkg_ultramate_common.sf_getcomponentstring(service_table(row_in)
                                                                          .component_skey);
            END IF;

            IF nvl(service_table(row_in).qgroup_skey, 0) > 0
            THEN
                IF vvc2_return IS NOT NULL
                THEN
                    vvc2_return := rtrim(vvc2_return) || ' ' ||
                                   pkg_ultramate_common.sf_getqualifierstring(service_table(row_in)
                                                                              .qgroup_skey,
                                                                              '1',
                                                                              FALSE);
                ELSE
                    vvc2_return := pkg_ultramate_common.sf_getqualifierstring(service_table(row_in)
                                                                              .qgroup_skey,
                                                                              '1',
                                                                              FALSE);
                END IF;
            END IF;

            IF bflag
               AND nvl(service_table(row_in).inline_note_skey, 0) > 0
            THEN
                IF vvc2_return IS NOT NULL
                THEN
                    vvc2_return := rtrim(vvc2_return) ||
                                   pkg_ultramate_common.sf_getnote_by_skey(service_table(row_in)
                                                                           .inline_note_skey);
                ELSE
                    vvc2_return := pkg_ultramate_common.sf_getnote_by_skey(service_table(row_in)
                                                                           .inline_note_skey);
                END IF;
            END IF;

            RETURN rtrim(vvc2_return);
        END;

        FUNCTION getlaborverbcomponent
        (
            row_in INTEGER,
            bflag  BOOLEAN
        ) RETURN VARCHAR2 IS
            vvc2_return VARCHAR2(200);
        BEGIN

            IF nvl(service_table(row_in).labor_verb_skey, 0) > 0
            THEN
                vvc2_return := pkg_ultramate_common.sf_getlaborverbstring(service_table(row_in)
                                                                          .labor_verb_skey);
            END IF;

            IF nvl(service_table(row_in).component_skey, 0) > 0
            THEN
                IF vvc2_return IS NOT NULL
                THEN
                    vvc2_return := rtrim(vvc2_return) || ' ' ||
                                   pkg_ultramate_common.sf_getcomponentstring(service_table(row_in)
                                                                              .component_skey);
                ELSE
                    vvc2_return := pkg_ultramate_common.sf_getcomponentstring(service_table(row_in)
                                                                              .component_skey);
                END IF;
            END IF;

            IF bflag
               AND nvl(service_table(row_in).inline_note_skey, 0) > 0
            THEN
                IF vvc2_return IS NOT NULL
                THEN
                    vvc2_return := rtrim(vvc2_return) ||
                                   pkg_ultramate_common.sf_getnote_by_skey(service_table(row_in)
                                                                           .inline_note_skey);
                ELSE
                    vvc2_return := pkg_ultramate_common.sf_getnote_by_skey(service_table(row_in)
                                                                           .inline_note_skey);
                END IF;
            END IF;

            RETURN rtrim(vvc2_return);
        END;

        FUNCTION getparttext
        (
            row_in          INTEGER,
            indent_level_in VARCHAR2,
            bnoteflag       BOOLEAN,
            byear           BOOLEAN := FALSE
        ) RETURN VARCHAR2 IS
            vvc2_return VARCHAR2(200);
            vvc2_temp   VARCHAR2(200);
        BEGIN
            IF nvl(service_table(row_in).component_skey, 0) > 0
            THEN
                vvc2_return := pkg_ultramate_common.sf_getreversestring(pkg_ultramate_common.sf_getcomponentstring(service_table(row_in)
                                                                                                                   .component_skey));
            END IF;

            IF nvl(service_table(row_in).qgroup_skey, 0) > 0
            THEN
                vvc2_temp := pkg_ultramate_common.sf_getqualifierstring(service_table(row_in)
                                                                        .qgroup_skey,
                                                                        indent_level_in,
                                                                        byear);
                IF vvc2_return IS NOT NULL
                THEN
                    IF substr(vvc2_temp, 1, 1) = '('
                    THEN
                        vvc2_return := rtrim(vvc2_return) || vvc2_temp;
                    ELSE
                        vvc2_return := rtrim(vvc2_return) || ' ' ||
                                       vvc2_temp;
                    END IF;
                ELSE
                    vvc2_return := vvc2_temp;
                END IF;
            END IF;

            IF bnoteflag
               AND nvl(service_table(row_in).inline_note_skey, 0) > 0
            THEN
                IF vvc2_return IS NOT NULL
                THEN
                    vvc2_return := rtrim(vvc2_return) ||
                                   pkg_ultramate_common.sf_getnote_by_skey(service_table(row_in)
                                                                           .inline_note_skey);
                ELSE
                    vvc2_return := pkg_ultramate_common.sf_getnote_by_skey(service_table(row_in)
                                                                           .inline_note_skey);
                END IF;
            END IF;

            RETURN rtrim(vvc2_return);
        END;

        -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
        PROCEDURE addpointdelete
        (
            out_fhandle     IN OUT utl_file.file_type,
            barcode         IN VARCHAR2,
            resequence      IN NUMBER,
            note_text       IN VARCHAR2,
            smartprtc       IN NUMBER,
            header_sequence NUMBER
        ) AS
            --  PROCEDURE addPointDelete(out_fhandle in out utl_file.file_type, barcode in varchar2,
            --              resequence in number, note_text in varchar2, smartprtc in number) as
            -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
            -- 09/28/2015 mm5095
            line_text_skey NUMBER;
            -- 09/28/2015 mm5095

        BEGIN
            -- 09/28/2015 mm5095
            line_text_skey := sf_get_line_text_skey(upper(note_text),
                                                    note_text);
            -- 09/28/2015 mm5095

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
                              -- 08/17/2007 mm5095 => added support for special material qualifiers
                               || '|' || note_text
                              -- 08/17/2007 mm5095 => added support for special material qualifiers
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
                                                                 note_text)
                              -- 02/09/2017 mm5095
                              );
        END;

        -- 09/22/2009 mm5095: added to support color graphics
        PROCEDURE addgraphic
        (
            graphic_file_name_in VARCHAR2,
            callout_number_in    VARCHAR2,
            nimage_in            NUMBER
        ) IS
            CURSOR graphic_cur
            (
                graphic_in   VARCHAR2,
                extension_in VARCHAR2,
                callout_in   VARCHAR2
            ) IS
                SELECT /*+ graphic_cur */
                 *
                  FROM hotspot
                 WHERE graphic_file_name = graphic_in || extension_in
                   AND callout_number = callout_in;
            graphic_rec graphic_cur%ROWTYPE;

            CURSOR graphic_png_cur
            (
                graphic_in   VARCHAR2,
                extension_in VARCHAR2,
                callout_in   VARCHAR2
            ) IS
                SELECT /*+ graphic_cur */
                 a.*
                  FROM hotspot                  a,
                       special_material_graphic b
                 WHERE a.graphic_file_name = graphic_in || extension_in
                   AND callout_number = callout_in
                   AND b.graphic_file_name = a.graphic_file_name;

        BEGIN

            IF callout_number_in != callout_number_pre
            THEN
                OPEN graphic_cur(graphic_file_name_in,
                                 '.tif',
                                 callout_number_in);
                FETCH graphic_cur
                    INTO graphic_rec;
                IF graphic_cur%FOUND
                THEN
                    WHILE graphic_cur%FOUND
                    LOOP
                        utl_file.put_line(hotspot_fhandle,
                                          nheader || '|' || nsection || '|' ||
                                          npart || '|' || nimage_in || '|' ||
                                          callout_number_in || '|' ||
                                          graphic_rec.x_coordinate || '|' ||
                                          graphic_rec.y_coordinate || '|' ||
                                          graphic_rec.x_extent || '|' ||
                                          graphic_rec.y_extent);
                        -- 02/07/2008 mm5095 => to support Adesa, FocusWrite and Online data
                        -- 03/22/2008 mm5095 => added exception handling
                        BEGIN
                            INSERT /*+ um_data_de_insert */
                            INTO um_data_de
                                (service,
                                 category_skey,
                                 subcategory_skey,
                                 part_skey,
                                 image_skey,
                                 callout_number,
                                 x_coordinate,
                                 y_coordinate,
                                 x_extent,
                                 y_extent)
                            VALUES
                                (to_char(service_barcode_in),
                                 nheader,
                                 nsection,
                                 npart,
                                 nimage_in,
                                 callout_number_in,
                                 graphic_rec.x_coordinate,
                                 graphic_rec.y_coordinate,
                                 graphic_rec.x_extent,
                                 graphic_rec.y_extent);
                        EXCEPTION
                            WHEN OTHERS THEN
                                dbms_output.put_line('Parse error inserting into um_data_de');
                        END;
                        -- 03/22/2008 mm5095 => added exception handling

                        -- 02/07/2008 mm5095 => to support Adesa, FocusWrite and Online data
                        FETCH graphic_cur
                            INTO graphic_rec;
                    END LOOP;
                    CLOSE graphic_cur;
                ELSE
                    CLOSE graphic_cur;
                    IF bconsecutive_graphics
                    THEN
                        -- check if callout number found in previous graphic_file_name
                        OPEN graphic_cur(graphic_file_name_pre,
                                         '.tif',
                                         callout_number_in);
                        FETCH graphic_cur
                            INTO graphic_rec;
                        IF graphic_cur%FOUND
                        THEN
                            WHILE graphic_cur%FOUND
                            LOOP
                                utl_file.put_line(hotspot_fhandle,
                                                  nheader || '|' ||
                                                  nsection || '|' || npart || '|' ||
                                                  nimage_pre || '|' ||
                                                  callout_number_in || '|' ||
                                                  graphic_rec.x_coordinate || '|' ||
                                                  graphic_rec.y_coordinate || '|' ||
                                                  graphic_rec.x_extent || '|' ||
                                                  graphic_rec.y_extent);
                                -- 02/07/2008 mm5095 => to support Adesa, FocusWrite and Online data
                                -- 03/22/2008 mm5095 => added exception handling
                                BEGIN
                                    INSERT /*+ um_data_de_insert2 */
                                    INTO um_data_de
                                        (service,
                                         category_skey,
                                         subcategory_skey,
                                         part_skey,
                                         image_skey,
                                         callout_number,
                                         x_coordinate,
                                         y_coordinate,
                                         x_extent,
                                         y_extent)
                                    VALUES
                                        (to_char(service_barcode_in),
                                         nheader,
                                         nsection,
                                         npart,
                                         nimage_pre,
                                         callout_number_in,
                                         graphic_rec.x_coordinate,
                                         graphic_rec.y_coordinate,
                                         graphic_rec.x_extent,
                                         graphic_rec.y_extent);
                                EXCEPTION
                                    WHEN OTHERS THEN
                                        dbms_output.put_line('Parse error inserting into um_data_de');
                                END;
                                -- 03/22/2008 mm5095 => added exception handling
                                -- 02/07/2008 mm5095 => to support Adesa, FocusWrite and Online data
                                FETCH graphic_cur
                                    INTO graphic_rec;
                            END LOOP;
                        END IF;
                        CLOSE graphic_cur;
                    ELSE
                        -- create dummy hotspot
                        utl_file.put_line(hotspot_fhandle,
                                          nheader || '|' || nsection || '|' ||
                                          npart || '|' || nimage_in || '|' ||
                                          callout_number_in || '|' || -100 || '|' || -100 || '|' || 0 || '|' || 0);
                        -- 02/07/2008 mm5095 => to support Adesa, FocusWrite and Online data
                        -- 03/22/2008 mm5095 => added exception handling
                        BEGIN
                            INSERT /*+ um_data_de_insert3 */
                            INTO um_data_de
                                (service,
                                 category_skey,
                                 subcategory_skey,
                                 part_skey,
                                 image_skey,
                                 callout_number,
                                 x_coordinate,
                                 y_coordinate,
                                 x_extent,
                                 y_extent)
                            VALUES
                                (to_char(service_barcode_in),
                                 nheader,
                                 nsection,
                                 npart,
                                 nimage_in,
                                 callout_number_in,
                                 -100,
                                 -100,
                                 0,
                                 0);
                        EXCEPTION
                            WHEN OTHERS THEN
                                dbms_output.put_line('Parse error inserting into um_data_de');
                        END;
                        -- 03/22/2008 mm5095 => added exception handling
                        -- 02/07/2008 mm5095 => to support Adesa, FocusWrite and Online data

                    END IF;
                END IF;
            END IF;

            IF callout_number_in != callout_number_pre
            THEN
                OPEN graphic_png_cur(graphic_file_name_in,
                                     '.png',
                                     callout_number_in);
                FETCH graphic_png_cur
                    INTO graphic_rec;
                IF graphic_png_cur%FOUND
                THEN
                    WHILE graphic_png_cur%FOUND
                    LOOP
                        utl_file.put_line(color_hotspot_fhandle,
                                          nheader || '|' || nsection || '|' ||
                                          npart || '|' || nimage_in || '|' ||
                                          callout_number_in || '|' ||
                                          graphic_rec.x_coordinate || '|' ||
                                          graphic_rec.y_coordinate || '|' ||
                                          graphic_rec.x_extent || '|' ||
                                          graphic_rec.y_extent);
                        FETCH graphic_png_cur
                            INTO graphic_rec;
                    END LOOP;
                    CLOSE graphic_png_cur;
                ELSE
                    CLOSE graphic_png_cur;
                    IF bconsecutive_graphics
                    THEN
                        -- check if callout number found in previous graphic_file_name
                        OPEN graphic_png_cur(graphic_file_name_pre,
                                             '.png',
                                             callout_number_in);
                        FETCH graphic_png_cur
                            INTO graphic_rec;
                        IF graphic_png_cur%FOUND
                        THEN
                            WHILE graphic_png_cur%FOUND
                            LOOP
                                utl_file.put_line(color_hotspot_fhandle,
                                                  nheader || '|' ||
                                                  nsection || '|' || npart || '|' ||
                                                  nimage_pre || '|' ||
                                                  callout_number_in || '|' ||
                                                  graphic_rec.x_coordinate || '|' ||
                                                  graphic_rec.y_coordinate || '|' ||
                                                  graphic_rec.x_extent || '|' ||
                                                  graphic_rec.y_extent);
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
                        IF graphic_cur%FOUND
                        THEN
                            WHILE graphic_cur%FOUND
                            LOOP
                                utl_file.put_line(color_hotspot_fhandle,
                                                  nheader || '|' ||
                                                  nsection || '|' || npart || '|' ||
                                                  nimage_in || '|' ||
                                                  callout_number_in || '|' ||
                                                  graphic_rec.x_coordinate || '|' ||
                                                  graphic_rec.y_coordinate || '|' ||
                                                  graphic_rec.x_extent || '|' ||
                                                  graphic_rec.y_extent);
                                FETCH graphic_cur
                                    INTO graphic_rec;
                            END LOOP;
                            CLOSE graphic_cur;
                        ELSE
                            CLOSE graphic_cur;
                            IF bconsecutive_graphics
                            THEN
                                -- check if callout number found in previous graphic_file_name
                                OPEN graphic_cur(graphic_file_name_pre,
                                                 '.tif',
                                                 callout_number_in);
                                FETCH graphic_cur
                                    INTO graphic_rec;
                                IF graphic_cur%FOUND
                                THEN
                                    WHILE graphic_cur%FOUND
                                    LOOP
                                        utl_file.put_line(color_hotspot_fhandle,
                                                          nheader || '|' ||
                                                          nsection || '|' ||
                                                          npart || '|' ||
                                                          nimage_pre || '|' ||
                                                          callout_number_in || '|' ||
                                                          graphic_rec.x_coordinate || '|' ||
                                                          graphic_rec.y_coordinate || '|' ||
                                                          graphic_rec.x_extent || '|' ||
                                                          graphic_rec.y_extent);
                                        FETCH graphic_cur
                                            INTO graphic_rec;
                                    END LOOP;
                                END IF;
                                CLOSE graphic_cur;
                            ELSE
                                -- create dummy hotspot
                                utl_file.put_line(color_hotspot_fhandle,
                                                  nheader || '|' ||
                                                  nsection || '|' || npart || '|' ||
                                                  nimage_in || '|' ||
                                                  callout_number_in || '|' || -100 || '|' || -100 || '|' || 0 || '|' || 0);
                            END IF;
                        END IF;
                    END IF;
                END IF;
            END IF;

        EXCEPTION
            WHEN OTHERS THEN
                dbms_output.put_line('Error code ' || SQLCODE || ': ' ||
                                     substr(SQLERRM, 1, 64));
                callout_number_pre := callout_number_in;
        END;

        /*
          PROCEDURE AddGraphic(graphic_file_name_in varchar2, callout_number_in varchar2, nimage_in number)
          IS
            cursor graphic_cur (graphic_in varchar2, callout_in varchar2) is
            select /*+ graphic_cur *
            from hotspot
            where graphic_file_name =graphic_in
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
        -- 02/07/2008 mm5095 => to support Adesa, FocusWrite and Online data
        -- 03/22/2008 mm5095 => added exception handling
                  BEGIN
                    insert /*+ um_data_de_insert  into um_data_de
                    (service, category_skey, subcategory_skey, part_skey, image_skey, callout_number,
                     x_coordinate, y_coordinate, x_extent, y_extent)
                     values(to_char(service_barcode_in), nheader, nsection, npart, nimage_in, callout_number_in, graphic_rec.x_coordinate,
                     graphic_rec.y_coordinate, graphic_rec.x_extent, graphic_rec.y_extent);
                  EXCEPTION WHEN OTHERS THEN
                    dbms_output.put_line('Parse error inserting into um_data_de');
                  END;
        -- 03/22/2008 mm5095 => added exception handling

        -- 02/07/2008 mm5095 => to support Adesa, FocusWrite and Online data
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
        -- 02/07/2008 mm5095 => to support Adesa, FocusWrite and Online data
        -- 03/22/2008 mm5095 => added exception handling
                      BEGIN
                        insert /*+ um_data_de_insert2 into um_data_de
                        (service, category_skey, subcategory_skey, part_skey, image_skey, callout_number,
                           x_coordinate, y_coordinate, x_extent, y_extent)
                         values(to_char(service_barcode_in), nheader, nsection, npart, nimage_in, callout_number_in, graphic_rec.x_coordinate,
                           graphic_rec.y_coordinate, graphic_rec.x_extent, graphic_rec.y_extent);
                      EXCEPTION WHEN OTHERS THEN
                        dbms_output.put_line('Parse error inserting into um_data_de');
                      END;
        -- 03/22/2008 mm5095 => added exception handling
        -- 02/07/2008 mm5095 => to support Adesa, FocusWrite and Online data
                      fetch graphic_cur into graphic_rec;
                    END LOOP;
                  end if;
                  close graphic_cur;
                else
                  -- create dummy hotspot
                  utl_file.put_line(hotspot_fhandle, nheader || '|' || nsection || '|' || npart || '|'
                    || nimage_in || '|' || callout_number_in || '|'
                    || -100 || '|' || -100 || '|' || 0 || '|' || 0);
        -- 02/07/2008 mm5095 => to support Adesa, FocusWrite and Online data
        -- 03/22/2008 mm5095 => added exception handling
                  BEGIN
                    insert /*+ um_data_de_insert3  into um_data_de
                    (service, category_skey, subcategory_skey, part_skey, image_skey, callout_number,
                       x_coordinate, y_coordinate, x_extent, y_extent)
                     values(to_char(service_barcode_in), nheader, nsection, npart, nimage_in, callout_number_in,
                       -100, -100, 0, 0);
                  EXCEPTION WHEN OTHERS THEN
                    dbms_output.put_line('Parse error inserting into um_data_de');
                  END;
        -- 03/22/2008 mm5095 => added exception handling
        -- 02/07/2008 mm5095 => to support Adesa, FocusWrite and Online data

                end if;
              end if;
            end if;
            callout_number_pre := callout_number_in;
          END;
        */
        -- 09/22/2009 mm5095: added to support color graphics

        PROCEDURE addsection
        (
            row_in      NUMBER,
            subcat_text VARCHAR2,
            bdateflag   BOOLEAN := FALSE
        ) IS
            my_start_date_ret VARCHAR2(8) := -1;
            my_end_date_ret   VARCHAR2(8) := -1;

            -- 03/01/2017 mm5095 -=> date bug fix
            local_start_date DATE;
            local_end_date   DATE;
            -- 03/01/2017 mm5095 -=> date bug fix

            -- 05/09/2008 mm5095 => added support for mixed case Category description
            mc_subcategory subcat_description.mixed_case_subcat_name%TYPE;
            -- 05/09/2008 mm5095 => added support for mixed case Category description

            -- 09/28/2015 mm5095
            line_text_skey NUMBER;
            -- 09/28/2015 mm5095

        BEGIN
            nsection           := nsection + 1;
            rightoverhaultime  := 0;
            leftoverhaultime   := 0;
            callout_number_pre := ' ';

            -- 05/09/2008 mm5095 => added support for mixed case Category description
            mc_subcategory := pkg_ultramate_common.sf_getmixedcasesubcategory(rtrim(subcat_text));
            -- 05/09/2008 mm5095 => added support for mixed case Category description

            -- 09/28/2015 mm5095
            line_text_skey := sf_get_line_text_skey(subcat_text,
                                                    mc_subcategory);
            -- 09/28/2015 mm5095

            IF bdateflag
            THEN
                -- 2007/02/09 mm5095 => removed arguments not used
                pkg_ultramate_common.getstartenddate(service_table    (row_in)
                                                     .lower_effectivity_date,
                                                     service_table    (row_in)
                                                     .upper_effectivity_date,
                                                     my_start_date_ret,
                                                     my_end_date_ret);

                -- 03/01/2017 mm5095 -=> date bug fix
                local_start_date := service_table(row_in)
                                    .lower_effectivity_date;
                local_end_date   := service_table(row_in)
                                    .upper_effectivity_date;
                -- 03/01/2017 mm5095 -=> date bug fix

                --      getStartEndDate(service_table(row_in).lower_effectivity_date, service_table(row_in).upper_effectivity_date, start_date_ret, end_date_ret, false);
                -- 2007/02/09 mm5095 => removed arguments not used
            END IF;

            utl_file.put_line(section_fhandle,
                              nheader || '|' || nsection || '|' ||
                               my_start_date_ret || '|' || my_end_date_ret || '|' ||
                               rtrim(subcat_text)
                              -- 10/11/2004 mm5095 => added support for hidden lines
                               || '|' || service_table(row_in)
                              .suppression_reason_code
                              -- 10/11/2004 mm5095 => added support for hidden lines
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

            -- 07/25/2007 mm5095 => insert into table to support part list initiative
            -- 03/22/2008 mm5095 => added exception handling
            BEGIN
                INSERT /*+ um_data_db_insert */
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
                     -- 03/01/2017 mm5095 -=> date bug fix
                     local_start_date, --service_table(row_in).lower_effectivity_date,
                     local_end_date, --service_table(row_in).upper_effectivity_date,
                     -- 03/01/2017 mm5095 -=> date bug fix
                     rtrim(subcat_text),
                     service_table(row_in).suppression_reason_code,
                     USER,
                     SYSDATE);
            EXCEPTION
                WHEN OTHERS THEN
                    dbms_output.put_line('Parse error inserting into um_data_db');
            END;
            -- 03/22/2008 mm5095 => added exception handling
            -- 07/25/2007 mm5095 => insert into table to support part list initiative

        END;

        PROCEDURE addpart
        (
            callout_number_in       VARCHAR2,
            text_in                 VARCHAR2,
            row_in                  INTEGER,
            suppression_reason_code INTEGER
        ) IS
            my_text VARCHAR2(200);
            -- 09/28/2105
            line_text_skey NUMBER;
            -- 09/28/2105
        BEGIN
            my_text := rtrim(ltrim(text_in));

            -- 09/28/2105
            line_text_skey := sf_get_line_text_skey(my_text, my_text);
            -- 09/28/2105

            IF nsection = 0
            THEN
                -- add dummy section
                bdummysection := TRUE;
                addsection(row_in,
                           pkg_ultramate_common.sf_getcategorystring(service_table(row_in)
                                                                     .category_skey));
            END IF;

            npart := npart + 1;

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

            -- 07/25/2007 mm5095 => insert into table to support part list initiative
            -- 03/22/2008 mm5095 => added exception handling
            BEGIN
                INSERT /*+ um_data_dc_insert */
                INTO um_data_dc
                    (service,
                     category_skey,
                     subcategory_skey,
                     part_skey,
                     part,
                     suppression_code,
                     last_update_user,
                     last_update_date,
                     --2012/08/02 mm5095 => next gen requirement
                     part_or_labor)
                --2012/08/02 mm5095 => next gen requirement
                VALUES
                    (to_char(service_barcode_in),
                     nheader,
                     nsection,
                     npart,
                     my_text,
                     suppression_reason_code,
                     USER,
                     SYSDATE,
                     --2012/08/02 mm5095 => next gen requirement
                     'P');
                --2012/08/02 mm5095 => next gen requirement
            EXCEPTION
                WHEN OTHERS THEN
                    dbms_output.put_line('Parse error inserting into um_data_dc');
            END;
            -- 03/22/2008 mm5095 => added exception handling
            -- 07/25/2007 mm5095 => insert into table to support part list initiative

            IF nvl(callout_number_in, ' ') != ' '
            THEN
                addgraphic(graphic_file_name, callout_number_in, nimage);
            END IF;

            savedetailnote := nvl(service_table(row_in).note_symbol, ' ');
            -- 07/08/02 mm5095 => note_group_xref fix
            IF service_table(row_in).version_type = 'PR'
            THEN
                OPEN note_cur(service_table(row_in).unique_row_id,
                              service_table(row_in).version_type);
                FETCH note_cur
                    INTO note_rec;
                WHILE note_cur%FOUND
                LOOP
                    IF note_rec.note_symbol != '#'
                    THEN
                        pkg_ultramate_common.getnoteid_by_skey(note_rec.note_group_skey,
                                                               note_type,
                                                               note_id,
                                                               run_type,
                                                               gparallelnumber);
                        -- 03/27/2017 mm5095 => skip dups
                        --                        utl_file.put_line(pnote_fhandle,
                        --                                          nheader || '|' || nsection || '|' ||
                        --                                          npart || '|' || note_type || '|' ||
                        --                                          note_id);
                        -- 03/27/2017 mm5095 => skip dups
                        -- 02/07/08 mm5095 =>
                        -- 03/22/2008 mm5095 => added exception handling
                        BEGIN
                            INSERT /*+ um_data_dh_insert */
                            INTO um_data_dh
                                (service,
                                 category_skey,
                                 subcategory_skey,
                                 part_skey,
                                 note_type,
                                 note_id)
                            VALUES
                                (service_barcode_in,
                                 nheader,
                                 nsection,
                                 npart,
                                 note_type,
                                 note_id);
                            -- 03/27/2017 mm5095 => skip dups
                            utl_file.put_line(pnote_fhandle,
                                              nheader || '|' || nsection || '|' ||
                                              npart || '|' || note_type || '|' ||
                                              note_id);
                            -- 03/27/2017 mm5095 => skip dups
                        EXCEPTION
                            -- 03/27/2017 mm5095 => skip dups
                            WHEN dup_val_on_index THEN
                                NULL; -- skip duplicate
                            -- 03/27/2017 mm5095 => skip dups
                            WHEN OTHERS THEN
                                dbms_output.put_line('Parse error inserting into um_data_dh');
                        END;
                        -- 03/22/2008 mm5095 => added exception handling
                        -- 02/07/08 mm5095 =>
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
                WHILE note_cur_wip%FOUND
                LOOP
                    IF note_rec.note_symbol != '#'
                    THEN
                        pkg_ultramate_common.getnoteid_by_skey(note_rec.note_group_skey,
                                                               note_type,
                                                               note_id,
                                                               run_type,
                                                               gparallelnumber);

                        -- 03//27/2017 mm5095 => skip dups
                        --                        utl_file.put_line(pnote_fhandle,
                        --                                          nheader || '|' || nsection || '|' ||
                        --                                          npart || '|' || note_type || '|' ||
                        --                                          note_id);
                        -- 03//27/2017 mm5095 => skip dups
                        -- 02/07/08 mm5095 =>
                        -- 03/22/2008 mm5095 => added exception handling
                        BEGIN
                            INSERT /*+ um_data_dh_insert2 */
                            INTO um_data_dh
                                (service,
                                 category_skey,
                                 subcategory_skey,
                                 part_skey,
                                 note_type,
                                 note_id)
                            VALUES
                                (service_barcode_in,
                                 nheader,
                                 nsection,
                                 npart,
                                 note_type,
                                 note_id);

                            -- 03//27/2017 mm5095 => skip dups
                            utl_file.put_line(pnote_fhandle,
                                              nheader || '|' || nsection || '|' ||
                                              npart || '|' || note_type || '|' ||
                                              note_id);
                            -- 03//27/2017 mm5095 => skip dups
                        EXCEPTION
                            -- 03//27/2017 mm5095 => skip dups
                            WHEN dup_val_on_index THEN
                                NULL; -- skip duplicate
                            -- 03//27/2017 mm5095 => skip dups
                            WHEN OTHERS THEN
                                dbms_output.put_line('Parse error inserting into um_data_dh');
                        END;
                        -- 03/22/2008 mm5095 => added exception handling
                        -- 02/07/08 mm5095 =>
                    END IF;
                    FETCH note_cur_wip
                        INTO note_rec;
                END LOOP;
                CLOSE note_cur_wip;
            END IF;
            -- 07/08/02 mm5095 => note_group_xref fix
        END;

        PROCEDURE addpartdetail
        (
            row_in       INTEGER,
            text_in      VARCHAR2,
            baddpartnote BOOLEAN
        ) IS
            CURSOR labor_cur(prtc_in VARCHAR2) IS
                SELECT labor_rate_code
                  FROM prtc_body
                 WHERE prtc_body = prtc_in;

            ceg_labor_time NUMBER;
            ioh_flag       CHAR(1);
            labor_type     CHAR(1);
            -- 2007/02/09 mm5095 => not used
            --    labor_operation char(1);
            -- 2007/02/09 mm5095 => not used
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
            -- 2007/02/09 mm5095 => not used
            --    npos number;
            -- 2007/02/09 mm5095 => not used
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
            line_text_skey          NUMBER;
            expanded_prtc_text_skey NUMBER;
            -- 09/28/2015 mm5095

        BEGIN
            IF substr(service_table(row_in).prtc, 4, 4) = 'TEXT'
            THEN
                RETURN;
            END IF;

            my_right_left_code := 0;

            -- 02/05/2008 jr6600 => added support for special material flag
            special_material_flag := '0';
            -- 02/05/2008 jr6600 => added support for special material flag

            my_text := rtrim(ltrim(text_in));
            pkg_ultramate_common.sp_striptext(my_text, my_right_left_code);

            IF service_table(row_in).right_left_code = 'R'
            THEN
                my_right_left_code := 1;
            ELSIF service_table(row_in).right_left_code = 'L'
            THEN
                my_right_left_code := 2;
            END IF;

            resequence := resequence + 1;

            pkg_ultramate_common.sp_getlaborinfo(service_table(row_in)
                                                 .labor_operation_skey,
                                                 ceg_labor_time,
                                                 ioh_flag,
                                                 labor_type);

            IF gcountryabbr NOT IN ('CA', 'US')
            THEN
                pkg_ultramate_common.sp_getpartinfo(service_table    (row_in)
                                                    .unique_row_id,
                                                    service_table    (row_in)
                                                    .version_type,
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
                pkg_ultramate_common.sp_getpartinfo(service_table    (row_in)
                                                    .unique_row_id,
                                                    service_table    (row_in)
                                                    .version_type,
                                                    'CA',
                                                    can_part_number,
                                                    can_effdt1,
                                                    can_price1,
                                                    can_effdt2,
                                                    can_price2,
                                                    discontinued_flag,
                                                    new_flag,
                                                    special_flag);

                pkg_ultramate_common.sp_getpartinfo(service_table    (row_in)
                                                    .unique_row_id,
                                                    service_table    (row_in)
                                                    .version_type,
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

            -- 04/19/05 mm5095 => added to prevent rv and motorcycle info from getting to bell and howell
            IF service_table(row_in)
             .mfr_number < '100'
                AND substr(service_table(row_in).prtc, 10, 1) = 'A'
            THEN
                --    if substr(service_table(row_in).prtc,10,1) = 'A' then
                -- 04/19/05 mm5095 => added to prevent rv and motorcycle info from getting to bell and howell
                --10/11/04 mm5095 => added support for hidden lines
                -- 10/20/08 mm5095 => bell and howell no longer supported
                --      if bell_howell_flag and bitAnd(service_table(row_in).suppression_reason_code,1) = 1 then
                --      if bell_howell_flag then
                --10/11/04 mm5095 => added support for hidden lines
                --        utl_file.put_line(bell_howell_fhandle, '"' || service_barcode_in || '","'
                --          || service_table(row_in).barcode || '","' || us_part_number || '"');
                --      end if;
                -- 10/20/08 mm5095 => bell and howell no longer supported
                can_part_number := 'ORDER FROM DEALER';
                us_part_number  := 'ORDER FROM DEALER';
            END IF;

            my_labor_type := 0;

            OPEN labor_cur(substr(service_table(row_in).prtc, 4, 4));
            FETCH labor_cur
                INTO my_labor_rate;
            CLOSE labor_cur;

            my_labor_type := to_number(my_labor_rate);

            IF labor_type = 'M'
            THEN
                my_labor_type := 4;
            ELSIF labor_type = 'F'
            THEN
                my_labor_type := 3;
            END IF;

            labor_op := 1;
            -- 10/24/2006 mm5095 => added support for 'NA' refinish PRTC
            -- 08/13/2020 - pb0690 - added FC and FD
            IF substr(service_table(row_in).prtc, 4, 2) IN
               ('FA', 'FC', 'FD')
               OR substr(service_table(row_in).prtc, 4, 2) = 'NA'
            THEN
                --    if substr(service_table(row_in).prtc,4,2) = 'FA' then
                -- 10/24/2006 mm5095 => added support for 'NA' refinish PRTC
                labor_op := 6;
                -- 08/13/2020 - pb0690 - added IB and IC
            ELSIF substr(service_table(row_in).prtc, 4, 2) IN
                  ('IA', 'IB', 'IC')
            THEN
                labor_op := 2;
            ELSIF substr(service_table(row_in).prtc, 4, 2) = 'OA'
            THEN
                labor_op := 5;
            ELSIF substr(service_table(row_in).prtc, 4, 2) = 'AD'
            THEN
                labor_op := 8;
            ELSIF substr(service_table(row_in).prtc, 4, 2) = 'AL'
            THEN
                labor_op := 4;
            -- 05/11/2023 - RS7649 - added to assign RE to labor_op 9
            ELSIF substr(service_table(row_in).prtc, 4, 2) = 'RE'
             THEN
                labor_op := 9;
            END IF;

            my_prtc_desc := pkg_build_prtc_desc.full_description(service_table(row_in).prtc);

            IF labor_type IS NOT NULL
            THEN
                my_prtc_desc := rpad(my_prtc_desc, 40, ' ');
                IF substr(my_prtc_desc, 39, 2) = '  '
                THEN
                    my_prtc_desc := substr(my_prtc_desc, 1, 38) || '-' ||
                                    labor_type;
                END IF;
            END IF;

            -- 10/24/2006 mm5095 => added support for special material qualifiers
            special_qualifier := NULL;

            IF service_table(row_in).qgroup_skey IS NOT NULL
            THEN
                special_qualifier  := sf_getspecialqualifier(service_table(row_in)
                                                             .qgroup_skey);
                expanded_prtc_desc := pkg_build_prtc_desc.full_description(service_table(row_in).prtc);

                IF special_qualifier IS NOT NULL
                   AND
                   length(special_qualifier) + length(expanded_prtc_desc) + 1 < 41
                THEN
                    expanded_prtc_desc := pkg_build_prtc_desc.full_description(service_table(row_in).prtc) || ' ' ||
                                          special_qualifier;

                    -- 02/05/2008 jr6600 => added support for special material flag
                    special_material_flag := '1';
                    -- 02/05/2008 jr6600 => added support for special material flag

                    IF labor_type IS NOT NULL
                    THEN
                        expanded_prtc_desc := rpad(expanded_prtc_desc,
                                                   40,
                                                   ' ');
                        IF substr(expanded_prtc_desc, 39, 2) = '  '
                        THEN
                            expanded_prtc_desc := substr(expanded_prtc_desc,
                                                         1,
                                                         38) || '-' ||
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

            IF ioh_flag = 'Y'
            THEN
                pkg_ultramate_common.getnoteid_by_text('Included in Overhaul',
                                                       2,
                                                       note_id,
                                                       run_type,
                                                       gparallelnumber);
                IF baddpartnote
                THEN
                    utl_file.put_line(pnote_fhandle,
                                      nheader || '|' || nsection || '|' ||
                                      npart || '|2|' || note_id);
                    -- 02/07/08 mm5095 =>
                    -- 03/22/2008 mm5095 => added exception handling
                    BEGIN
                        INSERT /*+ um_data_dh_insert3 */
                        INTO um_data_dh
                            (service,
                             category_skey,
                             subcategory_skey,
                             part_skey,
                             note_type,
                             note_id)
                        VALUES
                            (service_barcode_in,
                             nheader,
                             nsection,
                             npart,
                             2,
                             note_id);
                    EXCEPTION
                        WHEN OTHERS THEN
                            dbms_output.put_line('Parse error inserting into um_data_dh');
                    END;
                    -- 03/22/2008 mm5095 => added exception handling
                    -- 02/07/08 mm5095 =>
                ELSE
                    utl_file.put_line(dtnote_fhandle,
                                      service_table(row_in)
                                      .barcode || '|2|' || note_id);
                    -- 02/07/08 mm5095 =>
                    -- 03/22/2008 mm5095 => added exception handling
                    BEGIN
                        INSERT /*+ um_data_dj_insert */
                        INTO um_data_dj
                            (service,
                             barcode,
                             note_type,
                             note_id)
                        VALUES
                            (service_barcode_in,
                             service_table(row_in).barcode,
                             2,
                             note_id);
                    EXCEPTION
                        WHEN OTHERS THEN
                            dbms_output.put_line('Parse error inserting into um_data_dj');
                    END;
                    -- 03/22/2008 mm5095 => added exception handling
                    -- 02/07/08 mm5095 =>
                END IF;

                -- check for overhaul labor value
                IF substr(service_table(row_in).prtc, 1, 1) = 'R'
                   OR substr(service_table(row_in).prtc, 2, 1) = 'R'
                   OR substr(service_table(row_in).prtc, 3, 1) = 'R'
                THEN
                    ceg_labor_time := rightoverhaultime;
                ELSIF substr(service_table(row_in).prtc, 1, 1) = 'L'
                      OR substr(service_table(row_in).prtc, 2, 1) = 'L'
                      OR substr(service_table(row_in).prtc, 3, 1) = 'L'
                THEN
                    ceg_labor_time := leftoverhaultime;
                ELSE
                    -- RightOverhaulTime applies to both when no differentiation
                    ceg_labor_time := rightoverhaultime;
                END IF;
            END IF;

            -- 2007/02/09 mm5095 => removed arguments not used
            pkg_ultramate_common.getstartenddate(service_table(row_in)
                                                 .lower_effectivity_date,
                                                 service_table(row_in)
                                                 .upper_effectivity_date,
                                                 start_date,
                                                 end_date);
            --    getStartEndDate(service_table(row_in).lower_effectivity_date, service_table(row_in).upper_effectivity_date, start_date, end_date, true);
            -- 2007/02/09 mm5095 => removed arguments not used

            IF nvl(service_table(row_in).quad_year_range, ' ') != ' '
               OR nvl(service_table(row_in).lower_effectivity_date,
                      to_date('01/01/2099', 'MM/DD/YYYY')) != glowerdate
               OR nvl(service_table(row_in).upper_effectivity_date,
                      to_date('01/01/2099', 'MM/DD/YYYY')) != gupperdate
            THEN
                quad_flag := 'T';
            ELSE
                quad_flag := 'F';
            END IF;

            smartprtc := pkg_ultramate_common.sf_getsmartprtcid(sf_transformprtc(service_table(row_in).prtc,
                                                                                 'SERVICE'),
                                                                run_type);

            -- 05/09/2008 mm5095 => added support for mixed case text
            mc_prtc_desc := pkg_ultramate_common.sf_getmixedcaseprtc(service_table(row_in)
                                                                     .component_category_skey,
                                                                     expanded_prtc_desc);
            -- 05/09/2008 mm5095 => added support for mixed case text

            -- 09/28/2015 mm5095
            line_text_skey          := sf_get_line_text_skey(upper(my_text),
                                                             my_text);
            expanded_prtc_text_skey := sf_get_line_text_skey(expanded_prtc_desc,
                                                             mc_prtc_desc);
            -- 09/28/2015 mm5095

            utl_file.put_line(detail_fhandle,
                              nheader || '|' || nsection || '|' ||
                               npart_detail || '|' || service_table(row_in)
                              .barcode || '|' || resequence || '|' ||
                               quad_flag || '|' || start_date || '|' ||
                               end_date || '|' || my_right_left_code || '|' ||
                               my_labor_type || '|' || labor_op || '|' || service_table(row_in).part_type_id || '|' ||
--                               my_labor_type || '|' || labor_op || '|' || 48 || '|' ||
                               substr(us_part_number, 1, 20) || '|' ||
                               substr(can_part_number, 1, 20) || '|' ||
                               my_text || '|' || my_prtc_desc || '|' ||
                               to_char(us_effdt1, 'MMDDYYYY') || '|' ||
                               us_price1 * 100 || '|' ||
                               to_char(can_effdt1, 'MMDDYYYY') || '|' ||
                               can_price1 * 100 || '|' ||
                               to_char(us_effdt2, 'MMDDYYYY') || '|' ||
                               us_price2 * 100 || '|' ||
                               to_char(can_effdt2, 'MMDDYYYY') || '|' ||
                               can_price2 * 100 || '|' ||
                               ceg_labor_time * 10 || '|' || smartprtc || '|' || service_table(row_in)
                              .suppression_reason_code
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
                               expanded_prtc_text_skey
                              -- 09/28/2015 mm5095
                              -- 02/09/2017 mm5095
                               || '|' ||
                               pkg_ultramate_common.sf_getfrench(line_text_skey,
                                                                 my_text) || '|' ||
                               pkg_ultramate_common.sf_getfrench(expanded_prtc_text_skey,
                                                                 mc_prtc_desc)
                              -- 02/09/2017 mm5095
                              );

            -- 07/25/2007 mm5095 => insert into table to support part list initiative
            -- 03/22/2008 mm5095 => added exception handling
            BEGIN
                INSERT /*+ um_data_dd_insert */
                INTO um_data_dd
                    (service,
                     category_skey,
                     subcategory_skey,
                     part_skey,
                     barcode,
                     sequence,
                     quad_flag,
                     start_date,
                     end_date,
                     right_left_code,
                     labor_type,
                     labor_op,
                     part_type,
                     us_part_number,
                     ca_part_number,
                     part_descr,
                     prtc_descr,
                     us_effect_date1,
                     us_price1,
                     ca_effect_date1,
                     ca_price1,
                     us_effect_date2,
                     us_price2,
                     ca_effect_date2,
                     ca_price2,
                     ceg_time,
                     partid,
                     suppression_code,
                     header_sequence,
                     last_update_user,
                     last_update_date,
                     material_desc,
                     material_flag,
                     unique_row_id,
                     component_skey)
                VALUES
                    (to_char(service_barcode_in),
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
--                     48,
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
                     USER,
                     SYSDATE,
                     mc_prtc_desc,
                     special_material_flag,
                     service_table(row_in).unique_row_id,
                     service_table(row_in).component_skey);
            EXCEPTION
                WHEN OTHERS THEN
                    dbms_output.put_line('Parse error inserting into um_data_dd');
            END;
            -- 03/22/2008 mm5095 => added exception handling

            -- 07/25/2007 mm5095 => insert into table to support part list initiative

            -- 07/08/02 mm5095 => note_group_xref fix
            IF service_table(row_in).version_type = 'PR'
            THEN
                OPEN note_cur(service_table(row_in).unique_row_id,
                              service_table(row_in).version_type);
                FETCH note_cur
                    INTO note_rec;
                WHILE note_cur%FOUND
                LOOP
                    IF instr(savedetailnote, note_rec.note_symbol) = 0
                       OR note_rec.note_symbol = '#'
                    THEN
                        pkg_ultramate_common.getnoteid_by_skey(note_rec.note_group_skey,
                                                               note_type,
                                                               note_id,
                                                               run_type,
                                                               gparallelnumber);
                        utl_file.put_line(dtnote_fhandle,
                                          service_table(row_in)
                                          .barcode || '|' || note_type || '|' ||
                                           note_id);
                        -- 02/07/08 mm5095 =>
                        -- 03/22/2008 mm5095 => added exception handling
                        BEGIN
                            INSERT /*+ um_data_dj_insert */
                            INTO um_data_dj
                                (service,
                                 barcode,
                                 note_type,
                                 note_id)
                            VALUES
                                (service_barcode_in,
                                 service_table(row_in).barcode,
                                 note_type,
                                 note_id);
                        EXCEPTION
                            WHEN OTHERS THEN
                                dbms_output.put_line('Parse error inserting into um_data_dj');
                        END;
                        -- 03/22/2008 mm5095 => added exception handling
                        -- 02/07/08 mm5095 =>
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
                WHILE note_cur_wip%FOUND
                LOOP
                    IF instr(savedetailnote, note_rec.note_symbol) = 0
                       OR note_rec.note_symbol = '#'
                    THEN
                        pkg_ultramate_common.getnoteid_by_skey(note_rec.note_group_skey,
                                                               note_type,
                                                               note_id,
                                                               run_type,
                                                               gparallelnumber);
                        utl_file.put_line(dtnote_fhandle,
                                          service_table(row_in)
                                          .barcode || '|' || note_type || '|' ||
                                           note_id);
                        -- 02/07/08 mm5095 =>
                        -- 03/22/2008 mm5095 => added exception handling
                        BEGIN
                            INSERT /*+ um_data_dj_insert2 */
                            INTO um_data_dj
                                (service,
                                 barcode,
                                 note_type,
                                 note_id)
                            VALUES
                                (service_barcode_in,
                                 service_table(row_in).barcode,
                                 note_type,
                                 note_id);
                        EXCEPTION
                            WHEN OTHERS THEN
                                dbms_output.put_line('Parse error inserting into um_data_dj');
                        END;
                        -- 03/22/2008 mm5095 => added exception handling
                        -- 02/07/08 mm5095 =>
                    END IF;
                    FETCH note_cur_wip
                        INTO note_rec;
                END LOOP;
                CLOSE note_cur_wip;
            END IF;
            -- 07/08/02 mm5095 => note_group_xref fix

            IF discontinued_flag = 'Y'
            THEN
                note_type := 3;
                pkg_ultramate_common.getnoteid_by_text('Discontinued by the Manufacturer',
                                                       note_type,
                                                       note_id,
                                                       run_type,
                                                       gparallelnumber);
                utl_file.put_line(dtnote_fhandle,
                                  service_table(row_in)
                                  .barcode || '|' || note_type || '|' ||
                                   note_id);
                -- 02/07/08 mm5095 =>
                -- 03/22/2008 mm5095 => added exception handling
                BEGIN
                    INSERT /*+ um_data_dj_insert3 */
                    INTO um_data_dj
                        (service,
                         barcode,
                         note_type,
                         note_id)
                    VALUES
                        (service_barcode_in,
                         service_table(row_in).barcode,
                         note_type,
                         note_id);
                EXCEPTION
                    WHEN OTHERS THEN
                        dbms_output.put_line('Parse error inserting into um_data_dj');
                END;
                -- 03/22/2008 mm5095 => added exception handling

                -- 02/07/08 mm5095 =>
            ELSIF new_flag = 'Y'
            THEN
                note_type := 5;
                pkg_ultramate_common.getnoteid_by_text('Remanufactured Part',
                                                       note_type,
                                                       note_id,
                                                       run_type,
                                                       gparallelnumber);
                utl_file.put_line(dtnote_fhandle,
                                  service_table(row_in)
                                  .barcode || '|' || note_type || '|' ||
                                   note_id);
                -- 02/07/08 mm5095 =>
                -- 03/22/2008 mm5095 => added exception handling
                BEGIN
                    INSERT /*+ um_data_dj_insert4 */
                    INTO um_data_dj
                        (service,
                         barcode,
                         note_type,
                         note_id)
                    VALUES
                        (service_barcode_in,
                         service_table(row_in).barcode,
                         note_type,
                         note_id);
                EXCEPTION
                    WHEN OTHERS THEN
                        dbms_output.put_line('Parse error inserting into um_data_dj');
                END;
                -- 03/22/2008 mm5095 => added exception handling
                -- 02/07/08 mm5095 =>
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                dbms_output.put_line('AddDetailPart ' || SQLERRM(SQLCODE));
        END;

        FUNCTION getlabortext
        (
            row_in INTEGER,
            bflag  BOOLEAN
        ) RETURN VARCHAR2 IS
            vvc2_return VARCHAR2(200);
        BEGIN

            IF nvl(service_table(row_in).labor_verb_skey, 0) > 0
            THEN
                vvc2_return := pkg_ultramate_common.sf_getlaborverbstring(service_table(row_in)
                                                                          .labor_verb_skey);
            END IF;

            IF nvl(service_table(row_in).component_skey, 0) > 0
            THEN
                IF vvc2_return IS NOT NULL
                THEN
                    vvc2_return := rtrim(vvc2_return) || ' ' ||
                                   pkg_ultramate_common.sf_getcomponentstring(service_table(row_in)
                                                                              .component_skey);
                ELSE
                    vvc2_return := pkg_ultramate_common.sf_getcomponentstring(service_table(row_in)
                                                                              .component_skey);
                END IF;
            END IF;

            IF nvl(service_table(row_in).qgroup_skey, 0) > 0
            THEN
                IF vvc2_return IS NOT NULL
                THEN
                    vvc2_return := rtrim(vvc2_return) || ' ' ||
                                   pkg_ultramate_common.sf_getqualifierstring(service_table(row_in)
                                                                              .qgroup_skey,
                                                                              '1',
                                                                              FALSE);
                ELSE
                    vvc2_return := pkg_ultramate_common.sf_getqualifierstring(service_table(row_in)
                                                                              .qgroup_skey,
                                                                              '1',
                                                                              FALSE);
                END IF;
            END IF;

            IF bflag
               AND nvl(service_table(row_in).inline_note_skey, 0) > 0
            THEN
                IF vvc2_return IS NOT NULL
                THEN
                    vvc2_return := rtrim(vvc2_return) ||
                                   pkg_ultramate_common.sf_getnote_by_skey(service_table(row_in)
                                                                           .inline_note_skey);
                ELSE
                    vvc2_return := pkg_ultramate_common.sf_getnote_by_skey(service_table(row_in)
                                                                           .inline_note_skey);
                END IF;
            END IF;

            RETURN rtrim(vvc2_return);
        END;

        -- 2007/02/09 mm5095 => removed arguments not used
        PROCEDURE addlaborpart
        (
            text_in                 VARCHAR2,
            row_in                  INTEGER,
            last_row_in             INTEGER,
            suppression_reason_code INTEGER
        )
        -- 2007/02/09 mm5095 => removed arguments not used
         IS
            part_text VARCHAR2(160);
            -- 2007/02/09 mm5095 => not used
            --    part_text2 varchar2(160);
            -- 2007/02/09 mm5095 => not used
            ncount          INTEGER;
            bremovecomplete BOOLEAN;

            -- 09/28/2105 mm5095
            line_text_skey NUMBER;
            -- 09/28/2105 mm5095

        BEGIN
            vvc2_procedure_name := 'AddLaborPart';

            part_text := rtrim(ltrim(text_in));

            IF nsection = 0
            THEN
                -- add dummy section
                bdummysection := TRUE;
                addsection(row_in,
                           pkg_ultramate_common.sf_getcategorystring(service_table(row_in)
                                                                     .category_skey));
            END IF;

            -- skip dual quarter overhaul's
            IF substr(service_table(row_in).prtc, 4, 2) = 'RZ'
            THEN
                RETURN;
            END IF;

            -- skip dual quarter overhaul's that wrap across multiple lines
            FOR n IN row_in .. last_row_in - 1
            LOOP
                IF inlaborset(n, row_in)
                THEN
                    IF substr(service_table(n).prtc, 4, 4) = 'TEXT'
                    THEN
                        IF substr(service_table(n + 1).prtc, 4, 2) = 'RZ'
                        THEN
                            RETURN;
                        END IF;
                    ELSE
                        EXIT;
                    END IF;
                ELSE
                    EXIT;
                END IF;
            END LOOP;

            IF substr(part_text, 1, 8) = 'Refinish'
               AND substr(part_text, length(part_text) - 6, 7) = 'Outside'
            THEN
                FOR n IN row_in + 1 .. last_row_in
                LOOP
                    IF NOT inlaborset(n, row_in)
                    THEN
                        EXIT;
                    END IF;

                    IF nvl(service_table(n).indent_level, ' ') = '0'
                       AND
                       (nvl(service_table(n).labor_verb_skey, 0) !=
                        nvl(service_table(row_in).labor_verb_skey, 0) OR
                        nvl(service_table(n).component_skey, 0) !=
                        nvl(service_table(row_in).component_skey, 0))
                    THEN
                        EXIT;
                    END IF;

                    IF substr(pkg_ultramate_common.sf_getlaborverbstring(service_table(n)
                                                                         .labor_verb_skey),
                              1,
                              3) = 'Add'
                    THEN
                        part_text := substr(part_text,
                                            1,
                                            length(part_text) - 8);
                        EXIT;
                    END IF;
                END LOOP;
            ELSIF substr(part_text, 1, 8) = 'Refinish'
                  AND
                  substr(part_text, length(part_text) - 7, 8) = 'Complete'
            THEN
                ncount          := 0;
                bremovecomplete := FALSE;
                FOR n IN row_in + 1 .. last_row_in
                LOOP
                    IF inlaborset(n, row_in)
                    THEN
                        IF nvl(service_table(n).right_left_code, ' ') = ' '
                        THEN
                            bremovecomplete := TRUE;
                            EXIT;
                        END IF;
                        ncount := ncount + 1;
                        IF ncount > 1
                        THEN
                            bremovecomplete := TRUE;
                            EXIT;
                        END IF;
                    ELSE
                        EXIT;
                    END IF;
                END LOOP;

                IF bremovecomplete
                THEN
                    part_text := substr(part_text, 1, length(part_text) - 9);
                END IF;
            END IF;

            npart := npart + 1;

            -- 09/28/2105 mm5095
            line_text_skey := sf_get_line_text_skey(part_text, part_text);
            -- 09/28/2105 mm5095

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

            -- 07/25/2007 mm5095 => insert into table to support part list initiative
            -- 03/22/2008 mm5095 => added exception handling
            BEGIN
                INSERT /*+ um_data_dc_insert */
                INTO um_data_dc
                    (service,
                     category_skey,
                     subcategory_skey,
                     part_skey,
                     part,
                     suppression_code,
                     last_update_user,
                     last_update_date,
                     -- 2012/08/09 mm5095 => next gen requirement
                     part_or_labor)
                -- 2012/08/09 mm5095 => next gen requirement
                VALUES
                    (to_char(service_barcode_in),
                     nheader,
                     nsection,
                     npart,
                     part_text,
                     suppression_reason_code,
                     USER,
                     SYSDATE,
                     -- 2012/08/09 mm5095 => next gen requirement
                     'L'
                     -- 2012/08/09 mm5095 => next gen requirement
                     );
            EXCEPTION
                WHEN OTHERS THEN
                    dbms_output.put_line('Parse error inserting into um_data_dc');
            END;
            -- 03/22/2008 mm5095 => added exception handling
            -- 07/25/2007 mm5095 => insert into table to support part list initiative

            savedetailnote := nvl(service_table(row_in).note_symbol, ' ');
            -- 07/08/02 mm5095 => note_group_xref fix
            IF service_table(row_in).version_type = 'PR'
            THEN
                OPEN note_cur(service_table(row_in).unique_row_id,
                              service_table(row_in).version_type);
                FETCH note_cur
                    INTO note_rec;
                WHILE note_cur%FOUND
                LOOP
                    IF note_rec.note_symbol != '#'
                    THEN
                        pkg_ultramate_common.getnoteid_by_skey(note_rec.note_group_skey,
                                                               note_type,
                                                               note_id,
                                                               run_type,
                                                               gparallelnumber);
                        utl_file.put_line(pnote_fhandle,
                                          nheader || '|' || nsection || '|' ||
                                          npart || '|' || note_type || '|' ||
                                          note_id);
                        -- 02/07/08 mm5095 =>
                        -- 03/22/2008 mm5095 => added exception handling
                        BEGIN
                            INSERT /*+ um_data_dh_insert */
                            INTO um_data_dh
                                (service,
                                 category_skey,
                                 subcategory_skey,
                                 part_skey,
                                 note_type,
                                 note_id)
                            VALUES
                                (service_barcode_in,
                                 nheader,
                                 nsection,
                                 npart,
                                 note_type,
                                 note_id);
                        EXCEPTION
                            WHEN OTHERS THEN
                                dbms_output.put_line('Parse error inserting into um_data_dh');
                        END;
                        -- 03/22/2008 mm5095 => added exception handling
                        -- 02/07/08 mm5095 =>
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
                WHILE note_cur_wip%FOUND
                LOOP
                    IF note_rec.note_symbol != '#'
                    THEN
                        pkg_ultramate_common.getnoteid_by_skey(note_rec.note_group_skey,
                                                               note_type,
                                                               note_id,
                                                               run_type,
                                                               gparallelnumber);
                        utl_file.put_line(pnote_fhandle,
                                          nheader || '|' || nsection || '|' ||
                                          npart || '|' || note_type || '|' ||
                                          note_id);
                        -- 02/07/08 mm5095 =>
                        -- 03/22/2008 mm5095 => added exception handling
                        BEGIN
                            INSERT /*+ um_data_dh_insert2 */
                            INTO um_data_dh
                                (service,
                                 category_skey,
                                 subcategory_skey,
                                 part_skey,
                                 note_type,
                                 note_id)
                            VALUES
                                (service_barcode_in,
                                 nheader,
                                 nsection,
                                 npart,
                                 note_type,
                                 note_id);
                        EXCEPTION
                            WHEN OTHERS THEN
                                dbms_output.put_line('Parse error inserting into um_data_dh');
                        END;
                        -- 03/22/2008 mm5095 => added exception handling
                        -- 02/07/08 mm5095 =>
                    END IF;
                    FETCH note_cur_wip
                        INTO note_rec;
                END LOOP;
                CLOSE note_cur_wip;
            END IF;
            -- 07/08/02 mm5095 => note_group_xref fix
        END;

        PROCEDURE addlabordetail
        (
            row_in  INTEGER,
            text_in VARCHAR2
        ) IS
            CURSOR labor_cur(prtc_in VARCHAR2) IS
                SELECT labor_rate_code
                  FROM prtc_body
                 WHERE prtc_body = prtc_in;

            ceg_labor_time NUMBER;
            ioh_flag       CHAR(1);
            labor_type     CHAR(1);
            -- 2007/02/09 mm5095 => not used
            --    labor_operation char(1);
            -- 2007/02/09 mm5095 => not used
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
            line_text_skey NUMBER;
            prtc_text_skey NUMBER;
            -- 09/28/2015 mm5095

        BEGIN
            IF substr(service_table(row_in).prtc, 4, 4) = 'TEXT'
            THEN
                RETURN;
            END IF;

            pkg_ultramate_common.sp_getlaborinfo(service_table(row_in)
                                                 .labor_operation_skey,
                                                 ceg_labor_time,
                                                 ioh_flag,
                                                 labor_type);

            my_right_left_code := 0;

            IF service_table(row_in).right_left_code = 'R'
            THEN
                my_right_left_code := 1;
            ELSIF service_table(row_in).right_left_code = 'L'
            THEN
                my_right_left_code := 2;
            END IF;

            --    my_labor_type := 0;

            OPEN labor_cur(substr(service_table(row_in).prtc, 4, 4));
            FETCH labor_cur
                INTO my_labor_rate;
            CLOSE labor_cur;

            my_labor_type := to_number(my_labor_rate);

            IF labor_type = 'M'
            THEN
                my_labor_type := 4;
            ELSIF labor_type = 'F'
            THEN
                my_labor_type := 3;
            END IF;

            labor_op := 1;
            -- 10/24/2006 mm5095 => added support for 'NA' refinish PRTC
            -- 08/13/2020 - pb0690 - added FC and FD
            IF substr(service_table(row_in).prtc, 4, 2) IN
               ('FA', 'FC', 'FD')
               OR substr(service_table(row_in).prtc, 4, 2) = 'NA'
            THEN
                --    if substr(service_table(row_in).prtc,4,2) = 'FA' then
                -- 10/24/2006 mm5095 => added support for 'NA' refinish PRTC
                labor_op := 6;
                -- 08/13/2020 - pb0690 - added IB and IC
            ELSIF substr(service_table(row_in).prtc, 4, 2) IN
                  ('IA', 'IB', 'IC')
            THEN
                labor_op := 2;
            ELSIF substr(service_table(row_in).prtc, 4, 2) = 'OA'
            THEN
                labor_op := 5;
            ELSIF substr(service_table(row_in).prtc, 4, 2) = 'AD'
            THEN
                labor_op := 8;
            ELSIF substr(service_table(row_in).prtc, 4, 2) = 'AL'
            THEN
                labor_op := 4;
            -- 05/11/2023 - RS7649 - added to assign RE to labor_op 9
            ELSIF substr(service_table(row_in).prtc, 4, 2) = 'RE'
             THEN
                labor_op := 9;
            END IF;

            my_text := rtrim(ltrim(text_in));
            pkg_ultramate_common.sp_striptext(my_text, my_right_left_code);

            IF substr(service_table(row_in).prtc, 4, 2) = 'RZ'
            THEN
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

            IF labor_type IS NOT NULL
            THEN
                my_prtc_desc := rpad(my_prtc_desc, 40, ' ');
                IF substr(my_prtc_desc, 39, 2) = '  '
                THEN
                    my_prtc_desc := substr(my_prtc_desc, 1, 38) || '-' ||
                                    labor_type;
                END IF;
            END IF;

            -- 2007/02/09 mm5095 => removed arguments not used
            pkg_ultramate_common.getstartenddate(service_table(row_in)
                                                 .lower_effectivity_date,
                                                 service_table(row_in)
                                                 .upper_effectivity_date,
                                                 start_date,
                                                 end_date);
            --    getStartEndDate(service_table(row_in).lower_effectivity_date, service_table(row_in).upper_effectivity_date, start_date, end_date, true);
            -- 2007/02/09 mm5095 => removed arguments not used

            IF nvl(service_table(row_in).quad_year_range, ' ') != ' '
               OR nvl(service_table(row_in).lower_effectivity_date,
                      to_date('01/01/2099', 'MM/DD/YYYY')) != glowerdate
               OR nvl(service_table(row_in).upper_effectivity_date,
                      to_date('01/01/2099', 'MM/DD/YYYY')) != gupperdate
            THEN
                quad_flag := 'T';
            ELSE
                quad_flag := 'F';
            END IF;

            smartprtc := pkg_ultramate_common.sf_getsmartprtcid(sf_transformprtc(service_table(row_in).prtc,
                                                                                 'SERVICE'),
                                                                run_type);

            -- 05/09/2008 mm5095 => added support for mixed case text
            mc_prtc_desc := pkg_ultramate_common.sf_getmixedcaseprtc(service_table(row_in)
                                                                     .component_category_skey,
                                                                     my_prtc_desc);
            -- 05/09/2008 mm5095 => added support for mixed case text

            -- 09/28/2015 mm5095
            line_text_skey := sf_get_line_text_skey(upper(my_text), my_text);
            prtc_text_skey := sf_get_line_text_skey(my_prtc_desc,
                                                    mc_prtc_desc);
            -- 09/28/2015 mm5095

            utl_file.put_line(detail_fhandle,
                              my_header || '|' || my_section || '|' ||
                               my_part || '|' || service_table(row_in)
                              .barcode || '|' || resequence || '|' ||
                               quad_flag || '|' || start_date || '|' ||
                               end_date || '|' || my_right_left_code || '|' ||
                               my_labor_type || '|' || labor_op || '|' || 48 || '|' || '' || '|' || '' || '|' ||
                               rtrim(my_text) || '|' || my_prtc_desc || '|' || '' || '|' || '' || '|' || '' || '|' || '' || '|' || '' || '|' || '' || '|' || '' || '|' || '' || '|' ||
                               ceg_labor_time * 10 || '|' || smartprtc || '|' || service_table(row_in)
                              .suppression_reason_code
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
                               || '|' || line_text_skey || '|' ||
                               prtc_text_skey
                              -- 09/28/2015 mm5095
                              -- 02/09/2017 mm5095
                               || '|' ||
                               pkg_ultramate_common.sf_getfrench(line_text_skey,
                                                                 my_text) || '|' ||
                               pkg_ultramate_common.sf_getfrench(prtc_text_skey,
                                                                 mc_prtc_desc)
                              -- 02/09/2017 mm5095
                              );

            -- 07/25/2007 mm5095 => insert into table to support part list initiative
            -- 03/22/2008 mm5095 => added exception handling
            BEGIN
                INSERT /*+ um_data_dd_insert */
                INTO um_data_dd
                    (service,
                     category_skey,
                     subcategory_skey,
                     part_skey,
                     barcode,
                     sequence,
                     quad_flag,
                     start_date,
                     end_date,
                     right_left_code,
                     labor_type,
                     labor_op,
                     part_type,
                     us_part_number,
                     ca_part_number,
                     part_descr,
                     prtc_descr,
                     us_effect_date1,
                     us_price1,
                     ca_effect_date1,
                     ca_price1,
                     us_effect_date2,
                     us_price2,
                     ca_effect_date2,
                     ca_price2,
                     ceg_time,
                     partid,
                     suppression_code,
                     header_sequence,
                     last_update_user,
                     last_update_date,
                     material_desc,
                     material_flag,
                     unique_row_id,
                     component_skey)
                VALUES
                    (to_char(service_barcode_in),
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
                     USER,
                     SYSDATE,
                     mc_prtc_desc,
                     '0',
                     service_table(row_in).unique_row_id,
                     service_table(row_in).component_skey);
            EXCEPTION
                WHEN OTHERS THEN
                    dbms_output.put_line('Parse error inserting into um_data_dd');
            END;
            -- 03/22/2008 mm5095 => added exception handling
            -- 07/25/2007 mm5095 => insert into table to support part list initiative

            IF service_table(row_in).clearcoat_flag = 'C'
            THEN
                note_type := 4;
                pkg_ultramate_common.getnoteid_by_text('Part Included in Clear Coat Application',
                                                       note_type,
                                                       note_id,
                                                       run_type,
                                                       gparallelnumber);

                utl_file.put_line(dtnote_fhandle,
                                  service_table(row_in)
                                  .barcode || '|' || note_type || '|' ||
                                   note_id);
                -- 02/07/08 mm5095 =>
                -- 03/22/2008 mm5095 => added exception handling
                BEGIN
                    INSERT /*+ um_data_dj_insert */
                    INTO um_data_dj
                        (service,
                         barcode,
                         note_type,
                         note_id)
                    VALUES
                        (service_barcode_in,
                         service_table(row_in).barcode,
                         note_type,
                         note_id);
                EXCEPTION
                    WHEN OTHERS THEN
                        dbms_output.put_line('Parse error inserting into um_data_dj');
                END;
                -- 03/22/2008 mm5095 => added exception handling
                -- 02/07/08 mm5095 =>
            END IF;

            IF service_table(row_in).version_type = 'PR'
            THEN
                OPEN note_cur(service_table(row_in).unique_row_id,
                              service_table(row_in).version_type);
                FETCH note_cur
                    INTO note_rec;
                WHILE note_cur%FOUND
                LOOP
                    IF instr(savedetailnote, note_rec.note_symbol) = 0
                       OR note_rec.note_symbol = '#'
                    THEN
                        pkg_ultramate_common.getnoteid_by_skey(note_rec.note_group_skey,
                                                               note_type,
                                                               note_id,
                                                               run_type,
                                                               gparallelnumber);
                        utl_file.put_line(dtnote_fhandle,
                                          service_table(row_in)
                                          .barcode || '|' || note_type || '|' ||
                                           note_id);
                        -- 02/07/08 mm5095 =>
                        -- 03/22/2008 mm5095 => added exception handling
                        BEGIN
                            INSERT /*+ um_data_dj_insert2 */
                            INTO um_data_dj
                                (service,
                                 barcode,
                                 note_type,
                                 note_id)
                            VALUES
                                (service_barcode_in,
                                 service_table(row_in).barcode,
                                 note_type,
                                 note_id);
                        EXCEPTION
                            WHEN OTHERS THEN
                                dbms_output.put_line('Parse error inserting into um_data_dj');
                        END;
                        -- 03/22/2008 mm5095 => added exception handling
                        -- 02/07/08 mm5095 =>
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
                WHILE note_cur_wip%FOUND
                LOOP
                    IF instr(savedetailnote, note_rec.note_symbol) = 0
                       OR note_rec.note_symbol = '#'
                    THEN
                        pkg_ultramate_common.getnoteid_by_skey(note_rec.note_group_skey,
                                                               note_type,
                                                               note_id,
                                                               run_type,
                                                               gparallelnumber);
                        utl_file.put_line(dtnote_fhandle,
                                          service_table(row_in)
                                          .barcode || '|' || note_type || '|' ||
                                           note_id);
                        -- 02/07/08 mm5095 =>
                        -- 03/22/2008 mm5095 => added exception handling
                        BEGIN
                            INSERT /*+ um_data_dj_insert3 */
                            INTO um_data_dj
                                (service,
                                 barcode,
                                 note_type,
                                 note_id)
                            VALUES
                                (service_barcode_in,
                                 service_table(row_in).barcode,
                                 note_type,
                                 note_id);
                        EXCEPTION
                            WHEN OTHERS THEN
                                dbms_output.put_line('Parse error inserting into um_data_dj');
                        END;
                        -- 03/22/2008 mm5095 => added exception handling
                        -- 02/07/08 mm5095 =>
                    END IF;
                    FETCH note_cur_wip
                        INTO note_rec;
                END LOOP;
                CLOSE note_cur_wip;
            END IF;

            -- get overhaul time, if any
            IF nvl(service_table(row_in).labor_verb_skey, 0) > 0
            THEN
                IF pkg_ultramate_common.sf_getlaborverbstring(service_table(row_in)
                                                              .labor_verb_skey) =
                   'O/H'
                THEN
                    IF substr(service_table(row_in).prtc, 4, 2) = 'OA'
                    THEN
                        IF substr(service_table(row_in).prtc, 6, 2) != '**'
                        THEN
                            labor_time := pkg_ultramate_common.sf_getlabortime(service_table(row_in)
                                                                               .labor_operation_skey);
                            IF labor_time > 0
                            THEN
                                IF rightoverhaultime = 0
                                   AND leftoverhaultime = 0
                                   AND
                                   nvl(service_table(row_in).right_left_code,
                                       ' ') = ' '
                                THEN
                                    rightoverhaultime := labor_time;
                                    leftoverhaultime  := labor_time;
                                ELSIF nvl(service_table(row_in)
                                          .right_left_code,
                                          ' ') = 'R'
                                THEN
                                    rightoverhaultime := labor_time;
                                ELSE
                                    leftoverhaultime := labor_time;
                                END IF;
                            END IF;
                        END IF;
                    END IF;
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                dbms_output.put_line('Add Labor ' || SQLERRM(SQLCODE));
        END;

        PROCEDURE create_chassis_notes
        (
            row_in      INTEGER,
            last_row_in INTEGER
        ) IS
            my_note_id     NUMBER;
            my_text        VARCHAR2(100);
            out_fhandle    utl_file.file_type;
            line_text_skey NUMBER;
        BEGIN
            IF gparallelnumber = '1'
            THEN
                BEGIN
                    SELECT /*+ max note */
                     MAX(note_id)
                      INTO my_note_id
                      FROM um_note;
                EXCEPTION
                    WHEN no_data_found THEN
                        my_note_id := 0;
                END;
            ELSIF gparallelnumber = '2'
            THEN
                BEGIN
                    SELECT /*+ max note2 */
                     MAX(note_id)
                      INTO my_note_id
                      FROM um_note2;
                EXCEPTION
                    WHEN no_data_found THEN
                        my_note_id := 0;
                END;
            END IF;

            out_fhandle := utl_file.fopen(path,
                                          'DI' || service_barcode || '.txt',
                                          'a');

            FOR n IN row_in .. last_row_in
            LOOP
                IF NOT inlaborset(n, row_in)
                THEN
                    EXIT;
                END IF;

                IF service_table(n).line_type = 'N'
                THEN

                    my_text := getlaborverbcomponent(n, FALSE);

                    IF my_text IS NOT NULL
                    THEN
                        my_text := my_text || ' ' ||
                                   pkg_ultramate_common.sf_getqualifierstring(service_table(n)
                                                                              .detail_qgroup_skey,
                                                                              '1',
                                                                              FALSE);
                    ELSE
                        my_text := pkg_ultramate_common.sf_getqualifierstring(service_table(n)
                                                                              .detail_qgroup_skey,
                                                                              '1',
                                                                              FALSE);
                    END IF;

                    my_note_id := my_note_id + 1;

                    -- 09/28/2015 mm5095
                    line_text_skey := sf_get_line_text_skey(my_text,
                                                            my_text);
                    -- 09/28/2015 mm5095

                    utl_file.put_line(out_fhandle,
                                      my_note_id || '|1|' ||
                                      -- 02/09/2017 mm5095
                                      -- 03/26/2017 mm5095 => bug fix
                                       '1|' ||
                                      --                    '|1|' ||
                                      -- 03/26/2017 mm5095 => bug fix
                                      -- 02/09/2017 mm5095
                                       my_text
                                      --- 09/28/2015 mm5095
                                       || '|' || line_text_skey
                                      --- 09/28/2015 mm5095
                                      );
                    -- 02/07/08 mm5095 =>
                    -- 03/22/2008 mm5095 => added exception handling

                    -- 02/09/2017 mm5095
                    utl_file.put_line(out_fhandle,
                                      my_note_id || '|2|' ||
                                      -- 03/26/2017 mm5095 => bug fix
                                       '1|' ||
                                      --                   '|1|' ||
                                      -- 03/26/2017 mm5095 => bug fix
                                       pkg_ultramate_common.sf_getfrench(line_text_skey,
                                                                         my_text) || '|' ||
                                       line_text_skey);
                    -- 02/09/2017 mm5095

                    BEGIN
                        INSERT /*+ um_data_di_insert */
                        INTO um_data_di
                            (service,
                             note_id,
                             line_sequence,
                             note_text)
                        VALUES
                            (service_barcode_in,
                             my_note_id,
                             1,
                             my_text);
                    EXCEPTION
                        WHEN OTHERS THEN
                            dbms_output.put_line('Parse error inserting into um_data_di ' ||
                                                 SQLCODE || ': ' ||
                                                 substr(SQLERRM, 1, 64) || ' ' ||
                                                 service_barcode_in || ' ' ||
                                                 row_in);
                    END;
                    -- 03/22/2008 mm5095 => added exception handling

                    -- 02/07/08 mm5095 =>

                    IF bdummysection
                    THEN
                        utl_file.put_line(pnote_fhandle,
                                          nheader || '|0|0|0|' ||
                                          my_note_id);
                        -- 02/07/08 mm5095 =>
                        -- 03/22/2008 mm5095 => added exception handling
                        BEGIN
                            INSERT /*+ um_data_dh_insert */
                            INTO um_data_dh
                                (service,
                                 category_skey,
                                 subcategory_skey,
                                 part_skey,
                                 note_type,
                                 note_id)
                            VALUES
                                (service_barcode_in,
                                 nheader,
                                 0,
                                 0,
                                 0,
                                 -- 03/21/2017 mm5095 => bug fix
                                 my_note_id);
                            --                                 note_id);
                            -- 03/21/2017 mm5095 => bug fix
                        EXCEPTION
                            WHEN OTHERS THEN
                                dbms_output.put_line('Parse error inserting into um_data_dh');
                        END;
                        -- 03/22/2008 mm5095 => added exception handling
                        -- 02/07/08 mm5095 =>

                    ELSE
                        utl_file.put_line(pnote_fhandle,
                                          nheader || '|' || nsection ||
                                          '|0|0|' || my_note_id);
                        -- 02/07/08 mm5095 =>
                        -- 03/22/2008 mm5095 => added exception handling
                        BEGIN
                            INSERT /*+ um_data_dh_insert2 */
                            INTO um_data_dh
                                (service,
                                 category_skey,
                                 subcategory_skey,
                                 part_skey,
                                 note_type,
                                 note_id)
                            VALUES
                                (service_barcode_in,
                                 nheader,
                                 0,
                                 0,
                                 0,
                                 -- 03/21/2017 mm5095 => bug fix
                                 my_note_id);
                            --                                 note_id);
                            -- 03/21/2017 mm5095 => bug fix
                        EXCEPTION
                            WHEN OTHERS THEN
                                dbms_output.put_line('Parse error inserting into um_data_dh');
                        END;
                        -- 03/22/2008 mm5095 => added exception handling
                        -- 02/07/08 mm5095 =>
                    END IF;
                END IF;
            END LOOP;

            IF utl_file.is_open(out_fhandle)
            THEN
                utl_file.fclose(out_fhandle);
            END IF;
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

        PROCEDURE create_main
        (
            service_barcode VARCHAR2,
            mfr_in          VARCHAR2,
            service_in      VARCHAR2,
            version_in      VARCHAR2
        ) IS
            CURSOR deleteandpoint_cur IS
                SELECT /*+ deleteandpoint_cur */
                 delete_message_prtc_body prtc_body,
                 note_text
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
            -- 2007/02/09 mm5095 => not used
            --    country_abbr varchar2(2);
            -- 2007/02/09 mm5095 => not used
            my_category VARCHAR2(80);
            my_text     VARCHAR2(200);
            -- 2007/02/09 mm5095 => not used
            --    bFirstTime boolean;
            -- 2007/02/09 mm5095 => not used
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

            -- 11/16/2004 mm5095 => added support for rr_vs_repair
            CURSOR rr_cur
            (
                mfr_in     VARCHAR2,
                service_in VARCHAR2,
                version_in VARCHAR2
            ) IS
                SELECT /*+ rr_cur */
                 b.barcode rr_barcode,
                 c.barcode ri_barcode
                  FROM labor_ri_rr             a,
                       service_category_detail b,
                       service_category_detail c
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
            -- 11/16/2004 mm5095 => added support for rr_vs_repair

            -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
            vehicle_type_skey    NUMBER;
            bcheckheadersequence BOOLEAN;
            -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5

            -- 05/09/2008 mm5095 => added support for mixed case Category description
            mc_category category_description.mixed_case_category_name%TYPE;
            -- 05/09/2008 mm5095 => added support for mixed case Category description

            tmp_graphic_file_name service_category_detail.graphic_file_name%TYPE;

            -- 09/28/2015 mm5095 => added support for English/French term keys
            line_text_skey NUMBER;
            -- 09/28/2015 mm5095 => added support for English/French term keys

        BEGIN
            vvc2_procedure_name := 'create_main';

            service_barcode_in := to_number(service_barcode);

            -- open output files
            header_fhandle  := utl_file.fopen(path,
                                              'DA' || service_barcode ||
                                              '.txt',
                                              'w');
            section_fhandle := utl_file.fopen(path,
                                              'DB' || service_barcode ||
                                              '.txt',
                                              'w');
            part_fhandle    := utl_file.fopen(path,
                                              'DC' || service_barcode ||
                                              '.txt',
                                              'w');
            detail_fhandle  := utl_file.fopen(path,
                                              'DD' || service_barcode ||
                                              '.txt',
                                              'w');

            -- 04/12/2006 mm5095 => add support for atg graphics UM 6.5
            --    if mfr_in != '006' then  -- ignore ATG graphics
            graphic_fhandle       := utl_file.fopen(path,
                                                    'DK' || service_barcode ||
                                                    '.txt',
                                                    'w');
            hotspot_fhandle       := utl_file.fopen(path,
                                                    'DE' || service_barcode ||
                                                    '.txt',
                                                    'w');
            color_graphic_fhandle := utl_file.fopen(path,
                                                    'DM' || service_barcode ||
                                                    '.txt',
                                                    'w');
            color_hotspot_fhandle := utl_file.fopen(path,
                                                    'DN' || service_barcode ||
                                                    '.txt',
                                                    'w');
            --    end if;
            -- 04/12/2006 mm5095 => add support for atg graphics UM 6.5

            pnote_fhandle  := utl_file.fopen(path,
                                             'DH' || service_barcode ||
                                             '.txt',
                                             'w');
            dtnote_fhandle := utl_file.fopen(path,
                                             'DJ' || service_barcode ||
                                             '.txt',
                                             'w');

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
            IF mfr_in > '700'
               AND mfr_in <= '799'
            THEN
                CLASS := 'CHT';
            ELSIF mfr_in > '200'
                  AND mfr_in <= '699'
            THEN
                CLASS := 'MCS';
            ELSIF mfr_in >= '100'
                  AND mfr_in <= '199'
            THEN
                CLASS := 'RVS';
                -- 01/14/2005 mm5095 => added ppage support for motorcycles and RVs
            ELSIF mfr_in = '006'
            THEN
                CLASS := 'ATG';
                -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
                --      resequence := 0;
                -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
                -- 04/21/2011 mm5095 => add support for mtd/htd
            ELSE
                CLASS := pkg_ultramate_common.sf_getclass(mfr_in,
                                                          service_in);
                -- 04/21/2011 mm5095 => add support for mtd/htd
            END IF;

            -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
            vehicle_type_skey    := pkg_ultramate_common.sf_get_vehicle_type(service_barcode,
                                                                             mfr_in);
            bcheckheadersequence := pkg_ultramate_common.sf_get_check_header(vehicle_type_skey);
            -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5

            -- 04/21/2011 mm5095 => add support for mtd/htd
            IF CLASS IN ('MTD', 'HTD')
            THEN
                vehicle_type_skey := 7;
            END IF;
            -- 04/21/2011 mm5095 => add support for mtd/htd

            -- load pl/sql table
            service_table := empty_service_table;
            last_row      := 0;
            FOR rec IN s_cur(mfr_in, service_in, version_in)
            LOOP
                -- if valid line, add to table
                IF NOT (nvl(rec.wip_tran_code, ' ') = 'D' OR
                    rec.delete_flag != 'N' OR
                    nvl(rec.forward_pointer_row_id, 0) > 0)
                THEN
                    -- 10/11/2004 mm5095 => added support for hidden lines
                    -- 07/12/04 mm5095 => added support for hidden lines
                    --        if suppression_flag = 'N' or not isSuppressedCategory(rec.category_skey, rec.subcategory_skey) then
                    -- 07/12/04 mm5095 => added support for hidden lines
                    -- 10/11/2004 mm5095 => added support for hidden lines

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

                    -- 10/11/2004 mm5095 => added support for hidden lines
                    --        end if;
                    -- 10/11/2004 mm5095 => added support for hidden lines
                END IF;
            END LOOP;

            IF last_row > 0
            THEN
                current_row           := 1;
                bconsecutive_graphics := FALSE;
                LOOP
                    BEGIN
                        IF service_table(current_row)
                         .line_type IN ('A', 'G')
                        THEN
                            IF nvl(service_table(current_row).indent_level,
                                   ' ') = '0'
                               OR
                               (nvl(service_table(current_row).indent_level,
                                    ' ') != '0' AND
                                (service_table(current_row).callout_number IS NOT NULL OR
                                  nvl(service_table(current_row)
                                      .inline_note_skey,
                                      0) > 0))
                            THEN
                                bcomponentset    := TRUE;
                                bcomponentdetail := TRUE;
                                bqualifierdetail := TRUE;
                                ncount           := 0;
                                barcode_row      := NULL;

                                -- 10/11/2004 mm5095 => added support for hidden lines
                                d_code := 0;
                                -- 10/11/2004 mm5095 => added support for hidden lines

                                FOR n IN current_row .. last_row
                                LOOP
                                    IF NOT inpartset(n, current_row)
                                    THEN
                                        EXIT;
                                    END IF;
                                    -- 10/11/2004 mm5095 => added support for hidden lines
                                    d_code := (d_code + service_table(n)
                                              .suppression_reason_code) -
                                              bitand(d_code,
                                                     service_table(n)
                                                     .suppression_reason_code);
                                    -- 10/11/2004 mm5095 => added support for hidden lines

                                    IF service_table(n)
                                     .line_type IN ('A', 'G')
                                    THEN
                                        IF nvl(service_table(n)
                                               .component_skey,
                                               0) != nvl(service_table(current_row)
                                                         .component_skey,
                                                         0)
                                        THEN
                                            bcomponentset := FALSE;
                                        END IF;

                                        IF nvl(service_table(n).barcode,
                                               ' ') != ' '
                                        THEN
                                            IF barcode_row IS NULL
                                            THEN
                                                barcode_row := n;
                                            END IF;

                                            IF nvl(service_table(n)
                                                   .component_skey,
                                                   0) != nvl(service_table(barcode_row)
                                                             .component_skey,
                                                             0)
                                            THEN
                                                bcomponentdetail := FALSE;
                                            END IF;

                                            IF nvl(service_table(n)
                                                   .qgroup_skey,
                                                   0) != nvl(service_table(barcode_row)
                                                             .qgroup_skey,
                                                             0)
                                            THEN
                                                bqualifierdetail := FALSE;
                                            END IF;

                                            ncount := ncount + 1;
                                        END IF;
                                    END IF;
                                END LOOP;

                                IF ncount = 0
                                THEN
                                    -- part inline note only line
                                    IF nvl(service_table(current_row)
                                           .inline_note_skey,
                                           0) > 0
                                    THEN
                                        -- 10/11/2004 mm5095 => added support for hidden lines
                                        addpart(nvl(service_table(current_row)
                                                    .callout_number,
                                                    ' '),
                                                getparttext(current_row,
                                                            '1',
                                                            TRUE,
                                                            TRUE),
                                                current_row,
                                                d_code);
                                        --              AddPart(nvl(service_table(current_row).callout_number,' '),getPartText(current_row,'1',true, true), current_row);
                                        -- 10/11/2004 mm5095 => added support for hidden lines
                                    ELSE
                                        -- 10/11/2004 mm5095 => added support for hidden lines
                                        d_code := 0;
                                        -- 10/11/2004 mm5095 => added support for hidden lines
                                        FOR n IN current_row .. last_row
                                        LOOP
                                            IF NOT inpartset(n, current_row)
                                            THEN
                                                current_row := n - 1;
                                                EXIT;
                                            END IF;

                                            -- 10/11/2004 mm5095 => added support for hidden lines
                                            d_code := (d_code + service_table(n)
                                                      .suppression_reason_code) -
                                                      bitand(d_code,
                                                             service_table(n)
                                                             .suppression_reason_code);
                                            -- 10/11/2004 mm5095 => added support for hidden lines
                                            IF nvl(service_table(n)
                                                   .inline_note_skey,
                                                   0) > 0
                                            THEN
                                                IF nvl(service_table(n)
                                                       .callout_number,
                                                       ' ') != ' '
                                                THEN
                                                    -- 10/11/2004 mm5095 => added support for hidden lines
                                                    addpart(nvl(service_table(n)
                                                                .callout_number,
                                                                ' '),
                                                            getparttext(n,
                                                                        '1',
                                                                        TRUE,
                                                                        TRUE),
                                                            n,
                                                            d_code);
                                                    d_code := 0;
                                                    --                    AddPart(nvl(service_table(n).callout_number,' '),getPartText(n,'1',true, true), n);
                                                    -- 10/11/2004 mm5095 => added support for hidden lines
                                                ELSE
                                                    -- 10/11/2004 mm5095 => added support for hidden lines
                                                    addpart(nvl(service_table(current_row)
                                                                .callout_number,
                                                                ' '),
                                                            getparttext(n,
                                                                        '1',
                                                                        TRUE,
                                                                        TRUE),
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
                                    IF bcomponentset
                                    THEN
                                        IF ncount = 1
                                        THEN
                                            -- 07/11/02 mm5095 => fix single detail preceded by detail line with inline note
                                            -- 10/11/2004 mm5095 => added support for hidden lines
                                            d_code := 0;
                                            -- 10/11/2004 mm5095 => added support for hidden lines
                                            FOR n IN current_row .. barcode_row
                                            LOOP
                                                IF NOT
                                                    inpartset(n, current_row)
                                                THEN
                                                    EXIT;
                                                END IF;

                                                -- 10/11/2004 mm5095 => added support for hidden lines
                                                d_code := (d_code + service_table(n)
                                                          .suppression_reason_code) -
                                                          bitand(d_code,
                                                                 service_table(n)
                                                                 .suppression_reason_code);
                                                -- 10/11/2004 mm5095 => added support for hidden lines
                                                IF nvl(service_table(n)
                                                       .barcode,
                                                       ' ') = ' '
                                                   AND nvl(service_table(n)
                                                           .indent_level,
                                                           ' ') != '0'
                                                   AND nvl(service_table(n)
                                                           .inline_note_skey,
                                                           0) > 0
                                                THEN
                                                    -- part inline note only detail line
                                                    -- 10/11/2004 mm5095 => added support for hidden lines
                                                    addpart(nvl(service_table(n)
                                                                .callout_number,
                                                                ' '),
                                                            getparttext(n,
                                                                        '1',
                                                                        TRUE,
                                                                        TRUE),
                                                            n,
                                                            d_code);
                                                    d_code := 0;
                                                    --                    AddPart(nvl(service_table(n).callout_number,' '),getPartText(n,'1',true,true), n);
                                                    -- 10/11/2004 mm5095 => added support for hidden lines
                                                END IF;
                                            END LOOP;
                                            -- 07/11/02 mm5095 => fix single detail preceded by detail line with inline note

                                            IF nvl(service_table(current_row)
                                                   .callout_number,
                                                   ' ') != ' '
                                            THEN
                                                -- 10/11/2004 mm5095 => added support for hidden lines
                                                IF d_code = 0
                                                THEN
                                                    d_code := service_table(barcode_row)
                                                              .suppression_reason_code;
                                                END IF;

                                                addpart(service_table(current_row)
                                                        .callout_number,
                                                        getparttext(barcode_row,
                                                                    '1',
                                                                    TRUE,
                                                                    TRUE),
                                                        barcode_row,
                                                        d_code);
                                                --                AddPart(service_table(current_row).callout_number,getPartText(barcode_row,'1',true,true), barcode_row);
                                                -- 10/11/2004 mm5095 => added support for hidden lines
                                                IF nvl(service_table(current_row)
                                                       .indent_level,
                                                       'Q') != 'Q'
                                                THEN
                                                    part_indent_level := service_table(current_row)
                                                                         .indent_level;
                                                END IF;
                                            ELSE
                                                -- 10/11/2004 mm5095 => added support for hidden lines
                                                IF d_code = 0
                                                THEN
                                                    d_code := service_table(barcode_row)
                                                              .suppression_reason_code;
                                                END IF;

                                                addpart(nvl(service_table(barcode_row)
                                                            .callout_number,
                                                            ' '),
                                                        getparttext(barcode_row,
                                                                    '1',
                                                                    TRUE,
                                                                    TRUE),
                                                        barcode_row,
                                                        d_code);
                                                --                  AddPart(nvl(service_table(barcode_row).callout_number,' '),getPartText(barcode_row,'1',true,true), barcode_row);
                                                -- 10/11/2004 mm5095 => added support for hidden lines
                                                IF nvl(service_table(barcode_row)
                                                       .indent_level,
                                                       'Q') != 'Q'
                                                THEN
                                                    part_indent_level := service_table(barcode_row)
                                                                         .indent_level;
                                                END IF;
                                            END IF;
                                            npart_detail := npart;
                                            addpartdetail(barcode_row,
                                                          getparttext(barcode_row,
                                                                      '1',
                                                                      TRUE),
                                                          TRUE);
                                            current_row := barcode_row;
                                        ELSE
                                            IF bqualifierdetail
                                            THEN
                                                IF nvl(service_table(barcode_row)
                                                       .qgroup_skey,
                                                       0) > 0
                                                THEN
                                                    -- 10/11/2004 mm5095 => added support for hidden lines
                                                    addpart(nvl(service_table(current_row)
                                                                .callout_number,
                                                                ' '),
                                                            getparttext(barcode_row,
                                                                        '1',
                                                                        TRUE),
                                                            barcode_row,
                                                            d_code);
                                                    --                    AddPart(nvl(service_table(current_row).callout_number,' '),getPartText(barcode_row,'1',true), barcode_row);
                                                    -- 10/11/2004 mm5095 => added support for hidden lines
                                                    IF nvl(service_table(current_row)
                                                           .indent_level,
                                                           'Q') != 'Q'
                                                    THEN
                                                        part_indent_level := service_table(current_row)
                                                                             .indent_level;
                                                    END IF;
                                                ELSE
                                                    IF nvl(service_table(current_row)
                                                           .callout_number,
                                                           ' ') != ' '
                                                    THEN
                                                        -- 10/11/2004 mm5095 => added support for hidden lines
                                                        addpart(nvl(service_table(current_row)
                                                                    .callout_number,
                                                                    ' '),
                                                                getparttext(barcode_row,
                                                                            '1',
                                                                            TRUE),
                                                                barcode_row,
                                                                d_code);
                                                        --                      AddPart(nvl(service_table(current_row).callout_number,' '),getPartText(barcode_row,'1',true), barcode_row);
                                                        -- 10/11/2004 mm5095 => added support for hidden lines
                                                        IF nvl(service_table(current_row)
                                                               .indent_level,
                                                               'Q') != 'Q'
                                                        THEN
                                                            part_indent_level := service_table(current_row)
                                                                                 .indent_level;
                                                        END IF;
                                                    ELSE
                                                        -- 10/11/2004 mm5095 => added support for hidden lines
                                                        addpart(nvl(service_table(barcode_row)
                                                                    .callout_number,
                                                                    ' '),
                                                                getparttext(barcode_row,
                                                                            '1',
                                                                            TRUE),
                                                                barcode_row,
                                                                d_code);
                                                        --                      AddPart(nvl(service_table(barcode_row).callout_number,' '),getPartText(barcode_row,'1',true), barcode_row);
                                                        -- 10/11/2004 mm5095 => added support for hidden lines
                                                        IF nvl(service_table(barcode_row)
                                                               .indent_level,
                                                               'Q') != 'Q'
                                                        THEN
                                                            part_indent_level := service_table(barcode_row)
                                                                                 .indent_level;
                                                        END IF;
                                                    END IF;
                                                END IF;

                                                npart_detail := npart;

                                                -- 10/11/2004 mm5095 => added support for hidden lines
                                                d_code := 0;
                                                -- 10/11/2004 mm5095 => added support for hidden lines
                                                FOR n IN current_row .. last_row
                                                LOOP
                                                    IF NOT
                                                        inpartset(n,
                                                                  current_row)
                                                    THEN
                                                        current_row := n - 1;
                                                        EXIT;
                                                    END IF;

                                                    -- 10/11/2004 mm5095 => added support for hidden lines
                                                    d_code := (d_code + service_table(n)
                                                              .suppression_reason_code) -
                                                              bitand(d_code,
                                                                     service_table(n)
                                                                     .suppression_reason_code);
                                                    -- 10/11/2004 mm5095 => added support for hidden lines
                                                    IF nvl(service_table(n)
                                                           .barcode,
                                                           ' ') != ' '
                                                    THEN
                                                        IF nvl(service_table(n)
                                                               .qgroup_skey,
                                                               0) > 0
                                                        THEN
                                                            addpartdetail(n,
                                                                          getqualifiernotestring(n,
                                                                                                 current_row,
                                                                                                 part_indent_level + 2,
                                                                                                 FALSE),
                                                                          ncount = 1);
                                                        ELSE
                                                            addpartdetail(n,
                                                                          NULL,
                                                                          ncount = 1);
                                                        END IF;
                                                    ELSE
                                                        IF nvl(service_table(n)
                                                               .indent_level,
                                                               ' ') != '0'
                                                           AND
                                                           nvl(service_table(n)
                                                               .inline_note_skey,
                                                               0) > 0
                                                        THEN
                                                            -- part inline note only detail line
                                                            -- 10/11/2004 mm5095 => added support for hidden lines
                                                            addpart(nvl(service_table(n)
                                                                        .callout_number,
                                                                        ' '),
                                                                    getparttext(n,
                                                                                '1',
                                                                                TRUE,
                                                                                TRUE),
                                                                    n,
                                                                    d_code);
                                                            d_code := 0;
                                                            --                        AddPart(nvl(service_table(n).callout_number,' '),getPartText(n,'1',true,true), n);
                                                            -- 10/11/2004 mm5095 => added support for hidden lines
                                                        END IF;
                                                    END IF;

                                                    IF n = last_row
                                                    THEN
                                                        current_row := last_row;
                                                        EXIT;
                                                    END IF;
                                                END LOOP;
                                            ELSE
                                                -- component same, qualifiers differ
                                                -- 10/11/2004 mm5095 => added support for hidden lines
                                                addpart(nvl(service_table(current_row)
                                                            .callout_number,
                                                            ' '),
                                                        getparttext(current_row,
                                                                    '1',
                                                                    TRUE),
                                                        current_row,
                                                        d_code);
                                                --                  AddPart(nvl(service_table(current_row).callout_number,' '),getPartText(current_row,'1',true), current_row);
                                                -- 10/11/2004 mm5095 => added support for hidden lines
                                                IF nvl(service_table(current_row)
                                                       .indent_level,
                                                       'Q') != 'Q'
                                                THEN
                                                    part_indent_level := service_table(current_row)
                                                                         .indent_level;
                                                END IF;
                                                npart_detail := npart;
                                                -- 10/11/2004 mm5095 => added support for hidden lines
                                                d_code := 0;
                                                -- 10/11/2004 mm5095 => added support for hidden lines
                                                FOR n IN current_row .. last_row
                                                LOOP
                                                    IF NOT
                                                        inpartset(n,
                                                                  current_row)
                                                    THEN
                                                        current_row := n - 1;
                                                        EXIT;
                                                    END IF;

                                                    -- 10/11/2004 mm5095 => added support for hidden lines
                                                    d_code := (d_code + service_table(n)
                                                              .suppression_reason_code) -
                                                              bitand(d_code,
                                                                     service_table(n)
                                                                     .suppression_reason_code);
                                                    -- 10/11/2004 mm5095 => added support for hidden lines
                                                    IF nvl(service_table(n)
                                                           .indent_level,
                                                           'Q') != 'Q'
                                                    THEN
                                                        last_indent_level := service_table(n)
                                                                             .indent_level;
                                                    END IF;

                                                    IF nvl(service_table(current_row)
                                                           .indent_level,
                                                           ' ') != '0'
                                                       AND last_indent_level <
                                                       nvl(service_table(current_row)
                                                               .indent_level,
                                                               ' ')
                                                    THEN
                                                        -- 10/11/2004 mm5095 => added support for hidden lines
                                                        addpart(nvl(service_table(n)
                                                                    .callout_number,
                                                                    ' '),
                                                                getparttext(n,
                                                                            '1',
                                                                            TRUE),
                                                                n,
                                                                d_code);
                                                        d_code := 0;
                                                        --                      AddPart(nvl(service_table(n).callout_number,' '),getPartText(n,'1',true),n);
                                                        -- 10/11/2004 mm5095 => added support for hidden lines
                                                        part_indent_level := last_indent_level;
                                                        npart_detail      := npart;
                                                        current_row       := n;
                                                        -- 08/06/02 mm5095
                                                        IF nvl(service_table(n)
                                                               .barcode,
                                                               ' ') != ' '
                                                        THEN
                                                            addpartdetail(n,
                                                                          pkg_ultramate_common.sf_getqualifierstring(service_table(n)
                                                                                                                     .qgroup_skey,
                                                                                                                     part_indent_level + 2,
                                                                                                                     FALSE),
                                                                          ncount = 1);
                                                        END IF;
                                                        -- 08/06/02 mm5095
                                                    ELSIF n != current_row
                                                          AND
                                                          nvl(service_table(n)
                                                              .indent_level,
                                                              ' ') = '0'
                                                          AND n > 1
                                                          AND service_table(n - 1)
                                                         .line_type IN
                                                          ('A', 'G')
                                                          AND
                                                          nvl(service_table(n - 1)
                                                              .indent_level,
                                                              'Q') = 'Q'
                                                    THEN
                                                        -- 10/11/2004 mm5095 => added support for hidden lines
                                                        addpart(nvl(service_table(n)
                                                                    .callout_number,
                                                                    ' '),
                                                                getparttext(n,
                                                                            '1',
                                                                            TRUE),
                                                                n,
                                                                d_code);
                                                        d_code := 0;
                                                        --                      AddPart(nvl(service_table(n).callout_number,' '),getPartText(n,'1',true),n);
                                                        -- 10/11/2004 mm5095 => added support for hidden lines
                                                        IF nvl(service_table(n)
                                                               .indent_level,
                                                               'Q') != 'Q'
                                                        THEN
                                                            part_indent_level := service_table(n)
                                                                                 .indent_level;
                                                        END IF;
                                                        npart_detail := npart;
                                                        current_row  := n;
                                                        -- 08/06/02 mm5095
                                                        IF nvl(service_table(n)
                                                               .barcode,
                                                               ' ') != ' '
                                                        THEN
                                                            addpartdetail(n,
                                                                          pkg_ultramate_common.sf_getqualifierstring(service_table(n)
                                                                                                                     .qgroup_skey,
                                                                                                                     part_indent_level + 2,
                                                                                                                     FALSE),
                                                                          ncount = 1);
                                                        END IF;
                                                        -- 08/06/02 mm5095
                                                    ELSIF nvl(service_table(current_row)
                                                              .indent_level,
                                                              ' ') != '0'
                                                          AND
                                                          nvl(service_table(current_row)
                                                              .callout_number,
                                                              ' ') != ' '
                                                          AND nvl(service_table(n)
                                                                  .indent_level,
                                                                  ' ') =
                                                          nvl(service_table(current_row)
                                                                  .indent_level,
                                                                  ' ')
                                                         -- 08/06/02 mm5095
                                                         --                      and nvl(service_table(n).qgroup_skey,0) != nvl(service_table(current_row).qgroup_skey,0) then
                                                          AND nvl(service_table(n)
                                                                  .qgroup_skey,
                                                                  0) !=
                                                          nvl(service_table(current_row)
                                                                  .qgroup_skey,
                                                                  0)
                                                          AND
                                                          nvl(service_table(n)
                                                              .barcode,
                                                              ' ') != ' '
                                                    THEN
                                                        -- 08/06/02 mm5095

                                                        -- 10/11/2004 mm5095 => added support for hidden lines
                                                        addpart(nvl(service_table(n)
                                                                    .callout_number,
                                                                    ' '),
                                                                getparttext(n,
                                                                            '1',
                                                                            TRUE),
                                                                n,
                                                                d_code);
                                                        d_code := 0;
                                                        --                        AddPart(nvl(service_table(n).callout_number,' '),getPartText(n,'1',true),n);
                                                        -- 10/11/2004 mm5095 => added support for hidden lines
                                                        IF nvl(service_table(n)
                                                               .indent_level,
                                                               'Q') != 'Q'
                                                        THEN
                                                            part_indent_level := service_table(n)
                                                                                 .indent_level;
                                                        END IF;

                                                        npart_detail := npart;
                                                        current_row  := n;
                                                        -- 08/06/02 mm5095
                                                        addpartdetail(n,
                                                                      pkg_ultramate_common.sf_getqualifierstring(service_table(n)
                                                                                                                 .qgroup_skey,
                                                                                                                 part_indent_level + 2,
                                                                                                                 FALSE),
                                                                      ncount = 1);
                                                        -- 08/06/02 mm5095
                                                    ELSIF nvl(service_table(n)
                                                              .barcode,
                                                              ' ') = ' '
                                                    THEN
                                                        IF nvl(service_table(n)
                                                               .indent_level,
                                                               ' ') != '0'
                                                           AND
                                                           nvl(service_table(n)
                                                               .inline_note_skey,
                                                               0) > 0
                                                        THEN
                                                            -- part inline note only detail line
                                                            -- 10/11/2004 mm5095 => added support for hidden lines
                                                            -- 08/22/2006 => correct hidden line inline note error
                                                            addpart(nvl(service_table(n)
                                                                        .callout_number,
                                                                        ' '),
                                                                    getparttext(n,
                                                                                '1',
                                                                                TRUE,
                                                                                TRUE),
                                                                    n,
                                                                    service_table(n)
                                                                    .suppression_reason_code);
                                                            --                        AddPart(nvl(service_table(n).callout_number,' '),getPartText(n,'1',true,true), n, d_code);
                                                            -- 08/22/2006 => correct hidden line inline note error
                                                            d_code := 0;
                                                            --                        AddPart(nvl(service_table(n).callout_number,' '),getPartText(n,'1',true,true), n);
                                                            -- 10/11/2004 mm5095 => added support for hidden lines
                                                        END IF;
                                                    ELSE
                                                        addpartdetail(n,
                                                                      pkg_ultramate_common.sf_getqualifierstring(service_table(n)
                                                                                                                 .qgroup_skey,
                                                                                                                 part_indent_level + 2,
                                                                                                                 FALSE),
                                                                      ncount = 1);
                                                    END IF;

                                                    IF n = last_row
                                                    THEN
                                                        current_row := last_row;
                                                        EXIT;
                                                    END IF;
                                                END LOOP;
                                            END IF;
                                        END IF;
                                    ELSE
                                        -- component and/or qualifiers are different
                                        -- 10/11/2004 mm5095 => added support for hidden lines
                                        addpart(nvl(service_table(current_row)
                                                    .callout_number,
                                                    ' '),
                                                getparttext(current_row,
                                                            '1',
                                                            TRUE),
                                                current_row,
                                                d_code);
                                        --              AddPart(nvl(service_table(current_row).callout_number,' '),getPartText(current_row,'1',true), current_row);
                                        -- 10/11/2004 mm5095 => added support for hidden lines
                                        IF nvl(service_table(current_row)
                                               .indent_level,
                                               'Q') != 'Q'
                                        THEN
                                            part_indent_level := service_table(current_row)
                                                                 .indent_level;
                                        END IF;
                                        npart_detail := npart;

                                        FOR n IN current_row .. last_row
                                        LOOP
                                            IF NOT inpartset(n, current_row)
                                            THEN
                                                EXIT;
                                            END IF;

                                            IF nvl(service_table(n).barcode,
                                                   ' ') != ' '
                                            THEN
                                                addpartdetail(n,
                                                              getparttext(n,
                                                                          part_indent_level + 2,
                                                                          nvl(service_table(n)
                                                                              .inline_note_skey,
                                                                              0) !=
                                                                          nvl(service_table(current_row)
                                                                              .inline_note_skey,
                                                                              0)),
                                                              ncount = 1);
                                            END IF;

                                            IF n = last_row
                                            THEN
                                                current_row := last_row;
                                                EXIT;
                                            END IF;
                                        END LOOP;
                                    END IF;
                                END IF;
                            END IF;
                        ELSIF service_table(current_row)
                         .line_type IN ('C', 'K', 'R')
                        THEN
                            pkg_ultramate_common.getnoteid_by_skey(service_table(current_row)
                                                                   .note_group_skey,
                                                                   note_type,
                                                                   note_id,
                                                                   run_type,
                                                                   gparallelnumber);
                            IF bdummysection
                            THEN
                                utl_file.put_line(pnote_fhandle,
                                                  nheader || '|0|0|' ||
                                                  note_type || '|' ||
                                                  note_id);
                                -- 02/07/08 mm5095 =>
                                -- 03/22/2008 mm5095 => added exception handling
                                BEGIN
                                    INSERT /*+ um_data_dh_insert */
                                    INTO um_data_dh
                                        (service,
                                         category_skey,
                                         subcategory_skey,
                                         part_skey,
                                         note_type,
                                         note_id)
                                    VALUES
                                        (service_barcode_in,
                                         nheader,
                                         0,
                                         note_type,
                                         0,
                                         note_id);
                                EXCEPTION
                                    WHEN OTHERS THEN
                                        dbms_output.put_line('Parse error inserting into um_data_dh');
                                END;
                                -- 03/22/2008 mm5095 => added exception handling
                                -- 02/07/08 mm5095 =>

                            ELSE
                                utl_file.put_line(pnote_fhandle,
                                                  nheader || '|' ||
                                                  nsection || '|0|' ||
                                                  note_type || '|' ||
                                                  note_id);
                                -- 02/07/08 mm5095 =>
                                -- 03/22/2008 mm5095 => added exception handling
                                BEGIN
                                    INSERT /*+ um_data_dh_insert2 */
                                    INTO um_data_dh
                                        (service,
                                         category_skey,
                                         subcategory_skey,
                                         part_skey,
                                         note_type,
                                         note_id)
                                    VALUES
                                        (service_barcode_in,
                                         nheader,
                                         nsection,
                                         0,
                                         note_type,
                                         note_id);
                                EXCEPTION
                                    WHEN OTHERS THEN
                                        dbms_output.put_line('Parse error inserting into um_data_dh');
                                END;
                                -- 03/22/2008 mm5095 => added exception handling
                                -- 02/07/08 mm5095 =>
                            END IF;
                        ELSIF service_table(current_row).line_type = 'H'
                        THEN
                            nheader           := nheader + 1;
                            nsection          := 0;
                            npart             := 0;
                            rightoverhaultime := 0;
                            leftoverhaultime  := 0;
                            bdummysection     := FALSE;
                            my_category       := pkg_ultramate_common.sf_getcategorystring(service_table(current_row)
                                                                                           .category_skey);
                            -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
                            IF bcheckheadersequence
                            THEN
                                header_sequence := pkg_ultramate_common.sf_get_header_sequence(vehicle_type_skey,
                                                                                               mfr_in,
                                                                                               service_table(current_row)
                                                                                               .category_skey,
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
                            utl_file.put_line(header_fhandle,
                                              nheader || '|' ||
                                               rtrim(my_category)
                                              -- 10/11/2004 mm5095 => added support for hidden lines
                                               || '|' || service_table(current_row)
                                              .suppression_reason_code
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

                            -- 07/25/2007 mm5095 => insert into table to support part list initiative
                            -- 03/22/2008 mm5095 => added exception handling
                            BEGIN
                                INSERT /*+ um_data_da_insert */
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
                                     service_table(current_row)
                                     .suppression_reason_code);
                            EXCEPTION
                                WHEN OTHERS THEN
                                    dbms_output.put_line('Parse error inserting into um_data_da');
                            END;
                            -- 03/22/2008 mm5095 => added exception handling
                            -- 07/25/2007 mm5095 => insert into table to support part list initiative

                            glowerdate := nvl(service_table(current_row)
                                              .lower_effectivity_date,
                                              to_date('01/01/2099',
                                                      'MM/DD/YYYY'));
                            gupperdate := nvl(service_table(current_row)
                                              .upper_effectivity_date,
                                              to_date('01/01/2099',
                                                      'MM/DD/YYYY'));

                            -- get ppage text
                            my_text := sf_getppagetext(CLASS,
                                                       mfr_in,
                                                       service_in,
                                                       version_in,
                                                       service_table(current_row)
                                                       .category_skey);
                            IF my_text IS NOT NULL
                            THEN
                                pkg_ultramate_common.getnoteid_by_text(my_text,
                                                                       215,
                                                                       note_id,
                                                                       run_type,
                                                                       gparallelnumber);
                                utl_file.put_line(pnote_fhandle,
                                                  nheader || '|0|0|215|' ||
                                                  note_id);
                                -- 02/07/08 mm5095 =>
                                -- 03/22/2008 mm5095 => added exception handling
                                BEGIN
                                    INSERT /*+ um_data_dh_insert */
                                    INTO um_data_dh
                                        (service,
                                         category_skey,
                                         subcategory_skey,
                                         part_skey,
                                         note_type,
                                         note_id)
                                    VALUES
                                        (service_barcode_in,
                                         nheader,
                                         0,
                                         0,
                                         215,
                                         note_id);
                                EXCEPTION
                                    WHEN OTHERS THEN
                                        dbms_output.put_line('Parse error inserting into um_data_dh');
                                END;
                                -- 03/22/2008 mm5095 => added exception handling
                                -- 02/07/08 mm5095 =>
                            END IF;
                            -- 04/12/2006 mm5095 => add support for atg graphics UM 6.5
                        ELSIF service_table(current_row).line_type = 'I'
                        THEN
                            --        elsif service_table(current_row).line_type = 'I' and mfr_in != '006' then -- ignore ATG graphics
                            -- 04/12/2006 mm5095 => add support for atg graphics UM 6.5
                            -- save previous graphic info just in case 2 graphics before part details
                            graphic_file_name_pre := graphic_file_name;
                            nimage_pre            := nimage;

                            graphic_file_name := service_table(current_row)
                                                 .graphic_file_name;

                            -- 09/25/02 mm5095 => unique graphic fix
                            BEGIN
                                SELECT /*+ tmp_um_graphic_select */
                                 graphic_id
                                  INTO nimage
                                  FROM tmp_um_graphic
                                 WHERE graphic_name = graphic_file_name;
                            EXCEPTION
                                WHEN no_data_found THEN
                                    SELECT MAX(graphic_id)
                                      INTO nimage
                                      FROM tmp_um_graphic;

                                    IF nimage IS NULL
                                    THEN
                                        nimage := 0;
                                    END IF;

                                    nimage := nimage + 1;
                                    INSERT INTO tmp_um_graphic
                                    VALUES
                                        (nimage,
                                         graphic_file_name);

                                    --          nimage := nimage + 1;
                                    utl_file.put_line(graphic_fhandle,
                                                      nimage || '|' || service_table(current_row)
                                                      .graphic_file_name);

                                    -- 09/22/2009 mm5095: added to support color graphics
                                    BEGIN
                                        SELECT a.graphic_file_name
                                          INTO tmp_graphic_file_name
                                        -- 02/24/2011 mm5095 => limit color graphics to special materials
                                          FROM graphic                  a,
                                               special_material_graphic b
                                         WHERE a.graphic_file_name = service_table(current_row)
                                              .graphic_file_name || '.png'
                                           AND b.graphic_file_name =
                                               a.graphic_file_name;
                                        --              FROM graphic a
                                        --              WHERE a.graphic_file_name = service_table(current_row).graphic_file_name || '.png';
                                        -- 02/24/2011 mm5095 => limit color graphics to special materials
                                        utl_file.put_line(color_graphic_fhandle,
                                                          nimage || '|' ||
                                                          graphic_file_name ||
                                                          '.png');
                                    EXCEPTION
                                        WHEN OTHERS THEN
                                            utl_file.put_line(color_graphic_fhandle,
                                                              nimage || '|' ||
                                                              graphic_file_name ||
                                                              '.tif');
                                    END;
                                    -- 09/22/2009 mm5095: added to support color graphics

                                    -- 02/07/2008 mm5095 => to support Adesa, FocusWrite and Online data
                                    -- 03/22/2008 mm5095 => added exception handling
                                    BEGIN
                                        INSERT /*+ um_data_dk_insert */
                                        INTO um_data_dk
                                            (service,
                                             image_skey,
                                             graphic_file_name,
                                             graphic_extension)
                                        VALUES
                                            (to_char(service_barcode_in),
                                             nimage,
                                             service_table(current_row)
                                             .graphic_file_name,
                                             NULL);
                                    EXCEPTION
                                        WHEN OTHERS THEN
                                            dbms_output.put_line('Parse error inserting into um_data_dk');
                                    END;
                                    -- 03/22/2008 mm5095 => added exception handling
                                -- 02/07/2008 mm5095 => to support Adesa, FocusWrite and Online data
                            END;
                            -- 09/25/02 mm5095 => unique graphic fix

                            -- 04/21/2011 mm5095 => add support for mtd/htd
                            IF mfr_in = '006'
                               OR my_category = 'UNDERHOOD DIMENSIONS'
                               OR NOT hashotspot(graphic_file_name)
                            THEN
                                -- 04/12/2006 mm5095 => add support for atg graphics UM 6.5
                                --          if mfr_in = '006' or my_category = 'UNDERHOOD DIMENSIONS' then
                                -- 04/21/2011 mm5095 => add support for mtd/htd
                                --          if my_category = 'UNDERHOOD DIMENSIONS' then
                                -- 04/12/2006 mm5095 => add support for atg graphics UM 6.5
                                IF bdummysection
                                THEN
                                    utl_file.put_line(hotspot_fhandle,
                                                      nheader || '|0|0|' ||
                                                      nimage ||
                                                      '|0|0|0|0|0');
                                    -- 09/22/2009 mm5095: added to support color graphics
                                    utl_file.put_line(color_hotspot_fhandle,
                                                      nheader || '|0|0|' ||
                                                      nimage ||
                                                      '|0|0|0|0|0');
                                    -- 09/22/2009 mm5095: added to support color graphics
                                    -- 02/07/2008 mm5095 => to support Adesa, FocusWrite and Online data
                                    -- 03/22/2008 mm5095 => added exception handling
                                    BEGIN
                                        INSERT /*+ um_data_de_insert */
                                        INTO um_data_de
                                            (service,
                                             category_skey,
                                             subcategory_skey,
                                             part_skey,
                                             image_skey,
                                             callout_number,
                                             x_coordinate,
                                             y_coordinate,
                                             x_extent,
                                             y_extent)
                                        VALUES
                                            (to_char(service_barcode_in),
                                             nheader,
                                             0,
                                             0,
                                             nimage,
                                             0,
                                             0,
                                             0,
                                             0,
                                             0);
                                    EXCEPTION
                                        WHEN OTHERS THEN
                                            dbms_output.put_line('Parse error inserting into um_data_de');
                                    END;
                                    -- 03/22/2008 mm5095 => added exception handling
                                    -- 02/07/2008 mm5095 => to support Adesa, FocusWrite and Online data
                                ELSE
                                    utl_file.put_line(hotspot_fhandle,
                                                      nheader || '|' ||
                                                      nsection || '|0|' ||
                                                      nimage ||
                                                      '|0|0|0|0|0');
                                    -- 09/22/2009 mm5095: added to support color graphics
                                    utl_file.put_line(color_hotspot_fhandle,
                                                      nheader || '|' ||
                                                      nsection || '|0|' ||
                                                      nimage ||
                                                      '|0|0|0|0|0');
                                    -- 09/22/2009 mm5095: added to support color graphics
                                    -- 02/07/2008 mm5095 => to support Adesa, FocusWrite and Online data
                                    -- 03/22/2008 mm5095 => added exception handling
                                    BEGIN
                                        INSERT /*+ um_data_de_insert2 */
                                        INTO um_data_de
                                            (service,
                                             category_skey,
                                             subcategory_skey,
                                             part_skey,
                                             image_skey,
                                             callout_number,
                                             x_coordinate,
                                             y_coordinate,
                                             x_extent,
                                             y_extent)
                                        VALUES
                                            (to_char(service_barcode_in),
                                             nheader,
                                             nsection,
                                             0,
                                             nimage,
                                             0,
                                             0,
                                             0,
                                             0,
                                             0);
                                    EXCEPTION
                                        WHEN OTHERS THEN
                                            dbms_output.put_line('Parse error inserting into um_data_de');
                                    END;
                                    -- 03/22/2008 mm5095 => added exception handling

                                    -- 02/07/2008 mm5095 => to support Adesa, FocusWrite and Online data
                                END IF;
                            END IF;
                        ELSIF service_table(current_row)
                         .line_type = 'N'
                               AND
                               nvl(service_table(current_row).indent_level,
                                   ' ') = '0'
                        THEN

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

                            FOR n IN current_row .. last_row
                            LOOP
                                IF NOT inlaborset(n, current_row)
                                THEN
                                    EXIT;
                                END IF;

                                -- 10/11/2004 mm5095 => added support for hidden lines
                                d_code := (d_code + service_table(n)
                                          .suppression_reason_code) -
                                          bitand(d_code,
                                                 service_table(n)
                                                 .suppression_reason_code);
                                -- 10/11/2004 mm5095 => added support for hidden lines

                                IF service_table(n).line_type = 'N'
                                THEN
                                    IF nvl(service_table(n).labor_verb_skey,
                                           0) != nvl(service_table(current_row)
                                                     .labor_verb_skey,
                                                     0)
                                    THEN
                                        blaborverbset := FALSE;
                                    END IF;

                                    IF nvl(service_table(n).component_skey,
                                           0) != nvl(service_table(current_row)
                                                     .component_skey,
                                                     0)
                                    THEN
                                        bcomponentset := FALSE;
                                    END IF;

                                    IF nvl(service_table(n).barcode, ' ') != ' '
                                    THEN
                                        IF barcode_row IS NULL
                                        THEN
                                            barcode_row := n;
                                        END IF;

                                        IF nvl(service_table(n)
                                               .labor_verb_skey,
                                               0) != nvl(service_table(barcode_row)
                                                         .labor_verb_skey,
                                                         0)
                                        THEN
                                            blaborverbdetail := FALSE;
                                        END IF;

                                        IF nvl(service_table(n)
                                               .component_skey,
                                               0) != nvl(service_table(barcode_row)
                                                         .component_skey,
                                                         0)
                                        THEN
                                            bcomponentdetail := FALSE;
                                        END IF;

                                        IF nvl(service_table(n).qgroup_skey,
                                               0) != nvl(service_table(barcode_row)
                                                         .qgroup_skey,
                                                         0)
                                        THEN
                                            bqualifierdetail := FALSE;
                                        END IF;

                                        ncount := ncount + 1;
                                    END IF;
                                END IF;
                            END LOOP;

                            IF ncount = 0
                            THEN
                                IF pkg_ultramate_common.sf_getcategorystring(service_table(current_row)
                                                                             .category_skey) =
                                   'CHASSIS TYPE'
                                THEN
                                    create_chassis_notes(current_row,
                                                         last_row);
                                    /* 03/26/2016 mm5095 => commented out to deal with too many of these errors - find out why erroring out
                                                                   ELSE
                                                                        dbms_output.put_line('N line nCount is null at: ' ||
                                                                                             service_barcode || ' ' ||
                                                                                             mfr_in || ' ' ||
                                                                                             service_in || ' ' ||
                                                                                             version_in || ' ' || service_table(current_row)
                                                                                             .unique_row_id);
                                    */
                                END IF;
                            ELSE
                                IF blaborverbset
                                   AND bcomponentset
                                THEN
                                    IF ncount = 1
                                    THEN
                                        IF nvl(service_table(current_row)
                                               .barcode,
                                               ' ') = ' '
                                        THEN
                                            -- 10/11/2004 mm5095 => added support for hidden lines
                                            -- 2007/02/09 mm5095 => removed arguments not used
                                            addlaborpart(getlabortext(barcode_row,
                                                                      TRUE),
                                                         current_row,
                                                         last_row,
                                                         d_code);
                                            --                  AddLaborPart(getLaborText(barcode_row,true),current_row,last_row,version_in,false,d_code);
                                            --                  AddLaborPart(getLaborText(barcode_row,true),current_row,last_row,version_in,false);
                                            -- 10/11/2004 mm5095 => added support for hidden lines
                                        ELSE
                                            -- 10/11/2004 mm5095 => added support for hidden lines
                                            -- 2007/02/09 mm5095 => removed arguments not used
                                            addlaborpart(getlabortext(current_row,
                                                                      TRUE),
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
                                        IF nvl(service_table(barcode_row)
                                               .detail_qgroup_skey,
                                               0) > 0
                                        THEN
                                            addlabordetail(barcode_row,
                                                           getqualifiernotestring(barcode_row,
                                                                                  current_row,
                                                                                  '1',
                                                                                  FALSE));
                                        ELSE
                                            addlabordetail(barcode_row,
                                                           getlabortext(barcode_row,
                                                                        TRUE));
                                        END IF;
                                    ELSE
                                        IF bqualifierdetail
                                        THEN
                                            -- 10/11/2004 mm5095 => added support for hidden lines
                                            addlaborpart(getlabortext(barcode_row,
                                                                      TRUE),
                                                         current_row,
                                                         last_row,
                                                         d_code);
                                            --                  AddLaborPart(getLaborText(barcode_row,true),current_row,last_row,version_in,false,d_code);
                                            -- 2007/02/09 mm5095 => removed arguments not used
                                            --                  AddLaborPart(getLaborText(barcode_row,true),current_row,last_row,version_in,false);
                                            -- 10/11/2004 mm5095 => added support for hidden lines
                                            npart_detail := npart;
                                            FOR n IN current_row .. last_row
                                            LOOP
                                                IF NOT
                                                    inlaborset(n,
                                                               current_row)
                                                THEN
                                                    current_row := n - 1;
                                                    EXIT;
                                                END IF;

                                                IF nvl(service_table(n)
                                                       .barcode,
                                                       ' ') != ' '
                                                THEN
                                                    addlabordetail(n, NULL);
                                                END IF;

                                                IF n = last_row
                                                THEN
                                                    current_row := last_row;
                                                    EXIT;
                                                END IF;
                                            END LOOP;
                                        ELSE
                                            -- labor verb and component same, qualifiers differ
                                            -- 10/11/2004 mm5095 => added support for hidden lines
                                            -- 2007/02/09 mm5095 => removed arguments not used
                                            addlaborpart(getlaborverbcomponent(current_row,
                                                                               TRUE),
                                                         current_row,
                                                         last_row,
                                                         d_code);
                                            --                  AddLaborPart(getLaborVerbComponent(current_row,true),current_row,last_row,version_in,false,d_code);
                                            -- 2007/02/09 mm5095 => removed arguments not used
                                            --                  AddLaborPart(getLaborVerbComponent(current_row,true),current_row,last_row,version_in,false);
                                            -- 10/11/2004 mm5095 => added support for hidden lines
                                            npart_detail := npart;
                                            FOR n IN current_row .. last_row
                                            LOOP
                                                IF NOT
                                                    inlaborset(n,
                                                               current_row)
                                                THEN
                                                    current_row := n - 1;
                                                    EXIT;
                                                END IF;

                                                IF nvl(service_table(n)
                                                       .barcode,
                                                       ' ') != ' '
                                                THEN
                                                    addlabordetail(n,
                                                                   pkg_ultramate_common.sf_getqualifierstring(service_table(n)
                                                                                                              .qgroup_skey,
                                                                                                              '1',
                                                                                                              FALSE));
                                                END IF;

                                                IF n = last_row
                                                THEN
                                                    current_row := last_row;
                                                    EXIT;
                                                END IF;
                                            END LOOP;
                                        END IF;
                                    END IF;
                                ELSIF blaborverbset
                                THEN
                                    -- 10/11/2004 mm5095 => added support for hidden lines
                                    -- 2007/02/09 mm5095 => removed arguments not used
                                    addlaborpart(getlaborverbcomponent(current_row,
                                                                       TRUE),
                                                 current_row,
                                                 last_row,
                                                 d_code);
                                    --              AddLaborPart(getLaborVerbComponent(current_row,true),current_row,last_row,version_in,false,d_code);
                                    -- 2007/02/09 mm5095 => removed arguments not used
                                    --              AddLaborPart(getLaborVerbComponent(current_row,true),current_row,last_row,version_in,false);
                                    -- 10/11/2004 mm5095 => added support for hidden lines
                                    npart_detail := npart;
                                    FOR n IN current_row .. last_row
                                    LOOP
                                        IF NOT inlaborset(n, current_row)
                                        THEN
                                            current_row := n - 1;
                                            EXIT;
                                        END IF;

                                        IF nvl(service_table(n).barcode,
                                               ' ') != ' '
                                        THEN
                                            addlabordetail(n,
                                                           getlabortext(n,
                                                                        nvl(service_table(n)
                                                                            .inline_note_skey,
                                                                            0) !=
                                                                        nvl(service_table(current_row)
                                                                            .inline_note_skey,
                                                                            0)));
                                        END IF;

                                        IF n = last_row
                                        THEN
                                            current_row := last_row;
                                            EXIT;
                                        END IF;
                                    END LOOP;
                                ELSE
                                    -- labor verb, component and/or qualifiers are different
                                    IF nvl(service_table(current_row)
                                           .barcode,
                                           ' ') = ' '
                                    THEN
                                        IF blaborverbdetail
                                           AND bcomponentdetail
                                           AND bqualifierdetail
                                        THEN
                                            barcode_row := NULL;
                                            FOR n IN current_row .. last_row
                                            LOOP
                                                IF NOT
                                                    inlaborset(n,
                                                               current_row)
                                                THEN
                                                    current_row := n - 1;
                                                    EXIT;
                                                END IF;

                                                -- 10/11/2004 mm5095 => added support for hidden lines
                                                d_code := (d_code + service_table(n)
                                                          .suppression_reason_code) -
                                                          bitand(d_code,
                                                                 service_table(n)
                                                                 .suppression_reason_code);
                                                -- 10/11/2004 mm5095 => added support for hidden lines
                                                IF nvl(service_table(n)
                                                       .barcode,
                                                       ' ') != ' '
                                                THEN
                                                    barcode_row := n;
                                                    EXIT;
                                                END IF;
                                            END LOOP;

                                            IF barcode_row IS NULL
                                            THEN
                                                dbms_output.put_line('Error, no barcode row found at: ' || service_table(current_row)
                                                                     .unique_row_id);
                                            ELSE
                                                IF nvl(service_table(current_row)
                                                       .labor_verb_skey,
                                                       0) !=
                                                   nvl(service_table(barcode_row)
                                                       .labor_verb_skey,
                                                       0)
                                                THEN
                                                    temp_text := getlabortext(barcode_row,
                                                                              TRUE);
                                                    IF substr(temp_text,
                                                              1,
                                                              3) = 'To '
                                                       OR
                                                       substr(temp_text,
                                                              1,
                                                              4) = 'For '
                                                       OR
                                                       substr(temp_text,
                                                              1,
                                                              4) = 'Aim '
                                                    THEN
                                                        -- 10/11/2004 mm5095 => added support for hidden lines
                                                        -- 2007/02/09 mm5095 => removed arguments not used
                                                        addlaborpart(getlabortext(current_row,
                                                                                  FALSE) || ' ' ||
                                                                     temp_text,
                                                                     current_row,
                                                                     last_row,
                                                                     d_code);
                                                        --                        AddLaborPart(getLaborText(current_row,false) || ' ' || temp_text, current_row, last_row,version_in,false,d_code);
                                                        -- 2007/02/09 mm5095 => removed arguments not used
                                                        d_code := 0;
                                                        --                        AddLaborPart(getLaborText(current_row,false) || ' ' || temp_text, current_row, last_row,version_in,false);
                                                        -- 10/11/2004 mm5095 => added support for hidden lines
                                                    ELSE
                                                        -- 10/11/2004 mm5095 => added support for hidden lines
                                                        -- 2007/02/09 mm5095 => removed arguments not used
                                                        addlaborpart(getlabortext(current_row,
                                                                                  FALSE) ||
                                                                     ' to ' ||
                                                                     temp_text,
                                                                     current_row,
                                                                     last_row,
                                                                     d_code);
                                                        --                        AddLaborPart(getLaborText(current_row,false) || ' to ' || temp_text, current_row, last_row,version_in,false,d_code);
                                                        -- 2007/02/09 mm5095 => removed arguments not used
                                                        d_code := 0;
                                                        --                        AddLaborPart(getLaborText(current_row,false) || ' to ' || temp_text, current_row, last_row,version_in,false);
                                                        -- 10/11/2004 mm5095 => added support for hidden lines
                                                    END IF;
                                                ELSE
                                                    -- 10/11/2004 mm5095 => added support for hidden lines
                                                    -- 2007/02/09 mm5095 => removed arguments not used
                                                    addlaborpart(getlabortext(barcode_row,
                                                                              TRUE),
                                                                 barcode_row,
                                                                 last_row,
                                                                 d_code);
                                                    --                      AddLaborPart(getLaborText(barcode_row,true),barcode_row,last_row,version_in,false,d_code);
                                                    -- 2007/02/09 mm5095 => removed arguments not used
                                                    d_code := 0;
                                                    --                      AddLaborPart(getLaborText(barcode_row,true),barcode_row,last_row,version_in,false);
                                                    -- 10/11/2004 mm5095 => added support for hidden lines
                                                END IF;
                                            END IF;
                                        ELSE
                                            -- 10/11/2004 mm5095 => added support for hidden lines
                                            -- 2007/02/09 mm5095 => removed arguments not used
                                            addlaborpart(getlabortext(current_row,
                                                                      TRUE),
                                                         current_row,
                                                         last_row,
                                                         d_code);
                                            --                  AddLaborPart(getLaborText(current_row,true),current_row,last_row,version_in,false,d_code);
                                            -- 2007/02/09 mm5095 => removed arguments not used
                                            d_code := 0;
                                            --                  AddLaborPart(getLaborText(current_row,true),current_row,last_row,version_in,false);
                                            -- 10/11/2004 mm5095 => added support for hidden lines
                                        END IF;
                                    ELSE
                                        -- 10/11/2004 mm5095 => added support for hidden lines
                                        -- 2007/02/09 mm5095 => removed arguments not used
                                        addlaborpart(getlabortext(current_row,
                                                                  TRUE),
                                                     current_row,
                                                     last_row,
                                                     d_code);
                                        --                AddLaborPart(getLaborText(current_row,true),current_row,last_row,version_in,false,d_code);
                                        -- 2007/02/09 mm5095 => removed arguments not used
                                        d_code := 0;
                                        --                AddLaborPart(getLaborText(current_row,true),current_row,last_row,version_in,false);
                                        -- 10/11/2004 mm5095 => added support for hidden lines
                                    END IF;

                                    npart_detail := npart;
                                    prefix_row   := NULL;
                                    FOR n IN current_row .. last_row
                                    LOOP
                                        IF NOT inlaborset(n, current_row)
                                        THEN
                                            current_row := n - 1;
                                            EXIT;
                                        END IF;

                                        -- 10/11/2004 mm5095 => added support for hidden lines
                                        d_code := (d_code + service_table(n)
                                                  .suppression_reason_code) -
                                                  bitand(d_code,
                                                         service_table(n)
                                                         .suppression_reason_code);
                                        -- 10/11/2004 mm5095 => added support for hidden lines
                                        IF nvl(service_table(n).barcode,
                                               ' ') != ' '
                                        THEN
                                            IF nvl(service_table(current_row)
                                                   .barcode,
                                                   ' ') = ' '
                                               AND
                                               nvl(service_table(n)
                                                   .labor_verb_skey,
                                                   0) = nvl(service_table(current_row)
                                                            .labor_verb_skey,
                                                            0)
                                               AND
                                               nvl(service_table(n)
                                                   .component_skey,
                                                   0) = nvl(service_table(current_row)
                                                            .component_skey,
                                                            0)
                                            THEN
                                                addlabordetail(n,
                                                               pkg_ultramate_common.sf_getqualifierstring(service_table(n)
                                                                                                          .qgroup_skey,
                                                                                                          '1',
                                                                                                          FALSE));
                                            ELSIF nvl(service_table(current_row)
                                                      .barcode,
                                                      ' ') = ' '
                                                  AND
                                                  nvl(service_table(n)
                                                      .labor_verb_skey,
                                                      0) = nvl(service_table(current_row)
                                                               .labor_verb_skey,
                                                               0)
                                            THEN
                                                addlabordetail(n,
                                                               getcomponentqualifier(n,
                                                                                     FALSE));
                                            ELSE
                                                IF (blaborverbdetail AND
                                                   bcomponentdetail)
                                                   OR prefix_row IS NULL
                                                   OR nvl(service_table(n)
                                                          .indent_level,
                                                          ' ') =
                                                   nvl(service_table(prefix_row)
                                                          .indent_level,
                                                          ' ')
                                                   OR (nvl(service_table(n)
                                                           .labor_verb_skey,
                                                           0) =
                                                   nvl(service_table(prefix_row)
                                                           .labor_verb_skey,
                                                           0))
                                                   OR (prefix_row =
                                                   current_row AND
                                                   nvl(service_table(current_row)
                                                           .barcode,
                                                           ' ') = ' ')
                                                THEN
                                                    addlabordetail(n,
                                                                   getlabortext(n,
                                                                                nvl(service_table(n)
                                                                                    .inline_note_skey,
                                                                                    0) !=
                                                                                nvl(service_table(current_row)
                                                                                    .inline_note_skey,
                                                                                    0)));
                                                ELSIF blaborverbdetail
                                                THEN
                                                    addlabordetail(n,
                                                                   getlabortext(n,
                                                                                nvl(service_table(n)
                                                                                    .inline_note_skey,
                                                                                    0) !=
                                                                                nvl(service_table(current_row)
                                                                                    .inline_note_skey,
                                                                                    0)));
                                                ELSE
                                                    temp_text := getlabortext(n,
                                                                              nvl(service_table(n)
                                                                                  .inline_note_skey,
                                                                                  0) !=
                                                                              nvl(service_table(current_row)
                                                                                  .inline_note_skey,
                                                                                  0));
                                                    IF nvl(service_table(n)
                                                           .indent_level,
                                                           ' ') >
                                                       nvl(service_table(prefix_row)
                                                           .indent_level,
                                                           ' ')
                                                    THEN
                                                        IF substr(temp_text,
                                                                  1,
                                                                  3) =
                                                           'To '
                                                           OR substr(temp_text,
                                                                     1,
                                                                     4) =
                                                           'For '
                                                           OR substr(temp_text,
                                                                     1,
                                                                     4) =
                                                           'Aim '
                                                        THEN
                                                            addlabordetail(n,
                                                                           getlabortext(prefix_row,
                                                                                        FALSE) || ' ' ||
                                                                           temp_text);
                                                        ELSE
                                                            pre_text := getlabortext(prefix_row,
                                                                                     FALSE);
                                                            IF length(pre_text ||
                                                                      ' to ' ||
                                                                      temp_text) > 61
                                                            THEN
                                                                addlabordetail(n,
                                                                               temp_text);
                                                            ELSE
                                                                addlabordetail(n,
                                                                               pre_text ||
                                                                               ' to ' ||
                                                                               temp_text);
                                                            END IF;
                                                        END IF;
                                                    ELSE
                                                        addlabordetail(n,
                                                                       temp_text);
                                                    END IF;
                                                END IF;
                                            END IF;
                                        ELSE
                                            prefix_row := n;
                                        END IF;

                                        IF n = last_row
                                        THEN
                                            current_row := last_row;
                                            EXIT;
                                        END IF;
                                    END LOOP;
                                END IF;
                            END IF;
                        ELSIF service_table(current_row).line_type = 'S'
                        THEN
                            glowerdate := nvl(service_table(current_row)
                                              .lower_effectivity_date,
                                              to_date('01/01/2099',
                                                      'MM/DD/YYYY'));
                            gupperdate := nvl(service_table(current_row)
                                              .upper_effectivity_date,
                                              to_date('01/01/2099',
                                                      'MM/DD/YYYY'));

                            IF current_row <
                               last_row
                               AND service_table(current_row + 1).line_type = 'S'
                               AND service_table(current_row).category_skey = service_table(current_row + 1)
                              .category_skey
                               AND service_table(current_row)
                              .subcategory_skey = service_table(current_row + 1)
                              .subcategory_skey
                               AND service_table(current_row)
                              .subcategory_qgroup_skey = 0
                            THEN
                                -- skip placeholder category/subcategory/qgroup = 0 when followed by same category/subcategory/qgroup != 0
                                NULL;
                            ELSE
                                addsection(current_row,
                                           pkg_ultramate_common.sf_getsubcategorytext(service_table(current_row)
                                                                                      .subcategory_skey,
                                                                                      service_table(current_row)
                                                                                      .subcategory_qgroup_skey),
                                           TRUE);
                                bdummysection := FALSE;
                            END IF;
                        END IF;
                    EXCEPTION
                        WHEN OTHERS THEN
                            dbms_output.put_line('ERROR: ' || mfr_in || ' ' ||
                                                 service_in || ' ' ||
                                                 version_in || ' ' || service_table(current_row)
                                                 .unique_row_id || ' ' ||
                                                 SQLERRM(SQLCODE));
                    END;

                    IF service_table(current_row).line_type != 'N'
                    THEN
                        labor_verb_skey  := 0;
                        component_skey   := 0;
                        qgroup_skey      := 0;
                        inline_note_skey := 0;
                    END IF;

                    IF service_table(current_row).line_type = 'I'
                    THEN
                        IF last_line_type = 'I'
                        THEN
                            bconsecutive_graphics := TRUE;
                        ELSE
                            bconsecutive_graphics := FALSE;
                        END IF;
                    END IF;

                    last_line_type := service_table(current_row).line_type;

                    IF current_row < last_row
                    THEN
                        current_row := current_row + 1;
                    ELSE
                        EXIT;
                    END IF;
                END LOOP;

                -- add point and delete entries into last detail table
                -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
                IF bcheckheadersequence
                THEN
                    header_sequence := pkg_ultramate_common.sf_get_max_header_sequence(vehicle_type_skey,
                                                                                       header_offset);
                ELSE
                    header_sequence := 0;
                END IF;
                -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
                FOR rec IN deleteandpoint_cur
                LOOP
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
                utl_file.fclose(header_fhandle);
                utl_file.fclose(section_fhandle);
                utl_file.fclose(part_fhandle);
                utl_file.fclose(detail_fhandle);

                -- 04/12/2006 mm5095 => add support for atg graphics UM 6.5
                --      if mfr_in != '006' then
                utl_file.fclose(graphic_fhandle);
                utl_file.fclose(hotspot_fhandle);

                utl_file.fclose(color_graphic_fhandle);
                utl_file.fclose(color_hotspot_fhandle);

                --      end if;
                -- 04/12/2006 mm5095 => add support for atg graphics UM 6.5

                utl_file.fclose(pnote_fhandle);
                utl_file.fclose(dtnote_fhandle);

                -- 04/21/2011 mm5095 => add support for mtd/htd
                IF NOT (CLASS = 'HTD' OR CLASS = 'MTD')
                THEN
                    -- 11/16/2004 mm5095 => added support for rr_vs_repair
                    rr_fhandle := utl_file.fopen(path,
                                                 'DR' || service_barcode ||
                                                 '.txt',
                                                 'w');

                    FOR rec IN rr_cur(mfr_in, service_in, version_in)
                    LOOP
                        utl_file.put_line(rr_fhandle,
                                          rec.rr_barcode || '|' ||
                                          rec.ri_barcode);

                        -- 01/13/2010 mm5095 => insert into table to support next gen
                        IF run_type = 'FULL'
                        THEN
                            IF rec.rr_barcode IS NOT NULL
                               AND rec.ri_barcode IS NOT NULL
                            THEN
                                BEGIN
                                    INSERT INTO um_data_dr
                                        (service,
                                         rr_barcode,
                                         ri_barcode)
                                    VALUES
                                        (service_barcode_in,
                                         rec.rr_barcode,
                                         rec.ri_barcode);
                                EXCEPTION
                                    WHEN OTHERS THEN
                                        dbms_output.put_line('Parse error inserting into um_data_dr');
                                END;
                            END IF;
                        END IF;

                    -- 01/13/2010 mm5095 => insert into table to support next gen

                    END LOOP;

                    utl_file.fclose(rr_fhandle);
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
                -- 11/16/2004 mm5095 => added support for rr_vs_repair
                -- 04/21/2011 mm5095 => add support for mtd/htd
                IF NOT (CLASS = 'HTD' OR CLASS = 'MTD')
                THEN
                    pkg_ultramate_common.sp_output_barcode_semaphore(path,
                                                                     service_barcode,
                                                                     'DR' ||
                                                                     service_barcode ||
                                                                     '.txt',
                                                                     'a');
                END IF;
                -- 04/21/2011 mm5095 => add support for mtd/htd
                -- 11/16/2004 mm5095 => added support for rr_vs_repair

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
  -- end commented block */ 

                --      end if;
                -- 04/12/2006 mm5095 => add support for atg graphics UM 6.5
            ELSE
                dbms_output.put_line('ERROR - no data for: ' || mfr_in || ' ' ||
                                     service_in || ' ' || version_in);
            END IF;
        END;

        PROCEDURE commonparse
        (
            mfr_in     VARCHAR2,
            service_in VARCHAR2,
            version_in VARCHAR2,
            mfr1       IN VARCHAR2,
            service1   IN VARCHAR2,
            mfr2       VARCHAR2,
            service2   VARCHAR2,
            run_type   VARCHAR2,
            path       VARCHAR2
        ) IS
            service_barcode VARCHAR2(6);

            vehicle_type INTEGER;

        BEGIN
            -- get service barcode
            service_barcode := sf_getservicebarcode(mfr_in, service_in);

            -- output semaphore
  /* -- File generation disabled: [barcode].txt semaphore initial write (FTP sunset)
            pkg_ultramate_common.sp_output_barcode_semaphore(path,
                                                             service_barcode,
                                                             NULL,
                                                             'w');
  -- end commented block */ 

            -- 04/21/2011 mm5095 => add support for mtd/htd
            vehicle_type := pkg_ultramate_common.sf_get_vehicle_type(service_barcode,
                                                                     mfr_in);

            /* 08/29/2016 mm5095 => not necessary for UM 7.1 international

                       -- 11/15/2012 mm5095 => prevent RVs from getting alternate parts to save disk space
                       IF NOT (mfr_in = '006' OR vehicle_type = 7 OR vehicle_type = 9 OR
                           mfr_in > '099')
                       THEN
                           --    if not (mfr_in = '006' or vehicle_type = 7 or vehicle_type = 9) then
                           -- 11/15/2012 mm5095 => prevent RVs from getting alternate parts to save disk space
                           --    if mfr_in != '006' then
                           -- 04/21/2011 mm5095 => add support for mtd/htd
                           pkg_ultramate_common.create_altpart(service_barcode,
                                                               mfr_in,
                                                               service_in,
                                                               version_in,
                                                               path,
                                                               run_type);
                       END IF;

            08/29/2016 mm5095 => not necessary for UM 7.1 international */

            -- 04/21/2011 mm5095 => add support for mtd/htd
            IF NOT (vehicle_type = 7 OR vehicle_type = 9)
            THEN
                -- 04/21/2011 mm5095 => add support for mtd/htd
                pkg_ultramate_common.create_overlap(service_barcode,
                                                    mfr_in,
                                                    service_in,
                                                    version_in,
                                                    mfr1,
                                                    service1,
                                                    mfr2,
                                                    service2,
                                                    run_type,
                                                    path);

                pkg_ultramate_common.create_matrix(service_barcode,
                                                   mfr_in,
                                                   service_in,
                                                   version_in,
                                                   run_type,
                                                   path);
                -- 04/21/2011 mm5095 => add support for mtd/htd
            END IF;
            -- 04/21/2011 mm5095 => add support for mtd/htd

            -- 2008/12/31 PAG - Moved create_notes into PKG_ULTRAMATE_COMMON and
            -- combined create_notes2 logic in same package. Logic will be based on
            -- run_type and parallel number.
            pkg_ultramate_common.create_notes(service_barcode,
                                              mfr_in,
                                              service_in,
                                              version_in,
                                              run_type,
                                              path,
                                              gparallelnumber);
            --if gParallelNumber = '1' then
            --  create_notes(service_barcode, mfr_in, service_in, version_in);
            --elsif gParallelNumber = '2' then
            --  create_notes2(service_barcode, mfr_in, service_in, version_in);
            --end if;

            -- 04/21/2011 mm5095 => add support for mtd/htd
            IF NOT (vehicle_type = 7 OR vehicle_type = 9)
            THEN
                -- 04/21/2011 mm5095 => add support for mtd/htd
                pkg_ultramate_common.create_options(service_barcode,
                                                    mfr_in,
                                                    service_in,
                                                    version_in,
                                                    path,
                                                    run_type);
                -- 04/21/2011 mm5095 => add support for mtd/htd
            END IF;
            -- 04/21/2011 mm5095 => add support for mtd/htd

            -- 07/12/04 mm5095 => added support for hidden lines
            -- retrieve product id
            OPEN product_cur(mfr_in, service_in, version_in);
            FETCH product_cur
                INTO product_rec;
            CLOSE product_cur;

            create_main(service_barcode, mfr_in, service_in, version_in);

            -- update extract date for restart
            UPDATE /*+ um_extract_update */ um_extract
               SET extract_date = SYSDATE
             WHERE mfr_number = mfr_in
               AND service_number = service_in
               AND version_type = version_in;

            -- retrieve version number and checkout date
            OPEN version_cur(mfr_in, service_in, version_in);
            FETCH version_cur
                INTO version_rec;
            CLOSE version_cur;

            -- update product history
            INSERT /*+ product_history_insert */
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
                (mfr_in,
                 service_in,
                 version_in,
                 version_rec.version_number,
                 version_rec.checkout_date,
                 product_rec.product_code,
                 SYSDATE,
                 USER,
                 SYSDATE);

            -- if WP, clear post checkin process date in version
            IF version_in = 'WP'
            THEN
                UPDATE /*+ version_update */ version
                   SET post_checkin_process_date = NULL
                 WHERE mfr_number = mfr_in
                   AND service_number = service_in
                   AND version_type = version_in;
            END IF;

            COMMIT;

  /* -- File generation disabled: zz[barcode].txt creation (FTP sunset)
            out_fhandle := utl_file.fopen(path,
                                          'zz' || service_barcode || '.txt',
                                          'w');
            utl_file.fclose(out_fhandle);
  -- end commented block */ 

            -- ftp to NT
            -- 01/25/2007 mm5095 => added Oracle directory support
  /* -- FTP send disabled: [barcode].txt sp_ftp_command (FTP sunset)
            pkg_ultramate_common.sp_ftp_command(service_barcode || '.txt',
                                                ftp_path,
                                                my_ftp_dest_path,
                                                my_ftp_machine_name,
                                                ftp_on_flag,
                                                ftp_ret_code);
  -- end commented block */ 
            --    FTP_COMMAND(service_barcode || '.txt', path, full_flag);
            -- 01/25/2007 mm5095 => added Oracle directory support

        EXCEPTION
            WHEN utl_file.invalid_path THEN
                utl_file.fclose_all;
                raise_application_error(-20100,
                                        vvc2_procedure_name ||
                                        ': INVALID PATH');
            WHEN utl_file.invalid_mode THEN
                utl_file.fclose_all;
                raise_application_error(-20101,
                                        vvc2_procedure_name ||
                                        ': INVALID MODE');
            WHEN utl_file.invalid_operation THEN
                utl_file.fclose_all;
                raise_application_error(-20102,
                                        vvc2_procedure_name ||
                                        ': INVALID OPERATION');
            WHEN utl_file.invalid_filehandle THEN
                utl_file.fclose_all;
                raise_application_error(-20103,
                                        vvc2_procedure_name ||
                                        ': INVALID FILEHANDLE');
            WHEN utl_file.write_error THEN
                utl_file.fclose_all;
                raise_application_error(-20104,
                                        vvc2_procedure_name ||
                                        ': WRITE ERROR');
            WHEN utl_file.read_error THEN
                utl_file.fclose_all;
                raise_application_error(-20105,
                                        vvc2_procedure_name ||
                                        ': READ ERROR');
            WHEN utl_file.internal_error THEN
                utl_file.fclose_all;
                raise_application_error(-20106,
                                        vvc2_procedure_name ||
                                        ': INTERNAL ERROR');
                --    WHEN OTHERS THEN
            --      UTL_FILE.FCLOSE_ALL;
            --      RAISE_APPLICATION_ERROR(-20107,vvc2_procedure_name || ': UNKNOWN ERROR');
        END;

        -- MAIN ROUTINE
    BEGIN
        vvc2_procedure_name := 'main loop';

        -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
        pkg_ultramate_common.sp_get_header_offset(header_offset,
                                                  ceg_offset);
        -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5

        vvc2_procedure_name := 'delete from tmp_um_graphic';
        IF gparallelnumber = '1'
        THEN
            -- 2012/10/30 mm5095 => bug fix to prevent segment rollback time out
            last_service_row := 0;
            FOR s_rec IN service_cur
            LOOP
                last_service_row := last_service_row + 1;
                service_loop_table(last_service_row) := s_rec;
            END LOOP;

            FOR n IN 1 .. last_service_row
            LOOP
                DELETE /*+ tmp_um_graphic_delete */
                FROM tmp_um_graphic;
                gcountryabbr    := service_loop_table(n).country_abbr;
                service_barcode := sf_getservicebarcode(service_loop_table(n)
                                                        .mfr_number,
                                                        service_loop_table(n)
                                                        .service_number);
                commonparse(service_loop_table(n).mfr_number,
                            service_loop_table(n).service_number,
                            service_loop_table(n).version_type,
                            service_loop_table(n).mfr1,
                            service_loop_table(n).service1,
                            service_loop_table(n).mfr2,
                            service_loop_table(n).service2,
                            run_type,
                            path);

            --      delete /*+ tmp_um_graphic_delete */ from tmp_um_graphic;
            --      gCountryAbbr := s_rec.country_abbr;
            --      service_barcode := sf_getServiceBarcode(s_rec.mfr_number, s_rec.service_number);
            --      CommonParse(s_rec.mfr_number, s_rec.service_number, s_rec.version_type,
            --                  s_rec.mfr1, s_rec.service1, s_rec.mfr2, s_rec.service2, run_type, path);
            END LOOP;
            -- 2012/10/30 mm5095 => bug fix to prevent segment rollback time out
        ELSIF gparallelnumber = '2'
        THEN
            -- 2012/10/30 mm5095 => bug fix to prevent segment rollback time out
            last_service2_row := 0;
            FOR s_rec IN service_cur2
            LOOP
                last_service2_row := last_service2_row + 1;
                service_loop2_table(last_service2_row) := s_rec;
            END LOOP;

            FOR n IN 1 .. last_service2_row
            LOOP
                DELETE /*+ tmp_um_graphic_delete */
                FROM tmp_um_graphic;
                gcountryabbr    := service_loop2_table(n).country_abbr;
                service_barcode := sf_getservicebarcode(service_loop2_table(n)
                                                        .mfr_number,
                                                        service_loop2_table(n)
                                                        .service_number);
                commonparse(service_loop2_table(n).mfr_number,
                            service_loop2_table(n).service_number,
                            service_loop2_table(n).version_type,
                            service_loop2_table(n).mfr1,
                            service_loop2_table(n).service1,
                            service_loop2_table(n).mfr2,
                            service_loop2_table(n).service2,
                            run_type,
                            path);
                -- 2012/10/30 mm5095 => bug fix to prevent segment rollback time out

            --     delete /*+ tmp_um_graphic_delete */ from tmp_um_graphic;
            --      gCountryAbbr := s_rec.country_abbr;
            --      service_barcode := sf_getServiceBarcode(s_rec.mfr_number, s_rec.service_number);
            --      CommonParse(s_rec.mfr_number, s_rec.service_number, s_rec.version_type,
            --                  s_rec.mfr1, s_rec.service1, s_rec.mfr2, s_rec.service2, run_type, path);
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            utl_file.fclose_all;
            dbms_output.put_line('SQL Error: ' || SQLCODE || '  ' ||
                                 SQLERRM);
            raise_application_error(-20107,
                                    'UNKNOWN ERROR IN ' ||
                                    vvc2_procedure_name);
    END;

    ---------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------
    --                                          MAIN PROCESSING BLOCK FOR ULTRAMATE_BUILD                              --
    ---------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------
    -- 01/25/2007 mm5095 => added Oracle directory support
    PROCEDURE ultramate_parse
    (
        run_type         VARCHAR2,
        unix_full_dir    VARCHAR2,
        unix_mini_dir    VARCHAR2,
        ftp_machine_name VARCHAR2,
        ftp_dest_path    VARCHAR2,
        parallel_run     CHAR
    )
    --PROCEDURE ULTRAMATE_PARSE(parm_path varchar2, run_type varchar2, parm_file varchar2, edsys_path varchar2, version varchar2, restart_flag char,
        --ftp_machine_name varchar2, ftp_dest_path varchar2, parallel_run char)
        -- 01/25/2007 mm5095 => added Oracle directory support
     IS
        my_edsys_path VARCHAR2(100);
        edsys_path    VARCHAR2(100);
        -- 2007/02/09 mm5095 => not used
        --  full_flag char(1);
        --  n_services integer;
        -- 2007/02/09 mm5095 => not used
    BEGIN
        dbms_output.enable(1000000);

        my_ftp_machine_name := ftp_machine_name;
        my_ftp_dest_path    := ftp_dest_path;
        gparallelnumber     := parallel_run;

        -- 10/24/2006 mm5095 => added support for special material qualifiers
        sp_populatespecialmaterialtbl;
        -- 10/24/2006 mm5095 => added support for special material qualifiers

        IF run_type = 'FULL'
        THEN
            -- 2007/02/09 mm5095 => not used
            --    full_flag := 'T';
            -- 2007/02/09 mm5095 => not used
            -- 10/20/08 mm5095 => bell and howell no longer supported
            --    bell_howell_flag := true;
            -- 10/20/08 mm5095 => bell and howell no longer supported
            -- 01/25/2007 mm5095 => added Oracle directory support
            my_edsys_path := unix_full_dir;
            --    edsys_path := edsys_dir || '/um_full';
            -- 01/25/2007 mm5095 => added Oracle directory support
        ELSE
            -- 2007/02/09 mm5095 => not used
            --    full_flag := 'F';
            -- 2007/02/09 mm5095 => not used
            -- 10/20/08 mm5095 => bell and howell no longer supported
            --    bell_howell_flag := false;
            -- 10/20/08 mm5095 => bell and howell no longer supported
            -- 01/25/2007 mm5095 => added Oracle directory support
            my_edsys_path := unix_mini_dir;
            --    edsys_path := edsys_dir || '/um_mini';
            -- 01/25/2007 mm5095 => added Oracle directory support
        END IF;

        -- 2008/12/31 PAG => edsys_path is used to determine ftp_on_flag value (based on whether this is running in prod versus mdev).
        -- 01/25/2007 mm5095 => added Oracle directory support
        dbms_output.put_line(' ');
        edsys_path := sf_getdirectorypath(my_edsys_path);
        IF edsys_path IS NULL
        THEN
            dbms_output.put_line('Invalid directory path. ftp_on_flag set to false.');
            ftp_on_flag := FALSE;
        ELSIF substr(edsys_path, 2, 4) = 'prod'
        THEN
            dbms_output.put_line('Running in prod environment. ftp_on_flag set to true.');
            ftp_on_flag := TRUE;
        ELSE
            dbms_output.put_line('Running in mdev environment. ftp_on_flag set to false.');
            ftp_on_flag := FALSE;
        END IF;
        -- 01/25/2007 mm5095 => added Oracle directory support
        -- 2008/12/31 PAG => edsys_path is used to determine ftp_on_flag value

        -----------------------------------------
        -- process list of services
        -----------------------------------------

        -- if full build, open bell and howell UTL file
        -- 10/20/08 mm5095 => bell and howell no longer supported
        --  if bell_howell_flag then
        --    if restart_flag = 'T' then
        --      bell_howell_fhandle := UTL_FILE.FOPEN(my_edsys_path, 'ceg_belhow_' || gParallelNumber || '.ext','a');
        --    else
        --      bell_howell_fhandle := UTL_FILE.FOPEN(my_edsys_path, 'ceg_belhow_' || gParallelNumber || '.ext','w');
        --    end if;
        --  end if;
        -- 10/20/08 mm5095 => bell and howell no longer supported

        -- 01/25/2007 mm5095 => added Oracle directory support
        BEGIN
            ext_service(my_edsys_path, edsys_path, run_type);
        END;
        --  EXT_SERVICE(my_edsys_path, full_flag, restart_flag);
        -- 01/25/2007 mm5095 => added Oracle directory support

        -- 10/20/08 mm5095 => bell and howell no longer supported
        --  if bell_howell_flag and UTL_FILE.IS_OPEN(bell_howell_fhandle) then
        --    UTL_FILE.FCLOSE(bell_howell_fhandle);
        --  end if;
        -- 10/20/08 mm5095 => bell and howell no longer supported

    END;

END;
/
