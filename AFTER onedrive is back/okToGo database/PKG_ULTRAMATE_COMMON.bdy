CREATE OR REPLACE PACKAGE BODY EXT."PKG_ULTRAMATE_COMMON" IS
    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
    *   PL/SQL name:     PKG_ULTRAMATE_COMMON                                         *
    *   Author:          pg2697                                                       *
    *   Description:     Common Functions and Procedures called by Ultramate          *
    *                    Full and Mini Programs.                                      *
    *   Modifications:                                                                *
    *   2008/12/31 PAG - Pulled code from PKG_ULTRAMATE_BUILD, PREPARSE, and PARSE    *
    *                    to create this package, allowing for differences between     *
    *                    FULL and MINI logic. Added logic to support Marine Engines   *
    *                    and Service Concatenation.                                   *
    *                  - Renamed sp_output_semaphore to sp_output_zzglobal_done_files.*
    *                  - Renamed sp_update_semaphore to sp_update_globaltxt_semaphore.*
    *   2009/06/04 mm5095/pg2697 - corrected ATG/CEG overlap issue where services     *
    *                    having mfr's 001 - 005 weren't preceding the ATG overlap in  *
    *                    sort order, as desired (MFR overlap first, then ATG overlap).*
    *   2012/08  mm5095- added code to support NSF certified MAPP parts               *
    *   2014/11  jl101765 - Added hints to altpart_cur cursor in create_altpart       *
    *                       procedure to improve performance                          *
    *   2015/08  jl101765 - Modified sp_update_mapp_supplier_xref to support NextGen  *
    *                       MAPPP extract                                             *
    *   2018/05  jl101765 - Modified dynamic price extract to use new view instead of *
    *                       hardcoding values                                         *
    *   2018/04 pg2697 - Add extract of data from NRP_Add_To to set_matrix_cur and    *
    *                 create_matrix. Also, clone of AirBag Add_To rec 6's to 7's for  *
    *                 NextGen (um_data_df).                                           *
    *   2020/04/05 pb0690 - MCE Mini changes/additions                                *
    *   2020/08    pb0690 - Add PRTC For Specialty                                    *
    *   2020/04/17 pg2697 - Added code associated to Specialty Vehicles (CHT/CMT)     *
    *   2020/09/23 pg2697 - Added more code associated to Specialty Vehicles (CHT/CMT)*
    *   2020/09/30 rs7649 - Replaced ref.dat with Oracle tables (ref_sheet_category   *
    *                       ref_sheet_category_detail                                 *
    *   2023/03/09 rs7649 - Added relationship 9 to Matrix table                      *
    *   2026/04    rj132422 - FTP sunset: disabled file generation for OTP006       *
    * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

    /* ----------------------------------------------------------------------------- sf_getMixedCase */
    -- 05/09/2008 mm5095 => added support for mixed case text
    FUNCTION sf_getmixedcase(text_in VARCHAR2) RETURN VARCHAR2 IS
        npos             INTEGER;
        npos2            INTEGER;
        text             VARCHAR2(1000);
        extracted_word   VARCHAR2(1000);
        replacement_word VARCHAR2(1000);
        word_counter     INTEGER := 1;

    BEGIN

        IF text_in IS NULL
        THEN
            RETURN NULL;
        END IF;

        word_counter := 1;
        text         := initcap(text_in);

        LOOP
            npos := regexp_instr(text, '[^ ]+', 1, word_counter);
            EXIT WHEN npos = 0;
            word_counter := word_counter + 1;
            npos2        := regexp_instr(text, '[^ ]+', 1, word_counter);
            EXIT WHEN npos2 = 0;
            extracted_word := substr(text, npos, npos2 - npos - 1);
            BEGIN
                SELECT /*+ retain_caps */
                 dest_descr
                  INTO replacement_word
                  FROM retain_caps
                 WHERE source_descr = TRIM(extracted_word);
                IF npos = 1
                THEN
                    text := replacement_word ||
                            substr(text, npos + length(extracted_word));
                ELSE
                    text := substr(text, 1, npos - 1) || replacement_word ||
                            substr(text, npos + length(extracted_word));
                END IF;
            EXCEPTION
                WHEN no_data_found THEN
                    NULL; --nothing to be done
                WHEN OTHERS THEN
                    EXIT;
                    NULL; -- todo:
            END;
            npos := npos2;
        END LOOP;

        extracted_word := TRIM(substr(text, npos));
        BEGIN
            SELECT /*+ retain_caps2 */
             dest_descr
              INTO replacement_word
              FROM retain_caps
             WHERE source_descr = extracted_word;

            IF npos = 1
            THEN
                text := replacement_word ||
                        substr(text, npos + length(extracted_word));
            ELSE
                text := substr(text, 1, npos - 1) || replacement_word ||
                        substr(text, npos + length(extracted_word));
            END IF;
        EXCEPTION
            WHEN no_data_found THEN
                NULL; --nothing to be done
            WHEN OTHERS THEN
                NULL; -- todo:
        END;

        RETURN text;
    END;

    /* ----------------------------------------------------------------------------- sf_getMixedCaseCategory */
    FUNCTION sf_getmixedcasecategory(category_in VARCHAR2) RETURN VARCHAR2 IS
        vvc2_return category_description.mixed_case_category_name%TYPE;
    BEGIN
        SELECT /*+ sf_getMixedCaseCategory.category_description_select */
         a.mixed_case_category_name
          INTO vvc2_return
          FROM category_description a
         WHERE a.category_name = category_in;
        RETURN vvc2_return;
    EXCEPTION
        WHEN OTHERS THEN
            vvc2_return := sf_getmixedcase(category_in);

            BEGIN
                INSERT /*+ sf_getMixedCaseCategory.category_description_insert */
                INTO category_description
                    (category_name,
                     mixed_case_category_name)
                VALUES
                    (category_in,
                     vvc2_return);
            EXCEPTION
                WHEN OTHERS THEN
                    NULL; --todo: error handling?
            END;
            RETURN vvc2_return;
    END;

    /* ----------------------------------------------------------------------------- sf_getMixedCaseSubcategory */
    FUNCTION sf_getmixedcasesubcategory(subcat_in VARCHAR2) RETURN VARCHAR2 IS
        vvc2_return subcat_description.mixed_case_subcat_name%TYPE;
    BEGIN
        SELECT /*+ sf_getMixedCaseSubcategory.subcat_description_select */
         a.mixed_case_subcat_name
          INTO vvc2_return
          FROM subcat_description a
         WHERE a.subcat_name = subcat_in;
        RETURN vvc2_return;
    EXCEPTION
        WHEN OTHERS THEN
            vvc2_return := sf_getmixedcase(subcat_in);

            BEGIN
                INSERT /*+ sf_getMixedCaseSubcategory.subcat_description_insert */
                INTO subcat_description
                    (subcat_name,
                     mixed_case_subcat_name)
                VALUES
                    (subcat_in,
                     vvc2_return);
            EXCEPTION
                WHEN OTHERS THEN
                    NULL; --todo: error handling?
            END;
            RETURN vvc2_return;
    END;

    /* ----------------------------------------------------------------------------- sf_getMixedCasePRTC */
    FUNCTION sf_getmixedcaseprtc
    (
        skey_in NUMBER,
        prtc_in VARCHAR2
    ) RETURN VARCHAR2 IS
        vvc2_return prtc_description.mixed_case_descr%TYPE;
    BEGIN
        -- 04/27/2017 mm5095 => removed dependency on empty component_category_name table
        /*        BEGIN
                    SELECT
                     a.description
                      INTO vvc2_return
                      FROM component_category_name a
                     WHERE a.component_category_skey = skey_in;
                    RETURN vvc2_return;
                EXCEPTION
                    WHEN OTHERS THEN
        */
        -- 04/27/2017 mm5095 => removed dependency on empty component_category_name table
        BEGIN
            SELECT /*+ sf_getMixedCasePRTC.prtc_description_Select */
             a.mixed_case_descr
              INTO vvc2_return
              FROM prtc_description a
             WHERE a.description = prtc_in;
            RETURN vvc2_return;
        EXCEPTION
            WHEN OTHERS THEN
                vvc2_return := sf_getmixedcase(prtc_in);

                BEGIN
                    INSERT /*+ sf_getMixedCasePRTC.prtc_description_Insert */
                    INTO prtc_description
                        (description,
                         mixed_case_descr)
                    VALUES
                        (prtc_in,
                         vvc2_return);
                EXCEPTION
                    WHEN OTHERS THEN
                        NULL; --todo: error handling?
                END;
                RETURN vvc2_return;
        END;
        -- 04/27/2017 mm5095 => removed dependency on empty component_category_name table
        --        END;
        -- 04/27/2017 mm5095 => removed dependency on empty component_category_name table
    END;
    -- 05/09/2008 mm5095 => added support for mixed case text

    /* ----------------------------------------------------------------------------- sf_getSpecialQualifier */
    FUNCTION sf_getcategorystring(skey_in NUMBER) RETURN VARCHAR2 IS
        vvc2_return VARCHAR2(80);
    BEGIN
        SELECT /*+ sf_getCategoryString.category_select */
         category_name
          INTO vvc2_return
          FROM category
         WHERE category_skey = skey_in;
        RETURN vvc2_return;
    EXCEPTION
        WHEN no_data_found THEN
            RETURN vvc2_return;
    END;

    /* ----------------------------------------------------------------------------- sf_getComponentString */
    FUNCTION sf_getcomponentstring(skey_in NUMBER) RETURN VARCHAR2 IS
        vvc2_return VARCHAR2(80);
    BEGIN
        SELECT /*+ sf_getComponentString.component_select */
         publish_component_name
          INTO vvc2_return
          FROM component
         WHERE component_skey = skey_in;
        RETURN vvc2_return;
    EXCEPTION
        WHEN no_data_found THEN
            RETURN vvc2_return;
    END;

    /* ----------------------------------------------------------------------------- sf_getlabortime */
    FUNCTION sf_getlabortime(skey_in NUMBER) RETURN NUMBER IS
        vn_return NUMBER(5, 2) := 0;

        CURSOR c1_cur IS
            SELECT /*+ sf_getlabortime.c1_cur */
             ceg_labor_time
              FROM labor_operation
             WHERE labor_operation_skey = skey_in;
    BEGIN
        OPEN c1_cur;
        FETCH c1_cur
            INTO vn_return;
        CLOSE c1_cur;
        RETURN vn_return;
    END;

    /* ----------------------------------------------------------------------------- sf_getLaborVerbString */
    FUNCTION sf_getlaborverbstring(skey_in NUMBER) RETURN VARCHAR2 IS
        vvc2_return VARCHAR2(80);
    BEGIN
        SELECT /*+ sf_getLaborVerbString.labor_verb_select */
         labor_verb
          INTO vvc2_return
          FROM labor_verb
         WHERE labor_verb_skey = skey_in;
        RETURN vvc2_return;
    EXCEPTION
        WHEN no_data_found THEN
            RETURN vvc2_return;
    END;

    /* ----------------------------------------------------------------------------- sf_getNote_by_Skey */
    FUNCTION sf_getnote_by_skey(note_skey IN NUMBER) RETURN VARCHAR2 IS
        CURSOR note_cur(skey_in NUMBER) IS
            SELECT /*+ sf_getNote_by_Skey.note_cur */
             note_text
              FROM note
             WHERE note_skey = skey_in;

        vvc2_return VARCHAR2(1000);
    BEGIN
        OPEN note_cur(note_skey);
        FETCH note_cur
            INTO vvc2_return;
        IF note_cur%FOUND
        THEN
            IF substr(vvc2_return, 1, 1) != '-'
            THEN
                vvc2_return := ' ' || vvc2_return;
            END IF;
        END IF;
        CLOSE note_cur;

        RETURN vvc2_return;
    END;

    /* ----------------------------------------------------------------------------- sf_getQualifierString */
    FUNCTION sf_getqualifierstring
    (
        skey_in   NUMBER,
        indent_in VARCHAR2,
        bpartflag BOOLEAN
    ) RETURN VARCHAR2 IS
        local_indent VARCHAR2(2);

        CURSOR qualifier_list IS
            SELECT /*+ sf_getQualifierString.qualifier_list_cur */
             b.qualifier_name qualifier_name,
             qualifier_type_skey,
             a.sequence_number,
             a.indent_level
              FROM qgroup_qualifier a,
                   qualifier        b
             WHERE (a.qgroup_skey = skey_in)
               AND (a.qualifier_skey = b.qualifier_skey)
               AND a.indent_level >= local_indent
             ORDER BY a.indent_level,
                      a.sequence_number;

        CURSOR qual_type_cur IS
            SELECT /*+ sf_getQualifierString.qual_type_cur */
             qualifier_type_skey
              FROM qualifier_type
             WHERE description IN
                   ('Year',
                    'Multiple Qualifiers',
                    'Not Categorized',
                    'Date/Chassis/Engine/VIN Breaks');

        vvc2_temp             VARCHAR2(80);
        vvc2_qualifier_string VARCHAR2(240);
        last_indent_level     VARCHAR2(2);
        -- 2007/02/09 mm5095 => not used
        --    npos number;
        -- 2007/02/09 mm5095 => not used
    BEGIN

        IF indent_in = '0'
        THEN
            local_indent := '1';
        ELSE
            local_indent := indent_in;
        END IF;

        FOR rec IN qualifier_list
        LOOP
            vvc2_temp := rec.qualifier_name;
            IF NOT bpartflag
            THEN
                FOR rec2 IN qual_type_cur
                LOOP
                    IF rec.qualifier_type_skey = rec2.qualifier_type_skey
                    THEN
                        vvc2_temp := pkg_ultramate_common.sf_stripdate(rec.qualifier_name);
                        EXIT;
                    END IF;
                END LOOP;
            END IF;

            IF vvc2_temp IS NOT NULL
            THEN
                IF vvc2_qualifier_string IS NULL
                THEN
                    vvc2_qualifier_string := vvc2_temp;
                ELSIF rec.indent_level = last_indent_level
                THEN
                    IF substr(rec.qualifier_name, 1, 2) IN ('w/', 'W/')
                       OR substr(rec.qualifier_name, 1, 1) = '('
                       OR substr(vvc2_qualifier_string,
                                 length(vvc2_qualifier_string),
                                 1) = '('
                       OR
                       (substr(vvc2_qualifier_string,
                               length(vvc2_qualifier_string),
                               1) = ')' AND rec.qualifier_name = 'Model')
                    THEN
                        vvc2_qualifier_string := vvc2_qualifier_string || ' ' ||
                                                 vvc2_temp;
                    ELSE
                        vvc2_qualifier_string := vvc2_qualifier_string || ', ' ||
                                                 vvc2_temp;
                    END IF;
                ELSE
                    vvc2_qualifier_string := vvc2_qualifier_string || ' ' ||
                                             vvc2_temp;
                END IF;
            END IF;
            last_indent_level := rec.indent_level;
        END LOOP;

        RETURN ltrim(rtrim(vvc2_qualifier_string));
    END;

    /* ----------------------------------------------------------------------------- sf_getReverseString */
    FUNCTION sf_getreversestring(text_in IN VARCHAR2) RETURN VARCHAR2 IS
        vvc2_return VARCHAR2(80);
        npos        NUMBER;
        npos2       NUMBER;
    BEGIN

        vvc2_return := text_in;

        npos  := instr(text_in, ',');
        npos2 := instr(text_in, '(');

        IF npos > 0
        THEN
            IF npos2 > 0
            THEN
                IF npos2 > npos
                THEN
                    vvc2_return := ltrim(substr(text_in,
                                                npos + 1,
                                                npos2 - npos - 2)) || ' ' ||
                                   rtrim(substr(text_in, 1, npos - 1)) || ' ' ||
                                   rtrim(substr(text_in, npos2));
                ELSE
                    vvc2_return := ltrim(substr(text_in, npos + 1)) || ' ' ||
                                   rtrim(substr(text_in, 1, npos - 1));
                END IF;
            ELSE
                IF substr(text_in, npos + 1, 3) = ' at'
                THEN
                    vvc2_return := substr(text_in, 1, npos - 1) ||
                                   substr(text_in, npos + 1);
                ELSE
                    vvc2_return := ltrim(substr(text_in, npos + 1)) || ' ' ||
                                   rtrim(substr(text_in, 1, npos - 1));
                END IF;
            END IF;
        END IF;

        IF substr(vvc2_return, 1, 6) = 'Right '
        THEN
            vvc2_return := substr(vvc2_return, 7) || ' Right';
        ELSIF substr(vvc2_return, 1, 5) = 'Left '
        THEN
            vvc2_return := substr(vvc2_return, 6) || ' Left';
        END IF;

        RETURN vvc2_return;
    END;

    /* ----------------------------------------------------------------------------- sf_getServiceBarcode */
    FUNCTION sf_getservicebarcode
    (
        mfr_in     VARCHAR2,
        service_in VARCHAR2
    ) RETURN VARCHAR2 IS
        vvc2_return VARCHAR2(6) := NULL;
        CURSOR service_cur IS
            SELECT /*+ sf_getServiceBarcode.service_cur */
             barcode
              FROM service
             WHERE mfr_number = mfr_in
               AND service_number = service_in;

    BEGIN
        OPEN service_cur;
        FETCH service_cur
            INTO vvc2_return;
        IF service_cur%FOUND
        THEN
            vvc2_return := '9' || vvc2_return;
        END IF;
        CLOSE service_cur;
        RETURN vvc2_return;
    END;

    /* ----------------------------------------------------------------------------- sf_getSubcategoryText */
    FUNCTION sf_getsubcategorytext
    (
        category_skey IN NUMBER,
        qgroup_skey   IN NUMBER
    ) RETURN VARCHAR2 IS
        vvc2_return VARCHAR2(160);
    BEGIN
        vvc2_return := pkg_ultramate_common.sf_getcategorystring(category_skey);
        IF vvc2_return = '<Blank>'
        THEN
            vvc2_return := pkg_authoring.buildqualifierstring(qgroup_skey,
                                                              'HEADER');
        ELSIF qgroup_skey > 0
        THEN
            vvc2_return := vvc2_return || ' ' ||
                           pkg_authoring.buildqualifierstring(qgroup_skey,
                                                              'HEADER');
        END IF;

        RETURN REPLACE(vvc2_return, '^', ' ');
    END;

    /* ----------------------------------------------------------------------------- sf_getSmartPRTC1 */
    FUNCTION sf_getsmartprtc1
    (
        prtc_in            IN VARCHAR2,
        clearcoat_maj_flag IN CHAR,
        clearcoat_min_flag IN CHAR
    ) RETURN NUMBER IS
        smartprtc1 NUMBER := 0;
        p1         CHAR := substr(prtc_in, 1, 1);
        p2         CHAR := substr(prtc_in, 2, 1);
        p3         CHAR := substr(prtc_in, 3, 1);
        s1         CHAR := substr(prtc_in, 8, 1);
        s2         CHAR := substr(prtc_in, 9, 1);
        s3         CHAR := substr(prtc_in, 10, 1);
        np1        NUMBER;
        np2        NUMBER;
        np3        NUMBER;
        ns1        NUMBER;
        ns2        NUMBER;
        ns3        NUMBER;
        noccur     NUMBER;
        nref_min   NUMBER := 0;
        nref_maj   NUMBER := 0;

        FUNCTION getprefixvalue(p_in IN CHAR) RETURN NUMBER IS
            vn_return NUMBER := 0;
        BEGIN
            IF NOT (p_in = '*' OR p_in BETWEEN '0' AND '9')
            THEN
                IF p_in = 'A'
                THEN
                    vn_return := 25;
                ELSIF p_in = 'B'
                THEN
                    vn_return := 1;
                ELSIF p_in = 'C'
                THEN
                    vn_return := 2;
                ELSIF p_in = 'D'
                THEN
                    vn_return := 3;
                ELSIF p_in = 'E'
                THEN
                    vn_return := 4;
                ELSIF p_in = 'F'
                THEN
                    vn_return := 5;
                ELSIF p_in = 'G'
                THEN
                    vn_return := 6;
                ELSIF p_in = 'H'
                THEN
                    vn_return := 7;
                ELSIF p_in = 'I'
                THEN
                    vn_return := 8;
                ELSIF p_in = 'J'
                THEN
                    vn_return := 9;
                ELSIF p_in = 'K'
                THEN
                    vn_return := 10;
                ELSIF p_in = 'L'
                THEN
                    vn_return := 11;
                ELSIF p_in = 'M'
                THEN
                    vn_return := 12;
                ELSIF p_in = 'N'
                THEN
                    vn_return := 26;
                ELSIF p_in = 'O'
                THEN
                    vn_return := 13;
                ELSIF p_in = 'P'
                THEN
                    vn_return := 14;
                ELSIF p_in = 'Q'
                THEN
                    vn_return := 15;
                ELSIF p_in = 'R'
                THEN
                    vn_return := 16;
                ELSIF p_in = 'S'
                THEN
                    vn_return := 17;
                ELSIF p_in = 'T'
                THEN
                    vn_return := 18;
                ELSIF p_in = 'U'
                THEN
                    vn_return := 19;
                ELSIF p_in = 'V'
                THEN
                    vn_return := 20;
                ELSIF p_in = 'W'
                THEN
                    vn_return := 21;
                ELSIF p_in = 'X'
                THEN
                    vn_return := 22;
                ELSIF p_in = 'Y'
                THEN
                    vn_return := 23;
                ELSIF p_in = 'Z'
                THEN
                    vn_return := 24;
                END IF;
            END IF;
            RETURN vn_return;
        END;

        FUNCTION getsuffix1value(s_in IN CHAR) RETURN NUMBER IS
            vn_return NUMBER := 0;
        BEGIN
            IF NOT s_in = '*'
            THEN
                IF s_in = 'A'
                THEN
                    vn_return := 1;
                ELSIF s_in = 'B'
                THEN
                    vn_return := 2;
                ELSIF s_in = 'C'
                THEN
                    vn_return := 3;
                ELSIF s_in = 'D'
                THEN
                    vn_return := 4;
                ELSIF s_in = 'E'
                THEN
                    vn_return := 5;
                ELSIF s_in = 'F'
                THEN
                    vn_return := 6;
                ELSIF s_in = 'G'
                THEN
                    vn_return := 7;
                ELSIF s_in = 'H'
                THEN
                    vn_return := 8;
                ELSIF s_in = 'I'
                THEN
                    vn_return := 9;
                ELSIF s_in = 'J'
                THEN
                    vn_return := 10;
                ELSIF s_in = 'K'
                THEN
                    vn_return := 11;
                ELSIF s_in = 'L'
                THEN
                    vn_return := 12;
                ELSIF s_in = 'M'
                THEN
                    vn_return := 13;
                ELSIF s_in = 'N'
                THEN
                    vn_return := 14;
                ELSIF s_in = 'O'
                THEN
                    vn_return := 15;
                ELSIF s_in = 'P'
                THEN
                    vn_return := 16;
                ELSIF s_in = 'Q'
                THEN
                    vn_return := 17;
                ELSIF s_in = 'S'
                THEN
                    vn_return := 18;
                END IF;
            END IF;
            RETURN vn_return;
        END;

        FUNCTION getsuffix2value(s_in IN CHAR) RETURN NUMBER IS
            vn_return NUMBER := 0;
        BEGIN
            IF NOT s_in = '*'
            THEN
                IF s_in = 'A'
                THEN
                    vn_return := 1;
                ELSIF s_in = 'C'
                THEN
                    vn_return := 2;
                ELSIF s_in = 'D'
                THEN
                    vn_return := 3;
                ELSIF s_in = 'E'
                THEN
                    vn_return := 4;
                ELSIF s_in = 'F'
                THEN
                    vn_return := 5;
                ELSIF s_in = 'G'
                THEN
                    vn_return := 6;
                ELSIF s_in = 'H'
                THEN
                    vn_return := 7;
                ELSIF s_in = 'K'
                THEN
                    vn_return := 8;
                ELSIF s_in = '0'
                THEN
                    vn_return := 9;
                ELSIF s_in = '1'
                THEN
                    vn_return := 10;
                ELSIF s_in = '2'
                THEN
                    vn_return := 11;
                ELSIF s_in = '3'
                THEN
                    vn_return := 12;
                ELSIF s_in = '4'
                THEN
                    vn_return := 13;
                ELSIF s_in = '5'
                THEN
                    vn_return := 14;
                ELSIF s_in = '6'
                THEN
                    vn_return := 15;
                ELSIF s_in = '7'
                THEN
                    vn_return := 16;
                ELSIF s_in = '8'
                THEN
                    vn_return := 17;
                ELSIF s_in = '9'
                THEN
                    vn_return := 18;
                END IF;
            END IF;
            RETURN vn_return;
        END;

        FUNCTION getsuffix3value(s_in IN CHAR) RETURN NUMBER IS
            vn_return NUMBER := 0;
        BEGIN
            IF NOT s_in = '*'
            THEN
                IF s_in = 'A'
                THEN
                    vn_return := 1;
                ELSIF s_in = 'B'
                THEN
                    vn_return := 2;
                ELSIF s_in = 'C'
                THEN
                    vn_return := 3;
                ELSIF s_in = 'D'
                THEN
                    vn_return := 4;
                ELSIF s_in = 'E'
                THEN
                    vn_return := 5;
                ELSIF s_in = 'F'
                THEN
                    vn_return := 6;
                ELSIF s_in = 'G'
                THEN
                    vn_return := 7;
                ELSIF s_in = 'L'
                THEN
                    vn_return := 8;
                ELSIF s_in = 'P'
                THEN
                    vn_return := 9;
                ELSIF s_in = 'R'
                THEN
                    vn_return := 10;
                ELSIF s_in = 'Y'
                THEN
                    vn_return := 11;
                ELSIF s_in = 'Z'
                THEN
                    vn_return := 12;
                ELSIF s_in = '8'
                THEN
                    vn_return := 13;
                END IF;
            END IF;
            RETURN vn_return;
        END;

        FUNCTION getoccurance(p_in IN CHAR) RETURN NUMBER IS
            vn_return NUMBER := 0;
        BEGIN
            IF p_in = '0'
            THEN
                vn_return := 4;
            ELSIF p_in = '2'
            THEN
                vn_return := 1;
            ELSIF p_in BETWEEN '3' AND '5'
            THEN
                vn_return := 2;
            ELSIF p_in BETWEEN '6' AND '9'
            THEN
                vn_return := 3;
            END IF;
            RETURN vn_return;
        END;

    BEGIN
        -- calculate smartPRTC1

        np1 := getprefixvalue(p1);
        np2 := getprefixvalue(p2);
        np3 := getprefixvalue(p3);

        ns1 := getsuffix1value(s1);
        ns2 := getsuffix2value(s2);
        ns3 := getsuffix3value(s3);

        noccur := getoccurance(p3);

        IF clearcoat_min_flag = 'Y'
        THEN
            nref_min := 1073741824;
        END IF;

        IF clearcoat_maj_flag = 'Y'
        THEN
            nref_maj := 2147483648;
        END IF;

        smartprtc1 := 0;

        IF p3 BETWEEN 'A' AND 'Z'
           OR p3 = '*'
        THEN
            smartprtc1 := 18421830 * np1 + 682290 * np2 + 25270 * np3 +
                          1330 * ns1 + 70 * ns2 + 5 * ns3 + noccur +
                          nref_min + nref_maj;
        ELSIF p3 BETWEEN '0' AND '9'
        THEN
            smartprtc1 := 682290 * np1 + 25270 * np2 + 1330 * ns1 +
                          70 * ns2 + 5 * ns3 + noccur + nref_min + nref_maj;
        END IF;

        IF smartprtc1 > 2147483647
        THEN
            smartprtc1 := -2147483648 + smartprtc1 - 2147483648;
        END IF;
        RETURN smartprtc1;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN - 1;
    END;

    /* ----------------------------------------------------------------------------- sf_getSmartPRTC2 */
    FUNCTION sf_getsmartprtc2
    (
        prtc_in            IN VARCHAR2,
        body_id            IN NUMBER,
        csb_flag           IN CHAR,
        ref_comp_body      IN VARCHAR2,
        clearcoat_cap_flag IN CHAR,
        two_tone_flag      IN CHAR,
        repair_elim_flag   IN CHAR,
        dup_elim_flag      IN CHAR
    ) RETURN NUMBER IS
        smartprtc2 NUMBER := body_id;
        --  my_profile_switch number := 0;
    BEGIN
        -- calculate smartPRTC2
        IF csb_flag = 'Y'
        THEN
            smartprtc2 := 524288 + smartprtc2;
        END IF;

        IF substr(prtc_in, 4, 2) IN ('RD', 'RS', 'RT')
        THEN
            smartprtc2 := 1048576 + smartprtc2;
            IF substr(prtc_in, 4, 2) = 'RD'
            THEN
                smartprtc2 := 4194304 + smartprtc2;
            END IF;
        END IF;

        IF substr(prtc_in, 4, 2) IN ('FD', 'FS', 'FT')
        THEN
            smartprtc2 := 2097152 + smartprtc2;
        END IF;

        -- 10/02/2006 mm5095 => added support for 'NA' as refinish
        -- 08/13/2020 - pb0690 - added FC and FD and IB and IC
        IF substr(prtc_in, 4, 2) IN ('AD',
                                     'AL',
                                     'CI',
                                     'DI',
                                     'FA',
                                     'FC',
                                     'FD',
                                     'IA',
                                     'IB',
                                     'IC',
                                     'NA',
                                     'OA',
                                     'OB',
                                     'RA',
                                     'RC',
                                     'RD',
                                     'OG')
        THEN
            --  if substr(prtc_in,4,2) in ('AD','AL','CI','DI','FA','IA','OA','OB','RA','RC','RD','OG') then
            -- 10/02/2006 mm5095 => added support for 'NA' as refinish
            smartprtc2 := 8388608 + smartprtc2;
        END IF;

        -- 10/02/2006 mm5095 => added support for 'NA' as refinish
        -- 08/13/2020 - pb0690 - added FC and FD and IB and IC
        IF substr(prtc_in, 4, 2) IN ('FA', 'FC', 'FD')
           OR substr(prtc_in, 4, 2) = 'NA'
        THEN
            --  if substr(prtc_in,4,2) = 'FA' then
            -- 10/02/2006 mm5095 => added support for 'NA' as refinish
            smartprtc2 := 16777216 + smartprtc2;
        END IF;

        IF substr(prtc_in, 4, 2) = 'OA'
        THEN
            smartprtc2 := 33554432 + smartprtc2;
        END IF;

        IF rtrim(ref_comp_body) IS NOT NULL
        THEN
            smartprtc2 := 67108864 + smartprtc2;
        END IF;

        IF substr(prtc_in, 4, 2) = 'RZ'
        THEN
            smartprtc2 := 134217728 + smartprtc2;
        END IF;

        IF clearcoat_cap_flag = 'Y'
        THEN
            smartprtc2 := 268435456 + smartprtc2;
        END IF;

        IF two_tone_flag = 'Y'
        THEN
            smartprtc2 := 536870912 + smartprtc2;
        END IF;

        IF repair_elim_flag = 'Y'
        THEN
            smartprtc2 := 1073741824 + smartprtc2;
        END IF;

        IF dup_elim_flag = 'N'
        THEN
            smartprtc2 := 2147483648 + smartprtc2;
        END IF;

        IF smartprtc2 > 2147483647
        THEN
            smartprtc2 := -2147483648 + smartprtc2 - 2147483648;
        END IF;

        RETURN smartprtc2;
    END;

    /* ----------------------------------------------------------------------------- sf_getSmartPRTCId */
    FUNCTION sf_getsmartprtcid
    (
        prtc_in  IN VARCHAR2,
        run_type VARCHAR2
    ) RETURN NUMBER IS

        vn_return NUMBER := 0;

        CURSOR full_cur IS
            SELECT /*+ sf_getSmartPRTCId.full_cur */
             partid
              FROM um_smartprtc a
             WHERE a.prtc = prtc_in;

        CURSOR mini_cur IS
            SELECT /*+ sf_getSmartPRTCId.mini_cur */
             partid
              FROM tmp_um_smartprtc a
             WHERE a.prtc = prtc_in;

    BEGIN
        IF run_type = 'FULL'
        THEN
            OPEN full_cur;
            FETCH full_cur
                INTO vn_return;
            CLOSE full_cur;
        ELSE
            OPEN mini_cur;
            FETCH mini_cur
                INTO vn_return;
            CLOSE mini_cur;
        END IF;

        RETURN vn_return;

    EXCEPTION
        WHEN OTHERS THEN
            RETURN vn_return;
    END;

    /* ----------------------------------------------------------------------------- sf_StripDate */
    FUNCTION sf_stripdate(vvc2_qualifier IN VARCHAR2) RETURN VARCHAR2 IS
        nquote      BOOLEAN;
        nparen      BOOLEAN;
        nstart      INTEGER;
        v_text      VARCHAR2(80);
        vvc2_return VARCHAR2(80);
        n_year      INTEGER;

    BEGIN
        nquote      := FALSE;
        nparen      := FALSE;
        nstart      := 1;
        vvc2_return := vvc2_qualifier;

        IF substr(vvc2_qualifier, 1, 3) = 'To '
           OR substr(vvc2_qualifier, 1, 5) = 'From '
        THEN
            RETURN vvc2_return;
        END IF;

        FOR n IN 1 .. length(vvc2_qualifier)
        LOOP
            v_text := NULL;
            IF NOT nquote
               AND NOT nparen
               AND substr(vvc2_qualifier, n, 1) = ' '
            THEN
                v_text := substr(vvc2_qualifier, nstart, n - nstart);
                nstart := n + 1;
            ELSIF substr(vvc2_qualifier, n, 1) = '"'
            THEN
                IF nquote
                THEN
                    nquote := FALSE;
                ELSE
                    nquote := TRUE;
                END IF;
            ELSIF substr(vvc2_qualifier, n, 1) = '('
            THEN
                nparen := TRUE;
            ELSIF substr(vvc2_qualifier, n, 1) = ')'
            THEN
                nparen := FALSE;
            ELSIF NOT nquote
                  AND NOT nparen
                  AND n = length(vvc2_qualifier)
            THEN
                v_text := substr(vvc2_qualifier, nstart);
            END IF;

            IF v_text IS NOT NULL
            THEN
                IF length(v_text) = 4
                THEN
                    BEGIN
                        n_year := to_number(v_text);
                        IF n_year > 1949
                           AND n_year < 2038
                        THEN
                            vvc2_return := ltrim(REPLACE(vvc2_qualifier,
                                                         v_text));
                            vvc2_return := REPLACE(vvc2_return, '  ', ' ');
                            EXIT;
                        END IF;
                    EXCEPTION
                        WHEN OTHERS THEN
                            NULL; -- not numeric, skip
                    END;
                ELSIF substr(v_text, 5, 1) = '-'
                THEN
                    BEGIN
                        n_year := to_number(substr(v_text, 1, 4));
                        IF n_year > 1949
                           AND n_year < 2038
                        THEN
                            IF substr(v_text, 8, 1) = '-'
                               OR length(v_text) = 7
                            THEN
                                -- 1984-85-...
                                BEGIN
                                    n_year := to_number(substr(v_text, 6, 2));
                                    -- 1984-85-Unicode
                                    -- strip off 7 digits
                                    vvc2_return := ltrim(REPLACE(vvc2_qualifier,
                                                                 substr(v_text,
                                                                        1,
                                                                        7)));
                                    vvc2_return := REPLACE(vvc2_return,
                                                           '  ',
                                                           ' ');
                                    EXIT;
                                EXCEPTION
                                    WHEN OTHERS THEN
                                        -- 1984-Unicode
                                        -- strip off 4 digits
                                        vvc2_return := ltrim(REPLACE(vvc2_qualifier,
                                                                     substr(v_text,
                                                                            1,
                                                                            4)));
                                        vvc2_return := REPLACE(vvc2_return,
                                                               '  ',
                                                               ' ');
                                        EXIT;
                                END;
                            ELSIF substr(v_text, 10, 1) = '-'
                                  OR length(v_text) = 9
                            THEN
                                -- 1984-1985-...
                                BEGIN
                                    n_year := to_number(substr(v_text, 6, 4));
                                    -- 1984-1985-Unicode
                                    -- strip off 9 digits
                                    vvc2_return := ltrim(REPLACE(vvc2_qualifier,
                                                                 substr(v_text,
                                                                        1,
                                                                        9)));
                                    vvc2_return := REPLACE(vvc2_return,
                                                           '  ',
                                                           ' ');
                                    EXIT;
                                EXCEPTION
                                    WHEN OTHERS THEN
                                        -- 1984-Unicode
                                        -- stip off 4 digits
                                        vvc2_return := ltrim(REPLACE(vvc2_qualifier,
                                                                     substr(v_text,
                                                                            1,
                                                                            4)));
                                        vvc2_return := REPLACE(vvc2_return,
                                                               '  ',
                                                               ' ');
                                        EXIT;
                                END;
                            ELSE
                                BEGIN
                                    n_year      := to_number(v_text, 6);
                                    vvc2_return := ltrim(REPLACE(vvc2_qualifier,
                                                                 v_text));
                                    vvc2_return := REPLACE(vvc2_return,
                                                           '  ',
                                                           ' ');
                                    EXIT;
                                EXCEPTION
                                    WHEN OTHERS THEN
                                        -- 1984
                                        -- strip off 4 digits
                                        vvc2_return := ltrim(REPLACE(vvc2_qualifier,
                                                                     substr(v_text,
                                                                            1,
                                                                            4)));
                                        vvc2_return := REPLACE(vvc2_return,
                                                               '  ',
                                                               ' ');
                                        EXIT;
                                END;
                            END IF;
                        END IF;
                    EXCEPTION
                        WHEN OTHERS THEN
                            NULL; -- not numeric do nothing
                    END;
                ELSIF length(v_text) = 5
                      AND substr(v_text, 3, 1) = '-'
                THEN
                    -- 95-01
                    BEGIN
                        -- 2007/02/09 mm5095 => not used
                        --            n_year := to_number(substr(v_text,1,2));
                        --            n_year := to_number(substr(v_text,4,2));
                        -- 2007/02/09 mm5095 => not used
                        vvc2_return := ltrim(REPLACE(vvc2_qualifier, v_text));
                        vvc2_return := REPLACE(vvc2_return, '  ', ' ');
                        EXIT;
                    EXCEPTION
                        WHEN OTHERS THEN
                            NULL; -- not numeric do nothing
                    END;
                END IF;
            END IF;
        END LOOP;
        RETURN vvc2_return;
    END;

    /* ----------------------------------------------------------------------------- sf_SupplierConversion */
    FUNCTION sf_supplierconversion(supplier_num IN VARCHAR2) RETURN NUMBER IS
        vn_return NUMBER;
    BEGIN
        vn_return := ascii(substr(supplier_num, 1, 1)) +
                     ascii(substr(supplier_num, 2, 1)) * 256 +
                     ascii(substr(supplier_num, 3, 1)) * 65536 +
                     ascii(substr(supplier_num, 4, 1)) * 16777216;
        RETURN vn_return;
    END;

    /* ----------------------------------------------------------------------------- sp_getLaborInfo */
    PROCEDURE sp_getlaborinfo
    (
        skey           IN NUMBER,
        ceg_labor_time OUT NUMBER,
        ioh_flag       OUT CHAR,
        labor_type     OUT CHAR
    ) IS
        CURSOR c1_cur IS
            SELECT /*+ sp_getLaborInfo.c1_cur */
             ceg_labor_time,
             ioh_flag,
             upper(labor_type)
              FROM labor_operation
             WHERE labor_operation_skey = skey;

    BEGIN
        OPEN c1_cur;
        FETCH c1_cur
            INTO ceg_labor_time,
                 ioh_flag,
                 labor_type;
        CLOSE c1_cur;
    END;

    /* ----------------------------------------------------------------------------- sp_getPartInfo */
    PROCEDURE sp_getpartinfo
    (
        row_id            IN NUMBER,
        version           IN VARCHAR2,
        country_abbr      IN VARCHAR2,
        part              OUT VARCHAR2,
        date1             OUT DATE,
        price1            OUT NUMBER,
        date2             OUT DATE,
        price2            OUT NUMBER,
        discontinued_flag OUT CHAR,
        new_flag          OUT CHAR,
        special_flag      OUT CHAR
    ) IS

        my_discontinued_date DATE;
        my_part_supplier     VARCHAR2(3);

        CURSOR c1_cur IS
            SELECT /*+ sp_getPartInfo.c1_cur */
             part_supplier_number,
             part_number,
             current_effective_date,
             current_price,
             previous_effective_date,
             previous_price,
             discontinued_date,
             new_or_reman_flag,
             special_price_flag
              FROM detail_part_xref a,
                   part             b
             WHERE a.unique_row_id = row_id
               AND a.version_type = version
               AND a.part_skey = b.part_skey
               AND b.part_supplier_country_abbr = country_abbr;

    BEGIN
        OPEN c1_cur;
        FETCH c1_cur
            INTO my_part_supplier,
                 part,
                 date1,
                 price1,
                 date2,
                 price2,
                 my_discontinued_date,
                 new_flag,
                 special_flag;
        CLOSE c1_cur;

        -- 02/19/2016 mm5095 => no longer necessary
        /*        IF my_part_supplier IN ('001', '034', '038')
                THEN
                    -- gm part
                    IF length(rtrim(part)) < 13
                    THEN
                        part := rpad(part, 20, ' ');
                        part := substr(part, 1, 13) || 'GM PART';
                    END IF;
                ELS
        */
        IF my_part_supplier = '000'
        THEN
            -- nags part
            IF substr(part, 1, 2) = 'C '
            THEN
                part := substr(part, 3);
            END IF;
        END IF;

        IF my_discontinued_date IS NOT NULL
        THEN
            discontinued_flag := 'Y';
        ELSE
            discontinued_flag := 'N';
        END IF;
    END;

    /* ----------------------------------------------------------------------------- sp_getSmartPRTCbits */
    PROCEDURE sp_getsmartprtcbits
    (
        prtc_in  IN VARCHAR2,
        bit1_0   OUT NUMBER,
        bit1_1   OUT NUMBER,
        run_type IN VARCHAR2
    ) IS
        CURSOR full_cur IS
            SELECT /*+ sp_getSmartPRTCbits.full_cur */
             smartprtc1,
             smartprtc2
              FROM um_smartprtc
             WHERE prtc = prtc_in;

        CURSOR mini_cur IS
            SELECT /*+ sp_getSmartPRTCbits.mini_cur */
             smartprtc1,
             smartprtc2
              FROM tmp_um_smartprtc
             WHERE prtc = prtc_in;

    BEGIN

        IF run_type = 'FULL'
        THEN
            OPEN full_cur;
            FETCH full_cur
                INTO bit1_0,
                     bit1_1;
            CLOSE full_cur;
        ELSE
            OPEN mini_cur;
            FETCH mini_cur
                INTO bit1_0,
                     bit1_1;
            CLOSE mini_cur;
        END IF;

    END;

    /* ----------------------------------------------------------------------------- sp_getSmartPRTCInfo */
    PROCEDURE sp_getsmartprtcinfo
    (
        prtc_in    IN VARCHAR2,
        bit1_0     OUT NUMBER,
        bit1_1     OUT NUMBER,
        partid_out OUT NUMBER,
        run_type   IN VARCHAR2
    ) IS
        CURSOR full_cur IS
            SELECT /*+ sp_getSmartPRTCInfo.full_cur */
             smartprtc1,
             smartprtc2,
             partid
              FROM um_smartprtc
             WHERE prtc = prtc_in;

        CURSOR mini_cur IS
            SELECT /*+ sp_getSmartPRTCInfo.mini_cur */
             smartprtc1,
             smartprtc2,
             partid
              FROM tmp_um_smartprtc
             WHERE prtc = prtc_in;

    BEGIN
        IF run_type = 'FULL'
        THEN
            OPEN full_cur;
            FETCH full_cur
                INTO bit1_0,
                     bit1_1,
                     partid_out;
            CLOSE full_cur;
        ELSE
            OPEN mini_cur;
            FETCH mini_cur
                INTO bit1_0,
                     bit1_1,
                     partid_out;
            CLOSE mini_cur;
        END IF;

    END;

    /* ----------------------------------------------------------------------------- sp_StripText */
    PROCEDURE sp_striptext
    (
        text_in         IN OUT VARCHAR2,
        right_left_code IN OUT NUMBER
    ) IS
        npos  NUMBER;
        npos2 NUMBER;
    BEGIN
        npos := instr(text_in, 'Right');
        IF npos > 0
        THEN
            npos2 := instr(text_in, 'Right Only');
            IF npos2 = 0
            THEN
                npos2 := instr(text_in, 'Right Side Only');
            END IF;

            -- 04/12/04 mm5095 => to support Right Side qualifier
            IF npos2 = 0
            THEN
                npos2 := instr(text_in, 'Right Side');
                IF npos2 > 0
                THEN
                    right_left_code := 1;
                END IF;
            END IF;
            -- 04/12/04 mm5095 => to support Right Side qualifier

            IF npos2 = 0
            THEN
                right_left_code := 1;
                IF npos = 1
                THEN
                    text_in := ltrim(substr(text_in, npos + 5));
                ELSE
                    text_in := substr(text_in, 1, npos - 1) ||
                               substr(text_in, npos + 6);
                END IF;
            END IF;
        ELSE
            npos := instr(text_in, 'Left');
            IF npos > 0
            THEN
                npos2 := instr(text_in, 'Left Only');
                IF npos2 = 0
                THEN
                    npos2 := instr(text_in, 'Left Side Only');
                END IF;

                -- 04/12/04 mm5095 => to support Left Side qualifier
                IF npos2 = 0
                THEN
                    npos2 := instr(text_in, 'Left Side');
                    IF npos2 > 0
                    THEN
                        right_left_code := 2;
                    END IF;
                END IF;
                -- 04/12/04 mm5095 => to support Left Side qualifier

                IF npos2 = 0
                THEN
                    right_left_code := 2;
                    IF npos = 1
                    THEN
                        text_in := ltrim(substr(text_in, npos + 4));
                    ELSE
                        text_in := substr(text_in, 1, npos - 1) ||
                                   substr(text_in, npos + 5);
                    END IF;
                END IF;
            END IF;
        END IF;
    END;

    /* ----------------------------------------------------------------------------- sp_output_semaphore */
    /* Description: Creates zzGLOBAL and zzDONE semaphore files. Also, opens and closes done.txt file.   */
    /* ------------------------------------------------------------------------------------------------- */
    PROCEDURE sp_output_zzglobal_done_files
    (
        path         VARCHAR2,
        file_name    VARCHAR2,
        full_flag    CHAR,
        restart_flag CHAR
    ) IS
        out_fhandle utl_file.file_type;

    BEGIN

        -- open zzglobal or zzdone file
        out_fhandle := utl_file.fopen(path,
                                      'zz' || file_name || '.txt',
                                      'w');

        -- writes to zzglobal or zzdone file
        IF full_flag = 'T'
           AND restart_flag = 'T'
        THEN
            utl_file.put_line(out_fhandle, 'RESTART');
        ELSE
            utl_file.put_line(out_fhandle, 'FULL');
        END IF;

        -- closes zzglobal or zzdone file
        utl_file.fclose(out_fhandle);

        -- open done.txt file
        IF file_name = 'done'
        THEN
            out_fhandle := utl_file.fopen(path, file_name || '.txt', 'w');
        END IF;

        -- close done.txt file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

    EXCEPTION
        WHEN utl_file.invalid_path THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20100, 'INVALID PATH');
        WHEN utl_file.invalid_mode THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20101, 'INVALID MODE');
        WHEN utl_file.invalid_operation THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20102, 'INVALID OPERATION');
        WHEN utl_file.invalid_filehandle THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20103, 'INVALID FILEHANDLE');
        WHEN utl_file.write_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20104, 'WRITE ERROR');
        WHEN utl_file.read_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20105, 'READ ERROR');
        WHEN utl_file.internal_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20106, 'INTERNAL ERROR');
            --  WHEN OTHERS THEN
        --    UTL_FILE.FCLOSE(OUT_FHANDLE);
        --    RAISE_APPLICATION_ERROR(-20107,'UNKNOWN ERROR');
    END;

    /* ----------------------------------------------------------------------------- sp_update_globaltxt_semaphore */
    PROCEDURE sp_update_globaltxt_semaphore
    (
        path         VARCHAR2,
        file_name_in VARCHAR2,
        file_mode_in VARCHAR2,
        text_in      VARCHAR2
    ) IS
        out_fhandle utl_file.file_type;
    BEGIN
        -- open files
        out_fhandle := utl_file.fopen(path, file_name_in, file_mode_in);

        utl_file.put_line(out_fhandle, text_in);

        -- close files, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;
    EXCEPTION
        WHEN utl_file.invalid_path THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20100, 'INVALID PATH');
        WHEN utl_file.invalid_mode THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20101, 'INVALID MODE');
        WHEN utl_file.invalid_operation THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20102, 'INVALID OPERATION');
        WHEN utl_file.invalid_filehandle THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20103, 'INVALID FILEHANDLE');
        WHEN utl_file.write_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20104, 'WRITE ERROR');
        WHEN utl_file.read_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20105, 'READ ERROR');
        WHEN utl_file.internal_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20106, 'INTERNAL ERROR');
            --  WHEN OTHERS THEN
        --    UTL_FILE.FCLOSE(OUT_FHANDLE);
        --    RAISE_APPLICATION_ERROR(-20107,'UNKNOWN ERROR');
    END;

    /* ----------------------------------------------------------------------------- sp_output_barcode_semaphore */
    PROCEDURE sp_output_barcode_semaphore
    (
        path         VARCHAR2,
        barcode_in   VARCHAR2,
        text_in      VARCHAR2,
        file_mode_in VARCHAR2
    ) IS
        fhandle utl_file.file_type;
    BEGIN
        fhandle := utl_file.fopen(path, barcode_in || '.txt', file_mode_in);

        IF text_in IS NOT NULL
        THEN
            utl_file.put_line(fhandle, text_in);
        END IF;

        utl_file.fclose(fhandle);
    END;

    /**********************************************************************************/
    /* set_version_cur                                                                */
    /* This gets latest version number and assoc'd post_checkin_process_date of       */
    /* service that is passed into cursor.                                            */
    /* NOTE: PRODUCT_CODE is only needed for MINI-related query.                      */
    /**********************************************************************************/
    PROCEDURE set_version_cursor
    (
        cursor_parm     IN OUT version_cursor,
        full_flag       IN CHAR,
        mfr_in          IN VARCHAR2,
        service_in      IN VARCHAR2,
        version_in      IN VARCHAR2,
        product_code_in IN VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN

        IF full_flag = 'T'
        THEN
            --FULL run (full_flag = True)
            --FULL checks all EP Product Codes when valuing MCE_Flag and UM_Flag
            OPEN cursor_parm FOR
                SELECT /*+ SET_VERSION_CURSOR.version_cur_full */
                 version_number,
                 post_checkin_process_date,
                 -- 04/17/2020 pg2697 => add mce_flag and um_flag
                 nvl((SELECT 'Y'
                       FROM product_service ps,
                            product         p
                      WHERE ps.mfr_number = v.mfr_number
                        AND ps.service_number = v.service_number
                        AND p.product_code = ps.product_code
                        AND p.product_type = 'EP'
                        AND p.um_mini_flag = 'N'
                        AND p.mce_flag = 'Y'
                           -- causes MCE_FLAG to be set to 'N' for all HTD and MTD-ONLY services
                           -- where service isn't associated to a MTD/HTD product code and also isn't associated to a CEG product code
                        AND NOT EXISTS
                      (SELECT 1
                               FROM product         px,
                                    product_service psx
                              WHERE psx.mfr_number = v.mfr_number
                                AND psx.service_number = v.service_number
                                AND px.product_code = psx.product_code
                                AND px.product_type = 'EP'
                                AND px.product_class_code IN ('MTD', 'HTD')
                                AND px.um_mini_flag = 'N'
                                AND NOT EXISTS
                              (SELECT 1
                                       FROM product         px,
                                            product_service psx
                                      WHERE psx.mfr_number = v.mfr_number
                                        AND psx.service_number =
                                            v.service_number
                                        AND px.product_code =
                                            psx.product_code
                                        AND px.product_type = 'EP'
                                        AND px.product_class_code = 'CEG'
                                        AND px.um_mini_flag = 'N'
                                        AND px.mce_flag = 'Y'))
                        AND rownum = 1),
                     'N') AS mce_flag,
                 nvl((SELECT 'Y'
                       FROM product_service ps,
                            product         p
                      WHERE ps.mfr_number = v.mfr_number
                        AND ps.service_number = v.service_number
                        AND p.product_code = ps.product_code
                        AND p.product_type = 'EP'
                        AND p.um_mini_flag = 'N'
                        AND p.um_flag = 'Y'
                           -- causes UM_FLAG to be set to 'N' for all CHT/CMT services
                        AND NOT EXISTS
                      (SELECT 1
                               FROM product         px,
                                    product_service psx
                              WHERE psx.mfr_number = v.mfr_number
                                AND psx.service_number = v.service_number
                                AND px.product_code = psx.product_code
                                AND px.product_type = 'EP'
                                AND px.product_class_code IN ('CMT', 'CHT'))
                        AND rownum = 1),
                     'N') AS um_flag
                ---- 04/17/2020 pg2697 => add mce_flag and um_flag (end)
                  FROM version v
                 WHERE v.mfr_number = mfr_in
                   AND v.service_number = service_in
                   AND v.version_type = version_in
                   AND rownum = 1
                 ORDER BY version_number DESC;
        ELSE
            --MINI run (full_flag = False)
            --MINI checks specific UM_Mini Product Code when valuing MCE_Flag and UM_Flag
            OPEN cursor_parm FOR
                SELECT /*+ SET_VERSION_CURSOR.version_cur_mini */
                 version_number,
                 post_checkin_process_date,
                 -- 04/17/2020 pg2697 => add mce_flag and um_flag
                 nvl((SELECT p.mce_flag
                        FROM product_service ps,
                             product         p
                       WHERE ps.mfr_number = v.mfr_number
                         AND ps.service_number = v.service_number
                         AND p.product_code = product_code_in
                         AND p.product_code = ps.product_code
                         AND p.product_type = 'EP'
                         AND p.um_mini_flag = 'Y'
                            -- causes MCE_FLAG to be set to 'N' for all HTD and MTD services
                            -- where service isn't associated to a MTD/HTD product code
                        AND NOT EXISTS
                      (SELECT 1
                               FROM product         px,
                                    product_service psx
                              WHERE psx.mfr_number = v.mfr_number
                                AND psx.service_number = v.service_number
                                AND px.product_code = psx.product_code
                                AND px.product_type = 'EP'
                                AND px.product_class_code IN ('MTD', 'HTD')
                                AND px.um_mini_flag = 'N'
                                AND NOT EXISTS
                              (SELECT 1
                                       FROM product         px,
                                            product_service psx
                                      WHERE psx.mfr_number = v.mfr_number
                                        AND psx.service_number =
                                            v.service_number
                                        AND px.product_code =
                                            psx.product_code
                                        AND px.product_type = 'EP'
                                        AND px.product_class_code = 'CEG'
                                        AND px.um_mini_flag = 'N'
                                           --
                                        AND px.mce_flag = 'Y'))
                        AND rownum = 1),
                     'N') AS mce_flag,
                 nvl((SELECT p.um_flag
                        FROM product_service ps,
                             product         p
                       WHERE ps.mfr_number = v.mfr_number
                         AND ps.service_number = v.service_number
                         AND p.product_code = product_code_in
                         AND p.product_code = ps.product_code
                         AND p.product_type = 'EP'
                         AND p.um_mini_flag = 'Y'
                            -- causes UM_FLAG to be set to 'N' for all 700's
                        AND NOT EXISTS
                      (SELECT 1
                               FROM product         px,
                                    product_service psx
                              WHERE psx.mfr_number = v.mfr_number
                                AND psx.service_number = v.service_number
                                AND px.product_code = psx.product_code
                                AND px.product_type = 'EP'
                                AND px.product_class_code IN ('CMT', 'CHT'))
                        AND rownum = 1),
                     'N') AS um_flag
                ---- 04/17/2020 pg2697 => add mce_flag and um_flag (end)
                  FROM version v
                 WHERE v.mfr_number = mfr_in
                   AND v.service_number = service_in
                   AND v.version_type = version_in
                 ORDER BY version_number DESC;
        END IF;

    END set_version_cursor;

    /********************************************************************************/
    /* Program Name: extract_service_barcodes                                       */
    /* Author:       MM5095                                                         */
    /* Last Modified:                                                               */
    /* 10/02/2001 MM5095                                                            */
    /* 04/17/2020 PG2697 - added MCE_FLAG and UM_FLAG to version_cur select         */
    /* ---------------------------------------------------------------------------- */
    /* Description: This SQL script performs the following functions:               */
    /* - Accepts runtime parameters that designate the data sources for             */
    /*   filtering the RACE Products and Mfr/Service combinations that              */
    /*   are included in the Ultramate build.                                       */
    /* - I.E. THIS DRIVES THE EXTRACT!                                              */
    /********************************************************************************/
    PROCEDURE extract_service_barcodes
    (
        path         VARCHAR2,
        parm_file    VARCHAR2,
        version      VARCHAR2,
        full_flag    CHAR,
        restart_flag CHAR
    ) IS

        --This gets latest version number and assoc'd post_checkin_process_date of service that is passed into cursor
        CURSOR extract_cur
        (
            mfr_in     VARCHAR2,
            service_in VARCHAR2,
            version_in VARCHAR2
        ) IS
            SELECT /*+ EXTRACT_SERVICE_BARCODES.extract_cur */
             post_checkin_process_date,
             extract_date
              FROM tmp_um_extract
             WHERE mfr_number = mfr_in
               AND service_number = service_in
               AND version_type = version_in;
        extract_rec extract_cur%ROWTYPE;

        --get services associated to passed in product code
        CURSOR service_cur(product_code_in VARCHAR2) IS
            SELECT /*+ EXTRACT_SERVICE_BARCODES.service_cur */
             mfr_number,
             service_number
              FROM product_service
             WHERE product_code = product_code_in;

        -- 2020/07/20 PAG - Moved select for version_cur into procedure SET_VERSION_CURSOR
        -- so that selection criteria can be changed based on run_type.
        version_cur version_cursor;
        version_rec version_record;

        -- 01/04/2005 mm5095 => now support motorcycles and RVs
        -- 12/01/2004 mm5095 => temporary change to prevent motorcycles
        --                      and RVs from being added to UltraMate
        --                      remove changes when motorcycles and RVs are supported
        --get all active services
        CURSOR slocate_cur IS
            SELECT /*+ EXTRACT_SERVICE_BARCODES.slocate_cur */
            DISTINCT mfr_number,
                     service_number,
                     a.barcode
              FROM um_service_location a,
                   service             b
             WHERE a.barcode = '9' || b.barcode
               AND deleted_date IS NULL
                  /*     --<<PAG: TESTING PURPOSES ONLY!! --20 TEST CASES
                  AND (b.mfr_number || '-' || b.service_number IN
                      ('001-00072',
                        '004-51700',
                        '007-00003',
                        '007-02700',
                        '007-73500',
                        '027-00100',
                        '030-00014',
                        '030-19300',
                        '044-00028',
                        '101-88200',
                        '108-00900',
                        '146-07300',
                        '208-09000',
                        '291-00019',
                        '308-00200',
                        '391-00100',
                        '408-00500',
                        '508-17900',
                        '608-00001',
                        '705-00002'))
                     --<<PAG: TESTING PURPOSES ONLY!! --END*/
               AND mfr_number != '000';

        --2020/07/20 PAG: added version_in. Was returning 2 rows when only 1 needed.
        CURSOR barcode_cur
        (
            mfr_in     VARCHAR2,
            service_in VARCHAR2,
            version_in VARCHAR2
        ) IS
            SELECT /*+ EXTRACT_SERVICE_BARCODES.barcode_cur */
             '9' || barcode barcode
              FROM service s
             WHERE s.mfr_number = mfr_in
               AND s.service_number = service_in
               AND s.version_type = version_in;
        barcode_rec barcode_cur%ROWTYPE;

        CURSOR in_ext_cur
        (
            mfr_in     VARCHAR2,
            service_in VARCHAR2,
            version_in VARCHAR2
        ) IS
            SELECT /*+ EXTRACT_SERVICE_BARCODES.in_ext_cur */
             *
              FROM ext.service_category
             WHERE mfr_number = mfr_in
               AND service_number = service_in
               AND version_type = version_in
               AND rownum = 1;
        in_ext_rec in_ext_cur%ROWTYPE;

        CURSOR product_country_cur(product_code_in VARCHAR) IS
            SELECT /*+ EXTRACT_SERVICE_BARCODES.product_country_cur */
             country_abbr
              FROM product_country
             WHERE product_code = product_code_in;
        product_country_rec product_country_cur%ROWTYPE;

        in_fhandle utl_file.file_type;

        line_in                   VARCHAR2(80);
        product_code              VARCHAR2(6); -- 2020/07/20 PAG added
        post_checkin_process_date DATE;
        extract_date              DATE;
        my_country_abbr           VARCHAR2(2);
        bservicefound             BOOLEAN;
        -- 2007/02/09 mm5095 => no longer necessary
        --  ret_val varchar2(4);
        -- 2007/02/09 mm5095 => no longer necessary

    BEGIN
        IF full_flag = 'F'
        THEN
            in_fhandle := utl_file.fopen(path, parm_file, 'r');
        END IF;

        DELETE /*+ EXTRACT_SERVICE_BARCODES.tmp_um_extract_delete */
        FROM tmp_um_extract;

        IF full_flag = 'T'
        THEN
            -- UM full-build
            IF restart_flag = 'F'
            THEN
                -- start from the beginning
                -- get services that are um_service_location and verify each was successfully copied from race to ext
                FOR s_rec IN slocate_cur
                LOOP

                    -- 2020/07/20 PAG - calls set_version_cursor to determine cursor select to be used
                    set_version_cursor(version_cur,
                                       full_flag,
                                       s_rec.mfr_number,
                                       s_rec.service_number,
                                       version);
                    FETCH version_cur
                        INTO version_rec;
                    -- 2020/07/20 PAG - calls set_version_cursor to determine cursor select to be used
                    IF version_cur%FOUND
                    THEN
                        --For Testing
                        --dbms_output.put_line(s_rec.mfr_number || ' ' ||
                        --                     s_rec.service_number || ' => processing');
                        --For Testing
                        --IF version_rec.post_checkin_process_date IS NULL THEN
                        -- error: service has been worked on in RACE and checked in (use current EXT version)
                        -- or post_checkin_process failed during move from RACE to EXT
                        --  dbms_output.put_line(s_rec.mfr_number || ' ' ||
                        --                       s_rec.service_number ||
                        --                       ' => Post checkin process date error. Using EXT version of service.');
                        --END IF;

                        -- verify that service is found in ext.service_category table
                        OPEN in_ext_cur(s_rec.mfr_number,
                                        s_rec.service_number,
                                        version);
                        FETCH in_ext_cur
                            INTO in_ext_rec;
                        IF in_ext_cur%FOUND
                        THEN
                            BEGIN
                                INSERT /*+ EXTRACT_SERVICE_BARCODES.tmp_um_extract_insert */
                                INTO tmp_um_extract
                                    (mfr_number,
                                     service_number,
                                     version_type,
                                     product_code,
                                     country_abbr,
                                     barcode,
                                     -- 04/17/2020 pg2697 => add mce_flag and um_flag
                                     mce_flag,
                                     um_flag,
                                     -- 04/17/2020 pg2697 => add mce_flag and um_flag (end)
                                     post_checkin_process_date)
                                VALUES
                                    (s_rec.mfr_number,
                                     s_rec.service_number,
                                     version,
                                     'UMFULL',
                                     'US',
                                     s_rec.barcode,
                                     -- 04/17/2020 pg2697 => add mce_flag and um_flag
                                     version_rec.mce_flag,
                                     version_rec.um_flag,
                                     -- 04/17/2020 pg2697 => add mce_flag and um_flag (end)
                                     version_rec.post_checkin_process_date);
                            EXCEPTION
                                WHEN dup_val_on_index THEN
                                    NULL; -- skip duplicates
                            END;
                        ELSE
                            dbms_output.put_line('ERROR: ' ||
                                                 s_rec.mfr_number || ' ' ||
                                                 s_rec.service_number || ' ' ||
                                                 version ||
                                                 ' not found in EXT!');
                        END IF;
                        CLOSE in_ext_cur;
                    ELSE
                        dbms_output.put_line(s_rec.mfr_number || ' ' ||
                                             s_rec.service_number ||
                                             ' => Service not found!');
                    END IF;
                    CLOSE version_cur;
                END LOOP;
            ELSE
                -- restarting
                -- populate tmp_um_extract with everything that was processed previously (prior to restart)
                -- 04/17/2020 pg2697 - Added column names to clarify what is being selected and inserted.
                INSERT /*+ EXTRACT_SERVICE_BARCODES.tmp_um_extract_insert2 */
                INTO tmp_um_extract
                    (mfr_number,
                     service_number,
                     version_type,
                     product_code,
                     country_abbr,
                     barcode,
                     post_checkin_process_date,
                     extract_date,
                     mce_flag,
                     um_flag)
                    SELECT mfr_number,
                           service_number,
                           version_type,
                           product_code,
                           country_abbr,
                           barcode,
                           post_checkin_process_date,
                           extract_date,
                           mce_flag,
                           um_flag
                      FROM um_extract;

                -- check that post checkin process has been applied to all services in parameter file
                FOR s_rec IN slocate_cur
                LOOP
                    -- 2020/07/20 PAG - calls set_version_cursor to determine cursor select to be used
                    set_version_cursor(version_cur,
                                       full_flag,
                                       s_rec.mfr_number,
                                       s_rec.service_number,
                                       version);
                    FETCH version_cur
                        INTO version_rec;
                    -- 2020/07/20 PAG - calls set_version_cursor to determine cursor select to be used
                    IF version_cur%FOUND
                    THEN
                        IF version_rec.post_checkin_process_date IS NULL
                        THEN
                            -- error: service has been worked on in RACE and checked in (use current EXT version)
                            -- or post_checkin_process failed during move from RACE to EXT
                            dbms_output.put_line(s_rec.mfr_number || ' ' ||
                                                 s_rec.service_number ||
                                                 ' post checkin process date error.');
                            dbms_output.put_line('Using EXT version of service.');
                        END IF;

                        OPEN extract_cur(s_rec.mfr_number,
                                         s_rec.service_number,
                                         version);
                        FETCH extract_cur
                            INTO extract_rec;
                        IF extract_cur%NOTFOUND
                        THEN
                            -- if service not found, add to tmp table
                            OPEN in_ext_cur(s_rec.mfr_number,
                                            s_rec.service_number,
                                            version);
                            FETCH in_ext_cur
                                INTO in_ext_rec;
                            IF in_ext_cur%FOUND
                            THEN
                                BEGIN
                                    INSERT /*+ EXTRACT_SERVICE_BARCODES.tmp_um_extract_insert3 */
                                    INTO tmp_um_extract
                                        (mfr_number,
                                         service_number,
                                         version_type,
                                         product_code,
                                         country_abbr,
                                         barcode,
                                         -- 04/17/2020 pg2697 => add mce_flag and um_flag
                                         mce_flag,
                                         um_flag,
                                         -- 04/17/2020 pg2697 => add mce_flag and um_flag (end)
                                         post_checkin_process_date)
                                    VALUES
                                        (s_rec.mfr_number,
                                         s_rec.service_number,
                                         version,
                                         'UMFULL',
                                         'US',
                                         s_rec.barcode,
                                         -- 04/17/2020 pg2697 => add mce_flag and um_flag
                                         version_rec.mce_flag,
                                         version_rec.um_flag,
                                         -- 04/17/2020 pg2697 => add mce_flag and um_flag (end)
                                         version_rec.post_checkin_process_date);
                                EXCEPTION
                                    WHEN dup_val_on_index THEN
                                        NULL; -- skip duplicates
                                END;
                            ELSE
                                dbms_output.put_line('ERROR: ' ||
                                                     s_rec.mfr_number || ' ' ||
                                                     s_rec.service_number || ' ' ||
                                                     version ||
                                                     ' not found in EXT!');
                            END IF;
                            CLOSE in_ext_cur;
                        END IF;
                        CLOSE extract_cur;
                    ELSE
                        dbms_output.put_line(s_rec.mfr_number || ' ' ||
                                             s_rec.service_number ||
                                             ' not found!');
                    END IF;
                    CLOSE version_cur;
                END LOOP;
            END IF;
        ELSE
            --Mini-build  full_flag = 'F'
            LOOP
                BEGIN
                    utl_file.get_line(in_fhandle, line_in);
                    --2020/07/20 PAG - added set and use of product_code variable to clarify what was being passed into cursors
                    product_code := rtrim(line_in);

                    --2020/07/20 PAG - changed to use product_code variable
                    --OPEN product_country_cur(rtrim(line_in));
                    OPEN product_country_cur(product_code);
                    FETCH product_country_cur
                        INTO product_country_rec.country_abbr;
                    IF product_country_cur%FOUND
                    THEN

                        --2020/07/20 PAG - calls set_version_cursor to determine cursor select to be used
                        --product code must be passed in to get the flags associated to the correct product_code!!
                        --FOR s_rec IN service_cur(rtrim(line_in)) LOOP
                        --OPEN version_cur(s_rec.mfr_number,
                        --                   s_rec.service_number,
                        --                   version);
                        FOR s_rec IN service_cur(product_code)
                        LOOP

                            set_version_cursor(version_cur,
                                               full_flag,
                                               s_rec.mfr_number,
                                               s_rec.service_number,
                                               version,
                                               product_code);
                            FETCH version_cur
                                INTO version_rec;
                            -- 2020/07/20 PAG - calls set_version_cursor to determine cursor select to be used
                            IF version_cur%FOUND
                            THEN
                                --For Testing
                                --dbms_output.put_line(s_rec.mfr_number || ' ' ||
                                --                     s_rec.service_number ||
                                --                     ' => processing....');
                                --For Testing

                                --  if version_rec.post_checkin_process_date is null then
                                --     --error: service has been worked on in RACE and checked in (use current EXT version)
                                --     -- or post_checkin_process failed during move from RACE to EXT
                                --     dbms_output.put_line(s_rec.mfr_number || ' ' || s_rec.service_number || ' post checkin process date error.');
                                --     dbms_output.put_line('Using EXT version of service.');
                                --  end if;

                                OPEN barcode_cur(s_rec.mfr_number,
                                                 s_rec.service_number,
                                                 version);
                                FETCH barcode_cur
                                    INTO barcode_rec;
                                CLOSE barcode_cur;

                                -- 06/10/02 mm5095 => Pat requested that mini allow multiple countries (price is not important)
                                BEGIN
                                    bservicefound := TRUE;
                                    SELECT /*+ EXTRACT_SERVICE_BARCODES.service_country_select */
                                     country_abbr
                                      INTO my_country_abbr
                                      FROM service_country
                                     WHERE mfr_number = s_rec.mfr_number
                                       AND service_number =
                                           s_rec.service_number
                                       AND version_type = version
                                       AND rownum = 1
                                       AND (country_abbr = 'US' OR
                                           country_abbr = 'CA');
                                EXCEPTION
                                    WHEN no_data_found THEN
                                        -- get the first global you find
                                        BEGIN
                                            SELECT /*+ EXTRACT_SERVICE_BARCODES.service_country_select2 */
                                             country_abbr
                                              INTO my_country_abbr
                                              FROM service_country
                                             WHERE mfr_number =
                                                   s_rec.mfr_number
                                               AND service_number =
                                                   s_rec.service_number
                                               AND version_type = version
                                               AND rownum = 1;
                                        EXCEPTION
                                            WHEN no_data_found THEN
                                                bservicefound := FALSE;
                                        END;
                                END;

                                IF bservicefound
                                THEN
                                    OPEN in_ext_cur(s_rec.mfr_number,
                                                    s_rec.service_number,
                                                    version);
                                    FETCH in_ext_cur
                                        INTO in_ext_rec;
                                    IF in_ext_cur%FOUND
                                    THEN
                                        BEGIN
                                            INSERT /*+ EXTRACT_SERVICE_BARCODES.tmp_um_extract_insert4 */
                                            INTO tmp_um_extract
                                                (mfr_number,
                                                 service_number,
                                                 version_type,
                                                 product_code,
                                                 country_abbr,
                                                 barcode,
                                                 -- 04/17/2020 pg2697 => add mce_flag and um_flag
                                                 mce_flag,
                                                 um_flag,
                                                 -- 04/17/2020 pg2697 => add mce_flag and um_flag (end)
                                                 post_checkin_process_date)
                                            VALUES
                                                (s_rec.mfr_number,
                                                 s_rec.service_number,
                                                 version,
                                                 rtrim(line_in),
                                                 my_country_abbr,
                                                 barcode_rec.barcode,
                                                 -- 04/17/2020 pg2697 => add mce_flag and um_flag
                                                 version_rec.mce_flag,
                                                 version_rec.um_flag,
                                                 -- 04/17/2020 pg2697 => add mce_flag and um_flag (end)
                                                 version_rec.post_checkin_process_date);
                                        EXCEPTION
                                            WHEN dup_val_on_index THEN
                                                NULL; -- skip duplicates
                                        END;
                                    ELSE
                                        dbms_output.put_line('ERROR: ' ||
                                                             s_rec.mfr_number || ' ' ||
                                                             s_rec.service_number || ' ' ||
                                                             version ||
                                                             ' not found in EXT!');
                                    END IF;
                                    CLOSE in_ext_cur;
                                END IF;
                            ELSE
                                dbms_output.put_line(s_rec.mfr_number || ' ' ||
                                                     s_rec.service_number ||
                                                     ' not found!');
                            END IF;
                            CLOSE version_cur;
                        END LOOP;
                    END IF;
                    CLOSE product_country_cur;
                EXCEPTION
                    WHEN no_data_found THEN
                        EXIT; -- end of product codes in parameter file
                END;
            END LOOP;
        END IF;

        IF utl_file.is_open(in_fhandle)
        THEN
            utl_file.fclose(in_fhandle);
        END IF;

    EXCEPTION
        WHEN utl_file.invalid_path THEN
            utl_file.fclose(in_fhandle);
            raise_application_error(-20100, 'INVALID PATH');
        WHEN utl_file.invalid_mode THEN
            utl_file.fclose(in_fhandle);
            raise_application_error(-20101, 'INVALID MODE');
        WHEN utl_file.invalid_operation THEN
            utl_file.fclose(in_fhandle);
            raise_application_error(-20102, 'INVALID OPERATION');
        WHEN utl_file.invalid_filehandle THEN
            utl_file.fclose(in_fhandle);
            raise_application_error(-20103, 'INVALID FILEHANDLE');
        WHEN utl_file.write_error THEN
            utl_file.fclose(in_fhandle);
            raise_application_error(-20104, 'WRITE ERROR');
        WHEN utl_file.read_error THEN
            utl_file.fclose(in_fhandle);
            raise_application_error(-20105, 'READ ERROR');
        WHEN utl_file.internal_error THEN
            utl_file.fclose(in_fhandle);
            raise_application_error(-20106, 'INTERNAL ERROR');
            --  WHEN OTHERS THEN
        --    UTL_FILE.FCLOSE(in_fhandle);
        --    RAISE_APPLICATION_ERROR(-20107,'UNKNOWN ERROR');

    END extract_service_barcodes;

    /* ----------------------------------------------------------------------------- SET_EXTR_SERVICE_GROUP_CURSOR */
    PROCEDURE set_extr_service_group_cursor
    (
        cursor_parm IN OUT svcgrp_cur,
        run_type    IN VARCHAR2
    ) IS
    BEGIN

        IF run_type = 'FULL'
        THEN
            OPEN cursor_parm FOR
                SELECT /*+ SET_EXTR_SERVICE_GROUP_CURSOR.cursor_parm_full */
                DISTINCT a.barcode barcode,
                         a.mfr_number,
                         a.service_number,
                         a.version_type,
                         decode(to_year,
                                from_year,
                                from_year || NULL,
                                from_year || '-' || to_year) year_range,
                         mfr_name,
                         make_name,
                         model_name,
                         cd_volume,
                         post_checkin_process_date,
                         -- 02/08/2005 mm5095 => add vehicle category id
                         e.vehiclecategoryid,
                         -- 04/17/2020 pg2697 => added mce_flag and um_flag
                         a.mce_flag,
                         a.um_flag
                -- 04/17/2020 pg2697 => added mce_flag and um_flag (end)
                  FROM tmp_um_extract      a,
                       service_country     b,
                       um_service_location c,
                       mfr                 d,
                       vcd_vehicle_service e
                -- 02/08/2005 mm5095 => add vehicle category id
                 WHERE a.mfr_number = b.mfr_number
                   AND a.service_number = b.service_number
                   AND a.version_type = b.version_type
                   AND a.barcode = c.barcode(+)
                   AND a.mfr_number = d.mfr_number
                      -- 04/05/02 mm5095 => jim service_location bug fix
                   AND b.country_abbr IN ('US', 'CA')
                      --    and a.country_abbr = b.country_abbr
                      -- 04/05/02 mm5095 => jim service_location bug fix
                   AND extract_date IS NULL
                      -- 02/08/2005 mm5095 => add vehicle category id
                   AND e.manufacturernumber = b.mfr_number
                   AND e.servicenumber = b.service_number;
            -- 02/08/2005 mm5095 => add vehicle category id
        ELSE
            OPEN cursor_parm FOR
                SELECT /*+ SET_EXTR_SERVICE_GROUP_CURSOR.cursor_parm_mini */
                DISTINCT a.barcode barcode,
                         a.mfr_number,
                         a.service_number,
                         a.version_type,
                         decode(to_year,
                                from_year,
                                from_year || NULL,
                                from_year || '-' || to_year) year_range,
                         mfr_name,
                         make_name,
                         model_name,
                         cd_volume,
                         post_checkin_process_date,
                         -- 02/08/2005 mm5095 => add vehicle category id
                         e.vehiclecategoryid,
                         -- 04/17/2020 pg2697 => added mce_flag and um_flag
                         a.mce_flag,
                         a.um_flag
                -- 04/17/2020 pg2697 => added mce_flag and um_flag (end)
                  FROM tmp_um_extract      a,
                       service_country     b,
                       um_service_location c,
                       mfr                 d,
                       vcd_vehicle_service e
                -- 02/08/2005 mm5095 => add vehicle category id
                 WHERE a.mfr_number = b.mfr_number
                   AND a.service_number = b.service_number
                   AND a.version_type = b.version_type
                   AND a.barcode = c.barcode(+)
                   AND a.mfr_number = d.mfr_number
                   AND a.country_abbr = b.country_abbr
                   AND extract_date IS NULL
                      -- 02/08/2005 mm5095 => add vehicle category id
                   AND e.manufacturernumber = b.mfr_number
                   AND e.servicenumber = b.service_number;
            -- 02/08/2005 mm5095 => add vehicle category id;
        END IF;

    END set_extr_service_group_cursor;

    FUNCTION sf_getclass
    (
        mfr_in     VARCHAR2,
        service_in VARCHAR2
    ) RETURN VARCHAR2 IS
        CLASS VARCHAR2(3) := 'CEG';
        --07/23/2020 PAG-------------------------------------------------------------------------------------------------
        --  This should work for both FULL and MINI as it's using the FULL Product Codes only and service associations.
        --  When a new service is created, it is added to the appropriate product. (So all services that are in a MINI,
        --  should exist in a FULL product, and therefore, the appropriate product_class_code be found.)
        --07/23/2020 PAG-------------------------------------------------------------------------------------------------
    BEGIN
        SELECT b.product_class_code
          INTO CLASS
          FROM product_service a
         INNER JOIN product b
            ON b.product_code = a.product_code
              -- 01/03/2012 mm5095 => added UM_Flag check
              -- 04/17/2020 pg2697 => added MCE_flag check
           AND (b.um_flag = 'Y' OR b.mce_flag = 'Y')
        -- 04/17/2020 pg2697 => added MCE_flag check
         WHERE a.mfr_number = mfr_in
           AND a.service_number = service_in
              -- 12/30/2011 mm5095 => bug fix
           AND a.product_code NOT IN ('TT0990', 'PT0990')
              -- 12/30/2011 mm5095 => bug fix
           AND rownum = 1;
        RETURN CLASS;

    EXCEPTION
        WHEN OTHERS THEN
            RETURN CLASS;
    END;

    /************************************************************************/
    /* Program Name: extract_service_group                                  */
    /* Author:       MM5095                                                 */
    /* Last Modified: 10/08/2001                                            */
    /* Description: Creates service group text file                         */
    /************************************************************************/
    PROCEDURE extract_service_group
    (
        path         VARCHAR2,
        full_flag    CHAR,
        restart_flag CHAR,
        run_type     VARCHAR2
    ) IS

        -- 2008/12/31 PAG - Moved select associated to svcinfo_cur into procedure SET_EXTR_SERVICE_GROUP_CURSOR
        -- so that selection criteria can be changed based on run_type.
        svcinfo_cur svcgrp_cur;
        svcinfo_rec svcgrp_rec;
        -- 2008/12/31 PAG - Moved select associated to svcinfo_cur

        CURSOR mfr_cur(mfr_in VARCHAR2) IS
            SELECT /*+ EXTRACT_SERVICE_GROUP.mfr_cur */
             mfr_type
              FROM mfr
             WHERE mfr_number = mfr_in;
        mfr_rec mfr_cur%ROWTYPE;

        CURSOR service_cat_cur
        (
            mfr_in     VARCHAR2,
            service_in VARCHAR2,
            version_in VARCHAR2
        ) IS
            SELECT /*+ EXTRACT_SERVICE_GROUP.service_cat_cur */
             mfr_number,
             service_number
              FROM ext.service_category
             WHERE mfr_number = mfr_in
               AND service_number = service_in
               AND version_type = version_in;
        service_cat_rec service_cat_cur%ROWTYPE;

        srvc_fhandle utl_file.file_type;
        service_type NUMBER(1);
        cd_volume    NUMBER;
        last_barcode VARCHAR2(6) := ' ';
        CLASS        VARCHAR2(3);

    BEGIN
        -- 04/05/02 mm5095 => jim service_location bug fix
        IF full_flag = 'T'
           AND restart_flag = 'F'
        THEN
            EXECUTE IMMEDIATE 'truncate table um_extract';
        END IF;
        -- 04/05/02 mm5095 => jim service_location bug fix

        srvc_fhandle := utl_file.fopen(path, 'srvcgrp.txt', 'w');

        -- output reference sheet (always 1st)
        utl_file.put_line(srvc_fhandle, '000000|||2|1||||');

        -- output generic (always 2nd)
        utl_file.put_line(srvc_fhandle, '911000|||2|1||||');

        -- 2008/12/31 PAG - Moved select associated to svcinfo_cur into procedure SET_EXTR_SERVICE_GROUP_CURSOR
        -- so that selection criteria can be changed based on run_type.
        set_extr_service_group_cursor(svcinfo_cur, run_type);
        LOOP
            FETCH svcinfo_cur
                INTO svcinfo_rec;
            EXIT WHEN svcinfo_cur%NOTFOUND;
            --for rec in svcinfo_cur LOOP
            -- 2008/12/31 PAG - Moved select associated to svcinfo_cur into procedure SET_EXTR_SERVICE_GROUP_CURSOR
            IF svcinfo_rec.barcode != last_barcode
            THEN
                -- validate that service in EXT
                OPEN service_cat_cur(svcinfo_rec.mfr_number,
                                     svcinfo_rec.service_number,
                                     svcinfo_rec.version_type);
                FETCH service_cat_cur
                    INTO service_cat_rec;
                IF service_cat_cur%FOUND
                THEN

                    -- 11/03/03 mm5095 =>
                    IF full_flag = 'T'
                    THEN
                        --    if full_flag = 'T' and restart_flag = 'F' then
                        -- 11/03/03 mm5095 =>
                        BEGIN
                            INSERT /*+ EXTRACT_SERVICE_GROUP.um_extract_insert */
                            INTO um_extract
                                (mfr_number,
                                 service_number,
                                 version_type,
                                 product_code,
                                 country_abbr,
                                 barcode,
                                 -- 04/17/2020 pg2697 => add mce_flag and um_flag
                                 mce_flag,
                                 um_flag,
                                 -- 04/17/2020 pg2697 => add mce_flag and um_flag (end)
                                 post_checkin_process_date)
                            VALUES
                                (svcinfo_rec.mfr_number,
                                 svcinfo_rec.service_number,
                                 svcinfo_rec.version_type,
                                 'UMFULL',
                                 'US',
                                 svcinfo_rec.barcode,
                                 -- 04/17/2020 pg2697 => add mce_flag and um_flag
                                 svcinfo_rec.mce_flag,
                                 svcinfo_rec.um_flag,
                                 -- 04/17/2020 pg2697 => add mce_flag and um_flag (end)
                                 svcinfo_rec.post_checkin_process_date);
                            COMMIT;
                            -- 11/03/03 mm5095 =>
                        EXCEPTION
                            WHEN dup_val_on_index THEN
                                NULL;
                        END;
                        -- 11/03/03 mm5095 =>
                    ELSE
                        BEGIN
                            INSERT /*+ EXTRACT_SERVICE_GROUP.um_extract_insert 2*/
                            INTO tmp_um_extract
                                (mfr_number,
                                 service_number,
                                 version_type,
                                 product_code,
                                 country_abbr,
                                 barcode,
                                 -- 04/17/2020 pg2697 => add mce_flag and um_flag
                                 mce_flag,
                                 um_flag,
                                 -- 04/17/2020 pg2697 => add mce_flag and um_flag (end)
                                 post_checkin_process_date)
                            VALUES
                                (svcinfo_rec.mfr_number,
                                 svcinfo_rec.service_number,
                                 svcinfo_rec.version_type,
                                 'UMMINI',
                                 'US',
                                 svcinfo_rec.barcode,
                                 -- 04/17/2020 pg2697 => add mce_flag and um_flag
                                 svcinfo_rec.mce_flag,
                                 svcinfo_rec.um_flag,
                                 -- 04/17/2020 pg2697 => add mce_flag and um_flag (end)
                                 svcinfo_rec.post_checkin_process_date);

                            -- 11/03/03 mm5095 =>
                        EXCEPTION
                            WHEN dup_val_on_index THEN
                                NULL;
                        END;
                    END IF;

                    -- get mfr_type
                    OPEN mfr_cur(svcinfo_rec.mfr_number);
                    FETCH mfr_cur
                        INTO mfr_rec;
                    CLOSE mfr_cur;

                    CLASS := sf_getclass(svcinfo_rec.mfr_number,
                                         svcinfo_rec.service_number);

                    ---------------------------------------------------------------------------
                    -- Service_Type:  1=CEG, 2=Reference Sheet, 3=ATG, 4=OlderModel, 5=HTD/MTD
                    ---------------------------------------------------------------------------
                    service_type := 1; -- default to CEG

                    -- 04/21/2011 mm5095 => add support for mtd/htd
                    IF CLASS IN ('HTD', 'MTD')
                    THEN
                        service_type := 5;
                        -- 04/21/2011 mm5095 => add support for mtd/htd
                    ELSIF svcinfo_rec.mfr_number = '006'
                    THEN
                        service_type := 3; -- ATG
                        cd_volume    := 1;
                    ELSIF svcinfo_rec.barcode = '911000'
                    THEN
                        -- reference sheet
                        service_type := 2;
                    END IF;

                    IF svcinfo_rec.cd_volume IS NULL
                    THEN
                        -- 01/19/2005 mm5095 => added support for motorcycles and RVs
                        -- Note; Motorcycles, RVs, Marine, ATVs, Snowmobiles, CHT and CMT are all assigned cd_volume=4
                        IF svcinfo_rec.mfr_number > '099'
                        THEN
                            cd_volume := 4;
                        ELSE
                            -- 01/19/2005 mm5095 => added support for motorcycles and RVs
                            cd_volume := 2;
                        END IF;
                    ELSE
                        cd_volume := svcinfo_rec.cd_volume;
                    END IF;

                    -- 07/19/02 mm5095 => fix missing older model service_type
                    IF service_type = 1
                       AND cd_volume = 1
                    THEN
                        service_type := 4; -- older model
                    END IF;
                    -- 07/19/02 mm5095 => fix missing older model service_type

                    -- 04/17/2020 pg2697 => bypass writing MCE-Only Services to srvcgrp.txt file (MCE-Only is: MCE=Y; UM=N)
                    IF svcinfo_rec.um_flag = 'Y'
                    THEN
                        -- 04/17/2020 pg2697 => bypass writing MCE-Only Services to srvcgrp.txt (UM-used) file
                        utl_file.put_line(srvc_fhandle,
                                          svcinfo_rec.barcode || '|' ||
                                          svcinfo_rec.mfr_number || '|' ||
                                          mfr_rec.mfr_type || '|' ||
                                          service_type || '|' || cd_volume || '|' ||
                                          svcinfo_rec.mfr_name || '|' ||
                                          svcinfo_rec.year_range || '|' ||
                                          svcinfo_rec.make_name || '|' ||
                                          svcinfo_rec.model_name || '|' ||
                                          svcinfo_rec.vehiclecategoryid);
                        -- 04/17/2020 pg2697 => bypass writing MCE-Only Services to srvcgrp.txt file
                    END IF;
                    -- 04/17/2020 pg2697 => bypass writing MCE-Only Services to srvcgrp.txt file
                ELSE
                    -- error: service not found in EXT
                    dbms_output.put_line('ERROR: ' ||
                                         svcinfo_rec.mfr_number || ' ' ||
                                         svcinfo_rec.service_number || ' ' ||
                                         svcinfo_rec.version_type ||
                                         ' not found on EXT!');
                END IF;
                CLOSE service_cat_cur;
            END IF;
            last_barcode := svcinfo_rec.barcode;
        END LOOP;
        -- 2008/12/31 PAG - Moved select associated to svcinfo_cur into procedure SET_EXTR_SERVICE_GROUP_CURSOR
        CLOSE svcinfo_cur;
        -- 2008/12/31 PAG - Moved select associated to svcinfo_cur into procedure SET_EXTR_SERVICE_GROUP_CURSOR

        -- update semaphore file
        -- 11/21/2012 mm5095 => to support creation of SupplierXref
        sp_update_globaltxt_semaphore(path,
                                      'global.txt',
                                      'a',
                                      'srvcgrp.txt');
        --  sp_update_globaltxt_semaphore(path, 'global.txt', 'w', 'srvcgrp.txt');
        -- 11/21/2012 mm5095 => to support creation of SupplierXref

        -- close files, if open
        IF utl_file.is_open(srvc_fhandle)
        THEN
            utl_file.fclose(srvc_fhandle);
        END IF;

    EXCEPTION
        WHEN utl_file.invalid_path THEN
            utl_file.fclose_all;
            raise_application_error(-20100, 'INVALID PATH');
        WHEN utl_file.invalid_mode THEN
            utl_file.fclose_all;
            raise_application_error(-20101, 'INVALID MODE');
        WHEN utl_file.invalid_operation THEN
            utl_file.fclose_all;
            raise_application_error(-20102, 'INVALID OPERATION');
        WHEN utl_file.invalid_filehandle THEN
            utl_file.fclose_all;
            raise_application_error(-20103, 'INVALID FILEHANDLE');
        WHEN utl_file.write_error THEN
            utl_file.fclose_all;
            raise_application_error(-20104, 'WRITE ERROR');
        WHEN utl_file.read_error THEN
            utl_file.fclose_all;
            raise_application_error(-20105, 'READ ERROR');
        WHEN utl_file.internal_error THEN
            utl_file.fclose_all;
            raise_application_error(-20106, 'INTERNAL ERROR');
            --  WHEN OTHERS THEN
        --    UTL_FILE.FCLOSE_ALL;
        --    RAISE_APPLICATION_ERROR(-20107,'UNKNOWN ERROR');

    END extract_service_group;

    /************************************************************************/
    /* Program Name:  build_user_refinish_complete                          */
    /* Author:       MM5095       .                                         */
    /* Last Modified: 09/20/2001                                            */
    /* Description: Creates t_user_refinish_complete table from             */
    /* refinish_complete table.                                             */
    /************************************************************************/
    PROCEDURE build_user_refinish_complete
    --PROCEDURE BUILD_USER_REFINISH_COMPLETE(version varchar2)
     IS
        CURSOR c1_cur IS
            SELECT /*+ BUILD_USER_REFINISH_COMPLETE.c1_cur */
             sequence_number,
             hdr_prtc_body,
             dtl_prtc_body
              FROM refinish_complete a,
                   prtc_calc_type    b
             WHERE a.hdr_prtc_body = b.prtc_body
               AND a.calc_type = b.calc_type
               AND a.calc_type = 'REF'
             ORDER BY sequence_number,
                      dtl_prtc_body;

        /*****  -- 07/02/04 tmc => WIP tables removed - All processing now uses PR only
          -- WIP version
          cursor c1_wip_cur is
          select sequence_number, hdr_prtc_body, dtl_prtc_body
          from refinish_complete_wip a, prtc_calc_type_wip b
          where a.hdr_prtc_body = b.prtc_body
          and a.calc_type = b.calc_type
          and a.calc_type = 'REF'
          order by sequence_number, dtl_prtc_body;
        *****/

        last_sequence NUMBER := -1;
        header_seq    NUMBER := 0;
        item_seq      NUMBER;

    BEGIN
        DELETE /*+ BUILD_USER_REFINISH_COMPLETE.tmp_um_refinish_complete_delete */
        FROM tmp_um_refinish_complete;

        --  if version = 'PR' then        -- 07/02/04 tmc => WIP tables removed - All processing now uses PR only
        FOR c1_rec IN c1_cur
        LOOP
            IF last_sequence != c1_rec.sequence_number
            THEN
                header_seq := header_seq + 1;
                item_seq   := 0;
                BEGIN
                    INSERT /*+ BUILD_USER_REFINISH_COMPLETE.tmp_um_refinish_complete_insert */
                    INTO tmp_um_refinish_complete
                    VALUES
                        (header_seq,
                         item_seq,
                         c1_rec.hdr_prtc_body);
                EXCEPTION
                    WHEN OTHERS THEN
                        NULL;
                END;
                last_sequence := c1_rec.sequence_number;
            END IF;

            BEGIN
                item_seq := item_seq + 1;
                INSERT /*+ BUILD_USER_REFINISH_COMPLETE.tmp_um_refinish_complete_insert2 */
                INTO tmp_um_refinish_complete
                VALUES
                    (header_seq,
                     item_seq,
                     c1_rec.dtl_prtc_body);
            EXCEPTION
                WHEN OTHERS THEN
                    NULL;
            END;
        END LOOP;
        /*****  -- 07/02/04 tmc => WIP tables removed - All processing now uses PR only
          else
            for c1_rec in c1_wip_cur LOOP
              if last_sequence != c1_rec.sequence_number then
                header_seq := header_seq + 1;
                item_seq := 0;
                BEGIN
                  insert into tmp_um_refinish_complete
                  values(header_seq, item_seq, c1_rec.hdr_prtc_body);
                EXCEPTION when others then
                  null;
                END;
                last_sequence := c1_rec.sequence_number;
              end if;

              BEGIN
                item_seq := item_seq + 1;
                insert into tmp_um_refinish_complete
                values(header_seq, item_seq, c1_rec.dtl_prtc_body);
              EXCEPTION when others then
                null;
              END;
            END LOOP;
          end if;
        *****/
    END build_user_refinish_complete;

    /************************************************************************/
    /* Program Name: extract_alternate_parts                                */
    /* Author:       MM5095                                                 */
    /* Last Modified: 09/20/2001                                            */
    /* Description: Creates alternate part supplier list                    */
    /************************************************************************/
    PROCEDURE extract_alternate_parts(path VARCHAR2) IS
        CURSOR altpart_sup_cur IS
            SELECT /*+ EXTRACT_ALTERNATE_PARTS.altpart_sup_cur */
             *
              FROM altpart_supplier
            --11/17/2004 mm5095 => added support for MAPP v2.5 enhancements
             WHERE part_count > 0
               AND delete_date IS NULL;
        --11/17/2004 mm5095 => added support for MAPP v2.5 enhancements
        out_fhandle utl_file.file_type;

    BEGIN

        out_fhandle := utl_file.fopen(path, 'altprtsp.txt', 'w');

        FOR rec IN altpart_sup_cur
        LOOP
            utl_file.put_line(out_fhandle,
                              rec.altpart_supplier_number || '|' ||
                              rec.altpart_supplier_name || '|' ||
                              rec.address_line1 || '|' || rec.address_line2 || '|' ||
                              rec.city || '|' || rec.state_abbr || '|' ||
                              rec.zip_code || '|' || rec.primary_phone || '|' ||
                              rec.secondary_phone || '|' ||
                              rec.oem_discount_flag);
        END LOOP;

        -- update semaphore file
        sp_update_globaltxt_semaphore(path,
                                      'global.txt',
                                      'a',
                                      'altprtsp.txt');

        -- close files, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

    EXCEPTION
        WHEN utl_file.invalid_path THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20100, 'INVALID PATH');
        WHEN utl_file.invalid_mode THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20101, 'INVALID MODE');
        WHEN utl_file.invalid_operation THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20102, 'INVALID OPERATION');
        WHEN utl_file.invalid_filehandle THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20103, 'INVALID FILEHANDLE');
        WHEN utl_file.write_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20104, 'WRITE ERROR');
        WHEN utl_file.read_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20105, 'READ ERROR');
        WHEN utl_file.internal_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20106, 'INTERNAL ERROR');
            --  WHEN OTHERS THEN
        --    UTL_FILE.FCLOSE(OUT_FHANDLE);
        --    RAISE_APPLICATION_ERROR(-20107,'UNKNOWN ERROR');
    END extract_alternate_parts;

    /************************************************************************/
    /* Program Name: extract_disclaimer                                     */
    /* Author:       MM5095       .                                         */
    /* Last Modified: 10/09/2001                                            */
    /************************************************************************/
    PROCEDURE extract_disclaimer(path VARCHAR2) IS
        CURSOR c1_cur IS
            SELECT /*+ EXTRACT_DISCLAIMER.c1_cur */
             *
              FROM disclaimer;
        out_fhandle     utl_file.file_type;
        wrap_text       VARCHAR2(1000);
        nline           NUMBER(1);
        npos            NUMBER;
        max_line_length NUMBER := 132;

    BEGIN

        out_fhandle := utl_file.fopen(path, 'disclaim.txt', 'w');

        FOR c1_rec IN c1_cur
        LOOP
            -- 02/05/03 mm5095 => correct for bad data in authoring system
            wrap_text := REPLACE(c1_rec.disclaimer_text, '|');
            wrap_text := REPLACE(wrap_text, chr(10));
            wrap_text := REPLACE(wrap_text, chr(13));
            --    wrap_text := c1_rec.disclaimer_text;
            -- 02/05/03 mm5095 => correct for bad data in authoring system
            nline := 1;

            WHILE TRUE
            LOOP
                IF length(wrap_text) > max_line_length
                THEN
                    npos := instr(wrap_text,
                                  ' ',
                                  max_line_length - length(wrap_text),
                                  1);
                    IF npos > 0
                    THEN
                        utl_file.put_line(out_fhandle,
                                          c1_rec.state_abbr || '|' || nline || '|' ||
                                          substr(wrap_text, 1, npos - 1));
                        wrap_text := substr(wrap_text, npos + 1);
                        nline     := nline + 1;
                    ELSE
                        utl_file.put_line(out_fhandle,
                                          c1_rec.state_abbr || '|' || nline || '|' ||
                                          wrap_text);
                        EXIT;
                    END IF;
                ELSE
                    utl_file.put_line(out_fhandle,
                                      c1_rec.state_abbr || '|' || nline || '|' ||
                                      wrap_text);
                    EXIT;
                END IF;
            END LOOP;
        END LOOP;

        -- update semaphore file
        sp_update_globaltxt_semaphore(path,
                                      'global.txt',
                                      'a',
                                      'disclaim.txt');

        -- close files, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;
    EXCEPTION
        WHEN utl_file.invalid_path THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20100, 'INVALID PATH');
        WHEN utl_file.invalid_mode THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20101, 'INVALID MODE');
        WHEN utl_file.invalid_operation THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20102, 'INVALID OPERATION');
        WHEN utl_file.invalid_filehandle THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20103, 'INVALID FILEHANDLE');
        WHEN utl_file.write_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20104, 'WRITE ERROR');
        WHEN utl_file.read_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20105, 'READ ERROR');
        WHEN utl_file.internal_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20106, 'INTERNAL ERROR');
            --  WHEN OTHERS THEN
        --    UTL_FILE.FCLOSE(OUT_FHANDLE);
        --    RAISE_APPLICATION_ERROR(-20107,'UNKNOWN ERROR');
    END extract_disclaimer;

    /************************************************************************/
    /* Program Name: extract_disclosure                                     */
    /* Author:       MM5095       .                                         */
    /* Last Modified: 03/23/2016                                            */
    /************************************************************************/
    PROCEDURE extract_disclosure(path VARCHAR2) IS
        CURSOR c1_cur IS
            SELECT /*+ EXTRACT_DISCLOSURE.c1_cur */
             *
              FROM disclosure;
        out_fhandle     utl_file.file_type;
        wrap_text       VARCHAR2(1000);
        nline           NUMBER(1);
        npos            NUMBER;
        max_line_length NUMBER := 132;

    BEGIN

        out_fhandle := utl_file.fopen(path, 'disclosure.txt', 'w');

        FOR c1_rec IN c1_cur
        LOOP
            -- 02/05/03 mm5095 => correct for bad data in authoring system
            wrap_text := REPLACE(c1_rec.disclosure_text, '|');
            wrap_text := REPLACE(wrap_text, chr(10));
            wrap_text := REPLACE(wrap_text, chr(13));
            --    wrap_text := c1_rec.disclaimer_text;
            -- 02/05/03 mm5095 => correct for bad data in authoring system
            nline := 1;

            WHILE TRUE
            LOOP
                IF length(wrap_text) > max_line_length
                THEN
                    npos := instr(wrap_text,
                                  ' ',
                                  max_line_length - length(wrap_text),
                                  1);
                    IF npos > 0
                    THEN
                        utl_file.put_line(out_fhandle,
                                          c1_rec.state_abbr || '|' || nline || '|' ||
                                          substr(wrap_text, 1, npos - 1));
                        wrap_text := substr(wrap_text, npos + 1);
                        nline     := nline + 1;
                    ELSE
                        utl_file.put_line(out_fhandle,
                                          c1_rec.state_abbr || '|' || nline || '|' ||
                                          wrap_text);
                        EXIT;
                    END IF;
                ELSE
                    utl_file.put_line(out_fhandle,
                                      c1_rec.state_abbr || '|' || nline || '|' ||
                                      wrap_text);
                    EXIT;
                END IF;
            END LOOP;
        END LOOP;

        -- update semaphore file
        sp_update_globaltxt_semaphore(path,
                                      'global.txt',
                                      'a',
                                      'disclosure.txt');

        -- close files, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;
    EXCEPTION
        WHEN utl_file.invalid_path THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20100, 'INVALID PATH');
        WHEN utl_file.invalid_mode THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20101, 'INVALID MODE');
        WHEN utl_file.invalid_operation THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20102, 'INVALID OPERATION');
        WHEN utl_file.invalid_filehandle THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20103, 'INVALID FILEHANDLE');
        WHEN utl_file.write_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20104, 'WRITE ERROR');
        WHEN utl_file.read_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20105, 'READ ERROR');
        WHEN utl_file.internal_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20106, 'INTERNAL ERROR');
            --  WHEN OTHERS THEN
        --    UTL_FILE.FCLOSE(OUT_FHANDLE);
        --    RAISE_APPLICATION_ERROR(-20107,'UNKNOWN ERROR');
    END extract_disclosure;
    /* ----------------------------------------------------------------------------- EXTRACT_MMCATG */
    PROCEDURE extract_mmcatg(path VARCHAR2) IS
        CURSOR c1_cur IS
        --2009/07/27 - PAG - corrected select to include sequence_number
        --  select /*+ EXTRACT_MMCATG.c1_cur */ altpart_class_code || altpart_class_code
        --2009/07/27 - PAG - corrected select to include sequence_number
        --  2012/08/08 mm5095 => added to support NSF
            SELECT /*+ EXTRACT_MMCATG.c1_cur */
             altpart_class_code,
             lpad(mapp_matrix_sequence_number, 3, '0') mapp_matrix_sequence_number,
             rpad(substr(description, 1, 24), 24, ' ') description,
             decode(reconditioned_flag, 'Y', 1, 0) reconditioned_flag,
             to_char(create_date, 'YYDDD') create_date,
             to_char(last_update_date, 'YYDDD') last_update_date,
             certified_flag
              FROM altpart_class
             ORDER BY 1,
                      2,
                      3,
                      4,
                      5,
                      6,
                      7;

        /*
          select /*+ EXTRACT_MMCATG.c1_cur / altpart_class_code || lpad(mapp_matrix_sequence_number,3,'0')
          || rpad(substr(description,1,24), 24, ' ') || decode(reconditioned_flag,'Y',1,0) ||
          to_char(create_date,'YYDDD') || to_char(last_update_date,'YYDDD') ||
          capa_certified_flag output_text
          from altpart_class
          order by 1;
        */
        --  2012/08/08 mm5095 => added to support NSF

        out_fhandle utl_file.file_type;

    BEGIN

        out_fhandle := utl_file.fopen(path, 'mmcatg.seq', 'w');

        FOR rec IN c1_cur
        LOOP

            --  2012/08/08 mm5095 => added to support NSF
            utl_file.put_line(out_fhandle,
                              rec.altpart_class_code ||
                              rec.mapp_matrix_sequence_number ||
                              rec.description || rec.reconditioned_flag ||
                              rec.create_date || rec.last_update_date ||
                              rec.certified_flag);

        --    utl_file.put_line(out_fhandle, rec.output_text);
        --  2012/08/08 mm5095 => added to support NSF
        END LOOP;
        -- update semaphore file
        sp_update_globaltxt_semaphore(path,
                                      'global.txt',
                                      'a',
                                      'mmcatg.seq');

        -- close files, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;
    EXCEPTION
        WHEN utl_file.invalid_path THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20100, 'INVALID PATH');
        WHEN utl_file.invalid_mode THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20101, 'INVALID MODE');
        WHEN utl_file.invalid_operation THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20102, 'INVALID OPERATION');
        WHEN utl_file.invalid_filehandle THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20103, 'INVALID FILEHANDLE');
        WHEN utl_file.write_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20104, 'WRITE ERROR');
        WHEN utl_file.read_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20105, 'READ ERROR');
        WHEN utl_file.internal_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20106, 'INTERNAL ERROR');
            --  WHEN OTHERS THEN
        --    UTL_FILE.FCLOSE(OUT_FHANDLE);
        --    RAISE_APPLICATION_ERROR(-20107,'UNKNOWN ERROR');
    END extract_mmcatg;

    /* ----------------------------------------------------------------------------- EXTRACT_PDR */
    -- 05/02/05 mm5095 => added support for PDR
    PROCEDURE extract_pdr(path VARCHAR2) IS

        CURSOR company_cur IS
            SELECT /*+ EXTRACT_PDR.company_cur */
             *
              FROM pdr_company
             WHERE active_flag = 'Y'
               AND um_flag = 'Y'
             ORDER BY company_id;

        CURSOR markup_cur(id NUMBER) IS
            SELECT /*+ EXTRACT_PDR.markup_cur */
             *
              FROM pdr_company_markup
             WHERE company_id = id
             ORDER BY criteria_id;

        CURSOR pricelabor_cur(id NUMBER) IS
            SELECT /*+ EXTRACT_PDR.priceLabor_cur */
             MAX(dent_count),
             1 pricelaborind
              FROM pdr_dent_wizard_matrix
             WHERE company_id = id
            UNION
            SELECT MAX(dent_count),
                   2 pricelaborind
              FROM pdr_labor_hours
             WHERE company_id = id;

        CURSOR prtc_cur IS
            SELECT /*+ EXTRACT_PDR.prtc_cur */
             a.panel_id,
             a.panel_name,
             b.prtc_body
              FROM pdr_panels           a,
                   pdr_dent_wizard_prtc b
             WHERE a.panel_id = b.panel_id
             ORDER BY 1;

        CURSOR lookup_cur IS
            SELECT /*+ EXTRACT_PDR.lookup_cur */
             company_id,
             panel_id,
             dent_value,
             dent_count,
             decode(rr_flag, 'N', dollar_amount, -2) price_or_labor
              FROM pdr_dent_wizard_matrix
            UNION
            SELECT company_id,
                   dent_count panel_id,
                   dent_value,
                   dent_count,
                   round(labor_hours * 100)
              FROM pdr_labor_hours
             ORDER BY 1,
                      2,
                      3,
                      4;

        out_fhandle   utl_file.file_type;
        maxdentcount  INTEGER;
        pricelaborind INTEGER;
        bfound        BOOLEAN := FALSE;

        -- 2006/06/07 mm5095 => Editorial enhancement request to eliminate need to enter 0 values
        company_id NUMBER := -999;
        panel_id   NUMBER := -999;
        dent_value NUMBER := -999;
        dent_count NUMBER := -999;
        bfirsttime BOOLEAN := TRUE;
        -- 2006/06/07 mm5095 => Editorial enhancement request to eliminate need to enter 0 values

    BEGIN
        FOR company_rec IN company_cur
        LOOP
            IF bfound = FALSE
            THEN
                -- create dbCorec output
                out_fhandle := utl_file.fopen(path, 'dbCorec.txt', 'w');
                bfound      := TRUE;
            END IF;

            utl_file.put(out_fhandle,
                         company_rec.company_abbr || '|' ||
                         company_rec.company_id);

            FOR rec IN markup_cur(company_rec.company_id)
            LOOP
                utl_file.put(out_fhandle, '|' || rec.percent_markup);
            END LOOP;

            OPEN pricelabor_cur(company_rec.company_id);
            FETCH pricelabor_cur
                INTO maxdentcount,
                     pricelaborind;
            CLOSE pricelabor_cur;

            utl_file.put_line(out_fhandle,
                              '|' || pricelaborind || '|' || maxdentcount);
        END LOOP;

        IF bfound
        THEN
            utl_file.fflush(out_fhandle);

            -- close file, if open
            IF utl_file.is_open(out_fhandle)
            THEN
                utl_file.fclose(out_fhandle);
            END IF;

            -- update semaphore file
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'dbCorec.txt');

            bfound := FALSE;

            FOR rec IN prtc_cur
            LOOP
                IF bfound = FALSE
                THEN
                    -- create dbPanelsPRTCrec output
                    out_fhandle := utl_file.fopen(path, 'dbPanels.txt', 'w');
                    bfound      := TRUE;
                END IF;

                utl_file.put_line(out_fhandle,
                                  rec.prtc_body || '|' || rec.panel_id || '|' ||
                                  rec.panel_name);
            END LOOP;

            IF bfound
            THEN
                utl_file.fflush(out_fhandle);

                -- close file, if open
                IF utl_file.is_open(out_fhandle)
                THEN
                    utl_file.fclose(out_fhandle);
                END IF;

                -- update semaphore file
                sp_update_globaltxt_semaphore(path,
                                              'global.txt',
                                              'a',
                                              'dbPanels.txt');
            END IF;

            bfound := FALSE;

            FOR rec IN lookup_cur
            LOOP
                IF bfound = FALSE
                THEN
                    -- create dbLookUprec output
                    out_fhandle := utl_file.fopen(path, 'dbLookup.txt', 'w');
                    bfound      := TRUE;
                END IF;

                -- 2006/06/07 mm5095 => Editorial enhancement request to eliminate need to enter 0 values
                IF bfirsttime
                THEN
                    company_id := rec.company_id;
                    panel_id   := rec.panel_id;
                    dent_value := rec.dent_value;
                    dent_count := rec.dent_count;
                    bfirsttime := FALSE;
                END IF;

                IF (rec.company_id != company_id OR
                   rec.panel_id != panel_id OR
                   rec.dent_value != dent_value)
                THEN
                    FOR n IN dent_count + 1 .. 300
                    LOOP
                        utl_file.put_line(out_fhandle,
                                          company_id || '|' || panel_id || '|' ||
                                          dent_value || '|' || n || '|' || '-2');
                    END LOOP;
                    company_id := rec.company_id;
                    panel_id   := rec.panel_id;
                    dent_value := rec.dent_value;
                END IF;
                -- 2006/06/07 mm5095 => Editorial enhancement request to eliminate need to enter 0 values

                utl_file.put_line(out_fhandle,
                                  rec.company_id || '|' || rec.panel_id || '|' ||
                                  rec.dent_value || '|' || rec.dent_count || '|' ||
                                  rec.price_or_labor);

                -- 2006/06/07 mm5095 => Editorial enhancement request to eliminate need to enter 0 values
                dent_count := rec.dent_count;
                -- 2006/06/07 mm5095 => Editorial enhancement request to eliminate need to enter 0 values

            END LOOP;

            IF bfound
            THEN
                utl_file.fflush(out_fhandle);

                -- close file, if open
                IF utl_file.is_open(out_fhandle)
                THEN
                    utl_file.fclose(out_fhandle);
                END IF;

                -- update semaphore file
                sp_update_globaltxt_semaphore(path,
                                              'global.txt',
                                              'a',
                                              'dbLookup.txt');
            END IF;
        END IF;
    EXCEPTION
        WHEN utl_file.invalid_path THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20100, 'INVALID PATH');
        WHEN utl_file.invalid_mode THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20101, 'INVALID MODE');
        WHEN utl_file.invalid_operation THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20102, 'INVALID OPERATION');
        WHEN utl_file.invalid_filehandle THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20103, 'INVALID FILEHANDLE');
        WHEN utl_file.write_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20104, 'WRITE ERROR');
        WHEN utl_file.read_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20105, 'READ ERROR');
        WHEN utl_file.internal_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20106, 'INTERNAL ERROR');
            --  WHEN OTHERS THEN
        --    UTL_FILE.FCLOSE(OUT_FHANDLE);
        --    RAISE_APPLICATION_ERROR(-20107,'UNKNOWN ERROR');
    END extract_pdr;
    -- 05/02/05 mm5095 => added support for PDR

    /* ----------------------------------------------------------------------------- EXTRACT_RV_MATRICES */
    -- 04/18/2006 mm5095 => added support for RV_Matrices um6.5
    -- 08/01/2007 jr6600 => RV_Matrices substantially changed in support
    --                      of Marine Calculators.  One set of combined
    --                      tables for similar data / functionality.
    PROCEDURE extract_rv_matrices(path VARCHAR2) IS
        CURSOR rv_labor_matrix_cur IS
            SELECT /*+ EXTRACT_RV_MATRICES.rv_labor_matrix_cur */
             material_skey,
             procedure_skey,
             square_inch,
             labor_time
              FROM race.spec_calc_matrix
             WHERE vehicle_class_type = 'RV'
             ORDER BY material_skey,
                      procedure_skey,
                      square_inch;

        CURSOR rv_procedure_cur IS
            SELECT /*+ EXTRACT_RV_MATRICES.rv_procedure_cur */
             procedure_skey,
             procedure_name
              FROM race.spec_calc_procedure
             WHERE vehicle_class_type = 'RV'
             ORDER BY procedure_skey;

        CURSOR rv_category_prtc_cur IS
            SELECT /*+ EXTRACT_RV_MATRICES.rv_category_prtc_cur */
             b.category_name category_name,
             decode(c.category_name,
                    '<Blank>',
                    b.category_name,
                    c.category_name) subcategory_name,
             prtc_body,
             spec_calc_type_skey
              FROM race.spec_calc_category_prtc_xref a,
                   category                          b,
                   category                          c
             WHERE a.vehicle_class_type = 'RV'
               AND b.category_skey = a.category_skey
               AND c.category_skey = a.subcategory_skey;

        CURSOR rv_calculator_type_cur IS
            SELECT /*+ EXTRACT_RV_MATRICES.rv_calculator_type_cur */
             spec_calc_type_skey,
             spec_calc_type
              FROM race.spec_calc_type
             WHERE vehicle_class_type = 'RV';

        -- >> jr6600 additions for new tables
        CURSOR rv_material_cur IS
            SELECT /*+ EXTRACT_RV_MATRICES.rv_material_cur */
             material_skey,
             material_name
              FROM race.spec_calc_material
             WHERE vehicle_class_type = 'RV'
             ORDER BY material_skey;

        CURSOR rv_panel_cur IS
            SELECT /*+ EXTRACT_RV_MATRICES.rv_panel_cur */
             panel_skey,
             panel_name
              FROM race.spec_calc_panel
             WHERE vehicle_class_type = 'RV'
             ORDER BY panel_skey;

        CURSOR rv_siding_cur IS
            SELECT /*+ EXTRACT_RV_MATRICES.rv_siding_cur */
             siding_skey,
             siding_name
              FROM race.spec_calc_siding
             WHERE vehicle_class_type = 'RV'
             ORDER BY siding_skey;

        CURSOR rv_material_matrix_cur IS
            SELECT /*+ EXTRACT_RV_MATRICES.rv_material_matrix_cur */
             panel_skey,
             material_skey,
             siding_skey,
             current_price,
             seamed_material_flag
              FROM race.spec_calc_material_matrix
             WHERE vehicle_class_type = 'RV'
             ORDER BY panel_skey,
                      material_skey,
                      siding_skey;

        CURSOR rv_list_material_xref_cur IS
            SELECT /*+ EXTRACT_RV_MATRICES.rv_list_material_xref_cur */
             list_skey,
             material_skey
              FROM race.spec_calc_list_material_xref
             WHERE vehicle_class_type = 'RV'
             ORDER BY list_skey;

        CURSOR rv_um_list_cur IS
            SELECT /*+ EXTRACT_RV_MATRICES.rv_um_list_cur */
             list_skey,
             description
              FROM race.spec_calc_um_list
             WHERE vehicle_class_type = 'RV'
             ORDER BY list_skey;

        CURSOR rv_font_size_cur IS
            SELECT /*+ EXTRACT_RV_MATRICES.rv_font_size_cur */
             lettering_weight_skey,
             weight_type,
             weight_factor
              FROM race.spec_calc_lettering_weight
             WHERE vehicle_class_type = 'RV'
             ORDER BY lettering_weight_skey;

        CURSOR rv_lettering_type_cur IS
            SELECT /*+ EXTRACT_RV_MATRICES.rv_lettering_type_cur */
             lettering_style_skey,
             style_name,
             style_factor
              FROM race.spec_calc_lettering_style
             WHERE vehicle_class_type = 'RV'
             ORDER BY lettering_style_skey;

        CURSOR rv_graphic_type_cur IS
            SELECT /*+ EXTRACT_RV_MATRICES.rv_graphic_type_cur */
             graphic_skey,
             graphic_name,
             graphic_factor
              FROM race.spec_calc_graphic_type
             WHERE vehicle_class_type = 'RV'
             ORDER BY graphic_skey;

        CURSOR rv_material_width_cur IS
            SELECT /*+ EXTRACT_RV_MATRICES.rv_material_width_cur */
             material_skey,
             material_width
              FROM race.spec_calc_material_width
             WHERE vehicle_class_type = 'RV'
             ORDER BY material_skey;

        CURSOR rv_decal_config_cur IS
            SELECT /*+ EXTRACT_RV_MATRICES.rv_decal_config_cur */
             config_skey,
             oem_max_quantity,
             custom_max_quantity,
             custom_max_color,
             custom_dig_prt_percent_min,
             custom_dig_prt_percent_intrvl,
             custom_dig_prt_percent_cnt,
             custom_dom_prt_percent_min,
             custom_dom_prt_percent_intrvl,
             custom_dom_prt_percent_cnt
              FROM race.spec_calc_decal_config
             WHERE vehicle_class_type = 'RV'
             ORDER BY config_skey;

        -- >> end jr6600 additions for new tables

        out_fhandle utl_file.file_type;
        bfirsttime  BOOLEAN := TRUE;
    BEGIN
        FOR rec IN rv_labor_matrix_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'rv_labor_matrix.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.material_skey || '|' ||
                              rec.procedure_skey || '|' || rec.square_inch || '|' ||
                              rec.labor_time * 10);
        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'rv_labor_matrix.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN rv_procedure_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path, 'rv_procedure.txt', 'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.procedure_skey || '|' ||
                              rec.procedure_name);
        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'rv_procedure.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN rv_category_prtc_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'rv_cat_prtc_xref.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.category_name || '|' ||
                              rec.subcategory_name || '|' || rec.prtc_body || '|' ||
                              rec.spec_calc_type_skey);
        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'rv_cat_prtc_xref.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN rv_calculator_type_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path, 'rv_calc_type.txt', 'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.spec_calc_type_skey || '|' ||
                              rec.spec_calc_type);
        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'rv_calc_type.txt');
        END IF;

        -- >> jr6600 additions for new tables
        bfirsttime := TRUE;
        FOR rec IN rv_material_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path, 'rv_material.txt', 'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.material_skey || '|' || rec.material_name);
        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'rv_material.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN rv_panel_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path, 'rv_panel.txt', 'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.panel_skey || '|' || rec.panel_name);
        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'rv_panel.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN rv_siding_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path, 'rv_siding.txt', 'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.siding_skey || '|' || rec.siding_name);
        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'rv_siding.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN rv_material_matrix_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'rv_material_matrix.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.panel_skey || '|' || rec.material_skey || '|' ||
                              rec.siding_skey || '|' ||
                              rec.current_price * 100 || '|' ||
                              rec.seamed_material_flag);
        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'rv_material_matrix.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN rv_list_material_xref_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'rv_material_list_detail.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.list_skey || '|' || rec.material_skey);
        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'rv_material_list_detail.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN rv_um_list_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'rv_material_list.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.list_skey || '|' || rec.description);
        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'rv_material_list.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN rv_font_size_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path, 'rv_font_size.txt', 'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.lettering_weight_skey || '|' ||
                              rec.weight_type || '|' ||
                              rec.weight_factor * 1000);
        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'rv_font_size.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN rv_lettering_type_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'rv_lettering_type.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.lettering_style_skey || '|' ||
                              rec.style_name || '|' ||
                              rec.style_factor * 1000);
        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'rv_lettering_type.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN rv_graphic_type_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'rv_graphic_type.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.graphic_skey || '|' || rec.graphic_name || '|' ||
                              rec.graphic_factor * 1000);
        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'rv_graphic_type.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN rv_material_width_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'rv_material_width.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.material_skey || '|' ||
                              rec.material_width);
        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'rv_material_width.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN rv_decal_config_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'rv_decal_config.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.config_skey || '|' ||
                              rec.oem_max_quantity || '|' ||
                              rec.custom_max_quantity || '|' ||
                              rec.custom_max_color || '|' ||
                              rec.custom_dig_prt_percent_min || '|' ||
                              rec.custom_dig_prt_percent_intrvl || '|' ||
                              rec.custom_dig_prt_percent_cnt || '|' ||
                              rec.custom_dom_prt_percent_min || '|' ||
                              rec.custom_dom_prt_percent_intrvl || '|' ||
                              rec.custom_dom_prt_percent_cnt);
        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'rv_decal_config.txt');
        END IF;

        -- >> end jr6600 additions for new tables
    EXCEPTION
        WHEN utl_file.invalid_path THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20100, 'INVALID PATH');
        WHEN utl_file.invalid_mode THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20101, 'INVALID MODE');
        WHEN utl_file.invalid_operation THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20102, 'INVALID OPERATION');
        WHEN utl_file.invalid_filehandle THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20103, 'INVALID FILEHANDLE');
        WHEN utl_file.write_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20104, 'WRITE ERROR');
        WHEN utl_file.read_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20105, 'READ ERROR');
        WHEN utl_file.internal_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20106, 'INTERNAL ERROR');
            --  WHEN OTHERS THEN
        --    UTL_FILE.FCLOSE(OUT_FHANDLE);
        --    RAISE_APPLICATION_ERROR(-20107,'UNKNOWN ERROR');
    END extract_rv_matrices;
    -- 2008/12/31 PAG - Older commented sections of code removed
    --                 to reduce package size and improve readability.
    --                 Check prior PVCS version, if you want to view this code.
    -- 04/18/2006 mm5095 => added support for RV_Matrices um6.5
    -- 2008/12/31 PAG - Older commented sections of code removed

    /* ----------------------------------------------------------------------------- EXTRACT_MARINE_MATRICES */
    -- 08/01/2007 jr6600 => added support for Marine_Matrices UM6.7
    PROCEDURE extract_marine_matrices(path VARCHAR2) IS
        CURSOR umm_labor_matrix_cur IS
            SELECT /*+ EXTRACT_MARINE_MATRICES.umm_labor_matrix_cur */
             material_skey,
             procedure_skey,
             square_inch,
             labor_time
              FROM race.spec_calc_matrix
             WHERE vehicle_class_type = 'MA'
             ORDER BY material_skey,
                      procedure_skey,
                      square_inch;

        -- 2008/12/31 PAG => Changed to select Hull-based styles and added cursor for Engine-based styles
        CURSOR umm_boat_hull_style_cur IS
            SELECT /*+ EXTRACT_MARINE_MATRICES.umm_boat_hull_style_cur */
             marine_style_skey,
             description,
             style_factor
              FROM race.marine_style
             WHERE marine_style_skey <> 8
               AND hull_flag = 'Y'
             ORDER BY marine_style_skey;

        CURSOR umm_boat_engine_style_cur IS
            SELECT /*+ EXTRACT_MARINE_MATRICES.umm_boat_engine_style_cur */
             marine_style_skey,
             description,
             style_factor
              FROM race.marine_style
             WHERE marine_style_skey <> 8
               AND engine_flag = 'Y'
             ORDER BY marine_style_skey;
        -- 2008/12/31 PAG => Changed to select Hull-based styles and added cursor for Engine-based styles

        CURSOR umm_cat_prtc_xref_cur IS
            SELECT /*+ EXTRACT_MARINE_MATRICES.umm_cat_prtc_xref_cur */
             b.category_name category_name,
             decode(c.category_name,
                    '<Blank>',
                    b.category_name,
                    c.category_name) subcategory_name,
             prtc_body,
             spec_calc_type_skey
              FROM race.spec_calc_category_prtc_xref a,
                   category                          b,
                   category                          c
             WHERE a.vehicle_class_type = 'MA'
               AND b.category_skey = a.category_skey
               AND c.category_skey = a.subcategory_skey;

        CURSOR umm_calc_type_cur IS
            SELECT /*+ EXTRACT_MARINE_MATRICES.umm_calc_type_cur */
             spec_calc_type_skey,
             spec_calc_type
              FROM race.spec_calc_type
             WHERE vehicle_class_type = 'MA';

        CURSOR umm_panel_cur IS
            SELECT /*+ EXTRACT_MARINE_MATRICES.umm_panel_cur */
             panel_skey,
             panel_name
              FROM race.spec_calc_panel
             WHERE vehicle_class_type = 'MA'
             ORDER BY panel_skey;

        -- 20071205 jr6600 => change per development request
        CURSOR umm_material_cur IS
            SELECT /*+ EXTRACT_MARINE_MATRICES.umm_material_cur */
             material_skey,
             material_name,
             material_factor
              FROM race.spec_calc_material
             WHERE vehicle_class_type = 'MA'
               AND decal_flag <> 'Y'
             ORDER BY material_skey;
        --  cursor umm_material_cur is
        --  select material_skey, material_name, material_factor
        --  from RACE.SPEC_CALC_MATERIAL
        --  where vehicle_class_type = 'MA'
        --  order by material_skey;
        -- 20071205 jr6600 => change per development request

        CURSOR umm_panel_data_cur IS
            SELECT /*+ EXTRACT_MARINE_MATRICES.umm_panel_data_cur */
             panel_skey,
             max_length,
             first_multiplier,
             second_multiplier,
             first_add,
             second_add
              FROM race.spec_calc_panel_data
             WHERE vehicle_class_type = 'MA'
             ORDER BY panel_skey,
                      max_length;

        CURSOR umm_boat_type_cur IS
            SELECT /*+ EXTRACT_MARINE_MATRICES.umm_boat_type_cur */
             marine_type_skey,
             description,
             type_factor
              FROM race.marine_type
             ORDER BY marine_type_skey;

        CURSOR umm_decals_font_size_cur IS
            SELECT /*+ EXTRACT_MARINE_MATRICES.umm_decals_font_size_cur */
             lettering_weight_skey,
             weight_type,
             weight_factor
              FROM race.spec_calc_lettering_weight
             WHERE vehicle_class_type = 'MA'
             ORDER BY lettering_weight_skey;

        CURSOR umm_decals_lettering_type_cur IS
            SELECT /*+ EXTRACT_MARINE_MATRICES.umm_decals_lettering_type_cur */
             lettering_style_skey,
             style_name,
             style_factor
              FROM race.spec_calc_lettering_style
             WHERE vehicle_class_type = 'MA'
             ORDER BY lettering_style_skey;

        CURSOR umm_decals_graphic_type_cur IS
            SELECT /*+ EXTRACT_MARINE_MATRICES.umm_decals_graphic_type_cur */
             graphic_skey,
             graphic_name,
             graphic_factor
              FROM race.spec_calc_graphic_type
             WHERE vehicle_class_type = 'MA'
             ORDER BY graphic_skey;

        CURSOR umm_boat_length_cur IS
            SELECT /*+ EXTRACT_MARINE_MATRICES.umm_boat_length_cur */
             marine_length_skey,
             description,
             length_factor
              FROM race.marine_length
             ORDER BY marine_length_skey;

        CURSOR umm_decals_config_cur IS
            SELECT /*+ EXTRACT_MARINE_MATRICES.umm_decals_config_cur */
             config_skey,
             oem_max_quantity,
             custom_max_quantity,
             custom_max_color,
             custom_dig_prt_percent_min,
             custom_dig_prt_percent_intrvl,
             custom_dig_prt_percent_cnt,
             custom_dom_prt_percent_min,
             custom_dom_prt_percent_intrvl,
             custom_dom_prt_percent_cnt
              FROM race.spec_calc_decal_config
             WHERE vehicle_class_type = 'MA'
             ORDER BY config_skey;

        CURSOR umm_refinish_type_cur IS
            SELECT refinish_type_skey,
                   refinish_type
              FROM race.spec_calc_refinish_type
             WHERE vehicle_class_type = 'MA'
             ORDER BY refinish_type_skey;

        CURSOR umm_decal_material_cur IS
            SELECT material_skey,
                   material_name
              FROM race.spec_calc_material
             WHERE vehicle_class_type = 'MA'
               AND decal_flag = 'Y'
             ORDER BY material_skey;

        CURSOR umm_color_config_cur IS
            SELECT color_type_skey,
                   color_value,
                   color_config_factor,
                   description
              FROM race.spec_calc_ref_color_config
             WHERE vehicle_class_type = 'MA'
             ORDER BY color_type_skey,
                      color_value,
                      color_config_factor,
                      description;

        CURSOR umm_color_factor_cur IS
            SELECT color_config_skey,
                   refinish_type_skey,
                   refinish_factor
              FROM race.spec_calc_ref_color_factor
             WHERE vehicle_class_type = 'MA'
             ORDER BY color_config_skey,
                      refinish_type_skey,
                      refinish_factor;

        CURSOR umm_color_type_cur IS
            SELECT color_type_skey,
                   color_type
              FROM race.spec_calc_refinish_color_type
             WHERE vehicle_class_type = 'MA'
             ORDER BY color_type_skey;

        -- 2008/12/31 PAG => Changed to select Hull-based configs and added cursor for Engine-based configs
        -- 20071130 jr6600 => change per development request
        CURSOR umm_marine_hull_config_cur IS
            SELECT /*+ EXTRACT_MARINE_MATRICES.umm_marine_hull_config_cur */
             a.marine_config_skey,
             b.year,
             a.marine_make_skey,
             a.marine_model_skey,
             a.marine_style_skey,
             a.service_barcode
              FROM race.marine_config a,
                   race.marine_year   b
             WHERE a.marine_year_skey = b.marine_year_skey
               AND a.hull_flag = 'Y'
             ORDER BY b.year DESC,
                      a.marine_make_skey,
                      a.marine_model_skey;
        --  cursor umm_marine_config_cur is
        --  select MARINE_CONFIG_SKEY, MARINE_YEAR_SKEY, MARINE_MAKE_SKEY, MARINE_MODEL_SKEY,
        --  MARINE_STYLE_SKEY, SERVICE_BARCODE
        --  from RACE.MARINE_CONFIG
        --  order by MARINE_YEAR_SKEY, MARINE_MAKE_SKEY, MARINE_MODEL_SKEY;
        -- 20071130 jr6600 => change per development request

        CURSOR umm_hull_config_cur IS
            SELECT /*+ EXTRACT_MARINE_MATRICES.umm_hull_config_cur */
            DISTINCT a.marine_make_skey,
                     a.marine_model_skey,
                     a.marine_style_skey,
                     a.service_barcode,
                     (SELECT MIN(mc.marine_config_skey)
                        FROM marine_config mc
                       WHERE mc.marine_make_skey = a.marine_make_skey
                         AND mc.marine_model_skey = a.marine_model_skey
                         AND mc.marine_style_skey = a.marine_style_skey
                         AND mc.service_barcode = a.service_barcode) AS marine_config_skey
              FROM race.marine_config a
             WHERE a.hull_flag = 'Y'
             ORDER BY a.marine_make_skey,
                      a.marine_model_skey,
                      a.marine_style_skey;

        CURSOR umm_marine_engine_config_cur IS
            SELECT /*+ EXTRACT_MARINE_MATRICES.umm_marine_engine_config_cur */
             a.marine_config_skey,
             a.marine_make_skey,
             a.marine_model_skey,
             a.marine_style_skey,
             a.service_barcode
              FROM race.marine_config a
             WHERE a.engine_flag = 'Y'
             ORDER BY a.marine_make_skey,
                      a.marine_model_skey,
                      a.marine_style_skey;
        -- 2008/12/31 PAG

        -- 2008/12/31 PAG => Changed to select Hull-based makes and added cursor for Engine-based makes
        CURSOR umm_marine_hull_makes_cur IS
            SELECT /*+ EXTRACT_MARINE_MATRICES.umm_marine_hull_makes_cur */
             marine_make_skey,
             make_name
              FROM race.marine_make
             WHERE hull_flag = 'Y'
             ORDER BY make_name;

        CURSOR umm_marine_engine_makes_cur IS
            SELECT /*+ EXTRACT_MARINE_MATRICES.umm_marine_engine_makes_cur */
             marine_make_skey,
             make_name
              FROM race.marine_make
             WHERE engine_flag = 'Y'
             ORDER BY make_name;
        -- 2008/12/31 PAG

        -- 2008/12/31 PAG => Changed to select Hull-based models and added cursor for Engine-based models
        CURSOR umm_marine_hull_models_cur IS
            SELECT /*+ EXTRACT_MARINE_MATRICES.umm_marine_hull_models_cur */
             marine_model_skey,
             model_name
              FROM race.marine_model
             WHERE hull_flag = 'Y'
             ORDER BY model_name;

        CURSOR umm_marine_engine_models_cur IS
            SELECT /*+ EXTRACT_MARINE_MATRICES.umm_marine_engine_models_cur */
             marine_model_skey,
             model_name
              FROM race.marine_model
             WHERE engine_flag = 'Y'
             ORDER BY model_name;
        -- 2008/12/31 PAG

        -- 20071129 jr6600 => change per development request
        CURSOR umm_marine_years_cur IS
            SELECT /*+ EXTRACT_MARINE_MATRICES.umm_marine_years_cur */
             a.year
              FROM race.marine_year a
             ORDER BY a.year DESC;

        --  cursor umm_marine_years_cur is
        --  select MARINE_YEAR_SKEY, YEAR
        --  from RACE.MARINE_YEAR
        --  order by YEAR;
        -- 20071129 jr6600 => change per development request

        out_fhandle utl_file.file_type;
        bfirsttime  BOOLEAN := TRUE;
    BEGIN
        FOR rec IN umm_labor_matrix_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'marine_labor_matrix.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.material_skey || '|' ||
                              rec.procedure_skey || '|' || rec.square_inch || '|' ||
                              rec.labor_time * 10);
        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'marine_labor_matrix.txt');
        END IF;

        -- 2008/12/31 PAG => changed cursor name to reflect HULL-related
        --                  and added code associated to extract of ENGINE-related styles.
        bfirsttime := TRUE;
        FOR rec IN umm_boat_hull_style_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'marine_boat_style.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            -- 20071204 jr6600 => change per development request
            utl_file.put_line(out_fhandle,
                              rec.marine_style_skey || '|' ||
                              rec.description || '|' ||
                              rec.style_factor * 1000);
            -- utl_file.put_line(out_fhandle, rec.MARINE_STYLE_SKEY || '|'
        -- || rec.DESCRIPTION || '|'
        -- || rec.STYLE_FACTOR);
        -- 20071204 jr6600 => change per development request

        END LOOP; --umm_boat_hull_style_cur loop

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'marine_boat_style.txt');
        END IF;

        --end of hull style; beginning of engine style

        bfirsttime := TRUE;
        FOR rec IN umm_boat_engine_style_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path, 'engine_style.txt', 'w');
                bfirsttime  := FALSE;
            END IF;

            -- 20071204 jr6600 => change per development request
            utl_file.put_line(out_fhandle,
                              rec.marine_style_skey || '|' ||
                              rec.description);
            -- utl_file.put_line(out_fhandle, rec.MARINE_STYLE_SKEY || '|'
        -- || rec.DESCRIPTION || '|'
        -- || rec.STYLE_FACTOR);
        -- 20071204 jr6600 => change per development request

        END LOOP; --umm_boat_engine_style_cur loop

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'engine_style.txt');
        END IF;
        -- 2008/12/31 PAG => end of change

        bfirsttime := TRUE;
        FOR rec IN umm_cat_prtc_xref_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'marine_cat_prtc_xref.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.category_name || '|' ||
                              rec.subcategory_name || '|' || rec.prtc_body || '|' ||
                              rec.spec_calc_type_skey);
        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'marine_cat_prtc_xref.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN umm_calc_type_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'marine_calc_type.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.spec_calc_type_skey || '|' ||
                              rec.spec_calc_type);
        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'marine_calc_type.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN umm_panel_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path, 'marine_panel.txt', 'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.panel_skey || '|' || rec.panel_name);
        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'marine_panel.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN umm_material_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'marine_material.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            -- 20071204 jr6600 => change per development request
            utl_file.put_line(out_fhandle,
                              rec.material_skey || '|' || rec.material_name || '|' ||
                              rec.material_factor * 1000);
            -- utl_file.put_line(out_fhandle, rec.material_skey || '|'
        -- || rec.material_name || '|'
        -- || rec.material_factor);
        -- 20071204 jr6600 => change per development request

        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'marine_material.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN umm_panel_data_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'marine_panel_data.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.panel_skey || '|' || rec.max_length || '|' ||
                              rec.first_multiplier || '|' ||
                              rec.second_multiplier || '|' || rec.first_add || '|' ||
                              rec.second_add);
        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'marine_panel_data.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN umm_boat_type_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'marine_boat_type.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            -- 20071204 jr6600 => change per development request
            utl_file.put_line(out_fhandle,
                              rec.marine_type_skey || '|' ||
                              rec.description || '|' ||
                              rec.type_factor * 1000);
            -- utl_file.put_line(out_fhandle, rec.MARINE_TYPE_SKEY || '|'
        -- || rec.description || '|'
        -- || rec.type_factor);
        -- 20071204 jr6600 => change per development request

        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'marine_boat_type.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN umm_decals_font_size_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'marine_decals_font_size.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            -- 20071204 jr6600 => change per development request
            utl_file.put_line(out_fhandle,
                              rec.lettering_weight_skey || '|' ||
                              rec.weight_type || '|' ||
                              rec.weight_factor * 1000);
            -- utl_file.put_line(out_fhandle, rec.LETTERING_WEIGHT_SKEY || '|'
        -- || rec.WEIGHT_TYPE || '|'
        -- || rec.WEIGHT_FACTOR);
        -- 20071204 jr6600 => change per development request

        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'marine_decals_font_size.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN umm_decals_lettering_type_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'marine_decals_lettering_type.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            -- 20071204 jr6600 => change per development request
            utl_file.put_line(out_fhandle,
                              rec.lettering_style_skey || '|' ||
                              rec.style_name || '|' ||
                              rec.style_factor * 1000);
            -- utl_file.put_line(out_fhandle, rec.LETTERING_STYLE_SKEY || '|'
        -- || rec.STYLE_NAME || '|'
        -- || rec.STYLE_FACTOR);
        -- 20071204 jr6600 => change per development request

        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'marine_decals_lettering_type.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN umm_decals_graphic_type_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'marine_decals_graphic_type.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            -- 20071204 jr6600 => change per development request
            utl_file.put_line(out_fhandle,
                              rec.graphic_skey || '|' || rec.graphic_name || '|' ||
                              rec.graphic_factor * 1000);
            -- utl_file.put_line(out_fhandle, rec.graphic_skey || '|'
        -- || rec.graphic_name || '|'
        -- || rec.graphic_factor);
        -- 20071204 jr6600 => change per development request

        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'marine_decals_graphic_type.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN umm_boat_length_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'marine_boat_length.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            -- 20071204 jr6600 => change per development request
            utl_file.put_line(out_fhandle,
                              rec.marine_length_skey || '|' ||
                              rec.description || '|' ||
                              rec.length_factor * 1000);
            -- utl_file.put_line(out_fhandle, rec.marine_length_skey || '|'
        -- || rec.description || '|'
        -- || rec.length_factor);
        -- 20071204 jr6600 => change per development request

        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'marine_boat_length.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN umm_decals_config_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'marine_decals_config.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.config_skey || '|' ||
                              rec.oem_max_quantity || '|' ||
                              rec.custom_max_quantity || '|' ||
                              rec.custom_max_color || '|' ||
                              rec.custom_dig_prt_percent_min || '|' ||
                              rec.custom_dig_prt_percent_intrvl || '|' ||
                              rec.custom_dig_prt_percent_cnt || '|' ||
                              rec.custom_dom_prt_percent_min || '|' ||
                              rec.custom_dom_prt_percent_intrvl || '|' ||
                              rec.custom_dom_prt_percent_cnt);
        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'marine_decals_config.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN umm_refinish_type_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'marine_refinish_type.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.refinish_type_skey || '|' ||
                              rec.refinish_type);
        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'marine_refinish_type.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN umm_decal_material_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'marine_decal_material.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.material_skey || '|' || rec.material_name);
        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'marine_decal_material.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN umm_color_config_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'marine_refinish_color_config.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            -- 20071204 jr6600 => change per development request
            utl_file.put_line(out_fhandle,
                              rec.color_type_skey || '|' || rec.color_value || '|' ||
                              rec.color_config_factor * 1000 || '|' ||
                              rec.description);
            -- utl_file.put_line(out_fhandle, rec.COLOR_TYPE_SKEY || '|'
        -- || rec.COLOR_VALUE || '|'
        -- || rec.COLOR_CONFIG_FACTOR || '|'
        -- || rec.DESCRIPTION);
        -- 20071204 jr6600 => change per development request

        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'marine_refinish_color_config.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN umm_color_factor_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'marine_refinish_color_factor.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            -- 20071204 jr6600 => change per development request
            utl_file.put_line(out_fhandle,
                              rec.color_config_skey || '|' ||
                              rec.refinish_type_skey || '|' ||
                              rec.refinish_factor * 1000);
            -- utl_file.put_line(out_fhandle, rec.COLOR_CONFIG_SKEY || '|'
        -- || rec.REFINISH_TYPE_SKEY || '|'
        -- || rec.REFINISH_FACTOR);
        -- 20071204 jr6600 => change per development request
        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'marine_refinish_color_factor.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN umm_color_type_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'marine_refinish_color_type.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.color_type_skey || '|' || rec.color_type);
        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'marine_refinish_color_type.txt');
        END IF;

        -- 2008/12/31 PAG => changed cursor names assoc'd to CONFIG, MAKES, and MODELS to reflect HULL-related
        --                  and added code associated to extract of ENGINE-related CONFIGs, MAKES, and MODELS.
        bfirsttime := TRUE;
        FOR rec IN umm_marine_hull_config_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path, 'boat_configs.txt', 'w');
                bfirsttime  := FALSE;
            END IF;

            -- 20071130 jr6600 => change per development request
            utl_file.put_line(out_fhandle,
                              rec.marine_config_skey || '|' || rec.year || '|' ||
                              rec.marine_make_skey || '|' ||
                              rec.marine_model_skey || '|' ||
                              rec.marine_style_skey || '|' ||
                              rec.service_barcode);

        --    utl_file.put_line(out_fhandle, rec.MARINE_CONFIG_SKEY || '|'
        --       || rec.MARINE_YEAR_SKEY || '|'
        --       || rec.MARINE_MAKE_SKEY || '|'
        --       || rec.MARINE_MODEL_SKEY || '|'
        --       || rec.MARINE_STYLE_SKEY || '|'
        --       || rec.SERVICE_BARCODE);
        -- 20071130 jr6600 => change per development request
        END LOOP; --end of umm_marine_hull_config_cur loop

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'boat_configs.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN umm_hull_config_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path, 'hull_configs.txt', 'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.marine_config_skey || '|' ||
                              rec.marine_make_skey || '|' ||
                              rec.marine_model_skey || '|' ||
                              rec.marine_style_skey || '|' ||
                              rec.service_barcode);

        END LOOP; --end of umm_hull_config_cur loop

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'hull_configs.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN umm_marine_engine_config_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'engine_configs.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.marine_config_skey || '|' ||
                              rec.marine_make_skey || '|' ||
                              rec.marine_model_skey || '|' ||
                              rec.marine_style_skey || '|' ||
                              rec.service_barcode);

        END LOOP; --end of umm_marine_engine_config_cur loop

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'engine_configs.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN umm_marine_hull_makes_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path, 'boat_makes.txt', 'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.marine_make_skey || '|' || rec.make_name);
        END LOOP; --end of umm_marine_hull_makes_cur loop

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'boat_makes.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN umm_marine_engine_makes_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path, 'engine_makes.txt', 'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.marine_make_skey || '|' || rec.make_name);
        END LOOP; --end of umm_marine_engine_makes_cur loop

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'engine_makes.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN umm_marine_hull_models_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path, 'boat_models.txt', 'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.marine_model_skey || '|' ||
                              rec.model_name);
        END LOOP; --end of umm_marine_hull_models_cur loop

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'boat_models.txt');
        END IF;

        bfirsttime := TRUE;
        FOR rec IN umm_marine_engine_models_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'engine_models.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.marine_model_skey || '|' ||
                              rec.model_name);
        END LOOP; --end of umm_marine_engine_models_cur loop

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'engine_models.txt');
        END IF;
        -- 2008/12/31 PAG => end of change

        bfirsttime := TRUE;
        FOR rec IN umm_marine_years_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path, 'boat_years.txt', 'w');
                bfirsttime  := FALSE;
            END IF;

            -- 20071129 jr6600 => change per development request
            utl_file.put_line(out_fhandle, rec.year || '|' || rec.year);
            --    utl_file.put_line(out_fhandle, rec.MARINE_YEAR_SKEY || '|'
        --       || rec.YEAR);
        -- 20071129 jr6600 => change per development request
        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'boat_years.txt');
        END IF;
    EXCEPTION
        WHEN utl_file.invalid_path THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20100, 'INVALID PATH');
        WHEN utl_file.invalid_mode THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20101, 'INVALID MODE');
        WHEN utl_file.invalid_operation THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20102, 'INVALID OPERATION');
        WHEN utl_file.invalid_filehandle THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20103, 'INVALID FILEHANDLE');
        WHEN utl_file.write_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20104, 'WRITE ERROR');
        WHEN utl_file.read_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20105, 'READ ERROR');
        WHEN utl_file.internal_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20106, 'INTERNAL ERROR');
            --  WHEN OTHERS THEN
        --    UTL_FILE.FCLOSE(OUT_FHANDLE);
        --    RAISE_APPLICATION_ERROR(-20107,'UNKNOWN ERROR');
    END extract_marine_matrices;
    -- 08/01/2007 jr6600 => added support for Marine_Matrices UM6.7

    /* ----------------------------------------------------------------------------- EXTRACT_QUALIFICATION_EXCLUDE */
    -- 08/03/2006 jr6600 => added support for qualification exclusion um6.0
    PROCEDURE extract_qualification_exclude(path VARCHAR2) IS
        CURSOR exclude_cur IS
            SELECT /*+ EXTRACT_QUALIFICATION_EXCLUDE.exclude_cur */
             barcode
              FROM um_qualification_exclude
             ORDER BY barcode;

        out_fhandle utl_file.file_type;
        bfirsttime  BOOLEAN := TRUE;
    BEGIN
        FOR rec IN exclude_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'um_qualif_exclude.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle, rec.barcode);
        END LOOP;

        -- close file, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'um_qualif_exclude.txt');
        END IF;
    EXCEPTION
        WHEN utl_file.invalid_path THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20100, 'INVALID PATH');
        WHEN utl_file.invalid_mode THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20101, 'INVALID MODE');
        WHEN utl_file.invalid_operation THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20102, 'INVALID OPERATION');
        WHEN utl_file.invalid_filehandle THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20103, 'INVALID FILEHANDLE');
        WHEN utl_file.write_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20104, 'WRITE ERROR');
        WHEN utl_file.read_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20105, 'READ ERROR');
        WHEN utl_file.internal_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20106, 'INTERNAL ERROR');
            --  WHEN OTHERS THEN
        --    UTL_FILE.FCLOSE(OUT_FHANDLE);
        --    RAISE_APPLICATION_ERROR(-20107,'UNKNOWN ERROR');
    END extract_qualification_exclude;
    -- 08/03/2006 jr6600 => added support for qualification exclusion um6.0

    /************************************************************************/
    /* Program Name: extract_overlap                                        */
    /* Author:       MM5095                                                 */
    /* Last Modified: 09/25/01                                              */
    /* Description: Creates smartPRTC file for UltraMate build              */
    /************************************************************************/
    PROCEDURE extract_overlap
    (
        parm_path    VARCHAR2,
        path         VARCHAR2,
        full_flag    CHAR,
        restart_flag CHAR,
        version_in   VARCHAR2
    ) IS

        test_flag BOOLEAN := FALSE; -- set to TRUE to change to a "limited" run

        CURSOR body_cur IS
            SELECT /*+ EXTRACT_OVERLAP.body_cur */
            DISTINCT prtc_body
              FROM tmp_um_smartprtc;

        CURSOR smartprtc_cur IS
            SELECT /*+ EXTRACT_OVERLAP.smartprtc_cur */
             prtc,
             a.prtc_body,
             partid,
             clearcoat_major_flag,
             clearcoat_minor_flag,
             body_id,
             color_sand_buff_flag,
             clearcoat_cap_flag,
             twotone_flag,
             repair_elimination_flag,
             duplicate_allow_flag
              FROM tmp_um_smartprtc a,
                   tmp_um_body      b,
                   prtc_body        c
             WHERE a.prtc_body = b.prtc_body
               AND b.prtc_body = c.prtc_body(+)
               FOR UPDATE OF partid, smartprtc1, smartprtc2;

        CURSOR service_cur(version_in VARCHAR2) IS
            SELECT /*+ EXTRACT_OVERLAP.service_cur */
            DISTINCT mfr_number,
                     service_number,
                     substr(sf_transformprtc(prtc, 'SERVICE'), 1, 10) prtc
              FROM ext.service_category_detail
             WHERE (mfr_number, service_number) IN
                   (SELECT DISTINCT mfr_number,
                                    service_number
                      FROM tmp_um_extract
                     WHERE extract_date IS NULL)
               AND version_type = version_in
               AND rtrim(delete_flag_date) IS NULL
               AND rtrim(delete_message_note_skey) IS NULL
               AND rtrim(forward_pointer_row_id) IS NULL
               AND rtrim(prtc) IS NOT NULL
           --****** For Concatenation
             UNION
              SELECT DISTINCT b.mfr_number,
                     b.service_number,
                     substr(sf_transformprtc(prtc, 'SERVICE'), 1, 10) prtc
              FROM ext.service_category_detail a, service_category_substitution b
             WHERE b.mfr_number >= '700'
               AND a.mfr_number = b.substitute_mfr_number
               AND a.service_number = b.substitute_service_number
               AND version_type = version_in
               AND rtrim(delete_flag_date) IS NULL
               AND rtrim(delete_message_note_skey) IS NULL
               AND rtrim(forward_pointer_row_id) IS NULL
               AND rtrim(prtc) IS NOT NULL;

        /*        CURSOR um_service_prtc_cur IS
                    SELECT /*+ EXTRACT_OVERLAP.um_service_prtc_cur
                    DISTINCT transformed_prtc
                      FROM tmp_um_service_prtc;
        */

        -- RS 09/23/2020 Replaced ref.dat
        CURSOR refsheetcur IS
            SELECT prtc
              FROM ref_sheet_category_detail;

        my_body_count   NUMBER := 99;
        smartprtc_count NUMBER := 0;

        utl_smartprtc_fhandle utl_file.file_type;

        my_smartprtc1        NUMBER;
        my_smartprtc2        NUMBER;
        my_refinish_complete VARCHAR2(4);

        record_type CHAR(1);
        line_in     CHAR(80);
        in_fhandle  utl_file.file_type;

        -- 05/20/2008 mm5095 => support for Front Sheet Metal Clear
        fsm_outside    NUMBER;
        fsm_underside  NUMBER;
        hood_outside   NUMBER;
        hood_underside NUMBER;
        -- 05/20/2008 mm5095 => support for Front Sheet Metal Clear

        FUNCTION getrefinishcomplete(prtc_body_in VARCHAR2) RETURN VARCHAR2 IS
            CURSOR c1_cur IS
                SELECT /*+ EXTRACT_OVERLAP.c1_cur */
                 refinish_complete
                  FROM tmp_um_refinish_complete
                 WHERE refinish_complete = prtc_body_in
                      -- 07/26/02 => mm5095 limit search to hdr records
                   AND itemnum = 0;
            -- 07/26/02 => mm5095 limit search to hdr records

            vvc2_return VARCHAR2(4) := NULL;
        BEGIN
            OPEN c1_cur;
            FETCH c1_cur
                INTO vvc2_return;
            CLOSE c1_cur;
            RETURN vvc2_return;
        END;

        -- 05/20/2008 mm5095 => support for Front Sheet Metal Clear
        FUNCTION getpartid(prtc_in VARCHAR2) RETURN NUMBER IS
            vn_return NUMBER := 0;
        BEGIN
            SELECT /*+ EXTRACT_OVERLAP.getPartID */
             a.partid
              INTO vn_return
              FROM tmp_um_smartprtc a
             WHERE a.prtc = prtc_in;
            RETURN vn_return;
        EXCEPTION
            WHEN OTHERS THEN
                RETURN vn_return;
        END;
        -- 05/20/2008 mm5095 => support for Front Sheet Metal Clear

    BEGIN

        -- 04/05/2020 pb0690 => Replaced execute immediate truncates with use of procedure.
        sp_truncate_table('EXT',
                          'tmp_um_body, tmp_um_smartprtc, tmp_um_service_prtc',
                          FALSE);
        IF full_flag = 'F'
        THEN
            --for MINI
            sp_truncate_table_authid('tmp_um_smartprtc', FALSE);
        END IF;
        -- 11/08/11 mm5095 => for incremental, um_smartprtc values need to remain constant
        --  if full_flag = 'T' and restart_flag = 'T' then
        -- 11/08/11 mm5095 => for incremental, um_smartprtc values need to remain constant
        -- full-build, restart
        -- refresh temp tables from previous session
        INSERT /*+ EXTRACT_OVERLAP.tmp_um_body_insert */
        INTO tmp_um_body
            SELECT *
              FROM um_body;

        INSERT /*+ EXTRACT_OVERLAP.tmp_um_service_prtc_insert */
        INTO tmp_um_service_prtc
            SELECT *
              FROM um_service_prtc;

        INSERT /*+ EXTRACT_OVERLAP.tmp_um_smartprtc_insert */
        INTO tmp_um_smartprtc
            SELECT *
              FROM um_smartprtc;

        SELECT /*+ EXTRACT_OVERLAP.tmp_um_smartprtc_select */
         MAX(partid)
          INTO smartprtc_count
          FROM tmp_um_smartprtc;
        -- 11/08/11 mm5095 => for incremental, um_smartprtc values need to remain constant
        --  end if;
        -- 11/08/11 mm5095 => for incremental, um_smartprtc values need to remain constant

        -- 03/08/2016 mm5095 =>bug fix
        IF smartprtc_count IS NULL
        THEN
            smartprtc_count := 0;
        END IF;
        -- 03/08/2016 mm5095 =>bug fix

        -- 11/14/01 mm5095 => added for testing ------- "LIMITED" RUN
        IF test_flag
        THEN
            RETURN;
        END IF;
        -- 11/14/01 mm5095 => added for testing

        -- get prtcs for services
        -- 11/08/11 mm5095 => for incremental, um_smartprtc values need to remain constant
        --  if full_flag = 'T' and restart_flag = 'T' then
        -- 11/08/11 mm5095 => for incremental, um_smartprtc values need to remain constant
        FOR rec IN service_cur(version_in)
        LOOP
            BEGIN
                INSERT /*+ EXTRACT_OVERLAP.tmp_um_service_prtc_insert2 */
                INTO tmp_um_service_prtc
                    (mfr_number,
                     service_number,
                     transformed_prtc)
                VALUES
                    (rec.mfr_number,
                     rec.service_number,
                     rec.prtc);
            EXCEPTION
                WHEN dup_val_on_index THEN
                    NULL; -- skip duplicates
            END;
        END LOOP;
        -- 11/08/11 mm5095 => for incremental, um_smartprtc values need to remain constant
        /*
          else
            insert /*+ EXTRACT_OVERLAP.tmp_um_service_prtc_insert3 / into tmp_um_service_prtc
            (mfr_number, service_number, transformed_prtc)
            select distinct mfr_number, service_number, substr(sf_transformprtc(prtc,'SERVICE'),1,10)
            from ext.service_category_detail scd
            where (scd.mfr_number, scd.service_number)
            in (select tue.mfr_number, tue.service_number
            from tmp_um_extract tue
            where tue.extract_date is null)
            and scd.version_type = version_in
            and rtrim(scd.delete_flag_date) is null
            and rtrim(scd.delete_message_note_skey) is null
            and rtrim(scd.forward_pointer_row_id) is null
            and rtrim(scd.prtc) is not null;
          end if;
        */
        -- 11/08/11 mm5095 => for incremental, um_smartprtc values need to remain constant

        UPDATE /*+ EXTRACT_OVERLAP.tmp_um_service_prtc_update */ tmp_um_service_prtc
           SET transformed_prtc46 = substr(transformed_prtc, 4, 6)
         WHERE transformed_prtc46 IS NULL;

        -- create distinct list of prtcs for creation of smart prtcs:
        -- includes prtcs for services in mini, prtcs found in overlap
        -- and detail tables for services in mini, combined overlap prtcs,
        -- prtcs associated with delete and points, prtcs from reference sheet,
        -- "magic" prtcs and '***XXXX***'
        IF version_in = 'PR'
        THEN
            -- 11/08/11 mm5095 => for incremental, um_smartprtc values need to remain constant
            /*
                if full_flag = 'T' and restart_flag = 'T' then
                  for rec in um_service_prtc_cur LOOP
                    BEGIN
                      insert /*+ EXTRACT_OVERLAP.tmp_um_smartprtc_insert2 / into tmp_um_smartprtc
                      (prtc)
                      values(rec.transformed_prtc);
                    EXCEPTION WHEN DUP_VAL_ON_INDEX THEN
                      null; -- skip duplicates
                    END;
                  END LOOP;
                else
            */ -- UltraMate full-build from start
            INSERT /*+ EXTRACT_OVERLAP.tmp_um_smartprtc_insert_full */
            INTO tmp_um_smartprtc
                (prtc)
            -- 11/08/11 mm5095 => for incremental, um_smartprtc values need to remain constant
                (
                 -- 11/08/11 mm5095 => for incremental, um_smartprtc values need to remain constant
                 SELECT transformed_prtc
                   FROM tmp_um_service_prtc
                 UNION
                 SELECT substr(sf_transformprtc(autoincl_prtc, 'COMBINED'),
                                1,
                                10)
                   FROM combo_overlap_header
                 UNION
                 SELECT substr(sf_transformprtc(incl_prtc_1, 'COMBINED'),
                                1,
                                10)
                   FROM combo_overlap_header
                 UNION
                 SELECT substr(sf_transformprtc(incl_prtc_2, 'COMBINED'),
                                1,
                                10)
                   FROM combo_overlap_header
                 UNION
                 SELECT substr(sf_transformprtc(incl_prtc_3, 'COMBINED'),
                                1,
                                10)
                   FROM combo_overlap_header
                 UNION
                 SELECT substr(sf_transformprtc(incl_prtc_4, 'COMBINED'),
                                1,
                                10)
                   FROM combo_overlap_header
                 UNION
                 SELECT substr(sf_transformprtc(incl_prtc_5, 'COMBINED'),
                                1,
                                10)
                   FROM combo_overlap_header
                 UNION
                 SELECT substr(sf_transformprtc(autoincl_prtc, 'COMBINED'),
                                1,
                                10)
                   FROM combo_overlap_detail
                 UNION
                 SELECT substr(sf_transformprtc(incl_prtc_1, 'COMBINED'),
                                1,
                                10)
                   FROM combo_overlap_detail
                 UNION
                 SELECT substr(sf_transformprtc(incl_prtc_2, 'COMBINED'),
                                1,
                                10)
                   FROM combo_overlap_detail
                 UNION
                 SELECT substr(sf_transformprtc(incl_prtc_3, 'COMBINED'),
                                1,
                                10)
                   FROM combo_overlap_detail
                 UNION
                 SELECT substr(sf_transformprtc(incl_prtc_4, 'COMBINED'),
                                1,
                                10)
                   FROM combo_overlap_detail
                 UNION
                 SELECT substr(sf_transformprtc(incl_prtc_5, 'COMBINED'),
                                1,
                                10)
                   FROM combo_overlap_detail
                 UNION
                 SELECT '***' || delete_message_prtc_body || '***'
                   FROM note
                  WHERE note_type = 'D'
                 UNION
                 SELECT '***' || prtc_body || '***'
                   FROM um_magic_prtc_body
                 UNION
                 -- where overlap matches the mfr/service that the customer will see
                 SELECT substr(sf_transformprtc(prtc, 'OVERLAP'), 1, 10)
                   FROM overlap_header
                  WHERE (mfr_number, service_number) IN
                        (SELECT DISTINCT mfr_number,
                                         service_number
                           FROM tmp_um_extract
                          WHERE extract_date IS NULL)
                 -- 2008/12/31 PAG - added for Service Concatenation (begin)
                 -- where overlap matches the mfr/service of the concatenated service (next 2 unions)
                 UNION
                 SELECT substr(sf_transformprtc(prtc, 'OVERLAP'), 1, 10)
                   FROM overlap_header
                  WHERE (mfr_number, service_number) IN
                        (SELECT DISTINCT psc.first_mfr_number,
                                         psc.first_service_number
                           FROM product_service_concatenation psc,
                                tmp_um_extract                um
                          WHERE um.extract_date IS NULL
                            AND '9' || psc.product_service_barcode =
                                um.barcode
                            AND (psc.first_mfr_number != um.mfr_number OR
                                psc.first_service_number !=
                                um.service_number))
                 UNION
                 SELECT substr(sf_transformprtc(prtc, 'OVERLAP'), 1, 10)
                   FROM overlap_header
                  WHERE (mfr_number, service_number) IN
                        (SELECT DISTINCT psc.second_mfr_number,
                                         psc.second_service_number
                           FROM product_service_concatenation psc,
                                tmp_um_extract                um
                          WHERE um.extract_date IS NULL
                            AND '9' || psc.product_service_barcode =
                                um.barcode
                            AND (psc.second_mfr_number != um.mfr_number OR
                                psc.second_service_number !=
                                um.service_number))
                 -- 2008/12/31 PAG - added for Service Concatenation (end)
                 UNION
                 SELECT /*+ USE_NL(B,A) ORDERED */
                  substr(sf_transformprtc(b.prtc, 'OVERLAP'), 1, 10)
                   FROM overlap_header a,
                         overlap_detail b
                  WHERE (mfr_number, service_number) IN
                        (SELECT DISTINCT mfr_number,
                                         service_number
                           FROM tmp_um_extract
                          WHERE extract_date IS NULL)
                    AND b.overlap_skey = a.overlap_skey
                    AND b.prtc NOT LIKE '%$%'
                 -- 2008/12/31 PAG - for Service Concatenation (begin)
                 UNION
                 SELECT /*+ USE_NL(B,A) ORDERED */
                  substr(sf_transformprtc(b.prtc, 'OVERLAP'), 1, 10)
                   FROM overlap_header a,
                         overlap_detail b
                  WHERE (mfr_number, service_number) IN
                        (SELECT DISTINCT psc.first_mfr_number,
                                         psc.first_service_number
                           FROM product_service_concatenation psc,
                                tmp_um_extract                um
                          WHERE um.extract_date IS NULL
                            AND '9' || psc.product_service_barcode =
                                um.barcode
                            AND (psc.first_mfr_number != um.mfr_number OR
                                psc.first_service_number !=
                                um.service_number))
                    AND b.overlap_skey = a.overlap_skey
                    AND b.prtc NOT LIKE '%$%'
                 UNION
                 SELECT /*+ USE_NL(B,A) ORDERED */
                  substr(sf_transformprtc(b.prtc, 'OVERLAP'), 1, 10)
                   FROM overlap_header a,
                         overlap_detail b
                  WHERE (mfr_number, service_number) IN
                        (SELECT DISTINCT psc.second_mfr_number,
                                         psc.second_service_number
                           FROM product_service_concatenation psc,
                                tmp_um_extract                um
                          WHERE um.extract_date IS NULL
                            AND '9' || psc.product_service_barcode =
                                um.barcode
                            AND (psc.second_mfr_number != um.mfr_number OR
                                psc.second_service_number !=
                                um.service_number))
                    AND b.overlap_skey = a.overlap_skey
                    AND b.prtc NOT LIKE '%$%'
                 -- 2008/12/31 PAG - for Service Concatenation (end)
                 -- 11/04/2011 mm5095 => added support for mtd/htd concatenation
                 UNION
                 SELECT substr(sf_transformprtc(prtc, 'SERVICE'), 1, 10)
                   FROM service_category_substitution a
                  INNER JOIN service_category_detail b
                     ON b.mfr_number = a.substitute_mfr_number
                    AND b.service_number = a.substitute_service_number
                    AND ((b.subcategory_skey = 0 OR
                        b.subcategory_skey = a.substitute_subcategory_skey) OR
                        a.all_subcategory_flag = 'Y')
                    AND b.version_type = version_in
                 -- 11/04/2011 mm5095 => added support for mtd/htd concatenation
                 UNION
                 -- 11/08/11 mm5095 => for incremental, um_smartprtc values need to remain constant
                 --      select '***XXXX***' from dual;
                 SELECT '***XXXX***'
                   FROM dual) MINUS
                SELECT prtc
                  FROM tmp_um_smartprtc;
            -- 11/08/11 mm5095 => for incremental, um_smartprtc values need to remain constant
            --    end if;
            -- 11/08/11 mm5095 => for incremental, um_smartprtc values need to remain constant

        ELSE
            -- UltraMate mini-build from WP
            INSERT /*+ EXTRACT_OVERLAP.tmp_um_smartprtc_insert_wp */
            INTO tmp_um_smartprtc
                (prtc)
            -- 11/08/11 mm5095 => for incremental, um_smartprtc values need to remain constant
                (
                 -- 11/08/11 mm5095 => for incremental, um_smartprtc values need to remain constant
                 SELECT transformed_prtc
                   FROM tmp_um_service_prtc
                 UNION
                 SELECT substr(sf_transformprtc(autoincl_prtc, 'COMBINED'),
                                1,
                                10)
                   FROM combo_overlap_header_wip
                 UNION
                 SELECT substr(sf_transformprtc(incl_prtc_1, 'COMBINED'),
                                1,
                                10)
                   FROM combo_overlap_header_wip
                 UNION
                 SELECT substr(sf_transformprtc(incl_prtc_2, 'COMBINED'),
                                1,
                                10)
                   FROM combo_overlap_header_wip
                 UNION
                 SELECT substr(sf_transformprtc(incl_prtc_3, 'COMBINED'),
                                1,
                                10)
                   FROM combo_overlap_header_wip
                 UNION
                 SELECT substr(sf_transformprtc(incl_prtc_4, 'COMBINED'),
                                1,
                                10)
                   FROM combo_overlap_header_wip
                 UNION
                 SELECT substr(sf_transformprtc(incl_prtc_5, 'COMBINED'),
                                1,
                                10)
                   FROM combo_overlap_header_wip
                 UNION
                 SELECT substr(sf_transformprtc(autoincl_prtc, 'COMBINED'),
                                1,
                                10)
                   FROM combo_overlap_detail_wip
                 UNION
                 SELECT substr(sf_transformprtc(incl_prtc_1, 'COMBINED'),
                                1,
                                10)
                   FROM combo_overlap_detail_wip
                 UNION
                 SELECT substr(sf_transformprtc(incl_prtc_2, 'COMBINED'),
                                1,
                                10)
                   FROM combo_overlap_detail_wip
                 UNION
                 SELECT substr(sf_transformprtc(incl_prtc_3, 'COMBINED'),
                                1,
                                10)
                   FROM combo_overlap_detail_wip
                 UNION
                 SELECT substr(sf_transformprtc(incl_prtc_4, 'COMBINED'),
                                1,
                                10)
                   FROM combo_overlap_detail_wip
                 UNION
                 SELECT substr(sf_transformprtc(incl_prtc_5, 'COMBINED'),
                                1,
                                10)
                   FROM combo_overlap_detail_wip
                 UNION
                 SELECT '***' || delete_message_prtc_body || '***'
                   FROM note
                  WHERE note_type = 'D'
                 UNION
                 SELECT '***' || prtc_body || '***'
                   FROM um_magic_prtc_body
                 UNION
                 -- where overlap matches the mfr/service that the customer will see
                 SELECT substr(sf_transformprtc(prtc, 'OVERLAP'), 1, 10)
                   FROM overlap_header_wip
                  WHERE (mfr_number, service_number) IN
                        (SELECT DISTINCT mfr_number,
                                         service_number
                           FROM tmp_um_extract
                          WHERE extract_date IS NULL)
                 -- 2008/12/31 PAG - added for Service Concatenation (begin)
                 -- where overlap matches the mfr/service of the concatenated service (next 2 unions)
                 UNION
                 SELECT substr(sf_transformprtc(prtc, 'OVERLAP'), 1, 10)
                   FROM overlap_header_wip
                  WHERE (mfr_number, service_number) IN
                        (SELECT DISTINCT psc.first_mfr_number,
                                         psc.first_service_number
                           FROM product_service_concatenation psc,
                                tmp_um_extract                um
                          WHERE um.extract_date IS NULL
                            AND '9' || psc.product_service_barcode =
                                um.barcode
                            AND (psc.first_mfr_number != um.mfr_number OR
                                psc.first_service_number !=
                                um.service_number))
                 UNION
                 SELECT substr(sf_transformprtc(prtc, 'OVERLAP'), 1, 10)
                   FROM overlap_header_wip
                  WHERE (mfr_number, service_number) IN
                        (SELECT DISTINCT psc.second_mfr_number,
                                         psc.second_service_number
                           FROM product_service_concatenation psc,
                                tmp_um_extract                um
                          WHERE um.extract_date IS NULL
                            AND '9' || psc.product_service_barcode =
                                um.barcode
                            AND (psc.second_mfr_number != um.mfr_number OR
                                psc.second_service_number !=
                                um.service_number))
                 -- 2008/12/31 PAG - added for Service Concatenation (end)
                 UNION
                 -- where overlap matches the mfr/service that the customer will see
                 SELECT /*+ USE_NL(B,A) ORDERED */
                  substr(sf_transformprtc(b.prtc, 'OVERLAP'), 1, 10)
                   FROM overlap_header_wip a,
                         overlap_detail_wip b
                  WHERE (a.mfr_number, a.service_number) IN
                        (SELECT DISTINCT um.mfr_number,
                                         um.service_number
                           FROM tmp_um_extract um
                          WHERE um.extract_date IS NULL)
                    AND b.overlap_skey = a.overlap_skey
                    AND b.prtc NOT LIKE '%$%'
                 -- 2008/12/31 PAG - for Service Concatenation (begin)
                 UNION
                 SELECT /*+ USE_NL(B,A) ORDERED */
                  substr(sf_transformprtc(b.prtc, 'OVERLAP'), 1, 10)
                   FROM overlap_header_wip a,
                         overlap_detail_wip b
                  WHERE (mfr_number, service_number) IN
                        (SELECT DISTINCT psc.first_mfr_number,
                                         psc.first_service_number
                           FROM product_service_concatenation psc,
                                tmp_um_extract                um
                          WHERE um.extract_date IS NULL
                            AND '9' || psc.product_service_barcode =
                                um.barcode
                            AND (psc.first_mfr_number != um.mfr_number OR
                                psc.first_service_number !=
                                um.service_number))
                    AND b.overlap_skey = a.overlap_skey
                    AND b.prtc NOT LIKE '%$%'
                 UNION
                 SELECT /*+ USE_NL(B,A) ORDERED */
                  substr(sf_transformprtc(b.prtc, 'OVERLAP'), 1, 10)
                   FROM overlap_header_wip a,
                         overlap_detail_wip b
                  WHERE (mfr_number, service_number) IN
                        (SELECT DISTINCT psc.second_mfr_number,
                                         psc.second_service_number
                           FROM product_service_concatenation psc,
                                tmp_um_extract                um
                          WHERE um.extract_date IS NULL
                            AND '9' || psc.product_service_barcode =
                                um.barcode
                            AND (psc.second_mfr_number != um.mfr_number OR
                                psc.second_service_number !=
                                um.service_number))
                    AND b.overlap_skey = a.overlap_skey
                    AND b.prtc NOT LIKE '%$%'
                 -- 2008/12/31 PAG - for Service Concatenation (end)
                 -- 11/04/2011 mm5095 => added support for mtd/htd concatenation
                 UNION
                 SELECT substr(sf_transformprtc(prtc, 'SERVICE'), 1, 10)
                   FROM service_category_substitution a
                  INNER JOIN service_category_detail b
                     ON b.mfr_number = a.substitute_mfr_number
                    AND b.service_number = a.substitute_service_number
                    AND ((b.subcategory_skey = 0 OR
                        b.subcategory_skey = a.substitute_subcategory_skey) OR
                        a.all_subcategory_flag = 'Y')
                    AND b.version_type = version_in
                 -- 11/04/2011 mm5095 => added support for mtd/htd concatenation
                 UNION
                 -- 11/08/11 mm5095 => for incremental, um_smartprtc values need to remain constant
                 --      select '***XXXX***' from dual;
                 SELECT '***XXXX***'
                   FROM dual) MINUS
                SELECT prtc
                  FROM tmp_um_smartprtc;
            -- 11/08/11 mm5095 => for incremental, um_smartprtc values need to remain constant
        END IF;

        -- RS 09/25/2020 Replace ref.dat
        FOR p IN refsheetcur
        LOOP
          BEGIN
              INSERT /*+ EXTRACT_OVERLAP.tmp_um_smartprtc_insert_3 */
              INTO tmp_um_smartprtc
                  (prtc)
              VALUES
                  (p.prtc);

           EXCEPTION
               WHEN dup_val_on_index THEN
                   NULL; -- skip duplicates
           END;
        END LOOP;

        UPDATE /*+ EXTRACT_OVERLAP.tmp_um_smartprtc_update */ tmp_um_smartprtc
           SET prtc_body = substr(prtc, 4, 4)
         WHERE prtc_body IS NULL;

        -- process prtc bodys for smartprtc's
        -- 11/08/11 mm5095 => for incremental, um_smartprtc values need to remain constant
        --  if full_flag = 'T' and restart_flag = 'T' then
        -- 11/08/11 mm5095 => for incremental, um_smartprtc values need to remain constant
        SELECT /*+ EXTRACT_OVERLAP.tmp_um_body_select_full */
         MAX(body_id)
          INTO my_body_count
          FROM tmp_um_body;
        -- 11/08/11 mm5095 => for incremental, um_smartprtc values need to remain constant
        --  else
        --    insert /*+ EXTRACT_OVERLAP.tmp_um_body_insert_2 */ into tmp_um_body
        --    select * from um_magic_prtc_body;
        --  end if;
        -- 11/08/11 mm5095 => for incremental, um_smartprtc values need to remain constant

        -- 03/08/2016 mm5095 => bug fix
        IF my_body_count IS NULL
        THEN
            my_body_count := 99;
        END IF;
        -- 03/08/2016

        FOR rec IN body_cur
        LOOP
            BEGIN
                my_body_count := my_body_count + 1;
                INSERT /*+ EXTRACT_OVERLAP.tmp_um_body_insert_3 */
                INTO tmp_um_body
                VALUES
                    (rec.prtc_body,
                     my_body_count);
            EXCEPTION
                WHEN dup_val_on_index THEN
                    -- ignore duplicates, set counter back
                    my_body_count := my_body_count - 1;
            END;
        END LOOP;

        -- open smartprtc output file
        utl_smartprtc_fhandle := utl_file.fopen(path, 'dbsmartp.txt', 'w');

        -- populate smartprtc's with partid, bit1 and bit2
        FOR rec IN smartprtc_cur
        LOOP

            my_smartprtc1        := sf_getsmartprtc1(rec.prtc,
                                                     rec.clearcoat_major_flag,
                                                     rec.clearcoat_minor_flag);
            my_refinish_complete := getrefinishcomplete(rec.prtc_body);
            my_smartprtc2        := sf_getsmartprtc2(rec.prtc,
                                                     rec.body_id,
                                                     rec.color_sand_buff_flag,
                                                     my_refinish_complete,
                                                     rec.clearcoat_cap_flag,
                                                     rec.twotone_flag,
                                                     rec.repair_elimination_flag,
                                                     rec.duplicate_allow_flag);

            IF rec.partid IS NULL
            THEN
                smartprtc_count := smartprtc_count + 1;
                UPDATE /*+ EXTRACT_OVERLAP.tmp_um_smartprtc_update_3 */ tmp_um_smartprtc
                   SET partid     = smartprtc_count,
                       smartprtc1 = my_smartprtc1,
                       smartprtc2 = my_smartprtc2
                 WHERE CURRENT OF smartprtc_cur;

                -- output smart prtc information
                utl_file.put_line(utl_smartprtc_fhandle,
                                  rec.prtc || '|' || smartprtc_count || '|' ||
                                  smartprtc_count || '|' || my_smartprtc1 || '|' ||
                                  my_smartprtc2);
            ELSE
                -- 09/05/2014 mm5095 => bug fix: smartprtc values not getting updated when flags change
                UPDATE /*+ EXTRACT_OVERLAP.tmp_um_smartprtc_update_3 */ tmp_um_smartprtc
                   SET smartprtc1 = my_smartprtc1,
                       smartprtc2 = my_smartprtc2
                 WHERE CURRENT OF smartprtc_cur;
                -- 09/05/2014 mm5095 => bug fix: smartprtc values not getting updated when flags change

                -- output smart prtc information
                utl_file.put_line(utl_smartprtc_fhandle,
                                  rec.prtc || '|' || rec.partid || '|' ||
                                  rec.partid || '|' || my_smartprtc1 || '|' ||
                                  my_smartprtc2);
            END IF;
        END LOOP;

        -- update semaphore file
        sp_update_globaltxt_semaphore(path,
                                      'global.txt',
                                      'a',
                                      'dbsmartp.txt');

        utl_file.fclose(utl_smartprtc_fhandle);

        -- 05/20/2008 mm5095 => support for Front Sheet Metal Clear
        fsm_outside    := getpartid('***FAG1***');
        fsm_underside  := getpartid('***FAN6***');
        hood_outside   := getpartid('***FAAQ***');
        hood_underside := getpartid('***FAAR***');

        in_fhandle := utl_file.fopen(path, 'fsm.txt', 'w');
        utl_file.put_line(in_fhandle,
                          '1 ' || fsm_outside || ' ' || hood_outside);
        utl_file.put_line(in_fhandle,
                          '2 ' || fsm_underside || ' ' || hood_underside);

        sp_update_globaltxt_semaphore(path, 'global.txt', 'a', 'fsm.txt');

        utl_file.fclose(in_fhandle);
        -- 05/20/2008 mm5095 => support for Front Sheet Metal Clear
    EXCEPTION
        WHEN utl_file.invalid_path THEN
            utl_file.fclose_all;
            raise_application_error(-20100, 'INVALID PATH');
        WHEN utl_file.invalid_mode THEN
            utl_file.fclose_all;
            raise_application_error(-20101, 'INVALID MODE');
        WHEN utl_file.invalid_operation THEN
            utl_file.fclose_all;
            raise_application_error(-20102, 'INVALID OPERATION');
        WHEN utl_file.invalid_filehandle THEN
            utl_file.fclose_all;
            raise_application_error(-20103, 'INVALID FILEHANDLE');
        WHEN utl_file.write_error THEN
            utl_file.fclose_all;
            raise_application_error(-20104, 'WRITE ERROR');
        WHEN utl_file.read_error THEN
            utl_file.fclose_all;
            raise_application_error(-20105, 'READ ERROR');
        WHEN utl_file.internal_error THEN
            utl_file.fclose_all;
            raise_application_error(-20106, 'INTERNAL ERROR');
            --  WHEN OTHERS THEN
        --    UTL_FILE.FCLOSE_ALL;
        --    RAISE_APPLICATION_ERROR(-20107,'UNKNOWN ERROR');
    END extract_overlap;

    -- 2008/12/31 PAG - Older commented sections of code removed
    --                 to reduce package size and improve readability.
    --                 Check prior PVCS version, if you want to view this code.
    -- 08/06/04 tmc => WIP is no longer used here
    -- PROCEDURE EXTRACT_CEGATGQRP_WIP(path varchar2)
    -- 2008/12/31 PAG - Older commented sections of code removed
    -- 08/06/04 tmc => WIP is no longer used here
    /************************************************************************/
    /* Program Name: extract_cegatgqrp                                      */
    /* Author:       MM5095                                                 */
    /* Last Modified: 09/21/2001                                            */
    /* Description: Create ceg/atg, ceg/qrp, atg/qrp relationship files     */
    /* for ultramate full build                                             */
    /* NOTE: Make certain any changes made here are duplicated in           */
    /* extract_cegatgqrp_wip.sql routine that preceeds this one!            */
    /************************************************************************/
    PROCEDURE extract_cegatgqrp
    (
        path     VARCHAR2,
        run_type VARCHAR2
    ) IS
        CURSOR bceg_atg_cur IS
            SELECT /*+ EXTRACT_CEGATGQRP.bceg_atg_cur */
            DISTINCT b.prtc bceg_prtc_match,
                     c.prtc atg_prtc_match
              FROM bceg_atg_xref    a,
                   tmp_um_smartprtc b,
                   tmp_um_smartprtc c
             WHERE substr(bceg_prtc, 4, 4) = b.prtc_body
               AND (substr(b.prtc, 1, 3) = '***' OR
                    ((substr(bceg_prtc, 1, 1) = substr(b.prtc, 1, 1) OR
                     substr(bceg_prtc, 1, 1) = substr(b.prtc, 2, 1) OR
                     substr(bceg_prtc, 1, 1) = substr(b.prtc, 3, 1) OR
                     substr(bceg_prtc, 1, 1) = '$') AND
                     (substr(bceg_prtc, 2, 1) = substr(b.prtc, 1, 1) OR
                     substr(bceg_prtc, 2, 1) = substr(b.prtc, 2, 1) OR
                     substr(bceg_prtc, 2, 1) = substr(b.prtc, 3, 1) OR
                     substr(bceg_prtc, 2, 1) = '$') AND
                     (substr(bceg_prtc, 3, 1) = substr(b.prtc, 1, 1) OR
                     substr(bceg_prtc, 3, 1) = substr(b.prtc, 2, 1) OR
                     substr(bceg_prtc, 3, 1) = substr(b.prtc, 3, 1) OR
                     substr(bceg_prtc, 3, 1) = '$')))
               AND substr(atg_prtc, 4, 4) = c.prtc_body
               AND (substr(c.prtc, 1, 3) = '***' OR
                    ((substr(atg_prtc, 1, 1) = substr(c.prtc, 1, 1) OR
                     substr(atg_prtc, 1, 1) = substr(c.prtc, 2, 1) OR
                     substr(atg_prtc, 1, 1) = substr(c.prtc, 3, 1) OR
                     substr(atg_prtc, 1, 1) = '$') AND
                     (substr(atg_prtc, 2, 1) = substr(c.prtc, 1, 1) OR
                     substr(atg_prtc, 2, 1) = substr(c.prtc, 2, 1) OR
                     substr(atg_prtc, 2, 1) = substr(c.prtc, 3, 1) OR
                     substr(atg_prtc, 2, 1) = '$') AND
                     (substr(atg_prtc, 3, 1) = substr(c.prtc, 1, 1) OR
                     substr(atg_prtc, 3, 1) = substr(c.prtc, 2, 1) OR
                     substr(atg_prtc, 3, 1) = substr(c.prtc, 3, 1) OR
                     substr(atg_prtc, 3, 1) = '$')))
               AND (substr(b.prtc, 1, 3) = substr(c.prtc, 1, 3) OR
                    (substr(b.prtc, 1, 2) = substr(c.prtc, 1, 2) AND
                     substr(b.prtc, 3, 1) BETWEEN '0' AND '9' AND
                     substr(c.prtc, 3, 1) BETWEEN '0' AND '9')
                    -- 06/11/04 mm5095 => changed at Editorial request to loosen CEG-ATG mapping
                    OR (b.prtc_body IN ('EWAA',
                                        'EWCM',
                                        'GHAA',
                                        'GHCM',
                                        'HHAA',
                                        'HHCM',
                                        'JHAA',
                                        'JHCM') AND
                        (substr(c.prtc, 1, 1) = substr(b.prtc, 1, 1) OR
                        substr(c.prtc, 1, 1) = substr(b.prtc, 2, 1) OR
                        substr(c.prtc, 1, 1) = substr(b.prtc, 3, 1) OR
                        substr(c.prtc, 1, 1) = '*') AND
                        (substr(c.prtc, 2, 1) = substr(b.prtc, 1, 1) OR
                        substr(c.prtc, 2, 1) = substr(b.prtc, 2, 1) OR
                        substr(c.prtc, 2, 1) = substr(b.prtc, 3, 1) OR
                        substr(c.prtc, 2, 1) = '*') AND
                        (substr(c.prtc, 3, 1) = substr(b.prtc, 1, 1) OR
                        substr(c.prtc, 3, 1) = substr(b.prtc, 2, 1) OR
                        substr(c.prtc, 3, 1) = substr(b.prtc, 3, 1) OR
                        substr(c.prtc, 3, 1) = '*')))
                  -- 06/11/04 mm5095 => changed at Editorial request to loosen CEG-ATG mapping
               AND substr(b.prtc, 8, 1) = substr(c.prtc, 8, 1);

        CURSOR bceg_qrp_cur IS
            SELECT /*+ EXTRACT_CEGATGQRP.bceg_qrp_cur */
            DISTINCT qrp_assy_type,
                     prtc
              FROM bceg_qrp_xref    a,
                   tmp_um_smartprtc b
             WHERE substr(bceg_prtc, 4, 4) = b.prtc_body
               AND (substr(bceg_prtc, 1, 1) = substr(b.prtc, 1, 1) OR
                    substr(bceg_prtc, 1, 1) = substr(b.prtc, 2, 1) OR
                    substr(bceg_prtc, 1, 1) = substr(b.prtc, 3, 1) OR
                    substr(bceg_prtc, 1, 1) = '$')
               AND (substr(bceg_prtc, 2, 1) = substr(b.prtc, 1, 1) OR
                    substr(bceg_prtc, 2, 1) = substr(b.prtc, 2, 1) OR
                    substr(bceg_prtc, 2, 1) = substr(b.prtc, 3, 1) OR
                    substr(bceg_prtc, 2, 1) = '$')
               AND (substr(bceg_prtc, 3, 1) = substr(b.prtc, 1, 1) OR
                    substr(bceg_prtc, 3, 1) = substr(b.prtc, 2, 1) OR
                    substr(bceg_prtc, 3, 1) = substr(b.prtc, 3, 1) OR
                    substr(bceg_prtc, 3, 1) = '$');

        CURSOR atg_qrp_cur IS
            SELECT /*+ EXTRACT_CEGATGQRP.atg_qrp_cur */
            DISTINCT qrp_assy_type,
                     prtc
              FROM atg_qrp_xref     a,
                   tmp_um_smartprtc b
             WHERE substr(atg_prtc, 4, 4) = b.prtc_body
               AND (substr(atg_prtc, 1, 1) = substr(b.prtc, 1, 1) OR
                    substr(atg_prtc, 1, 1) = substr(b.prtc, 2, 1) OR
                    substr(atg_prtc, 1, 1) = substr(b.prtc, 3, 1) OR
                    substr(atg_prtc, 1, 1) = '$')
               AND (substr(atg_prtc, 2, 1) = substr(b.prtc, 1, 1) OR
                    substr(atg_prtc, 2, 1) = substr(b.prtc, 2, 1) OR
                    substr(atg_prtc, 2, 1) = substr(b.prtc, 3, 1) OR
                    substr(atg_prtc, 2, 1) = '$')
               AND (substr(atg_prtc, 3, 1) = substr(b.prtc, 1, 1) OR
                    substr(atg_prtc, 3, 1) = substr(b.prtc, 2, 1) OR
                    substr(atg_prtc, 3, 1) = substr(b.prtc, 3, 1) OR
                    substr(atg_prtc, 3, 1) = '$');

        pclook1     NUMBER;
        pclook2     NUMBER;
        return1     NUMBER;
        return2     NUMBER;
        bceg_partid NUMBER;
        atg_partid  NUMBER;

        maprec_fhandle utl_file.file_type;
        bit2id_fhandle utl_file.file_type;

    BEGIN
        -- open file
        maprec_fhandle := utl_file.fopen(path, 'dbmaprec.txt', 'w');
        bit2id_fhandle := utl_file.fopen(path, 'dbbit2id.txt', 'w');

        FOR rec IN bceg_atg_cur
        LOOP
            sp_getsmartprtcinfo(rec.bceg_prtc_match,
                                pclook1,
                                pclook2,
                                bceg_partid,
                                run_type);
            sp_getsmartprtcinfo(rec.atg_prtc_match,
                                return1,
                                return2,
                                atg_partid,
                                run_type);

            utl_file.put_line(maprec_fhandle,
                              '1' || '|' || pclook1 || '|' || pclook2 || '|' ||
                              return1 || '|' || return2);

            utl_file.put_line(bit2id_fhandle,
                              bceg_partid || '|' || pclook1 || '|' ||
                              pclook2);
            utl_file.put_line(bit2id_fhandle,
                              atg_partid || '|' || return1 || '|' ||
                              return2);

        END LOOP;

        FOR rec IN atg_qrp_cur
        LOOP
            sp_getsmartprtcinfo(rec.prtc,
                                pclook1,
                                pclook2,
                                atg_partid,
                                run_type);
            utl_file.put_line(maprec_fhandle,
                              '2' || '|' || pclook1 || '|' || pclook2 || '|' ||
                              rec.qrp_assy_type || '|' || 0);
        END LOOP;

        FOR rec IN bceg_qrp_cur
        LOOP
            sp_getsmartprtcinfo(rec.prtc,
                                pclook1,
                                pclook2,
                                bceg_partid,
                                run_type);
            utl_file.put_line(maprec_fhandle,
                              '3' || '|' || pclook1 || '|' || pclook2 || '|' ||
                              rec.qrp_assy_type || '|' || 0);

        END LOOP;

        -- update semaphore file
        sp_update_globaltxt_semaphore(path,
                                      'global.txt',
                                      'a',
                                      'dbmaprec.txt');
        sp_update_globaltxt_semaphore(path,
                                      'global.txt',
                                      'a',
                                      'dbbit2id.txt');

        -- close files, if open
        IF utl_file.is_open(maprec_fhandle)
        THEN
            utl_file.fclose(maprec_fhandle);
            utl_file.fclose(bit2id_fhandle);
        END IF;
    EXCEPTION
        WHEN utl_file.invalid_path THEN
            utl_file.fclose_all;
            raise_application_error(-20100, 'INVALID PATH');
        WHEN utl_file.invalid_mode THEN
            utl_file.fclose_all;
            raise_application_error(-20101, 'INVALID MODE');
        WHEN utl_file.invalid_operation THEN
            utl_file.fclose_all;
            raise_application_error(-20102, 'INVALID OPERATION');
        WHEN utl_file.invalid_filehandle THEN
            utl_file.fclose_all;
            raise_application_error(-20103, 'INVALID FILEHANDLE');
        WHEN utl_file.write_error THEN
            utl_file.fclose_all;
            raise_application_error(-20104, 'WRITE ERROR');
        WHEN utl_file.read_error THEN
            utl_file.fclose_all;
            raise_application_error(-20105, 'READ ERROR');
        WHEN utl_file.internal_error THEN
            utl_file.fclose_all;
            raise_application_error(-20106, 'INTERNAL ERROR');
            --  WHEN OTHERS THEN
        --    UTL_FILE.FCLOSE_ALL;
        --    RAISE_APPLICATION_ERROR(-20107,'UNKNOWN ERROR');
    END extract_cegatgqrp;

    /************************************************************************/
    /* Program Name: ext_refinish_complete                                  */
    /* Author:       MM5095       .                                         */
    /* Last Modified: 09/22/2001                                            */
    /* Description: Creates refinish complete text file for UltraMate       */
    /************************************************************************/
    PROCEDURE ext_refinish_complete(path VARCHAR2) IS
        CURSOR c1_cur IS
            SELECT /*+ EXT_REFINISH_COMPLETE.c1_cur */
             *
              FROM tmp_um_refinish_complete
             ORDER BY headernum,
                      itemnum;
        out_fhandle utl_file.file_type;
        bfound      BOOLEAN := FALSE;
        my_body_id  NUMBER;
        headernum   NUMBER := 0;

    BEGIN

        out_fhandle := utl_file.fopen(path, 'refcomp.txt', 'w');

        FOR c1_rec IN c1_cur
        LOOP
            IF c1_rec.itemnum = 0
            THEN
                BEGIN
                    SELECT /*+ EXT_REFINISH_COMPLETE.tmp_um_body_select */
                     body_id
                      INTO my_body_id
                      FROM tmp_um_body
                     WHERE prtc_body = c1_rec.refinish_complete;
                    headernum := headernum + 1;
                    bfound    := TRUE;
                    utl_file.put_line(out_fhandle,
                                      headernum || '|' || c1_rec.itemnum || '|' ||
                                      my_body_id);
                EXCEPTION
                    WHEN OTHERS THEN
                        bfound := FALSE;
                END;
            ELSIF bfound
            THEN
                BEGIN
                    SELECT /*+ EXT_REFINISH_COMPLETE.tmp_um_body_select2 */
                     body_id
                      INTO my_body_id
                      FROM tmp_um_body
                     WHERE prtc_body = c1_rec.refinish_complete;
                    utl_file.put_line(out_fhandle,
                                      headernum || '|' || c1_rec.itemnum || '|' ||
                                      my_body_id);
                EXCEPTION
                    WHEN OTHERS THEN
                        NULL; -- to do: error handling
                END;
            END IF;
        END LOOP;

        -- update semaphore file
        sp_update_globaltxt_semaphore(path,
                                      'global.txt',
                                      'a',
                                      'refcomp.txt');

        -- close files, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;
    EXCEPTION
        WHEN utl_file.invalid_path THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20100, 'INVALID PATH');
        WHEN utl_file.invalid_mode THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20101, 'INVALID MODE');
        WHEN utl_file.invalid_operation THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20102, 'INVALID OPERATION');
        WHEN utl_file.invalid_filehandle THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20103, 'INVALID FILEHANDLE');
        WHEN utl_file.write_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20104, 'WRITE ERROR');
        WHEN utl_file.read_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20105, 'READ ERROR');
        WHEN utl_file.internal_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20106, 'INTERNAL ERROR');
            --  WHEN OTHERS THEN
        --    UTL_FILE.FCLOSE(OUT_FHANDLE);
        --    RAISE_APPLICATION_ERROR(-20107,'UNKNOWN ERROR');
    END ext_refinish_complete;

    /************************************************************************/
    /* Program Name: ext_refsheet                                           */
    /* Author:       MM5095       .                                         */
    /* Last Modified: 09/21/2001                                            */
    /* Description: Creates reference sheet service                         */
    /************************************************************************/
    PROCEDURE ext_refsheet
    (
        path                VARCHAR2,
        my_edsys_path       VARCHAR2,
        edsys_path          VARCHAR2,
        my_ftp_dest_path    VARCHAR2,
        my_ftp_machine_name VARCHAR2,
        ftp_on_flag         BOOLEAN,
        ftp_ret_code        BINARY_INTEGER,
        run_type            VARCHAR2
    ) IS

    -- RS 09/25/2020 Cursors below replace ref.dat file
    CURSOR GetCategory IS
      SELECT b.category_name,
             a.category_skey,
             a.sequence_number,
             a.extract_flag
        FROM Ref_Sheet_Category a, CATEGORY b
       WHERE a.category_skey = b.category_skey
         AND a.subcategory_skey = 0
       ORDER BY a.sequence_number;

    CURSOR GetSubCategory(CategorySkey NUMBER) IS
      SELECT (SELECT category_name
                FROM CATEGORY
               WHERE category_skey = a.subcategory_skey) subcategory_name,
             a.subcategory_skey,
             a.sequence_number,
             a.extract_flag
        FROM Ref_Sheet_Category a
       WHERE a.category_skey = CategorySkey
         AND a.subcategory_skey <> 0
       ORDER BY a.sequence_number;

    CURSOR GetDetails(CategorySkey NUMBER, SubcategorySkey NUMBER) IS
      SELECT a.barcode,
             a.prtc,
             a.prtc_description,
             a.extract_flag,
             a.labortypeid,
             nvl(a.laboropid, 0) laboropid
        FROM Ref_Sheet_Category_detail a
       WHERE a.category_skey = CategorySkey
         AND a.subcategory_skey = SubcategorySkey
       ORDER BY a.sequence_number;

    display_flag CHAR(1);
    record_type  CHAR(1);
    --  barcode varchar2(6);
    labor_type      VARCHAR2(2);
    part_type       VARCHAR2(2);
    labor_operation VARCHAR2(2);
    prtc            VARCHAR2(10);
    in_fhandle      utl_file.file_type;
    header_fhandle  utl_file.file_type;
    section_fhandle utl_file.file_type;
    part_fhandle    utl_file.file_type;
    detail_fhandle  utl_file.file_type;
    out_fhandle     utl_file.file_type;
    line_in         VARCHAR2(80);
    n_header        NUMBER := 0;
    header_num      NUMBER;
    n_section       NUMBER := 0;
    n_part          NUMBER := 0;
    smartprtc       NUMBER;

    -- 05/09/2008 mm5095 => added support for mixed case description
    mc_category    category_description.mixed_case_category_name%TYPE;
    mc_subcategory subcat_description.mixed_case_subcat_name%TYPE;
    mc_prtc_desc   prtc_description.mixed_case_descr%TYPE;
    -- 05/09/2008 mm5095 => added support for mixed case text

    -- 09/28/2015 mm5095
    line_text_skey NUMBER;
    prtc_text_skey NUMBER;
    -- 09/28/2015 mm5095
  BEGIN

    -- open output files
        /* -- File generation disabled: refsheet file fopen (FTP sunset)
            out_fhandle     := utl_file.fopen(my_edsys_path, '000000.txt', 'w');
            header_fhandle  := utl_file.fopen(my_edsys_path, 'DA000000.txt', 'w');
            section_fhandle := utl_file.fopen(my_edsys_path, 'DB000000.txt', 'w');
            part_fhandle    := utl_file.fopen(my_edsys_path, 'DC000000.txt', 'w');
            detail_fhandle  := utl_file.fopen(my_edsys_path, 'DD000000.txt', 'w');
        -- end commented block */

    -- LOOP to get all cateogries
    FOR c IN GetCategory LOOP

      n_header := n_header + 1;

      IF c.extract_flag = 'Y' THEN
        header_num := n_header;
      ELSE
        header_num := 0;
      END IF;

      -- 05/09/2008 mm5095 => added support for mixed case Category description
      mc_category := sf_getmixedcasecategory(rtrim(c.category_name));
      -- 05/09/2008 mm5095 => added support for mixed case Category description

      -- 09/28/2015 mm5095
      line_text_skey := sf_get_line_text_skey(rtrim(c.category_name),
                                              mc_category);

      -- 09/28/2015 mm5095
      /* -- File generation disabled: DA put_line (FTP sunset)
          utl_file.put_line(header_fhandle,
                            header_num || '|' ||
                            rtrim(c.category_name)
                            -- 10/11/2004 mm5095 => added support for hidden lines
                            || '|1'
                            -- 10/11/2004 mm5095 => added support for hidden lines
                            -- 05/09/2008 mm5095 => added support for mixed case Category description
                            || '|' || mc_category
                            -- 05/09/2008 mm5095 => added support for mixed case Category description
                            -- 09/28/2015 mm5095
                            || '|' || line_text_skey
                            -- 09/28/2015 mm5095
                            -- 02/09/2017 mm5095
                            || '|' ||
                            sf_getfrench(line_text_skey,
                                         mc_category)
                            -- 02/09/2017 mm5095
                            );
      -- end commented block */
      -- 07/25/2007 mm5095 => insert into table to support part list initiative
      -- 03/22/2008 mm5095 => added exception handling
      -- 2008/12/31 pg2697 => added check of runtype since code is now shared by FULL and MINI
      -- 2020/04/05 pb0690 => removed check of run_type=FULL for MCE_Mini.

      BEGIN
        INSERT /*+ EXT_REFSHEET.um_data_da_insert */
        INTO um_data_da
          (service,
           category_skey,
           category,
           last_update_user,
           last_update_date,
           suppression_reason_code)
        VALUES
          ('000000', header_num, c.category_name, USER, SYSDATE, 0);
      EXCEPTION
        WHEN OTHERS THEN
          dbms_output.put_line('Pre-parse error inserting into um_data_da');
      END;

      -- 2008/12/31 pg2697 => added check of runtype since code is now shared by FULL and MINI
      -- 03/22/2008 mm5095 => added exception handling
      -- 07/25/2007 mm5095 => insert into table to support part list initiative

      -- LOOP to get Subcategories for parent Cateory
      FOR s IN GetSubCategory(c.category_skey) LOOP

        -- add section
        n_section := n_section + 1;

        IF s.extract_flag = 'Y' THEN
          header_num := n_header;
        ELSE
          header_num := 0;
        END IF;

        -- 05/09/2008 mm5095 => added support for mixed case Subcategory description
        mc_subcategory := sf_getmixedcasesubcategory(rtrim(s.subcategory_name));

        -- 05/09/2008 mm5095 => added support for mixed case Subcategory description

        -- 09/28/2015 mm5095
        line_text_skey := sf_get_line_text_skey(rtrim(s.subcategory_name),
                                                mc_subcategory);

        -- 09/28/2015 mm5095

        /* -- File generation disabled: DB put_line (FTP sunset)
            utl_file.put_line(section_fhandle,
                              header_num || '|' || n_section || '|-1|-1|' ||
                               s.subcategory_name
                              -- 10/11/2004 mm5095 => added support for hidden lines
                               || '|1'
                              -- 10/11/2004 mm5095 => added support for hidden lines
                              -- 05/09/2008 mm5095 => added support for mixed case Subcategory description
                               || '|' || mc_subcategory
                              -- 05/09/2008 mm5095 => added support for mixed case Subcategory description
                              -- 09/28/2015 mm5095
                               || '|' || line_text_skey
                              -- 09/28/2015 mm5095
                              -- 02/09/2017 mm5095
                               || '|' ||
                               sf_getfrench(line_text_skey, mc_subcategory)
                              -- 02/09/2017 mm5095
                              );
        -- end commented block */

        -- 07/25/2007 mm5095 => insert into table to support part list initiative
        -- 03/22/2008 mm5095 => added exception handling
        -- 11/21/2008 pg2697 => added check of runtype since code is now shared by FULL and MINI
        -- 2020/04/05 pb0690 => removed check of run_type=FULL for MCE_Mini.

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
            ('000000',
             header_num,
             n_section,
             to_date('01/01/1900', 'MM/DD/YYYY'),
             to_date('12/31/2099', 'MM/DD/YYYY'),
             s.subcategory_name,
             1,
             USER,
             SYSDATE);
        EXCEPTION
          WHEN OTHERS THEN
            dbms_output.put_line('Pre-parse error inserting into um_data_db');
        END;
        -- 03/22/2008 mm5095 => added exception handling

        IF header_num = 0 THEN
          -- 03/22/2008 mm5095 => added exception handling
          BEGIN
            INSERT /*+ EXT_REFSHEET.um_data_db_insert2 */

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
              ('000000',
               header_num,
               n_section + 1,
               to_date('01/01/1900', 'MM/DD/YYYY'),
               to_date('12/31/2099', 'MM/DD/YYYY'),
               s.subcategory_name,
               1,
               USER,
               SYSDATE);
          EXCEPTION
            WHEN OTHERS THEN
              dbms_output.put_line('Pre-parse error inserting into um_data_db');
          END;
        END IF;

        -- 2008/12/31 pg2697 => added check of runtype since code is now shared by FULL and MINI
        -- 03/22/2008 mm5095 => added exception handling
        -- 07/25/2007 mm5095 => insert into table to support part list initiative

        -- LOOP to get detail for category, subcateory
        FOR d IN GetDetails(c.category_skey, s.subcategory_skey) LOOP
          -- add part
          n_part := n_part + 1;

          IF d.extract_flag = 'Y' THEN
            header_num := n_header;
          ELSE
            header_num := 0;
          END IF;

          -- 05/09/2008 mm5095 => added support for mixed case Subcategory description
          mc_subcategory := sf_getmixedcasesubcategory(rtrim(d.prtc_description));

          -- 05/09/2008 mm5095 => added support for mixed case Subcategory description

          -- 09/28/2015 mm5095
          line_text_skey := sf_get_line_text_skey(rtrim(d.prtc_description),
                                                  mc_subcategory);

          -- 09/28/2015 mm5095

          /* -- File generation disabled: DC put_line (FTP sunset)
              utl_file.put_line(part_fhandle,
                                header_num || '|' || n_section || '|' || n_part || '|' ||
                                 d.prtc_description
                                -- 10/11/2004 mm5095 => added support for hidden lines
                                 || '|1'
                                -- 10/11/2004 mm5095 => added support for hidden lines
                                -- 05/09/2008 mm5095 => added support for mixed case Subcategory description
                                 || '|' || mc_subcategory
                                -- 05/09/2008 mm5095 => added support for mixed case Subcategory description
                                -- 09/28/2015 mm5095
                                 || '|' || line_text_skey
                                -- 09/28/2015 mm5095
                                -- 02/09/2017 mm5095
                                 || '|' ||
                                 sf_getfrench(line_text_skey, mc_subcategory)
                                -- 02/09/2017 mm5095
                                );
          -- end commented block */


          -- 07/25/2007 mm5095 => insert into table to support part list initiative
          -- 03/22/2008 mm5095 => added exception handling
          -- 2008/12/31 pg2697 => added check of runtype since code is now shared by FULL and MINI
          -- 2020/04/05 pb0690 => removed check of run_type=FULL for MCE_Mini.

          BEGIN
            INSERT /*+ EXT_REFSHEET.um_data_dc_insert */
            INTO um_data_dc
              (service,
               category_skey,
               subcategory_skey,
               part_skey,
               part,
               suppression_code,
               last_update_user,
               last_update_date)
            VALUES
              ('000000',
               header_num,
               n_section,
               n_part,
               d.prtc_description,
               1,
               USER,
               SYSDATE);
          EXCEPTION
            WHEN OTHERS THEN
              dbms_output.put_line('Pre-parse error inserting into um_data_dc');
          END;

          -- 2008/12/31 pg2697 => added check of runtype since code is now shared by FULL and MINI
          -- 03/22/2008 mm5095 => added exception handling
          -- 07/25/2007 mm5095 => insert into table to support part list initiative

          part_type := 0;
          smartprtc := sf_getsmartprtcid(d.prtc, run_type);

          -- 05/09/2008 mm5095 => added support for mixed case text
          mc_prtc_desc := sf_getmixedcaseprtc(0, rtrim(d.prtc_description));

          -- 05/09/2008 mm5095 => added support for mixed case text

          -- 09/28/2015 mm5095
          line_text_skey := sf_get_line_text_skey(rtrim(d.prtc_description),
                                                  rtrim(d.prtc_description));
          prtc_text_skey := sf_get_line_text_skey(upper(mc_prtc_desc),
                                                  mc_prtc_desc);

          -- 09/28/2015 mm5095

          -- add detail
          /* -- File generation disabled: DD put_line (FTP sunset)
              utl_file.put_line(detail_fhandle,
                                header_num || '|' || n_section || '|' || n_part || '|' ||
                                 d.barcode || '|' -- resequence (null)
                                 || '|F' -- quad_flag
                                 || '|-1' -- start date
                                 || '|-1' -- end dates
                                 || '|0' -- right/left code
                                 || '|' || d.labortypeid -- labor type
                                 || '|' || d.laboropid -- labor op
                                 || '|' || to_number(part_type) -- part type
                                 || '|' -- us part number (null)
                                 || '|' -- can part number (null)
                                 || '|' || d.prtc_description || '|' ||
                                 d.prtc_description || '|0' -- us effective date1
                                 || '|0' -- us price1
                                 || '|0' -- can effective date1
                                 || '|0' -- can price1
                                 || '|0' -- us effective date2
                                 || '|0' -- us price2
                                 || '|0' -- can effective date2
                                 || '|0' -- can price2
                                 || '|0' -- ceg labor time
                                 || '|' || smartprtc -- smart prtc
                                -- 10/11/2004 mm5095 => added support for hidden lines
                                 || '|1'
                                -- 10/11/2004 mm5095 => added support for hidden lines
                                -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
                                 || '|0' -- header sequence
                                -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
                                -- 10/24/2006 mm5095 => added support for special material qualifiers
                                 || '|' || d.prtc_description --rtrim(substr(line_in, 25)) -- prtc description
                                -- 10/24/2006 mm5095 => added support for special material qualifiers
                                -- 02/05/2008 jr6600 => added support for special material flag
                                 || '|0' -- special_material_flag
                                -- 02/05/2008 jr6600 => added support for special material flag
                                -- 05/09/2008 mm5095 => added support for mixed case text
                                 || '|' || mc_prtc_desc
                                -- 05/09/2008 mm5095 => added support for mixed case text
                                -- 09/28/2015
                                 || '|' || line_text_skey || '|' ||
                                 prtc_text_skey
                                -- 09/28/2015
                                -- 02/09/2017 mm5095
                                 || '|' ||
                                 sf_getfrench(line_text_skey,
                                              rtrim(d.prtc_description)) || '|' ||
                                 sf_getfrench(prtc_text_skey, mc_prtc_desc)
                                -- 02/09/2017 mm5095
                                );
          -- end commented block */

          -- 07/25/2007 mm5095 => insert into table to support part list initiative
          -- 03/22/2008 mm5095 => added exception handling
          -- 2008/12/31 pg2697 => added check of runtype since code is now shared by FULL and MINI
          -- 2020/04/05 pb0690 => removed check of run_type=FULL for MCE_Mini.

          BEGIN
            INSERT /*+ EXT_REFSHEET.um_data_dd_insert */
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
               material_flag)
            VALUES
              ('000000',
               header_num,
               n_section,
               n_part,
               d.barcode,
               NULL,
               'F',
               to_date('01/01/1900', 'MM/DD/YYYY'),
               to_date('12/31/2099', 'MM/DD/YYYY'),
               0,
               d.labortypeid,
               d.laboropid,
               to_number(part_type),
               NULL,
               NULL,
               rtrim(d.prtc_description),
               rtrim(d.prtc_description),
               NULL,
               0,
               NULL,
               0,
               NULL,
               0,
               NULL,
               0,
               0,
               smartprtc,
               1,
               0,
               USER,
               SYSDATE,
               rtrim(substr(mc_prtc_desc, 0, 100)),
               0);
          EXCEPTION
            WHEN OTHERS THEN
              dbms_output.put_line('Pre-parse error inserting into um_data_dd');
          END;

        -- 2008/12/31 pg2697 => added check of runtype since code is now shared by FULL and MINI
        -- 03/22/2008 mm5095 => added exception handling
        -- 07/25/2007 mm5095 => insert into table to support part list initiative
        END LOOP; -- Reference Sheet Detail Cursor
      END LOOP; -- Reference Sheet SubCategory Cursor

    END LOOP; -- Reference Sheet Category Cursor

    -- output semaphore information
    /* -- File generation disabled: refsheet semaphore put_line and fclose (FTP sunset)
        utl_file.put_line(out_fhandle, 'DA000000.txt');
        utl_file.put_line(out_fhandle, 'DB000000.txt');
        utl_file.put_line(out_fhandle, 'DC000000.txt');
        utl_file.put_line(out_fhandle, 'DD000000.txt');
        utl_file.fclose(out_fhandle);

        utl_file.fclose(header_fhandle);
        utl_file.fclose(section_fhandle);
        utl_file.fclose(part_fhandle);
        utl_file.fclose(detail_fhandle);
    -- end commented block */

    /* -- File generation disabled: zz000000 fopen and fclose (FTP sunset)
        out_fhandle := utl_file.fopen(my_edsys_path, 'zz000000.txt', 'w');

        -- 2007/02/09 mm5095 => bug fix
        IF utl_file.is_open(out_fhandle) THEN
          utl_file.fclose(out_fhandle);
        END IF;
        -- 2007/02/09 mm5095 => bug fix
    -- end commented block */

    /* -- FTP send disabled: 000000.txt sp_ftp_command (FTP sunset)
        -- ftp to NT
        sp_ftp_command('000000.txt',
                       edsys_path,
                       my_ftp_dest_path,
                       my_ftp_machine_name,
                       ftp_on_flag,
                       ftp_ret_code);
    -- end commented block */
    --  FTP_COMMAND('000000.txt', edsys_path, full_flag);
  EXCEPTION
    WHEN utl_file.invalid_path THEN
      utl_file.fclose_all;
      raise_application_error(-20100, 'INVALID PATH');
    WHEN utl_file.invalid_mode THEN
      utl_file.fclose_all;
      raise_application_error(-20101, 'INVALID MODE');
    WHEN utl_file.invalid_operation THEN
      utl_file.fclose_all;
      raise_application_error(-20102, 'INVALID OPERATION');
    WHEN utl_file.invalid_filehandle THEN
      utl_file.fclose_all;
      raise_application_error(-20103, 'INVALID FILEHANDLE');
    WHEN utl_file.write_error THEN
      utl_file.fclose_all;
      raise_application_error(-20104, 'WRITE ERROR');
    WHEN utl_file.read_error THEN
      utl_file.fclose_all;
      raise_application_error(-20105, 'READ ERROR');
    WHEN utl_file.internal_error THEN
      utl_file.fclose_all;
      raise_application_error(-20106, 'INTERNAL ERROR');
      --  WHEN OTHERS THEN
    --    UTL_FILE.FCLOSE_ALL;
    --    RAISE_APPLICATION_ERROR(-20107,'UNKNOWN UTL_FILE ERROR');
  END ext_refsheet;

    /* ----------------------------------------------------------------------------- SP_FTP_COMMAND */
    PROCEDURE sp_ftp_command
    (
        filename            VARCHAR2,
        edsys_path          VARCHAR2,
        my_ftp_dest_path    VARCHAR2,
        my_ftp_machine_name VARCHAR2,
        ftp_on_flag         BOOLEAN,
        ftp_ret_code        BINARY_INTEGER
    )
    --PROCEDURE FTP_COMMAND(filename varchar2, edsys_path varchar2, full_flag char)
     IS
        ftp_return_cd BINARY_INTEGER;
        perl_path     VARCHAR2(50);

    BEGIN
        ftp_return_cd := ftp_ret_code;
        -- 20110323 mm5095 => modified to support dynamic update of path where ftp_put.pl is located
        perl_path := substr(edsys_path, 1, 5) || '/race/share/bin';

        IF ftp_on_flag
           AND ftp_return_cd = 0
        THEN
            sp_um_ftp_put(perl_path,
                          filename,
                          'ftpuser',
                          'FTP123abc',
                          edsys_path || '/',
                          my_ftp_dest_path,
                          my_ftp_machine_name,
                          ftp_return_cd);
            -- 20110323 mm5095 => modified to support dynamic update of path where ftp_put.pl is located

            -- note: if return code = 127, perl script is not in path identified above
            IF ftp_return_cd != 0
            THEN
                dbms_output.put_line('FTP ERROR: ' || ftp_return_cd ||
                                     'on file: ' || filename);
                NULL; -- error! do: how to handle?
            END IF;
        ELSE
            NULL; -- ftp failed earlier, skip ftp
        END IF;
    END;

    /* ----------------------------------------------------------------------------- create_altpart */
    PROCEDURE create_altpart
    (
        service_barcode VARCHAR2,
        mfr_in          VARCHAR2,
        service_in      VARCHAR2,
        version_in      VARCHAR2,
        path            VARCHAR2,
        run_type        VARCHAR2
    ) IS
        CURSOR part_capa_xref_cur
        (
            part_supplier_num_in VARCHAR2,
            part_number_in       VARCHAR2
        ) IS
            SELECT /*+ CREATE_ALTPART.part_capa_xref_cur */
             capa_certified_flag
              FROM part_capa_xref
             WHERE part_supplier_number = part_supplier_num_in
               AND part_number = part_number_in
               AND capa_certified_flag = 'Y';

        --  2012/08/08 mm5095 => added to support NSF
        CURSOR part_nsf_xref_cur
        (
            part_supplier_num_in VARCHAR2,
            part_number_in       VARCHAR2
        ) IS
            SELECT /*+ CREATE_ALTPART.part_nsf_xref_cur */
             nsf_certified_flag
              FROM race.part_nsf_xref
             WHERE part_supplier_number = part_supplier_num_in
               AND part_number = part_number_in
               AND nsf_certified_flag = 'Y';
        --  2012/08/08 mm5095 => added to support NSF

        CURSOR service_cur
        (
            mfr_in     VARCHAR2,
            service_in VARCHAR2,
            version_in VARCHAR2
        ) IS
            SELECT /*+ CREATE_ALTPART.service_cur */
             a.barcode,
             prtc,
             prtc_body,
             part_supplier_number,
             part_number,
             c.part_skey
              FROM ext.service_category_detail a,
                   detail_part_xref            b,
                   part                        c
             WHERE a.mfr_number = mfr_in -- '002'
               AND a.service_number = service_in -- '23200'
               AND a.version_type = version_in --'PR'
               AND b.unique_row_id = a.unique_row_id
               AND b.version_type = a.version_type
               AND c.part_skey = b.part_skey
               AND (c.part_supplier_country_abbr = 'US' OR
                   c.part_supplier_country_abbr = 'CA')
             ORDER BY barcode;

        CURSOR altpart_cur(skey_in NUMBER) IS
            SELECT /*+ ordered use_nl(b a) */
             a.altpart_supplier_number,
             altpart_number,
             altpart_reconditioned_flag rcnd_flag,
             capa_certified_flag,
             --  2012/08/08 mm5095 => added to support NSF
             nsf_certified_flag,
             --  2012/08/08 mm5095 => added to support NSF
             altpart_price,
             a.oem_discount_flag
              FROM altpart_supplier  b,
                   part_altpart_xref a
             WHERE part_skey = skey_in
                  --11/17/2004 mm5095 => added support for MAPP v2.5 enhancements
               AND b.altpart_supplier_number = a.altpart_supplier_number
               AND b.part_count > 0
               AND b.delete_date IS NULL
                  --11/17/2004 mm5095 => added support for MAPP v2.5 enhancements
                  -- 11/29/2012 mm5095 => limit mapp suppliers
               AND b.altpart_supplier_number IN
                   (SELECT altpart_supplier_number_xref
                      FROM mapp_supplier_xref)
            -- 11/29/2012 mm5095 => limit mapp suppliers
             ORDER BY altpart_supplier_number,
                      altpart_reconditioned_flag,
                      capa_certified_flag,
                      --  2012/08/08 mm5095 => added to support NSF
                      nsf_certified_flag,
                      --  2012/08/08 mm5095 => added to support NSF
                      oem_discount_flag,
                      to_number(altpart_price);

        -- 2008/12/31 PAG - Older commented sections of code removed
        --                 to reduce package size and improve readability.
        --                 Check prior PVCS version, if you want to view this code.
        --    cursor cat_cur(prtc_body_in varchar2, reconditioned_in varchar2, capa_flag_in varchar2) is
        --    cursor cat_cur2(prtc_body_in varchar2, reconditioned_in varchar2) is
        -- 2008/12/31 PAG - Older commented sections of code removed

        CURSOR cat_cur3(prtc_body_in VARCHAR2) IS
            SELECT /*+ CREATE_ALTPART.cat_cur3 */
             a.altpart_class_code,
             reconditioned_flag,
             certified_flag
              FROM altpart_class_prtc_xref a,
                   altpart_class           b
             WHERE prtc_body = prtc_body_in
               AND b.altpart_class_code = a.altpart_class_code;

        reconditioned_flag CHAR(1);
        --        part_number         VARCHAR2(20);
        altpart_number VARCHAR2(20);
        certified_flag VARCHAR2(2);
        --        certified_code      VARCHAR2(2);
        xref_certified_flag CHAR(1);
        --  2012/08/08 mm5095 => added to support NSF
        nsf_certified_flag CHAR(1);
        --  2012/08/08 mm5095 => added to support NSF
        cat_code CHAR(3);

        last_reconditioned_flag      CHAR(1) := ' ';
        last_altpart_supplier_number VARCHAR2(4) := ' ';
        last_certified_flag          VARCHAR2(2) := ' ';
        last_oem_discount            CHAR(1) := ' '; -- 05/15/2006 mm5095 => added support for oem_discount

        out_fhandle utl_file.file_type;
        bfirsttime  BOOLEAN := TRUE;
        bfound      BOOLEAN;
        last_row    INTEGER;

        -- 2012/10/11 mm5095 => added to support NSF
        altpart_certified_flag CHAR(1);
        -- 2012/10/11 mm5095 => added to support NSF

        TYPE altpart_class_table_type IS TABLE OF cat_cur3%ROWTYPE INDEX BY BINARY_INTEGER;
        altpart_class_table       altpart_class_table_type;
        empty_altpart_class_table altpart_class_table_type;

    BEGIN

        FOR s_rec IN service_cur(mfr_in, service_in, version_in)
        LOOP
            xref_certified_flag := 'N';
            --  2012/08/08 mm5095 => added to support NSF
            nsf_certified_flag := 'N';
            --  2012/08/08 mm5095 => added to support NSF

            OPEN part_capa_xref_cur(s_rec.part_supplier_number,
                                    s_rec.part_number);
            FETCH part_capa_xref_cur
                INTO xref_certified_flag;
            CLOSE part_capa_xref_cur;

            --  2012/08/08 mm5095 => added to support NSF
            OPEN part_nsf_xref_cur(s_rec.part_supplier_number,
                                   s_rec.part_number);
            FETCH part_nsf_xref_cur
                INTO nsf_certified_flag;
            CLOSE part_nsf_xref_cur;
            --  2012/08/08 mm5095 => added to support NSF

            altpart_class_table := empty_altpart_class_table;
            last_row            := 0;
            FOR cat_rec IN cat_cur3(s_rec.prtc_body)
            LOOP
                last_row := last_row + 1;
                altpart_class_table(last_row) := cat_rec;
            END LOOP;

            IF last_row > 0
            THEN
                last_altpart_supplier_number := ' ';
                FOR rec IN altpart_cur(s_rec.part_skey)
                LOOP

                    -- for each barcode, output the least expensive alternate part (new and used, if found) per supplier
                    IF xref_certified_flag = 'Y'
                       AND rec.capa_certified_flag = 'Y'
                    THEN
                        --  2012/08/08 mm5095 => added to support NSF
                        certified_flag := '1';
                        --            certified_flag := 'Y';
                        --  2012/08/08 mm5095 => added to support NSF
                    ELSE
                        --  2012/08/08 mm5095 => added to support NSF
                        certified_flag := '0';
                        --            certified_flag := 'N';
                        --  2012/08/08 mm5095 => added to support NSF
                    END IF;

                    --  2012/08/08 mm5095 => added to support NSF
                    -- 2013/01/07 mm5095 => uncomment code to activate NSF
                    IF nsf_certified_flag = 'Y'
                       AND rec.nsf_certified_flag = 'Y'
                    THEN
                        IF certified_flag = '1'
                        THEN
                            certified_flag := '3';
                        ELSE
                            certified_flag := '2';
                        END IF;
                    END IF;
                    -- 2013/01/07 mm5095 => uncomment code to activate NSF
                    --  2012/08/08 mm5095 => added to support NSF

                    IF rec.rcnd_flag = 'N'
                    THEN
                        reconditioned_flag := '0';
                    ELSE
                        reconditioned_flag := '1';
                    END IF;

                    IF substr(s_rec.prtc, 10, 1) = 'A'
                    THEN
                        altpart_number := 'ORDER BY APPLIC.    ';
                    ELSE
                        altpart_number := rpad(rec.altpart_number, 20, ' ');
                    END IF;

                    -- 2012/10/11 mm5095 => added to support NSF
                    --          if certified_flag = 'Y' then
                    IF certified_flag > '0'
                    THEN
                        altpart_certified_flag := 'Y';
                    ELSE
                        altpart_certified_flag := 'N';
                    END IF;
                    -- 2012/10/11 mm5095 => added to support NSF

                    bfound := FALSE;
                    FOR n IN 1 .. last_row
                    LOOP
                        IF rec.rcnd_flag = altpart_class_table(n)
                          .reconditioned_flag
                          --  2012/08/08 mm5095 => added to support NSF
                          -- 2012/10/11 mm5095 => added to support NSF
                           AND altpart_certified_flag = altpart_class_table(n)
                          .certified_flag
                        THEN
                            --              and (rec.capa_certified_flag = altpart_class_table(n).certified_flag
                            --                  or rec.nsf_certified_flag = altpart_class_table(n).certified_flag) then
                            -- 2012/10/11 mm5095 => added to support NSF--  2012/08/08 mm5095 => added to support NSF
                            IF altpart_class_table(n)
                             .certified_flag = 'Y'
                                AND rec.rcnd_flag = 'N'
                            THEN
                                NULL;
                            ELSE
                                --  2012/08/08 mm5095 => added to support NSF
                                certified_flag := '1';
                                --                certified_flag := 'Y';
                            END IF;

                            cat_code := altpart_class_table(n)
                                        .altpart_class_code;
                            bfound   := TRUE;
                            EXIT;
                        END IF;
                    END LOOP;

                    IF NOT bfound
                    THEN
                        FOR n IN 1 .. last_row
                        LOOP
                            IF rec.rcnd_flag = altpart_class_table(n)
                              .reconditioned_flag
                            THEN
                                IF altpart_class_table(n)
                                 .certified_flag = 'Y'
                                    AND rec.rcnd_flag = 'N'
                                THEN
                                    NULL;
                                ELSE
                                    --  2012/08/08 mm5095 => added to support NSF
                                    certified_flag := '1';
                                    --                  certified_flag := 'Y';
                                    --  2012/08/08 mm5095 => added to support NSF
                                END IF;
                                cat_code := altpart_class_table(n)
                                            .altpart_class_code;
                                bfound   := TRUE;
                                EXIT;
                            END IF;
                        END LOOP;
                    END IF;

                    IF bfound
                    THEN
                        IF rec.altpart_supplier_number !=
                           last_altpart_supplier_number
                           OR certified_flag != last_certified_flag
                           OR reconditioned_flag != last_reconditioned_flag
                          -- 05/15/2006 mm5095 => added support for oem_discount
                           OR rec.oem_discount_flag != last_oem_discount
                        -- 05/15/2006 mm5095 => added support for oem_discount
                        THEN

                            --  2012/08/08 mm5095 => added to support NSF
                            --              if certified_flag = 'Y' then
                            --                certified_code := '89';
                            --              else
                            --                certified_code := '78';
                            --              end if;
                            --  2012/08/08 mm5095 => added to support NSF
                            /*
                                          if s_rec.barcode is not null then
                                            utl_file.put_line(out_fhandle, service_barcode || s_rec.barcode
                                              || reconditioned_flag || rec.altpart_supplier_number
                                              || rpad(altpart_number,20) || certified_flag
                                              || to_char(rec.altpart_price * 100,'fm099999') || s_rec.prtc_body || cat_code);
                                          end if;
                            */
                            IF s_rec.barcode IS NOT NULL
                            THEN
                                IF bfirsttime
                                THEN
                                    /* -- File generation disabled: DL file fopen (FTP sunset)
                                        out_fhandle := utl_file.fopen(path,
                                                                      'DL' ||
                                                                      service_barcode ||
                                                                      '.txt',
                                                                      'w');
                                    -- end commented block */
                                    bfirsttime  := FALSE;
                                END IF;

                                --  2012/08/08 mm5095 => converting to decimal value for Raima load
                                IF certified_flag = '0'
                                THEN
                                    certified_flag := '48';
                                ELSIF certified_flag = '1'
                                THEN
                                    certified_flag := '49';
                                ELSIF certified_flag = '2'
                                THEN
                                    certified_flag := '50';
                                ELSIF certified_flag = '3'
                                THEN
                                    certified_flag := '51';
                                END IF;
                                --  2012/08/08 mm5095 => converting to decimal value for Raima load

                                /* -- File generation disabled: DL put_line (FTP sunset)
                                    utl_file.put_line(out_fhandle,
                                                      s_rec.barcode || '|' ||
                                                       sf_supplierconversion(rec.altpart_supplier_number) || '|' ||
                                                       reconditioned_flag || '|' ||
                                                       to_number(cat_code) || '|' ||
                                                       rec.altpart_price * 100 || '|' ||
                                                      --  2012/08/08 mm5095 => added to support NSF
                                                       certified_flag || '|'
                                                      --                  certified_code || '|'
                                                      --  2012/08/08 mm5095 => added to support NSF
                                                       || substr(ltrim(altpart_number),
                                                                 1,
                                                                 20) || '|' ||
                                                       rec.oem_discount_flag);
                                -- end commented block */

                                -- 01/13/2010 mm5095 => insert into table to support next gen
                                -- activate when appropriate
                                /*                if run_type = 'FULL' then
                                                  BEGIN
                                                    INSERT /*+ UPDATE_UM_DL.um_data_dl_update
                                                    INTO um_data_dl
                                                    (service, barcode, supplier_code, reconditioned_flag, category_code, price, certified_code, altpart_number, oem_discount_flag)
                                                    VALUES(service_barcode, s_rec.barcode, sf_supplierconversion(rec.altpart_supplier_number), reconditioned_flag, to_number(cat_code),
                                                      rec.altpart_price * 100, certified_code, substr(ltrim(altpart_number),1,20),
                                                      rec.oem_discount_flag);
                                                  EXCEPTION WHEN OTHERS THEN
                                                    dbms_output.put_line('Parse error inserting into um_data_dl');
                                                  END;
                                                end IF;
                                */
                                -- 01/13/2010 mm5095 => insert into table to support next gen
                            END IF;

                            last_altpart_supplier_number := rec.altpart_supplier_number;
                            last_certified_flag          := certified_flag;
                            last_reconditioned_flag      := reconditioned_flag;
                            -- 05/15/2006 mm5095 => added support for oem_discount
                            last_oem_discount := rec.oem_discount_flag;
                            -- 05/15/2006 mm5095 => added support for oem_discount
                        END IF;
                    END IF;
                END LOOP;
            END IF;
        END LOOP;

        /* -- File generation disabled: DL fclose and semaphore (FTP sunset)
            IF utl_file.is_open(out_fhandle)
            THEN
                utl_file.fclose(out_fhandle);

                -- create semaphore file
                pkg_ultramate_common.sp_output_barcode_semaphore(path,
                                                                 service_barcode,
                                                                 'DL' ||
                                                                 service_barcode ||
                                                                 '.txt',
                                                                 'a');

            END IF;
        -- end commented block */
    END create_altpart;

    /* ----------------------------------------------------------------------------- sp_getATGService */
    -- get atg mfr/service for ceg mfr/service
    PROCEDURE sp_getatgservice
    (
        mfr_in      VARCHAR2,
        service_in  VARCHAR2,
        atg_mfr     IN OUT VARCHAR2,
        atg_service IN OUT VARCHAR2,
        run_type    VARCHAR2
    ) IS

        CURSOR full_cur IS
            SELECT /*+ sp_getATGService.full_cur */
            DISTINCT atgmanufacturernumber,
                     atgservicenumber
              FROM vcd_vehicle_service a,
                   um_extract          b
             WHERE manufacturernumber = mfr_in
               AND servicenumber = service_in
               AND b.mfr_number = atgmanufacturernumber
               AND b.service_number = atgservicenumber;

        CURSOR mini_cur IS
            SELECT /*+ sp_getATGService.mini_cur */
            DISTINCT atgmanufacturernumber,
                     atgservicenumber
              FROM vcd_vehicle_service a,
                   tmp_um_extract      b
             WHERE manufacturernumber = mfr_in
               AND servicenumber = service_in
               AND b.mfr_number = atgmanufacturernumber
               AND b.service_number = atgservicenumber;

    BEGIN

        atg_mfr     := NULL;
        atg_service := NULL;

        IF run_type = 'FULL'
        THEN
            OPEN full_cur;
            FETCH full_cur
                INTO atg_mfr,
                     atg_service;
            CLOSE full_cur;
        ELSE
            OPEN mini_cur;
            FETCH mini_cur
                INTO atg_mfr,
                     atg_service;
            CLOSE mini_cur;
        END IF;

    END;

    /*************************************************************************
    * Description:
    * -- 04/05/2020 pb0690 => For MCE Mini
    *************************************************************************/
    PROCEDURE truncate_um_extm_tables IS

    BEGIN

        sp_truncate_table_authid('um_data_a,um_data_e,um_data_da,um_data_db,um_data_dc,um_data_dd,um_data_de,um_data_df,um_data_dg,um_data_dh,um_data_di,um_data_dj,um_data_dk,um_data_dr,um_data_oh,um_data_od,um_data_r',
                                 FALSE);

        pkg_ultramate_common.reset_seq('um_data_dh_seq');
        pkg_ultramate_common.reset_seq('um_data_dj_seq');

        -- 06/15/2016 mm5095 => per request by next gen, reference sheet note
        BEGIN
            INSERT /*+ um_data_di insert */
            INTO um_data_di
            VALUES
                ('000000',
                 1,
                 1,
                 'Two Tone Does Not Apply to Blended Panels',
                 USER,
                 SYSDATE);

        EXCEPTION
            WHEN OTHERS THEN
                dbms_output.put_line('pkg_ultramate_common - Error inserting into um_data_di' ||
                                     ' Error : ' || SQLCODE || ': ' ||
                                     substr(SQLERRM, 1, 120));
        END;

        BEGIN

            INSERT /*+ um_data_dj insert8 */
            INTO um_data_dj
                (service,
                 barcode,
                 note_type,
                 note_id)
            VALUES
                ('000000',
                 '933000',
                 35,
                 1);

        EXCEPTION
            WHEN OTHERS THEN
                dbms_output.put_line('pkg_ultramate_common - Error inserting into um_data_dj' ||
                                     ' Error : ' || SQLCODE || ': ' ||
                                     substr(SQLERRM, 1, 120));
        END;

        BEGIN

            INSERT /*+ um_data_dh insert */
            INTO um_data_dh
                (service,
                 category_skey,
                 subcategory_skey,
                 part_skey,
                 note_type,
                 note_id)
            VALUES
                ('000000',
                 2,
                 2,
                 23,
                 171,
                 1);
        EXCEPTION
            WHEN OTHERS THEN
                dbms_output.put_line('pkg_ultramate_common - Error inserting into um_data_dh' ||
                                     ' Error : ' || SQLCODE || ': ' ||
                                     substr(SQLERRM, 1, 120));
        END;

    END;

    /*************************************************************************
    * Description:
    *************************************************************************/

    PROCEDURE insert_um_data_dc
    (
        service          VARCHAR2,
        header_num       INTEGER,
        n_section        INTEGER,
        n_part           INTEGER,
        part_text        VARCHAR2,
        suppression_code INTEGER,
        part_or_labor    VARCHAR2
    ) IS
    BEGIN
        INSERT /*+ insert_um_data_dc */
        INTO um_data_dc
            (service,
             category_skey,
             subcategory_skey,
             part_skey,
             part,
             suppression_code,
             part_or_labor,
             last_update_user,
             last_update_date)
        VALUES
            (service,
             header_num,
             n_section,
             n_part,
             part_text,
             suppression_code,
             part_or_labor,
             USER,
             SYSDATE);
    EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line('pkg_ultramate_common - Pre-parse error inserting into um_data_dc ' ||
                                 ' Error : ' || SQLCODE || ': ' ||
                                 substr(SQLERRM, 1, 120));
    END;

    /*************************************************************************
    * Description:
    *************************************************************************/

    PROCEDURE insert_um_data_dd
    (
        service          VARCHAR2,
        category_skey    NUMBER,
        subcategory_skey NUMBER,
        part_skey        NUMBER,
        barcode          VARCHAR2,
        sequence         INTEGER,
        quad_flag        CHAR,
        start_date       DATE,
        end_date         DATE,
        right_left_code  INTEGER,
        labor_type       INTEGER,
        labor_op         INTEGER,
        part_type        INTEGER,
        us_part_number   VARCHAR2,
        ca_part_number   VARCHAR2,
        part_descr       VARCHAR2,
        prtc_descr       VARCHAR2,
        us_effect_date1  DATE,
        us_price1        INTEGER,
        ca_effect_date1  DATE,
        ca_price1        INTEGER,
        us_effect_date2  DATE,
        us_price2        INTEGER,
        ca_effect_date2  DATE,
        ca_price2        INTEGER,
        ceg_time         INTEGER,
        partid           INTEGER,
        suppression_code INTEGER,
        header_sequence  INTEGER,
        material_desc    VARCHAR2,
        material_flag    INTEGER,
        unique_row_id    INTEGER,
        component_skey   INTEGER
    ) IS
    BEGIN
        INSERT /*+ insert_um_data_dd */
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
             to_number(labor_type),
             to_number(labor_op),
             to_number(part_type),
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
             USER,
             SYSDATE,
             material_desc,
             material_flag,
             unique_row_id,
             component_skey);

    EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line('pkg_ultramate_common - Pre-parse error inserting into um_data_dd' ||
                                 'service ' || ', ' || service || ', ' ||
                                 'barcode ' || ', ' ||
                                 substr(barcode, 3, 6) || ', ' ||
                                 'Error : ' || SQLCODE || ': ' ||
                                 substr(SQLERRM, 1, 120));
    END;

    /*************************************************************************
    * Description:
    *************************************************************************/

    PROCEDURE insert_um_data_de
    (
        service_barcode_in VARCHAR2,
        nheader            INTEGER,
        nsection           INTEGER,
        npart              INTEGER,
        nimage_in          VARCHAR2,
        callout_number_in  VARCHAR2,
        x_coordinate       INTEGER,
        y_coordinate       INTEGER,
        x_extent           INTEGER,
        y_extent           INTEGER
    ) IS

    BEGIN
        INSERT /*+ insert_um_data_de */
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
             x_coordinate,
             y_coordinate,
             x_extent,
             y_extent);
    EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line('pkg_ultramate_common - Parse error inserting into um_data_de' ||
                                 ' Error : ' || SQLCODE || ': ' ||
                                 substr(SQLERRM, 1, 120));
    END;

    /*************************************************************************
    * Description:
    *************************************************************************/

    PROCEDURE insert_um_data_dh
    (
        service          VARCHAR2,
        category_skey    VARCHAR2,
        subcategory_skey INTEGER,
        part_skey        INTEGER,
        note_type        INTEGER,
        note_id          INTEGER
    ) IS
    BEGIN
        INSERT /*+ insert_um_data_dh */
        INTO um_data_dh
            (service,
             category_skey,
             subcategory_skey,
             part_skey,
             note_type,
             note_id)
        VALUES
            (service,
             category_skey,
             subcategory_skey,
             part_skey,
             note_type,
             note_id);

    EXCEPTION
        WHEN dup_val_on_index THEN
            NULL; -- skip duplicate
        WHEN OTHERS THEN
            dbms_output.put_line('pkg_ultramate_common - Parse error inserting into um_data_dh' ||
                                 ' Error : ' || SQLCODE || ': ' ||
                                 substr(SQLERRM, 1, 120));
    END;

    /*************************************************************************
    * Description:
    *************************************************************************/

    PROCEDURE insert_um_data_dj
    (
        service_barcode_in VARCHAR2,
        barcode            VARCHAR2,
        note_type          INTEGER,
        note_id            INTEGER
    ) IS
    BEGIN
        INSERT /*+ insert_um_data_dj */
        INTO um_data_dj
            (service,
             barcode,
             note_type,
             note_id)
        VALUES
            (service_barcode_in,
             barcode,
             note_type,
             note_id);
    EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line('pkg_ultramate_common - Parse error inserting into um_data_dj' ||
                                 ' Error : ' || SQLCODE || ': ' ||
                                 substr(SQLERRM, 1, 120));
    END;

    /* ----------------------------------------------------------------------------- UPDATE_UM_DF */
    -- 10/24/2007 mm5095 => insert into table to support FocusWrite rewrite
    -- 2018/04 pg2697 => added quantity
    PROCEDURE update_um_df
    (
        service_in      VARCHAR2,
        relationship_in INTEGER,
        parent_in       VARCHAR2,
        child_in        VARCHAR2,
        quantity_in     NUMBER
    ) IS
    BEGIN
        -- 2018/04 pg2697 => added quantity
        INSERT /*+ UPDATE_UM_DF.um_data_df_insert */
        INTO um_data_df
            (service,
             relationship,
             parent_barcode,
             child_barcode,
             quantity,
             last_update_user,
             last_update_date)
        VALUES
            (service_in,
             relationship_in,
             parent_in,
             child_in,
             quantity_in,
             USER,
             SYSDATE);
        -- 03/22/2008 mm5095 => added exception handling
    EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line('Parse error inserting into um_data_df');
            -- 03/22/2008 mm5095 => added exception handling
    END;
    -- 10/24/2007 mm5095 => insert into table to support FocusWrite rewrite

    /* ----------------------------------------------------------------------------- UPDATE_UM_DI */
    -- 10/24/2007 mm5095 => insert into table to support french rewrite
    PROCEDURE update_um_di
    (
        service_in VARCHAR2,
        note_id_in INTEGER,
        nline_in   INTEGER,
        text_in    VARCHAR2
    ) IS
    BEGIN
        INSERT /*+ UPDATE_UM_DI.um_data_di_insert */
        INTO um_data_di
            (service,
             note_id,
             line_sequence,
             note_text,
             last_update_user,
             last_update_date)
        VALUES
            (service_in,
             note_id_in,
             nline_in,
             text_in,
             USER,
             SYSDATE);
        -- 03/22/2008 mm5095 => added exception handling
    EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line('Parse error inserting into um_data_di ' ||
                                 SQLCODE || ': ' || substr(SQLERRM, 1, 64) || ' ' ||
                                 service_in);
            -- 03/22/2008 mm5095 => added exception handling
    END update_um_di;
    -- 10/24/2007 mm5095 => insert into table to support french rewrite

    /* ----------------------------------------------------------------------------- UPDATE_UM_OH */
    -- 10/24/2007 mm5095 => insert into table to support FocusWrite rewrite
    PROCEDURE update_um_oh
    (
        service_in        VARCHAR2,
        part_id_in        INTEGER,
        type_in           INTEGER,
        min_labor_time_in INTEGER,
        overlap_skey_in   INTEGER
    ) IS
    BEGIN
        INSERT /*+ UPDATE_UM_OH.um_data_oh_insert */
        INTO um_data_oh
            (service,
             part_id,
             overlap_type,
             min_labor_time,
             overlap_skey,
             last_update_user,
             last_update_date)
        VALUES
            (service_in,
             part_id_in,
             type_in,
             min_labor_time_in,
             overlap_skey_in,
             USER,
             SYSDATE);
        -- 03/22/2008 mm5095 => added exception handling
    EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line('Parse error inserting into um_data_oh');
            -- 03/22/2008 mm5095 => added exception handling
    END;

    /* ----------------------------------------------------------------------------- UPDATE_UM_OD */
    PROCEDURE update_um_od
    (
        service_in      VARCHAR2,
        overlap_skey_in INTEGER,
        part_id_in      INTEGER,
        labor_in        INTEGER
    ) IS
    BEGIN
        INSERT /*+ UPDATE_UM_OD.um_data_od_insert */
        INTO um_data_od
            (service,
             overlap_skey,
             part_id,
             labor_time,
             last_update_user,
             last_update_date)
        VALUES
            (service_in,
             overlap_skey_in,
             part_id_in,
             labor_in,
             USER,
             SYSDATE);
        -- 03/22/2008 mm5095 => added exception handling
    EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line('Parse error inserting into um_data_od');
            -- 03/22/2008 mm5095 => added exception handling
    END;

    /* ----------------------------------------------------------------------------- UPDATE_UM_R */

    PROCEDURE update_um_r
    (
        service_in    VARCHAR2,
        combo_skey_in INTEGER,
        bit1_0_in     INTEGER,
        bit1_1_in     INTEGER,
        bit2_0_in     INTEGER,
        bit2_1_in     INTEGER,
        bit3_0_in     INTEGER,
        bit3_1_in     INTEGER,
        bit4_0_in     INTEGER,
        bit4_1_in     INTEGER,
        bit5_0_in     INTEGER,
        bit5_1_in     INTEGER,
        bit6_0_in     INTEGER,
        bit6_1_in     INTEGER
    ) IS
    BEGIN
        INSERT /*+ UPDATE_UM_R.um_data_r_insert */
        INTO um_data_r
            (service,
             combo_skey,
             bit1_0,
             bit1_1,
             bit2_0,
             bit2_1,
             bit3_0,
             bit3_1,
             bit4_0,
             bit4_1,
             bit5_0,
             bit5_1,
             bit6_0,
             bit6_1)
        VALUES
            (service_in,
             combo_skey_in,
             bit1_0_in,
             bit1_1_in,
             bit2_0_in,
             bit2_1_in,
             bit3_0_in,
             bit3_1_in,
             bit4_0_in,
             bit4_1_in,
             bit5_0_in,
             bit5_1_in,
             bit6_0_in,
             bit6_1_in);
    EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line('Parse error inserting into um_data_r');
    END;

    /* ----------------------------------------------------------------------------- UPDATE_UM_E */
    PROCEDURE update_um_e
    (
        service_in    VARCHAR2,
        combo_skey_in INTEGER,
        bit1_0_in     INTEGER,
        bit1_1_in     INTEGER
    ) IS
    BEGIN
        INSERT /*+ UPDATE_UM_E.um_data_e_insert */
        INTO um_data_e
            (service,
             combo_skey,
             bit1_0,
             bit1_1)
        VALUES
            (service_in,
             combo_skey_in,
             bit1_0_in,
             bit1_1_in);
    EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line('Parse error inserting into um_data_e');
    END;

    /* ----------------------------------------------------------------------------- UPDATE_UM_A */
    PROCEDURE update_um_a
    (
        service_in    VARCHAR2,
        combo_skey_in INTEGER,
        bit1_0_in     INTEGER,
        bit1_1_in     INTEGER,
        bit2_0_in     INTEGER,
        bit2_1_in     INTEGER,
        bit3_0_in     INTEGER,
        bit3_1_in     INTEGER,
        bit4_0_in     INTEGER,
        bit4_1_in     INTEGER,
        bit5_0_in     INTEGER,
        bit5_1_in     INTEGER,
        bit6_0_in     INTEGER,
        bit6_1_in     INTEGER
    ) IS
    BEGIN
        INSERT /*+ UPDATE_UM_A.um_data_a_insert */
        INTO um_data_a
            (service,
             combo_skey,
             bit1_0,
             bit1_1,
             bit2_0,
             bit2_1,
             bit3_0,
             bit3_1,
             bit4_0,
             bit4_1,
             bit5_0,
             bit5_1,
             bit6_0,
             bit6_1)
        VALUES
            (service_in,
             combo_skey_in,
             bit1_0_in,
             bit1_1_in,
             bit2_0_in,
             bit2_1_in,
             bit3_0_in,
             bit3_1_in,
             bit4_0_in,
             bit4_1_in,
             bit5_0_in,
             bit5_1_in,
             bit6_0_in,
             bit6_1_in);
    EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line('Parse error inserting into um_data_a');
    END;

    /* ----------------------------------------------------------------------------- UPDATE_UM_DG */
    PROCEDURE update_um_dg
    (
        service_in        VARCHAR2,
        option_barcode_in INTEGER,
        barcode_in        VARCHAR2,
        labor_hours_in    INTEGER
    ) IS
    BEGIN
        INSERT /*+ UPDATE_UM_DG.um_data_dg_insert */
        INTO um_data_dg
            (service,
             option_barcode,
             barcode,
             labor_hours)
        VALUES
            (service_in,
             option_barcode_in,
             barcode_in,
             labor_hours_in);
    EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line('Parse error inserting into um_data_dg');
    END;

    /* ----------------------------------------------------------------------------- UPDATE_UM_DL */
    /*    PROCEDURE UPDATE_UM_DL(service_in VARCHAR2, supplier_code_in varchar2, recond_flag_in varchar2,
        cat_code_in integer, price_in INTEGER, certified_code_in varchar2,
        altpart_number_in varchar2, discount_flag_in varchar2)
      IS
      BEGIN
        INSERT \*+ UPDATE_UM_DL.um_data_dl_insert *\
        INTO um_data_dl
        (service, supplier_code, reconditioned_flag, category_code, price, certified_code, altpart_number, oem_discount_flag)
        VALUES(service_in, supplier_code_in, recond_flag_in, cat_code_in, price_in, certified_code_in, altpart_number_in, discount_flag_in);
        EXCEPTION WHEN OTHERS THEN
          dbms_output.put_line('Parse error inserting into um_data_dl');
      END;
    */

    /* ----------------------------------------------------------------------------- SET_MATRIX_CUR */
    PROCEDURE set_matrix_cur
    (
        cursor_parm IN OUT matrix_cur,
        mfr_in      IN VARCHAR2,
        service_in  IN VARCHAR2,
        version_in  IN VARCHAR2,
        run_type    IN VARCHAR2
    ) IS

      vvc2_service_sub  VARCHAR2(1);

      CURSOR CheckSubstitution IS
        SELECT 'X'
          FROM race.service_category_substitution a
          WHERE a.mfr_number >= '700'
           AND a.mfr_number <= '799'
            AND a.mfr_number = mfr_in
            AND a.service_number = service_in;

    BEGIN

       OPEN CheckSubstitution;
       FETCH CheckSubstitution INTO vvc2_service_sub;
       CLOSE CheckSubstitution;


        --201804 pg2697 - Consolidated IF,THEN,ELSE associated to cursor parm below into ONE set. It previously
        --                established one cursor_parm for a FULL run and another for MINI, due to the supression
        --                of R&I autoincludes for FULL runs. But in 2011, mm5095 commented out this code restriction;
        --                making the FULL and MINI code the same. (See prior version in TFS.)
      IF vvc2_service_sub IS NULL THEN

        OPEN cursor_parm FOR
            SELECT /*+ SET_MATRIX_CUR.select_matrix_data */
             1           relationship,
             c.barcode   parent_id,
             a.barcode   child_id,
             a.line_type,
             -- 20170613 pg2697 => added seq1, seq2, and order by; to get ADD TO's in proper display order
             0 AS seq_1,
             0 AS seq_2,
             --20180329 pg2697 => added quantity
             0 AS quantity
              FROM ext.service_category_detail a,
                   auto_include                b,
                   ext.service_category_detail c
             WHERE a.mfr_number = mfr_in
               AND a.service_number = service_in
               AND a.version_type = version_in
               AND a.unique_row_id = b.unique_row_id
               AND a.version_type = b.version_type
               AND c.unique_row_id = b.auto_include_row_id
               AND c.version_type = b.version_type
               AND c.barcode IS NOT NULL
               AND a.barcode IS NOT NULL
            -- 2011/06/29 mm5095 => activate R&I autoincludes
            -- 20070709 mm5095 => suppress R&I autoincludes for FULL
            --        and substr(a.prtc_body,1,2) != 'IA'
            -- 20070709 mm5095 => suppress R&I autoincludes for FULL
            -- 2011/06/29 mm5095 => activate R&I autoincludes
            UNION
            SELECT 2           relationship,
                   c.barcode   parent_id,
                   a.barcode   child_id,
                   a.line_type,
                   -- 20170613 pg2697 => added seq1, seq2, and order by; to get ADD TO's in proper display order
                   0 AS seq_1,
                   0 AS seq_2,
                   --20180329 pg2697 => added quantity
                   0 AS quantity
              FROM ext.service_category_detail a,
                   assembly                    b,
                   ext.service_category_detail c
             WHERE a.mfr_number = mfr_in
               AND a.service_number = service_in
               AND a.version_type = version_in
               AND a.unique_row_id = b.unique_row_id
               AND a.version_type = b.version_type
               AND c.unique_row_id = b.assy_row_id
               AND c.version_type = b.version_type
               AND c.barcode IS NOT NULL
               AND a.barcode IS NOT NULL
            UNION
            SELECT 5           relationship,
                   a.barcode   parent_id,
                   b.barcode   child_id,
                   a.line_type,
                   -- 20170613 pg2697 => added seq1, seq2, and order by; to get ADD TO's in proper display order
                   0 AS seq_1,
                   0 AS seq_2,
                   --20180329 pg2697 => added quantity
                   0 AS quantity
              FROM ext.service_category_detail a,
                   ext.service_category_detail b
             WHERE a.mfr_number = mfr_in
               AND a.service_number = service_in
               AND a.version_type = version_in
               AND a.forward_pointer_row_id IS NOT NULL
               AND b.version_type = a.version_type
               AND b.unique_row_id = a.forward_pointer_row_id
               AND b.barcode IS NOT NULL
               AND a.barcode IS NOT NULL
            UNION
            SELECT 5 relationship,
                   a.barcode parent_id,
                   substr(barcode, 1, 1) || '9' || delete_message_prtc_body child_id,
                   a.line_type,
                   -- 20170613 pg2697 => added seq1, seq2, and order by; to get ADD TO's in proper display order
                   0 AS seq_1,
                   0 AS seq_2,
                   --20180329 pg2697 => added quantity
                   0 AS quantity
              FROM ext.service_category_detail a,
                   note                        b
             WHERE a.mfr_number = mfr_in
               AND a.service_number = service_in
               AND a.version_type = version_in
               AND a.delete_message_note_skey IS NOT NULL
               AND b.note_skey = a.delete_message_note_skey
               AND a.barcode IS NOT NULL
            UNION
            SELECT 6           relationship,
                   a.barcode   parent_id,
                   c.barcode   child_id,
                   a.line_type,
                   -- 20170613 pg2697 => added seq1, seq2, and order by; to get ADD TO's in proper display order
                   sc.line_sequence_number AS seq_1,
                   c.line_sequence_number  AS seq_2,
                   --20180329 pg2697 => added quantity
                   0 AS quantity
              FROM ext.service_category_detail a,
                   add_to                      b,
                   ext.service_category_detail c,
                   service_category            sc
             WHERE a.mfr_number = mfr_in
               AND a.service_number = service_in
               AND a.version_type = version_in
               AND a.unique_row_id = b.unique_row_id
               AND a.version_type = b.version_type
               AND c.unique_row_id = b.add_to_row_id
               AND c.version_type = b.version_type
               AND c.barcode IS NOT NULL
               AND a.barcode IS NOT NULL
               AND sc.mfr_number = c.mfr_number
               AND sc.service_number = c.service_number
               AND sc.version_type = c.version_type
               AND sc.category_skey = c.category_skey
               AND sc.subcategory_skey = c.subcategory_skey
               AND sc.subcategory_qgroup_skey = c.subcategory_qgroup_skey
            UNION
            SELECT 7                       relationship,
                   a.barcode               parent_id,
                   c.barcode               child_id,
                   a.line_type,
                   sc.line_sequence_number AS seq_1,
                   c.line_sequence_number  AS seq_2,
                   b.quantity
              FROM ext.service_category_detail a,
                   nrp_add_to                  b,
                   ext.service_category_detail c,
                   service_category            sc
             WHERE a.mfr_number = mfr_in
               AND a.service_number = service_in
               AND a.version_type = version_in
               AND a.unique_row_id = b.unique_row_id
               AND a.version_type = b.version_type
               AND c.unique_row_id = b.nrp_add_to_row_id
               AND c.version_type = b.version_type
               AND c.barcode IS NOT NULL
               AND a.barcode IS NOT NULL
               AND sc.mfr_number = c.mfr_number
               AND sc.service_number = c.service_number
               AND sc.version_type = c.version_type
               AND sc.category_skey = c.category_skey
               AND sc.subcategory_skey = c.subcategory_skey
               AND sc.subcategory_qgroup_skey = c.subcategory_qgroup_skey
            UNION
            SELECT 8 relationship,
                   a.barcode parent_id,
                   b.barcode child_id,
                   a.line_type,
                   sc.line_sequence_number AS seq_1,
                   rfc.sequence_number + rfd.sequence_number AS seq_2,
                   0 AS quantity
              FROM ext.service_category_detail    a,
                   service_cat_dtl_ref_sheet_xref b,
                   service_category               sc,
                   ref_sheet_category_detail      rfd,
                   ref_sheet_category             rfc
             WHERE a.mfr_number = mfr_in
               AND a.service_number = service_in
               AND a.version_type = version_in
               AND a.unique_row_id = b.unique_row_id
               AND a.version_type = b.version_type
               AND a.barcode IS NOT NULL
               AND sc.mfr_number = a.mfr_number
               AND sc.service_number = a.service_number
               AND sc.version_type = a.version_type
               AND sc.category_skey = a.category_skey
               AND sc.subcategory_skey = a.subcategory_skey
               AND sc.subcategory_qgroup_skey = a.subcategory_qgroup_skey
               AND rfd.barcode = b.barcode
               AND rfd.extract_flag = 'Y'
               AND rfc.category_skey = rfd.category_skey
               AND rfc.subcategory_skey = rfd.subcategory_skey
            UNION
             SELECT 9                      relationship,
                   a.barcode               parent_id,
                   c.barcode               child_id,
                   a.line_type,
                   sc.line_sequence_number AS seq_1,
                   c.line_sequence_number  AS seq_2,
                   0 AS quantity
              FROM ext.service_category_detail a,
                   panel_adjacency             b,
                   ext.service_category_detail c,
                   service_category            sc
             WHERE a.mfr_number = mfr_in
               AND a.service_number = service_in
               AND a.version_type = version_in
               AND a.unique_row_id = b.unique_row_id
               AND a.version_type = b.version_type
               AND c.unique_row_id = b.adjacent_row_id
               AND c.version_type = b.version_type
               AND c.barcode IS NOT NULL
               AND a.barcode IS NOT NULL
               AND sc.mfr_number = a.mfr_number
               AND sc.service_number = a.service_number
               AND sc.version_type = a.version_type
               AND sc.category_skey = a.category_skey
               AND sc.subcategory_skey = a.subcategory_skey
               AND sc.subcategory_qgroup_skey = a.subcategory_qgroup_skey
             ORDER BY relationship,
                      parent_id,
                      seq_1,
                      seq_2;
      ELSE
        OPEN cursor_parm FOR
            SELECT /*+ SET_MATRIX_CUR.select_matrix_data */
             1           relationship,
             c.barcode   parent_id,
             a.barcode   child_id,
             a.line_type,
             -- 20170613 pg2697 => added seq1, seq2, and order by; to get ADD TO's in proper display order
             0 AS seq_1,
             0 AS seq_2,
             --20180329 pg2697 => added quantity
             0 AS quantity
              FROM ext.service_category_detail a,
                   auto_include                b,
                   ext.service_category_detail c
             WHERE a.mfr_number = mfr_in
               AND a.service_number = service_in
               AND a.version_type = version_in
               AND a.unique_row_id = b.unique_row_id
               AND a.version_type = b.version_type
               AND c.unique_row_id = b.auto_include_row_id
               AND c.version_type = b.version_type
               AND c.barcode IS NOT NULL
               AND a.barcode IS NOT NULL
            -- 2011/06/29 mm5095 => activate R&I autoincludes
            -- 20070709 mm5095 => suppress R&I autoincludes for FULL
            --        and substr(a.prtc_body,1,2) != 'IA'
            -- 20070709 mm5095 => suppress R&I autoincludes for FULL
            -- 2011/06/29 mm5095 => activate R&I autoincludes
            UNION
      -- *** 09/28/2021 RS Added for Contatenated service
            SELECT
             1           relationship,
             c.barcode   parent_id,
             a.barcode   child_id,
             a.line_type,
             -- 20170613 pg2697 => added seq1, seq2, and order by; to get ADD TO's in proper display order
             0 AS seq_1,
             0 AS seq_2,
             --20180329 pg2697 => added quantity
             0 AS quantity
              FROM ext.service_category_detail a,
                   auto_include                b,
                   ext.service_category_detail c,
                   race.service_category_substitution d
             WHERE d.mfr_number = mfr_in
               AND d.service_number = service_in
               AND a.mfr_number = d.substitute_mfr_number
               AND a.service_number = d.substitute_service_number
               AND a.category_skey = d.substitute_category_skey
               AND a.subcategory_skey = case when d.all_subcategory_flag = 'N' then d.substitute_subcategory_skey else a.subcategory_skey END
               AND a.version_type = version_in
               AND a.unique_row_id = b.unique_row_id
               AND a.version_type = b.version_type
               AND c.unique_row_id = b.auto_include_row_id
               AND c.version_type = b.version_type
               AND c.barcode IS NOT NULL
               AND a.barcode IS NOT NULL
            UNION
            SELECT 2           relationship,
                   c.barcode   parent_id,
                   a.barcode   child_id,
                   a.line_type,
                   -- 20170613 pg2697 => added seq1, seq2, and order by; to get ADD TO's in proper display order
                   0 AS seq_1,
                   0 AS seq_2,
                   --20180329 pg2697 => added quantity
                   0 AS quantity
              FROM ext.service_category_detail a,
                   assembly                    b,
                   ext.service_category_detail c
             WHERE a.mfr_number = mfr_in
               AND a.service_number = service_in
               AND a.version_type = version_in
               AND a.unique_row_id = b.unique_row_id
               AND a.version_type = b.version_type
               AND c.unique_row_id = b.assy_row_id
               AND c.version_type = b.version_type
               AND c.barcode IS NOT NULL
               AND a.barcode IS NOT NULL
            UNION
      -- *** 09/28/2021 RS Added for Contatenated service
            SELECT 2           relationship,
                   c.barcode   parent_id,
                   a.barcode   child_id,
                   a.line_type,
                   -- 20170613 pg2697 => added seq1, seq2, and order by; to get ADD TO's in proper display order
                   0 AS seq_1,
                   0 AS seq_2,
                   --20180329 pg2697 => added quantity
                   0 AS quantity
              FROM ext.service_category_detail a,
                   assembly                    b,
                   ext.service_category_detail c,
                   race.service_category_substitution d
             WHERE d.mfr_number = mfr_in
               AND d.service_number = service_in
               AND a.mfr_number = d.substitute_mfr_number
               AND a.service_number = d.substitute_service_number
               AND a.category_skey = d.substitute_category_skey
               AND a.subcategory_skey = case when d.all_subcategory_flag = 'N' then d.substitute_subcategory_skey else a.subcategory_skey END
               AND a.version_type = version_in
               AND a.unique_row_id = b.unique_row_id
               AND a.version_type = b.version_type
               AND c.unique_row_id = b.assy_row_id
               AND c.version_type = b.version_type
               AND c.barcode IS NOT NULL
               AND a.barcode IS NOT NULL
            UNION
            SELECT 5           relationship,
                   a.barcode   parent_id,
                   b.barcode   child_id,
                   a.line_type,
                   -- 20170613 pg2697 => added seq1, seq2, and order by; to get ADD TO's in proper display order
                   0 AS seq_1,
                   0 AS seq_2,
                   --20180329 pg2697 => added quantity
                   0 AS quantity
              FROM ext.service_category_detail a,
                   ext.service_category_detail b
             WHERE a.mfr_number = mfr_in
               AND a.service_number = service_in
               AND a.version_type = version_in
               AND a.forward_pointer_row_id IS NOT NULL
               AND b.version_type = a.version_type
               AND b.unique_row_id = a.forward_pointer_row_id
               AND b.barcode IS NOT NULL
               AND a.barcode IS NOT NULL
            UNION
      -- *** 09/28/2021 RS Added for Contatenated service
            SELECT 5           relationship,
                   a.barcode   parent_id,
                   b.barcode   child_id,
                   a.line_type,
                   -- 20170613 pg2697 => added seq1, seq2, and order by; to get ADD TO's in proper display order
                   0 AS seq_1,
                   0 AS seq_2,
                   --20180329 pg2697 => added quantity
                   0 AS quantity
              FROM ext.service_category_detail a,
                   ext.service_category_detail b,
                   race.service_category_substitution d
             WHERE d.mfr_number = mfr_in
               AND d.service_number = service_in
               AND a.mfr_number = d.substitute_mfr_number
               AND a.service_number = d.substitute_service_number
               AND a.category_skey = d.substitute_category_skey
               AND a.subcategory_skey = case when d.all_subcategory_flag = 'N' then d.substitute_subcategory_skey else a.subcategory_skey END
               AND a.version_type = version_in
               AND a.forward_pointer_row_id IS NOT NULL
               AND b.version_type = a.version_type
               AND b.unique_row_id = a.forward_pointer_row_id
               AND b.barcode IS NOT NULL
               AND a.barcode IS NOT NULL
            UNION
            SELECT 5 relationship,
                   a.barcode parent_id,
                   substr(barcode, 1, 1) || '9' || delete_message_prtc_body child_id,
                   a.line_type,
                   -- 20170613 pg2697 => added seq1, seq2, and order by; to get ADD TO's in proper display order
                   0 AS seq_1,
                   0 AS seq_2,
                   --20180329 pg2697 => added quantity
                   0 AS quantity
              FROM ext.service_category_detail a,
                   note                        b
             WHERE a.mfr_number = mfr_in
               AND a.service_number = service_in
               AND a.version_type = version_in
               AND a.delete_message_note_skey IS NOT NULL
               AND b.note_skey = a.delete_message_note_skey
               AND a.barcode IS NOT NULL
            UNION
      -- *** 09/28/2021 RS Added for Contatenated service
            SELECT 5 relationship,
                   a.barcode parent_id,
                   substr(barcode, 1, 1) || '9' || delete_message_prtc_body child_id,
                   a.line_type,
                   -- 20170613 pg2697 => added seq1, seq2, and order by; to get ADD TO's in proper display order
                   0 AS seq_1,
                   0 AS seq_2,
                   --20180329 pg2697 => added quantity
                   0 AS quantity
              FROM ext.service_category_detail a,
                   note                        b,
                   race.service_category_substitution d
             WHERE d.mfr_number = mfr_in
               AND d.service_number = service_in
               AND a.mfr_number = d.substitute_mfr_number
               AND a.service_number = d.substitute_service_number
               AND a.category_skey = d.substitute_category_skey
               AND a.subcategory_skey = case when d.all_subcategory_flag = 'N' then d.substitute_subcategory_skey else a.subcategory_skey END
               AND a.version_type = version_in
               AND a.delete_message_note_skey IS NOT NULL
               AND b.note_skey = a.delete_message_note_skey
               AND a.barcode IS NOT NULL
            UNION
            SELECT 6           relationship,
                   a.barcode   parent_id,
                   c.barcode   child_id,
                   a.line_type,
                   -- 20170613 pg2697 => added seq1, seq2, and order by; to get ADD TO's in proper display order
                   sc.line_sequence_number AS seq_1,
                   c.line_sequence_number  AS seq_2,
                   --20180329 pg2697 => added quantity
                   0 AS quantity
              FROM ext.service_category_detail a,
                   add_to                      b,
                   ext.service_category_detail c,
                   service_category            sc
             WHERE a.mfr_number = mfr_in
               AND a.service_number = service_in
               AND a.version_type = version_in
               AND a.unique_row_id = b.unique_row_id
               AND a.version_type = b.version_type
               AND c.unique_row_id = b.add_to_row_id
               AND c.version_type = b.version_type
               AND c.barcode IS NOT NULL
               AND a.barcode IS NOT NULL
               AND sc.mfr_number = c.mfr_number
               AND sc.service_number = c.service_number
               AND sc.version_type = c.version_type
               AND sc.category_skey = c.category_skey
               AND sc.subcategory_skey = c.subcategory_skey
               AND sc.subcategory_qgroup_skey = c.subcategory_qgroup_skey
            UNION
      -- *** 09/28/2021 RS Added for Contatenated service
            SELECT 6           relationship,
                   a.barcode   parent_id,
                   c.barcode   child_id,
                   a.line_type,
                   -- 20170613 pg2697 => added seq1, seq2, and order by; to get ADD TO's in proper display order
                   sc.line_sequence_number AS seq_1,
                   c.line_sequence_number  AS seq_2,
                   --20180329 pg2697 => added quantity
                   0 AS quantity
              FROM ext.service_category_detail a,
                   add_to                      b,
                   ext.service_category_detail c,
                   service_category            sc,
                   race.service_category_substitution d
             WHERE d.mfr_number = mfr_in
               AND d.service_number = service_in
               AND a.mfr_number = d.substitute_mfr_number
               AND a.service_number = d.substitute_service_number
               AND a.category_skey = d.substitute_category_skey
               AND a.subcategory_skey = case when d.all_subcategory_flag = 'N' then d.substitute_subcategory_skey else a.subcategory_skey END
               AND a.version_type = version_in
               AND a.unique_row_id = b.unique_row_id
               AND a.version_type = b.version_type
               AND c.unique_row_id = b.add_to_row_id
               AND c.version_type = b.version_type
               AND c.barcode IS NOT NULL
               AND a.barcode IS NOT NULL
               AND sc.mfr_number = c.mfr_number
               AND sc.service_number = c.service_number
               AND sc.version_type = c.version_type
               AND sc.category_skey = c.category_skey
               AND sc.subcategory_skey = c.subcategory_skey
               AND sc.subcategory_qgroup_skey = c.subcategory_qgroup_skey
            --20180329 pg2697 => added record type 7 logic for NRP_ADD_TO's
            UNION
            SELECT 7                       relationship,
                   a.barcode               parent_id,
                   c.barcode               child_id,
                   a.line_type,
                   sc.line_sequence_number AS seq_1,
                   c.line_sequence_number  AS seq_2,
                   b.quantity
              FROM ext.service_category_detail a,
                   nrp_add_to                  b,
                   ext.service_category_detail c,
                   service_category            sc
             WHERE a.mfr_number = mfr_in
               AND a.service_number = service_in
               AND a.version_type = version_in
               AND a.unique_row_id = b.unique_row_id
               AND a.version_type = b.version_type
               AND c.unique_row_id = b.nrp_add_to_row_id
               AND c.version_type = b.version_type
               AND c.barcode IS NOT NULL
               AND a.barcode IS NOT NULL
               AND sc.mfr_number = c.mfr_number
               AND sc.service_number = c.service_number
               AND sc.version_type = c.version_type
               AND sc.category_skey = c.category_skey
               AND sc.subcategory_skey = c.subcategory_skey
               AND sc.subcategory_qgroup_skey = c.subcategory_qgroup_skey
            UNION
      -- *** 09/28/2021 RS Added for Contatenated service
            SELECT 7                       relationship,
                   a.barcode               parent_id,
                   c.barcode               child_id,
                   a.line_type,
                   sc.line_sequence_number AS seq_1,
                   c.line_sequence_number  AS seq_2,
                   b.quantity
              FROM ext.service_category_detail a,
                   nrp_add_to                  b,
                   ext.service_category_detail c,
                   service_category            sc,
                   race.service_category_substitution d
             WHERE d.mfr_number = mfr_in
               AND d.service_number = service_in
               AND a.mfr_number = d.substitute_mfr_number
               AND a.service_number = d.substitute_service_number
               AND a.category_skey = d.substitute_category_skey
               AND a.subcategory_skey = case when d.all_subcategory_flag = 'N' then d.substitute_subcategory_skey else a.subcategory_skey END
               AND a.version_type = version_in
               AND a.unique_row_id = b.unique_row_id
               AND a.version_type = b.version_type
               AND c.unique_row_id = b.nrp_add_to_row_id
               AND c.version_type = b.version_type
               AND c.barcode IS NOT NULL
               AND a.barcode IS NOT NULL
               AND sc.mfr_number = c.mfr_number
               AND sc.service_number = c.service_number
               AND sc.version_type = c.version_type
               AND sc.category_skey = c.category_skey
               AND sc.subcategory_skey = c.subcategory_skey
               AND sc.subcategory_qgroup_skey = c.subcategory_qgroup_skey
            --20200930 RS7649 => added record type 8 logic for Reference Sheets
            UNION
            SELECT 8 relationship,
                   a.barcode parent_id,
                   b.barcode child_id,
                   a.line_type,
                   sc.line_sequence_number AS seq_1,
                   rfc.sequence_number + rfd.sequence_number AS seq_2,
                   0 AS quantity
              FROM ext.service_category_detail    a,
                   service_cat_dtl_ref_sheet_xref b,
                   service_category               sc,
                   ref_sheet_category_detail      rfd,
                   ref_sheet_category             rfc
             WHERE a.mfr_number = mfr_in
               AND a.service_number = service_in
               AND a.version_type = version_in
               AND a.unique_row_id = b.unique_row_id
               AND a.version_type = b.version_type
               AND a.barcode IS NOT NULL
               AND sc.mfr_number = a.mfr_number
               AND sc.service_number = a.service_number
               AND sc.version_type = a.version_type
               AND sc.category_skey = a.category_skey
               AND sc.subcategory_skey = a.subcategory_skey
               AND sc.subcategory_qgroup_skey = a.subcategory_qgroup_skey
               AND rfd.barcode = b.barcode
               AND rfd.extract_flag = 'Y'
               AND rfc.category_skey = rfd.category_skey
               AND rfc.subcategory_skey = rfd.subcategory_skey
            UNION
      -- *** 09/28/2021 RS Added for Contatenated service
            SELECT 8 relationship,
                   a.barcode parent_id,
                   b.barcode child_id,
                   a.line_type,
                   sc.line_sequence_number AS seq_1,
                   rfc.sequence_number + rfd.sequence_number AS seq_2,
                   0 AS quantity
              FROM ext.service_category_detail    a,
                   service_cat_dtl_ref_sheet_xref b,
                   service_category               sc,
                   ref_sheet_category_detail      rfd,
                   ref_sheet_category             rfc,
                   race.service_category_substitution d
             WHERE d.mfr_number = mfr_in
               AND d.service_number = service_in
               AND a.mfr_number = d.substitute_mfr_number
               AND a.service_number = d.substitute_service_number
               AND a.category_skey = d.substitute_category_skey
               AND a.subcategory_skey = case when d.all_subcategory_flag = 'N' then d.substitute_subcategory_skey else a.subcategory_skey END
               AND a.version_type = version_in
               AND a.unique_row_id = b.unique_row_id
               AND a.version_type = b.version_type
               AND a.barcode IS NOT NULL
               AND sc.mfr_number = a.mfr_number
               AND sc.service_number = a.service_number
               AND sc.version_type = a.version_type
               AND sc.category_skey = a.category_skey
               AND sc.subcategory_skey = a.subcategory_skey
               AND sc.subcategory_qgroup_skey = a.subcategory_qgroup_skey
               AND rfd.barcode = b.barcode
               AND rfd.extract_flag = 'Y'
               AND rfc.category_skey = rfd.category_skey
               AND rfc.subcategory_skey = rfd.subcategory_skey
            UNION
            SELECT 9                       relationship,
                   a.barcode               parent_id,
                   c.barcode               child_id,
                   a.line_type,
                   sc.line_sequence_number AS seq_1,
                   c.line_sequence_number  AS seq_2,
                   0 AS quantity
              FROM ext.service_category_detail a,
                   panel_adjacency             b,
                   ext.service_category_detail c,
                   service_category            sc
             WHERE a.mfr_number = mfr_in
               AND a.service_number = service_in
               AND a.version_type = version_in
               AND a.unique_row_id = b.unique_row_id
               AND a.version_type = b.version_type
               AND c.unique_row_id = b.adjacent_row_id
               AND c.version_type = b.version_type
               AND c.barcode IS NOT NULL
               AND a.barcode IS NOT NULL
               AND sc.mfr_number = a.mfr_number
               AND sc.service_number = a.service_number
               AND sc.version_type = a.version_type
               AND sc.category_skey = a.category_skey
               AND sc.subcategory_skey = a.subcategory_skey
               AND sc.subcategory_qgroup_skey = a.subcategory_qgroup_skey
            UNION
      -- *** 09/28/2021 RS Added for Contatenated service
            SELECT 9                       relationship,
                   a.barcode               parent_id,
                   c.barcode               child_id,
                   a.line_type,
                   sc.line_sequence_number AS seq_1,
                   c.line_sequence_number  AS seq_2,
                   0 AS quantity
              FROM ext.service_category_detail a,
                   panel_adjacency             b,
                   ext.service_category_detail c,
                   service_category            sc,
                   race.service_category_substitution d
             WHERE d.mfr_number = mfr_in
               AND d.service_number = service_in
               AND a.mfr_number = d.substitute_mfr_number
               AND a.service_number = d.substitute_service_number
               AND a.category_skey = d.substitute_category_skey
               AND a.subcategory_skey = case when d.all_subcategory_flag = 'N' then d.substitute_subcategory_skey else a.subcategory_skey END
               AND a.version_type = version_in
               AND a.unique_row_id = b.unique_row_id
               AND a.version_type = b.version_type
               AND c.unique_row_id = b.adjacent_row_id
               AND c.version_type = b.version_type
               AND c.barcode IS NOT NULL
               AND a.barcode IS NOT NULL
               AND sc.mfr_number = a.mfr_number
               AND sc.service_number = a.service_number
               AND sc.version_type = a.version_type
               AND sc.category_skey = a.category_skey
               AND sc.subcategory_skey = a.subcategory_skey
               AND sc.subcategory_qgroup_skey = a.subcategory_qgroup_skey
             ORDER BY relationship,
                      parent_id,
                      seq_1,
                      seq_2;

      END IF;
    END set_matrix_cur;

    /* ----------------------------------------------------------------------------- CREATE_MATRIX
         This routine creates: matrix-related txt file for UM and um_data_ tables for MCE.
         It also adds the txt file name to the service-related semaphore file so that Ultrldr
         program knows to process matrix info for the service.
    */
    PROCEDURE create_matrix
    (
        service_barcode VARCHAR2,
        mfr_in          VARCHAR2,
        service_in      VARCHAR2,
        version_in      VARCHAR2,
        run_type        VARCHAR2,
        path            VARCHAR2
    ) IS

        -- 2008/12/31 PAG - Moved select associated to matrix_cur into procedure SET_MATRIX_CUR
        -- so that selection criteria can be changed based on run_type.
        matrixinfo_cur matrix_cur;
        matrixinfo_rec matrix_rec;
        -- 2008/12/31 PAG - Moved select associated to matrix_cur

        out_fhandle       utl_file.file_type;
        bfirsttime        BOOLEAN := TRUE;
        vn_relationship_7 NUMBER := 7;

    BEGIN

        -- 2008/12/31 PAG - Moved select associated to matrix_cur into procedure SET_MATRIX_CUR
        -- so that selection criteria can be changed based on run_type.
        set_matrix_cur(matrixinfo_cur,
                       mfr_in,
                       service_in,
                       version_in,
                       run_type);
        LOOP
            FETCH matrixinfo_cur
                INTO matrixinfo_rec;
            EXIT WHEN matrixinfo_cur%NOTFOUND;
            -- for rec in matrix_cur LOOP
            -- 2008/12/31 PAG - Moved select associated to matrix_cur into procedure SET_MATRIX_CUR
            IF bfirsttime
            THEN
                /* -- File generation disabled: DF file fopen (FTP sunset)
                    out_fhandle := utl_file.fopen(path,
                                                  'DF' || service_barcode ||
                                                  '.txt',
                                                  'w');
                -- end commented block */
                bfirsttime  := FALSE;
            END IF;

            -- handle "wacky" table

            -- 04/05/2020 pb0690 => Remove full versus mini check and code. Adding MCE Mini functionality.
            IF matrixinfo_rec.relationship = 2
               AND matrixinfo_rec.line_type = 'N'
            THEN
                --201804 pg2697 Added quantity
                /* -- File generation disabled: DF put_line (FTP sunset)
                    utl_file.put_line(out_fhandle,
                                      matrixinfo_rec.relationship || '|' ||
                                      matrixinfo_rec.child_id || '|' ||
                                      matrixinfo_rec.parent_id || '|' ||
                                      matrixinfo_rec.quantity);
                -- end commented block */
                -- 10/24/2007 mm5095 => insert into table to support FocusWrite rewrite
                --201804 pg2697 Added quantity
                update_um_df(service_barcode,
                             matrixinfo_rec.relationship,
                             matrixinfo_rec.child_id,
                             matrixinfo_rec.parent_id,
                             matrixinfo_rec.quantity);
                -- 10/24/2007 mm5095 => insert into table to support FocusWrite rewrite
            ELSE
                --201804 pg2697 Added quantity
                /* -- File generation disabled: DF put_line (FTP sunset)
                    utl_file.put_line(out_fhandle,
                                      matrixinfo_rec.relationship || '|' ||
                                      matrixinfo_rec.parent_id || '|' ||
                                      matrixinfo_rec.child_id || '|' ||
                                      matrixinfo_rec.quantity);
                -- end commented block */
                -- 10/24/2007 mm5095 => insert into table to support FocusWrite rewrite
                --201804 pg2697 Added quantity
                update_um_df(service_barcode,
                             matrixinfo_rec.relationship,
                             matrixinfo_rec.parent_id,
                             matrixinfo_rec.child_id,
                             matrixinfo_rec.quantity);
                -- 10/24/2007 mm5095 => insert into table to support FocusWrite rewrite
                --201804 pg2697 If AirBag AddTo record (6), clone it as NRP_AddTo record 7 as well - for NextGen only.
                IF matrixinfo_rec.relationship = 6
                   AND matrixinfo_rec.line_type = 'A'
                THEN
                    update_um_df(service_barcode,
                                 vn_relationship_7,
                                 matrixinfo_rec.parent_id,
                                 matrixinfo_rec.child_id,
                                 matrixinfo_rec.quantity);
                END IF;
                --201804 pg2697 AirBag (end)
            END IF;

        END LOOP;
        -- 2008/12/31 PAG - Moved select associated to matrix_cur into procedure SET_MATRIX_CUR
        -- so that selection criteria can be changed based on run_type.
        CLOSE matrixinfo_cur;
        -- 2008/12/31 PAG - Moved select associated to matrix_cur into procedure SET_MATRIX_CUR

        /* -- File generation disabled: DF fclose and semaphore (FTP sunset)
            IF utl_file.is_open(out_fhandle)
            THEN
                utl_file.fclose(out_fhandle);

                -- update service semaphore
                pkg_ultramate_common.sp_output_barcode_semaphore(path,
                                                                 service_barcode,
                                                                 'DF' ||
                                                                 service_barcode ||
                                                                 '.txt',
                                                                 'a');
            END IF;
        -- end commented block */

    END create_matrix;

    /* ----------------------------------------------------------------------------- SET_DISTINCTNOTES_CURSOR */
    PROCEDURE set_distinctnotes_cursor
    (
        cursor_parm     IN OUT distinct_cur,
        run_type        IN VARCHAR2,
        parallel_number CHAR
    ) IS
    BEGIN

        IF run_type = 'FULL'
           AND parallel_number = '1'
        THEN
            OPEN cursor_parm FOR
                SELECT /*+ SET_DISTINCTNOTES_CURSOR.cursor_parm_full */
                DISTINCT note_text
                  FROM um_note
                 WHERE note_text IS NOT NULL;
        ELSIF run_type = 'FULL'
              AND parallel_number = '2'
        THEN
            OPEN cursor_parm FOR
                SELECT DISTINCT note_text
                  FROM um_note2
                 WHERE note_text IS NOT NULL;
        ELSE
            --MINI
            OPEN cursor_parm FOR
                SELECT /*+ SET_DISTINCTNOTES_CURSOR.cursor_parm_mini */
                DISTINCT note_text
                  FROM tmp_um_note
                 WHERE note_text IS NOT NULL;
        END IF;

    END set_distinctnotes_cursor;

    /* ----------------------------------------------------------------------------- SET_NOTE_CURSOR */
    PROCEDURE set_note_cursor
    (
        cursor_parm     IN OUT note_cur,
        run_type        IN VARCHAR2,
        parallel_number IN CHAR
    ) IS
    BEGIN

        IF run_type = 'FULL'
           AND parallel_number = '1'
        THEN
            OPEN cursor_parm FOR
                SELECT /*+ SET_NOTE_CURSOR.cursor_parm_full */
                 note_group_skey,
                 note_id,
                 note_type,
                 note_text,
                 line_type,
                 note_symbol,
                 ROWID AS "NOTE_ROWID"
                  FROM um_note
                 WHERE note_type = 0;
            -- 2008/12/31 PAG => replaced "where current of" with match on ROWID due to use of REF Cursor
            -- for update of note_type;
            -- 2008/12/31 PAG => replaced "where current of" with match on ROWID due to use of REF Cursor
        ELSIF run_type = 'FULL'
              AND parallel_number = '2'
        THEN
            OPEN cursor_parm FOR
                SELECT /*+ SET_NOTE_CURSOR.cursor_parm_full2 */
                 note_group_skey,
                 note_id,
                 note_type,
                 note_text,
                 line_type,
                 note_symbol,
                 ROWID AS "NOTE_ROWID"
                  FROM um_note2
                 WHERE note_type = 0;
            -- 2008/12/31 PAG => replaced "where current of" with match on ROWID due to use of REF Cursor
            -- for update of note_type;
            -- 2008/12/31 PAG => replaced "where current of" with match on ROWID due to use of REF Cursor
        ELSE
            --MINI
            OPEN cursor_parm FOR
                SELECT /*+ SET_NOTE_CURSOR.cursor_parm_mini */
                 note_group_skey,
                 note_id,
                 note_type,
                 note_text,
                 line_type,
                 note_symbol,
                 ROWID AS "NOTE_ROWID"
                  FROM tmp_um_note
                 WHERE note_type = 0;
            -- 2008/12/31 PAG => replaced "where current of" with match on ROWID due to use of REF Cursor
            -- for update of note_type;
            -- 2008/12/31 PAG => replaced "where current of" with match on ROWID due to use of REF Cursor

        END IF;

    END set_note_cursor;

    /* ----------------------------------------------------------------------------- CREATE_NOTES */
    PROCEDURE create_notes
    (
        service_barcode VARCHAR2,
        mfr_in          VARCHAR2,
        service_in      VARCHAR2,
        version_in      VARCHAR2,
        run_type        VARCHAR2,
        path            VARCHAR2,
        parallel_number CHAR
    ) IS

        -- 2008/12/31 PAG - Moved selects for distinct_cur and note_cur into procedure SET_NOTES_CURSOR
        -- so that selection criteria can be changed based on run_type.
        distinctnotes_cur distinct_cur;
        distinctnotes_rec distinct_rec;

        notes_cur note_cur;
        notes_rec note_rec;
        -- 2008/12/31 PAG - Moved selects for distinct_cur and note_cur

        my_note_id      NUMBER := 0;
        nline           NUMBER := 0;
        my_note_type    NUMBER;
        out_fhandle     utl_file.file_type;
        wrap_text       VARCHAR2(1000);
        npos            NUMBER;
        max_line_length NUMBER := 60;
        CLASS           VARCHAR2(3);

        -- 09/28/2015 mm5095
        line_text_skey NUMBER;
        -- 09/28/2015 mm5095

        -- 02/09/2017 mm5095
        french_text VARCHAR2(1000);
        -- 02/09/2017 mm5095
    BEGIN

        -- 2008/12/31 PAG - Combined Build and Parse (create_notes and create_notes2) logic based on runtype and parallel number

        CLASS := sf_getclass(mfr_in, service_in);

        IF run_type = 'FULL'
           AND parallel_number = '1'
        THEN
            -- FULL PARALLEL 1 LOGIC

            DELETE /*+ CREATE_NOTES.um_note_delete */
            FROM um_note;

            INSERT /*+ CREATE_NOTES.um_note_insert */
            INTO um_note
                (note_group_skey,
                 note_id,
                 note_type,
                 note_text,
                 line_type,
                 note_symbol)
                SELECT note_group_skey,
                       0 note_id,
                       0 note_type,
                       substr(ext.sf_getnote(line_type,
                                             version_type,
                                             note_group_skey),
                              1,
                              2000) note_text,
                       line_type,
                       note_symbol
                  FROM ext.service_category_detail
                 WHERE mfr_number = mfr_in
                   AND service_number = service_in
                   AND version_type = version_in
                   AND line_type IN ('C', 'F', 'K', 'L', 'R')
                UNION
                SELECT 0   note_group_skey,
                       0   note_id,
                       215 note_type,
                       -- 01/14/2005 mm5095 => added ppage support for motorcycles and RVs
--                       substr(sf_getppagetext(decode(least(mfr_number,
--                                                           '200'),
--                                                     '200',
--                                                     'MCS',
--                                                     decode(least(mfr_number,
--                                                                  '100'),
--                                                            '100',
--                                                            'RVS',
--                                                            CLASS)),
                                              --               decode(mfr_number,'006','ATG','CEG'))),
                                              --    substr(sf_getPPageText(decode(mfr_number,'006','ATG','CEG'),
                                              -- 01/14/2005 mm5095 => added ppage support for motorcycles and RVs
                       substr(sf_getppagetext(CLASS,
                                              mfr_number,
                                              service_number,
                                              version_type,
                                              category_skey),
                              1,
                              2000) note_text,
                       ' ' line_type,
                       ' ' note_symbol
                  FROM ext.service_category
                 WHERE mfr_number = mfr_in
                   AND service_number = service_in
                   AND version_type = version_in
                   AND subcategory_skey = 0
                   AND subcategory_qgroup_skey = 0
                -- 11/04/2011 mm5095 => added support for mtd/htd concatenation
                UNION
                SELECT b.note_group_skey,
                       0 note_id,
                       0 note_type,
                       substr(ext.sf_getnote(b.line_type,
                                             b.version_type,
                                             b.note_group_skey),
                              1,
                              2000) note_text,
                       b.line_type,
                       b.note_symbol
                  FROM service_category_substitution a
                 INNER JOIN service_category_detail b
                    ON b.mfr_number = a.substitute_mfr_number
                   AND b.service_number = a.substitute_service_number
                   AND ((b.subcategory_skey = 0 OR
                       b.subcategory_skey = a.substitute_subcategory_skey) OR
                       a.all_subcategory_flag = 'Y')
                   AND b.version_type = version_in
                 WHERE a.mfr_number = mfr_in
                   AND a.service_number = service_in
                   AND b.line_type IN ('C', 'F', 'K', 'L', 'R')
                UNION
                SELECT 0   note_group_skey,
                       0   note_id,
                       215 note_type,

                       -- 01/14/2005 mm5095 => added ppage support for motorcycles and RVs
--                       substr(sf_getppagetext(decode(least(b.mfr_number,
--                                                           '200'),
--                                                     '200',
--                                                     'MCS',
--                                                     decode(least(b.mfr_number,
--                                                                  '100'),
--                                                            '100',
--                                                            'RVS',
--                                                            CLASS)),
                                              --               decode(mfr_number,'006','ATG','CEG'))),
                                              --    substr(sf_getPPageText(decode(mfr_number,'006','ATG','CEG'),
                                              -- 01/14/2005 mm5095 => added ppage support for motorcycles and RVs
                       substr(sf_getppagetext(CLASS,
                                              b.mfr_number,
                                              b.service_number,
                                              b.version_type,
                                              b.category_skey),
                              1,
                              2000) note_text,
                       ' ' line_type,
                       ' ' note_symbol
                  FROM service_category_substitution a
                 INNER JOIN service_category b
                    ON b.mfr_number = a.substitute_mfr_number
                   AND b.service_number = a.substitute_service_number
                   AND ((b.subcategory_skey = 0 OR
                       b.subcategory_skey = a.substitute_subcategory_skey) OR
                       a.all_subcategory_flag = 'Y')
                 WHERE a.mfr_number = mfr_in
                   AND a.service_number = service_in
                   AND b.version_type = version_in
                   AND b.subcategory_skey = 0
                   AND b.subcategory_qgroup_skey = 0;
            -- 11/04/2011 mm5095 => added support for mtd/htd concatenation

            -- insert "special notes" for each service
            INSERT /*+ CREATE_NOTES.um_note_insert2 */
            INTO um_note
                (note_group_skey,
                 note_id,
                 note_type,
                 note_text)
            VALUES
                (0,
                 0,
                 2,
                 'Included in Overhaul');
            INSERT /*+ CREATE_NOTES.um_note_insert3 */
            INTO um_note
                (note_group_skey,
                 note_id,
                 note_type,
                 note_text)
            VALUES
                (0,
                 0,
                 3,
                 'Discontinued by the Manufacturer');
            INSERT /*+ CREATE_NOTES.um_note_insert4 */
            INTO um_note
                (note_group_skey,
                 note_id,
                 note_type,
                 note_text)
            VALUES
                (0,
                 0,
                 4,
                 'Part Included in Clear Coat Application');
            INSERT /*+ CREATE_NOTES.um_note_insert5 */
            INTO um_note
                (note_group_skey,
                 note_id,
                 note_type,
                 note_text)
            VALUES
                (0,
                 0,
                 5,
                 'Remanufactured Part');
            INSERT /*+ CREATE_NOTES.um_note_insert6 */
            INTO um_note
                (note_group_skey,
                 note_id,
                 note_type,
                 note_text)
            VALUES
                (0,
                 0,
                 175,
                 'Special Pricing');
            INSERT /*+ CREATE_NOTES.um_note_insert7 */
            INTO um_note
                (note_group_skey,
                 note_id,
                 note_type,
                 note_text)
            VALUES
                (0,
                 0,
                 173,
                 'Interchangeable Part');

        ELSIF run_type = 'FULL'
              AND parallel_number = '2'
        THEN
            -- FULL PARALLEL 2 LOGIC

            DELETE /*+ CREATE_NOTES.um_note2_delete */
            FROM um_note2;

            INSERT /*+ CREATE_NOTES.um_note2_insert */
            INTO um_note2
                (note_group_skey,
                 note_id,
                 note_type,
                 note_text,
                 line_type,
                 note_symbol)
                SELECT note_group_skey,
                       0 note_id,
                       0 note_type,
                       substr(ext.sf_getnote(line_type,
                                             version_type,
                                             note_group_skey),
                              1,
                              2000) note_text,
                       line_type,
                       note_symbol
                  FROM ext.service_category_detail
                 WHERE mfr_number = mfr_in
                   AND service_number = service_in
                   AND version_type = version_in
                   AND line_type IN ('C', 'F', 'K', 'L', 'R')
                UNION
                SELECT 0   note_group_skey,
                       0   note_id,
                       215 note_type,
                       -- 01/14/2005 mm5095 => added ppage support for motorcycles and RVs
--                       substr(sf_getppagetext(decode(least(mfr_number,
--                                                           '200'),
--                                                     '200',
--                                                     'MCS',
--                                                     decode(least(mfr_number,
--                                                                  '100'),
--                                                            '100',
--                                                            'RVS',
--                                                            CLASS)),
                                              --               decode(mfr_number,'006','ATG','CEG'))),
                                              --    substr(sf_getPPageText(decode(mfr_number,'006','ATG','CEG'),
                                              -- 01/14/2005 mm5095 => added ppage support for motorcycles and RVs
                       substr(sf_getppagetext(CLASS,
                                              mfr_number,
                                              service_number,
                                              version_type,
                                              category_skey),
                              1,
                              2000) note_text,
                       ' ' line_type,
                       ' ' note_symbol
                  FROM ext.service_category
                 WHERE mfr_number = mfr_in
                   AND service_number = service_in
                   AND version_type = version_in
                   AND subcategory_skey = 0
                   AND subcategory_qgroup_skey = 0
                -- 11/04/2011 mm5095 => added support for mtd/htd concatenation
                UNION
                SELECT b.note_group_skey,
                       0 note_id,
                       0 note_type,
                       substr(ext.sf_getnote(b.line_type,
                                             b.version_type,
                                             b.note_group_skey),
                              1,
                              2000) note_text,
                       b.line_type,
                       b.note_symbol
                  FROM service_category_substitution a
                 INNER JOIN service_category_detail b
                    ON b.mfr_number = a.substitute_mfr_number
                   AND b.service_number = a.substitute_service_number
                   AND ((b.subcategory_skey = 0 OR
                       b.subcategory_skey = a.substitute_subcategory_skey) OR
                       a.all_subcategory_flag = 'Y')
                   AND b.version_type = version_in
                 WHERE a.mfr_number = mfr_in
                   AND a.service_number = service_in
                   AND b.line_type IN ('C', 'F', 'K', 'L', 'R')
                UNION
                SELECT 0   note_group_skey,
                       0   note_id,
                       215 note_type,
                       -- 01/14/2005 mm5095 => added ppage support for motorcycles and RVs
--                       substr(sf_getppagetext(decode(least(b.mfr_number,
--                                                           '200'),
--                                                     '200',
--                                                     'MCS',
--                                                     decode(least(b.mfr_number,
--                                                                  '100'),
--                                                            '100',
--                                                            'RVS',
--                                                            CLASS)),
                                              --               decode(mfr_number,'006','ATG','CEG'))),
                                              --    substr(sf_getPPageText(decode(mfr_number,'006','ATG','CEG'),
                                              -- 01/14/2005 mm5095 => added ppage support for motorcycles and RVs
                       substr(sf_getppagetext(CLASS,
                                              b.mfr_number,
                                              b.service_number,
                                              b.version_type,
                                              b.category_skey),
                              1,
                              2000) note_text,
                       ' ' line_type,
                       ' ' note_symbol
                  FROM service_category_substitution a
                 INNER JOIN service_category b
                    ON b.mfr_number = a.substitute_mfr_number
                   AND b.service_number = a.substitute_service_number
                   AND b.category_skey = a.substitute_category_skey
                 WHERE a.mfr_number = mfr_in
                   AND a.service_number = service_in
                   AND b.version_type = version_in
                   AND b.subcategory_skey = 0
                   AND b.subcategory_qgroup_skey = 0;
            -- 11/04/2011 mm5095 => added support for mtd/htd concatenation

            -- insert "special notes" for each service
            INSERT /*+ CREATE_NOTES.um_note2_insert2 */
            INTO um_note2
                (note_group_skey,
                 note_id,
                 note_type,
                 note_text)
            VALUES
                (0,
                 0,
                 2,
                 'Included in Overhaul');
            INSERT /*+ CREATE_NOTES.um_note2_insert3 */
            INTO um_note2
                (note_group_skey,
                 note_id,
                 note_type,
                 note_text)
            VALUES
                (0,
                 0,
                 3,
                 'Discontinued by the Manufacturer');
            INSERT /*+ CREATE_NOTES.um_note2_insert4 */
            INTO um_note2
                (note_group_skey,
                 note_id,
                 note_type,
                 note_text)
            VALUES
                (0,
                 0,
                 4,
                 'Part Included in Clear Coat Application');
            INSERT /*+ CREATE_NOTES.um_note2_insert5 */
            INTO um_note2
                (note_group_skey,
                 note_id,
                 note_type,
                 note_text)
            VALUES
                (0,
                 0,
                 5,
                 'Remanufactured Part');
            INSERT /*+ CREATE_NOTES.um_note2_insert6 */
            INTO um_note2
                (note_group_skey,
                 note_id,
                 note_type,
                 note_text)
            VALUES
                (0,
                 0,
                 175,
                 'Special Pricing');
            INSERT /*+ CREATE_NOTES.um_note2_insert7 */
            INTO um_note2
                (note_group_skey,
                 note_id,
                 note_type,
                 note_text)
            VALUES
                (0,
                 0,
                 173,
                 'Interchangeable Part');

        ELSE
            -- MINI Logic

            DELETE /*+ CREATE_NOTES.um_note_delete_mini */
            FROM tmp_um_note;

            INSERT /*+ CREATE_NOTES.um_note_insert_mini */
            INTO tmp_um_note
                (note_group_skey,
                 note_id,
                 note_type,
                 note_text,
                 line_type,
                 note_symbol)
                SELECT note_group_skey,
                       0 note_id,
                       0 note_type,
                       substr(ext.sf_getnote(line_type,
                                             version_type,
                                             note_group_skey),
                              1,
                              2000) note_text,
                       line_type,
                       note_symbol
                  FROM ext.service_category_detail
                 WHERE mfr_number = mfr_in
                   AND service_number = service_in
                   AND version_type = version_in
                   AND line_type IN ('C', 'F', 'K', 'L', 'R')
                -- 11/04/2011 mm5095 => added support for mtd/htd concatenation
                UNION
                SELECT b.note_group_skey,
                       0 note_id,
                       0 note_type,
                       substr(ext.sf_getnote(b.line_type,
                                             b.version_type,
                                             b.note_group_skey),
                              1,
                              2000) note_text,
                       b.line_type,
                       b.note_symbol
                  FROM service_category_substitution a
                 INNER JOIN service_category_detail b
                    ON b.mfr_number = a.substitute_mfr_number
                   AND b.service_number = a.substitute_service_number
                   AND ((b.subcategory_skey = 0 OR
                       b.subcategory_skey = a.substitute_subcategory_skey) OR
                       a.all_subcategory_flag = 'Y')
                   AND b.version_type = version_in
                 WHERE a.mfr_number = mfr_in
                   AND a.service_number = service_in
                   AND b.line_type IN ('C', 'F', 'K', 'L', 'R')
                -- 11/04/2011 mm5095 => added support for mtd/htd concatenation
                UNION
                SELECT 0   note_group_skey,
                       0   note_id,
                       215 note_type,
                       -- 01/14/2005 mm5095 => added ppage support for motorcycles and RVs
--                       substr(sf_getppagetext(decode(least(mfr_number,
--                                                           '200'),
--                                                     '200',
--                                                     'MCS',
--                                                     decode(least(mfr_number,
--                                                                  '100'),
--                                                            '100',
--                                                            'RVS',
--                                                            CLASS)),
                                              --               decode(mfr_number,'006','ATG','CEG'))),
                                              --    substr(sf_getPPageText(decode(mfr_number,'006','ATG','CEG'),
                                              -- 01/14/2005 mm5095 => added ppage support for motorcycles and RVs
                       substr(sf_getppagetext(CLASS,
                                              mfr_number,
                                              service_number,
                                              version_type,
                                              category_skey),
                              1,
                              2000) note_text,
                       ' ' line_type,
                       ' ' note_symbol
                  FROM ext.service_category
                 WHERE mfr_number = mfr_in
                   AND service_number = service_in
                   AND version_type = version_in
                   AND subcategory_skey = 0
                   AND subcategory_qgroup_skey = 0;

            -- insert "special notes" for each service
            INSERT /*+ CREATE_NOTES.um_note_insert_mini2 */
            INTO tmp_um_note
                (note_group_skey,
                 note_id,
                 note_type,
                 note_text)
            VALUES
                (0,
                 0,
                 2,
                 'Included in Overhaul');
            INSERT /*+ CREATE_NOTES.um_note_insert_mini3 */
            INTO tmp_um_note
                (note_group_skey,
                 note_id,
                 note_type,
                 note_text)
            VALUES
                (0,
                 0,
                 3,
                 'Discontinued by the Manufacturer');
            INSERT /*+ CREATE_NOTES.um_note_insert_mini4 */
            INTO tmp_um_note
                (note_group_skey,
                 note_id,
                 note_type,
                 note_text)
            VALUES
                (0,
                 0,
                 4,
                 'Part Included in Clear Coat Application');
            INSERT /*+ CREATE_NOTES.um_note_insert_mini5 */
            INTO tmp_um_note
                (note_group_skey,
                 note_id,
                 note_type,
                 note_text)
            VALUES
                (0,
                 0,
                 5,
                 'Remanufactured Part');
            INSERT /*+ CREATE_NOTES.um_note_insert_mini6 */
            INTO tmp_um_note
                (note_group_skey,
                 note_id,
                 note_type,
                 note_text)
            VALUES
                (0,
                 0,
                 175,
                 'Special Pricing');
            INSERT /*+ CREATE_NOTES.um_note_insert_mini7 */
            INTO tmp_um_note
                (note_group_skey,
                 note_id,
                 note_type,
                 note_text)
            VALUES
                (0,
                 0,
                 173,
                 'Interchangeable Part');

        END IF;
        -- 2008/12/31 PAG - Combined Build and Parse (create_notes and create_notes2) logic based on runtype and parallel number

        /* -- File generation disabled: DI file fopen (FTP sunset)
            out_fhandle := utl_file.fopen(path,
                                          'DI' || service_barcode || '.txt',
                                          'w');
        -- end commented block */

        my_note_id := 0;

        -- 2008/12/31 PAG - Moved selects for distinct_cur and note_cur
        set_distinctnotes_cursor(distinctnotes_cur,
                                 run_type,
                                 parallel_number);
        LOOP
            FETCH distinctnotes_cur
                INTO distinctnotes_rec;
            EXIT WHEN distinctnotes_cur%NOTFOUND;
            -- 2008/12/31 PAG - Moved selects for distinct_cur and note_cur

            my_note_id := my_note_id + 1;

            nline := 1;

            -- 09/04/02 mm5095 => added support for blank line
            IF distinctnotes_rec.note_text = '[BLANK LINE]'
            THEN
                wrap_text := NULL;
            ELSE
                wrap_text := distinctnotes_rec.note_text;
            END IF;
            --      wrap_text := rec.note_text;
            -- 09/04/02 mm5095 => added support for blank line

            -- 09/28/2015 mm5095
            IF distinctnotes_rec.note_text = '[BLANK LINE]'
            THEN
                line_text_skey := 0;
            ELSE
                line_text_skey := sf_get_line_text_skey(wrap_text,
                                                        wrap_text);
            END IF;
            -- 09/28/2015 mm5095

            -- 02/09/2017 mm5095
            french_text := sf_getfrench(line_text_skey, wrap_text);
            -- 02/09/2017 mm5095

            WHILE TRUE
            LOOP
                IF length(wrap_text) > max_line_length
                THEN
                    npos := instr(wrap_text,
                                  ' ',
                                  max_line_length - length(wrap_text),
                                  1);
                    IF npos > 0
                    THEN
                        /* -- File generation disabled: DI put_line (FTP sunset)
                            utl_file.put_line(out_fhandle,
                                              my_note_id || '|' ||
                                              -- 02/09/2017 mm5095
                                               '1' || '|' ||
                                              -- 02/09/2017 mm5095
                                               nline || '|' ||
                                               substr(wrap_text, 1, npos - 1)
                                              -- 09/28/2015 mm5095
                                               || '|' || line_text_skey
                                              -- 09/28/2015
                                              );
                        -- end commented block */

                        -- 04/05/2020 pb0690 => Remove full versus mini check and code. Adding MCE Mini functionality.
                        -- 10/24/2007 mm5095 => insert into table to support french rewrite
                        update_um_di(service_barcode,
                                     my_note_id,
                                     nline,
                                     substr(wrap_text, 1, npos - 1));
                        -- 10/24/2007 mm5095 => insert into table to support french rewrite

                        wrap_text := substr(wrap_text, npos + 1);
                        nline     := nline + 1;
                    ELSE
                        /* -- File generation disabled: DI put_line (FTP sunset)
                            utl_file.put_line(out_fhandle,
                                              my_note_id || '|' ||
                                              -- 02/09/2017 mm5095
                                               '1' || '|' ||
                                              -- 02/09/2017 mm5095
                                               nline || '|' || wrap_text
                                              -- 09/28/2105 mm5095
                                               || '|' || line_text_skey
                                              -- 09/28/2015);
                                              );
                        -- end commented block */

                        -- 10/24/2007 mm5095 => insert into table to support french rewrite
                        update_um_di(service_barcode,
                                     my_note_id,
                                     nline,
                                     wrap_text);
                        -- 10/24/2007 mm5095 => insert into table to support french rewrite

                        EXIT;
                    END IF;
                ELSE
                    /* -- File generation disabled: DI put_line (FTP sunset)
                        utl_file.put_line(out_fhandle,
                                          my_note_id || '|' ||
                                          -- 02/09/2017 mm5095
                                           '1' || '|' ||
                                          -- 02/09/2017 mm5095
                                           nline || '|' || wrap_text
                                          -- 09/28/2105 mm5095
                                           || '|' || line_text_skey
                                          -- 09/28/2015);
                                          );
                    -- end commented block */

                    -- 10/24/2007 mm5095 => insert into table to support french rewrite
                    update_um_di(service_barcode,
                                 my_note_id,
                                 nline,
                                 wrap_text);
                    -- 10/24/2007 mm5095 => insert into table to support french rewrite

                    EXIT;
                END IF;
            END LOOP;

            -- 02/09/2107 mm5095
            wrap_text := french_text;
            nline     := 1;

            WHILE TRUE
            LOOP
                IF length(wrap_text) > max_line_length
                THEN
                    npos := instr(wrap_text,
                                  ' ',
                                  max_line_length - length(wrap_text),
                                  1);
                    IF npos > 0
                    THEN
                        /* -- File generation disabled: DI put_line French (FTP sunset)
                            utl_file.put_line(out_fhandle,
                                              my_note_id || '|' ||
                                              -- 02/09/2017 mm5095
                                               '2' || '|' ||
                                              -- 02/09/2017 mm5095
                                               nline || '|' ||
                                               substr(wrap_text, 1, npos - 1)
                                              -- 09/28/2015 mm5095
                                               || '|' || line_text_skey
                                              -- 09/28/2015
                                              );
                        -- end commented block */

                        wrap_text := substr(wrap_text, npos + 1);
                        nline     := nline + 1;
                    ELSE
                        /* -- File generation disabled: DI put_line French (FTP sunset)
                            utl_file.put_line(out_fhandle,
                                              my_note_id || '|' ||
                                              -- 02/09/2017 mm5095
                                               '2' || '|' ||
                                              -- 02/09/2017 mm5095
                                               nline || '|' || wrap_text
                                              -- 09/28/2105 mm5095
                                               || '|' || line_text_skey
                                              -- 09/28/2015);
                                              );
                        -- end commented block */
                        EXIT;
                    END IF;
                ELSE
                    /* -- File generation disabled: DI put_line French (FTP sunset)
                        utl_file.put_line(out_fhandle,
                                          my_note_id || '|' ||
                                          -- 02/09/2017 mm5095
                                           '2' || '|' ||
                                          -- 02/09/2017 mm5095
                                           nline || '|' || wrap_text
                                          -- 09/28/2105 mm5095
                                           || '|' || line_text_skey
                                          -- 09/28/2015);
                                          );
                    -- end commented block */
                    EXIT;
                END IF;
            END LOOP;
            -- 02/09/2107 mm5095

            -- 2008/12/31 PAG - Combined Build and Parse logic based on runtype
            IF run_type = 'FULL'
               AND parallel_number = '1'
            THEN
                -- FULL parallel 1
                UPDATE /*+ CREATE_NOTES.um_note_update */ um_note
                   SET note_id = my_note_id
                 WHERE note_text = distinctnotes_rec.note_text;
            ELSIF run_type = 'FULL'
                  AND parallel_number = '2'
            THEN
                -- FULL parallel 1
                UPDATE /*+ CREATE_NOTES.um_note2_update */ um_note2
                   SET note_id = my_note_id
                 WHERE note_text = distinctnotes_rec.note_text;
            ELSE
                -- MINI
                UPDATE /*+ CREATE_NOTES.um_note_update2 */ tmp_um_note
                   SET note_id = my_note_id
                 WHERE note_text = distinctnotes_rec.note_text;
            END IF;
            -- 2008/12/31 PAG - Combined Build and Parse logic based on runtype

        END LOOP;

        -- 2008/12/31 PAG - Moved selects for distinct_cur and note_cur
        CLOSE distinctnotes_cur;
        -- 2008/12/31 PAG - Moved selects for distinct_cur and note_cur

        /* -- File generation disabled: DI fclose and semaphore (FTP sunset)
            IF utl_file.is_open(out_fhandle)
            THEN
                utl_file.fclose(out_fhandle);

                -- update semaphore file
                pkg_ultramate_common.sp_output_barcode_semaphore(path,
                                                                 service_barcode,
                                                                 'DI' ||
                                                                 service_barcode ||
                                                                 '.txt',
                                                                 'a');
            END IF;
        -- end commented block */

        -- 2008/12/31 PAG - Moved selects for distinct_cur and note_cur
        set_note_cursor(notes_cur, run_type, parallel_number);
        LOOP
            FETCH notes_cur
                INTO notes_rec;
            EXIT WHEN notes_cur%NOTFOUND;
            -- 2008/12/31 PAG - Moved selects for distinct_cur and note_cur

            IF notes_rec.line_type = 'C'
            THEN
                IF substr(notes_rec.note_text, 1, 5) = 'NOTE:'
                THEN
                    my_note_type := 32;
                ELSIF substr(notes_rec.note_text, 1, 7) = 'NOTE 1:'
                THEN
                    my_note_type := 49;
                ELSIF substr(notes_rec.note_text, 1, 7) = 'NOTE 2:'
                THEN
                    my_note_type := 50;
                ELSE
                    -- error state
                    my_note_type := 0;
                END IF;
            ELSIF notes_rec.line_type = 'F'
            THEN
                IF notes_rec.note_symbol = '*'
                THEN
                    my_note_type := 171;
                ELSIF upper(notes_rec.note_symbol) BETWEEN 'A' AND 'Z'
                THEN
                    my_note_type := ascii(notes_rec.note_symbol);
                ELSE
                    -- error state
                    my_note_type := 0;
                END IF;
            ELSIF notes_rec.line_type = 'K'
            THEN
                my_note_type := 65;
            ELSIF notes_rec.line_type = 'L'
            THEN
                my_note_type := 35;
            ELSIF notes_rec.line_type = 'R'
            THEN
                my_note_type := 82;
            ELSE
                -- error state
                my_note_type := 0;
            END IF;

            IF run_type = 'FULL'
               AND parallel_number = '1'
            THEN
                -- FULL parallel 1
                UPDATE /*+ CREATE_NOTES.um_note_update3a */ um_note
                   SET note_type = my_note_type
                -- 2008/12/31 replaced "where current of" with match on ROWID due to use of REF Cursor
                 WHERE ROWID = notes_rec.note_rowid;
                --where current of notes_cur;
                -- 2008/12/31 "replaced where current of" with match on ROWID due to use of REF Cursor
            ELSIF run_type = 'FULL'
                  AND parallel_number = '2'
            THEN
                -- FULL parallel 2
                UPDATE /*+ CREATE_NOTES.um_note_update3b */ um_note2
                   SET note_type = my_note_type
                -- 2008/12/31 replaced "where current of" with match on ROWID due to use of REF Cursor
                 WHERE ROWID = notes_rec.note_rowid;
                --where current of notes_cur;
                -- 2008/12/31 "replaced where current of" with match on ROWID due to use of REF Cursor
            ELSE
                --MINI
                UPDATE /*+ CREATE_NOTES.tmp_um_note_update3c */ tmp_um_note
                   SET note_type = my_note_type
                -- 2008/12/31 replaced "where current of" with match on ROWID due to use of REF Cursor
                 WHERE ROWID = notes_rec.note_rowid;
                --where current of notes_cur;
                -- 2008/12/31 "replaced where current of" with match on ROWID due to use of REF Cursor

            END IF;

        END LOOP;

        -- 2008/12/31 PAG - Moved selects for distinct_cur and note_cur
        CLOSE notes_cur;
        -- 2008/12/31 PAG - Moved selects for distinct_cur and note_cur

    END create_notes;

    /* ----------------------------------------------------------------------------- CREATE_OPTIONS
         This routine creates: option-related txt file for UM and um_data_ tables for MCE.
         It also adds the txt file name to the service-related semaphore file so that Ultrldr
         program knows to process options for the service.
    */
    PROCEDURE create_options
    (
        service_barcode VARCHAR2,
        mfr_in          VARCHAR2,
        service_in      VARCHAR2,
        version_in      VARCHAR2,
        path            VARCHAR2,
        run_type        VARCHAR2
    ) IS
        CURSOR option_cur IS
            SELECT /*+ CREATE_OPTIONS.option_cur */
            DISTINCT barcode option_key,
                     '92' || b.prtc_body barcode,
                     labor_time * 10 labor_hrs
              FROM ext.service_category_detail a,
                   options                     b
             WHERE a.mfr_number = mfr_in
               AND a.service_number = service_in
               AND a.version_type = version_in
               AND a.unique_row_id = b.unique_row_id
               AND a.version_type = b.version_type
               AND barcode IS NOT NULL;

        out_fhandle utl_file.file_type;
        bfirsttime  BOOLEAN := TRUE;
    BEGIN

        FOR rec IN option_cur
        LOOP
            IF bfirsttime
            THEN
                /* -- File generation disabled: DG file fopen (FTP sunset)
                    out_fhandle := utl_file.fopen(path,
                                                  'DG' || service_barcode ||
                                                  '.txt',
                                                  'w');
                -- end commented block */
                bfirsttime  := FALSE;
            END IF;

            /* -- File generation disabled: DG put_line (FTP sunset)
                utl_file.put_line(out_fhandle,
                                  rec.option_key || '|' || rec.barcode || '|' ||
                                  rec.labor_hrs);
            -- end commented block */

            -- 04/05/2020 pb0690 => Remove full versus mini check and code. Adding MCE Mini functionality.
            -- 01/13/2010 mm5095 => insert into table to support next gen
            update_um_dg(service_barcode,
                         rec.option_key,
                         rec.barcode,
                         rec.labor_hrs);

        -- 01/13/2010 mm5095 => insert into table to support next gen

        END LOOP;

        /* -- File generation disabled: DG fclose and semaphore (FTP sunset)
            IF utl_file.is_open(out_fhandle)
            THEN
                utl_file.fclose(out_fhandle);
                -- update semaphore file

                -- update service semaphore
                pkg_ultramate_common.sp_output_barcode_semaphore(path,
                                                                 service_barcode,
                                                                 'DG' ||
                                                                 service_barcode ||
                                                                 '.txt',
                                                                 'a');
            END IF;
        -- end commented block */

    END create_options;

    /* ----------------------------------------------------------------------------- getStartEndDate */
    -- 2007/02/09 mm5095 => removed arguments not used
    PROCEDURE getstartenddate
    (
        lower_date     IN DATE,
        upper_date     IN DATE,
        start_date_out OUT VARCHAR2,
        end_date_out   OUT VARCHAR2
    )
    --  PROCEDURE getStartEndDate(lower_date in date, upper_date in date, start_date_out out varchar2, end_date_out out varchar2, bSuppress boolean) as
        -- 2007/02/09 mm5095 => removed arguments not used
     AS
    BEGIN
        start_date_out := -1;
        end_date_out   := -1;

        IF lower_date IS NOT NULL
        THEN
            start_date_out := to_char(lower_date, 'MMDDYYYY');
            end_date_out   := to_char(upper_date, 'MMDDYYYY');
        END IF;
    END getstartenddate;

    /* ----------------------------------------------------------------------------- getNoteId_by_Skey */
    PROCEDURE getnoteid_by_skey
    (
        skey            IN NUMBER,
        my_type         OUT NUMBER,
        my_id           OUT NUMBER,
        run_type        IN VARCHAR2,
        parallel_number IN CHAR
    ) IS

        CURSOR full_cur1 IS
            SELECT /*+ getNoteId_by_Skey.full_cur1 */
             note_type,
             note_id
              FROM um_note
             WHERE note_group_skey = skey;

        CURSOR full_cur2 IS
            SELECT /*+ getNoteId_by_Skey.full_cur2 */
             note_type,
             note_id
              FROM um_note2
             WHERE note_group_skey = skey;

        CURSOR mini_cur IS
            SELECT /*+ getNoteId_by_Skey.mini_cur */
             note_type,
             note_id
              FROM tmp_um_note
             WHERE note_group_skey = skey;

    BEGIN
        my_type := 0;
        my_id   := 0;

        IF run_type = 'FULL'
           AND parallel_number = '1'
        THEN
            OPEN full_cur1;
            FETCH full_cur1
                INTO my_type,
                     my_id;
            CLOSE full_cur1;
        ELSIF run_type = 'FULL'
              AND parallel_number = '2'
        THEN
            OPEN full_cur2;
            FETCH full_cur2
                INTO my_type,
                     my_id;
            CLOSE full_cur2;
        ELSE
            -- MINI run
            OPEN mini_cur;
            FETCH mini_cur
                INTO my_type,
                     my_id;
            CLOSE mini_cur;
        END IF;
    END;

    /* ----------------------------------------------------------------------------- getNoteId_by_Text */
    PROCEDURE getnoteid_by_text
    (
        my_text_in      IN VARCHAR2,
        my_type         IN NUMBER,
        my_id           OUT NUMBER,
        run_type        IN VARCHAR2,
        parallel_number IN CHAR
    ) IS

        CURSOR full_cur1 IS
            SELECT /*+ getNoteId_by_Text.full_cur1 */
             note_id
              FROM um_note
             WHERE note_type = my_type
               AND note_text = my_text_in;

        CURSOR full_cur2 IS
            SELECT /*+ getNoteId_by_Text.full_cur2 */
             note_id
              FROM um_note2
             WHERE note_type = my_type
               AND note_text = my_text_in;

        CURSOR mini_cur IS
            SELECT /*+ getNoteId_by_Text.mini_cur */
             note_id
              FROM tmp_um_note
             WHERE note_type = my_type
               AND note_text = my_text_in;

    BEGIN

        my_id := 0;

        IF run_type = 'FULL'
           AND parallel_number = '1'
        THEN
            OPEN full_cur1;
            FETCH full_cur1
                INTO my_id;
            CLOSE full_cur1;
        ELSIF run_type = 'FULL'
              AND parallel_number = '2'
        THEN
            OPEN full_cur2;
            FETCH full_cur2
                INTO my_id;
            CLOSE full_cur2;
        ELSE
            -- MINI run
            OPEN mini_cur;
            FETCH mini_cur
                INTO my_id;
            CLOSE mini_cur;
        END IF;
    END;

    -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5
    /* ----------------------------------------------------------------------------- sf_get_vehicle_type */
    FUNCTION sf_get_vehicle_type
    (
        barcode_in VARCHAR2,
        mfr_in     VARCHAR2
    ) RETURN NUMBER IS
        vn_return  NUMBER;
        class_code VARCHAR2(3);
    BEGIN
        IF mfr_in = '006'
        THEN
            BEGIN
                SELECT /*+ sf_get_vehicle_type.vcd_vehicle_service_select */
                 vehiclecategoryid
                  INTO vn_return
                  FROM vcd_vehicle_service
                 WHERE atgbarcode = barcode_in
                   AND rownum = 1;
            EXCEPTION
                WHEN OTHERS THEN
                    vn_return := -1;
            END;
        ELSE
            -- 01/06/2012 mm5095 bug fix
            BEGIN
                SELECT c.product_class_code
                  INTO class_code
                  FROM service a
                 INNER JOIN product_service b
                    ON b.mfr_number = a.mfr_number
                   AND b.service_number = a.service_number
                   AND b.product_code NOT IN ('TT0990', 'PT0990')
                 INNER JOIN product c
                    ON c.product_code = b.product_code
                 WHERE a.barcode = substr(barcode_in, 2)
                      -- 03/23/2012 mm5095 => added UM_Flag check
                      -- 04/17/2020 pg2697 => added MCE_flag check
                   AND (c.um_flag = 'Y' OR c.mce_flag = 'Y')
                   AND rownum = 1;

                IF class_code IN ('HTD', 'MTD')
                THEN
                    vn_return := 7;
                ELSE
                    BEGIN
                        SELECT /*+ sf_get_vehicle_type.vcd_vehicle_service_select2 */
                         vehiclecategoryid
                          INTO vn_return
                          FROM vcd_vehicle_service
                         WHERE servicebarcode = barcode_in;
                    EXCEPTION
                        WHEN OTHERS THEN
                            vn_return := -1;
                    END;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    vn_return := -1;
            END;
        END IF;
        RETURN vn_return;
    END;

    /* ----------------------------------------------------------------------------- sf_get_check_header */
    FUNCTION sf_get_check_header(vehicle_in NUMBER) RETURN BOOLEAN IS
        my_char CHAR(1);
    BEGIN
        SELECT /*+ sf_get_check_header.ceg_atg_category_xref_select */
         'X'
          INTO my_char
          FROM ceg_atg_category_xref
         WHERE vehicle_type_skey = vehicle_in
           AND rownum = 1;
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END;

    /* ----------------------------------------------------------------------------- sp_get_header_offset*/
    PROCEDURE sp_get_header_offset
    (
        header_offset_out OUT NUMBER,
        ceg_offset_out    OUT NUMBER
    ) IS
    BEGIN
        SELECT /*+ sp_get_header_offset.header_offset_select */
         category,
         ceg
          INTO header_offset_out,
               ceg_offset_out
          FROM header_offset;
    EXCEPTION
        WHEN OTHERS THEN
            -- todo: error_handling
            header_offset_out := 0;
            ceg_offset_out    := 0;
    END;

    /* ----------------------------------------------------------------------------- sf_get_header_sequence*/
    FUNCTION sf_get_header_sequence
    (
        vehicle_in    NUMBER,
        mfr_in        VARCHAR2,
        category_in   NUMBER,
        header_offset NUMBER,
        ceg_offset    NUMBER
    ) RETURN NUMBER IS
        vn_return   NUMBER;
        my_atg_flag CHAR(1) := 'N';
    BEGIN
        IF mfr_in = '006'
        THEN
            my_atg_flag := 'Y';
        END IF;

        SELECT /*+ sf_get_header_sequence.ceg_atg_category_xref_select */
         sequence_number
          INTO vn_return
          FROM ceg_atg_category_xref
         WHERE vehicle_type_skey = vehicle_in
           AND atg_flag = my_atg_flag
           AND category_skey = category_in;

        vn_return := vn_return * header_offset;
        IF mfr_in != '006'
        THEN
            vn_return := vn_return + ceg_offset;
        END IF;
        RETURN vn_return;
    EXCEPTION
        WHEN no_data_found THEN
            -- todo: error_handling
            RETURN - 1;
        WHEN OTHERS THEN
            -- todo: error_handling
            RETURN - 1;
    END;

    /* ----------------------------------------------------------------------------- sf_get_max_header_sequence*/
    FUNCTION sf_get_max_header_sequence
    (
        vehicle_in    NUMBER,
        header_offset NUMBER
    ) RETURN NUMBER IS
        vn_return NUMBER;
    BEGIN
        SELECT /*+ sf_get_max_header_sequence.ceg_atg_category_xref_select */
         MAX(sequence_number)
          INTO vn_return
          FROM ceg_atg_category_xref
         WHERE vehicle_type_skey = vehicle_in;

        vn_return := (vn_return + 1) * header_offset;
        RETURN vn_return;
    EXCEPTION
        WHEN no_data_found THEN
            -- todo: error_handling
            RETURN - 1;
        WHEN OTHERS THEN
            -- todo: error_handling
            RETURN - 1;
    END;
    -- 04/12/2006 mm5095 => add support for atg/ceg sequence UM 6.5

    /* ----------------------------------------------------------------------------- SET_HDR_DTL_CURSOR*/
    PROCEDURE set_hdr_dtl_cursor
    (
        cursor_parm IN OUT hdrdtl_cur,
        run_type    IN VARCHAR2,
        atg_mfr     VARCHAR2,
        atg_service VARCHAR2,
        mfr_in      VARCHAR2,
        service_in  VARCHAR2
    ) IS
    BEGIN

        -- 2008/12/31 PAG - Service concatenation.
        -- No need to use mfr1/service1 and mfr2/service2 for this query as
        -- mfr/service in tmp tables has already been decoded.
        -- select against VCD is to get the CEG service associated to an ATG service
        -- that is being processed.

        IF run_type = 'FULL'
        THEN

            OPEN cursor_parm FOR
                SELECT /*+ SET_HDR_DTL_CURSOR.cursor_parm_full */
                 a.mfr_number,
                 a.service_number,
                 prtc,
                 decode(overlap_type, 'HD', 72, 'OB', 79, 'RF', 82) TYPE,
                 min_labor_time,
                 transformed_prtc,
                 decode(adjustment_sign,
                        '-',
                        labor_time * -10,
                        labor_time * 10) labor_time
                  FROM tmp_um_header        a,
                       tmp_um_dtl_prtc_list b,
                       um_service_prtc      c
                 WHERE b.overlap_skey = a.overlap_skey
                   AND ((c.service_number = service_in AND
                       c.mfr_number = mfr_in) OR
                       (c.service_number = atg_service AND
                       c.mfr_number = atg_mfr) OR
                       (c.service_number, c.mfr_number) IN
                       (SELECT servicenumber,
                                manufacturernumber
                           FROM vcd_vehicle_service
                          WHERE atgmanufacturernumber = mfr_in
                            AND atgservicenumber = service_in))
                   AND c.transformed_prtc46 = substr(b.detail_prtc, 4, 6)
                   AND (substr(b.detail_prtc, 1, 3) =
                       substr(c.transformed_prtc, 1, 3) OR
                       substr(b.detail_prtc, 1, 3) = '$$$' OR
                       (substr(b.detail_prtc, 1, 2) = '$$' AND
                       (substr(b.detail_prtc, 3, 1) =
                       substr(c.transformed_prtc, 1, 1) OR
                       substr(b.detail_prtc, 3, 1) =
                       substr(c.transformed_prtc, 2, 1) OR
                       substr(b.detail_prtc, 3, 1) =
                       substr(c.transformed_prtc, 3, 1))) OR
                       (substr(b.detail_prtc, 1, 1) = '$' AND
                       (substr(b.detail_prtc, 2, 1) =
                       substr(c.transformed_prtc, 1, 1) OR
                       substr(b.detail_prtc, 2, 1) =
                       substr(c.transformed_prtc, 2, 1) OR
                       substr(b.detail_prtc, 2, 1) =
                       substr(c.transformed_prtc, 3, 1)) AND
                       (substr(b.detail_prtc, 3, 1) =
                       substr(c.transformed_prtc, 1, 1) OR
                       substr(b.detail_prtc, 3, 1) =
                       substr(c.transformed_prtc, 2, 1) OR
                       substr(b.detail_prtc, 3, 1) =
                       substr(c.transformed_prtc, 3, 1))) OR
                       (substr(c.transformed_prtc, 3, 1) BETWEEN '0' AND '9' AND
                       '*' || substr(c.transformed_prtc, 1, 2) =
                       substr(b.detail_prtc, 1, 3)))
                UNION
                SELECT a.mfr_number,
                       a.service_number,
                       prtc,
                       decode(overlap_type, 'HD', 72, 'OB', 79, 'RF', 82) TYPE,
                       min_labor_time,
                       detail_prtc AS transformed_prtc,
                       decode(adjustment_sign,
                              '-',
                              labor_time * -10,
                              labor_time * 10) labor_time
                  FROM tmp_um_header        a,
                       tmp_um_dtl_prtc_list b
                 WHERE b.overlap_skey = a.overlap_skey
                   AND substr(b.detail_prtc, 4, 4) = 'XXXX';

        ELSE
            -- MINI

            OPEN cursor_parm FOR
                SELECT /*+ SET_HDR_DTL_CURSOR.cursor_parm_mini */
                 a.mfr_number,
                 a.service_number,
                 prtc,
                 decode(overlap_type, 'HD', 72, 'OB', 79, 'RF', 82) TYPE,
                 min_labor_time,
                 transformed_prtc,
                 decode(adjustment_sign,
                        '-',
                        labor_time * -10,
                        labor_time * 10) labor_time
                  FROM tmp_um_header        a,
                       tmp_um_dtl_prtc_list b,
                       tmp_um_service_prtc  c
                 WHERE b.overlap_skey = a.overlap_skey
                   AND ((c.service_number = service_in AND
                       c.mfr_number = mfr_in) OR
                       (c.service_number = atg_service AND
                       c.mfr_number = atg_mfr) OR
                       (c.service_number, c.mfr_number) IN
                       (SELECT servicenumber,
                                manufacturernumber
                           FROM vcd_vehicle_service
                          WHERE atgmanufacturernumber = mfr_in
                            AND atgservicenumber = service_in))
                   AND c.transformed_prtc46 = substr(b.detail_prtc, 4, 6)
                   AND (substr(b.detail_prtc, 1, 3) =
                       substr(c.transformed_prtc, 1, 3) OR
                       substr(b.detail_prtc, 1, 3) = '$$$' OR
                       (substr(b.detail_prtc, 1, 2) = '$$' AND
                       (substr(b.detail_prtc, 3, 1) =
                       substr(c.transformed_prtc, 1, 1) OR
                       substr(b.detail_prtc, 3, 1) =
                       substr(c.transformed_prtc, 2, 1) OR
                       substr(b.detail_prtc, 3, 1) =
                       substr(c.transformed_prtc, 3, 1))) OR
                       (substr(b.detail_prtc, 1, 1) = '$' AND
                       (substr(b.detail_prtc, 2, 1) =
                       substr(c.transformed_prtc, 1, 1) OR
                       substr(b.detail_prtc, 2, 1) =
                       substr(c.transformed_prtc, 2, 1) OR
                       substr(b.detail_prtc, 2, 1) =
                       substr(c.transformed_prtc, 3, 1)) AND
                       (substr(b.detail_prtc, 3, 1) =
                       substr(c.transformed_prtc, 1, 1) OR
                       substr(b.detail_prtc, 3, 1) =
                       substr(c.transformed_prtc, 2, 1) OR
                       substr(b.detail_prtc, 3, 1) =
                       substr(c.transformed_prtc, 3, 1))) OR
                       (substr(c.transformed_prtc, 3, 1) BETWEEN '0' AND '9' AND
                       '*' || substr(c.transformed_prtc, 1, 2) =
                       substr(b.detail_prtc, 1, 3)))
                UNION
                SELECT a.mfr_number,
                       a.service_number,
                       prtc,
                       decode(overlap_type, 'HD', 72, 'OB', 79, 'RF', 82) TYPE,
                       min_labor_time,
                       detail_prtc AS transformed_prtc,
                       decode(adjustment_sign,
                              '-',
                              labor_time * -10,
                              labor_time * 10) labor_time
                  FROM tmp_um_header        a,
                       tmp_um_dtl_prtc_list b
                 WHERE b.overlap_skey = a.overlap_skey
                   AND substr(b.detail_prtc, 4, 4) = 'XXXX';

        END IF;

    END set_hdr_dtl_cursor;

    /* ----------------------------------------------------------------------------- SET_EXCPT_WIP_CURSOR*/
    PROCEDURE set_excpt_wip_cursor
    (
        cursor_parm IN OUT excptwip_cur,
        run_type    IN VARCHAR2,
        skey_in     NUMBER,
        mfr_in      VARCHAR2,
        service_in  VARCHAR2
    ) IS
    BEGIN

        -- 2008/12/31 PAG - Service concatenation.
        -- No need to use mfr1/service1 and mfr2/service2 for excpt_wip_cur
        -- queries as mfr/service in tmp table has already been decoded.

        IF run_type = 'FULL'
        THEN

            OPEN cursor_parm FOR
                SELECT /*+ SET_EXCPT_WIP_CURSOR.cursor_parm_full */
                 a.transformed_prtc
                  FROM um_service_prtc          a,
                       combo_overlap_header_wip b
                 WHERE b.combo_overlap_skey = skey_in
                   AND rtrim(b.excpt_prtc_1) IS NOT NULL
                   AND a.mfr_number = mfr_in
                   AND a.service_number = service_in
                   AND substr(b.excpt_prtc_1, 4, 6) = a.transformed_prtc46
                UNION
                SELECT a.transformed_prtc
                  FROM um_service_prtc          a,
                       combo_overlap_header_wip b
                 WHERE b.combo_overlap_skey = skey_in
                   AND rtrim(b.excpt_prtc_2) IS NOT NULL
                   AND a.mfr_number = mfr_in
                   AND a.service_number = service_in
                   AND substr(b.excpt_prtc_2, 4, 6) = a.transformed_prtc46
                UNION
                SELECT a.transformed_prtc
                  FROM um_service_prtc          a,
                       combo_overlap_header_wip b
                 WHERE b.combo_overlap_skey = skey_in
                   AND rtrim(b.excpt_prtc_3) IS NOT NULL
                   AND a.mfr_number = mfr_in
                   AND a.service_number = service_in
                   AND substr(b.excpt_prtc_3, 4, 6) = a.transformed_prtc46
                UNION
                SELECT a.transformed_prtc
                  FROM um_service_prtc          a,
                       combo_overlap_header_wip b
                 WHERE b.combo_overlap_skey = skey_in
                   AND rtrim(b.excpt_prtc_4) IS NOT NULL
                   AND a.mfr_number = mfr_in
                   AND a.service_number = service_in
                   AND substr(b.excpt_prtc_4, 4, 6) = a.transformed_prtc46
                UNION
                SELECT a.transformed_prtc
                  FROM um_service_prtc          a,
                       combo_overlap_header_wip b
                 WHERE b.combo_overlap_skey = skey_in
                   AND rtrim(b.excpt_prtc_5) IS NOT NULL
                   AND a.mfr_number = mfr_in
                   AND a.service_number = service_in
                   AND substr(b.excpt_prtc_5, 4, 6) = a.transformed_prtc46;

        ELSE
            -- MINI

            OPEN cursor_parm FOR
                SELECT /*+ SET_EXCPT_WIP_CURSOR.cursor_parm_mini */
                 a.transformed_prtc
                  FROM tmp_um_service_prtc      a,
                       combo_overlap_header_wip b
                 WHERE b.combo_overlap_skey = skey_in
                   AND rtrim(b.excpt_prtc_1) IS NOT NULL
                   AND a.mfr_number = mfr_in
                   AND a.service_number = service_in
                   AND substr(b.excpt_prtc_1, 4, 6) = a.transformed_prtc46
                UNION
                SELECT a.transformed_prtc
                  FROM tmp_um_service_prtc      a,
                       combo_overlap_header_wip b
                 WHERE b.combo_overlap_skey = skey_in
                   AND rtrim(b.excpt_prtc_2) IS NOT NULL
                   AND a.mfr_number = mfr_in
                   AND a.service_number = service_in
                   AND substr(b.excpt_prtc_2, 4, 6) = a.transformed_prtc46
                UNION
                SELECT a.transformed_prtc
                  FROM tmp_um_service_prtc      a,
                       combo_overlap_header_wip b
                 WHERE b.combo_overlap_skey = skey_in
                   AND rtrim(b.excpt_prtc_3) IS NOT NULL
                   AND a.mfr_number = mfr_in
                   AND a.service_number = service_in
                   AND substr(b.excpt_prtc_3, 4, 6) = a.transformed_prtc46
                UNION
                SELECT a.transformed_prtc
                  FROM tmp_um_service_prtc      a,
                       combo_overlap_header_wip b
                 WHERE b.combo_overlap_skey = skey_in
                   AND rtrim(b.excpt_prtc_4) IS NOT NULL
                   AND a.mfr_number = mfr_in
                   AND a.service_number = service_in
                   AND substr(b.excpt_prtc_4, 4, 6) = a.transformed_prtc46
                UNION
                SELECT a.transformed_prtc
                  FROM tmp_um_service_prtc      a,
                       combo_overlap_header_wip b
                 WHERE b.combo_overlap_skey = skey_in
                   AND rtrim(b.excpt_prtc_5) IS NOT NULL
                   AND a.mfr_number = mfr_in
                   AND a.service_number = service_in
                   AND substr(b.excpt_prtc_5, 4, 6) = a.transformed_prtc46;

        END IF;

    END set_excpt_wip_cursor;

    /* ----------------------------------------------------------------------------- SET_EXCPT_PRD_CURSOR*/
    PROCEDURE set_excpt_prd_cursor
    (
        cursor_parm IN OUT excptprd_cur,
        run_type    IN VARCHAR2,
        skey_in     NUMBER,
        mfr_in      VARCHAR2,
        service_in  VARCHAR2
    ) IS
    BEGIN

        -- 2008/12/31 PAG - Service concatenation.
        -- No need to use mfr1/service1 and mfr2/service2 for excpt_cur
        -- queries as mfr/service in tmp table has already been decoded.

        IF run_type = 'FULL'
        THEN

            OPEN cursor_parm FOR
                SELECT /*+ SET_EXCPT_PRD_CURSOR.cursor_parm_full */
                 a.transformed_prtc
                  FROM um_service_prtc      a,
                       combo_overlap_header b
                -- from um_service_prtc a, combo_overlap_header_wip b
                 WHERE b.combo_overlap_skey = skey_in
                   AND rtrim(b.excpt_prtc_1) IS NOT NULL
                   AND a.mfr_number = mfr_in
                   AND a.service_number = service_in
                   AND substr(b.excpt_prtc_1, 4, 6) = a.transformed_prtc46
                UNION
                SELECT a.transformed_prtc
                  FROM um_service_prtc      a,
                       combo_overlap_header b
                -- from um_service_prtc a, combo_overlap_header_wip b
                 WHERE b.combo_overlap_skey = skey_in
                   AND rtrim(b.excpt_prtc_2) IS NOT NULL
                   AND a.mfr_number = mfr_in
                   AND a.service_number = service_in
                   AND substr(b.excpt_prtc_2, 4, 6) = a.transformed_prtc46
                UNION
                SELECT a.transformed_prtc
                  FROM um_service_prtc      a,
                       combo_overlap_header b
                -- from um_service_prtc a, combo_overlap_header_wip b
                 WHERE b.combo_overlap_skey = skey_in
                   AND rtrim(b.excpt_prtc_3) IS NOT NULL
                   AND a.mfr_number = mfr_in
                   AND a.service_number = service_in
                   AND substr(b.excpt_prtc_3, 4, 6) = a.transformed_prtc46
                UNION
                SELECT a.transformed_prtc
                  FROM um_service_prtc      a,
                       combo_overlap_header b
                -- from um_service_prtc a, combo_overlap_header_wip b
                 WHERE b.combo_overlap_skey = skey_in
                   AND rtrim(b.excpt_prtc_4) IS NOT NULL
                   AND a.mfr_number = mfr_in
                   AND a.service_number = service_in
                   AND substr(b.excpt_prtc_4, 4, 6) = a.transformed_prtc46
                UNION
                SELECT a.transformed_prtc
                  FROM um_service_prtc      a,
                       combo_overlap_header b
                -- from um_service_prtc a, combo_overlap_header_wip b
                 WHERE b.combo_overlap_skey = skey_in
                   AND rtrim(b.excpt_prtc_5) IS NOT NULL
                   AND a.mfr_number = mfr_in
                   AND a.service_number = service_in
                   AND substr(b.excpt_prtc_5, 4, 6) = a.transformed_prtc46;

        ELSE
            -- MINI

            OPEN cursor_parm FOR
            -- 2008/12/31 PAG - Corrected from statements (should not be "_wip")
                SELECT /*+ SET_EXCPT_PRD_CURSOR.cursor_parm_mini */
                 a.transformed_prtc
                  FROM tmp_um_service_prtc  a,
                       combo_overlap_header b
                -- from tmp_um_service_prtc a, combo_overlap_header_wip b
                 WHERE b.combo_overlap_skey = skey_in
                   AND rtrim(b.excpt_prtc_1) IS NOT NULL
                   AND a.mfr_number = mfr_in
                   AND a.service_number = service_in
                   AND substr(b.excpt_prtc_1, 4, 6) = a.transformed_prtc46
                UNION
                SELECT a.transformed_prtc
                  FROM tmp_um_service_prtc  a,
                       combo_overlap_header b
                -- from tmp_um_service_prtc a, combo_overlap_header_wip b
                 WHERE b.combo_overlap_skey = skey_in
                   AND rtrim(b.excpt_prtc_2) IS NOT NULL
                   AND a.mfr_number = mfr_in
                   AND a.service_number = service_in
                   AND substr(b.excpt_prtc_2, 4, 6) = a.transformed_prtc46
                UNION
                SELECT a.transformed_prtc
                  FROM tmp_um_service_prtc  a,
                       combo_overlap_header b
                -- from tmp_um_service_prtc a, combo_overlap_header_wip b
                 WHERE b.combo_overlap_skey = skey_in
                   AND rtrim(b.excpt_prtc_3) IS NOT NULL
                   AND a.mfr_number = mfr_in
                   AND a.service_number = service_in
                   AND substr(b.excpt_prtc_3, 4, 6) = a.transformed_prtc46
                UNION
                SELECT a.transformed_prtc
                  FROM tmp_um_service_prtc  a,
                       combo_overlap_header b
                -- from tmp_um_service_prtc a, combo_overlap_header_wip b
                 WHERE b.combo_overlap_skey = skey_in
                   AND rtrim(b.excpt_prtc_4) IS NOT NULL
                   AND a.mfr_number = mfr_in
                   AND a.service_number = service_in
                   AND substr(b.excpt_prtc_4, 4, 6) = a.transformed_prtc46
                UNION
                SELECT a.transformed_prtc
                  FROM tmp_um_service_prtc  a,
                       combo_overlap_header b
                -- from tmp_um_service_prtc a, combo_overlap_header_wip b
                 WHERE b.combo_overlap_skey = skey_in
                   AND rtrim(b.excpt_prtc_5) IS NOT NULL
                   AND a.mfr_number = mfr_in
                   AND a.service_number = service_in
                   AND substr(b.excpt_prtc_5, 4, 6) = a.transformed_prtc46;
            -- 2008/12/31 PAG - Service concatenation.

        END IF;

    END set_excpt_prd_cursor;

    /* ----------------------------------------------------------------------------- CREATE_OVERLAP
         This routine creates: overlap-related txt files for UM and um_data_ tables for MCE.
         It also adds the txt files names to the service-related semaphore file so that Ultrldr
         program knows to process overlap for the service.
    */

    PROCEDURE create_overlap
    (
        service_barcode VARCHAR2,
        mfr_in          VARCHAR2,
        service_in      VARCHAR2,
        version_in      VARCHAR2,
        mfr1            VARCHAR2,
        service1        VARCHAR2,
        mfr2            VARCHAR2,
        service2        VARCHAR2,
        run_type        VARCHAR2,
        path            VARCHAR2
    ) IS
        -- 2008/12/31 PAG - Service concatenation.
        -- PROCEDURE create_overlap(service_barcode varchar2, mfr_in varchar2, service_in varchar2, version_in varchar2)
        -- IS
        -- 2008/12/31 PAG - Service concatenation.

        atg_mfr     VARCHAR2(3) := NULL;
        atg_service VARCHAR2(5) := NULL;

        -- 2008/12/31 PAG - Service concatenation.
        -- Note: CEG-related mfr/service numbers must be forced to mfr_in/service_in
        CURSOR rr_header_wip_cur IS
            SELECT /*+ create_overlap.rr_header_wip_cur */
             decode(nvl(oh.mfr_number, '000'),
                    '000',
                    '000',
                    atg_mfr,
                    atg_mfr,
                    mfr_in) mfr_number,
             decode(nvl(oh.service_number, '00000'),
                    '00000',
                    '00000',
                    atg_service,
                    atg_service,
                    service_in) service_number,
             oh.overlap_type,
             oh.overlap_skey,
             substr(sf_transformprtc(oh.prtc, 'OVERLAP'), 1, 10) transformed_prtc,
             oh.min_labor_time,
             oh.table_id
              FROM overlap_header_wip oh
             WHERE (((oh.mfr_number = mfr1 AND oh.service_number = service1) OR
                   (oh.mfr_number = mfr1 AND oh.service_number IS NULL) OR
                   (oh.mfr_number = mfr2 AND oh.service_number = service2) OR
                   (oh.mfr_number = mfr2 AND oh.service_number IS NULL) OR
                   (oh.mfr_number IS NULL AND oh.service_number IS NULL) OR
                   (oh.mfr_number = atg_mfr AND oh.service_number = atg_service) OR
                   (oh.mfr_number = atg_mfr AND oh.service_number IS NULL)) AND
                    oh.prtc NOT IN
                       (SELECT oh1.prtc
                          FROM overlap_header_wip oh1, service_category_substitution scs
                          WHERE scs.mfr_number = mfr1
                            AND scs.service_number = service1
                            AND oh1.mfr_number = scs.substitute_mfr_number
                            AND oh1.service_number = scs.substitute_service_number
                            AND overlap_type = 'RR'))
                 AND overlap_type = 'RR'
            UNION
             SELECT /*+ create_overlap.rr_header_cur */
	             decode(nvl(oh.mfr_number, '000'),
	             '000',
	             '000',
	             atg_mfr,
	             atg_mfr,
	             mfr_in) AS mfr_number,
	             decode(nvl(oh.service_number, '00000'),
	                    '00000',
	                    '00000',
	                    atg_service,
	                    atg_service,
	                    service_in) AS service_number,
	             oh.overlap_type,
	             oh.overlap_skey,
	             substr(sf_transformprtc(oh.prtc, 'OVERLAP'), 1, 10) transformed_prtc,
	             oh.min_labor_time,
	             oh.table_id
	             FROM overlap_header_wip oh, service_category_substitution scs
	             WHERE scs.mfr_number = mfr1
	               AND scs.service_number = service1
	               AND oh.mfr_number = scs.substitute_mfr_number
	               AND oh.service_number = scs.substitute_service_number
               AND overlap_type = 'RR'
               ORDER BY 1,2,5;
/*
            -- 05/08/2009 PAG - changed sort of mfr_number, service_number to include decode
             ORDER BY decode(nvl(mfr_number, '000'),
                             '000',
                             '000',
                             atg_mfr,
                             atg_mfr,
                             mfr_in),
                      decode(nvl(service_number, '00000'),
                             '00000',
                             '00000',
                             atg_service,
                             atg_service,
                             service_in),
                      table_id;
*/
        --    order by mfr_number, service_number, table_id;
        -- 05/08/2009 PAG - changed sort of mfr_number, service_number to include decode

        CURSOR rr_header_cur IS
            SELECT /*+ create_overlap.rr_header_cur */
             decode(nvl(oh.mfr_number, '000'),
                    '000',
                    '000',
                    atg_mfr,
                    atg_mfr,
                    mfr_in) AS mfr_number,
             decode(nvl(oh.service_number, '00000'),
                    '00000',
                    '00000',
                    atg_service,
                    atg_service,
                    service_in) AS service_number,
             oh.overlap_type,
             oh.overlap_skey,
             substr(sf_transformprtc(oh.prtc, 'OVERLAP'), 1, 10) transformed_prtc,
             oh.min_labor_time,
             oh.table_id
              FROM overlap_header oh
             WHERE (((mfr_number = mfr1 AND service_number = service1) OR
                   (mfr_number = mfr1 AND service_number IS NULL) OR
                   (mfr_number = mfr2 AND service_number = service2) OR
                   (mfr_number = mfr2 AND service_number IS NULL) OR
                   (mfr_number IS NULL AND service_number IS NULL) OR
                   (mfr_number = atg_mfr AND service_number = atg_service) OR
                   (mfr_number = atg_mfr AND service_number IS NULL) AND
                   (oh.mfr_number = atg_mfr AND oh.service_number IS NULL)) AND
                    oh.prtc NOT IN
                       (SELECT oh1.prtc
                          FROM overlap_header oh1, service_category_substitution scs
                          WHERE scs.mfr_number = mfr1
                            AND scs.service_number = service1
                            AND oh1.mfr_number = scs.substitute_mfr_number
                            AND oh1.service_number = scs.substitute_service_number
                            AND overlap_type = 'RR'))
               AND overlap_type = 'RR'
            UNION
             SELECT /*+ create_overlap.rr_header_cur */
               decode(nvl(oh.mfr_number, '000'),
               '000',
               '000',
               atg_mfr,
               atg_mfr,
               mfr_in) AS mfr_number,
               decode(nvl(oh.service_number, '00000'),
                      '00000',
                      '00000',
                      atg_service,
                      atg_service,
                      service_in) AS service_number,
               oh.overlap_type,
               oh.overlap_skey,
               substr(sf_transformprtc(oh.prtc, 'OVERLAP'), 1, 10) transformed_prtc,
               oh.min_labor_time,
               oh.table_id
               FROM overlap_header oh, service_category_substitution scs
               WHERE scs.mfr_number = mfr1
                 AND scs.service_number = service1
                 AND oh.mfr_number = scs.substitute_mfr_number
                 AND oh.service_number = scs.substitute_service_number
               AND overlap_type = 'RR'
               ORDER BY 1,2,5;

            -- 05/08/2009 PAG - changed sort of mfr_number, service_number to include decode
/*
             ORDER BY decode(nvl(mfr_number, '000'),
                             '000',
                             '000',
                             atg_mfr,
                             atg_mfr,
                             mfr_in),
                      decode(nvl(service_number, '00000'),
                             '00000',
                             '00000',
                             atg_service,
                             atg_service,
                             service_in),
                      table_id;
*/
/*
            -- 05/08/2009 PAG - changed sort of mfr_number, service_number to include decode
             ORDER BY decode(nvl(mfr_number, '000'),
                             '000',
                             '000',
                             atg_mfr,
                             atg_mfr,
                             mfr_in),
                      decode(nvl(service_number, '00000'),
                             '00000',
                             '00000',
                             atg_service,
                             atg_service,
                             service_in),
                      table_id;
*/
        --    order by mfr_number, service_number, table_id;
        -- 05/08/2009 PAG - changed sort of mfr_number, service_number to include decode

        /*
            cursor rr_header_wip_cur is
            select nvl(mfr_number,'000') mfr_number, nvl(service_number,'00000') service_number,
            overlap_type, overlap_skey,
            substr(sf_transformprtc(prtc,'OVERLAP'),1,10) transformed_prtc, min_labor_time, table_id
            from overlap_header_wip
            where ((mfr_number = mfr_in and service_number = service_in)
              or (mfr_number = mfr_in and service_number is null)
              or (mfr_number is null and service_number is null)
              or (mfr_number = atg_mfr and service_number = atg_service)
              or (mfr_number = atg_mfr and service_number is null))
              and overlap_type = 'RR'
            order by mfr_number, service_number, table_id;

            cursor rr_header_cur is
            select nvl(mfr_number,'000') mfr_number, nvl(service_number,'00000') service_number,
            overlap_type, overlap_skey,
            substr(sf_transformprtc(prtc,'OVERLAP'),1,10) transformed_prtc, min_labor_time, table_id
            from overlap_header
            where ((mfr_number = mfr_in and service_number = service_in)
              or (mfr_number = mfr_in and service_number is null)
              or (mfr_number is null and service_number is null)
              or (mfr_number = atg_mfr and service_number = atg_service)
              or (mfr_number = atg_mfr and service_number is null) )
              and overlap_type = 'RR'
            order by mfr_number, service_number, table_id;
        */
        -- 2008/12/31 PAG - Service concatenation.

        CURSOR rr_detail_wip_cur(skey IN NUMBER) IS
            SELECT /*+ create_overlap.rr_detail_wip_cur */
             prtc,
             labor_time,
             adjustment_sign,
             rr_sequence_number
              FROM overlap_detail_wip
             WHERE overlap_skey = skey
             ORDER BY rr_sequence_number;

        CURSOR rr_detail_cur(skey IN NUMBER) IS
            SELECT /*+ create_overlap.rr_detail_cur */
             prtc,
             labor_time,
             adjustment_sign,
             rr_sequence_number
              FROM overlap_detail
             WHERE overlap_skey = skey
             ORDER BY rr_sequence_number;

        rr_detail_rec rr_detail_cur%ROWTYPE;

        TYPE typetbloverlapdetail IS TABLE OF rr_detail_cur%ROWTYPE INDEX BY BINARY_INTEGER;
        tbldetail      typetbloverlapdetail;
        emptytbldetail typetbloverlapdetail;

        --06/04/2009 mm5095/pg2697 => correct ATG/CEG overlap issue
        CURSOR header_detail_cur IS
            SELECT /*+ create_overlap.header_detail_cur */
             tuhd.prtc,
             tuhd.type,
             tuhd.mfr_number,
             tuhd.service_number,
             tuhd.min_labor_time,
             tuhd.transformed_prtc,
             tuhd.labor_time
              FROM tmp_um_hdr_dtl tuhd
             WHERE mfr_number != '006'
             ORDER BY prtc           DESC,
                      TYPE           DESC,
                      mfr_number     DESC,
                      service_number DESC;

        CURSOR header_detail_006_cur IS
            SELECT /*+ create_overlap.header_detail_006_cur */
             tuhd.prtc,
             tuhd.type,
             tuhd.mfr_number,
             tuhd.service_number,
             tuhd.min_labor_time,
             tuhd.transformed_prtc,
             tuhd.labor_time
              FROM tmp_um_hdr_dtl tuhd
             WHERE mfr_number = '006'
             ORDER BY prtc           DESC,
                      TYPE           DESC,
                      mfr_number     DESC,
                      service_number DESC;

        --    cursor header_detail_cur is
        --    select /*+ create_overlap.header_detail_cur */ tuhd.prtc, tuhd.type,
        --           tuhd.mfr_number, tuhd.service_number,
        --           tuhd.min_labor_time, tuhd.transformed_prtc, tuhd.labor_time
        --    from tmp_um_hdr_dtl tuhd
        --    order by prtc desc, type desc, mfr_number desc, service_number desc;
        --06/04/2009 mm5095/pg2697 => correct ATG/CEG overlap issue

        -- 2008/12/31 PAG - Moved select associated to hdr_dtl_cur into procedure SET_HDR_DTL_CURSOR
        -- so that selection criteria can be changed based on run_type.
        hdr_dtl_cur hdrdtl_cur;
        hdr_dtl_rec hdrdtl_rec;
        -- 2008/12/31 PAG - Moved select associated to hdr_dtl_cur

        CURSOR rf_xxxx_cur IS
            SELECT /*+ create_overlap.rf_xxxx_cur */
             mfr_number,
             service_number,
             prtc,
             decode(overlap_type, 'HD', 72, 'OB', 79, 'RF', 82) TYPE
              FROM tmp_um_header
             WHERE overlap_type = 'RF'
            MINUS
            SELECT mfr_number,
                   service_number,
                   prtc,
                   TYPE
              FROM tmp_um_hdr_dtl;

        -- 2008/12/31 PAG - Service concatenation.
        -- Note: CEG-related mfr/service numbers must be forced to mfr_in/service_in
        CURSOR hdr_wip_cur IS
            SELECT /*+ create_overlap.hdr_wip_cur */
             decode(nvl(mfr_number, '000'),
                    '000',
                    '000',
                    atg_mfr,
                    atg_mfr,
                    mfr_in) AS mfr_number,
             decode(nvl(service_number, '00000'),
                    '00000',
                    '00000',
                    atg_service,
                    atg_service,
                    service_in) AS service_number,
             autoincl_prtc,
             substr(sf_transformprtc(incl_prtc_1, 'COMBINED'), 1, 10) incl_prtc_1,
             substr(sf_transformprtc(incl_prtc_2, 'COMBINED'), 1, 10) incl_prtc_2,
             substr(sf_transformprtc(incl_prtc_3, 'COMBINED'), 1, 10) incl_prtc_3,
             substr(sf_transformprtc(incl_prtc_4, 'COMBINED'), 1, 10) incl_prtc_4,
             substr(sf_transformprtc(incl_prtc_5, 'COMBINED'), 1, 10) incl_prtc_5,
             combo_overlap_skey
              FROM combo_overlap_header_wip
             WHERE (mfr_number IS NULL AND service_number IS NULL)
                OR (mfr_number = mfr1 AND service_number = service1)
                OR (mfr_number = mfr2 AND service_number = service2)
             ORDER BY autoincl_prtc DESC,
                      incl_prtc_1   DESC,
                      incl_prtc_2   DESC,
                      incl_prtc_3   DESC,
                      incl_prtc_4   DESC,
                      incl_prtc_5   DESC,
                      -- 05/08/2009 PAG - changed sort of mfr_number, service_number to include decode
                      --             mfr_number desc,
                      --             service_number desc;
                      decode(nvl(mfr_number, '000'),
                             '000',
                             '000',
                             atg_mfr,
                             atg_mfr,
                             mfr_in) DESC,
                      decode(nvl(service_number, '00000'),
                             '00000',
                             '00000',
                             atg_service,
                             atg_service,
                             service_in) DESC;
        -- 05/08/2009 PAG - changed sort of mfr_number, service_number to include decode

        CURSOR hdr_cur IS
            SELECT /*+ create_overlap.hdr_cur */
             decode(nvl(mfr_number, '000'),
                    '000',
                    '000',
                    atg_mfr,
                    atg_mfr,
                    mfr_in) AS mfr_number,
             decode(nvl(service_number, '00000'),
                    '00000',
                    '00000',
                    atg_service,
                    atg_service,
                    service_in) AS service_number,
             autoincl_prtc,
             substr(sf_transformprtc(incl_prtc_1, 'COMBINED'), 1, 10) incl_prtc_1,
             substr(sf_transformprtc(incl_prtc_2, 'COMBINED'), 1, 10) incl_prtc_2,
             substr(sf_transformprtc(incl_prtc_3, 'COMBINED'), 1, 10) incl_prtc_3,
             substr(sf_transformprtc(incl_prtc_4, 'COMBINED'), 1, 10) incl_prtc_4,
             substr(sf_transformprtc(incl_prtc_5, 'COMBINED'), 1, 10) incl_prtc_5,
             combo_overlap_skey
              FROM combo_overlap_header
             WHERE (mfr_number IS NULL AND service_number IS NULL)
                OR (mfr_number = mfr1 AND service_number = service1)
                OR (mfr_number = mfr2 AND service_number = service2)
             ORDER BY autoincl_prtc DESC,
                      incl_prtc_1   DESC,
                      incl_prtc_2   DESC,
                      incl_prtc_3   DESC,
                      incl_prtc_4   DESC,
                      incl_prtc_5   DESC,
                      -- 05/08/2009 PAG - changed sort of mfr_number, service_number to include decode
                      --             mfr_number desc,
                      --             service_number desc;
                      decode(nvl(mfr_number, '000'),
                             '000',
                             '000',
                             atg_mfr,
                             atg_mfr,
                             mfr_in) DESC,
                      decode(nvl(service_number, '00000'),
                             '00000',
                             '00000',
                             atg_service,
                             atg_service,
                             service_in) DESC;
        -- 05/08/2009 PAG - changed sort of mfr_number, service_number to include decode

        /*
            cursor hdr_wip_cur is
            select nvl(mfr_number,'000') mfr_number, nvl(service_number,'00000') service_number,
            autoincl_prtc,
            substr(sf_transformprtc(incl_prtc_1, 'COMBINED'),1,10) incl_prtc_1,
            substr(sf_transformprtc(incl_prtc_2, 'COMBINED'),1,10) incl_prtc_2,
            substr(sf_transformprtc(incl_prtc_3, 'COMBINED'),1,10) incl_prtc_3,
            substr(sf_transformprtc(incl_prtc_4, 'COMBINED'),1,10) incl_prtc_4,
            substr(sf_transformprtc(incl_prtc_5, 'COMBINED'),1,10) incl_prtc_5,
            combo_overlap_skey
            from combo_overlap_header_wip
            where (mfr_number is null and service_number is null)
              or (mfr_number = mfr_in and service_number = service_in)
            order by autoincl_prtc desc, incl_prtc_1 desc, incl_prtc_2 desc, incl_prtc_3 desc, incl_prtc_4 desc, incl_prtc_5 desc, mfr_number desc, service_number desc;

            cursor hdr_cur is
            select nvl(mfr_number,'000') mfr_number, nvl(service_number,'00000') service_number,
            autoincl_prtc,
            substr(sf_transformprtc(incl_prtc_1, 'COMBINED'),1,10) incl_prtc_1,
            substr(sf_transformprtc(incl_prtc_2, 'COMBINED'),1,10) incl_prtc_2,
            substr(sf_transformprtc(incl_prtc_3, 'COMBINED'),1,10) incl_prtc_3,
            substr(sf_transformprtc(incl_prtc_4, 'COMBINED'),1,10) incl_prtc_4,
            substr(sf_transformprtc(incl_prtc_5, 'COMBINED'),1,10) incl_prtc_5,
            combo_overlap_skey
            from combo_overlap_header
            where (mfr_number is null and service_number is null)
              or (mfr_number = mfr_in and service_number = service_in)
            order by autoincl_prtc desc, incl_prtc_1 desc, incl_prtc_2 desc, incl_prtc_3 desc, incl_prtc_4 desc, incl_prtc_5 desc, mfr_number desc, service_number desc;
        */
        -- 2008/12/31 PAG - Service concatenation.

        -- 2008/12/31 PAG - Moved select associated to excpt_wip_cur into procedure SET_EXCPT_WIP_CURSOR
        -- so that selection criteria can be changed based on run_type.
        excpt_wip_cur excptwip_cur;
        excpt_wip_rec excptwip_rec;
        -- 2008/12/31 PAG - Moved select associated to excpt_wip_cur

        -- 2008/12/31 PAG - Moved select associated to excpt_cur into procedure SET_EXCPT_WIP_CURSOR
        -- so that selection criteria can be changed based on run_type.
        excpt_prd_cur excptprd_cur;
        excpt_prd_rec excptprd_rec;
        -- 2008/12/31 PAG - Moved select associated to excpt_cur

        CURSOR auto_wip_cur(skey_in NUMBER) IS
            SELECT /*+ create_overlap.auto_wip_cur */
             autoincl_prtc,
             substr(sf_transformprtc(incl_prtc_1, 'COMBINED'), 1, 10) incl_prtc_1,
             substr(sf_transformprtc(incl_prtc_2, 'COMBINED'), 1, 10) incl_prtc_2,
             substr(sf_transformprtc(incl_prtc_3, 'COMBINED'), 1, 10) incl_prtc_3,
             substr(sf_transformprtc(incl_prtc_4, 'COMBINED'), 1, 10) incl_prtc_4,
             substr(sf_transformprtc(incl_prtc_5, 'COMBINED'), 1, 10) incl_prtc_5
              FROM combo_overlap_detail_wip
             WHERE combo_overlap_skey = skey_in
             ORDER BY sequence_number DESC; -- may need to order by descending count of non-null values;

        CURSOR auto_cur(skey_in NUMBER) IS
            SELECT /*+ create_overlap.auto_cur */
             autoincl_prtc,
             substr(sf_transformprtc(incl_prtc_1, 'COMBINED'), 1, 10) incl_prtc_1,
             substr(sf_transformprtc(incl_prtc_2, 'COMBINED'), 1, 10) incl_prtc_2,
             substr(sf_transformprtc(incl_prtc_3, 'COMBINED'), 1, 10) incl_prtc_3,
             substr(sf_transformprtc(incl_prtc_4, 'COMBINED'), 1, 10) incl_prtc_4,
             substr(sf_transformprtc(incl_prtc_5, 'COMBINED'), 1, 10) incl_prtc_5
              FROM combo_overlap_detail
             WHERE combo_overlap_skey = skey_in
             ORDER BY sequence_number DESC; -- may need to order by descending count of non-null values;

        --06/04/2009 mm5095/pg2697 => correct ATG/CEG overlap issue
        CURSOR final_hdr_detail_cur IS
            SELECT /*+ final_hdr_detail_cur */
            DISTINCT partid,
                     overlap_type,
                     min_labor_time,
                     detail_partid,
                     labor_time
              FROM tmp_final_hdr_detail
             ORDER BY partid,
                      overlap_type;

        my_partid NUMBER;
        --06/04/2009 mm5095/pg2697 => correct ATG/CEG overlap issue

        skey      NUMBER;
        last_skey NUMBER := 0;

        bit1_0 NUMBER;
        bit1_1 NUMBER;
        bit2_0 NUMBER;
        bit2_1 NUMBER;
        bit3_0 NUMBER;
        bit3_1 NUMBER;
        bit4_0 NUMBER;
        bit4_1 NUMBER;
        bit5_0 NUMBER;
        bit5_1 NUMBER;
        bit6_0 NUMBER;
        bit6_1 NUMBER;

        autoincl_prtc VARCHAR2(10) := ' ';
        incl_prtc_1   VARCHAR2(10) := ' ';
        incl_prtc_2   VARCHAR2(10) := ' ';
        incl_prtc_3   VARCHAR2(10) := ' ';
        incl_prtc_4   VARCHAR2(10) := ' ';
        incl_prtc_5   VARCHAR2(10) := ' ';

        --    prtc_body_in varchar2(4);
        --    my_body_id number;
        --    my_body_count number := 99;

        overlap_skey NUMBER;
        my_count     NUMBER;
        --    smartprtc_count number := 0;
        my_prtc  VARCHAR2(10) := ' ';
        my_type  NUMBER := 0;
        bgeneric BOOLEAN;
        bmfr     BOOLEAN;
        bservice BOOLEAN;

        utl_header_fhandle utl_file.file_type;
        utl_detail_fhandle utl_file.file_type;
        utl_rcombo_fhandle utl_file.file_type;
        utl_ecombo_fhandle utl_file.file_type;
        utl_acombo_fhandle utl_file.file_type;

        detail_partid NUMBER;
        partid        NUMBER;
        --    vvc2_string varchar2(80);

    BEGIN

        DELETE /*+ create_overlap.tmp_um_dtl_prtc_list_delete */
        FROM tmp_um_dtl_prtc_list;
        DELETE /*+ create_overlap.tmp_um_hdr_dtl_delete */
        FROM tmp_um_hdr_dtl;
        DELETE /*+ create_overlap.tmp_um_header_delete */
        FROM tmp_um_header;
        DELETE /*+ create_overlap.tmp_um_overlap_detail_delete */
        FROM tmp_um_overlap_detail;
        DELETE /*+ create_overlap.tmp_um_overlap_header_delete */
        FROM tmp_um_overlap_header;
        --06/04/2009 mm5095/pg2697 => correct ATG/CEG overlap issue
        DELETE /*+ create_overlap.tmp_final_hdr_detail_delete */
        FROM tmp_final_hdr_detail;
        --06/04/2009 mm5095/pg2697 => correct ATG/CEG overlap issue

        -- if not an atg service, check for matching atg service
        IF mfr_in != '006'
        THEN
            pkg_ultramate_common.sp_getatgservice(mfr_in,
                                                  service_in,
                                                  atg_mfr,
                                                  atg_service,
                                                  run_type);
        END IF;

        -- for debugging purposes ----------------------------------------------------------
        --    DBMS_OUTPUT.put_line('create_overlap: ' || mfr_in || ' / '
        --                                            || service_in  || ' - '
        --                                            || atg_mfr || ' / '
        --                                            || atg_service || ' - '
        --                                            || run_type || ' - '
        --                                            || mfr1 || ' / '
        --                                            || service1 || ' - '
        --                                            || mfr2 || ' / '
        --                                            || service2  );

        /* -- File generation disabled: overlap OH/OD/R/E/A file fopen (FTP sunset)
            utl_header_fhandle := utl_file.fopen(path,
                                                 'OH' || service_barcode ||
                                                 '.txt',
                                                 'w');
            utl_detail_fhandle := utl_file.fopen(path,
                                                 'OD' || service_barcode ||
                                                 '.txt',
                                                 'w');
            utl_rcombo_fhandle := utl_file.fopen(path,
                                                 'R' || service_barcode ||
                                                 '.txt',
                                                 'w');
            utl_ecombo_fhandle := utl_file.fopen(path,
                                                 'E' || service_barcode ||
                                                 '.txt',
                                                 'w');
            utl_acombo_fhandle := utl_file.fopen(path,
                                                 'A' || service_barcode ||
                                                 '.txt',
                                                 'w');
        -- end commented block */

        -- 2008/12/31 PAG - Service concatenation.
        -- Note: CEG-related mfr/service numbers must be forced to mfr_in/service_in
        IF version_in = 'PR'
        THEN
            INSERT /*+ create_overlap.tmp_um_overlap_header_insert */
            INTO tmp_um_overlap_header
                SELECT decode(nvl(oh.mfr_number, '000'),
                              '000',
                              '000',
                              atg_mfr,
                              atg_mfr,
                              mfr_in) AS mfr_number,
                       decode(nvl(oh.service_number, '00000'),
                              '00000',
                              '00000',
                              atg_service,
                              atg_service,
                              service_in) AS service_number,
                       oh.overlap_type,
                       oh.overlap_skey,
                       substr(sf_transformprtc(oh.prtc, 'OVERLAP'), 1, 10) transformed_prtc,
                       oh.min_labor_time,
                       oh.table_id
                  FROM overlap_header oh
                 WHERE (((mfr_number = mfr1 AND service_number = service1) OR
                       (mfr_number = mfr1 AND service_number IS NULL) OR
                       (mfr_number = mfr2 AND service_number = service2) OR
                       (mfr_number = mfr2 AND service_number IS NULL) OR
                       (mfr_number IS NULL AND service_number IS NULL)) AND
                        oh.prtc NOT IN
                       (SELECT oh1.prtc
                          FROM overlap_header oh1, service_category_substitution scs
                          WHERE scs.mfr_number = mfr1
                            AND scs.service_number = service1
                            AND oh1.mfr_number = scs.substitute_mfr_number
                            AND oh1.service_number = scs.substitute_service_number
                            AND overlap_type != 'RR'))
                   AND overlap_type != 'RR'
            UNION
                SELECT decode(nvl(oh.mfr_number, '000'),
                              '000',
                              '000',
                              atg_mfr,
                              atg_mfr,
                              mfr_in) AS mfr_number,
                       decode(nvl(oh.service_number, '00000'),
                              '00000',
                              '00000',
                              atg_service,
                              atg_service,
                              service_in) AS service_number,
                       oh.overlap_type,
                       oh.overlap_skey,
                       substr(sf_transformprtc(oh.prtc, 'OVERLAP'), 1, 10) transformed_prtc,
                       oh.min_labor_time,
                       oh.table_id
                  FROM overlap_header oh, service_category_substitution scs
             WHERE scs.mfr_number = mfr1
               AND scs.service_number = service1
               AND oh.mfr_number = scs.substitute_mfr_number
               AND oh.service_number = scs.substitute_service_number
               AND overlap_type != 'RR';
        ELSE
            INSERT /*+ create_overlap.tmp_um_overlap_header_insert2 */
           INTO tmp_um_overlap_header
                SELECT decode(nvl(oh.mfr_number, '000'),
                              '000',
                              '000',
                              atg_mfr,
                              atg_mfr,
                              mfr_in) AS mfr_number,
                       decode(nvl(oh.service_number, '00000'),
                              '00000',
                              '00000',
                              atg_service,
                              atg_service,
                              service_in) AS service_number,
                       oh.overlap_type,
                       oh.overlap_skey,
                       substr(sf_transformprtc(oh.prtc, 'OVERLAP'), 1, 10) transformed_prtc,
                       oh.min_labor_time,
                       oh.table_id
                  FROM overlap_header_wip oh
                 WHERE (((oh.mfr_number = mfr1 AND oh.service_number = service1) OR
                       (oh.mfr_number = mfr1 AND oh.service_number IS NULL) OR
                       (oh.mfr_number = mfr2 AND oh.service_number = service2) OR
                       (oh.mfr_number = mfr2 AND oh.service_number IS NULL) OR
                       (oh.mfr_number IS NULL AND oh.service_number IS NULL)) AND
                        oh.prtc NOT IN
                       (SELECT oh1.prtc
                          FROM overlap_header_wip oh1, service_category_substitution scs
                          WHERE scs.mfr_number = mfr1
                            AND scs.service_number = service1
                            AND oh1.mfr_number = scs.substitute_mfr_number
                            AND oh1.service_number = scs.substitute_service_number
                            AND overlap_type != 'RR'))
                   AND overlap_type != 'RR'
            UNION
                SELECT decode(nvl(oh.mfr_number, '000'),
                              '000',
                              '000',
                              atg_mfr,
                              atg_mfr,
                              mfr_in) AS mfr_number,
                       decode(nvl(oh.service_number, '00000'),
                              '00000',
                              '00000',
                              atg_service,
                              atg_service,
                              service_in) AS service_number,
                       oh.overlap_type,
                       oh.overlap_skey,
                       substr(sf_transformprtc(oh.prtc, 'OVERLAP'), 1, 10) transformed_prtc,
                       oh.min_labor_time,
                       oh.table_id
                  FROM overlap_header_wip oh, service_category_substitution scs
             WHERE scs.mfr_number = mfr1
               AND scs.service_number = service1
               AND oh.mfr_number = scs.substitute_mfr_number
               AND oh.service_number = scs.substitute_service_number
               AND overlap_type != 'RR';
        END IF;
        /*
            if version_in = 'PR' then
              insert into tmp_um_overlap_header
              select nvl(mfr_number,'000') mfr_number,
                     nvl(service_number,'00000') service_number,
                     overlap_type, overlap_skey,
                     substr(sf_transformprtc(prtc,'OVERLAP'),1,10) transformed_prtc,
                     min_labor_time, table_id
              from overlap_header
              where ((mfr_number = mfr_in and service_number = service_in)
                or (mfr_number = mfr_in and service_number is null)
                or (mfr_number is null and service_number is null))
              and overlap_type != 'RR';
            else
              insert into tmp_um_overlap_header
              select nvl(mfr_number,'000') mfr_number,
                     nvl(service_number,'00000') service_number,
                     overlap_type, overlap_skey,
                     substr(sf_transformprtc(prtc,'OVERLAP'),1,10) transformed_prtc,
                     min_labor_time, table_id
              from overlap_header_wip
              where ((mfr_number = mfr_in and service_number = service_in)
                or (mfr_number = mfr_in and service_number is null)
                or (mfr_number is null and service_number is null))
              and overlap_type != 'RR';
            end if;
        */
        -- 2008/12/31 PAG - Service concatenation.

        -- get maximum overlap skey for added expanded RR overlap
        -- 07/17/02 mm5095 => subtle, nasty bug found by Editorial
        --    select max(overlap_skey) into overlap_skey
        --    from tmp_um_overlap_header;
        -- 07/17/02 mm5095 => subtle, nasty bug found by Editorial

        -- expand RR type overlap
        tbldetail := emptytbldetail;

        IF version_in = 'PR'
        THEN
            FOR r_rec IN rr_header_cur
            LOOP
                -- place overlap detail into table for performance
                OPEN rr_detail_cur(r_rec.overlap_skey);
                my_count := 0;
                FETCH rr_detail_cur
                    INTO rr_detail_rec;
                WHILE rr_detail_cur%FOUND
                LOOP
                    my_count := my_count + 1;
                    tbldetail(my_count).prtc := rr_detail_rec.prtc;
                    tbldetail(my_count).labor_time := rr_detail_rec.labor_time;
                    tbldetail(my_count).adjustment_sign := rr_detail_rec.adjustment_sign;
                    tbldetail(my_count).rr_sequence_number := rr_detail_rec.rr_sequence_number;
                    FETCH rr_detail_cur
                        INTO rr_detail_rec;
                END LOOP;
                CLOSE rr_detail_cur;

                -- insert header record into table
                -- 07/17/02 mm5095 => subtle, nasty bug found by Editorial
                --          overlap_skey := overlap_skey + 1;
                -- 07/17/02 mm5095 => subtle, nasty bug found by Editorial
                INSERT /*+ create_overlap.tmp_um_overlap_header_insert3 */
                INTO tmp_um_overlap_header
                    (mfr_number,
                     service_number,
                     overlap_type,
                     overlap_skey,
                     transformed_prtc,
                     min_labor_time,
                     table_id)
                VALUES
                    (r_rec.mfr_number,
                     r_rec.service_number,
                     'OB',
                     r_rec.overlap_skey,
                     r_rec.transformed_prtc,
                     r_rec.min_labor_time,
                     0);

                -- insert detail records for first header into table
                FOR j IN 1 .. my_count
                LOOP
                    IF tbldetail(j).prtc != '***QUIT***'
                    THEN
                        INSERT /*+ create_overlap.tmp_um_overlap_detail_insert3 */
                        INTO tmp_um_overlap_detail
                            (overlap_skey,
                             transformed_prtc,
                             labor_time,
                             adjustment_sign)
                        VALUES
                            (r_rec.overlap_skey,
                             substr(sf_transformprtc(tbldetail(j).prtc,
                                                     'OVERLAP'),
                                    1,
                                    10),
                             tbldetail(j).labor_time,
                             tbldetail(j).adjustment_sign);
                    END IF;
                END LOOP;

                FOR j IN 1 .. my_count - 1
                LOOP
                    IF tbldetail(j).prtc = '***QUIT***'
                    THEN
                        EXIT;
                    END IF;

                    -- insert new 'child' header record
                    -- 07/17/02 mm5095 => subtle, nasty bug found by Editorial
                    overlap_skey := race.sf_generate_skey('OVERLAP_SEQ');
                    --            overlap_skey := overlap_skey + 1;
                    -- 07/17/02 mm5095 => subtle, nasty bug found by Editorial
                    INSERT /*+ create_overlap.tmp_um_overlap_header_insert4 */
                    INTO tmp_um_overlap_header
                        (mfr_number,
                         service_number,
                         overlap_type,
                         overlap_skey,
                         transformed_prtc,
                         min_labor_time,
                         table_id)
                    VALUES
                        (r_rec.mfr_number,
                         r_rec.service_number,
                         'OB',
                         overlap_skey,
                         substr(sf_transformprtc(tbldetail(j).prtc,
                                                 'OVERLAP'),
                                1,
                                10),
                         r_rec.min_labor_time,
                         0);

                    -- insert detail records
                    FOR k IN j + 1 .. my_count
                    LOOP
                        IF tbldetail(k).prtc != '***QUIT***'
                        THEN
                            my_prtc := substr(sf_transformprtc(tbldetail(k).prtc,
                                                               'OVERLAP'),
                                              1,
                                              10);
                            INSERT /*+ create_overlap.tmp_um_overlap_detail_insert4 */
                            INTO tmp_um_overlap_detail
                                (overlap_skey,
                                 transformed_prtc,
                                 labor_time,
                                 adjustment_sign)
                            VALUES
                                (overlap_skey,
                                 my_prtc,
                                 tbldetail(k).labor_time,
                                 tbldetail(k).adjustment_sign);
                        END IF;
                    END LOOP;
                END LOOP;
            END LOOP;
        ELSE
            FOR r_rec IN rr_header_wip_cur
            LOOP
                -- place overlap detail into table for performance
                OPEN rr_detail_wip_cur(r_rec.overlap_skey);
                my_count := 0;
                FETCH rr_detail_wip_cur
                    INTO rr_detail_rec;
                WHILE rr_detail_wip_cur%FOUND
                LOOP
                    my_count := my_count + 1;
                    tbldetail(my_count).prtc := rr_detail_rec.prtc;
                    tbldetail(my_count).labor_time := rr_detail_rec.labor_time;
                    tbldetail(my_count).adjustment_sign := rr_detail_rec.adjustment_sign;
                    tbldetail(my_count).rr_sequence_number := rr_detail_rec.rr_sequence_number;
                    FETCH rr_detail_wip_cur
                        INTO rr_detail_rec;
                END LOOP;
                CLOSE rr_detail_wip_cur;

                -- insert header record into table
                -- 07/17/02 mm5095 => subtle, nasty bug found by Editorial
                --          overlap_skey := overlap_skey + 1;
                -- 07/17/02 mm5095 => subtle, nasty bug found by Editorial
                INSERT /*+ create_overlap.tmp_um_overlap_header_insert5 */
                INTO tmp_um_overlap_header
                    (mfr_number,
                     service_number,
                     overlap_type,
                     overlap_skey,
                     transformed_prtc,
                     min_labor_time,
                     table_id)
                VALUES
                    (r_rec.mfr_number,
                     r_rec.service_number,
                     'OB',
                     r_rec.overlap_skey,
                     r_rec.transformed_prtc,
                     r_rec.min_labor_time,
                     0);

                -- insert detail records for first header into table
                FOR j IN 1 .. my_count
                LOOP
                    IF tbldetail(j).prtc != '***QUIT***'
                    THEN
                        INSERT /*+ create_overlap.tmp_um_overlap_detail_insert5 */
                        INTO tmp_um_overlap_detail
                            (overlap_skey,
                             transformed_prtc,
                             labor_time,
                             adjustment_sign)
                        VALUES
                            (r_rec.overlap_skey,
                             substr(sf_transformprtc(tbldetail(j).prtc,
                                                     'OVERLAP'),
                                    1,
                                    10),
                             tbldetail(j).labor_time,
                             tbldetail(j).adjustment_sign);
                    END IF;
                END LOOP;

                FOR j IN 1 .. my_count - 1
                LOOP
                    IF tbldetail(j).prtc = '***QUIT***'
                    THEN
                        EXIT;
                    END IF;

                    -- insert new 'child' header record
                    -- 07/17/02 mm5095 => subtle, nasty bug found by Editorial
                    overlap_skey := race.sf_generate_skey('OVERLAP_SEQ');
                    --            overlap_skey := overlap_skey + 1;
                    -- 07/17/02 mm5095 => subtle, nasty bug found by Editorial
                    INSERT /*+ create_overlap.tmp_um_overlap_header_insert6 */
                    INTO tmp_um_overlap_header
                        (mfr_number,
                         service_number,
                         overlap_type,
                         overlap_skey,
                         transformed_prtc,
                         min_labor_time,
                         table_id)
                    VALUES
                        (r_rec.mfr_number,
                         r_rec.service_number,
                         'OB',
                         overlap_skey,
                         substr(sf_transformprtc(tbldetail(j).prtc,
                                                 'OVERLAP'),
                                1,
                                10),
                         r_rec.min_labor_time,
                         0);

                    -- insert detail records
                    FOR k IN j + 1 .. my_count
                    LOOP
                        IF tbldetail(k).prtc != '***QUIT***'
                        THEN
                            my_prtc := substr(sf_transformprtc(tbldetail(k).prtc,
                                                               'OVERLAP'),
                                              1,
                                              10);
                            INSERT /*+ create_overlap.tmp_um_overlap_detail_insert6 */
                            INTO tmp_um_overlap_detail
                                (overlap_skey,
                                 transformed_prtc,
                                 labor_time,
                                 adjustment_sign)
                            VALUES
                                (overlap_skey,
                                 my_prtc,
                                 tbldetail(k).labor_time,
                                 tbldetail(k).adjustment_sign);
                        END IF;
                    END LOOP;
                END LOOP;
            END LOOP;
        END IF;

        -- create list of overlap headers found in service
        -- 2008/12/31 PAG - Service concatenation.
        -- No need to use mfr1/service1 and mfr2/service2 for this query as
        -- mfr/service in tmp tables has already been decoded.
        IF run_type = 'FULL'
        THEN
            INSERT /*+ create_overlap.tmp_um_header_full_insert */
            INTO tmp_um_header
                SELECT DISTINCT b.mfr_number,
                                b.service_number,
                                overlap_type,
                                a.transformed_prtc overlap_prtc, -- note, this uses the matching detail prtc, not the header prtc
                                min_labor_time * 10 min_labor_time,
                                overlap_skey
                  FROM um_service_prtc       a,
                       tmp_um_overlap_header b
                 WHERE ((a.mfr_number = mfr_in AND
                       a.service_number = service_in))
                   AND a.transformed_prtc46 =
                       substr(b.transformed_prtc, 4, 6)
                   AND (substr(a.transformed_prtc, 1, 3) =
                       substr(b.transformed_prtc, 1, 3) OR
                       (substr(a.transformed_prtc, 3, 1) BETWEEN '0' AND '9' AND
                       ('*' || substr(a.transformed_prtc, 1, 2) =
                       substr(b.transformed_prtc, 1, 3))));
        ELSE
            --MINI
            INSERT /*+ create_overlap.tmp_um_header_mini_insert */
            INTO tmp_um_header
                SELECT DISTINCT b.mfr_number,
                                b.service_number,
                                b.overlap_type,
                                a.transformed_prtc overlap_prtc, -- note, this uses the matching detail prtc, not the header prtc
                                min_labor_time * 10 min_labor_time,
                                overlap_skey
                  FROM tmp_um_service_prtc   a,
                       tmp_um_overlap_header b
                 WHERE ((a.mfr_number = mfr_in AND
                       a.service_number = service_in))
                   AND a.transformed_prtc46 =
                       substr(b.transformed_prtc, 4, 6)
                   AND (substr(a.transformed_prtc, 1, 3) =
                       substr(b.transformed_prtc, 1, 3) OR
                       (substr(a.transformed_prtc, 3, 1) BETWEEN '0' AND '9' AND
                       ('*' || substr(a.transformed_prtc, 1, 2) =
                       substr(b.transformed_prtc, 1, 3))));

        END IF;

        --  create table of potential header/detail lists
        IF version_in = 'PR'
        THEN
            INSERT /*+ create_overlap.tmp_um_dtl_prtc_list_PR_insert */
            INTO tmp_um_dtl_prtc_list
                SELECT /*+ USE_NL(A,B) ORDERED */
                 mfr_number,
                 service_number,
                 substr(sf_transformprtc(b.prtc, 'OVERLAP'), 1, 10) detail_prtc,
                 labor_time,
                 adjustment_sign,
                 a.overlap_skey
                  FROM tmp_um_header  a,
                       overlap_detail b
                 WHERE b.overlap_skey = a.overlap_skey
                UNION
                SELECT mfr_number,
                       service_number,
                       transformed_prtc detail_prtc,
                       labor_time,
                       adjustment_sign,
                       a.overlap_skey
                  FROM tmp_um_header         a,
                       tmp_um_overlap_detail b
                 WHERE b.overlap_skey = a.overlap_skey;
        ELSE
            INSERT /*+ create_overlap.tmp_um_dtl_prtc_list_WP_insert */
            INTO tmp_um_dtl_prtc_list
                SELECT /*+ USE_NL(A,B) ORDERED */
                 mfr_number,
                 service_number,
                 substr(sf_transformprtc(b.prtc, 'OVERLAP'), 1, 10) detail_prtc,
                 labor_time,
                 adjustment_sign,
                 a.overlap_skey
                  FROM tmp_um_header      a,
                       overlap_detail_wip b
                 WHERE b.overlap_skey = a.overlap_skey
                UNION
                SELECT mfr_number,
                       service_number,
                       transformed_prtc detail_prtc,
                       labor_time,
                       adjustment_sign,
                       a.overlap_skey
                  FROM tmp_um_header         a,
                       tmp_um_overlap_detail b
                 WHERE b.overlap_skey = a.overlap_skey;
        END IF;

        -- 2008/12/31 PAG - Moved select associated to hdr_dtl_cur into procedure SET_HDR_DTL_CURSOR
        -- so that selection criteria can be changed based on run_type.
        set_hdr_dtl_cursor(hdr_dtl_cur,
                           run_type,
                           atg_mfr,
                           atg_service,
                           mfr_in,
                           service_in);
        LOOP
            FETCH hdr_dtl_cur
                INTO hdr_dtl_rec;
            EXIT WHEN hdr_dtl_cur%NOTFOUND;
            --    for rec in hdr_dtl_cur LOOP
            -- 2008/12/31 PAG - Moved select associated to hdr_dtl_cur into procedure
            INSERT /*+ create_overlap.tmp_um_hdr_dtl_insert */
            INTO tmp_um_hdr_dtl
            VALUES
                (hdr_dtl_rec.mfr_number,
                 hdr_dtl_rec.service_number,
                 hdr_dtl_rec.prtc,
                 hdr_dtl_rec.type,
                 hdr_dtl_rec.min_labor_time,
                 hdr_dtl_rec.transformed_prtc,
                 hdr_dtl_rec.labor_time);
        END LOOP;

        FOR rf_xxxx_rec IN rf_xxxx_cur
        LOOP
            INSERT /*+ create_overlap.tmp_um_hdr_dtl_insert2 */
            INTO tmp_um_hdr_dtl
            VALUES
                (rf_xxxx_rec.mfr_number,
                 rf_xxxx_rec.service_number,
                 rf_xxxx_rec.prtc,
                 rf_xxxx_rec.type,
                 0,
                 '***XXXX***',
                 0);
        END LOOP;

        -- output overlap flat files
        --06/04/2009 mm5095/pg2697 => correct ATG/CEG overlap issue
        --    my_count := 0;
        --06/04/2009 mm5095/pg2697 => correct ATG/CEG overlap issue
        --2009/05/08 PAG Added initialization of my_prtc and my_type to circumvent
        -- sporadic overlap time error encountered during testing
        my_prtc := ' ';
        my_type := 0;
        --2009/05/08 PAG Added initialization of my_prtc and my_type to circumvent
        -- sporadic overlap time error encountered during testing
        FOR rec IN header_detail_cur
        LOOP

            -- for debugging purposes ----------------------------------------------------------
            --      DBMS_OUTPUT.put_line('header_detail_cur loop: ' || rec.prtc || ' - '
            --                                            || rec.type  || ' - '
            --                                            || rec.min_labor_time  || ' - '
            --                                            || rec.mfr_number || ' / '
            --                                            || rec.service_number || ' - '
            --                                            || run_type );

            IF my_prtc != rec.prtc
               OR my_type != rec.type
            THEN
                my_prtc := rec.prtc;
                my_type := rec.type;
                --06/04/2009 mm5095/pg2697 => correct ATG/CEG overlap issue
                --       my_count := my_count + 1;
                --06/04/2009 mm5095/pg2697 => correct ATG/CEG overlap issue

                bgeneric := FALSE;
                bmfr     := FALSE;
                bservice := FALSE;

                IF rec.mfr_number = '000'
                THEN
                    bgeneric := TRUE;
                ELSIF rec.service_number = '00000'
                THEN
                    bmfr := TRUE;
                ELSE
                    bservice := TRUE;
                END IF;

                partid        := pkg_ultramate_common.sf_getsmartprtcid(rec.prtc,
                                                                        run_type);
                detail_partid := pkg_ultramate_common.sf_getsmartprtcid(rec.transformed_prtc,
                                                                        run_type);

                --06/04/2009 mm5095/pg2697 => correct ATG/CEG overlap issue
                INSERT /*+ create_overlap.tmp_final_hdr_detail */
                INTO tmp_final_hdr_detail
                    (partid,
                     overlap_type,
                     min_labor_time,
                     detail_partid,
                     labor_time)
                VALUES
                    (partid,
                     rec.type,
                     rec.min_labor_time,
                     detail_partid,
                     rec.labor_time);

                --        utl_file.put_line(utl_header_fhandle, partid || '|' || rec.type || '|' || rec.min_labor_time || '|' || my_count);
                --        utl_file.put_line(utl_detail_fhandle, my_count || '|' || detail_partid || '|' || rec.labor_time);
                --        if run_type = 'FULL' then
                --          -- 10/24/2007 mm5095 => insert into table to support FocusWrite rewrite
                --          update_um_oh(service_barcode, partid, rec.type, rec.min_labor_time, my_count);
                --          update_um_od(service_barcode, my_count, detail_partid, rec.labor_time);
                --          -- 10/24/2007 mm5095 => insert into table to support FocusWrite rewrite
                --        end if;
                --06/04/2009 mm5095/pg2697 => correct ATG/CEG overlap issue
            ELSE
                IF (bservice AND rec.service_number != '00000')
                   OR (bmfr AND rec.mfr_number != '000' AND
                   rec.service_number = '00000')
                   OR (bgeneric AND rec.mfr_number = '000')
                THEN

                    detail_partid := pkg_ultramate_common.sf_getsmartprtcid(rec.transformed_prtc,
                                                                            run_type);

                    --06/04/2009 mm5095/pg2697 => correct ATG/CEG overlap issue
                    INSERT /*+ create_overlap.tmp_final_hdr_detail */
                    INTO tmp_final_hdr_detail
                        (partid,
                         overlap_type,
                         min_labor_time,
                         detail_partid,
                         labor_time)
                    VALUES
                        (partid,
                         rec.type,
                         rec.min_labor_time,
                         detail_partid,
                         rec.labor_time);

                    --         utl_file.put_line(utl_detail_fhandle, my_count || '|' || detail_partid || '|' || rec.labor_time);
                    --         if run_type = 'FULL' then
                    --           -- 10/24/2007 mm5095 => insert into table to support FocusWrite rewrite
                    --           update_um_od(service_barcode, my_count, detail_partid, rec.labor_time);
                    --           -- 10/24/2007 mm5095 => insert into table to support FocusWrite rewrite
                    --         end if;
                    --06/04/2009 mm5095/pg2697 => correct ATG/CEG overlap issue
                END IF;
            END IF;
        END LOOP;

        --06/04/2009 mm5095/pg2697 => correct ATG/CEG overlap issue
        my_prtc := ' ';
        my_type := 0;
        FOR rec IN header_detail_006_cur
        LOOP

            -- for debugging purposes ----------------------------------------------------------
            --      DBMS_OUTPUT.put_line('header_detail_006_cur loop: ' || rec.prtc || ' - '
            --                                            || rec.type  || ' - '
            --                                            || rec.min_labor_time  || ' - '
            --                                            || rec.mfr_number || ' / '
            --                                            || rec.service_number || ' - '
            --                                            || run_type );

            IF my_prtc != rec.prtc
               OR my_type != rec.type
            THEN
                my_prtc := rec.prtc;
                my_type := rec.type;

                bgeneric := FALSE;
                bmfr     := FALSE;
                bservice := FALSE;

                IF rec.mfr_number = '000'
                THEN
                    bgeneric := TRUE;
                ELSIF rec.service_number = '00000'
                THEN
                    bmfr := TRUE;
                ELSE
                    bservice := TRUE;
                END IF;

                partid        := pkg_ultramate_common.sf_getsmartprtcid(rec.prtc,
                                                                        run_type);
                detail_partid := pkg_ultramate_common.sf_getsmartprtcid(rec.transformed_prtc,
                                                                        run_type);

                INSERT /*+ create_overlap.tmp_final_hdr_detail */
                INTO tmp_final_hdr_detail
                    (partid,
                     overlap_type,
                     min_labor_time,
                     detail_partid,
                     labor_time)
                VALUES
                    (partid,
                     rec.type,
                     rec.min_labor_time,
                     detail_partid,
                     rec.labor_time);

            ELSE
                IF (bservice AND rec.service_number != '00000')
                   OR (bmfr AND rec.mfr_number != '000' AND
                   rec.service_number = '00000')
                   OR (bgeneric AND rec.mfr_number = '000')
                THEN

                    detail_partid := pkg_ultramate_common.sf_getsmartprtcid(rec.transformed_prtc,
                                                                            run_type);

                    INSERT /*+ create_overlap.tmp_final_hdr_detail2 */
                    INTO tmp_final_hdr_detail
                        (partid,
                         overlap_type,
                         min_labor_time,
                         detail_partid,
                         labor_time)
                    VALUES
                        (partid,
                         rec.type,
                         rec.min_labor_time,
                         detail_partid,
                         rec.labor_time);

                END IF;
            END IF;
        END LOOP;

        my_count  := 0;
        my_type   := 0;
        my_partid := 0;
        FOR frec IN final_hdr_detail_cur
        LOOP
            IF my_partid != frec.partid
               OR my_type != frec.overlap_type
            THEN
                my_partid := frec.partid;
                my_type   := frec.overlap_type;
                my_count  := my_count + 1;
                /* -- File generation disabled: OH put_line (FTP sunset)
                    utl_file.put_line(utl_header_fhandle,
                                      frec.partid || '|' || frec.overlap_type || '|' ||
                                      frec.min_labor_time || '|' || my_count);
                -- end commented block */

                -- 04/05/2020 pb0690 => Remove full versus mini check and code. Adding MCE Mini functionality.
                -- 10/24/2007 mm5095 => insert into table to support FocusWrite rewrite
                update_um_oh(service_barcode,
                             frec.partid,
                             frec.overlap_type,
                             frec.min_labor_time,
                             my_count);
                -- 10/24/2007 mm5095 => insert into table to support FocusWrite rewrite

            END IF;
            /* -- File generation disabled: OD put_line (FTP sunset)
                utl_file.put_line(utl_detail_fhandle,
                                  my_count || '|' || frec.detail_partid || '|' ||
                                  frec.labor_time);
            -- end commented block */

            -- 04/05/2020 pb0690 => Remove full versus mini check and code. Adding MCE Mini functionality.
            -- 10/24/2007 mm5095 => insert into table to support FocusWrite rewrite--
            update_um_od(service_barcode,
                         my_count,
                         frec.detail_partid,
                         frec.labor_time);
            -- 10/24/2007 mm5095 => insert into table to support FocusWrite rewrite

        END LOOP;

        --06/04/2009 mm5095/pg2697 => correct ATG/CEG overlap issue

        -- process combined overlap
        IF mfr_in != '006'
           AND version_in = 'PR'
        THEN
            FOR h_rec IN hdr_cur
            LOOP
                -- note: this logic will skip generics if they exactly match service specific required prtcs
                IF autoincl_prtc != h_rec.autoincl_prtc
                   OR incl_prtc_1 != h_rec.incl_prtc_1
                   OR incl_prtc_2 != h_rec.incl_prtc_2
                   OR incl_prtc_3 != nvl(h_rec.incl_prtc_3, ' ')
                   OR incl_prtc_4 != nvl(h_rec.incl_prtc_4, ' ')
                   OR incl_prtc_5 != nvl(h_rec.incl_prtc_5, ' ')
                THEN

                    autoincl_prtc := h_rec.autoincl_prtc;
                    incl_prtc_1   := h_rec.incl_prtc_1;
                    incl_prtc_2   := h_rec.incl_prtc_2;
                    incl_prtc_3   := nvl(h_rec.incl_prtc_3, ' ');
                    incl_prtc_4   := nvl(h_rec.incl_prtc_4, ' ');
                    incl_prtc_5   := nvl(h_rec.incl_prtc_5, ' ');

                    skey := h_rec.combo_overlap_skey;

                    pkg_ultramate_common.sp_getsmartprtcbits(h_rec.autoincl_prtc,
                                                             bit1_0,
                                                             bit1_1,
                                                             run_type);
                    pkg_ultramate_common.sp_getsmartprtcbits(h_rec.incl_prtc_1,
                                                             bit2_0,
                                                             bit2_1,
                                                             run_type);
                    pkg_ultramate_common.sp_getsmartprtcbits(h_rec.incl_prtc_2,
                                                             bit3_0,
                                                             bit3_1,
                                                             run_type);
                    pkg_ultramate_common.sp_getsmartprtcbits(h_rec.incl_prtc_3,
                                                             bit4_0,
                                                             bit4_1,
                                                             run_type);
                    pkg_ultramate_common.sp_getsmartprtcbits(h_rec.incl_prtc_4,
                                                             bit5_0,
                                                             bit5_1,
                                                             run_type);
                    pkg_ultramate_common.sp_getsmartprtcbits(h_rec.incl_prtc_5,
                                                             bit6_0,
                                                             bit6_1,
                                                             run_type);

                    /* -- File generation disabled: R put_line (FTP sunset)
                        utl_file.put_line(utl_rcombo_fhandle,
                                          skey || '|' || bit1_0 || '|' ||
                                          bit1_1 || '|' || bit2_0 || '|' ||
                                          bit2_1 || '|' || bit3_0 || '|' ||
                                          bit3_1 || '|' || bit4_0 || '|' ||
                                          bit4_1 || '|' || bit5_0 || '|' ||
                                          bit5_1 || '|' || bit6_0 || '|' ||
                                          bit6_1);
                    -- end commented block */

                    -- 04/05/2020 pb0690 => Remove full versus mini check and code. Adding MCE Mini functionality.
                    -- 01/13/2010 mm5095 => insert into table to support next gen
                    update_um_r(service_barcode,
                                skey,
                                bit1_0,
                                bit1_1,
                                bit2_0,
                                bit2_1,
                                bit3_0,
                                bit3_1,
                                bit4_0,
                                bit4_1,
                                bit5_0,
                                bit5_1,
                                bit6_0,
                                bit6_1);

                    -- 01/13/2010 mm5095 => insert into table to support next gen

                    IF last_skey != skey
                    THEN
                        -- output additional options, if found
                        FOR a_rec IN auto_cur(skey)
                        LOOP
                            pkg_ultramate_common.sp_getsmartprtcbits(a_rec.autoincl_prtc,
                                                                     bit1_0,
                                                                     bit1_1,
                                                                     run_type);
                            pkg_ultramate_common.sp_getsmartprtcbits(a_rec.incl_prtc_1,
                                                                     bit2_0,
                                                                     bit2_1,
                                                                     run_type);
                            pkg_ultramate_common.sp_getsmartprtcbits(a_rec.incl_prtc_2,
                                                                     bit3_0,
                                                                     bit3_1,
                                                                     run_type);
                            pkg_ultramate_common.sp_getsmartprtcbits(a_rec.incl_prtc_3,
                                                                     bit4_0,
                                                                     bit4_1,
                                                                     run_type);
                            pkg_ultramate_common.sp_getsmartprtcbits(a_rec.incl_prtc_4,
                                                                     bit5_0,
                                                                     bit5_1,
                                                                     run_type);
                            pkg_ultramate_common.sp_getsmartprtcbits(a_rec.incl_prtc_5,
                                                                     bit6_0,
                                                                     bit6_1,
                                                                     run_type);

                            /* -- File generation disabled: A put_line (FTP sunset)
                                utl_file.put_line(utl_acombo_fhandle,
                                                  skey || '|' || bit1_0 || '|' ||
                                                  bit1_1 || '|' || bit2_0 || '|' ||
                                                  bit2_1 || '|' || bit3_0 || '|' ||
                                                  bit3_1 || '|' || bit4_0 || '|' ||
                                                  bit4_1 || '|' || bit5_0 || '|' ||
                                                  bit5_1 || '|' || bit6_0 || '|' ||
                                                  bit6_1);
                            -- end commented block */

                            -- 01/13/2010 mm5095 => insert into table to support next gen

                            update_um_a(service_barcode,
                                        skey,
                                        bit1_0,
                                        bit1_1,
                                        bit2_0,
                                        bit2_1,
                                        bit3_0,
                                        bit3_1,
                                        bit4_0,
                                        bit4_1,
                                        bit5_0,
                                        bit5_1,
                                        bit6_0,
                                        bit6_1);

                        -- 01/13/2010 mm5095 => insert into table to support next gen
                        END LOOP;

                        -- 2008/12/31 PAG - Moved select associated to excpt_cur into procedure SET_EXCPT_CURSOR
                        -- so that selection criteria can be changed based on run_type.
                        set_excpt_prd_cursor(excpt_prd_cur,
                                             run_type,
                                             skey,
                                             mfr_in,
                                             service_in);
                        LOOP
                            FETCH excpt_prd_cur
                                INTO excpt_prd_rec;
                            EXIT WHEN excpt_prd_cur%NOTFOUND;
                            --            for e_rec in excpt_cur(skey) LOOP
                            -- 2008/12/31 PAG - Moved select associated to excpt_wip_cur into procedure
                            pkg_ultramate_common.sp_getsmartprtcbits(excpt_prd_rec.transformed_prtc,
                                                                     bit1_0,
                                                                     bit1_1,
                                                                     run_type);

                            /* -- File generation disabled: E put_line (FTP sunset)
                                utl_file.put_line(utl_ecombo_fhandle,
                                                  skey || '|' || bit1_0 || '|' ||
                                                  bit1_1);
                            -- end commented block */

                            -- 01/13/2010 mm5095 => insert into table to support next gen

                            update_um_e(service_barcode,
                                        skey,
                                        bit1_0,
                                        bit1_1);

                            -- 01/13/2010 mm5095 => insert into table to support next gen
                        END LOOP;
                    END IF;

                    last_skey := skey;
                END IF;
            END LOOP;
        ELSIF mfr_in != '006'
        THEN
            FOR h_rec IN hdr_wip_cur
            LOOP
                -- note: this logic will skip generics if they exactly match service specific required prtcs
                IF autoincl_prtc != h_rec.autoincl_prtc
                   OR incl_prtc_1 != h_rec.incl_prtc_1
                   OR incl_prtc_2 != h_rec.incl_prtc_2
                   OR incl_prtc_3 != nvl(h_rec.incl_prtc_3, ' ')
                   OR incl_prtc_4 != nvl(h_rec.incl_prtc_4, ' ')
                   OR incl_prtc_5 != nvl(h_rec.incl_prtc_5, ' ')
                THEN

                    autoincl_prtc := h_rec.autoincl_prtc;
                    incl_prtc_1   := h_rec.incl_prtc_1;
                    incl_prtc_2   := h_rec.incl_prtc_2;
                    incl_prtc_3   := nvl(h_rec.incl_prtc_3, ' ');
                    incl_prtc_4   := nvl(h_rec.incl_prtc_4, ' ');
                    incl_prtc_5   := nvl(h_rec.incl_prtc_5, ' ');

                    skey := h_rec.combo_overlap_skey;

                    pkg_ultramate_common.sp_getsmartprtcbits(h_rec.autoincl_prtc,
                                                             bit1_0,
                                                             bit1_1,
                                                             run_type);
                    pkg_ultramate_common.sp_getsmartprtcbits(h_rec.incl_prtc_1,
                                                             bit2_0,
                                                             bit2_1,
                                                             run_type);
                    pkg_ultramate_common.sp_getsmartprtcbits(h_rec.incl_prtc_2,
                                                             bit3_0,
                                                             bit3_1,
                                                             run_type);
                    pkg_ultramate_common.sp_getsmartprtcbits(h_rec.incl_prtc_3,
                                                             bit4_0,
                                                             bit4_1,
                                                             run_type);
                    pkg_ultramate_common.sp_getsmartprtcbits(h_rec.incl_prtc_4,
                                                             bit5_0,
                                                             bit5_1,
                                                             run_type);
                    pkg_ultramate_common.sp_getsmartprtcbits(h_rec.incl_prtc_5,
                                                             bit6_0,
                                                             bit6_1,
                                                             run_type);

                    /* -- File generation disabled: R put_line (FTP sunset)
                        utl_file.put_line(utl_rcombo_fhandle,
                                          skey || '|' || bit1_0 || '|' ||
                                          bit1_1 || '|' || bit2_0 || '|' ||
                                          bit2_1 || '|' || bit3_0 || '|' ||
                                          bit3_1 || '|' || bit4_0 || '|' ||
                                          bit4_1 || '|' || bit5_0 || '|' ||
                                          bit5_1 || '|' || bit6_0 || '|' ||
                                          bit6_1);
                    -- end commented block */

                    update_um_r(service_barcode,
                                skey,
                                bit1_0,
                                bit1_1,
                                bit2_0,
                                bit2_1,
                                bit3_0,
                                bit3_1,
                                bit4_0,
                                bit4_1,
                                bit5_0,
                                bit5_1,
                                bit6_0,
                                bit6_1);

                    IF last_skey != skey
                    THEN
                        -- output additional options, if found
                        FOR a_rec IN auto_wip_cur(skey)
                        LOOP
                            pkg_ultramate_common.sp_getsmartprtcbits(a_rec.autoincl_prtc,
                                                                     bit1_0,
                                                                     bit1_1,
                                                                     run_type);
                            pkg_ultramate_common.sp_getsmartprtcbits(a_rec.incl_prtc_1,
                                                                     bit2_0,
                                                                     bit2_1,
                                                                     run_type);
                            pkg_ultramate_common.sp_getsmartprtcbits(a_rec.incl_prtc_2,
                                                                     bit3_0,
                                                                     bit3_1,
                                                                     run_type);
                            pkg_ultramate_common.sp_getsmartprtcbits(a_rec.incl_prtc_3,
                                                                     bit4_0,
                                                                     bit4_1,
                                                                     run_type);
                            pkg_ultramate_common.sp_getsmartprtcbits(a_rec.incl_prtc_4,
                                                                     bit5_0,
                                                                     bit5_1,
                                                                     run_type);
                            pkg_ultramate_common.sp_getsmartprtcbits(a_rec.incl_prtc_5,
                                                                     bit6_0,
                                                                     bit6_1,
                                                                     run_type);

                            /* -- File generation disabled: A put_line (FTP sunset)
                                utl_file.put_line(utl_acombo_fhandle,
                                                  skey || '|' || bit1_0 || '|' ||
                                                  bit1_1 || '|' || bit2_0 || '|' ||
                                                  bit2_1 || '|' || bit3_0 || '|' ||
                                                  bit3_1 || '|' || bit4_0 || '|' ||
                                                  bit4_1 || '|' || bit5_0 || '|' ||
                                                  bit5_1 || '|' || bit6_0 || '|' ||
                                                  bit6_1);
                            -- end commented block */

                            update_um_a(service_barcode,
                                        skey,
                                        bit1_0,
                                        bit1_1,
                                        bit2_0,
                                        bit2_1,
                                        bit3_0,
                                        bit3_1,
                                        bit4_0,
                                        bit4_1,
                                        bit5_0,
                                        bit5_1,
                                        bit6_0,
                                        bit6_1);

                        END LOOP;

                        -- 2008/12/31 PAG - Moved select associated to excpt_wip_cur into procedure SET_EXCPT_WIP_CURSOR
                        -- so that selection criteria can be changed based on run_type.
                        set_excpt_wip_cursor(excpt_wip_cur,
                                             run_type,
                                             skey,
                                             mfr_in,
                                             service_in);
                        LOOP
                            FETCH excpt_wip_cur
                                INTO excpt_wip_rec;
                            EXIT WHEN excpt_wip_cur%NOTFOUND;
                            --            for e_rec in excpt_wip_cur(skey) LOOP
                            -- 2008/12/31 PAG - Moved select associated to excpt_wip_cur into procedure
                            pkg_ultramate_common.sp_getsmartprtcbits(excpt_wip_rec.transformed_prtc,
                                                                     bit1_0,
                                                                     bit1_1,
                                                                     run_type);

                            /* -- File generation disabled: E put_line (FTP sunset)
                                utl_file.put_line(utl_ecombo_fhandle,
                                                  skey || '|' || bit1_0 || '|' ||
                                                  bit1_1);
                            -- end commented block */

                            update_um_e(service_barcode,
                                        skey,
                                        bit1_0,
                                        bit1_1);

                        END LOOP;
                    END IF;

                    last_skey := skey;
                END IF;
            END LOOP;
        END IF;

        -- close flat files, if open
        /* -- File generation disabled: overlap OH/OD/R/E/A fclose and semaphore (FTP sunset)
            IF utl_file.is_open(utl_header_fhandle)
            THEN
                utl_file.fclose(utl_header_fhandle);
                utl_file.fclose(utl_detail_fhandle);
                utl_file.fclose(utl_rcombo_fhandle);
                utl_file.fclose(utl_ecombo_fhandle);
                utl_file.fclose(utl_acombo_fhandle);

                -- update service semaphore
                pkg_ultramate_common.sp_output_barcode_semaphore(path,
                                                                 service_barcode,
                                                                 'OH' ||
                                                                 service_barcode ||
                                                                 '.txt',
                                                                 'a');
                pkg_ultramate_common.sp_output_barcode_semaphore(path,
                                                                 service_barcode,
                                                                 'OD' ||
                                                                 service_barcode ||
                                                                 '.txt',
                                                                 'a');
                pkg_ultramate_common.sp_output_barcode_semaphore(path,
                                                                 service_barcode,
                                                                 'R' ||
                                                                 service_barcode ||
                                                                 '.txt',
                                                                 'a');
                pkg_ultramate_common.sp_output_barcode_semaphore(path,
                                                                 service_barcode,
                                                                 'E' ||
                                                                 service_barcode ||
                                                                 '.txt',
                                                                 'a');
                pkg_ultramate_common.sp_output_barcode_semaphore(path,
                                                                 service_barcode,
                                                                 'A' ||
                                                                 service_barcode ||
                                                                 '.txt',
                                                                 'a');
            END IF;
        -- end commented block */

    END create_overlap;

    /************************************************************************/
    /* Program Name: extract color graphic services list                    */
    /* Author:       MM5095                                                 */
    /* Last Modified: 03/14/2011                                            */
    /* Description: Creates color_services.txt file                         */
    /************************************************************************/
    PROCEDURE extract_color_services(path VARCHAR2) IS
        CURSOR color_cur IS
            SELECT /*+ EXTRACT_COLOR_SERVICES.color_cur */
             barcode
              FROM um_service_location
             WHERE color_graphic_flag = 'Y';

        out_fhandle utl_file.file_type;

    BEGIN

        out_fhandle := utl_file.fopen(path, 'color_services.txt', 'w');

        FOR rec IN color_cur
        LOOP
            utl_file.put_line(out_fhandle, rec.barcode);
        END LOOP;

        -- update semaphore file
        sp_update_globaltxt_semaphore(path,
                                      'global.txt',
                                      'a',
                                      'color_services.txt');

        -- close files, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

    EXCEPTION
        WHEN utl_file.invalid_path THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20100, 'INVALID PATH');
        WHEN utl_file.invalid_mode THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20101, 'INVALID MODE');
        WHEN utl_file.invalid_operation THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20102, 'INVALID OPERATION');
        WHEN utl_file.invalid_filehandle THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20103, 'INVALID FILEHANDLE');
        WHEN utl_file.write_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20104, 'WRITE ERROR');
        WHEN utl_file.read_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20105, 'READ ERROR');
        WHEN utl_file.internal_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20106, 'INTERNAL ERROR');
            --  WHEN OTHERS THEN
        --    UTL_FILE.FCLOSE(OUT_FHANDLE);
        --    RAISE_APPLICATION_ERROR(-20107,'UNKNOWN ERROR');
    END extract_color_services;

    PROCEDURE extract_side_body(path VARCHAR2) IS
        CURSOR side_body_cur IS
            SELECT /*+ SIDE_BODY.side_body_cur */
             prtc_body
              FROM side_body_prtc_body;

        out_fhandle utl_file.file_type;

    BEGIN

        out_fhandle := utl_file.fopen(path, 'side_body_prtc.txt', 'w');

        FOR rec IN side_body_cur
        LOOP
            utl_file.put_line(out_fhandle, rec.prtc_body);
        END LOOP;

        -- update semaphore file
        sp_update_globaltxt_semaphore(path,
                                      'global.txt',
                                      'a',
                                      'side_body_prtc.txt');

        -- close files, if open
        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

    EXCEPTION
        WHEN utl_file.invalid_path THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20100, 'INVALID PATH');
        WHEN utl_file.invalid_mode THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20101, 'INVALID MODE');
        WHEN utl_file.invalid_operation THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20102, 'INVALID OPERATION');
        WHEN utl_file.invalid_filehandle THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20103, 'INVALID FILEHANDLE');
        WHEN utl_file.write_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20104, 'WRITE ERROR');
        WHEN utl_file.read_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20105, 'READ ERROR');
        WHEN utl_file.internal_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20106, 'INTERNAL ERROR');
            --  WHEN OTHERS THEN
        --    UTL_FILE.FCLOSE(OUT_FHANDLE);
        --    RAISE_APPLICATION_ERROR(-20107,'UNKNOWN ERROR');
    END extract_side_body;

    /************************************************************************/
    /* Author:       MM5095                                                 */
    /* Last Modified: 10/31/2012                                            */
    /* Description: Creates and extracts MAPP Supplier Xref data            */
    /************************************************************************/
    PROCEDURE sp_update_mapp_supplier_xref(path VARCHAR2 DEFAULT NULL) IS
        -- Default added to parameter to support nextgen MAPP Extract
        CURSOR single_cur IS
            SELECT datafile_skey,
                   a.altpart_supplier_number
              FROM altpart_supplier_datafile a
             INNER JOIN altpart_supplier b
                ON b.altpart_supplier_number = a.altpart_supplier_number
               AND b.delete_date IS NULL
             WHERE a.altpart_supplier_number NOT IN
                   (SELECT altpart_supplier_number
                      FROM (SELECT altpart_supplier_number,
                                   COUNT(*)
                              FROM altpart_supplier_datafile
                             GROUP BY altpart_supplier_number
                            HAVING COUNT(*) > 1))
             ORDER BY 1,
                      2;

        CURSOR multiple_cur IS
            SELECT altpart_supplier_number
              FROM (SELECT a.altpart_supplier_number,
                           COUNT(*)
                      FROM altpart_supplier_datafile a
                     INNER JOIN altpart_supplier b
                        ON b.altpart_supplier_number =
                           a.altpart_supplier_number
                       AND b.delete_date IS NULL
                     GROUP BY a.altpart_supplier_number
                    HAVING COUNT(*) > 1);

        CURSOR output_cur IS
            SELECT a.altpart_supplier_number,
                   altpart_supplier_number_xref
              FROM mapp_supplier_xref a
             INNER JOIN altpart_supplier b
                ON b.altpart_supplier_number = a.altpart_supplier_number
               AND b.delete_date IS NULL
             WHERE a.altpart_supplier_number !=
                   altpart_supplier_number_xref;
        datafile_skey           INTEGER := 0;
        altpart_supplier_number VARCHAR2(4) := '    ';

        out_fhandle utl_file.file_type;

    BEGIN
        DELETE FROM mapp_supplier_xref;

        FOR rec IN single_cur
        LOOP
            IF datafile_skey != rec.datafile_skey
            THEN
                altpart_supplier_number := rec.altpart_supplier_number;
                datafile_skey           := rec.datafile_skey;
            END IF;

            INSERT INTO mapp_supplier_xref
            VALUES
                (rec.altpart_supplier_number,
                 altpart_supplier_number,
                 USER,
                 SYSDATE);
        END LOOP;

        FOR rec IN multiple_cur
        LOOP
            INSERT INTO mapp_supplier_xref
            VALUES
                (rec.altpart_supplier_number,
                 rec.altpart_supplier_number,
                 USER,
                 SYSDATE);
        END LOOP;

        COMMIT;

        IF (path IS NOT NULL) ---- Check added to support nextgen MAPP Extract
        THEN

            out_fhandle := utl_file.fopen(path, 'SupplierXref.txt', 'w');

            FOR rec IN output_cur
            LOOP
                utl_file.put_line(out_fhandle,
                                  rec.altpart_supplier_number || '|' ||
                                  rec.altpart_supplier_number_xref);
            END LOOP;

            utl_file.fclose(out_fhandle);

            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'w',
                                          'SupplierXref.txt');
        END IF;

    EXCEPTION
        WHEN utl_file.invalid_path THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20100, 'INVALID PATH');
        WHEN utl_file.invalid_mode THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20101, 'INVALID MODE');
        WHEN utl_file.invalid_operation THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20102, 'INVALID OPERATION');
        WHEN utl_file.invalid_filehandle THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20103, 'INVALID FILEHANDLE');
        WHEN utl_file.write_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20104, 'WRITE ERROR');
        WHEN utl_file.read_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20105, 'READ ERROR');
        WHEN utl_file.internal_error THEN
            utl_file.fclose(out_fhandle);
            raise_application_error(-20106, 'INTERNAL ERROR');
        WHEN OTHERS THEN
            dbms_output.put_line('Error creating/updating mapp_supplier_xref table');
    END;

    /********************************************************************/
    /* Author:       MM5095?                                             */
    /* Last Modified: 05/20/2014                                         */
    /* Description: Extracts price data                                  */
    /* Executed by procedure price_extract (below) for UM FULL Extract   */
    /*********************************************************************/
    PROCEDURE extract
    (
        path       VARCHAR2,
        country_in VARCHAR2
    ) IS

        CURSOR price_cur(country_in VARCHAR2) IS
            SELECT a.barcode service,
                   b.barcode,
                   CASE
                       WHEN substr(b.prtc, 10, 1) = 'A' THEN
                        'ORDER FROM DEALER'
                       WHEN d.part_supplier_number = '000'
                            AND substr(d.part_number, 1, 2) = 'C '
                            AND substr(d.part_number, 3, 1) IN ('D', 'F') THEN
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
              FROM um_extract a
             INNER JOIN service_category_detail b
                ON b.mfr_number = a.mfr_number
               AND b.service_number = a.service_number
               AND b.delete_flag_date IS NULL
               AND b.barcode IS NOT NULL
               AND b.version_type = a.version_type
             INNER JOIN detail_part_xref c
                ON c.unique_row_id = b.unique_row_id
               AND c.version_type = b.version_type
             INNER JOIN part d
                ON d.part_skey = c.part_skey
               AND d.part_supplier_country_abbr = country_in
               AND d.current_effective_date IS NOT NULL
             WHERE a.version_type = 'PR';

        bfirsttime  BOOLEAN := TRUE;
        out_fhandle utl_file.file_type;
    BEGIN
        IF country_in = 'US'
           OR country_in = 'CA'
        THEN
            FOR rec IN price_cur(country_in)
            LOOP
                IF (bfirsttime)
                THEN
                    bfirsttime  := FALSE;
                    out_fhandle := utl_file.fopen(path,
                                                  'price_' ||
                                                  lower(country_in) ||
                                                  '.txt',
                                                  'w');
                END IF;

                utl_file.put_line(out_fhandle,
                                  rec.service || ',' || rec.barcode || ',' || '"' ||
                                  rec.part_number || '"' || ',' ||
                                  rec.price1 || ',' || rec.curr_date || ',' ||
                                  rec.price2 || ',' || rec.prev_date || ',' ||
                                  rec.disc_flag || ',' || rec.reman_flag);
            END LOOP;

            IF utl_file.is_open(out_fhandle)
            THEN
                utl_file.fclose(out_fhandle);
            END IF;
        ELSE
            dbms_output.put_line('Unknown country abbr: ' || country_in);
            dbms_output.put_line('Usage: ext_price [CA|US]');
        END IF;
    END;

    /********************************************************************/
    /* Author:       MM5095                                             */
    /* Last Modified: 05/20/2014                                        */
    /* Description: Extracts price data (UM 7.1)                        */
    /* Executed by xex018.ksh UM FULL Extract                           */
    /********************************************************************/
    PROCEDURE price_extract
    (
        unix_full_dir    VARCHAR2,
        ftp_machine_name VARCHAR2,
        ftp_dest_path    VARCHAR2
    ) IS

        --        out_fhandle  utl_file.file_type;
        edsys_path   VARCHAR2(100);
        ftp_ret_code BINARY_INTEGER := 0;
        ftp_on_flag  BOOLEAN := TRUE;

    BEGIN
        edsys_path := sf_getdirectorypath(unix_full_dir);
        extract(unix_full_dir, 'US');
        pkg_ultramate_common.sp_update_globaltxt_semaphore(unix_full_dir,
                                                           'price.txt',
                                                           'w',
                                                           'price_us.txt');
        extract(unix_full_dir, 'CA');
        pkg_ultramate_common.sp_update_globaltxt_semaphore(unix_full_dir,
                                                           'price.txt',
                                                           'a',
                                                           'price_ca.txt');

        sp_ftp_command('price.txt',
                       edsys_path,
                       ftp_dest_path,
                       ftp_machine_name,
                       ftp_on_flag,
                       ftp_ret_code);
    END;

    /********************************************************************/
    /* Author:       MM5095                                             */
    /* Last Modified: 05/20/2014                                        */
    /* Description: Extracts mapp data for incremental (Um 7.1)         */
    /********************************************************************/
    PROCEDURE mapp_extract
    (
        unix_full_dir    VARCHAR2,
        ftp_machine_name VARCHAR2,
        ftp_dest_path    VARCHAR2
    ) IS

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
             WHERE a.altpart_supplier_number IN
                   (SELECT altpart_supplier_number_xref
                      FROM ext.mapp_supplier_xref)
             ORDER BY altpart_supplier_number,
                      service,
                      barcode,
                      reconditioned_flag,
                      extract_cert_flag,
                      oem_discount_flag,
                      price;

        lastsupplier          mapp_part_current.altpart_supplier_number%TYPE := NULL;
        lastservice           mapp_part_current.service%TYPE := '999999';
        lastbarcode           mapp_part_current.barcode%TYPE := '999999';
        lastcertflag          mapp_part_current.extract_cert_flag%TYPE := ' ';
        lastreconditionedflag mapp_part_current.reconditioned_flag%TYPE := ' ';
        lastdiscountflag      mapp_part_current.oem_discount_flag%TYPE := ' ';

        out_fhandle  utl_file.file_type;
        edsys_path   VARCHAR2(100);
        ftp_ret_code BINARY_INTEGER := 0;
        bfirsttime   BOOLEAN := TRUE;
        ftp_on_flag  BOOLEAN := TRUE;
        ncount       INTEGER := 0;

    BEGIN
        edsys_path := sf_getdirectorypath(unix_full_dir);

        FOR rec IN mapp_cur
        LOOP
            IF lastsupplier IS NULL
            THEN
                lastsupplier := rec.altpart_supplier_number;
                out_fhandle  := utl_file.fopen(unix_full_dir,
                                               lastsupplier || '.txt',
                                               'w');
                ncount       := ncount + 1;
            ELSIF lastsupplier != rec.altpart_supplier_number
            THEN
                IF utl_file.is_open(out_fhandle)
                THEN
                    utl_file.fclose(out_fhandle);

                    IF bfirsttime
                    THEN
                        pkg_ultramate_common.sp_update_globaltxt_semaphore(unix_full_dir,
                                                                           'mapp.txt',
                                                                           'w',
                                                                           lastsupplier ||
                                                                           '.txt');
                        bfirsttime := FALSE;
                    ELSE
                        pkg_ultramate_common.sp_update_globaltxt_semaphore(unix_full_dir,
                                                                           'mapp.txt',
                                                                           'a',
                                                                           lastsupplier ||
                                                                           '.txt');
                    END IF;
                END IF;

                lastsupplier := rec.altpart_supplier_number;
                out_fhandle  := utl_file.fopen(unix_full_dir,
                                               lastsupplier || '.txt',
                                               'w');
                ncount       := ncount + 1;
            END IF;

            IF (rec.service != lastservice OR rec.barcode != lastbarcode OR
               rec.extract_cert_flag != lastcertflag OR
               rec.reconditioned_flag != lastreconditionedflag OR
               rec.oem_discount_flag != lastdiscountflag)
            THEN
                utl_file.put_line(out_fhandle,
                                  rec.service || ',' || rec.barcode || ',' || '"' ||
                                  rec.altpart_supplier_number || '"' || ',' ||
                                  rec.reconditioned_flag || ',' ||
                                  rec.category_cd || ',' || rec.my_price || ',' ||
                                  rec.extract_cert_flag || ',' || '"' ||
                                  rec.altpart_number || '"' || ',' ||
                                  rec.oem_discount_flag);
            END IF;

            lastservice           := rec.service;
            lastbarcode           := rec.barcode;
            lastcertflag          := rec.extract_cert_flag;
            lastreconditionedflag := rec.reconditioned_flag;
            lastdiscountflag      := rec.oem_discount_flag;

        END LOOP;

        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
            pkg_ultramate_common.sp_update_globaltxt_semaphore(unix_full_dir,
                                                               'mapp.txt',
                                                               'a',
                                                               lastsupplier ||
                                                               '.txt');
        END IF;

        sp_ftp_command('mapp.txt',
                       edsys_path,
                       ftp_dest_path,
                       ftp_machine_name,
                       ftp_on_flag,
                       ftp_ret_code);
    END;

    /********************************************************************/
    /* Author:       MM5095                                             */
    /* Last Modified: 07/22/2014                                        */
    /* Description: Extracts cieca data                                 */
    /********************************************************************/
    PROCEDURE cieca_code_extract(path VARCHAR2) IS

        CURSOR main_cur IS
            SELECT a.cieca_code,
                   c.prtc
              FROM prtc_cieca_code_xref a
             INNER JOIN cieca_code b
                ON b.cieca_code = a.cieca_code
               AND b.parts_trader_flag = 'Y'
             INNER JOIN um_smartprtc c
                ON substr(c.prtc, 1, 7) = substr(a.prtc, 1, 7);

        out_fhandle utl_file.file_type;
        bfirsttime  BOOLEAN := TRUE;
    BEGIN
        FOR rec IN main_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'cieca_code_xref.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.cieca_code || '|' || rec.prtc);
        END LOOP;

        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'cieca_code_xref.txt');
        END IF;
    END;

    /********************************************************************/
    /* Author:       MM5095                                             */
    /* Last Modified: 05/05/2015                                        */
    /* Description: Extracts dynamic price                              */
    /********************************************************************/
    PROCEDURE dynamic_price_extract(path VARCHAR2) IS

        --JL: changed cursor select to use dynamic_price_um instead of specific mfr selection
        CURSOR main_cur IS
            SELECT DISTINCT a.barcode      servicebarcode,
                            a.from_year    minyear,
                            a.to_year      maxyear,
                            a.country_abbr countryabbr,
                            a.supplier     suppliername
              FROM dynamic_price_extract_vw a
             WHERE a.dynamic_price_um = 'Y'
               AND a.country_abbr != 'PR';

        out_fhandle utl_file.file_type;
        bfirsttime  BOOLEAN := TRUE;
    BEGIN
        FOR rec IN main_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'PriceSupplierXref.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            utl_file.put_line(out_fhandle,
                              rec.servicebarcode || '|' || rec.minyear || '|' ||
                              rec.maxyear || '|' || rec.countryabbr || '|' ||
                              rec.suppliername);
        END LOOP;

        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        -- update semaphore file
        IF bfirsttime = FALSE
        THEN
            sp_update_globaltxt_semaphore(path,
                                          'global.txt',
                                          'a',
                                          'PriceSupplierXref.txt');
        END IF;
    END;

    /*********************************************************************/
    /* Author:       MM5095                                          */
    /* Last Modified: 02/24/2016 create dictionary for each  language*/
    /* Description: Extracts dictionary                              */
    /*****************************************************************/
    PROCEDURE dictionary_extract(path VARCHAR2) IS

        CURSOR eng_cur IS
            SELECT line_text_skey,
                   mixed_case_line_text
              FROM um_english_text_nls;

        CURSOR fre_cur IS
            SELECT line_text_skey,
                   mixed_case_line_text
              FROM um_text_nls
             WHERE nls_country_abbr = 'CA'
               AND language_code = 'FRE'
            UNION
            SELECT line_text_skey,
                   mixed_case_line_text
              FROM um_english_text_nls
             WHERE line_text_skey IN
                   (SELECT line_text_skey
                      FROM um_english_text_nls
                    MINUS
                    SELECT line_text_skey
                      FROM um_text_nls
                     WHERE nls_country_abbr = 'CA'
                       AND language_code = 'FRE');

        out_fhandle     utl_file.file_type;
        bfirsttime      BOOLEAN := TRUE;
        wrap_text       VARCHAR2(2000);
        npos            NUMBER;
        nline           NUMBER;
        max_line_length NUMBER := 150;

    BEGIN

        FOR rec IN eng_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'dictionary_eng.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            -- 20160601 mm5095 => bug fix - remove carriage returns
            --            wrap_text := rec.mixed_case_line_text;
            wrap_text := translate(rec.mixed_case_line_text,
                                   'x' || chr(10) || chr(13),
                                   'x');
            -- 20160601 mm5095 => bug fix - remove carriage returns
            nline := 1;

            WHILE TRUE
            LOOP
                IF length(wrap_text) > max_line_length
                THEN
                    npos := instr(wrap_text,
                                  ' ',
                                  max_line_length - length(wrap_text),
                                  1);
                    IF npos > 0
                    THEN
                        utl_file.put_line(out_fhandle,
                                          rec.line_text_skey || '|' ||
                                          nline || '|' ||
                                          substr(wrap_text, 1, npos - 1));
                        wrap_text := substr(wrap_text, npos + 1);
                        nline     := nline + 1;
                    ELSE
                        utl_file.put_line(out_fhandle,
                                          rec.line_text_skey || '|' ||
                                          nline || '|' || wrap_text);
                        EXIT;
                    END IF;
                ELSE
                    utl_file.put_line(out_fhandle,
                                      rec.line_text_skey || '|' || nline || '|' ||
                                      wrap_text);
                    EXIT;
                END IF;
            END LOOP;
        END LOOP;

        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        bfirsttime := TRUE;
        FOR rec IN fre_cur
        LOOP
            IF bfirsttime
            THEN
                out_fhandle := utl_file.fopen(path,
                                              'dictionary_fre.txt',
                                              'w');
                bfirsttime  := FALSE;
            END IF;

            -- 20160601 mm5095 => bug fix - remove carriage returns
            --            wrap_text := rec.mixed_case_line_text;
            wrap_text := translate(rec.mixed_case_line_text,
                                   'x' || chr(10) || chr(13),
                                   'x');
            -- 20160601 mm5095 => bug fix - remove carriage returns
            nline := 1;

            WHILE TRUE
            LOOP
                IF length(wrap_text) > max_line_length
                THEN
                    npos := instr(wrap_text,
                                  ' ',
                                  max_line_length - length(wrap_text),
                                  1);
                    IF npos > 0
                    THEN
                        utl_file.put_line(out_fhandle,
                                          rec.line_text_skey || '|' ||
                                          nline || '|' ||
                                          substr(wrap_text, 1, npos - 1));
                        wrap_text := substr(wrap_text, npos + 1);
                        nline     := nline + 1;
                    ELSE
                        utl_file.put_line(out_fhandle,
                                          rec.line_text_skey || '|' ||
                                          nline || '|' || wrap_text);
                        EXIT;
                    END IF;
                ELSE
                    utl_file.put_line(out_fhandle,
                                      rec.line_text_skey || '|' || nline || '|' ||
                                      wrap_text);
                    EXIT;
                END IF;
            END LOOP;
        END LOOP;

        IF utl_file.is_open(out_fhandle)
        THEN
            utl_file.fclose(out_fhandle);
        END IF;

        sp_update_globaltxt_semaphore(path,
                                      'global.txt',
                                      'a',
                                      'dictionary_eng.txt');
        sp_update_globaltxt_semaphore(path,
                                      'global.txt',
                                      'a',
                                      'dictionary_fre.txt');

    END;

    /*********************************************************************/
    /* Author:       MM5095                                          */
    /* Last Modified: 02/09/2017 get french term for line_text_skey  */
    /* Description: Gets text for line_text_skey                     */
    /*****************************************************************/
    FUNCTION sf_getfrench
    (
        skey_in INTEGER,
        text_in VARCHAR2
    ) RETURN VARCHAR2 IS
        french_text um_text_nls.line_text%TYPE;
    BEGIN
        SELECT mixed_case_line_text
          INTO french_text
          FROM um_text_nls
         WHERE line_text_skey = skey_in
           AND nls_country_abbr = 'CA';
        RETURN french_text;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN text_in;
    END;

    /*****************************************************************/
    /* Author:       MM5095                                          */
    /* Last Modified: 03/10/2017                                     */
    /* Description: resets sequence number                           */
    /*****************************************************************/
    PROCEDURE reset_seq(p_seq_name IN VARCHAR2) IS
        l_val NUMBER;
    BEGIN
        EXECUTE IMMEDIATE 'select ' || p_seq_name || '.nextval from dual'
            INTO l_val;

        EXECUTE IMMEDIATE 'alter sequence ' || p_seq_name ||
                          ' increment by -' || l_val || ' minvalue 0';

        EXECUTE IMMEDIATE 'select ' || p_seq_name || '.nextval from dual'
            INTO l_val;

        EXECUTE IMMEDIATE 'alter sequence ' || p_seq_name ||
                          ' increment by 1 minvalue 0';
    END;

END; --END OF PROCEDURE PKG_ULTRAMATE_COMMON
/
