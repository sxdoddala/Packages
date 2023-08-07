create or replace PACKAGE BODY Tt_Pto_Ff_Util_Pkg
AS
   g_package   VARCHAR2 (33) := ' TT_PTO_FF_UTIL';    -- Global package name

   FUNCTION get_person_type (p_assignment_id IN NUMBER, p_effective_date IN  DATE)
      RETURN VARCHAR2
   IS
      CURSOR c_person_type
      IS
         (SELECT pj.attribute5
            FROM per_all_assignments_f paaf, per_jobs pj
           WHERE paaf.assignment_id = p_assignment_id
             AND p_effective_date BETWEEN paaf.effective_start_date
                                     AND paaf.effective_end_date
             AND paaf.assignment_type = 'E'
             AND paaf.primary_flag = 'Y'
             AND paaf.job_id = pj.job_id);

      l_person_type   VARCHAR2 (20);
   BEGIN
      OPEN c_person_type;

      FETCH c_person_type
       INTO l_person_type;

      CLOSE c_person_type;

      RETURN l_person_type;
   END;

/* Added for US PTO Project*/

FUNCTION get_P2M2_above_eligibility (p_assignment_id IN NUMBER, p_effective_date IN  DATE,p_work_city IN VARCHAR2,p_job IN VARCHAR2 )
      RETURN VARCHAR2
   IS
      CURSOR c_gca_coding
      IS
         (SELECT pj.attribute20
            FROM per_all_assignments_f paaf, per_jobs pj
           WHERE paaf.assignment_id = p_assignment_id
             AND p_effective_date BETWEEN paaf.effective_start_date
                                     AND paaf.effective_end_date
             AND paaf.assignment_type = 'E'
             AND paaf.primary_flag = 'Y'
			 AND pj.attribute20 in ('P2','P3','P4','P5','P6','M2','M3','M4','M5','M6','C1','C2','C3','C4','C5','C6','CD4','CD3','CD2')
             AND paaf.job_id = pj.job_id);

      l_gca_flag   VARCHAR2 (10);
   BEGIN

      BEGIN
      OPEN c_gca_coding;

      FETCH c_gca_coding
       INTO l_gca_flag;
	  CLOSE c_gca_coding;

	  IF l_gca_flag IS NULL
	  THEN
	     l_gca_flag:='N';
	  ELSE
	     l_gca_flag:='Y';
	  END IF;

      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            l_gca_flag:='N';
      END;

	  IF l_gca_flag='Y'
	  THEN
	     IF p_work_city='Tempe' AND p_job in ( 'DA1105.Manager, Sales Delivery I'

		 /*'DA1025.Acquistion Representative (Outbound Sales Rep)',
					  '26010.CSR I',
					  '26007.CSR III',
					  'DA1042.Customer Care Lead',
					  'DA1042-H.Customer Care Lead - Hourly',
					  'DA1043.Customer Service Rep',
					  'DA1043H.Customer Service Rep - Hourly',
					  'DA1214.Customer Service Rep - Part-Time',
					  'DA1216.Customer Service Rep Toshiba',
					  'DA26008.Customer Service Representative Level II',
					  'DA26008-H.Customer Service Representative Level II - Hourly',
					  'DA26009.Customer Service Representative Level III',
					  'DA26009-H.Customer Service Representative Level III - Hourly',
					  'DA1217.Inbound Sales Access Toshiba',
					  'DA25025.Inbound Sales Assoc II',
					  'DA1218.Inbound Sales Part-Time',
					  'DA25015.Inbound Sales Rep II',
					  'DA25016.Inbound Sales Rep III',
					  'DA1076-H.Inbound Sales Representative-Hourly',
					  'DA25017.Inside Sales Account Manager I',
					  'DA25017-H.Inside Sales Account Manager I - Hourly',
					  'DA25010.Inside Sales Account Manager II',
					  'DA25010-H.Inside Sales Account Manager II- Hourly',
					  'DA25011.Inside Sales Account Manager III',
					  'DA25011-H.Inside Sales Account Manager III - Hourly',
					  'DA25012.Inside Sales Specialist I',
					  'DA25012-H.Inside Sales Specialist I - Hourly',
					  'DA25013.Inside Sales Specialist II',
					  'DA25013-H.Inside Sales Specialist II - Hourly',
					  'DA25014.Inside Sales Specialist III',
					  'DA26006.Lead Associate, CSR',
					  'DA10017.Lead Qualifier',
					  'DA10017-H.Lead Qualifier',
					  'DA1224.Lead, Sales Representative',
					  'DA1224-H.Lead, Sales Representative',
					  'DA90028.Marketing Campaign Specialist I',
					  'DA90028-H.Marketing Campaign Specialist I - Hourly',
					  'DA1141-L.OSR -  Lead Generation',
					  '29010.OSR I',
					  '29008.OSR II',
					  '29007.OSR III',
					  'DA1141-H.Outbound Sales Rep - Hourly',
					  'DA1141-PT.Outbound Sales Rep - Part-Time',
					  'DA1141.Outbound Sales Representative',
					  'DA25023.Outbound Sales Representative - Tier II',
					  'DA25023-H.Outbound Sales Representative - Tier II',
					  'DA25024.Outbound Sales Representative Tier III',
					  'DA25024-H.Outbound Sales Representative Tier III -',
					  'DA25024-H.Outbound Sales Representative Tier III - Hourly',
					  'DA27007.TSR III',
					  'DA1202.Web Chat Representative',
					  'DA1202-H.Web Chat Representative',
					  'DA12021-H.Web Chat Representative Lvl 2',
					  'DA1141a.Outbound Sales Representative',
					  'DA1141-Ha.Outbound Sales Rep - Hourly',
					  'DA25011a.Inside Sales Account Manager III',
					  'DA25017a.Inside Sales Account Manager I'*/)
		 THEN
		    l_gca_flag:='N';
		 END IF;
	  END IF;


      RETURN l_gca_flag;
   END; /* End Function get_P2M2_above_eligibility */

   /* Function return Y if the employee is a Google employee */
   FUNCTION check_google_emp (p_assignment_id IN NUMBER,p_business_group_id IN NUMBER,p_effective_date IN  DATE)
      RETURN VARCHAR2
   IS

      CURSOR c_google_emp
      IS
         (
		    SELECT
             'Y'
            FROM cust.ttec_emp_proj_asg tpa ,per_all_assignments_f paaf
            WHERE paaf.assignment_id=p_assignment_id
			AND  paaf.business_group_id=p_business_group_id
			AND UPPER(tpa.client_desc) LIKE '%GOOGLE%'
           -- AND tpa.business_group_id = p_business_group_id
			AND tpa.person_id=paaf.person_id
			and p_effective_date BETWEEN paaf.effective_start_date and paaf.effective_end_date
            AND p_effective_date BETWEEN tpa.prj_strt_dt AND nvl(tpa.prj_end_dt,TO_DATE('31-DEC-4712','DD-MON-YYYY'))
		);

      l_Emp_flag   varchar2(2):='N';

   BEGIN


      OPEN c_google_emp;

	  BEGIN

       FETCH c_google_emp
       INTO l_Emp_flag;

	  EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            l_Emp_flag:='N';
      END;

      CLOSE c_google_emp;

      RETURN l_Emp_flag;
   END; /* End check_google_emp */

/* End chnages for US PTO Project NOV 2019 */

/* Function added to fix the acrual issue for previous yeares term emps. on 06-FEB-2020*/
FUNCTION tt_payoll_year_first_val_date (p_payroll_id IN NUMBER,p_effective_date IN  DATE)
      RETURN DATE
   IS

      CURSOR c_payroll_start_date
      IS
         (
		    select start_date
             from per_time_periods
             where payroll_id=p_payroll_id
             and period_num=1
             and SUBSTR(period_name,3,4)=to_char(p_effective_date,'YYYY')
		);

      period_start_date   date;

   BEGIN


      OPEN c_payroll_start_date;

	  BEGIN

       FETCH c_payroll_start_date
       INTO period_start_date;

	  EXCEPTION
         WHEN OTHERS
         THEN
            period_start_date:=to_date('1-JAN-1951','DD-MON-YYYY');
      END;

      CLOSE c_payroll_start_date;

      RETURN period_start_date;
   END; /* End get_payroll_year_begin */

---
   FUNCTION Get_Pay_Date
   (P_Payroll_ID                     IN  NUMBER
   ,P_Date_In_Period                 IN  DATE) RETURN DATE IS
   --
  l_proc        VARCHAR2(72) := g_package||'Get_Pay_Date';
  --
CURSOR csr_get_payroll_period IS
SELECT regular_payment_date
FROM   per_time_periods
WHERE  payroll_id = P_Payroll_ID
AND    P_Date_In_Period BETWEEN start_date AND end_date;
--
l_pay_date DATE;
--
l_error NUMBER;
--
BEGIN
   Hr_Utility.set_location(l_proc, 5);
   --
   OPEN csr_get_payroll_period;
   FETCH csr_get_payroll_period INTO l_pay_date;
   IF csr_get_payroll_period%NOTFOUND THEN
      CLOSE csr_get_payroll_period;
      Hr_Utility.set_location('Payroll Period not found '||l_proc, 10);
      l_error := Per_Formula_Functions.raise_error(800, 'HR_52798_PTO_PAYROLL_INVALID');
      RETURN NULL;
   END IF;
   CLOSE csr_get_payroll_period;
   --

   Hr_Utility.set_location(l_proc, 15);

   RETURN    l_pay_date;

END Get_Pay_Date;

--
   FUNCTION get_hours (
      p_assignment_id       IN   NUMBER,
      p_business_group_id   IN   NUMBER,
      p_period_ed           IN   DATE
   )
      RETURN NUMBER
   IS
--
      l_proc               VARCHAR2 (72) := g_package || 'tt_pto_get_hours';
      l_balname1            VARCHAR2 (50);
	  l_balname2            VARCHAR2 (50);
      l_defined_bal_id1     NUMBER;
      l_defined_bal_id2     NUMBER;
      l_user_entity_name1   VARCHAR2 (60);
      l_user_entity_name2   VARCHAR2 (60);
      l_value              NUMBER (9, 2) := 0;
      l_temp_value         NUMBER (9, 2);
	  l_virtual_date        DATE;
   BEGIN
      BEGIN                                              -- set context first

        Pay_Balance_Pkg.set_context ('BUSINESS_GROUP_ID',TO_CHAR (p_business_group_id) );
  		Pay_Balance_Pkg.set_context ('TAX_UNIT_ID', TO_CHAR(346));

      EXCEPTION
         WHEN OTHERS
         THEN
            DBMS_OUTPUT.PUT_LINE ('Error setting context');
      END;

      BEGIN                                          -- get defined balance id
         l_balname1 :=  'PTO_ELIGIBLE_HOURS';
         l_balname2  :=  'US_REGULAR_SALARY_HOURS';

         SELECT    UPPER (REPLACE (l_balname1, ' ', '_'))
                || '_'
                || 'ASG'
                || '_'
				|| 'GRE'
				|| '_'
                || 'PTD'
           INTO l_user_entity_name1
           FROM DUAL;

         DBMS_OUTPUT.PUT_LINE ('l_user_entity_name1=' || l_user_entity_name1);

         SELECT creator_id
           INTO l_defined_bal_id1
           FROM ff_user_entities
          WHERE user_entity_name = l_user_entity_name1
            AND business_group_id = p_business_group_id;


			 SELECT    UPPER (REPLACE (l_balname2, ' ', '_'))
                || '_'
                || 'ASG'
                || '_'
				|| 'GRE'
				|| '_'
                || 'PTD'
           INTO l_user_entity_name2
           FROM DUAL;

         DBMS_OUTPUT.PUT_LINE ('l_user_entity_name2=' || l_user_entity_name2);

         SELECT creator_id
           INTO l_defined_bal_id2
           FROM ff_user_entities
          WHERE user_entity_name = l_user_entity_name2
            AND business_group_id = p_business_group_id;
      EXCEPTION
         WHEN OTHERS
         THEN
            DBMS_OUTPUT.PUT_LINE ('Error getting defined bal id');
      END;

      BEGIN                                                       -- get value
	     l_virtual_date := p_period_ed + 14;

         l_value :=
            Pay_Balance_Pkg.get_value                            -- Get Value
                                   (p_defined_balance_id      => l_defined_bal_id1,
                                    p_assignment_id           => p_assignment_id,
                                    p_virtual_date            =>   l_virtual_date
                                   );

		  l_value := NVL(l_value,0) +
            NVL(Pay_Balance_Pkg.get_value                            -- Get Value
                                   (p_defined_balance_id      => l_defined_bal_id2,
                                    p_assignment_id           => p_assignment_id,
                                    p_virtual_date            =>   l_virtual_date
                                   ),0)  ;
      EXCEPTION
         WHEN OTHERS
         THEN
            DBMS_OUTPUT.PUT_LINE ('Error getting value');
      END;


      RETURN l_value;
   END get_hours;

   FUNCTION get_hours_action (
      p_assignment_id       IN   NUMBER,
      p_business_group_id   IN   NUMBER,
	  p_period_sd           IN DATE,
      p_period_ed           IN   DATE
   )
      RETURN NUMBER
   IS
--
      l_proc               VARCHAR2 (72) := g_package || 'get_hours_action';
      l_balname1            VARCHAR2 (50);
	  l_balname2            VARCHAR2 (50);
      l_defined_bal_id1     NUMBER;
      l_defined_bal_id2     NUMBER;
      l_user_entity_name1   VARCHAR2 (60);
      l_user_entity_name2   VARCHAR2 (60);
      l_value              NUMBER := 0;

	  CURSOR c_action IS
	  SELECT
              paa.assignment_action_id , paa.tax_unit_id
      FROM
	    pay_assignment_actions       paa
       ,pay_payroll_actions          ppa
     WHERE
        ppa.date_earned  BETWEEN p_period_sd AND p_period_ed
       AND paa.payroll_action_id     = ppa.payroll_action_id
       AND paa.assignment_id =  p_assignment_id
       --AND ppa.action_status     =  'C'
       --AND paa.action_status     =  'C'
       AND paa.run_type_id IS NOT NULL;

   BEGIN
      BEGIN    -- set context first
	  Hr_Utility.set_location ('Entering '||l_proc, 10);
	  Hr_Utility.set_location ('Assignment:'||p_assignment_id || l_proc, 10);

        Pay_Balance_Pkg.set_context ('BUSINESS_GROUP_ID',TO_CHAR (p_business_group_id) );

      EXCEPTION
         WHEN OTHERS
         THEN
            --DBMS_OUTPUT.put_line ('Error setting context');
			Hr_Utility.set_location ('Error getting context '||l_proc, 10);
      END;

      BEGIN         -- get defined balance id
         l_balname1 :=  'PTO_ELIGIBLE_HOURS';
         l_balname2  :=  'US_REGULAR_SALARY_HOURS';

		 l_user_entity_name1 :=
                l_balname1
                || '_'
                || 'ASG'
                || '_'
				|| 'GRE'
				|| '_'
                || 'RUN';

         SELECT creator_id
           INTO l_defined_bal_id1
           FROM ff_user_entities
          WHERE user_entity_name = l_user_entity_name1
            AND business_group_id = p_business_group_id;

		  l_user_entity_name2 :=    l_balname2
                || '_'
                || 'ASG'
                || '_'
				|| 'GRE'
				|| '_'
                || 'RUN';

         SELECT creator_id
           INTO l_defined_bal_id2
           FROM ff_user_entities
          WHERE user_entity_name = l_user_entity_name2
            AND business_group_id = p_business_group_id;
      EXCEPTION
         WHEN OTHERS
         THEN
            --DBMS_OUTPUT.put_line ('Error getting defined bal id');
			Hr_Utility.set_location ('Error getting define bal id '||l_proc, 10);
      END;

      BEGIN

	   FOR r_action IN c_action  LOOP
	     BEGIN
		    Hr_Utility.set_location( 'Period ED '||p_period_ed, 10);
  		    Pay_Balance_Pkg.set_context ('TAX_UNIT_ID', r_action.tax_unit_id);
            l_value := l_value +
                   NVL(Pay_Balance_Pkg.get_value                            -- Get Value
                                   (p_defined_balance_id      => l_defined_bal_id1,
                                    p_assignment_action_id     => r_action.assignment_action_id
                                   ),0);
		    l_value := NVL(l_value,0) +
                     NVL(Pay_Balance_Pkg.get_value                            -- Get Value
                                   (p_defined_balance_id      => l_defined_bal_id2,
                                    p_assignment_action_id     => r_action.assignment_action_id
                                   ),0)  ;

		 	Hr_Utility.set_location( 'Value Hours:'||l_value, 10);

		  EXCEPTION
			   WHEN OTHERS THEN
					  Hr_Utility.set_location('Error getting Hours Balance'||l_proc, 10);
                      Hr_Utility.set_location ('Assignment Action ID:'||r_action.assignment_action_id|| l_proc, 10);
		   END;
		 END LOOP;

      EXCEPTION
         WHEN OTHERS
         THEN
			Hr_Utility.set_location('Error getting Hours Balance'||l_proc, 10);
      END;

   	  Hr_Utility.set_location ('Leaving Hours value: ' || l_value || ' ' || l_proc, 10);
      RETURN l_value;
   END get_hours_action;

   FUNCTION get_hours_kbase_int (
      p_assignment_id       IN   NUMBER,
      p_effective_start_date           IN  DATE,
	  p_effective_end_date IN DATE
   )
      RETURN NUMBER
   IS
--
      l_proc                      VARCHAR2 (72) := g_package || 'tt_pto_get_hours';
      l_balname              VARCHAR2 (50);
      l_value                     NUMBER (9, 2);
      l_temp_value         NUMBER (9, 2);
	  l_virtual_date        DATE;

	  CURSOR c_bal  IS
	  (SELECT SUM(NVL(xbd.balance_value,0))    bal
        FROM
		       xkb_balance_details xbd ,
			   apps.xkb_balances xb,
			   pay_balance_types pbt
         WHERE pbt.balance_name IN ( 'PTO Eligible Hours', 'US Regular Salary Hours')
		  AND pbt.balance_type_id = xbd.balance_type_id
          AND xbd.assignment_action_id = xb.assignment_action_id
          AND xb.effective_date BETWEEN  p_effective_start_date  AND p_effective_end_date
          AND xb.assignment_id = p_assignment_id
		  );

   BEGIN

         OPEN c_bal;
		 FETCH c_bal INTO l_value;
		 CLOSE c_bal;

      RETURN  NVL(l_value,0) ;
   EXCEPTION
         WHEN OTHERS
         THEN
            DBMS_OUTPUT.PUT_LINE ('Error getting value');
			RETURN  NVL(l_value,0) ;

   END get_hours_kbase_int;

   FUNCTION get_hours_kbase (
      p_assignment_id       IN   NUMBER,
      p_effective_date           IN  DATE
   )
      RETURN NUMBER
   IS
--
      l_proc                      VARCHAR2 (72) := g_package || 'tt_pto_get_hours';
      l_balname              VARCHAR2 (50);
      l_value                     NUMBER (9, 2);
      l_temp_value         NUMBER (9, 2);
	  l_virtual_date        DATE;

	  CURSOR c_bal  IS
	  (SELECT SUM(NVL(xbd.balance_value,0))    bal
        FROM
		       xkb_balance_details xbd ,
			   apps.xkb_balances xb,
			   pay_balance_types pbt
         WHERE pbt.balance_name IN ( 'PTO Eligible Hours', 'US Regular Salary Hours')
		  AND pbt.balance_type_id = xbd.balance_type_id
          AND xbd.assignment_action_id = xb.assignment_action_id
          AND xb.effective_date = p_effective_date
          AND xb.assignment_id = p_assignment_id
		  );

   BEGIN

         OPEN c_bal;
		 FETCH c_bal INTO l_value;
		 CLOSE c_bal;

      RETURN  NVL(l_value,0) ;
   EXCEPTION
         WHEN OTHERS
         THEN
            DBMS_OUTPUT.PUT_LINE ('Error getting value');
			RETURN  NVL(l_value,0) ;

   END get_hours_kbase;



   FUNCTION get_hours_earned_kbase (
      p_assignment_id       IN   NUMBER,
      p_date_earned           IN  DATE
   )
      RETURN NUMBER
   IS
--
      l_proc                      VARCHAR2 (72) := g_package || 'tt_pto_get_hours';
      l_value                     NUMBER (9, 2);

	  CURSOR c_bal  IS
	  (SELECT SUM(NVL(xbd.balance_value,0))    bal
        FROM
		       xkb_balance_details xbd ,
			   apps.xkb_balances xb,
			   pay_balance_types pbt
         WHERE pbt.balance_name IN ( 'PTO Eligible Hours', 'US Regular Salary Hours')
		  AND pbt.balance_type_id = xbd.balance_type_id
          AND xbd.assignment_action_id = xb.assignment_action_id
          AND xb.date_earned = p_date_earned
          AND xb.assignment_id = p_assignment_id
		  );

   BEGIN

         OPEN c_bal;
		 FETCH c_bal INTO l_value;
		 CLOSE c_bal;

      RETURN  NVL(l_value,0) ;
   EXCEPTION
         WHEN OTHERS
         THEN
            DBMS_OUTPUT.PUT_LINE ('Error getting value');
			RETURN  NVL(l_value,0) ;

   END get_hours_earned_kbase;

   FUNCTION get_hours_earned_kbase_int (
      p_assignment_id       IN   NUMBER,
      p_period_start_date           IN  DATE,
      p_period_end_date           IN  DATE
   )
      RETURN NUMBER
   IS
--
      l_proc                      VARCHAR2 (72) := g_package || 'tt_pto_get_hours';
      l_value                     NUMBER (9, 2);

	  CURSOR c_bal  IS
	  (SELECT SUM(NVL(xbd.balance_value,0))    bal
        FROM
		       xkb_balance_details xbd ,
			   apps.xkb_balances xb,
			   pay_balance_types pbt
         WHERE pbt.balance_name IN ( 'PTO Eligible Hours', 'US Regular Salary Hours')
		  AND pbt.balance_type_id = xbd.balance_type_id
          AND xbd.assignment_action_id = xb.assignment_action_id
          AND xb.date_earned BETWEEN p_period_start_date AND p_period_end_date
          AND xb.assignment_id = p_assignment_id
		  );

   BEGIN

         OPEN c_bal;
		 FETCH c_bal INTO l_value;
		 CLOSE c_bal;

      RETURN  NVL(l_value,0) ;
   EXCEPTION
         WHEN OTHERS
         THEN
            DBMS_OUTPUT.PUT_LINE ('Error getting value');
			RETURN  NVL(l_value,0) ;

   END get_hours_earned_kbase_int;


/*
   FUNCTION get_accrual_rate (
      p_plan_name    IN   VARCHAR2,
      p_years_service  IN   NUMBER
   )
      RETURN NUMBER
   IS
      l_hourly_rate   NUMBER;
	  l_ceiling NUMBER;
	  l_years_to NUMBER;
      l_temp_value         NUMBER (9, 2);
   BEGIN                -- get accrual rate from the custom table tt_pto_bands
      SELECT hourly_rate, ceiling, years_to
        INTO l_hourly_rate, l_ceiling, l_years_to
        FROM tt_pto_bands
       WHERE plan_name = p_plan_name
         AND p_years_service BETWEEN years_from AND  years_to;


	l_temp_value := Per_Formula_Functions.set_number('TT_HOURLY_RATE', l_hourly_rate);
	l_temp_value := Per_Formula_Functions.set_number('CEILING', l_ceiling);
    l_temp_value := Per_Formula_Functions.set_number('UPPER_LIMIT', l_years_to);

      RETURN 0;
   EXCEPTION
      WHEN OTHERS
      THEN
         DBMS_OUTPUT.put_line ('Error getting accrual rate');
         RETURN -1;
   END get_accrual_rate;
*/
END Tt_Pto_Ff_Util_Pkg;
