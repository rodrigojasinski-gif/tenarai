CREATE OR REPLACE Package EXT.PKG_ULTRAMATE_DONE IS

  PROCEDURE ULTRAMATE_DONE(parm_path varchar2, run_type varchar2, parm_file varchar2,
  unix_full_dir varchar2, unix_mini_dir varchar2, version varchar2, restart_flag char,
  ftp_machine_name varchar2 DEFAULT NULL, ftp_dest_path varchar2 DEFAULT NULL);

END;
/
