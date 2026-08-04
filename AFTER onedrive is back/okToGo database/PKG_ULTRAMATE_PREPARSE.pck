CREATE OR REPLACE Package EXT.PKG_ULTRAMATE_PREPARSE IS

PROCEDURE ULTRAMATE_PREPARSE(parm_path varchar2, run_type varchar2, parm_file varchar2, unix_full_dir varchar2,
unix_mini_dir varchar2, version varchar2, restart_flag char, ftp_machine_name varchar2 DEFAULT NULL, ftp_dest_path varchar2 DEFAULT NULL);

END;
/
CREATE OR REPLACE PACKAGE BODY EXT."PKG_ULTRAMATE_PREPARSE" IS
    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
    *  $Workfile:$
    *    $Author:$
    *  $Revision:$
    *   $Modtime:$
    *
    *   PL/SQL name:     PKG_ULTRAMATE_PREPARSE                                       *
    *   Author:          MM5095                                                       *
    *   Description:                                                                  *
    *   Modifications:                                                                *
    *   2012/08  mm5095- added code to support NSF certified MAPP parts               *
    * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

    -- ftp global variables
    ftp_on_flag BOOLEAN; -- controls whether data ftp'd to NT system. (see code after sf_getDirectoryPath for set of value)

    ftp_ret_code        BINARY_INTEGER := 0;
    my_ftp_dest_path    VARCHAR2(80);
    my_ftp_machine_name VARCHAR2(10);

    -- 04/05/02 mm5095 => jim service_location bug fix

    ---------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------
    --                                          MAIN PROCESSING BLOCK FOR ULTRAMATE_BUILD                              --
    ---------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------
    -- 01/25/2007 mm5095 => added Oracle directory support
    PROCEDURE ultramate_preparse
    (
        parm_path        VARCHAR2,
        run_type         VARCHAR2,
        parm_file        VARCHAR2,
        unix_full_dir    VARCHAR2,
        unix_mini_dir    VARCHAR2,
        version          VARCHAR2,
        restart_flag     CHAR,
        ftp_machine_name VARCHAR2,
        ftp_dest_path    VARCHAR2
    )
    --PROCEDURE ULTRAMATE_PREPARSE(parm_path varchar2, run_type varchar2, parm_file varchar2, edsys_path varchar2, version varchar2, restart_flag char,
        --ftp_machine_name varchar2, ftp_dest_path varchar2)
        -- 01/25/2007 mm5095 => added Oracle directory support
     IS
        my_edsys_path VARCHAR2(100);
        -- 01/25/2007 mm5095 => added Oracle directory support
        edsys_path VARCHAR2(100);
        -- 01/25/2007 mm5095 => added Oracle directory support
        full_flag  CHAR(1);
        n_services INTEGER;

        -- 10/24/2006 mm5095 => added support for extract_date
        extract_fhandle utl_file.file_type;
        -- 10/24/2006 mm5095 => added support for extract_date

    BEGIN
        dbms_output.enable(1000000);

        my_ftp_machine_name := ftp_machine_name;
        my_ftp_dest_path    := ftp_dest_path;

        IF run_type = 'FULL'
        THEN
            full_flag := 'T';
            -- 01/25/2007 mm5095 => added Oracle directory support
            my_edsys_path := unix_full_dir;
            --    edsys_path := unix_path || '/um_full';
            -- 01/25/2007 mm5095 => added Oracle directory support
        ELSE
            full_flag := 'F';
            -- 01/25/2007 mm5095 => added Oracle directory support
            my_edsys_path := unix_mini_dir;
            --    edsys_path := edsys_path || '/um_mini';
            -- 01/25/2007 mm5095 => added Oracle directory support
        END IF;

        -- 2008/12/31 pg2697 => edsys_path is used to determine ftp_on_flag value (based on whether this is running in prod versus mdev).
        -- 01/25/2007 mm5095 => added Oracle directory support
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
        -- 2008/12/31 pg2697 => edsys_path is used to determine ftp_on_flag value (based on whether this is running in prod versus mdev).

        -- 10/31/2012 mm5095 => added support for MAPP Supplier Xref
        pkg_ultramate_common.sp_update_mapp_supplier_xref(my_edsys_path);
        -- 10/31/2012 mm5095 => added support for MAPP Supplier Xref

        pkg_ultramate_common.extract_service_barcodes(parm_path,
                                                      parm_file,
                                                      version,
                                                      full_flag,
                                                      restart_flag);

        SELECT /*+ count_services */
         COUNT(*)
          INTO n_services
          FROM tmp_um_extract
         WHERE extract_date IS NULL;

        IF n_services > 0
        THEN
            -- 08/09/02 mm5095 => rebuild index for performance
            IF (version = 'PR' AND
               race.pkg_race_ddl.sf_rbld_note_grp_xref_idxs != 0)
               OR (version = 'WP' AND
               race.pkg_race_ddl.sf_rbld_note_grp_xref_wip_idxs != 0)
            THEN
                dbms_output.put_line('NOTE_GROUP_XREF rebuild index failed');
                raise_application_error(-20106,
                                        'NOTE_GROUP_XREF rebuild index failed');
            ELSE
                -- 08/09/02 mm5095 => rebuild index for performance

                --2008/12/31 - Chg'd to use common routine. Run_type is passed to control logic differences between FULL and MINI..
                pkg_ultramate_common.extract_service_group(my_edsys_path,
                                                           full_flag,
                                                           restart_flag,
                                                           run_type);
                -- 04/05/02 mm5095 => jim service_location bug fix
                --    EXTRACT_SERVICE_GROUP_SQL(my_edsys_path, full_flag, restart_flag);
                --    EXTRACT_SERVICE_GROUP_SQL(my_edsys_path);
                -- 04/05/02 mm5095 => jim service_location bug fix
                --2008/12/31 - Chg'd to use common routine. Run_type is passed to control logic differences between FULL and MINI..

                pkg_ultramate_common.build_user_refinish_complete;
                pkg_ultramate_common.extract_alternate_parts(my_edsys_path);
                pkg_ultramate_common.extract_disclaimer(my_edsys_path);
                -- 03/23/2016 mm5095
                pkg_ultramate_common.extract_disclosure(my_edsys_path);
                -- 03/23/2016 mm5095
                -- 06/19/02 mm5095 => create missing file
                pkg_ultramate_common.extract_mmcatg(my_edsys_path);
                -- 06/19/02 mm5095 => create missing file
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
                -- 10/07/02 mm5095 => correction to restart logic
                IF full_flag = 'T'
                THEN
                    --      if full_flag = 'T' and restart_flag = 'F' then
                    -- 10/07/02 mm5095 => correction to restart logic
                    -- 04/05/02 mm5095 => jim service_location bug fix
                    --      execute immediate 'truncate table um_extract';
                    -- 04/05/02 mm5095 => jim service_location bug fix
                    EXECUTE IMMEDIATE 'truncate table um_body';
                    EXECUTE IMMEDIATE 'truncate table um_service_prtc';
                    EXECUTE IMMEDIATE 'truncate table um_smartprtc';

                    -- 07/25/2007 mm5095 => to support part list initiative
                    IF restart_flag = 'T'
                    THEN
                        DELETE /*+ um_data_a_delete */
                        FROM um_data_a
                         WHERE service IN
                               (SELECT barcode
                                  FROM tmp_um_extract
                                 WHERE extract_date IS NULL);
                        DELETE /*+ um_data_e_delete */
                        FROM um_data_e
                         WHERE service IN
                               (SELECT barcode
                                  FROM tmp_um_extract
                                 WHERE extract_date IS NULL);
                        DELETE /*+ um_data_da_delete */
                        FROM um_data_da a
                         WHERE service IN
                               (SELECT barcode
                                  FROM tmp_um_extract
                                 WHERE extract_date IS NULL)
                            OR service = '000000';

                        DELETE /*+ um_data_db_delete */
                        FROM um_data_db
                         WHERE service IN
                               (SELECT barcode
                                  FROM tmp_um_extract
                                 WHERE extract_date IS NULL)
                            OR service = '000000';

                        DELETE /*+ um_data_dc_delete */
                        FROM um_data_dc
                         WHERE service IN
                               (SELECT barcode
                                  FROM tmp_um_extract
                                 WHERE extract_date IS NULL)
                            OR service = '000000';

                        DELETE /*+ um_data_dd_delete */
                        FROM um_data_dd
                         WHERE service IN
                               (SELECT barcode
                                  FROM tmp_um_extract
                                 WHERE extract_date IS NULL)
                            OR service = '000000';

                        DELETE /*+ um_data_de_delete */
                        FROM um_data_de
                         WHERE service IN
                               (SELECT barcode
                                  FROM tmp_um_extract
                                 WHERE extract_date IS NULL)
                            OR service = '000000';

                        DELETE /*+ um_data_df_delete */
                        FROM um_data_df
                         WHERE service IN
                               (SELECT barcode
                                  FROM tmp_um_extract
                                 WHERE extract_date IS NULL);

                        DELETE /*+ um_data_dg_delete */
                        FROM um_data_dg
                         WHERE service IN
                               (SELECT barcode
                                  FROM tmp_um_extract
                                 WHERE extract_date IS NULL);

                        DELETE /*+ um_data_dh_delete */
                        FROM um_data_dh
                         WHERE service IN
                               (SELECT barcode
                                  FROM tmp_um_extract
                                 WHERE extract_date IS NULL);

                        DELETE /*+ um_data_di_delete */
                        FROM um_data_di
                         WHERE service IN
                               (SELECT barcode
                                  FROM tmp_um_extract
                                 WHERE extract_date IS NULL);

                        DELETE /*+ um_data_di_delete */
                        FROM um_data_dj
                         WHERE service IN
                               (SELECT barcode
                                  FROM tmp_um_extract
                                 WHERE extract_date IS NULL);

                        DELETE /*+ um_data_dk_delete */
                        FROM um_data_dk
                         WHERE service IN
                               (SELECT barcode
                                  FROM tmp_um_extract
                                 WHERE extract_date IS NULL);

                        DELETE /*+ um_data_dl_delete */
                        FROM um_data_dl
                         WHERE service IN
                               (SELECT barcode
                                  FROM tmp_um_extract
                                 WHERE extract_date IS NULL);

                        DELETE /*+ um_data_dr_delete */
                        FROM um_data_dr
                         WHERE service IN
                               (SELECT barcode
                                  FROM tmp_um_extract
                                 WHERE extract_date IS NULL);

                        DELETE /*+ um_data_oh_delete */
                        FROM um_data_oh
                         WHERE service IN
                               (SELECT barcode
                                  FROM tmp_um_extract
                                 WHERE extract_date IS NULL);

                        DELETE /*+ um_data_od_delete */
                        FROM um_data_od
                         WHERE service IN
                               (SELECT barcode
                                  FROM tmp_um_extract
                                 WHERE extract_date IS NULL);
                        DELETE /*+ um_data_r_delete */
                        FROM um_data_r
                         WHERE service IN
                               (SELECT barcode
                                  FROM tmp_um_extract
                                 WHERE extract_date IS NULL);
                    ELSE
                        EXECUTE IMMEDIATE 'truncate table um_data_a';
                        EXECUTE IMMEDIATE 'truncate table um_data_e';
                        EXECUTE IMMEDIATE 'truncate table um_data_da';
                        EXECUTE IMMEDIATE 'truncate table um_data_db';
                        EXECUTE IMMEDIATE 'truncate table um_data_dc';
                        EXECUTE IMMEDIATE 'truncate table um_data_dd';
                        EXECUTE IMMEDIATE 'truncate table um_data_de';
                        EXECUTE IMMEDIATE 'truncate table um_data_df';
                        EXECUTE IMMEDIATE 'truncate table um_data_dg';
                        EXECUTE IMMEDIATE 'truncate table um_data_dh';
                        EXECUTE IMMEDIATE 'truncate table um_data_di';
                        EXECUTE IMMEDIATE 'truncate table um_data_dj';
                        EXECUTE IMMEDIATE 'truncate table um_data_dk';
                        EXECUTE IMMEDIATE 'truncate table um_data_dl';
                        EXECUTE IMMEDIATE 'truncate table um_data_dr';
                        EXECUTE IMMEDIATE 'truncate table um_data_oh';
                        EXECUTE IMMEDIATE 'truncate table um_data_od';
                        EXECUTE IMMEDIATE 'truncate table um_data_r';

                        -- 03/10/2017 mm5095 => adding sequence to notes for next gen
                        pkg_ultramate_common.reset_seq('um_data_dh_seq');
                        pkg_ultramate_common.reset_seq('um_data_dj_seq');
                        -- 03/10/2017 mm5095 => adding sequence to notes for next gen

                        -- 06/15/2016 mm5095 => per request by next gen, reference sheet note
                        begin
                          insert into um_data_di values('000000',1,1,'Two Tone Does Not Apply to Blended Panels','EXT',sysdate);
                          insert into um_data_dj (service, barcode, note_type, note_id)
                          values('000000','933000',35,1);
                          insert into um_data_dh (service,category_skey, subcategory_skey, part_skey, note_type, note_id)
                          values('000000',2,2,23,171,1);
                        exception when others then
                            null;
                        end;

                        -- 06/15/2016 mm5095 => per request by next gen, reference sheet note
                    END IF;

                    EXECUTE IMMEDIATE 'truncate table um_smartprtc_qrp_xref';
                    -- 07/25/2007 mm5095 => to support part list initiative

                    -- 04/05/02 mm5095 => jim service_location bug fix
                    --      insert into um_extract
                    --      select * from tmp_um_extract;
                    -- 04/05/02 mm5095 => jim service_location bug fix

                    INSERT /*+ um_body_insert */
                    INTO um_body
                        SELECT *
                          FROM tmp_um_body;

                    INSERT /*+ um_service_prtc_insert */
                    INTO um_service_prtc
                        SELECT *
                          FROM tmp_um_service_prtc;

                    INSERT /*+ um_smartprtc_insert */
                    INTO um_smartprtc
                        SELECT *
                          FROM tmp_um_smartprtc;

                    COMMIT;
                END IF;

                pkg_ultramate_common.extract_cegatgqrp(my_edsys_path,
                                                       run_type);
                /**  -- 08/06/04 tmc => WIP is never used -- this package is production only
                      if version = 'PR' then
                        EXTRACT_CEGATGQRP(my_edsys_path);
                      else
                        EXTRACT_CEGATGQRP_WIP(my_edsys_path);
                      end if;
                **/ -- 08/06/04 tmc => WIP is never used -- this package is production only

                pkg_ultramate_common.ext_refinish_complete(my_edsys_path);

                -- 10/24/2006 mm5095 => added support for extract_date
                extract_fhandle := utl_file.fopen(my_edsys_path,
                                                  'extract_date.txt',
                                                  'w');
                utl_file.put_line(extract_fhandle,
                                  to_char(SYSDATE, 'MM/DD/YYYY'));

                -- close files, if open
                IF utl_file.is_open(extract_fhandle)
                THEN
                    utl_file.fclose(extract_fhandle);
                END IF;

                pkg_ultramate_common.sp_update_globaltxt_semaphore(my_edsys_path,
                                                                   'global.txt',
                                                                   'a',
                                                                   'extract_date.txt');
                -- 10/24/2006 mm5095 => added support for extract_date

                -- 2016/06/21 mm5095 => moved dictionary extract to after service processing
/*                -- 03/28/2106 mm5095
                pkg_ultramate_common.dictionary_extract(my_edsys_path);
                -- 03/28/2106 mm5095
*/                -- 2016/06/21 mm5095 => moved dictionary extract to after service processing

                -- 2011/03/14 mm5095 => added creation of color_services.txt file
                pkg_ultramate_common.extract_color_services(my_edsys_path);
                -- 2011/03/14 mm5095 => added creation of color_services.txt file

                -- 2014/07/22 mm5095 => added creation of cieca_code_xref.txt file
                pkg_ultramate_common.cieca_code_extract(my_edsys_path);
                -- 2014/07/22 mm5095 => added creation of cieca_code_xref.txt file

                -- 2015/05/05 mm5095 => create dynamicprice file
                pkg_ultramate_common.dynamic_price_extract(my_edsys_path);
                -- 2015/05/05 mm5095 => create dynamicprice file

/* -- File generation disabled: global.txt via sp_output_zzglobal_done_files call (FTP sunset)
                pkg_ultramate_common.sp_output_zzglobal_done_files(my_edsys_path,
                                                                   'global',
                                                                   full_flag,
                                                                   restart_flag);
-- end commented block */

                -- ftp global information to NT
        -- 2016/06/21 mm5095 => moved dictionary extract to after service processing
                -- 2007/02/09 mm5095 => full_flag not used
/*                pkg_ultramate_common.sp_ftp_command('global.txt',
                                                    edsys_path,
                                                    my_ftp_dest_path,
                                                    my_ftp_machine_name,
                                                    ftp_on_flag,
                                                    ftp_ret_code);
*/                --      FTP_COMMAND('global.txt', edsys_path, full_flag);
                -- 2007/02/09 mm5095 => full_flag not used
        -- 2016/06/21 mm5095 => moved dictionary extract to after service processing

                -- 2008/12/31 pg2697 => added parms to support execute of sp_ftp_command and support of mixed case category descriptions
                -- 01/25/2007 mm5095 => added Oracle directory support
                -- 2007/02/09 mm5095 => full_flag not used
                pkg_ultramate_common.ext_refsheet(parm_path,
                                                  my_edsys_path,
                                                  edsys_path,
                                                  my_ftp_dest_path,
                                                  my_ftp_machine_name,
                                                  ftp_on_flag,
                                                  ftp_ret_code,
                                                  run_type);
                -- 2007/02/09 mm5095 => full_flag not used
                --      EXT_REFSHEET(parm_path, my_edsys_path, full_flag);
                -- 01/25/2007 mm5095 => added Oracle directory support
                -- 2008/12/31 pg2697 => added parms to support execute of sp_ftp_command and support of mixed case category descriptions
            END IF;
        END IF;
    END;

END;
/