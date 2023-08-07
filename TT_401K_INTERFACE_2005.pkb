create or replace PACKAGE BODY      Tt_401k_Interface_2005 IS






/************************************************************************************
        Program Name:    TT_401K_INTERFACE_2005

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

--l_temp_ssn hr.per_all_people_f.national_identifier%TYPE;  --code commented by RXNETHI-ARGANO,9/06/23
l_temp_ssn apps.per_all_people_f.national_identifier%TYPE;  --code added by RXNETHI-ARGANO,9/06/23
i NUMBER := 0;
n NUMBER := 1;

BEGIN
  SELECT LENGTH(v_ssn)
  INTO   i
  FROM   dual;

  IF (i > 0) THEN
    FOR c IN 1..i LOOP
      IF (UPPER(SUBSTR(v_ssn, n, 1)) BETWEEN '0' AND '9') THEN
        l_temp_ssn := (l_temp_ssn||SUBSTR(v_ssn, n, 1));
        n := n + 1;
      ELSE
        n := n + 1;
      END IF;
    END LOOP;
    v_ssn := l_temp_ssn;
  END IF;
  EXCEPTION WHEN OTHERS THEN
   apps.Fnd_File.put_line (apps.Fnd_File.log,' Error in Formating SSN Function for Employee' );
END;


-----------------------------------------------------------------------------------------------------
-- Begin display_number ----------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
FUNCTION display_number (p_amount IN NUMBER) RETURN VARCHAR2 IS


i VARCHAR2(10) := 0;

BEGIN

IF p_amount < 0 THEN
   i  :=  '-' ||  SUBSTR(LPAD(-p_amount,9,'0'),1,9)  ;
ELSIF p_amount >= 0 THEN
   i  :=  SUBSTR(LPAD(p_amount,10,'0'),1,10);
ELSE
   i  := LPAD('0',10,'0');
END IF;


  RETURN i;

EXCEPTION
   WHEN OTHERS THEN

    apps.Fnd_File.put_line (apps.Fnd_File.log,' Error in Display Number Function: ' || to_char(p_amount) );

     RAISE;

END;
-----------------------------------------------------------------------------------------------------
-- Begin format_address -----------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
PROCEDURE format_address (v_address IN OUT VARCHAR2) IS

--l_temp_address hr.per_addresses.address_line1%TYPE;   --code commented by RXNETHI-ARGANO,9/06/23
l_temp_address apps.per_addresses.address_line1%TYPE;   --code added by RXNETHI-ARGANO,9/06/23
i NUMBER := 0;
n NUMBER := 1;

BEGIN
  SELECT LENGTH(v_address)
  INTO   i
  FROM   dual;

  IF (i > 0) THEN
    FOR c IN 1..i LOOP
      IF (UPPER(SUBSTR(v_address, n, 1)) = '/') OR
         (UPPER(SUBSTR(v_address, n, 1)) = '#')THEN
        n := n + 1;
      ELSE
        l_temp_address := (l_temp_address||SUBSTR(v_address, n, 1));
        n := n + 1;
      END IF;
    END LOOP;
  END IF;
  v_address := l_temp_address;

   EXCEPTION WHEN OTHERS THEN

    apps.Fnd_File.put_line (apps.Fnd_File.log,' Error in Formating Address Function: ' || v_address );

END;

-----------------------------------------------------------------------------------------------------
-- Begin get_balance_amount ----- -------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
PROCEDURE get_balance_amount (v_person_id IN NUMBER, v_balance_type IN VARCHAR2,
                              v_begin_date IN DATE, v_end_date IN DATE,
							  v_balance OUT NUMBER) IS

	l_begin_date   DATE := TRUNC(v_begin_date);
	l_end_date     DATE := TRUNC(v_end_date) ;

    BEGIN


        SELECT NVL( ROUND(SUM(NVL(d.balance_value,0)),2), 0)
               INTO v_balance
        --FROM apps.xkb_balance_details d , apps.xkb_balances b, pay_balance_types p --code commented by RXNETHI-ARGANO,29/06/23
        FROM apps.xkb_balance_details d , apps.xkb_balances b, apps.pay_balance_types p --code added by RXNETHI-ARGANO,29/06/23
        WHERE p.balance_name = v_balance_type
		  AND p.balance_type_id = d.balance_type_id
          AND d.assignment_action_id = b.assignment_action_id
          AND b.creation_date BETWEEN l_begin_date AND l_end_date + 1
          AND b.person_id = v_person_id;

    EXCEPTION
  	        WHEN NO_DATA_FOUND THEN
	            		 v_balance := 0;
                          apps.Fnd_File.put_line (apps.Fnd_File.log,' No Data Found in Get Balance Amount For Employee Person ID:  ' ||to_char(v_person_id) ||' Balance Type: '|| v_balance_type );
   	    	WHEN TOO_MANY_ROWS THEN
                         v_balance := 0;
                          apps.Fnd_File.put_line (apps.Fnd_File.log,' Too Many Rows Error in Get Balance Amount For Employee Person ID: ' ||to_char(v_person_id) ||' Balance Type: '|| v_balance_type );
            WHEN OTHERS THEN
					     v_balance := 0;
                         apps.Fnd_File.put_line (apps.Fnd_File.log,' Error in Get Balance Amount For Employee Person ID: ' ||to_char(v_person_id) ||' Balance Type: '|| v_balance_type );
                         RAISE;
    END;

  /************************************************************************************/
  /*                                  GET_EMP_ADDRESS                                 */
  /************************************************************************************/
    PROCEDURE get_emp_address(p_person_id IN NUMBER, p_address_line1 OUT VARCHAR2,
	                         p_address_line2 OUT VARCHAR2, p_town_or_city OUT VARCHAR2,
							 p_region_2 OUT VARCHAR2, p_postal_code OUT VARCHAR2) IS

    BEGIN


      SELECT pad.address_line1, pad.address_line2, pad.town_or_city,
	         pad.region_2,  pad.postal_code
	    INTO p_address_line1, p_address_line2, p_town_or_city,
	         p_region_2,  p_postal_code
	    --FROM hr.per_addresses pad  --code commented by RXNETHI-ARGANO,9/06/23
	    FROM apps.per_addresses pad  --code added by RXNETHI-ARGANO,9/06/23
	    WHERE pad.person_id = p_person_id
		AND pad.primary_flag = 'Y'
	    AND SYSDATE BETWEEN pad.date_from AND NVL(pad.date_to,SYSDATE);

    EXCEPTION

             WHEN NO_DATA_FOUND THEN
             apps.Fnd_File.put_line (apps.Fnd_File.log,' No Address Found in Get Emp Address For Employee Person ID: ' ||to_char(p_person_id)  );
				NULL;

             WHEN TOO_MANY_ROWS THEN
             apps.Fnd_File.put_line (apps.Fnd_File.log,' Too Many Addresses Found in Get Emp Address For Employee Person ID: ' ||to_char(p_person_id)  );
				NULL;

             WHEN OTHERS THEN
             apps.Fnd_File.put_line (apps.Fnd_File.log,' Error in Get Emp Address For Employee Person ID: ' ||to_char(p_person_id)  );
			    RAISE;

    END;


  /************************************************************************************/
  /*                                  GET_PLAN_TYPE
  /*  Commented by C. Chan on Feb 22,2006
  /*  Stop using this procedure. Should use the package TT_HR.get_401K_plan_type to avoid maintaining
  /*  the same logic in 2 different packages.                                                  */
  /************************************************************************************/
    PROCEDURE get_plan_type(p_assignment_id IN NUMBER, p_employee_number IN VARCHAR2,
	                      p_effective_date IN DATE, p_plan_type OUT VARCHAR2
	                      ) IS
--START R12.2 Upgrade Remediation
/*	l_job_family      per_jobs.attribute5%TYPE;
	l_location_code    hr_locations.location_code%TYPE;*/
	l_job_family      apps.per_jobs.attribute5%TYPE;
	l_location_code    apps.hr_locations.location_code%TYPE;    
--End R12.2 Upgrade Remediation
    BEGIN


      SELECT	  job.attribute5, loc.location_code
	             INTO  l_job_family, l_location_code
	  FROM
    	 apps.hr_locations loc
	   , apps.per_jobs job
	   --,  hr.per_all_assignments_f asg  --code commented by RXNETHI-ARGANO,9/06/23
	   ,  apps.per_all_assignments_f asg  --code added by RXNETHI-ARGANO,9/06/23
    WHERE
	     asg.assignment_id = p_assignment_id
         AND   asg.primary_flag = 'Y'
         AND    asg.location_id = loc.location_id
         AND    p_effective_date BETWEEN asg.effective_start_date AND asg.effective_end_date
         AND    asg.job_id = job.job_id (+)
		 AND    ROWNUM < 2;

	   IF l_location_code  IN ( 'USA-Bremerton', 'USA-Deland', 'USA-Enfield' , 'USA-Fairfield', 'USA-Hampton')     THEN
	            IF  l_job_family   =  'Agent'      THEN
                     		   p_plan_type :=  'TT2'  ;
				ELSIF l_job_family  IS NULL THEN
				               p_plan_type :=  NULL  ;
				ELSE
				               p_plan_type :=  'TTI'  ;
			    END IF;
		ELSE
    		   p_plan_type :=  'TTI'  ;
		END IF;

    EXCEPTION

             WHEN OTHERS THEN
			    apps.Fnd_File.put_line (apps.Fnd_File.log,
				                ' Error in Get Plan Type ' || 'Employee Number: '||p_employee_number||' Assignment ID: '||p_assignment_id||' Effective Date: '||p_effective_date||
				                 '-'||SUBSTR(SQLERRM,1,30));
				p_plan_type :=  NULL;
    END;

  /************************************************************************************/
  /*                                  GET_ADP_REHIRE                                                                */
  /************************************************************************************/
   FUNCTION get_adp_rehire(p_person_id IN NUMBER
	                      )  RETURN VARCHAR2 IS

	l_rehire_months     hr.per_analysis_criteria.segment3%TYPE;

	CURSOR c_adp IS
	   (SELECT ac.segment3
        --FROM hr.per_person_analyses pa,   --code commented by RXNETHI-ARGANO,9/06/23
        FROM apps.per_person_analyses pa,   --code added by RXNETHI-ARGANO,9/06/23
                -- hr.per_analysis_criteria ac     --code commented by RXNETHI-ARGANO,9/06/23
                 apps.per_analysis_criteria ac     --code added by RXNETHI-ARGANO,9/06/23
       WHERE pa.analysis_criteria_id = ac.analysis_criteria_id
                     AND   pa.id_flex_num = 50217
					 AND   pa.person_id = p_person_id
                     AND   pa.date_from   = (SELECT MAX(pa1.date_from)
                                            FROM  hr.per_person_analyses pa1
                    						 WHERE
                    						 pa1.person_id = pa.person_id
                    						 AND pa1.id_flex_num = 50217 )
		 );

    BEGIN

    OPEN c_adp;
	FETCH c_adp INTO l_rehire_months;
	CLOSE c_adp;

    RETURN l_rehire_months;

        EXCEPTION WHEN OTHERS THEN

        apps.Fnd_File.put_line (apps.Fnd_File.log,' Error in Get ADP Rehire Function for Employee with  Person ID: ' || to_char(p_person_id)  );

    END;


  /************************************************************************************/
  /*                                  TRAILER                                 */
  /************************************************************************************/
    PROCEDURE print_trailer   ( TRL    IN   T_TRAILER_INFO,
							  p_emp_output_trailer  OUT VARCHAR2) IS

    BEGIN
             p_emp_output_trailer  :=    (g_trailer_type
                         || RPAD(' ',237,' ')
						 || NVL(SUBSTR(LPAD(trl.trl_hours_ytd,10,'0'),1,10),LPAD('0',10,'0'))
						 || NVL(SUBSTR(LPAD(trl.trl_cum_hours,10,'0'),1,10),LPAD('0',10,'0'))
						 || NVL(SUBSTR(LPAD(trl.trl_prior_months,10,'0'),1,10),LPAD('0',10,'0'))
						 || display_number(trl.trl_money_type1)
						 || display_number(trl.trl_money_type2)
						 || NVL(SUBSTR(LPAD(trl.trl_money_type3,10,'0'),1,10),LPAD('0',10,'0'))
					 	 || NVL(SUBSTR(LPAD(trl.trl_money_type4,10,'0'),1,10),LPAD('0',10,'0'))
						 || NVL(SUBSTR(LPAD(trl.trl_money_type5,10,'0'),1,10),LPAD('0',10,'0'))
						 || NVL(SUBSTR(LPAD(trl.trl_money_type6,10,'0'),1,10),LPAD('0',10,'0'))
						 || NVL(SUBSTR(LPAD(trl.trl_money_type7,10,'0'),1,10),LPAD('0',10,'0'))
						 || NVL(SUBSTR(LPAD(trl.trl_money_type8,10,'0'),1,10),LPAD('0',10,'0'))
						 || NVL(SUBSTR(LPAD(trl.trl_money_type9,10,'0'),1,10),LPAD('0',10,'0'))
						 || NVL(SUBSTR(LPAD(trl.trl_money_type10,10,'0'),1,10),LPAD('0',10,'0'))
						 || NVL(SUBSTR(LPAD(trl.trl_money_type11,10,'0'),1,10),LPAD('0',10,'0'))
						 || NVL(SUBSTR(LPAD(trl.trl_money_type12,10,'0'),1,10),LPAD('0',10,'0'))
						 || NVL(SUBSTR(LPAD(trl.trl_money_type13,10,'0'),1,10),LPAD('0',10,'0'))
						 || NVL(SUBSTR(LPAD(trl.trl_money_type14,10,'0'),1,10),LPAD('0',10,'0'))
						 || NVL(SUBSTR(LPAD(trl.trl_money_type15,10,'0'),1,10),LPAD('0',10,'0'))
						 || display_number(trl.trl_loan1)
						 || NVL(SUBSTR(LPAD(trl.trl_loan2,10,'0'),1,10),LPAD('0',10,'0'))
						 || NVL(SUBSTR(LPAD(trl.trl_loan3,10,'0'),1,10),LPAD('0',10,'0'))
						 || NVL(SUBSTR(LPAD(trl.trl_loan4,10,'0'),1,10),LPAD('0',10,'0'))
						 || NVL(SUBSTR(LPAD(trl.trl_loan5,10,'0'),1,10),LPAD('0',10,'0'))
						 || NVL(SUBSTR(LPAD(trl.trl_loan6,10,'0'),1,10),LPAD('0',10,'0'))
						 || NVL(SUBSTR(LPAD(trl.trl_loan7,10,'0'),1,10),LPAD('0',10,'0'))
						 || NVL(SUBSTR(LPAD(trl.trl_loan8,10,'0'),1,10),LPAD('0',10,'0'))
						 || NVL(SUBSTR(LPAD(trl.trl_loan9,10,'0'),1,10),LPAD('0',10,'0'))
						 || NVL(SUBSTR(LPAD(trl.trl_loan10,10,'0'),1,10),LPAD('0',10,'0'))
						 || NVL(SUBSTR(LPAD(trl.trl_comp_amount0,12,'0'),1,12),LPAD('0',12,'0'))
						 || NVL(SUBSTR(LPAD(trl.trl_comp_amount1,12,'0'),1,12),LPAD('0',12,'0'))
						 || NVL(SUBSTR(LPAD(trl.trl_comp_amount5,10,'0'),1,10),LPAD('0',10,'0'))
						 || NVL(SUBSTR(LPAD(trl.trl_salary,12,'0'),1,12),LPAD('0',12,'0'))  --549-558
						 || NVL(SUBSTR(RPAD('0',10,'0'),1,10),RPAD('0',10,'0'))    --559-568
                        );


    END;


 /************************************************************************************/
 /*                               MAIN PROGRAM PROCEDURE                             */
 /************************************************************************************/

 PROCEDURE main (ERRBUF OUT VARCHAR2, RETCODE OUT NUMBER,
                          P_BEGIN_DATE IN DATE, P_END_DATE IN DATE,  P_ELIGIBLE_DATE IN DATE,
						  P_OUTPUT_DIR IN VARCHAR2 ) IS


g_payroll_date    DATE := P_END_DATE;
g_year_begin      DATE :=  P_ELIGIBLE_DATE;

-----------------------------------------------------------------------------------------------------
-- Cursor declarations ------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
CURSOR c_emp_data IS
SELECT  'P' transaction_type
       , emp.national_identifier   ssn
       , emp.first_name  first_name
       , emp.last_name  last_name
	   , loc.attribute2    std_unit_id
	   , pt.user_person_type  person_type
       , TO_CHAR(emp.date_of_birth, 'MM/DD/YYYY')  dob
       , NVL(emp.original_date_of_hire,pos.date_start) hire_date
       , pos.date_start rehire_date
       , pos.date_start start_date
	   , asg.ass_attribute15 high_comp
	   , emp.date_of_death   date_of_death
	   , pos.last_update_date  last_update
       , pos.actual_termination_date term_date
	   , pos.final_process_date final_process_date
	   , DECODE(pay.period_type,'Bi-Week','113','Calendar Month','100','999') payroll_cycle_code
       , asg.assignment_id    asg_id
	   , emp.person_id   person_id
	   , loc.location_code
	   , ROUND (DECODE(ppb.pay_basis, 'ANNUAL',
                    ppp.proposed_salary_n, 'HOURLY',
                    ppp.proposed_salary_n * 2080, 0), 2) salary
	   , emp.employee_number
	   , DECODE (emp.marital_status, 'M' /* Married */ , 1,
	                         'C' /* Common Law */ , 1,
							 'D' /*  Divorced */ , 2,
							 'S' /* Single */ ,4,
							 'W' /* Widowed */ ,4,
							 'DP' /* Domestic */ ,4,
							  0) marital_status
	   , DECODE (emp.sex, 'F', 2, 'M', 1, 0) sex
       , apps.Tt_Hr.get_401k_plan_type (  asg.assignment_id, pos.date_start,
                                pos.actual_termination_date,  P_ELIGIBLE_DATE  )  plan_type
/*
START R12.2 Upgrade Remediation
code commented by RXNETHI-ARGANO,29/06/23
FROM
	 hr.per_periods_of_service pos
	,  hr.per_person_types pt
	,  hr.per_pay_proposals ppp
	,  per_pay_bases ppb
    ,  hr.pay_all_payrolls_f pay
	,  apps.hr_locations_all loc
	,  hr.per_all_people_f emp
	,  hr.per_all_assignments_f asg
*/
--code added by RXNETHI-ARGANO,29/06/23
FROM
	   apps.per_periods_of_service pos
	,  apps.per_person_types pt
	,  apps.per_pay_proposals ppp
	,  apps.per_pay_bases ppb
    ,  apps.pay_all_payrolls_f pay
	,  apps.hr_locations_all loc
	,  apps.per_all_people_f emp
	,  apps.per_all_assignments_f asg
--END R12.2 Upgrade Remediation
WHERE
       emp.person_type_id = pt.person_type_id (+)
AND    emp.person_id = asg.person_id
AND    emp.business_group_id = 325
AND    asg.payroll_id = pay.payroll_id
AND    asg.location_id = loc.location_id
AND    asg.period_of_service_id = pos.period_of_service_id
AND    asg.primary_flag = 'Y'
AND    asg.assignment_type = 'E'
AND    NVL(pos.actual_termination_date, p_end_date) >= p_end_date-365
AND    asg.pay_basis_id  = ppb.pay_basis_id (+)
AND    asg.assignment_id = ppp.assignment_id
AND    ppp.change_date = (SELECT MAX(ppp1.change_date)
                         --FROM hr.per_pay_proposals ppp1  --code commented by RXNETHI-ARGANO,29/06/23
                         FROM apps.per_pay_proposals ppp1  --code added by RXNETHI-ARGANO,29/06/23
						 WHERE
						 ppp1.assignment_id = ppp.assignment_id
						 AND SYSDATE >= ppp1.change_date)
AND    P_END_DATE BETWEEN emp.effective_start_date AND emp.effective_end_date
AND    P_END_DATE BETWEEN asg.effective_start_date AND asg.effective_end_date
AND    P_END_DATE BETWEEN pay.effective_start_date AND pay.effective_end_date
--AND asg.assignment_id NOT IN (SELECT as1.assignment_id FROM hr.per_all_assignments_f as1 --code commented by RXNETHI-ARGANO,29/06/23
AND asg.assignment_id NOT IN (SELECT as1.assignment_id FROM apps.per_all_assignments_f as1 --code added by RXNETHI-ARGANO,29/06/23
			      WHERE as1.assignment_id = asg.assignment_id
			      AND   as1.employment_category IN ('FT','PT') AND as1.payroll_id = 137
				  AND 	SYSDATE BETWEEN
				  		as1.effective_start_date AND as1.effective_end_date);
-----------------------------------------------------------------------------------------------------
-- Record declarations ------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
TYPE T_HEADER_INFO IS RECORD
(
  hdr_transaction_type   VARCHAR2(1) := 'H'
, hdr_payroll_date 	     VARCHAR2(10)
, hdr_plan_id            VARCHAR2(8) := '00000TTI'
);

  emp_sort_key       VARCHAR2(30);
  emp_extra_unit_id  VARCHAR2(5)  ;
  emp_highly_comp    VARCHAR2(9) ;
  emp_top_heavy      VARCHAR2(9) ;
  emp_entry_date     VARCHAR2(10) ;
  emp_hours_ytd        VARCHAR2(4);
  emp_cum_hours        VARCHAR2(4);

  /*
  START R12.2 Upgrade Remediation
  code commented by RXNETHI-ARGANO,29/06/23
  emp_addr_line1 	 hr.per_addresses.address_line1%TYPE;
  emp_addr_line2 	 hr.per_addresses.address_line2%TYPE;
  emp_city 			 hr.per_addresses.town_or_city%TYPE;
  emp_state 		 hr.per_addresses.region_2%TYPE;
  emp_zip_code 		 hr.per_addresses.postal_code%TYPE;
  */
  --code added by RXNETHI-ARGANO,29/06/23
  emp_addr_line1 	 apps.per_addresses.address_line1%TYPE;
  emp_addr_line2 	 apps.per_addresses.address_line2%TYPE;
  emp_city 			 apps.per_addresses.town_or_city%TYPE;
  emp_state 		 apps.per_addresses.region_2%TYPE;
  emp_zip_code 		 apps.per_addresses.postal_code%TYPE;
  --END R12.2 Upgrade Remediation


-- Declare variables

trl 	   	 	      T_TRAILER_INFO;
l_emp_output 	VARCHAR2(2500);
v_rows 			VARCHAR2(555);
l_wachovia_status VARCHAR2(15);

l_plan_type   VARCHAR2(10);

--l_module_name CUST.TTEC_ERROR_HANDLING.module_name%TYPE := '401';  --code commented by RXNETHI-ARGANO,29/06/23
l_module_name APPS.TTEC_ERROR_HANDLING.module_name%TYPE := '401';    --code added by RXNETHI-ARGANO,29/06/23

l_rehire_months NUMBER := 0;
l_money_type1  NUMBER := 0;
l_money_type2  NUMBER := 0;
l_loan1        NUMBER := 0 ;
l_comp_amount   NUMBER := 0;
l_comp_amount1 NUMBER := 0;
l_salary NUMBER := 0;
l_term_date   DATE ;

l_comp_ind     NUMBER := 0;

t_rehire_months_TTI NUMBER := 0;
t_money_type1_TTI   NUMBER := 0;
t_money_type2_TTI   NUMBER := 0;
t_loan1_TTI         NUMBER := 0 ;
t_salary_TTI        NUMBER := 0;
t_comp_TTI        NUMBER := 0;

t_rehire_months_TT2 NUMBER := 0;
t_money_type1_TT2   NUMBER := 0;
t_money_type2_TT2   NUMBER := 0;
t_loan1_TT2         NUMBER := 0 ;
t_salary_TT2       NUMBER := 0;
t_comp_TT2        NUMBER := 0;

BEGIN   -- employee and trailer
dbms_output.put_line('Opening files...');
  v_daily_file_TTI    := UTL_FILE.FOPEN(P_OUTPUT_DIR, p_FileName_TTI, 'w');
  v_daily_file_TT2  := UTL_FILE.FOPEN(P_OUTPUT_DIR, p_FileName_TT2, 'w');

  -- Header Information --
  BEGIN  --  Header
    l_emp_output := (g_header_type || TO_CHAR(g_payroll_date,'MM/DD/YYYY') || g_plan_id_TTI);
    utl_file.put_line(v_daily_file_TTI, l_emp_output);
    l_emp_output := (g_header_type || TO_CHAR(g_payroll_date,'MM/DD/YYYY') || g_plan_id_TT2);
    utl_file.put_line(v_daily_file_TT2, l_emp_output);
  END;  -- Header
  -- Employee Data Extract --
  BEGIN   -- employee
/*  **************************************************************************************************************
    Commented by C. Chan on Feb 22, 2006
    Stop calling procedure -> get_plan_type. Should use the package TT_HR.get_401K_plan_type to avoid maintaining
    the same logic in 2 different packages.
	The packed is called at the c_emp_data cursor.
    ***************************************************************************************************************

-- Edited BVB 01FEB06 to elminate 04 to 05 conversion
	IF  NVL(rec_emp.term_date, g_year_begin) < g_year_begin THEN
	    l_plan_type :=  'TTI';
    ELSE
	      IF rec_emp.start_date  < g_year_begin THEN
        	       get_plan_type(rec_emp.asg_id, rec_emp.employee_number  ,g_year_begin, l_plan_type) ;
	      ELSE
		 	       get_plan_type(rec_emp.asg_id, rec_emp.employee_number, rec_emp.start_date, l_plan_type) ;
	    --END IF;
    END IF;

*/
    FOR rec_emp IN c_emp_data LOOP

	    -- added by C. Chan on Feb 22, 2006 for TT#457571
		-- plan_type is obtained from TT_HR.get_401K_plan_type
		--  assign to l_plan_type since we commented out the redundant logic in this package
		--
	    l_plan_type := rec_emp.plan_type;

		IF rec_emp.ssn IS NOT NULL THEN
		    format_ssn(rec_emp.ssn);
      		rec_emp.ssn := SUBSTR(rec_emp.ssn,1,3)||'-'||SUBSTR(rec_emp.ssn,4,2)||'-'||SUBSTR(rec_emp.ssn,6,4);
		END IF;

		get_emp_address(rec_emp.person_id, emp_addr_line1,
	                         emp_addr_line2, emp_city ,
							 emp_state , emp_zip_code) ;


        format_address(emp_addr_line1);
        format_address(emp_addr_line2);


		l_money_type1 := 0;
		l_money_type2 := 0;
		l_loan1 := 0;
		l_comp_amount := 0;
		l_comp_amount1 := 0;
		l_salary := 0;

         BEGIN  -- Calculation
          v_rows := 'XX';
		  l_term_date := rec_emp.term_date;
		  IF rec_emp.term_date <= P_END_DATE THEN	 -- newly terminated
		     l_wachovia_status := 'TERM';
			 rec_emp.rehire_date := NULL;
		  ELSIF rec_emp.term_date > P_END_DATE THEN	 -- future termination
		     l_wachovia_status :=   '    ';
			 rec_emp.rehire_date := NULL;
			 l_term_date := NULL;
		  ELSIF   rec_emp.date_of_death IS NOT NULL THEN       -- deceased
		     l_wachovia_status := 'DTH';
		  ELSIF    (rec_emp.rehire_date <>rec_emp.hire_date) AND     --rehire
		                  (TRUNC(P_END_DATE) - NVL(rec_emp.rehire_date,P_END_DATE)) < 15 THEN
		 	 l_wachovia_status := 'ACTV' ;
		  ELSE                                                       -- active
	         l_wachovia_status :=   '    ';
		  END IF;

   		IF rec_emp.hire_date = rec_emp.rehire_date THEN
		   rec_emp.rehire_date := NULL;
 		END IF;

		-- get rehire months from the function vs main query
        l_rehire_months := get_adp_rehire(rec_emp.person_id);

            -- moved this to here, l_comp_amount was tested before being set   Wasim
            -- Change compensation balance to YTD

		get_balance_amount(rec_emp.person_id,'US_401K_Discrimination_Testing',
                           		TRUNC(p_end_date,'YYYY'), p_end_date, l_comp_amount);

		IF rec_emp.final_process_date IS NOT NULL AND l_comp_amount = 0 THEN
		   --skip this employee
		   l_rehire_months := 0;
           apps.Fnd_File.put_line (apps.Fnd_File.log,' - Record skipped - Final Process Date is Not Blank: ' ||to_char(rec_emp.final_process_date)|| ' and US_401K_Discrimination_Testing Comp Amount is Zero For Employee: ' || rec_emp.last_name || ', '|| rec_emp.first_name);
		   RAISE skip_record;
		END IF;

	 	-- Change compensation balance to YTD
		-- get_balance_amount(rec_emp.person_id,'US_401K_Discrimination_Testing',
        --                   		TRUNC(p_end_date,'YYYY'), p_end_date, l_comp_amount);


         -- apps.Fnd_File.put_line (apps.Fnd_File.log, 'after -- '|| rec_emp.last_name || ' L_comp  ' ||to_char(l_comp_amount)  );

		-- Get Payroll PTD Values
        get_balance_amount(rec_emp.person_id,'Def Comp 401K',p_begin_date,p_end_date,l_money_type1);
		get_balance_amount(rec_emp.person_id,'Loan 1_401k',p_begin_date,p_end_date,l_loan1);

        -- compensation end

 		l_comp_amount1 := l_comp_amount * 100;
		l_money_type1 := l_money_type1 * 100;
		l_money_type2 := 0;
		l_loan1 := l_loan1 * 100;
		l_salary := rec_emp.salary * 100;


          IF rec_emp.high_comp IN ('5%','7%','9%') THEN  --per Nancy Fabick, CA
		     l_comp_ind  :=  3;
		  ELSE
		     l_comp_ind := 0;
		  END IF;


	      -- Calculate summary totals for trailer record
		  IF   l_plan_type =  'TTI'   THEN
		       t_rehire_months_TTI := t_rehire_months_TTI + NVL(l_rehire_months,0);
               t_money_type1_TTI := t_money_type1_TTI + NVL(l_money_type1,0);
		       t_money_type2_TTI := t_money_type2_TTI + NVL(l_money_type2,0);
		       t_loan1_TTI := t_loan1_TTI + NVL(l_loan1,0);
			   t_salary_TTI  := t_salary_TTI  + NVL(l_salary,0) ;
			   t_comp_TTI  := t_comp_TTI  + NVL(l_comp_amount1,0) ;
		  ELSIF  l_plan_type =  'TT2'   THEN
		       t_rehire_months_TT2 := t_rehire_months_TT2 + NVL(l_rehire_months,0);
		       t_money_type1_TT2 := t_money_type1_TT2 + NVL(l_money_type1,0);
		       t_money_type2_TT2 := t_money_type2_TT2 + NVL(l_money_type2,0);
		       t_loan1_TT2 := t_loan1_TT2 + NVL(l_loan1,0);
			   t_salary_TT2  := t_salary_TT2  + NVL(l_salary,0) ;
			   t_comp_TT2  := t_comp_TT2  + NVL(l_comp_amount1,0) ;
          ELSE
                apps.Fnd_File.put_line (apps.Fnd_File.log, ' No Plan Type Found for Employee ' || rec_emp.last_name || ' ,'||rec_emp.first_name );
		  END IF;


        EXCEPTION
		  WHEN SKIP_RECORD THEN
            v_rows := NULL;
            apps.Fnd_File.put_line (apps.Fnd_File.log,' Error in Main Processing Program for Employee: '
            || rec_emp.last_name ||', '|| rec_emp.first_name ||' - Person ID: ' || to_char(rec_emp.person_id)
             );
          WHEN OTHERS THEN
            RAISE;
        END;   -- Calculation

        IF (v_rows IS NOT NULL) THEN
        l_emp_output := (g_transaction_type  -- 1-1
                 || NVL(SUBSTR(RPAD(rec_emp.ssn,11,' '),1,11),'999-99-9999')  -- 2-12
                 || NVL(SUBSTR(RPAD(UPPER(rec_emp.first_name),15,' '),1,15),RPAD(' ',15,' '))	--13-27
                 || NVL(SUBSTR(RPAD(UPPER(rec_emp.last_name),30,' '),1,30), RPAD(' ',30,' '))  --28-57
 				 || NVL(RPAD(emp_sort_key,30,' '),RPAD(' ',30,' '))		--58-87
                 || NVL(SUBSTR(RPAD(UPPER(emp_addr_line1),30,' '),1,30),RPAD(' ',30,' '))  --88-117
                 || NVL(SUBSTR(RPAD(UPPER(emp_addr_line2),30,' '),1,30),RPAD(' ',30,' '))  --118-147
                 || NVL(SUBSTR(RPAD(UPPER(emp_city),23,' '),1,23),RPAD(' ',23,' ')) --148-170
                 || NVL(SUBSTR(RPAD(UPPER(emp_state),2,' '),1,2),RPAD(' ',2,' ')) --171-172
                 || NVL(SUBSTR(RPAD(emp_zip_code,10,' '),1,10),LPAD(' ',10,' '))  --173-182
 				 || NVL(SUBSTR(LPAD(rec_emp.std_unit_id,5,'0'),1,5),LPAD('0',5,'0'))   --183-187
                 || NVL(SUBSTR(RPAD(emp_extra_unit_id,5,' '),1,5),RPAD(' ',5,' '))    --188-192
 				 || NVL(SUBSTR(RPAD(UPPER(l_wachovia_status),4,' '),1,4),RPAD(' ',4,' '))   --193-196
 				 || l_comp_ind    --nvl(substr(rpad(rec_emp.highly_comp,1,' '),1,1),' ')  -- 197
 				 || NVL(SUBSTR(RPAD(emp_top_heavy,1,' '),1,1),'0')  --198
 				 || NVL(SUBSTR(RPAD(NULL,10,' '),1,10), RPAD(' ',10,' '))  -- date of plan entry (blank)  199-208
 				 || NVL(SUBSTR(RPAD(rec_emp.dob,10,' '),1,10), RPAD(' ',10,' '))   --209-218
 				 || NVL(SUBSTR(RPAD(TO_CHAR(rec_emp.hire_date,'MM/DD/YYYY'),10,' '),1,10),RPAD(' ',10,' '))   --219-228
 				 || NVL(SUBSTR(RPAD(TO_CHAR(rec_emp.rehire_date,'MM/DD/YYYY'),10,' '),1,10),RPAD(' ',10,' '))   --229-238
 				 || NVL(SUBSTR(RPAD(TO_CHAR(l_term_date,'MM/DD/YYYY'),10,' '),1,10),RPAD(' ',10,' '))   --  239-248
 				 || NVL(SUBSTR(RPAD(rec_emp.payroll_cycle_code,3,' '),1,3),RPAD(' ',3,' '))   --249-251
				 || NVL(SUBSTR(RPAD(rec_emp.sex,1,' '),1,1),RPAD(' ',1,' '))  -- 252
				 || NVL(SUBSTR(RPAD(rec_emp.marital_status,1,' '),1,1),RPAD(' ',1,' '))  -- 253
				 || RPAD(' ',1,' ')  -- 254  --language
 				 || NVL(SUBSTR(LPAD(emp_hours_ytd,4,'0'),1,4),LPAD('0',4,'0'))   --255-258
 				 || NVL(SUBSTR(LPAD(emp_cum_hours,4,'0'),1,4),LPAD('0',4,'0'))    --259-262
 				 || NVL(SUBSTR(LPAD(l_rehire_months,3,'0'),1,3),LPAD('0',3,'0'))   --263-265
				 || RPAD(' ',3,' ')  -- 266-268  --eligibility months
 				 || display_number(l_money_type1)   --269-278
 				 || display_number(l_money_type2)    --279-288
 				 || NVL(SUBSTR(LPAD(0,10,'0'),1,10),LPAD('0',10,'0'))	  -- money_type3
 			 	 || NVL(SUBSTR(LPAD(0,10,'0'),1,10),LPAD('0',10,'0'))	  -- money_type4
 				 || NVL(SUBSTR(LPAD(0,10,'0'),1,10),LPAD('0',10,'0'))	  -- money_type5
 				 || NVL(SUBSTR(LPAD(0,10,'0'),1,10),LPAD('0',10,'0'))	  -- money_type6
 				 || NVL(SUBSTR(LPAD(0,10,'0'),1,10),LPAD('0',10,'0'))	  -- money_type7
 				 || NVL(SUBSTR(LPAD(0,10,'0'),1,10),LPAD('0',10,'0'))	  -- money_type8
 				 || NVL(SUBSTR(LPAD(0,10,'0'),1,10),LPAD('0',10,'0'))	  -- money_type9
 				 || NVL(SUBSTR(LPAD(0,10,'0'),1,10),LPAD('0',10,'0'))	  -- money_type10
 				 || NVL(SUBSTR(LPAD(0,10,'0'),1,10),LPAD('0',10,'0'))	  -- money_type11
 				 || NVL(SUBSTR(LPAD(0,10,'0'),1,10),LPAD('0',10,'0'))	  -- money_type12
 				 || NVL(SUBSTR(LPAD(0,10,'0'),1,10),LPAD('0',10,'0'))	  -- money_type13
 				 || NVL(SUBSTR(LPAD(0,10,'0'),1,10),LPAD('0',10,'0'))	  -- money_type14
 				 || NVL(SUBSTR(LPAD(0,10,'0'),1,10),LPAD('0',10,'0'))	  -- money_type15
 				 || display_number(l_loan1)   --419-428
 				 || NVL(SUBSTR(LPAD(0,10,'0'),1,10),LPAD('0',10,'0'))   	  --  loan2
 				 || NVL(SUBSTR(LPAD(0,10,'0'),1,10),LPAD('0',10,'0'))   	  --  loan3
 				 || NVL(SUBSTR(LPAD(0,10,'0'),1,10),LPAD('0',10,'0'))   	  --  loan4
 				 || NVL(SUBSTR(LPAD(0,10,'0'),1,10),LPAD('0',10,'0'))   	  --  loan5
 				 || NVL(SUBSTR(LPAD(0,10,'0'),1,10),LPAD('0',10,'0'))   	  --  loan6
 				 || NVL(SUBSTR(LPAD(0,10,'0'),1,10),LPAD('0',10,'0'))   	  --  loan7
 				 || NVL(SUBSTR(LPAD(0,10,'0'),1,10),LPAD('0',10,'0'))	  --  loan8
 				 || NVL(SUBSTR(LPAD(0,10,'0'),1,10),LPAD('0',10,'0'))	  --  loan9
 				 || NVL(SUBSTR(LPAD(0,10,'0'),1,10),LPAD('0',10,'0'))	  --  loan10
 				 || display_number(l_comp_amount1)   --519-528 comp0
 				 || display_number(l_comp_amount1)   --529-538 comp1
 				 || NVL(SUBSTR(LPAD(l_salary,10,'0'),1,10),LPAD('0',10,'0'))   --539-548
 				 || NVL(SUBSTR(LPAD(0,10,'0'),1,10),LPAD('0',10,'0'))  	   --  549-558  comp_amount5
 				 || NVL(SUBSTR(RPAD(rec_emp.employee_number,7,'0'),1,7),RPAD('0',7,'0'))   --559-565
                        );
		IF   l_plan_type =  'TTI'   THEN
                 utl_file.put_line(v_daily_file_TTI, l_emp_output);
		ELSIF  l_plan_type =  'TT2'   THEN
                 utl_file.put_line(v_daily_file_TT2, l_emp_output);
        ELSE
                apps.Fnd_File.put_line (apps.Fnd_File.log, ' No Plan Type Found for Employee: ' || rec_emp.last_name || ' ,'||rec_emp.first_name );

		END IF;
        ELSE
                apps.Fnd_File.put_line (apps.Fnd_File.log, ' No Rows Found for Employee: ' || rec_emp.last_name || ' ,'||rec_emp.first_name );

        END IF;
    END LOOP;

  END;   -- employee

  	   BEGIN    --  Trailer

  -- Trailer Information --
  		      trl.trl_prior_months := t_rehire_months_TTI;
		      trl.trl_money_type1 := t_money_type1_TTI;
		      trl.trl_money_type2 := t_money_type2_TTI;
		      trl.trl_loan1 := t_loan1_TTI;
			  trl.trl_salary  := t_salary_TTI  ;
			  trl.trl_comp_amount0  :=  t_comp_TTI ;
			  trl.trl_comp_amount1  :=  t_comp_TTI  ;

			  apps.Fnd_File.put_line (1,'salary'||t_salary_TTI);

			  print_trailer   ( TRL ,  l_emp_output );

              utl_file.put_line(v_daily_file_TTI, l_emp_output);

  		      trl.trl_prior_months := t_rehire_months_TT2;
		      trl.trl_money_type1 := t_money_type1_TT2;
		      trl.trl_money_type2 := t_money_type2_TT2;
		      trl.trl_loan1 := t_loan1_TT2;
			  trl.trl_salary  := t_salary_TT2 ;
			  trl.trl_comp_amount0  :=  t_comp_TT2 ;
			  trl.trl_comp_amount1  :=  t_comp_TT2  ;

  			  apps.Fnd_File.put_line (1,'salary '||t_salary_TT2);

	          print_trailer   ( TRL ,  l_emp_output );

              utl_file.put_line(v_daily_file_TT2, l_emp_output);

	END;  -- Trailer

  UTL_FILE.FCLOSE(v_daily_file_TTI);
  UTL_FILE.FCLOSE(v_daily_file_TT2);

EXCEPTION
 WHEN UTL_FILE.INVALID_OPERATION THEN
		UTL_FILE.FCLOSE(v_daily_file_TTI);
		UTL_FILE.FCLOSE(v_daily_file_TT2);
		RAISE_APPLICATION_ERROR(-20051, p_FileName_TTI ||':  Invalid Operation');
  WHEN UTL_FILE.INVALID_FILEHANDLE THEN
		UTL_FILE.FCLOSE(v_daily_file_TTI);
		UTL_FILE.FCLOSE(v_daily_file_TT2);
		RAISE_APPLICATION_ERROR(-20052, p_FileName_TTI ||':  Invalid File Handle');
  WHEN UTL_FILE.READ_ERROR THEN
		UTL_FILE.FCLOSE(v_daily_file_TTI);
		UTL_FILE.FCLOSE(v_daily_file_TT2);
		RAISE_APPLICATION_ERROR(-20053, p_FileName_TTI ||':  Read Error');
  WHEN UTL_FILE.INVALID_PATH THEN
		UTL_FILE.FCLOSE(v_daily_file_TTI);
		UTL_FILE.FCLOSE(v_daily_file_TT2);
		RAISE_APPLICATION_ERROR(-20054, p_FileName_TTI ||':  Invalid Path');
  WHEN UTL_FILE.INVALID_MODE THEN
		UTL_FILE.FCLOSE(v_daily_file_TTI);
		UTL_FILE.FCLOSE(v_daily_file_TT2);
		RAISE_APPLICATION_ERROR(-20055, p_FileName_TTI ||':  Invalid Mode');
  WHEN UTL_FILE.WRITE_ERROR THEN
		UTL_FILE.FCLOSE(v_daily_file_TTI);
		UTL_FILE.FCLOSE(v_daily_file_TT2);
		RAISE_APPLICATION_ERROR(-20056, p_FileName_TTI ||':  Write Error');
  WHEN UTL_FILE.INTERNAL_ERROR THEN
		UTL_FILE.FCLOSE(v_daily_file_TTI);
		UTL_FILE.FCLOSE(v_daily_file_TT2);
		RAISE_APPLICATION_ERROR(-20057, p_FileName_TTI ||':  Internal Error');
  WHEN UTL_FILE.INVALID_MAXLINESIZE THEN
		UTL_FILE.FCLOSE(v_daily_file_TTI);
		UTL_FILE.FCLOSE(v_daily_file_TT2);
		RAISE_APPLICATION_ERROR(-20058, p_FileName_TTI ||':  Maxlinesize Error');
  WHEN OTHERS THEN
		UTL_FILE.FCLOSE(v_daily_file_TTI);
		UTL_FILE.FCLOSE(v_daily_file_TT2);
		dbms_output.put_line('ERROR');
        --CUST.TTEC_PROCESS_ERROR (g_application_code, g_interface, g_program_name, l_module_name,
        --      'FAILURE', SQLCODE, SQLERRM);
		RAISE;

END;    -- employee and trailer

END Tt_401k_Interface_2005;
/
show errors;
/