CREATE OR REPLACE PACKAGE EXT.PKG_ULTRAMATE_COMMON authid current_user is

  /* *********************************************
  *  $Workfile:   PKG_ULTRAMATE_COMMON_spec.sql  $
  *    $Author:   pg2697  $
  *  $Revision:   1.4  $
  *   $Modtime:   Jan 15 2013 16:56:16  $
  *   Modifications:
	*   2020/05  pb0690  Updates for MCE Mini
	*   2020/07	 pg2697  Commerical Truck changes
	*   2026/04  rj132422 FTP sunset - disabled file generation for OTP006
  * *********************************************/
  --2020/07/20 pg2697 Added version_rec (to handle FULL versus MINI)
  TYPE version_record IS RECORD(
    version_number            NUMBER(3),
    post_checkin_process_date DATE,
    mce_flag                  VARCHAR2(1),
    um_flag                   VARCHAR2(1));
  TYPE version_cursor IS REF CURSOR RETURN version_record;

  --2020/04/17 pg2697 Added MCE_FLAG and UM_FLAG
  TYPE svcgrp_rec IS RECORD(
    barcode                   VARCHAR2(6),
    mfr_number                VARCHAR2(3),
    service_number            VARCHAR2(5),
    version_type              VARCHAR2(2),
    year_range                VARCHAR2(9),
    mfr_name                  VARCHAR2(80),
    make_name                 VARCHAR2(30),
    model_name                VARCHAR2(30),
    cd_volume                 NUMBER(1),
    post_checkin_process_date DATE,
    vehiclecategoryid         NUMBER(10),
    mce_flag                  VARCHAR2(1),
    um_flag                   VARCHAR2(1));
  TYPE svcgrp_cur IS REF CURSOR RETURN svcgrp_rec;

  TYPE distinct_rec IS RECORD(
    note_text VARCHAR2(2000));
  TYPE distinct_cur IS REF CURSOR RETURN distinct_rec;

  TYPE note_rec IS RECORD(
    note_group_skey NUMBER(22),
    note_id         NUMBER(22),
    note_type       NUMBER(22),
    note_text       VARCHAR2(2000),
    line_type       CHAR(1),
    note_symbol     VARCHAR2(12),
    note_rowid      ROWID);
  TYPE note_cur IS REF CURSOR RETURN note_rec;

  TYPE hdrdtl_rec IS RECORD(
    mfr_number       VARCHAR2(3),
    service_number   VARCHAR2(5),
    prtc             VARCHAR2(10),
    TYPE             VARCHAR2(2),
    min_labor_time   NUMBER,
    transformed_prtc VARCHAR2(10),
    labor_time       NUMBER);
  TYPE hdrdtl_cur IS REF CURSOR RETURN hdrdtl_rec;

  TYPE excptwip_rec IS RECORD(
    transformed_prtc VARCHAR2(10));
  TYPE excptwip_cur IS REF CURSOR RETURN excptwip_rec;

  TYPE excptprd_rec IS RECORD(
    transformed_prtc VARCHAR2(10));
  TYPE excptprd_cur IS REF CURSOR RETURN excptprd_rec;

  TYPE matrix_rec IS RECORD(
    relationship NUMBER(1),
    parent_id    VARCHAR2(6),
    child_id     VARCHAR2(6),
    line_type    CHAR(1),
    seq_1        NUMBER(10),
    seq_2        NUMBER(10),
    quantity     NUMBER(3));
  TYPE matrix_cur IS REF CURSOR RETURN matrix_rec;

  FUNCTION sf_getmixedcase(text_in IN VARCHAR2) RETURN VARCHAR2;
  FUNCTION sf_getmixedcasecategory(category_in VARCHAR2) RETURN VARCHAR2;
  FUNCTION sf_getmixedcasesubcategory(subcat_in VARCHAR2) RETURN VARCHAR2;
  FUNCTION sf_getmixedcaseprtc(skey_in NUMBER, prtc_in VARCHAR2)
    RETURN VARCHAR2;
  FUNCTION sf_getcategorystring(skey_in NUMBER) RETURN VARCHAR2;
  FUNCTION sf_getcomponentstring(skey_in NUMBER) RETURN VARCHAR2;
  FUNCTION sf_getlabortime(skey_in IN NUMBER) RETURN NUMBER;
  FUNCTION sf_getlaborverbstring(skey_in NUMBER) RETURN VARCHAR2;
  FUNCTION sf_getnote_by_skey(note_skey IN NUMBER) RETURN VARCHAR2;
  FUNCTION sf_getqualifierstring(skey_in   NUMBER,
                                 indent_in VARCHAR2,
                                 bpartflag BOOLEAN) RETURN VARCHAR2;
  FUNCTION sf_getreversestring(text_in IN VARCHAR2) RETURN VARCHAR2;
  FUNCTION sf_getsubcategorytext(category_skey IN NUMBER,
                                 qgroup_skey   IN NUMBER) RETURN VARCHAR2;
  FUNCTION sf_getservicebarcode(mfr_in VARCHAR2, service_in VARCHAR2)
    RETURN VARCHAR2;
  FUNCTION sf_getsmartprtc1(prtc_in            IN VARCHAR2,
                            clearcoat_maj_flag IN CHAR,
                            clearcoat_min_flag IN CHAR) RETURN NUMBER;
  FUNCTION sf_getsmartprtc2(prtc_in            IN VARCHAR2,
                            body_id            IN NUMBER,
                            csb_flag           IN CHAR,
                            ref_comp_body      IN VARCHAR2,
                            clearcoat_cap_flag IN CHAR,
                            two_tone_flag      IN CHAR,
                            repair_elim_flag   IN CHAR,
                            dup_elim_flag      IN CHAR) RETURN NUMBER;
  FUNCTION sf_getsmartprtcid(prtc_in IN VARCHAR2, run_type IN VARCHAR2)
    RETURN NUMBER;
  FUNCTION sf_stripdate(vvc2_qualifier IN VARCHAR2) RETURN VARCHAR2;
  FUNCTION sf_supplierconversion(supplier_num IN VARCHAR2) RETURN NUMBER;

  PROCEDURE sp_getlaborinfo(skey           IN NUMBER,
                            ceg_labor_time OUT NUMBER,
                            ioh_flag       OUT CHAR,
                            labor_type     OUT CHAR);
  PROCEDURE sp_getpartinfo(row_id            IN NUMBER,
                           version           IN VARCHAR2,
                           country_abbr      IN VARCHAR2,
                           part              OUT VARCHAR2,
                           date1             OUT DATE,
                           price1            OUT NUMBER,
                           date2             OUT DATE,
                           price2            OUT NUMBER,
                           discontinued_flag OUT CHAR,
                           new_flag          OUT CHAR,
                           special_flag      OUT CHAR);
  PROCEDURE sp_getsmartprtcbits(prtc_in  IN VARCHAR2,
                                bit1_0   OUT NUMBER,
                                bit1_1   OUT NUMBER,
                                run_type IN VARCHAR2);
  PROCEDURE sp_getsmartprtcinfo(prtc_in    IN VARCHAR2,
                                bit1_0     OUT NUMBER,
                                bit1_1     OUT NUMBER,
                                partid_out OUT NUMBER,
                                run_type   IN VARCHAR2);
  PROCEDURE sp_striptext(text_in         IN OUT VARCHAR2,
                         right_left_code IN OUT NUMBER);
  PROCEDURE sp_output_zzglobal_done_files(path         VARCHAR2,
                                          file_name    VARCHAR2,
                                          full_flag    CHAR,
                                          restart_flag CHAR);
  PROCEDURE sp_update_globaltxt_semaphore(path         VARCHAR2,
                                          file_name_in VARCHAR2,
                                          file_mode_in VARCHAR2,
                                          text_in      VARCHAR2);
  PROCEDURE sp_output_barcode_semaphore(path         VARCHAR2,
                                        barcode_in   VARCHAR2,
                                        text_in      VARCHAR2,
                                        file_mode_in VARCHAR2);
  PROCEDURE set_version_cursor(cursor_parm IN OUT version_cursor,
                               full_flag   IN CHAR,
                               mfr_in      IN varchar2,
                               service_in  IN varchar2,
                               version_in  IN VARCHAR2,
                               product_code_in IN VARCHAR2 DEFAULT NULL);
  PROCEDURE extract_service_barcodes(path         VARCHAR2,
                                     parm_file    VARCHAR2,
                                     version      VARCHAR2,
                                     full_flag    CHAR,
                                     restart_flag CHAR);
  PROCEDURE set_extr_service_group_cursor(cursor_parm IN OUT svcgrp_cur,
                                          run_type    IN VARCHAR2);
  PROCEDURE extract_service_group(path         IN VARCHAR2,
                                  full_flag    IN CHAR,
                                  restart_flag IN CHAR,
                                  run_type     IN VARCHAR2);
  PROCEDURE build_user_refinish_complete;
  PROCEDURE extract_alternate_parts(path VARCHAR2);
  PROCEDURE extract_disclaimer(path VARCHAR2);
  PROCEDURE extract_mmcatg(path VARCHAR2);
  PROCEDURE extract_pdr(path VARCHAR2);
  PROCEDURE extract_rv_matrices(path VARCHAR2);
  PROCEDURE extract_marine_matrices(path VARCHAR2);
  PROCEDURE extract_qualification_exclude(path VARCHAR2);
  PROCEDURE extract_overlap(parm_path    VARCHAR2,
                            path         VARCHAR2,
                            full_flag    CHAR,
                            restart_flag CHAR,
                            version_in   VARCHAR2);
  PROCEDURE extract_cegatgqrp(path IN VARCHAR2, run_type IN VARCHAR2);
  PROCEDURE ext_refinish_complete(path VARCHAR2);
  PROCEDURE ext_refsheet(path                VARCHAR2,
                         my_edsys_path       VARCHAR2,
                         edsys_path          VARCHAR2,
                         my_ftp_dest_path    VARCHAR2 DEFAULT NULL,
                         my_ftp_machine_name VARCHAR2 DEFAULT NULL,
                         ftp_on_flag         BOOLEAN DEFAULT FALSE,
                         ftp_ret_code        BINARY_INTEGER,
                         run_type            VARCHAR2);
  PROCEDURE sp_ftp_command(filename            VARCHAR2,
                           edsys_path          VARCHAR2,
                           my_ftp_dest_path    VARCHAR2 DEFAULT NULL,
                           my_ftp_machine_name VARCHAR2 DEFAULT NULL,
                           ftp_on_flag         BOOLEAN DEFAULT FALSE,
                           ftp_ret_code        BINARY_INTEGER DEFAULT 0);
  PROCEDURE create_altpart(service_barcode VARCHAR2,
                           mfr_in          VARCHAR2,
                           service_in      VARCHAR2,
                           version_in      VARCHAR2,
                           path            VARCHAR2,
                           run_type        IN VARCHAR2);
  PROCEDURE sp_getatgservice(mfr_in      IN VARCHAR2,
                             service_in  IN VARCHAR2,
                             atg_mfr     IN OUT VARCHAR2,
                             atg_service IN OUT VARCHAR2,
                             run_type    IN VARCHAR2);
  PROCEDURE truncate_um_extm_tables;

  PROCEDURE insert_um_data_dc(service          VARCHAR2,
                              header_num       INTEGER,
                              n_section        INTEGER,
                              n_part           INTEGER,
                              part_text        VARCHAR2,
                              suppression_code INTEGER,
                              part_or_labor    VARCHAR2);

  PROCEDURE insert_um_data_dd(service          VARCHAR2,
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
                              component_skey   INTEGER);

  PROCEDURE insert_um_data_de(service_barcode_in VARCHAR2,
                              nheader            INTEGER,
                              nsection           INTEGER,
                              npart              INTEGER,
                              nimage_in          VARCHAR2,
                              callout_number_in  VARCHAR2,
                              x_coordinate       INTEGER,
                              y_coordinate       INTEGER,
                              x_extent           INTEGER,
                              y_extent           INTEGER);

  PROCEDURE insert_um_data_dh(service          VARCHAR2,
                              category_skey    VARCHAR2,
                              subcategory_skey INTEGER,
                              part_skey        INTEGER,
                              note_type        INTEGER,
                              note_id          INTEGER);

  PROCEDURE insert_um_data_dj(service_barcode_in VARCHAR2,
                              barcode            VARCHAR2,
                              note_type          INTEGER,
                              note_id            INTEGER);

  PROCEDURE update_um_df(service_in      VARCHAR2,
                         relationship_in INTEGER,
                         parent_in       VARCHAR2,
                         child_in        VARCHAR2,
                         quantity_in     NUMBER);
  PROCEDURE update_um_di(service_in VARCHAR2,
                         note_id_in INTEGER,
                         nline_in   INTEGER,
                         text_in    VARCHAR2);
  PROCEDURE update_um_oh(service_in        VARCHAR2,
                         part_id_in        INTEGER,
                         type_in           INTEGER,
                         min_labor_time_in INTEGER,
                         overlap_skey_in   INTEGER);
  PROCEDURE update_um_od(service_in      VARCHAR2,
                         overlap_skey_in INTEGER,
                         part_id_in      INTEGER,
                         labor_in        INTEGER);
  PROCEDURE set_matrix_cur(cursor_parm IN OUT matrix_cur,
                           mfr_in      IN VARCHAR2,
                           service_in  IN VARCHAR2,
                           version_in  IN VARCHAR2,
                           run_type    IN VARCHAR2);
  PROCEDURE create_matrix(service_barcode VARCHAR2,
                          mfr_in          VARCHAR2,
                          service_in      VARCHAR2,
                          version_in      VARCHAR2,
                          run_type        VARCHAR2,
                          path            VARCHAR2);
  PROCEDURE set_distinctnotes_cursor(cursor_parm     IN OUT distinct_cur,
                                     run_type        IN VARCHAR2,
                                     parallel_number CHAR);
  PROCEDURE set_note_cursor(cursor_parm     IN OUT note_cur,
                            run_type        IN VARCHAR2,
                            parallel_number CHAR);
  PROCEDURE create_notes(service_barcode IN VARCHAR2,
                         mfr_in          IN VARCHAR2,
                         service_in      IN VARCHAR2,
                         version_in      IN VARCHAR2,
                         run_type        IN VARCHAR2,
                         path            IN VARCHAR2,
                         parallel_number IN CHAR);
  PROCEDURE create_options(service_barcode VARCHAR2,
                           mfr_in          VARCHAR2,
                           service_in      VARCHAR2,
                           version_in      VARCHAR2,
                           path            VARCHAR2,
                           run_type        VARCHAR2);
  PROCEDURE getstartenddate(lower_date     IN DATE,
                            upper_date     IN DATE,
                            start_date_out OUT VARCHAR2,
                            end_date_out   OUT VARCHAR2);
  PROCEDURE getnoteid_by_skey(skey            IN NUMBER,
                              my_type         OUT NUMBER,
                              my_id           OUT NUMBER,
                              run_type        IN VARCHAR2,
                              parallel_number IN CHAR);
  PROCEDURE getnoteid_by_text(my_text_in      IN VARCHAR2,
                              my_type         IN NUMBER,
                              my_id           OUT NUMBER,
                              run_type        IN VARCHAR2,
                              parallel_number IN CHAR);

  FUNCTION sf_get_vehicle_type(barcode_in VARCHAR2, mfr_in VARCHAR2)
    RETURN NUMBER;
  FUNCTION sf_get_check_header(vehicle_in NUMBER) RETURN BOOLEAN;

  PROCEDURE sp_get_header_offset(header_offset_out OUT NUMBER,
                                 ceg_offset_out    OUT NUMBER);

  FUNCTION sf_get_header_sequence(vehicle_in    NUMBER,
                                  mfr_in        VARCHAR2,
                                  category_in   NUMBER,
                                  header_offset NUMBER,
                                  ceg_offset    NUMBER) RETURN NUMBER;
  FUNCTION sf_get_max_header_sequence(vehicle_in    NUMBER,
                                      header_offset NUMBER) RETURN NUMBER;

  PROCEDURE set_hdr_dtl_cursor(cursor_parm IN OUT hdrdtl_cur,
                               run_type    IN VARCHAR2,
                               atg_mfr     VARCHAR2,
                               atg_service VARCHAR2,
                               mfr_in      VARCHAR2,
                               service_in  VARCHAR2);
  PROCEDURE set_excpt_wip_cursor(cursor_parm IN OUT excptwip_cur,
                                 run_type    IN VARCHAR2,
                                 skey_in     NUMBER,
                                 mfr_in      VARCHAR2,
                                 service_in  VARCHAR2);
  PROCEDURE set_excpt_prd_cursor(cursor_parm IN OUT excptprd_cur,
                                 run_type    IN VARCHAR2,
                                 skey_in     NUMBER,
                                 mfr_in      VARCHAR2,
                                 service_in  VARCHAR2);
  PROCEDURE create_overlap(service_barcode VARCHAR2,
                           mfr_in          VARCHAR2,
                           service_in      VARCHAR2,
                           version_in      VARCHAR2,
                           mfr1            VARCHAR2,
                           service1        VARCHAR2,
                           mfr2            VARCHAR2,
                           service2        VARCHAR2,
                           run_type        VARCHAR2,
                           path            VARCHAR2);
  PROCEDURE extract_color_services(path VARCHAR2);
  FUNCTION sf_getclass(mfr_in VARCHAR2, service_in VARCHAR2) RETURN VARCHAR2;
  PROCEDURE sp_update_mapp_supplier_xref(path VARCHAR2 DEFAULT NULL); -- Default added to parameter to support nextgen MAPP
  PROCEDURE extract_side_body(path VARCHAR2);

  PROCEDURE price_extract(unix_full_dir    VARCHAR2,
                          ftp_machine_name VARCHAR2 DEFAULT NULL,
                          ftp_dest_path    VARCHAR2 DEFAULT NULL);

  PROCEDURE mapp_extract(unix_full_dir    VARCHAR2,
                         ftp_machine_name VARCHAR2 DEFAULT NULL,
                         ftp_dest_path    VARCHAR2 DEFAULT NULL);

  PROCEDURE cieca_code_extract(path VARCHAR2);
  PROCEDURE dynamic_price_extract(path VARCHAR2);
  PROCEDURE dictionary_extract(path VARCHAR2);
  PROCEDURE extract_disclosure(path VARCHAR2);

  FUNCTION sf_getfrench(skey_in INTEGER, text_in VARCHAR2) RETURN VARCHAR2;
  PROCEDURE reset_seq(p_seq_name IN VARCHAR2);
END;
/
