#!/bin/ksh
#                            
######################################################################################
# JN    - 11/07/01  Created for RACE II.                                             #
#                                                                                    #
#           This program reads a parm file requested for the extract                 #
#           and reports service_category_detail errors                               #
#                                                                                    #
######################################################################################
##start sqlplus
sqlplus << % 2>&1 > $LOG
$EXTUSERID

set serveroutput on;
set feedback on;
set echo on;
set arraysize 100;
 
define vi_IN_JOBNAME   = $SQL_JOBNAME       varchar2(20);
define vi_IN_DIR       = $SQL_PARMFILE_PATH varchar2(30);
define vi_IN_FILE      = $SQL_PARMFILE      varchar2(10);
define vi_IN_VERSION   = $SQL_VERSION       varchar2(02);
define vi_OUT_REPTFILE = $SQL_ERR_RPT       varchar2(06);
define vi_OUT_DIR      = $SQL_ERR_RPT_PATH  varchar2(30);
define vi_sys_date     = $SQL_SYS_DATE      varchar2(14);

drop table temp_xex_mfr_svc;
create table temp_xex_mfr_svc
(mfr_number     varchar2(03)
,service_number varchar2(05)
,load_date      date   default sysdate
,constraint pk01 primary key (mfr_number,service_number)
)
;

declare

 v_in_jobname           varchar2(20);
 v_in_rec               varchar2(80);
 v_in_dirname           varchar2(60);
 v_in_filename          varchar2(60);
 v_in_version           varchar2(02);
 v_out_dirname          varchar2(60);

 v_27_spaces            varchar2(27):='                           ';
 v_ceg1_access_coord_id varchar2(10);
 v_ceg1_barcode         varchar2(06);
 v_ceg1_prtc            varchar2(10);
 v_ceg1_labor_op_skey   number;
 v_ceg1_unique_row_id   number;
 v_ceg2_access_coord_id varchar2(10);
 v_ceg2_barcode         varchar2(06);
 v_ceg2_prtc            varchar2(10);
 v_ceg2_labor_op_skey   number;
 v_ceg2_unique_row_id   number;
 v_ceg2_part_supp_number  varchar2(03);
 v_ceg2_part_supp_country varchar2(02);
 v_date 		date;
 v_dup_ctr 		number:=0;
 v_mfr_num              varchar2(03);
 v_prod_code            varchar2(06);
 v_rpt_filename         varchar2(60);
 v_srvc_num             varchar2(05);
 v_srvc_barcd           varchar2(06);
 v_sys_date             varchar2(14);
 v_version              varchar2(02);

 v_hold_mfr_num         varchar2(03):=' ';
 v_hold_prod_code       varchar2(06):=' ';
 v_hold_srvc_num        varchar2(05):=' ';

 v_lines                number;
 v_new_svc              char(01):='Y';
 v_newpage              number :=60;
 v_page                 number; 
 v_blankline            varchar2(132):=' ';
 v_head_a               varchar2(132);
 v_head_b               varchar2(132);
 v_head1                varchar2(132);
 v_head2                varchar2(132);
 v_head3                varchar2(132);

 v_in_fHandle           UTL_FILE.FILE_TYPE;
 v_out_fHandlerpt       UTL_FILE.FILE_TYPE;

Cursor c_product is 
 select mfr_number
       ,service_number
 from   product_service
 where  product_code = v_prod_code;
 
Cursor c_temp_tbl is 
 select mfr_number
       ,service_number
 from   temp_xex_mfr_svc
 order by mfr_number, service_number;
 
Cursor c_ceg_errors is 
 select distinct a.access_coordinate_id
       ,NVL(a.barcode,'NULL')
       ,NVL(a.prtc,'NULL')
       ,a.unique_row_id
       ,NVL(a.labor_operation_skey,'0')
 from   service_category_detail a  
 where  a.mfr_number       = v_mfr_num   
    and a.service_number   = v_srvc_num
    and a.version_type     = v_version
    and ((nvl(a.barcode,'NULL')='NULL' 
       or nvl(a.prtc,'NULL'   )='NULL' 
          )
    and nvl(a.labor_operation_skey,0)!=0  
        ) 
    order by a.access_coordinate_id;

Cursor c_ceg_errors2 is
 select distinct a.access_coordinate_id
       ,NVL(a.barcode,'NULL')
       ,NVL(a.prtc,'NULL')
       ,a.unique_row_id
       ,NVL(a.labor_operation_skey,'0')
 from   service_category_detail a,
        detail_part_xref b 
 where  a.mfr_number       = v_mfr_num
    and a.service_number   = v_srvc_num
    and a.version_type     = v_version
    and a.line_type in ('A','G')
    and ((nvl(a.barcode,'NULL')='NULL'
       or nvl(a.prtc,'NULL'   )='NULL'
         )
    and (b.unique_row_id  = a.unique_row_id
    and b.version_type    = v_version)) 
    order by a.access_coordinate_id;

---main program begin ___
begin
v_in_filename     :='&vi_IN_FILE';
v_in_jobname      :='&vi_IN_JOBNAME';
v_in_dirname      :='&vi_IN_DIR';
v_in_version      :='&vi_IN_VERSION';
v_rpt_filename    :='&vi_OUT_REPTFILE';
v_out_dirname     :='&vi_OUT_DIR';
v_sys_date        :='&vi_sys_date';
v_page            :=0;

 select sysdate into v_date from dual;

 DBMS_OUTPUT.ENABLE(1000000);

 DBMS_OUTPUT.NEW_LINE;
 
 DBMS_OUTPUT.PUT_LINE('Start: ' || to_char(v_date,'MM/DD/YYYY HH24:MI:SS'));
 DBMS_OUTPUT.PUT_LINE('----------------------------------------');
 DBMS_OUTPUT.PUT_LINE('PRM  DIR: ' || v_in_dirname);
 DBMS_OUTPUT.PUT_LINE('PRM FILE: ' || v_in_filename);
 DBMS_OUTPUT.PUT_LINE('----------------------------------------');
    
-- Open Input/Output File

     v_head_a:=('                               MFR  SERVICE');
     v_head_b:=('                               ---  -------');

     v_head1:=(' XEXZ003   '||v_date||'      EXTRACT ERROR SUMMARY            PAGE: ');
     v_head2:=('MFR  SERVICE  SVC BARCD  ACCESS COORD   BARCODE   PRTC      ');
     v_head3:=('---  -------  ---------  ------------   -------   ----------');

     v_in_fHandle     := UTL_FILE.FOPEN(v_in_dirname,v_in_filename,'r');
     v_out_fHandlerpt := UTL_FILE.FOPEN(v_out_dirname,v_in_jobname||'a_'||v_rpt_filename||'_'||v_sys_date||'.rpt','w');
        
     v_lines:=65;

--#######################################
-- create mfr/srvc table to process
--#######################################
   LOOP <<l_create_temp_tbl>>

--read parm record
   BEGIN
    UTL_FILE.GET_LINE(v_in_fHandle,v_in_rec);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
        EXIT;
   END;

   v_prod_code  :=substr(v_in_rec,1,6);

   OPEN  c_product;
   FETCH c_product 
   INTO  v_mfr_num
        ,v_srvc_num;

   WHILE c_product%FOUND

    LOOP <<l_insert_into_tbl>>

       BEGIN
          insert into  temp_xex_mfr_svc
          (mfr_number
          ,service_number)
          values (v_mfr_num
                 ,v_srvc_num);
   
       EXCEPTION
           WHEN dup_val_on_index THEN
           v_dup_ctr:=v_dup_ctr +1;
   
       END;

--Check for new page     
       if v_lines > v_newpage then
          v_page:=v_page+1;
          UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_head1||to_char(v_page));
          UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_blankline);
          UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_blankline);
          UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_head_a);
          UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_head_b);
          UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_blankline);
          v_lines:=5;
       end if;
         
       UTL_FILE.PUT_LINE(v_out_fHandlerpt,'    '||v_27_spaces ||v_mfr_num
             ||'  '||v_srvc_num );

      v_lines:=v_lines+1;

       FETCH c_product 
       INTO  v_mfr_num
            ,v_srvc_num;

    END LOOP l_insert_into_tbl;
    CLOSE  c_product;
    
 END LOOP l_create_temp_tbl;

commit;

     UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_head1||to_char(v_page));
     UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_blankline);
     UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_blankline);
     UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_head2);
     UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_head3);
     UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_blankline);
     v_lines:=5;

   OPEN  c_temp_tbl;

--#######################################
-- processing parm file loop
--#######################################
 
   BEGIN
   FETCH c_temp_tbl 
   INTO  v_mfr_num
        ,v_srvc_num;
   END;

   WHILE c_temp_tbl%FOUND
   LOOP <<l_main>>

   v_version :=v_in_version;
 
--Check for new page     
   if v_lines > v_newpage then
      v_page:=v_page+1;
      UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_head1||to_char(v_page));
      UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_blankline);
      UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_blankline);
      UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_head2);
      UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_head3);
      UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_blankline);
      v_lines:=5;
   end if;
         
   BEGIN
   SELECT barcode
   INTO   v_srvc_barcd
   FROM   service
   WHERE  mfr_number    =v_mfr_num
     and  service_number=v_srvc_num
     and  version_type  =v_version;

   EXCEPTION
       WHEN NO_DATA_FOUND THEN
       v_srvc_barcd:='*NONE*';
   END;

   OPEN  c_ceg_errors;
   FETCH c_ceg_errors 
   INTO  v_ceg1_access_coord_id 
        ,v_ceg1_barcode
        ,v_ceg1_prtc  
        ,v_ceg1_unique_row_id  
        ,v_ceg1_labor_op_skey;

   WHILE c_ceg_errors%FOUND
   loop
   <<l_ceg_errors>> 

--Check for new page     
       if v_lines > v_newpage then
          v_page:=v_page+1;
          UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_head1||to_char(v_page));
          UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_blankline);
          UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_blankline);
          UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_head2);
          UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_head3);
          UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_blankline);
          v_lines:=5;
       end if;

      if  v_hold_mfr_num   = ' ' or
          v_hold_srvc_num  = ' ' or
         (v_mfr_num        = v_hold_mfr_num and
          v_hold_srvc_num  = v_hold_srvc_num) then
          v_hold_mfr_num   := v_mfr_num;
          v_hold_srvc_num  := v_srvc_num;
          v_new_svc :='N';
      else
          if  v_mfr_num   <> v_hold_mfr_num   or
              v_srvc_num  <> v_hold_srvc_num  then
              v_hold_mfr_num   := v_mfr_num;
              v_hold_srvc_num  := v_srvc_num;
              v_new_svc :='Y';
          end if;
      end if;

      if v_new_svc='Y' or v_lines=5  then
      UTL_FILE.PUT_LINE(v_out_fHandlerpt,' ' ||v_mfr_num
                          ||'   '||v_srvc_num||'    '||'9'||v_srvc_barcd ||'     '
                          ||lpad(v_ceg1_access_coord_id,10,' ')||'    '||rpad(v_ceg1_barcode,6,' ')||'   '
                          ||lpad(v_ceg1_prtc,10,' '));
      else
      UTL_FILE.PUT_LINE(v_out_fHandlerpt,rpad(v_27_spaces,27,' ')
                          ||lpad(v_ceg1_access_coord_id,10,' ')||'    '||rpad(v_ceg1_barcode,6,' ')||'   '
                          ||lpad(v_ceg1_prtc,10,' '));
      end if;

      v_lines:=v_lines+1;

      FETCH c_ceg_errors 
      INTO  v_ceg1_access_coord_id 
           ,v_ceg1_barcode
           ,v_ceg1_prtc
           ,v_ceg1_unique_row_id  
           ,v_ceg1_labor_op_skey;

    end loop l_ceg_errors;

--**********************************
-- Beginning of second error check *
--**********************************

   OPEN  c_ceg_errors2;
   FETCH c_ceg_errors2
   INTO  v_ceg2_access_coord_id 
        ,v_ceg2_barcode
        ,v_ceg2_prtc  
        ,v_ceg2_unique_row_id  
        ,v_ceg2_labor_op_skey;

   WHILE c_ceg_errors2%FOUND
   loop
   <<l_ceg_errors2>>

--Check for new page
       if v_lines > v_newpage then
          v_page:=v_page+1;
          UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_head1||to_char(v_page));
          UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_blankline);
          UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_blankline);
          UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_head2);
          UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_head3);
          UTL_FILE.PUT_LINE(v_out_fHandlerpt,v_blankline);
          v_lines:=5;
       end if;

      if  v_hold_mfr_num   = ' ' or
          v_hold_srvc_num  = ' ' or
         (v_mfr_num        = v_hold_mfr_num and
          v_hold_srvc_num  = v_hold_srvc_num) then
          v_hold_mfr_num   := v_mfr_num;
          v_hold_srvc_num  := v_srvc_num;
          v_new_svc :='N';
      else
          if  v_mfr_num   <> v_hold_mfr_num   or
              v_srvc_num  <> v_hold_srvc_num  then
              v_hold_mfr_num   := v_mfr_num;
              v_hold_srvc_num  := v_srvc_num;
              v_new_svc :='Y';
          end if;
      end if;

      if v_new_svc='Y' or v_lines=5  then
      UTL_FILE.PUT_LINE(v_out_fHandlerpt,' ' ||v_mfr_num
                          ||'   '||v_srvc_num||'    '||'9'||v_srvc_barcd ||'     '
                          ||lpad(v_ceg2_access_coord_id,10,' ')||'    '||rpad(v_ceg2_barcode,6,' ')||'   '
                          ||lpad(v_ceg2_prtc,10,' '));
      else
      UTL_FILE.PUT_LINE(v_out_fHandlerpt,rpad(v_27_spaces,27,' ')
                          ||lpad(v_ceg2_access_coord_id,10,' ')||'    '||rpad(v_ceg2_barcode,6,' ')||'   '
                          ||lpad(v_ceg2_prtc,10,' ')) ;
      end if;

      v_lines:=v_lines+1;

      FETCH c_ceg_errors2
      INTO  v_ceg2_access_coord_id
           ,v_ceg2_barcode
           ,v_ceg2_prtc
           ,v_ceg2_unique_row_id
           ,v_ceg2_labor_op_skey;
    end loop l_ceg_errors2;

   CLOSE  c_ceg_errors;
   CLOSE  c_ceg_errors2;

   FETCH c_temp_tbl 
   INTO  v_mfr_num
        ,v_srvc_num;

 END LOOP l_main;

-- close files
 UTL_FILE.FCLOSE(v_in_fHandle);
 UTL_FILE.FCLOSE(v_out_fHandlerpt);

 select sysdate into v_date from dual;
 DBMS_OUTPUT.PUT_LINE('End: ' || to_char(v_date,'MM/DD/YYYY HH24:MI:SS')); 
    
EXCEPTION
  
  WHEN OTHERS THEN
    RAISE;
      
end;
--leave "/" it is required for pl/sql end block--
/
quit;
--leave "end_sql_block" it is required for sql end block--
%
#END OF Script
