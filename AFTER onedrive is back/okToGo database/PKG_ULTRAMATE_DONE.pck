CREATE OR REPLACE Package EXT.PKG_ULTRAMATE_DONE IS

  PROCEDURE ULTRAMATE_DONE(parm_path varchar2, run_type varchar2, parm_file varchar2,
  unix_full_dir varchar2, unix_mini_dir varchar2, version varchar2, restart_flag char,
  ftp_machine_name varchar2 DEFAULT NULL, ftp_dest_path varchar2 DEFAULT NULL);

END;
/
CREATE OR REPLACE PACKAGE BODY EXT."PKG_ULTRAMATE_DONE" IS
    -- ftp global variables
    ftp_on_flag BOOLEAN; -- controls whether data ftp'd to NT system. (see code after sf_getDirectoryPath for set of value)

    ftp_ret_code        BINARY_INTEGER := 0;
    my_ftp_dest_path    VARCHAR2(80);
    my_ftp_machine_name VARCHAR2(10);

    -- 07/25/2007 mm5095 => to support part list initiative
    PROCEDURE update_um_smartprtc_qrp_xref IS
    BEGIN
        INSERT /*+ um_smartprtc_qrp_xref_insert */
        INTO um_smartprtc_qrp_xref
            (prtc,
             prtc_body,
             partid,
             qrp_assy_type,
             last_update_user,
             last_update_date)
            SELECT prtc,
                   prtc_body,
                   partid,
                   qrp_assy_type,
                   USER,
                   SYSDATE
              FROM bceg_qrp_xref a,
                   um_smartprtc  b
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
                    substr(bceg_prtc, 3, 1) = '$')
            UNION
            SELECT prtc,
                   substr(prtc, 4, 4) prtc_body,
                   partid,
                   qrp_assy_type,
                   USER,
                   SYSDATE
              FROM atg_qrp_xref a,
                   um_smartprtc b
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

    EXCEPTION
        WHEN OTHERS THEN
            raise_application_error(-20107, 'UNKNOWN ERROR');
    END;
    -- 07/25/2007 mm5095 => to support part list initiative

    ---------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------
    --                                          MAIN PROCESSING BLOCK FOR ULTRAMATE_DONE                               --
    ---------------------------------------------------------------------------------------------------------------------
    ---------------------------------------------------------------------------------------------------------------------
    -- 01/25/2007 mm5095 => added Oracle directory support
    PROCEDURE ultramate_done
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
    --  PROCEDURE ULTRAMATE_DONE(parm_path varchar2, run_type varchar2, parm_file varchar2, edsys_path varchar2, version varchar2, restart_flag char,
        --  ftp_machine_name varchar2, ftp_dest_path varchar2)
     IS

        my_edsys_path VARCHAR2(100);
        edsys_path    VARCHAR2(100);
        full_flag     CHAR(1);

    BEGIN
        dbms_output.enable(1000000);

        my_ftp_machine_name := ftp_machine_name;
        my_ftp_dest_path    := ftp_dest_path;

        IF run_type = 'FULL'
        THEN
            full_flag := 'T';
            -- 01/25/2007 mm5095 => added Oracle directory support
            my_edsys_path := unix_full_dir;
            --      edsys_path := unix_path || '/um_full';
            -- 01/25/2007 mm5095 => added Oracle directory support
        ELSE
            full_flag := 'F';
            -- 01/25/2007 mm5095 => added Oracle directory support
            my_edsys_path := unix_mini_dir;
            --      edsys_path := unix_path || '/um_mini';
            -- 01/25/2007 mm5095 => added Oracle directory support
        END IF;

        -- 2008/12/31 PAG => edsys_path is used to determine ftp_on_flag value (based on whether this is running in prod versus mdev).
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
        -- 2008/12/31 PAG => edsys_path is used to determine ftp_on_flag value

        -- 2016/06/21 mm5095 => moved dictionary extract to after service processing
        -- 02/09/2017 mm5095
/* -- File generation disabled: dictionary_extract call call (FTP sunset)
        pkg_ultramate_common.dictionary_extract(my_edsys_path);
-- end commented block */
        -- 02/09/2017 mm5095
        -- 2016/06/21 mm5095 => moved dictionary extract to after service processing

        -- 2016/06/21 mm5095 => moved to after service processing
/* -- FTP send disabled: global.txt sp_ftp_command send (FTP sunset)
        pkg_ultramate_common.sp_ftp_command('global.txt',
                                            edsys_path,
                                            my_ftp_dest_path,
                                            my_ftp_machine_name,
                                            ftp_on_flag,
                                            ftp_ret_code);
-- end commented block */
        -- 2016/06/22 mm5095 => moved to after service processing

/* -- File generation disabled: done.txt via sp_output_zzglobal_done_files call (FTP sunset)
        pkg_ultramate_common.sp_output_zzglobal_done_files(my_edsys_path,
                                                           'done',
                                                           full_flag,
                                                           restart_flag);
-- end commented block */

        -- ftp done status to NT
        --ftp_command('done.txt', edsys_path, full_flag);
/* -- FTP send disabled: done.txt sp_ftp_command send (FTP sunset)
        pkg_ultramate_common.sp_ftp_command('done.txt',
                                            edsys_path,
                                            my_ftp_dest_path,
                                            my_ftp_machine_name,
                                            ftp_on_flag,
                                            ftp_ret_code);
-- end commented block */

/* -- File generation disabled: price.txt via sp_output_zzglobal_done_files call (FTP sunset)
        pkg_ultramate_common.sp_output_zzglobal_done_files(my_edsys_path,
                                                           'price',
                                                           full_flag,
                                                           restart_flag);
-- end commented block */
/* -- File generation disabled: mapp.txt via sp_output_zzglobal_done_files call (FTP sunset)
        pkg_ultramate_common.sp_output_zzglobal_done_files(my_edsys_path,
                                                           'mapp',
                                                           full_flag,
                                                           restart_flag);
-- end commented block */

/* -- FTP send disabled: price.txt sp_ftp_command send (FTP sunset)
        pkg_ultramate_common.sp_ftp_command('price.txt',
                                            edsys_path,
                                            my_ftp_dest_path,
                                            my_ftp_machine_name,
                                            ftp_on_flag,
                                            ftp_ret_code);
-- end commented block */

/* -- FTP send disabled: mapp.txt sp_ftp_command send (FTP sunset)
        pkg_ultramate_common.sp_ftp_command('mapp.txt',
                                            edsys_path,
                                            my_ftp_dest_path,
                                            my_ftp_machine_name,
                                            ftp_on_flag,
                                            ftp_ret_code);
-- end commented block */

        -- update monthly data for ODD OEM
        pkg_oem_odd.sp_update_monthly_odd;

        -- 07/25/2007 mm5095 => to support part list initiative
        update_um_smartprtc_qrp_xref;
        -- 07/25/2007 mm5095 => to support part list initiative

    END;
END;
/
