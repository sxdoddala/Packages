create or replace PACKAGE BODY kbdx_kube_dd_utilities
 AS
/*
 * $History: kbdx_kube_dd_utilities.pkb $
 *
 * *****************  Version 53  *****************
 * User: Jkeller      Date: 8/25/10    Time: 12:28p
 * Updated in $/KBX Kube Main/40_CODE_BASE/PATCH/4005.7
 * removed uploadtemplates required by 4.2.26.1 desktop oracle instant
 * client
 *
 *   46  Jkeller     11/07/09    translate function 'CONSOLNAME2ID'
 *   42  Jkeller     12/22/08    allows multiple blocks of rows to be processed in loop
 *   39  Jkeller      4/17/08    v_dd_stmts   get_KBDX_KUBE_DD_STMTS%ROWTYPE
 *   37  Jkeller      4/15/08    requires kbdx_kube_binds 1-30 varchar2 and 31-60 number columns for k255Translation
 *	1.0	IXPRAVEEN(ARGANO)  12-May-2023		R12.2 Upgrade Remediation
 * See SourceSafe for addition comments
 *
*/

/*
  --JAK 08/22/2010 moved to kbdx_blob_writer prior to releasing 40057 thus only needed for
  -- desktop KBX Kube Manager 4.2.26.1
Procedure Uploadtemplate(
        p_kube_type_id          in       varchar2,
        p_kube_type             in       varchar2,
        p_template_name         in       varchar2,
        p_template_location     in       varchar2,
        p_template_author       in       varchar2,
        p_template_description  in       varchar2,
        p_user_defined          in       varchar2,
        p_template_executable   in       varchar2,
        p_template_type_id      in       varchar2,
        p_tooltip               in       varchar2,
        p_results               out      varchar2) IS
   --
BEGIN
   kbdx_blob_writer.Uploadtemplate(
        p_kube_type_id          => p_kube_type_id,
        p_kube_type             => p_kube_type,
        p_template_name         => p_template_name,
        p_template_location     => p_template_location,
        p_template_author       => p_template_author,
        p_template_description  => p_template_description,
        p_user_defined          => p_user_defined,
        p_template_executable   => p_template_executable,
        p_template_type_id      => p_template_type_id,
        p_tooltip               => p_tooltip,
        p_results               => p_results);
END;
*/
  --
Procedure Hold_KBDX_KUBE_DD_STMTS(p_ddstmt_id  in  number) is

BEGIN

     g_kbdx_kube_dd_stmts(p_ddstmt_id) := p_ddstmt_id;

END Hold_KBDX_KUBE_DD_STMTS;

--
Procedure Place_KBDX_KUBE_DD_STMTS is

 i            BINARY_INTEGER;

 cursor get_KBDX_KUBE_DD_STMTS(pddstmt_id number) is
  select /*+ RULE */
     d.ddstmt_id,
     d.client_server_execute,
     d.description,
     d.ddstmt,
     d.ddarchived
    --from kbace.kbdx_kube_dd_stmts d			-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
    from apps.kbdx_kube_dd_stmts d              --  code Added by IXPRAVEEN-ARGANO,   12-May-2023
   where d.ddstmt_id = pddstmt_id;

 v_dd_stmts   get_KBDX_KUBE_DD_STMTS%ROWTYPE;

BEGIN

  i := g_kbdx_kube_dd_stmts.FIRST;
  OPEN get_KBDX_KUBE_DD_STMTS(i);
  LOOP
    FETCH get_KBDX_KUBE_DD_STMTS into v_dd_stmts;
    --insert into kbace.kbdx_kube_dd_stmts_archive (				-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
    insert into apps.kbdx_kube_dd_stmts_archive (                   --  code Added by IXPRAVEEN-ARGANO,   12-May-2023
       ddstmt_id,
       client_server_execute,
       description,
       ddstmt,
       ddarchived)
     values (
       g_kbdx_kube_dd_stmts(i),
       v_dd_stmts.client_server_execute,
       v_dd_stmts.description,
       v_dd_stmts.ddstmt,
       v_dd_stmts.ddarchived);
     EXIT WHEN i = g_kbdx_kube_dd_stmts.LAST;
     i := g_kbdx_kube_dd_stmts.NEXT(i);
  END LOOP;

  CLOSE get_KBDX_KUBE_DD_STMTS;
  g_kbdx_kube_dd_stmts.DELETE;

  Exception
      When others then
          CLOSE get_KBDX_KUBE_DD_STMTS;
          g_kbdx_kube_dd_stmts.DELETE;

END Place_KBDX_KUBE_DD_STMTS;

Procedure Clean_KBDX_KUBE_DD_STMTS(DaysOld in number) is

 i BINARY_INTEGER;
 toDay date := sysdate;
 deleteCount int := 0;

cursor get_KBDX_KUBE_DD_STMTS_ARCHIVE is
  select /*+ RULE */ k.ddstmt_id
    --from kbace.KBDX_KUBE_DD_STMTS_ARCHIVE k				-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
    from apps.KBDX_KUBE_DD_STMTS_ARCHIVE k                 --  code Added by IXPRAVEEN-ARGANO,   12-May-2023
   --where not EXISTS (select /*+ RULE */ f.ddstmt_id from kbace.KBDX_KUBE_DD_STMTS f			-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
   where not EXISTS (select /*+ RULE */ f.ddstmt_id from apps.KBDX_KUBE_DD_STMTS f              --  code Added by IXPRAVEEN-ARGANO,   12-May-2023
                     where  f.ddstmt_id = k.ddstmt_id)
     and k.ddarchived is null;

BEGIN

    g_kbdx_kube_dd_stmts.DELETE;
    For i in get_KBDX_KUBE_DD_STMTS_ARCHIVE LOOP
        g_kbdx_kube_dd_stmts(i.ddstmt_id) := i.ddstmt_id;
        deleteCount := deleteCount + 1;
    END LOOP;

    if deleteCount > 0 then
        i := g_kbdx_kube_dd_stmts.FIRST;
        LOOP
           --update kbace.KBDX_KUBE_DD_STMTS_ARCHIVE f			-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
           update apps.KBDX_KUBE_DD_STMTS_ARCHIVE f            --  code Added by IXPRAVEEN-ARGANO,   12-May-2023
              set f.ddarchived = toDay
            where f.ddstmt_id = g_kbdx_kube_dd_stmts(i);
        EXIT WHEN i = g_kbdx_kube_dd_stmts.LAST;
        i := g_kbdx_kube_dd_stmts.NEXT(i);
        END LOOP;
    end if;

    --delete from kbace.KBDX_KUBE_DD_STMTS_ARCHIVE d			-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
    delete from apps.KBDX_KUBE_DD_STMTS_ARCHIVE d              --  code Added by IXPRAVEEN-ARGANO,   12-May-2023
     where not ddarchived is null
       and toDay - ddarchived < (-1 * DaysOld);

    g_kbdx_kube_dd_stmts.DELETE;

END Clean_KBDX_KUBE_DD_STMTS;
--
Procedure Prepare_dd50_stmt(
        p_ddstmt_id            in       number,
        p_pair_element_count   in       number,
        p_bind_labels          in       varchar2,
        p_lookup_pairs         in       varchar2,
        p_row_values           in       varchar2,
        P_sqlstmnt             Out      Long,
        P_message              Out      varchar2)
is
    BindLabelMissing           Exception;
    v_lup_row_values  varchar2(2000) := null;
    v_row_values      varchar2(2000) := null;
    v_sqltext         long;
    ln_start          number := 0;
    ln_end            number := 0;
    l_str             varchar2(500) := null;
    v_bind_count      number :=0;
    v_value_count     number :=0;
    v_return_code     number := 0;
Begin
  --
  gtBindLabel.delete;
  gtBindValue.delete;
  P_message     := null;
    --check early since this is the archive table
    -- exception handler at exit services no_data_found
  Select ddstmt
    into v_sqltext
    --from kbace.kbdx_kube_dd_stmts_archive			-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
    from apps.kbdx_kube_dd_stmts_archive           --  code Added by IXPRAVEEN-ARGANO,   12-May-2023
   where ddstmt_id = p_ddstmt_id;
 --
  If p_pair_element_count > 0 then
        RowTranslate(
            p_pair_elements =>  p_pair_element_count,
            p_pair_string   =>  p_lookup_pairs,
            P_pair_lookup   =>  v_lup_row_values,
            P_return_code   =>  v_return_code,
            P_message       =>  P_message);
        If v_return_code <> 0 then
	        return; --v_message is already set
        End IF;
        v_row_values := v_lup_row_values || '|' || p_row_values;
 Else
        v_row_values := p_row_values;
 End IF;
  --
  If v_lup_row_values is null then
        v_row_values := p_row_values;
  Else
        v_row_values := v_lup_row_values || '|' || p_row_values;
  End IF;
  --
  ln_start := 0; ln_end := 0; l_str := null; v_bind_count := 0;
  Loop
    v_bind_count := v_bind_count + 1;
    ln_start := ln_end + ln_start + 1;
    ln_end := instr(p_bind_labels,'|',1,v_bind_count) - ln_start;
    If ln_end < 0 Then
        l_str :=  substr(p_bind_labels,ln_start);
        gtBindLabel(v_bind_count) := l_str;
        l_str := null;
       Exit;
    Else
       l_str := substr(p_bind_labels,ln_start,ln_end);
       gtBindLabel(v_bind_count) := l_str;
       l_str := null;
    End IF;
  End Loop;
  --
  ln_start := 0; ln_end := 0; l_str := null; v_value_count := 0;
  Loop
    v_value_count := v_value_count + 1;
    ln_start := ln_end + ln_start + 1;
    ln_end := instr(v_row_values,'|',1,v_value_count) - ln_start;
    If ln_end < 0 Then
        l_str :=  substr(v_row_values,ln_start);
        gtBindValue(v_value_count) := l_str;
        l_str := null;
       Exit;
    Else
       l_str := substr(v_row_values,ln_start,ln_end);
       gtBindValue(v_value_count) := l_str;
       l_str := null;
    End IF;
  End Loop;
  --
  If v_bind_count != v_value_count then
    Raise BindLabelMissing;
  End IF;
  --
  for i in 1..nvl(v_bind_count,0) loop
    If instr(v_sqltext,gtBindLabel(i)) > 0 then
        v_sqltext := replace(v_sqltext,gtBindLabel(i),gtBindValue(i));
    End if;
  end loop;
  v_sqltext := Replace(v_sqltext, '#CHILD_DRILL_DOWN_ID#', '#CHILD_DDNAME#');
  P_sqlstmnt := v_sqltext;
--
Exception
  When BindLabelMissing Then
    hr_utility.set_location('Exception BindLabelMissing kbdx_kube_dd_utilities.prepare_dd50_stmt',5);
    P_message := 'Bind Label was not found';
  When no_data_found Then
    hr_utility.set_location('Exception no_data_found kbdx_kube_dd_utilities.prepare_dd50_stmt',7);
    P_message := 'The SQL statment for this drill down was not found';
  When Others Then
    hr_utility.set_location('Exception Others kbdx_kube_dd_utilities.prepare_dd50_stmt',8);
    hr_utility.set_location(substr(sqlerrm,1,200),9);
    P_message := 'kbdx_kube_dd_utilities.prepare_dd50_stmt Exception '||substr(sqlerrm,1,200);
--
End Prepare_dd50_stmt;
--
Procedure RowTranslate(
        p_pair_elements        in       number,
        p_pair_string          in       varchar2,
        P_pair_lookup          Out      varchar2,
        P_return_code          Out      number,
        P_message              Out      varchar2)
Is
--
l_text	                varchar2(2000) := null;
l_start                 number(4) := 0;
l_length                number(4) := 0;
l_str                   varchar2(256);
l_pair_column	     	number(2) := 0;
l_index                 number(4) := 1;
Begin
  --
  gtHeaderRow.delete;
  gtDetailRow.delete;

  P_pair_lookup := null;
  P_return_code := 0;
  P_message     := null;
  --
  -- Split pairs into arrays   example: Data|VARCHAR|data|NUMBER
  For i in 1..p_pair_elements Loop

    l_start := l_length + l_start + 1;
    l_length := instr(p_pair_string || '|','|',1,i) - l_start;
    If l_length < 0 Then
        l_str :=  substr(p_pair_string,l_start);
    Else
        l_str := substr(p_pair_string,l_start,l_length);
    End IF;

    if l_pair_column = 0 then	-- 1st of pair
	    gtHeaderRow(l_index) := l_str;
        l_pair_column := 1;
    else                        -- 2nd of pair
        gtDetailRow(l_index) := l_str;
        l_pair_column := 0;
        l_index := l_index + 1;
    end if;

    l_str := null;

  end loop;

   --
  for i in 1..l_index -1  loop
      l_text := l_text
		|| '|'
		|| translate(P_translate_function => gtDetailRow(i),
						 P_column_value       => gtHeaderRow(i));
  end loop;

  P_pair_lookup := Substr (l_text,2); -- remove leading pipe

Exception
  When Others Then
    P_return_code := 1;
    P_message := 'kbdx_kube_dd_utilities.rowtranslate Exception '||substr(sqlerrm,1,200);
End RowTranslate;

Procedure RowInfo(
        P_Columns              in       number,
        p_kube_type_id         in       Number,
        P_process_id           in       number,
        p_HeaderRow            in       varchar2,
        p_DetailRow            in       varchar2,
        P_sqlstmnt             Out      Long,
        P_return_code          Out      number,
        P_message              Out      varchar2)
Is
Type dd_parse_data is Record (
BindName                kbdx_drill_down_binds.bind_name%Type,
ColumnName              kbdx_drill_down_binds.column_name%Type,
ColumnValue             varchar2(256),
TranslateFunction       kbdx_drill_down_binds.translate_function%Type,
HeaderRowExists         Boolean);

Type dd_parse_data_type Is Table of dd_parse_data Index By BINARY_INTEGER;

dd_parse_data_tbl dd_parse_data_type;

MissingHeaderColumn     Exception;
DDDoesNotExist          Exception;
DDsqlNotFound           Exception;

Cursor c_bind(c_drill_down_id   number) is
  select *
  from   kbdx_drill_down_binds
  where  drill_down_id = c_drill_down_id;
r_bind c_bind%rowtype;

Cursor c_ddid(c_drill_down_type     varchar2,c_drill_down_source    varchar2) is
  select /*+ RULE */ dd.drill_down_id
  from   kbdx_drill_downs dd,
         kbdx_datasets d,
         kbdx_kube_types t
  where  dd.drill_down_type = c_drill_down_type
  and    dd.drill_down_source = c_drill_down_source
  and    dd.dataset_id = d.dataset_id
  and    d.process_type = t.kube_type
  and    t.kube_type_id = P_kube_type_id;
--
Cursor c_ddid_ns(c_drill_down_type     varchar2) is
  select /*+ RULE */ dd.drill_down_id
  from   kbdx_drill_downs dd,
         kbdx_datasets d,
         kbdx_kube_types t
  where  dd.drill_down_type = c_drill_down_type
  and    dd.dataset_id = d.dataset_id
  and    d.process_type = t.kube_type
  and    t.kube_type_id = P_kube_type_id;
--
Cursor c_ddidc_ns(c_drill_down_id      number,
               c_drill_down_type    varchar2) is
  select drill_down_id
  from   kbdx_drill_downs dd
  where  dd.drill_down_type = c_drill_down_type
  and    dd.drill_down_id   = c_drill_down_id;
--
Cursor c_ddidc(c_drill_down_id      number,
               c_drill_down_type    varchar2,
               c_drill_down_source  varchar2) is
  select drill_down_id
  from   kbdx_drill_downs dd
  where  dd.drill_down_type     = c_drill_down_type
  and    dd.drill_down_id       = c_drill_down_id
  and    dd.drill_down_source   = c_drill_down_source;
--
l_ddid                  number := 0;
l_ddsql_id              number;
l_dd_exists             number;
l_sqltext               long;
l_test                  varchar2(2000);
indx                    number;
l_child_drill_down_id   number;
l_source                varchar2(100) := null;
ln_start                number := 0;
ln_end                  number := 0;
l_str                   varchar2(500) := null;
l_sep varchar2(1) := '|';

Begin
  --
  -- hr_utility.trace_on('','ff');
  hr_utility.set_location('Begin kbx_drill_down.rowinfo',10);
  --
  g_process_id  := P_process_id;
  gtHeaderRow.delete;
  gtDetailRow.delete;
  P_return_code := 0;
  P_message     := null;
  l_ddid        := 0;
  l_dd_exists   := 0;
  indx := 0;
  --
  -- Populate the Header into the array

  ln_end := instr(p_HeaderRow,'|');
  If ln_end = 0 Then
    l_sep := ',';
  Else l_sep := '|';
  End If;

  ln_start := 0; ln_end := 0; l_str := null;

  For i in 1..p_columns Loop
    ln_start := ln_end + ln_start + 1;
    ln_end := instr(p_HeaderRow,l_sep,1,i) - ln_start;
    If ln_end < 0 Then
        l_str :=  substr(p_HeaderRow,ln_start);
        gtHeaderRow(i) := l_str;
        l_str := null;
    Else
       hr_utility.set_location('String : start '||ln_start||' end '||ln_end,85);
       l_str := substr(p_HeaderRow,ln_start,ln_end);
       hr_utility.set_location('SUBSTR : '||l_str,75);
        gtHeaderRow(i) := l_str;
        l_str := null;
    End IF;
  End Loop;
  --
  -- Populate the Detail Row into the array
  ln_start := 0; ln_end := 0; l_str := null;
  For i in 1..p_columns Loop
    ln_start := ln_end + ln_start + 1;
    ln_end := instr(p_DetailRow,l_sep,1,i) - ln_start;
    If ln_end < 0 Then
        l_str := substr(p_DetailRow,ln_start);
        gtDetailRow(i) := l_str;
        l_str := null;
    Else
        l_str :=  substr(p_DetailRow,ln_start,ln_end);
        gtDetailRow(i) := l_str;
        l_str := null;
    End If;
  End Loop;
  --
  --
  -- Check for column of DDID
  for i in 1..nvl(gtHeaderRow.count,0) loop
    if gtHeaderRow(i) = 'DDID' then
       l_ddid := to_number(gtDetailRow(i));
       select count(*)
       into l_dd_exists
       from kbdx_drill_downs
       where drill_down_id = l_ddid;
       if l_dd_exists = 0 then
         raise DDDoesNotExist;
       End if;
     end if;
     if gtHeaderRow(i) = 'SOURCE' then
        l_source := gtDetailRow(i);
     else
        l_source := null;
     end if;
  end loop;
  --
  if l_ddid = 0 and l_source is not null Then
    hr_utility.set_location('kbx_drill_down.rowinfo',20);
    open c_ddid('PARENT',l_source);
    fetch c_ddid into l_ddid;
    if  c_ddid%notfound then
          hr_utility.set_location('kbx_drill_down.rowinfo',25);
      raise DDsqlNotFound;
    End if;
    hr_utility.set_location('kbx_drill_down.rowinfo',30);
  elsif l_ddid <> 0 and l_source is not null then
    open c_ddidc(l_ddid,'CHILD',l_source);
    fetch c_ddidc into l_ddid;
    if  c_ddidc%notfound then
      raise DDsqlNotFound;
    End if;
    hr_utility.set_location('kbx_drill_down.rowinfo',31);
  elsif l_ddid = 0 and l_source is null then
    hr_utility.set_location('kbx_drill_down.rowinfo',32);
    open c_ddid_ns('PARENT');
    fetch c_ddid_ns into l_ddid;
    if c_ddid_ns%notfound then
      raise DDsqlNotfound;
    end if;
    hr_utility.set_location('kbx_drill_down.rowinfo',32);
  elsif l_ddid <> 0 and l_source is null then
    open c_ddidc_ns(l_ddid,'CHILD');
    fetch c_ddidc_ns into l_ddid;
    if  c_ddidc_ns%notfound then
      raise DDsqlNotFound;
    End if;
    hr_utility.set_location('kbx_drill_down.rowinfo',33);
  End if;

  open c_bind(l_ddid);
  loop
    fetch c_bind into r_bind;
    exit when c_bind%notfound;
    hr_utility.set_location('kbx_drill_down.rowinfo',35);
    indx := indx + 1;
    dd_parse_data_tbl(indx).ColumnName := r_bind.column_name;
    dd_parse_data_tbl(indx).BindName := r_bind.bind_name;
    dd_parse_data_tbl(indx).TranslateFunction := r_bind.Translate_Function;
    dd_parse_data_tbl(indx).HeaderRowExists := FALSE;
    for i in 1..nvl(gtHeaderRow.count,0) loop
      if upper(replace(replace(gtHeaderRow(i),' ',''),'_','')) = upper(replace(replace(r_bind.column_name,' ',''),'_','')) then
           dd_parse_data_tbl(indx).ColumnValue := gtDetailRow(i);
           dd_parse_data_tbl(indx).HeaderRowExists := TRUE;
      End if;
    end loop;
  end loop;
  close c_bind;
  --
  for i in 1..nvl(dd_parse_data_tbl.count,0) loop
    if dd_parse_data_tbl(i).HeaderRowExists = FALSE then
       P_message := 'Column Name: '||dd_parse_data_tbl(i).ColumnName||' is Missing from Row 1 of the worksheet';
       raise MissingHeaderColumn;
    End If;
  End loop;
  --
 select c.cursor_text, dd.child_drill_down_id
  into   l_sqltext, l_child_drill_down_id
  from   kbdx_cursors c,kbdx_drill_downs dd
  where  dd.drill_down_id = l_ddid
  and    dd.cursor_id = c.cursor_id;

  hr_utility.set_location('kbx_drill_down.rowinfo',40);
  --
  l_sqltext := replace(l_sqltext,'#PROCESS_ID#',P_Process_id);
  hr_utility.set_location('kbx_drill_down.rowinfo',45);

  l_sqltext := replace(l_sqltext,'#CHILD_DRILL_DOWN_ID#',nvl(l_child_drill_down_id,-1));
  hr_utility.set_location('kbx_drill_down.rowinfo',50);
  --
  for i in 1..nvl(dd_parse_data_tbl.count,0) loop
  hr_utility.set_location('kbx_drill_down.rowinfo',53);
  l_sqltext := replace(l_sqltext,dd_parse_data_tbl(i).BindName,
                       translate(P_translate_function => dd_parse_data_tbl(i).TranslateFunction,
                                                 P_column_value       => dd_parse_data_tbl(i).ColumnValue));
  hr_utility.set_location('kbx_drill_down.rowinfo',55);
  end loop;

  hr_utility.set_location('kbx_drill_down.rowinfo',60);

  P_sqlstmnt := l_sqltext;

  hr_utility.set_location('Leaving kbx_drill_down.rowinfo',90);

Exception
  When MissingHeaderColumn Then
    hr_utility.set_location('Exception MissingHeaderColumn kbx_drill_down.rowinfo',80);
    P_sqlstmnt    := 'Not all Column Headings Exist For Drill Down';
    P_return_code := 1;
  When DDDoesNotExist Then
    hr_utility.set_location('Exception DDDoesNotExist kbdx_drill_down.rowinfo',81);
    P_message := 'Drill Down Does Not Exist for this Sheet';
    P_return_code := 1;
  When DDsqlNotFound Then
    hr_utility.set_location('Exception DDsqlNotFound kbdx_dirll_down.rowinfo',82);
    P_message := 'The SQL statment for this drill down was not found';
    P_return_code := 1;
  When no_data_found Then
    hr_utility.set_location('Exception no_data_found kbdx_drill_down.rowinfo',83);
    P_message := 'No data was found for the selected drill down, re-check your selection sheet and row';
    P_return_code := 1;
  When Others Then
    hr_utility.set_location('Exception Others kbx_drill_down.rowinfo',84);
    hr_utility.set_location(substr(sqlerrm,1,200),85);
    P_return_code := 1;
    P_message := 'kbdx_drill_down.rowinfo Exception '||substr(sqlerrm,1,200);

    --P_message := 'P_Columns: ' || to_number(P_Columns) || ' p_kube_type_id: ' || to_number(p_kube_type_id)||' P_process_id: ' || to_number(P_process_id);
    --P_message := 'p_HeaderRow: ' || p_HeaderRow || ' p_DetailRow: ' || p_DetailRow;

End RowInfo;
--
-- -------------------------------------------------------------------------------------------
-- Function Translate
--
-- This function is used to translate various named values into id values or visa versa
-- -------------------------------------------------------------------------------------------
Function Translate(
        P_translate_function    in      varchar2,
        P_column_value          in      varchar2)
  return varchar2 is

 l_tmp_id        number;
 l_tmp_ch        varchar2(60);
 l_tmp_ch1       varchar2(60);
 l_empty         Varchar2(10);
Begin
  If P_translate_function = 'NUMBER' then
       -- No Translation just return
     return P_column_value;
  Elsif  P_translate_function = 'TUNAME2TUID' Then
      -- Return the Tax Unid ID
    select tax_unit_id
      into   l_tmp_id
      from   hr_tax_units_v
     where  replace(name,'''') = replace(P_column_value,'''')
       and business_group_id = fnd_profile.value('PER_BUSINESS_GROUP_ID');
    return to_char(l_tmp_id);
  Elsif P_translate_function = 'BGNAME2BGID' Then
      -- Return the Business Group ID
    select business_group_id
      into   l_tmp_id
      from   per_business_groups
     where  replace(name,'''') = replace(P_column_value,'''');
       -- and date_to is Null;
     return to_char(l_tmp_id);
  Elsif P_translate_function = 'ORGNAME2ORGID' Then
     -- Return the Business Group ID
    select organization_id
      into l_tmp_id
      from hr_all_organization_units
    where  replace(name,'''') = replace(P_column_value,'''')
       -- and date_to is Null
     and business_group_id = fnd_profile.value('PER_BUSINESS_GROUP_ID');
     return to_char(l_tmp_id);
  Elsif P_translate_function = 'VARCHAR2' Then
       -- Return the column value
    return replace(P_column_value,'''');
  Elsif P_translate_function = 'PYNAME2PYID' Then
    select payroll_id
      into   l_tmp_id
      from   pay_payrolls_f
     where  replace(payroll_name,'''') = replace(P_column_value,'''')
       and business_group_id = fnd_profile.value('PER_BUSINESS_GROUP_ID')
       and    rownum < 2;
    return to_char(l_tmp_id);
  Elsif P_translate_function = 'JURISDICTION_CODE' then
    if P_column_value is null
     or upper(P_column_value) = 'FEDERAL' then
      return 'FEDERAL';
    else
      return P_column_value;
    end if;
  Elsif P_translate_function = 'TAX_TYPE_EE_ER' then
    if instr(upper(P_column_value),'EE') > 0 then
      return 'EE';
    else
      return 'ER';
    end if;
  Elsif P_translate_function = 'TAX_TYPE_WO_EE_ER' then
    return rtrim(replace(replace(upper(P_column_value),'EE',null),'ER',null));
  ElsIf P_translate_function = 'BT_HR_ID' then
    if P_column_value is null Then
      select ''''''
        into l_empty
        from dual;
      return l_empty;
    else
      return P_column_value;
    end If;
  ElsIf P_translate_function = 'BALANCE_TYPE_ID' then
    select balance_type_id
      into l_tmp_id
      from pay_balance_types
     where replace(balance_name,'''') = replace(P_column_value,'''')
       and nvl(business_group_id,fnd_profile.value('PER_BUSINESS_GROUP_ID')) = fnd_profile.value('PER_BUSINESS_GROUP_ID')
       and rownum < 2;
     return l_tmp_id;
  ElsIf P_translate_function = 'NULL_JD_CODE' then
    if P_column_value is Null Then
      return '~';
    else
      return P_column_value ;
    end If;
  ElsIf P_translate_function = 'LOCCODE2LOCID' then
    select location_id
      into l_tmp_id
      from hr_locations
     where replace(location_code,'''') = replace(P_column_value,'''')
       and nvl(business_group_id,fnd_profile.value('PER_BUSINESS_GROUP_ID')) = fnd_profile.value('PER_BUSINESS_GROUP_ID')
       and rownum < 2;
    return l_tmp_id;
  Elsif P_translate_function = 'CONSOLNAME2ID' Then
      -- Return the Consolidation Set ID
    select consolidation_set_id
      into l_tmp_id
      from pay_consolidation_sets
     where replace(consolidation_set_name,'''') = replace(P_column_value,'''');
    return to_char(l_tmp_id);
  End If;
  return null;
End Translate;
  -- -------------------------------------------------------------------------------------------
  -- Procedure k255Translate translates various named values stored in the global temporary table
  --  kbdx_kube_binds k255 into id values or visa versa. Originally had 255 varchar2 now has
  --  columns 1-30 as varchar2 and 31-60 as number.
  -- -------------------------------------------------------------------------------------------
Procedure k255Translate(
        P_translate_function    in      varchar2,
        P_column_number         in      number,
        P_msg                   out     varchar2)
 is
 l_cnumber1  varchar2(3);
 l_cnumber31 varchar2(3);
 l_sql		varchar2(2000)  := null;
 l_sql2		varchar2(2000)  := null;
 l_sql3		varchar2(2000)  := null;
 ColumnNumberTooLarge     Exception;
Begin
  P_msg := null;
  If P_column_number > 30 then
    raise ColumnNumberTooLarge;
  Else
    l_cnumber1  := to_char(P_column_number);
    l_cnumber31 := to_char(P_column_number + 30);
  End If;
  l_sql3 := 'update kbdx_kube_binds k255'
         || ' set k255.c'||l_cnumber31||' = '
         || ' to_number(k255.c'||l_cnumber1||')';
  If P_translate_function = 'NUMBER' then
        -- No Translation
    NULL;
  Elsif P_translate_function = 'TUNAME2TUID' Then
        -- Return the Tax Unid ID
    l_sql := 'update kbdx_kube_binds k255'
         || ' set k255.c'||l_cnumber1||' = ('
         || ' select h.tax_unit_id'
         || ' from hr_tax_units_v h'
         || ' where replace(h.name,'''''''') = replace(k255.c'||l_cnumber1||','''''''')'
         || ' and h.business_group_id = fnd_profile.value(''PER_BUSINESS_GROUP_ID''))';
  Elsif P_translate_function = 'BGNAME2BGID' Then
        -- Return the Business Group ID
    l_sql := 'update kbdx_kube_binds k255'
          || ' set k255.c'||l_cnumber1||' = ('
          || ' select p.business_group_id'
          || ' from per_business_groups p'
          || ' where replace(p.name,'''''''') = replace(k255.c'||l_cnumber1||',''''''''))';
  Elsif P_translate_function = 'ORGNAME2ORGID' Then
        -- Return the Business Group ID
    l_sql := 'update kbdx_kube_binds k255'
          || ' set k255.c'||l_cnumber1||' = ('
          || ' select h.organization_id'
          || ' from hr_all_organization_units h'
          || ' where replace(h.name,'''''''') = replace(k255.c'||l_cnumber1||','''''''')'
          || ' and h.business_group_id = fnd_profile.value(''PER_BUSINESS_GROUP_ID''))';
  Elsif P_translate_function = 'VARCHAR2' Then
    l_sql := 'update kbdx_kube_binds k255'
          || ' set k255.c'||l_cnumber1||' = replace(k255.c'||l_cnumber1||','''''''')';
    l_sql3 := NULL;
  Elsif P_translate_function = 'PYNAME2PYID' Then
    l_sql := 'update kbdx_kube_binds k255'
          || ' set k255.c'||l_cnumber1||' = ('
          || ' select p.payroll_id'
          || ' from pay_payrolls_f p'
          || ' where replace(p.payroll_name,'''''''') = replace(k255.c'||l_cnumber1||','''''''')'
          || ' and p.business_group_id = fnd_profile.value(''PER_BUSINESS_GROUP_ID'')'
          || ' and rownum < 2)';
  Elsif P_translate_function = 'JURISDICTION_CODE' then
    l_sql := 'update kbdx_kube_binds k255'
          || ' set k255.c'||l_cnumber1||' = ''FEDERAL'''
          || ' where upper(k255.c'||l_cnumber1||') = ''FEDERAL'' or k255.c'||l_cnumber1||' is null';
        l_sql3 := NULL;
  Elsif P_translate_function = 'TAX_TYPE_EE_ER' then
    l_sql := 'update kbdx_kube_binds k255'
          || ' set k255.c'||l_cnumber1||' = ''EE'''
          || ' where instr(upper(k255.c'||l_cnumber1||'),''EE'') > 0';
    l_sql2 := 'update kbdx_kube_binds k255'
          || ' set k255.c'||l_cnumber1||' = ''ER'''
          || ' where instr(upper(k255.c'||l_cnumber1||'),''EE'') = 0';
    l_sql3 := NULL;
  Elsif P_translate_function = 'TAX_TYPE_WO_EE_ER' then
    l_sql := 'update kbdx_kube_binds k255'
          || ' set k255.c'||l_cnumber1||' = rtrim(replace(replace(upper(k255.c'||l_cnumber1||'),''EE'',null),''ER'',null))';
    l_sql3 := NULL;
  ElsIf P_translate_function = 'BT_HR_ID' then
      -- No Translation {recheck this}
    NULL;
  ElsIf P_translate_function = 'BALANCE_TYPE_ID' then
    l_sql := 'update kbdx_kube_binds k255'
          || ' set k255.c'||l_cnumber1||' = ('
          || ' select p.balance_type_id'
          || ' from pay_balance_types p'
          || ' where replace(p.balance_name,'''''''') = replace('||'k255.c'||l_cnumber1||','''''''')'
          || ' and nvl(p.business_group_id,fnd_profile.value(''PER_BUSINESS_GROUP_ID'')) = fnd_profile.value(''PER_BUSINESS_GROUP_ID'')'
          || ' and rownum < 2)';
  ElsIf P_translate_function = 'NULL_JD_CODE' then
    l_sql := 'update kbdx_kube_binds k255'
          || ' set k255.c'||l_cnumber1||' = ''~'''
          || ' where k255.c'||l_cnumber1||' is null';
    l_sql3 := NULL;
  ElsIf P_translate_function = 'LOCCODE2LOCID' then
    l_sql := 'update kbdx_kube_binds k255'
          || ' set k255.c'||l_cnumber1||' = ('
          || ' select h.location_id'
          || ' from hr_locations h'
          || ' where replace(h.location_code,'''''''') = replace('||'k255.c'||l_cnumber1||','''''''')'
          || ' and nvl(h.business_group_id,fnd_profile.value(''PER_BUSINESS_GROUP_ID'')) = fnd_profile.value(''PER_BUSINESS_GROUP_ID'')'
          || ' and rownum < 2)';
  Elsif P_translate_function = 'CONSOLNAME2ID' Then
      -- Return the Consolidation Set ID
    l_sql := 'update kbdx_kube_binds k255'
          || ' set k255.c'||l_cnumber1||' = ('
          || ' select p.consolidation_set_id'
          || ' from pay_consolidation_sets p'
          || ' where replace(p.consolidation_set_name,'''''''') = replace(k255.c'||l_cnumber1||',''''''''))';
  End If;
  If length(l_sql) > 0 then
    execute immediate l_sql;
  End If;
  If length(l_sql2) > 0 then
    execute immediate l_sql2;
  End If;
  If length(l_sql3) > 0 then
    execute immediate l_sql3;
  End If;
Exception
  When ColumnNumberTooLarge Then
    P_msg    := 'kbdx_kube_binds has 30 varchar2 columns. Requested '||to_char(P_column_number);
  When Others Then
    P_msg    := 'kbdx_kube_dd_utilities.k255Translate: '||P_translate_function||' Exception '||substr(sqlerrm,1,200);
End k255Translate;
-- -------------------------------------------------------------------------------------------
-- See Procedure k255Translation for description - this small proc indicates that
--  k255Translation with the P_last_call parameter is available {was added later}
-- -------------------------------------------------------------------------------------------
Procedure k255Translation(
        P_msg                   out     varchar2)
 is
Begin
--
        P_msg := '0';
--
End k255Translation;
-- -------------------------------------------------------------------------------------------
-- See Procedure k255Translation for description - 'last_call' string must be > 1 character to
--  invoke last_call translation function
-- -------------------------------------------------------------------------------------------
Procedure k255Translation(
        P_translate_map         in      varchar2,
        P_row_data0             in      varchar2,
        P_row_data1             in      varchar2,
        P_row_data2             in      varchar2,
        P_row_data3             in      varchar2,
        P_row_data4             in      varchar2,
        P_row_data5             in      varchar2,
        P_row_data6             in      varchar2,
        P_msg                   out     varchar2)
 is
Begin
--
    kbdx_kube_dd_utilities.k255Translation(
        P_translate_map,
        P_row_data0,
        P_row_data1,
        P_row_data2,
        P_row_data3,
        P_row_data4,
        P_row_data5,
        P_row_data6,
        'last_call',
        P_msg);
--
End k255Translation;
-- -------------------------------------------------------------------------------------------
-- Procedure k255Translation recieves a pipe delimited map of the global temporary table
--  kbdx_kube_binds k255 (fc1|fc2|fc3...) and performs the function on associated column.
--  P_row_data0 is a pipe delimited set of (set of column data strings) rows.
--  Caller sends '|' when a P_row_dataX parameter is empty.
--  length(P_last_call) > 0 on last call to envoke call to k255Translate
-- -------------------------------------------------------------------------------------------
Procedure k255Translation(
        P_translate_map         in      varchar2,
        P_row_data0             in      varchar2,
        P_row_data1             in      varchar2,
        P_row_data2             in      varchar2,
        P_row_data3             in      varchar2,
        P_row_data4             in      varchar2,
        P_row_data5             in      varchar2,
        P_row_data6             in      varchar2,
        P_last_call             in      varchar2,
        P_msg                   out     varchar2)
 is
l_row_dataX       number := 0;
ln_start          number := 0;
ln_end            number := 0;
l_str             varchar2(1000)  := NULL;
column_count      number :=0;
v_count           number :=0;
row_column_count  number :=0;
row_count         number :=0;
strInsert         varchar2(1000)  := NULL;
strValues         varchar2(4096)  := NULL;
bnExit            boolean;
lSQL              varchar2(32767) := NULL;
TranslateError    Exception;
Begin
--
    If length(P_translate_map) = 0 then
        return;
    End If;
    gtBindLabel.delete;
    ln_start := 0; ln_end := 0; l_str := NULL; column_count := 0;
    Loop
    	column_count := column_count + 1;
    	ln_start := ln_end + ln_start + 1;
    	ln_end := instr(P_translate_map,'|',1,column_count) - ln_start;
    	If ln_end < 0 Then
    	    l_str :=  substr(P_translate_map,ln_start);
    	    gtBindLabel(column_count) := l_str;
    	    l_str := NULL;
    	    Exit;
    	Else
    	    l_str := substr(P_translate_map,ln_start,ln_end);
    	    gtBindLabel(column_count) := l_str;
    	    l_str := NULL;
    	End If;
    End Loop;
        --ignore trailing pipe
    If gtBindLabel(column_count) IS NULL then
        column_count := column_count - 1;
    End If;
--
    For i in 1..column_count Loop
        if i > 1 Then
            l_str := l_str||',c'||to_char(i);
        Else
            l_str := 'c'||to_char(i);
        End If;
    End Loop;
    strInsert := 'insert into kbdx_kube_binds k255 ('||l_str||') values (';
--
    Loop
        If l_row_dataX = 0 then
            lSQL := P_row_data0;
        ElsIf  l_row_dataX = 1 then
            lSQL := P_row_data1;
        ElsIf  l_row_dataX = 2 then
            lSQL := P_row_data2;
        ElsIf  l_row_dataX = 3 then
            lSQL := P_row_data3;
        ElsIf  l_row_dataX = 4 then
            lSQL := P_row_data4;
        ElsIf  l_row_dataX = 5 then
            lSQL := P_row_data5;
        ElsIf  l_row_dataX = 6 then
            lSQL := P_row_data6;
        Else
            lSQL := '|'; --single character is sent to indicates parameter is empty
        End If;
        Exit When length(lSQL) <= 2; --two characters say skip translation
        ln_start := 0; ln_end := 0; l_str := NULL; v_count := 0; bnExit := false; row_count := 0; row_column_count := 0;
        Loop
        	v_count := v_count + 1; row_column_count := row_column_count + 1;
    	    ln_start := ln_end + ln_start + 1;
        	ln_end := instr(lSQL,'|',1,v_count) - ln_start;
        	If ln_end < 0 Then
        	    l_str :=  substr(lSQL,ln_start);
        	    bnExit := true;
        	Else
        	    l_str := substr(lSQL,ln_start,ln_end);
        	End If;
            if row_column_count > 1 Then
                strValues := strValues||','''||l_str||'''';
            Else
                strValues := ''''||l_str||'''';
            End If;
            If row_column_count = column_count Then
                row_count := row_count + 1;
                execute immediate strInsert||strValues||')';
                row_column_count := 0;
            End If;
            If bnExit Then
                EXIT;
            End If;
            l_str := NULL;
        End Loop;
        strValues := NULL; lSQL := NULL;
        l_row_dataX := l_row_dataX + 1;
    End Loop;
      --if two characters then skip translation allowing multiple calls
    If length(P_last_call) > 1 THEN
        For i in 1..column_count Loop
      	    kbdx_kube_dd_utilities.k255translate(gtBindLabel(i),i,l_str);
    	    If length(l_str) > 0 Then
    	        RAISE TranslateError;
        	End If;
        End Loop;
    End If;
--
Exception
  When TranslateError Then
    P_msg    := l_str;
   When Others Then
    P_msg    := 'kbdx_kube_dd_utilities.k255Translation: Row Count = '||to_char(row_count)||' Exception '||substr(sqlerrm,1,200);
End k255Translation;
-- -------------------------------------------------------------------------------------------
-- Procedure FetchStandardCursor receives a request from C402kbxDrillDown.xla for the
--  cursor and bind set so that it can perform a table based bind operation.
-- -------------------------------------------------------------------------------------------
Procedure FetchStandardCursor(
        P_ddid                 in       Number,
        P_kube_type_id         in       Number,
        P_process_id           in       Number,
        P_bindset              Out      varchar2,
        P_sqlstmnt             Out      long,
        P_msg                  Out      varchar2)
Is
--
DDDoesNotExist          Exception;
DDsqlNotFound           Exception;
--
Cursor c_bind(c_drill_down_id   number) is
  select *
  from   kbdx_drill_down_binds
  where  drill_down_id = c_drill_down_id;
 r_bind c_bind%rowtype;
--
Cursor c_ddid(c_drill_down_type     varchar2,c_drill_down_source    varchar2) is
  select /*+ RULE */ dd.drill_down_id
  from   kbdx_drill_downs dd,
         kbdx_datasets d,
         kbdx_kube_types t
  where  dd.drill_down_type = c_drill_down_type
  and    dd.drill_down_source = c_drill_down_source
  and    dd.dataset_id = d.dataset_id
  and    d.process_type = t.kube_type
  and    t.kube_type_id = P_kube_type_id;
--
Cursor c_ddid_ns(c_drill_down_type     varchar2) is
  select /*+ RULE */ dd.drill_down_id
  from   kbdx_drill_downs dd,
         kbdx_datasets d,
         kbdx_kube_types t
  where  dd.drill_down_type = c_drill_down_type
  and    dd.dataset_id = d.dataset_id
  and    d.process_type = t.kube_type
  and    t.kube_type_id = P_kube_type_id;
--
Cursor c_ddidc_ns(c_drill_down_id      number,
               c_drill_down_type    varchar2) is
  select drill_down_id
  from   kbdx_drill_downs dd
  where  dd.drill_down_type = c_drill_down_type
  and    dd.drill_down_id   = c_drill_down_id;
--
Cursor c_ddidc(c_drill_down_id      number,
               c_drill_down_type    varchar2,
               c_drill_down_source  varchar2) is
  select drill_down_id
  from   kbdx_drill_downs dd
  where  dd.drill_down_type     = c_drill_down_type
  and    dd.drill_down_id       = c_drill_down_id
  and    dd.drill_down_source   = c_drill_down_source;
--
l_sqltext               long;
l_child_drill_down_id   number;
l_ddid                  number := 0;
--
Begin
  --
  P_msg         := null;
  P_bindset     := null;
  l_ddid        := p_ddid;
  --
  if l_ddid = 0 then
    open c_ddid_ns('PARENT');
    fetch c_ddid_ns into l_ddid;
    if c_ddid_ns%notfound then
      raise DDsqlNotfound;
    end if;
  else
    open c_ddidc_ns(l_ddid,'CHILD');
    fetch c_ddidc_ns into l_ddid;
    if  c_ddidc_ns%notfound then
      raise DDsqlNotFound;
    End if;
  End if;
  --
  open c_bind(l_ddid);
  loop
    fetch c_bind into r_bind;
    exit when c_bind%notfound;
    P_bindset := P_bindset||'|'||r_bind.bind_name||'|'||r_bind.column_name||'|'||r_bind.Translate_Function;
  end loop;
  close c_bind;
  --
  P_bindset := Substr (P_bindset,2); -- remove leading pipe

 select c.cursor_text, dd.child_drill_down_id
  into   l_sqltext, l_child_drill_down_id
  from   kbdx_cursors c,kbdx_drill_downs dd
  where  dd.drill_down_id = l_ddid
  and    dd.cursor_id = c.cursor_id;
  --
  If instr(l_sqltext,'#PROCESS_ID#') > 0 then
    l_sqltext := replace(l_sqltext,'#PROCESS_ID#',P_Process_id);
  End If;
  If instr(l_sqltext,'#CHILD_DDNAME#') > 0 then
    l_sqltext := replace(l_sqltext,'#CHILD_DDNAME#',nvl(l_child_drill_down_id,-1));
  End If;
  If instr(l_sqltext,'#CHILD_DRILL_DOWN_ID#') > 0 then
    l_sqltext := replace(l_sqltext,'#CHILD_DRILL_DOWN_ID#',nvl(l_child_drill_down_id,-1));
  End If;
  P_sqlstmnt := l_sqltext;
  --
Exception
  When DDDoesNotExist Then
    P_msg := 'Drill Down Does Not Exist for this Sheet';
  When DDsqlNotFound Then
    P_msg := 'The SQL statment for this drill down was not found';
  When no_data_found Then
    P_msg := 'No data was found for the selected drill down, re-check your selection sheet and row';
  When Others Then
    P_msg := 'kbdx_kube_dd_utilities.FetchStandardCursor Exception '||substr(sqlerrm,1,200);
End FetchStandardCursor;

End KBDX_KUBE_DD_UTILITIES;
/
show errors;
/