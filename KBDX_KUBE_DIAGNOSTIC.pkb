create or replace Package Body kbdx_kube_diagnostic
 AS
/*
 * $History: kbdx_kube_diagnostic.pkb $
 *
 * *****************  Version 17  *****************
 * User: Jkeller      Date: 2/08/10    Time: 12:40p
 * Updated in $/KBX Kube Main/40_CODE_BASE/datasets/Diagnostic Kube
 * corrected rule hint
 *
 *   14  Jkeller      6/16/09    mod
 *
 * See SourceSafe for addition comments
    Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
    IXPRAVEEN(ARGANO)            1.0     11-May-2023     R12.2 Upgrade Remediation
 *	
*/
procedure proc_select_all_static_table(av_oracle_table_name varchar2,
                                       av_kb_table_name varchar2 default null,
                                       an_kube_type_id number,
                                       av_execption_1 varchar2 default null,
                                       av_execption_2 varchar2 default null)
as

cursor lcur_columns(av_table_name varchar2,cav_execption_1 varchar2)
is select /*+ RULE */ column_name,
   upper(data_type) kbx_data_type,
   Initcap(replace(replace(replace(column_name,'?',''),'''',''),'"','')) kbx_column
from all_tab_columns
where upper(table_name) = upper(av_oracle_table_name)
and   upper(column_name) <> nvl(upper(cav_execption_1),'x')
order by COLUMN_ID;

ln_counter number;
l_sql Varchar2(32000);
l_column_string varchar2(32000);
kube_tab kbdx_kube_seed_pkg.column_tabtype;

begin

  kube_tab.delete;
  ln_counter := 0;
  for rec in lcur_columns(av_oracle_table_name,av_execption_1) loop
    --dbms_output.put_line('coLUMN: '||rec.column_name);
    ln_counter := ln_counter + 1;
    if ln_counter = 1 then
        l_column_string := rec.column_name ;
    else
        l_column_string := l_column_string ||'||''|''||'|| rec.column_name ;
    end if;

    kube_tab(ln_counter).name := rec.kbx_column;

    if rec.kbx_data_type = 'DATE' THEN
       kube_tab(ln_counter).DATA_TYPE :=  'DATE';
    ELSIF rec.kbx_data_type = 'VARCHAR2' OR rec.kbx_data_type = 'CHAR' THEN
         kube_tab(ln_counter).DATA_TYPE :=  'TEXT';
    ELSIF SUBSTR(rec.column_name,-3) = '_ID' and rec.kbx_data_type = 'NUMBER' THEN
         kube_tab(ln_counter).DATA_TYPE :=  'LONG';
    ELSIF rec.kbx_data_type = 'NUMBER' THEN
         kube_tab(ln_counter).DATA_TYPE :=  'NUMBER';
    ELSE
         kube_tab(ln_counter).DATA_TYPE :=  'TEXT';
    END IF;
 end loop;

 l_sql := 'select '||l_column_string||' data From '||av_oracle_table_name;

  --dbms_output.put_line('sql: '||substr(l_sql,1,200));

 kbdx_kube_api_seed_pkg.create_static_table(
                              p_table_name => nvl(av_kb_table_name,av_oracle_table_name),
                              p_sql_stmt  => l_sql,
                              p_kube_type_id => an_kube_type_id,
                              p_table_structure => kube_tab);


/*
  lproc_select_all_static_table(av_oracle_table_name => '',
                                av_kb_table_name => '',
                                an_kube_type_id =>l_kube_type_id);
                                */

end proc_select_all_static_table;

Procedure main(p_process_id in number) Is
  l_kube_type_id number := 0;

  l_sql_string varchar2(32767);
  l_from varchar2(32767);
  l_where varchar2(32767);
  l_string varchar2(32767);
  l_error varchar2(32767);


cursor get_kube_flexfields(p_kube_type_id number, p_bg_id number) Is
select d.app_table_cxt_id, d.app_table_name table_name, d.context,
       c.column_name client_link_column, d.client_dest_table_name,
       t.file_name source_table_name, d.flex_type, d.LEGISLATIVE_TABLE,t.table_id						-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
--from kbace.kbdx_kube_columns c, kbace.kbdx_kube_tables t, kbace.kbdx_kube_flexfield_def d             --  code Added by IXPRAVEEN-ARGANO,   11-May-2023
from apps.kbdx_kube_columns c, apps.kbdx_kube_tables t, apps.kbdx_kube_flexfield_def d
where d.kube_type_id = p_kube_type_id
and d.kube_type_id = t.kube_type_id
and c.column_id = d.CLIENT_LINK_COLUMN_ID
and t.table_id = d.CLIENT_SOURCE_TABLE_ID
and d.business_group_id = p_bg_id
union
select d.app_table_cxt_id, d.app_table_name table_name, d.context,
       c.column_name client_link_column, d.client_dest_table_name,
       t.file_name source_table_name, d.flex_type, d.LEGISLATIVE_TABLE,t.table_id
--from kbace.kbdx_kube_columns c, kbace.kbdx_kube_tables t, kbace.kbdx_kube_flexfield_def d					-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
from apps.kbdx_kube_columns c, apps.kbdx_kube_tables t, apps.kbdx_kube_flexfield_def d                   --  code Added by IXPRAVEEN-ARGANO,   11-May-2023
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
                    and r.rule_type = 'S')));

cursor get_kubes
is select kube_type_id from kbdx_kube_types;

Begin

  l_kube_type_id := kbdx_kube_api_pkg.initialize_kube(
                   p_process_id => p_process_id,
                   p_aol_owner => fnd_profile.value('PER_BUSINESS_GROUP_ID'));

  for rec_kubes in get_kubes loop

     for rec in get_kube_flexfields(rec_kubes.kube_type_id,fnd_profile.value('PER_BUSINESS_GROUP_ID')) loop

    If rec.flex_type = 'D' Then
      For i in  kbdx_kube_utilities.c_desc_flex_def (rec.table_name, rec.context) Loop

         --                   '|'||i.column_seq_num||
              l_string := rec_kubes.kube_type_id||'|'||rec.table_id||
                   '|'||rec.table_name||'|'||'Descriptive'||'|'||rec.context||
                   '|'||i.application_column_name||
                   '|'||i.column_seq_num||
                   '|'||i.end_user_column_name||
                   '|'||i.required_flag||
                   '|'||i.display_flag;

        kbdx_kube_api_pkg.write (p_file_type => 'KB_FLEXFIELDS', p_buffer => l_string);
      end loop;
    else
      For i in  kbdx_kube_utilities.c_key_flex_def(rec.table_name, rec.context) Loop
         l_string := rec_kubes.kube_type_id||'|'||rec.table_id||
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
end loop;

  kbdx_kube_api_pkg.finish_kube(p_process_id => p_process_id, p_aol_owner => fnd_profile.value('PER_BUSINESS_GROUP_ID'));

  Exception
    When OTHERS Then
      l_error := substr(SQLERRM,1,2000);
      kbdx_kube_api_pkg.finish_kube(p_process_id  => p_process_id, p_message => l_error);

End main;
End kbdx_kube_diagnostic;
/
show errors;
/