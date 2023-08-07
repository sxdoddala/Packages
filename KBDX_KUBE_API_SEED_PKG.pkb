create or replace PACKAGE body kbdx_kube_api_seed_pkg AS
/*
 * $History: kbdx_kube_api_seed_pkg.pkb $
 *
 * *****************  Version 36  *****************
 * User: Jkeller      Date: 9/14/10    Time: 2:03p
 * Updated in $/KBX Kube Main/40_CODE_BASE/PATCH/4005.7
 * insert_column_mask
 *
 *   31  Jkeller      9/06/10    overload build_kube adding p_parameter_view
 *1.0	IXPRAVEEN(ARGANO)  16-May-2023		R12.2 Upgrade Remediation
 * See SourceSafe for addition comments
 *
*/
  --do not create duplicates
Procedure insert_column_mask(p_column_mask_rule_id in number,
                             p_column_name in varchar2) Is
Begin
  delete kbdx_column_masks where COLUMN_MASK_RULE_ID = p_column_mask_rule_id and upper(COLUMN_NAME) = upper(p_column_name);
  insert into kbdx_column_masks (COLUMN_MASK_RULE_ID,COLUMN_NAME) values(p_column_mask_rule_id,upper(p_column_name));
End insert_column_mask;
  --
  --do not create duplicates
Procedure insert_column_mask(p_column_mask_rule_id in number,
                             p_postload_name in varchar2,
                             p_column_name in varchar2) Is
Begin
  delete kbdx_column_masks_post where COLUMN_MASK_RULE_ID = p_column_mask_rule_id
     and upper(POSTLOAD_NAME) = upper(p_postload_name) and upper(COLUMN_NAME) = upper(p_column_name);
  insert into kbdx_column_masks_post (COLUMN_MASK_RULE_ID,POSTLOAD_NAME,COLUMN_NAME)
  values(p_column_mask_rule_id,upper(p_postload_name),upper(p_column_name));
End insert_column_mask;
  --
  --do not create duplicates
Procedure insert_column_mask(p_column_mask_rule_id in number,
                             p_kube_type in varchar2,
                             p_table_name in varchar2,
                             p_column_name in varchar2) Is
Begin
  delete kbdx_column_masks_late where COLUMN_MASK_RULE_ID = p_column_mask_rule_id
     and upper(KUBE_TYPE) = upper(p_kube_type) and upper(TABLE_NAME) = upper(p_table_name)
     and upper(COLUMN_NAME) = upper(p_column_name);
  insert into kbdx_column_masks_late (COLUMN_MASK_RULE_ID,KUBE_TYPE,TABLE_NAME,COLUMN_NAME)
  values(p_column_mask_rule_id,upper(p_kube_type),upper(p_table_name),upper(p_column_name));
End insert_column_mask;
  --
Procedure build_kube (p_kube_group in varchar2,
                      p_kube_type in varchar2,
                      p_kube_description in varchar2,
                      p_parameter_group in varchar2,
                      p_executable in varchar2,
                      p_parameter_view in varchar2,
                      p_update_prior_data in BOOLEAN DEFAULT TRUE,
                      p_kube_type_id in out number) Is
    --
Begin
  kbdx_kube_api_seed_pkg.build_kube (
                      p_kube_group => p_kube_group,
                      p_kube_type => p_kube_type,
                      p_kube_description => p_kube_description,
                      p_parameter_group => p_parameter_group,
                      p_executable => p_executable,
                      p_update_prior_data => p_update_prior_data,
                      p_kube_type_id => p_kube_type_id);
    --
  kbdx_kube_api_seed_pkg.assign_kube_parameter_view (p_kube_type_id, p_parameter_view);
    --
End build_kube;

Procedure build_kube (p_kube_group in varchar2,
                      p_kube_type in varchar2,
                      p_kube_description in varchar2,
                      p_parameter_group in varchar2,
                      p_executable in varchar2,
                      p_update_prior_data in BOOLEAN DEFAULT TRUE,
                      p_kube_type_id in out number) Is
l_worksheet_id number;
Begin

  kbdx_kube_seed_pkg.initialize(p_kube_group => p_kube_group,
                                p_kube_type  => p_kube_type,
                                p_kube_description => p_kube_description,
                                p_fnd_executable => 'KBDXUGEN',
                                p_parameter_group => p_parameter_group,
                                p_update_prior_info => TRUE,
                                p_kube_type_id => p_kube_type_id,
                                p_worksheet_id => l_worksheet_id);

  kbdx_kube_seed_pkg.build_templates_seed(p_kube_type_id => p_kube_type_id,
                                          p_worksheet_id =>l_worksheet_id);

  kbdx_kube_seed_pkg.create_executable(p_kube_type_id => p_kube_type_id,
                                       p_executable   => p_executable);

End build_kube;

Procedure create_static_table(p_table_name in varchar2, p_sql_stmt  in varchar2,
                              p_kube_type_id in number, p_table_structure in kbdx_kube_seed_pkg.column_tabtype) Is
l_table_id Number;
l_worksheet_id Number;
Begin
  kbdx_kube_seed_pkg.delete_table(p_kube_type_id => p_kube_type_id, p_table_name => p_table_name);
  l_worksheet_id := kbdx_kube_seed_pkg.get_worksheet_id (p_kube_type_id => p_kube_type_id);

  l_table_id := kbdx_kube_seed_pkg.insert_table (p_table_name => p_table_name , p_aol_owner_id => -999, p_table_type => 'STATIC',
                              p_sql_stmt => p_sql_stmt, p_plsql_dim_tab => NULL, p_dimension_sql_id => 2,
                              p_kube_type_id => p_kube_type_id, p_worksheet_id => l_worksheet_id,
                              p_columns => p_table_structure);
End create_static_table;

Procedure create_dimension_table(p_table_name in varchar2, p_sql_stmt  in varchar2,
                                 p_kube_type_id in number, p_plsql_tab in varchar2,
                                 p_table_structure in kbdx_kube_seed_pkg.column_tabtype) Is
l_table_id Number;
l_worksheet_id Number;
Begin
  /** Creates a dimension table that will process one row per dimension id **/
  kbdx_kube_seed_pkg.delete_table(p_kube_type_id => p_kube_type_id, p_table_name => p_table_name);
  l_worksheet_id := kbdx_kube_seed_pkg.get_worksheet_id (p_kube_type_id => p_kube_type_id);

  l_table_id := kbdx_kube_seed_pkg.insert_table (p_table_name => p_table_name, p_aol_owner_id => -999, p_table_type => 'DIM',
                              p_sql_stmt => p_sql_stmt, p_plsql_dim_tab => p_plsql_tab, p_dimension_sql_id => 1,
                              p_kube_type_id => p_kube_type_id, p_worksheet_id => l_worksheet_id,
                              p_columns => p_table_structure);
End create_dimension_table;

Procedure create_dimtab_multrows(p_table_name in varchar2, p_sql_stmt  in varchar2,
                                 p_kube_type_id in number, p_plsql_tab in varchar2,
                                 p_table_structure in kbdx_kube_seed_pkg.column_tabtype) Is
l_table_id Number;
l_worksheet_id Number;
Begin
  /** Creates a dimension table that will process multiple rows per dimension id if necessary **/
  kbdx_kube_seed_pkg.delete_table(p_kube_type_id => p_kube_type_id, p_table_name => p_table_name);
  l_worksheet_id := kbdx_kube_seed_pkg.get_worksheet_id (p_kube_type_id => p_kube_type_id);

  l_table_id := kbdx_kube_seed_pkg.insert_table (p_table_name => p_table_name, p_aol_owner_id => -999, p_table_type => 'DIM',
                              p_sql_stmt => p_sql_stmt, p_plsql_dim_tab => p_plsql_tab, p_dimension_sql_id => 5,
                              p_kube_type_id => p_kube_type_id, p_worksheet_id => l_worksheet_id,
                              p_columns => p_table_structure);
End create_dimtab_multrows;

Procedure create_dimtab_if_exists(p_table_name in varchar2, p_sql_stmt  in varchar2,
                                  p_kube_type_id in number, p_plsql_tab in varchar2,
                                  p_table_structure in kbdx_kube_seed_pkg.column_tabtype) Is
l_table_id Number;
l_worksheet_id Number;
Begin
  /** Creates a dimension table that will process one row per dimension id  - if dimension id has no data then NO record is written for
      that dimension id **/
  kbdx_kube_seed_pkg.delete_table(p_kube_type_id => p_kube_type_id, p_table_name => p_table_name);
  l_worksheet_id := kbdx_kube_seed_pkg.get_worksheet_id (p_kube_type_id => p_kube_type_id);

  l_table_id := kbdx_kube_seed_pkg.insert_table (p_table_name => p_table_name, p_aol_owner_id => -999, p_table_type => 'DIM',
                              p_sql_stmt => p_sql_stmt, p_plsql_dim_tab => p_plsql_tab, p_dimension_sql_id => 4,
                              p_kube_type_id => p_kube_type_id, p_worksheet_id => l_worksheet_id,
                              p_columns => p_table_structure);
End create_dimtab_if_exists;

Procedure create_fact_table(p_table_name in varchar2, p_kube_type_id in number,
                            p_table_structure in kbdx_kube_seed_pkg.column_tabtype) Is
l_table_id Number;
l_worksheet_id Number;
Begin

  kbdx_kube_seed_pkg.delete_table(p_kube_type_id => p_kube_type_id, p_table_name => p_table_name);
  l_worksheet_id := kbdx_kube_seed_pkg.get_worksheet_id (p_kube_type_id => p_kube_type_id);

  l_table_id := kbdx_kube_seed_pkg.insert_table (p_table_name => p_table_name, p_aol_owner_id => null, p_table_type => 'FACT',
                              p_sql_stmt => null, p_plsql_dim_tab => null, p_dimension_sql_id => null,
                              p_kube_type_id => p_kube_type_id, p_worksheet_id => l_worksheet_id,
                              p_columns => p_table_structure);
End create_fact_table;

Procedure create_user_fact_table(p_table_name in varchar2, p_kube_type_id in number,
                            p_table_structure in kbdx_kube_seed_pkg.column_tabtype) Is
l_table_id Number;
l_worksheet_id Number;
Begin

  kbdx_kube_seed_pkg.delete_table(p_kube_type_id => p_kube_type_id, p_table_name => p_table_name);
  l_worksheet_id := kbdx_kube_seed_pkg.get_worksheet_id (p_kube_type_id => p_kube_type_id);

  l_table_id := kbdx_kube_seed_pkg.insert_table (p_table_name => p_table_name, p_aol_owner_id => -888, p_table_type => 'FACT',
                              p_sql_stmt => null, p_plsql_dim_tab => null, p_dimension_sql_id => null,
                              p_kube_type_id => p_kube_type_id, p_worksheet_id => l_worksheet_id,
                              p_columns => p_table_structure);
End create_user_fact_table;

Procedure create_post_load (p_kube_type_id in number, p_stmt in varchar2,
                         p_name in varchar2, p_type in varchar2) Is
ln_sequence number;
Begin

  --select max(load_sequence) + 1 into ln_sequence from kbace.kbdx_kube_post_load		-- Commented code by IXPRAVEEN-ARGANO,16-May-2023	
  select max(load_sequence) + 1 into ln_sequence from apps.kbdx_kube_post_load          --  code Added by IXPRAVEEN-ARGANO,   16-May-2023
  where kube_type_id = p_kube_type_id;

  --insert into kbace.kbdx_kube_post_load			-- Commented code by IXPRAVEEN-ARGANO,16-May-2023
  insert into apps.kbdx_kube_post_load              --  code Added by IXPRAVEEN-ARGANO,   16-May-2023
(kube_type_id,sql_stmt,load_sequence,name,type)
  values (p_kube_type_id, p_stmt,nvl(ln_sequence,1),p_name,p_type);

End      create_post_load;

Procedure create_post_load(p_kube_type_id in Number,
                           p_post_load_stmt in Varchar2,
                           p_load_sequence in Number,
                           p_post_load_name in varchar2,
                           p_post_load_type in Varchar2) Is
Begin

  --insert into kbace.kbdx_kube_post_load(kube_type_id,sql_stmt,load_sequence,name,type)				-- Commented code by IXPRAVEEN-ARGANO,16-May-2023
  insert into apps.kbdx_kube_post_load(kube_type_id,sql_stmt,load_sequence,name,type)                  --  code Added by IXPRAVEEN-ARGANO,   16-May-2023
  values (p_kube_type_id,p_post_load_stmt,p_load_sequence,p_post_load_name,p_post_load_type);
End create_post_load;


Procedure insert_kube_sql_parameters(p_kube_type_id in number, p_parameter_name in varchar2,
                                     p_source_table in varchar2, p_source_alias in varchar2,
                                     p_parameter_table in varchar2, p_parameter_alias in varchar2,
                                     p_source_column in varchar2, p_parameter_column1 in varchar2,
                                     p_parameter_column2 in varchar2 default null,
                                     p_operator in varchar2,p_context in varchar2 default null,
                                     p_context_usage in varchar2 default null,
                                     p_dynamic_add in varchar2 default null) Is
l_parameter_id Number;
Begin
  Begin
    select parameter_id into l_parameter_id from kbdx_kube_parameters where parameter_name = p_parameter_name;
    Exception
      When NO_DATA_FOUND Then
        raise_application_error (-20001,'ERROR: Parameter '||p_parameter_name||' not defined');
      When TOO_MANY_ROWS Then
        raise_application_error (-20002,'ERROR: Parameter '||p_parameter_name||' not defined properly');
  End;
  delete from kbdx_kube_sql_parameters where kube_type_id = p_kube_type_id and parameter_id = l_parameter_id;

  kbdx_kube_seed_pkg.insert_kube_sql_parameters(p_kube_type_id => p_kube_type_id, p_parameter_name => p_parameter_name ,
                                     p_source_table => p_source_table , p_source_alias => p_source_alias ,
                                     p_parameter_table => p_parameter_table , p_parameter_alias => p_parameter_alias ,
                                     p_source_column => p_source_column , p_parameter_column1 => p_parameter_column1 ,
                                     p_parameter_column2 => p_parameter_column2 ,
                                     p_operator => p_operator , p_context => p_context ,
                                     p_context_usage => p_context_usage ,
                                     p_dynamic_add => p_dynamic_add );
End insert_kube_sql_parameters;


Function create_kube_group(p_kube_group in varchar2, p_kube_description in varchar2) Return Number Is
x Number;
Begin
  x := kbdx_kube_seed_pkg.create_kube_group(p_kube_group => p_kube_group, p_kube_description => p_kube_description);
  return x;
End create_kube_group;


procedure proc_select_all_dim_table(   p_oracle_table_name varchar2,
                                       p_kb_table_name varchar2 default null,
                                       p_kube_type_id number,
                                       p_plsql_tab  varchar2,
                                       p_select_column varchar2,
                                       p_execption_1 varchar2 default null,
                                       p_execption_2 varchar2 default null,
                                       p_multi_or_single varchar2 default 'S',
                                       p_table_owner varchar2 default null,
                                       p_data_filter varchar2 default null,
                                       p_load_columns varchar2 default null,
                                       p_load_arrays  varchar2 default null,
                                       p_load_data_types varchar2 default null,
                                       p_who_columns varchar2 default 'N')
as

begin

KBDX_KUBE_ORACLE_UTILS.proc_select_all_dim_table(av_oracle_table_name  => p_oracle_table_name,
                                       av_kb_table_name => p_kb_table_name,
                                       an_kube_type_id => p_kube_type_id,
                                       p_plsql_tab => p_plsql_tab,
                                       p_select_column => p_select_column,
                                       av_execption_1 => p_execption_1,
                                       av_execption_2 => p_execption_2,
                                       av_multi_or_single => p_multi_or_single,
                                       av_table_owner => p_table_owner,
                                       av_data_filter => p_data_filter,
                                       p_load_columns => p_load_columns,
                                       p_load_arrays => p_load_arrays,
                                       p_load_data_types => p_load_data_types,
                                       av_who_columns => p_who_columns);

end proc_select_all_dim_table;

procedure proc_select_all_static_table(p_oracle_table_name varchar2,
                p_kb_table_name varchar2 default null,
                p_kube_type_id number,
                p_execption_1 varchar2 default null,
                p_execption_2 varchar2 default null,
                p_table_owner varchar2 default null,
                p_data_filter varchar2 default null,
                p_who_columns varchar2 default 'N')
as

begin

KBDX_KUBE_ORACLE_UTILS.proc_select_all_static_table(av_oracle_table_name  => p_oracle_table_name,
                av_kb_table_name  => p_kb_table_name,
                an_kube_type_id  => p_kube_type_id,
                av_execption_1  => p_execption_1,
                av_execption_2  => p_execption_2,
                av_table_owner  => p_table_owner,
                av_data_filter  => p_data_filter,
                av_who_columns => p_who_columns);

end proc_select_all_static_table;


-- *************************************************
procedure proc_dff_for_table(p_oracle_table_name varchar2,
                             p_table_application varchar2 default null,
                             p_flex_application  in varchar2 default null,
                             p_id_flex_code in varchar2 default null,
                             p_kb_table_name varchar2 default null,
                             P_kube_type_id number,
                             p_plsql_tab  varchar2,
                             p_select_column varchar2,
                             p_addl_cols in varchar2 default null,
                             p_data_filter in varchar2 default null)
as
ln_number number;

cursor lcur_test_for_dff(av_oracle_table_name varchar2,av_table_application varchar2,av_flex_application varchar2)
is select descriptive_flex_context_code,b.application_table_name
 from FND_DESCR_FLEX_CONTEXTS a,FND_DESCRIPTIVE_FLEXS b,fnd_application fa
where fa.application_short_name in (av_table_application,av_flex_application)
and fa.application_id = b.application_id
and b.application_table_name = av_oracle_table_name
and b.freeze_flex_definition_flag = 'Y'
and a.application_id = b.application_id
and a.descriptive_flexfield_name = b.descriptive_flexfield_name
and enabled_flag = 'Y';

begin

 for rec in lcur_test_for_dff(p_oracle_table_name,p_table_application,p_flex_application) loop

  ln_number := KBDX_KUBE_FF_UTILITIES.build_ff_tables (
                           p_app_table => p_oracle_table_name,
                           p_client_table => p_kb_table_name ,
                           p_kube_type_id => p_kube_type_id,
                           p_flex_type => 'D',
                           p_source_column => p_select_column,
                           p_id_flex_code => rec.descriptive_flex_context_code,
                           p_flex_application => p_flex_application,
                           p_addl_cols => p_addl_cols,
                           p_plsql_tab => p_plsql_tab,
                           p_data_filter => p_data_filter,
                           p_table_application => p_table_application);
 end loop;

end proc_dff_for_table;


Procedure assign_kube_parameter_view (p_kube_type_id in number,
                                      p_view_name in varchar2) Is
Begin

  delete from kbdx_kube_parameter_views where kube_type_id = p_kube_type_id;
  insert into kbdx_kube_parameter_views (kube_type_id,parameter_view)
  values (p_kube_type_id, p_view_name);

End assign_kube_parameter_view;

End kbdx_kube_api_seed_pkg;
/
show errors;
/