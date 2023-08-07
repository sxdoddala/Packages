create or replace PACKAGE BODY tt_ca_holiday_rate_calc IS

/*-------------------------------------------------------------

Program Name    :  TT_CA_Holiday_Rate_Calc

Desciption      : Publica holiday calculation

Input/Output Parameters

Called From     :  CA FAST FORMULA - PARYOLL

Created By      :
Date            :

Modification Log:
-----------------
Ver        Developer             Date                    Description

1.0      Elango Pandu          1/15/19         Since Pay day  changed from thursday to Friday , we are changing this
                                              value from 5 to 6. (Error skipping one pay period)

1.10    ELANGO PANDU                            Payroll name changed from atelka to TTEC CANADA SOLUTIONS
1.11    Narasimhulu Yellam                      Added new logic for province MB ,BC and SK.
1.12    Venkata Kovvuri        10-Feb-2023      Added new function get_average_daily_wage for Alberta provision.
1.0     RXNETHI-ARGANO         16-MAY-2023      R12.2 Upgrade Remediation
---------------------------------------------------------------*/

    FUNCTION get_rate (
        p_period_end_date   IN DATE,
        p_assignment_number IN VARCHAR2,
        p_date_earned       IN DATE
    ) RETURN NUMBER IS
V_DAYS_WORKED number ;
        l_rate           NUMBER;
        l_rate1          NUMBER;
        l_asg_id         NUMBER;
        l_asg_num        VARCHAR2(20);
        l_country        VARCHAR2(50);
        l_province       VARCHAR2(50);
        l_comm_count     NUMBER := 0;
        l_diff           NUMBER := 0;
        l_payroll_name   VARCHAR2(100);
        l_person_id      NUMBER;
        l_total_amount   NUMBER;
        l_total_hours    NUMBER;
        l_total_hours1   NUMBER;
        l_tab_amt        NUMBER := 0;
        l_tab_hrs        NUMBER := 0;
        l_tab_days       NUMBER := 0;
        l_tab_comm_count NUMBER := 0;
        l_hire_date      DATE;
        l_start_date     DATE;
        lv_start_date    DATE;
        lv_end_date      DATE;
        lv_start_date1   DATE;
        lv_end_date1     DATE;
        lv_start_date2   DATE;
        lv_end_date2     DATE;
        lv_ann_sal       NUMBER;
        lv_sal_bas       VARCHAR2(20);
        lv_balance_val   NUMBER;
        lv_bal_val       NUMBER;
        lv_tot_days      NUMBER;
        lv_bc_bal_val    NUMBER;
        lv_bc_days       NUMBER;

---ENTRY_EFFECTIVE_DATE

/*
CURSOR cur_main   IS
(SELECT
  SUM(bd.balance_value)  rate
FROM
 apps.xkb_balance_details bd,
 apps.xkb_balances bb,
 hr.pay_balance_types bt,
 hr.per_all_assignments_f paaf
WHERE
 bt.balance_name = 'Holiday Eligible Wages'
 AND bt.balance_type_id = bd.balance_type_id
 AND bd.assignment_action_id = bb.assignment_action_id
 AND TRUNC(bb.date_earned) BETWEEN p_period_end_date - 35 AND  p_period_end_date - 5
 AND bb.person_id = paaf.person_id
 AND paaf.assignment_type = 'E'
 AND paaf.primary_flag = 'Y'
 AND TRUNC(bb.effective_date) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
 AND paaf.assignment_number =  p_assignment_number
 AND paaf.business_group_id = 326  );

BEGIN

OPEN  cur_main;
FETCH cur_main INTO l_rate;
CLOSE cur_main;

l_rate := ROUND(l_rate/20,2);

RETURN  NVL(l_rate,0);

EXCEPTION
    WHEN OTHERS THEN
        RETURN 0;

END;
*/
/* initial payroll data load in custom table hence following curosr */
        CURSOR cur_cust_tab (
            l_from_period NUMBER,
            l_to_period   NUMBER
        ) IS
        SELECT
            SUM(tcae.pay_amount)   AS tot_pay,
            SUM(tcae.hours_worked) AS tot_hrs,
            SUM(tcae.days_worked)  AS tot_days
        FROM
            apps.tt_ca_atelka_emp_pay tcae,
            /*
			START R12.2 Upgrade Remediation
			code commented by RXNETHI-ARGANO,17/05/23
			hr.per_all_people_f       papf,
            hr.per_all_assignments_f  paaf
            */
			--code added by RXNETHI-ARGANO,17/05/23
			apps.per_all_people_f       papf,
            apps.per_all_assignments_f  paaf
			--END R12.2 Upgrade Remediation
		WHERE
                tcae.employee_number = papf.employee_number
            AND papf.person_id = paaf.person_id
            AND papf.business_group_id = paaf.business_group_id
            AND sysdate BETWEEN papf.effective_start_date AND papf.effective_end_date
            AND sysdate BETWEEN paaf.effective_start_date AND paaf.effective_end_date
            AND trunc(tcae.period_end_date) BETWEEN ( p_period_end_date - l_from_period ) AND ( p_period_end_date - l_to_period )
            AND paaf.assignment_number = p_assignment_number --like  '3209631%'
            ;

        CURSOR cur_main (
            from_period NUMBER,
            to_period   NUMBER
        ) IS
        SELECT
            SUM(bd.balance_value) rate
        FROM
            apps.xkb_balance_details bd,
            apps.xkb_balances        bb,
            /*
			START R12.2 Upgrade Remediation
			code commented by RXNETHI-ARGANO,17/05/23
			hr.pay_balance_types     bt,
            hr.per_all_assignments_f paaf
			*/
			--code adde dby RXNETHI-ARGANO,17/05/23
			apps.pay_balance_types     bt,
            apps.per_all_assignments_f paaf
			--END R12.2 Upgrade Remediation
        WHERE
                bt.balance_name = 'Holiday Eligible Wages'
            AND bt.balance_type_id = bd.balance_type_id
            AND bd.assignment_action_id = bb.assignment_action_id
            AND trunc(bb.date_earned) BETWEEN p_period_end_date - from_period /*(35)*/ AND p_period_end_date - to_period /*(5)*/
            AND bb.person_id = paaf.person_id
            AND paaf.assignment_type = 'E'
            AND paaf.primary_flag = 'Y'
            AND trunc(bb.effective_date) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
            AND paaf.assignment_number = p_assignment_number
            AND paaf.business_group_id = 326;

        CURSOR cur_reg_earn_bal (
            v_bal_name    VARCHAR2,
            v_from_period NUMBER,
            v_to_period   NUMBER
        ) IS
        SELECT
            SUM(bd.balance_value) rate
        FROM
            apps.xkb_balance_details bd,
            apps.xkb_balances        bb,
            /*
			hr.pay_balance_types     bt,
            hr.per_all_assignments_f paaf
            */
			--code added by RXNETHI-ARGANO,17/05/23
			apps.pay_balance_types     bt,
            apps.per_all_assignments_f paaf
			--END R12.2 Upgrade Remediation
		WHERE
                bt.balance_name = v_bal_name
            AND bt.balance_type_id = bd.balance_type_id
            AND bd.assignment_action_id = bb.assignment_action_id
 ----AND TRUNC(bb.date_earned) BETWEEN P_DATE_EARNED -v_from_period AND  P_DATE_EARNED -v_to_period
            AND trunc(bb.date_earned) BETWEEN ( p_period_end_date - v_from_period ) AND ( p_period_end_date - v_to_period )
            AND bb.person_id = paaf.person_id
            AND paaf.assignment_type = 'E'
            AND paaf.primary_flag = 'Y'
            AND trunc(bb.effective_date) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
            AND paaf.assignment_number = p_assignment_number --like  '3209631%'
            AND paaf.business_group_id = 326;

        CURSOR cur_reg_earn_bal1 (
            v_bal_name    VARCHAR2,
            v_from_period NUMBER,
            v_to_period   NUMBER
        ) IS
        SELECT
            SUM(nvl(value, 0))
        FROM
            pay_balance_values_v
        WHERE
            assignment_id IN (
                SELECT
                    assignment_id
                FROM
                    per_all_assignments_f
                WHERE
                        assignment_number = p_assignment_number
                    AND trunc(sysdate) BETWEEN effective_start_date AND effective_end_date
            )
            AND balance_name = v_bal_name
            AND trunc(effective_date) BETWEEN ( p_period_end_date - v_from_period ) AND ( p_period_end_date - v_to_period + 6 );

/*
Elango Moidified  on 1/15/19 for pay day change

cursor cur_reg_earn_bal1 (v_bal_name varchar2,v_from_period number, v_to_period number) is

SELECT SUM(NVL(value,0))
FROM pay_balance_values_v
WHERE assignment_id IN
  (SELECT assignment_id
  FROM per_all_assignments_f
  WHERE assignment_number=p_assignment_number
  AND TRUNC(sysdate) BETWEEN effective_start_date AND effective_end_date
  )
AND balance_name=v_bal_name
AND TRUNC(effective_date) BETWEEN (P_PERIOD_END_DATE-v_from_period) AND (P_PERIOD_END_DATE-v_to_period+5);

*/

        CURSOR cur_reg_earn_bal2 (
            v_bal_name    VARCHAR2,
            v_from_period NUMBER,
            v_to_period   NUMBER
        ) IS
        SELECT
            SUM(nvl(peev1.screen_entry_value, 0))
        FROM
            pay_element_types_f        pet,
            pay_input_values_f         piv1,
            pay_element_entries_f      pee,
            pay_element_entry_values_f peev1
        WHERE
            pee.assignment_id IN (
                SELECT
                    assignment_id
                FROM
                    per_all_assignments_f
                WHERE
                        assignment_number = p_assignment_number--'1044624'
                    AND trunc(sysdate) BETWEEN effective_start_date AND effective_end_date
            )
            AND pet.element_name = v_bal_name--'Atelka Days Worked'
            AND ( p_period_end_date - v_to_period + 5 ) BETWEEN pet.effective_start_date AND pet.effective_end_date
            AND pet.element_type_id = piv1.element_type_id
       --  AND piv1.name = 'Amount'
            AND ( p_period_end_date - v_to_period + 5 ) BETWEEN piv1.effective_start_date AND piv1.effective_end_date
            AND pet.element_type_id = pee.element_type_id
        -- AND pee.creator_type = 'SP'
            AND piv1.input_value_id = peev1.input_value_id
            AND pee.element_entry_id = peev1.element_entry_id
            AND pee.effective_start_date = peev1.effective_start_date
            AND pee.effective_end_date = peev1.effective_end_date
            AND ( ( pee.effective_start_date BETWEEN ( p_period_end_date - v_from_period ) AND ( p_period_end_date - v_to_period + 5 )
                    OR pee.effective_end_date BETWEEN ( p_period_end_date - v_from_period ) AND ( p_period_end_date - v_to_period + 5 ) )
             --((to_date('08-SEP-2018','DD-MON-RRRR')-35) BETWEEN pee.effective_start_date AND pee.effective_end_date)
                     )
            AND ( ( peev1.effective_start_date BETWEEN ( p_period_end_date - v_from_period ) AND ( p_period_end_date - v_to_period + 5 )
                    OR peev1.effective_end_date BETWEEN ( p_period_end_date - v_from_period ) AND ( p_period_end_date - v_to_period +
                    5 )
             --((to_date('08-SEP-2018','DD-MON-RRRR')-35) BETWEEN peev1.effective_start_date AND peev1.effective_end_date)
                     ) );

        CURSOR cur_reg_earn_bal3 (
            v_start_date  DATE,
            v_from_period NUMBER,
            v_to_period   NUMBER
        ) IS
        SELECT
            SUM(nvl(peev1.screen_entry_value, 0))
        FROM
            pay_element_types_f        pet,
            pay_input_values_f         piv1,
            pay_element_entries_f      pee,
            pay_element_entry_values_f peev1
        WHERE
            pee.assignment_id IN (
                SELECT
                    assignment_id
                FROM
                    per_all_assignments_f
                WHERE
                        assignment_number = p_assignment_number--'1044624'
                    AND trunc(sysdate) BETWEEN effective_start_date AND effective_end_date
            )
            AND pet.element_name = 'Atelka Days Worked'
            AND ( v_start_date - v_to_period + 6 ) BETWEEN pet.effective_start_date AND pet.effective_end_date
            AND pet.element_type_id = piv1.element_type_id
       --  AND piv1.name = 'Amount'
            AND ( v_start_date - v_to_period + 6 ) BETWEEN piv1.effective_start_date AND piv1.effective_end_date
            AND pet.element_type_id = pee.element_type_id
        -- AND pee.creator_type = 'SP'
            AND piv1.input_value_id = peev1.input_value_id
            AND pee.element_entry_id = peev1.element_entry_id
            AND pee.effective_start_date = peev1.effective_start_date
            AND pee.effective_end_date = peev1.effective_end_date
            AND ( ( pee.effective_start_date BETWEEN ( v_start_date - v_from_period ) AND ( v_start_date - v_to_period + 6 )
                    OR pee.effective_end_date BETWEEN ( v_start_date - v_from_period ) AND ( v_start_date - v_to_period + 6 ) )
             --((to_date('08-SEP-2018','DD-MON-RRRR')-35) BETWEEN pee.effective_start_date AND pee.effective_end_date)
                     )
            AND ( ( peev1.effective_start_date BETWEEN ( v_start_date - v_from_period ) AND ( v_start_date - v_to_period + 6 )
                    OR peev1.effective_end_date BETWEEN ( v_start_date - v_from_period ) AND ( v_start_date - v_to_period + 6 )
             --((to_date('08-SEP-2018','DD-MON-RRRR')-35) BETWEEN peev1.effective_start_date AND peev1.effective_end_date)
                     ) );
      ------ For Province BC ---------
    /*   CURSOR cur_reg_earn_bal4 (
            from_period   NUMBER,
            to_period     NUMBER
        ) IS
        SELECT
            SUM(bd.balance_value) rate
        FROM
            apps.xkb_balance_details   bd,
            apps.xkb_balances          bb,
            hr.pay_balance_types       bt,
            hr.per_all_assignments_f   paaf
        WHERE
            bt.balance_name = 'Holiday Eligible Wages BC'
            AND bt.balance_type_id = bd.balance_type_id
            AND bd.assignment_action_id = bb.assignment_action_id
            AND trunc(bb.date_earned) BETWEEN p_period_end_date - from_period  AND p_period_end_date - to_period
            AND bb.person_id = paaf.person_id
            AND paaf.assignment_type = 'E'
            AND paaf.primary_flag = 'Y'
            AND trunc(bb.effective_date) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
            AND paaf.assignment_number = p_assignment_number
            AND paaf.business_group_id = 326;

  CURSOR cur_reg_earn_bal5 (
            v_bal_name      VARCHAR2,
            v_from_period   NUMBER,
            v_to_period     NUMBER
        ) IS
        SELECT
            SUM(nvl(peev1.screen_entry_value, 0))
        FROM
            pay_element_types_f          pet,
            pay_input_values_f           piv1,
            pay_element_entries_f        pee,
            pay_element_entry_values_f   peev1
        WHERE
            pee.assignment_id IN (
                SELECT
                    assignment_id
                FROM
                    per_all_assignments_f
                WHERE
                    assignment_number = p_assignment_number--'1044624'
                    AND trunc(sysdate) BETWEEN effective_start_date AND effective_end_date
            )
            AND pet.element_name = v_bal_name--'Atelka Days Worked'
            AND ( p_period_end_date - v_to_period  ) BETWEEN pet.effective_start_date AND pet.effective_end_date
            AND pet.element_type_id = piv1.element_type_id
       --  AND piv1.name = 'Amount'
            AND ( p_period_end_date - v_to_period  ) BETWEEN piv1.effective_start_date AND piv1.effective_end_date
            AND pet.element_type_id = pee.element_type_id
        -- AND pee.creator_type = 'SP'
            AND piv1.input_value_id = peev1.input_value_id
            AND pee.element_entry_id = peev1.element_entry_id
            AND pee.effective_start_date = peev1.effective_start_date
            AND pee.effective_end_date = peev1.effective_end_date
            AND ( ( pee.effective_start_date BETWEEN ( p_period_end_date - v_from_period ) AND ( p_period_end_date - v_to_period
            )
                    OR pee.effective_end_date BETWEEN ( p_period_end_date - v_from_period ) AND ( p_period_end_date - v_to_period
                    ) )
             --((to_date('08-SEP-2018','DD-MON-RRRR')-35) BETWEEN pee.effective_start_date AND pee.effective_end_date)
                     )
            AND ( ( peev1.effective_start_date BETWEEN ( p_period_end_date - v_from_period ) AND ( p_period_end_date - v_to_period
             )
                    OR peev1.effective_end_date BETWEEN ( p_period_end_date - v_from_period ) AND ( p_period_end_date - v_to_period
                    )
             --((to_date('08-SEP-2018','DD-MON-RRRR')-35) BETWEEN peev1.effective_start_date AND peev1.effective_end_date)
                     ) );
*/

    BEGIN
        SELECT
            paaf.assignment_id,
            paaf.assignment_number,
            hla.country,
            hla.region_1,
            (
                SELECT
                    payroll_name
                FROM
                    pay_payrolls_f ppf
                WHERE
                        ppf.payroll_id = paaf.payroll_id
                    AND sysdate BETWEEN ppf.effective_start_date AND ppf.effective_end_date
                    AND ppf.business_group_id = paaf.business_group_id
            ),
            paaf.person_id
        INTO
            l_asg_id,
            l_asg_num,
            l_country,
            l_province,
            l_payroll_name,
            l_person_id
        FROM
            per_all_assignments_f paaf,
            hr_locations_all      hla
        WHERE
                paaf.assignment_number = p_assignment_number--'1044410'
            AND paaf.location_id = hla.location_id
            AND p_period_end_date BETWEEN paaf.effective_start_date AND paaf.effective_end_date;
--dbms_output.put_line('l_province = '||l_province);
--dbms_output.put_line('l_payroll_name = '||l_payroll_name);
       --'ATELKA' THEN
--        dbms_output.put_line('l_payroll 1 = '||l_payroll_name);
            IF l_province = 'QC' THEN
--            dbms_output.put_line('l_province1 = '||l_province);
                SELECT
                    COUNT(1)
                INTO l_comm_count
                FROM
                    pay_element_entries_f
                WHERE
                        assignment_id = l_asg_id
                    AND trunc(effective_start_date) BETWEEN p_period_end_date - 95 AND p_period_end_date - 5
                    AND element_type_id IN (
                        SELECT
                            element_type_id
                        FROM
                            pay_element_types_f
                        WHERE
                            element_name IN ( 'Commission', 'CommissionBillable_Atelka', 'Commission No Rate', 'Commission Salary' )
                            AND business_group_id = 326
                    );

                SELECT
                    COUNT(1)
                INTO l_tab_comm_count
                FROM
                    tt_ca_atelka_emp_pay     tcae,
                    /*
					START R12.2 Upgrade Remediation
					code commented by RXNETHI-ARGANO,17/05/23
					hr.per_all_people_f      papf,
                    hr.per_all_assignments_f paaf
					*/
					--code added by RXNETHI-ARGANO,17/05/23
					apps.per_all_people_f      papf,
                    apps.per_all_assignments_f paaf
					--END R12.2 Upgrade Remediation
                WHERE
                        tcae.employee_number = papf.employee_number
                    AND papf.person_id = paaf.person_id
                    AND papf.business_group_id = paaf.business_group_id
                    AND sysdate BETWEEN papf.effective_start_date AND papf.effective_end_date
                    AND sysdate BETWEEN paaf.effective_start_date AND paaf.effective_end_date
                    AND paaf.assignment_id = l_asg_id
                    AND trunc(tcae.period_start_date) BETWEEN p_period_end_date - 95 AND p_period_end_date - 5
                    AND tcae.commision_flag = 'Y';

                IF ( l_comm_count > 0 ) THEN

/*   OPEN  cur_reg_earn_bal ('Holiday Eligible Wages QC',95,14);---35,5);
  FETCH cur_reg_earn_bal INTO l_rate1;
  CLOSE cur_reg_earn_bal;*/
                    OPEN cur_reg_earn_bal1('Holiday Eligible Wages QC', 90, 14);---35,5);
                    FETCH cur_reg_earn_bal1 INTO l_rate1;
                    CLOSE cur_reg_earn_bal1;
                    l_rate := round(l_rate1 / 60, 2);
--                    dbms_output.put_line('l_rate1= ' ||l_rate);
                ELSE

 /*  OPEN  cur_reg_earn_bal ('Holiday Eligible Wages QC',35,14);---35,5);
  FETCH cur_reg_earn_bal INTO l_rate1;
  CLOSE cur_reg_earn_bal;*/
                    OPEN cur_reg_earn_bal1('Holiday Eligible Wages QC', 35, 14);---35,5);
                    FETCH cur_reg_earn_bal1 INTO l_rate1;
                    CLOSE cur_reg_earn_bal1;
                    l_rate := round(l_rate1 / 20, 2);
                     dbms_output.put_line('l_rate2= ' ||l_rate);
                END IF;

/*
if (l_tab_comm_count >0) then
  OPEN  cur_cust_tab (95,14);
  FETCH cur_cust_tab INTO l_tab_amt, l_tab_hrs,l_tab_days;
  CLOSE cur_cust_tab;

  l_rate := l_rate+ROUND((nvl(l_tab_amt,0))/60,2);
else
  OPEN  cur_cust_tab (35,14);
  FETCH cur_cust_tab INTO l_tab_amt,l_tab_hrs,l_tab_days;
  CLOSE cur_cust_tab;

  l_rate := l_rate+ROUND((nvl(l_tab_amt,0))/20,2);

end if;
*/

            ELSIF l_province = 'ON' THEN
--            dbms_output.put_line('l_province 3= '||l_province);
                SELECT
                    COUNT(1)
                INTO l_comm_count
                FROM
                    pay_element_entries_f
                WHERE
                        assignment_id = l_asg_id
                    AND trunc(effective_start_date) BETWEEN p_period_end_date - 35 AND p_period_end_date - 5;
/*
and element_type_id in ( select element_type_id from
                          pay_element_types_f
                          where element_name in ( 'Commission','CommissionBillable_Atelka','Commission No Rate', 'Commission Salary')
                          and business_group_id = 326
                        );*/

                SELECT
                    COUNT(1)
                INTO l_tab_comm_count
                FROM
                    tt_ca_atelka_emp_pay     tcae,
                    /*
					hr.per_all_people_f      papf,
                    hr.per_all_assignments_f paaf
                    */
					--code added by RXNETHI-ARGANO,17/05/23
					apps.per_all_people_f      papf,
                    apps.per_all_assignments_f paaf
					--END R12.2 Upgrade Remediation
				WHERE
                        tcae.employee_number = papf.employee_number
                    AND papf.person_id = paaf.person_id
                    AND papf.business_group_id = paaf.business_group_id
                    AND sysdate BETWEEN papf.effective_start_date AND papf.effective_end_date
                    AND sysdate BETWEEN paaf.effective_start_date AND paaf.effective_end_date
                    AND paaf.assignment_id = l_asg_id
                    AND trunc(tcae.period_start_date) BETWEEN p_period_end_date - 35 AND p_period_end_date - 5
--and tcae.COMMISION_FLAG = 'Y'
                    ;

                OPEN cur_reg_earn_bal1('Holiday Eligible Wages ON', 35, 14);---35,5);
                FETCH cur_reg_earn_bal1 INTO l_rate1;
                CLOSE cur_reg_earn_bal1;
                l_rate := round(l_rate1 / 20, 2);
--                 dbms_output.put_line('l_rate3= ' ||l_rate);

/****************************************************************************************************
--- Entire block commentd to have same model as QUBEC
---  Commented on 07-Jul-2018
--- By : Sathya
***************************************************************************************************

\*
The statutory holiday pay for eligible employees shall be paid based on an average day's
pay. The pay will be equal to regular wages earned during the four complete weeks of
pay preceding the week of the holiday, divided by the number of days worked during
these four weeks.

*\

   OPEN  cur_reg_earn_bal1 ('Vacation Taken Hours',21,14);---35,5);
  FETCH cur_reg_earn_bal1 INTO l_total_hours1;
  CLOSE cur_reg_earn_bal1;

  IF (l_total_hours1>=75) THEN

\*
      OPEN  cur_reg_earn_bal1 ('Vacation Taken Hours',36,28);---35,5);
      FETCH cur_reg_earn_bal1 INTO l_total_hours1;
      CLOSE cur_reg_earn_bal1;

      IF (l_total_hours1>=75) THEN

          OPEN  cur_reg_earn_bal1 ('Holiday Eligible Wages ON',50,42);---35,5);
          FETCH cur_reg_earn_bal1 INTO l_total_amount;
          CLOSE cur_reg_earn_bal1;

          OPEN  cur_reg_earn_bal1 ('Atelka Days Worked',50,42);---35,5);
          FETCH cur_reg_earn_bal1 INTO l_total_hours;
          CLOSE cur_reg_earn_bal1;

      ELSE *\

      OPEN  cur_reg_earn_bal1 ('Holiday Eligible Wages ON',36,28);---35,5);
      FETCH cur_reg_earn_bal1 INTO l_total_amount;
      CLOSE cur_reg_earn_bal1;

      OPEN  cur_reg_earn_bal1 ('Atelka Days Worked',36,28);---35,5);
      FETCH cur_reg_earn_bal1 INTO l_total_hours;
      CLOSE cur_reg_earn_bal1;

    \*  END IF;*\

  ELSE

      OPEN  cur_reg_earn_bal1('Holiday Eligible Wages ON',22,14);---35,5);
      FETCH cur_reg_earn_bal1 INTO l_total_amount;
      CLOSE cur_reg_earn_bal1;

      OPEN  cur_reg_earn_bal1 ('Atelka Days Worked',22,14);---35,5);
      FETCH cur_reg_earn_bal1 INTO l_total_hours;
      CLOSE cur_reg_earn_bal1;

  END IF;

  OPEN  cur_cust_tab (35,5);
  FETCH cur_cust_tab INTO l_tab_amt,l_tab_hrs,l_tab_days;
  CLOSE cur_cust_tab;

  ------l_rate := ROUND((l_total_amount+l_tab_amt)/(l_total_hours+l_tab_hrs));
  if ( trunc(P_DATE_EARNED) >= trunc(to_date('01-Jan-2018')) ) then
 -- l_rate := ROUND(((nvl(l_total_amount,0)+nvl(l_tab_amt,0))/((nvl(l_total_hours,0)/8)+nvl(l_tab_days,0))),2);
   l_rate := ROUND(((nvl(l_total_amount,0)+nvl(l_tab_amt,0))/((nvl(l_total_hours,0))+nvl(l_tab_days,0))),2);
 --  l_rate:=10;
  else
  l_rate := ROUND((nvl(l_tab_amt,0))/20,2);
 -- l_rate:=11;
  end if;

 ***************************************************************************************************
---END Entire block commentd to have same model as QUBEC
---  Commented on 07-Jul-2018
--- By : Sathya
****************************************************************************************************/

/***************************************************************************************************
---  NovaScotia - New block added on 01-Oct-2018
--- By : Sathya
--- NB and PEI replicated in NS location
****************************************************************************************************/
            ELSIF l_province = 'NS' THEN
--            dbms_output.put_line('l_province NS = '||l_province);
 --- (an employee must be employed by Atelka for at least 90 calendar days during the 12 months before the statutory holiday)
  /* select round(P_DATE_EARNED - start_date) into l_diff
   from per_all_people_f
   where person_id = (select person_id into l_person_id from per_assignments_x
                      where assignment_number = P_ASSIGNMENT_NUMBER
                      and rownum<2 )
   and sysdate between effective_start_date and effective_end_date;*/
  /* select person_id into l_person_id from per_assignments_x
                      where assignment_number = P_ASSIGNMENT_NUMBER
                      and rownum<2;
  l_diff := TT_CA_Holiday_Rate_Calc.get_employment_period (l_person_id, P_DATE_EARNED);

  */

   /*
   the total number of hours worked, excluding
overtime, in the 30 calendar days immediately preceding the holiday divided by the
number of days worked in that same 30-day period, times the employee's regular rate
pay.
   */
   /* if (l_diff >= 90) then */
/*   OPEN  cur_reg_earn_bal ('TT Time Entry Wages',30,14);
  FETCH cur_reg_earn_bal INTO l_total_amount;
  CLOSE cur_reg_earn_bal;
*/

/*   OPEN  cur_reg_earn_bal ('Holiday Eligible Wages NB',30,14);
  FETCH cur_reg_earn_bal INTO l_total_amount;
  CLOSE cur_reg_earn_bal;*/
                OPEN cur_reg_earn_bal1('Holiday Eligible Wages NS', 35, 14);
                FETCH cur_reg_earn_bal1 INTO l_total_amount;
                CLOSE cur_reg_earn_bal1;

/*
OPEN  cur_reg_earn_bal ('TT Time Entry Wages Hours',30,14);
  FETCH cur_reg_earn_bal INTO l_total_hours;
  CLOSE cur_reg_earn_bal;
*/
/*   OPEN  cur_reg_earn_bal ('Atelka Days Worked',30,14);
  FETCH cur_reg_earn_bal INTO l_total_hours;
  CLOSE cur_reg_earn_bal;
*/
                OPEN cur_reg_earn_bal2('Atelka Days Worked', 35, 14);
                FETCH cur_reg_earn_bal2 INTO l_total_hours;
                CLOSE cur_reg_earn_bal2;

--  l_rate := ROUND(l_total_amount/l_total_hours);
 /* OPEN  cur_cust_tab (35,5);
  FETCH cur_cust_tab INTO l_tab_amt,l_tab_hrs,l_tab_days;
  CLOSE cur_cust_tab;
*/

--  l_rate := ROUND(((nvl(l_total_amount,0)+nvl(l_tab_amt,0))/((nvl(l_total_hours,0)/8)+nvl(l_tab_days,0))),2);
                l_rate := round(((nvl(l_total_amount, 0) + nvl(l_tab_amt, 0)) /((nvl(l_total_hours, 0)) + nvl(l_tab_days, 0))), 2);
--                  dbms_output.put_line('l_rate1G= ' ||l_rate);

   /* else
     l_rate := 0;
     end if;
    */
/***************************************************************************************************
---  Newfoundland - New block added on 01-Oct-2018
--- By : Sathya

****************************************************************************************************/

            ELSIF l_province = 'NL' THEN
--            dbms_output.put_line('l_province NL = '||l_province);
 --- (an employee must be employed by Atelka for at least 90 calendar days during the 12 months before the statutory holiday)
  /* select round(P_DATE_EARNED - start_date) into l_diff
   from per_all_people_f
   where person_id = (select person_id into l_person_id from per_assignments_x
                      where assignment_number = P_ASSIGNMENT_NUMBER
                      and rownum<2 )
   and sysdate between effective_start_date and effective_end_date;*/

  /* select person_id into l_person_id from per_assignments_x
                      where assignment_number = P_ASSIGNMENT_NUMBER
                      and rownum<2;
  l_diff := TT_CA_Holiday_Rate_Calc.get_employment_period (l_person_id, P_DATE_EARNED);

  */

   /*
   the total number of hours worked, excluding
overtime, in the 30 calendar days immediately preceding the holiday divided by the
number of days worked in that same 30-day period, times the employee's regular rate
pay.
   */

   /* if (l_diff >= 90) then */

/*   OPEN  cur_reg_earn_bal ('TT Time Entry Wages',30,14);
  FETCH cur_reg_earn_bal INTO l_total_amount;
  CLOSE cur_reg_earn_bal;
*/

/*   OPEN  cur_reg_earn_bal ('Holiday Eligible Wages NB',30,14);
  FETCH cur_reg_earn_bal INTO l_total_amount;
  CLOSE cur_reg_earn_bal;*/
                OPEN cur_reg_earn_bal1('Holiday Eligible Wages NL', 30, 14);
                FETCH cur_reg_earn_bal1 INTO l_total_amount;
                CLOSE cur_reg_earn_bal1;

/*   OPEN  cur_reg_earn_bal ('TT Time Entry Wages Hours',30,14);
  FETCH cur_reg_earn_bal INTO l_total_hours;
  CLOSE cur_reg_earn_bal;
*/
/*   OPEN  cur_reg_earn_bal ('Atelka Days Worked',30,14);
  FETCH cur_reg_earn_bal INTO l_total_hours;
  CLOSE cur_reg_earn_bal;
*/
                OPEN cur_reg_earn_bal2('Atelka Days Worked', 30, 14);
                FETCH cur_reg_earn_bal2 INTO l_total_hours;
                CLOSE cur_reg_earn_bal2;

--  l_rate := ROUND(l_total_amount/l_total_hours);
 /* OPEN  cur_cust_tab (35,5);
  FETCH cur_cust_tab INTO l_tab_amt,l_tab_hrs,l_tab_days;
  CLOSE cur_cust_tab;
*/

--  l_rate := ROUND(((nvl(l_total_amount,0)+nvl(l_tab_amt,0))/((nvl(l_total_hours,0)/8)+nvl(l_tab_days,0))),2);
                l_rate := round(((nvl(l_total_amount, 0) + nvl(l_tab_amt, 0)) /((nvl(l_total_hours, 0)) + nvl(l_tab_days, 0))), 2);
--                 dbms_output.put_line('l_rate4= ' ||l_rate);

  /*  else
     l_rate := 0;
 end if;
 */

            ELSIF l_province = 'NB' THEN
--            dbms_output.put_line('l_province NB = '||l_province);
 --- (an employee must be employed by Atelka for at least 90 calendar days during the 12 months before the statutory holiday)
  /* select round(P_DATE_EARNED - start_date) into l_diff
   from per_all_people_f
   where person_id = (select person_id into l_person_id from per_assignments_x
                      where assignment_number = P_ASSIGNMENT_NUMBER
                      and rownum<2 )
   and sysdate between effective_start_date and effective_end_date;*/
                SELECT
                    person_id
                INTO l_person_id
                FROM
                    per_assignments_x
                WHERE
                        assignment_number = p_assignment_number
                    AND ROWNUM < 2;

                l_diff := tt_ca_holiday_rate_calc.get_employment_period(l_person_id, p_date_earned);
   /*
   the total number of hours worked, excluding
overtime, in the 30 calendar days immediately preceding the holiday divided by the
number of days worked in that same 30-day period, times the employee's regular rate
pay.
   */
                IF ( l_diff >= 90 ) THEN
/*   OPEN  cur_reg_earn_bal ('TT Time Entry Wages',30,14);
  FETCH cur_reg_earn_bal INTO l_total_amount;
  CLOSE cur_reg_earn_bal;
*/

/*   OPEN  cur_reg_earn_bal ('Holiday Eligible Wages NB',30,14);
  FETCH cur_reg_earn_bal INTO l_total_amount;
  CLOSE cur_reg_earn_bal;*/
                    OPEN cur_reg_earn_bal1('Holiday Eligible Wages NB', 35, 14);
                    FETCH cur_reg_earn_bal1 INTO l_total_amount;
                    CLOSE cur_reg_earn_bal1;

/*   OPEN  cur_reg_earn_bal ('TT Time Entry Wages Hours',30,14);
  FETCH cur_reg_earn_bal INTO l_total_hours;
  CLOSE cur_reg_earn_bal;
*/
/*   OPEN  cur_reg_earn_bal ('Atelka Days Worked',30,14);
  FETCH cur_reg_earn_bal INTO l_total_hours;
  CLOSE cur_reg_earn_bal;
*/

/*
  Commented on 07-Jan-2019 By sathya

  OPEN  cur_reg_earn_bal2 ('Atelka Days Worked',35,14);
  FETCH cur_reg_earn_bal2 INTO l_total_hours;
  CLOSE cur_reg_earn_bal2;

  */

--  l_rate := ROUND(l_total_amount/l_total_hours);
 /* OPEN  cur_cust_tab (35,5);
  FETCH cur_cust_tab INTO l_tab_amt,l_tab_hrs,l_tab_days;
  CLOSE cur_cust_tab;
*/

/* Modified on 07-Jan-2019 by Sathya*/
                    BEGIN
                        SELECT /*to_date(end_date,'DD-MON-RRRR'),*/
                            start_date
                        INTO l_start_date
                        FROM
                            apps.per_time_periods      tp,
                            apps.per_all_assignments_f paaf
                        WHERE
                                to_date(end_date, 'DD-MON-RRRR') = p_period_end_date--to_date('29-DEC-2018','DD-MON-RRRR')
                            AND paaf.payroll_id = tp.payroll_id
                            AND paaf.assignment_number = p_assignment_number--'1053379'
                            AND tp.end_date BETWEEN paaf.effective_start_date AND paaf.effective_end_date;

                    EXCEPTION
                        WHEN OTHERS THEN
                            l_start_date := p_period_end_date;
                    END;

                    OPEN cur_reg_earn_bal3(l_start_date, 28, 14);
                    FETCH cur_reg_earn_bal3 INTO l_total_hours;
                    CLOSE cur_reg_earn_bal3;

--  l_rate := ROUND(((nvl(l_total_amount,0)+nvl(l_tab_amt,0))/((nvl(l_total_hours,0)/8)+nvl(l_tab_days,0))),2);
                    l_rate := round(((nvl(l_total_amount, 0) + nvl(l_tab_amt, 0)) /((nvl(l_total_hours, 0)) + nvl(l_tab_days, 0))), 2);
-- dbms_output.put_line('l_rate5 = ' ||l_rate);
                ELSE
                    l_rate := 0;
--                     dbms_output.put_line('l_rate6 = ' ||l_rate);
                END IF;

            ELSIF l_province = 'PE' THEN
--            dbms_output.put_line('l_province PE = '||l_province);
/*
an employee must be employed by
Atelka for at least 30 calendar days prior to the holiday and have earned pay on at least
15 of the 30 calendar days immediately preceding the holiday.
*/
                SELECT
                    p_date_earned - start_date
                INTO l_diff
                FROM
                    per_all_people_f
                WHERE
                        person_id = (
                            SELECT
                                person_id
                            FROM
                                per_assignments_x
                            WHERE
                                    assignment_number = p_assignment_number
                                AND ROWNUM < 2
                        )
                    AND sysdate BETWEEN effective_start_date AND effective_end_date;

                IF ( l_diff >= 30 ) THEN
/*
  the total number of hours worked, excluding
overtime, in the 30 calendar days immediately preceding the holiday divided by the
number of days worked in that same 30-day period, times the employee's regular rate
pay.

*/
/*   OPEN  cur_reg_earn_bal ('TT Time Entry Wages',30,14);
  FETCH cur_reg_earn_bal INTO l_total_amount;
  CLOSE cur_reg_earn_bal;
*/

/*   OPEN  cur_reg_earn_bal ('Holiday Eligible Wages PEI',30,14);
  FETCH cur_reg_earn_bal INTO l_total_amount;
  CLOSE cur_reg_earn_bal;*/
                    OPEN cur_reg_earn_bal1('Holiday Eligible Wages PEI', 35, 14);
                    FETCH cur_reg_earn_bal1 INTO l_total_amount;
                    CLOSE cur_reg_earn_bal1;

/*   OPEN  cur_reg_earn_bal ('TT Time Entry Wages Hours',30,14);
  FETCH cur_reg_earn_bal INTO l_total_hours;
  CLOSE cur_reg_earn_bal;
*/
/*   OPEN  cur_reg_earn_bal ('Atelka Days Worked',30,14);
  FETCH cur_reg_earn_bal INTO l_total_hours;
  CLOSE cur_reg_earn_bal;*/

/*
  COMMENTED BY SATHYA ON 25-JAN-2019

  OPEN  cur_reg_earn_bal2('Atelka Days Worked',35,14);
  FETCH cur_reg_earn_bal2 INTO l_total_hours;
  CLOSE cur_reg_earn_bal2;*/

/* Modified on 07-Jan-2019 by Sathya*/
                    BEGIN
                        SELECT /*to_date(end_date,'DD-MON-RRRR'),*/
                            start_date
                        INTO l_start_date
                        FROM
                            apps.per_time_periods      tp,
                            apps.per_all_assignments_f paaf
                        WHERE
                                to_date(end_date, 'DD-MON-RRRR') = p_period_end_date--to_date('29-DEC-2018','DD-MON-RRRR')
                            AND paaf.payroll_id = tp.payroll_id
                            AND paaf.assignment_number = p_assignment_number--'1053379'
                            AND tp.end_date BETWEEN paaf.effective_start_date AND paaf.effective_end_date;

                    EXCEPTION
                        WHEN OTHERS THEN
                            l_start_date := p_period_end_date;
                    END;

                    OPEN cur_reg_earn_bal3(l_start_date, 28, 14);
                    FETCH cur_reg_earn_bal3 INTO l_total_hours;
                    CLOSE cur_reg_earn_bal3;
                    OPEN cur_cust_tab(35, 5);
                    FETCH cur_cust_tab INTO
                        l_tab_amt,
                        l_tab_hrs,
                        l_tab_days;
                    CLOSE cur_cust_tab;

--  l_rate := ROUND(((nvl(l_total_amount,0)+nvl(l_tab_amt,0))/((nvl(l_total_hours,0)/8)+nvl(l_tab_days,0))),2);
                    l_rate := round(((nvl(l_total_amount, 0) + nvl(l_tab_amt, 0)) /((nvl(l_total_hours, 0)) + nvl(l_tab_days, 0))), 2);
--                     dbms_output.put_line('l_rate7 = ' ||l_rate);
--  l_rate := 54;
--  l_rate := ROUND(l_total_amount/l_total_hours);

                ELSE
                    l_rate := 0;
--                      dbms_output.put_line('l_rateF= ' ||l_rate);
--     l_rate := 11;;
                END IF;

------- Province MB Started -------- 1.11

            ELSIF l_province = 'MB' THEN
--            dbms_output.put_line('l_province MB = '||l_province);
                BEGIN
                    SELECT
                        ppb.name
                    INTO lv_sal_bas
                    FROM
                        per_all_people_f      papf,
                        per_all_assignments_f paaf,
                        per_pay_bases         ppb
                    WHERE
                            papf.person_id = paaf.person_id
                        AND paaf.pay_basis_id = ppb.pay_basis_id
                        AND trunc(sysdate) BETWEEN papf.effective_start_date AND papf.effective_end_date
                        AND trunc(sysdate) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
                        AND ppb.business_group_id = 326
                        AND paaf.assignment_number = p_assignment_number;

--                    dbms_output.put_line('Start date :' || lv_sal_bas);
                EXCEPTION
                    WHEN OTHERS THEN
                        dbms_output.put_line('Error in returining employee Sal bases' || sqlerrm);
                END;

                BEGIN
                    SELECT
                        ppp.proposed_salary_n
                    INTO lv_ann_sal
                    FROM
                        per_all_assignments_f paaf,
                        per_pay_proposals     ppp
                    WHERE
                            1 = 1
                        AND paaf.assignment_number = p_assignment_number
                        AND paaf.primary_flag = 'Y'
                        AND sysdate BETWEEN paaf.effective_start_date AND paaf.effective_end_date
                        AND ppp.pay_proposal_id IN (
                            SELECT
                                MAX(pay_proposal_id)
                            FROM
                                per_pay_proposals
                            WHERE
                                assignment_id = paaf.assignment_id
                        );

--                    dbms_output.put_line('Start date :' || lv_ann_sal);
                EXCEPTION
                    WHEN OTHERS THEN
                        dbms_output.put_line('Error in returining employee annual sal' || sqlerrm);
                END;

                BEGIN
                    SELECT
                        start_date
                    INTO lv_start_date
                    FROM
                        apps.per_time_periods      tp,
                        apps.per_all_assignments_f paaf
                    WHERE
                            to_date(end_date, 'DD-MON-RRRR') = p_period_end_date
                        AND paaf.payroll_id = tp.payroll_id
                        AND paaf.assignment_number = p_assignment_number
                        AND tp.payroll_id = 782
                        AND tp.end_date BETWEEN paaf.effective_start_date AND paaf.effective_end_date;

                    dbms_output.put_line('Start date :' || lv_start_date);
                    dbms_output.put_line('End date :' || lv_end_date);
                EXCEPTION
                    WHEN OTHERS THEN
                        dbms_output.put_line('Error in returining period start date and period end date' || sqlerrm);
                END;

                BEGIN
                    SELECT
                        start_date,
                        end_date
                    INTO
                        lv_start_date1,
                        lv_end_date1
                    FROM
                        per_time_periods a
                    WHERE
                            a.payroll_id = 782
                        AND to_date(lv_start_date, 'DD-MON-RRRR') - 1 BETWEEN start_date AND end_date
                    ORDER BY
                        time_period_id DESC;

                    dbms_output.put_line('Start date :' || lv_start_date1);
                    dbms_output.put_line('End date :' || lv_end_date1);
                EXCEPTION
                    WHEN OTHERS THEN
                        dbms_output.put_line('Error in returining period start date1 and period end date1' || sqlerrm);
                END;

                BEGIN
                    SELECT
                        start_date,
                        end_date
                    INTO
                        lv_start_date2,
                        lv_end_date2
                    FROM
                        per_time_periods a
                    WHERE
                            a.payroll_id = 782
                        AND to_date(lv_start_date1, 'DD-MON-RRRR') - 1 BETWEEN start_date AND end_date
                    ORDER BY
                        time_period_id DESC;

                    dbms_output.put_line('Start date :' || lv_start_date2);
                    dbms_output.put_line('End date :' || lv_end_date2);
                EXCEPTION
                    WHEN OTHERS THEN
                        dbms_output.put_line('Error in returining period start date1 and period end date1' || sqlerrm);
                END;

            /*    BEGIN
                    SELECT
                        SUM(prb.balance_value)
                    INTO lv_balance_val
                    FROM
                        pay_balance_dimensions      pbd,
                        pay_defined_balances        pdb,
                        pay_balance_types           pbt,
                        pay_run_balances            prb,
                        per_all_assignments_f       paaf,
                        apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions    ppa
                    WHERE
                            1 = 1
                        AND pbd.balance_dimension_id = pdb.balance_dimension_id
                        AND pdb.balance_type_id = pbt.balance_type_id
                        AND pbt.balance_name = 'Holiday Eligible Wages MB'
                        AND pdb.defined_balance_id = prb.defined_balance_id
                        AND prb.assignment_id = paaf.assignment_id
                        AND paaf.assignment_number = p_assignment_number
                        AND paaf.business_group_id = 326
                        AND ppa.date_earned BETWEEN paaf.effective_start_date AND paaf.effective_end_date
                        AND prb.assignment_action_id = paa.assignment_action_id
                        AND paa.payroll_action_id = ppa.payroll_action_id
--and ppa.date_earned  between '08-AUG-2021' and '04-SEP-2021'
                        AND trunc(ppa.date_earned) BETWEEN lv_start_date2 AND lv_end_date1;
        --    group by bt.balance_type_id,bt.balance_name,paaf.assignment_number,bb.DATE_EARNED
                    dbms_output.put_line('Balance value :' || lv_balance_val);
                EXCEPTION
                    WHEN OTHERS THEN
                        dbms_output.put_line('Error in returining balance value' || sqlerrm);
                END; */

                OPEN cur_reg_earn_bal1('Holiday Eligible Wages MB', 35, 14);---35,5);
                FETCH cur_reg_earn_bal1 INTO lv_balance_val;
                CLOSE cur_reg_earn_bal1;

                IF lv_sal_bas = 'Salary' THEN
                    l_rate := ( lv_ann_sal / 2080 ) * 8;
                ELSIF lv_sal_bas = 'Hourly' THEN
                    l_rate := lv_balance_val * 5 / 100;
--                     dbms_output.put_line('l_rate8= ' ||l_rate);
                ELSE
                    l_rate := 0;
--                      dbms_output.put_line('l_rateE= ' ||l_rate);
                END IF;

------- Province MB Ended ---------- 1.11

------- Province BC started ------- 1.11

            ELSIF l_province = 'BC' THEN
--            dbms_output.put_line('l_province BC = '||l_province);
             /*  SELECT
                    p_date_earned - start_date
                INTO l_diff
                FROM
                    per_all_people_f
                WHERE
                    person_id = (
                        SELECT
                            person_id
                        FROM
                            per_assignments_x
                        WHERE
                            assignment_number = p_assignment_number
                            AND ROWNUM < 2
                    )
                    AND sysdate BETWEEN effective_start_date AND effective_end_date;

                IF ( l_diff >= 30 ) THEN*/
             /*   BEGIN
                    SELECT
                        SUM(prb.balance_value)
                    INTO lv_bal_val
                    FROM
                        pay_balance_dimensions      pbd,
                        pay_defined_balances        pdb,
                        pay_balance_types           pbt,
                        pay_run_balances            prb,
                        per_all_assignments_f       paaf,
                        apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions    ppa
                    WHERE
                            1 = 1
                        AND pbd.balance_dimension_id = pdb.balance_dimension_id
                        AND pdb.balance_type_id = pbt.balance_type_id
                        AND pbt.balance_name = 'Holiday Eligible Wages BC'
                        AND pdb.defined_balance_id = prb.defined_balance_id
                        AND prb.assignment_id = paaf.assignment_id
                        AND paaf.assignment_number = p_assignment_number
                        AND paaf.business_group_id = 326
                        AND ppa.date_earned BETWEEN paaf.effective_start_date AND paaf.effective_end_date
                        AND prb.assignment_action_id = paa.assignment_action_id
                        AND paa.payroll_action_id = ppa.payroll_action_id
--and ppa.date_earned  between '08-AUG-2021' and '04-SEP-2021'
                        AND trunc(ppa.date_earned) BETWEEN p_period_end_date - 35 AND p_period_end_date - 5 ;

                    dbms_output.put_line('BC Balance Value :' || lv_bal_val);
                EXCEPTION
                    WHEN OTHERS THEN
                        dbms_output.put_line('Error in returining employee BC balance val' || sqlerrm);
                END; */


                OPEN cur_reg_earn_bal1('Holiday Eligible Wages BC', 35, 14);---35,5);
                FETCH cur_reg_earn_bal1 INTO lv_bal_val;
                CLOSE cur_reg_earn_bal1;

                BEGIN
                    SELECT
                        SUM(nvl(peev1.screen_entry_value, 0))
                    INTO lv_tot_days
                    FROM
                        pay_element_types_f        pet,
                        pay_input_values_f         piv1,
                        pay_element_entries_f      pee,
                        pay_element_entry_values_f peev1
                    WHERE
                        pee.assignment_id IN (
                            SELECT
                                assignment_id
                            FROM
                                per_all_assignments_f
                            WHERE
                                    assignment_number = p_assignment_number--'1044624'
                                AND trunc(sysdate) BETWEEN effective_start_date AND effective_end_date
                        )
                        AND pet.element_name = 'Atelka Days Worked'
                        AND ( p_period_end_date - 5 ) BETWEEN pet.effective_start_date AND pet.effective_end_date
                        AND pet.element_type_id = piv1.element_type_id
       --  AND piv1.name = 'Amount'
                        AND ( p_period_end_date - 5 ) BETWEEN piv1.effective_start_date AND piv1.effective_end_date
                        AND pet.element_type_id = pee.element_type_id
        -- AND pee.creator_type = 'SP'
                        AND piv1.input_value_id = peev1.input_value_id
                        AND pee.element_entry_id = peev1.element_entry_id
                        AND pee.effective_start_date = peev1.effective_start_date
                        AND pee.effective_end_date = peev1.effective_end_date
                        AND ( ( pee.effective_start_date BETWEEN ( p_period_end_date - 35 ) AND ( p_period_end_date - 5 )
                                OR pee.effective_end_date BETWEEN ( p_period_end_date - 35 ) AND ( p_period_end_date - 5 ) )
             --((to_date('08-SEP-2018','DD-MON-RRRR')-35) BETWEEN pee.effective_start_date AND pee.effective_end_date)
                                 )
                        AND ( ( peev1.effective_start_date BETWEEN ( p_period_end_date - 35 ) AND ( p_period_end_date - 5 )
                                OR peev1.effective_end_date BETWEEN ( p_period_end_date - 35 ) AND ( p_period_end_date - 5 )
             --((to_date('08-SEP-2018','DD-MON-RRRR')-35) BETWEEN peev1.effective_start_date AND peev1.effective_end_date)
                                 ) );

                    dbms_output.put_line('BC Balance Value :' || lv_tot_days);
                EXCEPTION
                    WHEN OTHERS THEN
                        dbms_output.put_line('Error in returining employee BC working days' || sqlerrm);
                END;

				   /* OPEN cur_reg_earn_bal4(35, 5);
                    FETCH cur_reg_earn_bal4 INTO lv_bal_val;
                    CLOSE cur_reg_earn_bal4;

					OPEN cur_reg_earn_bal5('Atelka Days Worked', 35, 5);
                    FETCH cur_reg_earn_bal5 INTO lv_tot_days;
                    CLOSE cur_reg_earn_bal5;*/

                IF lv_bal_val IS NOT NULL THEN
                    l_rate := round(((nvl(lv_bal_val, 0) /(nvl(lv_tot_days, 0)))), 2);
--                     dbms_output.put_line('l_rate10 = ' ||l_rate);
                ELSE
                    l_rate := 0;
                      dbms_output.put_line('l_rateD= ' ||l_rate);
                END IF;

------- province BC Ended -------- 1.11
------- Province SK started ------ 1.11

            ELSIF l_province = 'SK' THEN
--            dbms_output.put_line('l_province SK = '||l_province);
                BEGIN
                    SELECT
                        ppb.name
                    INTO lv_sal_bas
                    FROM
                        per_all_people_f        papf,
                        per_all_assignments_f   paaf,
                        per_pay_bases           ppb
                    WHERE
                        papf.person_id = paaf.person_id
                        AND paaf.pay_basis_id = ppb.pay_basis_id
                        AND trunc(sysdate) BETWEEN papf.effective_start_date AND papf.effective_end_date
                        AND trunc(sysdate) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
                        AND ppb.business_group_id = 326
                        AND paaf.assignment_number = p_assignment_number;

--                    dbms_output.put_line('Salaray Bases :' || lv_sal_bas);
                EXCEPTION
                    WHEN OTHERS THEN
                        dbms_output.put_line('Error in returining employee Sal bases' || sqlerrm);
                END;

                BEGIN
                    SELECT
                        start_date
                    INTO lv_start_date
                    FROM
                        apps.per_time_periods        tp,
                        apps.per_all_assignments_f   paaf
                    WHERE
                        to_date(end_date, 'DD-MON-RRRR') = p_period_end_date
                        AND paaf.payroll_id = tp.payroll_id
                        AND paaf.assignment_number = p_assignment_number
                        AND tp.payroll_id = 782
                        AND tp.end_date BETWEEN paaf.effective_start_date AND paaf.effective_end_date;

                    dbms_output.put_line('Start date :' || lv_start_date);
                    dbms_output.put_line('End date :' || lv_end_date);
                EXCEPTION
                    WHEN OTHERS THEN
                        dbms_output.put_line('Error in returining period start date and period end date' || sqlerrm);
                END;

                BEGIN
                    SELECT
                        start_date,
                        end_date
                    INTO
                        lv_start_date1,
                        lv_end_date1
                    FROM
                        per_time_periods a
                    WHERE
                        a.payroll_id = 782
                        AND to_date(lv_start_date, 'DD-MON-RRRR') - 1 BETWEEN start_date AND end_date
                    ORDER BY
                        time_period_id DESC;

                    dbms_output.put_line('Start date :' || lv_start_date1);
                    dbms_output.put_line('End date :' || lv_end_date1);
                EXCEPTION
                    WHEN OTHERS THEN
                        dbms_output.put_line('Error in returining period start date1 and period end date1' || sqlerrm);
                END;

                BEGIN
                    SELECT
                        start_date,
                        end_date
                    INTO
                        lv_start_date2,
                        lv_end_date2
                    FROM
                        per_time_periods a
                    WHERE
                        a.payroll_id = 782
                        AND to_date(lv_start_date1, 'DD-MON-RRRR') - 1 BETWEEN start_date AND end_date
                    ORDER BY
                        time_period_id DESC;

                    dbms_output.put_line('Start date :' || lv_start_date2);
                    dbms_output.put_line('End date :' || lv_end_date2);
                EXCEPTION
                    WHEN OTHERS THEN
                        dbms_output.put_line('Error in returining period start date1 and period end date1' || sqlerrm);
                END;

                OPEN cur_reg_earn_bal1('Holiday Eligible Wages SK', 35, 14);---35,5);
                FETCH cur_reg_earn_bal1 INTO lv_balance_val;
                CLOSE cur_reg_earn_bal1;

             /*   BEGIN
                    SELECT
                        SUM(bd.balance_value)
                    INTO lv_balance_val
                    FROM
                        apps.xkb_balance_details   bd,
                        apps.xkb_balances          bb,
                        hr.pay_balance_types       bt,
                        hr.per_all_assignments_f   paaf
                    WHERE
                        1 = 1
                        AND bt.balance_name = 'Holiday Eligible Wages SK'
                        AND bb.payroll_id = 782
                        AND bt.balance_type_id = bd.balance_type_id
                        AND bd.assignment_action_id = bb.assignment_action_id
                        AND trunc(bb.date_earned) BETWEEN lv_start_date2 AND lv_end_date1
                        AND bb.person_id = paaf.person_id
                        AND paaf.assignment_type = 'E'
                        AND paaf.primary_flag = 'Y'
                        AND trunc(bb.effective_date) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
                        AND paaf.assignment_number = p_assignment_number
                        AND paaf.business_group_id = 326;
        --    group by bt.balance_type_id,bt.balance_name,paaf.assignment_number,bb.DATE_EARNED

                    dbms_output.put_line('Balance value :' || lv_balance_val);
                EXCEPTION
                    WHEN OTHERS THEN
                        dbms_output.put_line('Error in returining balance value' || sqlerrm);
                END; */

                IF lv_sal_bas = 'Hourly' THEN
                    l_rate := lv_balance_val * 5 / 100;
--                     dbms_output.put_line('l_rate1 11 = ' ||l_rate);
                ELSE
                    l_rate := 0;
--                      dbms_output.put_line('l_rate c= ' ||l_rate);
                END IF;
------- Province SK Ended --------- 1.11
------- Province AB Start ---------
	ELSIF l_province = 'AB' THEN
--    dbms_output.put_line('l_province AB= '||l_province);
    OPEN cur_reg_earn_bal1('Holiday Eligible Wages AB', 35, 14);---35,5);
                FETCH cur_reg_earn_bal1 INTO lv_bal_val;
                CLOSE cur_reg_earn_bal1;

                BEGIN
                    SELECT
                        SUM(nvl(peev1.screen_entry_value, 0))
                    INTO lv_tot_days
                    FROM
                        pay_element_types_f        pet,
                        pay_input_values_f         piv1,
                        pay_element_entries_f      pee,
                        pay_element_entry_values_f peev1
                    WHERE
                        pee.assignment_id IN (
                            SELECT
                                assignment_id
                            FROM
                                per_all_assignments_f
                            WHERE
                                    assignment_number = p_assignment_number--'1044624'
                                AND trunc(sysdate) BETWEEN effective_start_date AND effective_end_date
                        )
                        AND pet.element_name = 'Atelka Days Worked'
                        AND ( p_period_end_date - 5 ) BETWEEN pet.effective_start_date AND pet.effective_end_date
                        AND pet.element_type_id = piv1.element_type_id
       --  AND piv1.name = 'Amount'
                        AND ( p_period_end_date - 5 ) BETWEEN piv1.effective_start_date AND piv1.effective_end_date
                        AND pet.element_type_id = pee.element_type_id
        -- AND pee.creator_type = 'SP'
                        AND piv1.input_value_id = peev1.input_value_id
                        AND pee.element_entry_id = peev1.element_entry_id
                        AND pee.effective_start_date = peev1.effective_start_date
                        AND pee.effective_end_date = peev1.effective_end_date
                        AND ( ( pee.effective_start_date BETWEEN ( p_period_end_date - 35 ) AND ( p_period_end_date - 5 )
                                OR pee.effective_end_date BETWEEN ( p_period_end_date - 35 ) AND ( p_period_end_date - 5 ) )
             --((to_date('08-SEP-2018','DD-MON-RRRR')-35) BETWEEN pee.effective_start_date AND pee.effective_end_date)
                                 )
                        AND ( ( peev1.effective_start_date BETWEEN ( p_period_end_date - 35 ) AND ( p_period_end_date - 5 )
                                OR peev1.effective_end_date BETWEEN ( p_period_end_date - 35 ) AND ( p_period_end_date - 5 )
             --((to_date('08-SEP-2018','DD-MON-RRRR')-35) BETWEEN peev1.effective_start_date AND peev1.effective_end_date)
                                 ) );

                    dbms_output.put_line('BC Balance Value :' || lv_tot_days);
                EXCEPTION
                    WHEN OTHERS THEN
                        dbms_output.put_line('Error in returining employee BC working days' || sqlerrm);
                END;

				   /* OPEN cur_reg_earn_bal4(35, 5);
                    FETCH cur_reg_earn_bal4 INTO lv_bal_val;
                    CLOSE cur_reg_earn_bal4;

					OPEN cur_reg_earn_bal5('Atelka Days Worked', 35, 5);
                    FETCH cur_reg_earn_bal5 INTO lv_tot_days;
                    CLOSE cur_reg_earn_bal5;*/

                IF lv_bal_val IS NOT NULL THEN
                    l_rate := round(((nvl(lv_bal_val, 0) /(nvl(lv_tot_days, 0)))), 2);
--                     dbms_output.put_line('l_rate12= ' ||l_rate);
                ELSE
                    l_rate := 0;
--                      dbms_output.put_line('l_rateA= ' ||l_rate);
                END IF;

	------- Province AB Ended ---------
        ELSE
                l_rate := 0;
                  dbms_output.put_line('l_rateB= ' ||l_rate);
-- l_rate:=12;
            END IF;
 IF upper(l_payroll_name) = 'Percepta' THEN
            l_rate := get_rate(p_period_end_date, p_assignment_number);
             dbms_output.put_line('l_rate14= ' ||l_rate);
-- l_rate:=13;
        END IF;
--
--
--
--
        RETURN nvl(l_rate, 0);
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END get_rate;

    FUNCTION get_rate (
        p_period_end_date   IN DATE,
        p_assignment_number IN VARCHAR2
    ) RETURN NUMBER IS

        l_rate NUMBER := 0;
        CURSOR cur_main IS
        ( SELECT
            SUM(bd.balance_value) rate
        FROM
            apps.xkb_balance_details bd,
            apps.xkb_balances        bb,
            /*
			START R12.2 Upgrade Remediation
			code commented by RXNETHI-ARGANO,17/05/23
			hr.pay_balance_types     bt,
            hr.per_all_assignments_f paaf
			*/
			--code added  by RXNETHI-ARGANO,17/05/23
			apps.pay_balance_types     bt,
            apps.per_all_assignments_f paaf
			--END R12.2 Upgrade Remediation
        WHERE
                bt.balance_name = 'Holiday Eligible Wages'
            AND bt.balance_type_id = bd.balance_type_id
            AND bd.assignment_action_id = bb.assignment_action_id
            AND trunc(bb.date_earned) BETWEEN p_period_end_date - 35 AND p_period_end_date - 5
            AND bb.person_id = paaf.person_id
            AND paaf.assignment_type = 'E'
            AND paaf.primary_flag = 'Y'
            AND trunc(bb.effective_date) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
            AND paaf.assignment_number = p_assignment_number
            AND paaf.business_group_id = 326
        );

    BEGIN
        OPEN cur_main;
        FETCH cur_main INTO l_rate;
        CLOSE cur_main;
        l_rate := round(l_rate / 20, 2);
        RETURN nvl(l_rate, 0);
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END get_rate;

    FUNCTION get_employment_period (
        p_person_id   NUMBER,
        p_date_earned IN DATE
    ) RETURN NUMBER IS

        l_days NUMBER := 0;
        CURSOR emp_period (
            v_pid  NUMBER,
            v_date DATE
        ) IS
        SELECT
            person_id,
            date_start,
            nvl(actual_termination_date, p_date_earned) other_date
        FROM
            per_periods_of_service
        WHERE
                person_id = v_pid
            AND nvl(actual_termination_date, v_date) BETWEEN ( v_date - 365 ) AND v_date;

    BEGIN
        FOR i IN emp_period(p_person_id, p_date_earned) LOOP
            l_days := l_days + round(i.other_date - i.date_start);
        END LOOP;

        RETURN l_days;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END get_employment_period;

END tt_ca_holiday_rate_calc;
/
show errors;
/