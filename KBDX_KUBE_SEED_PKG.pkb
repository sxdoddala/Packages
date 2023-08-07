create or replace Package Body KBDX_KUBE_SEED_PKG
 As
/*
 * $History: kbdx_kube_seed_pkg.pkb $
 *
 * *****************  Version 61  *****************
 * User: Jkeller      Date: 1/08/11    Time: 3:36p
 * Updated in $/KBX Kube Main/40_CODE_BASE/PATCH/4005.7
 * delete previous post loads
 *
 *    57  Uaudi        9/10/10    update_prior_info
 *    55  Uaudi        9/09/10    added post_load to update_prior_info
 *    53  Jkeller      5/08/10    insert_table fetch worksheet_id if null
 *    48  Jkeller     10/28/09    update_prior_info
 *1.0	IXPRAVEEN(ARGANO)  14-july-2023		R12.2 Upgrade Remediation
 * See SourceSafe for addition comments
 *
*/
  --
function fix_name_for_access(v_object_name varchar2) return varchar2 is
l_return_val varchar2(64);
begin
 l_return_val := replace(replace(replace(replace(replace(replace(replace(replace(v_object_name,'.',''),'`',''),'!',''),'[',''),']',''),'"',''),'|',''),'$','');
 return l_return_val;
end;
  --
Procedure insert_kube_sql_parameters(p_kube_type_id in number, p_parameter_name in varchar2,
                                     p_source_table in varchar2, p_source_alias in varchar2,
                                     p_parameter_table in varchar2, p_parameter_alias in varchar2,
                                     p_source_column in varchar2, p_parameter_column1 in varchar2,
                                     p_parameter_column2 in varchar2 default null,
                                     p_operator in varchar2,p_context in varchar2 default null,
                                     p_context_usage in varchar2 default null,
                                     p_dynamic_add in varchar2 default null) Is
l_parameter_id number;
l_dynamic_add varchar2(1);
l_cxt_usage_id Number;
Begin
  select parameter_id into l_parameter_id
  from kbdx_kube_parameters
  where parameter_name = p_parameter_name;

  If p_dynamic_add = 'Y' Then
    l_dynamic_add := NULL;
  Else l_dynamic_add := p_dynamic_add;
  End If;

  If p_context is not NULL Then
    select context_usage_id into l_cxt_usage_id
    from kbdx_kube_context_usages u, kbdx_kube_contexts c
    where c.context_name = p_context
    and u.context_id = c.context_id
    and u.description = p_context_usage;
  End If;

   insert into kbdx_kube_sql_parameters (kube_type_id,parameter_id,source_table,source_alias,parameter_table,
                                         parameter_alias,source_column,parameter_column1,parameter_column2,
                                         operator,context_usage_id,dynamic_add,cursor_id)
   values(p_kube_type_id,l_parameter_id,p_source_table,p_source_alias,p_parameter_table,p_parameter_alias,
          p_source_column,p_parameter_column1,p_parameter_column2,p_operator,l_cxt_usage_id,l_dynamic_add,1);

End insert_kube_sql_parameters;

Function get_worksheet_id (p_kube_type_id in Number) Return Number Is
l_ws_id number;
Begin
  select w.worksheet_id into l_ws_id
  From kbdx_worksheets w, kbdx_datasets d, kbdx_kube_types t
  where d.process_type = t.kube_type
  and w.dataset_id = d.dataset_id
  and t.kube_type_id = p_kube_type_id;

  return l_ws_id;
End get_worksheet_id;

Procedure delete_table(p_kube_type_id in number, p_table_name in varchar2) Is
l_kube_type kbdx_kube_types.kube_type%type;
l_tab_id Number;
  Begin
    Begin
      select table_id into l_tab_id
      from kbdx_kube_tables
      where file_name = p_table_name
      and kube_type_id = p_kube_type_id;
     Exception
       When NO_DATA_FOUND Then
         return;
       When OTHERS Then
         raise;
    End;

  select kube_type into l_kube_type from kbdx_kube_types where kube_type_id = p_kube_type_id;

  delete from kbdx_kube_columns where table_id = l_tab_id;

  delete from kbdx_kube_tables where file_name = p_table_name and kube_type_id = p_kube_type_id;
  delete from kbdx_file_definitions where file_name = p_table_name and process_type = l_kube_type;

  delete from kbdx_kube_flexfield_columns
    where app_table_cxt_id in (select app_table_cxt_id from kbdx_kube_flexfield_def
                               where kube_type_id = p_kube_type_id
                               and client_source_table_id = l_tab_id);

  delete from kbdx_kube_flexfield_def
  where kube_type_id = p_kube_type_id
    and client_source_table_id = l_tab_id;
End delete_table;

Procedure create_executable(p_kube_type_id in number, p_executable in varchar2) Is
Begin
  insert into kbdx_kube_executables (kube_type_id, executable_name)
  values (p_kube_type_id, p_executable);
End create_executable;


Procedure store_addl_ff_columns (p_cxt_id in number, p_source_column in varchar2,
                                 p_source_table in varchar2, p_kube_type_id in number,
                                 p_sequence in number) Is
--l_column_id number;
Begin
kbdx_kube_ff_utilities.store_addl_ff_columns (p_cxt_id => p_cxt_id, p_source_column => p_source_column,
                                 p_source_table => p_source_table, p_kube_type_id => p_kube_type_id,
                                 p_sequence => p_sequence);
/*
  select c.column_id into  l_column_id
  from kbdx_kube_columns c, kbdx_kube_tables t
  where c.table_id = t.table_id
  and t.file_name = p_source_table
  and c.column_name = p_source_column
  and t.kube_type_id = p_kube_type_id;

  insert into kbace.kbdx_kube_flexfield_columns (app_table_cxt_id, column_id, column_sequence)
  values (p_cxt_id, l_column_id, p_sequence); */
End   store_addl_ff_columns;

Function build_ff_tables (p_app_table in varchar2, p_source_table in varchar2 default null, p_client_table in varchar2,
                          p_source_column in varchar2 default null, p_context in varchar2 default null, p_kube_type_id in number,
                          p_flex_type in varchar2, p_bg_id in number default null,p_id_flex_code in varchar2 default null,
                          p_flex_application in varchar2 default null,p_addl_cols in varchar2 default null,
                          p_context_query in varchar2 default null,p_plsql_tab in varchar2 default null,
                          p_data_filter in varchar2 default null) Return Number Is
l_cxt_id Number;

begin
l_cxt_id := kbdx_kube_ff_utilities.build_ff_tables (p_app_table => p_app_table, p_source_table => p_source_table, p_client_table => p_client_table,
                          p_source_column => p_source_column, p_context => p_context, p_kube_type_id => p_kube_type_id,
                          p_flex_type => p_flex_type, p_bg_id => p_bg_id,p_id_flex_code => p_id_flex_code,
                          p_flex_application => p_flex_application,p_addl_cols => p_addl_cols,
                          p_context_query => p_context_query,p_plsql_tab => p_plsql_tab,
                          p_data_filter => p_data_filter);
return l_cxt_id;
end build_ff_tables;

  --JAK 05/05/2010 if called with null p_worksheet_id then fetch worksheet_id
Function insert_table (p_table_name in varchar2,
                       p_aol_owner_id in number,
                       p_table_type in varchar2,
                       p_sql_stmt in varchar2,
                       p_plsql_dim_tab in varchar2,
                       p_dimension_sql_id in number,
                       p_kube_type_id in number,
                       p_worksheet_id in number,
                       p_columns in column_tabtype ) Return Number Is
l_table_id Number;
l_kube_type kbdx_kube_types.kube_type%type;
l_table_name varchar2(64);
l_worksheet_id Number;

Begin
  l_table_name := fix_name_for_access(p_table_name);
  select kube_type into l_kube_type from kbdx_kube_types where kube_type_id = p_kube_type_id;
  select kbdx_kube_tables_s .nextval into l_table_id from dual;
  If nvl(p_worksheet_id,0) = 0 then
    l_worksheet_id := get_worksheet_id(p_kube_type_id => p_kube_type_id);
  Else
    l_worksheet_id := p_worksheet_id;
  End if;

  INSERT INTO kbdx_kube_tables(TABLE_ID,KUBE_TYPE_ID,COLUMN_STRUCT_ID,PROCESS_TYPE,FILE_NAME,TABLE_TYPE,
                               PLSQL_DIM_TAB,SQL_STMT,DIMENSION_SQL_ID)
  VALUES(l_table_id,p_kube_type_id,1,l_kube_type,l_table_name,p_table_type,p_plsql_dim_tab,p_sql_stmt,p_dimension_sql_id);

  INSERT INTO kbdx_file_definitions
  (PROCESS_TYPE,FILE_NAME,WORKSHEET_ID,FILE_SEQUENCE,FILE_TYPE,AOL_OWNER_ID,MAX_FILE_SIZE)
  VALUES (l_kube_type,l_table_name,l_worksheet_id,1,p_table_name,p_aol_owner_id,999999999999);

  For i in 1 .. nvl(p_columns.Last,0) Loop
    kbdx_kube_seed_pkg.insert_columns(p_column_struct_id => 1,
                                      p_skeleton_id => 1,
                                      p_table_id => l_table_id,
                                      p_column_name => p_columns(i).name,
                                      p_column_sequence => i,
                                      p_data_type =>p_columns(i).data_type );
  End Loop;

  return l_table_id;

End insert_table;

Procedure insert_columns(p_column_struct_id in Number,
                         p_skeleton_id in Number,
                         p_column_name In Varchar2,
                         p_column_sequence in Number,
                         p_table_id in Number,
                         p_data_type in varchar2) Is
l_column_name varchar2(64);
Begin

  l_column_name := fix_name_for_access(p_column_name);
  insert into kbdx_kube_columns(column_id,column_struct_id,skeleton_id,column_name,column_sequence,table_id,data_type)
  values (kbdx_kube_columns_s.nextval,p_column_struct_id,p_skeleton_id,l_column_name,p_column_sequence,p_table_id, p_data_type);

End insert_columns;

Function create_kube_group(p_kube_group in varchar2,
                           p_kube_description in varchar2) Return Number Is
l_kg_id Number;

Begin
  Begin
    select kube_group_id into l_kg_id
    from kbdx_kube_type_groups
    where kube_group_name = p_kube_group;

    Exception
      When NO_DATA_FOUND Then
        l_kg_id := NULL;
      When OTHERS Then
        raise_application_error(-20009,'CREATE_KUBE_GROUP_ERROR : SQLCODE - '||SQLCODE);
  End;

  If l_kg_id is NULL Then
      select kbdx_kube_type_groups_s.nextval into l_kg_id from dual;
      Insert into kbdx_kube_type_groups (kube_group_name,kube_group_id,description)
      values (p_kube_group, l_kg_id, p_kube_description);
  End If;
  return l_kg_id;

Exception
  When OTHERS Then
    raise_application_error(-20010,'CREATE_KUBE_GROUP_ERROR : SQLCODE - '||SQLCODE);
End create_kube_group;

Function get_kube_group(p_kube_group in varchar2) Return Number Is
l_kg_id Number;

Begin
  select kube_group_id into l_kg_id
  from kbdx_kube_Type_groups
  where kube_group_name = p_kube_group;

  return l_kg_id;
End get_kube_group;

Procedure update_prior_info(p_kube_type in varchar2, p_kube_type_id in number) Is
 l_prior_kube_type_id Number := NULL;
Begin
  Begin
    select kube_type_id into l_prior_kube_type_id
    from kbdx_kube_types
    where kube_type = p_kube_type;
  Exception
    When OTHERS Then
      RETURN;
  End;
      --
  If l_prior_kube_type_id is not null Then
    update kbdx_kube_sql_parameters set kube_Type_id = p_kube_type_id
    where kube_Type_id=  l_prior_kube_type_id;
      --
    update kbdx_kube_assigned_resps set kube_type_id = p_kube_type_id
    where kube_Type_id=  l_prior_kube_type_id;
      --
    update kbdx_processes set parameter4 = to_char(p_kube_type_id), parameter2 = to_char(p_kube_type_id)
    where parameter4 = to_char(l_prior_kube_type_id) and parameter2 = to_char(l_prior_kube_type_id)
    and process_type = p_kube_type;
      --
    update kbdx_kube_containers set kube_type_id = p_kube_type_id
    where kube_type_id = l_prior_kube_type_id;
      --
    update kbdx_kube_parameter_views set kube_type_id = p_kube_type_id
    where kube_type_id = l_prior_kube_type_id;
      --
      -- Uaudi 09/10/10 since postloads maybe removed by the install of a Kube, we need to make sure
      -- the old ones no longer exist. By not preserving the postloads, we assure the old ones are removed.
      --
    delete from kbdx_kube_post_load where kube_type_id = l_prior_kube_type_id;
      --
  End If;
End update_prior_info;
  --
Procedure initialize(p_kube_group in varchar2,
                     p_kube_type in varchar2,
                     p_kube_description in varchar2,
                     p_fnd_executable in varchar2,
                     p_parameter_group in varchar2 default null,
                     p_update_prior_info in BOOLEAN Default FALSE,
                     p_kube_type_id out number,
                     p_worksheet_id out number) Is

 cursor get_existing_columns (p_kube_type varchar2, p_kube_version number) is
 select C.column_id from kbdx_kube_columns c, kbdx_kube_tables t, kbdx_kube_types k
 where c.table_id = t.table_id
 and t.kube_type_id = k.kube_type_id
 and k.kube_type  = p_kube_type
 and k.kube_version = p_kube_version;
   --
 cursor get_existing_tables (p_kube_type varchar2, p_kube_version number) is
 select t.table_id from kbdx_kube_tables t, kbdx_kube_types k
 where t.kube_type_id = k.kube_type_id
 and k.kube_type  = p_kube_type
 and k.kube_version = p_kube_version;
   --
 l_max_table Number;
 l_work_table Number := 0;
 l_kg_id Number;
 l_pg_id Number;
 l_kube_type_id Number;
 l_skeleton_id Number;
 l_template_group_id Number;
 l_dataset_id Number;
 l_worksheet_id Number;
 l_max_dataset_id Number;
 l_max_ws_id Number;
 l_prior_dataset_id Number;
Begin
      --
  l_kg_id := get_kube_group(p_kube_group);
      --
  For i in get_existing_columns(p_kube_type, 1) Loop
    delete from kbdx_kube_columns where column_id = i.column_id;
    delete from kbdx_kube_column_security where column_id = i.column_id;
  End Loop;
  For i in get_existing_tables(p_kube_type,1 ) Loop
    delete from kbdx_kube_tables where table_id = i.table_id;
  End Loop;
    --
  Begin
    select dataset_id into l_prior_dataset_id
    from kbdx_datasets
    where process_type = p_kube_type;
  Exception
    When OTHERS Then
      l_prior_dataset_id := 0;
  End;
    -- JAK 01/08/2011
  --delete from kbace.kbdx_kube_post_load where kube_type_id in (			-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
  delete from apps.kbdx_kube_post_load where kube_type_id in (              --  code Added by IXPRAVEEN-ARGANO,   14-july-2023
    select kube_type_id from kbdx_kube_types where kube_type = p_kube_type);
    --
  delete from kbdx_datasets where DATASET_DESCRIPTION = p_kube_type;
  delete from kbdx_datasets where process_type = p_kube_type;
  delete from kbdx_worksheets where name = p_kube_type;
  delete from kbdx_file_definitions where PROCESS_TYPE = p_kube_type;
  --delete from kbace.kbdx_kube_flexfield_def where kube_type_id in (			-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
  delete from apps.kbdx_kube_flexfield_def where kube_type_id in (             --  code Added by IXPRAVEEN-ARGANO,   14-july-2023
    select kube_type_id from kbdx_kube_types where kube_type = p_kube_type);
    --
  select kbdx_kube_types_s.nextval into l_kube_type_id from dual;
  If p_update_prior_info Then
    update_prior_info(p_kube_type, l_kube_type_id);
  Else  delete from kbdx_kube_assigned_resps where kube_type_id in (
        select kube_type_id from kbdx_kube_types where kube_type = p_kube_type);
  End If;
    --
  delete from kbdx_kube_executables where kube_type_id in (
    select kube_type_id from kbdx_kube_types where kube_type = p_kube_type);
  delete from kbdx_kube_types where kube_type = p_kube_type;
  select kbdx_kube_skeletons_s.nextval into l_skeleton_id from dual;
  select kbdx_template_groups_s.nextval into l_template_group_id from dual;
  select max(dataset_id) into l_max_dataset_id from kbdx_datasets;
  select kbdx_datasets_seq.nextval into l_dataset_id from dual;
  If  l_dataset_id <= l_max_dataset_id Then
    Loop
      Exit When l_dataset_id > l_max_dataset_id;
      select kbdx_datasets_seq.nextval into l_dataset_id from dual;
    End Loop;
  End If;
    --
  select min(worksheet_id) into l_max_ws_id from kbdx_worksheets;
  select KBDX_WORKSHEET_SEQ.nextval into l_worksheet_id from dual;
  If  l_worksheet_id >= l_max_ws_id Then
    Loop
      Exit When l_worksheet_id < l_max_ws_id;
      select KBDX_WORKSHEET_SEQ.nextval into l_worksheet_id from dual;
    End Loop;
  End If;
    --
  If p_parameter_group is not NULL Then
    select distinct parameter_group_id  into l_pg_id
    from kbdx_kube_parameter_groups
    where parameter_group_name = p_parameter_group;
  Else l_pg_id := NULL;
  End If;
    --
  INSERT INTO kbdx_kube_types (KUBE_TYPE_ID,KUBE_VERSION,KUBE_TYPE,KUBE_DESCRIPTION,kube_group_id,parameter_group_id)
   VALUES (l_kube_type_id,1,p_kube_type,p_kube_description,l_kg_id,l_pg_id);
    --
  INSERT INTO kbdx_kube_skeletons (skeleton_id, KUBE_TYPE_ID,template_group_id)
   VALUES (l_skeleton_id,l_kube_type_id,l_template_group_id);
    --KBDXUGEN
  INSERT INTO kbdx_datasets (DATASET_ID,DATASET_DESCRIPTION,CONCURRENT_PROGRAM_NAME,
                             AOL_OWNER_ID,PROCESS_TYPE,ENABLED_FLAG)
   VALUES  (l_dataset_id,p_kube_type,p_fnd_executable,NULL,p_kube_type,'Y');
    --
  INSERT INTO kbdx_worksheets (WORKSHEET_ID,DATASET_ID,NAME,TYPE,AOL_SETUP_GROUP)
   VALUES (l_worksheet_id,l_dataset_id,p_kube_type,'raw','0');
    --
  KBDX_KUBE_LOAD_SEED_DATA.add_kb_vs_info(l_kube_type_id);
  p_worksheet_id := l_worksheet_id;
  p_kube_type_id := l_kube_type_id;
    --
  If l_prior_dataset_id <> 0 then
    update kbdx_drill_downs set dataset_id = l_dataset_id
     where dataset_id = l_prior_dataset_id;
  End If;
    --
End Initialize;
  --
Procedure initialize(p_kube_group in varchar2,
                     p_kube_type in varchar2,
                     p_kube_description in varchar2,
                     p_fnd_executable in varchar2,
                     p_kbdx_executable in varchar2,
                     p_parameter_group in varchar2 default null,
                     p_update_prior_info in BOOLEAN Default FALSE,
                     p_kube_type_id out number,
                     p_worksheet_id out number) Is
  --
cursor get_existing_columns (p_kube_type varchar2, p_kube_version number) is
select C.column_id from kbdx_kube_columns c, kbdx_kube_tables t, kbdx_kube_types k
where c.table_id = t.table_id
and t.kube_type_id = k.kube_type_id
and k.kube_type  =p_kube_type
and k.kube_version = p_kube_version;
  --
cursor get_existing_tables (p_kube_type varchar2, p_kube_version number) is
select t.table_id from kbdx_kube_tables t, kbdx_kube_types k
where t.kube_type_id = k.kube_type_id
and k.kube_type  =p_kube_type
and k.kube_version = p_kube_version;
  --
  l_max_table Number;
  l_work_table Number := 0;
  l_kg_id Number;
  l_pg_id Number;
  l_kube_type_id Number;
  l_skeleton_id Number;
  l_template_group_id Number;
  l_dataset_id Number;
  l_worksheet_id Number;
  l_max_dataset_id Number;
  l_max_ws_id Number;
  l_prior_dataset_id Number;
Begin
    --
  l_kg_id := get_kube_group(p_kube_group);
    --
  For i in get_existing_columns(p_kube_type, 1) Loop
    delete from kbdx_kube_columns where column_id = i.column_id;
    delete from kbdx_kube_column_security where column_id = i.column_id;
  End Loop;
    --
  For i in get_existing_tables(p_kube_type,1 ) Loop
    delete from kbdx_kube_tables where table_id = i.table_id;
  End Loop;
    --
  Begin
    select dataset_id into l_prior_dataset_id
    from kbdx_datasets
    where process_type = p_kube_type;
  Exception
    When OTHERS Then
      l_prior_dataset_id := 0;
  End;
    --
  delete from kbdx_datasets where DATASET_DESCRIPTION = p_kube_type;
  delete from kbdx_datasets where process_type = p_kube_type;
  delete from kbdx_worksheets where name = p_kube_type;
  delete from kbdx_file_definitions where PROCESS_TYPE = p_kube_type;
  --delete from kbace.kbdx_kube_flexfield_def where kube_type_id in (		-- Commented code by IXPRAVEEN-ARGANO,14-july-2023
  delete from apps.kbdx_kube_flexfield_def where kube_type_id in (          --  code Added by IXPRAVEEN-ARGANO,   14-july-2023
    select kube_type_id from kbdx_kube_types where kube_type = p_kube_type);
  select kbdx_kube_types_s.nextval into l_kube_type_id from dual;
    --
  If p_update_prior_info Then
    update_prior_info(p_kube_type, l_kube_type_id);
  Else  delete from kbdx_kube_assigned_resps where kube_type_id in (
        select kube_type_id from kbdx_kube_types where kube_type = p_kube_type);
  End If;
    --
  delete from kbdx_kube_executables where kube_type_id in (
    select kube_type_id from kbdx_kube_types where kube_type = p_kube_type);
  delete from kbdx_kube_types where kube_type = p_kube_type;
  select kbdx_kube_skeletons_s.nextval into l_skeleton_id from dual;
  select kbdx_template_groups_s.nextval into l_template_group_id from dual;
    --
  select max(dataset_id) into l_max_dataset_id from kbdx_datasets;
  select kbdx_datasets_seq.nextval into l_dataset_id from dual;
  If  l_dataset_id <= l_max_dataset_id Then
    Loop
      Exit When l_dataset_id > l_max_dataset_id;
      select kbdx_datasets_seq.nextval into l_dataset_id from dual;
    End Loop;
  End If;
    --
  select min(worksheet_id) into l_max_ws_id from kbdx_worksheets;
  select KBDX_WORKSHEET_SEQ.nextval into l_worksheet_id from dual;
  If  l_worksheet_id >= l_max_ws_id Then
    Loop
      Exit When l_worksheet_id < l_max_ws_id;
      select KBDX_WORKSHEET_SEQ.nextval into l_worksheet_id from dual;
    End Loop;
  End If;
    --
  If p_parameter_group is not NULL Then
    select distinct parameter_group_id  into l_pg_id
    from kbdx_kube_parameter_groups
    where parameter_group_name = p_parameter_group;
  Else l_pg_id := NULL;
  End If;
    --
  INSERT INTO kbdx_kube_types (KUBE_TYPE_ID,KUBE_VERSION,KUBE_TYPE,KUBE_DESCRIPTION,kube_group_id,parameter_group_id)
   VALUES (l_kube_type_id,1,p_kube_type,p_kube_description,l_kg_id,l_pg_id);
    --
  INSERT INTO kbdx_kube_skeletons (skeleton_id, KUBE_TYPE_ID,template_group_id)
   VALUES (l_skeleton_id,l_kube_type_id,l_template_group_id);
    --KBDXUGEN
  INSERT INTO kbdx_datasets (DATASET_ID,DATASET_DESCRIPTION,CONCURRENT_PROGRAM_NAME,
                             AOL_OWNER_ID,PROCESS_TYPE,ENABLED_FLAG)
   VALUES (l_dataset_id,p_kube_type,p_fnd_executable,NULL,p_kube_type,'Y');
    --
  INSERT INTO kbdx_worksheets (WORKSHEET_ID,DATASET_ID,NAME,TYPE,AOL_SETUP_GROUP)
   VALUES (l_worksheet_id,l_dataset_id,p_kube_type,'raw','0');
    --
  kbdx_kube_seed_pkg.create_executable(p_kube_type_id => l_kube_type_id,
                                       p_executable => p_kbdx_executable);
  kbdx_kube_seed_pkg.build_templates_seed(p_kube_type_id => l_kube_type_id,
                                          p_worksheet_id => l_worksheet_id);
  KBDX_KUBE_LOAD_SEED_DATA.add_kb_vs_info(l_kube_type_id);
  p_worksheet_id := l_worksheet_id;
  p_kube_type_id := l_kube_type_id;
    --
  If l_prior_dataset_id <> 0 then
    update kbdx_drill_downs set dataset_id = l_dataset_id
    where dataset_id=  l_prior_dataset_id;
  End If;
    --
End Initialize;
    --
Procedure Build_Templates_Seed(p_kube_type_id in number, p_worksheet_id in number) Is
l_sql varchar2(32767);
l_dummy Number;
Begin
    -- Columns from kbdx_kube_containers
  delete_table(p_kube_type_id => p_kube_type_id, p_table_name =>'KB_KUBE_CONTAINERS');
    --
  column_tab.Delete;
  l_sql := 'select kube_type_id||''|''||template_group_id||''|''||
            template_name||''|''||template_location||''|''||template_executable||''|''||template_source||''|''||
            user_defined||''|''||template_type_id||''|''||template_description||''|''||template_author||''|''||
            template_id||''|''||tooltips data From kbAce.kbdx_kube_containers where kube_type_id = '||p_kube_type_id;
    --
  column_tab(1).name := 'KUBE_TYPE_ID';
  column_tab(2).name := 'TEMPLATE_GROUP_ID';
  column_tab(3).name := 'TEMPLATE_NAME';
  column_tab(4).name := 'TEMPLATE_LOCATION';
  column_tab(5).name := 'TEMPLATE_EXECUTABLE';
  column_tab(6).name := 'TEMPLATE_SOURCE';
  column_tab(7).name := 'USER_DEFINED';
  column_tab(8).name := 'TEMPLATE_TYPE_ID';
  column_tab(9).name := 'TEMPLATE_DESCRIPTION';
  column_tab(10).name := 'TEMPLATE_AUTHOR';
  column_tab(11).name := 'TEMPLATE_ID';
  column_tab(12).name := 'TOOLTIPS';
  column_tab(13).name := 'BLOB_DATA';
    --
  column_tab(1).DATA_TYPE := 'LONG';
  column_tab(2).DATA_TYPE := 'LONG';
  column_tab(3).DATA_TYPE := 'TEXT';
  column_tab(4).DATA_TYPE := 'TEXT';
  column_tab(5).DATA_TYPE := 'TEXT';
  column_tab(6).DATA_TYPE := 'TEXT';
  column_tab(7).DATA_TYPE := 'TEXT';
  column_tab(8).DATA_TYPE := 'LONG';
  column_tab(9).DATA_TYPE := 'TEXT';
  column_tab(10).DATA_TYPE := 'TEXT';
  column_tab(11).DATA_TYPE := 'LONG';
  column_tab(12).DATA_TYPE := 'TEXT';
  column_tab(13).DATA_TYPE := 'OLE';
    --
  l_dummy:=kbdx_kube_seed_pkg.insert_table (p_table_name => 'KB_KUBE_CONTAINERS',
                                            p_aol_owner_id => -999,
                                            p_table_type => 'STATIC',
                                            p_sql_stmt => l_sql,
                                            p_plsql_dim_tab => NULL,
                                            p_dimension_sql_id => 2,
                                            p_kube_type_id => p_kube_type_id,
                                            p_worksheet_id => p_worksheet_id,
                                            p_columns => column_tab);
End Build_Templates_Seed;
  --
Function insert_kube_parameters(p_parameter_name in Varchar2, p_data_type in Varchar2,
                                p_sql_stmt in Varchar2, p_object_id in Number) Return Number Is
l_parm_id Number;
Begin
    select kbdx_kube_parameters_s.nextval into l_parm_id from dual;
    Insert into kbdx_kube_parameters(parameter_id, parameter_name, data_type, sql_stmt, object_id) values
            (l_parm_id, p_parameter_name, p_data_type, p_sql_stmt, p_object_id);
    Return l_parm_id;
End insert_kube_parameters;
--

Function insert_kube_parm_groups (p_parameter_group_name in Varchar2, p_parameter_name in Varchar2,
                                  p_dependent_parameter_name in Varchar2,p_context_name in Varchar2,
                                  p_description in Varchar2, p_sequence in Number, p_parent_object in Varchar2,
                                  p_parameter_object in Varchar2, p_required_style in varchar2) Return Number Is
l_pg_id Number;
l_parm_id Number;
l_dep_parm_id Number;
l_context_id Number;
l_km_object_id number;
l_required Number;
l_parent_object_id Number;
Begin
  Begin
    select parameter_id into l_parm_id from kbdx_kube_parameters where parameter_name = p_parameter_name;

    Exception
      When OTHERS Then
        raise_application_error(-20001,'ERROR : Parameter '||p_parameter_name||' does not exist.');
    End;

  If p_dependent_parameter_name is NOT NULL Then
    Begin
     select parameter_id into l_dep_parm_id from kbdx_kube_parameters where parameter_name = p_dependent_parameter_name;

     Exception
       When OTHERS Then
         raise_application_error(-20002,'ERROR : Dependent Parameter '||p_parameter_name||' does not exist.');
     End;
   End If;

  If p_context_name is not NULL Then
    Begin
     select context_id into l_context_id from kbdx_kube_contexts where context_name = p_context_name;

     Exception
       When OTHERS Then
         raise_application_error(-20003,'ERROR : Context '||p_context_name||' does not exist.');
     End;
   End If;

   Begin
    select child_object_id into l_km_object_id
    from kbdx_kube_child_objects
    where child_object_definition =  p_parameter_object;

    Exception
      When OTHERS Then
        raise_application_error(-20004,'ERROR : PARAMETER OBJECT '||p_parameter_object||' does not exist.');
    End;

    Begin
    select parent_object_id into l_parent_object_id
    from kbdx_kube_parent_objects
    where parent_object_definition =  p_parent_object;

    Exception
      When OTHERS Then
        raise_application_error(-20005,'ERROR : PARENT OBJECT '||p_parent_object||' does not exist.');
    End;

    Begin
    select REQUIRED_STYLE_ID into l_required
    from kbdx_kube_required_styles
    where REQUIRED_DEFINITION =  p_required_style;

    Exception
      When OTHERS Then
        raise_application_error(-20006,'ERROR : REQUIRED_STYLE '||p_required_style||' does not exist.');
    End;
    Begin
      select distinct parameter_group_id into l_pg_id from kbdx_kube_parameter_groups
      where parameter_group_name = p_parameter_group_name;

      Exception
        When OTHERS Then
          select kbdx_kube_parameter_groups_s.nextval into l_pg_id from dual;
    End;
    Insert into kbdx_kube_parameter_groups(parameter_group_name, parameter_group_id, parameter_id, dependent_parameter_id,
                                           context_id, description, sequence, parent_object_id, km_object_id, required_flag)
                                           values (p_parameter_group_name, l_pg_id, l_parm_id, l_dep_parm_id,
                                                   l_context_id, p_description, p_sequence, l_parent_object_id, l_km_object_id,
                                                   l_required);
    Return l_pg_id;
End insert_kube_parm_groups;

End kbdx_kube_seed_pkg;
/
show errors;
/