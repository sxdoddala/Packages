create or replace package body TT_401K_INTERFACE is






/************************************************************************************
        Program Name:      TT_401K_INTERFACE

        Description:   

        Developed by : 
        Date         :  

       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
    RXNETHI(ARGANO)            1.0      29-JUN-2023      R12.2 Upgrade Remediation
    ****************************************************************************************/







-----------------------------------------------------------------------------------------------------
-- Begin format_ssn ---------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
PROCEDURE format_ssn (v_ssn IN OUT VARCHAR2) IS

--l_temp_ssn hr.per_all_people_f.national_identifier%TYPE;  --code commented by RXNETHI-ARGANO,29/06/23
l_temp_ssn apps.per_all_people_f.national_identifier%TYPE;  --code added by RXNETHI-ARGANO,29/06/23
i NUMBER := 0;
n NUMBER := 1;

BEGIN
  SELECT length(v_ssn)
  INTO   i
  FROM   dual;

  IF (i > 0) THEN
    FOR c IN 1..i LOOP
      IF (upper(substr(v_ssn, n, 1)) between '0' and '9') THEN
        l_temp_ssn := (l_temp_ssn||substr(v_ssn, n, 1));
        n := n + 1;
      ELSE
        n := n + 1;
      END IF;
    END LOOP;
    v_ssn := l_temp_ssn;
  END IF;
END;


-----------------------------------------------------------------------------------------------------
-- Begin display_number ----------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
FUNCTION display_number (p_amount IN NUMBER) RETURN VARCHAR2 IS


i VARCHAR2(10) := 0;

BEGIN

If p_amount < 0 then
   i  :=  '-' ||  substr(lpad(-p_amount,9,'0'),1,9)  ;
Elsif p_amount >= 0 then
   i  :=  substr(lpad(p_amount,10,'0'),1,10);
Else
   i  := lpad('0',10,'0');
End If;


  Return i;

EXCEPTION
   when others then
     raise;

END;
-----------------------------------------------------------------------------------------------------
-- Begin format_address -----------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
PROCEDURE format_address (v_address IN OUT VARCHAR2) IS

--l_temp_address hr.per_addresses.address_line1%TYPE;  --code commented by RXNETHI-ARGANO,29/06/23
l_temp_address apps.per_addresses.address_line1%TYPE;  --code added by RXNETHI-ARGANO,29/06/23
i NUMBER := 0;
n NUMBER := 1;

BEGIN
  SELECT length(v_address)
  INTO   i
  FROM   dual;

  IF (i > 0) THEN
    FOR c IN 1..i LOOP
      IF (upper(substr(v_address, n, 1)) = '/') OR
         (upper(substr(v_address, n, 1)) = '#')THEN
        n := n + 1;
      ELSE
        l_temp_address := (l_temp_address||substr(v_address, n, 1));
        n := n + 1;
      END IF;
    END LOOP;
  END IF;
  v_address := l_temp_address;
END;


-----------------------------------------------------------------------------------------------------
-- Begin get_balance_amount ----- -------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
PROCEDURE get_balance_amount (v_person_id IN NUMBER, v_balance_type IN VARCHAR2,
                              v_begin_date IN DATE, v_end_date IN DATE,
							  v_balance OUT NUMBER) IS

	l_begin_date   date := TRUNC(v_begin_date);
	l_end_date     date := TRUNC(v_end_date) ;

    BEGIN


        select NVL( ROUND(sum(NVL(d.balance_value,0)),2), 0)
               into v_balance
        --from apps.xkb_balance_details d , apps.xkb_balances b, pay_balance_types p  --code commented by RXNETHI-ARGANO,29/06/23
        from apps.xkb_balance_details d , apps.xkb_balances b, apps.pay_balance_types p  --code added by RXNETHI-ARGANO,29/06/23
        where UPPER(p.balance_name) = UPPER(v_balance_type)
		  and p.balance_type_id = d.balance_type_id
          and d.assignment_action_id = b.assignment_action_id
		  --  ikonak 04/29 change from effective date to creation date
          and TRUNC(b.creation_date) BETWEEN l_begin_date and l_end_date
          and b.person_id = v_person_id;

    EXCEPTION
  	        WHEN NO_DATA_FOUND THEN
	            		 v_balance := 0;
   	    	WHEN TOO_MANY_ROWS THEN
                         v_balance := 0;
            WHEN OTHERS THEN
					     v_balance := 0;
                         RAISE;
    END;


-----------------------------------------------------------------------------------------------------
-- Begin get_balance_amount ----- -------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
PROCEDURE get_balance_amount_ytd (v_person_id IN NUMBER, v_balance_type IN VARCHAR2,
                              v_begin_date IN DATE,
                              v_end_date IN DATE, v_balance OUT NUMBER) IS

	l_begin_date   date := TRUNC(v_end_date,'YY');
	l_end_date     date := TRUNC(v_end_date) ;

    BEGIN

	if TO_CHAR(v_end_date,'YYYY') = '2003' then

	    select NVL( ROUND(sum(NVL(d.balance_value,0)),2), 0)
               into v_balance
        --from apps.xkb_balance_details d , apps.xkb_balances b, pay_balance_types p --code commented by RXNETHI-ARGANO,29/06/23
        from apps.xkb_balance_details d , apps.xkb_balances b, apps.pay_balance_types p --code added by RXNETHI-ARGANO,29/06/23
        where UPPER(p.balance_name) = UPPER(v_balance_type)
		  and p.balance_type_id = d.balance_type_id
          and d.assignment_action_id = b.assignment_action_id
		  --  ikonak 04/29 change from effective date to creation date
		  --  ikonak 06/23 for 20003 get all the entries as there are without pay date
		  --  include 2002 entries
        --  and NVL(TRUNC(b.creation_date), l_begin_date)
		  --          <= l_end_date
		    and NVL(TRUNC(b.effective_date), l_begin_date) <= l_end_date	---changed by eoa 2004-09-02
	        and b.person_id = v_person_id;
	else

        select NVL( ROUND(sum(NVL(d.balance_value,0)),2), 0)
               into v_balance
        --from apps.xkb_balance_details d , apps.xkb_balances b, pay_balance_types p --code commented by RXNETHI-ARGANO,29/06/23
        from apps.xkb_balance_details d , apps.xkb_balances b, apps.pay_balance_types p --code commented by RXNETHI-ARGANO,29/06/23
        where UPPER(p.balance_name) = UPPER(v_balance_type)
		  and p.balance_type_id = d.balance_type_id
          and d.assignment_action_id = b.assignment_action_id
		  --  ikonak 04/29 change from effective date to creation date
         -- and TRUNC(b.creation_date)  BETWEEN l_begin_date and l_end_date
		  and TRUNC(b.effective_date)  BETWEEN l_begin_date and l_end_date     ---changed by eoa 2004-09-02
          and b.person_id = v_person_id;
    end if;

    EXCEPTION
  	        WHEN NO_DATA_FOUND THEN
	            		 v_balance := 0;
   	    	WHEN TOO_MANY_ROWS THEN
                         v_balance := 0;
            WHEN OTHERS THEN
					     v_balance := 0;
                         RAISE;
    END;


 /************************************************************************************/
 /*                               MAIN PROGRAM PROCEDURE                             */
 /************************************************************************************/

 PROCEDURE main (ERRBUF OUT VARCHAR2, RETCODE OUT NUMBER,
                          P_BEGIN_DATE IN DATE, P_END_DATE IN DATE,
						  P_OUTPUT_DIR IN VARCHAR2 ) IS


g_payroll_date    date := P_END_DATE; --'(25-OCT-2002' ,'11-OCT-2002' ,sysdate)

-----------------------------------------------------------------------------------------------------
-- Cursor declarations ------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
CURSOR c_emp_data IS
SELECT distinct 'P' transaction_type
       , emp.national_identifier national_identifier
       , emp.first_name
       , emp.last_name
	   , NULL as sort_key
       , adr.address_line1
       , adr.address_line2
       , adr.town_or_city
       , adr.region_2
       , adr.postal_code
	   , loc.attribute2 std_unit_id
	   , NULL extra_unit_id
	   , pt.user_person_type
	   , NULL highly_comp
	   , NULL top_heavy
	   , NULL plan_entry_date
       , to_char(emp.date_of_birth, 'MM/DD/YYYY') date_of_birth
       , to_char(emp.original_date_of_hire,'MM/DD/YYYY') original_date_of_hire
       , to_char(pos.date_start, 'MM/DD/YYYY') date_start
	   , emp.date_of_death
	   , pos.last_update_date
       , to_char(pos.actual_termination_date, 'MM/DD/YYYY') actual_termination_date
	   , DECODE(pay.period_type,'Bi-Week','113','Calendar Month','100','999') payroll_cycle_code
	   , NULL as hours_ytd
	   , NULL as cum_hours
	   , rehires.segment3 rehire_months
       , asg.assignment_id
	   , emp.person_id
/*
START R12.2 Upgrade Remediation
code commented by RXNETHI-ARGANO,29/06/23
FROM   hr.per_all_people_f emp
    ,  hr.per_addresses adr
	,  hr.per_periods_of_service pos
	,  hr.per_person_types pt
*/
--code added by RXNETHI-ARGANO,29/06/23
FROM   apps.per_all_people_f emp
    ,  apps.per_addresses adr
	,  apps.per_periods_of_service pos
	,  apps.per_person_types pt
--END R12.2 Upgrade Remediation
 --, (select person_id, max(date_start) date_start from hr.per_periods_of_service group by  person_id) max_date  --code commented by RXNETHI-ARGANO,29/06/23
 , (select person_id, max(date_start) date_start from apps.per_periods_of_service group by  person_id) max_date--code added by RXNETHI-ARGANO,29/06/23
 --, (select pa.person_id, pa.id_flex_num, ac.segment3 from hr.per_person_analyses pa, --code commented by RXNETHI-ARGANO,29/06/23
 , (select pa.person_id, pa.id_flex_num, ac.segment3 from apps.per_person_analyses pa,   --code added by RXNETHI-ARGANO,29/06/23
    --hr.per_analysis_criteria ac    --code commented by RXNETHI-ARGANO,29/06/23
    apps.per_analysis_criteria ac    --code added by RXNETHI-ARGANO,29/06/23
    where pa.analysis_criteria_id = ac.analysis_criteria_id
    and pa.id_flex_num = (select id_flex_num
	                      from apps.FND_ID_FLEX_STRUCTURES
                          where
                          id_flex_structure_code = 'TELETECH_ADP_DATA')) rehires  -- ADP Data flexfields
    --,  hr.pay_all_payrolls_f pay       --code commented by RXNETHI-ARGANO,29/06/23
    ,  apps.pay_all_payrolls_f pay       --code added by RXNETHI-ARGANO,29/06/23
	--,  hr.per_all_assignments_f asg    --code commented by RXNETHI-ARGANO,29/06/23
	,  apps.per_all_assignments_f asg    --code added by RXNETHI-ARGANO,29/06/23
	,  apps.hr_locations_all loc
WHERE  emp.person_id = adr.person_id (+)
AND    emp.person_id = pos.person_id (+)
AND    emp.person_type_id = pt.person_type_id (+)
AND    emp.person_id = rehires.person_id (+)
AND    emp.person_id = asg.person_id
AND    asg.payroll_id = pay.payroll_id
AND    asg.location_id = loc.location_id
AND    (asg.person_id = pos.person_id AND asg.period_of_service_id = pos.period_of_service_id)
AND    (pos.person_id = max_date.person_id and pos.date_start = max_date.date_start)
AND    adr.primary_flag = 'Y'
AND    adr.COUNTRY = 'US'
AND    trunc(P_END_DATE) between emp.effective_start_date and emp.effective_end_date
AND    trunc(P_END_DATE) between adr.date_from and nvl(adr.date_to, trunc(P_END_DATE+1))
AND    trunc(P_END_DATE) between asg.effective_start_date and asg.effective_end_date
;


-----------------------------------------------------------------------------------------------------
-- Record declarations ------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
TYPE T_HEADER_INFO IS RECORD
(
  hdr_transaction_type   varchar2(1) := 'H'
, hdr_payroll_date 	     varchar2(10)
, hdr_plan_id            varchar2(8) := '00000TTI'
);

/*
START R12.2 Upgrade Remediation
code commented by RXNETHI-ARGANO,29/06/23
TYPE T_EMPLOYEE_INFO IS RECORD
(
  emp_transaction_type   varchar2(1)
, emp_ssn 			 hr.per_all_people_f.national_identifier%TYPE
, emp_first_name 	 hr.per_all_people_f.first_name%TYPE
, emp_last_name 	 hr.per_all_people_f.last_name%TYPE
, emp_sort_key       VARCHAR2(30)
, emp_addr_line1 	 hr.per_addresses.address_line1%TYPE
, emp_addr_line2 	 hr.per_addresses.address_line2%TYPE
, emp_city 			 hr.per_addresses.town_or_city%TYPE
, emp_state 		 hr.per_addresses.region_2%TYPE
, emp_zip_code 		 hr.per_addresses.postal_code%TYPE
, emp_std_unit_id    VARCHAR2(5)
, emp_extra_unit_id  VARCHAR2(5)
, emp_person_type    VARCHAR2(80)
, emp_highly_comp    varchar2(9)
, emp_top_heavy      varchar2(9)
, emp_entry_date     varchar2(10)
, emp_dob 		     varchar2(15) -- hr.per_all_people_f.date_of_birth%TYPE
, emp_hire_date      varchar2(15) -- hr.per_all_people_f.original_date_of_hire%TYPE
, emp_rehire_date    varchar2(15) -- hr.per_periods_of_service.date_start%TYPE
, emp_date_of_death  date
, emp_last_update    date
, emp_term_date      varchar2(15) -- hr.per_periods_of_service.actual_termination_date%TYPE
, emp_payroll_cycle_code  VARCHAR2(3)
, emp_hours_ytd        VARCHAR2(4)
, emp_cum_hours        VARCHAR2(4)
, emp_rehire_months  hr.per_analysis_criteria.segment3%TYPE
, emp_asg_id         HR.PER_ALL_ASSIGNMENTS_F.assignment_id%TYPE
, emp_person_id      HR.PER_ALL_PEOPLE_F.person_id%TYPE
);
*/
--code added by RXNETHI-ARGANO,29/06/23
TYPE T_EMPLOYEE_INFO IS RECORD
(
  emp_transaction_type   varchar2(1)
, emp_ssn 			 apps.per_all_people_f.national_identifier%TYPE
, emp_first_name 	 apps.per_all_people_f.first_name%TYPE
, emp_last_name 	 apps.per_all_people_f.last_name%TYPE
, emp_sort_key       VARCHAR2(30)
, emp_addr_line1 	 apps.per_addresses.address_line1%TYPE
, emp_addr_line2 	 apps.per_addresses.address_line2%TYPE
, emp_city 			 apps.per_addresses.town_or_city%TYPE
, emp_state 		 apps.per_addresses.region_2%TYPE
, emp_zip_code 		 apps.per_addresses.postal_code%TYPE
, emp_std_unit_id    VARCHAR2(5)
, emp_extra_unit_id  VARCHAR2(5)
, emp_person_type    VARCHAR2(80)
, emp_highly_comp    varchar2(9)
, emp_top_heavy      varchar2(9)
, emp_entry_date     varchar2(10)
, emp_dob 		     varchar2(15) -- hr.per_all_people_f.date_of_birth%TYPE
, emp_hire_date      varchar2(15) -- hr.per_all_people_f.original_date_of_hire%TYPE
, emp_rehire_date    varchar2(15) -- hr.per_periods_of_service.date_start%TYPE
, emp_date_of_death  date
, emp_last_update    date
, emp_term_date      varchar2(15) -- hr.per_periods_of_service.actual_termination_date%TYPE
, emp_payroll_cycle_code  VARCHAR2(3)
, emp_hours_ytd        VARCHAR2(4)
, emp_cum_hours        VARCHAR2(4)
, emp_rehire_months  apps.per_analysis_criteria.segment3%TYPE
, emp_asg_id         APPS.PER_ALL_ASSIGNMENTS_F.assignment_id%TYPE
, emp_person_id      APPS.PER_ALL_PEOPLE_F.person_id%TYPE
);
--END R12.2 Upgrade Remediation
TYPE T_TRAILER_INFO IS RECORD
(
  trl_transaction_type   varchar2(1) := 'T'
, trl_hours_ytd          varchar2(10) := NULL
, trl_cum_hours          varchar2(10) := NULL
, trl_prior_months       varchar2(10) := 0
, trl_money_type1        varchar2(10) := NULL
, trl_money_type2        varchar2(10) := NULL
, trl_money_type3        varchar2(10) := NULL
, trl_money_type4        varchar2(10) := NULL
, trl_money_type5        varchar2(10) := NULL
, trl_money_type6        varchar2(10) := NULL
, trl_money_type7        varchar2(10) := NULL
, trl_money_type8        varchar2(10) := NULL
, trl_money_type9        varchar2(10) := NULL
, trl_money_type10        varchar2(10) := NULL
, trl_money_type11        varchar2(10) := NULL
, trl_money_type12        varchar2(10) := NULL
, trl_money_type13        varchar2(10) := NULL
, trl_money_type14        varchar2(10) := NULL
, trl_money_type15        varchar2(10) := NULL
, trl_loan1               varchar2(10) := NULL
, trl_loan2               varchar2(10) := NULL
, trl_loan3               varchar2(10) := NULL
, trl_loan4               varchar2(10) := NULL
, trl_loan5               varchar2(10) := NULL
, trl_loan6               varchar2(10) := NULL
, trl_loan7               varchar2(10) := NULL
, trl_loan8               varchar2(10) := NULL
, trl_loan9               varchar2(10) := NULL
, trl_loan10              varchar2(10) := NULL
, trl_comp_amount0        varchar2(100) := NULL
, trl_comp_amount1        varchar2(100) := NULL
, trl_comp_amount5        varchar2(10) := NULL
);


-- Declare variables
emp 	   	 	T_EMPLOYEE_INFO;
trl 	   	 	T_TRAILER_INFO;
--depn 	   	 	T_DEPENDENT_INFO;
l_emp_output 	VARCHAR2(2000);
l_depn_output	CHAR(555);
v_rows 			VARCHAR2(555);
l_wachovia_status varchar2(15);
l_assignment_action_id   NUMBER;

--l_module_name CUST.TTEC_error_handling.module_name%type := '401';
l_module_name APPS.TTEC_error_handling.module_name%type := '401';

l_rehire_months number := 0;
l_money_type1 number := 0;
l_money_type2 number := 0;
l_loan1 number := 0 ;
l_comp_amount0 number := 0;
l_comp_amount1 number := 0;
l_comp_amount00 number := 0;

l_comp_ind     number := 0;

t_rehire_months number := 0;
t_money_type1 number := 0;
t_money_type2 number := 0;
t_loan1 number := 0 ;
t_comp_amount0 number := 0;
t_comp_amount1 number := 0;


v_emp_status varchar2(4);

BEGIN
dbms_output.put_line('Opening file...');
  v_daily_file := UTL_FILE.FOPEN(P_OUTPUT_DIR, p_FileName, 'w');

  -- Header Information --
  BEGIN
    l_emp_output := (g_header_type || to_char(g_payroll_date,'MM/DD/YYYY') || g_plan_id);
    utl_file.put_line(v_daily_file, l_emp_output);
  END;
  -- Employee Data Extract --
  BEGIN
    OPEN c_emp_data;
    LOOP
      BEGIN
        FETCH c_emp_data
        INTO  emp.emp_transaction_type
            , emp.emp_ssn
            , emp.emp_first_name
            , emp.emp_last_name
			, emp.emp_sort_key
            , emp.emp_addr_line1
            , emp.emp_addr_line2
            , emp.emp_city
            , emp.emp_state
            , emp.emp_zip_code
			, emp.emp_std_unit_id
			, emp.emp_extra_unit_id
			, emp.emp_person_type
			, emp.emp_highly_comp
			, emp.emp_top_heavy
			, emp.emp_entry_date
            , emp.emp_dob
            , emp.emp_hire_date
			, emp.emp_rehire_date
			, emp.emp_date_of_death
			, emp.emp_last_update
			, emp.emp_term_date
			, emp.emp_payroll_cycle_code
			, emp.emp_hours_ytd
			, emp.emp_cum_hours
			, emp.emp_rehire_months
			, emp.emp_asg_id
			, emp.emp_person_id  ;

        EXIT  WHEN c_emp_data%NOTFOUND;

	    --IKONAK 01/08/03  allow single quote and dash
        --format_lastname(emp.emp_last_name);

		if emp.emp_ssn is not null then
		    format_ssn(emp.emp_ssn);
      		emp.emp_ssn := substr(emp.emp_ssn,1,3)||'-'||substr(emp.emp_ssn,4,2)||'-'||substr(emp.emp_ssn,6,4);
		end if;



        format_address(emp.emp_addr_line1);
        format_address(emp.emp_addr_line2);


		l_money_type1 := 0;
		l_money_type2 := 0;
		l_loan1 := 0;
		l_comp_amount0 := 0;
		l_comp_amount1 := 0;
		l_comp_amount00 := 0;

         BEGIN
          v_rows := 'XX';
		  if emp.emp_term_date IS NOT NULL then	 -- newly terminated
		     l_wachovia_status := 'TERM';
			 emp.emp_rehire_date := null;
		  elsif
		     emp.emp_date_of_death IS NOT NULL then         									 	   -- deceased
		     l_wachovia_status := 'DTH';
		  elsif
             (emp.emp_rehire_date <> emp.emp_hire_date) and
		     (trunc(P_END_DATE) - to_date(nvl(emp.emp_rehire_date,to_char(P_END_DATE,'MM/DD/YYYY')),'MM/DD/YYYY')) < 15 then
		 	 l_wachovia_status := 'ACTV' ;
		  --elsif
		     --(trunc(P_END_DATE) - to_date(nvl(emp.emp_hire_date,to_char(P_END_DATE,'MM/DD/YYYY')),'MM/DD/YYYY')) < 15 then                                                      -- newhire
	 	 	 --l_wachovia_status := '    ';    --'ACTV';
		  else
	         l_wachovia_status := '    ';
		  end if;

   		if emp.emp_hire_date = emp.emp_rehire_date then
		   emp.emp_rehire_date := null;
 		end if;

        l_rehire_months := emp.emp_rehire_months;

		-- Get Payroll PTD Values
    	get_balance_amount(emp.emp_person_id,'US 401K',p_begin_date,p_end_date,l_money_type1);
		--get_balance_amount(emp.emp_person_id,'US 401K ER',p_begin_date,p_end_date,l_money_type2);
		get_balance_amount(emp.emp_person_id,'Loan 1_401K',p_begin_date,p_end_date,l_loan1);
		-- Change compensation balance to YTD
		get_balance_amount_ytd(emp.emp_person_id,'US_401K_Discrimination_Testing',
		                                                  p_begin_date,p_end_date,l_comp_amount0);

		-- Per Cathy Rien, both comp fields use same compensation basis
		-- ORIGINALLY CODED AS:  get_balance_amount(emp.emp_person_id,'US 401K Eligible Comp',l_comp_amount0);
		l_comp_amount1 := l_comp_amount0 ;

		l_money_type1 := l_money_type1 * 100;
		--l_money_type2 := l_money_type2 * 100;
		l_money_type2 := 0;
		l_loan1 := l_loan1 * 100;
		l_comp_amount0 := l_comp_amount0 * 100;


		  If l_comp_amount1 < 90000 then  --per Cathy Rien
		     l_comp_ind  :=  0;
		  else
		     l_comp_ind := 3;
		  end if;

	      -- Calculate summary totals for trailer record
		  t_rehire_months := t_rehire_months + nvl(l_rehire_months,0);
		  t_money_type1 := t_money_type1 + nvl(l_money_type1,0);
		  t_money_type2 := t_money_type2 + nvl(l_money_type2,0);
		  t_loan1 := t_loan1 + nvl(l_loan1,0);

		  -- ikonak 06/10/03  comp amounts are zero fill per Andy Becker
		  --t_comp_amount0 := t_comp_amount0 + nvl(l_comp_amount0,0);
		  --t_comp_amount1 := t_comp_amount1 + nvl(l_comp_amount0,0);  --sama as t_comp_amount0


        EXCEPTION
          WHEN NO_DATA_FOUND THEN
		--    dbms_output.put_line('DID NOT FIND DATA SOMEWHERE');
            v_rows := NULL;
          WHEN TOO_MANY_ROWS THEN
            v_rows := 'not null';
          WHEN OTHERS THEN
            RAISE;
        END;

        IF (v_rows is not null) THEN
        l_emp_output := (g_transaction_type
                 || nvl(substr(rpad(emp.emp_ssn,11,' '),1,11),'999-99-9999')
                 || nvl(substr(rpad(UPPER(emp.emp_first_name),15,' '),1,15),rpad(' ',15,' '))
                 || nvl(substr(rpad(UPPER(emp.emp_last_name),30,' '),1,30), rpad(' ',30,' '))
 				 || nvl(rpad(emp.emp_sort_key,30,' '),rpad(' ',30,' '))
                 || nvl(substr(rpad(UPPER(emp.emp_addr_line1),30,' '),1,30),rpad(' ',30,' '))
                 || nvl(substr(rpad(UPPER(emp.emp_addr_line2),30,' '),1,30),rpad(' ',30,' '))
                 || nvl(substr(rpad(UPPER(emp.emp_city),23,' '),1,23),rpad(' ',23,' '))
                 || nvl(substr(rpad(UPPER(emp.emp_state),2,' '),1,2),rpad(' ',2,' '))
                 || nvl(substr(rpad(emp.emp_zip_code,10,' '),1,10),lpad(' ',10,' '))
                 --|| nvl(substr(lpad(emp.emp_zip_code,10,' '),1,10),lpad(' ',10,' '))
 				 || nvl(substr(lpad(emp.emp_std_unit_id,5,'0'),1,5),lpad('0',5,'0'))
                 || nvl(substr(rpad(emp.emp_extra_unit_id,5,' '),1,5),rpad(' ',5,' '))
 				 || nvl(substr(rpad(UPPER(l_wachovia_status),4,' '),1,4),rpad(' ',4,' '))
 				 || l_comp_ind    --nvl(substr(rpad(emp.emp_highly_comp,1,' '),1,1),' ')
 				 || nvl(substr(rpad(emp.emp_top_heavy,1,' '),1,1),'0')
 				 || nvl(substr(rpad(NULL,10,' '),1,10), rpad(' ',10,' '))  -- date of plan entry (blank)
 				 || nvl(substr(rpad(emp.emp_dob,10,' '),1,10), rpad(' ',10,' '))
 				 || nvl(substr(rpad(emp.emp_hire_date,10,' '),1,10),rpad(' ',10,' '))
 				 || nvl(substr(rpad(emp.emp_rehire_date,10,' '),1,10),rpad(' ',10,' '))
 				 || nvl(substr(rpad(' ',10,' '),1,10),rpad(' ',10,' '))               -- filler field 239-248
 				 || nvl(substr(rpad(emp.emp_term_date,10,' '),1,10),rpad(' ',10,' '))
 				 || nvl(substr(rpad(emp.emp_payroll_cycle_code,3,' '),1,3),rpad(' ',3,' '))
 				 || nvl(substr(lpad(emp.emp_hours_ytd,4,'0'),1,4),lpad('0',4,'0'))
 				 || nvl(substr(lpad(emp.emp_cum_hours,4,'0'),1,4),lpad('0',4,'0'))
 				 || nvl(substr(lpad(emp.emp_rehire_months,3,'0'),1,3),lpad('0',3,'0'))
 				 || display_number(l_money_type1)
 				 || display_number(l_money_type2)
 				 || nvl(substr(lpad(0,10,'0'),1,10),lpad('0',10,'0'))	  -- money_type3
 			 	 || nvl(substr(lpad(0,10,'0'),1,10),lpad('0',10,'0'))	  -- money_type4
 				 || nvl(substr(lpad(0,10,'0'),1,10),lpad('0',10,'0'))	  -- money_type5
 				 || nvl(substr(lpad(0,10,'0'),1,10),lpad('0',10,'0'))	  -- money_type6
 				 || nvl(substr(lpad(0,10,'0'),1,10),lpad('0',10,'0'))	  -- money_type7
 				 || nvl(substr(lpad(0,10,'0'),1,10),lpad('0',10,'0'))	  -- money_type8
 				 || nvl(substr(lpad(0,10,'0'),1,10),lpad('0',10,'0'))	  -- money_type9
 				 || nvl(substr(lpad(0,10,'0'),1,10),lpad('0',10,'0'))	  -- money_type10
 				 || nvl(substr(lpad(0,10,'0'),1,10),lpad('0',10,'0'))	  -- money_type11
 				 || nvl(substr(lpad(0,10,'0'),1,10),lpad('0',10,'0'))	  -- money_type12
 				 || nvl(substr(lpad(0,10,'0'),1,10),lpad('0',10,'0'))	  -- money_type13
 				 || nvl(substr(lpad(0,10,'0'),1,10),lpad('0',10,'0'))	  -- money_type14
 				 || nvl(substr(lpad(0,10,'0'),1,10),lpad('0',10,'0'))	  -- money_type15
 				 || display_number(l_loan1)
 				 || nvl(substr(lpad(0,10,'0'),1,10),lpad('0',10,'0'))   	  --  loan2
 				 || nvl(substr(lpad(0,10,'0'),1,10),lpad('0',10,'0'))   	  --  loan3
 				 || nvl(substr(lpad(0,10,'0'),1,10),lpad('0',10,'0'))   	  --  loan4
 				 || nvl(substr(lpad(0,10,'0'),1,10),lpad('0',10,'0'))   	  --  loan5
 				 || nvl(substr(lpad(0,10,'0'),1,10),lpad('0',10,'0'))   	  --  loan6
 				 || nvl(substr(lpad(0,10,'0'),1,10),lpad('0',10,'0'))   	  --  loan7
 				 || nvl(substr(lpad(0,10,'0'),1,10),lpad('0',10,'0'))	  --  loan8
 				 || nvl(substr(lpad(0,10,'0'),1,10),lpad('0',10,'0'))	  --  loan9
 				 || nvl(substr(lpad(0,10,'0'),1,10),lpad('0',10,'0'))	  --  loan10
 				 || display_number(l_comp_amount0)
 				 || display_number(l_comp_amount0)
 				 || nvl(substr(lpad(0,10,'0'),1,10),lpad('0',10,'0'))  	   --  emp.emp_comp_amount5
                        );
        utl_file.put_line(v_daily_file, l_emp_output);

        END IF;
      END;
    END LOOP;
    CLOSE c_emp_data;
  END;

  	   BEGIN

  -- Trailer Information --
  		  trl.trl_prior_months := t_rehire_months;
		  trl.trl_money_type1 := t_money_type1;
		  trl.trl_money_type2 := t_money_type2;
		  trl.trl_loan1 := t_loan1;
		  -- ikonak 06/10/03  comp amounts are zero fill per Andy Becker
		  --trl.trl_comp_amount0 := t_comp_amount0;
		  --trl.trl_comp_amount1 := t_comp_amount1;

          l_emp_output := (g_trailer_type
                         || rpad(' ',237,' ')
						 || nvl(substr(lpad(trl.trl_hours_ytd,10,'0'),1,10),lpad('0',10,'0'))
						 || nvl(substr(lpad(trl.trl_cum_hours,10,'0'),1,10),lpad('0',10,'0'))
						 || nvl(substr(lpad(trl.trl_prior_months,10,'0'),1,10),lpad('0',10,'0'))
						 || display_number(trl.trl_money_type1)
						 || display_number(trl.trl_money_type2)
						 || nvl(substr(lpad(trl.trl_money_type3,10,'0'),1,10),lpad('0',10,'0'))
					 	 || nvl(substr(lpad(trl.trl_money_type4,10,'0'),1,10),lpad('0',10,'0'))
						 || nvl(substr(lpad(trl.trl_money_type5,10,'0'),1,10),lpad('0',10,'0'))
						 || nvl(substr(lpad(trl.trl_money_type6,10,'0'),1,10),lpad('0',10,'0'))
						 || nvl(substr(lpad(trl.trl_money_type7,10,'0'),1,10),lpad('0',10,'0'))
						 || nvl(substr(lpad(trl.trl_money_type8,10,'0'),1,10),lpad('0',10,'0'))
						 || nvl(substr(lpad(trl.trl_money_type9,10,'0'),1,10),lpad('0',10,'0'))
						 || nvl(substr(lpad(trl.trl_money_type10,10,'0'),1,10),lpad('0',10,'0'))
						 || nvl(substr(lpad(trl.trl_money_type11,10,'0'),1,10),lpad('0',10,'0'))
						 || nvl(substr(lpad(trl.trl_money_type12,10,'0'),1,10),lpad('0',10,'0'))
						 || nvl(substr(lpad(trl.trl_money_type13,10,'0'),1,10),lpad('0',10,'0'))
						 || nvl(substr(lpad(trl.trl_money_type14,10,'0'),1,10),lpad('0',10,'0'))
						 || nvl(substr(lpad(trl.trl_money_type15,10,'0'),1,10),lpad('0',10,'0'))
						 || display_number(trl.trl_loan1)
						 || nvl(substr(lpad(trl.trl_loan2,10,'0'),1,10),lpad('0',10,'0'))
						 || nvl(substr(lpad(trl.trl_loan3,10,'0'),1,10),lpad('0',10,'0'))
						 || nvl(substr(lpad(trl.trl_loan4,10,'0'),1,10),lpad('0',10,'0'))
						 || nvl(substr(lpad(trl.trl_loan5,10,'0'),1,10),lpad('0',10,'0'))
						 || nvl(substr(lpad(trl.trl_loan6,10,'0'),1,10),lpad('0',10,'0'))
						 || nvl(substr(lpad(trl.trl_loan7,10,'0'),1,10),lpad('0',10,'0'))
						 || nvl(substr(lpad(trl.trl_loan8,10,'0'),1,10),lpad('0',10,'0'))
						 || nvl(substr(lpad(trl.trl_loan9,10,'0'),1,10),lpad('0',10,'0'))
						 || nvl(substr(lpad(trl.trl_loan10,10,'0'),1,10),lpad('0',10,'0'))
						 || lpad('0',10,'0')  --display_number(trl.trl_comp_amount0)
						 || lpad('0',10,'0')  --display_number(trl.trl_comp_amount0)
						 || nvl(substr(lpad(trl.trl_comp_amount5,10,'0'),1,10),lpad('0',10,'0'))
                        );
        utl_file.put_line(v_daily_file, l_emp_output);
	END;

  COMMIT;
  UTL_FILE.FCLOSE(v_daily_file);

EXCEPTION
 WHEN UTL_FILE.INVALID_OPERATION THEN
		UTL_FILE.FCLOSE(v_daily_file);
		RAISE_APPLICATION_ERROR(-20051, p_FileName ||':  Invalid Operation');
  WHEN UTL_FILE.INVALID_FILEHANDLE THEN
		UTL_FILE.FCLOSE(v_daily_file);
		RAISE_APPLICATION_ERROR(-20052, p_FileName ||':  Invalid File Handle');
  WHEN UTL_FILE.READ_ERROR THEN
		UTL_FILE.FCLOSE(v_daily_file);
		RAISE_APPLICATION_ERROR(-20053, p_FileName ||':  Read Error');
  WHEN UTL_FILE.INVALID_PATH THEN
		UTL_FILE.FCLOSE(v_daily_file);
		RAISE_APPLICATION_ERROR(-20054, p_FileName ||':  Invalid Path');
  WHEN UTL_FILE.INVALID_MODE THEN
		UTL_FILE.FCLOSE(v_daily_file);
		RAISE_APPLICATION_ERROR(-20055, p_FileName ||':  Invalid Mode');
  WHEN UTL_FILE.WRITE_ERROR THEN
		UTL_FILE.FCLOSE(v_daily_file);
		RAISE_APPLICATION_ERROR(-20056, p_FileName ||':  Write Error');
  WHEN UTL_FILE.INTERNAL_ERROR THEN
		UTL_FILE.FCLOSE(v_daily_file);
		RAISE_APPLICATION_ERROR(-20057, p_FileName ||':  Internal Error');
  WHEN UTL_FILE.INVALID_MAXLINESIZE THEN
		UTL_FILE.FCLOSE(v_daily_file);
		RAISE_APPLICATION_ERROR(-20058, p_FileName ||':  Maxlinesize Error');
  WHEN OTHERS THEN
		UTL_FILE.FCLOSE(v_daily_file);
		dbms_output.put_line('ERROR');
        --CUST.TTEC_PROCESS_ERROR (g_application_code, g_interface, g_program_name, l_module_name,
        --                 'FAILURE', SQLCODE, SQLERRM);
		RAISE;

END;

END TT_401K_INTERFACE;
/
show errors;
/