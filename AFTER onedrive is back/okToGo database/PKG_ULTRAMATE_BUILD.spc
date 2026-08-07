CREATE OR REPLACE Package EXT.PKG_ULTRAMATE_BUILD
authid current_user is

PROCEDURE ULTRAMATE_MAIN(parm_path varchar2, run_type varchar2, parm_file varchar2,
unix_full_dir varchar2, unix_mini_dir varchar2, version varchar2, restart_flag char,
ftp_machine_name varchar2 DEFAULT NULL, ftp_dest_path varchar2 DEFAULT NULL);
END;
/
