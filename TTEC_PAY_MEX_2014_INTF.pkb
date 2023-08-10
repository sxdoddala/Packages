create or replace PACKAGE BODY      ttec_pay_mex_2014_intf
IS
   /*---------------------------------------------------------------------------------------
    Objective    : Interface to extract data for all Mexico employees to send to vendor
    Package spec :ttec_pay_mex_2014_intf
    Parameters:p_output_dir    --  output directory to generate the files.
               p_start_date  -- required payroll start paramters to run the report if the data is missing for particular dates
               p_end_date  -- required payroll end paramters to run the report if the data is missing for particular dates
      MODIFICATION HISTORY
      Person               Version  Date        Comments
      ------------------------------------------------
      Kaushik Babu         1.0      1/20/2014  New package for sending mexico payroll employee data to vendor INC0304270
      Kaushik Babu         1.1      6/26/2014  removed '-' for rfc_id column as per ticket INC0385479
	  Kaushik Babu         1.2      1/25/2014  Changes by Kaushik
      Christiane Chan      1.3      1/25/2014  Changes by Christiane Chan
      Christiane Chan      1.4      1/26/2014  Changes by Christiane Chan -- taken out MX_SF_COMPANY_LIQ  and MX_SF_LIQUIDATION from c_emp_element
                                                                          -- adding MX_RE_SAVING_FUNDS to both 'PE' and 'DE'
      Christiane Chan      1.5      1/26/2014  Changes by Christiane Chan -- to Fix Termed Employee got profit sharing after left company  eg. emp 7025464 Term in 2/28/14 profit sharing in first Period in May
      Christiane Chan      1.6      1/26/2014  Changes by Christiane Chan --  Performance tuning when only employee is provided at the parameter
      Christiane Chan      1.7      1/26/2014  Changes by Christiane Chan --  Add Pay date Paramater to control the NO record
      Christiane Chan      1.8      1/26/2014  Changes by Christiane Chan --  change to call Deduction ocounterpart instaed of Perception counterpard in element classification -> Earnings
	  RXNETHI-ARGANO       1.0      05/10/23   R12.2 Upgrade Remediation
   *== END ==================================================================================================*/
   FUNCTION get_balance (p_assignment_id       NUMBER,
                         p_balance_name     IN VARCHAR2,
                         p_dimension_name   IN VARCHAR2,
                         p_effective_date   IN DATE)
      RETURN NUMBER
   IS
      l_value   VARCHAR2 (100);
   BEGIN
      l_value := 0;

      SELECT NVL (SUM (a.balance_value), 0)
        INTO l_value
        FROM (SELECT prb.assignment_id, prb.balance_value,
                     pdb.defined_balance_id, pdb.balance_type_id,
                     pdb.balance_dimension_id
                FROM (SELECT defined_balance_id, assignment_id,
                             effective_date, balance_value
                        --FROM hr.pay_run_balances --code commented by RXNETHI-ARGANO,10/05/23
						FROM apps.pay_run_balances --code added by RXNETHI-ARGANO,10/05/23
                       WHERE     effective_date = p_effective_date
                             AND assignment_id IS NOT NULL
                             AND assignment_id = p_assignment_id) prb,
                     --hr.pay_defined_balances pdb --code commented by RXNETHI-ARGANO,10/05/23
					 apps.pay_defined_balances pdb --code added by RXNETHI-ARGANO,10/05/23
               WHERE prb.defined_balance_id = pdb.defined_balance_id) a,
             --hr.pay_balance_types pbt,      --code commented by RXNETHI-ARGANO,10/05/23
             --hr.pay_balance_dimensions pbd  --code commented by RXNETHI-ARGANO,10/05/23
			 apps.pay_balance_types pbt,      --code added by RXNETHI-ARGANO,10/05/23
             apps.pay_balance_dimensions pbd  --code added by RXNETHI-ARGANO,10/05/23
       WHERE     a.balance_type_id = pbt.balance_type_id
             AND pbt.balance_name LIKE p_balance_name
             AND pbt.legislation_code = 'MX'
             AND pbt.currency_code = 'MXN'
             AND a.balance_dimension_id = pbd.balance_dimension_id
             AND pbd.database_item_suffix = p_dimension_name;

      RETURN l_value;
   EXCEPTION
      WHEN OTHERS
      THEN
         l_value := 0;
         RETURN l_value;
   END get_balance;

   FUNCTION cvt_char (p_text VARCHAR2)
      RETURN VARCHAR2
   AS
      v_text   VARCHAR2 (150);
   BEGIN
      SELECT REPLACE (
                TRANSLATE (
                   CONVERT (TRIM (p_text) || ' ',            --'WE8ISO8859P1',
                                                             --'WE8ISO8859P9',
                    'WE8MSWIN1252', 'UTF8'),
                   '&:;'''',"??%^??#?',
                   '&'),
                '&',
                '')
        INTO v_text
        FROM DUAL;

      RETURN (v_text);
   EXCEPTION
      WHEN OTHERS
      THEN
         v_text := p_text;
         RETURN (v_text);
   END;

   FUNCTION get_risk_ins (p_gre_name VARCHAR2, p_session_date DATE)
      RETURN VARCHAR2
   AS
      l_result   VARCHAR2 (200);
   BEGIN
      l_result := NULL;

      SELECT ROUND (pucif.VALUE)
        INTO l_result
        FROM pay_user_tables put,
             pay_user_columns puc,
             pay_user_rows_f pur,
             pay_user_column_instances_f pucif
       WHERE     put.user_table_name = 'Work Risk Insurance Premium'
             AND puc.user_column_name = 'Percentage'
             AND pur.row_low_range_or_name = p_gre_name
             AND put.user_table_id = puc.user_table_id
             AND put.user_table_id = puc.user_table_id
             AND pucif.user_row_id = pur.user_row_id(+)
             AND puc.user_column_id = pucif.user_column_id(+)
             AND p_session_date BETWEEN pur.effective_start_date(+)
                                    AND pur.effective_end_date(+)
             AND p_session_date BETWEEN pucif.effective_start_date(+)
                                    AND pucif.effective_end_date(+);

      RETURN l_result;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         l_result := NULL;
         RETURN l_result;
      WHEN TOO_MANY_ROWS
      THEN
         l_result := NULL;
         RETURN l_result;
      WHEN OTHERS
      THEN
         l_result := NULL;
         RETURN l_result;
   END;

   FUNCTION get_cntr_name (p_column_name      VARCHAR2,
                           p_information11    VARCHAR2,
                           p_element_name     VARCHAR2,
                           p_session_date     DATE)
      RETURN VARCHAR2
   AS
      l_result   VARCHAR2 (200);
      l_value    VARCHAR2 (10);
   BEGIN
      l_result := NULL;
      l_value := NULL;

      IF p_information11 IS NULL
      THEN
         SELECT pucif.VALUE
           INTO l_value
           FROM pay_user_tables put,
                pay_user_columns puc,
                pay_user_rows_f pur,
                pay_user_column_instances_f pucif
          WHERE     put.user_table_name = 'TTEC_MEXICO_SAT_CODES'
                AND puc.user_column_name = 'Seeded Elements'
                AND pur.row_low_range_or_name = p_element_name
                AND put.user_table_id = puc.user_table_id
                AND put.user_table_id = puc.user_table_id
                AND pucif.user_row_id = pur.user_row_id(+)
                AND puc.user_column_id = pucif.user_column_id(+)
                AND p_session_date BETWEEN pur.effective_start_date(+)
                                       AND pur.effective_end_date(+)
                AND p_session_date BETWEEN pucif.effective_start_date(+)
                                       AND pucif.effective_end_date(+);
      END IF;

      SELECT SUBSTRB (pucif.VALUE,
                      INSTR (pucif.VALUE, '-') + 1,
                      LENGTH (pucif.VALUE))
        INTO l_result
        FROM pay_user_tables put,
             pay_user_columns puc,
             pay_user_rows_f pur,
             pay_user_column_instances_f pucif
       WHERE     put.user_table_name = 'TTEC_MEXICO_SAT_CODES'
             AND puc.user_column_name = p_column_name
             AND pur.row_low_range_or_name = NVL (p_information11, l_value)
             AND put.user_table_id = puc.user_table_id
             AND put.user_table_id = puc.user_table_id
             AND pucif.user_row_id = pur.user_row_id(+)
             AND puc.user_column_id = pucif.user_column_id(+)
             AND p_session_date BETWEEN pur.effective_start_date(+)
                                    AND pur.effective_end_date(+)
             AND p_session_date BETWEEN pucif.effective_start_date(+)
                                    AND pucif.effective_end_date(+);

      RETURN l_result;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         l_result := NULL;
         RETURN l_result;
      WHEN TOO_MANY_ROWS
      THEN
         l_result := NULL;
         RETURN l_result;
      WHEN OTHERS
      THEN
         l_result := NULL;
         RETURN l_result;
   END;

   FUNCTION get_cntr_code (p_column_name      VARCHAR2,
                           p_information11    VARCHAR2,
                           p_element_name     VARCHAR2,
                           p_session_date     DATE)
      RETURN VARCHAR2
   AS
      l_result   VARCHAR2 (200);
      l_value    VARCHAR2 (10);
   BEGIN
      l_result := NULL;
      l_value := NULL;

      IF p_information11 IS NULL
      THEN
         SELECT pucif.VALUE
           INTO l_value
           FROM pay_user_tables put,
                pay_user_columns puc,
                pay_user_rows_f pur,
                pay_user_column_instances_f pucif
          WHERE     put.user_table_name = 'TTEC_MEXICO_SAT_CODES'
                AND puc.user_column_name = 'Seeded Elements'
                AND pur.row_low_range_or_name = p_element_name
                AND put.user_table_id = puc.user_table_id
                AND put.user_table_id = puc.user_table_id
                AND pucif.user_row_id = pur.user_row_id(+)
                AND puc.user_column_id = pucif.user_column_id(+)
                AND p_session_date BETWEEN pur.effective_start_date(+)
                                       AND pur.effective_end_date(+)
                AND p_session_date BETWEEN pucif.effective_start_date(+)
                                       AND pucif.effective_end_date(+);
      END IF;

      SELECT SUBSTRB (pucif.VALUE, 1, INSTR (pucif.VALUE, '-') - 1)
        INTO l_result
        FROM pay_user_tables put,
             pay_user_columns puc,
             pay_user_rows_f pur,
             pay_user_column_instances_f pucif
       WHERE     put.user_table_name = 'TTEC_MEXICO_SAT_CODES'
             AND puc.user_column_name = p_column_name
             AND pur.row_low_range_or_name = NVL (p_information11, l_value)
             AND put.user_table_id = puc.user_table_id
             AND put.user_table_id = puc.user_table_id
             AND pucif.user_row_id = pur.user_row_id(+)
             AND puc.user_column_id = pucif.user_column_id(+)
             AND p_session_date BETWEEN pur.effective_start_date(+)
                                    AND pur.effective_end_date(+)
             AND p_session_date BETWEEN pucif.effective_start_date(+)
                                    AND pucif.effective_end_date(+);

      RETURN l_result;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         l_result := NULL;
         RETURN l_result;
      WHEN TOO_MANY_ROWS
      THEN
         l_result := NULL;
         RETURN l_result;
      WHEN OTHERS
      THEN
         l_result := NULL;
         RETURN l_result;
   END;

   FUNCTION get_sat_code (p_element_name            VARCHAR2,
                          p_information_category    VARCHAR2,
                          p_information11           VARCHAR2,
                          p_session_date            DATE)
      RETURN VARCHAR2
   AS
      l_result   VARCHAR2 (200);
   BEGIN
      l_result := NULL;

      SELECT pucif.VALUE
        INTO l_result
        FROM pay_user_tables put,
             pay_user_columns puc,
             pay_user_rows_f pur,
             pay_user_column_instances_f pucif
       WHERE     put.user_table_name = 'TTEC_MEXICO_SAT_CODES'
             AND puc.user_column_name = 'Seeded Elements'
             AND pur.row_low_range_or_name = p_element_name
             AND put.user_table_id = puc.user_table_id
             AND put.user_table_id = puc.user_table_id
             AND pucif.user_row_id = pur.user_row_id(+)
             AND puc.user_column_id = pucif.user_column_id(+)
             AND p_session_date BETWEEN pur.effective_start_date(+)
                                    AND pur.effective_end_date(+)
             AND p_session_date BETWEEN pucif.effective_start_date(+)
                                    AND pucif.effective_end_date(+);

      RETURN l_result;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         BEGIN
            SELECT LPAD (
                      SUBSTRB (flv.meaning, 1, INSTR (flv.meaning, '-') - 2),
                      3,
                      '0')
              INTO l_result
              FROM fnd_lookup_values flv
             WHERE flv.LANGUAGE = 'US' AND flv.lookup_code = p_information11
                   AND flv.lookup_type =
                          DECODE (
                             p_information_category,
                             'MX_SUPPLEMENTAL EARNINGS', 'MX_PAYSLIP_EARNING_CODES',
                             'MX_IMPUTED EARNINGS', 'MX_PAYSLIP_EARNING_CODES',
                             'MX_EARNINGS', 'MX_PAYSLIP_EARNING_CODES');

            RETURN l_result;
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               l_result := NULL;
               RETURN l_result;
            WHEN TOO_MANY_ROWS
            THEN
               l_result := NULL;
               RETURN l_result;
            WHEN OTHERS
            THEN
               l_result := NULL;
               RETURN l_result;
         END;
      WHEN TOO_MANY_ROWS
      THEN
         l_result := NULL;
         RETURN l_result;
      WHEN OTHERS
      THEN
         l_result := NULL;
         RETURN l_result;
   END;

   FUNCTION get_rep_name (p_element_name VARCHAR2, p_session_date DATE)
      RETURN VARCHAR2
   AS
      l_result   VARCHAR2 (200);
   BEGIN
      l_result := NULL;

      SELECT pucif.VALUE
        INTO l_result
        FROM pay_user_tables put,
             pay_user_columns puc,
             pay_user_rows_f pur,
             pay_user_column_instances_f pucif
       WHERE     put.user_table_name = 'TTEC_MEXICO_SAT_CODES'
             AND puc.user_column_name = 'Reporting Name'
             AND pur.row_low_range_or_name = p_element_name
             AND put.user_table_id = puc.user_table_id
             AND put.user_table_id = puc.user_table_id
             AND pucif.user_row_id = pur.user_row_id(+)
             AND puc.user_column_id = pucif.user_column_id(+)
             AND p_session_date BETWEEN pur.effective_start_date(+)
                                    AND pur.effective_end_date(+)
             AND p_session_date BETWEEN pucif.effective_start_date(+)
                                    AND pucif.effective_end_date(+);

      RETURN l_result;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         l_result := NULL;
         RETURN l_result;
      WHEN TOO_MANY_ROWS
      THEN
         l_result := NULL;
         RETURN l_result;
      WHEN OTHERS
      THEN
         l_result := NULL;
         RETURN l_result;
   END;
-- 1.2 Kaushik
   FUNCTION get_information (p_element_name VARCHAR2, p_session_date DATE)
      RETURN VARCHAR2
   AS
      l_result   VARCHAR2 (200);
   BEGIN
      l_result := 'N';

      SELECT pucif.VALUE
        INTO l_result
        FROM pay_user_tables put,
             pay_user_columns puc,
             pay_user_rows_f pur,
             pay_user_column_instances_f pucif
       WHERE     put.user_table_name = 'TTEC_MEXICO_SAT_CODES'
             AND puc.user_column_name = 'Information'
             AND pur.row_low_range_or_name = p_element_name
             AND put.user_table_id = puc.user_table_id
             AND put.user_table_id = puc.user_table_id
             AND pucif.user_row_id = pur.user_row_id(+)
             AND puc.user_column_id = pucif.user_column_id(+)
             AND p_session_date BETWEEN pur.effective_start_date(+)
                                    AND pur.effective_end_date(+)
             AND p_session_date BETWEEN pucif.effective_start_date(+)
                                    AND pucif.effective_end_date(+);

      RETURN l_result;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         l_result := 'N';
         RETURN l_result;
      WHEN TOO_MANY_ROWS
      THEN
         l_result := 'N';
         RETURN l_result;
      WHEN OTHERS
      THEN
         l_result := 'N';
         RETURN l_result;
   END;

   FUNCTION get_value (p_element_name    IN VARCHAR2,
                       p_class_name      IN VARCHAR2,
                       p_input_value     IN VARCHAR2,
                       p_assignment_id   IN VARCHAR2,
                       p_start_date      IN DATE,
                       p_end_date        IN DATE)
      RETURN NUMBER
   AS
      l_result_value   VARCHAR2 (100);
   BEGIN
      IF p_element_name = 'ISR'
      THEN
         SELECT NVL (SUM (TO_NUMBER (result_value)), 0)
           INTO l_result_value
           FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                        LPAD (petf.element_information11, 3, '0') sat_code,
                        petf.element_type_id, petf.reporting_name
                   FROM apps.pay_run_results prr,
                        apps.pay_element_types_f petf,
                        apps.pay_element_classifications pec
                  WHERE prr.element_type_id = petf.element_type_id
                        AND petf.classification_id = pec.classification_id
                        AND UPPER (pec.classification_name) LIKE
                               UPPER (
                                  NVL ('%' || p_class_name || '%',
                                       pec.classification_name))
                        AND UPPER (petf.element_name) =
                               UPPER (
                                  NVL (p_element_name, petf.element_name))) a,
                (SELECT paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,10/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,10/05/23
                        apps.per_time_periods ptp
                  WHERE     ppa.payroll_action_id = paa.payroll_action_id
                        AND paa.assignment_id = paaf.assignment_id
                        AND paaf.primary_flag = 'Y'
                        AND paaf.assignment_id = p_assignment_id
                        AND ptp.payroll_id = ppa.payroll_id
                        AND ptp.regular_payment_date = ppa.effective_date
                        AND ppa.date_earned BETWEEN paaf.effective_start_date
                                                AND paaf.effective_end_date
                        AND ppa.effective_date BETWEEN p_start_date
                                                   AND p_end_date) b,
                (SELECT prrv.run_result_id, prrv.result_value
                   FROM apps.pay_input_values_f pivf,
                        apps.pay_run_result_values prrv
                  WHERE     pivf.input_value_id = prrv.input_value_id
                        AND prrv.result_value IS NOT NULL
                        AND pivf.NAME = p_input_value) c
          WHERE a.assignment_action_id = b.assignment_action_id
                AND a.run_result_id = c.run_result_id;
      ELSE
         SELECT NVL (SUM (TO_NUMBER (ABS (result_value))), 0)
           INTO l_result_value
           FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                        LPAD (petf.element_information11, 3, '0') sat_code,
                        petf.element_type_id, petf.reporting_name
                   FROM apps.pay_run_results prr,
                        apps.pay_element_types_f petf,
                        apps.pay_element_classifications pec
                  WHERE prr.element_type_id = petf.element_type_id
                        AND petf.classification_id = pec.classification_id
                        AND UPPER (pec.classification_name) LIKE
                               UPPER (
                                  NVL ('%' || p_class_name || '%',
                                       pec.classification_name))
                        AND UPPER (petf.element_name) =
                               UPPER (
                                  NVL (p_element_name, petf.element_name))) a,
                (SELECT paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,10/05/23
                        apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,10/05/23
						apps.per_time_periods ptp
                  WHERE     ppa.payroll_action_id = paa.payroll_action_id
                        AND paa.assignment_id = paaf.assignment_id
                        AND paaf.primary_flag = 'Y'
                        AND paaf.assignment_id = p_assignment_id
                        AND ptp.payroll_id = ppa.payroll_id
                        AND ptp.regular_payment_date = ppa.effective_date
                        AND ppa.date_earned BETWEEN paaf.effective_start_date
                                                AND paaf.effective_end_date
                        AND ppa.effective_date BETWEEN p_start_date
                                                   AND p_end_date) b,
                (SELECT prrv.run_result_id, prrv.result_value
                   FROM apps.pay_input_values_f pivf,
                        apps.pay_run_result_values prrv
                  WHERE     pivf.input_value_id = prrv.input_value_id
                        AND prrv.result_value IS NOT NULL
                        AND pivf.NAME = p_input_value) c
          WHERE a.assignment_action_id = b.assignment_action_id
                AND a.run_result_id = c.run_result_id;
      END IF;

      RETURN l_result_value;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         l_result_value := 0;
         RETURN l_result_value;
      WHEN OTHERS
      THEN
         l_result_value := 0;
         RETURN l_result_value;
         fnd_file.put_line (fnd_file.LOG,
                            'Error out of get_value procedure -' || SQLERRM);
   END;

   FUNCTION get_neg_value (p_element_name    IN VARCHAR2,
                           p_class_name      IN VARCHAR2,
                           p_input_value     IN VARCHAR2,
                           p_assignment_id   IN VARCHAR2,
                           p_start_date      IN DATE,
                           p_end_date        IN DATE)
      RETURN NUMBER
   AS
      l_result_value   VARCHAR2 (100);
   BEGIN
      SELECT NVL (SUM (TO_NUMBER (ABS (result_value))), 0)
        INTO l_result_value
        FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                     LPAD (petf.element_information11, 3, '0') sat_code,
                     petf.element_type_id, petf.reporting_name
                FROM apps.pay_run_results prr,
                     apps.pay_element_types_f petf,
                     apps.pay_element_classifications pec
               WHERE prr.element_type_id = petf.element_type_id
                     AND petf.classification_id = pec.classification_id
                     AND UPPER (pec.classification_name) LIKE
                            UPPER (
                               NVL ('%' || p_class_name || '%',
                                    pec.classification_name))
                     AND petf.element_name <> 'ISR'
                     AND UPPER (petf.element_name) =
                            UPPER (NVL (p_element_name, petf.element_name))) a,
             (SELECT paa.assignment_action_id, ppa.date_earned,
                     ppa.effective_date, ptp.start_date, ptp.end_date
                FROM apps.pay_assignment_actions paa,
                     apps.pay_payroll_actions ppa,
                     --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,10/05/23
					 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,10/05/23
                     apps.per_time_periods ptp
               WHERE     ppa.payroll_action_id = paa.payroll_action_id
                     AND paa.assignment_id = paaf.assignment_id
                     AND paaf.primary_flag = 'Y'
                     AND paaf.assignment_id = p_assignment_id
                     AND ptp.payroll_id = ppa.payroll_id
                     AND ptp.regular_payment_date = ppa.effective_date
                     AND ppa.date_earned BETWEEN paaf.effective_start_date
                                             AND paaf.effective_end_date
                     AND ppa.effective_date BETWEEN p_start_date
                                                AND p_end_date) b,
             (SELECT prrv.run_result_id, prrv.result_value
                FROM apps.pay_input_values_f pivf,
                     apps.pay_run_result_values prrv
               WHERE     pivf.input_value_id = prrv.input_value_id
                     AND prrv.result_value IS NOT NULL
                     AND prrv.result_value LIKE '%-%'
                     AND pivf.NAME = p_input_value) c
       WHERE a.assignment_action_id = b.assignment_action_id
             AND a.run_result_id = c.run_result_id;

      RETURN l_result_value;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         l_result_value := 0;
         RETURN l_result_value;
      WHEN OTHERS
      THEN
         l_result_value := 0;
         RETURN l_result_value;
         fnd_file.put_line (
            fnd_file.LOG,
            'Error out of get_neg_value procedure -' || SQLERRM);
   END;

   FUNCTION get_ear_value (p_element_name    IN VARCHAR2,
                           p_class_name      IN VARCHAR2,
                           p_input_value     IN VARCHAR2,
                           p_assignment_id   IN VARCHAR2,
                           p_start_date      IN DATE,
                           p_end_date        IN DATE)
      RETURN NUMBER
   AS
      l_result_value   VARCHAR2 (100);
      l_count          NUMBER;
   BEGIN
      l_result_value := NULL;
      l_count := 0;

      SELECT NVL (SUM (TO_NUMBER (result_value)), 0), COUNT (*)
        INTO l_result_value, l_count
        FROM (SELECT ABS (c.result_value) result_value, a.run_result_id
                FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                             petf.element_information11, petf.element_type_id,
                             petf.reporting_name, petf.element_name,
                             petf.element_information_category, 'E' ear_ded
                        FROM apps.pay_run_results prr,
                             apps.pay_element_types_f petf,
                             apps.pay_element_classifications pec
                       WHERE prr.element_type_id = petf.element_type_id
                             AND petf.classification_id =
                                    pec.classification_id
                             AND pec.classification_name LIKE
                                    '%' || p_class_name || '%'
                             AND UPPER (petf.element_name) =
                                    UPPER (
                                       NVL (p_element_name,
                                            petf.element_name))
                             AND petf.element_name NOT IN
                                    ('MX_ML_WORK_RISK',
                                     'MX_ML_SICKNESS',
                                     'MX_ML_MATERNITY',
                                     'MX_ML_WORK_RISK Pending',
                                     'MX_NCNS',                           --1.3
                                     'MX_NCNS Pending', --1.3
                                     'MX_SUSPENSION', --1.8
                                     'MX_NO_PAY_AUT_LEAVE', --1.8
                                     'MX_OVERPAID_SALARY', --1.8
                                     'MX_ML_SICKNESS Pending',
                                     'MX_ML_MATERNITY Pending')) a,
                     (SELECT paa.assignment_action_id, ppa.date_earned,
                             ppa.effective_date, ptp.start_date, ptp.end_date
                        FROM apps.pay_assignment_actions paa,
                             apps.pay_payroll_actions ppa,
                             --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,10/05/23
							 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,10/05/23
                             apps.per_time_periods ptp
                       WHERE ppa.payroll_action_id = paa.payroll_action_id
                             AND paa.assignment_id = paaf.assignment_id
                             AND paaf.primary_flag = 'Y'
                             AND paaf.assignment_id = p_assignment_id
                             AND ptp.payroll_id = ppa.payroll_id
                             AND ptp.regular_payment_date =
                                    ppa.effective_date
                             AND ppa.date_earned BETWEEN paaf.effective_start_date
                                                     AND paaf.effective_end_date
                             AND ppa.effective_date BETWEEN p_start_date
                                                        AND p_end_date) b,
                     (SELECT prrv.run_result_id, prrv.result_value
                        FROM apps.pay_input_values_f pivf,
                             apps.pay_run_result_values prrv
                       WHERE     pivf.input_value_id = prrv.input_value_id
                             AND prrv.result_value <> '0'
                             AND prrv.result_value NOT LIKE '%-%'
                             AND pivf.NAME = NVL (p_input_value, pivf.NAME)) c
               WHERE a.assignment_action_id = b.assignment_action_id
                     AND a.run_result_id = c.run_result_id
              UNION
              SELECT TO_NUMBER (c.result_value), a.run_result_id
                FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                             petf.element_information11, petf.element_type_id,
                             petf.reporting_name, petf.element_name,
                             'E' ear_ded, petf.element_information_category
                        FROM apps.pay_run_results prr,
                             apps.pay_element_types_f petf,
                             apps.pay_element_classifications pec
                       WHERE prr.element_type_id = petf.element_type_id
                             AND petf.classification_id =
                                    pec.classification_id
                             AND pec.classification_name IN ('Tax Credit')
                             AND UPPER (petf.element_name) =
                                    UPPER (
                                       NVL (p_element_name,
                                            petf.element_name))) a,
                     (SELECT paa.assignment_action_id, ppa.date_earned,
                             ppa.effective_date, ptp.start_date, ptp.end_date
                        FROM apps.pay_assignment_actions paa,
                             apps.pay_payroll_actions ppa,
                             --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,10/05/23
							 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,10/05/23
                             apps.per_time_periods ptp
                       WHERE ppa.payroll_action_id = paa.payroll_action_id
                             AND paa.assignment_id = paaf.assignment_id
                             AND paaf.primary_flag = 'Y'
                             AND paaf.assignment_id = p_assignment_id
                             AND ptp.payroll_id = ppa.payroll_id
                             AND ptp.regular_payment_date =
                                    ppa.effective_date
                             AND ppa.date_earned BETWEEN paaf.effective_start_date
                                                     AND paaf.effective_end_date
                             AND ppa.effective_date BETWEEN p_start_date
                                                        AND p_end_date) b,
                     (SELECT prrv.run_result_id, prrv.result_value
                        FROM apps.pay_input_values_f pivf,
                             apps.pay_run_result_values prrv
                       WHERE     pivf.input_value_id = prrv.input_value_id
                             AND prrv.result_value <> '0'
                             --AND prrv.result_value NOT LIKE '%-%'
                             AND pivf.NAME IN ('Pay Value')) c
               WHERE a.assignment_action_id = b.assignment_action_id
                     AND a.run_result_id = c.run_result_id
              UNION
              SELECT (ABS ('0')) result_value, a.run_result_id
                FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                             petf.element_information11, petf.element_type_id,
                             petf.reporting_name, petf.element_name,
                             'E' ear_ded, petf.element_information_category
                        FROM apps.pay_run_results prr,
                             apps.pay_element_types_f petf,
                             apps.pay_element_classifications pec
                       WHERE prr.element_type_id = petf.element_type_id
                             AND petf.classification_id =
                                    pec.classification_id
                             AND pec.classification_name IN
                                    ('Non-payroll Payments')
                             AND petf.element_name NOT IN  -- 1.4
                                    ('MX_SF_COMPANY_LIQ',  -- 1.4
                                     'MX_SF_LIQUIDATION')  -- 1.4
                             AND UPPER (petf.element_name) =
                                    UPPER (
                                       NVL (p_element_name,
                                            petf.element_name))) a,
                     (SELECT paa.assignment_action_id, ppa.date_earned,
                             ppa.effective_date, ptp.start_date, ptp.end_date
                        FROM apps.pay_assignment_actions paa,
                             apps.pay_payroll_actions ppa,
                             --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,10/05/23
							 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,10/05/23
                             apps.per_time_periods ptp
                       WHERE ppa.payroll_action_id = paa.payroll_action_id
                             AND paa.assignment_id = paaf.assignment_id
                             AND paaf.primary_flag = 'Y'
                             AND paaf.assignment_id = p_assignment_id
                             AND ptp.payroll_id = ppa.payroll_id
                             AND ptp.regular_payment_date =
                                    ppa.effective_date
                             AND ppa.date_earned BETWEEN paaf.effective_start_date
                                                     AND paaf.effective_end_date
                             AND ppa.effective_date BETWEEN p_start_date
                                                        AND p_end_date) b,
                     (SELECT prrv.run_result_id, prrv.result_value
                        FROM apps.pay_input_values_f pivf,
                             apps.pay_run_result_values prrv
                       WHERE     pivf.input_value_id = prrv.input_value_id
                             AND prrv.result_value <> '0'
                             AND prrv.result_value NOT LIKE '%-%'
                             AND pivf.NAME IN ('Pay Value')) c
               WHERE a.assignment_action_id = b.assignment_action_id
                     AND a.run_result_id = c.run_result_id
              UNION
              SELECT ABS (c.result_value) result_value, a.run_result_id
                FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                             petf.element_information11, petf.element_type_id,
                             petf.reporting_name, petf.element_name,
                             'E' ear_ded, petf.element_information_category
                        FROM apps.pay_run_results prr,
                             apps.pay_element_types_f petf,
                             apps.pay_element_classifications pec
                       WHERE prr.element_type_id = petf.element_type_id
                             AND petf.classification_id =
                                    pec.classification_id
                             AND pec.classification_name IN ('Amends')
                             AND UPPER (petf.element_name) =
                                    UPPER (
                                       NVL (p_element_name,
                                            petf.element_name))) a,
                     (SELECT paa.assignment_action_id, ppa.date_earned,
                             ppa.effective_date, ptp.start_date, ptp.end_date
                        FROM apps.pay_assignment_actions paa,
                             apps.pay_payroll_actions ppa,
                             --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,10/05/23
							 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,10/05/23
                             apps.per_time_periods ptp
                       WHERE ppa.payroll_action_id = paa.payroll_action_id
                             AND paa.assignment_id = paaf.assignment_id
                             AND paaf.primary_flag = 'Y'
                             AND paaf.assignment_id = p_assignment_id
                             AND ptp.payroll_id = ppa.payroll_id
                             AND ptp.regular_payment_date =
                                    ppa.effective_date
                             AND ppa.date_earned BETWEEN paaf.effective_start_date
                                                     AND paaf.effective_end_date
                             AND ppa.effective_date BETWEEN p_start_date
                                                        AND p_end_date) b,
                     (SELECT prrv.run_result_id, prrv.result_value
                        FROM apps.pay_input_values_f pivf,
                             apps.pay_run_result_values prrv
                       WHERE     pivf.input_value_id = prrv.input_value_id
                             AND prrv.result_value <> '0'
                             AND prrv.result_value NOT LIKE '%-%'
                             AND pivf.NAME IN ('ISR Subject')) c
               WHERE a.assignment_action_id = b.assignment_action_id
                     AND a.run_result_id = c.run_result_id
              UNION
              SELECT TO_NUMBER (c.result_value) result_value, a.run_result_id
                FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                             petf.element_information11, petf.element_type_id,
                             petf.reporting_name, petf.element_name,
                             petf.element_information_category, 'D' ear_ded
                        FROM apps.pay_run_results prr,
                             apps.pay_element_types_f petf,
                             apps.pay_element_classifications pec
                       WHERE prr.element_type_id = petf.element_type_id
                             AND petf.classification_id =
                                    pec.classification_id
                             AND pec.classification_name LIKE '%Deduction%'
                             AND petf.element_name <> 'ISR'
                             AND UPPER (petf.element_name) =
                                    UPPER (
                                       NVL (p_element_name,
                                            petf.element_name))) a,
                     (SELECT paa.assignment_action_id, ppa.date_earned,
                             ppa.effective_date, ptp.start_date, ptp.end_date
                        FROM apps.pay_assignment_actions paa,
                             apps.pay_payroll_actions ppa,
                             --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,10/05/23
							 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,10/05/23
                             apps.per_time_periods ptp
                       WHERE ppa.payroll_action_id = paa.payroll_action_id
                             AND paa.assignment_id = paaf.assignment_id
                             AND paaf.primary_flag = 'Y'
                             AND paaf.assignment_id = p_assignment_id
                             AND ptp.payroll_id = ppa.payroll_id
                             AND ptp.regular_payment_date =
                                    ppa.effective_date
                             AND ppa.date_earned BETWEEN paaf.effective_start_date
                                                     AND paaf.effective_end_date
                             AND ppa.effective_date BETWEEN p_start_date
                                                        AND p_end_date) b,
                     (SELECT prrv.run_result_id, prrv.result_value
                        FROM apps.pay_input_values_f pivf,
                             apps.pay_run_result_values prrv
                       WHERE     pivf.input_value_id = prrv.input_value_id
                             AND prrv.result_value LIKE '%-%'
                             AND pivf.NAME IN ('Pay Value')) c
               WHERE a.assignment_action_id = b.assignment_action_id
                     AND a.run_result_id = c.run_result_id);

--         UNION /* --1.4 Saving Fund*/
/*             SELECT TO_NUMBER (c.result_value) result_value, a.run_result_id
                    FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                                 petf.element_information11,
                                 petf.element_type_id, petf.reporting_name,
                                 petf.element_name,
                                 petf.element_information_category,
                                 'E' ear_ded
                            FROM apps.pay_run_results prr,
                                 apps.pay_element_types_f petf,
                                 apps.pay_element_classifications pec
                           WHERE prr.element_type_id = petf.element_type_id
                             AND petf.classification_id =
                                                         pec.classification_id
                             AND pec.classification_name LIKE '%Information%'
                             AND petf.element_name = 'MX_RE_SAVING_FUNDS'  -- 1.4
                             ) a,
                         (SELECT paa.assignment_action_id, ppa.date_earned,
                                 ppa.effective_date, ptp.start_date,
                                 ptp.end_date
                            FROM apps.pay_assignment_actions paa,
                                 apps.pay_payroll_actions ppa,
--                                 hr_lookups lo1,
                                 hr.per_all_assignments_f paaf,
                                 apps.per_time_periods ptp
                           WHERE ppa.payroll_action_id = paa.payroll_action_id
                             AND paa.assignment_id = paaf.assignment_id
                             AND paaf.primary_flag = 'Y'
                             AND paaf.assignment_id = p_assignment_id
                             AND paa.assignment_id = paaf.assignment_id
--                             AND lo1.lookup_type = 'ACTION_TYPE'
--                             AND lo1.meaning =  'Balance adjustment'
--                             AND lo1.lookup_code = ppa.action_type
                             AND ptp.payroll_id = ppa.payroll_id
                             AND ptp.regular_payment_date = ppa.effective_date
                             AND ppa.date_earned
                                    BETWEEN paaf.effective_start_date
                                        AND paaf.effective_end_date
                             AND ppa.effective_date BETWEEN p_start_date
                                                        AND p_end_date) b,
                         (SELECT prrv.run_result_id, prrv.result_value
                            FROM apps.pay_input_values_f pivf,
                                 apps.pay_run_result_values prrv
                           WHERE pivf.input_value_id = prrv.input_value_id
                             AND prrv.result_value <> '0'
                             AND prrv.result_value NOT LIKE '%-%'
                             AND UPPER (pivf.NAME) IN UPPER ('Pay Value')) c
                   WHERE a.assignment_action_id = b.assignment_action_id
                     AND a.run_result_id = c.run_result_id);
*/

      IF l_result_value <= 0 AND l_count = 1
      THEN
         l_result_value := 0;
      END IF;

      RETURN l_result_value;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         l_result_value := 0;
         RETURN l_result_value;
      WHEN OTHERS
      THEN
         l_result_value := 0;
         RETURN l_result_value;
         fnd_file.put_line (
            fnd_file.LOG,
            'Error out of get_ear_value procedure -' || SQLERRM);
   END;

   FUNCTION get_ded_value (p_element_name    IN VARCHAR2,
                           p_class_name      IN VARCHAR2,
                           p_input_value     IN VARCHAR2,
                           p_assignment_id   IN VARCHAR2,
                           p_start_date      IN DATE,
                           p_end_date        IN DATE)
      RETURN NUMBER
   AS
      l_result_value   VARCHAR2 (100);
      l_count          NUMBER;
   BEGIN
      l_result_value := NULL;
      l_count := 0;

      SELECT NVL (SUM (TO_NUMBER (result_value)), 0), COUNT (*)
        INTO l_result_value, l_count
        FROM (SELECT ABS (c.result_value) result_value, a.run_result_id
                FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                             LPAD (petf.element_information11, 3, '0') sat_code,
                             petf.element_type_id, petf.reporting_name,
                             petf.element_name, 'D' ear_ded
                        FROM apps.pay_run_results prr,
                             apps.pay_element_types_f petf,
                             apps.pay_element_classifications pec
                       WHERE prr.element_type_id = petf.element_type_id
                             AND petf.classification_id =
                                    pec.classification_id
                             AND UPPER (petf.element_name) =
                                    UPPER (
                                       NVL (p_element_name,
                                            petf.element_name))
                             AND pec.classification_name LIKE
                                    '%' || p_class_name || '%') a,
                     (SELECT paa.assignment_action_id, ppa.date_earned,
                             ppa.effective_date, ptp.start_date, ptp.end_date
                        FROM apps.pay_assignment_actions paa,
                             apps.pay_payroll_actions ppa,
                             --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,10/05/23
							 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,10/05/23
                             apps.per_time_periods ptp
                       WHERE ppa.payroll_action_id = paa.payroll_action_id
                             AND paa.assignment_id = paaf.assignment_id
                             AND paaf.primary_flag = 'Y'
                             AND paaf.assignment_id = p_assignment_id
                             AND ptp.payroll_id = ppa.payroll_id
                             AND ptp.regular_payment_date =
                                    ppa.effective_date
                             AND ppa.date_earned BETWEEN paaf.effective_start_date
                                                     AND paaf.effective_end_date
                             AND ppa.effective_date BETWEEN p_start_date
                                                        AND p_end_date) b,
                     (SELECT prrv.run_result_id, prrv.result_value
                        FROM apps.pay_input_values_f pivf,
                             apps.pay_run_result_values prrv
                       WHERE     pivf.input_value_id = prrv.input_value_id
                             AND prrv.result_value <> '0'
                             AND prrv.result_value NOT LIKE '%-%'
                             AND pivf.NAME IN ('Pay Value')) c
               WHERE a.assignment_action_id = b.assignment_action_id
                     AND a.run_result_id = c.run_result_id
              UNION
              SELECT TO_NUMBER (c.result_value) result_value, a.run_result_id
                FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                             LPAD (petf.element_information11, 3, '0') sat_code,
                             petf.element_type_id, petf.reporting_name,
                             petf.element_name, 'D' ear_ded
                        FROM apps.pay_run_results prr,
                             apps.pay_element_types_f petf,
                             apps.pay_element_classifications pec
                       WHERE prr.element_type_id = petf.element_type_id
                             AND petf.classification_id =
                                    pec.classification_id
                             AND petf.element_name = 'ISR'
                             AND UPPER (petf.element_name) =
                                    UPPER (
                                       NVL (p_element_name,
                                            petf.element_name))
                             AND pec.classification_name LIKE
                                    '%' || p_class_name || '%') a,
                     (SELECT paa.assignment_action_id, ppa.date_earned,
                             ppa.effective_date, ptp.start_date, ptp.end_date
                        FROM apps.pay_assignment_actions paa,
                             apps.pay_payroll_actions ppa,
                             --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,10/05/23
                             apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,10/05/23
							 apps.per_time_periods ptp
                       WHERE ppa.payroll_action_id = paa.payroll_action_id
                             AND paa.assignment_id = paaf.assignment_id
                             AND paaf.primary_flag = 'Y'
                             AND paaf.assignment_id = p_assignment_id
                             AND ptp.payroll_id = ppa.payroll_id
                             AND ptp.regular_payment_date =
                                    ppa.effective_date
                             AND ppa.date_earned BETWEEN paaf.effective_start_date
                                                     AND paaf.effective_end_date
                             AND ppa.effective_date BETWEEN p_start_date
                                                        AND p_end_date) b,
                     (SELECT prrv.run_result_id, prrv.result_value
                        FROM apps.pay_input_values_f pivf,
                             apps.pay_run_result_values prrv
                       WHERE     pivf.input_value_id = prrv.input_value_id
                             AND prrv.result_value <> '0'
                             AND prrv.result_value LIKE '%-%'
                             AND pivf.NAME IN ('Pay Value')) c
               WHERE a.assignment_action_id = b.assignment_action_id
                     AND a.run_result_id = c.run_result_id
              UNION
              SELECT ABS (c.result_value) result_value, a.run_result_id
                FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                             petf.element_information11, petf.element_type_id,
                             petf.reporting_name, petf.element_name,
                             'E' ear_ded, petf.element_information_category
                        FROM apps.pay_run_results prr,
                             apps.pay_element_types_f petf,
                             apps.pay_element_classifications pec
                       WHERE prr.element_type_id = petf.element_type_id
                             AND petf.classification_id =
                                    pec.classification_id
                             AND pec.classification_name LIKE '%Earning%'
                             AND UPPER (petf.element_name) =
                                    UPPER (
                                       NVL (p_element_name,
                                            petf.element_name))
                             AND petf.element_name IN
                                    ('MX_ML_WORK_RISK',
                                     'MX_ML_SICKNESS',
                                     'MX_ML_MATERNITY',
                                     'MX_ML_WORK_RISK Pending',
                                     'MX_NCNS',                           --1.3
                                     'MX_NCNS Pending', --1.3
                                     'MX_SUSPENSION', --1.8
                                     'MX_NO_PAY_AUT_LEAVE', --1.8
                                     'MX_OVERPAID_SALARY', --1.8
                                     'MX_ML_SICKNESS Pending',
                                     'MX_ML_MATERNITY Pending')) a,
                     (SELECT paa.assignment_action_id, ppa.date_earned,
                             ppa.effective_date, ptp.start_date, ptp.end_date
                        FROM apps.pay_assignment_actions paa,
                             apps.pay_payroll_actions ppa,
                             --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,10/05/23
							 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,10/05/23
                             apps.per_time_periods ptp
                       WHERE ppa.payroll_action_id = paa.payroll_action_id
                             AND paa.assignment_id = paaf.assignment_id
                             AND paaf.primary_flag = 'Y'
                             AND paaf.assignment_id = p_assignment_id
                             AND ptp.payroll_id = ppa.payroll_id
                             AND ptp.regular_payment_date =
                                    ppa.effective_date
                             AND ppa.date_earned BETWEEN paaf.effective_start_date
                                                     AND paaf.effective_end_date
                             AND ppa.effective_date BETWEEN p_start_date
                                                        AND p_end_date) b,
                     (SELECT prrv.run_result_id, prrv.result_value
                        FROM apps.pay_input_values_f pivf,
                             apps.pay_run_result_values prrv
                       WHERE     pivf.input_value_id = prrv.input_value_id
                             AND prrv.result_value <> '0'
                             AND UPPER (pivf.NAME) IN ('ISR SUBJECT')) c
               WHERE a.assignment_action_id = b.assignment_action_id
                     AND a.run_result_id = c.run_result_id
              UNION
              SELECT ABS (c.result_value) result_value, a.run_result_id
                FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                             petf.element_information11, petf.element_type_id,
                             petf.reporting_name,
                             petf.element_information_category,
                             petf.element_name, 'E' ear_ded
                        FROM apps.pay_run_results prr,
                             apps.pay_element_types_f petf,
                             apps.pay_element_classifications pec
                       WHERE prr.element_type_id = petf.element_type_id
                             AND petf.classification_id =
                                    pec.classification_id
                             AND UPPER (petf.element_name) =
                                    UPPER (
                                       NVL (p_element_name,
                                            petf.element_name))
                             AND pec.classification_name LIKE '%Earning%'
                             AND petf.element_name NOT IN
                                    ('MX_ML_WORK_RISK',
                                     'MX_ML_SICKNESS',
                                     'MX_ML_MATERNITY',
                                     'MX_ML_WORK_RISK Pending',
                                     'MX_NCNS',                           --1.3
                                     'MX_NCNS Pending', --1.3
                                     'MX_SUSPENSION', --1.8
                                     'MX_NO_PAY_AUT_LEAVE', --1.8
                                     'MX_OVERPAID_SALARY', --1.8
                                     'MX_ML_SICKNESS Pending',
                                     'MX_ML_MATERNITY Pending')) a,
                     (SELECT paa.assignment_action_id, ppa.date_earned,
                             ppa.effective_date, ptp.start_date, ptp.end_date
                        FROM apps.pay_assignment_actions paa,
                             apps.pay_payroll_actions ppa,
                             --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,10/05/23
							 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,10/05/23
                             apps.per_time_periods ptp
                       WHERE ppa.payroll_action_id = paa.payroll_action_id
                             AND paa.assignment_id = paaf.assignment_id
                             AND paaf.primary_flag = 'Y'
                             AND paaf.assignment_id = p_assignment_id
                             AND ptp.payroll_id = ppa.payroll_id
                             AND ptp.regular_payment_date =
                                    ppa.effective_date
                             AND ppa.date_earned BETWEEN paaf.effective_start_date
                                                     AND paaf.effective_end_date
                             AND ppa.effective_date BETWEEN p_start_date
                                                        AND p_end_date) b,
                     (SELECT prrv.run_result_id, prrv.result_value
                        FROM apps.pay_input_values_f pivf,
                             apps.pay_run_result_values prrv
                       WHERE     pivf.input_value_id = prrv.input_value_id
                             AND prrv.result_value LIKE '%-%'
                             AND UPPER (pivf.NAME) IN ('ISR SUBJECT')) c
               WHERE a.assignment_action_id = b.assignment_action_id
                     AND a.run_result_id = c.run_result_id
              UNION	-- --1.3
                   SELECT TO_NUMBER (c.result_value) result_value, a.run_result_id
                    FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                                 petf.element_information11,
                                 petf.element_type_id, petf.reporting_name,
                                 petf.element_name,
                                 petf.element_information_category,
                                 'E' ear_ded
                            FROM apps.pay_run_results prr,
                                 apps.pay_element_types_f petf,
                                 apps.pay_element_classifications pec
                           WHERE prr.element_type_id = petf.element_type_id
                             AND petf.classification_id =
                                                         pec.classification_id
                             AND pec.classification_name LIKE '%Information%') a,
                         (SELECT paa.assignment_action_id, ppa.date_earned,
                                 ppa.effective_date, ptp.start_date,
                                 ptp.end_date
                            FROM apps.pay_assignment_actions paa,
                                 apps.pay_payroll_actions ppa,
                                 hr_lookups lo1,
                                 --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,10/05/23
								 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,10/05/23
                                 apps.per_time_periods ptp
                           WHERE ppa.payroll_action_id = paa.payroll_action_id
                             AND paa.assignment_id = paaf.assignment_id
                             AND paaf.primary_flag = 'Y'
                             AND paaf.assignment_id = p_assignment_id
                             AND paa.assignment_id = paaf.assignment_id
                             AND lo1.lookup_type = 'ACTION_TYPE'
                             AND lo1.meaning =  'Balance adjustment'
                             AND lo1.lookup_code = ppa.action_type
                             AND ptp.payroll_id = ppa.payroll_id
                             AND ptp.regular_payment_date = ppa.effective_date
                             AND ppa.date_earned
                                    BETWEEN paaf.effective_start_date
                                        AND paaf.effective_end_date
                             AND ppa.effective_date BETWEEN p_start_date
                                                        AND p_end_date) b,
                         (SELECT prrv.run_result_id, prrv.result_value
                            FROM apps.pay_input_values_f pivf,
                                 apps.pay_run_result_values prrv
                           WHERE pivf.input_value_id = prrv.input_value_id
                             AND prrv.result_value <> '0'
                             AND prrv.result_value NOT LIKE '%-%'
                             AND UPPER (pivf.NAME) IN UPPER ('Pay Value')) c
                   WHERE a.assignment_action_id = b.assignment_action_id
                     AND a.run_result_id = c.run_result_id
          UNION /* --1.4 Saving Fund*/
                   SELECT TO_NUMBER (c.result_value) result_value, a.run_result_id
                    FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                                 petf.element_information11,
                                 petf.element_type_id, petf.reporting_name,
                                 petf.element_name,
                                 petf.element_information_category,
                                 'E' ear_ded
                            FROM apps.pay_run_results prr,
                                 apps.pay_element_types_f petf,
                                 apps.pay_element_classifications pec
                           WHERE prr.element_type_id = petf.element_type_id
                             AND petf.classification_id =
                                                         pec.classification_id
                             AND pec.classification_name LIKE '%Information%'
                             AND petf.element_name = 'MX_RE_SAVING_FUNDS'  -- 1.4
                             ) a,
                         (SELECT paa.assignment_action_id, ppa.date_earned,
                                 ppa.effective_date, ptp.start_date,
                                 ptp.end_date
                            FROM apps.pay_assignment_actions paa,
                                 apps.pay_payroll_actions ppa,
--                                 hr_lookups lo1,
                                 --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,10/05/23
								 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,10/05/23
                                 apps.per_time_periods ptp
                           WHERE ppa.payroll_action_id = paa.payroll_action_id
                             AND paa.assignment_id = paaf.assignment_id
                             AND paaf.primary_flag = 'Y'
                             AND paaf.assignment_id = p_assignment_id
                             AND paa.assignment_id = paaf.assignment_id
--                             AND lo1.lookup_type = 'ACTION_TYPE'
--                             AND lo1.meaning =  'Balance adjustment'
--                             AND lo1.lookup_code = ppa.action_type
                             AND ptp.payroll_id = ppa.payroll_id
                             AND ptp.regular_payment_date = ppa.effective_date
                             AND ppa.date_earned
                                    BETWEEN paaf.effective_start_date
                                        AND paaf.effective_end_date
                             AND ppa.effective_date BETWEEN p_start_date
                                                        AND p_end_date) b,
                         (SELECT prrv.run_result_id, prrv.result_value
                            FROM apps.pay_input_values_f pivf,
                                 apps.pay_run_result_values prrv
                           WHERE pivf.input_value_id = prrv.input_value_id
                             AND prrv.result_value <> '0'
                             AND prrv.result_value NOT LIKE '%-%'
                             AND UPPER (pivf.NAME) IN UPPER ('Pay Value')) c
                   WHERE a.assignment_action_id = b.assignment_action_id
                     AND a.run_result_id = c.run_result_id);

/*              				-- 1.2 Kaushik
              SELECT ABS (c.result_value) result_value, a.run_result_id
                FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                             petf.element_information11, petf.element_type_id,
                             petf.reporting_name,
                             petf.element_information_category,
                             petf.element_name,
                             get_information (petf.element_name, p_start_date) ear_ded
                        FROM apps.pay_run_results prr,
                             apps.pay_element_types_f petf,
                             apps.pay_element_classifications pec
                       WHERE prr.element_type_id = petf.element_type_id
                             AND petf.classification_id =
                                    pec.classification_id
                             AND UPPER (petf.element_name) =
                                    UPPER (
                                       NVL (p_element_name,
                                            petf.element_name))
                             AND pec.classification_name LIKE '%Information%'
                             AND petf.element_name NOT IN
                                    ('MX_ML_WORK_RISK',
                                     'MX_ML_SICKNESS',
                                     'MX_ML_MATERNITY',
                                     'MX_ML_WORK_RISK Pending',
                                     'MX_NCNS',                           --1.3
                                     'MX_ML_SICKNESS Pending',
                                     'MX_ML_MATERNITY Pending')) a,
                     (SELECT paa.assignment_action_id, ppa.date_earned,
                             ppa.effective_date, ptp.start_date, ptp.end_date
                        FROM apps.pay_assignment_actions paa,
                             apps.pay_payroll_actions ppa,
                             hr.per_all_assignments_f paaf,
                             apps.per_time_periods ptp
                       WHERE ppa.payroll_action_id = paa.payroll_action_id
                             AND paa.assignment_id = paaf.assignment_id
                             AND paaf.primary_flag = 'Y'
                             AND paaf.assignment_id = p_assignment_id
                             AND ptp.payroll_id = ppa.payroll_id
                             AND ptp.regular_payment_date =
                                    ppa.effective_date
                             AND ppa.date_earned BETWEEN paaf.effective_start_date
                                                     AND paaf.effective_end_date
                             AND ppa.effective_date BETWEEN p_start_date
                                                        AND p_end_date) b,
                     (SELECT prrv.run_result_id, prrv.result_value
                        FROM apps.pay_input_values_f pivf,
                             apps.pay_run_result_values prrv
                       WHERE     pivf.input_value_id = prrv.input_value_id
                             AND prrv.result_value LIKE '%-%'
                             AND UPPER (pivf.NAME) IN ('ISR SUBJECT')) c
               WHERE     a.assignment_action_id = b.assignment_action_id
                     AND a.run_result_id = c.run_result_id
                     AND a.ear_ded = 'Y');
*/
      IF l_result_value <= 0 AND l_count = 1
      THEN
         l_result_value := 0;
      END IF;

      RETURN l_result_value;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         l_result_value := 0;
         RETURN l_result_value;
      WHEN OTHERS
      THEN
         l_result_value := 0;
         RETURN l_result_value;
         fnd_file.put_line (
            fnd_file.LOG,
            'Error out of get_ded_value procedure -' || SQLERRM);
   END;

   FUNCTION get_amount (p_value VARCHAR2)
      RETURN VARCHAR2
   AS
      l_value          VARCHAR2 (10) DEFAULT NULL;
      l_actual_value   VARCHAR2 (10) DEFAULT NULL;
   BEGIN
      l_value := NULL;
      l_actual_value := NULL;
      l_actual_value := ROUND (p_value, 2);

      IF SUBSTRB (l_actual_value, 1, 1) = '.'
      THEN
         l_actual_value := '0' || l_actual_value;
      ELSIF SUBSTRB (l_actual_value, 1, 2) = '-.'
      THEN
         l_actual_value := REPLACE (l_actual_value, '-', '-0');
      END IF;

      IF SUBSTR (l_actual_value,
                 INSTR (l_actual_value,
                        '.',
                        -1,
                        1),
                 1) = '.'
         AND LENGTH (SUBSTR (l_actual_value,
                             INSTR (l_actual_value,
                                    '.',
                                    -1,
                                    1))) = 3
      THEN
         l_value := l_actual_value;
      ELSIF SUBSTR (l_actual_value,
                    INSTR (l_actual_value,
                           '.',
                           -1,
                           1),
                    1) = '.'
            AND LENGTH (SUBSTR (l_actual_value,
                                INSTR (l_actual_value,
                                       '.',
                                       -1,
                                       1))) = 2
      THEN
         l_value := l_actual_value || '0';
      ELSE
         l_value := l_actual_value || '.' || '00';
      END IF;

      RETURN l_value;
   EXCEPTION
      WHEN OTHERS
      THEN
         l_value := p_value;
         RETURN l_value;
   END;

   PROCEDURE main_proc (errbuf                  OUT VARCHAR2,
                        retcode                 OUT NUMBER,
                        p_output_directory   IN     VARCHAR2,
                        p_start_date         IN     VARCHAR2,
                        p_end_date           IN     VARCHAR2,
                        p_payroll_id         IN     NUMBER,
                        p_employee_number    IN     VARCHAR2,
                        p_pay_date           IN     VARCHAR2,
                        p_profit_sharing_payout IN    VARCHAR2
                        )
   IS
      CURSOR c_emp_rec (
         p_cut_off_date        DATE,
         p_current_run_date    DATE)
      IS
           SELECT MAX (date_start) date_start,
                  MAX (NVL (actual_termination_date, p_current_run_date)) actual_termination_date,
                  person_id
             FROM per_periods_of_service ppos
            WHERE business_group_id = 1633
                  AND ( (TRUNC (ppos.last_update_date) BETWEEN p_cut_off_date
                                                           AND p_current_run_date
                         AND ppos.actual_termination_date IS NOT NULL)
                       OR (ppos.actual_termination_date IS NULL
                           AND ppos.person_id IN
                                  (SELECT DISTINCT person_id
                                     FROM per_all_people_f papf
                                    WHERE papf.current_employee_flag = 'Y'
                                      AND business_group_id = 1633  ))  --1.5
                       OR (ppos.actual_termination_date =
                              (SELECT MAX (actual_termination_date)
                                 FROM per_periods_of_service
                                WHERE person_id = ppos.person_id
                                  AND business_group_id = 1633  --1.5
                                      AND actual_termination_date IS NOT NULL)
                          -- AND ppos.actual_termination_date >= p_cut_off_date -- 1.5
                           AND ( ( p_profit_sharing_payout = 'N'
                                   AND ppos.actual_termination_date  >= p_cut_off_date)
                                OR
                                  ( p_profit_sharing_payout = 'Y'
                                    AND ppos.actual_termination_date  between to_date('01-JAN-'|| to_char(to_char(p_cut_off_date,'YYYY')- 1))
                                                                          and p_cut_off_date-- 1.5
                                  ) )
                           ))
         --AND ppos.person_id IN (468091,185110)
                  AND ppos.person_id IN  /* 1.6 */
                                  (SELECT DISTINCT papf.person_id
                                     FROM per_all_people_f papf
                                    WHERE papf.employee_number = NVL(p_employee_number,papf.employee_number)
                                    AND ppos.person_id  = papf.PERSON_ID
                                      AND business_group_id = 1633)
         GROUP BY person_id;

      CURSOR c_emp_info (
         p_person_id                  NUMBER,
         p_actual_termination_date    DATE)
      IS
           SELECT DISTINCT ftt.territory_short_name country,
                           hgre.org_information1 org_ssn,
                           paaf.assignment_number, papf.national_identifier,
                           REPLACE (papf.per_information3, '-') ssn_id,
                           paaf.assignment_id,
                           REPLACE (papf.per_information2, '-') rfc_id, -- 1.1
                           NVL (pcak_asg.segment3, pcak_org.segment3) department,
                           pcak_asg.segment2 client, papf.original_date_of_hire,
                           job.NAME job_name, fnd_asg_cat.meaning ass_cat_mean,
                           paaf.ass_attribute7 type_of_work_day,
                           papf.first_name, papf.last_name, papf.full_name,
                           paaf.employment_category, past.user_status,
                           papf.person_id, papf.employee_number,
                           hla.location_code loc_name,
                           sup.employee_number sup_employee_number,
                           job.attribute5 job_family,
                           job.attribute6 manager_level,
                           pps.actual_termination_date term_date,
                           hla.attribute2 location_code,
                           ffv_loc_hr.description location_desc,
                           tepa.clt_cd proj_assg_clt_cd,
                           tepa.client_desc proj_assg_clt_desc,
                           pcak_org.segment3 department_code,
                           ffv_dept_org.description department_desc,
                           hagre.NAME gre, paaf.payroll_id,
                           DECODE (hla.location_id,  35255, 'GDL',  1547, 'LN',  42776, 'REP') loc_abbrv,
                           DECODE (paaf.payroll_id,  420, 2101,  421, 6902) employer_acc,
                           pad.postal_code
             /*
START R12.2 Upgrade Remediation
code commented by RXNETHI-ARGANO,10/05/23
FROM hr.per_all_people_f papf,
                  hr.per_all_assignments_f paaf,
                  hr.per_all_people_f sup,
                  apps.per_addresses pad,
                  apps.per_business_groups pbg,
                  hr.hr_locations_all hla,
                  hr.pay_cost_allocations_f pcaf,
                  hr.pay_cost_allocation_keyflex pcak_org,
                  hr.pay_cost_allocation_keyflex pcak_asg,
                  hr.hr_all_organization_units haou,
                  hr.hr_soft_coding_keyflex hsck,
                  hr.hr_all_organization_units hagre,
                  hr.hr_organization_information hgre,
                  hr.per_jobs job,
                  hr.per_pay_bases ppb,
                  hr.hr_organization_information horginfo,
                  per_periods_of_service pps,
                  apps.fnd_currencies_vl fcv,
                  hr.per_pay_proposals ppp,
                  apps.fnd_flex_values_vl ffv_client,
                  apps.fnd_flex_values_vl ffv_dept_org,
                  apps.fnd_flex_values_vl ffv_dept,
                  apps.fnd_flex_values_vl ffv_loc_cost,
                  apps.fnd_flex_values_vl ffv_loc_hr,
                  apps.fnd_lookup_values fnd_asg_cat,
                  applsys.fnd_territories_tl ftt,
                  hr.per_assignment_status_types past,
                  cust.ttec_emp_proj_asg tepa,
                  pay_input_values_f piv,
                  pay_element_types_f pet,
                  apps.fnd_user fu,
                  apps.per_all_people_f papfcost*/
--code added by RXNETHI-ARGANO,10/05/23
             FROM apps.per_all_people_f papf,
                  apps.per_all_assignments_f paaf,
                  apps.per_all_people_f sup,
                  apps.per_addresses pad,
                  apps.per_business_groups pbg,
                  apps.hr_locations_all hla,
                  apps.pay_cost_allocations_f pcaf,
                  apps.pay_cost_allocation_keyflex pcak_org,
                  apps.pay_cost_allocation_keyflex pcak_asg,
                  apps.hr_all_organization_units haou,
                  apps.hr_soft_coding_keyflex hsck,
                  apps.hr_all_organization_units hagre,
                  apps.hr_organization_information hgre,
                  apps.per_jobs job,
                  apps.per_pay_bases ppb,
                  apps.hr_organization_information horginfo,
                  per_periods_of_service pps,
                  apps.fnd_currencies_vl fcv,
                  apps.per_pay_proposals ppp,
                  apps.fnd_flex_values_vl ffv_client,
                  apps.fnd_flex_values_vl ffv_dept_org,
                  apps.fnd_flex_values_vl ffv_dept,
                  apps.fnd_flex_values_vl ffv_loc_cost,
                  apps.fnd_flex_values_vl ffv_loc_hr,
                  apps.fnd_lookup_values fnd_asg_cat,
                  apps.fnd_territories_tl ftt,
                  apps.per_assignment_status_types past,
                  apps.ttec_emp_proj_asg tepa,
                  pay_input_values_f piv,
                  pay_element_types_f pet,
                  apps.fnd_user fu,
                  apps.per_all_people_f papfcost
--END R12.2 Upgrade Remediation
            WHERE papf.business_group_id <> 0
                  AND p_actual_termination_date BETWEEN papf.effective_start_date
                                                    AND papf.effective_end_date
                  AND pbg.business_group_id = papf.business_group_id
                  AND papf.person_id = paaf.person_id
                  AND papf.person_id = pad.person_id(+)
                  AND pad.primary_flag(+) = 'Y'
                  AND papf.current_employee_flag = 'Y'
                  AND paaf.assignment_type = 'E'
                  AND paaf.primary_flag = 'Y'
                  AND papf.person_id = p_person_id
                  AND papf.employee_number =
                         NVL (p_employee_number, papf.employee_number)
                  AND paaf.payroll_id = NVL (p_payroll_id, paaf.payroll_id)
                  AND p_actual_termination_date BETWEEN paaf.effective_start_date
                                                    AND paaf.effective_end_date
                  AND paaf.location_id = hla.location_id(+)
                  AND paaf.job_id = job.job_id(+)
                  AND paaf.pay_basis_id = ppb.pay_basis_id(+)
                  AND ppb.input_value_id = piv.input_value_id(+)
                  AND piv.element_type_id = pet.element_type_id(+)
                  AND p_actual_termination_date BETWEEN pet.effective_start_date
                                                    AND pet.effective_end_date
                  AND p_actual_termination_date BETWEEN piv.effective_start_date
                                                    AND piv.effective_end_date
                  AND paaf.assignment_id = ppp.assignment_id(+)
                  AND p_actual_termination_date BETWEEN ppp.change_date(+)
                                                    AND NVL (
                                                           ppp.date_to(+),
                                                           TO_DATE (
                                                              '31-DEC-4712',
                                                              'DD-MON-YYYY'))
                  AND paaf.assignment_id = pcaf.assignment_id(+)
                  AND paaf.organization_id = haou.organization_id(+)
                  AND paaf.soft_coding_keyflex_id =
                         hsck.soft_coding_keyflex_id(+)
                  AND hsck.segment1 = hagre.organization_id(+)
                  AND hagre.organization_id = hgre.organization_id(+)
                  AND hgre.org_information_context(+) = 'MX_SOC_SEC_DETAILS'
                  AND p_actual_termination_date BETWEEN pcaf.effective_start_date(+)
                                                    AND pcaf.effective_end_date(+)
                  AND pps.person_id = papf.person_id
                  AND pps.period_of_service_id = paaf.period_of_service_id
                  AND paaf.supervisor_id = sup.person_id(+)
                  AND p_actual_termination_date BETWEEN sup.effective_start_date(+)
                                                    AND sup.effective_end_date(+)
                  AND haou.cost_allocation_keyflex_id =
                         pcak_org.cost_allocation_keyflex_id(+)
                  AND pcaf.cost_allocation_keyflex_id =
                         pcak_asg.cost_allocation_keyflex_id(+)
                  AND ffv_client.flex_value_meaning(+) = pcak_asg.segment2
                  AND ffv_client.flex_value_set_id(+) = '1002611'
                  AND pcak_org.segment3 = ffv_dept_org.flex_value(+)
                  AND ffv_dept_org.flex_value_set_id(+) = '1002612'
                  AND pcak_asg.segment3 = ffv_dept.flex_value(+)
                  AND ffv_dept.flex_value_set_id(+) = '1002612'
                  AND hla.attribute2 = ffv_loc_hr.flex_value(+)
                  AND ffv_loc_hr.flex_value_set_id(+) = '1002610'
                  AND pcak_asg.segment1 = ffv_loc_cost.flex_value(+)
                  AND ffv_loc_cost.flex_value_set_id(+) = '1002610'
                  AND papf.business_group_id = horginfo.organization_id(+)
                  AND horginfo.org_information_context(+) =
                         'Business Group Information'
                  AND fcv.currency_code(+) = horginfo.org_information10
                  AND fnd_asg_cat.lookup_code(+) = paaf.employment_category
                  AND fnd_asg_cat.lookup_type(+) = 'EMP_CAT'
                  AND fnd_asg_cat.LANGUAGE(+) = 'US'
                  AND fnd_asg_cat.security_group_id(+) = 25
                  AND ftt.territory_code(+) = hla.country
                  AND ftt.LANGUAGE(+) = USERENV ('LANG')
                  AND papf.business_group_id = 1633
                  AND paaf.assignment_status_type_id =
                         past.assignment_status_type_id(+)
                  AND tepa.person_id(+) = papf.person_id
                  AND p_actual_termination_date BETWEEN tepa.prj_strt_dt(+)
                                                    AND tepa.prj_end_dt(+)
                  AND pcaf.last_updated_by = fu.user_id
                  AND fu.employee_id = papfcost.person_id(+)
                  AND p_actual_termination_date BETWEEN pad.date_from(+)
                                                    AND NVL (
                                                           pad.date_to(+),
                                                           TO_DATE (
                                                              '31-DEC-4712',
                                                              'DD-MON-YYYY'))
                  AND p_actual_termination_date BETWEEN papfcost.effective_start_date(+)
                                                    AND papfcost.effective_end_date(+)
         ORDER BY 1, 2;

      CURSOR c_ded_element (
         p_assignment_id    NUMBER,
         p_start_date       DATE,
         p_end_date         DATE,
         p_class_name       VARCHAR2)
      IS
         SELECT DISTINCT
                b.effective_date,
                b.start_date,
                b.end_date,
                LPAD (NVL (a.element_information11,
                           get_sat_code (a.element_name,
                                         a.element_information_category,
                                         a.element_information11,
                                         p_start_date)),
                      3,
                      '0')
                   sat_code,
                a.element_type_id,
                NVL (get_rep_name (a.element_name, p_start_date),
                     a.reporting_name)
                   reporting_name,
                a.element_name,
                a.ear_ded,
                get_amount (ABS (TO_NUMBER (c.result_value))) ele_amt,
                NULL run_result_id
           FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                        petf.element_information11, petf.element_type_id,
                        petf.reporting_name, petf.element_name, 'D' ear_ded,
                        petf.element_information_category
                   FROM apps.pay_run_results prr,
                        apps.pay_element_types_f petf,
                        apps.pay_element_classifications pec
                  WHERE prr.element_type_id = petf.element_type_id
                        AND petf.classification_id = pec.classification_id
                        AND pec.classification_name LIKE
                               '%' || p_class_name || '%') a,
                (SELECT paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,10/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,10/05/23
                        apps.per_time_periods ptp
                  WHERE     ppa.payroll_action_id = paa.payroll_action_id
                        AND paa.assignment_id = paaf.assignment_id
                        AND paaf.primary_flag = 'Y'
                        AND paaf.assignment_id = p_assignment_id
                        AND ptp.payroll_id = ppa.payroll_id
                        AND ptp.regular_payment_date = ppa.effective_date
                        AND ppa.date_earned BETWEEN paaf.effective_start_date
                                                AND paaf.effective_end_date
                        AND ppa.effective_date BETWEEN p_start_date
                                                   AND p_end_date) b,
                (SELECT prrv.run_result_id, prrv.result_value
                   FROM apps.pay_input_values_f pivf,
                        apps.pay_run_result_values prrv
                  WHERE     pivf.input_value_id = prrv.input_value_id
                        AND prrv.result_value <> '0'
                        AND prrv.result_value NOT LIKE '%-%'
                        AND pivf.NAME IN ('Pay Value')) c
          WHERE a.assignment_action_id = b.assignment_action_id
                AND a.run_result_id = c.run_result_id
         UNION
         SELECT DISTINCT
                b.effective_date,
                b.start_date,
                b.end_date,
                LPAD (NVL (a.element_information11,
                           get_sat_code (a.element_name,
                                         a.element_information_category,
                                         a.element_information11,
                                         p_start_date)),
                      3,
                      '0')
                   sat_code,
                a.element_type_id,
                NVL (get_rep_name (a.element_name, p_start_date),
                     a.reporting_name)
                   reporting_name,
                a.element_name,
                a.ear_ded,
                get_amount (TO_NUMBER (c.result_value)) ele_amt,
                NULL run_result_id
           FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                        petf.element_information11, petf.element_type_id,
                        petf.reporting_name, petf.element_name, 'D' ear_ded,
                        petf.element_information_category
                   FROM apps.pay_run_results prr,
                        apps.pay_element_types_f petf,
                        apps.pay_element_classifications pec
                  WHERE prr.element_type_id = petf.element_type_id
                        AND petf.classification_id = pec.classification_id
                        AND pec.classification_name LIKE
                               '%' || p_class_name || '%'
                        AND petf.element_name = 'ISR') a,
                (SELECT paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,10/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,10/05/23
                        apps.per_time_periods ptp
                  WHERE     ppa.payroll_action_id = paa.payroll_action_id
                        AND paa.assignment_id = paaf.assignment_id
                        AND paaf.primary_flag = 'Y'
                        AND paaf.assignment_id = p_assignment_id
                        AND ptp.payroll_id = ppa.payroll_id
                        AND ptp.regular_payment_date = ppa.effective_date
                        AND ppa.date_earned BETWEEN paaf.effective_start_date
                                                AND paaf.effective_end_date
                        AND ppa.effective_date BETWEEN p_start_date
                                                   AND p_end_date) b,
                (SELECT prrv.run_result_id, prrv.result_value
                   FROM apps.pay_input_values_f pivf,
                        apps.pay_run_result_values prrv
                  WHERE     pivf.input_value_id = prrv.input_value_id
                        AND prrv.result_value <> '0'
                        AND prrv.result_value LIKE '%-%'
                        AND pivf.NAME IN ('Pay Value')) c
          WHERE a.assignment_action_id = b.assignment_action_id
                AND a.run_result_id = c.run_result_id
         UNION
         SELECT DISTINCT b.effective_date, b.start_date, b.end_date,
                         LPAD (SUBSTRB (a.meaning, 1, INSTR (a.meaning, '-') - 2), 3, '0') sat_code,
                         a.element_type_id, a.reporting_name, a.element_name,
                         a.ear_ded,
                         get_amount (ABS (TO_NUMBER (c.result_value))) ele_amt,
                         a.run_result_id
           FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                        petf.element_information11, petf.element_type_id,
                        petf.reporting_name, petf.element_name, 'E' ear_ded,
                        petf.element_information_category, flv.meaning
                   FROM apps.pay_run_results prr,
                        apps.pay_element_types_f petf,
                        apps.pay_element_classifications pec,
                        apps.fnd_lookup_values flv
                  WHERE     prr.element_type_id = petf.element_type_id
                        AND petf.classification_id = pec.classification_id
                        AND pec.classification_name LIKE '%Earning%'
                        AND flv.LANGUAGE = 'US'
                        AND flv.lookup_code = petf.element_information11
                        AND flv.lookup_type =
                               DECODE (
                                  petf.element_information_category,
                                  'MX_SUPPLEMENTAL EARNINGS', 'MX_PAYSLIP_EARNING_CODES',
                                  'MX_IMPUTED EARNINGS', 'MX_PAYSLIP_EARNING_CODES',
                                  'MX_EARNINGS', 'MX_PAYSLIP_EARNING_CODES')
                        AND petf.element_name IN
                               ('MX_ML_WORK_RISK',
                                'MX_ML_SICKNESS',
                                'MX_ML_MATERNITY',
                                'MX_NCNS',                                --1.3
                                'MX_NCNS Pending', --1.3
                                'MX_SUSPENSION', --1.8
                                'MX_NO_PAY_AUT_LEAVE', --1.8
                                'MX_OVERPAID_SALARY', --1.8
                                'MX_ML_WORK_RISK Pending',
                                'MX_ML_SICKNESS Pending',
                                'MX_ML_MATERNITY Pending')) a,
                (SELECT paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,10/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,10/05/23
                        apps.per_time_periods ptp
                  WHERE     ppa.payroll_action_id = paa.payroll_action_id
                        AND paa.assignment_id = paaf.assignment_id
                        AND paaf.primary_flag = 'Y'
                        AND paaf.assignment_id = p_assignment_id
                        AND ptp.payroll_id = ppa.payroll_id
                        AND ptp.regular_payment_date = ppa.effective_date
                        AND ppa.date_earned BETWEEN paaf.effective_start_date
                                                AND paaf.effective_end_date
                        AND ppa.effective_date BETWEEN p_start_date
                                                   AND p_end_date) b,
                (SELECT prrv.run_result_id, prrv.result_value
                   FROM apps.pay_input_values_f pivf,
                        apps.pay_run_result_values prrv
                  WHERE     pivf.input_value_id = prrv.input_value_id
                        AND prrv.result_value <> '0'
                        AND UPPER (pivf.NAME) IN ('ISR SUBJECT')) c
          WHERE a.assignment_action_id = b.assignment_action_id
                AND a.run_result_id = c.run_result_id
         UNION
         SELECT DISTINCT
                b.effective_date,
                b.start_date,
                b.end_date,
                LPAD (get_cntr_code ('Perception Counterpart',
                                     a.element_information11,
                                     a.element_name,
                                     p_start_date),
                      3,
                      0)
                   sat_code,
                a.element_type_id,
                get_cntr_name ('Perception Counterpart',
                               a.element_information11,
                               a.element_name,
                               p_start_date)
                   reporting_name,
                a.element_name,
                a.ear_ded,
                get_amount (ABS (TO_NUMBER (c.result_value))) ele_amt,
                a.run_result_id
           FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                        petf.element_information11, petf.element_type_id,
                        petf.reporting_name,
                        petf.element_information_category, petf.element_name,
                        'E' ear_ded
                   FROM apps.pay_run_results prr,
                        apps.pay_element_types_f petf,
                        apps.pay_element_classifications pec
                  WHERE     prr.element_type_id = petf.element_type_id
                        AND petf.classification_id = pec.classification_id
                        AND pec.classification_name LIKE '%Earning%'
                        AND petf.element_name NOT IN
                               ('MX_ML_WORK_RISK',
                                'MX_ML_SICKNESS',
                                'MX_ML_MATERNITY',
                                'MX_NCNS',                                --1.3
                                'MX_NCNS Pending', --1.3
                                'MX_SUSPENSION', --1.8
                                'MX_NO_PAY_AUT_LEAVE', --1.8
                                'MX_OVERPAID_SALARY', --1.8
                                'MX_ML_WORK_RISK Pending',
                                'MX_ML_SICKNESS Pending',
                                'MX_ML_MATERNITY Pending')) a,
                (SELECT paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,10/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,10/05/23
                        apps.per_time_periods ptp
                  WHERE     ppa.payroll_action_id = paa.payroll_action_id
                        AND paa.assignment_id = paaf.assignment_id
                        AND paaf.primary_flag = 'Y'
                        AND paaf.assignment_id = p_assignment_id
                        AND ptp.payroll_id = ppa.payroll_id
                        AND ptp.regular_payment_date = ppa.effective_date
                        AND ppa.date_earned BETWEEN paaf.effective_start_date
                                                AND paaf.effective_end_date
                        AND ppa.effective_date BETWEEN p_start_date
                                                   AND p_end_date) b,
                (SELECT prrv.run_result_id, prrv.result_value
                   FROM apps.pay_input_values_f pivf,
                        apps.pay_run_result_values prrv
                  WHERE     pivf.input_value_id = prrv.input_value_id
                        AND prrv.result_value LIKE '%-%'
                        AND prrv.result_value <> '0'
                        AND UPPER (pivf.NAME) IN ('ISR SUBJECT')) c
          WHERE a.assignment_action_id = b.assignment_action_id
                AND a.run_result_id = c.run_result_id
          UNION /* --1.3 */
                   SELECT DISTINCT b.effective_date, b.start_date, b.end_date,
                         LPAD
                            (NVL
                                (a.element_information11,
                                 get_sat_code (a.element_name,
                                               a.element_information_category,
                                               a.element_information11,
                                               p_start_date
                                              )
                                ),
                             3,
                             '0'
                            ) sat_code,
                         a.element_type_id,
                         NVL (get_information (a.element_name, p_start_date),
                              a.reporting_name
                             ) reporting_name,
                         a.element_name, a.ear_ded,
                         get_amount (get_value (a.element_name,
                                                'Information',
                                                'Pay Value',
                                                p_assignment_id,
                                                p_start_date,
                                                p_end_date
                                               )
                                    ) ele_amt,
--                         get_amount (get_value (a.element_name,
--                                                NULL,
--                                                'ISR Exempt',
--                                                p_assignment_id,
--                                                p_start_date,
--                                                p_end_date
--                                               )
--                                    ) exempt_amt,
                         NULL run_result_id
                    FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                                 petf.element_information11,
                                 petf.element_type_id, petf.reporting_name,
                                 petf.element_name,
                                 petf.element_information_category,
                                 'E' ear_ded
                            FROM apps.pay_run_results prr,
                                 apps.pay_element_types_f petf,
                                 apps.pay_element_classifications pec
                           WHERE prr.element_type_id = petf.element_type_id
                             AND petf.classification_id =
                                                         pec.classification_id
                             AND pec.classification_name LIKE '%Information%') a,
                         (SELECT paa.assignment_action_id, ppa.date_earned,
                                 ppa.effective_date, ptp.start_date,
                                 ptp.end_date
                            FROM apps.pay_assignment_actions paa,
                                 apps.pay_payroll_actions ppa,
                                 hr_lookups lo1,
                                 --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,10/05/23
								 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,10/05/23
                                 apps.per_time_periods ptp
                           WHERE ppa.payroll_action_id = paa.payroll_action_id
                             AND paa.assignment_id = paaf.assignment_id
                             AND paaf.primary_flag = 'Y'
                             AND paaf.assignment_id = p_assignment_id
                             AND paa.assignment_id = paaf.assignment_id
                             AND lo1.lookup_type = 'ACTION_TYPE'
                             AND lo1.meaning =  'Balance adjustment'
                             AND lo1.lookup_code = ppa.action_type
                             AND ptp.payroll_id = ppa.payroll_id
                             AND ptp.regular_payment_date = ppa.effective_date
                             AND ppa.date_earned
                                    BETWEEN paaf.effective_start_date
                                        AND paaf.effective_end_date
                             AND ppa.effective_date BETWEEN p_start_date
                                                        AND p_end_date) b,
                         (SELECT prrv.run_result_id, prrv.result_value
                            FROM apps.pay_input_values_f pivf,
                                 apps.pay_run_result_values prrv
                           WHERE pivf.input_value_id = prrv.input_value_id
                             AND prrv.result_value <> '0'
                             AND prrv.result_value NOT LIKE '%-%'
                             AND UPPER (pivf.NAME) IN UPPER ('Pay Value')) c
                   WHERE a.assignment_action_id = b.assignment_action_id
                     AND a.run_result_id = c.run_result_id
              UNION --1.4 Saving Fund
                  SELECT DISTINCT b.effective_date, b.start_date, b.end_date,
--                         LPAD
--                            (NVL
--                                (a.element_information11,
--                                 get_sat_code (a.element_name,
--                                               a.element_information_category,
--                                               a.element_information11,
--                                               p_start_date
--                                              )
--                                ),
--                             3,
--                             '0'
--                            ) sat_code,
                LPAD (get_cntr_code ('Deduction Counterpart',
                                     a.element_information11,
                                     a.element_name,
                                     p_start_date),
                      3,
                      0)
                   sat_code,
                         a.element_type_id,
                         NVL (get_information (a.element_name, p_start_date),
                              a.reporting_name
                             ) reporting_name,
                         a.element_name, a.ear_ded,
                         get_amount (get_value (a.element_name,
                                                'Information',
                                                'Pay Value',
                                                p_assignment_id,
                                                p_start_date,
                                                p_end_date
                                               )
                                    ) ele_amt,
--                         get_amount (get_value (a.element_name,
--                                                NULL,
--                                                'ISR Exempt',
--                                                p_assignment_id,
--                                                p_start_date,
--                                                p_end_date
--                                               )
--                                    ) exempt_amt,
                         NULL run_result_id
                    FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                                 petf.element_information11,
                                 petf.element_type_id, petf.reporting_name,
                                 petf.element_name,
                                 petf.element_information_category,
                                 'E' ear_ded
                            FROM apps.pay_run_results prr,
                                 apps.pay_element_types_f petf,
                                 apps.pay_element_classifications pec
                           WHERE prr.element_type_id = petf.element_type_id
                             AND petf.classification_id =
                                                         pec.classification_id
                             AND pec.classification_name LIKE '%Information%'
                             AND petf.element_name = 'MX_RE_SAVING_FUNDS'  -- 1.4
                             ) a,
                         (SELECT paa.assignment_action_id, ppa.date_earned,
                                 ppa.effective_date, ptp.start_date,
                                 ptp.end_date
                            FROM apps.pay_assignment_actions paa,
                                 apps.pay_payroll_actions ppa,
--                                 hr_lookups lo1,
                                 --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,10/05/23
								 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,10/05/23
                                 apps.per_time_periods ptp
                           WHERE ppa.payroll_action_id = paa.payroll_action_id
                             AND paa.assignment_id = paaf.assignment_id
                             AND paaf.primary_flag = 'Y'
                             AND paaf.assignment_id = p_assignment_id
                             AND paa.assignment_id = paaf.assignment_id
--                             AND lo1.lookup_type = 'ACTION_TYPE'
--                             AND lo1.meaning =  'Balance adjustment'
--                             AND lo1.lookup_code = ppa.action_type
                             AND ptp.payroll_id = ppa.payroll_id
                             AND ptp.regular_payment_date = ppa.effective_date
                             AND ppa.date_earned
                                    BETWEEN paaf.effective_start_date
                                        AND paaf.effective_end_date
                             AND ppa.effective_date BETWEEN p_start_date
                                                        AND p_end_date) b,
                         (SELECT prrv.run_result_id, prrv.result_value
                            FROM apps.pay_input_values_f pivf,
                                 apps.pay_run_result_values prrv
                           WHERE pivf.input_value_id = prrv.input_value_id
                             AND prrv.result_value <> '0'
                             AND prrv.result_value NOT LIKE '%-%'
                             AND UPPER (pivf.NAME) IN UPPER ('Pay Value')) c
                   WHERE a.assignment_action_id = b.assignment_action_id
                     AND a.run_result_id = c.run_result_id;
/*
         UNION		-- 1.2 Kaushik
         SELECT DISTINCT
                b.effective_date,
                b.start_date,
                b.end_date,
                LPAD (get_cntr_code ('Perception Counterpart',
                                     a.element_information11,
                                     a.element_name,
                                     p_start_date),
                      3,
                      0)
                   sat_code,
                a.element_type_id,
                get_cntr_name ('Perception Counterpart',
                               a.element_information11,
                               a.element_name,
                               p_start_date)
                   reporting_name,
                a.element_name,
                a.ear_ded,
                get_amount (ABS (TO_NUMBER (c.result_value))) ele_amt,
                a.run_result_id
           FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                        petf.element_information11, petf.element_type_id,
                        petf.reporting_name,
                        petf.element_information_category, petf.element_name,
                        get_information (petf.element_name, p_start_date) ear_ded
                   FROM apps.pay_run_results prr,
                        apps.pay_element_types_f petf,
                        apps.pay_element_classifications pec
                  WHERE     prr.element_type_id = petf.element_type_id
                        AND petf.classification_id = pec.classification_id
                        AND pec.classification_name LIKE '%Information%'
                        AND petf.element_name NOT IN
                               ('MX_ML_WORK_RISK',
                                'MX_ML_SICKNESS',
                                'MX_ML_MATERNITY',
                                'MX_NCNS',                                --1.3
                                'MX_ML_WORK_RISK Pending',
                                'MX_ML_SICKNESS Pending',
                                'MX_ML_MATERNITY Pending')) a,
                (SELECT paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        hr.per_all_assignments_f paaf,
                        apps.per_time_periods ptp
                  WHERE     ppa.payroll_action_id = paa.payroll_action_id
                        AND paa.assignment_id = paaf.assignment_id
                        AND paaf.primary_flag = 'Y'
                        AND paaf.assignment_id = p_assignment_id
                        AND ptp.payroll_id = ppa.payroll_id
                        AND ptp.regular_payment_date = ppa.effective_date
                        AND ppa.date_earned BETWEEN paaf.effective_start_date
                                                AND paaf.effective_end_date
                        AND ppa.effective_date BETWEEN p_start_date
                                                   AND p_end_date) b,
                (SELECT prrv.run_result_id, prrv.result_value
                   FROM apps.pay_input_values_f pivf,
                        apps.pay_run_result_values prrv
                  WHERE     pivf.input_value_id = prrv.input_value_id
                        AND prrv.result_value LIKE '%-%'
                        AND prrv.result_value <> '0'
                        AND UPPER (pivf.NAME) IN ('ISR SUBJECT')) c
          WHERE     a.assignment_action_id = b.assignment_action_id
                AND a.run_result_id = c.run_result_id
                AND a.ear_ded = 'Y';
*/
      CURSOR c_emp_element (
         p_assignment_id    NUMBER,
         p_start_date       DATE,
         p_end_date         DATE,
         p_class_name       VARCHAR2)
      IS
         SELECT DISTINCT
                b.effective_date,
                b.start_date,
                b.end_date,
                LPAD (get_sat_code (a.element_name,
                                    a.element_information_category,
                                    a.element_information11,
                                    p_start_date),
                      3,
                      '0')
                   sat_code,
                a.element_type_id,
                NVL (get_rep_name (a.element_name, p_start_date),
                     a.reporting_name)
                   reporting_name,
                a.element_name,
                a.ear_ded,
                get_amount (get_value (a.element_name,
                                       'Earning',
                                       'ISR Subject',
                                       p_assignment_id,
                                       p_start_date,
                                       p_end_date))
                   ele_amt,
                get_amount (get_value (a.element_name,
                                       NULL,
                                       'ISR Exempt',
                                       p_assignment_id,
                                       p_start_date,
                                       p_end_date))
                   exempt_amt,
                NULL run_result_id
           FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                        petf.element_information11, petf.element_type_id,
                        petf.reporting_name, petf.element_name,
                        petf.element_information_category, 'E' ear_ded
                   FROM apps.pay_run_results prr,
                        apps.pay_element_types_f petf,
                        apps.pay_element_classifications pec
                  WHERE prr.element_type_id = petf.element_type_id
                        AND petf.classification_id = pec.classification_id
                        AND pec.classification_name LIKE
                               '%' || p_class_name || '%'
                        AND petf.element_name NOT IN
                               ('MX_ML_WORK_RISK',
                                'MX_ML_SICKNESS',
                                'MX_ML_MATERNITY',
                                'MX_NCNS',                                --1.3
                                'MX_NCNS Pending', --1.3
                                'MX_SUSPENSION', --1.9
                                'MX_NO_PAY_AUT_LEAVE', --1.9
                                'MX_OVERPAID_SALARY', --1.9
                                'MX_ML_WORK_RISK Pending',
                                'MX_ML_SICKNESS Pending',
                                'MX_ML_MATERNITY Pending')) a,
                (SELECT paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,10/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,10/05/23
                        apps.per_time_periods ptp
                  WHERE     ppa.payroll_action_id = paa.payroll_action_id
                        AND paa.assignment_id = paaf.assignment_id
                        AND paaf.primary_flag = 'Y'
                        AND paaf.assignment_id = p_assignment_id
                        AND ptp.payroll_id = ppa.payroll_id
                        AND ptp.regular_payment_date = ppa.effective_date
                        AND ppa.date_earned BETWEEN paaf.effective_start_date
                                                AND paaf.effective_end_date
                        AND ppa.effective_date BETWEEN p_start_date
                                                   AND p_end_date) b,
                (SELECT prrv.run_result_id, prrv.result_value
                   FROM apps.pay_input_values_f pivf,
                        apps.pay_run_result_values prrv
                  WHERE     pivf.input_value_id = prrv.input_value_id
                        AND prrv.result_value <> '0'
                        AND prrv.result_value NOT LIKE '%-%'
                        AND UPPER (pivf.NAME) IN UPPER ('Pay Value')) c
          WHERE a.assignment_action_id = b.assignment_action_id
                AND a.run_result_id = c.run_result_id
         UNION
         SELECT DISTINCT
                b.effective_date,
                b.start_date,
                b.end_date,
                LPAD (NVL (a.element_information11,
                           get_sat_code (a.element_name,
                                         a.element_information_category,
                                         a.element_information11,
                                         p_start_date)),
                      3,
                      '0')
                   sat_code,
                a.element_type_id,
                NVL (get_rep_name (a.element_name, p_start_date),
                     a.reporting_name)
                   reporting_name,
                a.element_name,
                a.ear_ded,
                get_amount (get_value (a.element_name,
                                       'Amends',
                                       'ISR Subject',
                                       p_assignment_id,
                                       p_start_date,
                                       p_end_date))
                   ele_amt,
                get_amount (get_value (a.element_name,
                                       NULL,
                                       'ISR Exempt',
                                       p_assignment_id,
                                       p_start_date,
                                       p_end_date))
                   exempt_amt,
                NULL run_result_id
           FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                        petf.element_information11, petf.element_type_id,
                        petf.reporting_name, petf.element_name,
                        petf.element_information_category, 'E' ear_ded
                   FROM apps.pay_run_results prr,
                        apps.pay_element_types_f petf,
                        apps.pay_element_classifications pec
                  WHERE     prr.element_type_id = petf.element_type_id
                        AND petf.classification_id = pec.classification_id
                        AND pec.classification_name LIKE '%Amends%') a,
                (SELECT paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,10/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,10/05/23
                        apps.per_time_periods ptp
                  WHERE     ppa.payroll_action_id = paa.payroll_action_id
                        AND paa.assignment_id = paaf.assignment_id
                        AND paaf.primary_flag = 'Y'
                        AND paaf.assignment_id = p_assignment_id
                        AND ptp.payroll_id = ppa.payroll_id
                        AND ptp.regular_payment_date = ppa.effective_date
                        AND ppa.date_earned BETWEEN paaf.effective_start_date
                                                AND paaf.effective_end_date
                        AND ppa.effective_date BETWEEN p_start_date
                                                   AND p_end_date) b,
                (SELECT prrv.run_result_id, prrv.result_value
                   FROM apps.pay_input_values_f pivf,
                        apps.pay_run_result_values prrv
                  WHERE     pivf.input_value_id = prrv.input_value_id
                        AND prrv.result_value <> '0'
                        AND prrv.result_value NOT LIKE '%-%'
                        AND UPPER (pivf.NAME) IN UPPER ('Pay Value')) c
          WHERE a.assignment_action_id = b.assignment_action_id
                AND a.run_result_id = c.run_result_id
         UNION
         SELECT DISTINCT
                b.effective_date,
                b.start_date,
                b.end_date,
                LPAD (NVL (a.element_information11,
                           get_sat_code (a.element_name,
                                         a.element_information_category,
                                         a.element_information11,
                                         p_start_date)),
                      3,
                      '0')
                   sat_code,
                a.element_type_id,
                NVL (get_rep_name (a.element_name, p_start_date),
                     a.reporting_name)
                   reporting_name,
                a.element_name,
                a.ear_ded,
                get_amount (TO_NUMBER (c.result_value)) ele_amt,
                get_amount (get_value (a.element_name,
                                       NULL,
                                       'ISR Exempt',
                                       p_assignment_id,
                                       p_start_date,
                                       p_end_date))
                   exempt_amt,
                a.run_result_id
           FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                        petf.element_information11, petf.element_type_id,
                        petf.reporting_name, petf.element_name, 'E' ear_ded,
                        petf.element_information_category
                   FROM apps.pay_run_results prr,
                        apps.pay_element_types_f petf,
                        apps.pay_element_classifications pec
                  WHERE     prr.element_type_id = petf.element_type_id
                        AND petf.classification_id = pec.classification_id
                        AND pec.classification_name IN ('Tax Credit')) a,
                (SELECT paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,10/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,10/05/23
                        apps.per_time_periods ptp
                  WHERE     ppa.payroll_action_id = paa.payroll_action_id
                        AND paa.assignment_id = paaf.assignment_id
                        AND paaf.primary_flag = 'Y'
                        AND paaf.assignment_id = p_assignment_id
                        AND ptp.payroll_id = ppa.payroll_id
                        AND ptp.regular_payment_date = ppa.effective_date
                        AND ppa.date_earned BETWEEN paaf.effective_start_date
                                                AND paaf.effective_end_date
                        AND ppa.effective_date BETWEEN p_start_date
                                                   AND p_end_date) b,
                (SELECT prrv.run_result_id, prrv.result_value
                   FROM apps.pay_input_values_f pivf,
                        apps.pay_run_result_values prrv
                  WHERE     pivf.input_value_id = prrv.input_value_id
                        AND prrv.result_value <> '0'
                        --AND prrv.result_value NOT LIKE '%-%'
                        AND pivf.NAME IN ('Pay Value')) c
          WHERE a.assignment_action_id = b.assignment_action_id
                AND a.run_result_id = c.run_result_id
         UNION
         SELECT DISTINCT
                b.effective_date,
                b.start_date,
                b.end_date,
                LPAD (NVL (a.element_information11,
                           get_sat_code (a.element_name,
                                         a.element_information_category,
                                         a.element_information11,
                                         p_start_date)),
                      3,
                      '0')
                   sat_code,
                a.element_type_id,
                NVL (get_rep_name (a.element_name, p_start_date),
                     a.reporting_name)
                   reporting_name,
                a.element_name,
                a.ear_ded,
                '0.00' ele_amt,
                get_amount (ABS (TO_NUMBER (c.result_value))) exempt_amt,
                a.run_result_id
           FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                        petf.element_information11, petf.element_type_id,
                        petf.reporting_name, petf.element_name, 'E' ear_ded,
                        petf.element_information_category
                   FROM apps.pay_run_results prr,
                        apps.pay_element_types_f petf,
                        apps.pay_element_classifications pec
                  WHERE prr.element_type_id = petf.element_type_id
                        AND petf.classification_id = pec.classification_id
                        AND pec.classification_name IN
                               ('Non-payroll Payments')
                        AND petf.element_name NOT IN  -- 1.4
                               ('MX_SF_COMPANY_LIQ',  -- 1.4
                                'MX_SF_LIQUIDATION')  -- 1.4
                               ) a,
                (SELECT paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,10/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,10/05/23
                        apps.per_time_periods ptp
                  WHERE     ppa.payroll_action_id = paa.payroll_action_id
                        AND paa.assignment_id = paaf.assignment_id
                        AND paaf.primary_flag = 'Y'
                        AND paaf.assignment_id = p_assignment_id
                        AND ptp.payroll_id = ppa.payroll_id
                        AND ptp.regular_payment_date = ppa.effective_date
                        AND ppa.date_earned BETWEEN paaf.effective_start_date
                                                AND paaf.effective_end_date
                        AND ppa.effective_date BETWEEN p_start_date
                                                   AND p_end_date) b,
                (SELECT prrv.run_result_id, prrv.result_value
                   FROM apps.pay_input_values_f pivf,
                        apps.pay_run_result_values prrv
                  WHERE     pivf.input_value_id = prrv.input_value_id
                        AND prrv.result_value <> '0'
                        AND prrv.result_value NOT LIKE '%-%'
                        AND pivf.NAME IN ('Pay Value')) c
          WHERE a.assignment_action_id = b.assignment_action_id
                AND a.run_result_id = c.run_result_id
         UNION
         SELECT DISTINCT
                b.effective_date,
                b.start_date,
                b.end_date,
                LPAD (get_cntr_code ('Perception Counterpart',
                                     a.element_information11,
                                     a.element_name,
                                     p_start_date),
                      3,
                      0)
                   sat_code,
                a.element_type_id,
                get_cntr_name ('Perception Counterpart',
                               a.element_information11,
                               a.element_name,
                               p_start_date)
                   reporting_name,
                a.element_name,
                a.ear_ded,
                get_amount (get_value (a.element_name,
                                       NULL,
                                       'ISR Exempt',
                                       p_assignment_id,
                                       p_start_date,
                                       p_end_date))
                   ele_amt,
                get_amount (ABS (TO_NUMBER (c.result_value))) exempt_amt,
                a.run_result_id
           FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                        petf.element_information11, petf.element_type_id,
                        petf.reporting_name, petf.element_name,
                        petf.element_information_category, 'D' ear_ded
                   FROM apps.pay_run_results prr,
                        apps.pay_element_types_f petf,
                        apps.pay_element_classifications pec
                  WHERE     prr.element_type_id = petf.element_type_id
                        AND petf.classification_id = pec.classification_id
                        AND pec.classification_name LIKE '%Deduction%'
                        AND petf.element_name <> 'ISR') a,
                (SELECT paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,10/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,10/05/23
                        apps.per_time_periods ptp
                  WHERE     ppa.payroll_action_id = paa.payroll_action_id
                        AND paa.assignment_id = paaf.assignment_id
                        AND paaf.primary_flag = 'Y'
                        AND paaf.assignment_id = p_assignment_id
                        AND ptp.payroll_id = ppa.payroll_id
                        AND ptp.regular_payment_date = ppa.effective_date
                        AND ppa.date_earned BETWEEN paaf.effective_start_date
                                                AND paaf.effective_end_date
                        AND ppa.effective_date BETWEEN p_start_date
                                                   AND p_end_date) b,
                (SELECT prrv.run_result_id, prrv.result_value
                   FROM apps.pay_input_values_f pivf,
                        apps.pay_run_result_values prrv
                  WHERE     pivf.input_value_id = prrv.input_value_id
                        AND prrv.result_value LIKE '%-%'
                        AND prrv.result_value <> '0'
                        AND pivf.NAME IN ('Pay Value')) c
          WHERE a.assignment_action_id = b.assignment_action_id
                AND a.run_result_id = c.run_result_id
          UNION /* --CC1.4 Saving Fund*/
                   SELECT DISTINCT b.effective_date, b.start_date, b.end_date,
                         LPAD
                            (NVL
                                (a.element_information11,
                                 get_sat_code (a.element_name,
                                               a.element_information_category,
                                               a.element_information11,
                                               p_start_date
                                              )
                                ),
                             3,
                             '0'
                            ) sat_code,
                         a.element_type_id,
                         NVL (get_information (a.element_name, p_start_date),
                              a.reporting_name
                             ) reporting_name,
                         a.element_name, a.ear_ded,
                         get_amount (get_value (a.element_name,
                                                NULL,
                                                'ISR Exempt',
                                                p_assignment_id,
                                                p_start_date,
                                                p_end_date
                                               )
                                    ) ele_amt,
                         get_amount (get_value (a.element_name,
                                                'Information',
                                                'Pay Value',
                                                p_assignment_id,
                                                p_start_date,
                                                p_end_date
                                               )
                                    ) exempt_amt,
                         NULL run_result_id
                    FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                                 petf.element_information11,
                                 petf.element_type_id, petf.reporting_name,
                                 petf.element_name,
                                 petf.element_information_category,
                                 'E' ear_ded
                            FROM apps.pay_run_results prr,
                                 apps.pay_element_types_f petf,
                                 apps.pay_element_classifications pec
                           WHERE prr.element_type_id = petf.element_type_id
                             AND petf.classification_id =
                                                         pec.classification_id
                             AND pec.classification_name LIKE '%Information%'
                             AND petf.element_name = 'MX_RE_SAVING_FUNDS'  -- 1.4
                             ) a,
                         (SELECT paa.assignment_action_id, ppa.date_earned,
                                 ppa.effective_date, ptp.start_date,
                                 ptp.end_date
                            FROM apps.pay_assignment_actions paa,
                                 apps.pay_payroll_actions ppa,
--                                 hr_lookups lo1,
                                 --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,10/05/23
								 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,10/05/23
                                 apps.per_time_periods ptp
                           WHERE ppa.payroll_action_id = paa.payroll_action_id
                             AND paa.assignment_id = paaf.assignment_id
                             AND paaf.primary_flag = 'Y'
                             AND paaf.assignment_id = p_assignment_id
                             AND paa.assignment_id = paaf.assignment_id
--                             AND lo1.lookup_type = 'ACTION_TYPE'
--                             AND lo1.meaning =  'Balance adjustment'
--                             AND lo1.lookup_code = ppa.action_type
                             AND ptp.payroll_id = ppa.payroll_id
                             AND ptp.regular_payment_date = ppa.effective_date
                             AND ppa.date_earned
                                    BETWEEN paaf.effective_start_date
                                        AND paaf.effective_end_date
                             AND ppa.effective_date BETWEEN p_start_date
                                                        AND p_end_date) b,
                         (SELECT prrv.run_result_id, prrv.result_value
                            FROM apps.pay_input_values_f pivf,
                                 apps.pay_run_result_values prrv
                           WHERE pivf.input_value_id = prrv.input_value_id
                             AND prrv.result_value <> '0'
                             AND prrv.result_value NOT LIKE '%-%'
                             AND UPPER (pivf.NAME) IN UPPER ('Pay Value')) c
                   WHERE a.assignment_action_id = b.assignment_action_id
                     AND a.run_result_id = c.run_result_id;


        	/* --1.3 begin*/
/*
         SELECT DISTINCT
                b.effective_date,
                b.start_date,
                b.end_date,
                         LPAD
                            (NVL
                                (a.element_information11,
                                 get_sat_code (a.element_name,
                                               a.element_information_category,
                                               a.element_information11,
                                               p_start_date
                                              )
                                ),
                             3,
                             '0'
                            ) sat_code,
                         a.element_type_id,
                         NVL (get_information (a.element_name, p_start_date),
                              a.reporting_name
                             ) reporting_name,
                         a.element_name, a.ear_ded,
                         get_amount (get_value (a.element_name,
                                                'Information',
                                                'Pay Value',
                                                p_assignment_id,
                                                p_start_date,
                                                p_end_date
                                               )
                                    ) ele_amt,
                         get_amount (get_value (a.element_name,
                                                NULL,
                                                'ISR Exempt',
                                                p_assignment_id,
                                                p_start_date,
                                                p_end_date
                                               )
                                    ) exempt_amt,
                         NULL run_result_id
                    FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                                 petf.element_information11,
                                 petf.element_type_id, petf.reporting_name,
                                 petf.element_name,
                                 petf.element_information_category,
                                 'E' ear_ded
                            FROM apps.pay_run_results prr,
                                 apps.pay_element_types_f petf,
                                 apps.pay_element_classifications pec
                           WHERE prr.element_type_id = petf.element_type_id
                             AND petf.classification_id =
                                                         pec.classification_id
                             AND pec.classification_name LIKE '%Information%') a,
                         (SELECT paa.assignment_action_id, ppa.date_earned,
                                 ppa.effective_date, ptp.start_date,
                                 ptp.end_date
                            FROM apps.pay_assignment_actions paa,
                                 apps.pay_payroll_actions ppa,
                                 hr_lookups lo1,
                                 hr.per_all_assignments_f paaf,
                                 apps.per_time_periods ptp
                           WHERE ppa.payroll_action_id = paa.payroll_action_id
                             AND paa.assignment_id = paaf.assignment_id
                             AND paaf.primary_flag = 'Y'
                             AND paaf.assignment_id = p_assignment_id
                             AND paa.assignment_id = paaf.assignment_id
                             AND lo1.lookup_type = 'ACTION_TYPE'
                             AND lo1.meaning =  'Balance adjustment'
                             AND lo1.lookup_code = ppa.action_type
                             AND ptp.payroll_id = ppa.payroll_id
                             AND ptp.regular_payment_date = ppa.effective_date
                             AND ppa.date_earned
                                    BETWEEN paaf.effective_start_date
                                        AND paaf.effective_end_date
                             AND ppa.effective_date BETWEEN p_start_date
                                                        AND p_end_date) b,
                         (SELECT prrv.run_result_id, prrv.result_value
                            FROM apps.pay_input_values_f pivf,
                                 apps.pay_run_result_values prrv
                           WHERE pivf.input_value_id = prrv.input_value_id
                             AND prrv.result_value <> '0'
                             AND prrv.result_value NOT LIKE '%-%'
                             AND UPPER (pivf.NAME) IN UPPER ('Pay Value')) c
                   WHERE a.assignment_action_id = b.assignment_action_id
                     AND a.run_result_id = c.run_result_id ;
                  /* --1.3 End*/

      CURSOR c_emp_overtime (
         p_assignment_id    NUMBER,
         p_start_date       DATE,
         p_end_date         DATE)
      IS
           SELECT DISTINCT a.element_name,
                           DECODE (a.element_name, 'MX_OVERTIME_200', 'Dobles', 'Triples') ot_type,
                           NULL amt, COUNT (c.result_value) cnt
             FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                          LPAD (petf.element_information11, 3, '0') sat_code,
                          petf.element_type_id, petf.reporting_name,
                          petf.element_name
                     FROM apps.pay_run_results prr,
                          apps.pay_element_types_f petf,
                          apps.pay_element_classifications pec
                    WHERE prr.element_type_id = petf.element_type_id
                          AND petf.classification_id = pec.classification_id
                          AND petf.element_name IN
                                 ('MX_OVERTIME_200', 'MX_OVERTIME_300')) a,
                  (SELECT paa.assignment_action_id, ppa.date_earned,
                          ppa.effective_date, ptp.start_date, ptp.end_date
                     FROM apps.pay_assignment_actions paa,
                          apps.pay_payroll_actions ppa,
                          --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,10/05/23
						  apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,10/05/23
                          apps.per_time_periods ptp
                    WHERE     ppa.payroll_action_id = paa.payroll_action_id
                          AND paa.assignment_id = paaf.assignment_id
                          AND paaf.primary_flag = 'Y'
                          AND paaf.assignment_id = p_assignment_id
                          AND ptp.payroll_id = ppa.payroll_id
                          AND ptp.regular_payment_date = ppa.effective_date
                          AND ppa.date_earned BETWEEN paaf.effective_start_date
                                                  AND paaf.effective_end_date
                          AND ppa.effective_date BETWEEN p_start_date
                                                     AND p_end_date) b,
                  (SELECT prrv.run_result_id, prrv.result_value
                     FROM apps.pay_input_values_f pivf,
                          apps.pay_run_result_values prrv
                    WHERE     pivf.input_value_id = prrv.input_value_id
                          AND prrv.result_value IS NOT NULL
                          AND pivf.NAME = 'Entry Effective Date') c
            WHERE a.assignment_action_id = b.assignment_action_id
                  AND a.run_result_id = c.run_result_id
         GROUP BY a.element_name;

      CURSOR c_emp_sick (
         p_assignment_id    NUMBER,
         p_start_date       DATE,
         p_end_date         DATE)
      IS
           SELECT DISTINCT a.sat_code, a.element_name,
                           COUNT (c.result_value) cnt
             FROM (SELECT prr.run_result_id,
                          prr.assignment_action_id,
                          get_sat_code (petf.element_name,
                                        petf.element_information_category,
                                        petf.element_information11,
                                        p_start_date)
                             sat_code,
                          petf.element_type_id,
                          petf.reporting_name,
                          petf.element_name
                     FROM apps.pay_run_results prr,
                          apps.pay_element_types_f petf,
                          apps.pay_element_classifications pec
                    WHERE prr.element_type_id = petf.element_type_id
                          AND petf.classification_id = pec.classification_id
                          AND petf.element_name IN
                                 ('MX_ML_WORK_RISK',
                                  'MX_ML_SICKNESS',
                                  'MX_ML_MATERNITY',
                                   --'MX_NCNS',  --1.3 per email from Edna on Jan24,2015 take out NCNS
                                  'MX_ML_WORK_RISK Pending',
                                  'MX_ML_SICKNESS Pending',
                                  'MX_ML_MATERNITY Pending')) a,
                  (SELECT paa.assignment_action_id, ppa.date_earned,
                          ppa.effective_date, ptp.start_date, ptp.end_date
                     FROM apps.pay_assignment_actions paa,
                          apps.pay_payroll_actions ppa,
                          --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,10/05/23
						  apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,10/05/23
                          apps.per_time_periods ptp
                    WHERE     ppa.payroll_action_id = paa.payroll_action_id
                          AND paa.assignment_id = paaf.assignment_id
                          AND paaf.primary_flag = 'Y'
                          AND paaf.assignment_id = p_assignment_id
                          AND ptp.payroll_id = ppa.payroll_id
                          AND ptp.regular_payment_date = ppa.effective_date
                          AND ppa.date_earned BETWEEN paaf.effective_start_date
                                                  AND paaf.effective_end_date
                          AND ppa.effective_date BETWEEN p_start_date
                                                     AND p_end_date) b,
                  (SELECT prrv.run_result_id, prrv.result_value
                     FROM apps.pay_input_values_f pivf,
                          apps.pay_run_result_values prrv
                    WHERE     pivf.input_value_id = prrv.input_value_id
                          AND prrv.result_value IS NOT NULL
                          AND pivf.NAME = 'Entry Effective Date') c
            WHERE a.assignment_action_id = b.assignment_action_id
                  AND a.run_result_id = c.run_result_id
         GROUP BY a.sat_code, a.element_name;

      CURSOR c_legal_info (
         p_payroll_id NUMBER)
      IS
         SELECT org_information1, org_information2, hla.address_line_1,
                hla.address_line_2, hla.town_or_city, hla.country,
                hla.region_1, hla.postal_code
           --FROM hr.hr_organization_information hoi, --code commented by RXNETHI-ARGANO,10/05/23
		   FROM apps.hr_organization_information hoi, --code added by RXNETHI-ARGANO,10/05/23
                hr_all_organization_units haou,
                hr_locations_all hla
          WHERE hoi.org_information_context = 'MX_TAX_REGISTRATION'
                AND haou.organization_id =
                       DECODE (p_payroll_id, 420, 1654, 1651)
                AND hoi.organization_id = haou.organization_id
                AND haou.location_id = hla.location_id;

      v_text               VARCHAR (32765) DEFAULT NULL;
      v_file_name          VARCHAR2 (200) DEFAULT NULL;
      v_file_type          UTL_FILE.file_type;
      v_second_file        VARCHAR2 (200) DEFAULT NULL;
      v_second_type        UTL_FILE.file_type;
      v_cut_off_date       DATE;
      v_current_run_date   DATE;
      v_pay_date           DATE;
      v_pl_id              NUMBER DEFAULT NULL;
      v_not_eli_fsa        VARCHAR2 (1) DEFAULT NULL;
      l_fsa_term_date      DATE DEFAULT NULL;
      v_effective_date     DATE DEFAULT NULL;
      v_flag               VARCHAR2 (1) DEFAULT NULL;
      v_ded_flag           VARCHAR2 (1) DEFAULT NULL;
   BEGIN
      v_cut_off_date := TO_DATE (p_start_date, 'YYYY/MM/DD HH24:MI:SS');
      v_current_run_date := TO_DATE (p_end_date, 'YYYY/MM/DD HH24:MI:SS');
      v_pay_date := TO_DATE (p_pay_date, 'YYYY/MM/DD HH24:MI:SS');

      BEGIN
         FOR r_emp_rec IN c_emp_rec (v_cut_off_date, v_current_run_date)
         LOOP
            v_text := NULL;
            v_flag := 'N';
            v_ded_flag := 'N';

            FOR r_emp_info
               IN c_emp_info (r_emp_rec.person_id,
                              r_emp_rec.actual_termination_date)
            LOOP
               v_file_name :=
                     'MEX_'
                  || r_emp_info.gre
                  || '_'
                  || r_emp_info.employee_number
                  || '_'
                  || r_emp_info.loc_abbrv
                  || '_'
                  || TO_CHAR (v_current_run_date, 'YYYYMMDD')
                  || '_PAY.NOM';
               v_file_type :=
                  UTL_FILE.fopen (p_output_directory,
                                  v_file_name,
                                  'w',
                                  32765);

               BEGIN
                  v_text :=
                        'NO'
                     || '|'
                     || r_emp_info.org_ssn
                     || '|'
                     || r_emp_info.assignment_number
                     || '|'
                     || r_emp_info.national_identifier
                     || '|'
                     || '2'
                     || '|'
                     || r_emp_info.ssn_id
                     || '|'
                     || TO_CHAR (v_current_run_date, 'YYYY-MM-DD')
                     || '|'
                     || TO_CHAR (v_cut_off_date, 'YYYY-MM-DD')
                     || '|'
                     || TO_CHAR (v_pay_date, 'YYYY-MM-DD') -- 1.7
                     || '|'
                     || get_amount (get_value ('MX_DAYS_IN_PERIOD',
                                               NULL,
                                               'Days',
                                               r_emp_info.assignment_id,
                                               v_cut_off_date,
                                               v_current_run_date))
                     || '|'
                     || r_emp_info.client
                     || '|'
                     || ''
                     || '|'
                     || '014'
                     || '|'
                     || TO_CHAR (r_emp_info.original_date_of_hire,
                                 'YYYY-MM-DD')
                     || '|'
                     || ''
                     || '|'
                     || ''  --TRIM (cvt_char (r_emp_info.job_name)) -- 1.4
                     || '|'
                     || ''  --TRIM (cvt_char (r_emp_info.ass_cat_mean)) -- 1.4
                     || '|'
                     || ''  --TRIM (cvt_char (r_emp_info.type_of_work_day)) -- 1.4
                     || '|'
                     || 'Quincenal'
                     || '|'
--                     || get_amount (get_value ('MX_TOTAL_EARNINGS',  --1.4
--                                               NULL,
--                                               'Pay Value',
--                                               r_emp_info.assignment_id,
--                                               v_cut_off_date,
--                                               v_current_run_date))
                     || '|'
                     || '1'
                     || '|';
--                     || get_amount (get_value ('Integrated Daily Wage', --1.4
--                                               NULL,
--                                               NULL,
--                                               'Pay Value',
--                                               r_emp_info.assignment_id,
--                                               v_cut_off_date,
--                                               v_current_run_date));
                  UTL_FILE.put_line (v_file_type, v_text);
                  fnd_file.put_line (fnd_file.output, v_text);
               END;

               BEGIN
                  v_text := NULL;
                  v_text :=
                        'PES'
                     || '|'
                     || get_amount (get_ear_value (NULL,
                                                   'Earning',
                                                   'ISR Subject',
                                                   r_emp_info.assignment_id,
                                                   v_cut_off_date,
                                                   v_current_run_date))
                     || '|'
                     || get_amount (
                             get_balance (r_emp_info.assignment_id,
                                          'ISR Exempt',
                                          '_ASG_GRE_RUN',
                                          v_current_run_date)
                           +  (  get_value (NULL,
                                        'Non-payroll Payments',
                                        'Pay Value',
                                        r_emp_info.assignment_id,
                                        v_cut_off_date,
                                        v_current_run_date)
                               + get_value ('MX_RE_SAVING_FUNDS', -- 1.4
                                        'Information',
                                        'Pay Value',
                                        r_emp_info.assignment_id,
                                        v_cut_off_date,
                                        v_current_run_date)
                               - get_value ('MX_SF_COMPANY_LIQ',  --1.4
                                            'Non-payroll Payments',
                                            'Pay Value',
                                            r_emp_info.assignment_id,
                                            v_cut_off_date,
                                            v_current_run_date)
                               - get_value ('MX_SF_LIQUIDATION', --1.4
                                            'Non-payroll Payments',
                                            'Pay Value',
                                            r_emp_info.assignment_id,
                                            v_cut_off_date,
                                            v_current_run_date)
                                        )
                           + get_neg_value (NULL,
                                            'Deduction',
                                            'Pay Value',
                                            r_emp_info.assignment_id,
                                            v_cut_off_date,
                                            v_current_run_date));

                  IF v_text <> 'PES|0.00|0.00'
                  THEN
                     UTL_FILE.put_line (v_file_type, v_text);
                     fnd_file.put_line (fnd_file.output, v_text);
                  ELSE
                     v_flag := 'Y';
                  END IF;
               END;

               BEGIN
                  FOR r_emp_element
                     IN c_emp_element (r_emp_info.assignment_id,
                                       v_cut_off_date,
                                       v_current_run_date,
                                       'Earning')
                  LOOP
                     v_text := NULL;
                     v_text :=
                           'PE'
                        || '|'
                        || r_emp_element.sat_code
                        || '|'
                        || r_emp_element.element_type_id
                        || '|'
                        || TRIM (cvt_char (r_emp_element.reporting_name))
                        || '|'
                        || r_emp_element.ele_amt
                        || '|'
                        || r_emp_element.exempt_amt;

                     IF v_flag <> 'Y'
                     THEN
                        UTL_FILE.put_line (v_file_type, v_text);
                        fnd_file.put_line (fnd_file.output, v_text);
                     END IF;
                  END LOOP;
               END;

               BEGIN
                  v_text := NULL;
                  v_text :=
                        'DES'
                     || '|'
                     || get_amount (get_ded_value (NULL,
                                                   'Deductions',
                                                   'Pay Value',
                                                   r_emp_info.assignment_id,
                                                   v_cut_off_date,
                                                   v_current_run_date))
                     || '|'
                     || '0.00';

                  IF v_text <> 'DES|0.00|0.00'
                  THEN
                     UTL_FILE.put_line (v_file_type, v_text);
                     fnd_file.put_line (fnd_file.output, v_text);
                  ELSE
                     v_ded_flag := 'Y';
                  END IF;
               END;

               BEGIN
                  FOR r_ded_element
                     IN c_ded_element (r_emp_info.assignment_id,
                                       v_cut_off_date,
                                       v_current_run_date,
                                       'Deductions')
                  LOOP
                     v_text := NULL;
                     v_text :=
                           'DE'
                        || '|'
                        || r_ded_element.sat_code
                        || '|'
                        || r_ded_element.element_type_id
                        || '|'
                        || TRIM (cvt_char (r_ded_element.reporting_name))
                        || '|'
                        || r_ded_element.ele_amt
                        || '|'
                        || '0.00';

                     IF v_ded_flag <> 'Y'
                     THEN
                        UTL_FILE.put_line (v_file_type, v_text);
                        fnd_file.put_line (fnd_file.output, v_text);
                     END IF;
                  END LOOP;
               END;

               BEGIN
                  FOR r_emp_sick
                     IN c_emp_sick (r_emp_info.assignment_id,
                                    v_cut_off_date,
                                    v_current_run_date)
                  LOOP
                     v_text := NULL;
                     v_text :=
                           'IN'
                        || '|'
                        || get_amount (r_emp_sick.cnt)
                        || '|'
                        || r_emp_sick.sat_code
                        || '|'
                        || get_amount (get_value (r_emp_sick.element_name,
                                                  NULL,
                                                  'Pay Value',
                                                  r_emp_info.assignment_id,
                                                  v_cut_off_date,
                                                  v_current_run_date));
                     UTL_FILE.put_line (v_file_type, v_text);
                     fnd_file.put_line (fnd_file.output, v_text);
                  END LOOP;
               END;

               BEGIN
                  FOR r_emp_overtime
                     IN c_emp_overtime (r_emp_info.assignment_id,
                                        v_cut_off_date,
                                        v_current_run_date)
                  LOOP
                     v_text := NULL;

                     IF r_emp_overtime.element_name = 'MX_OVERTIME_200'
                     THEN
                        r_emp_overtime.amt :=
                           get_value ('MX_OVERTIME_200',
                                      NULL,
                                      'Pay Value',
                                      r_emp_info.assignment_id,
                                      v_cut_off_date,
                                      v_current_run_date)
                           + get_value ('MX_ADJ_OT200',
                                        NULL,
                                        'Pay Value',
                                        r_emp_info.assignment_id,
                                        v_cut_off_date,
                                        v_current_run_date);
                     ELSE
                        r_emp_overtime.amt :=
                           get_value ('MX_OVERTIME_300',
                                      NULL,
                                      'Pay Value',
                                      r_emp_info.assignment_id,
                                      v_cut_off_date,
                                      v_current_run_date)
                           + get_value ('MX_ADJ_OT300',
                                        NULL,
                                        'Pay Value',
                                        r_emp_info.assignment_id,
                                        v_cut_off_date,
                                        v_current_run_date);
                     END IF;

                     v_text :=
                           'HE'
                        || '|'
                        || r_emp_overtime.cnt
                        || '|'
                        || r_emp_overtime.ot_type
                        || '|'
                        || ROUND (get_value (r_emp_overtime.element_name,
                                             NULL,
                                             'Hours',
                                             r_emp_info.assignment_id,
                                             v_cut_off_date,
                                             v_current_run_date))
                        || '|'
                        || get_amount (r_emp_overtime.amt);
                     UTL_FILE.put_line (v_file_type, v_text);
                     fnd_file.put_line (fnd_file.output, v_text);
                  END LOOP;
               END;

               UTL_FILE.fclose (v_file_type);
            END LOOP;
         END LOOP;
      EXCEPTION
         WHEN OTHERS
         THEN
            UTL_FILE.fclose (v_file_type);
            fnd_file.put_line (fnd_file.LOG,
                               'Error out NOM File -' || SQLERRM);
      END;

      BEGIN
         FOR r_emp_rec IN c_emp_rec (v_cut_off_date, v_current_run_date)
         LOOP
            v_text := NULL;

            FOR r_emp_info
               IN c_emp_info (r_emp_rec.person_id,
                              r_emp_rec.actual_termination_date)
            LOOP
               v_second_file :=
                     'MEX_'
                  || r_emp_info.gre
                  || '_'
                  || r_emp_info.employee_number
                  || '_'
                  || r_emp_info.loc_abbrv
                  || '_'
                  || TO_CHAR (v_current_run_date, 'YYYYMMDD')
                  || '_PAY.txt';
               v_second_type :=
                  UTL_FILE.fopen (p_output_directory,
                                  v_second_file,
                                  'w',
                                  32765);

               BEGIN
                  v_text :=
                        '[H1]'
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || TO_CHAR (SYSDATE, 'YYYYMMDD')
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || 'Pago en una solo exhibicion'
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || 'RECIBO_NOMINA'
                     || '|'
                     || ''
                     || '|'
                     || 'Deducciones Nomina'
                     || '|'
                     || get_amount (get_ded_value (NULL,
                                                   'Deductions',
                                                   'Pay Value',
                                                   r_emp_info.assignment_id,
                                                   v_cut_off_date,
                                                   v_current_run_date))
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || 'MEXICO DF'
                     || '|'
                     || 'TRANSFERENCIA ELECTRONICA'
                     || '|'
                     || 'MXN'
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || iby_amount_in_words.get_amount_in_words (
                           get_value ('MX_NET_PAY',
                                      NULL,
                                      'Pay Value',
                                      r_emp_info.assignment_id,
                                      v_cut_off_date,
                                      v_current_run_date),
                           'MXN')
                     || '|'
                     || 'D02'
                     || '|'
                     || 'T'
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || 'NOM'
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || '';
                  UTL_FILE.put_line (v_second_type, v_text);
                  fnd_file.put_line (fnd_file.output, v_text);
               END;

               BEGIN
                  FOR r_legal_info IN c_legal_info (r_emp_info.payroll_id)
                  LOOP
                     v_text := NULL;
                     v_text :=
                           '[H2]'
                        || '|'
                        || r_legal_info.org_information1
                        || '|'
                        || r_legal_info.org_information2
                        || '|'
                        || ''
                        || '|'
                        || r_legal_info.address_line_1
                        || '|'
                        || r_legal_info.address_line_2
                        || '|'
                        || ''
                        || '|'
                        || ''
                        || '|'
                        || ''
                        || '|'
                        || ''
                        || '|'
                        || r_legal_info.town_or_city
                        || '|'
                        || r_legal_info.region_1
                        || '|'
                        || r_legal_info.country
                        || '|'
                        || r_legal_info.postal_code
                        || '|'
                        || 'Sueldos y Salarios'
                        || '|'
                        || ''
                        || '|'
                        || ''
                        || '|'
                        || ''
                        || '|'
                        || ''
                        || '|'
                        || ''
                        || '|'
                        || ''
                        || '|'
                        || ''
                        || '|'
                        || ''
                        || '|'
                        || ''
                        || '|'
                        || r_emp_info.employer_acc;
                     UTL_FILE.put_line (v_second_type, v_text);
                     fnd_file.put_line (fnd_file.output, v_text);
                  END LOOP;
               END;

               BEGIN
                  v_text := NULL;
                  v_text :=
                        '[H4]'
                     || '|'
                     || r_emp_info.full_name
                     || '|'
                     || r_emp_info.rfc_id
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || r_emp_info.country
                     || '|'
                     || r_emp_info.postal_code
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || '';
                  UTL_FILE.put_line (v_second_type, v_text);
                  fnd_file.put_line (fnd_file.output, v_text);
               END;

               BEGIN
                  v_text := NULL;
                  v_text :=
                        '[D]'
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || 'Periodo de Pago'
                     || '|'
                     || ''
                     || '|'
                     || '1'
                     || '|'
                     || 'Service'
                     || '|'
                     || ''
                     || '|'
                     || get_amount (
                             get_ear_value (NULL,
                                            'Earning',
                                            'ISR Subject',
                                            r_emp_info.assignment_id,
                                            v_cut_off_date,
                                            v_current_run_date)
                           + (
                            get_balance (r_emp_info.assignment_id,
                                          'ISR Exempt',
                                          '_ASG_GRE_RUN',
                                          v_current_run_date)
                           +  (  get_value (NULL,
                                        'Non-payroll Payments',
                                        'Pay Value',
                                        r_emp_info.assignment_id,
                                        v_cut_off_date,
                                        v_current_run_date)
                               +  get_value ('MX_RE_SAVING_FUNDS', -- 1.4
                                        'Information',
                                        'Pay Value',
                                        r_emp_info.assignment_id,
                                        v_cut_off_date,
                                        v_current_run_date)
                               - get_value ('MX_SF_COMPANY_LIQ',  --1.4
                                            'Non-payroll Payments',
                                            'Pay Value',
                                            r_emp_info.assignment_id,
                                            v_cut_off_date,
                                            v_current_run_date)
                               - get_value ('MX_SF_LIQUIDATION', --1.4
                                            'Non-payroll Payments',
                                            'Pay Value',
                                            r_emp_info.assignment_id,
                                            v_cut_off_date,
                                            v_current_run_date)
                                        )
                           + get_neg_value (NULL,
                                            'Deduction',
                                            'Pay Value',
                                            r_emp_info.assignment_id,
                                            v_cut_off_date,
                                            v_current_run_date)
                              )
                                            )
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || get_amount (
                             get_ear_value (NULL,
                                            'Earning',
                                            'ISR Subject',
                                            r_emp_info.assignment_id,
                                            v_cut_off_date,
                                            v_current_run_date)
                           + (
                            get_balance (r_emp_info.assignment_id,
                                          'ISR Exempt',
                                          '_ASG_GRE_RUN',
                                          v_current_run_date)
                           +  (  get_value (NULL,
                                        'Non-payroll Payments',
                                        'Pay Value',
                                        r_emp_info.assignment_id,
                                        v_cut_off_date,
                                        v_current_run_date)
                               +  get_value ('MX_RE_SAVING_FUNDS', -- 1.4
                                        'Information',
                                        'Pay Value',
                                        r_emp_info.assignment_id,
                                        v_cut_off_date,
                                        v_current_run_date)
                               - get_value ('MX_SF_COMPANY_LIQ',  --1.4
                                            'Non-payroll Payments',
                                            'Pay Value',
                                            r_emp_info.assignment_id,
                                            v_cut_off_date,
                                            v_current_run_date)
                               - get_value ('MX_SF_LIQUIDATION', --1.4
                                            'Non-payroll Payments',
                                            'Pay Value',
                                            r_emp_info.assignment_id,
                                            v_cut_off_date,
                                            v_current_run_date)
                                        )
                           + get_neg_value (NULL,
                                            'Deduction',
                                            'Pay Value',
                                            r_emp_info.assignment_id,
                                            v_cut_off_date,
                                            v_current_run_date)
                              )
                                            )
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || get_amount (get_value ('ISR',
                                               NULL,
                                               'Pay Value',
                                               r_emp_info.assignment_id,
                                               v_cut_off_date,
                                               v_current_run_date))
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || '';
                  UTL_FILE.put_line (v_second_type, v_text);
                  fnd_file.put_line (fnd_file.output, v_text);
               END;

               BEGIN
                  v_text := NULL;
                  v_text :=
                        '[S]'
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     --                     || get_amount (get_value ('MX_NET_PAY',
                     --                                               NULL,
                     --                                               'Pay Value',
                     --                                               r_emp_info.assignment_id,
                     --                                               v_cut_off_date,
                     --                                               v_current_run_date
                     --                                              )
                     --                                   )
                     || get_amount (
                             get_ear_value (NULL,
                                            'Earning',
                                            'ISR Subject',
                                            r_emp_info.assignment_id,
                                            v_cut_off_date,
                                            v_current_run_date)
                           + (
                            get_balance (r_emp_info.assignment_id,
                                          'ISR Exempt',
                                          '_ASG_GRE_RUN',
                                          v_current_run_date)
                           +  (  get_value (NULL,
                                        'Non-payroll Payments',
                                        'Pay Value',
                                        r_emp_info.assignment_id,
                                        v_cut_off_date,
                                        v_current_run_date)
                               +  get_value ('MX_RE_SAVING_FUNDS', -- 1.4
                                        'Information',
                                        'Pay Value',
                                        r_emp_info.assignment_id,
                                        v_cut_off_date,
                                        v_current_run_date)
                               - get_value ('MX_SF_COMPANY_LIQ',  --1.4
                                            'Non-payroll Payments',
                                            'Pay Value',
                                            r_emp_info.assignment_id,
                                            v_cut_off_date,
                                            v_current_run_date)
                               - get_value ('MX_SF_LIQUIDATION', --1.4
                                            'Non-payroll Payments',
                                            'Pay Value',
                                            r_emp_info.assignment_id,
                                            v_cut_off_date,
                                            v_current_run_date)
                                        )
                           + get_neg_value (NULL,
                                            'Deduction',
                                            'Pay Value',
                                            r_emp_info.assignment_id,
                                            v_cut_off_date,
                                            v_current_run_date)
                              )
                           - get_ded_value (NULL,                        -- --1.3
                                            'Deductions',
                                            'Pay Value',
                                            r_emp_info.assignment_id,
                                            v_cut_off_date,
                                            v_current_run_date))
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || get_amount (get_value ('ISR',
                                               NULL,
                                               'Pay Value',
                                               r_emp_info.assignment_id,
                                               v_cut_off_date,
                                               v_current_run_date)
                                               )
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || get_amount (
                             get_ear_value (NULL,
                                            'Earning',
                                            'ISR Subject',
                                            r_emp_info.assignment_id,
                                            v_cut_off_date,
                                            v_current_run_date)
                           + (
                            get_balance (r_emp_info.assignment_id,
                                          'ISR Exempt',
                                          '_ASG_GRE_RUN',
                                          v_current_run_date)
                           +  (  get_value (NULL,
                                        'Non-payroll Payments',
                                        'Pay Value',
                                        r_emp_info.assignment_id,
                                        v_cut_off_date,
                                        v_current_run_date)
                               +  get_value ('MX_RE_SAVING_FUNDS', -- 1.4
                                        'Information',
                                        'Pay Value',
                                        r_emp_info.assignment_id,
                                        v_cut_off_date,
                                        v_current_run_date)
                               - get_value ('MX_SF_COMPANY_LIQ',  --1.4
                                            'Non-payroll Payments',
                                            'Pay Value',
                                            r_emp_info.assignment_id,
                                            v_cut_off_date,
                                            v_current_run_date)
                               - get_value ('MX_SF_LIQUIDATION', --1.4
                                            'Non-payroll Payments',
                                            'Pay Value',
                                            r_emp_info.assignment_id,
                                            v_cut_off_date,
                                            v_current_run_date)
                                        )
                           + get_neg_value (NULL,
                                            'Deduction',
                                            'Pay Value',
                                            r_emp_info.assignment_id,
                                            v_cut_off_date,
                                            v_current_run_date)
                              )
                                            )
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || '';
                  UTL_FILE.put_line (v_second_type, v_text);
                  fnd_file.put_line (fnd_file.output, v_text);
               END;

               UTL_FILE.fclose (v_second_type);
            END LOOP;
         END LOOP;
      EXCEPTION
         WHEN OTHERS
         THEN
            UTL_FILE.fclose (v_second_type);
            fnd_file.put_line (fnd_file.LOG,
                               'Error out GEN File -' || SQLERRM);
      END;
   EXCEPTION
      WHEN OTHERS
      THEN
         UTL_FILE.fclose (v_file_type);
         UTL_FILE.fclose (v_second_type);
         fnd_file.put_line (fnd_file.LOG,
                            'Error out of main loop main_proc -' || SQLERRM);
   END main_proc;
END ttec_pay_mex_2014_intf;
/
show errors;
/