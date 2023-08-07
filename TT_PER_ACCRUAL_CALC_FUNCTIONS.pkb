/************************************************************************************
        Program Name:  TT_PER_ACCRUAL_CALC_FUNCTIONS

       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
    IXPRAVEEN(ARGANO)            1.0     16-May-2023     R12.2 Upgrade Remediation
    ****************************************************************************************/
create or replace PACKAGE BODY tt_per_accrual_calc_functions AS

--
-- Start of fix 3222662
    TYPE g_entry_value IS
        TABLE OF pay_element_entry_values_f.screen_entry_value%TYPE INDEX BY BINARY_INTEGER;
    TYPE g_add_subtract IS
        TABLE OF pay_net_calculation_rules.add_or_subtract%TYPE INDEX BY BINARY_INTEGER;
    TYPE g_effective_date IS
        TABLE OF DATE INDEX BY BINARY_INTEGER;
-- End of 3222662
--
    g_package VARCHAR2(50) := '  per_accrual_calc_functions.';  -- Global package name

--

/* =====================================================================
   Name    : Get_Other_Net_Contribution
   Purpose :
   Returns : Total contribution of other elements.
   ---------------------------------------------------------------------*/
    FUNCTION get_other_net_contribution (
        p_assignment_id    IN NUMBER,
        p_plan_id          IN NUMBER,
        p_calculation_date IN DATE,
        p_start_date       IN DATE,
        p_input_value_id   IN NUMBER DEFAULT NULL
    ) RETURN NUMBER IS

        l_proc            VARCHAR2(72) := g_package || 'Get_Other_Net_Contribution';
        l_contribution    NUMBER := 0;
  -- Start of fix 3222662
        l_limit           NATURAL := 100; -- Limiting the bulk collect, if not limited then bulk collect
                                     -- returns entire rows for the condition, it may affect memory
        l_prev_collect    NUMBER := 0;   -- Cumulative record count till previous fetch
        l_curr_collect    NUMBER := 0;   -- Cumulative record count including the current fetch
        l_diff_collect    NUMBER := 0;   -- To check that, whether the last fetch retrived any new
                                     -- records, if not then to exit from the loop
-- v_val varchar2(100);
        g_amount_entries  g_entry_value;
        g_add_sub_entries g_add_subtract;
  --
        CURSOR c_get_contribution IS
        SELECT
            pev.screen_entry_value amount,
            ncr.add_or_subtract    add_or_subtract
        FROM
            pay_accrual_plans          pap,
            pay_net_calculation_rules  ncr,
            pay_element_entries_f      pee,
            pay_element_entry_values_f pev,
            pay_input_values_f         iv
        WHERE
                pap.accrual_plan_id = p_plan_id
            AND pee.assignment_id = p_assignment_id
            AND pee.element_entry_id = pev.element_entry_id
            AND pev.input_value_id = ncr.input_value_id
            AND pap.accrual_plan_id = ncr.accrual_plan_id
            AND ncr.input_value_id NOT IN ( pap.co_input_value_id, pap.pto_input_value_id )
            AND pev.screen_entry_value IS NOT NULL
            AND ( ( p_input_value_id IS NOT NULL
                    AND p_input_value_id = ncr.input_value_id )
                  OR p_input_value_id IS NULL )
            AND pev.effective_start_date = pee.effective_start_date
            AND pev.effective_end_date = pee.effective_end_date
            AND iv.input_value_id = ncr.input_value_id
            AND p_calculation_date BETWEEN iv.effective_start_date AND iv.effective_end_date
            AND pee.element_type_id = iv.element_type_id
            AND pee.element_type_id <> 829
     /* commented and added new exists clause inorder to work in 11.5.10 by solbource 02/01/06
     and exists
        (select null
           from pay_element_entry_values_f pev1
          where pev1.element_entry_id     = pev.element_entry_id
            and pev1.input_value_id       = ncr.date_input_value_id
            and pev1.effective_start_date = pev.effective_start_date
            and pev1.effective_end_date   = pev.effective_end_date
            and fnd_date.canonical_to_date(pev1.screen_entry_value)
                between p_start_date and p_calculation_date)
*/
            AND EXISTS (
                SELECT
                    NULL
                FROM
                    pay_element_entry_values_f pev1,
                    pay_input_values_f         piv2
                WHERE
                        pev1.element_entry_id = pev.element_entry_id
                    AND pev1.input_value_id = ncr.date_input_value_id
                    AND pev1.effective_start_date = pev.effective_start_date
                    AND pev1.effective_end_date = pev.effective_end_date
                    AND ncr.date_input_value_id = piv2.input_value_id
                    AND pee.element_type_id = piv2.element_type_id
                    AND p_calculation_date BETWEEN piv2.effective_start_date AND piv2.effective_end_date
                    AND fnd_date.canonical_to_date(decode(substr(piv2.uom, 1, 1), 'D', pev1.screen_entry_value, NULL)) BETWEEN p_start_date
                    AND p_calculation_date
            );
  --
    BEGIN
  --
        OPEN c_get_contribution;
  --
        LOOP
     --
            FETCH c_get_contribution
            BULK COLLECT INTO
                g_amount_entries,
                g_add_sub_entries
            LIMIT l_limit;
            l_prev_collect := l_curr_collect;
            l_curr_collect := c_get_contribution%rowcount;
            l_diff_collect := l_curr_collect - l_prev_collect;
            --

            IF l_diff_collect > 0 THEN
               --
                FOR i IN g_amount_entries.first..g_amount_entries.last LOOP
                  --
                    l_contribution := l_contribution + ( g_amount_entries(i) * g_add_sub_entries(i) );
                  --
                END LOOP;
               --
            END IF;

            --
         -- Exiting, if the present fetch is NOT returning any new rows
            EXIT WHEN ( l_diff_collect = 0 );
         --
     --
        END LOOP;

  --
        CLOSE c_get_contribution;
  -- End of fix 3222662
/*
  -- Bug 1570965. The below is commented out because we are interested
  -- in displaying the negative value: it appears on the View Accruals form.
  --
  -- If we are dealing with a single net calculation rule,
  -- we return the absolute value, rather than a potentially
  -- negative one. We are only interested in the negative value
  -- when summing all elements together, so that we get an
  -- accurate result

  if p_input_value_id is not null then
    l_contribution := abs(l_contribution);
  end if;
*/
  --
  --
        RETURN nvl(l_contribution, 0);
  --
  --
    END get_other_net_contribution;
--
--

    FUNCTION get_balance_transfer (
        p_assignment_id IN NUMBER,
        p_start_date    IN DATE,
        p_end_date      IN DATE
    ) RETURN NUMBER IS
        l_bal NUMBER;
    BEGIN
        l_bal := 0;
        SELECT
            nvl(SUM(screen_entry_value), 0)
        INTO l_bal
        FROM
            pay_element_entry_values_f
        WHERE
            element_entry_id IN (
                SELECT
                    peef.element_entry_id
                FROM
                    pay_element_entries_f      peef, pay_element_entry_values_f peevf
                WHERE
                        assignment_id = p_assignment_id
                    AND element_type_id = 14727
                    AND peef.element_entry_id = peevf.element_entry_id
                    AND input_value_id = 37672
                    AND fnd_date.canonical_to_date(peevf.screen_entry_value) BETWEEN trunc(p_start_date) AND trunc(p_end_date)
            )
            AND input_value_id = 37671;

        RETURN l_bal;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END get_balance_transfer;

    FUNCTION get_prev_accrual_bal (
        p_assignment_id NUMBER,
        p_hire_date     DATE
    ) RETURN NUMBER IS
        l_pto_wellness NUMBER := 0;
    BEGIN
        SELECT
            apps.ttec_get_accrual(paaf.assignment_id, paaf.payroll_id, decode(paaf.payroll_id, 46, 236, 1357), paaf.business_group_id,
            pps.actual_termination_date, 'NET')
        INTO l_pto_wellness
        FROM
            per_periods_of_service pps,
            per_all_assignments_f  paaf
        WHERE
                pps.person_id = paaf.person_id
            AND pps.actual_termination_date BETWEEN ( p_hire_date - 272 ) AND ( p_hire_date - 1 )
            AND pps.actual_termination_date IS NOT NULL
       -- AND ROWNUM = 1
            AND trunc(pps.actual_termination_date) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
            AND pps.actual_termination_date IN (
                SELECT
                    MAX(actual_termination_date)
                FROM
                    per_periods_of_service
                WHERE
                    person_id = pps.person_id
            )
            AND pps.person_id IN (
                SELECT
                    person_id
                FROM
                    per_all_assignments_f
                WHERE
                    assignment_id = p_assignment_id
                GROUP BY
                    person_id
            );

        RETURN l_pto_wellness;
    EXCEPTION
        WHEN OTHERS THEN
            l_pto_wellness := 0;
            RETURN l_pto_wellness;
    END get_prev_accrual_bal;

    FUNCTION get_prev_accrual_bal_rein (
        p_assignment_id IN NUMBER,
        p_hire_date     IN DATE,
        p_state         IN VARCHAR2,
        p_city          IN VARCHAR2,
        p_county        IN VARCHAR2
    ) RETURN NUMBER IS
        l_pto_wellness NUMBER := 0;
        l_pto_value    NUMBER := 0;
    BEGIN
        IF
            p_state = 'MD'
            AND p_county != 'Montgomery'
        THEN
            SELECT
               /* apps.ttec_get_accrual(paaf.assignment_id, paaf.payroll_id, decode(paaf.payroll_id, 46, 236, 1357), paaf.business_group_id,
                pps.actual_termination_date, 'NET')*/
            tt_per_accrual_calc_functions.TTEC_GET_ACCRUAL_ARCHIVE(paaf.assignment_id)
            INTO l_pto_value
            FROM
                per_periods_of_service pps,
                per_all_assignments_f  paaf
            WHERE
                    pps.person_id = paaf.person_id
         --  AND pps.actual_termination_date BETWEEN ( p_hire_date - 272 ) AND ( p_hire_date - 1 )
                AND trunc(to_date(p_hire_date, 'DD-MON-YYYY') - to_date(pps.actual_termination_date, 'DD-MON-YYYY')) <= 259
                AND pps.actual_termination_date IS NOT NULL
       -- AND ROWNUM = 1
                AND trunc(pps.actual_termination_date) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
                AND pps.actual_termination_date IN (
                    SELECT
                        MAX(actual_termination_date)
                    FROM
                        per_periods_of_service
                    WHERE
                        person_id = pps.person_id
                )
                AND pps.person_id IN (
                    SELECT
                        person_id
                    FROM
                        per_all_assignments_f
                    WHERE
                        assignment_id = p_assignment_id
                    GROUP BY
                        person_id
                );

            l_pto_wellness := l_pto_value;
        ELSIF p_state = 'AZ' OR (
            p_state = 'MD'
            AND p_county = 'Montgomery'
        ) THEN
            SELECT
               /* apps.ttec_get_accrual(paaf.assignment_id, paaf.payroll_id, decode(paaf.payroll_id, 46, 236, 1357), paaf.business_group_id,
                pps.actual_termination_date, 'NET') */
                tt_per_accrual_calc_functions.TTEC_GET_ACCRUAL_ARCHIVE(paaf.assignment_id)
            INTO l_pto_value
            FROM
                per_periods_of_service pps,
                per_all_assignments_f  paaf
            WHERE
                    pps.person_id = paaf.person_id
         --  AND pps.actual_termination_date BETWEEN ( p_hire_date - 272 ) AND ( p_hire_date - 1 )
                AND months_between(p_hire_date, actual_termination_date) <= 9
                AND pps.actual_termination_date IS NOT NULL
       -- AND ROWNUM = 1
                AND trunc(pps.actual_termination_date) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
                AND pps.actual_termination_date IN (
                    SELECT
                        MAX(actual_termination_date)
                    FROM
                        per_periods_of_service
                    WHERE
                        person_id = pps.person_id
                )
                AND pps.person_id IN (
                    SELECT
                        person_id
                    FROM
                        per_all_assignments_f
                    WHERE
                        assignment_id = p_assignment_id
                    GROUP BY
                        person_id
                );

            l_pto_wellness := l_pto_value;
        ELSIF (
            p_state = 'CA'
            AND p_city != 'San Diego'
        ) OR p_state = 'DC' THEN
            SELECT
               /* apps.ttec_get_accrual(paaf.assignment_id, paaf.payroll_id, decode(paaf.payroll_id, 46, 236, 1357), paaf.business_group_id,
                pps.actual_termination_date, 'NET')*/
                tt_per_accrual_calc_functions.TTEC_GET_ACCRUAL_ARCHIVE(paaf.assignment_id)
            INTO l_pto_value
            FROM
                per_periods_of_service pps,
                per_all_assignments_f  paaf
            WHERE
                    pps.person_id = paaf.person_id
         --  AND pps.actual_termination_date BETWEEN ( p_hire_date - 272 ) AND ( p_hire_date - 1 )
                AND months_between(p_hire_date, actual_termination_date) <= 12
                AND pps.actual_termination_date IS NOT NULL
       -- AND ROWNUM = 1
                AND trunc(pps.actual_termination_date) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
                AND pps.actual_termination_date IN (
                    SELECT
                        MAX(actual_termination_date)
                    FROM
                        per_periods_of_service
                    WHERE
                        person_id = pps.person_id
                )
                AND pps.person_id IN (
                    SELECT
                        person_id
                    FROM
                        per_all_assignments_f
                    WHERE
                        assignment_id = p_assignment_id
                    GROUP BY
                        person_id
                );

            l_pto_wellness := l_pto_value;
        ELSIF p_state = 'CO' OR (
            p_state = 'NY'
            AND p_city = 'New York'
        ) OR p_state = 'PA' OR (
            p_state = 'CA'
            AND p_city = 'San Diego'
        ) OR p_state = 'NJ' THEN
            SELECT
                /*apps.ttec_get_accrual(paaf.assignment_id, paaf.payroll_id, decode(paaf.payroll_id, 46, 236, 1357), paaf.business_group_id,
                pps.actual_termination_date, 'NET')*/
                tt_per_accrual_calc_functions.TTEC_GET_ACCRUAL_ARCHIVE(paaf.assignment_id)
            INTO l_pto_value
            FROM
                per_periods_of_service pps,
                per_all_assignments_f  paaf
            WHERE
                    pps.person_id = paaf.person_id
         --  AND pps.actual_termination_date BETWEEN ( p_hire_date - 272 ) AND ( p_hire_date - 1 )
                AND months_between(p_hire_date, actual_termination_date) <= 6
                AND pps.actual_termination_date IS NOT NULL
       -- AND ROWNUM = 1
                AND trunc(pps.actual_termination_date) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
                AND pps.actual_termination_date IN (
                    SELECT
                        MAX(actual_termination_date)
                    FROM
                        per_periods_of_service
                    WHERE
                        person_id = pps.person_id
                )
                AND pps.person_id IN (
                    SELECT
                        person_id
                    FROM
                        per_all_assignments_f
                    WHERE
                        assignment_id = p_assignment_id
                    GROUP BY
                        person_id
                );

            l_pto_wellness := l_pto_value;
        ELSIF p_state = 'NM' OR p_state = 'MA' OR p_state = 'WA' THEN
            SELECT
               /* apps.ttec_get_accrual(paaf.assignment_id, paaf.payroll_id, decode(paaf.payroll_id, 46, 236, 1357), paaf.business_group_id,
                pps.actual_termination_date, 'NET') */
                tt_per_accrual_calc_functions.TTEC_GET_ACCRUAL_ARCHIVE(paaf.assignment_id)
            INTO l_pto_value
            FROM
                per_periods_of_service pps,
                per_all_assignments_f  paaf
            WHERE
                    pps.person_id = paaf.person_id
         --  AND pps.actual_termination_date BETWEEN ( p_hire_date - 272 ) AND ( p_hire_date - 1 )
                AND months_between(p_hire_date, actual_termination_date) <= 12
                AND pps.actual_termination_date IS NOT NULL
       -- AND ROWNUM = 1
                AND trunc(pps.actual_termination_date) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
                AND pps.actual_termination_date IN (
                    SELECT
                        MAX(actual_termination_date)
                    FROM
                        per_periods_of_service
                    WHERE
                        person_id = pps.person_id
                )
                AND pps.person_id IN (
                    SELECT
                        person_id
                    FROM
                        per_all_assignments_f
                    WHERE
                        assignment_id = p_assignment_id
                    GROUP BY
                        person_id
                );

            l_pto_wellness := l_pto_value;
        ELSIF p_state = 'RI' THEN
            SELECT
               /* apps.ttec_get_accrual(paaf.assignment_id, paaf.payroll_id, decode(paaf.payroll_id, 46, 236, 1357), paaf.business_group_id,
                pps.actual_termination_date, 'NET')*/
                tt_per_accrual_calc_functions.TTEC_GET_ACCRUAL_ARCHIVE(paaf.assignment_id)
            INTO l_pto_value
            FROM
                per_periods_of_service pps,
                per_all_assignments_f  paaf
            WHERE
                    pps.person_id = paaf.person_id
         --  AND pps.actual_termination_date BETWEEN ( p_hire_date - 272 ) AND ( p_hire_date - 1 )
                AND trunc(to_date(p_hire_date, 'DD-MON-YYYY') - to_date(pps.actual_termination_date, 'DD-MON-YYYY')) <= 135
                AND pps.actual_termination_date IS NOT NULL
       -- AND ROWNUM = 1
                AND trunc(pps.actual_termination_date) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
                AND pps.actual_termination_date IN (
                    SELECT
                        MAX(actual_termination_date)
                    FROM
                        per_periods_of_service
                    WHERE
                        person_id = pps.person_id
                )
                AND pps.person_id IN (
                    SELECT
                        person_id
                    FROM
                        per_all_assignments_f
                    WHERE
                        assignment_id = p_assignment_id
                    GROUP BY
                        person_id
                );

            l_pto_wellness := l_pto_value;
        ELSIF p_state = 'MN' THEN
            SELECT
               /* apps.ttec_get_accrual(paaf.assignment_id, paaf.payroll_id, decode(paaf.payroll_id, 46, 236, 1357), paaf.business_group_id,
                pps.actual_termination_date, 'NET')*/
                tt_per_accrual_calc_functions.TTEC_GET_ACCRUAL_ARCHIVE(paaf.assignment_id)
            INTO l_pto_value
            FROM
                per_periods_of_service pps,
                per_all_assignments_f  paaf
            WHERE
                    pps.person_id = paaf.person_id
         --  AND pps.actual_termination_date BETWEEN ( p_hire_date - 272 ) AND ( p_hire_date - 1 )
                AND trunc(to_date(p_hire_date, 'DD-MON-YYYY') - to_date(pps.actual_termination_date, 'DD-MON-YYYY')) <= 90
                AND pps.actual_termination_date IS NOT NULL
       -- AND ROWNUM = 1
                AND trunc(pps.actual_termination_date) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
                AND pps.actual_termination_date IN (
                    SELECT
                        MAX(actual_termination_date)
                    FROM
                        per_periods_of_service
                    WHERE
                        person_id = pps.person_id
                )
                AND pps.person_id IN (
                    SELECT
                        person_id
                    FROM
                        per_all_assignments_f
                    WHERE
                        assignment_id = p_assignment_id
                    GROUP BY
                        person_id
                );

            l_pto_wellness := l_pto_value;
        ELSIF p_state = 'OR' THEN
            SELECT
                /*apps.ttec_get_accrual(paaf.assignment_id, paaf.payroll_id, decode(paaf.payroll_id, 46, 236, 1357), paaf.business_group_id,
                pps.actual_termination_date, 'NET')*/
                tt_per_accrual_calc_functions.TTEC_GET_ACCRUAL_ARCHIVE(paaf.assignment_id)
            INTO l_pto_value
            FROM
                per_periods_of_service pps,
                per_all_assignments_f  paaf
            WHERE
                    pps.person_id = paaf.person_id
         --  AND pps.actual_termination_date BETWEEN ( p_hire_date - 272 ) AND ( p_hire_date - 1 )
                AND trunc(to_date(p_hire_date, 'DD-MON-YYYY') - to_date(pps.actual_termination_date, 'DD-MON-YYYY')) <= 180
                AND pps.actual_termination_date IS NOT NULL
       -- AND ROWNUM = 1
                AND trunc(pps.actual_termination_date) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
                AND pps.actual_termination_date IN (
                    SELECT
                        MAX(actual_termination_date)
                    FROM
                        per_periods_of_service
                    WHERE
                        person_id = pps.person_id
                )
                AND pps.person_id IN (
                    SELECT
                        person_id
                    FROM
                        per_all_assignments_f
                    WHERE
                        assignment_id = p_assignment_id
                    GROUP BY
                        person_id
                );

            l_pto_wellness := l_pto_value;
        END IF;

        RETURN l_pto_wellness;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END get_prev_accrual_bal_rein;

    FUNCTION get_first_period_bal (
        p_assignment_id     IN NUMBER,
        p_business_group_id IN NUMBER,
        p_paryoll_id        IN NUMBER,
        p_hire_date         IN DATE
    ) RETURN NUMBER IS

        l_start_date          DATE;
        l_end_date            DATE;
        l_tt_hours            NUMBER := 0;
        l_tt_hours_ot         NUMBER := 0;
        l_first_period_acrual NUMBER := 0;
    BEGIN
        SELECT
            start_date,
            end_date
        INTO
            l_start_date,
            l_end_date
        FROM
            per_time_periods ptp
        WHERE
                ptp.payroll_id = p_paryoll_id
            AND p_hire_date BETWEEN ptp.start_date AND ptp.end_date;

        IF p_hire_date != l_start_date THEN
            l_tt_hours := ttec_get_hours_balance(p_assignment_id, p_business_group_id, l_end_date, 'WELLNESS_ELIGIBLE_HOURS');
            l_tt_hours_ot := ttec_get_hours_balance(p_assignment_id, p_business_group_id, l_end_date, 'WELLNESS_OT_ELIGIBLE_HOURS');
            l_first_period_acrual := ( ( l_tt_hours + l_tt_hours_ot ) / 30 );
        END IF;

        RETURN l_first_period_acrual;
    EXCEPTION
        WHEN OTHERS THEN
            l_first_period_acrual := 0;
            RETURN l_first_period_acrual;
    END get_first_period_bal;

-------Start get_P2M2C2_above_eligibility -------
    FUNCTION get_p2m2c2_above_eligibility (
        p_assignment_id  IN NUMBER,
        p_effective_date IN DATE,
        p_work_city      IN VARCHAR2,
        p_job            IN VARCHAR2
    ) RETURN VARCHAR2 IS

        CURSOR c_gca_coding IS
        ( SELECT
            pj.attribute20
        FROM
            per_all_assignments_f paaf,
            per_jobs              pj
        WHERE
                paaf.assignment_id = p_assignment_id
            AND p_effective_date BETWEEN paaf.effective_start_date AND paaf.effective_end_date
            AND paaf.assignment_type = 'E'
            AND paaf.primary_flag = 'Y'
            AND pj.attribute20 IN ( 'M6', 'M5', 'M4', 'M3', 'M2',
                                    'P6', 'P5', 'P4', 'P3', 'P2',
                                    'C1', 'C2', 'C3', 'C4', 'C5',
                                    'C6', 'CD4', 'CD3', 'CD2', 'CD5',
                                    'E1', 'E2', 'E3', 'E4' )
            AND paaf.job_id = pj.job_id
        );

        l_gca_flag VARCHAR2(10);
    BEGIN
        BEGIN
            OPEN c_gca_coding;
            FETCH c_gca_coding INTO l_gca_flag;
            CLOSE c_gca_coding;
            IF l_gca_flag IS NULL THEN
                l_gca_flag := 'N';
            ELSE
                l_gca_flag := 'Y';
            END IF;

        EXCEPTION
            WHEN no_data_found THEN
                l_gca_flag := 'N';
        END;

        IF l_gca_flag = 'Y' THEN
            IF
                p_work_city = 'Tempe'
                AND p_job IN ( 'DA1105.Manager, Sales Delivery I'

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
					  'DA25017a.Inside Sales Account Manager I'*/ )
            THEN
                l_gca_flag := 'N';
            END IF;

        END IF;

        RETURN l_gca_flag;
    END;
---- End get_P2M2C2_above_eligibility ----
---- start Srt date function ---------------
    FUNCTION get_p2m2c2_above_job_srt_date (
        p_assignment_id  IN NUMBER,
        p_effective_date IN DATE
    ) RETURN DATE IS

        CURSOR c_gca_date IS
        ( SELECT
            MIN(paaf.effective_start_date)
        FROM
            per_all_assignments_f paaf,
            per_jobs              pj
        WHERE
                paaf.assignment_id = p_assignment_id
          --  AND trunc(sysdate) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
            AND paaf.assignment_type = 'E'
            AND paaf.primary_flag = 'Y'
            AND pj.attribute20 IN ( 'M6', 'M5', 'M4', 'M3', 'M2',
                                    'P6', 'P5', 'P4', 'P3', 'P2',
                                    'C1', 'C2', 'C3', 'C4', 'C5',
                                    'C6', 'CD4', 'CD3', 'CD2', 'CD5',
                                    'E1', 'E2', 'E3', 'E4' )
            AND paaf.job_id = pj.job_id
        );

        l_gca_date DATE;
    BEGIN
        BEGIN
            OPEN c_gca_date;
            FETCH c_gca_date INTO l_gca_date;
            CLOSE c_gca_date;
            RETURN l_gca_date;
        EXCEPTION
            WHEN OTHERS THEN
                RETURN NULL;
        END;
    END;

----end srt date function -------------

  ----- start get_wellness_taken -------
    FUNCTION get_wellness_taken (
        p_assignment_id IN NUMBER,
        p_start_date    IN DATE,
        p_end_date      IN DATE
    ) RETURN NUMBER IS
        l_bal NUMBER;
    BEGIN
        l_bal := 0;
        SELECT
            nvl(SUM(screen_entry_value), 0)
        INTO l_bal
        FROM
            pay_element_entry_values_f
        WHERE
            element_entry_id IN (
                SELECT
                    peef.element_entry_id
                FROM
                    pay_element_entries_f      peef, pay_element_entry_values_f peevf
                WHERE
                        assignment_id = p_assignment_id
                    AND element_type_id = 14718
                    AND peef.element_entry_id = peevf.element_entry_id
                    AND input_value_id = 37586
                    AND fnd_date.canonical_to_date(peevf.screen_entry_value) BETWEEN trunc(p_start_date) AND trunc(p_end_date)
            )
            AND input_value_id = 37578;

        RETURN l_bal;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END get_wellness_taken;

----- END get_wellness_taken-------

    FUNCTION ttec_get_pto_elig_info_county (
        p_assignment_id  IN NUMBER,
        p_effective_date IN DATE,
        p_county         OUT VARCHAR2
    ) RETURN VARCHAR2 IS
--

        l_work_at_home VARCHAR2(1);
--
        CURSOR csr_location_address IS
        SELECT
            loc.region_1
        FROM
		--START R12.2 Upgrade Remediation
            /*hr.hr_locations_all      loc,				-- Commented code by IXPRAVEEN-ARGANO,16-May-2023
            hr.per_all_assignments_f paaf*/             
            apps.hr_locations_all      loc,				--  code Added by IXPRAVEEN-ARGANO,   16-May-2023
            apps.per_all_assignments_f paaf	
		--END R12.2.12 Upgrade remediation	
        WHERE
                loc.location_id = paaf.location_id
            AND p_effective_date BETWEEN paaf.effective_start_date AND paaf.effective_end_date
            AND paaf.assignment_id = p_assignment_id;

        CURSOR csr_home_address IS
        SELECT
            pa.region_1
        FROM
		--START R12.2 Upgrade Remediation
            /*hr.per_addresses         pa,				 -- Commented code by IXPRAVEEN-ARGANO,16-May-2023
            hr.per_all_assignments_f paaf*/              
			apps.per_addresses         pa,				--  code Added by IXPRAVEEN-ARGANO,   16-May-2023
            apps.per_all_assignments_f paaf
		--END R12.2.12 Upgrade remediatio	
        WHERE
                paaf.person_id = pa.person_id
            AND pa.primary_flag = 'Y'
            AND date_to IS NULL
            AND p_effective_date BETWEEN paaf.effective_start_date AND paaf.effective_end_date
            AND paaf.assignment_id = p_assignment_id;
--
    BEGIN
        SELECT
            nvl(work_at_home, 'N')
        INTO l_work_at_home
        FROM
            --hr.per_all_assignments_f paaf				-- Commented code by IXPRAVEEN-ARGANO,16-May-2023
            apps.per_all_assignments_f paaf             --  code Added by IXPRAVEEN-ARGANO,   16-May-2023
        WHERE
                paaf.assignment_id = p_assignment_id
            AND p_effective_date BETWEEN paaf.effective_start_date AND paaf.effective_end_date;

        IF l_work_at_home = 'Y' THEN
            OPEN csr_home_address;
            FETCH csr_home_address INTO p_county;
            CLOSE csr_home_address;
        ELSE
            OPEN csr_location_address;
            FETCH csr_location_address INTO p_county;
            CLOSE csr_location_address;
        END IF;

        RETURN l_work_at_home;
    END ttec_get_pto_elig_info_county;

    ------------- Rehire emp function start ----------------
    FUNCTION ttec_get_rehire_emp (
        p_assignment_id  IN NUMBER,
        p_effective_date IN DATE
    ) RETURN VARCHAR2 IS
--

        l_rehire_flag VARCHAR2(1);
    BEGIN
        SELECT
            CASE
                WHEN paaf.assignment_number LIKE '%-%' THEN
                    'Y'
                ELSE
                    'N'
            END
        INTO l_rehire_flag
        FROM
            per_all_assignments_f paaf
        WHERE
                1 = 1
            AND paaf.effective_start_date = (
                SELECT
                    MAX(effective_start_date)
                FROM
                    per_all_assignments_f
                WHERE
                    assignment_id = paaf.assignment_id
            )
            AND paaf.effective_end_date = (
                SELECT
                    MAX(effective_end_date)
                FROM
                    per_all_assignments_f
                WHERE
                    assignment_id = paaf.assignment_id
            )
            AND paaf.primary_flag = 'Y'
            AND paaf.assignment_id = p_assignment_id
            AND paaf.business_group_id <> 0;

        RETURN l_rehire_flag;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN NULL;
    END ttec_get_rehire_emp;

    -------------- Rehire emp function end ---------------
    --------------- start same year function-------------
    FUNCTION emp_rehired_same_year (
        p_assignment_id IN NUMBER,
        p_hire_date     IN DATE
    ) RETURN varchar2 IS
      --  l_hire_date date;
      --  l_term_date    date;
        l_hire_flag VARCHAR2(2);

    BEGIN
        SELECT
          case when to_char(pps.actual_termination_date,'RRRR') = to_char(to_date(p_hire_date,'DD-MON-RRRR'),'RRRR') then
                    'Y'
                ELSE
                    'N'
            END
        INTO l_hire_flag
        FROM
            per_periods_of_service pps,
            per_all_assignments_f  paaf
        WHERE
                pps.person_id = paaf.person_id
         --  AND pps.actual_termination_date BETWEEN ( p_hire_date - 272 ) AND ( p_hire_date - 1 )
  --  AND trunc(to_date(p_hire_date, 'DD-MON-YYYY') - to_date(pps.actual_termination_date, 'DD-MON-YYYY')) <= 135
            AND pps.actual_termination_date IS NOT NULL
            AND trunc(pps.actual_termination_date) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
            AND pps.actual_termination_date IN (
                SELECT
                    MAX(actual_termination_date)
                FROM
                    per_periods_of_service
                WHERE
                    person_id = pps.person_id
            )
            AND pps.person_id IN (
                SELECT
                    person_id
                FROM
                    per_all_assignments_f
                WHERE
                    assignment_id = p_assignment_id
                GROUP BY
                    person_id
            );

           RETURN l_hire_flag;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN NULL;
    END emp_rehired_same_year;
    --------------end same year function----------------
    FUNCTION TTEC_GET_ACCRUAL_ARCHIVE (
        p_assignment_id IN NUMBER
    ) RETURN NUMBER IS
        lv_accr_bal NUMBER;
        lv_pay_date DATE;
        lv_bal number;
        begin
    BEGIN
        SELECT
            MAX(ppa.effective_date)
        INTO lv_pay_date
        FROM
            pay_payroll_actions    ppa,
            pay_assignment_actions paa,
            pay_payrolls_f         pp,
            per_all_assignments_f  paaf,
            per_all_people_f       papf
        WHERE
                1 = 1
            AND paaf.assignment_id = p_assignment_id
            AND ppa.payroll_action_id = paa.payroll_action_id
            AND ppa.payroll_id = pp.payroll_id
            AND paaf.assignment_id = paa.assignment_id
            AND paaf.person_id = papf.person_id
            AND paa.action_status = 'C'
            and paa.assignment_action_type = 'R'
            and ppa.action_type = 'R'
            AND trunc(sysdate) BETWEEN papf.effective_start_date AND papf.effective_end_date;

        dbms_output.put_line('Start date :' || lv_pay_date);
    EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line('Error in returining employee last pay date' || sqlerrm);
    END;

BEGIN
    SELECT
        max(action_information6)
    INTO lv_accr_bal
    FROM
        pay_action_information
    WHERE
            assignment_id = p_assignment_id
        AND effective_date = lv_pay_date
        AND action_information_category = 'EMPLOYEE ACCRUALS'
        AND action_information4 = 'Wellness';
    dbms_output.put_line('Accrual Balance value :' || lv_accr_bal);
EXCEPTION
    WHEN OTHERS THEN
        dbms_output.put_line('Error in returining employee Accrual Balance Value' || sqlerrm);
END;

if lv_accr_bal is not null
then  lv_bal := lv_accr_bal;
else
 lv_bal := 0;
end if;

RETURN NVL(lv_bal,0);

end TTEC_GET_ACCRUAL_ARCHIVE;

END tt_per_accrual_calc_functions;
/
show errors;
/