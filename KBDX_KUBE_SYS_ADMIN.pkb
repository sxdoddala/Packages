create or replace PACKAGE BODY kbdx_kube_sys_admin
 AS
/*
 * $History: kbdx_kube_sys_admin.pkb $
 *
 * *****************  Version 6  *****************
 * User: Jkeller      Date: 2/17/09    Time: 1:16p
 * Updated in $/KBX Kube Main/40_CODE_BASE/datasets/Diagnostic Kube
 *
 *    4  Mmiller      7/30/03    called parameter utils for parameter dates
 *    1  Mmiller      7/30/03    created
 *    8  Mmiller      6/20/03    made get a public method ported to new oracle ff package
 *    6  Mmiller      5/06/03    Enhancements
 *    4  Rreyes       1/28/03    Fixed header strings added / at end of file
 
 --  1.0     MXKEERTHI(ARGANO)  05/04/23               R12.2 Upgrade Remediation
*/
Procedure main(p_process_id in number) Is
  l_kube_type_id number := 0;

  l_sql_string varchar2(32767);
  l_from varchar2(32767);
  l_where varchar2(32767);
  l_string varchar2(32767);
  l_error varchar2(32767);

cursor get_kubes
is select kube_type_id from kbdx_kube_types;

cursor lcur_get_tabl_sql is select * from kbdx_kube_tables;

cursor lcur_get_processes(ad_start date, ad_end date)
is select p.process_id,
          p.request_id,
          p.fnd_user_id,
          u.user_name,
          decode(upper(p.status),'E','Error','C','Complete','P','Pending','I','Inactive','R','Running') status,
          p.process_type,
          p.message_text,
          p.creation_date,
          p.completion_date,
          p.directory_name,
          p.file_name
from kbdx_processes p,fnd_user u
where p.completion_date between ad_start  and ad_end
and u.user_id = p.fnd_user_id
order by process_id desc;


ld_start_date date;
ld_end_date date;
l_parameter_id number;

Begin

  g_processes_tab.delete;

  l_kube_type_id := kbdx_kube_api_pkg.initialize_kube(
                   p_process_id => p_process_id,
                   p_aol_owner => fnd_profile.value('PER_BUSINESS_GROUP_ID'));


   -- Get the dates for the kbdx_kube_processes
    ld_start_date := kbdx_kube_parameter_utils.get_parameter_start_date(p_parameter_name => 'DATE',
                                             p_process_id => p_process_id);


    ld_end_date := kbdx_kube_parameter_utils.get_parameter_end_date(p_parameter_name => 'DATE',
                                             p_process_id => p_process_id);


   gd_start_date := ld_start_date;
   gd_end_date := ld_end_date;

   -- end dates

  for rec_kubes in get_kubes loop
    sproc_get_ff(rec_kubes.kube_type_id);
  end loop;


-- Now go get what has been run
  for rec_p in lcur_get_processes(ld_start_date,ld_end_date) loop

      l_string := '';
      l_string := rec_p.process_id||'|'||rec_p.request_id;
      l_string := l_string||'|'||rec_p.fnd_user_id||'|'||rec_p.user_name
               ||'|'||rec_p.status||'|'||rec_p.process_type||'|'||rec_p.message_text
               ||'|'||to_char(rec_p.creation_date,'MM/DD/YYYY HH12:MI:SS')||'|'||to_char(rec_p.completion_date,'MM/DD/YYYY HH12:MI:SS')
               ||'|'||rec_p.directory_name||'|'||rec_p.file_name||'|'||''||'|'||to_char(rec_p.creation_date,'MM/DD/YYYY') ;
      l_string := l_string||'|'||0 ;

        kbdx_kube_api_pkg.write (p_file_type => 'KBDX_PROCESSES', p_buffer => l_string);


      if not g_processes_tab.exists(rec_p.process_id)then
        g_processes_tab(rec_p.process_id) := rec_p.process_id;
      end if;

  end loop;

-- now get the table selects


 for rec_sql in lcur_get_tabl_sql loop

       l_string := '';
       l_string := rec_sql.KUBE_TYPE_ID||'|'||rec_sql.TABLE_ID||'|'||replace(replace(replace(rec_sql.sql_stmt,'|',''),chr(10),''),chr(13),'');

       kbdx_kube_api_pkg.write (p_file_type => 'KBDX_TABLE_SQL', p_buffer => l_string);

 end loop;



  kbdx_kube_api_pkg.finish_kube(p_process_id => p_process_id, p_aol_owner => fnd_profile.value('PER_BUSINESS_GROUP_ID'));

  Exception
    When OTHERS Then
      l_error := substr(SQLERRM,1,2000);
      kbdx_kube_api_pkg.finish_kube(p_process_id  => p_process_id, p_message => l_error);

End main;

function g_start_date return varchar2 is

begin

 return to_char(gd_start_date,'DD-MON-YYYY');

end;

function g_end_date return varchar2 is

begin

 return to_char(gd_end_date,'DD-MON-YYYY');

end;

-- proc for ff
procedure sproc_get_ff(an_kube_type_id number)
is
  l_sql_string varchar2(32767);
  l_string varchar2(32767);

cursor get_kube_flexfields(p_kube_type_id number, p_bg_id number) Is
select t.table_id,d.app_table_cxt_id, d.app_table_name table_name, d.context,
       c.column_name client_link_column, d.client_dest_table_name,
       t.file_name source_table_name, d.flex_type, d.LEGISLATIVE_TABLE,d.flex_id_code,d.flex_application_id,d.business_group_id
--from kbace.kbdx_kube_columns c, kbace.kbdx_kube_tables t, kbace.kbdx_kube_flexfield_def d   --Commented code by MXKEERTHI-ARGANO, 05/04/2023  
from apps.kbdx_kube_columns c, APPS.kbdx_kube_tables t, APPS.kbdx_kube_flexfield_def d    --code Added  by MXKEERTHI-ARGANO, 05/04/2023
where d.kube_type_id = p_kube_type_id
and d.kube_type_id = t.kube_type_id
and c.column_id = d.CLIENT_LINK_COLUMN_ID
and t.table_id = d.CLIENT_SOURCE_TABLE_ID
and d.business_group_id = p_bg_id
union
select t.table_id,d.app_table_cxt_id, d.app_table_name table_name, d.context,
       c.column_name client_link_column, d.client_dest_table_name,
       t.file_name source_table_name, d.flex_type, d.LEGISLATIVE_TABLE,d.flex_id_code,d.flex_application_id,d.business_group_id
--from kbace.kbdx_kube_columns c, kbace.kbdx_kube_tables t, kbace.kbdx_kube_flexfield_def d   --Commented code by MXKEERTHI-ARGANO, 05/04/2023  
from APPS.kbdx_kube_columns c, APPS.kbdx_kube_tables t, APPS.kbdx_kube_flexfield_def d --code Added  by MXKEERTHI-ARGANO, 05/04/2023


where d.kube_type_id = p_kube_type_id
and d.kube_type_id = t.kube_type_id
and c.column_id = d.CLIENT_LINK_COLUMN_ID
and t.table_id = d.CLIENT_SOURCE_TABLE_ID
--     and (d.context  = (select legislation_code from per_business_groups where business_group_id = p_bg_id)
--     or  d.context  = 'Global Data Elements'
and ((d.legislative_table = 'Y'
     and d.context = (select legislation_code from per_business_groups where business_group_id = p_bg_id))
 or  (d.flex_type = 'D'
      and d.legislative_table ='N')
 or  (d.context  = (select rule_mode from pay_legislation_rules r, per_business_groups b
                    where b.business_group_id = p_bg_id
                    and r.legislation_code = b.legislation_code
                    and r.rule_type = 'S'))
 or flex_type = 'K' and d.business_group_id is null);

begin
 for rec in get_kube_flexfields(an_kube_type_id,fnd_profile.value('PER_BUSINESS_GROUP_ID')) loop

    If rec.flex_type = 'D' Then
      For i in  KBDX_KUBE_FF_UTILITIES.c_desc_flex_def (rec.table_name, rec.context,rec.flex_id_code,rec.flex_application_id) Loop

         --                   '|'||i.column_seq_num||
              l_string := an_kube_type_id||'|'||rec.table_id||
                   '|'||rec.table_name||'|'||'Descriptive'||'|'||rec.context||
                   '|'||i.application_column_name||
                   '|'||i.column_seq_num||
                   '|'||i.end_user_column_name||
                   '|'||i.required_flag||
                   '|'||i.display_flag;

        kbdx_kube_api_pkg.write (p_file_type => 'KB_FLEXFIELDS', p_buffer => l_string);
      end loop;
    else
      For i in  KBDX_KUBE_FF_UTILITIES.c_key_flex_def(rec.table_name, rec.context,rec.flex_id_code,rec.flex_application_id) Loop
         l_string := an_kube_type_id||'|'||rec.table_id||
                   '|'||rec.table_name||'|'||'Key'||'|'||rec.context||
                   '|'||i.application_column_name||
                   '|'||i.segment_num||
                   '|'||i.end_user_column_name||
                   '|'||i.required_flag||
                   '|'||i.display_flag;

        kbdx_kube_api_pkg.write (p_file_type => 'KB_FLEXFIELDS', p_buffer => l_string);
      end loop;
    end if;
  end loop;

end sproc_get_ff;
End kbdx_kube_sys_admin;
/
show errors;
/