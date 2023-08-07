create or replace PACKAGE BODY      ttec_arg_intf_util AS

/*------------------------------------------------------------------------
Module Name:   apps.ttec_arg_intf_util
Description:   This package specification contains utility program units
		required for the Argentina Payroll Outbound Interface.
Version:       1.0
Author:        Vijay Mayadam - Consultant
Date created:	18-Jan-2005
Modification History:
--------------------------------------------------------------------------
Author     Date                  Version  Change Description
-------------------------------------------------------------------------*/


Function Record_Changed_V (P_Column_Name IN VARCHAR2,
			 P_Person_Id IN NUMBER,
			 P_Assignment_Id IN NUMBER,
			 P_g_sysdate IN DATE) RETURN VARCHAR2 IS

CURSOR attribute12_cur IS

Select nvl(a.attribute12,'X') from
	(  	Select trunc(cut_off_date), curr.attribute12
  	From
		--	cust.ttec_arg_pay_interface_mst curr --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.person_id = p_person_id
	and curr.assignment_id = p_assignment_id
	and trunc(curr.cut_off_date) = p_g_sysdate
Union
  	Select trunc(cut_off_date), past.attribute12
  	From
		--	cust.ttec_arg_pay_interface_mst past --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.person_id = p_person_id
	and past.assignment_id = p_assignment_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from   cust.ttec_arg_pay_interface_mst --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from   apps.ttec_arg_pay_interface_mst --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where  person_id = p_person_id
						and    assignment_id = p_assignment_id
						and    trunc(cut_off_date) < p_g_sysdate)
	) a;


CURSOR marital_status_cursor IS

Select nvl(a.marital_status,'X') from
	(  	Select trunc(cut_off_date), curr.marital_status
  	From
		--	cust.ttec_arg_pay_interface_mst curr --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.person_id = p_person_id
	and curr.assignment_id = p_assignment_id
	and trunc(curr.cut_off_date) = p_g_sysdate
Union
  	Select trunc(cut_off_date), past.marital_status
  	From
		--	cust.ttec_arg_pay_interface_mst past --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.person_id = p_person_id
	and past.assignment_id = p_assignment_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from   cust.ttec_arg_pay_interface_mst --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from   apps.ttec_arg_pay_interface_mst --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where  person_id = p_person_id
						and    assignment_id = p_assignment_id
						and    trunc(cut_off_date) < p_g_sysdate)
	) a;


CURSOR last_name_cur IS

Select nvl(a.last_name,'X') from
	(  	Select trunc(cut_off_date), curr.last_name
  	From
		--	cust.ttec_arg_pay_interface_mst curr --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.person_id = p_person_id
	and curr.assignment_id = p_assignment_id
	and trunc(curr.cut_off_date) = p_g_sysdate
Union
  	Select trunc(cut_off_date), past.last_name
  	From
		--	cust.ttec_arg_pay_interface_mst past --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.person_id = p_person_id
	and past.assignment_id = p_assignment_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from   cust.ttec_arg_pay_interface_mst --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from   apps.ttec_arg_pay_interface_mst --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where  person_id = p_person_id
						and    assignment_id = p_assignment_id
						and    trunc(cut_off_date) < p_g_sysdate)
	) a;


CURSOR first_name_cur IS

Select nvl(a.first_name,'X') from
	(  	Select trunc(cut_off_date), curr.first_name
  	From
		--	cust.ttec_arg_pay_interface_mst curr --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.person_id = p_person_id
	and curr.assignment_id = p_assignment_id
	and trunc(curr.cut_off_date) = p_g_sysdate
Union
  	Select trunc(cut_off_date), past.first_name
  	From
		--	cust.ttec_arg_pay_interface_mst past --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.person_id = p_person_id
	and past.assignment_id = p_assignment_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from   cust.ttec_arg_pay_interface_mst --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from   apps.ttec_arg_pay_interface_mst --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where  person_id = p_person_id
						and    assignment_id = p_assignment_id
						and    trunc(cut_off_date) < p_g_sysdate)
	) a;


CURSOR middle_names_cur IS
Select nvl(a.middle_names,'X') from
	(  	Select trunc(cut_off_date), curr.middle_names
  	From
		--	cust.ttec_arg_pay_interface_mst curr --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.person_id = p_person_id
	and curr.assignment_id = p_assignment_id
	and trunc(curr.cut_off_date) = p_g_sysdate
Union
  	Select trunc(cut_off_date), past.middle_names
  	From
		--	cust.ttec_arg_pay_interface_mst past --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.person_id = p_person_id
	and past.assignment_id = p_assignment_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from   cust.ttec_arg_pay_interface_mst --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from   apps.ttec_arg_pay_interface_mst --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where  person_id = p_person_id
						and    assignment_id = p_assignment_id
						and    trunc(cut_off_date) < p_g_sysdate)
	) a;


CURSOR national_identifier_cur IS
Select nvl(a.national_identifier,'X') from
	(  	Select trunc(cut_off_date), curr.national_identifier
  	From
		--	cust.ttec_arg_pay_interface_mst curr --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.person_id = p_person_id
	and curr.assignment_id = p_assignment_id
	and trunc(curr.cut_off_date) = p_g_sysdate
Union
  	Select trunc(cut_off_date), past.national_identifier
  	From
		--	cust.ttec_arg_pay_interface_mst past --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.person_id = p_person_id
	and past.assignment_id = p_assignment_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from   cust.ttec_arg_pay_interface_mst --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from   apps.ttec_arg_pay_interface_mst --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where  person_id = p_person_id
						and    assignment_id = p_assignment_id
						and    trunc(cut_off_date) < p_g_sysdate)
	) a;


CURSOR gender_cur IS
Select nvl(a.sex,'X') from
	(  	Select trunc(cut_off_date), curr.sex
  	From
		--	cust.ttec_arg_pay_interface_mst curr --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.person_id = p_person_id
	and curr.assignment_id = p_assignment_id
	and trunc(curr.cut_off_date) = p_g_sysdate
Union
  	Select trunc(cut_off_date), past.sex
  	From
		--	cust.ttec_arg_pay_interface_mst past --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.person_id = p_person_id
	and past.assignment_id = p_assignment_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from   cust.ttec_arg_pay_interface_mst --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from   apps.ttec_arg_pay_interface_mst --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where  person_id = p_person_id
						and    assignment_id = p_assignment_id
						and    trunc(cut_off_date) < p_g_sysdate)
	) a;


CURSOR per_attribute6_cur IS
Select nvl(a.attribute6,'X') from
	(  	Select trunc(cut_off_date), curr.attribute6
  	From
		--	cust.ttec_arg_pay_interface_mst curr --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.person_id = p_person_id
	and curr.assignment_id = p_assignment_id
	and trunc(curr.cut_off_date) = p_g_sysdate
Union
  	Select trunc(cut_off_date), past.attribute6
  	From
		--	cust.ttec_arg_pay_interface_mst past --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.person_id = p_person_id
	and past.assignment_id = p_assignment_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from   cust.ttec_arg_pay_interface_mst --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from   apps.ttec_arg_pay_interface_mst --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where  person_id = p_person_id
						and    assignment_id = p_assignment_id
						and    trunc(cut_off_date) < p_g_sysdate)
	) a;


CURSOR per_attribute7_cur IS
Select nvl(a.attribute7,'X') from
	(  	Select trunc(cut_off_date), curr.attribute7
  	From
		--	cust.ttec_arg_pay_interface_mst curr --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.person_id = p_person_id
	and curr.assignment_id = p_assignment_id
	and trunc(curr.cut_off_date) = p_g_sysdate
Union
  	Select trunc(cut_off_date), past.attribute7
  	From
		--	cust.ttec_arg_pay_interface_mst past --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.person_id = p_person_id
	and past.assignment_id = p_assignment_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from   cust.ttec_arg_pay_interface_mst --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from   apps.ttec_arg_pay_interface_mst --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where  person_id = p_person_id
						and    assignment_id = p_assignment_id
						and    trunc(cut_off_date) < p_g_sysdate)
	) a;

CURSOR cost_segment2_cur IS
Select nvl(a.cost_segment2,'X') from
	(  	Select trunc(cut_off_date), curr.cost_segment2
  	From
		--	cust.ttec_arg_pay_interface_mst curr --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.person_id = p_person_id
	and curr.assignment_id = p_assignment_id
	and trunc(curr.cut_off_date) = p_g_sysdate
Union
  	Select trunc(cut_off_date), past.cost_segment2
  	From
		--	cust.ttec_arg_pay_interface_mst past --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.person_id = p_person_id
	and past.assignment_id = p_assignment_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from   cust.ttec_arg_pay_interface_mst --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from   apps.ttec_arg_pay_interface_mst --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where  person_id = p_person_id
						and    assignment_id = p_assignment_id
						and    trunc(cut_off_date) < p_g_sysdate)
	) a;

CURSOR cost_segment3_cur IS
Select nvl(a.cost_segment3,'X') from
	(  	Select trunc(cut_off_date), curr.cost_segment3
  	From
		--	cust.ttec_arg_pay_interface_mst curr --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.person_id = p_person_id
	and curr.assignment_id = p_assignment_id
	and trunc(curr.cut_off_date) = p_g_sysdate
Union
  	Select trunc(cut_off_date), past.cost_segment3
  	From
		--	cust.ttec_arg_pay_interface_mst past --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.person_id = p_person_id
	and past.assignment_id = p_assignment_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from   cust.ttec_arg_pay_interface_mst --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from   apps.ttec_arg_pay_interface_mst --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where  person_id = p_person_id
						and    assignment_id = p_assignment_id
						and    trunc(cut_off_date) < p_g_sysdate)
	) a;

CURSOR job_segment1_cur IS
Select nvl(a.job_segment1,'X') from
	(  	Select trunc(cut_off_date), curr.job_segment1
  	From
		--	cust.ttec_arg_pay_interface_mst curr --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.person_id = p_person_id
	and curr.assignment_id = p_assignment_id
	and trunc(curr.cut_off_date) = p_g_sysdate
Union
  	Select trunc(cut_off_date), past.job_segment1
  	From
		--	cust.ttec_arg_pay_interface_mst past --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.person_id = p_person_id
	and past.assignment_id = p_assignment_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from   cust.ttec_arg_pay_interface_mst --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from   apps.ttec_arg_pay_interface_mst --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where  person_id = p_person_id
						and    assignment_id = p_assignment_id
						and    trunc(cut_off_date) < p_g_sysdate)
	) a;

CURSOR pay_method_name_cur IS
Select nvl(a.org_payment_method_name,'X') from
	(  	Select trunc(cut_off_date), curr.org_payment_method_name
  	From
		--	cust.ttec_arg_pay_interface_mst curr --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.person_id = p_person_id
	and curr.assignment_id = p_assignment_id
	and trunc(curr.cut_off_date) = p_g_sysdate
Union
  	Select trunc(cut_off_date), past.org_payment_method_name
  	From
		--	cust.ttec_arg_pay_interface_mst past --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.person_id = p_person_id
	and past.assignment_id = p_assignment_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from   cust.ttec_arg_pay_interface_mst --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from   apps.ttec_arg_pay_interface_mst --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where  person_id = p_person_id
						and    assignment_id = p_assignment_id
						and    trunc(cut_off_date) < p_g_sysdate)
	) a;

CURSOR pay_method_segment1_cur IS
Select nvl(a.pea_segment1,'X') from
	(  	Select trunc(cut_off_date), curr.pea_segment1
  	From
		--	cust.ttec_arg_pay_interface_mst curr --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.person_id = p_person_id
	and curr.assignment_id = p_assignment_id
	and trunc(curr.cut_off_date) = p_g_sysdate
Union
  	Select trunc(cut_off_date), past.pea_segment1
  	From
		--	cust.ttec_arg_pay_interface_mst past --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.person_id = p_person_id
	and past.assignment_id = p_assignment_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from   cust.ttec_arg_pay_interface_mst --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from   apps.ttec_arg_pay_interface_mst --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where  person_id = p_person_id
						and    assignment_id = p_assignment_id
						and    trunc(cut_off_date) < p_g_sysdate)
	) a;

CURSOR pay_method_segment3_cur IS
Select nvl(a.pea_segment3,'X') from
	(  	Select trunc(cut_off_date), curr.pea_segment3
  	From
		--	cust.ttec_arg_pay_interface_mst curr --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.person_id = p_person_id
	and curr.assignment_id = p_assignment_id
	and trunc(curr.cut_off_date) = p_g_sysdate
Union
  	Select trunc(cut_off_date), past.pea_segment3
  	From
		--	cust.ttec_arg_pay_interface_mst past --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.person_id = p_person_id
	and past.assignment_id = p_assignment_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from   cust.ttec_arg_pay_interface_mst --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from   apps.ttec_arg_pay_interface_mst --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where  person_id = p_person_id
						and    assignment_id = p_assignment_id
						and    trunc(cut_off_date) < p_g_sysdate)
	) a;

CURSOR pay_method_segment4_cur IS
Select nvl(a.pea_segment4,'X') from
	(  	Select trunc(cut_off_date), curr.pea_segment4
  	From
		--	cust.ttec_arg_pay_interface_mst curr --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.person_id = p_person_id
	and curr.assignment_id = p_assignment_id
	and trunc(curr.cut_off_date) = p_g_sysdate
Union
  	Select trunc(cut_off_date), past.pea_segment4
  	From
		--	cust.ttec_arg_pay_interface_mst past --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.person_id = p_person_id
	and past.assignment_id = p_assignment_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from   cust.ttec_arg_pay_interface_mst --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from   apps.ttec_arg_pay_interface_mst --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where  person_id = p_person_id
						and    assignment_id = p_assignment_id
						and    trunc(cut_off_date) < p_g_sysdate)
	) a;

CURSOR ass_attribute8_cur IS
Select nvl(a.ass_attribute8,'X') from
	(  	Select trunc(cut_off_date), curr.ass_attribute8
  	From
		--	cust.ttec_arg_pay_interface_mst curr --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.person_id = p_person_id
	and curr.assignment_id = p_assignment_id
	and trunc(curr.cut_off_date) = p_g_sysdate
Union
  	Select trunc(cut_off_date), past.ass_attribute8
  	From
		--	cust.ttec_arg_pay_interface_mst past --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.person_id = p_person_id
	and past.assignment_id = p_assignment_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from   cust.ttec_arg_pay_interface_mst --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from   apps.ttec_arg_pay_interface_mst --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where  person_id = p_person_id
						and    assignment_id = p_assignment_id
						and    trunc(cut_off_date) < p_g_sysdate)
	) a;

CURSOR ass_attribute7_cur IS
Select nvl(a.ass_attribute7,'X') from
	(  	Select trunc(cut_off_date), curr.ass_attribute7
  	From
		--	cust.ttec_arg_pay_interface_mst curr --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.person_id = p_person_id
	and curr.assignment_id = p_assignment_id
	and trunc(curr.cut_off_date) = p_g_sysdate
Union
  	Select trunc(cut_off_date), past.ass_attribute7
  	From
		--	cust.ttec_arg_pay_interface_mst past --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.person_id = p_person_id
	and past.assignment_id = p_assignment_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from   cust.ttec_arg_pay_interface_mst --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from   apps.ttec_arg_pay_interface_mst --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where  person_id = p_person_id
						and    assignment_id = p_assignment_id
						and    trunc(cut_off_date) < p_g_sysdate)
	) a;

CURSOR ass_attribute9_cur IS
Select nvl(a.ass_attribute9,'X') from
	(  	Select trunc(cut_off_date), curr.ass_attribute9
  	From
		--	cust.ttec_arg_pay_interface_mst curr --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.person_id = p_person_id
	and curr.assignment_id = p_assignment_id
	and trunc(curr.cut_off_date) = p_g_sysdate
Union
  	Select trunc(cut_off_date), past.ass_attribute9
  	From
		--	cust.ttec_arg_pay_interface_mst past --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.person_id = p_person_id
	and past.assignment_id = p_assignment_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from   cust.ttec_arg_pay_interface_mst --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from   apps.ttec_arg_pay_interface_mst --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where  person_id = p_person_id
						and    assignment_id = p_assignment_id
						and    trunc(cut_off_date) < p_g_sysdate)
	) a;

CURSOR ass_attribute10_cur IS
Select nvl(a.ass_attribute10,'X') from
	(  	Select trunc(cut_off_date), curr.ass_attribute10
  	From
		--	cust.ttec_arg_pay_interface_mst curr --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.person_id = p_person_id
	and curr.assignment_id = p_assignment_id
	and trunc(curr.cut_off_date) = p_g_sysdate
Union
  	Select trunc(cut_off_date), past.ass_attribute10
  	From
		--	cust.ttec_arg_pay_interface_mst past --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.person_id = p_person_id
	and past.assignment_id = p_assignment_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from   cust.ttec_arg_pay_interface_mst --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from   apps.ttec_arg_pay_interface_mst --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where  person_id = p_person_id
						and    assignment_id = p_assignment_id
						and    trunc(cut_off_date) < p_g_sysdate)
	) a;

CURSOR ass_attribute11_cur IS
Select nvl(a.ass_attribute11,'X') from
	(  	Select trunc(cut_off_date), curr.ass_attribute11
  	From
		--	cust.ttec_arg_pay_interface_mst curr --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.person_id = p_person_id
	and curr.assignment_id = p_assignment_id
	and trunc(curr.cut_off_date) = p_g_sysdate
Union
  	Select trunc(cut_off_date), past.ass_attribute11
  	From
		--	cust.ttec_arg_pay_interface_mst past --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.person_id = p_person_id
	and past.assignment_id = p_assignment_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from   cust.ttec_arg_pay_interface_mst --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from   apps.ttec_arg_pay_interface_mst --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where  person_id = p_person_id
						and    assignment_id = p_assignment_id
						and    trunc(cut_off_date) < p_g_sysdate)
	) a;

CURSOR ass_attribute12_cur IS
Select nvl(a.ass_attribute12,'X') from
	(  	Select trunc(cut_off_date), curr.ass_attribute12
  	From
		--	cust.ttec_arg_pay_interface_mst curr --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.person_id = p_person_id
	and curr.assignment_id = p_assignment_id
	and trunc(curr.cut_off_date) = p_g_sysdate
Union
  	Select trunc(cut_off_date), past.ass_attribute12
  	From
		--	cust.ttec_arg_pay_interface_mst past --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.person_id = p_person_id
	and past.assignment_id = p_assignment_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from   cust.ttec_arg_pay_interface_mst --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from   apps.ttec_arg_pay_interface_mst --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where  person_id = p_person_id
						and    assignment_id = p_assignment_id
						and    trunc(cut_off_date) < p_g_sysdate)
	) a;

CURSOR pei_attribute1_cur IS
Select nvl(a.pei_attribute1,'X') from
	(  	Select trunc(cut_off_date), curr.pei_attribute1
  	From
		--	cust.ttec_arg_pay_interface_mst curr --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.person_id = p_person_id
	and curr.assignment_id = p_assignment_id
	and trunc(curr.cut_off_date) = p_g_sysdate
Union
  	Select trunc(cut_off_date), past.pei_attribute1
  	From
		--	cust.ttec_arg_pay_interface_mst past --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.person_id = p_person_id
	and past.assignment_id = p_assignment_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from   cust.ttec_arg_pay_interface_mst --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from   apps.ttec_arg_pay_interface_mst --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where  person_id = p_person_id
						and    assignment_id = p_assignment_id
						and    trunc(cut_off_date) < p_g_sysdate)
	) a;

CURSOR contract_type_cur IS
Select nvl(a.contract_type,'X') from
	(  	Select trunc(cut_off_date), curr.contract_type
  	From
		--	cust.ttec_arg_pay_interface_mst curr --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.person_id = p_person_id
	and curr.assignment_id = p_assignment_id
	and trunc(curr.cut_off_date) = p_g_sysdate
Union
  	Select trunc(cut_off_date), past.contract_type
  	From
		--	cust.ttec_arg_pay_interface_mst past --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.person_id = p_person_id
	and past.assignment_id = p_assignment_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from   cust.ttec_arg_pay_interface_mst --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from   apps.ttec_arg_pay_interface_mst --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where  person_id = p_person_id
						and    assignment_id = p_assignment_id
						and    trunc(cut_off_date) < p_g_sysdate)
	) a;


CURSOR system_person_type_cur IS
Select nvl(a.system_person_type,'X') from
	(  	Select trunc(cut_off_date), curr.system_person_type
  	From
		--	cust.ttec_arg_pay_interface_mst curr --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.person_id = p_person_id
	and curr.assignment_id = p_assignment_id
	and trunc(curr.cut_off_date) = p_g_sysdate
Union
  	Select trunc(cut_off_date), past.system_person_type
  	From
		--	cust.ttec_arg_pay_interface_mst past --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.person_id = p_person_id
	and past.assignment_id = p_assignment_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from   cust.ttec_arg_pay_interface_mst --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from   apps.ttec_arg_pay_interface_mst --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where  person_id = p_person_id
						and    assignment_id = p_assignment_id
						and    trunc(cut_off_date) < p_g_sysdate)
	) a;

CURSOR rehire_cur IS
Select nvl(a.system_person_type,'X') from
	(  	Select trunc(cut_off_date), curr.system_person_type
  	From
		--	cust.ttec_arg_pay_interface_mst curr --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.person_id = p_person_id
--	and curr.assignment_id = p_assignment_id
	and trunc(curr.cut_off_date) = p_g_sysdate
	and curr.system_person_type = 'EMP'
Union
  	Select trunc(cut_off_date), past.system_person_type
  	From
		--	cust.ttec_arg_pay_interface_mst past --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.person_id = p_person_id
--	and past.assignment_id = p_assignment_id
	and past.system_person_type = 'EX_EMP'
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from   cust.ttec_arg_pay_interface_mst --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from   apps.ttec_arg_pay_interface_mst --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where  person_id = p_person_id
--						and    assignment_id = p_assignment_id
						and    trunc(cut_off_date) < p_g_sysdate)
	) a;


CURSOR relationship_dep_cursor IS

Select nvl(a.relationship,'NO_REL') from
	(  	Select trunc(cut_off_date), curr.relationship
  	From
		--cust.ttec_arg_pay_interface_dep curr--Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_dep curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.contact_relationship_id=p_person_id
	and trunc(curr.cut_off_date) = p_g_sysdate

Union

  	Select trunc(cut_off_date), past.relationship
  	From
		--cust.ttec_arg_pay_interface_dep past--Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_dep past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.contact_relationship_id=p_person_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from cust.ttec_arg_pay_interface_dep --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from apps.ttec_arg_pay_interface_dep  --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where contact_relationship_id=p_person_id
						and  trunc(cut_off_date) < p_g_sysdate)
	)a;

CURSOR rel_last_name_dep_cursor IS
Select nvl(a.last_name,'X') from
	(  	Select trunc(cut_off_date), curr.last_name
  	From
		--cust.ttec_arg_pay_interface_dep curr--Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_dep curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.contact_relationship_id=p_person_id
	and trunc(curr.cut_off_date) = p_g_sysdate

Union

  	Select trunc(cut_off_date), past.last_name
  	From
		--cust.ttec_arg_pay_interface_dep past--Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_dep past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.contact_relationship_id=p_person_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from cust.ttec_arg_pay_interface_dep --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from apps.ttec_arg_pay_interface_dep  --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where contact_relationship_id=p_person_id
						and  trunc(cut_off_date) < p_g_sysdate)
	)a;

CURSOR rel_first_name_dep_cursor IS
Select nvl(a.first_name,'X') from
	(  	Select trunc(cut_off_date), curr.first_name
  	From
		--cust.ttec_arg_pay_interface_dep curr--Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_dep curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.contact_relationship_id=p_person_id
	and trunc(curr.cut_off_date) = p_g_sysdate

Union

  	Select trunc(cut_off_date), past.first_name
  	From
		--cust.ttec_arg_pay_interface_dep past--Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_dep past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.contact_relationship_id=p_person_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from cust.ttec_arg_pay_interface_dep --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from apps.ttec_arg_pay_interface_dep  --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where contact_relationship_id=p_person_id
						and  trunc(cut_off_date) < p_g_sysdate)
	)a;

CURSOR rel_middle_names_dep_cursor IS
Select nvl(a.middle_names,'X') from
	(  	Select trunc(cut_off_date), curr.middle_names
  	From
		--cust.ttec_arg_pay_interface_dep curr--Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_dep curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.contact_relationship_id=p_person_id
	and trunc(curr.cut_off_date) = p_g_sysdate

Union

  	Select trunc(cut_off_date), past.middle_names
  	From
		--cust.ttec_arg_pay_interface_dep past--Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_dep past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.contact_relationship_id=p_person_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from cust.ttec_arg_pay_interface_dep --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from apps.ttec_arg_pay_interface_dep  --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where contact_relationship_id=p_person_id
						and  trunc(cut_off_date) < p_g_sysdate)
	)a;

CURSOR rel_document_type_dep_cursor IS
Select nvl(a.document_type,'X') from
	(  	Select trunc(cut_off_date), curr.document_type
  	From
		--cust.ttec_arg_pay_interface_dep curr--Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_dep curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.contact_relationship_id=p_person_id
	and trunc(curr.cut_off_date) = p_g_sysdate

Union

  	Select trunc(cut_off_date), past.document_type
  	From
		--cust.ttec_arg_pay_interface_dep past--Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_dep past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.contact_relationship_id=p_person_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from cust.ttec_arg_pay_interface_dep --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from apps.ttec_arg_pay_interface_dep  --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where contact_relationship_id=p_person_id
						and  trunc(cut_off_date) < p_g_sysdate)
	)a;


CURSOR rel_document_number_dep_cursor IS
Select nvl(a.document_number,'X') from
	(  	Select trunc(cut_off_date), curr.document_number
  	From
		--cust.ttec_arg_pay_interface_dep curr--Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_dep curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.contact_relationship_id=p_person_id
	and trunc(curr.cut_off_date) = p_g_sysdate

Union

  	Select trunc(cut_off_date), past.document_number
  	From
		--cust.ttec_arg_pay_interface_dep past--Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_dep past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.contact_relationship_id=p_person_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from cust.ttec_arg_pay_interface_dep --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from apps.ttec_arg_pay_interface_dep  --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where contact_relationship_id=p_person_id
						and  trunc(cut_off_date) < p_g_sysdate)
	)a;


CURSOR rel_scholastic_info_dep_cursor IS
Select nvl(a.scholastic_info,'X') from
	(  	Select trunc(cut_off_date), curr.scholastic_info
  	From
		--cust.ttec_arg_pay_interface_dep curr--Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_dep curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.contact_relationship_id=p_person_id
	and trunc(curr.cut_off_date) = p_g_sysdate

Union

  	Select trunc(cut_off_date), past.scholastic_info
  	From
		--cust.ttec_arg_pay_interface_dep past--Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_dep past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.contact_relationship_id=p_person_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from cust.ttec_arg_pay_interface_dep --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from apps.ttec_arg_pay_interface_dep  --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where contact_relationship_id=p_person_id
						and  trunc(cut_off_date) < p_g_sysdate)
	)a;





i binary_integer :=0;

l_v_index binary_integer;
l_v_value_to_compare varchar2(240);


TYPE v_rectabtype IS TABLE OF varchar2(240) index by binary_integer;
v_records_table v_rectabtype;


l_record_changed VARCHAR2(1) := 'N';

l_v_record_count NUMBER :=0;


BEGIN

 IF

  p_column_name = 'MARITAL_STATUS' THEN

    OPEN marital_status_cursor;
    LOOP

	i := i+1;
       FETCH marital_status_cursor INTO v_records_table(i);
	       EXIT WHEN marital_status_cursor%NOTFOUND;
    END LOOP;


 ELSIF p_column_name = 'ATTRIBUTE12' THEN

    OPEN attribute12_cur;
    LOOP

	i := i+1;
       FETCH attribute12_cur INTO v_records_table(i);
	       EXIT WHEN attribute12_cur%NOTFOUND;
    END LOOP;


 ELSIF p_column_name = 'LAST_NAME' THEN

    OPEN last_name_cur;
    LOOP
	       EXIT WHEN last_name_cur%NOTFOUND;
	i := i+1;
       FETCH last_name_cur INTO v_records_table(i);

    END LOOP;



ELSIF p_column_name = 'FIRST_NAME' THEN

    OPEN first_name_cur;
    LOOP
	       EXIT WHEN first_name_cur%NOTFOUND;
	i := i+1;
       FETCH first_name_cur INTO v_records_table(i);

    END LOOP;



ELSIF p_column_name = 'MIDDLE_NAMES' THEN

    OPEN middle_names_cur;
    LOOP
	       EXIT WHEN middle_names_cur%NOTFOUND;
	i := i+1;
       FETCH middle_names_cur INTO v_records_table(i);

    END LOOP;


ELSIF p_column_name = 'NATIONAL_IDENTIFIER' THEN

    OPEN national_identifier_cur;
    LOOP
	       EXIT WHEN national_identifier_cur%NOTFOUND;
	i := i+1;
       FETCH national_identifier_cur INTO v_records_table(i);

    END LOOP;


ELSIF p_column_name = 'SEX' THEN

    OPEN gender_cur;
    LOOP
	       EXIT WHEN gender_cur%NOTFOUND;
	i := i+1;
       FETCH gender_cur INTO v_records_table(i);

    END LOOP;



ELSIF p_column_name = 'ATTRIBUTE6' THEN

    OPEN per_attribute6_cur;
    LOOP
	       EXIT WHEN per_attribute6_cur%NOTFOUND;
	i := i+1;
       FETCH per_attribute6_cur INTO v_records_table(i);

    END LOOP;


ELSIF p_column_name = 'ATTRIBUTE7' THEN

    OPEN per_attribute7_cur;
    LOOP
	       EXIT WHEN per_attribute7_cur%NOTFOUND;
	i := i+1;
       FETCH per_attribute7_cur INTO v_records_table(i);

    END LOOP;


ELSIF p_column_name = 'COST_SEGMENT2' THEN

    OPEN cost_segment2_cur;
    LOOP
	       EXIT WHEN cost_segment2_cur%NOTFOUND;
	i := i+1;
       FETCH cost_segment2_cur INTO v_records_table(i);

    END LOOP;


ELSIF p_column_name = 'COST_SEGMENT3' THEN

    OPEN cost_segment3_cur;
    LOOP
	       EXIT WHEN cost_segment3_cur%NOTFOUND;
	i := i+1;
       FETCH cost_segment3_cur INTO v_records_table(i);

    END LOOP;



ELSIF p_column_name = 'JOB_SEGMENT1' THEN

    OPEN job_segment1_cur;
    LOOP
	       EXIT WHEN job_segment1_cur%NOTFOUND;
	i := i+1;
       FETCH job_segment1_cur INTO v_records_table(i);

    END LOOP;




ELSIF p_column_name = 'ORG_PAYMENT_METHOD_NAME' THEN

    OPEN pay_method_name_cur;
    LOOP
	       EXIT WHEN pay_method_name_cur%NOTFOUND;
	i := i+1;
       FETCH pay_method_name_cur INTO v_records_table(i);

    END LOOP;





ELSIF p_column_name = 'PEA_SEGMENT1' THEN

    OPEN pay_method_segment1_cur;
    LOOP
	       EXIT WHEN pay_method_segment1_cur%NOTFOUND;
	i := i+1;
       FETCH pay_method_segment1_cur INTO v_records_table(i);

    END LOOP;




ELSIF p_column_name = 'PEA_SEGMENT3' THEN

    OPEN pay_method_segment3_cur;
    LOOP
	       EXIT WHEN pay_method_segment3_cur%NOTFOUND;
	i := i+1;
       FETCH pay_method_segment3_cur INTO v_records_table(i);

    END LOOP;




ELSIF p_column_name = 'PEA_SEGMENT4' THEN

    OPEN pay_method_segment4_cur;
    LOOP
	       EXIT WHEN pay_method_segment4_cur%NOTFOUND;
	i := i+1;
       FETCH pay_method_segment4_cur INTO v_records_table(i);

    END LOOP;




ELSIF p_column_name = 'ASS_ATTRIBUTE7' THEN

    OPEN ass_attribute7_cur;
    LOOP
	       EXIT WHEN ass_attribute7_cur%NOTFOUND;
	i := i+1;
       FETCH ass_attribute7_cur INTO v_records_table(i);

    END LOOP;




ELSIF p_column_name = 'ASS_ATTRIBUTE8' THEN

    OPEN ass_attribute8_cur;
    LOOP
	       EXIT WHEN ass_attribute8_cur%NOTFOUND;
	i := i+1;
       FETCH ass_attribute8_cur INTO v_records_table(i);

    END LOOP;




ELSIF p_column_name = 'ASS_ATTRIBUTE9' THEN

    OPEN ass_attribute9_cur;
    LOOP
	       EXIT WHEN ass_attribute9_cur%NOTFOUND;
	i := i+1;
       FETCH ass_attribute9_cur INTO v_records_table(i);

    END LOOP;




ELSIF p_column_name = 'ASS_ATTRIBUTE10' THEN

    OPEN ass_attribute10_cur;
    LOOP
	       EXIT WHEN ass_attribute10_cur%NOTFOUND;
	i := i+1;
       FETCH ass_attribute10_cur INTO v_records_table(i);

    END LOOP;




	ELSIF p_column_name = 'ASS_ATTRIBUTE11' THEN

    OPEN ass_attribute11_cur;
    LOOP
	       EXIT WHEN ass_attribute11_cur%NOTFOUND;
	i := i+1;
       FETCH ass_attribute11_cur INTO v_records_table(i);

    END LOOP;




ELSIF p_column_name = 'ASS_ATTRIBUTE12' THEN

    OPEN ass_attribute12_cur;
    LOOP
	       EXIT WHEN ass_attribute12_cur%NOTFOUND;
	i := i+1;
       FETCH ass_attribute12_cur INTO v_records_table(i);

    END LOOP;




ELSIF p_column_name = 'PEI_ATTRIBUTE11' THEN

    OPEN pei_attribute1_cur;
    LOOP
	       EXIT WHEN pei_attribute1_cur%NOTFOUND;
	i := i+1;
       FETCH pei_attribute1_cur INTO v_records_table(i);

    END LOOP;


ELSIF p_column_name = 'CONTRACT_TYPE' THEN

    OPEN contract_type_cur;
    LOOP
	       EXIT WHEN contract_type_cur%NOTFOUND;
	i := i+1;
       FETCH contract_type_cur INTO v_records_table(i);

    END LOOP;


ELSIF p_column_name = 'SYSTEM_PERSON_TYPE' THEN

    OPEN system_person_type_cur;
    LOOP
	       EXIT WHEN system_person_type_cur%NOTFOUND;
	i := i+1;
       FETCH system_person_type_cur INTO v_records_table(i);

    END LOOP;

ELSIF p_column_name = 'REHIRE' THEN

    OPEN rehire_cur;
    LOOP
	       EXIT WHEN rehire_cur%NOTFOUND;
	i := i+1;
       FETCH rehire_cur INTO v_records_table(i);

    END LOOP;

ELSIF p_column_name = 'RELATIONSHIP' THEN

    OPEN relationship_dep_cursor;
    LOOP
	       EXIT WHEN relationship_dep_cursor%NOTFOUND;
	i := i+1;
       FETCH relationship_dep_cursor INTO v_records_table(i);

    END LOOP;

ELSIF p_column_name = 'REL_LAST_NAME' THEN

    OPEN rel_last_name_dep_cursor;
    LOOP
	       EXIT WHEN rel_last_name_dep_cursor%NOTFOUND;
	i := i+1;
       FETCH rel_last_name_dep_cursor INTO v_records_table(i);

    END LOOP;

ELSIF p_column_name = 'REL_FIRST_NAME' THEN

    OPEN rel_first_name_dep_cursor;
    LOOP
	       EXIT WHEN rel_first_name_dep_cursor%NOTFOUND;
	i := i+1;
       FETCH rel_first_name_dep_cursor INTO v_records_table(i);

    END LOOP;

ELSIF p_column_name = 'REL_MIDDLE_NAMES' THEN

    OPEN rel_middle_names_dep_cursor;
    LOOP
	       EXIT WHEN rel_middle_names_dep_cursor%NOTFOUND;
	i := i+1;
       FETCH rel_middle_names_dep_cursor INTO v_records_table(i);

    END LOOP;

ELSIF p_column_name = 'REL_DOCUMENT_TYPE' THEN

    OPEN rel_document_type_dep_cursor;
    LOOP
	       EXIT WHEN rel_document_type_dep_cursor%NOTFOUND;
	i := i+1;
       FETCH rel_document_type_dep_cursor INTO v_records_table(i);

    END LOOP;

ELSIF p_column_name = 'REL_DOCUMENT_NUMBER' THEN

    OPEN rel_document_number_dep_cursor;
    LOOP
	       EXIT WHEN rel_document_number_dep_cursor%NOTFOUND;
	i := i+1;
       FETCH rel_document_number_dep_cursor INTO v_records_table(i);

    END LOOP;

ELSIF p_column_name = 'REL_SCHOLASTIC_INFO' THEN

    OPEN rel_scholastic_info_dep_cursor;
    LOOP
	       EXIT WHEN rel_scholastic_info_dep_cursor%NOTFOUND;
	i := i+1;
       FETCH rel_scholastic_info_dep_cursor INTO v_records_table(i);

    END LOOP;


 END IF;

IF p_column_name in
   ('ATTRIBUTE12', 'MARITAL_STATUS', 'LAST_NAME', 'FIRST_NAME','MIDDLE_NAMES', 'NATIONAL_IDENTIFIER',
    'SEX', 'ATTRIBUTE6', 'ATTRIBUTE7','COST_SEGMENT2', 'COST_SEGMENT3', 'JOB_SEGMENT1',
	'ORG_PAYMENT_METHOD_NAME', 'PEA_SEGMENT1','PEA_SEGMENT3', 'PEA_SEGMENT4', 'ASS_ATTRIBUTE7',
	'ASS_ATTRIBUTE8', 'ASS_ATTRIBUTE9','ASS_ATTRIBUTE10', 'ASS_ATTRIBUTE11', 'ASS_ATTRIBUTE12',
	'PEI_ATTRIBUTE11', 'CONTRACT_TYPE', 'SYSTEM_PERSON_TYPE', 'REHIRE',
	'RELATIONSHIP','REL_LAST_NAME' ,'REL_FIRST_NAME', 'REL_MIDDLE_NAMES', 'REL_DOCUMENT_TYPE', 'REL_DOCUMENT_NUMBER', 'REL_SCHOLASTIC_INFO')
THEN
 l_v_index := v_records_table.FIRST;

 if l_v_index is not null then
 l_v_value_to_compare := v_records_table(l_v_index);
 end if;


 l_v_record_count := v_records_table.COUNT;
END IF;



 IF (l_v_record_count <> 0) THEN

 FOR i IN v_records_table.FIRST .. v_records_table.LAST LOOP

    IF v_records_table(i) <> l_v_value_to_compare THEN

        l_record_changed := 'Y';
	exit;  /* exits the loop */

    END IF;

 END LOOP;

ELSE
   l_record_changed := 'N';
 END IF;

  return(l_record_changed);



EXCEPTION WHEN OTHERS THEN
  return(l_record_changed);


END;



Function Record_Changed_N (P_Column_Name IN VARCHAR2,
			 P_Person_Id IN NUMBER,
			 P_Assignment_Id IN NUMBER,
			 P_g_sysdate IN DATE) RETURN VARCHAR2 IS

CURSOR salary_cursor IS
Select nvl(a.salary,0) from
	(  	Select trunc(cut_off_date), to_number(curr.salary) salary
  	From
		--	cust.ttec_arg_pay_interface_mst curr --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.person_id = p_person_id
	and curr.assignment_id = p_assignment_id
	and trunc(curr.cut_off_date) = p_g_sysdate
Union
  	Select trunc(cut_off_date), to_number(past.salary) salary
  	From
		--	cust.ttec_arg_pay_interface_mst past --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.person_id = p_person_id
	and past.assignment_id = p_assignment_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from   cust.ttec_arg_pay_interface_mst --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from   apps.ttec_arg_pay_interface_mst --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where  person_id = p_person_id
						and    assignment_id = p_assignment_id
						and    trunc(cut_off_date) < p_g_sysdate)
	) a;

i binary_integer :=0;


l_n_index binary_integer;
l_n_value_to_compare number;

TYPE n_rectabtype IS TABLE OF number(15) index by binary_integer;
n_records_table n_rectabtype;

l_record_changed VARCHAR2(1) := 'N';

l_n_record_count NUMBER :=0;

BEGIN

 IF p_column_name = 'SALARY' THEN

    OPEN salary_cursor;
    LOOP
	       EXIT WHEN salary_cursor%NOTFOUND;
	i := i+1;
       FETCH salary_cursor INTO n_records_table(i);

    END LOOP;



 END IF;


IF p_column_name in ('SALARY')
THEN
 l_n_index := n_records_table.FIRST;
if l_n_index is not null then
 l_n_value_to_compare := n_records_table(l_n_index);
end if;
 l_n_record_count := n_records_table.COUNT;
END IF;


 IF (l_n_record_count <> 0) THEN

 FOR i IN n_records_table.FIRST .. n_records_table.LAST LOOP

    IF n_records_table(i) <> l_n_value_to_compare THEN

        l_record_changed := 'Y';
	exit;  -- exits the loop --

    END IF;

 END LOOP;

ELSE
   l_record_changed := 'N';
 END IF;
  return(l_record_changed);

EXCEPTION WHEN OTHERS THEN
  return(l_record_changed);


END;



Function Record_Changed_D (P_Column_Name IN VARCHAR2,
			 P_Person_Id IN NUMBER,
			 P_Assignment_Id IN NUMBER,
			 P_g_sysdate IN DATE) RETURN VARCHAR2 IS


CURSOR date_of_birth_cur IS
Select nvl(a.date_of_birth,TO_DATE('01-JAN-1951','DD-MON-YYYY')) from
	(  	Select trunc(cut_off_date), curr.date_of_birth
  	From
		--	cust.ttec_arg_pay_interface_mst curr --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.person_id = p_person_id
	and curr.assignment_id = p_assignment_id
	and trunc(curr.cut_off_date) = p_g_sysdate
Union
  	Select trunc(cut_off_date), past.date_of_birth
  	From
		--	cust.ttec_arg_pay_interface_mst past --Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_mst past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.person_id = p_person_id
	and past.assignment_id = p_assignment_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from   cust.ttec_arg_pay_interface_mst --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from   apps.ttec_arg_pay_interface_mst --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where  person_id = p_person_id
						and    assignment_id = p_assignment_id
						and    trunc(cut_off_date) < p_g_sysdate)
	) a;

CURSOR rel_dob_cursor IS
Select nvl(a.date_of_birth,'X') from
	(  	Select trunc(cut_off_date), curr.date_of_birth
  	From
		--cust.ttec_arg_pay_interface_dep curr--Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_dep curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.contact_relationship_id=p_person_id
	and trunc(curr.cut_off_date) = p_g_sysdate

Union

  	Select trunc(cut_off_date), past.date_of_birth
  	From
		--cust.ttec_arg_pay_interface_dep past--Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_dep past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.contact_relationship_id=p_person_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from cust.ttec_arg_pay_interface_dep --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from apps.ttec_arg_pay_interface_dep  --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where contact_relationship_id=p_person_id
						and  trunc(cut_off_date) < p_g_sysdate)
	)a;


CURSOR rel_date_from_cursor IS
Select nvl(a.relationship_date_from,'X') from
	(  	Select trunc(cut_off_date), curr.relationship_date_from
  	From
		--cust.ttec_arg_pay_interface_dep curr--Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_dep curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.contact_relationship_id=p_person_id
	and trunc(curr.cut_off_date) = p_g_sysdate

Union

  	Select trunc(cut_off_date), past.relationship_date_from
  	From
		--cust.ttec_arg_pay_interface_dep past--Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_dep past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.contact_relationship_id=p_person_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from cust.ttec_arg_pay_interface_dep --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from apps.ttec_arg_pay_interface_dep  --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where contact_relationship_id=p_person_id
						and  trunc(cut_off_date) < p_g_sysdate)
	)a;

CURSOR rel_date_to_cursor IS
Select nvl(a.relationship_date_to,'X') from
	(  	Select trunc(cut_off_date), curr.relationship_date_to
  	From
		--cust.ttec_arg_pay_interface_dep curr--Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_dep curr --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	curr.contact_relationship_id=p_person_id
	and trunc(curr.cut_off_date) = p_g_sysdate

Union

  	Select trunc(cut_off_date), past.relationship_date_to
  	From
		--cust.ttec_arg_pay_interface_dep past--Commented code by MXKEERTHI-ARGANO,07/17/2023
	apps.ttec_arg_pay_interface_dep past --code added by MXKEERTHI-ARGANO, 07/17/2023 
	Where
	past.contact_relationship_id=p_person_id
	and trunc(past.cut_off_date) = (select max(trunc(cut_off_date))
                        	--from cust.ttec_arg_pay_interface_dep --Commented code by MXKEERTHI-ARGANO,07/17/2023
	from apps.ttec_arg_pay_interface_dep  --code added by MXKEERTHI-ARGANO, 07/17/2023 
						where contact_relationship_id=p_person_id
						and  trunc(cut_off_date) < p_g_sysdate)
	)a;
i binary_integer :=0;


l_d_index binary_integer;
l_d_value_to_compare date;


TYPE d_rectabtype IS TABLE OF date index by binary_integer;
d_records_table d_rectabtype;

l_record_changed VARCHAR2(1) := 'N';

l_d_record_count NUMBER :=0;

BEGIN

 IF p_column_name = 'DATE_OF_BIRTH' THEN

    OPEN date_of_birth_cur;
    LOOP
	       EXIT WHEN date_of_birth_cur%NOTFOUND;
	i := i+1;
       FETCH date_of_birth_cur INTO d_records_table(i);

    END LOOP;





ELSIF p_column_name = 'REL_DATE_OF_BIRTH' THEN

    OPEN rel_dob_cursor;
    LOOP
	       EXIT WHEN rel_dob_cursor%NOTFOUND;
	i := i+1;
       FETCH rel_dob_cursor INTO d_records_table(i);

    END LOOP;

ELSIF p_column_name = 'REL_DATE_FROM' THEN

    OPEN rel_date_from_cursor;
    LOOP
	       EXIT WHEN rel_date_from_cursor%NOTFOUND;
	i := i+1;
       FETCH rel_date_from_cursor INTO d_records_table(i);

    END LOOP;

ELSIF p_column_name = 'REL_DATE_TO' THEN

    OPEN rel_date_to_cursor;
    LOOP
	       EXIT WHEN rel_date_to_cursor%NOTFOUND;
	i := i+1;
       FETCH rel_date_to_cursor INTO d_records_table(i);

    END LOOP;

END IF;

IF p_column_name in ('DATE_OF_BIRTH', 'REL_DATE_OF_BIRTH', 'REL_DATE_FROM', 'REL_DATE_TO')
THEN
 l_d_index := d_records_table.FIRST;

 if l_d_index is not null then
 l_d_value_to_compare := d_records_table(l_d_index);
 end if;

 l_d_record_count := d_records_table.COUNT;
END IF;



  IF (l_d_record_count <> 0) THEN

 FOR i IN d_records_table.FIRST .. d_records_table.LAST LOOP

    IF d_records_table(i) <> l_d_value_to_compare THEN

        l_record_changed := 'Y';
	exit;  -- exits the loop --

    END IF;

 END LOOP;

ELSE
   l_record_changed := 'N';
 END IF;

 return(l_record_changed);

EXCEPTION WHEN OTHERS THEN
  return(l_record_changed);


END;



END ttec_arg_intf_util;
/
show errors;
/