create or replace Package body KBDX_PURGE_KUBES AS
/*
 * $History: kbdx_purge_kubes.pkb $
 *
 * *****************  Version 24  *****************
 * User: Jkeller      Date: 5/04/11    Time: 11:56a
 * Updated in $/KBX Kube Main/40_CODE_BASE/PATCH/4005.8
 * comments added
 *
 *    20  Jkeller      7/15/08    keep kbdx_file_definitions and kbdx_worksheets
 *    16  Jkeller      4/17/08    d.concurrent_program_name = 'KBDXUGEN' and
 *	1.0	IXPRAVEEN(ARGANO)  16-May-2023		R12.2 Upgrade Remediation
 *  Note this is the only Kube that should not call Initialize_Kube_Files or Initialize_Kube
 *   so that it does not use the RAC Cache LOBCACHE feature. We want to purge the Kubes
 *   from the final output path, not the local RAC Cache.
 *
 * See SourceSafe for addition comments
 *
*/
 l_error varchar2(2500);
   --
procedure main(p_process_id number) is

 l_count         number         := 0;
 l_in_count      number         := 0;
 l_out_count     number         := 0;
 l_removed_count number         := 0;
 l_utl_file_dir  varchar2(4000);
 l_zip_status    number         := 0;

cursor get_aged_out_kbx_filename Is
  select /*+ RULE */ k.process_id, k.file_name
    --from kbace.kbdx_processes k			-- Commented code by IXPRAVEEN-ARGANO,16-May-2023
    from apps.kbdx_processes k             --  code Added by IXPRAVEEN-ARGANO,   16-May-2023
   where not EXISTS (select /*+ RULE */ f.request_id from fnd_concurrent_requests f
                     where  f.REQUEST_ID = k.REQUEST_ID)
    and k.max_line_size = 0
    and k.number_of_lines = 0
    and k.dataset_id = 0
    and file_name is not null;

type tProcess_id is table of NUMBER index by binary_integer;
  gtProcess_id         tProcess_id;
BEGIN
    --
  select /*+ RULE */ count(*) --k.file_name
    into l_in_count
    --from kbace.kbdx_processes k			-- Commented code by IXPRAVEEN-ARGANO,16-May-2023
    from apps.kbdx_processes k              --  code Added by IXPRAVEEN-ARGANO,   16-May-2023
   where not EXISTS (select /*+ RULE */ f.request_id from fnd_concurrent_requests f
                     where  f.REQUEST_ID = k.REQUEST_ID)
    and k.max_line_size = 0
    and k.number_of_lines = 0
    and k.dataset_id = 0
    and file_name is not null;
    --
  select kbdx_file_utils.get_path into l_utl_file_dir from dual;
    --
  For i in get_aged_out_kbx_filename Loop
     l_removed_count := l_removed_count + 1;
     begin
       utl_file.FREMOVE(location=>'LOBMANIP', FILENAME=>i.file_name);
      EXCEPTION
        when OTHERS then
          l_zip_status := kbdx_delete (p_path =>l_utl_file_dir , p_file =>i.file_name);
     end;
     gtProcess_id(l_removed_count) := i.process_id;
     fnd_file.put_line(fnd_file.log,'Deleted the Process Id: '||i.process_id||' - '||i.file_name);
     fnd_file.put_line(fnd_file.log,' ');
  End Loop;
    --
  l_removed_count := 0;
  for i in 1..nvl(gtProcess_id.count,0) Loop
     l_removed_count := l_removed_count + 1;
     delete from kbdx_http_parameter_files where process_id = gtProcess_id(l_removed_count);
     delete from kbdx_kube_parameter_files where process_id = gtProcess_id(l_removed_count);
     delete  from kbdx_kube_parameter_data where process_id = gtProcess_id(l_removed_count);
     --delete from kbace.kbdx_processes where process_id = gtProcess_id(l_removed_count);						-- Commented code by IXPRAVEEN-ARGANO,16-May-2023
     delete from apps.kbdx_processes where process_id = gtProcess_id(l_removed_count);                         --  code Added by IXPRAVEEN-ARGANO,   16-May-2023
  End loop;
    --
  select /*+ RULE */ count(*) --k.file_name
    into l_out_count
    --from kbace.kbdx_processes k				-- Commented code by IXPRAVEEN-ARGANO,16-May-2023
    from apps.kbdx_processes k                 --  code Added by IXPRAVEEN-ARGANO,   16-May-2023
   where not EXISTS (select /*+ RULE */ f.request_id from fnd_concurrent_requests f
                     where  f.REQUEST_ID = k.REQUEST_ID)
    and k.max_line_size = 0
    and k.number_of_lines = 0
    and k.dataset_id = 0
    and file_name is not null;
    --
  fnd_file.put_line(fnd_file.log,'Physical location Of the files: '||l_utl_file_dir);
  fnd_file.put_line(fnd_file.log,' ');
  fnd_file.put_line(fnd_file.log,'Total Files Selected For Purging: '||l_in_count);
  fnd_file.put_line(fnd_file.log,' ');
  fnd_file.put_line(fnd_file.log,'Total Files Actually Purged: '||l_removed_count);
  fnd_file.put_line(fnd_file.log,' ');
  fnd_file.put_line(fnd_file.log,'Files That could not be purged: '||l_out_count);
    --
  select count(*) into l_count from kbdx_file_definitions d where not exists (select null from kbdx_kube_types t where t.kube_type = d.process_type);
  fnd_file.put_line(fnd_file.log,' ');
  fnd_file.put_line(fnd_file.log,'Noted orphaned kbdx_file_definitions. Possibly for KBX version 3: '||l_count);
    -- was delete from kbdx_file_definitions d where not exists (select null from kbdx_kube_types t where t.kube_type = d.process_type);
    --
  select count(*) into l_count from kbdx_worksheets w where not exists (select null from kbdx_kube_types t where t.kube_type = w.name);
  fnd_file.put_line(fnd_file.log,' ');
  fnd_file.put_line(fnd_file.log,'Noted orphaned kbdx_worksheets. Possibly for KBX version 3: '||l_count);
   -- was delete from kbdx_worksheets w where not exists (select null from kbdx_kube_types t where t.kube_type = w.name);
    --
  select count(*) into l_count from kbdx_datasets d where d.concurrent_program_name = 'KBDXUGEN' and not exists (select null from kbdx_kube_types t where t.kube_type = d.process_type);
  fnd_file.put_line(fnd_file.log,' ');
  fnd_file.put_line(fnd_file.log,'Removed orphaned kbdx_datasets(process_type): '||l_count);
  delete from kbdx_datasets d where d.concurrent_program_name = 'KBDXUGEN' and not exists (select null from kbdx_kube_types t where t.kube_type = d.process_type);
    --
  select count(*) into l_count from kbdx_datasets d where d.concurrent_program_name = 'KBDXUGEN' and not exists (select null from kbdx_kube_types t where t.kube_type = d.dataset_description);
  fnd_file.put_line(fnd_file.log,' ');
  fnd_file.put_line(fnd_file.log,'Removed orphaned kbdx_datasets(dataset_description): '||l_count);
  delete from kbdx_datasets d where d.concurrent_program_name = 'KBDXUGEN' and not exists (select null from kbdx_kube_types t where t.kube_type = d.dataset_description);
    --
  select count(*) into l_count from kbdx_kube_tables ta where not exists (select null from kbdx_kube_types t where t.kube_type_id = ta.kube_type_id);
  fnd_file.put_line(fnd_file.log,' ');
  fnd_file.put_line(fnd_file.log,'Removed orphaned kbdx_kube_tables: '||l_count);
  delete from kbdx_kube_tables ta where not exists (select null from kbdx_kube_types t where t.kube_type_id = ta.kube_type_id);
    --
  select count(*) into l_count from kbdx_kube_assigned_resps a where not exists (select null from kbdx_kube_types t where t.kube_type_id = a.kube_type_id);
  fnd_file.put_line(fnd_file.log,' ');
  fnd_file.put_line(fnd_file.log,'Removed orphaned kbdx_kube_assigned_resps: '||l_count);
  delete from kbdx_kube_assigned_resps a where not exists (select null from kbdx_kube_types t where t.kube_type_id = a.kube_type_id);
    --
  --select count(*) into l_count from kbace.kbdx_kube_flexfield_def d where not exists (select null from kbdx_kube_types t where t.kube_type_id = d.kube_type_id);			-- Commented code by IXPRAVEEN-ARGANO,16-May-2023
  select count(*) into l_count from apps.kbdx_kube_flexfield_def d where not exists (select null from kbdx_kube_types t where t.kube_type_id = d.kube_type_id);            --  code Added by IXPRAVEEN-ARGANO,   16-May-2023
  fnd_file.put_line(fnd_file.log,' ');
  fnd_file.put_line(fnd_file.log,'Removed orphaned kbace.kbdx_kube_flexfield_def: '||l_count);
  --delete from kbace.kbdx_kube_flexfield_def d where not exists (select null from kbdx_kube_types t where t.kube_type_id = d.kube_type_id);		-- Commented code by IXPRAVEEN-ARGANO,16-May-2023
  delete from apps.kbdx_kube_flexfield_def d where not exists (select null from kbdx_kube_types t where t.kube_type_id = d.kube_type_id);           --  code Added by IXPRAVEEN-ARGANO,   16-May-2023
    --
  select count(*) into l_count from kbdx_kube_executables e where not exists (select null from kbdx_kube_types t where t.kube_type_id = e.kube_type_id);
  fnd_file.put_line(fnd_file.log,' ');
  fnd_file.put_line(fnd_file.log,'Removed orphaned kbdx_kube_executables: '||l_count);
  delete from kbdx_kube_executables e where not exists (select null from kbdx_kube_types t where t.kube_type_id = e.kube_type_id);
    --
  select count(*) into l_count from kbdx_kube_post_load p where not exists (select null from kbdx_kube_types t where t.kube_type_id = p.kube_type_id);
  fnd_file.put_line(fnd_file.log,' ');
  fnd_file.put_line(fnd_file.log,'Removed orphaned kbdx_kube_post_load: '||l_count);
  delete from kbdx_kube_post_load p where not exists (select null from kbdx_kube_types t where t.kube_type_id = p.kube_type_id);
    --
  select count(*) into l_count from kbdx_kube_containers c where not exists (select null from kbdx_kube_types t where t.kube_type_id = c.kube_type_id);
  fnd_file.put_line(fnd_file.log,' ');
  fnd_file.put_line(fnd_file.log,'Removed orphaned kbdx_kube_containers: '||l_count);
  delete from kbdx_kube_containers c where not exists (select null from kbdx_kube_types t where t.kube_type_id = c.kube_type_id);
    --
---------------------------------------------------------------------------------------------------------
-- FINISH KUBE
---------------------------------------------------------------------------------------------------------

  kbdx_kube_api_pkg.finish_kube(p_process_id => p_process_id, p_aol_owner  => fnd_profile.value('PER_BUSINESS_GROUP_ID'));

 Exception
    When OTHERS Then
      l_error := substr(SQLERRM,1,2000);
      kbdx_kube_api_pkg.finish_kube(p_process_id  => p_process_id, p_message => l_error);

End Main;
END KBDX_PURGE_KUBES;
/
show errors;
/