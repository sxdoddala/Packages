create or replace Package Body kbdx_kube_load_seed_data
 IS
/*
 * $History: kbdx_kube_load_seed_data.pkb $
 *
 * *****************  Version 48  *****************
 * User: Jkeller      Date: 9/20/10    Time: 4:07p
 * Updated in $/KBX Kube Main/40_CODE_BASE/PATCH/4005.7
 * 40057
 *
 *   44  Jkeller      4/12/10    AS [ADDL_PERSON_DETAILS_LINK_ID]
 *   41  Jkeller      3/04/10    ASSIGNMENT_ACTION_ID datatype DECIMAL
 *   39  Jkeller     10/25/09    bproc_per_person_det_working kb_person_us_context_data
 *   37  Jkeller      8/27/09    per_organizations in per_asg_details and per_hr_asg_details pass null to allow multiple context
 *   35  Jkeller      7/06/07    comments in per_addresses
 *  1.0	IXPRAVEEN(ARGANO)  12-May-2023		R12.2 Upgrade Remediation
 * See SourceSafe for addition comments
 *
*/
cursor c_get_dff_context_asg is
select distinct nvl(ass_attribute_category,'Global Data Elements') ass_attribute_category from per_all_assignments_f;

cursor c_get_dff_context_ppf is
select distinct nvl(attribute_category,'Global Data Elements') attribute_category from per_all_people_f;

procedure bproc_per_person_det_working(p_kube_type_id number,av_date_to varchar2,p_context varchar2 default 'US');
  --
  --JAK 05/05/2010 Prior to 40057 calls to kbdx_kube_seed_pkg.build_ff_tables were with an incorrect p_client_table which survives
  -- most sites setup where there is only one business_group defined. At 40057 we standardize naming. See example per_jobs...
  --
Function get_build_ff_tables_naming
 RETURN NUMBER IS
 l_build_ff_tables_naming number;
Begin
  Begin
    select to_number(nvl(parameter_value,40056)) into l_build_ff_tables_naming
    from xkb_action_parameters
    where parameter_name = 'BUILD_FF_TABLES_NAMING';
   Exception
     when others then
       l_build_ff_tables_naming := 40056;
  End;
  If l_build_ff_tables_naming < 40056 then
    l_build_ff_tables_naming := 40056;
  End if;
  return l_build_ff_tables_naming;
End;

procedure add_kb_vs_info(an_kube_type_id number) as
 l_kube_type_id number := an_kube_type_id;
 l_sql varchar2(6000);
 column_tab kbdx_kube_seed_pkg.column_tabtype;
begin
    --
    -- 'KB_VS_INFO'
    --
  column_tab.delete;
  column_tab(1).name := 'VALUE_SET_ID';
  column_tab(2).name := 'VALUE';
  column_tab(3).name := 'ID';
    --
  column_tab(1).data_type := 'LONG';
  column_tab(2).data_type := 'TEXT';
  column_tab(3).data_type := 'TEXT';
    --
  --l_sql := 'select value_set_id||''|''||value_column||''|''||id_column data From kbace.kbdx_kube_vs_information';			-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
  l_sql := 'select value_set_id||''|''||value_column||''|''||id_column data From apps.kbdx_kube_vs_information';           --  code Added by IXPRAVEEN-ARGANO,   12-May-2023
    --
  kbdx_kube_api_seed_pkg.create_static_table(p_table_name => 'KB_VS_INFO',
                                             p_sql_stmt => l_sql,
                                             p_kube_type_id => l_kube_type_id,
                                             p_table_structure => column_tab);
End add_kb_vs_info;

procedure static_hr_lookup(an_kube_type_id number,
                           av_lookup_code varchar2,
                           av_table_name varchar2 default null) as
 lv_table_name varchar2(200);
 l_sql varchar2(6000);
 column_tab kbdx_kube_seed_pkg.column_tabtype;
 l_kube_type_id number := an_kube_type_id;
begin
    --
    -- lv_table_name
    --
  column_tab.delete;
  column_tab(1).name := 'Lookup_Code';
  column_tab(2).name := 'Meaning';
    --
  column_tab(1).data_type := 'TEXT';
  column_tab(2).data_type := 'TEXT';
    --
  if av_table_name is null then
    lv_table_name := 'KB_'||av_lookup_code;
  else
    lv_table_name :=  av_table_name;
  end if;
    --
  l_sql :=
 'select /*+ RULE */ lookup_code||''|''||nvl(description,meaning) data
  from hr_lookups where lookup_type = '''||av_lookup_code||'''
  union select ''-999''||''|Missing'' data from dual';
    --
  kbdx_kube_api_seed_pkg.create_static_table(p_table_name => lv_table_name,
                                             p_sql_stmt => l_sql,
                                             p_kube_type_id => l_kube_type_id,
                                             p_table_structure => column_tab);
End static_hr_lookup;

Procedure pay_people_groups_kf(p_kube_type_id in number,
                               p_dim_tab in varchar2,
                               av_client_table_name varchar2 default null) as
 l_sql varchar2(6000);
 l_worksheet_id Number;
 column_tab kbdx_kube_seed_pkg.column_tabtype;
 l_table_id Number;
 l_cxt_id Number;
 lv_client_table_name varchar2(300);
 loldDffKffnaming boolean := false;
Begin
    --JAK 05/05/2010
  if get_build_ff_tables_naming <= 40056 then
    loldDffKffnaming := true;
  end if;
    --
  kbdx_kube_seed_pkg.delete_table(p_kube_type_id => p_kube_type_id,
                                  p_table_name => 'KB_PG_SOURCE');

  l_worksheet_id := kbdx_kube_seed_pkg.get_worksheet_id(p_kube_type_id => p_kube_type_id);

    --
    -- 'KB_PG_SOURCE'
    --
  column_tab.delete;
  column_tab(1).name := 'PEOPLE_GROUP_ID';
  column_tab(2).name := 'DETAIL_ID1';
  column_tab(3).name := 'DETAIL_ID2';
  column_tab(4).name := 'DETAIL_ID3';
  column_tab(5).name := 'DETAIL_ID4';
  column_tab(6).name := 'DETAIL_ID5';
  column_tab(7).name := 'DETAIL_ID6';
  column_tab(8).name := 'DETAIL_ID7';
  column_tab(9).name := 'DETAIL_ID8';
  column_tab(10).name := 'DETAIL_ID9';
  column_tab(11).name := 'DETAIL_ID10';
  column_tab(12).name := 'DETAIL_ID11';
  column_tab(13).name := 'DETAIL_ID12';
  column_tab(14).name := 'DETAIL_ID13';
  column_tab(15).name := 'DETAIL_ID14';
  column_tab(16).name := 'DETAIL_ID15';
  column_tab(17).name := 'DETAIL_ID16';
  column_tab(18).name := 'DETAIL_ID17';
  column_tab(19).name := 'DETAIL_ID18';
  column_tab(20).name := 'DETAIL_ID19';
  column_tab(21).name := 'DETAIL_ID20';
  column_tab(22).name := 'DETAIL_ID21';
  column_tab(23).name := 'DETAIL_ID22';
  column_tab(24).name := 'DETAIL_ID23';
  column_tab(25).name := 'DETAIL_ID24';
  column_tab(26).name := 'DETAIL_ID25';
  column_tab(27).name := 'DETAIL_ID26';
  column_tab(28).name := 'DETAIL_ID27';
  column_tab(29).name := 'DETAIL_ID28';
  column_tab(30).name := 'DETAIL_ID29';
  column_tab(31).name := 'DETAIL_ID30';
  column_tab(32).name := 'VS_ID1';
  column_tab(33).name := 'VS_ID2';
  column_tab(34).name := 'VS_ID3';
  column_tab(35).name := 'VS_ID4';
  column_tab(36).name := 'VS_ID5';
  column_tab(37).name := 'VS_ID6';
  column_tab(38).name := 'VS_ID7';
  column_tab(39).name := 'VS_ID8';
  column_tab(40).name := 'VS_ID9';
  column_tab(41).name := 'VS_ID10';
  column_tab(42).name := 'VS_ID11';
  column_tab(43).name := 'VS_ID12';
  column_tab(44).name := 'VS_ID13';
  column_tab(45).name := 'VS_ID14';
  column_tab(46).name := 'VS_ID15';
  column_tab(47).name := 'VS_ID16';
  column_tab(48).name := 'VS_ID17';
  column_tab(49).name := 'VS_ID18';
  column_tab(50).name := 'VS_ID19';
  column_tab(51).name := 'VS_ID20';
  column_tab(52).name := 'VS_ID21';
  column_tab(53).name := 'VS_ID22';
  column_tab(54).name := 'VS_ID23';
  column_tab(55).name := 'VS_ID24';
  column_tab(56).name := 'VS_ID25';
  column_tab(57).name := 'VS_ID26';
  column_tab(58).name := 'VS_ID27';
  column_tab(59).name := 'VS_ID28';
  column_tab(60).name := 'VS_ID29';
  column_tab(61).name := 'VS_ID30';
    --
  column_tab(1).DATA_TYPE := 'LONG';
  column_tab(2).DATA_TYPE := 'TEXT';
  column_tab(3).DATA_TYPE := 'TEXT';
  column_tab(4).DATA_TYPE := 'TEXT';
  column_tab(5).DATA_TYPE := 'TEXT';
  column_tab(6).DATA_TYPE := 'TEXT';
  column_tab(7).DATA_TYPE := 'TEXT';
  column_tab(8).DATA_TYPE := 'TEXT';
  column_tab(9).DATA_TYPE := 'TEXT';
  column_tab(10).DATA_TYPE := 'TEXT';
  column_tab(11).DATA_TYPE := 'TEXT';
  column_tab(12).DATA_TYPE := 'TEXT';
  column_tab(13).DATA_TYPE := 'TEXT';
  column_tab(14).DATA_TYPE := 'TEXT';
  column_tab(15).DATA_TYPE := 'TEXT';
  column_tab(16).DATA_TYPE := 'TEXT';
  column_tab(17).DATA_TYPE := 'TEXT';
  column_tab(18).DATA_TYPE := 'TEXT';
  column_tab(19).DATA_TYPE := 'TEXT';
  column_tab(20).DATA_TYPE := 'TEXT';
  column_tab(21).DATA_TYPE := 'TEXT';
  column_tab(22).DATA_TYPE := 'TEXT';
  column_tab(23).DATA_TYPE := 'TEXT';
  column_tab(24).DATA_TYPE := 'TEXT';
  column_tab(25).DATA_TYPE := 'TEXT';
  column_tab(26).DATA_TYPE := 'TEXT';
  column_tab(27).DATA_TYPE := 'TEXT';
  column_tab(28).DATA_TYPE := 'TEXT';
  column_tab(29).DATA_TYPE := 'TEXT';
  column_tab(30).DATA_TYPE := 'TEXT';
  column_tab(31).DATA_TYPE := 'TEXT';
  column_tab(32).DATA_TYPE := 'LONG';
  column_tab(33).DATA_TYPE := 'LONG';
  column_tab(34).DATA_TYPE := 'LONG';
  column_tab(35).DATA_TYPE := 'LONG';
  column_tab(36).DATA_TYPE := 'LONG';
  column_tab(37).DATA_TYPE := 'LONG';
  column_tab(38).DATA_TYPE := 'LONG';
  column_tab(39).DATA_TYPE := 'LONG';
  column_tab(40).DATA_TYPE := 'LONG';
  column_tab(41).DATA_TYPE := 'LONG';
  column_tab(42).DATA_TYPE := 'LONG';
  column_tab(43).DATA_TYPE := 'LONG';
  column_tab(44).DATA_TYPE := 'LONG';
  column_tab(45).DATA_TYPE := 'LONG';
  column_tab(46).DATA_TYPE := 'LONG';
  column_tab(47).DATA_TYPE := 'LONG';
  column_tab(48).DATA_TYPE := 'LONG';
  column_tab(49).DATA_TYPE := 'LONG';
  column_tab(50).DATA_TYPE := 'LONG';
  column_tab(51).DATA_TYPE := 'LONG';
  column_tab(52).DATA_TYPE := 'LONG';
  column_tab(53).DATA_TYPE := 'LONG';
  column_tab(54).DATA_TYPE := 'LONG';
  column_tab(55).DATA_TYPE := 'LONG';
  column_tab(56).DATA_TYPE := 'LONG';
  column_tab(57).DATA_TYPE := 'LONG';
  column_tab(58).DATA_TYPE := 'LONG';
  column_tab(59).DATA_TYPE := 'LONG';
  column_tab(60).DATA_TYPE := 'LONG';
  column_tab(61).DATA_TYPE := 'LONG';
    --
  l_sql :=
 'select segment1||''|''||segment2||''|''||segment3||''|''||segment4||''|''||segment5||''|''
  ||segment6||''|''||segment7||''|''||segment8||''|''||segment9||''|''||segment10||''|''
  ||segment11||''|''||segment12||''|''||segment13||''|''||segment14||''|''||segment15||''|''
  ||segment16||''|''||segment17||''|''||segment18||''|''||segment19||''|''||segment20||''|''
  ||segment21||''|''||segment22||''|''||segment23||''|''||segment24||''|''||segment25||''|''
  ||segment26||''|''||segment27||''|''||segment28||''|''||segment29||''|''||segment30 into l_data
  From pay_people_groups
  where people_group_id = :p_data_tab;';
    --
  l_table_id := kbdx_kube_seed_pkg.insert_table (p_table_name => 'KB_PG_SOURCE', p_aol_owner_id => -999, p_table_type => 'DIM',
                              p_sql_stmt => l_sql, p_plsql_dim_tab => p_dim_tab, p_dimension_sql_id => 3,
                              p_kube_type_id => p_kube_type_id, p_worksheet_id => l_worksheet_id,p_columns => column_tab);
    --
  For i in kbdx_kube_seed_pkg.c_get_bg Loop
      --JAK 05/05/2010
    if loldDffKffnaming then
      lv_client_table_name := nvl(av_client_table_name,'KB_PEOPLE_GROUPS_'||i.people_group_structure);
    else
      lv_client_table_name := nvl(av_client_table_name,'KB_PEOPLE_GROUPS')||i.business_group_id;
    end if;
      --
    lv_client_table_name := nvl(av_client_table_name,'KB_PEOPLE_GROUPS');
    l_cxt_id := kbdx_kube_seed_pkg.build_ff_tables (
                                 p_app_table => 'PAY_PEOPLE_GROUPS',
                                 p_source_table => 'KB_PG_SOURCE',
                                 p_client_table => lv_client_table_name,
                                 p_source_column => 'PEOPLE_GROUP_ID',
                                 p_context => i.people_group_structure,
                                 p_kube_type_id => p_kube_type_id,
                                 p_flex_type => 'K',
                                 p_bg_id  => i.business_group_id);
  End Loop;
    --
End pay_people_groups_kf;

Procedure costing_kf(p_kube_type_id in number,
                     p_dim_tab in varchar2,
                     av_client_table_name varchar2 default null) as
 l_sql varchar2(6000);
 l_worksheet_id Number;
 column_tab kbdx_kube_seed_pkg.column_tabtype;
 l_table_id Number;
 l_cxt_id Number;
 lv_client_table_name varchar2(300);
 loldDffKffnaming boolean := false;
Begin
    --JAK 05/05/2010
  if get_build_ff_tables_naming <= 40056 then
    loldDffKffnaming := true;
  end if;
    --
  kbdx_kube_seed_pkg.delete_table(p_kube_type_id => p_kube_type_id,
                                  p_table_name => 'KB_COSTING_CONFIG_RAW');
  l_worksheet_id := kbdx_kube_seed_pkg.get_worksheet_id(p_kube_type_id => p_kube_type_id);
    --
    -- 'KB_COSTING_CONFIG_RAW'
    --
  column_tab.delete;
  column_tab(1).name := 'COST_ALLOCATION_KEYFLEX_ID';
  column_tab(2).name := 'DETAIL_ID1';
  column_tab(3).name := 'DETAIL_ID2';
  column_tab(4).name := 'DETAIL_ID3';
  column_tab(5).name := 'DETAIL_ID4';
  column_tab(6).name := 'DETAIL_ID5';
  column_tab(7).name := 'DETAIL_ID6';
  column_tab(8).name := 'DETAIL_ID7';
  column_tab(9).name := 'DETAIL_ID8';
  column_tab(10).name := 'DETAIL_ID9';
  column_tab(11).name := 'DETAIL_ID10';
  column_tab(12).name := 'DETAIL_ID11';
  column_tab(13).name := 'DETAIL_ID12';
  column_tab(14).name := 'DETAIL_ID13';
  column_tab(15).name := 'DETAIL_ID14';
  column_tab(16).name := 'DETAIL_ID15';
  column_tab(17).name := 'DETAIL_ID16';
  column_tab(18).name := 'DETAIL_ID17';
  column_tab(19).name := 'DETAIL_ID18';
  column_tab(20).name := 'DETAIL_ID19';
  column_tab(21).name := 'DETAIL_ID20';
  column_tab(22).name := 'DETAIL_ID21';
  column_tab(23).name := 'DETAIL_ID22';
  column_tab(24).name := 'DETAIL_ID23';
  column_tab(25).name := 'DETAIL_ID24';
  column_tab(26).name := 'DETAIL_ID25';
  column_tab(27).name := 'DETAIL_ID26';
  column_tab(28).name := 'DETAIL_ID27';
  column_tab(29).name := 'DETAIL_ID28';
  column_tab(30).name := 'DETAIL_ID29';
  column_tab(31).name := 'DETAIL_ID30';
  column_tab(32).name := 'VS_ID1';
  column_tab(33).name := 'VS_ID2';
  column_tab(34).name := 'VS_ID3';
  column_tab(35).name := 'VS_ID4';
  column_tab(36).name := 'VS_ID5';
  column_tab(37).name := 'VS_ID6';
  column_tab(38).name := 'VS_ID7';
  column_tab(39).name := 'VS_ID8';
  column_tab(40).name := 'VS_ID9';
  column_tab(41).name := 'VS_ID10';
  column_tab(42).name := 'VS_ID11';
  column_tab(43).name := 'VS_ID12';
  column_tab(44).name := 'VS_ID13';
  column_tab(45).name := 'VS_ID14';
  column_tab(46).name := 'VS_ID15';
  column_tab(47).name := 'VS_ID16';
  column_tab(48).name := 'VS_ID17';
  column_tab(49).name := 'VS_ID18';
  column_tab(50).name := 'VS_ID19';
  column_tab(51).name := 'VS_ID20';
  column_tab(52).name := 'VS_ID21';
  column_tab(53).name := 'VS_ID22';
  column_tab(54).name := 'VS_ID23';
  column_tab(55).name := 'VS_ID24';
  column_tab(56).name := 'VS_ID25';
  column_tab(57).name := 'VS_ID26';
  column_tab(58).name := 'VS_ID27';
  column_tab(59).name := 'VS_ID28';
  column_tab(60).name := 'VS_ID29';
  column_tab(61).name := 'VS_ID30';
    --
  column_tab(1).DATA_TYPE := 'LONG';
  column_tab(2).DATA_TYPE := 'TEXT';
  column_tab(3).DATA_TYPE := 'TEXT';
  column_tab(4).DATA_TYPE := 'TEXT';
  column_tab(5).DATA_TYPE := 'TEXT';
  column_tab(6).DATA_TYPE := 'TEXT';
  column_tab(7).DATA_TYPE := 'TEXT';
  column_tab(8).DATA_TYPE := 'TEXT';
  column_tab(9).DATA_TYPE := 'TEXT';
  column_tab(10).DATA_TYPE := 'TEXT';
  column_tab(11).DATA_TYPE := 'TEXT';
  column_tab(12).DATA_TYPE := 'TEXT';
  column_tab(13).DATA_TYPE := 'TEXT';
  column_tab(14).DATA_TYPE := 'TEXT';
  column_tab(15).DATA_TYPE := 'TEXT';
  column_tab(16).DATA_TYPE := 'TEXT';
  column_tab(17).DATA_TYPE := 'TEXT';
  column_tab(18).DATA_TYPE := 'TEXT';
  column_tab(19).DATA_TYPE := 'TEXT';
  column_tab(20).DATA_TYPE := 'TEXT';
  column_tab(21).DATA_TYPE := 'TEXT';
  column_tab(22).DATA_TYPE := 'TEXT';
  column_tab(23).DATA_TYPE := 'TEXT';
  column_tab(24).DATA_TYPE := 'TEXT';
  column_tab(25).DATA_TYPE := 'TEXT';
  column_tab(26).DATA_TYPE := 'TEXT';
  column_tab(27).DATA_TYPE := 'TEXT';
  column_tab(28).DATA_TYPE := 'TEXT';
  column_tab(29).DATA_TYPE := 'TEXT';
  column_tab(30).DATA_TYPE := 'TEXT';
  column_tab(31).DATA_TYPE := 'TEXT';
  column_tab(32).DATA_TYPE := 'LONG';
  column_tab(33).DATA_TYPE := 'LONG';
  column_tab(34).DATA_TYPE := 'LONG';
  column_tab(35).DATA_TYPE := 'LONG';
  column_tab(36).DATA_TYPE := 'LONG';
  column_tab(37).DATA_TYPE := 'LONG';
  column_tab(38).DATA_TYPE := 'LONG';
  column_tab(39).DATA_TYPE := 'LONG';
  column_tab(40).DATA_TYPE := 'LONG';
  column_tab(41).DATA_TYPE := 'LONG';
  column_tab(42).DATA_TYPE := 'LONG';
  column_tab(43).DATA_TYPE := 'LONG';
  column_tab(44).DATA_TYPE := 'LONG';
  column_tab(45).DATA_TYPE := 'LONG';
  column_tab(46).DATA_TYPE := 'LONG';
  column_tab(47).DATA_TYPE := 'LONG';
  column_tab(48).DATA_TYPE := 'LONG';
  column_tab(49).DATA_TYPE := 'LONG';
  column_tab(50).DATA_TYPE := 'LONG';
  column_tab(51).DATA_TYPE := 'LONG';
  column_tab(52).DATA_TYPE := 'LONG';
  column_tab(53).DATA_TYPE := 'LONG';
  column_tab(54).DATA_TYPE := 'LONG';
  column_tab(55).DATA_TYPE := 'LONG';
  column_tab(56).DATA_TYPE := 'LONG';
  column_tab(57).DATA_TYPE := 'LONG';
  column_tab(58).DATA_TYPE := 'LONG';
  column_tab(59).DATA_TYPE := 'LONG';
  column_tab(60).DATA_TYPE := 'LONG';
  column_tab(61).DATA_TYPE := 'LONG';
    --
  l_sql :=
 'select segment1||''|''||segment2||''|''||segment3||''|''||segment4||''|''||segment5||''|''
  ||segment6||''|''||segment7||''|''||segment8||''|''||segment9||''|''||segment10||''|''
  ||segment11||''|''||segment12||''|''||segment13||''|''||segment14||''|''||segment15||''|''
  ||segment16||''|''||segment17||''|''||segment18||''|''||segment19||''|''||segment20||''|''
  ||segment21||''|''||segment22||''|''||segment23||''|''||segment24||''|''||segment25||''|''
  ||segment26||''|''||segment27||''|''||segment28||''|''||segment29||''|''||segment30 into l_data
  From pay_cost_allocation_keyflex
  where COST_ALLOCATION_KEYFLEX_ID = :p_data_tab;';
    --
  l_table_id := kbdx_kube_seed_pkg.insert_table (p_table_name => 'KB_COSTING_CONFIG_RAW', p_aol_owner_id => -999, p_table_type => 'DIM',
                              p_sql_stmt => l_sql, p_plsql_dim_tab => p_dim_tab, p_dimension_sql_id => 3,
                              p_kube_type_id => p_kube_type_id, p_worksheet_id => l_worksheet_id,p_columns => column_tab);
    --
  For i in kbdx_kube_seed_pkg.c_get_bg Loop
      --JAK 05/05/2010
    if loldDffKffnaming then
      lv_client_table_name := nvl(av_client_table_name,'MT_COSTING_CONFIG'||i.COST_ALLOCATION_STRUCTURE);
    else
      lv_client_table_name := nvl(av_client_table_name,'MT_COSTING_CONFIG')||i.business_group_id;
    end if;
      --
    lv_client_table_name := nvl(av_client_table_name,'MT_COSTING_CONFIG');
    l_cxt_id := kbdx_kube_seed_pkg.build_ff_tables (
                                p_app_table => 'PAY_COST_ALLOCATION_KEYFLEX',
                                p_source_table => 'KB_COSTING_CONFIG_RAW',
                                p_client_table => lv_client_table_name,
                                p_source_column => 'COST_ALLOCATION_KEYFLEX_ID',
                                p_context => i.COST_ALLOCATION_STRUCTURE,
                                p_kube_type_id => p_kube_type_id,
                                p_flex_type => 'K',
                                p_bg_id  => i.business_group_id);
  End Loop;
    --
End costing_kf;

Procedure add_salary_components(p_kube_type_id in number) as
 l_kube_type_id number := p_kube_type_id;
 column_tab kbdx_kube_seed_pkg.column_tabtype;
Begin
  kbdx_kube_seed_pkg.delete_table(p_kube_type_id => p_kube_type_id,
                                  p_table_name => 'KB_SALARY_COMPONENTS');
    --
    -- 'KB_SALARY_COMPONENTS'
    --
  column_tab.delete;
  column_tab(1).name := 'ADDL_ASG_DETAILS_LINK_ID';
  column_tab(2).name := 'ASSIGNMENT_ID';
  column_tab(3).name := 'Salary Start Date';
  column_tab(4).name := 'Salary End Date';
  column_tab(5).name := 'Proposed Salary';
  column_tab(6).name := 'REASON_CODE';
  column_tab(7).name := 'Change Amount';
  column_tab(8).name := 'Prior Salary';
    --
  column_tab(1).DATA_TYPE := 'LONG';
  column_tab(2).DATA_TYPE := 'LONG';
  column_tab(3).DATA_TYPE := 'DATE';
  column_tab(4).DATA_TYPE := 'DATE';
  column_tab(5).DATA_TYPE := 'DOUBLE';
  column_tab(6).DATA_TYPE := 'TEXT';
  column_tab(7).DATA_TYPE := 'DOUBLE';
  column_tab(8).DATA_TYPE := 'DOUBLE';
  kbdx_kube_api_seed_pkg.create_fact_table(p_table_name => 'KB_SALARY_COMPONENTS',
                                           p_kube_type_id => l_kube_type_id,
                                           p_table_structure => column_tab);
End add_salary_components;

Procedure costed_payroll_action(p_kube_type_id in number) as
 l_sql varchar2(6000);
 column_tab kbdx_kube_seed_pkg.column_tabtype;
 l_kube_type_id number := p_kube_type_id;
Begin
  kbdx_kube_seed_pkg.delete_table(p_kube_type_id => p_kube_type_id,
                                  p_table_name => 'KB_COSTED_PAYROLL_ACTIONS');
    --
    -- 'KB_COSTED_PAYROLL_ACTIONS'
    --
  column_tab.delete;
  column_tab(1).name := 'COST_ID';
  column_tab(2).name := 'Payroll Action';
  column_tab(3).name := 'Check Date';
  column_tab(4).name := 'Date Earned';
  column_tab(5).name := 'Creation Date';
  column_tab(6).name := 'ASSIGNMENT_ACTION_ID';
    --
  column_tab(1).DATA_TYPE := 'DECIMAL';
  column_tab(2).DATA_TYPE := 'TEXT';
  column_tab(3).DATA_TYPE := 'DATE';
  column_tab(4).DATA_TYPE := 'DATE';
  column_tab(5).DATA_TYPE := 'DATE';
  column_tab(6).DATA_TYPE := 'LONG';
    --
  l_sql :=
 'select p.action_type||''|''||to_char(p.effective_date,''MM/DD/YYYY'')
  ||''|''||to_char(p.date_earned,''MM/DD/YYYY'')||''|''||to_char(p.creation_date,''MM/DD/YYYY'')||''|''||a.assignment_action_id
  into l_data
  from pay_payroll_actions p, pay_assignment_actions a, pay_run_results r, pay_costs c
  where p.payroll_action_id = a.payroll_action_id
  and a.assignment_action_id = r.assignment_action_id
  and r.run_result_id = c.run_result_id
  and c.cost_id = :p_data_tab;';
    --
  kbdx_kube_api_seed_pkg.create_dimension_table(p_table_name => 'KB_COSTED_PAYROLL_ACTIONS',
                                                p_sql_stmt  => l_sql,
                                                p_kube_type_id => l_kube_type_id,
                                                p_plsql_tab => 'kbdx_kube_cost_data.g_cost_tab',
                                                p_table_structure => column_tab);
End costed_payroll_action;

Procedure load_job_and_grades(p_kube_type_id in number) as
Begin
 KBDX_KUBE_LOAD_SEED_DATA.per_grades(p_kube_type_id);
 KBDX_KUBE_LOAD_SEED_DATA.per_jobs(p_kube_type_id ,'US');
End load_job_and_grades;

Procedure  per_jobs(p_kube_type_id in number,
                    p_context in varchar2) as
 l_sql varchar2(6000);
 l_worksheet_id Number;
 column_tab kbdx_kube_seed_pkg.column_tabtype;
 l_table_id Number;
 l_cxt_id Number;
 lv_client_table_name varchar2(300);
 loldDffKffnaming boolean := false;
Begin
    --JAK 05/05/2010
  if get_build_ff_tables_naming <= 40056 then
    loldDffKffnaming := true;
  end if;
    --
  kbdx_kube_seed_pkg.delete_table(p_kube_type_id => p_kube_type_id,
                                  p_table_name => 'KB_JOB_ADDL_DATA');
  kbdx_kube_seed_pkg.delete_table(p_kube_type_id => p_kube_type_id,
                                  p_table_name => 'KB_JOB_DEFINITIONS');
  kbdx_kube_seed_pkg.delete_table(p_kube_type_id => p_kube_type_id,
                                  p_table_name => 'KB_JOBS_CXT_DATA');

  l_worksheet_id := kbdx_kube_seed_pkg.get_worksheet_id(p_kube_type_id => p_kube_type_id);
    --
    -- 'KB_JOB_ADDL_DATA'
    --
  column_tab.delete;
  column_tab(1).name := 'JOB_ID';
  column_tab(2).name := 'JOB_DEFINITION_ID';
  column_tab(3).name := 'DETAIL_ID1';
  column_tab(4).name := 'DETAIL_ID2';
  column_tab(5).name := 'DETAIL_ID3';
  column_tab(6).name := 'DETAIL_ID4';
  column_tab(7).name := 'DETAIL_ID5';
  column_tab(8).name := 'DETAIL_ID6';
  column_tab(9).name := 'DETAIL_ID7';
  column_tab(10).name := 'DETAIL_ID8';
  column_tab(11).name := 'DETAIL_ID9';
  column_tab(12).name := 'DETAIL_ID10';
  column_tab(13).name := 'DETAIL_ID11';
  column_tab(14).name := 'DETAIL_ID12';
  column_tab(15).name := 'DETAIL_ID13';
  column_tab(16).name := 'DETAIL_ID14';
  column_tab(17).name := 'DETAIL_ID15';
  column_tab(18).name := 'DETAIL_ID16';
  column_tab(19).name := 'DETAIL_ID17';
  column_tab(20).name := 'DETAIL_ID18';
  column_tab(21).name := 'DETAIL_ID19';
  column_tab(22).name := 'DETAIL_ID20';
  column_tab(23).name := 'VS_ID1';
  column_tab(24).name := 'VS_ID2';
  column_tab(25).name := 'VS_ID3';
  column_tab(26).name := 'VS_ID4';
  column_tab(27).name := 'VS_ID5';
  column_tab(28).name := 'VS_ID6';
  column_tab(29).name := 'VS_ID7';
  column_tab(30).name := 'VS_ID8';
  column_tab(31).name := 'VS_ID9';
  column_tab(32).name := 'VS_ID10';
  column_tab(33).name := 'VS_ID11';
  column_tab(34).name := 'VS_ID12';
  column_tab(35).name := 'VS_ID13';
  column_tab(36).name := 'VS_ID14';
  column_tab(37).name := 'VS_ID15';
  column_tab(38).name := 'VS_ID16';
  column_tab(39).name := 'VS_ID17';
  column_tab(40).name := 'VS_ID18';
  column_tab(41).name := 'VS_ID19';
  column_tab(42).name := 'VS_ID20';
    --
  column_tab(1).DATA_TYPE := 'LONG';
  column_tab(2).DATA_TYPE := 'LONG';
  column_tab(3).DATA_TYPE := 'TEXT';
  column_tab(4).DATA_TYPE := 'TEXT';
  column_tab(5).DATA_TYPE := 'TEXT';
  column_tab(6).DATA_TYPE := 'TEXT';
  column_tab(7).DATA_TYPE := 'TEXT';
  column_tab(8).DATA_TYPE := 'TEXT';
  column_tab(9).DATA_TYPE := 'TEXT';
  column_tab(10).DATA_TYPE := 'TEXT';
  column_tab(11).DATA_TYPE := 'TEXT';
  column_tab(12).DATA_TYPE := 'TEXT';
  column_tab(13).DATA_TYPE := 'TEXT';
  column_tab(14).DATA_TYPE := 'TEXT';
  column_tab(15).DATA_TYPE := 'TEXT';
  column_tab(16).DATA_TYPE := 'TEXT';
  column_tab(17).DATA_TYPE := 'TEXT';
  column_tab(18).DATA_TYPE := 'TEXT';
  column_tab(19).DATA_TYPE := 'TEXT';
  column_tab(20).DATA_TYPE := 'TEXT';
  column_tab(21).DATA_TYPE := 'TEXT';
  column_tab(22).DATA_TYPE := 'TEXT';
  column_tab(23).DATA_TYPE := 'LONG';
  column_tab(24).DATA_TYPE := 'LONG';
  column_tab(25).DATA_TYPE := 'LONG';
  column_tab(26).DATA_TYPE := 'LONG';
  column_tab(27).DATA_TYPE := 'LONG';
  column_tab(28).DATA_TYPE := 'LONG';
  column_tab(29).DATA_TYPE := 'LONG';
  column_tab(30).DATA_TYPE := 'LONG';
  column_tab(31).DATA_TYPE := 'LONG';
  column_tab(32).DATA_TYPE := 'LONG';
  column_tab(33).DATA_TYPE := 'LONG';
  column_tab(34).DATA_TYPE := 'LONG';
  column_tab(35).DATA_TYPE := 'LONG';
  column_tab(36).DATA_TYPE := 'LONG';
  column_tab(37).DATA_TYPE := 'LONG';
  column_tab(38).DATA_TYPE := 'LONG';
  column_tab(39).DATA_TYPE := 'LONG';
  column_tab(40).DATA_TYPE := 'LONG';
  column_tab(41).DATA_TYPE := 'LONG';
  column_tab(42).DATA_TYPE := 'LONG';
    --
  l_sql := 'select JOB_DEFINITION_ID||''|''||attribute1||''|''||attribute2||''|''||attribute3||''|''||attribute4||''|''||attribute5||''|''
                ||attribute6||''|''||attribute7||''|''||attribute8||''|''||attribute9||''|''||attribute10||''|''
                ||attribute11||''|''||attribute12||''|''||attribute13||''|''||attribute14||''|''||attribute15||''|''
                ||attribute16||''|''||attribute17||''|''||attribute18||''|''||attribute19||''|''||attribute20
                into l_data
          From per_jobs
          where job_id = :p_data_tab;';
    --
   l_table_id := kbdx_kube_seed_pkg.insert_table (p_table_name => 'KB_JOB_ADDL_DATA', p_aol_owner_id => -999, p_table_type => 'DIM',
                              p_sql_stmt => l_sql, p_plsql_dim_tab => 'kbdx_kube_utilities.g_job_tab', p_dimension_sql_id => 3,
                              p_kube_type_id => p_kube_type_id, p_worksheet_id => l_worksheet_id,p_columns => column_tab);

    --
    -- 'KB_JOB_DEFINITIONS'
    --
  column_tab.delete;
  column_tab(1).name := 'JOB_DEFINITION_ID';
  column_tab(2).name := 'DETAIL_ID1';
  column_tab(3).name := 'DETAIL_ID2';
  column_tab(4).name := 'DETAIL_ID3';
  column_tab(5).name := 'DETAIL_ID4';
  column_tab(6).name := 'DETAIL_ID5';
  column_tab(7).name := 'DETAIL_ID6';
  column_tab(8).name := 'DETAIL_ID7';
  column_tab(9).name := 'DETAIL_ID8';
  column_tab(10).name := 'DETAIL_ID9';
  column_tab(11).name := 'DETAIL_ID10';
  column_tab(12).name := 'DETAIL_ID11';
  column_tab(13).name := 'DETAIL_ID12';
  column_tab(14).name := 'DETAIL_ID13';
  column_tab(15).name := 'DETAIL_ID14';
  column_tab(16).name := 'DETAIL_ID15';
  column_tab(17).name := 'DETAIL_ID16';
  column_tab(18).name := 'DETAIL_ID17';
  column_tab(19).name := 'DETAIL_ID18';
  column_tab(20).name := 'DETAIL_ID19';
  column_tab(21).name := 'DETAIL_ID20';
  column_tab(22).name := 'DETAIL_ID21';
  column_tab(23).name := 'DETAIL_ID22';
  column_tab(24).name := 'DETAIL_ID23';
  column_tab(25).name := 'DETAIL_ID24';
  column_tab(26).name := 'DETAIL_ID25';
  column_tab(27).name := 'DETAIL_ID26';
  column_tab(28).name := 'DETAIL_ID27';
  column_tab(29).name := 'DETAIL_ID28';
  column_tab(30).name := 'DETAIL_ID29';
  column_tab(31).name := 'DETAIL_ID30';
  column_tab(32).name := 'VS_ID1';
  column_tab(33).name := 'VS_ID2';
  column_tab(34).name := 'VS_ID3';
  column_tab(35).name := 'VS_ID4';
  column_tab(36).name := 'VS_ID5';
  column_tab(37).name := 'VS_ID6';
  column_tab(38).name := 'VS_ID7';
  column_tab(39).name := 'VS_ID8';
  column_tab(40).name := 'VS_ID9';
  column_tab(41).name := 'VS_ID10';
  column_tab(42).name := 'VS_ID11';
  column_tab(43).name := 'VS_ID12';
  column_tab(44).name := 'VS_ID13';
  column_tab(45).name := 'VS_ID14';
  column_tab(46).name := 'VS_ID15';
  column_tab(47).name := 'VS_ID16';
  column_tab(48).name := 'VS_ID17';
  column_tab(49).name := 'VS_ID18';
  column_tab(50).name := 'VS_ID19';
  column_tab(51).name := 'VS_ID20';
  column_tab(52).name := 'VS_ID21';
  column_tab(53).name := 'VS_ID22';
  column_tab(54).name := 'VS_ID23';
  column_tab(55).name := 'VS_ID24';
  column_tab(56).name := 'VS_ID25';
  column_tab(57).name := 'VS_ID26';
  column_tab(58).name := 'VS_ID27';
  column_tab(59).name := 'VS_ID28';
  column_tab(60).name := 'VS_ID29';
  column_tab(61).name := 'VS_ID30';
    --
  column_tab(1).DATA_TYPE := 'LONG';
  column_tab(2).DATA_TYPE := 'TEXT';
  column_tab(3).DATA_TYPE := 'TEXT';
  column_tab(4).DATA_TYPE := 'TEXT';
  column_tab(5).DATA_TYPE := 'TEXT';
  column_tab(6).DATA_TYPE := 'TEXT';
  column_tab(7).DATA_TYPE := 'TEXT';
  column_tab(8).DATA_TYPE := 'TEXT';
  column_tab(9).DATA_TYPE := 'TEXT';
  column_tab(10).DATA_TYPE := 'TEXT';
  column_tab(11).DATA_TYPE := 'TEXT';
  column_tab(12).DATA_TYPE := 'TEXT';
  column_tab(13).DATA_TYPE := 'TEXT';
  column_tab(14).DATA_TYPE := 'TEXT';
  column_tab(15).DATA_TYPE := 'TEXT';
  column_tab(16).DATA_TYPE := 'TEXT';
  column_tab(17).DATA_TYPE := 'TEXT';
  column_tab(18).DATA_TYPE := 'TEXT';
  column_tab(19).DATA_TYPE := 'TEXT';
  column_tab(20).DATA_TYPE := 'TEXT';
  column_tab(21).DATA_TYPE := 'TEXT';
  column_tab(22).DATA_TYPE := 'TEXT';
  column_tab(23).DATA_TYPE := 'TEXT';
  column_tab(24).DATA_TYPE := 'TEXT';
  column_tab(25).DATA_TYPE := 'TEXT';
  column_tab(26).DATA_TYPE := 'TEXT';
  column_tab(27).DATA_TYPE := 'TEXT';
  column_tab(28).DATA_TYPE := 'TEXT';
  column_tab(29).DATA_TYPE := 'TEXT';
  column_tab(30).DATA_TYPE := 'TEXT';
  column_tab(31).DATA_TYPE := 'TEXT';
  column_tab(32).DATA_TYPE := 'LONG';
  column_tab(33).DATA_TYPE := 'LONG';
  column_tab(34).DATA_TYPE := 'LONG';
  column_tab(35).DATA_TYPE := 'LONG';
  column_tab(36).DATA_TYPE := 'LONG';
  column_tab(37).DATA_TYPE := 'LONG';
  column_tab(38).DATA_TYPE := 'LONG';
  column_tab(39).DATA_TYPE := 'LONG';
  column_tab(40).DATA_TYPE := 'LONG';
  column_tab(41).DATA_TYPE := 'LONG';
  column_tab(42).DATA_TYPE := 'LONG';
  column_tab(43).DATA_TYPE := 'LONG';
  column_tab(44).DATA_TYPE := 'LONG';
  column_tab(45).DATA_TYPE := 'LONG';
  column_tab(46).DATA_TYPE := 'LONG';
  column_tab(47).DATA_TYPE := 'LONG';
  column_tab(48).DATA_TYPE := 'LONG';
  column_tab(49).DATA_TYPE := 'LONG';
  column_tab(50).DATA_TYPE := 'LONG';
  column_tab(51).DATA_TYPE := 'LONG';
  column_tab(52).DATA_TYPE := 'LONG';
  column_tab(53).DATA_TYPE := 'LONG';
  column_tab(54).DATA_TYPE := 'LONG';
  column_tab(55).DATA_TYPE := 'LONG';
  column_tab(56).DATA_TYPE := 'LONG';
  column_tab(57).DATA_TYPE := 'LONG';
  column_tab(58).DATA_TYPE := 'LONG';
  column_tab(59).DATA_TYPE := 'LONG';
  column_tab(60).DATA_TYPE := 'LONG';
  column_tab(61).DATA_TYPE := 'LONG';
    --
  l_sql :=
 'select segment1||''|''||segment2||''|''||segment3||''|''||segment4||''|''||segment5||''|''
  ||segment6||''|''||segment7||''|''||segment8||''|''||segment9||''|''||segment10||''|''
  ||segment11||''|''||segment12||''|''||segment13||''|''||segment14||''|''||segment15||''|''
  ||segment16||''|''||segment17||''|''||segment18||''|''||segment19||''|''||segment20||''|''
  ||segment21||''|''||segment22||''|''||segment23||''|''||segment24||''|''||segment25||''|''
  ||segment26||''|''||segment27||''|''||segment28||''|''||segment29||''|''||segment30 into l_data
  from per_job_definitions where job_definition_id = :p_data_tab;';
    --
   l_table_id := kbdx_kube_seed_pkg.insert_table (p_table_name => 'KB_JOB_DEFINITIONS', p_aol_owner_id => -999, p_table_type => 'DIM',
                              p_sql_stmt => l_sql, p_plsql_dim_tab => 'kbdx_kube_utilities.g_job_def_tab', p_dimension_sql_id => 3,
                              p_kube_type_id => p_kube_type_id, p_worksheet_id => l_worksheet_id,p_columns => column_tab);
    --
    -- 'KB_JOBS_CXT_DATA'
    --
  column_tab.delete;
  column_tab(1).name := 'JOB_ID';
  column_tab(2).name := 'JOB_DEFINITION_ID';
  column_tab(3).name := 'CX_INFO_CODE';
  column_tab(4).name := 'DETAIL_ID1';
  column_tab(5).name := 'DETAIL_ID2';
  column_tab(6).name := 'DETAIL_ID3';
  column_tab(7).name := 'DETAIL_ID4';
  column_tab(8).name := 'DETAIL_ID5';
  column_tab(9).name := 'DETAIL_ID6';
  column_tab(10).name := 'DETAIL_ID7';
  column_tab(11).name := 'DETAIL_ID8';
  column_tab(12).name := 'DETAIL_ID9';
  column_tab(13).name := 'DETAIL_ID10';
  column_tab(14).name := 'DETAIL_ID11';
  column_tab(15).name := 'DETAIL_ID12';
  column_tab(16).name := 'DETAIL_ID13';
  column_tab(17).name := 'DETAIL_ID14';
  column_tab(18).name := 'DETAIL_ID15';
  column_tab(19).name := 'DETAIL_ID16';
  column_tab(20).name := 'DETAIL_ID17';
  column_tab(21).name := 'DETAIL_ID18';
  column_tab(22).name := 'DETAIL_ID19';
  column_tab(23).name := 'DETAIL_ID20';
  column_tab(24).name := 'VS_ID1';
  column_tab(25).name := 'VS_ID2';
  column_tab(26).name := 'VS_ID3';
  column_tab(27).name := 'VS_ID4';
  column_tab(28).name := 'VS_ID5';
  column_tab(29).name := 'VS_ID6';
  column_tab(30).name := 'VS_ID7';
  column_tab(31).name := 'VS_ID8';
  column_tab(32).name := 'VS_ID9';
  column_tab(33).name := 'VS_ID10';
  column_tab(34).name := 'VS_ID11';
  column_tab(35).name := 'VS_ID12';
  column_tab(36).name := 'VS_ID13';
  column_tab(37).name := 'VS_ID14';
  column_tab(38).name := 'VS_ID15';
  column_tab(39).name := 'VS_ID16';
  column_tab(40).name := 'VS_ID17';
  column_tab(41).name := 'VS_ID18';
  column_tab(42).name := 'VS_ID19';
  column_tab(43).name := 'VS_ID20';
    --
  column_tab(1).DATA_TYPE := 'LONG';
  column_tab(2).DATA_TYPE := 'LONG';
  column_tab(3).DATA_TYPE := 'TEXT';
  column_tab(4).DATA_TYPE := 'TEXT';
  column_tab(5).DATA_TYPE := 'TEXT';
  column_tab(6).DATA_TYPE := 'TEXT';
  column_tab(7).DATA_TYPE := 'TEXT';
  column_tab(8).DATA_TYPE := 'TEXT';
  column_tab(9).DATA_TYPE := 'TEXT';
  column_tab(10).DATA_TYPE := 'TEXT';
  column_tab(11).DATA_TYPE := 'TEXT';
  column_tab(12).DATA_TYPE := 'TEXT';
  column_tab(13).DATA_TYPE := 'TEXT';
  column_tab(14).DATA_TYPE := 'TEXT';
  column_tab(15).DATA_TYPE := 'TEXT';
  column_tab(16).DATA_TYPE := 'TEXT';
  column_tab(17).DATA_TYPE := 'TEXT';
  column_tab(18).DATA_TYPE := 'TEXT';
  column_tab(19).DATA_TYPE := 'TEXT';
  column_tab(20).DATA_TYPE := 'TEXT';
  column_tab(21).DATA_TYPE := 'TEXT';
  column_tab(22).DATA_TYPE := 'TEXT';
  column_tab(23).DATA_TYPE := 'TEXT';
  column_tab(24).DATA_TYPE := 'LONG';
  column_tab(25).DATA_TYPE := 'LONG';
  column_tab(26).DATA_TYPE := 'LONG';
  column_tab(27).DATA_TYPE := 'LONG';
  column_tab(28).DATA_TYPE := 'LONG';
  column_tab(29).DATA_TYPE := 'LONG';
  column_tab(30).DATA_TYPE := 'LONG';
  column_tab(31).DATA_TYPE := 'LONG';
  column_tab(32).DATA_TYPE := 'LONG';
  column_tab(33).DATA_TYPE := 'LONG';
  column_tab(34).DATA_TYPE := 'LONG';
  column_tab(35).DATA_TYPE := 'LONG';
  column_tab(36).DATA_TYPE := 'LONG';
  column_tab(37).DATA_TYPE := 'LONG';
  column_tab(38).DATA_TYPE := 'LONG';
  column_tab(39).DATA_TYPE := 'LONG';
  column_tab(40).DATA_TYPE := 'LONG';
  column_tab(41).DATA_TYPE := 'LONG';
  column_tab(42).DATA_TYPE := 'LONG';
  column_tab(43).DATA_TYPE := 'LONG';
    --
  l_sql :=
 'select job_definition_id||''|''||job_information_category||''|''||job_information1||''|''||job_information2||''|''||job_information3||''|''||job_information4||''|''||job_information5||''|''
  ||job_information6||''|''||job_information7||''|''||job_information8||''|''||job_information9||''|''||job_information10||''|''
  ||job_information11||''|''||job_information12||''|''||job_information13||''|''||job_information14||''|''||job_information15||''|''
  ||job_information16||''|''||job_information17||''|''||job_information18||''|''||job_information19||''|''||job_information20
  into l_data from per_jobs where job_id = :p_data_tab;';
    --
  l_table_id := kbdx_kube_seed_pkg.insert_table (p_table_name => 'KB_JOBS_CXT_DATA', p_aol_owner_id => -999, p_table_type => 'DIM',
                              p_sql_stmt => l_sql, p_plsql_dim_tab => 'kbdx_kube_utilities.g_job_tab', p_dimension_sql_id => 3,
                              p_kube_type_id => p_kube_type_id, p_worksheet_id => l_worksheet_id,p_columns => column_tab);
    --
  if upper(p_context) <> 'ALL' then
    l_cxt_id := kbdx_kube_seed_pkg.build_ff_tables (
                           p_app_table => 'PER_JOBS',
                           p_source_table => 'KB_JOBS_CXT_DATA',
                           p_client_table => 'KB_JOBS_'||upper(p_context)||'_CONTEXT_DATA',
                           p_source_column => 'JOB_ID',
                           p_context => upper(p_context),
                           p_kube_type_id => p_kube_type_id,
                           p_flex_type => 'D',
                           p_bg_id => NULL);
      --
    kbdx_kube_seed_pkg.store_addl_ff_columns (p_cxt_id => l_cxt_id, p_source_column => 'JOB_DEFINITION_ID',
                           p_source_table => 'KB_JOBS_CXT_DATA', p_kube_type_id =>p_kube_type_id,
                           p_sequence => 1);
  else
    For i in kbdx_kube_seed_pkg.c_get_legislations Loop
        --JAK 05/05/2010
      if loldDffKffnaming then
        lv_client_table_name := 'KB_JOBS_'||upper(p_context)||'_CONTEXT_DATA';
      else
        lv_client_table_name := 'KB_JOBS_'||i.legislation_code||'_CONTEXT_DATA';
      end if;
        --
      l_cxt_id := kbdx_kube_seed_pkg.build_ff_tables (
                             p_app_table => 'PER_JOBS',
                             p_source_table => 'KB_JOBS_CXT_DATA',
                             p_client_table => lv_client_table_name,
                             p_source_column => 'JOB_ID',
                             p_context => i.legislation_code,
                             p_kube_type_id => p_kube_type_id,
                             p_flex_type => 'D',
                             p_bg_id => NULL);

      kbdx_kube_seed_pkg.store_addl_ff_columns (p_cxt_id => l_cxt_id, p_source_column => 'JOB_DEFINITION_ID',
                             p_source_table => 'KB_JOBS_CXT_DATA', p_kube_type_id =>p_kube_type_id,
                             p_sequence => 1);
    End Loop;
      --
  end if;
    --
  l_cxt_id := kbdx_kube_seed_pkg.build_ff_tables (
                         p_app_table => 'PER_JOBS',
                         p_source_table => 'KB_JOB_ADDL_DATA',
                         p_client_table => 'KB_JOB_FLEXFIELD_DATA',
                         p_source_column => 'JOB_ID',
                         p_context => 'Global Data Elements',
                         p_kube_type_id => p_kube_type_id,
                         p_flex_type => 'D',
                         p_bg_id => NULL);
    --
  kbdx_kube_seed_pkg.store_addl_ff_columns (p_cxt_id => l_cxt_id, p_source_column => 'JOB_DEFINITION_ID',
                         p_source_table => 'KB_JOB_ADDL_DATA', p_kube_type_id => p_kube_type_id,
                         p_sequence => 1);
    --
  For i in kbdx_kube_seed_pkg.c_get_bg Loop
      --JAK 05/05/2010
    if loldDffKffnaming then
      lv_client_table_name := 'KB_JOB_KEYFLEX_DATA';
    else
      lv_client_table_name := 'KB_JOB_KEYFLEX_DATA'||i.business_group_id;
    end if;
      --
    l_cxt_id := kbdx_kube_seed_pkg.build_ff_tables (
                             p_app_table => 'PER_JOB_DEFINITIONS',
                             p_source_table => 'KB_JOB_DEFINITIONS',
                             p_client_table => lv_client_table_name,
                             p_source_column => 'JOB_DEFINITION_ID',
                             p_context => i.job_structure,
                             p_kube_type_id => p_kube_type_id,
                             p_flex_type => 'K',
                             p_bg_id  => i.business_group_id);
  End Loop;
    --
End per_jobs;

Procedure per_grades(p_kube_type_id in number) as
 l_sql varchar2(6000);
 l_worksheet_id Number;
 column_tab kbdx_kube_seed_pkg.column_tabtype;
 l_table_id Number;
 l_cxt_id Number;
 lv_client_table_name varchar2(300);
 loldDffKffnaming boolean := false;
Begin
    --JAK 05/05/2010
  if get_build_ff_tables_naming <= 40056 then
    loldDffKffnaming := true;
  end if;
    --
  kbdx_kube_seed_pkg.delete_table(p_kube_type_id => p_kube_type_id,
                                  p_table_name => 'KB_GRADE_ADDL_DATA');
  kbdx_kube_seed_pkg.delete_table(p_kube_type_id => p_kube_type_id,
                                  p_table_name => 'KB_GRADE_DEFINITIONS');
    --
  l_worksheet_id := kbdx_kube_seed_pkg.get_worksheet_id(p_kube_type_id => p_kube_type_id);
    --
    -- 'KB_GRADE_ADDL_DATA'
    --
  column_tab.delete;
  column_tab(1).name := 'GRADE_ID';
  column_tab(2).name := 'GRADE_DEFINITION_ID';
  column_tab(3).name := 'DETAIL_ID1';
  column_tab(4).name := 'DETAIL_ID2';
  column_tab(5).name := 'DETAIL_ID3';
  column_tab(6).name := 'DETAIL_ID4';
  column_tab(7).name := 'DETAIL_ID5';
  column_tab(8).name := 'DETAIL_ID6';
  column_tab(9).name := 'DETAIL_ID7';
  column_tab(10).name := 'DETAIL_ID8';
  column_tab(11).name := 'DETAIL_ID9';
  column_tab(12).name := 'DETAIL_ID10';
  column_tab(13).name := 'DETAIL_ID11';
  column_tab(14).name := 'DETAIL_ID12';
  column_tab(15).name := 'DETAIL_ID13';
  column_tab(16).name := 'DETAIL_ID14';
  column_tab(17).name := 'DETAIL_ID15';
  column_tab(18).name := 'DETAIL_ID16';
  column_tab(19).name := 'DETAIL_ID17';
  column_tab(20).name := 'DETAIL_ID18';
  column_tab(21).name := 'DETAIL_ID19';
  column_tab(22).name := 'DETAIL_ID20';
  column_tab(23).name := 'VS_ID1';
  column_tab(24).name := 'VS_ID2';
  column_tab(25).name := 'VS_ID3';
  column_tab(26).name := 'VS_ID4';
  column_tab(27).name := 'VS_ID5';
  column_tab(28).name := 'VS_ID6';
  column_tab(29).name := 'VS_ID7';
  column_tab(30).name := 'VS_ID8';
  column_tab(31).name := 'VS_ID9';
  column_tab(32).name := 'VS_ID10';
  column_tab(33).name := 'VS_ID11';
  column_tab(34).name := 'VS_ID12';
  column_tab(35).name := 'VS_ID13';
  column_tab(36).name := 'VS_ID14';
  column_tab(37).name := 'VS_ID15';
  column_tab(38).name := 'VS_ID16';
  column_tab(39).name := 'VS_ID17';
  column_tab(40).name := 'VS_ID18';
  column_tab(41).name := 'VS_ID19';
  column_tab(42).name := 'VS_ID20';
    --
  column_tab(1).DATA_TYPE := 'LONG';
  column_tab(2).DATA_TYPE := 'LONG';
  column_tab(3).DATA_TYPE := 'TEXT';
  column_tab(4).DATA_TYPE := 'TEXT';
  column_tab(5).DATA_TYPE := 'TEXT';
  column_tab(6).DATA_TYPE := 'TEXT';
  column_tab(7).DATA_TYPE := 'TEXT';
  column_tab(8).DATA_TYPE := 'TEXT';
  column_tab(9).DATA_TYPE := 'TEXT';
  column_tab(10).DATA_TYPE := 'TEXT';
  column_tab(11).DATA_TYPE := 'TEXT';
  column_tab(12).DATA_TYPE := 'TEXT';
  column_tab(13).DATA_TYPE := 'TEXT';
  column_tab(14).DATA_TYPE := 'TEXT';
  column_tab(15).DATA_TYPE := 'TEXT';
  column_tab(16).DATA_TYPE := 'TEXT';
  column_tab(17).DATA_TYPE := 'TEXT';
  column_tab(18).DATA_TYPE := 'TEXT';
  column_tab(19).DATA_TYPE := 'TEXT';
  column_tab(20).DATA_TYPE := 'TEXT';
  column_tab(21).DATA_TYPE := 'TEXT';
  column_tab(22).DATA_TYPE := 'TEXT';
  column_tab(23).DATA_TYPE := 'LONG';
  column_tab(24).DATA_TYPE := 'LONG';
  column_tab(25).DATA_TYPE := 'LONG';
  column_tab(26).DATA_TYPE := 'LONG';
  column_tab(27).DATA_TYPE := 'LONG';
  column_tab(28).DATA_TYPE := 'LONG';
  column_tab(29).DATA_TYPE := 'LONG';
  column_tab(30).DATA_TYPE := 'LONG';
  column_tab(31).DATA_TYPE := 'LONG';
  column_tab(32).DATA_TYPE := 'LONG';
  column_tab(33).DATA_TYPE := 'LONG';
  column_tab(34).DATA_TYPE := 'LONG';
  column_tab(35).DATA_TYPE := 'LONG';
  column_tab(36).DATA_TYPE := 'LONG';
  column_tab(37).DATA_TYPE := 'LONG';
  column_tab(38).DATA_TYPE := 'LONG';
  column_tab(39).DATA_TYPE := 'LONG';
  column_tab(40).DATA_TYPE := 'LONG';
  column_tab(41).DATA_TYPE := 'LONG';
  column_tab(42).DATA_TYPE := 'LONG';
    --
  l_sql :=
 'select GRADE_DEFINITION_ID||''|''||attribute1||''|''||attribute2||''|''||attribute3||''|''||attribute4||''|''||attribute5||''|''
  ||attribute6||''|''||attribute7||''|''||attribute8||''|''||attribute9||''|''||attribute10||''|''
  ||attribute11||''|''||attribute12||''|''||attribute13||''|''||attribute14||''|''||attribute15||''|''
  ||attribute16||''|''||attribute17||''|''||attribute18||''|''||attribute19||''|''||attribute20
  into l_data from per_grades where grade_id = :p_data_tab;';
    --
  l_table_id := kbdx_kube_seed_pkg.insert_table (p_table_name => 'KB_GRADE_ADDL_DATA', p_aol_owner_id => -999, p_table_type => 'DIM',
                              p_sql_stmt => l_sql, p_plsql_dim_tab => 'kbdx_kube_utilities.g_grade_tab', p_dimension_sql_id => 3,
                              p_kube_type_id => p_kube_type_id, p_worksheet_id => l_worksheet_id,p_columns => column_tab);
    --
    -- 'KB_GRADE_DEFINITIONS'
    --
  column_tab.delete;
  column_tab(1).name := 'GRADE_DEFINITION_ID';
  column_tab(2).name := 'DETAIL_ID1';
  column_tab(3).name := 'DETAIL_ID2';
  column_tab(4).name := 'DETAIL_ID3';
  column_tab(5).name := 'DETAIL_ID4';
  column_tab(6).name := 'DETAIL_ID5';
  column_tab(7).name := 'DETAIL_ID6';
  column_tab(8).name := 'DETAIL_ID7';
  column_tab(9).name := 'DETAIL_ID8';
  column_tab(10).name := 'DETAIL_ID9';
  column_tab(11).name := 'DETAIL_ID10';
  column_tab(12).name := 'DETAIL_ID11';
  column_tab(13).name := 'DETAIL_ID12';
  column_tab(14).name := 'DETAIL_ID13';
  column_tab(15).name := 'DETAIL_ID14';
  column_tab(16).name := 'DETAIL_ID15';
  column_tab(17).name := 'DETAIL_ID16';
  column_tab(18).name := 'DETAIL_ID17';
  column_tab(19).name := 'DETAIL_ID18';
  column_tab(20).name := 'DETAIL_ID19';
  column_tab(21).name := 'DETAIL_ID20';
  column_tab(22).name := 'DETAIL_ID21';
  column_tab(23).name := 'DETAIL_ID22';
  column_tab(24).name := 'DETAIL_ID23';
  column_tab(25).name := 'DETAIL_ID24';
  column_tab(26).name := 'DETAIL_ID25';
  column_tab(27).name := 'DETAIL_ID26';
  column_tab(28).name := 'DETAIL_ID27';
  column_tab(29).name := 'DETAIL_ID28';
  column_tab(30).name := 'DETAIL_ID29';
  column_tab(31).name := 'DETAIL_ID30';
  column_tab(32).name := 'VS_ID1';
  column_tab(33).name := 'VS_ID2';
  column_tab(34).name := 'VS_ID3';
  column_tab(35).name := 'VS_ID4';
  column_tab(36).name := 'VS_ID5';
  column_tab(37).name := 'VS_ID6';
  column_tab(38).name := 'VS_ID7';
  column_tab(39).name := 'VS_ID8';
  column_tab(40).name := 'VS_ID9';
  column_tab(41).name := 'VS_ID10';
  column_tab(42).name := 'VS_ID11';
  column_tab(43).name := 'VS_ID12';
  column_tab(44).name := 'VS_ID13';
  column_tab(45).name := 'VS_ID14';
  column_tab(46).name := 'VS_ID15';
  column_tab(47).name := 'VS_ID16';
  column_tab(48).name := 'VS_ID17';
  column_tab(49).name := 'VS_ID18';
  column_tab(50).name := 'VS_ID19';
  column_tab(51).name := 'VS_ID20';
  column_tab(52).name := 'VS_ID21';
  column_tab(53).name := 'VS_ID22';
  column_tab(54).name := 'VS_ID23';
  column_tab(55).name := 'VS_ID24';
  column_tab(56).name := 'VS_ID25';
  column_tab(57).name := 'VS_ID26';
  column_tab(58).name := 'VS_ID27';
  column_tab(59).name := 'VS_ID28';
  column_tab(60).name := 'VS_ID29';
  column_tab(61).name := 'VS_ID30';
    --
  column_tab(1).DATA_TYPE := 'LONG';
  column_tab(2).DATA_TYPE := 'TEXT';
  column_tab(3).DATA_TYPE := 'TEXT';
  column_tab(4).DATA_TYPE := 'TEXT';
  column_tab(5).DATA_TYPE := 'TEXT';
  column_tab(6).DATA_TYPE := 'TEXT';
  column_tab(7).DATA_TYPE := 'TEXT';
  column_tab(8).DATA_TYPE := 'TEXT';
  column_tab(9).DATA_TYPE := 'TEXT';
  column_tab(10).DATA_TYPE := 'TEXT';
  column_tab(11).DATA_TYPE := 'TEXT';
  column_tab(12).DATA_TYPE := 'TEXT';
  column_tab(13).DATA_TYPE := 'TEXT';
  column_tab(14).DATA_TYPE := 'TEXT';
  column_tab(15).DATA_TYPE := 'TEXT';
  column_tab(16).DATA_TYPE := 'TEXT';
  column_tab(17).DATA_TYPE := 'TEXT';
  column_tab(18).DATA_TYPE := 'TEXT';
  column_tab(19).DATA_TYPE := 'TEXT';
  column_tab(20).DATA_TYPE := 'TEXT';
  column_tab(21).DATA_TYPE := 'TEXT';
  column_tab(22).DATA_TYPE := 'TEXT';
  column_tab(23).DATA_TYPE := 'TEXT';
  column_tab(24).DATA_TYPE := 'TEXT';
  column_tab(25).DATA_TYPE := 'TEXT';
  column_tab(26).DATA_TYPE := 'TEXT';
  column_tab(27).DATA_TYPE := 'TEXT';
  column_tab(28).DATA_TYPE := 'TEXT';
  column_tab(29).DATA_TYPE := 'TEXT';
  column_tab(30).DATA_TYPE := 'TEXT';
  column_tab(31).DATA_TYPE := 'TEXT';
  column_tab(32).DATA_TYPE := 'LONG';
  column_tab(33).DATA_TYPE := 'LONG';
  column_tab(34).DATA_TYPE := 'LONG';
  column_tab(35).DATA_TYPE := 'LONG';
  column_tab(36).DATA_TYPE := 'LONG';
  column_tab(37).DATA_TYPE := 'LONG';
  column_tab(38).DATA_TYPE := 'LONG';
  column_tab(39).DATA_TYPE := 'LONG';
  column_tab(40).DATA_TYPE := 'LONG';
  column_tab(41).DATA_TYPE := 'LONG';
  column_tab(42).DATA_TYPE := 'LONG';
  column_tab(43).DATA_TYPE := 'LONG';
  column_tab(44).DATA_TYPE := 'LONG';
  column_tab(45).DATA_TYPE := 'LONG';
  column_tab(46).DATA_TYPE := 'LONG';
  column_tab(47).DATA_TYPE := 'LONG';
  column_tab(48).DATA_TYPE := 'LONG';
  column_tab(49).DATA_TYPE := 'LONG';
  column_tab(50).DATA_TYPE := 'LONG';
  column_tab(51).DATA_TYPE := 'LONG';
  column_tab(52).DATA_TYPE := 'LONG';
  column_tab(53).DATA_TYPE := 'LONG';
  column_tab(54).DATA_TYPE := 'LONG';
  column_tab(55).DATA_TYPE := 'LONG';
  column_tab(56).DATA_TYPE := 'LONG';
  column_tab(57).DATA_TYPE := 'LONG';
  column_tab(58).DATA_TYPE := 'LONG';
  column_tab(59).DATA_TYPE := 'LONG';
  column_tab(60).DATA_TYPE := 'LONG';
  column_tab(61).DATA_TYPE := 'LONG';
    --
  l_sql :=
 'select segment1||''|''||segment2||''|''||segment3||''|''||segment4||''|''||segment5||''|''
  ||segment6||''|''||segment7||''|''||segment8||''|''||segment9||''|''||segment10||''|''
  ||segment11||''|''||segment12||''|''||segment13||''|''||segment14||''|''||segment15||''|''
  ||segment16||''|''||segment17||''|''||segment18||''|''||segment19||''|''||segment20||''|''
  ||segment21||''|''||segment22||''|''||segment23||''|''||segment24||''|''||segment25||''|''
  ||segment26||''|''||segment27||''|''||segment28||''|''||segment29||''|''||segment30
  into l_data from per_grade_definitions where grade_definition_id = :p_data_tab;';
    --
  l_table_id := kbdx_kube_seed_pkg.insert_table (p_table_name => 'KB_GRADE_DEFINITIONS', p_aol_owner_id => -999, p_table_type => 'DIM',
                              p_sql_stmt => l_sql, p_plsql_dim_tab => 'kbdx_kube_utilities.g_grade_def_tab', p_dimension_sql_id => 3,
                              p_kube_type_id => p_kube_type_id, p_worksheet_id => l_worksheet_id,p_columns => column_tab);
    --
  l_cxt_id := kbdx_kube_seed_pkg.build_ff_tables (
                         p_app_table => 'PER_GRADES',
                         p_source_table => 'KB_GRADE_ADDL_DATA',
                         p_client_table => 'KB_GRADE_FLEXFIELD_DATA',
                         p_source_column => 'GRADE_ID',
                         p_context => 'Global Data Elements',
                         p_kube_type_id => p_kube_type_id,
                         p_flex_type => 'D',
                         p_bg_id => NULL);
    --
  kbdx_kube_seed_pkg.store_addl_ff_columns (p_cxt_id => l_cxt_id, p_source_column => 'GRADE_DEFINITION_ID',
                         p_source_table => 'KB_GRADE_ADDL_DATA', p_kube_type_id => p_kube_type_id,
                         p_sequence => 1);
    --
  For i in kbdx_kube_seed_pkg.c_get_bg Loop
      --JAK 05/05/2010
    if loldDffKffnaming then
      lv_client_table_name := 'KB_GRADE_KEYFLEX_DATA';
    else
      lv_client_table_name := 'KB_GRADE_KEYFLEX_DATA'||i.business_group_id;
    end if;
      --
    l_cxt_id := kbdx_kube_seed_pkg.build_ff_tables (
                              p_app_table => 'PER_GRADE_DEFINITIONS',
                              p_source_table => 'KB_GRADE_DEFINITIONS',
                              p_client_table => lv_client_table_name,
                              p_source_column => 'GRADE_DEFINITION_ID',
                              p_context => i.grade_structure,
                              p_kube_type_id => p_kube_type_id,
                              p_flex_type => 'K',
                              p_bg_id  => i.business_group_id);
  End Loop;
    --
End per_grades;

Procedure per_position_kf(p_kube_type_id in number,
                          p_dim_tab in varchar2) as
 l_sql varchar2(6000);
 l_worksheet_id Number;
 column_tab kbdx_kube_seed_pkg.column_tabtype;
 l_table_id Number;
 l_cxt_id Number;
 lv_client_table_name varchar2(300);
 loldDffKffnaming boolean := false;
Begin
    --JAK 05/05/2010
  if get_build_ff_tables_naming <= 40056 then
    loldDffKffnaming := true;
  end if;
    --
  l_worksheet_id := kbdx_kube_seed_pkg.get_worksheet_id(p_kube_type_id => p_kube_type_id);
    --
    -- 'KB_POSITION_SOURCE'
    --
  column_tab.delete;
  column_tab(1).name := 'POSITION_DEFINITION_ID';
  column_tab(2).name := 'DETAIL_ID1';
  column_tab(3).name := 'DETAIL_ID2';
  column_tab(4).name := 'DETAIL_ID3';
  column_tab(5).name := 'DETAIL_ID4';
  column_tab(6).name := 'DETAIL_ID5';
  column_tab(7).name := 'DETAIL_ID6';
  column_tab(8).name := 'DETAIL_ID7';
  column_tab(9).name := 'DETAIL_ID8';
  column_tab(10).name := 'DETAIL_ID9';
  column_tab(11).name := 'DETAIL_ID10';
  column_tab(12).name := 'DETAIL_ID11';
  column_tab(13).name := 'DETAIL_ID12';
  column_tab(14).name := 'DETAIL_ID13';
  column_tab(15).name := 'DETAIL_ID14';
  column_tab(16).name := 'DETAIL_ID15';
  column_tab(17).name := 'DETAIL_ID16';
  column_tab(18).name := 'DETAIL_ID17';
  column_tab(19).name := 'DETAIL_ID18';
  column_tab(20).name := 'DETAIL_ID19';
  column_tab(21).name := 'DETAIL_ID20';
  column_tab(22).name := 'DETAIL_ID21';
  column_tab(23).name := 'DETAIL_ID22';
  column_tab(24).name := 'DETAIL_ID23';
  column_tab(25).name := 'DETAIL_ID24';
  column_tab(26).name := 'DETAIL_ID25';
  column_tab(27).name := 'DETAIL_ID26';
  column_tab(28).name := 'DETAIL_ID27';
  column_tab(29).name := 'DETAIL_ID28';
  column_tab(30).name := 'DETAIL_ID29';
  column_tab(31).name := 'DETAIL_ID30';
  column_tab(32).name := 'VS_ID1';
  column_tab(33).name := 'VS_ID2';
  column_tab(34).name := 'VS_ID3';
  column_tab(35).name := 'VS_ID4';
  column_tab(36).name := 'VS_ID5';
  column_tab(37).name := 'VS_ID6';
  column_tab(38).name := 'VS_ID7';
  column_tab(39).name := 'VS_ID8';
  column_tab(40).name := 'VS_ID9';
  column_tab(41).name := 'VS_ID10';
  column_tab(42).name := 'VS_ID11';
  column_tab(43).name := 'VS_ID12';
  column_tab(44).name := 'VS_ID13';
  column_tab(45).name := 'VS_ID14';
  column_tab(46).name := 'VS_ID15';
  column_tab(47).name := 'VS_ID16';
  column_tab(48).name := 'VS_ID17';
  column_tab(49).name := 'VS_ID18';
  column_tab(50).name := 'VS_ID19';
  column_tab(51).name := 'VS_ID20';
  column_tab(52).name := 'VS_ID21';
  column_tab(53).name := 'VS_ID22';
  column_tab(54).name := 'VS_ID23';
  column_tab(55).name := 'VS_ID24';
  column_tab(56).name := 'VS_ID25';
  column_tab(57).name := 'VS_ID26';
  column_tab(58).name := 'VS_ID27';
  column_tab(59).name := 'VS_ID28';
  column_tab(60).name := 'VS_ID29';
  column_tab(61).name := 'VS_ID30';
    --
  column_tab(1).data_type := 'LONG';
  column_tab(2).data_type := 'TEXT';
  column_tab(3).data_type := 'TEXT';
  column_tab(4).data_type := 'TEXT';
  column_tab(5).data_type := 'TEXT';
  column_tab(6).data_type := 'TEXT';
  column_tab(7).data_type := 'TEXT';
  column_tab(8).data_type := 'TEXT';
  column_tab(9).data_type := 'TEXT';
  column_tab(10).data_type := 'TEXT';
  column_tab(11).data_type := 'TEXT';
  column_tab(12).data_type := 'TEXT';
  column_tab(13).data_type := 'TEXT';
  column_tab(14).data_type := 'TEXT';
  column_tab(15).data_type := 'TEXT';
  column_tab(16).data_type := 'TEXT';
  column_tab(17).data_type := 'TEXT';
  column_tab(18).data_type := 'TEXT';
  column_tab(19).data_type := 'TEXT';
  column_tab(20).data_type := 'TEXT';
  column_tab(21).data_type := 'TEXT';
  column_tab(22).data_type := 'TEXT';
  column_tab(23).data_type := 'TEXT';
  column_tab(24).data_type := 'TEXT';
  column_tab(25).data_type := 'TEXT';
  column_tab(26).data_type := 'TEXT';
  column_tab(27).data_type := 'TEXT';
  column_tab(28).data_type := 'TEXT';
  column_tab(29).data_type := 'TEXT';
  column_tab(30).data_type := 'TEXT';
  column_tab(31).data_type := 'TEXT';
  column_tab(32).data_type := 'LONG';
  column_tab(33).data_type := 'LONG';
  column_tab(34).data_type := 'LONG';
  column_tab(35).data_type := 'LONG';
  column_tab(36).data_type := 'LONG';
  column_tab(37).data_type := 'LONG';
  column_tab(38).data_type := 'LONG';
  column_tab(39).data_type := 'LONG';
  column_tab(40).data_type := 'LONG';
  column_tab(41).data_type := 'LONG';
  column_tab(42).data_type := 'LONG';
  column_tab(43).data_type := 'LONG';
  column_tab(44).data_type := 'LONG';
  column_tab(45).data_type := 'LONG';
  column_tab(46).data_type := 'LONG';
  column_tab(47).data_type := 'LONG';
  column_tab(48).data_type := 'LONG';
  column_tab(49).data_type := 'LONG';
  column_tab(50).data_type := 'LONG';
  column_tab(51).data_type := 'LONG';
  column_tab(52).data_type := 'LONG';
  column_tab(53).data_type := 'LONG';
  column_tab(54).data_type := 'LONG';
  column_tab(55).data_type := 'LONG';
  column_tab(56).data_type := 'LONG';
  column_tab(57).data_type := 'LONG';
  column_tab(58).data_type := 'LONG';
  column_tab(59).data_type := 'LONG';
  column_tab(60).data_type := 'LONG';
  column_tab(61).data_type := 'LONG';
    --
  l_sql :=
 'select segment1||''|''||segment2||''|''||segment3||''|''||segment4||''|''||segment5||''|''
  ||segment6||''|''||segment7||''|''||segment8||''|''||segment9||''|''||segment10||''|''
  ||segment11||''|''||segment12||''|''||segment13||''|''||segment14||''|''||segment15||''|''
  ||segment16||''|''||segment17||''|''||segment18||''|''||segment19||''|''||segment20||''|''
  ||segment21||''|''||segment22||''|''||segment23||''|''||segment24||''|''||segment25||''|''
  ||segment26||''|''||segment27||''|''||segment28||''|''||segment29||''|''||segment30
  into l_data from per_position_definitions where position_definition_id = :p_data_tab;';
    --
  l_table_id := kbdx_kube_seed_pkg.insert_table (p_table_name => 'KB_POSITION_SOURCE', p_aol_owner_id => -999, p_table_type => 'DIM',
                              p_sql_stmt => l_sql, p_plsql_dim_tab => p_dim_tab, p_dimension_sql_id => 3,
                              p_kube_type_id => p_kube_type_id, p_worksheet_id => l_worksheet_id,p_columns => column_tab);
    --
    -- 'KB_POSITION_ADDL_DATA'
    --
  column_tab.delete;
  column_tab(1).name := 'POSITION_ID';
  column_tab(2).name := 'POSITION_DEFINITION_ID';
  column_tab(3).name := 'DETAIL_ID1';
  column_tab(4).name := 'DETAIL_ID2';
  column_tab(5).name := 'DETAIL_ID3';
  column_tab(6).name := 'DETAIL_ID4';
  column_tab(7).name := 'DETAIL_ID5';
  column_tab(8).name := 'DETAIL_ID6';
  column_tab(9).name := 'DETAIL_ID7';
  column_tab(10).name := 'DETAIL_ID8';
  column_tab(11).name := 'DETAIL_ID9';
  column_tab(12).name := 'DETAIL_ID10';
  column_tab(13).name := 'DETAIL_ID11';
  column_tab(14).name := 'DETAIL_ID12';
  column_tab(15).name := 'DETAIL_ID13';
  column_tab(16).name := 'DETAIL_ID14';
  column_tab(17).name := 'DETAIL_ID15';
  column_tab(18).name := 'DETAIL_ID16';
  column_tab(19).name := 'DETAIL_ID17';
  column_tab(20).name := 'DETAIL_ID18';
  column_tab(21).name := 'DETAIL_ID19';
  column_tab(22).name := 'DETAIL_ID20';
  column_tab(23).name := 'VS_ID1';
  column_tab(24).name := 'VS_ID2';
  column_tab(25).name := 'VS_ID3';
  column_tab(26).name := 'VS_ID4';
  column_tab(27).name := 'VS_ID5';
  column_tab(28).name := 'VS_ID6';
  column_tab(29).name := 'VS_ID7';
  column_tab(30).name := 'VS_ID8';
  column_tab(31).name := 'VS_ID9';
  column_tab(32).name := 'VS_ID10';
  column_tab(33).name := 'VS_ID11';
  column_tab(34).name := 'VS_ID12';
  column_tab(35).name := 'VS_ID13';
  column_tab(36).name := 'VS_ID14';
  column_tab(37).name := 'VS_ID15';
  column_tab(38).name := 'VS_ID16';
  column_tab(39).name := 'VS_ID17';
  column_tab(40).name := 'VS_ID18';
  column_tab(41).name := 'VS_ID19';
  column_tab(42).name := 'VS_ID20';
    --
  column_tab(1).data_type := 'LONG';
  column_tab(2).data_type := 'LONG';
  column_tab(3).data_type := 'TEXT';
  column_tab(4).data_type := 'TEXT';
  column_tab(5).data_type := 'TEXT';
  column_tab(6).data_type := 'TEXT';
  column_tab(7).data_type := 'TEXT';
  column_tab(8).data_type := 'TEXT';
  column_tab(9).data_type := 'TEXT';
  column_tab(10).data_type := 'TEXT';
  column_tab(11).data_type := 'TEXT';
  column_tab(12).data_type := 'TEXT';
  column_tab(13).data_type := 'TEXT';
  column_tab(14).data_type := 'TEXT';
  column_tab(15).data_type := 'TEXT';
  column_tab(16).data_type := 'TEXT';
  column_tab(17).data_type := 'TEXT';
  column_tab(18).data_type := 'TEXT';
  column_tab(19).data_type := 'TEXT';
  column_tab(20).data_type := 'TEXT';
  column_tab(21).data_type := 'TEXT';
  column_tab(22).data_type := 'TEXT';
  column_tab(23).data_type := 'LONG';
  column_tab(24).data_type := 'LONG';
  column_tab(25).data_type := 'LONG';
  column_tab(26).data_type := 'LONG';
  column_tab(27).data_type := 'LONG';
  column_tab(28).data_type := 'LONG';
  column_tab(29).data_type := 'LONG';
  column_tab(30).data_type := 'LONG';
  column_tab(31).data_type := 'LONG';
  column_tab(32).data_type := 'LONG';
  column_tab(33).data_type := 'LONG';
  column_tab(34).data_type := 'LONG';
  column_tab(35).data_type := 'LONG';
  column_tab(36).data_type := 'LONG';
  column_tab(37).data_type := 'LONG';
  column_tab(38).data_type := 'LONG';
  column_tab(39).data_type := 'LONG';
  column_tab(40).data_type := 'LONG';
  column_tab(41).data_type := 'LONG';
  column_tab(42).data_type := 'LONG';
    --
  l_sql :=
 'select POSITION_DEFINITION_ID||''|''||attribute1||''|''||attribute2||''|''||attribute3||''|''||attribute4||''|''||attribute5||''|''
  ||attribute6||''|''||attribute7||''|''||attribute8||''|''||attribute9||''|''||attribute10||''|''
  ||attribute11||''|''||attribute12||''|''||attribute13||''|''||attribute14||''|''||attribute15||''|''
  ||attribute16||''|''||attribute17||''|''||attribute18||''|''||attribute19||''|''||attribute20
  into l_data from per_positions where position_id = :p_data_tab;';
    --
  l_table_id := kbdx_kube_seed_pkg.insert_table (p_table_name => 'KB_POSITION_ADDL_DATA', p_aol_owner_id => -999, p_table_type => 'DIM',
                              p_sql_stmt => l_sql, p_plsql_dim_tab => p_dim_tab, p_dimension_sql_id => 3,
                              p_kube_type_id => p_kube_type_id, p_worksheet_id => l_worksheet_id,p_columns => column_tab);
    --
  l_cxt_id := kbdx_kube_seed_pkg.build_ff_tables (
                         p_app_table => 'PER_POSITIONS',
                         p_source_table => 'KB_POSITION_ADDL_DATA',
                         p_client_table => 'KB_POSITIONS',
                         p_source_column => 'POSITION_ID',
                         p_context => 'Global Data Elements',
                         p_kube_type_id => p_kube_type_id,
                         p_flex_type => 'D',
                         p_bg_id => NULL);
    --
  kbdx_kube_seed_pkg.store_addl_ff_columns (p_cxt_id => l_cxt_id, p_source_column => 'POSITION_DEFINITION_ID',
                         p_source_table => 'KB_POSITION_ADDL_DATA', p_kube_type_id => p_kube_type_id,
                         p_sequence => 1);
    --
  For i in kbdx_kube_seed_pkg.c_get_bg Loop
      --JAK 05/05/2010
    if loldDffKffnaming then
      lv_client_table_name := 'KB_POSITION_DEFINITIONS';
    else
      lv_client_table_name := 'KB_POSITION_DEFINITIONS'||i.business_group_id;
    end if;
      --
    l_cxt_id := kbdx_kube_seed_pkg.build_ff_tables (
                              p_app_table => 'PER_POSITION_DEFINITIONS',
                              p_source_table => 'KB_POSITION_SOURCE',
                              p_client_table => lv_client_table_name,
                              p_source_column => 'POSITION_DEFINITION_ID',
                              p_context => i.position_structure,
                              p_kube_type_id => p_kube_type_id,
                              p_flex_type => 'K',
                              p_bg_id  => i.business_group_id);
  End Loop;
    --
End per_position_kf;

Procedure per_soft_coding_kf(p_kube_type_id in number,
                             p_dim_tab in varchar2,
                             av_client_table_name varchar2 default null) as
 l_sql varchar2(6000);
 l_worksheet_id Number;
 column_tab kbdx_kube_seed_pkg.column_tabtype;
 l_table_id Number;
 l_cxt_id Number;
begin
  l_worksheet_id := kbdx_kube_seed_pkg.get_worksheet_id(p_kube_type_id => p_kube_type_id);
    --
    -- 'KB_SOFT_CODING_KEYFLEX'
    --
  column_tab.delete;
  column_tab(1).name := 'SOFT_CODING_KEYFLEX_ID';
  column_tab(2).name := 'DETAIL_ID1';
  column_tab(3).name := 'DETAIL_ID2';
  column_tab(4).name := 'DETAIL_ID3';
  column_tab(5).name := 'DETAIL_ID4';
  column_tab(6).name := 'DETAIL_ID5';
  column_tab(7).name := 'DETAIL_ID6';
  column_tab(8).name := 'DETAIL_ID7';
  column_tab(9).name := 'DETAIL_ID8';
  column_tab(10).name := 'DETAIL_ID9';
  column_tab(11).name := 'DETAIL_ID10';
  column_tab(12).name := 'DETAIL_ID11';
  column_tab(13).name := 'DETAIL_ID12';
  column_tab(14).name := 'DETAIL_ID13';
  column_tab(15).name := 'DETAIL_ID14';
  column_tab(16).name := 'DETAIL_ID15';
  column_tab(17).name := 'DETAIL_ID16';
  column_tab(18).name := 'DETAIL_ID17';
  column_tab(19).name := 'DETAIL_ID18';
  column_tab(20).name := 'DETAIL_ID19';
  column_tab(21).name := 'DETAIL_ID20';
  column_tab(22).name := 'DETAIL_ID21';
  column_tab(23).name := 'DETAIL_ID22';
  column_tab(24).name := 'DETAIL_ID23';
  column_tab(25).name := 'DETAIL_ID24';
  column_tab(26).name := 'DETAIL_ID25';
  column_tab(27).name := 'DETAIL_ID26';
  column_tab(28).name := 'DETAIL_ID27';
  column_tab(29).name := 'DETAIL_ID28';
  column_tab(30).name := 'DETAIL_ID29';
  column_tab(31).name := 'DETAIL_ID30';
  column_tab(32).name := 'VS_ID1';
  column_tab(33).name := 'VS_ID2';
  column_tab(34).name := 'VS_ID3';
  column_tab(35).name := 'VS_ID4';
  column_tab(36).name := 'VS_ID5';
  column_tab(37).name := 'VS_ID6';
  column_tab(38).name := 'VS_ID7';
  column_tab(39).name := 'VS_ID8';
  column_tab(40).name := 'VS_ID9';
  column_tab(41).name := 'VS_ID10';
  column_tab(42).name := 'VS_ID11';
  column_tab(43).name := 'VS_ID12';
  column_tab(44).name := 'VS_ID13';
  column_tab(45).name := 'VS_ID14';
  column_tab(46).name := 'VS_ID15';
  column_tab(47).name := 'VS_ID16';
  column_tab(48).name := 'VS_ID17';
  column_tab(49).name := 'VS_ID18';
  column_tab(50).name := 'VS_ID19';
  column_tab(51).name := 'VS_ID20';
  column_tab(52).name := 'VS_ID21';
  column_tab(53).name := 'VS_ID22';
  column_tab(54).name := 'VS_ID23';
  column_tab(55).name := 'VS_ID24';
  column_tab(56).name := 'VS_ID25';
  column_tab(57).name := 'VS_ID26';
  column_tab(58).name := 'VS_ID27';
  column_tab(59).name := 'VS_ID28';
  column_tab(60).name := 'VS_ID29';
  column_tab(61).name := 'VS_ID30';
    --
  column_tab(1).data_type := 'LONG';
  column_tab(2).data_type := 'TEXT';
  column_tab(3).data_type := 'TEXT';
  column_tab(4).data_type := 'TEXT';
  column_tab(5).data_type := 'TEXT';
  column_tab(6).data_type := 'TEXT';
  column_tab(7).data_type := 'TEXT';
  column_tab(8).data_type := 'TEXT';
  column_tab(9).data_type := 'TEXT';
  column_tab(10).data_type := 'TEXT';
  column_tab(11).data_type := 'TEXT';
  column_tab(12).data_type := 'TEXT';
  column_tab(13).data_type := 'TEXT';
  column_tab(14).data_type := 'TEXT';
  column_tab(15).data_type := 'TEXT';
  column_tab(16).data_type := 'TEXT';
  column_tab(17).data_type := 'TEXT';
  column_tab(18).data_type := 'TEXT';
  column_tab(19).data_type := 'TEXT';
  column_tab(20).data_type := 'TEXT';
  column_tab(21).data_type := 'TEXT';
  column_tab(22).data_type := 'TEXT';
  column_tab(23).data_type := 'TEXT';
  column_tab(24).data_type := 'TEXT';
  column_tab(25).data_type := 'TEXT';
  column_tab(26).data_type := 'TEXT';
  column_tab(27).data_type := 'TEXT';
  column_tab(28).data_type := 'TEXT';
  column_tab(29).data_type := 'TEXT';
  column_tab(30).data_type := 'TEXT';
  column_tab(31).data_type := 'TEXT';
  column_tab(32).data_type := 'LONG';
  column_tab(33).data_type := 'LONG';
  column_tab(34).data_type := 'LONG';
  column_tab(35).data_type := 'LONG';
  column_tab(36).data_type := 'LONG';
  column_tab(37).data_type := 'LONG';
  column_tab(38).data_type := 'LONG';
  column_tab(39).data_type := 'LONG';
  column_tab(40).data_type := 'LONG';
  column_tab(41).data_type := 'LONG';
  column_tab(42).data_type := 'LONG';
  column_tab(43).data_type := 'LONG';
  column_tab(44).data_type := 'LONG';
  column_tab(45).data_type := 'LONG';
  column_tab(46).data_type := 'LONG';
  column_tab(47).data_type := 'LONG';
  column_tab(48).data_type := 'LONG';
  column_tab(49).data_type := 'LONG';
  column_tab(50).data_type := 'LONG';
  column_tab(51).data_type := 'LONG';
  column_tab(52).data_type := 'LONG';
  column_tab(53).data_type := 'LONG';
  column_tab(54).data_type := 'LONG';
  column_tab(55).data_type := 'LONG';
  column_tab(56).data_type := 'LONG';
  column_tab(57).data_type := 'LONG';
  column_tab(58).data_type := 'LONG';
  column_tab(59).data_type := 'LONG';
  column_tab(60).data_type := 'LONG';
  column_tab(61).data_type := 'LONG';
    --
  l_sql :=
 'select segment1||''|''||segment2||''|''||segment3||''|''||segment4||''|''||segment5||''|''
  ||segment6||''|''||segment7||''|''||segment8||''|''||segment9||''|''||segment10||''|''
  ||segment11||''|''||segment12||''|''||segment13||''|''||segment14||''|''||segment15||''|''
  ||segment16||''|''||segment17||''|''||segment18||''|''||segment19||''|''||segment20||''|''
  ||segment21||''|''||segment22||''|''||segment23||''|''||segment24||''|''||segment25||''|''
  ||segment26||''|''||segment27||''|''||segment28||''|''||segment29||''|''||segment30
  into l_data from hr_soft_coding_keyflex where soft_coding_keyflex_id = :p_data_tab;';
    --
  l_table_id := kbdx_kube_seed_pkg.insert_table
                             (p_table_name => 'KB_SOFT_CODING_KEYFLEX', p_aol_owner_id => -999, p_table_type => 'DIM',
                              p_sql_stmt => l_sql, p_plsql_dim_tab => p_dim_tab, p_dimension_sql_id => 3,
                              p_kube_type_id => p_kube_type_id, p_worksheet_id => l_worksheet_id,
                              p_columns => column_tab);
    --
   For i in kbdx_kube_seed_pkg.c_get_scl Loop
    l_cxt_id := kbdx_kube_seed_pkg.build_ff_tables (p_app_table => 'HR_SOFT_CODING_KEYFLEX',
                                 p_source_table => 'KB_SOFT_CODING_KEYFLEX',
                                 p_client_table => av_client_table_name,
                                 p_source_column => 'SOFT_CODING_KEYFLEX_ID',
                                 p_context => to_number(i.rule_mode),
                                 p_kube_type_id => p_kube_type_id,
                                 p_flex_type => 'K',
                                 p_bg_id => NULL);
  End Loop;
    --
end per_soft_coding_kf;

procedure add_KB_DFF_DEF(an_kube_type_id number) as
 column_tab kbdx_kube_seed_pkg.column_tabtype;
 l_kube_type_id number := an_kube_type_id;
begin
    --
    -- 'KB_DFF_DEF'
    --
  column_tab.delete;
  column_tab(1).name := 'SEQUENCE';
  column_tab(2).name := 'QUERY_TEXT';
    --
  column_tab(1).data_type := 'LONG';
  column_tab(2).data_type := 'MEMO';
  kbdx_kube_api_seed_pkg.create_fact_table(p_table_name => 'KB_DFF_DEF',
                                           p_kube_type_id => l_kube_type_id,
                                           p_table_structure => column_tab);
end add_KB_DFF_DEF;

Procedure per_person_types(p_kube_type_id in number,
                           p_dim_tab in varchar2) as
 l_sql varchar2(6000);
 l_kube_type_id number := p_kube_type_id;
 column_tab kbdx_kube_seed_pkg.column_tabtype;
Begin
  kbdx_kube_seed_pkg.delete_table(p_kube_type_id => p_kube_type_id,
                                  p_table_name => 'KB_PERSON_TYPES');
    --
    -- 'KB_PERSON_TYPES'
    --
  column_tab.delete;
  column_tab(1).name := 'PERSON_TYPE_ID';
  column_tab(2).name := 'System_Person_Type';
  column_tab(3).name := 'User_Person_Type';
    --
  column_tab(1).data_type := 'LONG';
  column_tab(2).data_type := 'TEXT';
  column_tab(3).data_type := 'TEXT';
    --
  l_sql :=
 'select /*+ RULE */ system_person_type||''|''||user_person_type
  into l_data
  from per_person_types
   where person_type_id = :p_data_tab;';
    --
  kbdx_kube_api_seed_pkg.create_dimension_table(p_table_name => 'KB_PERSON_TYPES',
                                                p_sql_stmt  => l_sql,
                                                p_kube_type_id => l_kube_type_id,
                                                p_plsql_tab => p_dim_tab,
                                                p_table_structure => column_tab);
End per_person_types;

  -- overloaded to include old bug with person type

Procedure per_person_details(p_kube_type_id number,
                             av_date_to varchar2 default '-999',
                             p_context varchar2 default 'US') as
 lv_default_date_to varchar2(200);
 lv_context varchar2(200);
begin
   if p_context = 'US' and (upper(av_date_to) = 'US' or upper(av_date_to) = 'GLOBAL' or upper(av_date_to) = 'CA') then
       lv_context := av_date_to;
       lv_default_date_to := '-999';
   else
       lv_default_date_to := av_date_to;
       lv_context := p_context;
   end if;
   bproc_per_person_det_working(p_kube_type_id => p_kube_type_id,av_date_to => lv_default_date_to,p_context => lv_context);
end per_person_details;

procedure bproc_per_person_det_working(p_kube_type_id number,
                                       av_date_to varchar2,
                                       p_context varchar2 default 'US') as
 l_sql varchar2(6000);
 column_tab kbdx_kube_seed_pkg.column_tabtype;
 l_cxt_id Number;
 l_kube_type_id number := p_kube_type_id;
begin
  if av_date_to = '-999' then
     per_person_types(p_kube_type_id,'kbdx_kube_utilities.g_person_types_tab');
  else
     per_person_type_usages(p_kube_type_id,av_date_to,'kbdx_kube_utilities.g_person_tab');
  end if;
    --
  static_hr_lookup(p_kube_type_id,'MAR_STATUS','kb_marital_status');
  static_hr_lookup(p_kube_type_id,'NATIONALITY','kb_nationality');
  static_hr_lookup(p_kube_type_id,'SEX','kb_sex');
  static_hr_lookup(p_kube_type_id,'TITLE','kb_person_title');
    --
    -- 'KB_PERSON_ADDL_DATA'
    --
  column_tab.delete;
  column_tab(1).name := 'ADDL_PERSON_DETAILS_LINK_ID';
  column_tab(2).name := 'DETAIL_ID1';
  column_tab(3).name := 'DETAIL_ID2';
  column_tab(4).name := 'DETAIL_ID3';
  column_tab(5).name := 'DETAIL_ID4';
  column_tab(6).name := 'DETAIL_ID5';
  column_tab(7).name := 'DETAIL_ID6';
  column_tab(8).name := 'DETAIL_ID7';
  column_tab(9).name := 'DETAIL_ID8';
  column_tab(10).name := 'DETAIL_ID9';
  column_tab(11).name := 'DETAIL_ID10';
  column_tab(12).name := 'DETAIL_ID11';
  column_tab(13).name := 'DETAIL_ID12';
  column_tab(14).name := 'DETAIL_ID13';
  column_tab(15).name := 'DETAIL_ID14';
  column_tab(16).name := 'DETAIL_ID15';
  column_tab(17).name := 'DETAIL_ID16';
  column_tab(18).name := 'DETAIL_ID17';
  column_tab(19).name := 'DETAIL_ID18';
  column_tab(20).name := 'DETAIL_ID19';
  column_tab(21).name := 'DETAIL_ID20';
  column_tab(22).name := 'DETAIL_ID21';
  column_tab(23).name := 'DETAIL_ID22';
  column_tab(24).name := 'DETAIL_ID23';
  column_tab(25).name := 'DETAIL_ID24';
  column_tab(26).name := 'DETAIL_ID25';
  column_tab(27).name := 'DETAIL_ID26';
  column_tab(28).name := 'DETAIL_ID27';
  column_tab(29).name := 'DETAIL_ID28';
  column_tab(30).name := 'DETAIL_ID29';
  column_tab(31).name := 'DETAIL_ID30';
  column_tab(32).name := 'VS_ID1';
  column_tab(33).name := 'VS_ID2';
  column_tab(34).name := 'VS_ID3';
  column_tab(35).name := 'VS_ID4';
  column_tab(36).name := 'VS_ID5';
  column_tab(37).name := 'VS_ID6';
  column_tab(38).name := 'VS_ID7';
  column_tab(39).name := 'VS_ID8';
  column_tab(40).name := 'VS_ID9';
  column_tab(41).name := 'VS_ID10';
  column_tab(42).name := 'VS_ID11';
  column_tab(43).name := 'VS_ID12';
  column_tab(44).name := 'VS_ID13';
  column_tab(45).name := 'VS_ID14';
  column_tab(46).name := 'VS_ID15';
  column_tab(47).name := 'VS_ID16';
  column_tab(48).name := 'VS_ID17';
  column_tab(49).name := 'VS_ID18';
  column_tab(50).name := 'VS_ID19';
  column_tab(51).name := 'VS_ID20';
  column_tab(52).name := 'VS_ID21';
  column_tab(53).name := 'VS_ID22';
  column_tab(54).name := 'VS_ID23';
  column_tab(55).name := 'VS_ID24';
  column_tab(56).name := 'VS_ID25';
  column_tab(57).name := 'VS_ID26';
  column_tab(58).name := 'VS_ID27';
  column_tab(59).name := 'VS_ID28';
  column_tab(60).name := 'VS_ID29';
  column_tab(61).name := 'VS_ID30';
    --
  column_tab(1).data_type := 'LONG';
  column_tab(2).data_type := 'TEXT';
  column_tab(3).data_type := 'TEXT';
  column_tab(4).data_type := 'TEXT';
  column_tab(5).data_type := 'TEXT';
  column_tab(6).data_type := 'TEXT';
  column_tab(7).data_type := 'TEXT';
  column_tab(8).data_type := 'TEXT';
  column_tab(9).data_type := 'TEXT';
  column_tab(10).data_type := 'TEXT';
  column_tab(11).data_type := 'TEXT';
  column_tab(12).data_type := 'TEXT';
  column_tab(13).data_type := 'TEXT';
  column_tab(14).data_type := 'TEXT';
  column_tab(15).data_type := 'TEXT';
  column_tab(16).data_type := 'TEXT';
  column_tab(17).data_type := 'TEXT';
  column_tab(18).data_type := 'TEXT';
  column_tab(19).data_type := 'TEXT';
  column_tab(20).data_type := 'TEXT';
  column_tab(21).data_type := 'TEXT';
  column_tab(22).data_type := 'TEXT';
  column_tab(23).data_type := 'TEXT';
  column_tab(24).data_type := 'TEXT';
  column_tab(25).data_type := 'TEXT';
  column_tab(26).data_type := 'TEXT';
  column_tab(27).data_type := 'TEXT';
  column_tab(28).data_type := 'TEXT';
  column_tab(29).data_type := 'TEXT';
  column_tab(30).data_type := 'TEXT';
  column_tab(31).data_type := 'TEXT';
  column_tab(32).data_type := 'LONG';
  column_tab(33).data_type := 'LONG';
  column_tab(34).data_type := 'LONG';
  column_tab(35).data_type := 'LONG';
  column_tab(36).data_type := 'LONG';
  column_tab(37).data_type := 'LONG';
  column_tab(38).data_type := 'LONG';
  column_tab(39).data_type := 'LONG';
  column_tab(40).data_type := 'LONG';
  column_tab(41).data_type := 'LONG';
  column_tab(42).data_type := 'LONG';
  column_tab(43).data_type := 'LONG';
  column_tab(44).data_type := 'LONG';
  column_tab(45).data_type := 'LONG';
  column_tab(46).data_type := 'LONG';
  column_tab(47).data_type := 'LONG';
  column_tab(48).data_type := 'LONG';
  column_tab(49).data_type := 'LONG';
  column_tab(50).data_type := 'LONG';
  column_tab(51).data_type := 'LONG';
  column_tab(52).data_type := 'LONG';
  column_tab(53).data_type := 'LONG';
  column_tab(54).data_type := 'LONG';
  column_tab(55).data_type := 'LONG';
  column_tab(56).data_type := 'LONG';
  column_tab(57).data_type := 'LONG';
  column_tab(58).data_type := 'LONG';
  column_tab(59).data_type := 'LONG';
  column_tab(60).data_type := 'LONG';
  column_tab(61).data_type := 'LONG';
  kbdx_kube_api_seed_pkg.create_fact_table(p_table_name => 'KB_PERSON_ADDL_DATA',
                                           p_kube_type_id => l_kube_type_id,
                                           p_table_structure => column_tab);
    --
    -- 'KB_PERSON_CXT_DATA'
    --
  column_tab.delete;
  column_tab(1).name := 'ADDL_PERSON_DETAILS_LINK_ID';
  column_tab(2).name := 'CX_INFO_CODE';
  column_tab(3).name := 'DETAIL_ID1';
  column_tab(4).name := 'DETAIL_ID2';
  column_tab(5).name := 'DETAIL_ID3';
  column_tab(6).name := 'DETAIL_ID4';
  column_tab(7).name := 'DETAIL_ID5';
  column_tab(8).name := 'DETAIL_ID6';
  column_tab(9).name := 'DETAIL_ID7';
  column_tab(10).name := 'DETAIL_ID8';
  column_tab(11).name := 'DETAIL_ID9';
  column_tab(12).name := 'DETAIL_ID10';
  column_tab(13).name := 'DETAIL_ID11';
  column_tab(14).name := 'DETAIL_ID12';
  column_tab(15).name := 'DETAIL_ID13';
  column_tab(16).name := 'DETAIL_ID14';
  column_tab(17).name := 'DETAIL_ID15';
  column_tab(18).name := 'DETAIL_ID16';
  column_tab(19).name := 'DETAIL_ID17';
  column_tab(20).name := 'DETAIL_ID18';
  column_tab(21).name := 'DETAIL_ID19';
  column_tab(22).name := 'DETAIL_ID20';
  column_tab(23).name := 'DETAIL_ID21';
  column_tab(24).name := 'DETAIL_ID22';
  column_tab(25).name := 'DETAIL_ID23';
  column_tab(26).name := 'DETAIL_ID24';
  column_tab(27).name := 'DETAIL_ID25';
  column_tab(28).name := 'DETAIL_ID26';
  column_tab(29).name := 'DETAIL_ID27';
  column_tab(30).name := 'DETAIL_ID28';
  column_tab(31).name := 'DETAIL_ID29';
  column_tab(32).name := 'DETAIL_ID30';
  column_tab(33).name := 'VS_ID1';
  column_tab(34).name := 'VS_ID2';
  column_tab(35).name := 'VS_ID3';
  column_tab(36).name := 'VS_ID4';
  column_tab(37).name := 'VS_ID5';
  column_tab(38).name := 'VS_ID6';
  column_tab(39).name := 'VS_ID7';
  column_tab(40).name := 'VS_ID8';
  column_tab(41).name := 'VS_ID9';
  column_tab(42).name := 'VS_ID10';
  column_tab(43).name := 'VS_ID11';
  column_tab(44).name := 'VS_ID12';
  column_tab(45).name := 'VS_ID13';
  column_tab(46).name := 'VS_ID14';
  column_tab(47).name := 'VS_ID15';
  column_tab(48).name := 'VS_ID16';
  column_tab(49).name := 'VS_ID17';
  column_tab(50).name := 'VS_ID18';
  column_tab(51).name := 'VS_ID19';
  column_tab(52).name := 'VS_ID20';
  column_tab(53).name := 'VS_ID21';
  column_tab(54).name := 'VS_ID22';
  column_tab(55).name := 'VS_ID23';
  column_tab(56).name := 'VS_ID24';
  column_tab(57).name := 'VS_ID25';
  column_tab(58).name := 'VS_ID26';
  column_tab(59).name := 'VS_ID27';
  column_tab(60).name := 'VS_ID28';
  column_tab(61).name := 'VS_ID29';
  column_tab(62).name := 'VS_ID30';
    --
  column_tab(1).data_type := 'LONG';
  column_tab(2).data_type := 'TEXT';
  column_tab(3).data_type := 'TEXT';
  column_tab(4).data_type := 'TEXT';
  column_tab(5).data_type := 'TEXT';
  column_tab(6).data_type := 'TEXT';
  column_tab(7).data_type := 'TEXT';
  column_tab(8).data_type := 'TEXT';
  column_tab(9).data_type := 'TEXT';
  column_tab(10).data_type := 'TEXT';
  column_tab(11).data_type := 'TEXT';
  column_tab(12).data_type := 'TEXT';
  column_tab(13).data_type := 'TEXT';
  column_tab(14).data_type := 'TEXT';
  column_tab(15).data_type := 'TEXT';
  column_tab(16).data_type := 'TEXT';
  column_tab(17).data_type := 'TEXT';
  column_tab(18).data_type := 'TEXT';
  column_tab(19).data_type := 'TEXT';
  column_tab(20).data_type := 'TEXT';
  column_tab(21).data_type := 'TEXT';
  column_tab(22).data_type := 'TEXT';
  column_tab(23).data_type := 'TEXT';
  column_tab(24).data_type := 'TEXT';
  column_tab(25).data_type := 'TEXT';
  column_tab(26).data_type := 'TEXT';
  column_tab(27).data_type := 'TEXT';
  column_tab(28).data_type := 'TEXT';
  column_tab(29).data_type := 'TEXT';
  column_tab(30).data_type := 'TEXT';
  column_tab(31).data_type := 'TEXT';
  column_tab(32).data_type := 'TEXT';
  column_tab(33).data_type := 'LONG';
  column_tab(34).data_type := 'LONG';
  column_tab(35).data_type := 'LONG';
  column_tab(36).data_type := 'LONG';
  column_tab(37).data_type := 'LONG';
  column_tab(38).data_type := 'LONG';
  column_tab(39).data_type := 'LONG';
  column_tab(40).data_type := 'LONG';
  column_tab(41).data_type := 'LONG';
  column_tab(42).data_type := 'LONG';
  column_tab(43).data_type := 'LONG';
  column_tab(44).data_type := 'LONG';
  column_tab(45).data_type := 'LONG';
  column_tab(46).data_type := 'LONG';
  column_tab(47).data_type := 'LONG';
  column_tab(48).data_type := 'LONG';
  column_tab(49).data_type := 'LONG';
  column_tab(50).data_type := 'LONG';
  column_tab(51).data_type := 'LONG';
  column_tab(52).data_type := 'LONG';
  column_tab(53).data_type := 'LONG';
  column_tab(54).data_type := 'LONG';
  column_tab(55).data_type := 'LONG';
  column_tab(56).data_type := 'LONG';
  column_tab(57).data_type := 'LONG';
  column_tab(58).data_type := 'LONG';
  column_tab(59).data_type := 'LONG';
  column_tab(60).data_type := 'LONG';
  column_tab(61).data_type := 'LONG';
  column_tab(62).data_type := 'LONG';
  kbdx_kube_api_seed_pkg.create_fact_table(p_table_name => 'KB_PERSON_CXT_DATA',
                                           p_kube_type_id => l_kube_type_id,
                                           p_table_structure => column_tab);
    --
    -- 'KB_DT_PERSON_INFO'
    --
  column_tab.delete;
  column_tab(1).name := 'ADDL_PERSON_DETAILS_LINK_ID';
  column_tab(2).name := 'PERSON_ID';
  column_tab(3).name := 'Effective Start Date';
  column_tab(4).name := 'Effective End Date';
  column_tab(5).name := 'Person Type ID';
  column_tab(6).name := 'Person Name';
  column_tab(7).name := 'Blood Type';
  column_tab(8).name := 'Date of Birth';
  column_tab(9).name := 'E-mail Address';
  column_tab(10).name := 'EE #';
  column_tab(11).name := 'FTE Capacity';
  column_tab(12).name := 'Mail Stop';
  column_tab(13).name := 'Preferred Name';
  column_tab(14).name := 'Marital Status';
  column_tab(15).name := 'Nationality';
  column_tab(16).name := 'SSN';
  column_tab(17).name := 'Office #';
  column_tab(18).name := 'On Military Svc';
  column_tab(19).name := 'Rehire Authorization';
  column_tab(20).name := 'Rehire Reason';
  column_tab(21).name := 'Rehire Recommendation';
  column_tab(22).name := 'Registered Disabled';
  column_tab(23).name := 'Gender';
  column_tab(24).name := 'Student Status';
  column_tab(25).name := 'Title';
  column_tab(26).name := 'Vendor ID';
  column_tab(27).name := 'Medical Plan #';
  column_tab(28).name := 'No Medical Coverage';
  column_tab(29).name := 'Dependent Adoption Date';
  column_tab(30).name := 'Dependent Voluntary Service';
  column_tab(31).name := 'Death Certificate Date';
  column_tab(32).name := 'Tobacco User';
  column_tab(33).name := 'Benefit Group ID';
  column_tab(34).name := 'Date of Death';
  column_tab(35).name := 'Original Hire Date';
  column_tab(36).name := 'Medical Plan Name';
  column_tab(37).name := 'Medical Insurance Carrier Name';
  column_tab(38).name := 'Medical Insurance Carrier Identifier';
  column_tab(39).name := 'Medical External Employer';
  column_tab(40).name := 'Medical Coverage Start Date';
  column_tab(41).name := 'Medical Coverage End Date';
  column_tab(42).name := 'Party ID';
  column_tab(43).name := 'First Name';
  column_tab(44).name := 'Middle Name';
  column_tab(45).name := 'Last Name';
  column_tab(46).name := 'Age';
  column_tab(47).name := 'Primary_Person_type';
    --
  column_tab(1).data_type := 'LONG';
  column_tab(2).data_type := 'LONG';
  column_tab(3).data_type := 'DATE';
  column_tab(4).data_type := 'DATE';
  column_tab(5).data_type := 'LONG';
  column_tab(6).data_type := 'TEXT';
  column_tab(7).data_type := 'TEXT';
  column_tab(8).data_type := 'DATE';
  column_tab(9).data_type := 'TEXT';
  column_tab(10).data_type := 'TEXT';
  column_tab(11).data_type := 'TEXT';
  column_tab(12).data_type := 'TEXT';
  column_tab(13).data_type := 'TEXT';
  column_tab(14).data_type := 'TEXT';
  column_tab(15).data_type := 'TEXT';
  column_tab(16).data_type := 'TEXT';
  column_tab(17).data_type := 'TEXT';
  column_tab(18).data_type := 'TEXT';
  column_tab(19).data_type := 'TEXT';
  column_tab(20).data_type := 'TEXT';
  column_tab(21).data_type := 'TEXT';
  column_tab(22).data_type := 'TEXT';
  column_tab(23).data_type := 'TEXT';
  column_tab(24).data_type := 'TEXT';
  column_tab(25).data_type := 'TEXT';
  column_tab(26).data_type := 'LONG';
  column_tab(27).data_type := 'TEXT';
  column_tab(28).data_type := 'TEXT';
  column_tab(29).data_type := 'DATE';
  column_tab(30).data_type := 'TEXT';
  column_tab(31).data_type := 'DATE';
  column_tab(32).data_type := 'TEXT';
  column_tab(33).data_type := 'LONG';
  column_tab(34).data_type := 'DATE';
  column_tab(35).data_type := 'DATE';
  column_tab(36).data_type := 'TEXT';
  column_tab(37).data_type := 'TEXT';
  column_tab(38).data_type := 'TEXT';
  column_tab(39).data_type := 'TEXT';
  column_tab(40).data_type := 'DATE';
  column_tab(41).data_type := 'DATE';
  column_tab(42).data_type := 'LONG';
  column_tab(43).data_type := 'TEXT';
  column_tab(44).data_type := 'TEXT';
  column_tab(45).data_type := 'TEXT';
  column_tab(46).data_type := 'DOUBLE';
  column_tab(47).data_type := 'TEXT';
    --
  l_sql :=
 'select nvl(person_details_id,-999)||''|''||nvl(person_id,-999)||''|''||to_char(effective_start_date,''MM/DD/YYYY'')||''|''||
  to_char(effective_end_date,''MM/DD/YYYY'')||''|''||nvl(person_type_id,-999)||''|''||first_name||'' ''||last_name||''|''||
  blood_type||''|''||to_char(date_of_birth,''MM/DD/YYYY'')||''|''||email_address||''|''||employee_number||''|''||
  fte_capacity||''|''||mailstop||''|''||known_as||''|''||nvl(marital_status,''-999'')||''|''||nvl(nationality,''-999'')||''|''||
  national_identifier||''|''||office_number||''|''||on_military_service||''|''||rehire_authorizor||''|''||
  rehire_reason||''|''||rehire_recommendation||''|''||registered_disabled_flag||''|''||nvl(sex,''-999'')||''|''||
  student_status||''|''||nvl(title,''-999'')||''|''||nvl(vendor_id,-999)||''|''||coord_ben_med_pln_no||''|''||coord_ben_no_cvg_flag||''|''||
  to_char(dpdnt_adoption_date,''MM/DD/YYYY'')||''|''||dpdnt_vlntry_svce_flag||''|''||to_char(receipt_of_death_cert_date,''MM/DD/YYYY'')||''|''||
  uses_tobacco_flag||''|''||nvl(benefit_group_id,999)||''|''||to_char(date_of_death,''MM/DD/YYYY'')||''|''||
  to_char(original_date_of_hire,''MM/DD/YYYY'')||''|''||coord_ben_med_pl_name||''|''||
  coord_ben_med_insr_crr_name||''|''||coord_ben_med_insr_crr_ident||''|''||coord_ben_med_ext_er||''|''||
  to_char(coord_ben_med_cvg_strt_dt,''MM/DD/YYYY'')||''|''||to_char(coord_ben_med_cvg_end_dt,''MM/DD/YYYY'')||''|''||
  nvl(party_id,-999)||''|''||first_name||''|''||middle_names||''|''||last_name||''|''||trunc(to_number(sysdate - date_of_birth)/365)||''|''||
   KBDX_KUBE_LOAD_SEED_DATA.GET_PERSON_TYPE(person_id,effective_end_date) data From kbAce.kbdx_kube_person_details ';			--  code Added by IXPRAVEEN-ARGANO,   12-May-2023
   --KBDX_KUBE_LOAD_SEED_DATA.GET_PERSON_TYPE(person_id,effective_end_date) data From apps.kbdx_kube_person_details ';         -- Commented code by IXPRAVEEN-ARGANO,12-May-2023
  kbdx_kube_api_seed_pkg.create_static_table(p_table_name => 'KB_DT_PERSON_INFO',
                                             p_sql_stmt => l_sql,
                                             p_kube_type_id => l_kube_type_id,
                                             p_table_structure => column_tab);
    --
  l_sql := 'create index KB_DT_PERSON_INFO_N1 on [KB_DT_PERSON_INFO] (PERSON_id, addl_person_details_link_id)';
  ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql, p_name=>'KB_DT_PERSON_INFO_N1',p_type=>'T');
    --
  l_sql := 'create index KB_DT_PERSON_INFO_N2 on [KB_DT_PERSON_INFO] (addl_person_details_link_id)';
  ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql, p_name=>'KB_DT_PERSON_INFO_N2',p_type=>'T');

  --JAK 10/24/2009 kb_person_us_context_data
  -- materialize new table
  if UPPER(p_context) = 'US' then
    l_sql :=
 'SELECT KB_DT_PERSON_INFO.[Person Name], KB_DT_PERSON_INFO.[EE #], KB_DT_PERSON_INFO.SSN, '||
  ' KB_DT_PERSON_INFO.[Effective Start Date], KB_DT_PERSON_INFO.[Effective End Date], KB_DT_PERSON_INFO.[Blood Type], '||
  ' KB_DT_PERSON_INFO.[Date of Birth], KB_DT_PERSON_INFO.[E-mail Address], KB_DT_PERSON_INFO.[FTE Capacity], '||
  ' KB_DT_PERSON_INFO.[Mail Stop], KB_DT_PERSON_INFO.[Preferred Name], KB_DT_PERSON_INFO.[Office #], '||
  ' KB_DT_PERSON_INFO.[On Military Svc], KB_DT_PERSON_INFO.[Student Status], KB_DT_PERSON_INFO.[First Name], '||
  ' KB_DT_PERSON_INFO.[Middle Name], KB_DT_PERSON_INFO.[Last Name], KB_DT_PERSON_INFO.Age, '||
  ' KB_DT_PERSON_INFO.PERSON_ID, KB_DT_PERSON_INFO.ADDL_PERSON_DETAILS_LINK_ID AS [ADDL_PERSON_DETAILS_LINK_ID], '||
  ' KB_DT_PERSON_INFO.Primary_Person_type AS [Person Type], kb_sex.Meaning AS Gender, kb_person_title.Meaning AS Title, '||
  ' kb_nationality.Meaning AS Nationality, kb_marital_status.Meaning AS [Mairtal Status], KB_DT_PERSON_INFO.[Rehire Authorization], '||
  ' KB_DT_PERSON_INFO.[Rehire Reason], KB_DT_PERSON_INFO.[Rehire Recommendation], KB_DT_PERSON_INFO.[Registered Disabled], '||
  ' KB_DT_PERSON_INFO.[Vendor ID], KB_DT_PERSON_INFO.[Medical Plan #], KB_DT_PERSON_INFO.[No Medical Coverage], '||
  ' KB_DT_PERSON_INFO.[Dependent Adoption Date], KB_DT_PERSON_INFO.[Dependent Voluntary Service], '||
  ' KB_DT_PERSON_INFO.[Death Certificate Date], KB_DT_PERSON_INFO.[Tobacco User], KB_DT_PERSON_INFO.[Benefit Group ID], '||
  ' KB_DT_PERSON_INFO.[Date of Death], KB_DT_PERSON_INFO.[Original Hire Date], KB_DT_PERSON_INFO.[Medical Plan Name], '||
  ' KB_DT_PERSON_INFO.[Medical Insurance Carrier Name], KB_DT_PERSON_INFO.[Medical Insurance Carrier Identifier], '||
  ' KB_DT_PERSON_INFO.[Medical External Employer], KB_DT_PERSON_INFO.[Medical Coverage Start Date], '||
  ' KB_DT_PERSON_INFO.[Medical Coverage End Date], KB_DT_PERSON_INFO.[Party ID], '||
  ' KB_PERSON_'||UPPER(p_context)||'_CONTEXT_DATA.* '||
  ' into [EUL Full Person Details] FROM ((((KB_DT_PERSON_INFO LEFT JOIN KB_PERSON_US_CONTEXT_DATA ON '||
  ' KB_DT_PERSON_INFO.ADDL_PERSON_DETAILS_LINK_ID = KB_PERSON_US_CONTEXT_DATA.ADDL_PERSON_DETAILS_LINK_ID) '||
  ' INNER JOIN '||
  ' kb_sex ON KB_DT_PERSON_INFO.Gender = kb_sex.Lookup_Code) INNER JOIN kb_person_title ON KB_DT_PERSON_INFO.Title = '||
  ' kb_person_title.Lookup_Code) INNER JOIN kb_nationality ON KB_DT_PERSON_INFO.Nationality = kb_nationality.Lookup_Code) '||
   ' INNER JOIN kb_marital_status ON KB_DT_PERSON_INFO.[Marital Status] = kb_marital_status.Lookup_Code';
    --
  l_cxt_id := kbdx_kube_seed_pkg.build_ff_tables (p_app_table => 'PER_ALL_PEOPLE_F',
                                          p_source_table => 'KB_PERSON_CXT_DATA',
                                          p_client_table => 'KB_PERSON_US_CONTEXT_DATA',
                                          p_source_column => 'ADDL_PERSON_DETAILS_LINK_ID',
                                          p_context => 'US',
                                          p_kube_type_id => p_kube_type_id,
                                          p_flex_type => 'D',
                                          p_bg_id => NULL);

  elsif UPPER(p_context) <> 'ALL' then -- some specific context other than US

     l_sql := 'SELECT KB_DT_PERSON_INFO.[Person Name], KB_DT_PERSON_INFO.[EE #], KB_DT_PERSON_INFO.SSN, '||
              ' KB_DT_PERSON_INFO.[Effective Start Date], KB_DT_PERSON_INFO.[Effective End Date], KB_DT_PERSON_INFO.[Blood Type], '||
              ' KB_DT_PERSON_INFO.[Date of Birth], KB_DT_PERSON_INFO.[E-mail Address], KB_DT_PERSON_INFO.[FTE Capacity], '||
              ' KB_DT_PERSON_INFO.[Mail Stop], KB_DT_PERSON_INFO.[Preferred Name], KB_DT_PERSON_INFO.[Office #], '||
              ' KB_DT_PERSON_INFO.[On Military Svc], KB_DT_PERSON_INFO.[Student Status], KB_DT_PERSON_INFO.[First Name], '||
              ' KB_DT_PERSON_INFO.[Middle Name], KB_DT_PERSON_INFO.[Last Name], KB_DT_PERSON_INFO.Age, '||
              '  KB_DT_PERSON_INFO.PERSON_ID, KB_DT_PERSON_INFO.ADDL_PERSON_DETAILS_LINK_ID AS [ADDL_PERSON_DETAILS_LINK_ID], '||
              '  KB_DT_PERSON_INFO.Primary_Person_type AS [Person Type], kb_sex.Meaning AS Gender, kb_person_title.Meaning AS Title, '||
              '  kb_nationality.Meaning AS Nationality, kb_marital_status.Meaning AS [Mairtal Status], KB_DT_PERSON_INFO.[Rehire Authorization], '||
              '  KB_DT_PERSON_INFO.[Rehire Reason], KB_DT_PERSON_INFO.[Rehire Recommendation], KB_DT_PERSON_INFO.[Registered Disabled], '||
              '  KB_DT_PERSON_INFO.[Vendor ID], KB_DT_PERSON_INFO.[Medical Plan #], KB_DT_PERSON_INFO.[No Medical Coverage], '||
              '  KB_DT_PERSON_INFO.[Dependent Adoption Date], KB_DT_PERSON_INFO.[Dependent Voluntary Service], '||
              '  KB_DT_PERSON_INFO.[Death Certificate Date], KB_DT_PERSON_INFO.[Tobacco User], KB_DT_PERSON_INFO.[Benefit Group ID], '||
              '  KB_DT_PERSON_INFO.[Date of Death], KB_DT_PERSON_INFO.[Original Hire Date], KB_DT_PERSON_INFO.[Medical Plan Name], '||
              '  KB_DT_PERSON_INFO.[Medical Insurance Carrier Name], KB_DT_PERSON_INFO.[Medical Insurance Carrier Identifier], '||
              '  KB_DT_PERSON_INFO.[Medical External Employer], KB_DT_PERSON_INFO.[Medical Coverage Start Date], '||
              '  KB_DT_PERSON_INFO.[Medical Coverage End Date], KB_DT_PERSON_INFO.[Party ID], '||
--
              '  into [EUL Full Person Details] FROM ((( '||
              '   INNER JOIN '||
              '  kb_sex ON KB_DT_PERSON_INFO.Gender = kb_sex.Lookup_Code) INNER JOIN kb_person_title ON KB_DT_PERSON_INFO.Title = '||
              '  kb_person_title.Lookup_Code) INNER JOIN kb_nationality ON KB_DT_PERSON_INFO.Nationality = kb_nationality.Lookup_Code) '||
              '  INNER JOIN kb_marital_status ON KB_DT_PERSON_INFO.[Marital Status] = kb_marital_status.Lookup_Code';


             l_cxt_id := kbdx_kube_seed_pkg.build_ff_tables (p_app_table => 'PER_ALL_PEOPLE_F',
                                          p_source_table => 'KB_PERSON_CXT_DATA',
                                          p_client_table => 'KB_PERSON_'||UPPER(p_context)||'_CONTEXT_DATA',
                                          p_source_column => 'ADDL_PERSON_DETAILS_LINK_ID',
                                          p_context => UPPER(p_context),
                                          p_kube_type_id => p_kube_type_id,
                                          p_flex_type => 'D',
                                          p_bg_id => NULL);


  else -- ALL
    l_sql :=
 'SELECT KB_DT_PERSON_INFO.[Person Name], KB_DT_PERSON_INFO.[EE #], KB_DT_PERSON_INFO.SSN, '||
  ' KB_DT_PERSON_INFO.[Effective Start Date], KB_DT_PERSON_INFO.[Effective End Date], KB_DT_PERSON_INFO.[Blood Type], '||
  ' KB_DT_PERSON_INFO.[Date of Birth], KB_DT_PERSON_INFO.[E-mail Address], KB_DT_PERSON_INFO.[FTE Capacity], '||
  ' KB_DT_PERSON_INFO.[Mail Stop], KB_DT_PERSON_INFO.[Preferred Name], KB_DT_PERSON_INFO.[Office #], '||
  ' KB_DT_PERSON_INFO.[On Military Svc], KB_DT_PERSON_INFO.[Student Status], KB_DT_PERSON_INFO.[First Name], '||
  ' KB_DT_PERSON_INFO.[Middle Name], KB_DT_PERSON_INFO.[Last Name], KB_DT_PERSON_INFO.Age, '||
  '  KB_DT_PERSON_INFO.PERSON_ID, KB_DT_PERSON_INFO.ADDL_PERSON_DETAILS_LINK_ID AS [ADDL_PERSON_DETAILS_LINK_ID], '||
  '  KB_DT_PERSON_INFO.Primary_Person_type AS [Person Type], kb_sex.Meaning AS Gender, kb_person_title.Meaning AS Title, '||
  '  kb_nationality.Meaning AS Nationality, kb_marital_status.Meaning AS [Mairtal Status], KB_DT_PERSON_INFO.[Rehire Authorization], '||
  '  KB_DT_PERSON_INFO.[Rehire Reason], KB_DT_PERSON_INFO.[Rehire Recommendation], KB_DT_PERSON_INFO.[Registered Disabled], '||
  '  KB_DT_PERSON_INFO.[Vendor ID], KB_DT_PERSON_INFO.[Medical Plan #], KB_DT_PERSON_INFO.[No Medical Coverage], '||
  '  KB_DT_PERSON_INFO.[Dependent Adoption Date], KB_DT_PERSON_INFO.[Dependent Voluntary Service], '||
  '  KB_DT_PERSON_INFO.[Death Certificate Date], KB_DT_PERSON_INFO.[Tobacco User], KB_DT_PERSON_INFO.[Benefit Group ID], '||
  '  KB_DT_PERSON_INFO.[Date of Death], KB_DT_PERSON_INFO.[Original Hire Date], KB_DT_PERSON_INFO.[Medical Plan Name], '||
  '  KB_DT_PERSON_INFO.[Medical Insurance Carrier Name], KB_DT_PERSON_INFO.[Medical Insurance Carrier Identifier], '||
  '  KB_DT_PERSON_INFO.[Medical External Employer], KB_DT_PERSON_INFO.[Medical Coverage Start Date], '||
  '  KB_DT_PERSON_INFO.[Medical Coverage End Date], KB_DT_PERSON_INFO.[Party ID], '||
--
  '  into [EUL FULL PERSON DETAILS] FROM ((( '||
  '  INNER JOIN '||
  '  kb_sex ON KB_DT_PERSON_INFO.Gender = kb_sex.Lookup_Code) INNER JOIN kb_person_title ON KB_DT_PERSON_INFO.Title = '||
  '  kb_person_title.Lookup_Code) INNER JOIN kb_nationality ON KB_DT_PERSON_INFO.Nationality = kb_nationality.Lookup_Code) '||
  '  INNER JOIN kb_marital_status ON KB_DT_PERSON_INFO.[Marital Status] = kb_marital_status.Lookup_Code';

    l_cxt_id := kbdx_kube_seed_pkg.build_ff_tables (
                                   p_app_table => 'PER_ALL_PEOPLE_F',
                                   p_source_table => 'KB_PERSON_CXT_DATA',
                                   p_client_table => 'KB_PERSON_US_CONTEXT_DATA',
                                   p_source_column => 'ADDL_PERSON_DETAILS_LINK_ID',
                                   p_context => 'US',
                                   p_kube_type_id => p_kube_type_id,
                                   p_flex_type => 'D',
                                   p_bg_id => NULL);
         --
    For i in kbdx_kube_seed_pkg.c_get_legislations Loop
      l_cxt_id := kbdx_kube_seed_pkg.build_ff_tables (p_app_table => 'PER_ALL_PEOPLE_F',
                                   p_source_table => 'KB_PERSON_CXT_DATA',
                                   p_client_table => 'KB_PERSON_'||i.legislation_code||'_CONTEXT_DATA',
                                   p_source_column => 'ADDL_PERSON_DETAILS_LINK_ID',
                                   p_context => i.legislation_code,
                                   p_kube_type_id => p_kube_type_id,
                                   p_flex_type => 'D',
                                   p_bg_id => NULL);
    End Loop;
  end if;
   -- Now insert the post load
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'EUL FULL PERSON DETAILS',p_type=>'T');
    --
  l_sql := 'create index [EUL Full Person Details N1] on [EUL Full Person Details](person_id)';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'EUL Full Person Details N1',p_type=>'T');
    --
  l_sql := 'create index [EUL Full Person Details N2] on [EUL Full Person Details](addl_person_details_link_id)';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'EUL Full Person Details N2',p_type=>'T');
    --
  l_sql := 'drop table kb_sex';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'KB_sex drop',p_type=>'T');
    --
  l_sql := 'drop table kb_nationality';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'KB_nationality drop',p_type=>'T');
    --
  l_sql := 'drop table kb_marital_status';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'kb_marital_status drop',p_type=>'T');
    --
  l_sql := 'drop table kb_person_title';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'kb_person_title drop',p_type=>'T');
    --
  FOR rec_ppf_dff in c_get_dff_context_ppf loop
    l_cxt_id := kbdx_kube_seed_pkg.build_ff_tables (
                               p_app_table => 'PER_ALL_PEOPLE_F',
                               p_source_table => 'KB_PERSON_ADDL_DATA',
                               p_client_table => 'KB_PERSON_DFF_'||replace(substr(rec_ppf_dff.attribute_category,1,5),' ','_')||'_DATA',
                               p_source_column => 'ADDL_PERSON_DETAILS_LINK_ID',
                               p_context => rec_ppf_dff.attribute_category,
                               p_kube_type_id => p_kube_type_id,
                               p_flex_type => 'D',
                               p_bg_id => NULL);
  End loop;
    --
end bproc_per_person_det_working;

Procedure add_hr_locations(p_kube_type_id in number,
                           p_dim_tab in varchar2,
                           av_client_table_name varchar2 default null) as
 l_sql varchar2(6000);
 l_kube_type_id number := p_kube_type_id;
 column_tab kbdx_kube_seed_pkg.column_tabtype;
begin
    --
    -- nvl(av_client_table_name,'KB_LOCATIONS')
    --
  column_tab.delete;
  column_tab(1).name := 'LOCATION_ID';
  column_tab(2).name := 'LOCATION_CODE';
  column_tab(3).name := 'DESCRIPTION';
  column_tab(4).name := 'ADDR_LINE1';
  column_tab(5).name := 'ADDR_LINE2';
  column_tab(6).name := 'ADDR_LINE3';
  column_tab(7).name := 'CITY';
  column_tab(8).name := 'COUNTY';
  column_tab(9).name := 'STATE';
  column_tab(10).name := 'ZIP_CODE';
  column_tab(11).name := 'COUNTRY';
    --
  column_tab(1).data_type := 'LONG';
  column_tab(2).data_type := 'TEXT';
  column_tab(3).data_type := 'TEXT';
  column_tab(4).data_type := 'TEXT';
  column_tab(5).data_type := 'TEXT';
  column_tab(6).data_type := 'TEXT';
  column_tab(7).data_type := 'TEXT';
  column_tab(8).data_type := 'TEXT';
  column_tab(9).data_type := 'TEXT';
  column_tab(10).data_type := 'TEXT';
  column_tab(11).data_type := 'TEXT';
    --
  l_sql :=
 'select l.location_code||''|''||l.description||''|''||l.address_line_1||''|''||l.address_line_2||''|''||
  l.address_line_3||''|''||l.town_or_city||''|''||l.region_1||''|''||l.region_2||''|''||
  l.postal_code||''|''||l.country
  into l_data from hr_locations_all l where l.location_id = :p_data_tab;';
    --
  kbdx_kube_api_seed_pkg.create_dimension_table(p_table_name => nvl(av_client_table_name,'KB_LOCATIONS'),
                                                p_sql_stmt  => l_sql,
                                                p_kube_type_id => l_kube_type_id,
                                                p_plsql_tab => p_dim_tab,
                                                p_table_structure => column_tab);
    --
  l_sql := 'create index KB_LOCATIONS_N1 on [KB_LOCATIONS] (LOCATION_ID)';
  ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'KB_LOCATIONS_N1',p_type=>'T');
    --
end add_hr_locations;

Procedure add_assignment_types(p_kube_type_id in number,
                               p_dim_tab in varchar2,
                               av_client_table_name varchar2 default null) as
 l_sql varchar2(6000);
 l_kube_type_id number := p_kube_type_id;
 column_tab kbdx_kube_seed_pkg.column_tabtype;
begin
    --
    -- 'KB_ASSIGNMENT_STATUS_TYPES'
    --
  column_tab.delete;
  column_tab(1).name := 'ASSIGNMENT_STATUS_TYPE_ID';
  column_tab(2).name := 'USER_STATUS';
  column_tab(3).name := 'PER_SYSTEM_STATUS';
  column_tab(4).name := 'PAY_SYSTEM_STATUS';
    --
  column_tab(1).data_type := 'LONG';
  column_tab(2).data_type := 'TEXT';
  column_tab(3).data_type := 'TEXT';
  column_tab(4).data_type := 'TEXT';
    --
  l_sql :=
 'select user_status||''|''||per_system_status||''|''||pay_system_status
  into l_data from per_assignment_status_types where assignment_status_type_id = :p_data_tab;';
    --
  kbdx_kube_api_seed_pkg.create_dimension_table(p_table_name => 'KB_ASSIGNMENT_STATUS_TYPES',
                                                p_sql_stmt  => l_sql,
                                                p_kube_type_id => l_kube_type_id,
                                                p_plsql_tab => p_dim_tab,
                                                p_table_structure => column_tab);
end add_assignment_types;

Procedure add_payrolls(p_kube_type_id in number,
                       p_dim_tab in varchar2,
                       av_client_table_name varchar2 default null) as
 l_sql varchar2(6000);
 l_kube_type_id number := p_kube_type_id;
 column_tab kbdx_kube_seed_pkg.column_tabtype;
begin
    --
    -- 'KB_PAYROLLS'
    --
  column_tab.delete;
  column_tab(1).name := 'PAYROLL_ID';
  column_tab(2).name := 'PAYROLL_NAME';
    --
  column_tab(1).data_type := 'LONG';
  column_tab(2).data_type := 'TEXT';
    --
  l_sql := 'select payroll_name into l_data from pay_payrolls_x where payroll_id = :p_data_tab;';
    --
  kbdx_kube_api_seed_pkg.create_dimension_table(p_table_name => 'KB_PAYROLLS',
                                                p_sql_stmt  => l_sql,
                                                p_kube_type_id => l_kube_type_id,
                                                p_plsql_tab => p_dim_tab,
                                                p_table_structure => column_tab);
end add_payrolls;

Procedure per_organizations(p_kube_type_id in number,
                            p_dim_tab in varchar2,
                            av_client_table_name varchar2 default null) as
 l_sql varchar2(6000);
 column_tab kbdx_kube_seed_pkg.column_tabtype;
 l_kube_type_id number := p_kube_type_id;
begin
    --
    -- nvl(av_client_table_name,'KB_ORGANIZATIONS')
    --
  column_tab.delete;
  column_tab(1).name := 'ORGANIZATION_ID';
  column_tab(2).name := 'ORGANIZATION_NAME';
  column_tab(3).name := 'ORGANIZATION_TYPE';
  column_tab(4).name := 'COST_ALLOCATION_KEYFLEX_ID';
    --
  column_tab(1).data_type := 'LONG';
  column_tab(2).data_type := 'TEXT';
  column_tab(3).data_type := 'TEXT';
  column_tab(4).data_type := 'LONG';
    --
  l_sql :=
 'select name||''|''||type||''|''||nvl(cost_allocation_keyflex_id,-999)
  into l_data from hr_all_organization_units o where o.organization_id = :p_data_tab;';
    --
  kbdx_kube_api_seed_pkg.create_dimension_table(p_table_name => nvl(av_client_table_name,'KB_ORGANIZATIONS'),
                                                p_sql_stmt  => l_sql,
                                                p_kube_type_id => l_kube_type_id,
                                                p_plsql_tab => p_dim_tab,
                                                p_table_structure => column_tab);
    --
  l_sql := 'create index KB_ORGANIZATIONS_N1 on [KB_ORGANIZATIONS] (organization_id)';
  ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'KB_ORGANIZATIONS_N1',p_type=>'T');
    --
end per_organizations;
  --
Procedure per_pay_basis(p_kube_type_id in number,
                        av_client_table_name varchar2 default null) as
 l_sql varchar2(6000);
 column_tab kbdx_kube_seed_pkg.column_tabtype;
 l_kube_type_id number := p_kube_type_id;
begin
    --
    -- nvl(av_client_table_name,'KB_PAY_BASIS')
    --
  column_tab.delete;
  column_tab(1).name := 'PAY_BASIS_ID';
  column_tab(2).name := 'Pay Basis Name';
  column_tab(3).name := 'Pay Basis Type';
  column_tab(4).name := 'Annualized Hours';
  column_tab(5).name := 'Pay Annualization Factor';
  column_tab(6).name := 'Grade Annualization Factor';
    --
  column_tab(1).data_type := 'LONG';
  column_tab(2).data_type := 'TEXT';
  column_tab(3).data_type := 'TEXT';
  column_tab(4).data_type := 'DECIMAL';
  column_tab(5).data_type := 'DECIMAL';
  column_tab(6).data_type := 'DECIMAL';
    --
  l_sql :=
 'select pay_basis_id||''|''||name||''|''||pay_basis||''|''||annualized_hours||''|''||pay_annualization_factor||''|''||grade_annualization_Factor data  From per_pay_bases
  union select ''-999''||''|Missing'' data from dual';
    --
  kbdx_kube_api_seed_pkg.create_static_table(p_table_name => nvl(av_client_table_name,'KB_PAY_BASIS'),
                                             p_sql_stmt => l_sql,
                                             p_kube_type_id => l_kube_type_id,
                                             p_table_structure => column_tab);
end per_pay_basis;

Procedure per_asg_details(p_kube_type_id number,
                          ab_full boolean default true) as
 l_sql varchar2(6000);
 column_tab kbdx_kube_seed_pkg.column_tabtype;
 l_kube_type_id number := p_kube_type_id;
 l_cxt_id Number;
begin
    -- supporting tables
  KBDX_KUBE_LOAD_SEED_DATA.add_assignment_types(p_kube_type_id,'kbdx_kube_utilities.g_asg_status_tab','KB_ASSIGNMENT_STATUS_TYPES');
  KBDX_KUBE_LOAD_SEED_DATA.static_hr_lookup(p_kube_type_id,'EMP_CAT','KB_EMP_CATEGORIES');
  KBDX_KUBE_LOAD_SEED_DATA.static_hr_lookup(p_kube_type_id,'BARGAINING_UNIT_CODE');
    --
  if ab_full then
      --
      -- KeyflexFields
    KBDX_KUBE_LOAD_SEED_DATA.load_job_and_grades(p_kube_type_id);
    KBDX_KUBE_LOAD_SEED_DATA.pay_people_groups_kf(p_kube_type_id,'kbdx_kube_utilities.g_ppg_tab','KB_PEOPLE_GROUPS') ;
    KBDX_KUBE_LOAD_SEED_DATA.per_position_kf(p_kube_type_id ,'kbdx_kube_utilities.g_posn_tab');
    KBDX_KUBE_LOAD_SEED_DATA.per_soft_coding_kf(p_kube_type_id ,'kbdx_kube_utilities.g_sck_tab','KB_GRE_DETAILS');
      --
      -- Supporting Dimension Tables
    KBDX_KUBE_LOAD_SEED_DATA.add_payrolls(p_kube_type_id,'kbdx_kube_utilities.g_pay_tab','KB_PAYROLLS');
    KBDX_KUBE_LOAD_SEED_DATA.add_hr_locations(p_kube_type_id,'kbdx_kube_utilities.g_loc_tab','KB_LOCATIONS');
    KBDX_KUBE_LOAD_SEED_DATA.per_period_of_service(p_kube_type_id,'kbdx_kube_utilities.g_ppos_tab','KB_SERVICE_LENGTH');
      --JAK 08/27/2009 was KBDX_KUBE_LOAD_SEED_DATA.per_organizations(p_kube_type_id,'kbdx_kube_utilities.g_organiztion_tab' ,'KB_ORGANIZATIONS');
    KBDX_KUBE_LOAD_SEED_DATA.per_organizations(p_kube_type_id,'kbdx_kube_utilities.g_organiztion_tab',NULL);
    KBDX_KUBE_LOAD_SEED_DATA.per_pay_basis(p_kube_type_id,'KB_PAY_BASIS');
  end if;
    --
    -- 'KB_ASG_ADDL_DATA'
    --
  column_tab.delete;
  column_tab(1).name := 'ADDL_ASG_DETAILS_LINK_ID';
  column_tab(2).name := 'DETAIL_ID1';
  column_tab(3).name := 'DETAIL_ID2';
  column_tab(4).name := 'DETAIL_ID3';
  column_tab(5).name := 'DETAIL_ID4';
  column_tab(6).name := 'DETAIL_ID5';
  column_tab(7).name := 'DETAIL_ID6';
  column_tab(8).name := 'DETAIL_ID7';
  column_tab(9).name := 'DETAIL_ID8';
  column_tab(10).name := 'DETAIL_ID9';
  column_tab(11).name := 'DETAIL_ID10';
  column_tab(12).name := 'DETAIL_ID11';
  column_tab(13).name := 'DETAIL_ID12';
  column_tab(14).name := 'DETAIL_ID13';
  column_tab(15).name := 'DETAIL_ID14';
  column_tab(16).name := 'DETAIL_ID15';
  column_tab(17).name := 'DETAIL_ID16';
  column_tab(18).name := 'DETAIL_ID17';
  column_tab(19).name := 'DETAIL_ID18';
  column_tab(20).name := 'DETAIL_ID19';
  column_tab(21).name := 'DETAIL_ID20';
  column_tab(22).name := 'DETAIL_ID21';
  column_tab(23).name := 'DETAIL_ID22';
  column_tab(24).name := 'DETAIL_ID23';
  column_tab(25).name := 'DETAIL_ID24';
  column_tab(26).name := 'DETAIL_ID25';
  column_tab(27).name := 'DETAIL_ID26';
  column_tab(28).name := 'DETAIL_ID27';
  column_tab(29).name := 'DETAIL_ID28';
  column_tab(30).name := 'DETAIL_ID29';
  column_tab(31).name := 'DETAIL_ID30';
  column_tab(32).name := 'VS_ID1';
  column_tab(33).name := 'VS_ID2';
  column_tab(34).name := 'VS_ID3';
  column_tab(35).name := 'VS_ID4';
  column_tab(36).name := 'VS_ID5';
  column_tab(37).name := 'VS_ID6';
  column_tab(38).name := 'VS_ID7';
  column_tab(39).name := 'VS_ID8';
  column_tab(40).name := 'VS_ID9';
  column_tab(41).name := 'VS_ID10';
  column_tab(42).name := 'VS_ID11';
  column_tab(43).name := 'VS_ID12';
  column_tab(44).name := 'VS_ID13';
  column_tab(45).name := 'VS_ID14';
  column_tab(46).name := 'VS_ID15';
  column_tab(47).name := 'VS_ID16';
  column_tab(48).name := 'VS_ID17';
  column_tab(49).name := 'VS_ID18';
  column_tab(50).name := 'VS_ID19';
  column_tab(51).name := 'VS_ID20';
  column_tab(52).name := 'VS_ID21';
  column_tab(53).name := 'VS_ID22';
  column_tab(54).name := 'VS_ID23';
  column_tab(55).name := 'VS_ID24';
  column_tab(56).name := 'VS_ID25';
  column_tab(57).name := 'VS_ID26';
  column_tab(58).name := 'VS_ID27';
  column_tab(59).name := 'VS_ID28';
  column_tab(60).name := 'VS_ID29';
  column_tab(61).name := 'VS_ID30';
  column_tab(62).name := 'ADDL_PERSON_DETAILS_LINK_ID';
    --
  column_tab(1).data_type := 'LONG';
  column_tab(2).data_type := 'TEXT';
  column_tab(3).data_type := 'TEXT';
  column_tab(4).data_type := 'TEXT';
  column_tab(5).data_type := 'TEXT';
  column_tab(6).data_type := 'TEXT';
  column_tab(7).data_type := 'TEXT';
  column_tab(8).data_type := 'TEXT';
  column_tab(9).data_type := 'TEXT';
  column_tab(10).data_type := 'TEXT';
  column_tab(11).data_type := 'TEXT';
  column_tab(12).data_type := 'TEXT';
  column_tab(13).data_type := 'TEXT';
  column_tab(14).data_type := 'TEXT';
  column_tab(15).data_type := 'TEXT';
  column_tab(16).data_type := 'TEXT';
  column_tab(17).data_type := 'TEXT';
  column_tab(18).data_type := 'TEXT';
  column_tab(19).data_type := 'TEXT';
  column_tab(20).data_type := 'TEXT';
  column_tab(21).data_type := 'TEXT';
  column_tab(22).data_type := 'TEXT';
  column_tab(23).data_type := 'TEXT';
  column_tab(24).data_type := 'TEXT';
  column_tab(25).data_type := 'TEXT';
  column_tab(26).data_type := 'TEXT';
  column_tab(27).data_type := 'TEXT';
  column_tab(28).data_type := 'TEXT';
  column_tab(29).data_type := 'TEXT';
  column_tab(30).data_type := 'TEXT';
  column_tab(31).data_type := 'TEXT';
  column_tab(32).data_type := 'LONG';
  column_tab(33).data_type := 'LONG';
  column_tab(34).data_type := 'LONG';
  column_tab(35).data_type := 'LONG';
  column_tab(36).data_type := 'LONG';
  column_tab(37).data_type := 'LONG';
  column_tab(38).data_type := 'LONG';
  column_tab(39).data_type := 'LONG';
  column_tab(40).data_type := 'LONG';
  column_tab(41).data_type := 'LONG';
  column_tab(42).data_type := 'LONG';
  column_tab(43).data_type := 'LONG';
  column_tab(44).data_type := 'LONG';
  column_tab(45).data_type := 'LONG';
  column_tab(46).data_type := 'LONG';
  column_tab(47).data_type := 'LONG';
  column_tab(48).data_type := 'LONG';
  column_tab(49).data_type := 'LONG';
  column_tab(50).data_type := 'LONG';
  column_tab(51).data_type := 'LONG';
  column_tab(52).data_type := 'LONG';
  column_tab(53).data_type := 'LONG';
  column_tab(54).data_type := 'LONG';
  column_tab(55).data_type := 'LONG';
  column_tab(56).data_type := 'LONG';
  column_tab(57).data_type := 'LONG';
  column_tab(58).data_type := 'LONG';
  column_tab(59).data_type := 'LONG';
  column_tab(60).data_type := 'LONG';
  column_tab(61).data_type := 'LONG';
  column_tab(62).data_type := 'LONG';
    --
  kbdx_kube_api_seed_pkg.create_fact_table(p_table_name => 'KB_ASG_ADDL_DATA',
                                           p_kube_type_id => l_kube_type_id,
                                           p_table_structure => column_tab);
    --
    -- 'KB_DT_ASG_INFO'
    --
  column_tab.delete;
  column_tab(1).name := 'ADDL_ASG_DETAILS_LINK_ID';
  column_tab(2).name := 'PERSON_ID';
  column_tab(3).name := 'ASSIGNMENT_ID';
  column_tab(4).name := 'Effective Start Date';
  column_tab(5).name := 'Effective End Date';
  column_tab(6).name := 'Grade ID';
  column_tab(7).name := 'Payroll ID';
  column_tab(8).name := 'Position ID';
  column_tab(9).name := 'Job ID';
  column_tab(10).name := 'Assignment Status Type ID';
  column_tab(11).name := 'Location ID';
  column_tab(12).name := 'Supervisor ID';
  column_tab(13).name := 'Organization ID';
  column_tab(14).name := 'People Group ID';
  column_tab(15).name := 'Sck ID';
  column_tab(16).name := 'Pay Basis ID';
  column_tab(17).name := 'Employment Category';
  column_tab(18).name := 'Work Hours';
  column_tab(19).name := 'Period of Service ID';
  column_tab(20).name := 'Bargaining Unit Code';
  column_tab(21).name := 'Union Member';
  column_tab(22).name := 'Contract ID';
  column_tab(23).name := 'Collective Agreement ID';
  column_tab(24).name := 'Collective Agreement Flex Num';
  column_tab(25).name := 'Collective Agreement Grade Def ID';
  column_tab(26).name := 'Establishment ID';
  column_tab(27).name := 'Title';
  column_tab(28).name := 'ADDL_PERSON_DETAILS_LINK_ID';
    --
  column_tab(1).data_type := 'LONG';
  column_tab(2).data_type := 'LONG';
  column_tab(3).data_type := 'LONG';
  column_tab(4).data_type := 'DATE';
  column_tab(5).data_type := 'DATE';
  column_tab(6).data_type := 'LONG';
  column_tab(7).data_type := 'LONG';
  column_tab(8).data_type := 'LONG';
  column_tab(9).data_type := 'LONG';
  column_tab(10).data_type := 'LONG';
  column_tab(11).data_type := 'LONG';
  column_tab(12).data_type := 'LONG';
  column_tab(13).data_type := 'LONG';
  column_tab(14).data_type := 'LONG';
  column_tab(15).data_type := 'LONG';
  column_tab(16).data_type := 'LONG';
  column_tab(17).data_type := 'TEXT';
  column_tab(18).data_type := 'DOUBLE';
  column_tab(19).data_type := 'LONG';
  column_tab(20).data_type := 'TEXT';
  column_tab(21).data_type := 'TEXT';
  column_tab(22).data_type := 'LONG';
  column_tab(23).data_type := 'LONG';
  column_tab(24).data_type := 'TEXT';
  column_tab(25).data_type := 'LONG';
  column_tab(26).data_type := 'LONG';
  column_tab(27).data_type := 'TEXT';
  column_tab(28).data_type := 'LONG';
    --
  l_sql :=
 'select nvl(asg_details_id,-999)||''|''||nvl(person_id,-999)||''|''||nvl(assignment_id,-999)||''|''||to_char(effective_start_date,''MM/DD/YYYY'')||''|''||
  to_char(effective_end_date,''MM/DD/YYYY'')||''|''||nvl(grade_id,-999)||''|''||nvl(payroll_id,-999)||''|''||nvl(position_id,-999)||''|''||
  nvl(job_id,-999)||''|''||nvl(assignment_status_type_id,-999)||''|''||nvl(location_id,-999)||''|''||nvl(supervisor_id,-999)||''|''||
  nvl(organization_id,-999)||''|''||nvl(people_group_id,-999)||''|''||nvl(soft_coding_keyflex_id,-999)||''|''||nvl(pay_basis_id,-999)||''|''||
  nvl(employment_category,''-999'')||''|''||normal_hours||''|''||nvl(period_of_service_id,-999)||''|''||nvl(bargaining_unit_code,''-999'')||''|''||
  labour_union_member_flag||''|''||nvl(contract_id,-999)||''|''||nvl(collective_agreement_id,-999)||''|''||cagr_id_flex_num||''|''||
  nvl(cagr_grade_def_id,-999)||''|''||nvl(establishment_id,-999)||''|''||title||''|''||person_details_id data
  from apps.kbdx_kube_asg_details';			--  code Added by IXPRAVEEN-ARGANO,   12-May-2023
  --from kbace.kbdx_kube_asg_details';		-- Commented code by IXPRAVEEN-ARGANO,12-May-2023	
    --
  kbdx_kube_api_seed_pkg.create_static_table(p_table_name => 'KB_DT_ASG_INFO',
                                             p_sql_stmt => l_sql,
                                             p_kube_type_id => l_kube_type_id,
                                             p_table_structure => column_tab);
    --
  l_sql := 'create index KB_DT_ASG_INFO_N1 on [KB_DT_ASG_INFO] (assignment_id, addl_asg_details_link_id)';
  ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'KB_DT_ASG_INFO_N1',p_type=>'T');
    --
  l_sql := 'create index KB_DT_ASG_INFO_N2 on [KB_DT_ASG_INFO] (addl_asg_details_link_id)';
  ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql, p_name=>'KB_DT_ASG_INFO_N2',p_type=>'T');
    --
  for rec_asg_dff in c_get_dff_context_asg loop
    l_cxt_id := kbdx_kube_seed_pkg.build_ff_tables (p_app_table => 'PER_ALL_ASSIGNMENTS_F',
                               p_source_table => 'KB_ASG_ADDL_DATA',
                               p_client_table => 'KB_ASG_DFF_'||replace(substr(rec_asg_dff.ass_attribute_category,1,5),' ','_')||'_DATA',
                               p_source_column => 'ADDL_ASG_DETAILS_LINK_ID',
                               p_context => rec_asg_dff.ass_attribute_category,
                               p_kube_type_id => p_kube_type_id,
                               p_flex_type => 'D',
                               p_bg_id => NULL);

  end loop;
    --
  l_sql :=
 ' SELECT KB_DT_ASG_INFO.ADDL_ASG_DETAILS_LINK_ID, KB_DT_ASG_INFO.ADDL_PERSON_DETAILS_LINK_ID, KB_DT_ASG_INFO.PERSON_ID, '||
 ' KB_DT_ASG_INFO.ASSIGNMENT_ID, KB_DT_ASG_INFO.[Effective Start Date], KB_DT_ASG_INFO.[Effective End Date], '||
 ' KB_DT_ASG_INFO.[Work Hours], KB_DT_ASG_INFO.[Union Member], KB_DT_ASG_INFO.Title, KB_ASSIGNMENT_STATUS_TYPES.USER_STATUS '||
 ' AS [Assignment Status], KB_SERVICE_LENGTH.[Start Date], KB_SERVICE_LENGTH.[Adjusted Service Date], '||
 ' KB_SERVICE_LENGTH.[Final Process Date], KB_SERVICE_LENGTH.[Term Date], KB_SERVICE_LENGTH.[Months of Service], '||
 ' KB_SERVICE_LENGTH.[Years of Service], KB_PAYROLLS.PAYROLL_NAME, KB_ORGANIZATIONS.ORGANIZATION_NAME, '||
 ' KB_ORGANIZATIONS.ORGANIZATION_TYPE, KB_ORGANIZATIONS.ORGANIZATION_ID, KB_DT_ASG_INFO.[Supervisor ID], '||
 ' KB_DT_ASG_INFO.[Position ID], KB_DT_ASG_INFO.[Job ID], KB_DT_ASG_INFO.[Location ID], KB_DT_ASG_INFO.[People Group ID], '||
 ' KB_DT_ASG_INFO.[Sck ID], KB_DT_ASG_INFO.[Grade ID], KB_DT_ASG_INFO.[Pay Basis ID], '||
 ' KB_EMP_CATEGORIES.Meaning AS [Employment Category], KB_DT_ASG_INFO.[Assignment Type], KB_DT_ASG_INFO.[Primary Flag], '||
 ' KB_DT_ASG_INFO.[Assignment Number], KB_DT_ASG_INFO.Frequency, KB_DT_ASG_INFO.[Manager Flag], '||
 ' KB_DT_ASG_INFO.[Default Code Combination Id], KB_DT_ASG_INFO.[Collective Agreement Grade Def ID], '||
 ' KB_DT_ASG_INFO.[Collective Agreement Flex Num], KB_DT_ASG_INFO.[Collective Agreement ID], KB_DT_ASG_INFO.[Contract ID], '||
 ' KB_DT_ASG_INFO.[Period of Service ID], KB_BARGAINING_UNIT_CODE.Meaning AS [Bargaining Unit] INTO [EUL ASSIGNMENT DETAILS] '||
 ' FROM (((((KB_DT_ASG_INFO INNER JOIN KB_ASSIGNMENT_STATUS_TYPES ON KB_DT_ASG_INFO.[Assignment Status Type ID] = '||
 ' KB_ASSIGNMENT_STATUS_TYPES.ASSIGNMENT_STATUS_TYPE_ID) INNER JOIN KB_SERVICE_LENGTH ON KB_DT_ASG_INFO.[Period of Service ID] = '||
 ' KB_SERVICE_LENGTH.PERIOD_OF_SERVICE_ID) INNER JOIN KB_PAYROLLS ON KB_DT_ASG_INFO.[Payroll ID] = KB_PAYROLLS.PAYROLL_ID) '||
 ' INNER JOIN KB_ORGANIZATIONS ON KB_DT_ASG_INFO.[Organization ID] = KB_ORGANIZATIONS.ORGANIZATION_ID) INNER JOIN KB_EMP_CATEGORIES '||
 ' ON KB_DT_ASG_INFO.[Employment Category] = KB_EMP_CATEGORIES.Lookup_Code) INNER JOIN KB_BARGAINING_UNIT_CODE ON '||
 ' KB_DT_ASG_INFO.[Bargaining Unit Code] = KB_BARGAINING_UNIT_CODE.Lookup_Code ';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql, p_name=>'EUL ASSIGNMENT DETAILS',p_type=>'T');
    --
  l_sql := 'create index [EUL Assignment Details N1] on [EUL Assignment Details] (ADDL_ASG_DETAILS_LINK_ID)';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql, p_name=>'EUL Assignment Details N1',p_type=>'T');
    --
  l_sql := 'create index [EUL Assignment Details N2] on [EUL Assignment Details] (ADDL_PERSON_DETAILS_LINK_ID)';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'EUL Assignment Details N2',p_type=>'T');
    --
  l_sql := 'create index [EUL Assignment Details N3] on [EUL Assignment Details] (assignment_id)';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'EUL Assignment Details N3',p_type=>'T');
    --
  l_sql := 'create index [EUL Assignment Details N5] on [EUL Assignment Details] (person_id)';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'EUL Assignment Details N5',p_type=>'T');
    --
  l_sql := 'drop table KB_DT_ASG_INFO';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'KB_DT_ASG_INFO drop',p_type=>'T');
    --
  l_sql := 'drop table KB_DT_PERSON_INFO';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'KB_DT_PERSON_INFO drop',p_type=>'T');
      --
  l_sql := 'drop table kb_payrolls';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'kb_payrolls drop',p_type=>'T');
     --
  l_sql := 'drop table kb_pay_basis';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'kb_pay_basis drop',p_type=>'T');
    --
  l_sql := 'drop table kb_emp_categories';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'kb_emp_categories drop',p_type=>'T');
    --
  l_sql := 'drop table kb_bargaining_unit_code';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'kb_bargaining_unit_code drop',p_type=>'T');
    --
end per_asg_details;

Procedure per_period_of_service(p_kube_type_id in number,
                                p_dim_tab in varchar2,
                                av_client_table_name varchar2 default null) as
 l_sql varchar2(6000);
 l_kube_type_id number := p_kube_type_id;
 column_tab kbdx_kube_seed_pkg.column_tabtype;
begin
    -- Supporting tables
  KBDX_KUBE_LOAD_SEED_DATA.static_hr_lookup(p_kube_type_id,'LEAV_REAS','KB_TERM_CODES');
      --
    -- nvl(av_client_table_name,'KB_SERVICE_LENGTH')
    --
  column_tab.delete;
  column_tab(1).name := 'PERIOD_OF_SERVICE_ID';
  column_tab(2).name := 'Start Date';
  column_tab(3).name := 'Adjusted Service Date';
  column_tab(4).name := 'Final Process Date';
  column_tab(5).name := 'Accepted Termination Date';
  column_tab(6).name := 'Notified Termination Date';
  column_tab(7).name := 'Projected Termination Date';
  column_tab(8).name := 'Term Date';
  column_tab(9).name := 'TERM_CODE';
  column_tab(10).name := 'Months of Service';
  column_tab(11).name := 'Years of Service';
    --
  column_tab(1).data_type := 'LONG';
  column_tab(2).data_type := 'DATE';
  column_tab(3).data_type := 'DATE';
  column_tab(4).data_type := 'DATE';
  column_tab(5).data_type := 'DATE';
  column_tab(6).data_type := 'DATE';
  column_tab(7).data_type := 'DATE';
  column_tab(8).data_type := 'DATE';
  column_tab(9).data_type := 'TEXT';
  column_tab(10).data_type := 'DECIMAL';
  column_tab(11).data_type := 'DECIMAL';
  l_sql  :=
 'select to_char(date_start,''MM/DD/YYYY'')||''|''||
  to_char(adjusted_svc_date,''MM/DD/YYYY'')||''|''||
  to_char(final_process_date,''MM/DD/YYYY'')||''|''||
  to_char(accepted_termination_date,''MM/DD/YYYY'')||''|''||
  to_char(notified_termination_date,''MM/DD/YYYY'')||''|''||
  to_char(projected_termination_date,''MM/DD/YYYY'')||''|''||
  to_char(actual_termination_date,''MM/DD/YYYY'')
  ||''|''||leaving_reason||''|''||MONTHS_BETWEEN(nvl(actual_termination_date,sysdate),date_start)
  ||''|''||MONTHS_BETWEEN(nvl(actual_termination_date,sysdate), date_start)/12
   into l_data from per_periods_of_service where period_of_service_id = :p_data_tab;';
  kbdx_kube_api_seed_pkg.create_dimension_table(p_table_name => nvl(av_client_table_name,'KB_SERVICE_LENGTH'),
                                                p_sql_stmt  => l_sql,
                                                p_kube_type_id => l_kube_type_id,
                                                p_plsql_tab => p_dim_tab,
                                                p_table_structure => column_tab);
end per_period_of_service;

Procedure per_tax_units(p_kube_type_id in number,
                        p_dim_tab in varchar2,
                        av_client_table_name varchar2 default null) as
 l_sql varchar2(6000);
 l_kube_type_id number := p_kube_type_id;
 column_tab  kbdx_kube_seed_pkg.column_tabtype;
begin
    --
    -- nvl(av_client_table_name,'KB_TAX_UNITS')
    --
  column_tab.delete;
  column_tab(1).name := 'TAX_UNIT_ID';
  column_tab(2).name := 'GRE';
  column_tab(3).name := 'EIN';
    --
  column_tab(1).data_type := 'LONG';
  column_tab(2).data_type := 'TEXT';
  column_tab(3).data_type := 'TEXT';
    --
  l_sql :=
 'Begin
   select name||''|''||employer_identification_number into l_data from hr_tax_units_v where tax_unit_id = kbdx_kube_utilities.g_tax_unit_tab(l_ndx);
  Exception
    When OTHERS Then
      l_data := ''MISSING|'';
  End;';
    --
  kbdx_kube_api_seed_pkg.create_dimension_table(p_table_name => nvl(av_client_table_name,'KB_TAX_UNITS'),
                                                p_sql_stmt  => l_sql,
                                                p_kube_type_id => l_kube_type_id,
                                                p_plsql_tab => p_dim_tab,
                                                p_table_structure => column_tab);
end  per_tax_units;

Procedure per_hr_asg_details(p_kube_type_id number,
                             ab_full boolean default true,
                             p_context varchar2 default 'US') as
 l_sql varchar2(6000);
 l_kube_type_id number := p_kube_type_id;
 column_tab kbdx_kube_seed_pkg.column_tabtype;
 l_cxt_id Number;
begin
    -- supporting tables
  KBDX_KUBE_LOAD_SEED_DATA.add_assignment_types(p_kube_type_id,'kbdx_kube_utilities.g_asg_status_tab','KB_ASSIGNMENT_STATUS_TYPES');
  KBDX_KUBE_LOAD_SEED_DATA.static_hr_lookup(p_kube_type_id,'EMP_CAT','KB_EMP_CATEGORIES');
  KBDX_KUBE_LOAD_SEED_DATA.static_hr_lookup(p_kube_type_id,'BARGAINING_UNIT_CODE');
    --
  if ab_full then
      --
      -- KeyflexFields
    KBDX_KUBE_LOAD_SEED_DATA.per_grades(p_kube_type_id);
    KBDX_KUBE_LOAD_SEED_DATA.per_jobs(p_kube_type_id ,p_context);
    KBDX_KUBE_LOAD_SEED_DATA.pay_people_groups_kf(p_kube_type_id,'kbdx_kube_utilities.g_ppg_tab','KB_PEOPLE_GROUPS') ;
    KBDX_KUBE_LOAD_SEED_DATA.per_position_kf(p_kube_type_id ,'kbdx_kube_utilities.g_posn_tab');
    KBDX_KUBE_LOAD_SEED_DATA.per_soft_coding_kf(p_kube_type_id ,'kbdx_kube_utilities.g_sck_tab','KB_GRE_DETAILS');
      --
      -- Supporting Dimension Tables
    KBDX_KUBE_LOAD_SEED_DATA.add_payrolls(p_kube_type_id,'kbdx_kube_utilities.g_pay_tab','KB_PAYROLLS');
    KBDX_KUBE_LOAD_SEED_DATA.add_hr_locations(p_kube_type_id,'kbdx_kube_utilities.g_loc_tab','KB_LOCATIONS');
    KBDX_KUBE_LOAD_SEED_DATA.per_period_of_service(p_kube_type_id,'kbdx_kube_utilities.g_ppos_tab','KB_SERVICE_LENGTH');
      --JAK 08/27/2009 was  KBDX_KUBE_LOAD_SEED_DATA.per_organizations(p_kube_type_id,'kbdx_kube_utilities.g_organiztion_tab' ,'KB_ORGANIZATIONS');
    KBDX_KUBE_LOAD_SEED_DATA.per_organizations(p_kube_type_id,'kbdx_kube_utilities.g_organiztion_tab',NULL);
    KBDX_KUBE_LOAD_SEED_DATA.per_pay_basis(p_kube_type_id,'KB_PAY_BASIS');
  end if;
    --
    -- 'KB_ASG_ADDL_DATA'
    --
  column_tab.delete;
  column_tab(1).name := 'ADDL_ASG_DETAILS_LINK_ID';
  column_tab(2).name := 'DETAIL_ID1';
  column_tab(3).name := 'DETAIL_ID2';
  column_tab(4).name := 'DETAIL_ID3';
  column_tab(5).name := 'DETAIL_ID4';
  column_tab(6).name := 'DETAIL_ID5';
  column_tab(7).name := 'DETAIL_ID6';
  column_tab(8).name := 'DETAIL_ID7';
  column_tab(9).name := 'DETAIL_ID8';
  column_tab(10).name := 'DETAIL_ID9';
  column_tab(11).name := 'DETAIL_ID10';
  column_tab(12).name := 'DETAIL_ID11';
  column_tab(13).name := 'DETAIL_ID12';
  column_tab(14).name := 'DETAIL_ID13';
  column_tab(15).name := 'DETAIL_ID14';
  column_tab(16).name := 'DETAIL_ID15';
  column_tab(17).name := 'DETAIL_ID16';
  column_tab(18).name := 'DETAIL_ID17';
  column_tab(19).name := 'DETAIL_ID18';
  column_tab(20).name := 'DETAIL_ID19';
  column_tab(21).name := 'DETAIL_ID20';
  column_tab(22).name := 'DETAIL_ID21';
  column_tab(23).name := 'DETAIL_ID22';
  column_tab(24).name := 'DETAIL_ID23';
  column_tab(25).name := 'DETAIL_ID24';
  column_tab(26).name := 'DETAIL_ID25';
  column_tab(27).name := 'DETAIL_ID26';
  column_tab(28).name := 'DETAIL_ID27';
  column_tab(29).name := 'DETAIL_ID28';
  column_tab(30).name := 'DETAIL_ID29';
  column_tab(31).name := 'DETAIL_ID30';
  column_tab(32).name := 'VS_ID1';
  column_tab(33).name := 'VS_ID2';
  column_tab(34).name := 'VS_ID3';
  column_tab(35).name := 'VS_ID4';
  column_tab(36).name := 'VS_ID5';
  column_tab(37).name := 'VS_ID6';
  column_tab(38).name := 'VS_ID7';
  column_tab(39).name := 'VS_ID8';
  column_tab(40).name := 'VS_ID9';
  column_tab(41).name := 'VS_ID10';
  column_tab(42).name := 'VS_ID11';
  column_tab(43).name := 'VS_ID12';
  column_tab(44).name := 'VS_ID13';
  column_tab(45).name := 'VS_ID14';
  column_tab(46).name := 'VS_ID15';
  column_tab(47).name := 'VS_ID16';
  column_tab(48).name := 'VS_ID17';
  column_tab(49).name := 'VS_ID18';
  column_tab(50).name := 'VS_ID19';
  column_tab(51).name := 'VS_ID20';
  column_tab(52).name := 'VS_ID21';
  column_tab(53).name := 'VS_ID22';
  column_tab(54).name := 'VS_ID23';
  column_tab(55).name := 'VS_ID24';
  column_tab(56).name := 'VS_ID25';
  column_tab(57).name := 'VS_ID26';
  column_tab(58).name := 'VS_ID27';
  column_tab(59).name := 'VS_ID28';
  column_tab(60).name := 'VS_ID29';
  column_tab(61).name := 'VS_ID30';
  column_tab(62).name := 'ADDL_PERSON_DETAILS_LINK_ID';
    --
  column_tab(1).data_type := 'LONG';
  column_tab(2).data_type := 'TEXT';
  column_tab(3).data_type := 'TEXT';
  column_tab(4).data_type := 'TEXT';
  column_tab(5).data_type := 'TEXT';
  column_tab(6).data_type := 'TEXT';
  column_tab(7).data_type := 'TEXT';
  column_tab(8).data_type := 'TEXT';
  column_tab(9).data_type := 'TEXT';
  column_tab(10).data_type := 'TEXT';
  column_tab(11).data_type := 'TEXT';
  column_tab(12).data_type := 'TEXT';
  column_tab(13).data_type := 'TEXT';
  column_tab(14).data_type := 'TEXT';
  column_tab(15).data_type := 'TEXT';
  column_tab(16).data_type := 'TEXT';
  column_tab(17).data_type := 'TEXT';
  column_tab(18).data_type := 'TEXT';
  column_tab(19).data_type := 'TEXT';
  column_tab(20).data_type := 'TEXT';
  column_tab(21).data_type := 'TEXT';
  column_tab(22).data_type := 'TEXT';
  column_tab(23).data_type := 'TEXT';
  column_tab(24).data_type := 'TEXT';
  column_tab(25).data_type := 'TEXT';
  column_tab(26).data_type := 'TEXT';
  column_tab(27).data_type := 'TEXT';
  column_tab(28).data_type := 'TEXT';
  column_tab(29).data_type := 'TEXT';
  column_tab(30).data_type := 'TEXT';
  column_tab(31).data_type := 'TEXT';
  column_tab(32).data_type := 'LONG';
  column_tab(33).data_type := 'LONG';
  column_tab(34).data_type := 'LONG';
  column_tab(35).data_type := 'LONG';
  column_tab(36).data_type := 'LONG';
  column_tab(37).data_type := 'LONG';
  column_tab(38).data_type := 'LONG';
  column_tab(39).data_type := 'LONG';
  column_tab(40).data_type := 'LONG';
  column_tab(41).data_type := 'LONG';
  column_tab(42).data_type := 'LONG';
  column_tab(43).data_type := 'LONG';
  column_tab(44).data_type := 'LONG';
  column_tab(45).data_type := 'LONG';
  column_tab(46).data_type := 'LONG';
  column_tab(47).data_type := 'LONG';
  column_tab(48).data_type := 'LONG';
  column_tab(49).data_type := 'LONG';
  column_tab(50).data_type := 'LONG';
  column_tab(51).data_type := 'LONG';
  column_tab(52).data_type := 'LONG';
  column_tab(53).data_type := 'LONG';
  column_tab(54).data_type := 'LONG';
  column_tab(55).data_type := 'LONG';
  column_tab(56).data_type := 'LONG';
  column_tab(57).data_type := 'LONG';
  column_tab(58).data_type := 'LONG';
  column_tab(59).data_type := 'LONG';
  column_tab(60).data_type := 'LONG';
  column_tab(61).data_type := 'LONG';
  column_tab(62).data_type := 'LONG';
  kbdx_kube_api_seed_pkg.create_fact_table(p_table_name => 'KB_ASG_ADDL_DATA',
                                           p_kube_type_id => l_kube_type_id,
                                           p_table_structure => column_tab);
    --
    -- 'KB_DT_ASG_INFO'
    --
  column_tab.delete;
  column_tab(1).name := 'ADDL_ASG_DETAILS_LINK_ID';
  column_tab(2).name := 'PERSON_ID';
  column_tab(3).name := 'ASSIGNMENT_ID';
  column_tab(4).name := 'Effective Start Date';
  column_tab(5).name := 'Effective End Date';
  column_tab(6).name := 'Grade ID';
  column_tab(7).name := 'Payroll ID';
  column_tab(8).name := 'Position ID';
  column_tab(9).name := 'Job ID';
  column_tab(10).name := 'Assignment Status Type ID';
  column_tab(11).name := 'Location ID';
  column_tab(12).name := 'Supervisor ID';
  column_tab(13).name := 'Organization ID';
  column_tab(14).name := 'People Group ID';
  column_tab(15).name := 'Sck ID';
  column_tab(16).name := 'Pay Basis ID';
  column_tab(17).name := 'Employment Category';
  column_tab(18).name := 'Work Hours';
  column_tab(19).name := 'Period of Service ID';
  column_tab(20).name := 'Bargaining Unit Code';
  column_tab(21).name := 'Union Member';
  column_tab(22).name := 'Contract ID';
  column_tab(23).name := 'Collective Agreement ID';
  column_tab(24).name := 'Collective Agreement Flex Num';
  column_tab(25).name := 'Collective Agreement Grade Def ID';
  column_tab(26).name := 'Establishment ID';
  column_tab(27).name := 'Title';
  column_tab(28).name := 'ADDL_PERSON_DETAILS_LINK_ID';
  column_tab(29).name := 'Assignment Type';
  column_tab(30).name := 'Primary Flag';
  column_tab(31).name := 'Assignment Number';
  column_tab(32).name := 'Frequency';
  column_tab(33).name := 'Manager Flag';
  column_tab(34).name := 'Default Code Combination Id';
    --
  column_tab(1).data_type := 'LONG';
  column_tab(2).data_type := 'LONG';
  column_tab(3).data_type := 'LONG';
  column_tab(4).data_type := 'DATE';
  column_tab(5).data_type := 'DATE';
  column_tab(6).data_type := 'LONG';
  column_tab(7).data_type := 'LONG';
  column_tab(8).data_type := 'LONG';
  column_tab(9).data_type := 'LONG';
  column_tab(10).data_type := 'LONG';
  column_tab(11).data_type := 'LONG';
  column_tab(12).data_type := 'LONG';
  column_tab(13).data_type := 'LONG';
  column_tab(14).data_type := 'LONG';
  column_tab(15).data_type := 'LONG';
  column_tab(16).data_type := 'LONG';
  column_tab(17).data_type := 'TEXT';
  column_tab(18).data_type := 'DOUBLE';
  column_tab(19).data_type := 'LONG';
  column_tab(20).data_type := 'TEXT';
  column_tab(21).data_type := 'TEXT';
  column_tab(22).data_type := 'LONG';
  column_tab(23).data_type := 'LONG';
  column_tab(24).data_type := 'TEXT';
  column_tab(25).data_type := 'LONG';
  column_tab(26).data_type := 'LONG';
  column_tab(27).data_type := 'TEXT';
  column_tab(28).data_type := 'LONG';
  column_tab(29).data_type := 'TEXT';
  column_tab(30).data_type := 'TEXT';
  column_tab(31).data_type := 'TEXT';
  column_tab(32).data_type := 'TEXT';
  column_tab(33).data_type := 'TEXT';
  column_tab(34).data_type := 'LONG';
    --
  l_sql :=
 'select nvl(asg_details_id,-999)||''|''||nvl(person_id,-999)||''|''||nvl(assignment_id,-999)||''|''||to_char(effective_start_date,''MM/DD/YYYY'')||''|''||
  to_char(effective_end_date,''MM/DD/YYYY'')||''|''||nvl(grade_id,-999)||''|''||nvl(payroll_id,-999)||''|''||nvl(position_id,-999)||''|''||
  nvl(job_id,-999)||''|''||nvl(assignment_status_type_id,-999)||''|''||nvl(location_id,-999)||''|''||nvl(supervisor_id,-999)||''|''||
  nvl(organization_id,-999)||''|''||nvl(people_group_id,-999)||''|''||nvl(soft_coding_keyflex_id,-999)||''|''||nvl(pay_basis_id,-999)||''|''||
  nvl(employment_category,''-999'')||''|''||normal_hours||''|''||nvl(period_of_service_id,-999)||''|''||nvl(bargaining_unit_code,''-999'')||''|''||
  labour_union_member_flag||''|''||nvl(contract_id,-999)||''|''||nvl(collective_agreement_id,-999)||''|''||cagr_id_flex_num||''|''||
  nvl(cagr_grade_def_id,-999)||''|''||nvl(establishment_id,-999)||''|''||title||''|''||person_details_id||''|''||
  assignment_type||''|''||primary_flag||''|''||assignment_number||''|''||frequency||''|''||manager_flag||''|''||
  nvl(default_code_comb_id,-999) data
  from apps.kbdx_kube_hr_asg_details';				--  code Added by IXPRAVEEN-ARGANO,   12-May-2023
  --from kbace.kbdx_kube_hr_asg_details';			-- Commented code by IXPRAVEEN-ARGANO,12-May-2023	
    --
  kbdx_kube_api_seed_pkg.create_static_table(p_table_name => 'KB_DT_ASG_INFO',
                                             p_sql_stmt => l_sql,
                                             p_kube_type_id => l_kube_type_id,
                                             p_table_structure => column_tab);
    --
  l_sql := 'create index KB_DT_ASG_INFO_N1 on [KB_DT_ASG_INFO] (assignment_id, addl_asg_details_link_id)';
  ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'KB_DT_ASG_INFO_N1',p_type=>'T');
    --
  l_sql := 'create index KB_DT_ASG_INFO_N2 on [KB_DT_ASG_INFO] (addl_asg_details_link_id)';
  ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql, p_name=>'KB_DT_ASG_INFO_N2',p_type=>'T');
    --
  for rec_asg_dff in c_get_dff_context_asg loop
    l_cxt_id := kbdx_kube_seed_pkg.build_ff_tables (
                               p_app_table => 'PER_ALL_ASSIGNMENTS_F',
                               p_source_table => 'KB_ASG_ADDL_DATA',
                               p_client_table => 'KB_ASG_DFF_'||replace(substr(rec_asg_dff.ass_attribute_category,1,5),' ','_')||'_DATA',
                               p_source_column => 'ADDL_ASG_DETAILS_LINK_ID',
                               p_context => rec_asg_dff.ass_attribute_category,
                               p_kube_type_id => p_kube_type_id,
                               p_flex_type => 'D',
                               p_bg_id => NULL);
  end loop;
    --
  l_sql :=
 ' SELECT KB_DT_ASG_INFO.ADDL_ASG_DETAILS_LINK_ID, KB_DT_ASG_INFO.ADDL_PERSON_DETAILS_LINK_ID, KB_DT_ASG_INFO.PERSON_ID, '||
 ' KB_DT_ASG_INFO.ASSIGNMENT_ID, KB_DT_ASG_INFO.[Effective Start Date], KB_DT_ASG_INFO.[Effective End Date], '||
 ' KB_DT_ASG_INFO.[Work Hours], KB_DT_ASG_INFO.[Union Member], KB_DT_ASG_INFO.Title, KB_ASSIGNMENT_STATUS_TYPES.USER_STATUS '||
 ' AS [Assignment Status], KB_SERVICE_LENGTH.[Start Date], KB_SERVICE_LENGTH.[Adjusted Service Date], '||
 ' KB_SERVICE_LENGTH.[Final Process Date], KB_SERVICE_LENGTH.[Term Date], KB_SERVICE_LENGTH.[Months of Service], '||
 ' KB_SERVICE_LENGTH.[Years of Service], KB_PAYROLLS.PAYROLL_NAME, KB_ORGANIZATIONS.ORGANIZATION_NAME, '||
 ' KB_ORGANIZATIONS.ORGANIZATION_TYPE, KB_ORGANIZATIONS.ORGANIZATION_ID, KB_DT_ASG_INFO.[Supervisor ID], '||
 ' KB_DT_ASG_INFO.[Position ID], KB_DT_ASG_INFO.[Job ID], KB_DT_ASG_INFO.[Location ID], KB_DT_ASG_INFO.[People Group ID], '||
 ' KB_DT_ASG_INFO.[Sck ID], KB_DT_ASG_INFO.[Grade ID], KB_DT_ASG_INFO.[Pay Basis ID], KB_EMP_CATEGORIES.Meaning AS '||
 ' [Employment Category], KB_DT_ASG_INFO.[Assignment Type], KB_DT_ASG_INFO.[Primary Flag], KB_DT_ASG_INFO.[Assignment Number], '||
 ' KB_DT_ASG_INFO.Frequency, KB_DT_ASG_INFO.[Manager Flag], KB_DT_ASG_INFO.[Default Code Combination Id], '||
 ' KB_DT_ASG_INFO.[Collective Agreement Grade Def ID], KB_DT_ASG_INFO.[Collective Agreement Flex Num], '||
 ' KB_DT_ASG_INFO.[Collective Agreement ID], KB_DT_ASG_INFO.[Contract ID], KB_DT_ASG_INFO.[Period of Service ID], '||
 ' KB_BARGAINING_UNIT_CODE.Meaning AS [Bargaining Unit], KB_DT_PERSON_INFO.[Person Name] AS Supervisor '||
 ' INTO [EUL ASSIGNMENT DETAILS] '||
 ' FROM ((((((KB_DT_ASG_INFO INNER JOIN KB_ASSIGNMENT_STATUS_TYPES ON KB_DT_ASG_INFO.[Assignment Status Type ID] = '||
 ' KB_ASSIGNMENT_STATUS_TYPES.ASSIGNMENT_STATUS_TYPE_ID) INNER JOIN KB_SERVICE_LENGTH ON '||
 ' KB_DT_ASG_INFO.[Period of Service ID] = KB_SERVICE_LENGTH.PERIOD_OF_SERVICE_ID) INNER JOIN KB_PAYROLLS ON '||
 ' KB_DT_ASG_INFO.[Payroll ID] = KB_PAYROLLS.PAYROLL_ID) INNER JOIN KB_ORGANIZATIONS ON KB_DT_ASG_INFO.[Organization ID] = '||
 ' KB_ORGANIZATIONS.ORGANIZATION_ID) INNER JOIN KB_EMP_CATEGORIES ON KB_DT_ASG_INFO.[Employment Category] = '||
 ' KB_EMP_CATEGORIES.Lookup_Code) INNER JOIN KB_BARGAINING_UNIT_CODE ON KB_DT_ASG_INFO.[Bargaining Unit Code] = '||
 ' KB_BARGAINING_UNIT_CODE.Lookup_Code) LEFT JOIN KB_DT_PERSON_INFO ON KB_DT_ASG_INFO.[Supervisor ID] = '||
 ' KB_DT_PERSON_INFO.PERSON_ID ';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql, p_name=>'EUL ASSIGNMENT DETAILS',p_type=>'T');
    --
  l_sql := 'create index [EUL Assignment Details N1] on [EUL Assignment Details] (ADDL_ASG_DETAILS_LINK_ID)';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql, p_name=>'EUL Assignment Details N1',p_type=>'T');
    --
  l_sql := 'create index [EUL Assignment Details N2] on [EUL Assignment Details] (ADDL_PERSON_DETAILS_LINK_ID)';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'EUL Assignment Details N2',p_type=>'T');
    --
  l_sql := 'create index [EUL Assignment Details N3] on [EUL Assignment Details] (assignment_id)';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'EUL Assignment Details N3',p_type=>'T');
    --
  l_sql := 'create index [EUL Assignment Details N5] on [EUL Assignment Details] (person_id)';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'EUL Assignment Details N5',p_type=>'T');
    --
  l_sql := 'drop table KB_DT_ASG_INFO';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'KB_DT_ASG_INFO drop',p_type=>'T');
    --
  l_sql := 'drop table KB_DT_PERSON_INFO';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'KB_DT_PERSON_INFO drop',p_type=>'T');
    --
  l_sql := 'drop table kb_payrolls';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'kb_payrolls drop',p_type=>'T');
    --
  l_sql := 'drop table kb_pay_basis';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'kb_pay_basis drop',p_type=>'T');
    --
  l_sql := 'drop table kb_emp_categories';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'kb_emp_categories drop',p_type=>'T');
    --
  l_sql := 'drop table kb_assignment_status_types';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'kb_assignment_status_types drop',p_type=>'T');
    --
  l_sql := 'drop table kb_bargaining_unit_code';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'kb_bargaining_unit_code drop',p_type=>'T');
    --
end per_hr_asg_details;

  --JAK 07/05/2007 note that kbdx_kube_ora_hrms_seed_pkg.per_addresses has been extensively modified from this version
Procedure per_addresses(p_kube_type_id in number,
                        p_dim_tab in varchar2,
                        p_context in varchar2,
                        av_date_from_variable in varchar2,
                        av_client_table_name varchar2 default null,
                        p_primary_flag varchar2 default null) as
 l_sql varchar2(6000);
 l_kube_type_id number := p_kube_type_id;
 column_tab kbdx_kube_seed_pkg.column_tabtype;
 cursor lcur_styles is select unique style from per_addresses;
begin
  KBDX_KUBE_LOAD_SEED_DATA.static_hr_lookup(p_kube_type_id,'ADDRESS_TYPE','KB_ADDRESS_TYPES');
    --
    -- nvl(av_client_table_name,'KB_ADDRESSES')
    --
  column_tab.delete;
  column_tab(1).name := 'PERSON_ID';
  column_tab(2).name := 'Date_From';
  column_tab(3).name := 'Date_To';
  column_tab(4).name := 'Style';
  column_tab(5).name := 'Primary_flag';
  column_tab(6).name := 'Address_Type';
  column_tab(7).name := 'Telephone Number 1';
  column_tab(8).name := 'Telephone Number 2';
  column_tab(9).name := 'Telephone Number 3';
  column_tab(10).name := 'Address Line 1';
  column_tab(11).name := 'Address Line 2';
  column_tab(12).name := 'Address Line 3';
  column_tab(13).name := 'Town_or_City';
  column_tab(14).name := 'Region_1';
  column_tab(15).name := 'Region_2';
  column_tab(16).name := 'Region_3';
  column_tab(17).name := 'Postal_Code';
  column_tab(18).name := 'Country';
  column_tab(19).name := 'Address_Type_Meaning';
  column_tab(20).name := 'add_attribute15';
  column_tab(21).name := 'add_attribute16';
  column_tab(22).name := 'add_attribute17';
  column_tab(23).name := 'add_attribute18';
  column_tab(24).name := 'add_attribute19';
  column_tab(25).name := 'add_attribute20';
    --
  column_tab(1).data_type := 'LONG';
  column_tab(2).data_type := 'DATE';
  column_tab(3).data_type := 'DATE';
  column_tab(4).data_type := 'TEXT';
  column_tab(5).data_type := 'TEXT';
  column_tab(6).data_type := 'TEXT';
  column_tab(7).data_type := 'TEXT';
  column_tab(8).data_type := 'TEXT';
  column_tab(9).data_type := 'TEXT';
  column_tab(10).data_type := 'TEXT';
  column_tab(11).data_type := 'TEXT';
  column_tab(12).data_type := 'TEXT';
  column_tab(13).data_type := 'TEXT';
  column_tab(14).data_type := 'TEXT';
  column_tab(15).data_type := 'TEXT';
  column_tab(16).data_type := 'TEXT';
  column_tab(17).data_type := 'TEXT';
  column_tab(18).data_type := 'TEXT';
  column_tab(19).data_type := 'TEXT';
  column_tab(20).data_type := 'TEXT';
  column_tab(21).data_type := 'TEXT';
  column_tab(22).data_type := 'TEXT';
  column_tab(23).data_type := 'TEXT';
  column_tab(24).data_type := 'TEXT';
  column_tab(25).data_type := 'TEXT';
    --
  l_sql :=
 'select /*+ RULE */
  to_char(a.date_from,''MM/DD/YYYY'')
  ||''|''
  ||nvl(to_char(a.date_to,''MM/DD/YYYY''),''12/31/4712'')
  ||''|''
  ||nvl(a.style,''-999'')
  ||''|''
  ||a.primary_flag
  ||''|''
  ||nvl(a.address_type,''-999'')
  ||''|''
  ||a.telephone_number_1
  ||''|''
  ||a.telephone_number_2
  ||''|''
  ||a.telephone_number_3
  ||''|''
  ||a.address_line1
  ||''|''
  ||a.address_line2
  ||''|''
  ||a.address_line3
  ||''|''
  ||a.town_or_city
  ||''|''
  ||a.region_1
  ||''|''
  ||a.region_2
  ||''|''
  ||a.region_3
  ||''|''
  ||a.postal_code
  ||''|''
  ||a.country
  ||''|''
  ||''Missing''
  ||''|''
  ||a.addr_attribute15
  ||''|''
  ||a.addr_attribute16
  ||''|''
  ||a.addr_attribute17
  ||''|''
  ||a.addr_attribute18
  ||''|''
  ||a.addr_attribute19
  ||''|''
  ||a.addr_attribute20 data
  from  per_addresses a
  where a.person_id = :p_data_tab
  and  a.primary_flag = nvl('''||p_primary_flag||''',a.primary_flag)
   and '||av_date_from_variable||' between a.date_from and nvl(date_to,''31-DEC-4712'')';
    --
  kbdx_kube_api_seed_pkg.create_dimtab_multrows(p_table_name => nvl(av_client_table_name,'KB_ADDRESSES'),
                                                p_sql_stmt => l_sql,
                                                p_kube_type_id => l_kube_type_id,
                                                p_plsql_tab => p_dim_tab,
                                                p_table_structure => column_tab);
    --
  l_sql := 'create index KB_ADDRESSES_N1 on [KB_ADDRESSES] (PERSON_id)';
  ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql, p_name=>'KB_ADDRESSES_N1',p_type=>'T');
    --
   l_sql:= ' UPDATE KB_ADDRESSES INNER JOIN KB_ADDRESS_TYPES ON KB_ADDRESSES.address_type = KB_ADDRESS_TYPES.Lookup_Code SET KB_ADDRESSES.[address_type_meaning] = [kb_address_types].[Meaning]';
   kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'KB_ADDRESSES update',p_type=>'T');
    --
  if upper(p_context) = 'US' or upper(p_context) = 'US_GLB' then
    l_sql := ' SELECT [EUL Full Person Details].[Person Name], [EUL Full Person Details].SSN, [EUL Full Person Details].Title, '||
              ' [EUL Full Person Details].[Person Type], KB_ADDRESSES.Address_Type_Meaning AS [Address Type], '||
              ' KB_ADDRESSES.[Address Line 1], KB_ADDRESSES.[Address Line 2], KB_ADDRESSES.[Address Line 3], '||
              ' KB_ADDRESSES.Town_or_City, KB_ADDRESSES.Region_2 AS State, KB_ADDRESSES.Postal_Code AS [Zip Code], '||
              ' KB_ADDRESSES.Country, KB_ADDRESSES.Primary_flag, KB_ADDRESSES.Date_From, KB_ADDRESSES.Date_To, '||
              ' KB_ADDRESSES.Region_1 AS County ,'||
              ' KB_ADDRESSES.[Telephone Number 1], KB_ADDRESSES.[Telephone Number 2], KB_ADDRESSES.[Telephone Number 3]'||
              ' FROM KB_ADDRESSES INNER JOIN [EUL Full Person Details] ON KB_ADDRESSES.PERSON_ID = '||
              ' [EUL Full Person Details].PERSON_ID '||
              ' WHERE (((KB_ADDRESSES.Style)=''US'' Or (KB_ADDRESSES.Style)=''US_GLB''));';
    kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id => p_kube_type_id,p_stmt =>l_sql,p_name=>'EUL_ADDRESSES_US',p_type=>'V');
      --
    l_sql := ' SELECT [EUL Full Person Details].[Person Name], [EUL Full Person Details].SSN, [EUL Full Person Details].Title, '||
     ' [EUL Full Person Details].[Person Type], KB_ADDRESSES.Address_Type_Meaning AS [Address Type], KB_ADDRESSES.[Address Line 1], '||
     ' KB_ADDRESSES.[Address Line 2], KB_ADDRESSES.[Address Line 3], KB_ADDRESSES.Town_or_City, KB_ADDRESSES.Region_2 AS State, '||
     ' KB_ADDRESSES.Postal_Code AS [Zip Code], KB_ADDRESSES.Country, KB_ADDRESSES.Primary_flag AS [Address Primary Flag], '||
     ' KB_ADDRESSES.Date_From, KB_ADDRESSES.Date_To, KB_ADDRESSES.Region_1 AS County, [EUL Assignment Details].PAYROLL_NAME AS Payroll, '||
     ' [EUL Assignment Details].ORGANIZATION_NAME AS Organization, [EUL Assignment Details].[Employment Category], '||
     ' [EUL Assignment Details].[Assignment Type], [EUL Assignment Details].[Assignment Status], '||
     ' [EUL Assignment Details].[Primary Flag] AS [Assignment Primary Flag], [EUL Assignment Details].[Assignment Number], '||
     ' KB_ADDRESSES.[Telephone Number 1], KB_ADDRESSES.[Telephone Number 2], KB_ADDRESSES.[Telephone Number 3]'||
     ' FROM (KB_ADDRESSES INNER JOIN [EUL Full Person Details] ON KB_ADDRESSES.PERSON_ID = [EUL Full Person Details].PERSON_ID) '||
     ' INNER JOIN [EUL Assignment Details] ON [EUL Full Person Details].ADDL_PERSON_DETAILS_LINK_ID = '||
     ' [EUL Assignment Details].ADDL_PERSON_DETAILS_LINK_ID '||
     ' WHERE (((KB_ADDRESSES.Style)=''US'' Or (KB_ADDRESSES.Style)=''US_GLB''))';
    kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id => p_kube_type_id,p_stmt =>l_sql,p_name=>'EUL_EMP_ADDRESSES_US',p_type=>'V');
  end if;
    --
  l_sql := 'drop table kb_address_types';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'kb_address_types drop',p_type=>'T');
    --
end per_addresses;

Procedure per_contacts(p_kube_type_id in number,
                       p_dim_tab in varchar2,
                       av_date_from_variable in varchar2,
                       av_date_to_variable in varchar2,
                       av_client_table_name varchar2 default null) as
 l_sql varchar2(6000);
 l_kube_type_id number := p_kube_type_id;
 column_tab kbdx_kube_seed_pkg.column_tabtype;
begin
    --
    -- nvl(av_client_table_name,'KB_CONTACTS')
    --
  column_tab.delete;
  column_tab(1).name := 'PERSON_ID';
  column_tab(2).name := 'CONTACT PERSON_ID';
  column_tab(3).name := 'Contact Type';
  column_tab(4).name := 'Contact Description';
  column_tab(5).name := 'Primary Contact Flag';
  column_tab(6).name := 'Personal Flag';
  column_tab(7).name := 'Date Start';
  column_tab(8).name := 'Date End';
  column_tab(9).name := 'Third Party Pay Flag';
  column_tab(10).name := 'Bondholder Flag';
  column_tab(11).name := 'Dependent Flag';
  column_tab(12).name := 'Beneficiary Flag';
    --
  column_tab(1).data_type := 'LONG';
  column_tab(2).data_type := 'LONG';
  column_tab(3).data_type := 'TEXT';
  column_tab(4).data_type := 'TEXT';
  column_tab(5).data_type := 'TEXT';
  column_tab(6).data_type := 'TEXT';
  column_tab(7).data_type := 'DATE';
  column_tab(8).data_type := 'DATE';
  column_tab(9).data_type := 'TEXT';
  column_tab(10).data_type := 'TEXT';
  column_tab(11).data_type := 'TEXT';
  column_tab(12).data_type := 'TEXT';
    --
  l_sql :=
 'select /*+ RULE */
  person_id
  ||''|''
  ||l.meaning
  ||''|''
  ||l.description
  ||''|''
  ||primary_contact_flag
  ||''|''
  ||personal_flag
  ||''|''
  ||nvl(to_char(date_start,''MM/DD/YYYY''),'''')
  ||''|''
  ||nvl(to_char(date_end,''MM/DD/YYYY''),'''')
  ||''|''
  ||third_party_pay_flag
  ||''|''
  ||bondholder_flag
  ||''|''
  ||dependent_flag
  ||''|''
  ||beneficiary_flag  data
  from hr_lookups l,per_contact_relationships pcr
  where l.lookup_type = ''CONTACT''
  and nvl(date_start,'||av_date_to_variable||') <= '||av_date_to_variable||'
  and nvl(date_end,'||av_date_from_variable||') between '||av_date_from_variable||' and '||av_date_to_variable||'
  and l.lookup_code = pcr.contact_type
   and pcr.contact_person_id = :p_data_tab ';
    --
  kbdx_kube_api_seed_pkg.create_dimtab_multrows(p_table_name => nvl(av_client_table_name,'KB_CONTACTS'),
                                                p_sql_stmt  => l_sql,
                                                p_kube_type_id => l_kube_type_id,
                                                p_plsql_tab => p_dim_tab,
                                                p_table_structure => column_tab);
    --
  l_sql := 'create index KB_CONTACTS_N1 on KB_CONTACTS (person_id)';
  ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'KB_CONTACTS_N1',p_type=>'T');
    --
  l_sql := 'create index KB_CONTACTS_N2 on KB_CONTACTS ([contact person_id])';
  ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'KB_CONTACTS_N2',p_type=>'T');
    --
end per_contacts;

Procedure per_phones(p_kube_type_id in number,
                     p_dim_tab in varchar2,
                     av_date_from_variable in varchar2,
                     av_client_table_name in varchar2 default null) as
 l_sql varchar2(6000);
 l_kube_type_id number := p_kube_type_id;
 column_tab kbdx_kube_seed_pkg.column_tabtype;
begin
    --
    -- nvl(av_client_table_name,'KB_PHONES')
    --
  column_tab.delete;
  column_tab(1).name := 'PERSON_ID';
  column_tab(2).name := 'Date From';
  column_tab(3).name := 'Date To';
  column_tab(4).name := 'Type';
  column_tab(5).name := 'Phone Number';
    --
  column_tab(1).data_type := 'LONG';
  column_tab(2).data_type := 'DATE';
  column_tab(3).data_type := 'DATE';
  column_tab(4).data_type := 'TEXT';
  column_tab(5).data_type := 'TEXT';
    --
  l_sql :=
 'select /*+ RULE */
  nvl(to_char(p.date_from,''MM/DD/YYYY''),'''')
  ||''|''
  ||nvl(TO_CHAR(p.date_to,''MM/DD/YYYY''),'''')
  ||''|''
  ||l.meaning
  ||''|''
  ||p.phone_number data
  from hr_lookups l, per_phones p
  where l.lookup_code = p.phone_type
  and l.lookup_type = ''PHONE_TYPE''
  and p.parent_table = ''PER_ALL_PEOPLE_F''
  and p.parent_id = :p_data_tab
   and '||av_date_from_variable||' between p.date_from and nvl(p.date_to,''31-Dec-4712'')';
    --
  kbdx_kube_api_seed_pkg.create_dimtab_multrows(p_table_name => nvl(av_client_table_name,'KB_PHONES'),
                                                p_sql_stmt  => l_sql,
                                                p_kube_type_id => l_kube_type_id,
                                                p_plsql_tab => p_dim_tab,
                                                p_table_structure => column_tab);
    --
  l_sql := 'create index KB_PHONES_N1 on [KB_PHONES] (PERSON_ID)';
  ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'KB_PHONES_N1',p_type=>'T');
    --
end per_phones;

Procedure per_hr_salary(p_kube_type_id in number,
                        av_client_table_name varchar2 default null) as
 l_sql varchar2(6000);
 l_kube_type_id number := p_kube_type_id;
 column_tab kbdx_kube_seed_pkg.column_tabtype;
begin
  kbdx_kube_load_seed_data.add_salary_components(p_kube_type_id => p_kube_type_id);
  KBDX_KUBE_LOAD_SEED_DATA.static_hr_lookup(p_kube_type_id,'PROPOSAL_REASON','KB_SAL_PROPOSAL_REASONS');
    --
    -- nvL(av_client_table_name,'KB_SALARY')
    --
  column_tab.delete;
  column_tab(1).name := 'ADDL_ASG_DETAILS_LINK_ID';
  column_tab(2).name := 'ASSIGNMENT_ID';
  column_tab(3).name := 'Salary Start Date';
  column_tab(4).name := 'Salary End Date';
  column_tab(5).name := 'Proposed Salary';
  column_tab(6).name := 'REASON_CODE';
  column_tab(7).name := 'Change Amount';
  column_tab(8).name := 'Prior Salary';
  column_tab(9).name := 'Pay Basis';
  column_tab(10).name := 'Pay Basis Type';
  column_tab(11).name := 'Annual Salary';
  column_tab(12).name := 'Change Date';
  column_tab(13).name := 'Next Perf Review Date';
  column_tab(14).name := 'Performance Rating';
  column_tab(15).name := 'Review Date';
  column_tab(16).name := 'Approved';
  column_tab(17).name := 'Multiple Components';
  column_tab(18).name := 'Change Reason';
  column_tab(19).name := 'Current Salary';

  column_tab(1).data_type := 'LONG';
  column_tab(2).data_type := 'LONG';
  column_tab(3).data_type := 'DATE';
  column_tab(4).data_type := 'DATE';
  column_tab(5).data_type := 'DECIMAL';
  column_tab(6).data_type := 'TEXT';
  column_tab(7).data_type := 'DECIMAL';
  column_tab(8).data_type := 'DECIMAL';
  column_tab(9).data_type := 'TEXT';
  column_tab(10).data_type := 'TEXT';
  column_tab(11).data_type := 'DECIMAL';
  column_tab(12).data_type := 'DATE';
  column_tab(13).data_type := 'DATE';
  column_tab(14).data_type := 'TEXT';
  column_tab(15).data_type := 'DATE';
  column_tab(16).data_type := 'TEXT';
  column_tab(17).data_type := 'TEXT';
  column_tab(18).data_type := 'TEXT';
  column_tab(19).data_type := 'DECIMAL';
    --
  kbdx_kube_api_seed_pkg.create_fact_table(p_table_name => nvL(av_client_table_name,'KB_SALARY'),
                                           p_kube_type_id => l_kube_type_id,
                                           p_table_structure => column_tab);
    --
  l_sql := 'create index KB_SALARY_N1 on [KB_SALARY] (assignment_id)';
  ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'KB_SALARY_N1',p_type=>'T');
    --
  l_sql := 'create index KB_SALARY_N2 on [KB_SALARY] (addl_asg_details_link_id)';
  ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'KB_SALARY_N2',p_type=>'T');
    --
  l_sql := 'create index KB_SALARY_N3 on [KB_SALARY] (addl_asg_details_link_id,assignment_id)';
  ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'KB_SALARY_N3',p_type=>'T');
    --
  l_sql := 'create index KB_SALARY_N4 on [KB_SALARY] (addl_asg_details_link_id,[Salary End Date])';
  ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'KB_SALARY_N4',p_type=>'T');
    --
  l_sql :=
 'SELECT KB_SALARY.ASSIGNMENT_ID, Max(KB_SALARY.[Salary End Date]) AS [MaxOfSalary End Date]
   into [KB_MAX_SALARY_DATE] FROM KB_SALARY GROUP BY KB_SALARY.ASSIGNMENT_ID';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql, p_name=>'KB_MAX_SALARY_DATE',p_type=>'T');
    --
  l_sql := 'create index KB_MAX_SALARY_DATE_N1 on [KB_MAX_SALARY_DATE] (assignment_id,[MaxOfSalary End Date])';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql, p_name=>'KB_MAX_SALARY_DATE_N1',p_type=>'T');
    --
  l_sql:= 'UPDATE (KB_MAX_SALARY_DATE INNER JOIN KB_SALARY ON '
            || ' (KB_MAX_SALARY_DATE.[MaxOfSalary End Date] = KB_SALARY.[Salary End Date]) AND '
            || ' (KB_MAX_SALARY_DATE.ASSIGNMENT_ID = KB_SALARY.ASSIGNMENT_ID)) INNER JOIN KB_SALARY AS '
            || ' KB_SALARY_1 ON (KB_MAX_SALARY_DATE.[MaxOfSalary End Date] = KB_SALARY_1.[Salary End Date]) '
            || ' AND (KB_MAX_SALARY_DATE.ASSIGNMENT_ID = KB_SALARY_1.ASSIGNMENT_ID) '
            || ' SET KB_SALARY.[Current Salary] = [kb_salary_1].[Annual Salary] '
            || ' WHERE (((KB_SALARY.[Annual Salary])>0)) ';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'kb_salary update',p_type=>'T');
    --
  l_sql:=
 ' UPDATE KB_SALARY INNER JOIN KB_SAL_PROPOSAL_REASONS ON KB_SALARY.REASON_CODE = KB_SAL_PROPOSAL_REASONS.Lookup_Code '||
 ' SET KB_SALARY.[Change Reason] = [kb_sal_proposal_reasons].[Meaning] ';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'kb_salary update',p_type=>'T');
    --
  l_sql := 'drop table kb_max_salary_date';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'kb_max_salary_date drop',p_type=>'T');
    --
  l_sql := 'drop table kb_sal_proposal_reasons';
  kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id =>p_kube_type_id,p_stmt =>l_sql,p_name=>'kb_sal_proposal_reasons drop',p_type=>'T');
    --
end per_hr_salary;

Procedure ins_post_load (p_kube_type_id in number,
                         p_stmt in varchar2,
                         p_name in varchar2,
                         p_type in varchar2) as
 ln_sequence number;
Begin
  --select max(load_sequence) + 1 into ln_sequence from kbace.kbdx_kube_post_load				-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
  select max(load_sequence) + 1 into ln_sequence from apps.kbdx_kube_post_load                 --  code Added by IXPRAVEEN-ARGANO,   12-May-2023
  where kube_type_id = p_kube_type_id;
    --
  insert into kbace.kbdx_kube_post_load (kube_type_id,sql_stmt,load_sequence,name,type)
  values (p_kube_type_id, p_stmt,nvl(ln_sequence,1),p_name,p_type);
    --
End ins_post_load;

Procedure ins_post_load (p_kube_type_id in number,
                         p_stmt in varchar2,
                         p_sequence in number,
                         p_name in varchar2, p_type in varchar2) as
Begin
  --insert into kbace.kbdx_kube_post_load (kube_type_id,sql_stmt,load_sequence,name,type)			-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
  insert into apps.kbdx_kube_post_load (kube_type_id,sql_stmt,load_sequence,name,type)              --  code Added by IXPRAVEEN-ARGANO,   12-May-2023
  values (p_kube_type_id, p_stmt,p_sequence,p_name,p_type);
End ins_post_load;

Procedure per_grade_mid_points(p_kube_type_id in number,
                               av_date_from_variable in varchar2) as
 l_sql varchar2(6000);
 l_kube_type_id number := p_kube_type_id;
 column_tab kbdx_kube_seed_pkg.column_tabtype;
begin
    --
    -- 'KB_GRADE_SALARY_DATA'
    --
  column_tab.delete;
  column_tab(1).name := 'Grade_Id';
  column_tab(2).name := 'Pay Basis Id';
  column_tab(3).name := 'Mid Value';
  column_tab(4).name := 'Maximum';
  column_tab(5).name := 'Minimum';
    --
  column_tab(1).data_type := 'LONG';
  column_tab(2).data_type := 'LONG';
  column_tab(3).data_type := 'DECIMAL';
  column_tab(4).data_type := 'DECIMAL';
  column_tab(5).data_type := 'DECIMAL';
    --
  l_sql :=
 'select /*+ RULE */
  ppb.pay_basis_id
  ||''|''
  ||nvl(pgr.mid_value,0)
  ||''|''
  ||nvl(maximum,0)
  ||''|''
  ||nvl(minimum,0) data
  from per_pay_bases ppb,
  pay_grade_rules_f pgr
  where ppb.rate_id = pgr.rate_id
  and '||av_date_from_variable||' between pgr.effective_start_date and pgr.effective_end_date
  and pgr.grade_or_spinal_point_id = :p_data_tab';
    --
  kbdx_kube_api_seed_pkg.create_dimtab_multrows(p_table_name => 'KB_GRADE_SALARY_DATA',
                                                p_sql_stmt  => l_sql,
                                                p_kube_type_id => l_kube_type_id,
                                                p_plsql_tab => 'kbdx_kube_utilities.g_grade_tab',
                                                p_table_structure => column_tab);
end per_grade_mid_points;

Procedure per_person_type_usages(p_kube_type_id in number,
                                 av_date_to  in varchar2,
                                 p_dim_tab in varchar2) as
 l_sql varchar2(6000);
 l_kube_type_id number := p_kube_type_id;
 column_tab kbdx_kube_seed_pkg.column_tabtype;
begin
    --
    -- 'KB_PERSON_TYPE_USAGES'
    --
  column_tab.delete;
  column_tab(1).name := 'PERSON_ID';
  column_tab(2).name := 'PERSON_TYPE_ID';
  column_tab(3).name := 'EFFECTIVE_START_DATE';
  column_tab(4).name := 'EFFECTIVE_END_DATE';
  column_tab(5).name := 'System_Person_Type';
  column_tab(6).name := 'User_Person_Type';
  column_tab(7).name := 'Primary_Person_type';
    --
  column_tab(1).data_type := 'LONG';
  column_tab(2).data_type := 'LONG';
  column_tab(3).data_type := 'DATE';
  column_tab(4).data_type := 'DATE';
  column_tab(5).data_type := 'TEXT';
  column_tab(6).data_type := 'TEXT';
  column_tab(7).data_type := 'TEXT';
    --
  l_sql :=
 'select /*+ RULE */ u.person_type_id||''|''||to_char(u.effective_start_date,''MM/DD/YYYY'')
  ||''|''||to_char(u.effective_end_date,''MM/DD/YYYY'')
  ||''|''||t.system_person_type||''|''||t.user_person_type||''|''||
  kbdx_kube_ora_hrms_seed_pkg.GET_PERSON_TYPE(u.person_id,u.effective_end_date) data
  from per_person_type_usages_f u,per_person_types t
  where u.person_id = :p_data_tab
  and t.business_group_id = fnd_profile.value(''PER_BUSINESS_GROUP_ID'')
  and t.person_type_id = u.person_type_id
  and '||av_date_to||' between u.effective_start_date and u.effective_end_date
  order by u.effective_start_date';
    --
  kbdx_kube_api_seed_pkg.create_dimtab_multrows(p_table_name => 'KB_PERSON_TYPE_USAGES',
                                                p_sql_stmt  => l_sql,
                                                p_kube_type_id => l_kube_type_id,
                                                p_plsql_tab => p_dim_tab,
                                                p_table_structure => column_tab);
end per_person_type_usages;

FUNCTION GET_PERSON_TYPE(an_person_id in number,
                         ad_date in date)
 RETURN  varchar2 IS
CURSOR csr_person_types
    (p_effective_date               IN     DATE
    ,p_person_id                    IN     NUMBER
    )
  IS
    SELECT ttl.user_person_type
      FROM per_person_types_tl ttl
          ,per_person_types typ
          ,per_person_type_usages_f ptu
     WHERE ttl.language = userenv('LANG')
       AND ttl.person_type_id = typ.person_type_id
       AND typ.system_person_type IN ('APL','EMP','EX_APL','EX_EMP','CWK','EX_CWK','OTHER')
       AND typ.person_type_id = ptu.person_type_id
       AND p_effective_date BETWEEN ptu.effective_start_date
                                AND ptu.effective_end_date
       AND ptu.person_id = p_person_id
  ORDER BY DECODE(typ.system_person_type
                 ,'EMP'   ,1
                 ,'CWK'   ,2
                 ,'APL'   ,3
                 ,'EX_EMP',4
                 ,'EX_CWK',5
                 ,'EX_APL',6
                          ,7
                 );
  l_user_person_type  VARCHAR2(2000);
  l_separator         VARCHAR2(1);
BEGIN
  l_separator := '.';
  FOR l_person_type IN csr_person_types
    (p_effective_date               => ad_date
    ,p_person_id                    => an_person_id
    )
  LOOP
    IF (l_user_person_type IS NULL)
    THEN
      l_user_person_type := l_person_type.user_person_type;
    ELSE
      l_user_person_type := l_user_person_type
                         || l_separator
                         || l_person_type.user_person_type;
    END IF;
  END LOOP;
  RETURN l_user_person_type;
 exception
  when others then
   return '';
END;
End kbdx_kube_load_seed_data;
/
show errors;
/