create or replace PACKAGE BODY TT_PR_RECON_REPORT AS






 /************************************************************************************
        Program Name:    TT_PR_RECON_REPORT

        Description:   

        Developed by : 
        Date         :  

       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
    RXNETHI(ARGANO)            1.0      30-JUN-2023      R12.2 Upgrade Remediation
    ****************************************************************************************/







/************************************************************************************/
/*                                   IS_NUMBER                                      */
/************************************************************************************/
    FUNCTION is_number(p_value IN VARCHAR2) RETURN VARCHAR2 IS

    p_is_num VARCHAR2(10):= NULL;
    l_number NUMBER := NULL;

    BEGIN
      -- set global module name for error handling

    --  g_module_name := 'is_number';

      l_number := to_number(nvl(p_value,'0'));

      p_is_num := 'TRUE';
      RETURN p_is_num;

    EXCEPTION
             WHEN INVALID_NUMBER THEN
			          p_is_num := 'FALSE';
                RETURN p_is_num;

             WHEN VALUE_ERROR THEN
			          p_is_num := 'FALSE';
                RETURN p_is_num;

             WHEN OTHERS THEN
			         -- g_error_message := SQLERRM;
                RAISE;

    END;

/************************************************************************************/
/*                                   paydata_summary                                     */
/************************************************************************************/
PROCEDURE paydata_summary(errcode varchar2, errbuff varchar2,
                          p_batch_name IN varchar2, p_batch_date IN date) IS

v_errmsg					  varchar2(200);

v_batch_counter               number := 0;
v_batch_id                    number;

l_emp_number                  varchar2(50);
l_value_1                     number := 0;
l_value_2                     number := 0;
l_value_3                     number := 0;
l_value_4                     number := 0;
l_value_5                     number := 0;
v_subcount					  number := 0;

/* Get all the employees for the current business Group*/
Cursor c_batch_header is
	select distinct a.batch_id, a.batch_name,
	       e.meaning head_status, loc.location_code, loc.location_id
	/*
	START R12.2 Upgrade Remediation
	code commented by RXNETHI-ARGANO,30/06/23
	from hr.pay_batch_headers a,
         hr.pay_batch_lines b,
	     hr.per_all_assignments_f c,
		 hr.hr_locations_all loc,
		 */
	--code added by RXNETHI-ARGANO,30/06/23
	from apps.pay_batch_headers a,
         apps.pay_batch_lines b,
	     apps.per_all_assignments_f c,
		 apps.hr_locations_all loc,
	--END R12.2 Upgrade Remediation
	     apps.fnd_common_lookups e
	where rtrim(a.batch_name) = nvl(p_batch_name,a.batch_name)
	and a.batch_id = b.batch_id
	and b.assignment_number = c.assignment_number
	and c.primary_flag = 'Y'
	and c.location_id = loc.location_id (+)
	AND    c.effective_start_date = (Select max(a1.effective_start_date)
       --from hr.per_all_assignments_f a1  --code commented by RXNETHI-ARGANO,30/06/23
       from apps.per_all_assignments_f a1  --code added by RXNETHI-ARGANO,30/06/23
       where a1.assignment_number = b.assignment_number)
	and a.batch_Status = e.lookup_code
	and e.lookup_type = 'BATCH_STATUS'
	and trunc(a.creation_Date) = nvl(p_batch_date,trunc(a.creation_Date));

Cursor c_batch_line (p_batch_id number, p_location_id number) is
	select d.employee_number,d.full_name,
	 	   b.assignment_id,
		   b.element_name,
		   b.effective_date,
--		   b.value_1,b.value_2
           /*
		   START R12.2 Upgrade Remediation
		   code commented by RXNETHI-ARGANO,30/06/23
		   DECODE(cust.TT_PR_RECON_REPORT.is_number(b.value_1), 'TRUE'
               ,to_char(to_number(b.value_1),'99999999.99'), b.value_1)	d_value_1,
           DECODE(cust.TT_PR_RECON_REPORT.is_number(b.value_2), 'TRUE'
               ,to_char(to_number(b.value_2),'99999999.99'), b.value_2)	d_value_2,
           DECODE(cust.TT_PR_RECON_REPORT.is_number(b.value_3), 'TRUE'
               ,to_char(to_number(b.value_3),'99999999.99'), b.value_3)	d_value_3,
           DECODE(cust.TT_PR_RECON_REPORT.is_number(b.value_4), 'TRUE'
               ,to_char(to_number(b.value_4),'99999999.99'), b.value_4)	d_value_4,
           DECODE(cust.TT_PR_RECON_REPORT.is_number(b.value_5), 'TRUE'
               ,to_char(to_number(b.value_5),'99999999.99'), b.value_5)	d_value_5,
           DECODE(cust.TT_PR_RECON_REPORT.is_number(b.value_1), 'TRUE'
               ,to_number(b.value_1), 0)	value_1,
           DECODE(cust.TT_PR_RECON_REPORT.is_number(b.value_2), 'TRUE'
               ,to_number(b.value_2), 0)	value_2,
           DECODE(cust.TT_PR_RECON_REPORT.is_number(b.value_3), 'TRUE'
               ,to_number(b.value_3), 0)	value_3,
           DECODE(cust.TT_PR_RECON_REPORT.is_number(b.value_4), 'TRUE'
               ,to_number(b.value_4), 0)	value_4,
           DECODE(cust.TT_PR_RECON_REPORT.is_number(b.value_5), 'TRUE'
               ,to_number(b.value_5), 0)	value_5
	from hr.pay_batch_lines b,
	     hr.per_all_assignments_f c, hr.per_all_people_f d
		 */
		  --code added by RXNETHI-ARGANO,30/06/23
		  DECODE(apps.TT_PR_RECON_REPORT.is_number(b.value_1), 'TRUE'
               ,to_char(to_number(b.value_1),'99999999.99'), b.value_1)	d_value_1,
           DECODE(apps.TT_PR_RECON_REPORT.is_number(b.value_2), 'TRUE'
               ,to_char(to_number(b.value_2),'99999999.99'), b.value_2)	d_value_2,
           DECODE(apps.TT_PR_RECON_REPORT.is_number(b.value_3), 'TRUE'
               ,to_char(to_number(b.value_3),'99999999.99'), b.value_3)	d_value_3,
           DECODE(apps.TT_PR_RECON_REPORT.is_number(b.value_4), 'TRUE'
               ,to_char(to_number(b.value_4),'99999999.99'), b.value_4)	d_value_4,
           DECODE(apps.TT_PR_RECON_REPORT.is_number(b.value_5), 'TRUE'
               ,to_char(to_number(b.value_5),'99999999.99'), b.value_5)	d_value_5,
           DECODE(apps.TT_PR_RECON_REPORT.is_number(b.value_1), 'TRUE'
               ,to_number(b.value_1), 0)	value_1,
           DECODE(apps.TT_PR_RECON_REPORT.is_number(b.value_2), 'TRUE'
               ,to_number(b.value_2), 0)	value_2,
           DECODE(apps.TT_PR_RECON_REPORT.is_number(b.value_3), 'TRUE'
               ,to_number(b.value_3), 0)	value_3,
           DECODE(apps.TT_PR_RECON_REPORT.is_number(b.value_4), 'TRUE'
               ,to_number(b.value_4), 0)	value_4,
           DECODE(apps.TT_PR_RECON_REPORT.is_number(b.value_5), 'TRUE'
               ,to_number(b.value_5), 0)	value_5
	from apps.pay_batch_lines b,
	     apps.per_all_assignments_f c, apps.per_all_people_f d
		  --END R12.2 Upgrade Remediation
	where b.batch_id = p_batch_id
	and b.assignment_number = c.assignment_number
	and c.person_id = d.person_id
	and c.primary_flag = 'Y'
	and c.location_id = NVL(p_location_id,c.location_id)
    and c.effective_start_date = (Select max(a1.effective_start_date)
       --from hr.per_all_assignments_f a1   --code commented by RXNETHI-ARGANO,30/06/23
       from apps.per_all_assignments_f a1   --code added by RXNETHI-ARGANO,30/06/23
       where a1.assignment_number = b.assignment_number)
    and d.effective_start_date = (Select max(d1.effective_start_date)
       --from hr.per_all_people_f d1   --code commented by RXNETHI-ARGANO,30/06/23
       from apps.per_all_people_f d1   --code added by RXNETHI-ARGANO,30/06/23
       where d1.person_id = c.person_id)
	order by d.employee_number, d.full_name, b.element_name;

Cursor c_location_total (p_batch_id number, p_location_id number) is
	select element_name
--	, sum(NVL(value_1,0)) totalValue1
--	, sum(NVL(value_2,0)) totalValue2
    /*
	START R12.2 Upgrade Remediation
	code commented by RXNETHI-ARGANO,30/06/23
	,sum(DECODE(cust.TT_PR_RECON_REPORT.is_number(value_1), 'TRUE'
               ,to_number(value_1), 0)) totalValue1
    ,sum(DECODE(cust.TT_PR_RECON_REPORT.is_number(value_2), 'TRUE'
                ,to_number(value_2), 0)) totalValue2
    ,sum(DECODE(cust.TT_PR_RECON_REPORT.is_number(value_3), 'TRUE'
                ,to_number(value_3), 0)) totalValue3
    ,sum(DECODE(cust.TT_PR_RECON_REPORT.is_number(value_4), 'TRUE'
                ,to_number(value_4), 0)) totalValue4
    ,sum(DECODE(cust.TT_PR_RECON_REPORT.is_number(value_5), 'TRUE'
                ,to_number(value_5), 0)) totalValue5
	from hr.pay_batch_lines b,
	     hr.per_all_assignments_f c
	*/
	--code added by RXNETHI-ARGANO,30/006/23
	,sum(DECODE(apps.TT_PR_RECON_REPORT.is_number(value_1), 'TRUE'
               ,to_number(value_1), 0)) totalValue1
    ,sum(DECODE(apps.TT_PR_RECON_REPORT.is_number(value_2), 'TRUE'
                ,to_number(value_2), 0)) totalValue2
    ,sum(DECODE(apps.TT_PR_RECON_REPORT.is_number(value_3), 'TRUE'
                ,to_number(value_3), 0)) totalValue3
    ,sum(DECODE(apps.TT_PR_RECON_REPORT.is_number(value_4), 'TRUE'
                ,to_number(value_4), 0)) totalValue4
    ,sum(DECODE(apps.TT_PR_RECON_REPORT.is_number(value_5), 'TRUE'
                ,to_number(value_5), 0)) totalValue5
	from apps.pay_batch_lines b,
	     apps.per_all_assignments_f c
	--END R12.2 Upgrade Remediation
	where b.batch_id = p_batch_id
	and b.assignment_number = c.assignment_number
	and c.primary_flag = 'Y'
	and c.location_id = NVL(p_location_id,c.location_id)
    and c.effective_start_date = (Select max(a1.effective_start_date)
                                  --from hr.per_all_assignments_f a1  --code commented by RXNETHI-ARGANO,30/06/23
                                  from apps.per_all_assignments_f a1  --code added by RXNETHI-ARGANO,30/06/23
                                  where a1.assignment_number = b.assignment_number)
	group by element_name;

Cursor c_batch_total (p_batch_id number) is
	select element_name
--	, sum(NVL(value_1,0)) totalValue1
--	, sum(NVL(value_2,0)) totalValue2
    /*
	START R12.2 Upgrade Remediation
	code commented by RXNETHI-ARGANO,30/06/23
	,sum(DECODE(cust.TT_PR_RECON_REPORT.is_number(value_1), 'TRUE'
               ,to_number(value_1), 0)) totalValue1
    ,sum(DECODE(cust.TT_PR_RECON_REPORT.is_number(value_2), 'TRUE'
                ,to_number(value_2), 0)) totalValue2
    ,sum(DECODE(cust.TT_PR_RECON_REPORT.is_number(value_3), 'TRUE'
                ,to_number(value_3), 0)) totalValue3
    ,sum(DECODE(cust.TT_PR_RECON_REPORT.is_number(value_4), 'TRUE'
                ,to_number(value_4), 0)) totalValue4
    ,sum(DECODE(cust.TT_PR_RECON_REPORT.is_number(value_5), 'TRUE'
                ,to_number(value_5), 0)) totalValue5
	from hr.pay_batch_lines
	*/
	--code added by RXNETHI-ARGANO,30/06/23
	,sum(DECODE(apps.TT_PR_RECON_REPORT.is_number(value_1), 'TRUE'
               ,to_number(value_1), 0)) totalValue1
    ,sum(DECODE(apps.TT_PR_RECON_REPORT.is_number(value_2), 'TRUE'
                ,to_number(value_2), 0)) totalValue2
    ,sum(DECODE(apps.TT_PR_RECON_REPORT.is_number(value_3), 'TRUE'
                ,to_number(value_3), 0)) totalValue3
    ,sum(DECODE(apps.TT_PR_RECON_REPORT.is_number(value_4), 'TRUE'
                ,to_number(value_4), 0)) totalValue4
    ,sum(DECODE(apps.TT_PR_RECON_REPORT.is_number(value_5), 'TRUE'
                ,to_number(value_5), 0)) totalValue5
	from apps.pay_batch_lines
	--END R12.2 Upgrade Remediation
	where batch_id = p_batch_id
	group by element_name ;

Begin

    apps.fnd_file.put_line(apps.fnd_file.output,
	       'Batch Element Entry Report');
    apps.fnd_file.put_line(apps.fnd_file.output,
	       'Batch Name:'||p_batch_name);
	apps.fnd_file.new_line(apps.fnd_file.output,2);


	For batch_h in c_batch_header loop

	  v_batch_counter := v_batch_counter + 1;

	  v_batch_id := batch_h.batch_id;

      --list location
	  apps.fnd_file.put_line(apps.fnd_file.output,
	    'Location Name:'||batch_h.location_code);

	  apps.fnd_file.put_line(apps.fnd_file.output,
	    'Employee Number '||
		'Employee Name                       '||
		'Element Name                        '||
		'Location Code                  '||
		'Eff. Date'||' '||
		'      Value1'||' '||
		'      Value2'||' '||
		'      Value3'||' '||
		'      Value4'||' '||
		'      Value5');
	  apps.fnd_file.put_line(apps.fnd_file.output,
	    '=============== '||
		'=================================== '||
		'=================================== '||
		'============================== '||
    	'========='||' '||
		'============'||' '||
		'============'||' '||
		'============'||' '||
		'============'||' '||
		'============');

	 -- apps.fnd_file.put_line(apps.fnd_file.output,
  		--			rpad('=',160,'='));

		l_emp_number := null;
        l_value_1 := 0;
		l_value_2 := 0;
        l_value_3 := 0;
		l_value_4 := 0;
        l_value_5 := 0;
		v_subcount := 0;

	--  dbms_output.put_line('BeforeBatch EmpCount'||v_subcount);

	    For batch_l in c_batch_line(batch_h.batch_id, batch_h.location_id) loop

		  If NVL(l_emp_number,batch_l.employee_number) = batch_l.employee_number then
            --same or first employee

		    l_emp_number := batch_l.employee_number;

	            l_value_1 := l_value_1 + NVL(batch_l.value_1,0);
	            l_value_2 := l_value_2 + NVL(batch_l.value_2,0);
	            l_value_3 := l_value_3 + NVL(batch_l.value_3,0);
	            l_value_4 := l_value_4 + NVL(batch_l.value_4,0);
	            l_value_5 := l_value_5 + NVL(batch_l.value_5,0);

		  Else  --next employee

		  v_subcount := v_subcount + 1;		--EAO 20031112

	--      dbms_output.put_line('Else EmpCount'||v_subcount);

			If l_value_1 = 0 then
			   l_value_1 := null;
			End If;
			If l_value_2 = 0 then
			   l_value_2 := null;
			End If;
			If l_value_3 = 0 then
			   l_value_3 := null;
			End If;
			If l_value_4 = 0 then
			   l_value_4 := null;
			End If;
			If l_value_5 = 0 then
			   l_value_5 := null;
			End If;

			apps.fnd_file.put_line(apps.fnd_file.output,
  					rpad(' ',97)||
					'Sub Total for Employee: '||
					l_emp_number||' '||
                	NVL(substr(lpad(to_char(to_number(l_value_1),'99999999.99'),12),1,12),rpad(' ',12)) ||' '||
                	NVL(substr(lpad(to_char(to_number(l_value_2),'99999999.99'),12),1,12),rpad(' ',12)) ||' '||
                	NVL(substr(lpad(to_char(to_number(l_value_3),'99999999.99'),12),1,12),rpad(' ',12)) ||' '||
                	NVL(substr(lpad(to_char(to_number(l_value_4),'99999999.99'),12),1,12),rpad(' ',12)) ||' '||
                    NVL(substr(lpad(to_char(to_number(l_value_5),'99999999.99'),12),1,12),rpad(' ',12))) ;


			apps.fnd_file.new_line(apps.fnd_file.output,1);

		    l_emp_number := batch_l.employee_number;
            l_value_1 := NVL(batch_l.value_1,0);
			l_value_2 := NVL(batch_l.value_2,0);
            l_value_3 := NVL(batch_l.value_3,0);
			l_value_4 := NVL(batch_l.value_4,0);
			l_value_5 := NVL(batch_l.value_5,0);

		  End If;

		  --list batch line
		  apps.fnd_file.put_line(apps.fnd_file.output,
  					substr(rpad(batch_l.employee_number,16),1,16)||
  					substr(rpad(batch_l.full_name,35),1,35)||' '||
			 		substr(rpad(batch_l.element_name,35),1,35)||' '||
					NVL(substr(rpad(batch_h.location_code,30),1,30),rpad(' ',30))||' '||
   				    NVL(substr(lpad(batch_l.effective_date,9),1,9),rpad(' ',9))||' '||
                    NVL(substr(lpad(rtrim(ltrim(batch_l.d_value_1)),12),1,12),rpad(' ',12))||' '||
					NVL(substr(lpad(rtrim(ltrim(batch_l.d_value_2)),12),1,12),rpad(' ',12))||' '||
					NVL(substr(lpad(rtrim(ltrim(batch_l.d_value_3)),12),1,12),rpad(' ',12))||' '||
					NVL(substr(lpad(rtrim(ltrim(batch_l.d_value_4)),12),1,12),rpad(' ',12))||' '||
					NVL(substr(lpad(rtrim(ltrim(batch_l.d_value_5)),12),1,12),rpad(' ',12))
				   );

		End Loop;  -- Batch Line Loop

		-- sub total for the last employee in the batch
		If l_value_1 = 0 then
		   l_value_1 := null;
		End If;
		If l_value_2 = 0 then
		   l_value_2 := null;
		End If;
		If l_value_3 = 0 then
		   l_value_3 := null;
		End If;
		If l_value_4 = 0 then
		   l_value_4 := null;
		End If;
		If l_value_5 = 0 then
		   l_value_5 := null;
		End If;

		--list employee sub total
		apps.fnd_file.put_line(apps.fnd_file.output,
  					rpad(' ',97)||
					'Sub Total for Employee: '||
					l_emp_number||' '||
                	NVL(substr(lpad(to_char(to_number(l_value_1),'99999999.99'),12),1,12),rpad(' ',12)) ||' '||
                	NVL(substr(lpad(to_char(to_number(l_value_2),'99999999.99'),12),1,12),rpad(' ',12)) ||' '||
                	NVL(substr(lpad(to_char(to_number(l_value_3),'99999999.99'),12),1,12),rpad(' ',12)) ||' '||
                	NVL(substr(lpad(to_char(to_number(l_value_4),'99999999.99'),12),1,12),rpad(' ',12)) ||' '||
                    NVL(substr(lpad(to_char(to_number(l_value_5),'99999999.99'),12),1,12),rpad(' ',12))) ;

		apps.fnd_file.new_line(apps.fnd_file.output,2);
		-- end sub total for the last employee in the batch

		-- location total

		v_subcount := v_subcount + 1;		--EAO 20031112

		--dbms_output.put_line('Location EmpCount'||v_subcount);

		apps.fnd_file.put_line(apps.fnd_file.output, 'Total Employees By Location:'||v_subcount); --EAO 20031113
		apps.fnd_file.new_line(apps.fnd_file.output,2);


		apps.fnd_file.put_line(apps.fnd_file.output, 'Location Total:'||batch_h.location_code);
		apps.fnd_file.put_line(apps.fnd_file.output,  rpad('Element Name',50,' ')||' '||
				                                      'Total Value1'||'  '||
				                                      'Total Value2'||'  '||
											          'Total Value3'||'  '||
											          'Total Value4'||'  '||
											          'Total Value5');
		apps.fnd_file.put_line(apps.fnd_file.output,  rpad('============',50,'=')||' '||
				                                      '============'||'  '||
				                                      '============'||'  '||
											          '============'||'  '||
											          '============'||'  '||
											          '============');
--        apps.fnd_file.put_line(apps.fnd_file.output,
--  					rpad('=',150,'='));

		For batch_l in c_location_total(batch_h.batch_id, batch_h.location_id) loop

		If batch_l.totalValue1 = 0 then
		   batch_l.totalValue1 := null;
		End If;
		If batch_l.totalValue2 = 0 then
		   batch_l.totalValue2 := null;
		End If;
		If batch_l.totalValue3 = 0 then
		   batch_l.totalValue3 := null;
		End If;
		If batch_l.totalValue4 = 0 then
		   batch_l.totalValue4 := null;
		End If;
		If batch_l.totalValue5 = 0 then
		   batch_l.totalValue5 := null;
		End If;

		    --list location total
		    apps.fnd_file.put_line(apps.fnd_file.output,
			 		--substr(rpad(batch_l.element_name,25),1,25)||		commented out by eoa to change 25 to 50 characters
			 		substr(rpad(batch_l.element_name,50),1,50)||' '||
                    NVL(substr(lpad(to_char(to_number(batch_l.totalValue1),'99999999.99'),12),1,12),rpad(' ',12))||'  '||
					NVL(substr(lpad(to_char(to_number(batch_l.totalValue2),'99999999.99'),12),1,12),rpad(' ',12))||'  '||
					NVL(substr(lpad(to_char(to_number(batch_l.totalValue3),'99999999.99'),12),1,12),rpad(' ',12))||'  '||
					NVL(substr(lpad(to_char(to_number(batch_l.totalValue4),'99999999.99'),12),1,12),rpad(' ',12))||'  '||
					NVL(substr(lpad(to_char(to_number(batch_l.totalValue5),'99999999.99'),12),1,12),rpad(' ',12)));

		End Loop;  -- Location Total Loop
		v_subcount := 0;
   		apps.fnd_file.new_line(apps.fnd_file.output,2);

	End Loop;  -- Batch Loop

    -- Batch Total
    apps.fnd_file.put_line(apps.fnd_file.output, 'Batch Total:'||p_batch_name);
    apps.fnd_file.put_line(apps.fnd_file.output,
		          rpad('Element Name',50,' ')||' '||  'Total Value1'||'  '||
				                                      'Total Value2'||'  '||
											          'Total Value3'||'  '||
											          'Total Value4'||'  '||
											          'Total Value5');
		apps.fnd_file.put_line(apps.fnd_file.output,  rpad('============',50,'=')||' '||
				                                      '============'||'  '||
				                                      '============'||'  '||
											          '============'||'  '||
											          '============'||'  '||
											          '============');
   -- apps.fnd_file.put_line(apps.fnd_file.output,
  		--			rpad('=',160,'='));

	For batch_t in c_batch_total(v_batch_id) loop	-- Batch Total Loop

		If batch_t.totalValue1 = 0 then
		   batch_t.totalValue1 := null;
		End If;
		If batch_t.totalValue2 = 0 then
		   batch_t.totalValue2 := null;
		End If;
		If batch_t.totalValue3 = 0 then
		   batch_t.totalValue3 := null;
		End If;
		If batch_t.totalValue4 = 0 then
		   batch_t.totalValue4 := null;
		End If;
		If batch_t.totalValue5 = 0 then
		   batch_t.totalValue5 := null;
		End If;

		    --list batch total
		    apps.fnd_file.put_line(apps.fnd_file.output,
			 	--    substr(rpad(batch_t.element_name,25),1,25)||  commented out by eoa to change 25 to 50 characters
				   substr(rpad(batch_t.element_name,50),1,50)||' '||
                    NVL(substr(lpad(to_char(to_number(batch_t.totalValue1),'99999999.99'),12),1,12),rpad(' ',12))||'  '||
					NVL(substr(lpad(to_char(to_number(batch_t.totalValue2),'99999999.99'),12),1,12),rpad(' ',12))||'  '||
					NVL(substr(lpad(to_char(to_number(batch_t.totalValue3),'99999999.99'),12),1,12),rpad(' ',12))||'  '||
					NVL(substr(lpad(to_char(to_number(batch_t.totalValue4),'99999999.99'),12),1,12),rpad(' ',12))||'  '||
					NVL(substr(lpad(to_char(to_number(batch_t.totalValue5),'99999999.99'),12),1,12),rpad(' ',12)));

	End Loop;	-- Batch Total Loop

end paydata_summary;
END TT_PR_RECON_REPORT;
/
show errors;
/