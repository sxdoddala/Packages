create or replace PACKAGE BODY TTEC_GL_VAC_SAL402 AS
----------------------------------------------------

 /************************************************************************************
        Program Name: TTEC_GL_VAC_SAL402 

        Description:   

        Developed by : 
        Date         :  

       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
    MXKEERTHI(ARGANO)            1.0      03-May-2023      R12.2 Upgrade Remediation
    ****************************************************************************************/




-- Filehandle Variables
p_FileDir VARCHAR2(60)           :=  '/usr/tmp';
p_FileName VARCHAR2(50)          := 'GLVAC_SAL.txt';
v_daily_file UTL_FILE.FILE_TYPE;


SKIP_RECORD   EXCEPTION;


PROCEDURE get_accrual_plan(p_accrual_plan_type IN VARCHAR2
	                       ,p_assignment_id IN NUMBER
				           ,p_date IN DATE
				           ,p_accrual_plan_id OUT NUMBER) IS
--l_error_message		 	CUST.ttec_error_handling.error_message%TYPE; --Commented code by MXKEERTHI-ARGANO, 05/03/2023
l_error_message		 	APPS.ttec_error_handling.error_message%TYPE;   --code Added  by MXKEERTHI-ARGANO, 05/03/2023

BEGIN
--dbms_output.put_line('get_accrual_plan');
     SELECT pap.accrual_plan_id
     INTO p_accrual_plan_id
     FROM
         pay_accrual_plans pap,
    	 pay_element_links_f 	pel,
	     pay_element_entries_f 	pee
     WHERE
         pap.accrual_category 	= p_accrual_plan_type  --('S' for sick, 'V'  for vacation)
         and pel.element_type_id = pap.accrual_plan_element_type_id
         and pee.element_link_id = pel.element_link_id
         and pee.assignment_id	= p_assignment_id
         and trunc(p_date) between pel.effective_start_date and pel.effective_end_date
         and trunc(p_date) between pee.effective_start_date and pee.effective_end_date;

    EXCEPTION

             WHEN NO_DATA_FOUND THEN
	         l_error_message := 'No Data Found when getting accrual plan';
               RAISE SKIP_RECORD;

             WHEN TOO_MANY_ROWS THEN
	         l_error_message := 'Too Many Rows when getting accrual plan';
             RAISE SKIP_RECORD;

             WHEN OTHERS THEN
			         l_error_message := SQLERRM;
             RAISE;


END get_accrual_plan;

PROCEDURE employee_salary (p_assignment IN NUMBER,
                           p_date IN DATE,
						   p_salary OUT NUMBER) IS
  --START R12.2 Upgrade Remediation
	  /*
		Commented code by MXKEERTHI-ARGANO, 05/03/2023
v_salary  		HR.PER_PAY_PROPOSALS.PROPOSED_SALARY_N%TYPE;
v_pay_basis 	HR.PER_PAY_BASES.PAY_BASIS%TYPE;
l_error_message		 	CUST.ttec_error_handling.error_message%TYPE;

	   */
	  --code Added  by MXKEERTHI-ARGANO, 05/03/2023
v_salary  		APPS.PER_PAY_PROPOSALS.PROPOSED_SALARY_N%TYPE;
v_pay_basis 	APPS.PER_PAY_BASES.PAY_BASIS%TYPE;
l_error_message		 	APPS.ttec_error_handling.error_message%TYPE;
	  
	  --END R12.2.10 Upgrade remediation

Begin

	v_pay_basis := NULL;
	p_salary := 0;
	v_salary := 0;

--dbms_output.put_line('employee_salary->'||p_assignment||'-'||p_date||'-'||p_salary);
SELECT PAYP.proposed_salary_n, PPB.pay_basis
               INTO   v_salary, v_pay_basis
			   --START R12.2 Upgrade Remediation
	  /*
		Commented code by MXKEERTHI-ARGANO, 05/03/2023
		 FROM
		 HR.PER_PAY_PROPOSALS PAYP,
 	     HR.PER_ALL_ASSIGNMENTS_F PAF,
	     HR.PER_PAY_BASES PPB

	   */
	  --code Added  by MXKEERTHI-ARGANO, 05/03/2023
       FROM
	     APPS.PER_PAY_PROPOSALS PAYP,
 	     APPS.PER_ALL_ASSIGNMENTS_F PAF,
	     APPS.PER_PAY_BASES PPB
	  
	  --END R12.2.10 Upgrade remediation

	 
	 WHERE PAF.ASSIGNMENT_ID = PAYP.ASSIGNMENT_ID
     AND  PAF.BUSINESS_GROUP_ID = PAYP.BUSINESS_GROUP_ID
	 AND  PPB.PAY_BASIS_ID = PAF.PAY_BASIS_ID
	 AND  trunc(p_date) BETWEEN PAF.EFFECTIVE_START_DATE AND PAF.EFFECTIVE_END_DATE
     AND  PAYP.CHANGE_DATE = (select max(change_date)
	                    --from  HR.PER_PAY_PROPOSALS --Commented code by MXKEERTHI-ARGANO, 05/08/2023
                         from  apps.PER_PAY_PROPOSALS --code added by MXKEERTHI-ARGANO, 05/08/2023
                         where ASSIGNMENT_ID = p_assignment)
	 AND  payp.ASSIGNMENT_ID = p_assignment;

	 if v_pay_basis = 'ANNUAL' then
	    p_salary := (v_salary/2080);
	 else
	    p_salary := v_salary;
	 end if;

    EXCEPTION

             WHEN NO_DATA_FOUND THEN
	         l_error_message := 'No Data Found when getting salary';
             RAISE SKIP_RECORD;

             WHEN TOO_MANY_ROWS THEN
	         l_error_message := 'Too Many Rows when getting salary';
             RAISE SKIP_RECORD;

             WHEN OTHERS THEN
			         l_error_message := SQLERRM;
             RAISE;


END employee_salary;

PROCEDURE Emp_costing(errcode varchar2, errbuff varchar2,p_location_code IN varchar2
                       ,p_report_date IN date,p_organization_name IN varchar2) IS


v_date						 date;
v_assignment_id				 number;
v_amount					 number;
v_full_name					 varchar2(50);
v_location					 pay_cost_allocation_keyflex.segment1%type := NULL;
v_client					 pay_cost_allocation_keyflex.segment1%type := NULL;
v_Department				 pay_cost_allocation_keyflex.segment1%type := NULL;
v_loc_override				 varchar2(10);
v_dep_override				 varchar2(10);
v_vac_balance				 number;
--v_salary	 				 HR.PER_PAY_PROPOSALS.PROPOSED_SALARY_N%TYPE;   --Commented code by MXKEERTHI-ARGANO, 05/03/2023
v_salary	 				 APPS.PER_PAY_PROPOSALS.PROPOSED_SALARY_N%TYPE;   --CODE ADDED  by MXKEERTHI-ARGANO, 05/03/2023
v_location_code				  hr_locations.location_code%type;--:='USA-Englewood (TTEC)';
v_organization_name                       hr_all_organization_units.name%type; -- 'TTEC-Inbound Operations'
v_vac_accrual_plan_id		  pay_accrual_plans.accrual_plan_id%type;
v_net_vac_accrual			  number;
v_count					  number;
v_errmsg				  varchar2(200);
v_user_name				  varchar2(20);
v_vac_allowed				  number;
v_accrual_plan_type           pay_accrual_plans.accrual_category%type;
v_vac_dollar_balance		  number;
--l_error_message		 	CUST.ttec_error_handling.error_message%TYPE;   --Commented code by MXKEERTHI-ARGANO, 05/03/2023
l_error_message		 	APPS.ttec_error_handling.error_message%TYPE;   --CODE ADDED  by MXKEERTHI-ARGANO, 05/03/2023


l_emp_output 	           CHAR(242);

cursor c_emp is

 select a.person_id empl_person_id
       ,a.employee_number empl_employee_number
       ,a.full_name empl_full_name
       ,b.assignment_id empl_assignment_id
       ,e.location_code empl_location_code
       ,e.attribute2 empl_attribute2
       ,b.organization_id empl_organization_id
       ,substr(concatenated_segments,1,instr(concatenated_segments,'.')-1) empl_Gre
       ,g.payroll_name empl_payroll_name
	   --START R12.2 Upgrade Remediation
	  /*
		Commented code by MXKEERTHI-ARGANO, 05/03/2023
         from hr.per_all_people_f a, hr.per_all_assignments_f b, hr.per_periods_of_service c,
		 hr.per_pay_bases d, hr.hr_locations_all e, hr.hr_soft_coding_keyflex f,
		 hr.pay_all_payrolls_f g, hr.hr_all_organization_units h
	   */
	  --code Added  by MXKEERTHI-ARGANO, 05/03/2023
	  from apps.per_all_people_f a, APPS.per_all_assignments_f b, APPS.per_periods_of_service c,
		 APPS.per_pay_bases d, APPS.hr_locations_all e, APPS.hr_soft_coding_keyflex f,
		 APPS.pay_all_payrolls_f g, APPS.hr_all_organization_units h
	  
	  --END R12.2.10 Upgrade remediation
	   
	
	where a.person_id = b.person_id and a.person_id = c.person_id
	and a.person_type_id in (select types.person_type_id from hr.per_person_types types
	where types.business_group_id = b.business_group_id
--	and b.business_group_id = 326
	and types.active_flag = 'Y'
	and types.system_person_type in ('EMP','EMP_APL')
	and types.default_flag = 'Y')
	and to_char(to_date(p_report_date),'DD-MON-YYYY') between a.effective_start_Date and a.effective_end_date
	and to_char(to_date(p_report_date),'DD-MON-YYYY') between b.effective_start_date and b.effective_end_date
	and b.pay_basis_id = d.pay_basis_id
	and b.primary_flag = 'Y' and c.actual_termination_date is null
	and b.location_id = e.location_id
	and e.location_code = nvl(p_location_code, e.location_code)
	and b.organization_id = h.organization_id
        and h.name = nvl(p_organization_name, h.name)
	and f.soft_coding_keyflex_id = b.soft_coding_keyflex_id
	and b.payroll_id = g.payroll_id
	and c.date_start = (select max(date_start) 
	
	                    --from hr.per_periods_of_service --Commented code by MXKEERTHI-ARGANO, 05/02/2023
						
	                    from APPS.per_periods_of_service -- code Added by MXKEERTHI-ARGANO, 05/02/2023
						where person_id = a.person_id
					    and date_start <= to_char(to_date(p_report_date),'DD-MON-YYYY') );

BEGIN

	v_daily_file := UTL_FILE.FOPEN(p_FileDir, p_FileName, 'w');

    v_assignment_id := 0;
    v_vac_balance := 0;
	v_salary := 0;
	v_vac_dollar_balance := 0;


l_emp_output := ('Employee GL Vacation Salary Report'||'|'||'Report Date:'||p_report_date);
utl_file.put_line(v_daily_file, l_emp_output);
--dbms_output.put_line('---------------------------------------------------------------------------------------------------------------------------------');
l_emp_output := ('Location Code'||'|'||'Employee Number'||'|'||'Employee Name'||'|'||'Location'||'|'||'Loc_Override'||'|'||'Client'||'|'||'Department'||'|'||'Dept_Override'||'|'||'Vac Balance'||'|'||'Hourly Pay'||'|'||'Vacation Dollars');
utl_file.put_line(v_daily_file, l_emp_output);


	For emp in c_emp loop
	    v_assignment_id := emp.empl_assignment_id;
     --dbms_output.put_line('emp assignment id'||to_char(v_assignment_id));
	--BEGIN
	 begin

		select b.segment1,b.segment2,b.segment3
		into v_location,v_client,v_department
		--from hr.pay_cost_allocations_f a, hr.pay_cost_allocation_keyflex b  --Commented code by MXKEERTHI-ARGANO, 05/03/2023
			from APPS.pay_cost_allocations_f a, apps.pay_cost_allocation_keyflex b --code Added  by MXKEERTHI-ARGANO, 05/03/2023

		
      	where a.assignment_id = v_assignment_id
      	and a.cost_allocation_keyflex_id = b.cost_allocation_keyflex_id
       	and to_char(to_date(p_report_date),'DD-MON-YYYY')  between a.effective_start_date and a.effective_end_date;

        --dbms_output.put_line('After'||v_assignment_id);
  --     EXCEPTION

  --   WHEN NO_DATA_FOUND THEN

		if v_location is null then
		   v_location := emp.empl_attribute2;
		   v_loc_override := ' ';
		else
		   v_loc_override := 'Override';
		end if;

		if v_department is null then
--dbms_output.put_line('if v_dept is null');
			select b.segment3 into v_department
			--from hr.hr_all_organization_units a,  hr.pay_cost_allocation_keyflex b  --Commented code by MXKEERTHI-ARGANO, 05/03/2023
			from APPS.hr_all_organization_units a,  apps.pay_cost_allocation_keyflex b   --code Added  by MXKEERTHI-ARGANO, 05/03/2023
			where a.cost_allocation_keyflex_id = b.cost_allocation_keyflex_id
			and a.organization_id = emp.empl_organization_id;
			v_dep_override := ' ';
		else
			v_dep_override := 'Override';
		end if;

    --   WHEN OTHERS THEN
	--		         l_error_message := SQLERRM;
    --         l_emp_output := (emp.empl_location_code					||'|'||
	--						  emp.empl_employee_number			||'|'||
	--						  emp.empl_full_name||l_error_message);
	--	RAISE SKIP_RECORD;

  --   end;
--dbms_output.put_line('Cursor Read: '||v_assignment_id);
-------------------------------------------------------------------------------------------------------------------------

/* Get which vacation plan is active for the employee as of the report date */

        	v_vac_accrual_plan_id := null;
			v_accrual_plan_type := 'V';
			get_accrual_plan(v_accrual_plan_type,v_assignment_id,p_report_date,v_vac_accrual_plan_id);


			----dbms_output.put_line('After getting plans ');

				v_net_vac_accrual:= null;

			   /* Get net Vacation accrual balance */

				if v_vac_accrual_plan_id is not null then
					v_net_vac_accrual:=pay_us_pto_accrual.get_net_accrual
									 (P_assignment_id          => v_assignment_id,
									  P_calculation_date       => p_report_date,
									  P_plan_id                => v_vac_accrual_plan_id);
				End if;


	--dbms_output.put_line('Net Vacation '||v_net_vac_accrual);

		employee_salary (v_assignment_id, p_report_date, v_salary);

		v_vac_dollar_balance := round((v_salary * v_net_vac_accrual),2);


-------------------------------------------------------------------------------------------------------------------

	--dbms_output.put_line(v_assignment_id);

			l_emp_output := (emp.empl_location_code			||'|'||
							  emp.empl_employee_number			||'|'||
							  emp.empl_full_name				||'|'||
							  v_location					    ||'|'||
							  v_loc_override				    ||'|'||
							  v_client					        ||'|'||
							  v_department					    ||'|'||
							  v_dep_override				    ||'|'||
							  round(v_net_vac_accrual,3)		||'|'||
							  round(v_salary,2)					||'|'||
							  v_vac_dollar_balance
							   );

	EXCEPTION
	 WHEN SKIP_RECORD THEN
	 l_emp_output := (emp.empl_location_code			    ||'|'||
						  emp.empl_employee_number			    ||'|'||
						  emp.empl_full_name				    ||'|'||
						  v_location					        ||'|'||
						  v_loc_override				        ||'|'||
						  v_client					            ||'|'||
						  v_department					        ||'|'||
						  v_dep_override
						  );
	    NULL;

      WHEN OTHERS THEN
	         l_error_message := SQLERRM;
           l_emp_output := (emp.empl_location_code					||'|'||
						  emp.empl_employee_number			||'|'||
						  emp.empl_full_name||l_error_message);


	END;
		utl_file.put_line(v_daily_file, l_emp_output);

	end Loop;

	UTL_FILE.FCLOSE(v_daily_file);

end emp_costing;

END TTEC_GL_VAC_SAL402;
/
show errors;
/