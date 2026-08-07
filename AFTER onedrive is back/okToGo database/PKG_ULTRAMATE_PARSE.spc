CREATE OR REPLACE PACKAGE EXT."PKG_ULTRAMATE_PARSE" IS

PROCEDURE ULTRAMATE_PARSE(run_type varchar2, unix_full_dir varchar2, unix_mini_dir varchar2,
                          ftp_machine_name varchar2 DEFAULT NULL, ftp_dest_path varchar2 DEFAULT NULL, parallel_run char);

END;
/
