/************************************************************************************
        Program Name:   CUST_ACCRUAL_REPORTS

       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
    IXPRAVEEN(ARGANO)            1.0     18-july-2023     R12.2 Upgrade Remediation
    ****************************************************************************************/
create or replace PACKAGE BODY CUST_ACCRUAL_REPORTS AS
Function get_value_for_accrual_plan(p_accrual_plan_id in number,p_assignment_id in number) return number
is
v_value number;
begin
	select sum(b.screen_entry_value) into v_value
	from pay_element_entries_f a, pay_element_entry_values_f b, pay_net_calculation_rules c
	where b.input_value_id = c.input_value_id
	and c.accrual_plan_id = p_accrual_plan_id
	and a.assignment_id = p_assignment_id
	and a.element_entry_id = b.element_entry_id
	and c.add_or_subtract = -1
	and a.effective_start_date <= v_date
	and b.effective_start_date <= v_date;
	return v_value;
end;
PROCEDURE personal_holiday_balance(location_code       IN   varchar2,
		  						  Report_date date) IS
v_accrual_plan_id			  pay_accrual_plans.accrual_plan_id%type;
v_net_accrual				  number;
v_supervisor_name			  varchar2(50);
v_count						  number;
v_errmsg					  varchar2(200);
v_user_name					  varchar2(20);
/* Get all the employees for the current business Group*/
Cursor c_employees is
	select a.person_id,a.employee_number,a.full_name,b.assignment_id,
		   b.supervisor_id, b.employment_category, b.payroll_id,d.location_code
	from per_all_people_f a, per_all_assignments_f b, per_periods_of_service c, hr_locations d
	where a.person_id = b.person_id and a.person_id = c.person_id
	and a.person_type_id in (select person_type_id from per_person_types
						 	 where business_group_id = v_business_group_id and active_flag = 'Y'
							 and system_person_type in ('EMP','EMP_APL')
						 	 and default_flag = 'Y')
	and v_date between a.effective_start_Date and a.effective_end_date
	and v_date between b.effective_start_date and b.effective_end_date
	and b.primary_flag = 'Y' and c.actual_termination_date is null
	and b.location_id = d.location_id and d.location_code = nvl(v_location_code,d.location_code)
	and c.date_start = (select max(date_start) from per_periods_of_service where person_id = a.person_id
					    and date_start <= v_date);
	--and b.assignment_id = 31421					;
Begin
	v_location_code := location_code;
	v_date			:= report_date;
	v_user_name := fnd_global.user_name;
	if v_user_name is null then
	   v_user_name := 'TEST';
	end if;
	--delete from cust.personal_holiday_balance where user_name = v_user_name;			 -- Commented code by IXPRAVEEN-ARGANO,18-july-2023
	delete from apps.personal_holiday_balance where user_name = v_user_name;             --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
	commit;
	For bus_group in c_bus_group loop
		v_business_group_id := bus_group.business_group_id;
		v_count := 0;
  		v_location_code := location_code;
		For emp in c_employees loop
			v_location_code := emp.location_code;
			/* Get the accrual plan id for the Accrual plan Personal Holiday Bank */
			select accrual_plan_id into v_accrual_plan_id
			from pay_accrual_plans
		    where Accrual_plan_name = 'Personal Holiday Bank';
			v_supervisor_name := null;
			if emp.supervisor_id is not null then
				/* Get the supervisor name */
				select full_name into v_supervisor_name
				from per_all_people_f
				where person_id = emp.supervisor_id
				and trunc(sysdate) between effective_start_date and effective_end_date;
			end if;
			begin
				v_net_accrual:= null;
				v_net_accrual:=pay_us_pto_accrual.get_net_accrual
								 (P_assignment_id          => emp.assignment_id,
								  P_calculation_date       => v_date,
								  P_plan_id                => v_accrual_plan_id);
				v_errmsg := null;
			exception
				when others then
					 v_errmsg := substr(sqlerrm,1,200);
			end;
			----dbms_output.put_line('Net Accrual '||v_net_accrual);
			--insert into cust.personal_holiday_balance fields			 -- Commented code by IXPRAVEEN-ARGANO,18-july-2023
			insert into apps.personal_holiday_balance fields             --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
               	(location_code 					 ,
                 emp_number 					 ,
                 Emp_name						 ,
                 holiday_balance		 		 ,
                 Supervisor_name		 		 ,
                 Person_id				 		 ,
                 assignment_id			 		 ,
                 Report_date			 		 ,
                 User_name						 ,
				 errmsg							 ,
				 business_group_id
				)
				values
               	(v_location_code				 ,
                 emp.employee_number			 ,
                 emp.full_name					 ,
                 v_net_accrual		 		 	 ,
                 v_supervisor_name		 		 ,
                 emp.Person_id			 		 ,
                 emp.assignment_id		 		 ,
                 v_date			 		 		 ,
                 v_user_name					 ,
				 v_errmsg						 ,
				 bus_group.business_group_id
				);
			v_count:=v_count+1;
			if mod(v_count,50) = 0 then
			   commit;
			end if;
		End Loop;
	End Loop;
	commit;
end personal_holiday_balance;
PROCEDURE negative_time_balance(location_code       IN   varchar2,
		  						  Report_date date) IS
v_sick_accrual_plan_id		  pay_accrual_plans.accrual_plan_id%type;
v_vac_accrual_plan_id		  pay_accrual_plans.accrual_plan_id%type;
v_net_sick_accrual			  number;
v_sick_taken				  number;
v_net_vac_accrual			  number;
v_vac_taken					  number;
v_supervisor_name			  varchar2(50);
v_count						  number;
v_errmsg					  varchar2(200);
v_user_name					  varchar2(20);
/* Get all the employees for the current business Group*/
Cursor c_employees is
	select a.person_id,a.employee_number,a.full_name,b.assignment_id,
		   b.supervisor_id, b.employment_category, b.payroll_id,d.location_code
	from per_all_people_f a, per_all_assignments_f b, per_periods_of_service c,hr_locations d
	where a.person_id = b.person_id and a.person_id = c.person_id
	and a.person_type_id in (select person_type_id from per_person_types
						 	 where business_group_id = v_business_group_id and active_flag = 'Y'
							 and system_person_type in ('EMP','EMP_APL')
						 	 and default_flag = 'Y')
	and v_date between a.effective_start_Date and a.effective_end_date
	and v_date between b.effective_start_date and b.effective_end_date
	and b.primary_flag = 'Y' and c.actual_termination_date is null
	and b.location_id = d.location_id and d.location_code = nvl(v_location_code,d.location_code)
	and c.date_start = (select max(date_start) from per_periods_of_service where person_id = a.person_id
					    and date_start <= v_date);
						--	and b.assignment_id = 31421					;
Begin
	v_location_code := location_code;
	v_date			:= report_date;
	v_user_name := fnd_global.user_name;
	if v_user_name is null then
	   v_user_name := 'TEST';
	end if;
	--delete from cust.negative_time_balance where user_name = v_user_name;			 -- Commented code by IXPRAVEEN-ARGANO,18-july-2023
	delete from apps.negative_time_balance where user_name = v_user_name;            --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
	commit;
	For bus_group in c_bus_group loop
		v_business_group_id := bus_group.business_group_id;
		v_count := 0;
		v_location_code := location_code;
		For emp in c_employees loop
		v_location_code := emp.location_code;
		begin
			v_assignment_id := emp.assignment_id;
			/* Get which sick plan is active for the employee as of the report date */
			v_sick_accrual_plan_id := null;
			v_accrual_plan := '%Sick%Plan%';
			open c_accrual_plan;
			fetch c_accrual_plan into v_sick_accrual_plan_id;
			close c_accrual_plan;
			/* Get which vacation plan is active for the employee as of the report date */
			v_vac_accrual_plan_id := null;
			v_accrual_plan := '%Vacation%Plan%';
			open c_accrual_plan;
			fetch c_accrual_plan into v_vac_accrual_plan_id;
			close c_accrual_plan;
			begin
				v_net_sick_accrual:= null;
			   /* Get net Sick accrual balance */
				if v_sick_accrual_plan_id is not null then
					v_net_sick_accrual:=pay_us_pto_accrual.get_net_accrual
									 (P_assignment_id          => emp.assignment_id,
									  P_calculation_date       => v_date,
									  P_plan_id                => v_sick_accrual_plan_id);
				end if;
				v_net_vac_accrual:= null;
			   /* Get net Vacation accrual balance */
				if v_vac_accrual_plan_id is not null then
					v_net_vac_accrual:=pay_us_pto_accrual.get_net_accrual
									 (P_assignment_id          => emp.assignment_id,
									  P_calculation_date       => v_date,
									  P_plan_id                => v_vac_accrual_plan_id);
				End if;
				v_errmsg := null;
				if v_net_vac_accrual <0 or v_net_sick_accrual < 0 then
				/* Only if vacation or sick balance is negative calculate vacation and sick leave taken */
					v_sick_taken := get_value_for_accrual_plan(v_sick_accrual_plan_id,emp.assignment_id);
					v_vac_taken  := get_value_for_accrual_plan(v_vac_accrual_plan_id,emp.assignment_id) ;
					v_supervisor_name := null;
					if emp.supervisor_id is not null then
						/* Get the supervisor name */
						select full_name into v_supervisor_name
						from per_all_people_f
						where person_id = emp.supervisor_id
						and v_date between effective_start_date and effective_end_date;
					end if;
				    --insert into cust.negative_time_balance fields			 -- Commented code by IXPRAVEEN-ARGANO,18-july-2023
				    insert into apps.negative_time_balance fields            --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
						(location_code 						 ,
						 emp_number 						 ,
						 Emp_name							 ,
						 vac_allowed		 			 	 ,
						 vac_taken		 			 	 	 ,
						 vac_balance		 			 	 ,
						 sick_allowed		 			 	 ,
						 sick_taken		 			 	 	 ,
						 sick_balance		 			 	 ,
						 Supervisor_name		 			 ,
						 Person_id				 			 ,
						 assignment_id			 			 ,
						 Report_date			 			 ,
						 User_name				 			 ,
						 business_group_id					 ,
						 errmsg
						 )
						 values
		               	(v_location_code				     ,
		                 emp.employee_number			 	 ,
		                 emp.full_name					 	 ,
		                 v_net_vac_accrual  + v_vac_taken 	 ,
		                 v_vac_taken		 		     	 ,
		                 v_net_vac_accrual		 		 	 ,
		                 v_net_sick_accrual + v_sick_taken	 ,
		                 v_sick_taken		 		     	 ,
		                 v_net_sick_accrual		 		 	 ,
		                 v_supervisor_name		 		 	 ,
		                 emp.Person_id			 		 	 ,
		                 emp.assignment_id		 		 	 ,
		                 v_date			 		 		 	 ,
		                 v_user_name					 	 ,
						 bus_group.business_group_id		 ,
						 v_errmsg
						);
				end if;
			exception
				when others then
					 v_errmsg := substr(sqlerrm,1,200);
				     --insert into cust.negative_time_balance fields			 -- Commented code by IXPRAVEEN-ARGANO,18-july-2023
				     insert into apps.negative_time_balance fields               --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
						(location_code 						 ,
						 emp_number 						 ,
						 Emp_name							 ,
						 vac_allowed		 			 	 ,
						 vac_taken		 			 	 	 ,
						 vac_balance		 			 	 ,
						 sick_allowed		 			 	 ,
						 sick_taken		 			 	 	 ,
						 sick_balance		 			 	 ,
						 Supervisor_name		 			 ,
						 Person_id				 			 ,
						 assignment_id			 			 ,
						 Report_date			 			 ,
						 User_name				 			 ,
						 business_group_id					 ,
						 errmsg
						 )
						 values
		               	(v_location_code				     ,
		                 emp.employee_number			 	 ,
		                 emp.full_name					 	 ,
		                 v_net_vac_accrual  + v_vac_taken 	 ,
		                 v_vac_taken		 		     	 ,
		                 v_net_vac_accrual		 		 	 ,
		                 v_net_sick_accrual + v_sick_taken	 ,
		                 v_sick_taken		 		     	 ,
		                 v_net_sick_accrual		 		 	 ,
		                 v_supervisor_name		 		 	 ,
		                 emp.Person_id			 		 	 ,
		                 emp.assignment_id		 		 	 ,
		                 v_date			 		 		 	 ,
		                 v_user_name					 	 ,
						 bus_group.business_group_id		 ,
						 v_errmsg
						);
			end;
			/*
			--dbms_output.put_line('Net Sick Accrual '||v_net_sick_accrual);
			--dbms_output.put_line('Net Vacation '||v_net_vac_accrual);
			--dbms_output.put_line('Sick Taken '||v_sick_taken);
			--dbms_output.put_line('va Taken '||v_vac_taken);
			*/
			v_count:=v_count+1;
			if mod(v_count,50) = 0 then
			   commit;
			end if;
		Exception
			when others then
					 v_errmsg := substr(sqlerrm,1,200);
				     --insert into cust.negative_time_balance fields			 -- Commented code by IXPRAVEEN-ARGANO,18-july-2023
				     insert into apps.negative_time_balance fields               --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
						(location_code 						 ,
						 emp_number 						 ,
						 Emp_name							 ,
						 vac_allowed		 			 	 ,
						 vac_taken		 			 	 	 ,
						 vac_balance		 			 	 ,
						 sick_allowed		 			 	 ,
						 sick_taken		 			 	 	 ,
						 sick_balance		 			 	 ,
						 Supervisor_name		 			 ,
						 Person_id				 			 ,
						 assignment_id			 			 ,
						 Report_date			 			 ,
						 User_name				 			 ,
						 business_group_id					 ,
						 errmsg
						 )
						 values
		               	(v_location_code				     ,
		                 emp.employee_number			 	 ,
		                 emp.full_name					 	 ,
		                 v_net_vac_accrual  + v_vac_taken 	 ,
		                 v_vac_taken		 		     	 ,
		                 v_net_vac_accrual		 		 	 ,
		                 v_net_sick_accrual + v_sick_taken	 ,
		                 v_sick_taken		 		     	 ,
		                 v_net_sick_accrual		 		 	 ,
		                 v_supervisor_name		 		 	 ,
		                 emp.Person_id			 		 	 ,
		                 emp.assignment_id		 		 	 ,
		                 v_date			 		 		 	 ,
		                 v_user_name					 	 ,
						 bus_group.business_group_id						 	 ,
						 v_errmsg
						);
		end;
		End Loop;
	End Loop;
	commit;
end negative_time_balance;
PROCEDURE time_off_balance(location_code       IN   varchar2,
		  						  Report_date date) IS
v_sick_accrual_plan_id		  pay_accrual_plans.accrual_plan_id%type;
v_vac_accrual_plan_id		  pay_accrual_plans.accrual_plan_id%type;
v_net_sick_accrual			  number;
v_sick_taken				  number;
v_net_vac_accrual			  number;
v_vac_taken					  number;
v_supervisor_name			  varchar2(50);
v_count						  number;
v_errmsg					  varchar2(200);
v_user_name					  varchar2(20);
/* Get all the busniss groups associated with this location
cursor c_bus_group is
	select distinct business_group_id
	from hr_all_organization_units where location_id = (select location_id from hr_locations
		 						   		 			    where location_code = v_location_code)
	and v_date between date_from and nvl(date_to,'31-dec-4712');
*/
/* Get all the employees for the current business Group*/
Cursor c_employees is
	select a.person_id,a.employee_number,a.full_name,b.assignment_id,
		   b.supervisor_id, b.employment_category, b.payroll_id, d.pay_basis,c.date_start,e.location_code
	from per_all_people_f a, per_all_assignments_f b, per_periods_of_service c,per_pay_bases d,hr_locations e
	where a.person_id = b.person_id and a.person_id = c.person_id
	and a.person_type_id in (select person_type_id from per_person_types
						 	 where business_group_id = v_business_group_id and active_flag = 'Y'
							 and system_person_type in ('EMP','EMP_APL')
						 	 and default_flag = 'Y')
	and v_date between a.effective_start_Date and a.effective_end_date
	and v_date between b.effective_start_date and b.effective_end_date
	and b.pay_basis_id = d.pay_basis_id
	and b.primary_flag = 'Y' and c.actual_termination_date is null
	and b.location_id = e.location_id and e.location_code = nvl(v_location_code,e.location_code)
	and c.date_start = (select max(date_start) from per_periods_of_service where person_id = a.person_id
					    and date_start <= v_date);
						--and b.assignment_id = 31421					;
Begin
	v_location_code := location_code;
	v_date			:= report_date;
	v_user_name := fnd_global.user_name;
	if v_user_name is null then
	   v_user_name := 'TEST';
	end if;
	---delete from cust.time_off_balance where user_name = v_user_name;			 -- Commented code by IXPRAVEEN-ARGANO,18-july-2023
	delete from apps.time_off_balance where user_name = v_user_name;             --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
	commit;
	For bus_group in c_bus_group loop
		v_business_group_id := bus_group.business_group_id;
		v_count := 0;
  	    v_location_code := location_code;
		For emp in c_employees loop
			v_location_code := emp.location_code;
			--dbms_output.put_line('assignment_id '||emp.assignment_id);
			v_assignment_id := emp.assignment_id;
			/* Get which sick plan is active for the employee as of the report date */
			v_sick_accrual_plan_id := null;
			v_accrual_plan := '%Sick%Plan%';
			open c_accrual_plan;
			fetch c_accrual_plan into v_sick_accrual_plan_id;
			close c_accrual_plan;
			/* Get which vacation plan is active for the employee as of the report date */
			v_vac_accrual_plan_id := null;
			v_accrual_plan := '%Vacation%Plan%';
			open c_accrual_plan;
			fetch c_accrual_plan into v_vac_accrual_plan_id;
			close c_accrual_plan;
			----dbms_output.put_line('After getting plans ');
			begin
				v_net_sick_accrual:= null;
			   /* Get net Sick accrual balance */
			   ----dbms_output.put_line('Sick Accrual plan id'||v_sick_accrual_plan_id);
				if v_sick_accrual_plan_id is not null then
					v_net_sick_accrual:=pay_us_pto_accrual.get_net_accrual
									 (P_assignment_id          => emp.assignment_id,
									  P_calculation_date       => v_date,
									  P_plan_id                => v_sick_accrual_plan_id);
				end if;
				v_net_vac_accrual:= null;
			   /* Get net Vacation accrual balance */
				if v_vac_accrual_plan_id is not null then
					v_net_vac_accrual:=pay_us_pto_accrual.get_net_accrual
									 (P_assignment_id          => emp.assignment_id,
									  P_calculation_date       => v_date,
									  P_plan_id                => v_vac_accrual_plan_id);
				End if;
				v_errmsg := null;
				/* Get the sick and vaction taken values */
				v_sick_taken := get_value_for_accrual_plan(v_sick_accrual_plan_id,emp.assignment_id);
				v_vac_taken  := get_value_for_accrual_plan(v_vac_accrual_plan_id ,emp.assignment_id);
				v_supervisor_name := null;
			/* Get the supervisor name */
				Begin
					select full_name into v_supervisor_name
					from per_all_people_f
					where person_id = (select supervisor_id
						  			   from per_all_assignments_f
									   where person_id = emp.person_id
									   and trunc(sysdate) between effective_start_date and effective_end_date)
					and trunc(sysdate) between effective_start_date and effective_end_date;
				exception
						 when others then
						 	  null;
				end;

			    --insert into cust.time_off_balance fields			 -- Commented code by IXPRAVEEN-ARGANO,18-july-2023
			    insert into apps.time_off_balance fields             --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
					(location_code 						 ,
					 emp_number 						 ,
					 Emp_name							 ,
					 vacation_date						 ,
					 vac_allowed		 			 	 ,
					 vac_taken		 			 	 	 ,
					 vac_balance		 			 	 ,
					 sick_allowed		 			 	 ,
					 sick_taken		 			 	 	 ,
					 sick_balance		 			 	 ,
					 hourly_salaried					 ,
					 hire_date							 ,
					 Person_id				 			 ,
					 assignment_id			 			 ,
					 Report_date			 			 ,
					 User_name				 			 ,
					 business_group_id					 ,
					 errmsg
					 )
					 values
	               	(v_location_code				     ,
	                 emp.employee_number			 	 ,
	                 emp.full_name					 	 ,
					 emp.date_start						 ,
	                 v_net_vac_accrual  + v_vac_taken 	 ,
	                 v_vac_taken		 		     	 ,
	                 v_net_vac_accrual		 		 	 ,
	                 v_net_sick_accrual + v_sick_taken	 ,
	                 v_sick_taken		 		     	 ,
	                 v_net_sick_accrual		 		 	 ,
					 emp.pay_basis						 ,
					 emp.date_start						 ,
	                 emp.Person_id			 		 	 ,
	                 emp.assignment_id		 		 	 ,
	                 v_date			 		 		 	 ,
	                 v_user_name					 	 ,
					 bus_group.business_group_id		 ,
					 v_errmsg
					);
			exception
				when others then
					 v_errmsg := substr(sqlerrm,1,200);
					   -- insert into cust.time_off_balance fields			 -- Commented code by IXPRAVEEN-ARGANO,18-july-2023
					    insert into apps.time_off_balance fields             --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
							(location_code 						 ,
							 emp_number 						 ,
							 Emp_name							 ,
							 vacation_date						 ,
							 vac_allowed		 			 	 ,
							 vac_taken		 			 	 	 ,
							 vac_balance		 			 	 ,
							 sick_allowed		 			 	 ,
							 sick_taken		 			 	 	 ,
							 sick_balance		 			 	 ,
							 hourly_salaried					 ,
							 hire_date							 ,
							 Person_id				 			 ,
							 assignment_id			 			 ,
							 Report_date			 			 ,
							 User_name				 			 ,
							 business_group_id					 ,
							 errmsg
							 )
							 values
			               	(v_location_code				     ,
			                 emp.employee_number			 	 ,
			                 emp.full_name					 	 ,
							 emp.date_start						 ,
			                 v_net_vac_accrual  + v_vac_taken 	 ,
			                 v_vac_taken		 		     	 ,
			                 v_net_vac_accrual		 		 	 ,
			                 v_net_sick_accrual + v_sick_taken	 ,
			                 v_sick_taken		 		     	 ,
			                 v_net_sick_accrual		 		 	 ,
							 emp.pay_basis						 ,
							 emp.date_start						 ,
			                 emp.Person_id			 		 	 ,
			                 emp.assignment_id		 		 	 ,
			                 v_date			 		 		 	 ,
			                 v_user_name					 	 ,
							 bus_group.business_group_id		 ,
							 v_errmsg
							);
			end;
			/*
			--dbms_output.put_line('Net Sick Accrual '||v_net_sick_accrual);
			--dbms_output.put_line('Net Vacation '||v_net_vac_accrual);
			--dbms_output.put_line('Sick Taken '||v_sick_taken);
			--dbms_output.put_line('va Taken '||v_vac_taken);
			*/
			v_count:=v_count+1;
			if mod(v_count,50) = 0 then
			   commit;
			end if;
		End Loop;
	End Loop;
	commit;
end time_off_balance;

PROCEDURE termed_emp_vac_balance(location_code       IN   varchar2,
		  						  Report_date date) IS
v_vac_accrual_plan_id		  pay_accrual_plans.accrual_plan_id%type;
v_net_vac_accrual			  number;
v_vac_taken					  number;
v_supervisor_name			  varchar2(50);
v_count						  number;
v_errmsg					  varchar2(200);
v_user_name					  varchar2(20);

/* Get all the employees for the current business Group*/
Cursor c_termed_employees is
select a.person_id,a.employee_number,a.full_name,b.assignment_id,
		   b.supervisor_id, c.date_start,c.actual_termination_date,c.accepted_termination_date,d.location_code
	from per_all_people_f a, per_all_assignments_f b, per_periods_of_service c,hr_locations d
	where a.person_id = b.person_id and a.person_id = c.person_id
	and a.person_type_id in (select person_type_id from per_person_types
						 	 where business_group_id = v_business_group_id and active_flag = 'Y'
							 and system_person_type in ('EX_EMP','EX_EMP_APL')
						 	 and default_flag = 'Y')
	and v_date between a.effective_start_Date and a.effective_end_date
	and v_date between b.effective_start_date and b.effective_end_date
	and b.primary_flag = 'Y' and c.actual_termination_date is not null
	and b.location_id = d.location_id
	and d.location_code = nvl(v_location_code,d.location_code)
	and c.actual_termination_date <= v_date;
						--and b.assignment_id = 31421					;
Begin
	v_date			:= report_date;
	v_user_name := fnd_global.user_name;
	if v_user_name is null then
	   v_user_name := 'TEST';
	end if;

	--delete from cust.termed_emp_vac_balance where user_name = v_user_name;			 -- Commented code by IXPRAVEEN-ARGANO,18-july-2023
	delete from apps.termed_emp_vac_balance where user_name = v_user_name;               --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
	commit;
	v_location_code := location_code;
	For bus_group in c_bus_group loop
		v_business_group_id := bus_group.business_group_id;
		v_count := 0;
    	v_location_code := location_code;
		For emp in c_termed_employees loop
			v_location_code := emp.location_code;
			--dbms_output.put_line('assignment_id '||emp.assignment_id);
			v_assignment_id := emp.assignment_id;
			/* Get which vacation plan is active for the employee as of the report date */
			v_vac_accrual_plan_id := null;
			v_accrual_plan := '%Vacation%Plan%';
			open c_accrual_plan;
			fetch c_accrual_plan into v_vac_accrual_plan_id;
			close c_accrual_plan;
			----dbms_output.put_line('After getting plans ');
			begin
				v_net_vac_accrual:= null;
			   /* Get net Vacation accrual balance */
				if v_vac_accrual_plan_id is not null then
					v_net_vac_accrual:=pay_us_pto_accrual.get_net_accrual
									 (P_assignment_id          => emp.assignment_id,
									  P_calculation_date       => v_date,
									  P_plan_id                => v_vac_accrual_plan_id);
				End if;
				v_errmsg := null;
				if v_net_vac_accrual > 0 then
					/* Get the vaction taken values */
					v_vac_taken  := get_value_for_accrual_plan(v_vac_accrual_plan_id ,emp.assignment_id);
				    --insert into cust.termed_emp_vac_balance			 -- Commented code by IXPRAVEEN-ARGANO,18-july-2023
				    insert into apps.termed_emp_vac_balance              --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
						(location_code 						 ,
						 emp_number 						 ,
						 Emp_name							 ,
						 termination_date					 ,
						 date_keyed							 ,
						 vac_allowed		 			 	 ,
						 vac_taken		 			 	 	 ,
						 vac_balance		 			 	 ,
						 Person_id				 			 ,
						 assignment_id			 			 ,
						 Report_date			 			 ,
						 User_name				 			 ,
						 business_group_id					 ,
						 errmsg
						 )
						 values
		               	(v_location_code				     ,
		                 emp.employee_number			 	 ,
		                 emp.full_name					 	 ,
						 emp.actual_termination_date		 ,
						 emp.accepted_termination_date		 ,
		                 v_net_vac_accrual  + v_vac_taken 	 ,
		                 v_vac_taken		 		     	 ,
		                 v_net_vac_accrual		 		 	 ,
		                 emp.Person_id			 		 	 ,
		                 emp.assignment_id		 		 	 ,
		                 v_date			 		 		 	 ,
		                 v_user_name					 	 ,
						 bus_group.business_group_id		 ,
						 v_errmsg
						);
				End if;
			exception
				when others then
					 v_errmsg := substr(sqlerrm,1,200);
				    --insert into cust.termed_emp_vac_balance			 -- Commented code by IXPRAVEEN-ARGANO,18-july-2023
				    insert into apps.termed_emp_vac_balance              --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
						(location_code 						 ,
						 emp_number 						 ,
						 Emp_name							 ,
						 termination_date					 ,
						 date_keyed							 ,
						 vac_allowed		 			 	 ,
						 vac_taken		 			 	 	 ,
						 vac_balance		 			 	 ,
						 Person_id				 			 ,
						 assignment_id			 			 ,
						 Report_date			 			 ,
						 User_name				 			 ,
						 business_group_id					 ,
						 errmsg
						 )
						 values
		               	(v_location_code				     ,
		                 emp.employee_number			 	 ,
		                 emp.full_name					 	 ,
						 emp.actual_termination_date		 ,
						 emp.accepted_termination_date		 ,
		                 v_net_vac_accrual  + v_vac_taken 	 ,
		                 v_vac_taken		 		     	 ,
		                 v_net_vac_accrual		 		 	 ,
		                 emp.Person_id			 		 	 ,
		                 emp.assignment_id		 		 	 ,
		                 v_date			 		 		 	 ,
		                 v_user_name					 	 ,
						 bus_group.business_group_id		 ,
						 v_errmsg
						);
			end;
			/*
			--dbms_output.put_line('Net Sick Accrual '||v_net_sick_accrual);
			--dbms_output.put_line('Net Vacation '||v_net_vac_accrual);
			--dbms_output.put_line('Sick Taken '||v_sick_taken);
			--dbms_output.put_line('va Taken '||v_vac_taken);
			*/
		End Loop;
	End Loop;
	commit;
end termed_emp_vac_balance;
PROCEDURE termed_emp_with_dd(location_code       IN   varchar2,
		  						  Report_date date) IS
v_vac_accrual_plan_id		  pay_accrual_plans.accrual_plan_id%type;
v_net_vac_accrual			  number;
v_vac_taken					  number;
v_supervisor_name			  varchar2(50);
v_count						  number;
v_errmsg					  varchar2(200);
v_user_name					  varchar2(20);
v_account1					  varchar2(10);
v_account2					  varchar2(10);
v_account3					  varchar2(10);
/* Get all the employees for the current business Group*/
Cursor c_termed_employees is
	select a.person_id,a.employee_number,a.full_name,b.assignment_id,
			   b.supervisor_id, c.date_start,c.actual_termination_date,c.accepted_termination_date,d.location_code
		from per_all_people_f a, per_all_assignments_f b, per_periods_of_service c, hr_locations d
		where a.person_id = b.person_id and a.person_id = c.person_id
		and a.person_type_id in (select person_type_id from per_person_types
							 	 where business_group_id = v_business_group_id and active_flag = 'Y'
								 and system_person_type in ('EX_EMP','EX_EMP_APL')
							 	 and default_flag = 'Y')
		and v_date between a.effective_start_Date and a.effective_end_date
		and v_date between b.effective_start_date and b.effective_end_date
		and b.primary_flag = 'Y' and c.actual_termination_date is not null
		and b.location_id = d.location_id and d.location_code = nvl(v_location_code,d.location_code)
		and c.actual_termination_date <= v_date    ;
		--and b.assignment_id = 35647					;
Cursor c_accounts is
	select decode(b.segment2,'C','Checking','Savings') name
	from pay_personal_payment_methods_f a, pay_external_accounts b
	where a.assignment_id = v_assignment_id
	and a.external_account_id = b.external_account_id
	and v_date between a.effective_start_date and a.effective_end_date;
Begin
	v_location_code := location_code;
	v_date			:= report_date;
	v_user_name := fnd_global.user_name;
	if v_user_name is null then
	   v_user_name := 'TEST';
	end if;
	--delete from cust.termed_emp_with_dd where user_name = v_user_name;			 -- Commented code by IXPRAVEEN-ARGANO,18-july-2023
	delete from apps.termed_emp_with_dd where user_name = v_user_name;               --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
	commit;

	For bus_group in c_bus_group loop
		v_business_group_id := bus_group.business_group_id;
		v_count := 0;
		v_location_code := location_code;
		For emp in c_termed_employees loop
			v_location_code := emp.location_code;
			--dbms_output.put_line('assignment_id '||emp.assignment_id);
			v_assignment_id := emp.assignment_id;
			v_count:=1;
			--dbms_output.put_line('before acc loop');
			For accs in c_accounts loop
				if v_count = 1 then
				   v_account1 := accs.name;
				elsif v_count = 2 then
				   v_account2 := accs.name;
				else
				   v_account3 := accs.name;
				end if;
				v_count := v_count + 1;
			end loop;
			if v_account1 is not null or v_Account2 is not null or v_account3 is not null then
			    --insert into cust.termed_emp_with_dd			 -- Commented code by IXPRAVEEN-ARGANO,18-july-2023
			    insert into apps.termed_emp_with_dd              --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
					(location_code 						 ,
					 emp_number 						 ,
					 Emp_name							 ,
					 termination_date					 ,
					 account1							 ,
					 account2							 ,
					 account3							 ,
					 Person_id				 			 ,
					 assignment_id			 			 ,
					 Report_date			 			 ,
					 User_name				 			 ,
					 business_group_id					 ,
					 errmsg
					 )
					 values
	               	(v_location_code				     ,
	                 emp.employee_number			 	 ,
	                 emp.full_name					 	 ,
					 emp.actual_termination_date		 ,
					 v_account1							 ,
					 v_account2							 ,
					 v_account3							 ,
	                 emp.Person_id			 		 	 ,
	                 emp.assignment_id		 		 	 ,
	                 v_date			 		 		 	 ,
	                 v_user_name					 	 ,
					 bus_group.business_group_id		 ,
					 v_errmsg
					);
			End If;
		End Loop;
	End Loop;
	commit;
end termed_emp_with_dd;

PROCEDURE check_recon(location_code       IN   varchar2,
		  						  Report_date date) IS

v_biweek_rate			  number;
v_legislation_code		  varchar2(20);
v_defined_balance_id	  number;
v_assignment_action_id			  number;
v_tax_unit_id			  number;
v_user_name				  varchar2(20);
v_amount				  number;
v_errmsg				  varchar2(200);
v_check_number			  varchar2(20);
v_count					  number:=0;
--v_payroll_id			  number;
/* Get all the employees for the current business Group*/
Cursor c_employees is
	select a.person_id,a.employee_number,a.full_name,b.assignment_id,
	   b.supervisor_id, b.employment_category, b.payroll_id,d.pay_annualization_factor,e.location_code
		from apps.per_all_people_f a, apps.per_all_assignments_f b, per_periods_of_service c, per_pay_bases d,hr_locations e
		where a.person_id = b.person_id and a.person_id = c.person_id
		and b.pay_basis_id = d.pay_basis_id --and d.pay_basis = 'HOURLY'
		and a.person_type_id in (select person_type_id from per_person_types
							 	 where business_group_id = v_business_group_id
								 and active_flag = 'Y'
								 and system_person_type in ('EMP','EMP_APL')
							 	 and default_flag = 'Y')
		and v_date between a.effective_start_Date and a.effective_end_date
		and v_date between b.effective_start_date and b.effective_end_date
		and b.primary_flag = 'Y'
		and b.location_id = e.location_id
		and e.location_code = nvl(v_location_code,e.location_code)
		--and a.person_id = 30418
		and c.date_start = (select max(date_start) from per_periods_of_service where person_id = a.person_id
						    and date_start <= v_date)
		and b.payroll_id is not null
		;--and b.payroll_id =45 ;

Begin
	v_location_code := location_code;
	v_date			:= report_date;
	v_user_name := fnd_global.user_name;
	if v_user_name is null then
	   v_user_name := 'TEST';
	end if;
	--delete from cust.check_recon where user_name = v_user_name;			 -- Commented code by IXPRAVEEN-ARGANO,18-july-2023
	delete from apps.check_recon where user_name = v_user_name;              --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
	commit;
			dbms_output.put_line('one');
	For bus_group in c_bus_group loop
		v_business_group_id := bus_group.business_group_id;

			dbms_output.put_line('two');
		/* Get the legislation code*/
		select org_information9 into v_legislation_code
		from hr_organization_information
		where org_information_context = 'Business Group Information' and organization_id = v_business_group_id;



		/* Get defined balance id */
		select defined_balance_id into v_defined_balance_id
		from pay_defined_balances where balance_type_id =
			 (select balance_type_id
			  from pay_balance_types
			  where balance_name = 'Gross Earnings'
			  and legislation_code = v_legislation_code)
		and balance_dimension_id =
			  (select balance_dimension_id
			  from pay_balance_dimensions
			  where database_item_suffix like '_ASG_GRE_PTD'
			  and legislation_code = v_legislation_code);

		v_location_code := location_code ;
		dbms_output.put_line('four');

		For emp in c_employees loop
			dbms_output.put_line('five'||emp.assignment_id);

			v_location_code := emp.location_code;
			Begin
				select round((c.proposed_salary_n*emp.pay_annualization_factor)/26,2)
				into v_biweek_rate
				from per_pay_proposals c
				where c.assignment_id = emp.assignment_id
				and c.change_date = (select max(change_date)
								  	 from per_pay_proposals
					   	    	     where assignment_id = emp.assignment_id
								     and change_date <= v_date);

				v_errmsg := null;

				begin

					v_amount := 0;

					/* Get assignment Action id
					select a.assignment_action_id,a.tax_unit_id,a.serial_number
					into v_assignment_action_id,v_tax_unit_id,v_check_number
					from pay_assignment_actions a, pay_payroll_actions b
					where a.payroll_action_id = b.payroll_Action_id
					and b.payroll_id = emp.payroll_id
					and a.assignment_id = emp.assignment_id
					and b.time_period_id in
					(select time_period_id from per_time_periods
										    where payroll_id = emp.payroll_id
										   	and v_date between start_date and end_date
											)
					and b.action_type in ('Q','R','O')
					and source_action_id is null and rownum < 2;*/

					select max(a.assignment_action_id),a.tax_unit_id,a.serial_number
					into v_assignment_action_id,v_tax_unit_id,v_check_number
					from pay_assignment_actions a, pay_payroll_actions b
					where a.payroll_action_id = b.payroll_Action_id
					--and a.chunk_number = b.current_chunk_number
					and b.payroll_id = emp.payroll_id
					and a.assignment_id = emp.assignment_id
					and b.time_period_id in
					(select time_period_id from per_time_periods
										    where payroll_id = emp.payroll_id
										   	and v_date between start_date and end_date
											)
					and b.action_type in ('Q','R','O')
					group by a.tax_unit_id,a.serial_number;

					--and source_action_id is null and rownum < 2;


					pay_balance_pkg.set_context('TAX_UNIT_ID',v_tax_unit_id);
					pay_balance_pkg.set_context('BUSINESS_GROUP_ID',v_business_group_id);
					v_amount := pay_balance_pkg.get_value
		                       ( p_defined_balance_id   => v_defined_balance_id,
		                         p_assignment_action_id => v_assignment_action_id);

					v_errmsg := null;

				exception
					when others then
						 v_amount := 0;
						 v_errmsg	:= 'Assignment Action id not found';
				end;

			Exception
				When others then
					 v_errmsg := 'No pay proposal for the specified date';
			end;

		    --insert into cust.check_recon			 -- Commented code by IXPRAVEEN-ARGANO,18-july-2023
		    insert into apps.check_recon             --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
				(location_code 						 ,
				 Emp_name							 ,
				 check_number						 ,
				 gross_pay							 ,
				 Biweek_rate						 ,
				 Person_id				 			 ,
				 assignment_id			 			 ,
				 Report_date			 			 ,
				 User_name				 			 ,
				 business_group_id					 ,
				 difference							 ,
				 errmsg
				 )
				 values
               	(v_location_code				     ,
                 emp.full_name					 	 ,
				 v_check_number						 ,
				 v_amount		 					 ,
				 v_biweek_rate 						 ,
                 emp.Person_id			 		 	 ,
                 emp.assignment_id		 		 	 ,
                 v_date			 		 		 	 ,
                 v_user_name					 	 ,
				 bus_group.business_group_id		 ,
				 v_amount-v_biweek_rate			 ,
				 v_errmsg
				);
			v_count:=v_count+1;
			if mod(v_count,50) = 0 then
			   commit;
			end if;

		End Loop;
	End Loop;
	commit;
end check_recon;
PROCEDURE check_recon_new(location_code       IN   varchar2,
		  						  Report_date date) IS

v_biweek_rate			number;
v_date					date;
v_Assignment_id			number;
--v_payroll_id			  number;
/* Get all the employees for the current business Group*/
Cursor c_emp is
	select a.business_group_id,a.person_id,a.employee_number,a.full_name,b.assignment_id,
	           b.supervisor_id, b.employment_category, b.payroll_id,d.pay_annualization_factor,e.location_code,
			   f.org_information9 legislation_code, g.defined_balance_id
		from apps.per_all_people_f a, apps.per_all_assignments_f b,
			 per_periods_of_service c, per_pay_bases d,hr_locations e,
			 hr_organization_information f, pay_defined_balances g
		where a.person_id = b.person_id and a.person_id = c.person_id
		and b.pay_basis_id = d.pay_basis_id --and d.pay_basis = 'HOURLY'
		and a.person_type_id in (select person_type_id from per_person_types
							 	 where business_group_id = a.business_group_id
								 and active_flag = 'Y'
								 and system_person_type in ('EMP','EMP_APL')
							 	 and default_flag = 'Y')
		and v_date between a.effective_start_Date and a.effective_end_date
		and v_date between b.effective_start_date and b.effective_end_date
		and b.primary_flag = 'Y'
		and b.location_id = e.location_id
		and b.assignment_id = v_Assignment_id
		and c.date_start = (select max(date_start) from per_periods_of_service where person_id = a.person_id
						    and date_start <= v_date)
		and b.payroll_id is not null
		and f.org_information_context = 'Business Group Information'
		and f.organization_id = a.business_group_id
		and g.balance_type_id =
			 (select balance_type_id
			  from pay_balance_types
			  where balance_name = 'Gross Earnings'
			  and legislation_code = f.org_information9)
		and balance_dimension_id =
			  (select balance_dimension_id
			  from pay_balance_dimensions
			  where database_item_suffix like '_ASG_RUN'
			  and legislation_code = f.org_information9);
Cursor c_checks is

	   select a.assignment_action_id,b.effective_date,a.serial_number,a.tax_unit_id,a.assignment_id
	    from pay_assignment_actions a, pay_payroll_Actions b
	   		  where a.serial_number is not null
				and action_type = 'H'
				and a.payroll_Action_id = b.payroll_action_id
				and b.effective_date = v_date;

v_Assignment_action_id				 number;
v_amount							 number;
v_user_name							 varchar2(20);
v_count								 number:=0;
v_errmsg					  varchar2(200);
v_location_code				  varchar2(50);

Begin
	v_user_name := fnd_global.user_name;
	if v_user_name is null then
	   v_user_name := 'TEST';
	end if;
--delete from cust.check_recon where user_name = v_user_name;		 -- Commented code by IXPRAVEEN-ARGANO,18-july-2023
delete from apps.check_recon where user_name = v_user_name;          --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
commit;
v_date := report_date;
v_location_code := location_code;
For chk in c_checks loop
		select max(locked_action_id) into v_assignment_action_id
		from pay_action_interlocks
		   where locking_Action_id = (select max(locked_action_id) from pay_action_interlocks
				    			   	  where locking_action_id = chk.assignment_action_id);

		v_assignment_id := chk.assignment_id;

		for emp in c_emp loop
			if nvl(v_location_code,emp.location_code) = emp.location_code then
				pay_balance_pkg.set_context('TAX_UNIT_ID',chk.tax_unit_id);
				pay_balance_pkg.set_context('BUSINESS_GROUP_ID',emp.business_group_id);
				v_amount := pay_balance_pkg.get_value
		                      ( p_defined_balance_id   => emp.defined_balance_id,
		                        p_assignment_action_id => v_assignment_action_id);

					begin
						select round((c.proposed_salary_n*emp.pay_annualization_factor)/26,2)
						into v_biweek_rate
						from per_pay_proposals c
						where c.assignment_id = emp.assignment_id
						and c.change_date = (select max(change_date)
										  	 from per_pay_proposals
							   	    	     where assignment_id = emp.assignment_id
										     and change_date <= v_date);
					exception
						when others then
							 v_biweek_rate := 0;
					end;

			    --insert into cust.check_recon				 -- Commented code by IXPRAVEEN-ARGANO,18-july-2023
			    insert into apps.check_recon                 --  code Added by IXPRAVEEN-ARGANO,   18-july-2023
					(location_code 						 ,
					 Emp_name							 ,
					 check_number						 ,
					 gross_pay							 ,
					 Biweek_rate						 ,
					 Person_id				 			 ,
					 assignment_id			 			 ,
					 Report_date			 			 ,
					 User_name				 			 ,
					 business_group_id					 ,
					 difference							 ,
					 errmsg
					 )
					 values
	               	(emp.location_code				     ,
	                 emp.full_name					 	 ,
					 chk.serial_number						 ,
					 v_amount		 					 ,
					 v_biweek_rate 						 ,
	                 emp.Person_id			 		 	 ,
	                 emp.assignment_id		 		 	 ,
	                 v_date			 		 		 	 ,
	                 v_user_name					 	 ,
					 emp.business_group_id		         ,
					 v_amount-v_biweek_rate 			 ,
					 v_errmsg
					);

				v_count:=v_count+1;
				if mod(v_count,50) = 0 then
				   commit;
				end if;
			End if;
		end loop;
	end Loop;
	commit;
end check_recon_new;

END CUST_ACCRUAL_REPORTS;
/
show errors;
/