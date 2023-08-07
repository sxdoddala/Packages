/************************************************************************************
        Program Name:  KBDX_KUBE_BEN_SEED_PKG

       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
    IXPRAVEEN(ARGANO)            1.0     16-May-2023     R12.2 Upgrade Remediation
    ****************************************************************************************/
create or replace package body kbdx_kube_ben_seed_pkg as

l_worksheet_id    number;
l_table_id 		  Number;
l_sql 			  Varchar2(32000);
l_cxt_id 		  Number;
ln_kg_count 	  number;

column_tab kbdx_kube_seed_pkg.column_tabtype;
--
-- ----------------------------------------------------------------
-- -----------------------< ins_post_load >------------------------
-- ----------------------------------------------------------------
--
procedure ins_post_load (p_kube_type_id in number
                        ,p_stmt         in varchar2
                        ,p_sequence 	in number
						,p_name 		in varchar2
						,p_type 		in varchar2) is
begin
  --insert into kbace.kbdx_kube_post_load				-- Commented code by IXPRAVEEN-ARGANO,16-May-2023
  insert into apps.kbdx_kube_post_load                  --  code Added by IXPRAVEEN-ARGANO,   16-May-2023
          (kube_type_id
		  ,sql_stmt
		  ,load_sequence
		  ,name
		  ,type)
  values (p_kube_type_id
         ,p_stmt
		 ,p_sequence
		 ,p_name
		 ,p_type);
end      ins_post_load;

--
-- ----------------------------------------------------------------
-- -----------------------< add_enrollments >----------------------
-- ----------------------------------------------------------------
--
procedure add_enrollments(p_kube_type_id   in number
                         ,p_bg_id_var_name in varchar2  -- < Name of BUSINESS_GROUP_ID varriable
						 ,p_date_var_name  in varchar2  -- < Name of EFFECTIVE_DATE varriable
						 ) is
begin
add_enrollment_setups(p_kube_type_id ,p_bg_id_var_name,p_date_var_name);

l_sql :=
   'select    	prtt_enrt_rslt_id
    		||''|''||nvl(per_in_ler_id,-999)
    		||''|''||nvl(person_id,-999)
    		||''|''||to_char(enrt_cvg_strt_dt,''MM/DD/YYYY'')
    		||''|''||to_char(enrt_cvg_thru_dt,''MM/DD/YYYY'')
    		||''|''||to_char(orgnl_enrt_dt,''MM/DD/YYYY'')
    		||''|''||hr_general.decode_lookup(''BEN_COMP_LVL'', comp_lvl_cd)
    		||''|''||hr_general.decode_lookup(''BEN_BNFT_TYP'',bnft_typ_cd)
    		||''|''||bnft_amt
    		||''|''||hr_general.decode_lookup(''BEN_ENRT_MTHD'',enrt_mthd_cd)
    		||''|''||uom
    		||''|''||nvl(pl_id,-999)
    	    ||''|''||nvl(oipl_id,-999)
    	    ||''|''||nvl(pgm_id,-999)
			||''|''||nvl(enrt.pl_typ_id,-999)  data
    from   ben_prtt_enrt_rslt_f enrt
    where '||p_date_var_name||' between enrt_cvg_strt_dt and enrt_cvg_thru_dt
	and    business_group_id = '||p_bg_id_var_name||'
	and    enrt_cvg_thru_dt <= effective_end_date
	and    prtt_enrt_rslt_stat_cd is null';


l_table_id := kbdx_kube_seed_pkg.insert_table
                     (p_table_name            => 'KB_BEN_ENROLLMENT_RESULTS'
				     ,p_aol_owner_id 		  => -999
  					 ,p_table_type 		  	  => 'STATIC'
  					 ,p_sql_stmt 			  => l_sql
  					 ,p_plsql_dim_tab 		  => NULL
  					 ,p_dimension_sql_id      => 2
  					 ,p_kube_type_id 		  => p_kube_type_id
  					 ,p_worksheet_id 		  => l_worksheet_id
  					 ,p_columns 			  => column_tab);

l_sql := 'create index KB_BEN_ENROLLMENT_RESULTS_N1 on [KB_BEN_ENROLLMENT_RESULTS] (PRTT_ENRT_RSLT_ID);';
kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id => p_kube_type_id
                                      ,p_stmt 		  => l_sql
									  ,p_name    	  => 'KB_BEN_ENROLLMENT_RESULTS_N1'
									  ,p_type		  => 'T');

l_sql := 'create index KB_BEN_ENROLLMENT_RESULTS_N2 on [KB_BEN_ENROLLMENT_RESULTS] (PER_IN_LER_ID);';
kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id => p_kube_type_id
                                      ,p_stmt 		  => l_sql
									  ,p_name    	  => 'KB_BEN_ENROLLMENT_RESULTS_N2'
									  ,p_type		  => 'T');

l_sql := 'create index KB_BEN_ENROLLMENT_RESULTS_N3 on [KB_BEN_ENROLLMENT_RESULTS] (PERSON_ID);';
kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id => p_kube_type_id
                                      ,p_stmt 		  => l_sql
									  ,p_name    	  => 'KB_BEN_ENROLLMENT_RESULTS_N3'
									  ,p_type		  => 'T');

l_sql := 'create index KB_BEN_ENROLLMENT_RESULTS_N4 on [KB_BEN_ENROLLMENT_RESULTS] (PL_ID);';
kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id => p_kube_type_id
                                      ,p_stmt 		  => l_sql
									  ,p_name    	  => 'KB_BEN_ENROLLMENT_RESULTS_N4'
									  ,p_type		  => 'T');

l_sql := 'create index KB_BEN_ENROLLMENT_RESULTS_N5 on [KB_BEN_ENROLLMENT_RESULTS] (OIPL_ID);';
kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id => p_kube_type_id
                                      ,p_stmt 		  => l_sql
									  ,p_name    	  => 'KB_BEN_ENROLLMENT_RESULTS_N5'
									  ,p_type		  => 'T');

end add_enrollments;
--
-- ----------------------------------------------------------------
-- -------------------< add_enrollment_setups >--------------------
-- ----------------------------------------------------------------
--
procedure add_enrollment_setups(p_kube_type_id   in number
                               ,p_bg_id_var_name in varchar2  -- < Name of BUSINESS_GROUP_ID varriable
							   ,p_date_var_name  in varchar2  -- < Name of EFFECTIVE_DATE varriable
							   ) is
begin

--
-- -----------------------------------
-- KB_BEN_PLANS_AND_TYPES
-- -----------------------------------
--
column_tab.delete;
column_tab(1).name := 'Plan Name';
column_tab(2).name := 'Plan Type';
column_tab(3).name := 'PLN_ATTRIBUTE1';
column_tab(4).name := 'PLN_ATTRIBUTE2';
column_tab(5).name := 'PLN_ATTRIBUTE3';
column_tab(6).name := 'PTP_ATTRIBUTE1';
column_tab(7).name := 'PTP_ATTRIBUTE2';
column_tab(8).name := 'PTP_ATTRIBUTE3';
column_tab(9).name := 'PL_TYP_ID';
column_tab(10).name := 'PL_ID';
--
column_tab(1).data_type := 'TEXT';
column_tab(2).data_type := 'TEXT';
column_tab(3).data_type := 'TEXT';
column_tab(4).data_type := 'TEXT';
column_tab(5).data_type := 'TEXT';
column_tab(6).data_type := 'TEXT';
column_tab(7).data_type := 'TEXT';
column_tab(8).data_type := 'TEXT';
column_tab(9).data_type := 'LONG';
column_tab(10).data_type := 'LONG';
--
--
l_sql :=
   'select   /*+ RULE */
	        a.name
		    ||''|''||b.name
	     	||''|''||a.pln_attribute1
	     	||''|''||a.pln_attribute2
	     	||''|''||a.pln_attribute3
	     	||''|''||b.ptp_attribute1
	     	||''|''||b.ptp_attribute2
	     	||''|''||b.ptp_attribute3
	     	||''|''||b.pl_typ_id
			||''|''||a.pl_id data
	from   ben_pl_typ_f b
		   ,ben_pl_f a
	where  a.pl_typ_id = b.pl_typ_id
	and    '||p_date_var_name||' between a.effective_start_date and a.effective_end_date
	and    '||p_date_var_name||' between b.effective_start_date and b.effective_end_date
	and    a.business_group_id = '||p_bg_id_var_name||'
	union
	select null
		   ||''|''||null
		   ||''|''||null
		   ||''|''||null
		   ||''|''||null
		   ||''|''||null
		   ||''|''||null
		   ||''|''||null
		   ||''|''||-999
		   ||''|''||-999 data
	from   dual';



l_table_id := kbdx_kube_seed_pkg.insert_table
                     (p_table_name            => 'KB_BEN_PLANS_AND_TYPES'
				     ,p_aol_owner_id 		  => -999
  					 ,p_table_type 		  	  => 'STATIC'
  					 ,p_sql_stmt 			  => l_sql
  					 ,p_plsql_dim_tab 		  => NULL
  					 ,p_dimension_sql_id      => 2
  					 ,p_kube_type_id 		  => p_kube_type_id
  					 ,p_worksheet_id 		  => l_worksheet_id
  					 ,p_columns 			  => column_tab);

l_sql := 'create index KB_BEN_PLANS_AND_TYPES_N1 on [KB_BEN_PLANS_AND_TYPES] (PL_ID);';
kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id => p_kube_type_id
                                      ,p_stmt 		  => l_sql
									  ,p_name    	  => 'KB_BEN_PLANS_AND_TYPES_N1'
									  ,p_type		  => 'T');

--
-- -----------------------------------
-- KB_BEN_OPTIONS_BY_OIPL
-- -----------------------------------
--
column_tab.delete;
column_tab(1).name := 'OIPL_ID';
column_tab(2).name := 'OPT_ID';
column_tab(3).name := 'Option';
column_tab(4).name := 'OPT_ATTRIBUTE1';
column_tab(5).name := 'OPT_ATTRIBUTE2';
column_tab(6).name := 'OPT_ATTRIBUTE3';
column_tab(7).name := 'COP_ATTRIBUTE1';
column_tab(8).name := 'COP_ATTRIBUTE2';
column_tab(9).name := 'COP_ATTRIBUTE3';
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
--
--
l_sql :=
    'select /*+ RULE */
		   oipl_id
		   ||''|''||a.opt_id
		   ||''|''||name
		   ||''|''||opt_attribute1
		   ||''|''||opt_attribute2
		   ||''|''||opt_attribute3
		   ||''|''||cop_attribute1
		   ||''|''||cop_attribute2
		   ||''|''||cop_attribute3 data
	from   ben_opt_f a
		   ,ben_oipl_f b
	where  a.opt_id = b.opt_id
	and    b.business_group_id = '||p_bg_id_var_name||'
	and    '||p_date_var_name||' between b.effective_start_date and b.effective_end_date
	and    '||p_date_var_name||' between a.effective_start_date and a.effective_end_date
	union
	select -999
		   ||''|''||-999
		   ||''|''||null
		   ||''|''||null
		   ||''|''||null
		   ||''|''||null
		   ||''|''||null
		   ||''|''||null
		   ||''|''||null data
   from dual';



l_table_id := kbdx_kube_seed_pkg.insert_table
                     (p_table_name            => 'KB_BEN_OPTIONS_BY_OIPL'
				     ,p_aol_owner_id 		  => -999
  					 ,p_table_type 		  	  => 'STATIC'
  					 ,p_sql_stmt 			  => l_sql
  					 ,p_plsql_dim_tab 		  => NULL
  					 ,p_dimension_sql_id      => 2
  					 ,p_kube_type_id 		  => p_kube_type_id
  					 ,p_worksheet_id 		  => l_worksheet_id
  					 ,p_columns 			  => column_tab);

l_sql := 'create index KB_BEN_OPTIONS_BY_OIPL_N1 on [KB_BEN_OPTIONS_BY_OIPL] (OIPL_ID);';
kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id => p_kube_type_id
                                      ,p_stmt 		  => l_sql
									  ,p_name    	  => 'KB_BEN_OPTIONS_BY_OIPL_N1'
									  ,p_type		  => 'T');

--
-- -----------------------------------
-- KB_BEN_PROGRAMS
-- -----------------------------------
--
column_tab.delete;
column_tab(1).name := 'PGM_ID';
column_tab(2).name := 'Program Name';
column_tab(3).name := 'pgm_attribute1';
column_tab(4).name := 'pgm_attribute2';
column_tab(5).name := 'pgm_attribute3';
--
column_tab(1).data_type := 'LONG';
column_tab(2).data_type := 'TEXT';
column_tab(3).data_type := 'TEXT';
column_tab(4).data_type := 'TEXT';
column_tab(5).data_type := 'TEXT';
--
--
l_sql :=
	'select pgm_id
		   ||''|''||name
		   ||''|''||pgm_attribute1
		   ||''|''||pgm_attribute2
		   ||''|''||pgm_attribute3  data
	from   ben_pgm_f
	where  '||p_date_var_name||' between effective_start_date and effective_end_date
	and    business_group_id = '||p_bg_id_var_name||'
	union
	select -999
		   ||''|''||''Not in Program''
		   ||''|''||null
		   ||''|''||null
		   ||''|''||null data
	from dual';



l_table_id := kbdx_kube_seed_pkg.insert_table
                     (p_table_name            => 'KB_BEN_PROGRAMS'
				     ,p_aol_owner_id 		  => -999
  					 ,p_table_type 		  	  => 'STATIC'
  					 ,p_sql_stmt 			  => l_sql
  					 ,p_plsql_dim_tab 		  => NULL
  					 ,p_dimension_sql_id      => 2
  					 ,p_kube_type_id 		  => p_kube_type_id
  					 ,p_worksheet_id 		  => l_worksheet_id
  					 ,p_columns 			  => column_tab);

l_sql := 'create index KB_BEN_PROGRAMS_N1 on [KB_BEN_PROGRAMS] (PGM_ID);';
kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id => p_kube_type_id
                                      ,p_stmt 		  => l_sql
									  ,p_name    	  => 'KB_BEN_PROGRAMS_N1'
									  ,p_type		  => 'T');

--
-- -----------------------------------
-- KB_BEN_BENEFIT_GROUPS
-- -----------------------------------
--
--
column_tab.delete;
column_tab(1).name := 'BENFTS_GRP_ID';
column_tab(2).name := 'Benefit Group';
column_tab(3).name := 'Benefit Group Description';
column_tab(4).name := 'bng_attribute1';
column_tab(5).name := 'bng_attribute2';
column_tab(6).name := 'bng_attribute3';
column_tab(7).name := 'bng_attribute4';
column_tab(8).name := 'bng_attribute5';
--
column_tab(1).data_type := 'LONG';
column_tab(2).data_type := 'TEXT';
column_tab(3).data_type := 'TEXT';
column_tab(4).data_type := 'TEXT';
column_tab(5).data_type := 'TEXT';
column_tab(6).data_type := 'TEXT';
column_tab(7).data_type := 'TEXT';
column_tab(8).data_type := 'TEXT';
--
--
l_sql :=
   'select benfts_grp_id
	      ||''|''||name
	      ||''|''||bng_desc
	      ||''|''||bng_attribute1
	      ||''|''||bng_attribute2
	      ||''|''||bng_attribute3
	      ||''|''||bng_attribute4
	      ||''|''||bng_attribute5 data
	from   ben_benfts_grp
	where  business_Group_id = '||p_bg_id_var_name||'
	union
	select -999
	      ||''|''||null
	      ||''|''||null
	      ||''|''||null
	      ||''|''||null
	      ||''|''||null
	      ||''|''||null
	      ||''|''||null data
	from  dual';


-- l_table_id := kbdx_kube_seed_pkg.insert_table
--                      (p_table_name            => 'KB_BEN_BENEFIT_GROUPS'
-- 				     ,p_aol_owner_id 		  => -999
--   					 ,p_table_type 		  	  => 'STATIC'
--   					 ,p_sql_stmt 			  => l_sql
--   					 ,p_plsql_dim_tab 		  => NULL
--   					 ,p_dimension_sql_id      => 2
--   					 ,p_kube_type_id 		  => p_kube_type_id
--   					 ,p_worksheet_id 		  => l_worksheet_id
--   					 ,p_columns 			  => column_tab);

kbdx_kube_api_seed_pkg.create_static_table(p_table_name      => 'KB_BEN_BENEFIT_GROUPS'
                                          ,p_sql_stmt  	     => l_sql
                                          ,p_kube_type_id	 => p_kube_type_id
				                          ,p_table_structure => column_tab);


l_sql := 'create index KB_BEN_BENEFIT_GROUPS_N1 on [KB_BEN_BENEFIT_GROUPS] (BENFTS_GRP_ID);';
kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id => p_kube_type_id
                                      ,p_stmt 		  => l_sql
									  ,p_name    	  => 'KB_BEN_BENEFIT_GROUPS_N1'
									  ,p_type		  => 'T');

end add_enrollment_setups;

--
-- ----------------------------------------------------------------
-- ----------------------< add_life_events >-----------------------
-- ----------------------------------------------------------------
--
procedure add_life_events(p_kube_type_id    in number
                         ,p_bg_id_var_name	in varchar2
                         ,p_date_var_name   in varchar2
                         ,p_pil_var_name	in varchar2) is

begin

l_worksheet_id := kbdx_kube_seed_pkg.get_worksheet_id(p_kube_type_id => p_kube_type_id);


column_tab.delete;
column_tab(1).name := 'LER_ID';
column_tab(2).name := 'Life Event';
--
column_tab(1).data_type := 'LONG';
column_tab(2).data_type := 'TEXT';
--
--
l_sql:=
   'select ler_id
		   ||''|''||name data
	from   ben_ler_f
	where  '||p_date_var_name||' between effective_start_date and effective_end_date
	and    business_group_id = '||p_bg_id_var_name||'
	union
	select -999||''|''||''Missing Life Event'' from dual';

l_table_id := kbdx_kube_seed_pkg.insert_table
                     (p_table_name            => 'KB_BEN_LIFE_EVENTS'
				     ,p_aol_owner_id 		  => -999
  					 ,p_table_type 		  	  => 'STATIC'
  					 ,p_sql_stmt 			  => l_sql
  					 ,p_plsql_dim_tab 		  => NULL
  					 ,p_dimension_sql_id      => 2
  					 ,p_kube_type_id 		  => p_kube_type_id
  					 ,p_worksheet_id 		  => l_worksheet_id
  					 ,p_columns 			  => column_tab);

--
column_tab.delete;
column_tab(1).name := 'PER_IN_LER_ID';
column_tab(2).name := 'Occurred';
column_tab(3).name := 'Status';
column_tab(4).name := 'Previous Status';
column_tab(5).name := 'Processed Date';
column_tab(6).name := 'Started Date';
column_tab(7).name := 'Voided Date';
column_tab(8).name := 'Backed Out Date';
column_tab(9).name := 'Notified Date';
column_tab(10).name := 'PERSON_ID';
column_tab(11).name := 'LER_ID';

column_tab(1).data_type := 'LONG';
column_tab(2).data_type := 'TEXT';
column_tab(3).data_type := 'TEXT';
column_tab(4).data_type := 'TEXT';
column_tab(5).data_type := 'DATETIME';
column_tab(6).data_type := 'DATETIME';
column_tab(7).data_type := 'DATETIME';
column_tab(8).data_type := 'DATETIME';
column_tab(9).data_type := 'DATETIME';
column_tab(10).data_type := 'LONG';
column_tab(11).data_type := 'LONG';

l_sql:=
	'Begin
	select  to_char(lf_evt_ocrd_dt,''MM/DD/YYYY'')
			||''|''||hr_general.decode_lookup(''BEN_PER_IN_LER_STAT'',per_in_ler_stat_cd)
			||''|''||hr_general.decode_lookup(''BEN_PER_IN_LER_STAT'',prvs_stat_cd)
			||''|''||to_char(procd_dt,''MM/DD/YYYY'')
			||''|''||to_char(strtd_dt,''MM/DD/YYYY'')
			||''|''||to_char(voidd_dt,''MM/DD/YYYY'')
			||''|''||to_char(bckt_dt,''MM/DD/YYYY'')
			||''|''||to_char(ntfn_dt,''MM/DD/YYYY'')
	    	||''|''||person_id
			||''|''||nvl(ler_id,-999) data
    into   l_data
	from    ben_per_in_ler
	where  per_in_ler_id = 	:p_data_tab
	and    per_in_ler_stat_cd not in  (''BCKDT'',''VOIDD'');
	Exception When Others Then
	  l_data := ''|'';
	  End;';

l_table_id := kbdx_kube_seed_pkg.insert_table (p_table_name        => 'KB_BEN_PERSON_LIFE_EVENTS'
                                              ,p_aol_owner_id 	   => -999
                                              ,p_table_type 	   => 'DIM'
                                              ,p_sql_stmt 		   => l_sql
                                              ,p_plsql_dim_tab 	   => p_pil_var_name
                                              ,p_dimension_sql_id  => 1
                                              ,p_kube_type_id 	   => p_kube_type_id
                                              ,p_worksheet_id 	   => l_worksheet_id
                                              ,p_columns 		   => column_tab);


-- Post Loads
l_sql :=
'SELECT KB_BEN_LIFE_EVENTS.[Life Event], KB_BEN_PERSON_LIFE_EVENTS.*
INTO KB_BEN_PER_IN_LER
FROM KB_BEN_LIFE_EVENTS RIGHT JOIN KB_BEN_PERSON_LIFE_EVENTS ON KB_BEN_LIFE_EVENTS.LER_ID=KB_BEN_PERSON_LIFE_EVENTS.LER_ID;';
kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id => p_kube_type_id
                                      ,p_stmt 		  => l_sql
									  ,p_name    	  => 'KB_BEN_PER_IN_LER'
									  ,p_type		  => 'T');

l_sql := 'create index KB_BEN_ENRT_RSLT_N1 on [KB_BEN_PER_IN_LER] (PER_IN_LER_ID);';
kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id => p_kube_type_id
                                      ,p_stmt 		  => l_sql
									  ,p_name    	  => 'KB_BEN_PER_IN_LER_N1'
									  ,p_type		  => 'T');

l_sql := 'create index KB_BEN_ENRT_RSLT_N2 on [KB_BEN_PER_IN_LER] (PERSON_ID);';
kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id => p_kube_type_id
                                      ,p_stmt 		  => l_sql
									  ,p_name    	  => 'KB_BEN_PER_IN_LER_N2'
									  ,p_type		  => 'T');

l_sql := 'DROP TABLE KB_BEN_PERSON_LIFE_EVENTS;';
kbdx_kube_load_seed_data.ins_post_load(p_kube_type_id => p_kube_type_id
                                      ,p_stmt 		  => l_sql
									  ,p_name    	  => 'DROP_KB_BEN_PERSON_LIFE_EVENTS'
									  ,p_type		  => 'T');


end add_life_events;



end kbdx_kube_ben_seed_pkg;
/
show errors;
/
