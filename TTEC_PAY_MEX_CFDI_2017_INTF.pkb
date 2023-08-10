create or replace PACKAGE BODY      ttec_pay_mex_cfdi_2017_intf
IS
   /*---------------------------------------------------------------------------------------
    Objective    : Interface to extract data for all Mexico employees to send to vendor
    Package spec :ttec_pay_mex_cfdi_2017_intf
    Parameters:p_output_dir    --  output directory to generate the files.
               p_start_date  -- required payroll start paramters to run the report if the data is missing for particular dates
               p_end_date  -- required payroll end paramters to run the report if the data is missing for particular dates
      MODIFICATION HISTORY
      Person               Version  Date        Comments
      ------------------------------------------------
      Kaushik Babu         1.0      1/20/2014  New package for sending mexico payroll employee data to vendor INC0304270
      Kaushik Babu         1.1      6/26/2014  removed '-' for rfc_id column as per ticket INC0385479
      Kaushik Babu         1.2      1/25/2015  Changes by Kaushik
      Christiane Chan      1.3      1/25/2015  Changes by Christiane Chan
      Christiane Chan      1.4      1/26/2015  Changes by Christiane Chan -- taken out MX_SF_COMPANY_LIQ  and MX_SF_LIQUIDATION from c_emp_element
                                                                          -- adding MX_RE_SAVING_FUNDS to both 'PE' and 'DE'
      Christiane Chan      1.5      1/26/2015  Changes by Christiane Chan -- to Fix Termed Employee got profit sharing after left company  eg. emp 7025464 Term in 2/28/14 profit sharing in first Period in May
      Christiane Chan      1.6      1/26/2015  Changes by Christiane Chan --  Performance tuning when only employee is provided at the parameter
      Christiane Chan      1.7      1/26/2015  Changes by Christiane Chan --  Add Pay date Paramater to control the NO record
      Christiane Chan      1.8      1/26/2015  Changes by Christiane Chan --  change to call Deduction ocounterpart instaed of Perception counterpard in element classification -> Earnings
      Christiane Chan      1.10     2/03/2015  Copy from 2014 package to take out Coupon from the file, since coupon will be delivered by a different package
      Christiane Chan      1.11     2/10/2015  Email Request on 2/10/2115 move the exempt side the amount of the  ISR Subsidy for Employment element
      Christiane Chan      1.12     2/26/2015  Swapping the Pay Date field with Pay Period End Date on 'NO' record
      Christiane Chan      1.13     4/14/2015  INC1177448 - assistance to keep empty the field "Bank", It appears with number 014 in the line "NO" into the concurent program
                                               Teletech Mexico CFDI Payroll Custom Interface - 2015 and TeleTech Mexico CFDI Payroll Custom Interface - 2015 Coupon due to it is an optional field.
      Christiane Chan      1.14     4/20/2015  INC1178577- add the employee's email in the line H4 Field 19
      Christiane Chan      2.0      2/8/2017   2017 CFDI Layout change
      Christiane Chan      2.1      5/11/2017  Need to include employee with Terminate Assignment that has a pay entries made at a later time
      Christiane Chan      2.2      6/1/2017   Fix for employee transferred to different payrll not getting picked up
      Christiane Chan      2.3      6/5/2017   2,3,1 Fix for [Deductions] should not be printed if zero amounts
                                               2.3.2 Element NumPaidDays only get generated during the Regular Run - do not exist for E = Extraordinary payroll  default to 1 only if no value
                                               2,3,3 Fix for [Percepccions] should not be printed if zero amounts
                                    6/16/2017  2.3.4 Take out Subcontracting
                                    6/23/2017  2.3.5 Restore Section C Recipient - Receptor 17 IntegratedDailySalary
      Christiane Chan      2.4      6/13/2017  2.4.1 Fix for negative tax exempt amount should not pick up in Perception
                                               2.4.2 Fix for counter part
                                               2.4.3 Fix for Hora Extra
                                               2.4.4 Fix for adding counterpart amount to the v_TotDeductions
                                               2.4.5 Fix for adding counterpart amount to the v_TotPercepcions
                                               2.4.6 Fix for overtime
                                               2.4.7 Fix for get_ded_value
                                               2.4.8 Fix for Seneority  [Receptor] negative value
                                               2.4.9 Fix for Nomina - v_TotPercepcions should not show 0.00
      Christiane Chan      3.0      2/16/2018  Mexico CFDI Version 3.3 requirements
                           3.1      3/06/2018  Mexico CFDI Version 3.3 requirements  - adding Expense Report
                           3.2      3/12/2018  Negative MX_CHRISTMAS_BONUS should be added back to Percepciones.v_TotTaxExempts emp 7047620 1PP DEC 2017
                           3.3      3/12/2018  Fix for Deduccion Missing SAT code and Reporting Name for Counter part for MX_GROSERY_COUPONS
                           3.4      3/13/2018  Fix for Negative ISR Exempts < MX_CHRISTMAS_BONUS
                           3.5      3/20/2018  Adding pipe immediately after the currency code H1F_Comprobante
      Christiane Chan      4.0      11/01/2018 Replacing the hardcoded values on loc_abbreviation and State_code with Lookup mapping 'TTEC_MEX_CFDI_LOC_ABBRV' and 'TTEC_MEX_CFDI_STATECODE'
      Rajesh Koneru        4.1      06/08/2020 Retrofitting changes for syntax
      Christiane Chan      5.0      08/11/2020 Mexico Payroll CFDI 2020 requirements:
                                                1. The following 3 CFDI elements need to be added simultaneously on 2PP, when 071 appears only under deduction section in 2PP and the value of 'ISR Subsidy for Employment' is negative
                                                   Section          SAT       Costing   Reporting Name                                          Value
                                                   ---------------  -------   -------   -----------------------------------------------         --------------------------------------------------------------------------------------------------------
                                                   [Deducciones]    107       2330      Ajuste al Subsidio Causado                              show 1PP ISR Subsidy for Employment' on Balance Name ->'ISR Subsidy for Employment'
                                                   [OtrosPagos]     007       2330      ISR ajustado por subsidio                               show 1PP ISR Calculated on Balance Name ->ISR Calculated
                                                                    008       2110      Subsidio efectivamente entregado que no corresponda     show 1PP Tax Credit on Balance Neme -> Tax Credit
                                                   ---------------  -------   -------   ---------------------------------------------------     --------------------------------------------------------------------------------------------------------
                                                2. Under c_other_pymnt_element section - Allow zero amount to be picked on 'Tax Credit' petf.element_name = 'ISR Subsidy for Employment'
                                                3. Renamed 'Subsidio para el empleo efectivamente entregado al trabajador' from 'Subsidio para el empleo' 5.0.3
                                                4. Allow Subtotal of Zero to display under Nomina
                                                5. Need to add under [OtroPago] section, entry of Zero amount on employee who has 'ISR' element appear under deduction but do not have 'ISR Subsidy for Employment' Element in payroll
                                                6. Need to split ISR into 'ISR 2'+ 'ISR ajuste mensual' under [Deduccion] section - on 2PP, when 071 appears only under deduction section in 2PP and the value of 'ISR Subsidy for Employment' is negative
                                                                                                                                   - if 'ISR 2' Amount is negative, show the original ISR only -> do not split
                                                7. Need to add under [OtroPago] section, entry of Zero amount on employee who do not have both ISR and 'ISR Subsidy for Employment' under [Deduccion] section
                                                8. CFDI requires to always include [SubsidioAlEmpleo] in 1PP and 2pp (AUG 21-2020 PM).
                                                9. When 071 appears under deduction section in 2PP, [SubsidioAlEmpleo] Amount
                                                    1. AUG 24 PM      feedback - Need to show total amount of 1PP and 2PP
                                                    2. AUG 25 AM      feedback - Need to show the original sign (negative value) on 2PP, otherwise, will show incorrect total  amount. CFDI
                                                    3. AUG 25 Evening feedback - Do not show [SubsidioAlEmpleo] if amount is Zero
                                                10. AUG 27 - IF we have a negative value under [SubsidioAlEmpleo] section -  need to show zero (0) , do not show the negative value
      Christiane Chan      5.1      09/28/2020 INC7579031 Fix on semicolon between email addresses, needs to be there when needed only.
      Christiane Chan      5.2     12/14/2020 INC8348465 - Update the field "Sindicalizado" in the RECEPTOR section  with hardcoded value 'No'
     Christiane Chan      5.3     2/28/2021  TASK1966395 -   Need to exclude MX_INTERNET_ALLOWANCE and MX_ELECTRICITY_SERVICE_ALLOWANCE under [OtroPago] section,  And should not appear
     Narasimhulu Yellam   5.4     25-Jun-2021 TASK2307834 - Legal Employer section and GRE section to reflect old details based pay period end date.
     Christiane Chan      6.0   08/27/2021 Fix for incorrect SAT code for MX_OVERPAID_SALARY, it should not be 038, it needs to be 013 just same as MX_DED_DUE2LATE_IN
     Neelofar Sheik       6.1   09/27/2022 Neelofar  Mexico Percepta New GRE Payroll Project.
	 RXNETHI-ARGANO       1.0   05/12/2023 R12.2 Upgrade Remediation
   *== END ==================================================================================================*/
    --v_module                         cust.ttec_error_handling.module_name%TYPE := 'Main'; --code commented by RXNETHI-ARGANO,12/05/23
	v_module                         apps.ttec_error_handling.module_name%TYPE := 'Main'; --code added by RXNETHI-ARGANO,12/05/23
    v_loc                            varchar2(10);
    v_071_appear_flag                varchar2(1):= 'N'; /* 5.0.9 */
   FUNCTION get_balance (p_assignment_id       NUMBER,
                         p_balance_name     IN VARCHAR2,
                         p_dimension_name   IN VARCHAR2,
                         p_effective_date   IN DATE)
      RETURN NUMBER
   IS
      l_value   VARCHAR2 (100);
      l_balance_name   VARCHAR2 (100);
   BEGIN
      l_value := 0;

      SELECT NVL (SUM (a.balance_value), 0)
        INTO l_value
        FROM (SELECT prb.assignment_id, prb.balance_value,
                     pdb.defined_balance_id, pdb.balance_type_id,
                     pdb.balance_dimension_id
                FROM (SELECT defined_balance_id, assignment_id,
                             effective_date, balance_value
                        --FROM hr.pay_run_balances --code commented by RXNETHI-ARGANO,12/05/23
						FROM apps.pay_run_balances --code added by RXNETHI-ARGANO,12/05/23
                       WHERE     effective_date = p_effective_date
                             AND assignment_id IS NOT NULL
                             AND assignment_id = p_assignment_id) prb,
                     --hr.pay_defined_balances pdb --code commented by RXNETHI-ARGANO,12/05/23
					 apps.pay_defined_balances pdb --code added by RXNETHI-ARGANO,12/05/23
               WHERE prb.defined_balance_id = pdb.defined_balance_id) a,
             --hr.pay_balance_types pbt,      --code commented by RXNETHI-ARGANO,12/05/23
             --hr.pay_balance_dimensions pbd  --code commented by RXNETHI-ARGANO,12/05/23
			 apps.pay_balance_types pbt,      --code added by RXNETHI-ARGANO,12/05/23
             apps.pay_balance_dimensions pbd  --code added by RXNETHI-ARGANO,12/05/23
       WHERE     a.balance_type_id = pbt.balance_type_id
             AND pbt.balance_name LIKE p_balance_name
             AND pbt.legislation_code = 'MX'
             AND pbt.currency_code = 'MXN'
             AND a.balance_dimension_id = pbd.balance_dimension_id
             AND pbd.database_item_suffix = p_dimension_name
             AND (   (     v_module in ('[A.7]', '[D.5]') -- v_TotTaxExempts
                       and (   ( pbt.balance_name  = 'ISR Subsidy for Employment Paid' and a.balance_value > 0)
                           -- OR ( pbt.balance_name != 'ISR Subsidy for Employment Paid') /* 2.4.5 */
                            OR ( pbt.balance_name != 'ISR Subsidy for Employment Paid' and a.balance_value > 0)  /* 2.4.5 */
                            )
                        )
                  OR v_module not in ('[A.7]', '[D.5]')  )
             ;

--          Fnd_File.put_line(Fnd_File.LOG,'>>>>>>>>>>Get Balance');
--          Fnd_File.put_line(Fnd_File.LOG,'    v_module :'||v_module);
--          Fnd_File.put_line(Fnd_File.LOG,'Balance Name :'||p_balance_name);
--          Fnd_File.put_line(Fnd_File.LOG,'>>>>>l_value :'||l_value);

      RETURN l_value;
   EXCEPTION
      WHEN OTHERS
      THEN
         l_value := 0;
         RETURN l_value;
   END get_balance;

   /* 5.0.1  Begin */
   FUNCTION get_1PP_ISR_subsidy_bal (p_assignment_id       NUMBER,
                                     p_balance_name     IN VARCHAR2,
                                     p_dimension_name   IN VARCHAR2,
                                     p_start_date      IN DATE,
                                     p_end_date        IN DATE)
   RETURN NUMBER
   AS
      l_result_value   NUMBER:=0;

   BEGIN

      SELECT (SELECT NVL (SUM (a.balance_value), 0)
                FROM (SELECT prb.assignment_id, prb.balance_value,
                             pdb.defined_balance_id, pdb.balance_type_id,
                             pdb.balance_dimension_id
                        FROM (SELECT defined_balance_id, assignment_id,
                                     effective_date, balance_value
                                --FROM hr.pay_run_balances --code commented by RXNETHI-ARGANO,12/05/23
								FROM apps.pay_run_balances --code added by RXNETHI-ARGANO,12/05/23
                               WHERE     effective_date = trunc(p_start_date, 'MM') + 14 --p_effective_date
                                     AND assignment_id IS NOT NULL
                                     AND assignment_id = p_assignment_id
                                     ) prb,
                             --hr.pay_defined_balances pdb --code commented by RXNETHI-ARGANO,12/05/23
							 apps.pay_defined_balances pdb --code added by RXNETHI-ARGANO,12/05/23
                       WHERE prb.defined_balance_id = pdb.defined_balance_id) a,
                     --hr.pay_balance_types pbt,      --code commented by RXNETHI-ARGANO,12/05/23
                     --hr.pay_balance_dimensions pbd  --code commented by RXNETHI-ARGANO,12/05/23
					 apps.pay_balance_types pbt,      --code added by RXNETHI-ARGANO,12/05/23
                     apps.pay_balance_dimensions pbd  --code added by RXNETHI-ARGANO,12/05/23
               WHERE     a.balance_type_id = pbt.balance_type_id
                     AND pbt.balance_name = p_balance_name
                     AND pbt.legislation_code = 'MX'
                     AND pbt.currency_code = 'MXN'
                     AND a.balance_dimension_id = pbd.balance_dimension_id
                     AND pbd.database_item_suffix = p_dimension_name
                              )
        INTO l_result_value
           FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                        petf.element_information11, petf.element_type_id,
                        petf.reporting_name, petf.element_name, 'D' ear_ded,
                        petf.element_information_category
                   FROM apps.pay_run_results prr,
                        apps.pay_element_types_f petf,
                        apps.pay_element_classifications pec
                  WHERE prr.element_type_id = petf.element_type_id
                        AND petf.classification_id = pec.classification_id
                        AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE
                        AND pec.classification_name = 'Tax Credit'
                        AND petf.element_name = 'ISR Subsidy for Employment'
                        ) a,
                (SELECT ppa.payroll_id, paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                        AND prrv.result_value LIKE '%-%' /* 5.0.1 */ -- has to be negative value
                        AND pivf.NAME IN ('Pay Value')) c
          WHERE a.assignment_action_id = b.assignment_action_id
            AND a.run_result_id = c.run_result_id
            AND b.start_date =  trunc(p_start_date, 'MM') + 15 /* 5.0.1 */ --Should be reported on 2PP only
            ;

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
            'Error out of get_1PP_ISR_subsidy_bal -' || SQLERRM);
   END;
   /* 5.0.1  End */
   FUNCTION cvt_char (p_text VARCHAR2)
      RETURN VARCHAR2
   AS
      v_text   VARCHAR2 (150);
   BEGIN
--      SELECT REPLACE (
--                TRANSLATE (
--                   CONVERT (TRIM (p_text) || ' ',            --'WE8ISO8859P1',
--                                                             --'WE8ISO8859P9',
--                    'WE8MSWIN1252', 'UTF8'),
--                   '&:;'''',"??%^??#?',
--                   '&'),
--                '&',
--                '')

        --SELECT ttec_library.remove_non_ascii (TRIM(TRANSLATE( CONVERT (TRIM (p_text) || ' ','WE8MSWIN1252', 'UTF8'),'???~!@#$%^&*()+{}|:"<>?=[]\/".',' ' )))
      SELECT ttec_library.remove_non_ascii (TRIM(TRANSLATE( TRIM (p_text),'???~!@#$%^&*()+{}|:"<>?=[]\/".',' ' )))  -- commented out for error en generación CFDi de Cliente, Error: NOM154
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

--          --Fnd_File.put_line(Fnd_File.LOG,'Get CNTR name');
--          --Fnd_File.put_line(Fnd_File.LOG,' p_column_name    :'||p_column_name);
--          --Fnd_File.put_line(Fnd_File.LOG,' p_information11  :'||p_information11);
--          --Fnd_File.put_line(Fnd_File.LOG,' p_element_name   :'||p_element_name);
--          --Fnd_File.put_line(Fnd_File.LOG,' p_session_date   :'||p_session_date);

      IF p_element_name = 'ISR Subsidy for Employment' THEN

         SELECT pucif.VALUE
           INTO l_value
           FROM pay_user_tables put,
                pay_user_columns puc,
                pay_user_rows_f pur,
                pay_user_column_instances_f pucif
          WHERE     put.user_table_name = 'TTEC_MEXICO_SAT_CODES'
                AND puc.user_column_name = 'Other Payment Type'
                AND pur.row_low_range_or_name = p_element_name
                AND put.user_table_id = puc.user_table_id
                AND put.user_table_id = puc.user_table_id
                AND pucif.user_row_id = pur.user_row_id(+)
                AND puc.user_column_id = pucif.user_column_id(+)
                AND p_session_date BETWEEN pur.effective_start_date(+)
                                       AND pur.effective_end_date(+)
                AND p_session_date BETWEEN pucif.effective_start_date(+)
                                       AND pucif.effective_end_date(+);

          --Fnd_File.put_line(Fnd_File.LOG,'Get CNTR code Section I ');
          --Fnd_File.put_line(Fnd_File.LOG,'Return Value :'||l_value);


      ELSIF p_information11 IS NULL
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

          --Fnd_File.put_line(Fnd_File.LOG,'Get CNTR Name Section II ');
          --Fnd_File.put_line(Fnd_File.LOG,'Return Value :'||l_value);
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

          --Fnd_File.put_line(Fnd_File.LOG,'Return Reporting Name - counter part' );
          --Fnd_File.put_line(Fnd_File.LOG,'Return Value :'||l_value);

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

--          --Fnd_File.put_line(Fnd_File.LOG,'Get CNTR code');
--          --Fnd_File.put_line(Fnd_File.LOG,'   p_column_name :'||p_column_name);
--          --Fnd_File.put_line(Fnd_File.LOG,'p_information11  :'||p_information11);
--          --Fnd_File.put_line(Fnd_File.LOG,' p_element_name  :'||p_element_name);
--          --Fnd_File.put_line(Fnd_File.LOG,' p_session_date  :'||p_session_date);

      IF p_element_name = 'ISR Subsidy for Employment' THEN

         SELECT pucif.VALUE
           INTO l_value
           FROM pay_user_tables put,
                pay_user_columns puc,
                pay_user_rows_f pur,
                pay_user_column_instances_f pucif
          WHERE     put.user_table_name = 'TTEC_MEXICO_SAT_CODES'
                AND puc.user_column_name = 'Other Payment Type'
                AND pur.row_low_range_or_name = p_element_name
                AND put.user_table_id = puc.user_table_id
                AND put.user_table_id = puc.user_table_id
                AND pucif.user_row_id = pur.user_row_id(+)
                AND puc.user_column_id = pucif.user_column_id(+)
                AND p_session_date BETWEEN pur.effective_start_date(+)
                                       AND pur.effective_end_date(+)
                AND p_session_date BETWEEN pucif.effective_start_date(+)
                                       AND pucif.effective_end_date(+);

--          --Fnd_File.put_line(Fnd_File.LOG,'Get CNTR code Section I ');
--          --Fnd_File.put_line(Fnd_File.LOG,'Return Value :'||l_value);


      ELSIF p_information11 IS NULL
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

--          --Fnd_File.put_line(Fnd_File.LOG,'Get CNTR code Section II ');
--          --Fnd_File.put_line(Fnd_File.LOG,'Return Value :'||l_value);
      END IF;

      --SELECT SUBSTRB (pucif.VALUE, 1, INSTR (pucif.VALUE, '-') - 1)
      SELECT NVL(SUBSTRB (pucif.VALUE, 1, INSTR (pucif.VALUE, '-') - 1),pucif.VALUE)
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
--          --Fnd_File.put_line(Fnd_File.LOG,'Return SAT code - counter part ');
--          --Fnd_File.put_line(Fnd_File.LOG,'Return Value :'||l_result);
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


--          --Fnd_File.put_line(Fnd_File.LOG,'Get SAT code');
--          --Fnd_File.put_line(Fnd_File.LOG,'p_element_name :'||p_element_name);
--          --Fnd_File.put_line(Fnd_File.LOG,'p_information_category  :'||p_information_category);
--          --Fnd_File.put_line(Fnd_File.LOG,'p_information11  :'||p_information11);
--          --Fnd_File.put_line(Fnd_File.LOG,'p_session_date  :'||p_session_date);

      IF p_element_name like '%ISR%'
         AND p_element_name not like ('1PP%') /* 5.0.1 */
      THEN


          SELECT pucif.VALUE
            INTO l_result
            FROM pay_user_tables put,
                 pay_user_columns puc,
                 pay_user_rows_f pur,
                 pay_user_column_instances_f pucif
           WHERE     put.user_table_name = 'TTEC_MEXICO_SAT_CODES'
                 AND puc.user_column_name = 'Other Payment Type'
                 AND pur.row_low_range_or_name = 'ISR Subsidy for Employment'
                 AND put.user_table_id = puc.user_table_id
                 AND put.user_table_id = puc.user_table_id
                 AND pucif.user_row_id = pur.user_row_id(+)
                 AND puc.user_column_id = pucif.user_column_id(+)
                 AND p_session_date BETWEEN pur.effective_start_date(+)
                                        AND pur.effective_end_date(+)
                 AND p_session_date BETWEEN pucif.effective_start_date(+)
                                        AND pucif.effective_end_date(+);


--          --Fnd_File.put_line(Fnd_File.LOG,'Get SAT code Section I ');
--          --Fnd_File.put_line(Fnd_File.LOG,'Return Value :'||l_result);

       ELSE



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

--          --Fnd_File.put_line(Fnd_File.LOG,'Get SAT code Section II ');
--          --Fnd_File.put_line(Fnd_File.LOG,'Return Value :'||l_result);
        END IF;



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

--          --Fnd_File.put_line(Fnd_File.LOG,'Get SAT code Section III ');
--          --Fnd_File.put_line(Fnd_File.LOG,'Return Value :'||l_result);

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

   FUNCTION get_cfdi_map_code (p_oracle_value            VARCHAR2,
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
       WHERE     put.user_table_name = p_information_category
             AND puc.user_column_name = p_information11
             AND pur.row_low_range_or_name = p_oracle_value
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

   FUNCTION get_ele_name (p_reporting_name VARCHAR2, p_session_date DATE)
      RETURN VARCHAR2
   AS
      l_result   VARCHAR2 (200);
   BEGIN
      l_result := NULL;

      SELECT pur.row_low_range_or_name
        INTO l_result
        FROM pay_user_tables put,
             pay_user_columns puc,
             pay_user_rows_f pur,
             pay_user_column_instances_f pucif
       WHERE     put.user_table_name = 'TTEC_MEXICO_SAT_CODES'
             AND puc.user_column_name = 'Reporting Name'
             --AND pur.row_low_range_or_name = p_element_name
             AND pucif.VALUE = p_reporting_name
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

   FUNCTION get_costing_info (p_payroll_id NUMBER,p_element_name VARCHAR2, p_session_date DATE)
      RETURN VARCHAR2
   AS
      l_result   VARCHAR2 (200);
   BEGIN
      l_result := NULL;

         SELECT pcak1.segment4
           INTO l_result
          FROM pay_element_links_f pel,
               apps.pay_cost_allocation_keyflex pcak1,
               apps.pay_cost_allocation_keyflex pcak2,
               pay_element_types_f pet,
              -- pay_payrolls_f ppf,
               pay_element_classifications pec
         WHERE pel.element_type_id = pet.element_type_id
           --AND pel.payroll_id = ppf.payroll_id
           AND pcak1.cost_allocation_keyflex_id(+) = pel.cost_allocation_keyflex_id
           AND pcak2.cost_allocation_keyflex_id(+) = pel.balancing_keyflex_id
           AND (pet.business_group_id = 1633 OR pet.legislation_code = 'MX')
           --AND ppf.payroll_id = p_payroll_id
           AND (   pel.payroll_id IS NULL
                OR (    pel.payroll_id IS NOT NULL
                    AND pel.payroll_id = p_payroll_id)
                )
           AND pet.element_name = p_element_name
           AND pet.classification_id = pec.classification_id
           --AND p_session_date BETWEEN ppf.effective_start_date AND ppf.effective_end_date
           AND p_session_date BETWEEN pet.effective_start_date AND pet.effective_end_date
           AND p_session_date BETWEEN pel.effective_start_date AND pel.effective_end_date;

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
                       p_end_date        IN DATE,
                       p_section         IN VARCHAR2 DEFAULT '' /* 2.4.1*/
   )
      RETURN NUMBER
   AS
      l_result_value   VARCHAR2 (100);
      l_TEMP           VARCHAR2 (100);
   BEGIN

--      Fnd_File.put_line(Fnd_File.LOG,'========================v_module :'||v_module);
--      Fnd_File.put_line(Fnd_File.LOG,'===============   p_element_name :'||p_element_name);
--      Fnd_File.put_line(Fnd_File.LOG,'===============    p_input_value :'||p_input_value);
      IF p_element_name  = 'ISR' and  ( p_class_name = 'Tax Deductions' OR  p_class_name IS NULL)
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
                        AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                        AND UPPER (pec.classification_name) LIKE
                               UPPER (
                                  NVL ('%' || p_class_name || '%',
                                       pec.classification_name))
                        AND UPPER (petf.element_name) like
                               UPPER (
                                  NVL (p_element_name, petf.element_name))) a,
                (SELECT paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                        AND prrv.result_value NOT LIKE '%-%' -- restricted to pickup negative ISR Value for 2017
                        --AND pivf.NAME like p_input_value) c
                        AND upper(pivf.NAME) like upper(p_input_value)) c
          WHERE a.assignment_action_id = b.assignment_action_id
                AND a.run_result_id = c.run_result_id;

--          Fnd_File.put_line(Fnd_File.LOG,'Get Value code Section I ');
--          Fnd_File.put_line(Fnd_File.LOG,'Return Value :'||l_result_value);

      ELSIF p_element_name not in ('ISR','ISR Subsidy for Employment') and p_class_name = 'Tax Credit'
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
                        AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                        AND UPPER (pec.classification_name) LIKE
                               UPPER (
                                  NVL ('%' || p_class_name || '%',
                                       pec.classification_name))
                        AND UPPER (petf.element_name) like
                               UPPER (
                                  NVL (p_element_name, petf.element_name))) a,
                (SELECT paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                        --AND pivf.NAME like p_input_value) c
                        AND upper(pivf.NAME) like upper(p_input_value)) c
          WHERE a.assignment_action_id = b.assignment_action_id
                AND a.run_result_id = c.run_result_id;

      ELSE

--         SELECT A.ELEMENT_NAME,NVL (SUM (TO_NUMBER (ABS (result_value))), 0)
--           INTO L_TEMP,l_result_value
         SELECT NVL (SUM (TO_NUMBER (ABS (result_value))), 0)
           INTO l_result_value
           FROM (SELECT prr.run_result_id, prr.assignment_action_id,petf.element_name,
                        LPAD (petf.element_information11, 3, '0') sat_code,
                        petf.element_type_id, petf.reporting_name
                   FROM apps.pay_run_results prr,
                        apps.pay_element_types_f petf,
                        apps.pay_element_classifications pec
                  WHERE prr.element_type_id = petf.element_type_id
                        AND petf.classification_id = pec.classification_id
                        AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                        AND UPPER (pec.classification_name) LIKE
                               UPPER (
                                  NVL ('%' || p_class_name || '%',
                                       pec.classification_name))
                        AND UPPER (petf.element_name) like
                               UPPER (
                                  NVL (p_element_name, petf.element_name))) a,
                (SELECT paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                        AND upper(pivf.NAME) like upper(p_input_value)) c
          WHERE a.assignment_action_id = b.assignment_action_id
                AND a.run_result_id = c.run_result_id
                AND (   ( p_section = '[Positive Amount]' AND result_value NOT LIKE '%-%')
                     OR ( p_section = '[Negative Amount]' AND result_value LIKE '%-%')
                     OR ( p_section = '')
                     )
                AND (    (v_module  in ('[A.7]','[E]','[D]','[D.5]') AND  a.element_name not in ('ISR','ISR Subsidy for Employment'))
                      OR
                         (v_module  = '[A.8]' AND  a.element_name = 'ISR Subsidy for Employment' AND c.result_value LIKE '%-%'  )
                      OR  v_module  not in ('[A.7]','[E]','[D]','[D.5]','[A.8]')
                     );
--          GROUP BY A.ELEMENT_NAME  ;

--          Fnd_File.put_line(Fnd_File.LOG,'Get Value code Section III ');
--          Fnd_File.put_line(Fnd_File.LOG,'Return Value :'||l_result_value);
--          Fnd_File.put_line(Fnd_File.LOG,'   p_section :'||p_section);

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
                     AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                     AND UPPER (pec.classification_name) LIKE
                            UPPER (
                               NVL ('%' || p_class_name || '%',
                                    pec.classification_name))
                     --AND petf.element_name <> 'ISR' /* commented out for 2.5.1 */
                     AND petf.element_name not in ( 'ISR', 'Annual Tax Adjustment') /* 2.5.1 */
                     AND UPPER (petf.element_name) like
                            UPPER (NVL (p_element_name, petf.element_name))) a,
             (SELECT paa.assignment_action_id, ppa.date_earned,
                     ppa.effective_date, ptp.start_date, ptp.end_date
                FROM apps.pay_assignment_actions paa,
                     apps.pay_payroll_actions ppa,
                     --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
					 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                     --AND pivf.NAME = p_input_value) c
                     AND upper(pivf.NAME) LIKE UPPER(p_input_value)) c
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
                             AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                             AND petf.classification_id =
                                    pec.classification_id
                             AND pec.classification_name LIKE
                                    '%' || p_class_name || '%'
                             AND UPPER (petf.element_name) like
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
                                   --  'MX_GROSERY_COUPONS', -- 1.10 /* Mar 22 change Grosery Coupon */
                                     'MX_ML_SICKNESS Pending',
                                     'MX_ML_MATERNITY Pending')) a,
                     (SELECT paa.assignment_action_id, ppa.date_earned,
                             ppa.effective_date, ptp.start_date, ptp.end_date
                        FROM apps.pay_assignment_actions paa,
                             apps.pay_payroll_actions ppa,
                             --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
							 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                             AND UPPER(pivf.NAME) like NVL (UPPER(p_input_value), UPPER(pivf.NAME))) c
               WHERE a.assignment_action_id = b.assignment_action_id
                     AND a.run_result_id = c.run_result_id
/* 1.11 Begin */
--              UNION
--              SELECT TO_NUMBER (c.result_value), a.run_result_id
--                FROM (SELECT prr.run_result_id, prr.assignment_action_id,
--                             petf.element_information11, petf.element_type_id,
--                             petf.reporting_name, petf.element_name,
--                             'E' ear_ded, petf.element_information_category
--                        FROM apps.pay_run_results prr,
--                             apps.pay_element_types_f petf,
--                             apps.pay_element_classifications pec
--                       WHERE prr.element_type_id = petf.element_type_id
--                             AND petf.classification_id =
--                                    pec.classification_id
--                             AND pec.classification_name IN ('Tax Credit')
--                             AND UPPER (petf.element_name) =
--                                    UPPER (
--                                       NVL (p_element_name,
--                                            petf.element_name))) a,
--                     (SELECT paa.assignment_action_id, ppa.date_earned,
--                             ppa.effective_date, ptp.start_date, ptp.end_date
--                        FROM apps.pay_assignment_actions paa,
--                             apps.pay_payroll_actions ppa,
--                             hr.per_all_assignments_f paaf,
--                             apps.per_time_periods ptp
--                       WHERE ppa.payroll_action_id = paa.payroll_action_id
--                             AND paa.assignment_id = paaf.assignment_id
--                             AND paaf.primary_flag = 'Y'
--                             AND paaf.assignment_id = p_assignment_id
--                             AND ptp.payroll_id = ppa.payroll_id
--                             AND ptp.regular_payment_date =
--                                    ppa.effective_date
--                             AND ppa.date_earned BETWEEN paaf.effective_start_date
--                                                     AND paaf.effective_end_date
--                             AND ppa.effective_date BETWEEN p_start_date
--                                                        AND p_end_date) b,
--                     (SELECT prrv.run_result_id, prrv.result_value
--                        FROM apps.pay_input_values_f pivf,
--                             apps.pay_run_result_values prrv
--                       WHERE     pivf.input_value_id = prrv.input_value_id
--                             AND prrv.result_value <> '0'
--                             --AND prrv.result_value NOT LIKE '%-%'
--                             AND pivf.NAME IN ('Pay Value')) c
--               WHERE a.assignment_action_id = b.assignment_action_id
--                     AND a.run_result_id = c.run_result_id
/* 1.11 End */
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
                             AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                             AND petf.classification_id =
                                    pec.classification_id
                             AND pec.classification_name IN
                                    ('Non-payroll Payments')
                             AND petf.element_name NOT IN  -- 1.4
                                    ('MX_SF_COMPANY_LIQ',  -- 1.4
                                     'MX_SF_LIQUIDATION')  -- 1.4
                             AND UPPER (petf.element_name) like
                                    UPPER (
                                       NVL (p_element_name,
                                            petf.element_name))) a,
                     (SELECT paa.assignment_action_id, ppa.date_earned,
                             ppa.effective_date, ptp.start_date, ptp.end_date
                        FROM apps.pay_assignment_actions paa,
                             apps.pay_payroll_actions ppa,
                             --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
							 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                             AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                             AND petf.classification_id =
                                    pec.classification_id
                             AND pec.classification_name IN ('Amends')
                             AND UPPER (petf.element_name) like
                                    UPPER (
                                       NVL (p_element_name,
                                            petf.element_name))) a,
                     (SELECT paa.assignment_action_id, ppa.date_earned,
                             ppa.effective_date, ptp.start_date, ptp.end_date
                        FROM apps.pay_assignment_actions paa,
                             apps.pay_payroll_actions ppa,
                             --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
							 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                     AND a.run_result_id = c.run_result_id);

/* 1.11 Begin */
--              UNION
--              SELECT TO_NUMBER (c.result_value) result_value, a.run_result_id
--                FROM (SELECT prr.run_result_id, prr.assignment_action_id,
--                             petf.element_information11, petf.element_type_id,
--                             petf.reporting_name, petf.element_name,
--                             petf.element_information_category, 'D' ear_ded
--                        FROM apps.pay_run_results prr,
--                             apps.pay_element_types_f petf,
--                             apps.pay_element_classifications pec
--                       WHERE prr.element_type_id = petf.element_type_id
--                             AND petf.classification_id =
--                                    pec.classification_id
--                             AND pec.classification_name LIKE '%Deduction%'
--                             AND petf.element_name <> 'ISR'
--                             AND UPPER (petf.element_name) =
--                                    UPPER (
--                                       NVL (p_element_name,
--                                            petf.element_name))) a,
--                     (SELECT paa.assignment_action_id, ppa.date_earned,
--                             ppa.effective_date, ptp.start_date, ptp.end_date
--                        FROM apps.pay_assignment_actions paa,
--                             apps.pay_payroll_actions ppa,
--                             hr.per_all_assignments_f paaf,
--                             apps.per_time_periods ptp
--                       WHERE ppa.payroll_action_id = paa.payroll_action_id
--                             AND paa.assignment_id = paaf.assignment_id
--                             AND paaf.primary_flag = 'Y'
--                             AND paaf.assignment_id = p_assignment_id
--                             AND ptp.payroll_id = ppa.payroll_id
--                             AND ptp.regular_payment_date =
--                                    ppa.effective_date
--                             AND ppa.date_earned BETWEEN paaf.effective_start_date
--                                                     AND paaf.effective_end_date
--                             AND ppa.effective_date BETWEEN p_start_date
--                                                        AND p_end_date) b,
--                     (SELECT prrv.run_result_id, prrv.result_value
--                        FROM apps.pay_input_values_f pivf,
--                             apps.pay_run_result_values prrv
--                       WHERE     pivf.input_value_id = prrv.input_value_id
--                             AND prrv.result_value LIKE '%-%'
--                             AND pivf.NAME IN ('Pay Value')) c
--               WHERE a.assignment_action_id = b.assignment_action_id
--                     AND a.run_result_id = c.run_result_id);
/* 1.11 End */


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
                             AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                             AND petf.classification_id =
                                    pec.classification_id
                             AND UPPER (petf.element_name) like
                                    UPPER (
                                       NVL (p_element_name,
                                            petf.element_name))
                             AND pec.classification_name LIKE
                                    '%' || p_class_name || '%') a,
                     (SELECT paa.assignment_action_id, ppa.date_earned,
                             ppa.effective_date, ptp.start_date, ptp.end_date
                        FROM apps.pay_assignment_actions paa,
                             apps.pay_payroll_actions ppa,
                             --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
							 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                             AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                             AND petf.classification_id =
                                    pec.classification_id
                             AND petf.element_name = 'ISR'
                             AND UPPER (petf.element_name) like
                                    UPPER (
                                       NVL (p_element_name,
                                            petf.element_name))
                             AND pec.classification_name LIKE
                                    '%' || p_class_name || '%') a,
                     (SELECT paa.assignment_action_id, ppa.date_earned,
                             ppa.effective_date, ptp.start_date, ptp.end_date
                        FROM apps.pay_assignment_actions paa,
                             apps.pay_payroll_actions ppa,
                             --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
							 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                             --AND prrv.result_value LIKE '%-%' --Commented out for 2017 format
                             AND prrv.result_value NOT LIKE '%-%' --Added this not to pickup negative amount for ISR for 2017
                             AND pivf.NAME IN ('Pay Value')) c
               WHERE a.assignment_action_id = b.assignment_action_id
                     AND a.run_result_id = c.run_result_id
              UNION /* 2.4.7  begin */
              SELECT ABS(TO_NUMBER (c.result_value)) result_value, a.run_result_id
                FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                        petf.element_information11, petf.element_type_id,
                        petf.reporting_name, petf.element_name, 'D' ear_ded,
                        petf.element_information_category
                   FROM apps.pay_run_results prr,
                        apps.pay_element_types_f petf,
                        apps.pay_element_classifications pec
                  WHERE prr.element_type_id = petf.element_type_id
                        AND petf.classification_id = pec.classification_id
                        AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE
                        AND pec.classification_name = 'Tax Credit'
                        AND petf.element_name = 'ISR Subsidy for Employment') a,
                (SELECT ppa.payroll_id, paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
              UNION  /* 2.4.7  end */
              SELECT ABS (c.result_value) result_value, a.run_result_id
                FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                             petf.element_information11, petf.element_type_id,
                             petf.reporting_name, petf.element_name,
                             'E' ear_ded, petf.element_information_category
                        FROM apps.pay_run_results prr,
                             apps.pay_element_types_f petf,
                             apps.pay_element_classifications pec
                       WHERE prr.element_type_id = petf.element_type_id
                             AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                             AND petf.classification_id =
                                    pec.classification_id
                             AND pec.classification_name LIKE '%Earning%'
                             AND UPPER (petf.element_name) like
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
                             --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
							 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                             AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                             AND petf.classification_id =
                                    pec.classification_id
                             AND UPPER (petf.element_name) like
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
                                    -- 'MX_GROSERY_COUPONS', -- 1.10 /* Mar 22 change Grosery Coupon */
                                     'MX_ML_SICKNESS Pending',
                                     'MX_ML_MATERNITY Pending')) a,
                     (SELECT paa.assignment_action_id, ppa.date_earned,
                             ppa.effective_date, ptp.start_date, ptp.end_date
                        FROM apps.pay_assignment_actions paa,
                             apps.pay_payroll_actions ppa,
                             --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
							 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                             --AND UPPER (pivf.NAME) IN ('ISR SUBJECT')
                             AND UPPER (pivf.NAME) IN ('ISR SUBJECT'
                                                      ,'PAY VALUE') /*2.4.2 */
                             ) c
               WHERE a.assignment_action_id = b.assignment_action_id
                     AND a.run_result_id = c.run_result_id
              UNION    -- --1.3
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
                             AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                             AND petf.classification_id =
                                                         pec.classification_id
                             AND pec.classification_name LIKE '%Information%') a,
                         (SELECT paa.assignment_action_id, ppa.date_earned,
                                 ppa.effective_date, ptp.start_date,
                                 ptp.end_date
                            FROM apps.pay_assignment_actions paa,
                                 apps.pay_payroll_actions ppa,
                                 hr_lookups lo1,
                                 --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
								 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                             AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
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
                                 --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
								 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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

/*                              -- 1.2 Kaushik
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

   FUNCTION get_subsidy_value (p_total_earning  VARCHAR2,
                               p_session_date   DATE
   )
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
       WHERE     put.user_table_name = 'ISR Subsidy for Empl_Month'
             AND puc.user_column_name = 'Amount'
             AND p_total_earning >= pur.row_low_range_or_name
             and p_total_earning <= pur.ROW_HIGH_RANGE
             AND put.user_table_id = puc.user_table_id
             AND put.user_table_id = puc.user_table_id
             AND pucif.user_row_id = pur.user_row_id(+)
             AND puc.user_column_id = pucif.user_column_id(+)
             AND trunc(SYSDATE) BETWEEN pur.effective_start_date(+)
                                    AND pur.effective_end_date(+)
             AND trunc(SYSDATE) BETWEEN pucif.effective_start_date(+)
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

   PROCEDURE main_proc (errbuf                  OUT VARCHAR2,
                        retcode                 OUT NUMBER,
                        p_output_directory   IN     VARCHAR2,
                        p_start_date         IN     VARCHAR2,
                        p_end_date           IN     VARCHAR2,
                        p_payroll_id         IN     NUMBER,
                        p_employee_number    IN     VARCHAR2,
                        p_pay_date           IN     VARCHAR2,
                        p_profit_sharing_payout     IN     VARCHAR2
                        )
   IS

--      CURSOR c_emp_rec (
--         p_cut_off_date        DATE,
--         p_current_run_date    DATE,
--         p_profit_sharing      VARCHAR2
--         )
--      IS
--           SELECT (date_start) date_start,
--                  (NVL (actual_termination_date, p_current_run_date)) actual_termination_date,
--                  person_id
--             FROM per_periods_of_service ppos
--            WHERE business_group_id = 1633
--            --AND ppos.person_id = 1199493
--            and p_current_run_date between ppos.DATE_START and NVL (actual_termination_date, p_current_run_date)
--                  AND ppos.person_id IN  /* 1.6 */
--                                  (SELECT DISTINCT papf.person_id
--                                     FROM per_all_people_f papf
--                                    WHERE papf.employee_number = NVL(p_employee_number,papf.employee_number)
--                                    AND ppos.person_id  = papf.PERSON_ID
--                                      AND business_group_id = 1633)
--                   AND ppos.person_id IN
--                           (
--                             SELECT paaf.person_id
--                               FROM apps.pay_assignment_actions paa,
--                                    apps.pay_payroll_actions ppa,
--                                    hr.per_all_assignments_f paaf
--                              WHERE     ppa.payroll_action_id = paa.payroll_action_id
--                                    AND paa.assignment_id = paaf.assignment_id
--                                    AND paaf.PERSON_ID = ppos.person_id
--                                    AND ppa.date_earned BETWEEN paaf.effective_start_date
--                                                            AND paaf.effective_end_date
--                                    AND ppa.date_earned BETWEEN p_cut_off_date AND p_current_run_date
--                           );


/* 2.2 Begin   */
      CURSOR c_emp_rec (
         p_cut_off_date        DATE,
         p_current_run_date    DATE,
         p_profit_sharing      VARCHAR2
         )
      IS
           SELECT MAX (date_start) date_start,
                  MAX (NVL (actual_termination_date, p_current_run_date)) actual_termination_date,
                  person_id
             FROM per_periods_of_service ppos
            WHERE business_group_id = 1633
                  AND ppos.DATE_START <= p_current_run_date /* 2.4.8 */
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
                             -- (SELECT MAX (actual_termination_date) /* 2.2 */
                                (SELECT MIN (actual_termination_date) /* 2.2 */
                                 FROM per_periods_of_service
                                WHERE person_id = ppos.person_id
                                  AND business_group_id = 1633  --1.5
                                  AND actual_termination_date >= p_current_run_date /* 2.2 */
                                  AND actual_termination_date IS NOT NULL)/* 2.2 */
                           AND ( ( p_profit_sharing = 'N'
                                   AND ppos.actual_termination_date  >= p_cut_off_date)
                                OR
                                  ( p_profit_sharing = 'Y'
                                    AND ppos.actual_termination_date  between to_date('01-JAN-'|| to_char(to_char(p_cut_off_date,'YYYY')- 1))
                                                                          and p_cut_off_date-- 1.5
                                  ) )
                           )
                       OR ppos.person_id IN /* 2.1 Begin */
                           (
                             SELECT paaf.person_id
                               FROM apps.pay_assignment_actions paa,
                                    apps.pay_payroll_actions ppa,
                                    --hr.per_all_assignments_f paaf --code commented by RXNETHI-ARGANO,12/05/23
									apps.per_all_assignments_f paaf --code added by RXNETHI-ARGANO,12/05/23
                              WHERE     ppa.payroll_action_id = paa.payroll_action_id
                                    AND paa.assignment_id = paaf.assignment_id
                                    AND paaf.PERSON_ID = ppos.person_id
                                    and paaf.ASSIGNMENT_STATUS_TYPE_ID = 3 --Terminate Assignment
                                    AND ppa.date_earned BETWEEN paaf.effective_start_date
                                                            AND paaf.effective_end_date
                                    AND ppa.date_earned BETWEEN p_cut_off_date AND p_current_run_date
                           ) /* 2.1 End */
                           )
         --AND ppos.person_id IN (468091,185110)
                  AND ppos.person_id IN  /* 1.6 */
                                  (SELECT DISTINCT papf.person_id
                                     FROM per_all_people_f papf
                                    WHERE papf.employee_number = NVL(p_employee_number,papf.employee_number)
                                    AND ppos.person_id  = papf.PERSON_ID
                                      AND business_group_id = 1633)
                   AND ppos.person_id IN
                           (
                             SELECT paaf.person_id
                               FROM apps.pay_assignment_actions paa,
                                    apps.pay_payroll_actions ppa,
                                    --hr.per_all_assignments_f paaf --code commented by RXNETHI-ARGANO,12/05/23
									apps.per_all_assignments_f paaf --code added by RXNETHI-ARGANO,12/05/23
                              WHERE     ppa.payroll_action_id = paa.payroll_action_id
                                    AND paa.assignment_id = paaf.assignment_id
                                    AND paaf.PERSON_ID = ppos.person_id
                                   -- AND paaf.person_id = 1283539
                                    --and paaf.ASSIGNMENT_STATUS_TYPE_ID = 3 --Terminate Assignment
                                    AND ppa.date_earned BETWEEN paaf.effective_start_date
                                                            AND paaf.effective_end_date
                                    AND ppa.date_earned BETWEEN p_cut_off_date AND p_current_run_date
                           )
         GROUP BY person_id;
/* 2.2 end */

      CURSOR c_emp_info (
         p_person_id                  NUMBER,
         p_actual_termination_date    DATE)
      IS
           --SELECT DISTINCT --paaf.ASS_ATTRIBUTE13 PayrollType,
                           --DECODE(papf.CURRENT_EMPLOYEE_FLAG,'Y','O','E') PayrollType,
           SELECT DISTINCT DECODE( (select papf1.CURRENT_EMPLOYEE_FLAG
                                    from per_all_people_f papf1
                                    where papf1.person_id = papf.person_id
                                    and g_current_run_date + 1 between papf1.EFFECTIVE_START_DATE and papf1.EFFECTIVE_END_DATE),'Y','O','E') PayrollType,
                           ROUND((p_actual_termination_date  - nvl(pps.ADJUSTED_SVC_DATE, pps.date_start))/365,0) length_service,
--                           ROUND(((g_current_run_date + 1 )  - nvl(pps.ADJUSTED_SVC_DATE, pps.date_start))/7,0) length_service_week,
--                           ROUND(((g_current_run_date + 1 )  -  pps.date_start)/7,0) length_service_week,
                           TRUNC(((g_current_run_date + 1 )  -  pps.date_start)/7,0) length_service_week,
                           pps.DATE_START WorkingRelStartDate,
--                           NVL(pps.ADJUSTED_SVC_DATE,pps.DATE_START) WorkingRelStartDate,
                           paaf.ASS_ATTRIBUTE7 PaymentFrequency,
                           ppb.NAME Salary_Basis,
--                           (SELECT meaning
--                            FROM fnd_lookup_values
--                            where lookup_type = 'EMP_CAT'
--                            and lookup_code = PAAf.EMPLOYMENT_CATEGORY
--                            and language = 'US'
--                            and security_group_id = 24
--                            and enabled_flag = 'Y'
--                           ) ContractType,
                           get_cfdi_map_code (paaf.ASS_ATTRIBUTE11           ,
                                             'TTEC_MEXICO_SAT_CODES' ,
                                             'Contract Type'         ,
                                             p_actual_termination_date) ContractType,
                           get_cfdi_map_code (paaf.ASS_ATTRIBUTE7           ,
                                             'TTEC_MEXICO_SAT_CODES' ,
                                              'Working Day Type'         ,
                                             p_actual_termination_date) WorkingDayType,
                           (SELECT meaning
                            FROM fnd_lookup_values
                            where lookup_type = 'EMPLOYEE_CATG'
                            and lookup_code = PAAf.EMPLOYEE_CATEGORY
                            and language = 'US'
                            and security_group_id = 25
                            and enabled_flag = 'Y'
                           ) EMPLOYEE_CATEGORY,
                           ftt.territory_short_name country,
                      --     hgre.org_information1 org_ssn,   commented as part of the change 5.4
                           case when to_date(p_end_date,'YYYY/MM/DD HH24:MI:SS') > '01-Jul-2021' then
                           hgre.org_information1
                           when to_date(p_end_date,'YYYY/MM/DD HH24:MI:SS') < '01-Jul-2021' and hagre.name ='SAB GRE GUADALAJARA TTEC CX SOLUTIONS MEXICO' then
                           'C1228593103'
                           when to_date(p_end_date,'YYYY/MM/DD HH24:MI:SS') < '01-Jul-2021' and hagre.name ='SAB GRE LEON  TTEC CX SOLUTIONS MEXICO' then
                           'B4885467109'
                           when to_date(p_end_date,'YYYY/MM/DD HH24:MI:SS') < '01-Jul-2021' and hagre.name ='SAB GRE MEXICO CITY TTEC CX SOLUTIONS MEXICO' then
                           'Y5831855100'
                           when to_date(p_end_date,'YYYY/MM/DD HH24:MI:SS') < '01-Jul-2021' and hagre.name ='SSI GRE GUADALAJARA TTEC CX SOLUTIONS MEXICO' then
                           'C1228592105'
                           when to_date(p_end_date,'YYYY/MM/DD HH24:MI:SS') < '01-Jul-2021' and hagre.name ='SSI GRE LEON TTEC CX SOLUTIONS MEXICO' then
                           'Z0611022103'
                            when to_date(p_end_date,'YYYY/MM/DD HH24:MI:SS') < '01-Jul-2021' and hagre.name ='SSI GRE MEXICO CITY TTEC CX SOLUTIONS MEXICO' then
                           'Y5831849103'
                            else
                            hgre.org_information1
                            end org_ssn,     -- 5.4
                           paaf.assignment_number, papf.national_identifier,
                           REPLACE (papf.per_information3, '-') ssn_id,
                           paaf.assignment_id,
                           REPLACE (papf.per_information2, '-') rfc_id, -- 1.1
                           NVL (pcak_asg.segment3, pcak_org.segment3) department,
                           pcak_asg.segment2 client,pcaf.Proportion , pcaf.EFFECTIVE_START_DATE,
                           papf.original_date_of_hire,
                           job.NAME job_name, fnd_asg_cat.meaning ass_cat_mean,
                           paaf.ass_attribute7 type_of_work_day,
                           papf.first_name, papf.last_name, papf.full_name,
                           paaf.employment_category, past.user_status,
                           papf.person_id, papf.employee_number,
                           --papf.EMAIL_ADDRESS||';'||papf.ATTRIBUTE1 email_address, /*1.14 */ /* 5.1 */
                           papf.EMAIL_ADDRESS||DECODE( papf.EMAIL_ADDRESS,NULL,'',DECODE(papf.ATTRIBUTE1,NULL,'', ';')) || papf.ATTRIBUTE1 email_address,  /* 5.1 */
                           hla.location_code loc_name,
                           hla.town_or_city ||', '|| (SELECT meaning
                                                 FROM hr_lookups
                                                WHERE lookup_code = hla.region_1
                                                AND LOOKUP_TYPE ='MX_STATE'
                           ) H1_F30,
                           hla.POSTAL_CODE emp_postal_code,
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
--                           DECODE (hla.location_id,  35255, 'GDL',  1547, 'LN',  42776, 'REP') loc_abbrv, /* 4.0 */
--                           DECODE (hla.location_id,  35255, 'JAL',  1547, 'GUA',  42776, 'DIF') StateCode, /* 4.0 */
                          (  SELECT TRIM(description)
                                FROM fnd_lookup_values_vl lv
                               WHERE lookup_type = 'TTEC_MEX_CFDI_LOC_ABBRV'
                                 AND lookup_code = hla.location_id
                                 AND (view_application_id = 3)
                                 AND (security_group_id = 25)
                                 and p_actual_termination_date between lv.START_DATE_ACTIVE and NVL(lv.END_DATE_ACTIVE,'31-DEC-4712')
                                 AND ROWNUM < 2
                          ) loc_abbrv, /* 4.0 */
                          (  SELECT TRIM(description)
                                FROM fnd_lookup_values_vl lv
                               WHERE lookup_type = 'TTEC_MEX_CFDI_STATECODE'
                                 AND lookup_code = hla.location_id
                                 AND (view_application_id = 3)
                                 AND (security_group_id = 25)
                                 and p_actual_termination_date between lv.START_DATE_ACTIVE and NVL(lv.END_DATE_ACTIVE,'31-DEC-4712')
                                 AND ROWNUM < 2
                          ) StateCode, /* 4.0 */
                           DECODE (paaf.payroll_id,  420, 2101,  421, 6902) employer_acc,
                           pad.postal_code
             /*
			 START R12.2 Upgrade Remediation
			 code commented by RXNETHI-ARGANO,12/05/23
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
                  apps.per_all_people_f papfcost
				  */
			 --code added by RXNETHI-ARGANO,12/05/23
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
                  AND ROWNUM < 2
                  ORDER BY pcaf.Proportion desc, pcaf.EFFECTIVE_START_DATE;

      CURSOR c_ded_element (
         p_assignment_id    NUMBER,
         p_start_date       DATE,
         p_end_date         DATE,
         p_class_name       VARCHAR2)
      IS
         SELECT DISTINCT 'Q1 Deduction' section,
                b.effective_date,
                b.start_date,
                b.end_date,
                LPAD (NVL (a.element_information11,
                           get_sat_code (a.element_name,
                                         a.element_information_category,
                                         lpad(a.element_information11,3,'0'),/* 2.4.2 */
                                         p_start_date)),
                      3,
                      '0')
                   sat_code,
                a.element_type_id,
                get_costing_info (b.payroll_id ,a.element_name, p_start_date) costing,
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
                        AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                        AND petf.element_name != 'ISR' /* 5.0.6 */
                        AND pec.classification_name LIKE
                               '%' || p_class_name || '%') a,
                (SELECT ppa.payroll_id, paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
         UNION /* below section is added for 2017 */
         SELECT DISTINCT 'Q2 Deduction' section,
                b.effective_date,
                b.start_date,
                b.end_date,
                LPAD ( get_cntr_code ('Tax Counterpart - ISR Subsidy', --'Other Payment Counterpart',
                                     a.element_information11,
                                     a.element_name,
                                     p_start_date ),
                      3,
                      0)
                   sat_code,
                         a.element_type_id,
                         get_costing_info (b.payroll_id ,a.element_name,p_start_date ) costing,
--                               get_costing_info (b.payroll_id , get_ele_name (get_cntr_name ('Other Payment Counterpart',
--                               a.element_information11,
--                               a.element_name,
--                               p_start_date),p_start_date),p_start_date ) costing,
                               --get_cntr_name ('Other Payment Counterpart',
                               get_cntr_name ('Tax Counterpart - ISR Subsidy',
                               lpad(a.element_information11,3,'0'),/* 2.4.2 */
                               a.element_name,
                               p_start_date) reporting_name,
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
                        AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
--                        AND pec.classification_name LIKE
--                               '%' || p_class_name || '%') a,
                        AND pec.classification_name = 'Tax Credit'
                        AND petf.element_name = 'ISR Subsidy for Employment') a,
                (SELECT ppa.payroll_id, paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
-- for 2017 moving ISR to FA for negative amount, positive amount stay here
--         UNION
--         SELECT DISTINCT
--                b.effective_date,
--                b.start_date,
--                b.end_date,
--                LPAD (NVL (a.element_information11,
--                           get_sat_code (a.element_name,
--                                         a.element_information_category,
--                                         a.element_information11,
--                                         p_start_date)),
--                      3,
--                      '0')
--                   sat_code,
--                a.element_type_id,
--                get_costing_info (b.payroll_id ,a.element_name, p_start_date) costing,
--                NVL (get_rep_name (a.element_name, p_start_date),
--                     a.reporting_name)
--                   reporting_name,
--                a.element_name,
--                a.ear_ded,
--                get_amount (TO_NUMBER (c.result_value)) ele_amt,
--                NULL run_result_id
--           FROM (SELECT prr.run_result_id, prr.assignment_action_id,
--                        petf.element_information11, petf.element_type_id,
--                        petf.reporting_name, petf.element_name, 'D' ear_ded,
--                        petf.element_information_category
--                   FROM apps.pay_run_results prr,
--                        apps.pay_element_types_f petf,
--                        apps.pay_element_classifications pec
--                  WHERE prr.element_type_id = petf.element_type_id
--                        AND petf.classification_id = pec.classification_id
--                        AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
--                        AND pec.classification_name LIKE
--                               '%' || p_class_name || '%'
--                        AND petf.element_name = 'ISR') a,
--                (SELECT ppa.payroll_id, paa.assignment_action_id, ppa.date_earned,
--                        ppa.effective_date, ptp.start_date, ptp.end_date
--                   FROM apps.pay_assignment_actions paa,
--                        apps.pay_payroll_actions ppa,
--                        hr.per_all_assignments_f paaf,
--                        apps.per_time_periods ptp
--                  WHERE     ppa.payroll_action_id = paa.payroll_action_id
--                        AND paa.assignment_id = paaf.assignment_id
--                        AND paaf.primary_flag = 'Y'
--                        AND paaf.assignment_id = p_assignment_id
--                        AND ptp.payroll_id = ppa.payroll_id
--                        AND ptp.regular_payment_date = ppa.effective_date
--                        AND ppa.date_earned BETWEEN paaf.effective_start_date
--                                                AND paaf.effective_end_date
--                        AND ppa.effective_date BETWEEN p_start_date
--                                                   AND p_end_date) b,
--                (SELECT prrv.run_result_id, prrv.result_value
--                   FROM apps.pay_input_values_f pivf,
--                        apps.pay_run_result_values prrv
--                  WHERE     pivf.input_value_id = prrv.input_value_id
--                        AND prrv.result_value <> '0'
--                        AND prrv.result_value LIKE '%-%' -- commented out for 2017
--                        --AND prrv.result_value NOT LIKE '%-%' -- restricted to pickup p
--                        AND pivf.NAME IN ('Pay Value')) c
--          WHERE a.assignment_action_id = b.assignment_action_id
--                AND a.run_result_id = c.run_result_id
         UNION
--         SELECT DISTINCT b.effective_date, b.start_date, b.end_date, /* to group severance pay in one line */
         SELECT         'Q3 Deduction' section, b.effective_date, b.start_date, b.end_date,
                         LPAD (SUBSTRB (a.meaning, 1, INSTR (a.meaning, '-') - 2), 3, '0') sat_code,
                         a.element_type_id,
                         get_costing_info (b.payroll_id ,a.element_name, p_start_date) costing,
                         a.reporting_name, a.element_name,
                         a.ear_ded,
--                         get_amount (ABS (TO_NUMBER (c.result_value))) ele_amt,
--                         a.run_result_id
                         get_amount (ABS (SUM(TO_NUMBER (c.result_value)))) ele_amt,
                         NULL run_result_id
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
                        AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                        AND pec.classification_name LIKE '%Earning%'
                        AND flv.LANGUAGE = 'US'
                        --and flv.security_group_id = 25
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
                            --    'MX_OVERPAID_SALARY', --1.8 /* 6.0 */
                                'MX_ML_WORK_RISK Pending',
                                'MX_ML_SICKNESS Pending',
                                'MX_ML_MATERNITY Pending')) a,
                (SELECT ppa.payroll_id, paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
         GROUP BY b.effective_date, b.start_date, b.end_date,
                         LPAD (SUBSTRB (a.meaning, 1, INSTR (a.meaning, '-') - 2), 3, '0') ,
                         a.element_type_id,
                         get_costing_info (b.payroll_id ,a.element_name, p_start_date),
                         a.reporting_name, a.element_name,
                         a.ear_ded, NULL
         UNION
         SELECT DISTINCT 'Q4 Deduction' section,
                b.effective_date,
                b.start_date,
                b.end_date,
                --LPAD (get_cntr_code ('Perception Counterpart', /* 2.4.2 */
                LPAD (get_cntr_code ('Deduction Counterpart', /* 2.4.2 */
                                    -- lpad(a.element_information11,3,'0'),/* 2.4.2 *//* 3.3 commented out */
                                     LPAD (SUBSTRB (a.meaning, 1, INSTR (a.meaning, '-') - 2), 3, '0') , /* 3.3 */
                                     a.element_name,
                                     p_start_date),
                      3,
                      0)
                   sat_code,
                a.element_type_id,
                get_costing_info (b.payroll_id ,a.element_name, p_start_date) costing,
                --get_cntr_name ('Perception Counterpart',/* 2.4.2 */
                get_cntr_name ('Deduction Counterpart', /* 2.4.2 */
                               --lpad(a.element_information11,3,'0'),/* 2.4.2 */ /* 3.3 commented out */
                               LPAD (SUBSTRB (a.meaning, 1, INSTR (a.meaning, '-') - 2), 3, '0') , /* 3.3 */
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
                        flv.meaning, /* 3.3 */
                        'E' ear_ded
                   FROM apps.pay_run_results prr,
                        apps.pay_element_types_f petf,
                        apps.pay_element_classifications pec
                      , apps.fnd_lookup_values flv /* 3.3 */
                  WHERE     prr.element_type_id = petf.element_type_id
                        AND petf.classification_id = pec.classification_id
                        AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                        AND pec.classification_name LIKE '%Earning%'
                        AND flv.LANGUAGE = 'US' /* 3.3 begin */
                        AND flv.lookup_code = petf.element_information11
                        AND flv.lookup_type =
                               DECODE (
                                  petf.element_information_category,
                                  'MX_SUPPLEMENTAL EARNINGS', 'MX_PAYSLIP_EARNING_CODES',
                                  'MX_IMPUTED EARNINGS', 'MX_PAYSLIP_EARNING_CODES',
                                  'MX_EARNINGS', 'MX_PAYSLIP_EARNING_CODES') /* 3.3 end */
                        AND petf.element_name NOT IN
                               ('MX_ML_WORK_RISK',
                                'MX_ML_SICKNESS',
                                'MX_ML_MATERNITY',
                                'MX_NCNS',                                --1.3
                                'MX_NCNS Pending', --1.3
                                'MX_SUSPENSION', --1.8
                                'MX_NO_PAY_AUT_LEAVE', --1.8
                              --  'MX_OVERPAID_SALARY', --1.8 /* 6.0 */
                               -- 'MX_GROSERY_COUPONS', -- 1.10 /* Mar 22 change Grosery Coupon */
                                'MX_ML_WORK_RISK Pending',
                                'MX_ML_SICKNESS Pending',
                                'MX_ML_MATERNITY Pending')) a,
                (SELECT ppa.payroll_id, paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                        --AND UPPER (pivf.NAME) IN ('ISR SUBJECT')) c /*2.4.2 */
                        AND UPPER (pivf.NAME) IN ('ISR SUBJECT'
                                                  ,'PAY VALUE' /*2.4.2 */
                        )) c
          WHERE a.assignment_action_id = b.assignment_action_id
                AND a.run_result_id = c.run_result_id
          UNION /* --1.3 */
                   SELECT DISTINCT 'Q5 Deduction' section,b.effective_date, b.start_date, b.end_date,
                         LPAD
                            (NVL
                                (a.element_information11,
                                 get_sat_code (a.element_name,
                                               a.element_information_category,
                                               lpad(a.element_information11,3,'0'),/* 2.4.2 */
                                               p_start_date
                                              )
                                ),
                             3,
                             '0'
                            ) sat_code,
                         a.element_type_id,
                         get_costing_info (b.payroll_id ,a.element_name, p_start_date) costing,
                         NVL (get_information (a.element_name, p_start_date),
                              a.reporting_name
                             ) reporting_name,
                         a.element_name, a.ear_ded,
                         get_amount (get_value (a.element_name,
                                                'Information',
                                                'Pay Value',
                                                p_assignment_id,
                                                p_start_date,
                                                p_end_date,
                                                '[Positive Amount]'/* 2.4.1 */
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
                             AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                             AND petf.classification_id =
                                                         pec.classification_id
                             AND pec.classification_name LIKE '%Information%') a,
                         (SELECT ppa.payroll_id, paa.assignment_action_id, ppa.date_earned,
                                 ppa.effective_date, ptp.start_date,
                                 ptp.end_date
                            FROM apps.pay_assignment_actions paa,
                                 apps.pay_payroll_actions ppa,
                                 hr_lookups lo1,
                                 --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
								 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                  SELECT DISTINCT 'Q6 Deduction' section,b.effective_date, b.start_date, b.end_date,
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
                                     lpad(a.element_information11,3,'0'),/* 2.4.2 */
                                     a.element_name,
                                     p_start_date),
                      3,
                      0)
                   sat_code,
                         a.element_type_id,
                         get_costing_info (b.payroll_id ,a.element_name, p_start_date) costing,
                         NVL (get_information (a.element_name, p_start_date),
                              a.reporting_name
                             ) reporting_name,
                         a.element_name, a.ear_ded,
                         get_amount (get_value (a.element_name,
                                                'Information',
                                                'Pay Value',
                                                p_assignment_id,
                                                p_start_date,
                                                p_end_date,
                                                '[Positive Amount]' /* 2.4.1 */
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
                             AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                             AND petf.classification_id =
                                                         pec.classification_id
                             AND pec.classification_name LIKE '%Information%'
                             AND petf.element_name = 'MX_RE_SAVING_FUNDS'  -- 1.4
                             ) a,
                         (SELECT ppa.payroll_id, paa.assignment_action_id, ppa.date_earned,
                                 ppa.effective_date, ptp.start_date,
                                 ptp.end_date
                            FROM apps.pay_assignment_actions paa,
                                 apps.pay_payroll_actions ppa,
--                                 hr_lookups lo1,
                                 --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
								 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                     AND a.run_result_id = c.run_result_id
              UNION -- Added Q7 for 5.0.1 2020 CFDI Requirement
              SELECT DISTINCT 'Q7 Deduction' section,
                b.effective_date,
                b.start_date,
                b.end_date,
                LPAD (
                       get_sat_code ('1PP ISR Subsidy for Employment', /* 5.0.1 */ -- SAT value needs to be 107
                                     a.element_information_category,
                                     lpad(a.element_information11,3,'0'),
                                     p_start_date),
                      3,
                      '0')
                   sat_code,
                a.element_type_id,
                get_costing_info (b.payroll_id ,'ISR Subsidy for Employment', p_start_date) costing, /* 5.0.1 */
                NVL (get_rep_name ('1PP ISR Subsidy for Employment', p_start_date), /* 5.0.1 */
                     a.reporting_name)
                   reporting_name,
                a.element_name,
                a.ear_ded,
                --get_amount (ABS (TO_NUMBER (c.result_value))) ele_amt,
                get_amount ( (SELECT NVL (SUM (a.balance_value), 0)
                                FROM (SELECT prb.assignment_id, prb.balance_value,
                                             pdb.defined_balance_id, pdb.balance_type_id,
                                             pdb.balance_dimension_id
                                        FROM (SELECT defined_balance_id, assignment_id,
                                                     effective_date, balance_value
                                                --FROM hr.pay_run_balances --code commented by RXNETHI-ARGANO,12/05/23
												FROM apps.pay_run_balances --code added by RXNETHI-ARGANO,12/05/23
                                               WHERE     effective_date = trunc(p_start_date, 'MM') + 14 --p_effective_date
                                                     AND assignment_id IS NOT NULL
                                                     AND assignment_id = p_assignment_id
                                                     ) prb,
                                             --hr.pay_defined_balances pdb  --code commented by RXNETHI-ARGANO,12/05/23
                                             apps.pay_defined_balances pdb  --code added by RXNETHI-ARGANO,12/05/23
                                       WHERE prb.defined_balance_id = pdb.defined_balance_id) a,
                                     --hr.pay_balance_types pbt,     --code commented by RXNETHI-ARGANO,12/05/23
                                     --hr.pay_balance_dimensions pbd --code commented by RXNETHI-ARGANO,12/05/23
									 apps.pay_balance_types pbt,     --code commented by RXNETHI-ARGANO,12/05/23
                                     apps.pay_balance_dimensions pbd --code added by RXNETHI-ARGANO,12/05/23
                               WHERE     a.balance_type_id = pbt.balance_type_id
                                     AND pbt.balance_name = 'ISR Subsidy for Employment'  --LIKE p_balance_name
                                     AND pbt.legislation_code = 'MX'
                                     AND pbt.currency_code = 'MXN'
                                     AND a.balance_dimension_id = pbd.balance_dimension_id
                                     AND pbd.database_item_suffix = '_ASG_GRE_RUN' --p_dimension_name '
                                              )) ele_amt,     /* 5.0.1 */ --Balance Amount of 1PP
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
                        AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE
                        AND pec.classification_name = 'Tax Credit'
                        AND petf.element_name = 'ISR Subsidy for Employment'
                        ) a,
                (SELECT ppa.payroll_id, paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                        AND prrv.result_value LIKE '%-%' /* 5.0.1 */ -- has to be negative value
                        AND pivf.NAME IN ('Pay Value')) c
          WHERE a.assignment_action_id = b.assignment_action_id
            AND a.run_result_id = c.run_result_id
            AND b.start_date = trunc(p_start_date, 'MM') + 15 /* 5.0.1 */ --Should be reported on 2PP only
              UNION -- Added Q8 for 5.0.6 2020 CFDI Requirement    'ISR.' ISR 2PP - 1PP bal ISR Calculated
              SELECT DISTINCT 'Q8 Deduction' section,
                b.effective_date,
                b.start_date,
                b.end_date,
                LPAD (
                       get_sat_code (a.element_name, /* 5.0.6 */ -- SAT value needs to be the same as ISR 002
                                     a.element_information_category,
                                     lpad(a.element_information11,3,'0'),
                                     p_start_date),
                      3,
                      '0')
                   sat_code,
                         a.element_type_id,
                         get_costing_info (b.payroll_id ,a.element_name, p_start_date) costing,
                get_cfdi_map_code ('ISR','TTEC_MEXICO_SAT_CODES','ISR Reporting Name',p_start_date)
                   reporting_name,
                a.element_name,
                a.ear_ded,
                --get_amount (ABS (TO_NUMBER (c.result_value))) ele_amt,
                get_amount (ABS (TO_NUMBER (c.result_value))-
                                                              (SELECT NVL (SUM (a.balance_value), 0)
                                                                FROM (SELECT prb.assignment_id, prb.balance_value,
                                                                             pdb.defined_balance_id, pdb.balance_type_id,
                                                                             pdb.balance_dimension_id
                                                                        FROM (SELECT defined_balance_id, assignment_id,
                                                                                     effective_date, balance_value
                                                                                --FROM hr.pay_run_balances
																				--code commented by RXNETHI-ARGANO,12/05/23
																				FROM apps.pay_run_balances
																				--code added by RXNETHI-ARGANO,12/05/23
                                                                               WHERE     effective_date = trunc(p_end_date, 'MM') + 14 --p_effective_date
                                                                                     AND assignment_id IS NOT NULL
                                                                                     AND assignment_id = p_assignment_id --p_assignment_id
                                                                                     ) prb,
                                                                             --hr.pay_defined_balances pdb
																			 --code commented by RXNETHI-ARGANO,12/05/23
																			 apps.pay_defined_balances pdb
																			 --code added by RXNETHI-ARGANO,12/05/23
                                                                       WHERE prb.defined_balance_id = pdb.defined_balance_id) a,
                                                                     --hr.pay_balance_types pbt,
																	 --code commented by RXNETHI-ARGANO,12/05/23
                                                                     --hr.pay_balance_dimensions pbd
																	 --code commented by RXNETHI-ARGANO,12/05/23
																	 apps.pay_balance_types pbt,
																	 --code added by RXNETHI-ARGANO,12/05/23
                                                                     apps.pay_balance_dimensions pbd
																	 --code added by RXNETHI-ARGANO,12/05/23
                                                               WHERE     a.balance_type_id = pbt.balance_type_id
                                                                     AND pbt.balance_name = 'ISR Calculated'  --LIKE p_balance_name
                                                                     AND pbt.legislation_code = 'MX'
                                                                     AND pbt.currency_code = 'MXN'
                                                                     AND a.balance_dimension_id = pbd.balance_dimension_id
                                                                     AND pbd.database_item_suffix = '_ASG_GRE_RUN' --p_dimension_name
                                                                     )
                                                                        ) ele_amt,
                NULL run_result_id
                    FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                                 petf.element_information11,
                                 petf.element_type_id, petf.reporting_name,
                                 petf.element_name,
                                 petf.element_information_category,
                                 'D' ear_ded
                            FROM apps.pay_run_results prr,
                                 apps.pay_element_types_f petf,
                                 apps.pay_element_classifications pec
                           WHERE prr.element_type_id = petf.element_type_id
                             AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                             AND petf.classification_id =
                                                         pec.classification_id
                             AND pec.classification_name = 'Tax Deductions'
                             AND petf.element_name = 'ISR'
                             ) a,
                         (SELECT ppa.payroll_id,paa.assignment_action_id, ppa.date_earned,
                                 ppa.effective_date, ptp.start_date,
                                 ptp.end_date
                            FROM apps.pay_assignment_actions paa,
                                 apps.pay_payroll_actions ppa,
                                 --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
								 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
                                 apps.per_time_periods ptp
                           WHERE ppa.payroll_action_id = paa.payroll_action_id
                             AND paa.assignment_id = paaf.assignment_id
                             AND paaf.primary_flag = 'Y'
                             AND paaf.assignment_id = p_assignment_id
                             AND paa.assignment_id = paaf.assignment_id
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
                             --AND prrv.result_value <> '0' /* 5.0.2 */
                             --AND prrv.result_value NOT LIKE '%-%' /* Levicom Feedback does not like negative , should noy commented out */
                             AND UPPER (pivf.NAME) IN UPPER ('Pay Value')) c
                   WHERE a.assignment_action_id = b.assignment_action_id
                     AND a.run_result_id = c.run_result_id
            AND  -- Need to show original if 2PP ISR - 1PP ISR Calculated is POSITIVE 5.0.6a
                   ( (SELECT SUM(TO_NUMBER (c.result_value))
                   FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                                petf.element_information11, petf.element_type_id,
                                petf.reporting_name, petf.element_name, --'D' ear_ded,
                                petf.element_information_category,petf.creation_date
                                ,pec.classification_name
                           FROM apps.pay_run_results prr,
                               apps.pay_element_types_f petf,
                                apps.pay_element_classifications pec
                          WHERE prr.element_type_id = petf.element_type_id
                                AND petf.classification_id = pec.classification_id
                                AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                                AND petf.element_name ='ISR'
                                AND pec.classification_name = 'Tax Deductions'
                                       ) a,
                        (SELECT ppa.payroll_id, paa.assignment_action_id, ppa.date_earned,
                                ppa.effective_date, ptp.start_date, ptp.end_date,paaf.assignment_id
                           FROM apps.pay_assignment_actions paa,
                                apps.pay_payroll_actions ppa,
                                --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
								apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                        (SELECT prrv.run_result_id, prrv.result_value,pivf.NAME
                           FROM apps.pay_input_values_f pivf,
                                apps.pay_run_result_values prrv
                          WHERE     pivf.input_value_id = prrv.input_value_id
                               -- AND prrv.result_value <> '0'
                                --AND prrv.result_value NOT LIKE '%-%'
                                AND pivf.NAME IN ('Pay Value')
                                ) c
                  WHERE a.assignment_action_id = b.assignment_action_id
                        AND a.run_result_id = c.run_result_id  )
               -
                  (SELECT NVL (SUM (a.balance_value), 0)
                    FROM (SELECT prb.assignment_id, prb.balance_value,
                                 pdb.defined_balance_id, pdb.balance_type_id,
                                 pdb.balance_dimension_id
                            FROM (SELECT defined_balance_id, assignment_id,
                                         effective_date, balance_value
                                    --FROM hr.pay_run_balances --code commented by RXNETHI-ARGANO,12/05/23
									FROM apps.pay_run_balances --code added by RXNETHI-ARGANO,12/05/23
                                   WHERE     effective_date = trunc(p_end_date, 'MM') + 14 --p_effective_date
                                         AND assignment_id IS NOT NULL
                                         AND assignment_id = p_assignment_id --p_assignment_id
                                         ) prb,
                                 --hr.pay_defined_balances pdb --code commented by RXNETHI-ARGANO,12/05/23
								 apps.pay_defined_balances pdb --code added by RXNETHI-ARGANO,12/05/23
                           WHERE prb.defined_balance_id = pdb.defined_balance_id) a,
                         --hr.pay_balance_types pbt,     --code commented by RXNETHI-ARGANO,12/05/23
                         --hr.pay_balance_dimensions pbd --code commented by RXNETHI-ARGANO,12/05/23
						 apps.pay_balance_types pbt,     --code added by RXNETHI-ARGANO,12/05/23
                         apps.pay_balance_dimensions pbd --code added by RXNETHI-ARGANO,12/05/23
                   WHERE     a.balance_type_id = pbt.balance_type_id
                         AND pbt.balance_name = 'ISR Calculated'  --LIKE p_balance_name
                         AND pbt.legislation_code = 'MX'
                         AND pbt.currency_code = 'MXN'
                         AND a.balance_dimension_id = pbd.balance_dimension_id
                         AND pbd.database_item_suffix = '_ASG_GRE_RUN' --p_dimension_name
                         )  )    >= 0
                   AND EXISTS(          --071 is met
                 SELECT DISTINCT
                        b.effective_date,
                        b.start_date,
                        b.end_date,
                        LPAD (NVL (a.element_information11,
                                   get_sat_code (a.element_name,
                                                 a.element_information_category,
                                                 lpad(a.element_information11,3,'0'),/* 2.4.2 */
                                                 p_start_date)),
                              3,
                              '0')
                           sat_code,
                        a.element_type_id,
                        get_costing_info (b.payroll_id ,a.element_name, p_start_date) costing,
                        NVL (get_rep_name (a.element_name, p_start_date),
                             a.reporting_name)
                           reporting_name,
                        a.element_name,
                        get_amount (ABS (TO_NUMBER (c.result_value))) ele_amt,
                        c.result_value
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
                                     AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                                     AND petf.classification_id =
                                                                 pec.classification_id
                                     AND pec.classification_name = 'Tax Credit'
                                     AND petf.element_name = 'ISR Subsidy for Employment'
                                     ) a,
                                 (SELECT ppa.payroll_id,paa.assignment_action_id, ppa.date_earned,
                                         ppa.effective_date, ptp.start_date,
                                         ptp.end_date
                                    FROM apps.pay_assignment_actions paa,
                                         apps.pay_payroll_actions ppa,
                                         --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
										 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
                                         apps.per_time_periods ptp
                                   WHERE ppa.payroll_action_id = paa.payroll_action_id
                                     AND paa.assignment_id = paaf.assignment_id
                                     AND paaf.primary_flag = 'Y'
                                     AND paaf.assignment_id = p_assignment_id
                                     AND paa.assignment_id = paaf.assignment_id
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
                                     --AND prrv.result_value <> '0'
                                     AND prrv.result_value  LIKE '%-%' /* should appear only if negative value */
                                     AND UPPER (pivf.NAME) IN UPPER ('Pay Value')) c
                           WHERE a.assignment_action_id = b.assignment_action_id
                             AND a.run_result_id = c.run_result_id )
              UNION -- Added Q8.1 for 5.0.6 2020 CFDI Requirement  -- Take out ISR from Q1 Deduction section
         SELECT DISTINCT 'Q8.1 Deduction' section, --Q8.1 will show if diff 1PP ISR - 2PP ISR Calculated is NEGATIVE OR the original ISR if 071 not met
                b.effective_date,
                b.start_date,
                b.end_date,
                LPAD (NVL (a.element_information11,
                           get_sat_code (a.element_name,
                                         a.element_information_category,
                                         lpad(a.element_information11,3,'0'),/* 2.4.2 */
                                         p_start_date)),
                      3,
                      '0')
                   sat_code,
                a.element_type_id,
                get_costing_info (b.payroll_id ,a.element_name, p_start_date) costing,
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
                        AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                        AND petf.element_name = 'ISR'
                        AND pec.classification_name LIKE
                               '%' || 'Deductions' || '%') a,
                (SELECT ppa.payroll_id, paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
            AND (( -- Need to show original if 2PP ISR - 1PP ISR Calculated is negative
                   ( (SELECT SUM(TO_NUMBER (c.result_value))
                   FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                                petf.element_information11, petf.element_type_id,
                                petf.reporting_name, petf.element_name, --'D' ear_ded,
                                petf.element_information_category,petf.creation_date
                                ,pec.classification_name
                           FROM apps.pay_run_results prr,
                               apps.pay_element_types_f petf,
                                apps.pay_element_classifications pec
                          WHERE prr.element_type_id = petf.element_type_id
                                AND petf.classification_id = pec.classification_id
                                AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                                AND petf.element_name ='ISR'
                                AND pec.classification_name = 'Tax Deductions'
                                       ) a,
                        (SELECT ppa.payroll_id, paa.assignment_action_id, ppa.date_earned,
                                ppa.effective_date, ptp.start_date, ptp.end_date,paaf.assignment_id
                           FROM apps.pay_assignment_actions paa,
                                apps.pay_payroll_actions ppa,
                                --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
								apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                        (SELECT prrv.run_result_id, prrv.result_value,pivf.NAME
                           FROM apps.pay_input_values_f pivf,
                                apps.pay_run_result_values prrv
                          WHERE     pivf.input_value_id = prrv.input_value_id
                               -- AND prrv.result_value <> '0'
                                --AND prrv.result_value NOT LIKE '%-%'
                                AND pivf.NAME IN ('Pay Value')
                                ) c
                  WHERE a.assignment_action_id = b.assignment_action_id
                        AND a.run_result_id = c.run_result_id  )
               -
                  (SELECT NVL (SUM (a.balance_value), 0)
                    FROM (SELECT prb.assignment_id, prb.balance_value,
                                 pdb.defined_balance_id, pdb.balance_type_id,
                                 pdb.balance_dimension_id
                            FROM (SELECT defined_balance_id, assignment_id,
                                         effective_date, balance_value
                                    --FROM hr.pay_run_balances --code commented by RXNETHI-ARGANO,12/05/23
									FROM apps.pay_run_balances --code added by RXNETHI-ARGANO,12/05/23
                                   WHERE     effective_date = trunc(p_end_date, 'MM') + 14 --p_effective_date
                                         AND assignment_id IS NOT NULL
                                         AND assignment_id = p_assignment_id --p_assignment_id
                                         ) prb,
                                 --hr.pay_defined_balances pdb --code commented by RXNETHI-ARGANO,12/05/23
								 apps.pay_defined_balances pdb --code added by RXNETHI-ARGANO,12/05/23
                           WHERE prb.defined_balance_id = pdb.defined_balance_id) a,
                         --hr.pay_balance_types pbt,      --code commented by RXNETHI-ARGANO,12/05/23
                         --hr.pay_balance_dimensions pbd  --code commented by RXNETHI-ARGANO,12/05/23
						 apps.pay_balance_types pbt,      --code added by RXNETHI-ARGANO,12/05/23
                         apps.pay_balance_dimensions pbd  --code added by RXNETHI-ARGANO,12/05/23
                   WHERE     a.balance_type_id = pbt.balance_type_id
                         AND pbt.balance_name = 'ISR Calculated'  --LIKE p_balance_name
                         AND pbt.legislation_code = 'MX'
                         AND pbt.currency_code = 'MXN'
                         AND a.balance_dimension_id = pbd.balance_dimension_id
                         AND pbd.database_item_suffix = '_ASG_GRE_RUN' --p_dimension_name
                         )  )    < 0)
            OR NOT EXISTS( -- This 8.1 is meant to show original ISR element value if 071 condition is not met
                             SELECT DISTINCT
                                    b.effective_date,
                                    b.start_date,
                                    b.end_date,
                                    LPAD (NVL (a.element_information11,
                                               get_sat_code (a.element_name,
                                                             a.element_information_category,
                                                             lpad(a.element_information11,3,'0'),/* 2.4.2 */
                                                             p_start_date)),
                                          3,
                                          '0')
                                       sat_code,
                                    a.element_type_id,
                                    get_costing_info (b.payroll_id ,a.element_name, p_start_date) costing,
                                    NVL (get_rep_name (a.element_name, p_start_date),
                                         a.reporting_name)
                                       reporting_name,
                                    a.element_name,
                                    get_amount (ABS (TO_NUMBER (c.result_value))) ele_amt,
                                    c.result_value
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
                                                 AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                                                 AND petf.classification_id =
                                                                             pec.classification_id
                                                 AND pec.classification_name = 'Tax Credit'
                                                 AND petf.element_name = 'ISR Subsidy for Employment'
                                                 ) a,
                                             (SELECT ppa.payroll_id,paa.assignment_action_id, ppa.date_earned,
                                                     ppa.effective_date, ptp.start_date,
                                                     ptp.end_date
                                                FROM apps.pay_assignment_actions paa,
                                                     apps.pay_payroll_actions ppa,
                                                     --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
													 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
                                                     apps.per_time_periods ptp
                                               WHERE ppa.payroll_action_id = paa.payroll_action_id
                                                 AND paa.assignment_id = paaf.assignment_id
                                                 AND paaf.primary_flag = 'Y'
                                                 AND paaf.assignment_id = p_assignment_id
                                                 AND paa.assignment_id = paaf.assignment_id
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
                                                 --AND prrv.result_value <> '0'
                                                 AND prrv.result_value  LIKE '%-%' /* should appear only if negative value */
                                                 AND UPPER (pivf.NAME) IN UPPER ('Pay Value')) c
                                       WHERE a.assignment_action_id = b.assignment_action_id
                                         AND a.run_result_id = c.run_result_id
                             )
                         )
              UNION -- Added Q9 for 5.0.6 2020 CFDI Requirement  -- Split ISR ajuste mensual  same as 007  -ISR ajuste mensual
              SELECT DISTINCT 'Q9 Deduction' section,
                b.effective_date,
                b.start_date,
                b.end_date,
                LPAD (
                       get_sat_code (a.element_name, /* 5.0.16*/ -- SAT value needs to be the same as ISR 002
                                     a.element_information_category,
                                     lpad(a.element_information11,3,'0'),
                                     p_start_date),
                      3,
                      '0')
                   sat_code,
                         a.element_type_id,
                 get_costing_info (b.payroll_id ,a.element_name, p_start_date) costing,
                 NVL (get_information (a.element_name, p_start_date),
                      a.reporting_name
                     ) reporting_name,
                a.element_name,
                a.ear_ded,
                --get_amount (ABS (TO_NUMBER (c.result_value))) ele_amt,
                get_amount ((SELECT NVL (SUM (a.balance_value), 0)
                                                                FROM (SELECT prb.assignment_id, prb.balance_value,
                                                                             pdb.defined_balance_id, pdb.balance_type_id,
                                                                             pdb.balance_dimension_id
                                                                        FROM (SELECT defined_balance_id, assignment_id,
                                                                                     effective_date, balance_value
                                                                                --FROM hr.pay_run_balances
                                                                                --code commented by RXNETHI-ARGANO,12/05/23
																				FROM apps.pay_run_balances
                                                                                --code added by RXNETHI-ARGANO,12/05/23
																			   WHERE     effective_date = trunc(p_end_date, 'MM') + 14 --p_effective_date
                                                                                     AND assignment_id IS NOT NULL
                                                                                     AND assignment_id = p_assignment_id --p_assignment_id
                                                                                     ) prb,
                                                                             --hr.pay_defined_balances pdb
																			 --code commented by RXNETHI-ARGANO,12/05/23
																			 apps.pay_defined_balances pdb
																			 --code added by RXNETHI-ARGANO,12/05/23
                                                                       WHERE prb.defined_balance_id = pdb.defined_balance_id) a,
                                                                     --hr.pay_balance_types pbt,
                                                                     --code commented by RXNETHI-ARGANO,12/05/23
																	 --hr.pay_balance_dimensions pbd
																	 --code commented by RXNETHI-ARGANO,12/05/23
																	 apps.pay_balance_types pbt,
                                                                     --code commented by RXNETHI-ARGANO,12/05/23
																	 apps.pay_balance_dimensions pbd
																	 --code added by RXNETHI-ARGANO,12/05/23						 
                                                               WHERE     a.balance_type_id = pbt.balance_type_id
                                                                     AND pbt.balance_name = 'ISR Calculated'  --LIKE p_balance_name
                                                                     AND pbt.legislation_code = 'MX'
                                                                     AND pbt.currency_code = 'MXN'
                                                                     AND a.balance_dimension_id = pbd.balance_dimension_id
                                                                     AND pbd.database_item_suffix = '_ASG_GRE_RUN' --p_dimension_name
                                                                     )
                                                                        ) ele_amt,
                NULL run_result_id
                    FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                                 petf.element_information11,
                                 petf.element_type_id, petf.reporting_name,
                                 petf.element_name,
                                 petf.element_information_category,
                                 'D' ear_ded
                            FROM apps.pay_run_results prr,
                                 apps.pay_element_types_f petf,
                                 apps.pay_element_classifications pec
                           WHERE prr.element_type_id = petf.element_type_id
                             AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                             AND petf.classification_id =
                                                         pec.classification_id
                             AND pec.classification_name = 'Tax Deductions'
                             AND petf.element_name = 'ISR'
                             ) a,
                         (SELECT ppa.payroll_id,paa.assignment_action_id, ppa.date_earned,
                                 ppa.effective_date, ptp.start_date,
                                 ptp.end_date
                            FROM apps.pay_assignment_actions paa,
                                 apps.pay_payroll_actions ppa,
                                 --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
								 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
                                 apps.per_time_periods ptp
                           WHERE ppa.payroll_action_id = paa.payroll_action_id
                             AND paa.assignment_id = paaf.assignment_id
                             AND paaf.primary_flag = 'Y'
                             AND paaf.assignment_id = p_assignment_id
                             AND paa.assignment_id = paaf.assignment_id
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
                             --AND prrv.result_value <> '0' /* 5.0.2 */
                             --AND prrv.result_value NOT LIKE '%-%' /* Levicom Feedback does not like negative , should noy commented out */
                             AND UPPER (pivf.NAME) IN UPPER ('Pay Value')) c
                   WHERE a.assignment_action_id = b.assignment_action_id
                     AND a.run_result_id = c.run_result_id
            AND ( -- Need to show original if 2PP ISR - 1PP ISR Calculated is negative
                   ( (SELECT SUM(TO_NUMBER (c.result_value))
                   FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                                petf.element_information11, petf.element_type_id,
                                petf.reporting_name, petf.element_name, --'D' ear_ded,
                                petf.element_information_category,petf.creation_date
                                ,pec.classification_name
                           FROM apps.pay_run_results prr,
                               apps.pay_element_types_f petf,
                                apps.pay_element_classifications pec
                          WHERE prr.element_type_id = petf.element_type_id
                                AND petf.classification_id = pec.classification_id
                                AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                                AND petf.element_name ='ISR'
                                AND pec.classification_name = 'Tax Deductions'
                                       ) a,
                        (SELECT ppa.payroll_id, paa.assignment_action_id, ppa.date_earned,
                                ppa.effective_date, ptp.start_date, ptp.end_date,paaf.assignment_id
                           FROM apps.pay_assignment_actions paa,
                                apps.pay_payroll_actions ppa,
                                --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
								apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
                                apps.per_time_periods ptp
                          WHERE     ppa.payroll_action_id = paa.payroll_action_id
                                AND paa.assignment_id = paaf.assignment_id
                                AND paaf.primary_flag = 'Y'
                                AND paaf.assignment_id = p_assignment_id --in (1081951,1040482) --= 1327696 --1126151 --644142
                                AND ptp.payroll_id = ppa.payroll_id
                                AND ptp.regular_payment_date = ppa.effective_date
                                AND ppa.date_earned BETWEEN paaf.effective_start_date
                                                        AND paaf.effective_end_date
                                AND ppa.effective_date BETWEEN p_start_date
                                                           AND p_end_date) b,
                        (SELECT prrv.run_result_id, prrv.result_value,pivf.NAME
                           FROM apps.pay_input_values_f pivf,
                                apps.pay_run_result_values prrv
                          WHERE     pivf.input_value_id = prrv.input_value_id
                               -- AND prrv.result_value <> '0'
                                --AND prrv.result_value NOT LIKE '%-%'
                                AND pivf.NAME IN ('Pay Value')
                                ) c
                  WHERE a.assignment_action_id = b.assignment_action_id
                        AND a.run_result_id = c.run_result_id  )
               -
                  (SELECT NVL (SUM (a.balance_value), 0)
                    FROM (SELECT prb.assignment_id, prb.balance_value,
                                 pdb.defined_balance_id, pdb.balance_type_id,
                                 pdb.balance_dimension_id
                            FROM (SELECT defined_balance_id, assignment_id,
                                         effective_date, balance_value
                                    --FROM hr.pay_run_balances --code commented by RXNETHI-ARGANO,12/05/23
									FROM apps.pay_run_balances --code added by RXNETHI-ARGANO,12/05/23
                                   WHERE     effective_date = trunc(p_end_date, 'MM') + 14 --p_effective_date
                                         AND assignment_id IS NOT NULL
                                         AND assignment_id = p_assignment_id --p_assignment_id
                                         ) prb,
                                 --hr.pay_defined_balances pdb --code commented by RXNETHI-ARGANO,12/05/23
								 apps.pay_defined_balances pdb --code added by RXNETHI-ARGANO,12/05/23
                           WHERE prb.defined_balance_id = pdb.defined_balance_id) a,
                         --hr.pay_balance_types pbt,     --code commented by RXNETHI-ARGANO,12/05/23
                         --hr.pay_balance_dimensions pbd --code commented by RXNETHI-ARGANO,12/05/23
						 apps.pay_balance_types pbt,     --code added by RXNETHI-ARGANO,12/05/23
                         apps.pay_balance_dimensions pbd --code added by RXNETHI-ARGANO,12/05/23
                   WHERE     a.balance_type_id = pbt.balance_type_id
                         AND pbt.balance_name = 'ISR Calculated'  --LIKE p_balance_name
                         AND pbt.legislation_code = 'MX'
                         AND pbt.currency_code = 'MXN'
                         AND a.balance_dimension_id = pbd.balance_dimension_id
                         AND pbd.database_item_suffix = '_ASG_GRE_RUN' --p_dimension_name
                         )  )    >= 0)
                   AND EXISTS(
                 SELECT DISTINCT
                        b.effective_date,
                        b.start_date,
                        b.end_date,
                        LPAD (NVL (a.element_information11,
                                   get_sat_code (a.element_name,
                                                 a.element_information_category,
                                                 lpad(a.element_information11,3,'0'),/* 2.4.2 */
                                                 p_start_date)),
                              3,
                              '0')
                           sat_code,
                        a.element_type_id,
                        get_costing_info (b.payroll_id ,a.element_name, p_start_date) costing,
                        NVL (get_rep_name (a.element_name, p_start_date),
                             a.reporting_name)
                           reporting_name,
                        a.element_name,
                        get_amount (ABS (TO_NUMBER (c.result_value))) ele_amt,
                        c.result_value
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
                                     AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                                     AND petf.classification_id =
                                                                 pec.classification_id
                                     AND pec.classification_name = 'Tax Credit'
                                     AND petf.element_name = 'ISR Subsidy for Employment'
                                     ) a,
                                 (SELECT ppa.payroll_id,paa.assignment_action_id, ppa.date_earned,
                                         ppa.effective_date, ptp.start_date,
                                         ptp.end_date
                                    FROM apps.pay_assignment_actions paa,
                                         apps.pay_payroll_actions ppa,
                                         --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
										 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
                                         apps.per_time_periods ptp
                                   WHERE ppa.payroll_action_id = paa.payroll_action_id
                                     AND paa.assignment_id = paaf.assignment_id
                                     AND paaf.primary_flag = 'Y'
                                     AND paaf.assignment_id = p_assignment_id
                                     AND paa.assignment_id = paaf.assignment_id
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
                                     --AND prrv.result_value <> '0'
                                     AND prrv.result_value  LIKE '%-%' /* should appear only if negative value */
                                     AND UPPER (pivf.NAME) IN UPPER ('Pay Value')) c
                           WHERE a.assignment_action_id = b.assignment_action_id
                             AND a.run_result_id = c.run_result_id )
                  order by 9;

/*
         UNION        -- 1.2 Kaushik
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
         SELECT DISTINCT 'Q1 Earning' section,
                b.effective_date,
                b.start_date,
                b.end_date,
                LPAD (get_sat_code (a.element_name,
                                    a.element_information_category,
                                    a.element_information11,
                                    --lpad(a.element_information11,3,'0'),/* 2.4.2 */
                                    p_start_date),
                      3,
                      '0')
                   sat_code,
                a.element_type_id,
                get_costing_info (b.payroll_id ,a.element_name, p_start_date) costing,
                NVL (get_rep_name (a.element_name, p_start_date),
                     a.reporting_name)
                   reporting_name,
                a.element_name element_name,
                a.ear_ded,
                get_amount (get_value (a.element_name,
                                       'Earning',
                                       'ISR Subject',
                                       p_assignment_id,
                                       p_start_date,
                                       p_end_date,
                                       '[Positive Amount]'/* 2.4.1 */
                                       ))
                   ele_amt,
                get_amount (get_value (a.element_name,
                                       NULL,
                                       'ISR Exempt',
                                       p_assignment_id,
                                       p_start_date,
                                       p_end_date,
                                       '[Positive Amount]'/* 2.4.1 */
                                       ))
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
                        AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                        AND pec.classification_name LIKE
                               '%' || p_class_name || '%'
                        AND petf.element_name NOT IN
                               ('MX_ML_WORK_RISK',
                                'MX_ML_SICKNESS',
                                'MX_TRAVEL_EXPENSES' ,/* 3.1 since this need to go under Otros Pagos*/
                                'MX_INTERNET_ALLOWANCE',--5.3
                                'MX_ELECTRICITY_SERVICE_ALLOWANCE',--5.3
                                'MX_ML_MATERNITY',
                                'MX_NCNS',                                --1.3
                                'MX_NCNS Pending', --1.3
                                'MX_SUSPENSION', --1.9
                                'MX_NO_PAY_AUT_LEAVE', --1.9
                                'MX_OVERPAID_SALARY', --1.9
                               -- 'MX_GROSERY_COUPONS', -- 1.10 /* Mar 22 change Grosery Coupon */
                                'MX_ML_WORK_RISK Pending',
                                'MX_ML_SICKNESS Pending',
                                'MX_ML_MATERNITY Pending')) a,
                (SELECT ppa.payroll_id,paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
         SELECT DISTINCT 'Q2 Earning' section,
                b.effective_date,
                b.start_date,
                b.end_date,
                LPAD (NVL (a.element_information11,
                           get_sat_code (a.element_name,
                                         a.element_information_category,
                                         lpad(a.element_information11,3,'0'),/* 2.4.2 */
                                         p_start_date)),
                      3,
                      '0')
                   sat_code,
                a.element_type_id,
                get_costing_info (b.payroll_id ,a.element_name, p_start_date) costing,
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
                                       p_end_date,
                                       '[Positive Amount]'/* 2.4.1 */
                                       ))
                   ele_amt,
                get_amount (get_value (a.element_name,
                                       NULL,
                                       'ISR Exempt',
                                       p_assignment_id,
                                       p_start_date,
                                       p_end_date,
                                       '[Positive Amount]'/* 2.4.1 */
                                       ))
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
                        AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                        AND pec.classification_name LIKE '%Amends%') a,
                (SELECT ppa.payroll_id,paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
         SELECT DISTINCT 'Q3 Earning' section,
                b.effective_date,
                b.start_date,
                b.end_date,
                LPAD (NVL (a.element_information11,
                           get_sat_code (a.element_name,
                                         a.element_information_category,
                                         lpad(a.element_information11,3,'0'),/* 2.4.2 */
                                         p_start_date)),
                      3,
                      '0')
                   sat_code,
                a.element_type_id,
                get_costing_info (b.payroll_id ,a.element_name, p_start_date) costing,
                NVL (get_rep_name (a.element_name, p_start_date),
                     a.reporting_name)
                   reporting_name,
                a.element_name,
                a.ear_ded,
/* 1.11 Begin */
--                get_amount (TO_NUMBER (c.result_value)) ele_amt,
--                get_amount (get_value (a.element_name,
--                                       NULL,
--                                       'ISR Exempt',
--                                       p_assignment_id,
--                                       p_start_date,
--                                       p_end_date))
--                   exempt_amt,
                get_amount (get_value (a.element_name,
                                       NULL,
                                       'ISR Exempt',
                                       p_assignment_id,
                                       p_start_date,
                                       p_end_date,
                                       '[Positive Amount]'/* 2.4.1 */
                                       )) ele_amt,
                get_amount (TO_NUMBER (c.result_value)) exempt_amt,
/* 1.11 End */
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
                        AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                        AND pec.classification_name = 'Tax Credit'
                        AND petf.element_name != 'ISR Subsidy for Employment'
                        ) a,
                (SELECT ppa.payroll_id,paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
         SELECT DISTINCT 'Q4 Earning' section,
                b.effective_date,
                b.start_date,
                b.end_date,
                LPAD (NVL (a.element_information11,
                           get_sat_code (a.element_name,
                                         a.element_information_category,
                                         lpad(a.element_information11,3,'0'),/* 2.4.2 */
                                         p_start_date)),
                      3,
                      '0')
                   sat_code,
                a.element_type_id,
                get_costing_info (b.payroll_id ,a.element_name, p_start_date) costing,
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
                        AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                        AND pec.classification_name IN
                               ('Non-payroll Payments')
                        AND petf.element_name NOT IN  -- 1.4
                               ('MX_SF_COMPANY_LIQ',  -- 1.4
                                'MX_SF_LIQUIDATION')  -- 1.4
                               ) a,
                (SELECT ppa.payroll_id,paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
         SELECT DISTINCT 'Q5 Earning' section,
                b.effective_date,
                b.start_date,
                b.end_date,
                LPAD (get_cntr_code ('Perception Counterpart',
                                     lpad(a.element_information11,3,'0'),/* 2.4.2 */
                                     a.element_name,
                                     p_start_date),
                      3,
                      0)
                   sat_code,
                a.element_type_id,
                get_costing_info (b.payroll_id ,a.element_name, p_start_date) costing,
                get_cntr_name ('Perception Counterpart',
                               lpad(a.element_information11,3,'0'),/* 2.4.2 */
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
                                       p_end_date,
                                       '[Negative Amount]' /* 2.4.1 */
                                       ))
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
                        AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                        AND pec.classification_name LIKE '%Deduction%'
                        --AND petf.element_name <> 'ISR') a, /* Commented Our for 2.5.1 */
                        AND petf.element_name not in ( 'ISR', 'Annual Tax Adjustment')) a,  /* 2.5.1 */
                (SELECT ppa.payroll_id,paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                   SELECT DISTINCT 'Q6 Earning' section,
                         b.effective_date,
                         b.start_date,
                         b.end_date,
                         LPAD
                            (NVL
                                (a.element_information11,
                                 get_sat_code (a.element_name,
                                               a.element_information_category,
                                               lpad(a.element_information11,3,'0'),/* 2.4.2 */
                                               p_start_date
                                              )
                                ),
                             3,
                             '0'
                            ) sat_code,
                         a.element_type_id,
                         get_costing_info (b.payroll_id ,a.element_name, p_start_date) costing,
                         NVL (get_information (a.element_name, p_start_date),
                              a.reporting_name
                             ) reporting_name,
                         a.element_name, a.ear_ded,
                         get_amount (get_value (a.element_name,
                                                NULL,
                                                'ISR Exempt',
                                                p_assignment_id,
                                                p_start_date,
                                                p_end_date,
                                                '[Positive Amount]'/* 2.4.1 */
                                       )) ele_amt,
                         get_amount (get_value (a.element_name,
                                                'Information',
                                                'Pay Value',
                                                p_assignment_id,
                                                p_start_date,
                                                p_end_date,
                                                '[Positive Amount]'/* 2.4.1 */
                                       )) exempt_amt,
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
                             AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                             AND petf.classification_id =
                                                         pec.classification_id
                             AND pec.classification_name LIKE '%Information%'
                             AND petf.element_name = 'MX_RE_SAVING_FUNDS'  -- 1.4
                             ) a,
                         (SELECT ppa.payroll_id,paa.assignment_action_id, ppa.date_earned,
                                 ppa.effective_date, ptp.start_date,
                                 ptp.end_date
                            FROM apps.pay_assignment_actions paa,
                                 apps.pay_payroll_actions ppa,
--                                 hr_lookups lo1,
                                 --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
								 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                     AND a.run_result_id = c.run_result_id
                   ORDER BY element_name ;


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

      CURSOR c_other_pymnt_element (
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
                                         lpad(a.element_information11,3,'0'),/* 2.4.2 */
                                         p_start_date)),
                      3,
                      '0')
                   sat_code,
                a.element_type_id,
                get_costing_info (b.payroll_id ,a.element_name, p_start_date) costing,
                NVL (get_rep_name (a.element_name, p_start_date),
                     a.reporting_name)
                   reporting_name,
                a.element_name,
                a.ear_ded,
                get_amount (get_value (a.element_name,
                                       NULL,
                                       'ISR Exempt',
                                       p_assignment_id,
                                       p_start_date,
                                       p_end_date,
                                       '[Positive Amount]'/* 2.4.1 */
                                       )) ele_amt,
                get_amount (TO_NUMBER (c.result_value)) exempt_amt,
                a.run_result_id
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
                             AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                             AND petf.classification_id =
                                                         pec.classification_id
                             AND pec.classification_name = 'Tax Credit'
                             AND petf.element_name = 'ISR Subsidy for Employment'
                             ) a,
                         (SELECT ppa.payroll_id,paa.assignment_action_id, ppa.date_earned,
                                 ppa.effective_date, ptp.start_date,
                                 ptp.end_date
                            FROM apps.pay_assignment_actions paa,
                                 apps.pay_payroll_actions ppa,
--                                 hr_lookups lo1,
                                 --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
								 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                             --AND prrv.result_value <> '0' /* 5.0.2 */
                             AND prrv.result_value NOT LIKE '%-%' /* Levicom Feedback does not like negative , should noy commented out */
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
                                         lpad(a.element_information11,3,'0'),/* 2.4.2 */
                                         p_start_date)),
                      3,
                      '0')
                   sat_code,
                a.element_type_id,
                get_costing_info (b.payroll_id ,a.element_name, p_start_date) costing,
                NVL (get_rep_name (a.element_name, p_start_date),
                     a.reporting_name)
                   reporting_name,
                a.element_name,
                a.ear_ded,
                get_amount (get_value (a.element_name,
                                       NULL,
                                       'ISR Exempt',
                                       p_assignment_id,
                                       p_start_date,
                                       p_end_date,
                                       '[Positive Amount]'/* 2.4.1 */
                                       )) ele_amt,
                get_amount (TO_NUMBER (c.result_value)) exempt_amt,
                a.run_result_id
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
                             AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                             AND petf.classification_id =
                                                         pec.classification_id
                             AND pec.classification_name = 'Supplemental Earnings'
                             AND petf.element_name = 'MX_TRAVEL_EXPENSES' /* 3.1 */
                             ) a,
                         (SELECT ppa.payroll_id,paa.assignment_action_id, ppa.date_earned,
                                 ppa.effective_date, ptp.start_date,
                                 ptp.end_date
                            FROM apps.pay_assignment_actions paa,
                                 apps.pay_payroll_actions ppa,
--                                 hr_lookups lo1,
                                 --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
								 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                     AND a.run_result_id = c.run_result_id
         UNION  /* 5.3 Begin */
         SELECT DISTINCT
                b.effective_date,
                b.start_date,
                b.end_date,
                LPAD ( get_sat_code (a.element_name,
                                    a.element_information_category,
                                    a.element_information11,
                                    --lpad(a.element_information11,3,'0'),/* 2.4.2 */
                                    to_date('16-FEB-2021') ),
                      3,
                      '0')
                   sat_code,
                a.element_type_id,
                get_costing_info (b.payroll_id ,a.element_name, p_start_date) costing,
                NVL (get_rep_name (a.element_name, p_start_date),
                     a.reporting_name)
                   reporting_name,
                a.element_name,
                a.ear_ded,
                get_amount (get_value (a.element_name,
                                       NULL,
                                       'ISR Exempt',
                                       p_assignment_id,
                                       p_start_date,
                                       p_end_date,
                                       '[Positive Amount]'/* 2.4.1 */
                                       )) ele_amt,
                get_amount (TO_NUMBER (c.result_value)) exempt_amt,
                a.run_result_id
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
                             AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                             AND petf.classification_id =
                                                         pec.classification_id
                             AND pec.classification_name = 'Earnings'
                             AND petf.element_name in ( 'MX_INTERNET_ALLOWANCE','MX_ELECTRICITY_SERVICE_ALLOWANCE' ) --5.3
                             ) a,
                         (SELECT ppa.payroll_id,paa.assignment_action_id, ppa.date_earned,
                                 ppa.effective_date, ptp.start_date,
                                 ptp.end_date
                            FROM apps.pay_assignment_actions paa,
                                 apps.pay_payroll_actions ppa,
--                                 hr_lookups lo1,
                                 --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
								 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                     AND a.run_result_id = c.run_result_id /* 5.3 End */
-- for 2017 moving from Deduccion for ISR to FA for negative amount to get the counterpart
         UNION
         SELECT DISTINCT
                b.effective_date,
                b.start_date,
                b.end_date,
--                LPAD (NVL (a.element_information11,
--                           get_sat_code (a.element_name,
--                                         a.element_information_category,
--                                         a.element_information11,
--                                         p_start_date)),
--                      3,
--                      '0')
--                   sat_code,
                LPAD ( get_cntr_code ('Tax Counterpart - ISR', --'Other Payment Counterpart',
                                     lpad(a.element_information11,3,'0'),/* 2.4.2 */
                                     a.element_name,
                                     p_start_date ),
                      3,
                      0)
                   sat_code,
                a.element_type_id,
--                get_costing_info (b.payroll_id ,a.element_name, p_start_date) costing,
--                NVL (get_rep_name (a.element_name, p_start_date),
--                     a.reporting_name)
--                   reporting_name,
------------------------
                 get_costing_info (b.payroll_id ,a.element_name, p_start_date) costing,
--                 get_costing_info (b.payroll_id ,
--                 get_ele_name (
--                 get_cntr_name ('Tax Counterpart - ISR', --'Perception Counterpart',
--                               a.element_information11,
--                               a.element_name,
--                               p_start_date)
--                               ,p_start_date )
--                               ,p_start_date ) costing,
                 get_cntr_name ('Tax Counterpart - ISR', --'Perception Counterpart',
                               lpad(a.element_information11,3,'0'),/* 2.4.2 */
                               a.element_name,
                               p_start_date) reporting_name ,
------------------------
                a.element_name,
                a.ear_ded,
--                get_amount (TO_NUMBER (c.result_value)) ele_amt,
--                NULL run_result_id
                get_amount (get_value (a.element_name,
                                       NULL,
                                       'ISR Exempt',
                                       p_assignment_id,
                                       p_start_date,
                                       p_end_date,
                                       '[Negative Amount]'/* 2.4.1 */
                                       )) ele_amt,
                --get_amount (TO_NUMBER (c.result_value)) exempt_amt,
                get_amount (ABS (TO_NUMBER (c.result_value))) exempt_amt,
                a.run_result_id
            FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                        petf.element_information11, petf.element_type_id,
                        petf.reporting_name, petf.element_name, 'D' ear_ded,
                        petf.element_information_category
                   FROM apps.pay_run_results prr,
                        apps.pay_element_types_f petf,
                        apps.pay_element_classifications pec
                  WHERE prr.element_type_id = petf.element_type_id
                        AND petf.classification_id = pec.classification_id
                        AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                        AND pec.classification_name LIKE
                               '%' || 'Deductions' || '%'
                        AND petf.element_name = 'ISR') a,
                (SELECT ppa.payroll_id, paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                        AND prrv.result_value LIKE '%-%' -- commented out for 2017
                        --AND prrv.result_value NOT LIKE '%-%' -- restricted to pickup p
                        AND pivf.NAME IN ('Pay Value')) c
          WHERE a.assignment_action_id = b.assignment_action_id
                AND a.run_result_id = c.run_result_id
         UNION -- Added for 5.0.1 2020 CFDI Requirement -c_other_pymnt_element ISR Calculated -007
         SELECT DISTINCT
                b.effective_date,
                b.start_date,
                b.end_date,
                LPAD (NVL (a.element_information11,
                           get_sat_code ('1PP ISR Calculated',
                                         a.element_information_category,
                                         lpad(a.element_information11,3,'0'),/* 2.4.2 */
                                         p_start_date)),
                      3,
                      '0')
                   sat_code,
                a.element_type_id,
                get_costing_info (b.payroll_id ,'ISR', p_start_date) costing,       /* 5.0.1 */ --  Costing need to reflect the ISR 2210
                NVL (get_rep_name ('1PP ISR Calculated', p_start_date),             /* 5.0.1 */ -- CFDI Reporting Name ->ISR ajustado por subsidio
                     a.reporting_name)
                   reporting_name,
                a.element_name,
                a.ear_ded,
                get_amount (get_value (a.element_name,
                                       NULL,
                                       'ISR Exempt',
                                       p_assignment_id,
                                       p_start_date,
                                       p_end_date,
                                       '[Positive Amount]'/* 2.4.1 */
                                       )) ele_amt,
                --get_amount (ABS (TO_NUMBER (c.result_value))) exempt_amt,
                                get_amount ( (SELECT NVL (SUM (a.balance_value), 0)
                                                FROM (SELECT prb.assignment_id, prb.balance_value,
                                                             pdb.defined_balance_id, pdb.balance_type_id,
                                                             pdb.balance_dimension_id
                                                        FROM (SELECT defined_balance_id, assignment_id,
                                                                     effective_date, balance_value
                                                                --FROM hr.pay_run_balances
                                                                --code commented by RXNETHI-ARGANO,12/05/23
																FROM apps.pay_run_balances
                                                                --code added by RXNETHI-ARGANO,12/05/23
															   WHERE     effective_date = trunc(p_start_date, 'MM') + 14 --p_effective_date
                                                                     AND assignment_id IS NOT NULL
                                                                     AND assignment_id = p_assignment_id
                                                                     ) prb,
                                                             --hr.pay_defined_balances pdb --code commented by RXNETHI-ARGANO,12/05/23
															 apps.pay_defined_balances pdb --code added by RXNETHI-ARGANO,12/05/23
                                                       WHERE prb.defined_balance_id = pdb.defined_balance_id) a,
                                                     --hr.pay_balance_types pbt,     --code commented by RXNETHI-ARGANO,12/05/23
                                                     --hr.pay_balance_dimensions pbd --code commented by RXNETHI-ARGANO,12/05/23
													 apps.pay_balance_types pbt,     --code added by RXNETHI-ARGANO,12/05/23
                                                     apps.pay_balance_dimensions pbd --code added by RXNETHI-ARGANO,12/05/23
                                               WHERE     a.balance_type_id = pbt.balance_type_id
                                                     AND pbt.balance_name = 'ISR Calculated'  --LIKE p_balance_name
                                                     AND pbt.legislation_code = 'MX'
                                                     AND pbt.currency_code = 'MXN'
                                                     AND a.balance_dimension_id = pbd.balance_dimension_id
                                                     AND pbd.database_item_suffix = '_ASG_GRE_RUN' --p_dimension_name
                                                     )) exempt_amt,     /* 5.0.1 */ --Balance Amount of 1PP
                a.run_result_id
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
                             AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE
                             AND petf.classification_id =pec.classification_id
                             AND pec.classification_name = 'Tax Credit'
                             AND petf.element_name = 'ISR Subsidy for Employment'
                             ) a,
                         (SELECT ppa.payroll_id,paa.assignment_action_id, ppa.date_earned,
                                 ppa.effective_date, ptp.start_date,
                                 ptp.end_date
                            FROM apps.pay_assignment_actions paa,
                                 apps.pay_payroll_actions ppa,
--                                 hr_lookups lo1,
                                 --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
								 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
                                 apps.per_time_periods ptp
                           WHERE ppa.payroll_action_id = paa.payroll_action_id
                             AND paa.assignment_id = paaf.assignment_id
                             AND paaf.primary_flag = 'Y'
                             AND paaf.assignment_id = p_assignment_id
                             AND paa.assignment_id = paaf.assignment_id
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
                             AND prrv.result_value  LIKE '%-%' /* 5.0.1 */ --should show only if 071 - ISR Subsidy for Employment has negative value in 2PP*/
                             AND pivf.NAME = 'Pay Value') c
                   WHERE a.assignment_action_id = b.assignment_action_id
                     AND a.run_result_id = c.run_result_id
                     AND b.start_date =  trunc(p_start_date, 'MM') + 15 /* 5.0.1 */ --Should be reported on 2PP only
         UNION -- Added for 5.0.1 2020 CFDI Requirement -c_other_pymnt_element Tax Credit Balance -> 008
         SELECT DISTINCT
                b.effective_date,
                b.start_date,
                b.end_date,
                LPAD (NVL (a.element_information11,
                           get_sat_code ('1PP Tax Credit',
                                         a.element_information_category,
                                         lpad(a.element_information11,3,'0'),/* 2.4.2 */
                                         p_start_date)),
                      3,
                      '0')
                   sat_code,
                a.element_type_id,
                get_costing_info (b.payroll_id ,a.element_name, p_start_date) costing, /* 5.0.1 */  -- Same Costing as ISR Subsidy for Employment
                NVL (get_rep_name ('1PP Tax Credit', p_start_date),                    /* 5.0.1 */ -- CFDI Reporting Name -> Subsidio efectivamente entregado que no corresponda
                     a.reporting_name)
                   reporting_name,
                a.element_name,
                a.ear_ded,
                get_amount (get_value (a.element_name,
                                       NULL,
                                       'ISR Exempt',
                                       p_assignment_id,
                                       p_start_date,
                                       p_end_date,
                                       '[Positive Amount]'/* 2.4.1 */
                                       )) ele_amt,
                --get_amount (ABS (TO_NUMBER (c.result_value))) exempt_amt,
                                get_amount ( (SELECT NVL (SUM (a.balance_value), 0)
                                                FROM (SELECT prb.assignment_id, prb.balance_value,
                                                             pdb.defined_balance_id, pdb.balance_type_id,
                                                             pdb.balance_dimension_id
                                                        FROM (SELECT defined_balance_id, assignment_id,
                                                                     effective_date, balance_value
                                                                --FROM hr.pay_run_balances --code commented by RXNETHI-ARGANO,12/05/23
																FROM apps.pay_run_balances --code added by RXNETHI-ARGANO,12/05/23
                                                               WHERE     effective_date = trunc(p_start_date, 'MM') + 14 --p_effective_date
                                                                     AND assignment_id IS NOT NULL
                                                                     AND assignment_id = p_assignment_id
                                                                     ) prb,
                                                             --hr.pay_defined_balances pdb --code commented by RXNETHI-ARGANO,12/05/23
															 apps.pay_defined_balances pdb --code added by RXNETHI-ARGANO,12/05/23
                                                       WHERE prb.defined_balance_id = pdb.defined_balance_id) a,
                                                     --hr.pay_balance_types pbt,     --code commented by RXNETHI-ARGANO,12/05/23
                                                     --hr.pay_balance_dimensions pbd --code commented by RXNETHI-ARGANO,12/05/23
													 apps.pay_balance_types pbt,     --code added by RXNETHI-ARGANO,12/05/23
                                                     apps.pay_balance_dimensions pbd --code added by RXNETHI-ARGANO,12/05/23
                                               WHERE     a.balance_type_id = pbt.balance_type_id
                                                     AND pbt.balance_name = 'Tax Credit'  -- p_balance_name
                                                     AND pbt.legislation_code = 'MX'
                                                     AND pbt.currency_code = 'MXN'
                                                     AND a.balance_dimension_id = pbd.balance_dimension_id
                                                     AND pbd.database_item_suffix = '_ASG_GRE_RUN' --p_dimension_name
                                                     )) exempt_amt,    /* 5.0.1 */ --Balance Amount of 1PP
                a.run_result_id
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
                             AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE
                             AND petf.classification_id =pec.classification_id
                             AND pec.classification_name = 'Tax Credit'
                             AND petf.element_name = 'ISR Subsidy for Employment'
                             ) a,
                         (SELECT ppa.payroll_id,paa.assignment_action_id, ppa.date_earned,
                                 ppa.effective_date, ptp.start_date,
                                 ptp.end_date
                            FROM apps.pay_assignment_actions paa,
                                 apps.pay_payroll_actions ppa,
--                                 hr_lookups lo1,
                                 --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
								 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
                                 apps.per_time_periods ptp
                           WHERE ppa.payroll_action_id = paa.payroll_action_id
                             AND paa.assignment_id = paaf.assignment_id
                             AND paaf.primary_flag = 'Y'
                             AND paaf.assignment_id = p_assignment_id
                             AND paa.assignment_id = paaf.assignment_id
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
                             AND prrv.result_value  LIKE '%-%' /* 5.0.1 */ --should show only if 071 - ISR Subsidy for Employment has negative value in 2PP*/
                             AND pivf.NAME = 'Pay Value') c
                   WHERE a.assignment_action_id = b.assignment_action_id
                     AND a.run_result_id = c.run_result_id
                     AND b.start_date =  trunc(p_start_date, 'MM') + 15 /* 5.0.1 */ --Should be reported on 2PP only
         UNION -- Added for 5.0.5 2020 CFDI Requirement -c_other_pymnt_element 002 -> 0.00
         SELECT DISTINCT
                b.effective_date,
                b.start_date,
                b.end_date,
                LPAD (NVL (a.element_information11,
                           get_sat_code ('ISR Subsidy for Employment', --a.element_name, /* 5.0.5 */
                                         a.element_information_category,
                                         lpad(a.element_information11,3,'0'),/* 2.4.2 */
                                         p_start_date)),
                      3,
                      '0')
                   sat_code,
                a.element_type_id,
                get_costing_info (b.payroll_id ,'ISR Subsidy for Employment' --a.element_name /* 5.0.5 */
                , p_start_date) costing,
                NVL (get_rep_name ('ISR Subsidy for Employment' --a.element_name /* 5.0.5 */
                , p_start_date),
                     a.reporting_name)
                   reporting_name,
                a.element_name,
                a.ear_ded,
                get_amount (get_value (a.element_name,
                                       NULL,
                                       'ISR Exempt',
                                       p_assignment_id,
                                       p_start_date,
                                       p_end_date,
                                       '[Positive Amount]'/* 2.4.1 */
                                       )) ele_amt,
                --get_amount (TO_NUMBER (c.result_value)) exempt_amt, /* 5.0.5 */
                get_amount (TO_NUMBER (0)) exempt_amt, /* 5.0.5 */
                --a.run_result_id
                NULL run_result_id /* 5.0.5 */
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
                             AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                             AND petf.classification_id =
                                                         pec.classification_id
                             AND pec.classification_name = 'Tax Deductions'
                             AND petf.element_name = 'ISR'
                             ) a,
                         (SELECT ppa.payroll_id,paa.assignment_action_id, ppa.date_earned,
                                 ppa.effective_date, ptp.start_date,
                                 ptp.end_date
                            FROM apps.pay_assignment_actions paa,
                                 apps.pay_payroll_actions ppa,
                                 --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
								 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
                                 apps.per_time_periods ptp
                           WHERE ppa.payroll_action_id = paa.payroll_action_id
                             AND paa.assignment_id = paaf.assignment_id
                             AND paaf.primary_flag = 'Y'
                             AND paaf.assignment_id = p_assignment_id
                             AND paa.assignment_id = paaf.assignment_id
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
                             --AND prrv.result_value <> '0' /* 5.0.2 */
                             --AND prrv.result_value NOT LIKE '%-%' /* Levicom Feedback does not like negative , should noy commented out */
                             AND UPPER (pivf.NAME) IN UPPER ('Pay Value')) c
                   WHERE a.assignment_action_id = b.assignment_action_id
                     AND a.run_result_id = c.run_result_id
                     AND (SELECT NVL (SUM (a.balance_value), 0)
                            FROM (SELECT prb.assignment_id, prb.balance_value,
                                         pdb.defined_balance_id, pdb.balance_type_id,
                                         pdb.balance_dimension_id
                                    FROM (SELECT defined_balance_id, assignment_id,
                                                 effective_date, balance_value
                                            --FROM hr.pay_run_balances --code commented by RXNETHI-ARGANO,12/05/23
											FROM apps.pay_run_balances --code added by RXNETHI-ARGANO,12/05/23
                                           WHERE     effective_date between trunc(p_end_date, 'MM') and p_end_date
                                                 AND assignment_id IS NOT NULL
                                                 AND assignment_id = p_assignment_id
                                                 ) prb,
                                         --hr.pay_defined_balances pdb --code commented by RXNETHI-ARGANO,12/05/23
										 apps.pay_defined_balances pdb --code added by RXNETHI-ARGANO,12/05/23
                                   WHERE prb.defined_balance_id = pdb.defined_balance_id) a,
                                 --hr.pay_balance_types pbt,     --code commented by RXNETHI-ARGANO,12/05/23
                                 --hr.pay_balance_dimensions pbd --code commented by RXNETHI-ARGANO,12/05/23
								 apps.pay_balance_types pbt,     --code added by RXNETHI-ARGANO,12/05/23
                                 apps.pay_balance_dimensions pbd --code added by RXNETHI-ARGANO,12/05/23
                           WHERE     a.balance_type_id = pbt.balance_type_id
                                 AND pbt.balance_name = 'ISR Subject Adjusted'
                                 AND pbt.legislation_code = 'MX'
                                 AND pbt.currency_code = 'MXN'
                                 AND a.balance_dimension_id = pbd.balance_dimension_id
                                 AND pbd.database_item_suffix = '_ASG_GRE_RUN' ) > DECODE(p_end_date,trunc(p_end_date, 'MM')+ 14,g_1PP_ISR_QUOTA,g_2PP_ISR_QUOTA)
                   AND NOT EXISTS(
                 SELECT DISTINCT
                        b.effective_date,
                        b.start_date,
                        b.end_date,
                        LPAD (NVL (a.element_information11,
                                   get_sat_code (a.element_name,
                                                 a.element_information_category,
                                                 lpad(a.element_information11,3,'0'),/* 2.4.2 */
                                                 p_start_date)),
                              3,
                              '0')
                           sat_code,
                        a.element_type_id,
                        get_costing_info (b.payroll_id ,a.element_name, p_start_date) costing,
                        NVL (get_rep_name (a.element_name, p_start_date),
                             a.reporting_name)
                           reporting_name,
                        a.element_name,
                        get_amount (ABS (TO_NUMBER (c.result_value))) ele_amt,
                        c.result_value
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
                                     AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                                     AND petf.classification_id =
                                                                 pec.classification_id
                                     AND pec.classification_name = 'Tax Credit'
                                     AND petf.element_name = 'ISR Subsidy for Employment'
                                     ) a,
                                 (SELECT ppa.payroll_id,paa.assignment_action_id, ppa.date_earned,
                                         ppa.effective_date, ptp.start_date,
                                         ptp.end_date
                                    FROM apps.pay_assignment_actions paa,
                                         apps.pay_payroll_actions ppa,
                                         --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
										 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
                                         apps.per_time_periods ptp
                                   WHERE ppa.payroll_action_id = paa.payroll_action_id
                                     AND paa.assignment_id = paaf.assignment_id
                                     AND paaf.primary_flag = 'Y'
                                     AND paaf.assignment_id = p_assignment_id
                                     AND paa.assignment_id = paaf.assignment_id
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
                                     --AND prrv.result_value <> '0'
                                     --AND prrv.result_value  LIKE '%-%' /* should appear only if negative value */
                                     AND UPPER (pivf.NAME) IN UPPER ('Pay Value')) c
                           WHERE a.assignment_action_id = b.assignment_action_id
                             AND a.run_result_id = c.run_result_id )
         UNION -- Added for 5.0.7 2020 CFDI Requirement -c_other_pymnt_element 002 -> 0.00
         SELECT DISTINCT
                p_end_date effective_date,
                p_start_date start_date,
                p_end_date end_date,
                APPS.ttec_pay_mex_cfdi_2017_intf.get_sat_code ('ISR Subsidy for Employment', --a.element_name, /* 5.0.7 */
                                         '',
                                         '',
                                         p_start_date)
                   sat_code,
                7526 element_type_id,
                APPS.ttec_pay_mex_cfdi_2017_intf.get_costing_info (420 -- r_emp_info.payroll_id
                ,'ISR Subsidy for Employment' --a.element_name /* 5.0.7 */
                , p_start_date) costing,
                APPS.ttec_pay_mex_cfdi_2017_intf.get_rep_name ('ISR Subsidy for Employment' --a.element_name /* 5.0.7 */
                , p_start_date)
                   reporting_name,
                'ISR Subsidy for Employment' element_name,
                'E' ear_ded,
                APPS.ttec_pay_mex_cfdi_2017_intf.get_amount (0) ele_amt,
                APPS.ttec_pay_mex_cfdi_2017_intf.get_amount (TO_NUMBER (0)) exempt_amt, /* 5.0.7 */
                NULL run_result_id
        FROM DUAL
        WHERE NOT EXISTS(
           SELECT b.assignment_id, c.result_value,a.element_name
           FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                        petf.element_information11, petf.element_type_id,
                        petf.reporting_name, petf.element_name, --'D' ear_ded,
                        petf.element_information_category,petf.creation_date
                        ,pec.classification_name
                   FROM apps.pay_run_results prr,
                       apps.pay_element_types_f petf,
                        apps.pay_element_classifications pec
                  WHERE prr.element_type_id = petf.element_type_id
                        AND petf.classification_id = pec.classification_id
                        AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                        AND petf.element_name in ('ISR','ISR Subsidy for Employment')
                      --  AND pec.classification_name LIKE'%' || 'Deductions' || '%'
                               ) a,
                (SELECT ppa.payroll_id, paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date,paaf.assignment_id
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                (SELECT prrv.run_result_id, prrv.result_value,pivf.NAME
                   FROM apps.pay_input_values_f pivf,
                        apps.pay_run_result_values prrv
                  WHERE     pivf.input_value_id = prrv.input_value_id
                       -- AND prrv.result_value <> '0'
                        --AND prrv.result_value NOT LIKE '%-%'
                        AND pivf.NAME IN ('Pay Value')
                        ) c
          WHERE a.assignment_action_id = b.assignment_action_id
                AND a.run_result_id = c.run_result_id    )
                     ;


      CURSOR c_TotISR_Refund (
         p_assignment_id    NUMBER,
         p_start_date       DATE,
         p_end_date         DATE)
      IS
         SELECT  SUM(ABS (TO_NUMBER (c.result_value))) ISR_Refund
            FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                        petf.element_information11, petf.element_type_id,
                        petf.reporting_name, petf.element_name, 'D' ear_ded,
                        petf.element_information_category
                   FROM apps.pay_run_results prr,
                        apps.pay_element_types_f petf,
                        apps.pay_element_classifications pec
                  WHERE prr.element_type_id = petf.element_type_id
                        AND petf.classification_id = pec.classification_id
                        AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                        AND pec.classification_name LIKE
                               '%' || 'Deductions' || '%'
                        AND petf.element_name = 'ISR') a,
                (SELECT ppa.payroll_id, paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                        AND prrv.result_value LIKE '%-%' -- commented out for 2017
                        --AND prrv.result_value NOT LIKE '%-%' -- restricted to pickup p
                        AND pivf.NAME IN ('Pay Value')) c
          WHERE a.assignment_action_id = b.assignment_action_id
                AND a.run_result_id = c.run_result_id;

      CURSOR c_TotISRSubsidy_Refund (
         p_assignment_id    NUMBER,
         p_start_date       DATE,
         p_end_date         DATE)
      IS
         SELECT  SUM(ABS (TO_NUMBER (c.result_value))) ISRSubsidy_Refund
            FROM (SELECT prr.run_result_id, prr.assignment_action_id,
                        petf.element_information11, petf.element_type_id,
                        petf.reporting_name, petf.element_name, 'D' ear_ded,
                        petf.element_information_category
                   FROM apps.pay_run_results prr,
                        apps.pay_element_types_f petf,
                        apps.pay_element_classifications pec
                  WHERE prr.element_type_id = petf.element_type_id
                        AND petf.classification_id = pec.classification_id
                        AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                        AND pec.classification_name = 'Tax Credit'
                        AND petf.element_name = 'ISR Subsidy for Employment') a,
                (SELECT ppa.payroll_id, paa.assignment_action_id, ppa.date_earned,
                        ppa.effective_date, ptp.start_date, ptp.end_date
                   FROM apps.pay_assignment_actions paa,
                        apps.pay_payroll_actions ppa,
                        --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
						apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                        --AND prrv.result_value LIKE '%-%' -- Cannot be negative always positive
                        AND prrv.result_value NOT LIKE '%-%' -- restricted to pickup up positive value for ISR Subsidy for Employment only
                        AND pivf.NAME IN ('Pay Value')) c
          WHERE a.assignment_action_id = b.assignment_action_id
                AND a.run_result_id = c.run_result_id;

      CURSOR c_TotOtherPayments (
         p_assignment_id    NUMBER,
         p_start_date       DATE,
         p_end_date         DATE,
         p_class_name       VARCHAR2)
      IS


         SELECT NVL (SUM (TO_NUMBER (exempt_amt)), 0)
         FROM (
         SELECT  NVL(ABS(TO_NUMBER (c.result_value)),0) exempt_amt
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
                             AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE
                             AND petf.classification_id = pec.classification_id
                             AND pec.classification_name = 'Tax Credit'
                             AND petf.element_name = 'ISR Subsidy for Employment'
                             ) a,
                         (SELECT ppa.payroll_id,paa.assignment_action_id, ppa.date_earned,
                                 ppa.effective_date, ptp.start_date,
                                 ptp.end_date
                            FROM apps.pay_assignment_actions paa,
                                 apps.pay_payroll_actions ppa,
                                 --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
								 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
                                 apps.per_time_periods ptp
                           WHERE ppa.payroll_action_id = paa.payroll_action_id
                             AND paa.assignment_id = paaf.assignment_id
                             AND paaf.primary_flag = 'Y'
                             AND paaf.assignment_id = p_assignment_id
                             AND paa.assignment_id = paaf.assignment_id
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
                             --AND prrv.result_value <> '0' /* 5.0.2 */
                             AND prrv.result_value NOT LIKE '%-%' /* Levicom Feedback does not like negative , should noy commented out */
                             AND pivf.NAME = 'Pay Value') c
                   WHERE a.assignment_action_id = b.assignment_action_id
                     AND a.run_result_id = c.run_result_id
         UNION -- Added for 5.0.1 2020 CFDI Requirement -c_other_pymnt_element ISR Calculated -007
            SELECT  (
                        SELECT NVL (SUM (a.balance_value), 0)
                                FROM (SELECT prb.assignment_id, prb.balance_value,
                                             pdb.defined_balance_id, pdb.balance_type_id,
                                             pdb.balance_dimension_id
                                        FROM (SELECT defined_balance_id, assignment_id,
                                                     effective_date, balance_value
                                                --FROM hr.pay_run_balances --code commented by RXNETHI-ARGANO,12/05/23
												FROM apps.pay_run_balances --code added by RXNETHI-ARGANO,12/05/23
                                               WHERE     effective_date = trunc(p_start_date, 'MM') + 14 --p_effective_date
                                                     AND assignment_id IS NOT NULL
                                                     AND assignment_id = p_assignment_id
                                                     ) prb,
                                             --hr.pay_defined_balances pdb --code commented by RXNETHI-ARGANO,12/05/23
											 apps.pay_defined_balances pdb --code added by RXNETHI-ARGANO,12/05/23
                                       WHERE prb.defined_balance_id = pdb.defined_balance_id) a,
                                     --hr.pay_balance_types pbt,     --code commented by RXNETHI-ARGANO,12/05/23
                                     --hr.pay_balance_dimensions pbd --code commented by RXNETHI-ARGANO,12/05/23
									 apps.pay_balance_types pbt,     --code added by RXNETHI-ARGANO,12/05/23
                                     apps.pay_balance_dimensions pbd --code added by RXNETHI-ARGANO,12/05/23
                               WHERE     a.balance_type_id = pbt.balance_type_id
                                     AND pbt.balance_name = 'ISR Calculated'  -- p_balance_name
                                     AND pbt.legislation_code = 'MX'
                                     AND pbt.currency_code = 'MXN'
                                     AND a.balance_dimension_id = pbd.balance_dimension_id
                                     AND pbd.database_item_suffix = '_ASG_GRE_RUN' --p_dimension_name
                     )                           exempt_amt     /* 5.0.1 */ --Balance Amount of 1PP
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
                     AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE
                     AND petf.classification_id =pec.classification_id
                     AND pec.classification_name = 'Tax Credit'
                     AND petf.element_name = 'ISR Subsidy for Employment'
                     ) a,
                 (SELECT ppa.payroll_id,paa.assignment_action_id, ppa.date_earned,
                         ppa.effective_date, ptp.start_date,
                         ptp.end_date
                    FROM apps.pay_assignment_actions paa,
                         apps.pay_payroll_actions ppa,
            --                                 hr_lookups lo1,
                         --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
						 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
                         apps.per_time_periods ptp
                   WHERE ppa.payroll_action_id = paa.payroll_action_id
                     AND paa.assignment_id = paaf.assignment_id
                     AND paaf.primary_flag = 'Y'
                     AND paaf.assignment_id = p_assignment_id
                     AND paa.assignment_id = paaf.assignment_id
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
                     AND prrv.result_value  LIKE '%-%' /* 5.0.1 */ --should show only if 071 - ISR Subsidy for Employment has negative value in 2PP*/
                     AND pivf.NAME = 'Pay Value') c
            WHERE a.assignment_action_id = b.assignment_action_id
             AND a.run_result_id = c.run_result_id
             AND b.start_date =  trunc(p_start_date, 'MM') + 15 /* 5.0.1 */ --Should be reported on 2PP only
         UNION /*Added for 5.0.1 2020 CFDI Requirement -c_other_pymnt_element Tax Credit -008 */
            SELECT  (
                        SELECT NVL (SUM (a.balance_value), 0)
                                FROM (SELECT prb.assignment_id, prb.balance_value,
                                             pdb.defined_balance_id, pdb.balance_type_id,
                                             pdb.balance_dimension_id
                                        FROM (SELECT defined_balance_id, assignment_id,
                                                     effective_date, balance_value
                                                --FROM hr.pay_run_balances --code commented by RXNETHI-ARGANO,12/05/23
												FROM apps.pay_run_balances --code added by RXNETHI-ARGANO,12/05/23
                                               WHERE     effective_date = trunc(p_start_date, 'MM') + 14 --p_effective_date
                                                     AND assignment_id IS NOT NULL
                                                     AND assignment_id = p_assignment_id
                                                     ) prb,
                                             --hr.pay_defined_balances pdb --code commented by RXNETHI-ARGANO,12/05/23
											 apps.pay_defined_balances pdb --code added by RXNETHI-ARGANO,12/05/23
                                       WHERE prb.defined_balance_id = pdb.defined_balance_id) a,
                                     --hr.pay_balance_types pbt,     --code commented by RXNETHI-ARGANO,12/05/23
                                     --hr.pay_balance_dimensions pbd --code commented by RXNETHI-ARGANO,12/05/23
									 apps.pay_balance_types pbt,     --code added by RXNETHI-ARGANO,12/05/23
                                     apps.pay_balance_dimensions pbd --code added by RXNETHI-ARGANO,12/05/23
                               WHERE     a.balance_type_id = pbt.balance_type_id
                                     AND pbt.balance_name = 'Tax Credit'  -- p_balance_name
                                     AND pbt.legislation_code = 'MX'
                                     AND pbt.currency_code = 'MXN'
                                     AND a.balance_dimension_id = pbd.balance_dimension_id
                                     AND pbd.database_item_suffix = '_ASG_GRE_RUN' --p_dimension_name
                     )          exempt_amt     /* 5.0.1 */ --Balance Amount of 1PP
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
                     AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE
                     AND petf.classification_id =pec.classification_id
                     AND pec.classification_name = 'Tax Credit'
                     AND petf.element_name = 'ISR Subsidy for Employment'
                     ) a,
                 (SELECT ppa.payroll_id,paa.assignment_action_id, ppa.date_earned,
                         ppa.effective_date, ptp.start_date,
                         ptp.end_date
                    FROM apps.pay_assignment_actions paa,
                         apps.pay_payroll_actions ppa,
            --                                 hr_lookups lo1,
                         --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
						 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
                         apps.per_time_periods ptp
                   WHERE ppa.payroll_action_id = paa.payroll_action_id
                     AND paa.assignment_id = paaf.assignment_id
                     AND paaf.primary_flag = 'Y'
                     AND paaf.assignment_id = p_assignment_id
                     AND paa.assignment_id = paaf.assignment_id
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
                     AND prrv.result_value  LIKE '%-%' /* 5.0.1 */ --should show only if 071 - ISR Subsidy for Employment has negative value in 2PP*/
                     AND pivf.NAME = 'Pay Value') c
            WHERE a.assignment_action_id = b.assignment_action_id
             AND a.run_result_id = c.run_result_id
             AND b.start_date =  trunc(p_start_date, 'MM') + 15 /* 5.0.1 */ --Should be reported on 2PP only
         UNION
         SELECT  NVL(TO_NUMBER (c.result_value),0) exempt_amt
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
                             AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                             AND petf.classification_id =
                                                         pec.classification_id
                             AND pec.classification_name = 'Supplemental Earnings'
                             AND petf.element_name = 'MX_TRAVEL_EXPENSES'
                             ) a,
                         (SELECT ppa.payroll_id,paa.assignment_action_id, ppa.date_earned,
                                 ppa.effective_date, ptp.start_date,
                                 ptp.end_date
                            FROM apps.pay_assignment_actions paa,
                                 apps.pay_payroll_actions ppa,
--                                 hr_lookups lo1,
                                 --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
								 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
                                 apps.per_time_periods ptp
                           WHERE ppa.payroll_action_id = paa.payroll_action_id
                             AND paa.assignment_id = paaf.assignment_id
                             AND paaf.primary_flag = 'Y'
                             AND paaf.assignment_id = p_assignment_id
                             AND paa.assignment_id = paaf.assignment_id
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
         UNION /* 5.3 Begin */
         SELECT  NVL(TO_NUMBER (c.result_value),0) exempt_amt
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
                             AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                             AND petf.classification_id =
                                                         pec.classification_id
                             AND pec.classification_name = 'Earnings'
                             AND petf.element_name in ( 'MX_INTERNET_ALLOWANCE','MX_ELECTRICITY_SERVICE_ALLOWANCE' ) --5.3
                             ) a,
                         (SELECT ppa.payroll_id,paa.assignment_action_id, ppa.date_earned,
                                 ppa.effective_date, ptp.start_date,
                                 ptp.end_date
                            FROM apps.pay_assignment_actions paa,
                                 apps.pay_payroll_actions ppa,
--                                 hr_lookups lo1,
                                 --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
								 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
                                 apps.per_time_periods ptp
                           WHERE ppa.payroll_action_id = paa.payroll_action_id
                             AND paa.assignment_id = paaf.assignment_id
                             AND paaf.primary_flag = 'Y'
                             AND paaf.assignment_id = p_assignment_id
                             AND paa.assignment_id = paaf.assignment_id
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
                     AND a.run_result_id = c.run_result_id) /* 5.3 End */
                     ;

      CURSOR c_ISR_Subsidy_for_Employment (
         p_assignment_id    NUMBER,
         p_start_date       DATE,
         p_end_date         DATE,
         p_class_name       VARCHAR2)
      IS
         SELECT DISTINCT 'c_ISR_Subsidy_for_Employmen - Q1' section,
                b.effective_date,
                b.start_date,
                b.end_date,
                LPAD (NVL (a.element_information11,
                           get_sat_code (a.element_name,
                                         a.element_information_category,
                                         lpad(a.element_information11,3,'0'),/* 2.4.2 */
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
                                       NULL,
                                       'ISR Exempt',
                                       p_assignment_id,
                                       p_start_date,
                                       p_end_date,
                                       '[Positive Amount]'/* 2.4.1 */
                                       )) ele_amt,
                get_amount (TO_NUMBER (c.result_value)) exempt_amt,
                a.run_result_id
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
                             AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                             AND petf.classification_id =
                                                         pec.classification_id
                             AND pec.classification_name = 'Tax Credit'
                             AND petf.element_name = 'ISR Subsidy for Employment'
                             ) a,
                         (SELECT paa.assignment_action_id, ppa.date_earned,
                                 ppa.effective_date, ptp.start_date,
                                 ptp.end_date
                            FROM apps.pay_assignment_actions paa,
                                 apps.pay_payroll_actions ppa,
--                                 hr_lookups lo1,
                                 --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
								 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                             AND UPPER (pivf.NAME) IN UPPER ('ISR Subsidy for Employment')) c
                   WHERE a.assignment_action_id = b.assignment_action_id
                     AND a.run_result_id = c.run_result_id
         UNION
         SELECT DISTINCT 'c_ISR_Subsidy_for_Employmen - Q2' section,
                b.effective_date,
                b.start_date,
                b.end_date,
                LPAD (get_cntr_code ('Perception Counterpart',
                                     lpad(a.element_information11,3,'0'),/* 2.4.2 */
                                     a.element_name,
                                     p_start_date),
                      3,
                      0)
                   sat_code,
                a.element_type_id,
--                NVL (get_rep_name (a.element_name, p_start_date),
--                     a.reporting_name)
--                   reporting_name,
                get_cntr_name ('Perception Counterpart',
                               lpad(a.element_information11,3,'0'),/* 2.4.2 */
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
                                       p_end_date,
                                       '[Negative Amount]'/* 2.4.1 */
                                       )) ele_amt,
                --get_amount (TO_NUMBER (c.result_value)) exempt_amt,
                --get_amount ( ABS (TO_NUMBER (c.result_value))) exempt_amt, /* 5.0.9 */
                get_amount ( (TO_NUMBER (c.result_value))) exempt_amt,/* 5.0.9 */
                a.run_result_id
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
                             AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                             AND petf.classification_id =
                                                         pec.classification_id
                             AND pec.classification_name = 'Tax Credit'
                             AND petf.element_name = 'ISR Subsidy for Employment'
                             ) a,
                         (SELECT paa.assignment_action_id, ppa.date_earned,
                                 ppa.effective_date, ptp.start_date,
                                 ptp.end_date
                            FROM apps.pay_assignment_actions paa,
                                 apps.pay_payroll_actions ppa,
--                                 hr_lookups lo1,
                                 --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
								 apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                             AND prrv.result_value LIKE '%-%'
                             AND UPPER (pivf.NAME) IN UPPER ('ISR Subsidy for Employment')) c
                   WHERE a.assignment_action_id = b.assignment_action_id
                     AND a.run_result_id = c.run_result_id;


      CURSOR c_emp_overtime (
         p_assignment_id    NUMBER,
         p_start_date       DATE,
         p_end_date         DATE,
         p_ot_ele_name      VARCHAR2)
      IS
           SELECT DISTINCT a.sat_code,a.element_name,
                           --DECODE (a.element_name, 'MX_OVERTIME_200', 'Dobles', 'Triples') ot_type,
                           DECODE (a.element_name, 'MX_OVERTIME_200', '01', '02') ot_type,
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
                          AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
                          --AND petf.element_name IN('MX_OVERTIME_200', 'MX_OVERTIME_300')
                          AND petf.element_name = p_ot_ele_name
                                 ) a,
                  (SELECT paa.assignment_action_id, ppa.date_earned,
                          ppa.effective_date, ptp.start_date, ptp.end_date
                     FROM apps.pay_assignment_actions paa,
                          apps.pay_payroll_actions ppa,
                          --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
						  apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
                  AND c.result_value NOT LIKE '%-%' /* 2.4.6 */
         GROUP BY a.sat_code,DECODE (a.element_name, 'MX_OVERTIME_200', '01', '02'),NULL,a.element_name;

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
                          AND p_start_date BETWEEN petf.EFFECTIVE_START_DATE AND petf.EFFECTIVE_END_DATE /* 03/17/2017 */
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
                          --hr.per_all_assignments_f paaf, --code commented by RXNETHI-ARGANO,12/05/23
						  apps.per_all_assignments_f paaf, --code added by RXNETHI-ARGANO,12/05/23
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
           --FROM hr.hr_organization_information hoi, --code commented by RXNETHI-ARGANO,12/05/23
		   FROM apps.hr_organization_information hoi, --code added by RXNETHI-ARGANO,12/05/23
                hr_all_organization_units haou,
                hr_locations_all hla
          WHERE hoi.org_information_context = 'MX_TAX_REGISTRATION'
                AND haou.organization_id in (select case when to_date(p_end_date,'YYYY/MM/DD HH24:MI:SS') > '01-JUL-2021' then
                                             DECODE (p_payroll_id,1183,69393,65173)--65173--added for 6.1
                                            else
                                            DECODE (p_payroll_id, 420, 1654, 1651)
                                            end from dual)  -- added condition as part of 5.4
                      -- DECODE (p_payroll_id, 420, 1654, 1651)
                AND hoi.organization_id = haou.organization_id
                AND haou.location_id = hla.location_id;

      v_text               VARCHAR (32765) DEFAULT NULL;
      v_text1              VARCHAR (32765) DEFAULT NULL;  /* 2.0 */
      v_file_name          VARCHAR2 (200) DEFAULT NULL;
      v_file_type          UTL_FILE.file_type;
      v_second_file        VARCHAR2 (200) DEFAULT NULL;
      --v_second_type        UTL_FILE.file_type;
      v_cut_off_date       DATE;
      v_current_run_date   DATE;
      v_pay_date           DATE;
      v_start_date         DATE; /* 2.0 */
      v_end_date           DATE; /* 2.0 */
      v_pl_id              NUMBER DEFAULT NULL;
      v_not_eli_fsa        VARCHAR2 (1) DEFAULT NULL;
      l_fsa_term_date      DATE DEFAULT NULL;
      v_effective_date     DATE DEFAULT NULL;
      v_flag               VARCHAR2 (1) DEFAULT NULL;
      v_profit_sharing_payout     VARCHAR2 (1) DEFAULT NULL;
      v_ded_flag           VARCHAR2 (1) DEFAULT NULL;
      v_net_pay            NUMBER;
      v_TotIncome          NUMBER;
      v_net_perception     NUMBER;
      v_net_pay_dsp        NUMBER;
      v_process_faa        VARCHAR2 (1) DEFAULT NULL;
      v_process_faa_p1     VARCHAR2 (1) DEFAULT NULL;
      v_process_f          VARCHAR2 (1) DEFAULT NULL;
      v_process_g          VARCHAR2 (1) DEFAULT NULL;
      v_Payroll_Type       VARCHAR2 (1) DEFAULT NULL;
      v_PaymentFrequency   VARCHAR2 (2) DEFAULT NULL;
      v_process_dc         VARCHAR2 (1) DEFAULT NULL;
      v_first_record       VARCHAR2 (1) DEFAULT NULL;
      v_pay_vacation       NUMBER;
      v_total_subsidy      NUMBER;
      v_total_subsidy_p1   NUMBER;
      v_total_subsidy_p2   NUMBER;
      v_run_date           DATE;
      v_run_date_p1        DATE;
      v_run_date_p2        DATE;
      v_cut_off_date_p1    DATE;
      v_DC_3               NUMBER;
      v_DC_4               NUMBER;
      v_DC_5               NUMBER;
      v_DC_ISR_subj        NUMBER;
      v_TotOtherPayments   NUMBER;
      v_TotPercepcions     NUMBER;
      v_TotDeductions      NUMBER;
      v_TotDeductionsOther NUMBER;  /* 2.3.1 */
      v_TotTaxExempts      NUMBER;
      v_TotSepComps        NUMBER;
      v_TotISR             NUMBER;
      v_TotISRRefunds      NUMBER;
--      v_TotISRSubsidyRefunds NUMBER;
      v_TotSepCompsD       VARCHAR2 (21) DEFAULT NULL;
      v_TotISRD            VARCHAR2 (21) DEFAULT NULL;
      v_TotPercepcionsD    VARCHAR2 (21) DEFAULT NULL;   /* 2.4.9 */
      v_TotDeductionsD     VARCHAR2 (21) DEFAULT NULL;
      v_TotDeductionsOtherD NUMBER;  /* 2.3.1 */
      v_instance           VARCHAR2 (20) DEFAULT NULL;
      v_TotOtherPaymentsD  VARCHAR2 (21) DEFAULT NULL;
      v_NumPaidDaysD       VARCHAR2 (21) DEFAULT NULL;    /* 2.3.2 */
      v_TotalTaxExemptD    VARCHAR2 (21) DEFAULT NULL;    /* 2.3.3 */
      v_TotalTaxableD      VARCHAR2 (21) DEFAULT NULL;    /* 2.3.3 */
      v_TotalSalariesD     VARCHAR2 (21) DEFAULT NULL;    /* 2.3.3 */
      v_previous_ele_name  VARCHAR2 (200) DEFAULT NULL;
      v_current_ele_name   VARCHAR2 (200) DEFAULT NULL;
      v_pago_de_nomina     VARCHAR2 (25) DEFAULT 'Pago de nómina';

   PROCEDURE process_overtime_total (
             p_assignment_id    NUMBER,
             p_start_date       DATE,
             p_end_date         DATE,
             p_overtime_element VARCHAR2
   )
   IS

   BEGIN

          IF p_overtime_element like '%OVERTIME%' THEN /* 2.4.3 */
               v_module := 'c_emp_overtime';
               v_loc := ' 120';
--               --Fnd_File.put_line(Fnd_File.LOG,v_module);

               BEGIN
                  FOR r_emp_overtime
                     IN c_emp_overtime (p_assignment_id,
                                        p_start_date,
                                        p_end_date,
                                        p_overtime_element)
                  LOOP
                     v_text := NULL;

                     IF r_emp_overtime.element_name = 'MX_OVERTIME_200'
                     THEN
                        r_emp_overtime.amt :=
                           get_value ('MX_OVERTIME_200',
                                      NULL,
                                      'Pay Value',
                                      p_assignment_id,
                                      p_start_date,
                                      p_end_date,
                                      '[Positive Amount]'/* 2.4.1 */
                                      )
                           + get_value ('MX_ADJ_OT200',
                                        NULL,
                                        'Pay Value',
                                        p_assignment_id,
                                        p_start_date,
                                        p_end_date,
                                      '[Positive Amount]'/* 2.4.1 */
                                      );
                     ELSE
                        r_emp_overtime.amt :=
                           get_value ('MX_OVERTIME_300',
                                      NULL,
                                      'Pay Value',
                                      p_assignment_id,
                                      p_start_date,
                                      p_end_date,
                                      '[Positive Amount]'/* 2.4.1 */
                                      )
                           + get_value ('MX_ADJ_OT300',
                                        NULL,
                                        'Pay Value',
                                        p_assignment_id,
                                        p_start_date,
                                        p_end_date,
                                      '[Positive Amount]'/* 2.4.1 */
                                      );
                     END IF;

                     v_module := '[DAB]';
                     v_loc := ' 130 ';
--                     --Fnd_File.put_line(Fnd_File.LOG,v_module);

                     --v_text :=  '[DAB]-Overtime'          --    DAB    [Overtime]    Alphanumeric    NO
                     v_text :=  '[HorasExtra]'          --    DAB    [Overtime]    Alphanumeric    NO
                     || '|'
                     || r_emp_overtime.cnt  --1    Days    Full    YES
                     || '|'
                     || r_emp_overtime.ot_type  --2    HoursType    "Catalogc_HoursType"    YES
                     || '|'
                     || CEIL (get_value (r_emp_overtime.element_name,
                                             NULL,
                                             'Hours',
                                             p_assignment_id,
                                             p_start_date,
                                             p_end_date,
                                             '[Positive Amount]'/* 2.4.1 */
                                             )) --3    Overtime    Full    YES
                     || '|'
                     || get_amount (r_emp_overtime.amt);  --4    AmountPaid    Decimal    YES

                     UTL_FILE.put_line (v_file_type, v_text);
                     fnd_file.put_line (fnd_file.output, v_text);


-- Below is old 2016 record
--                     v_text :=
--                           'HE'
--                        || '|'
--                        || r_emp_overtime.cnt
--                        || '|'
--                        || r_emp_overtime.ot_type
--                        || '|'
--                        || ROUND (get_value (r_emp_overtime.element_name,
--                                             NULL,
--                                             'Hours',
--                                             r_emp_info.assignment_id,
--                                             v_cut_off_date,
--                                             v_current_run_date))
--                        || '|'
--                        || get_amount (r_emp_overtime.amt);
--                     UTL_FILE.put_line (v_file_type, v_text);
--                     fnd_file.put_line (fnd_file.output, v_text);

                  END LOOP;
               END;

          END IF;  /* 2.4.3 */

   EXCEPTION

      WHEN OTHERS
      THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error out NOM File - process_overtime_total >>>' || SQLERRM);
         --RAISE skip_record;

   END process_overtime_total;

   BEGIN

    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'Concurrent Program -> TeleTech Mexico CFDI Payroll Custom Interface - 2017');
    Fnd_File.put_line(Fnd_File.LOG, '');
    Fnd_File.put_line(Fnd_File.LOG,'             ======================================================');
    Fnd_File.put_line(Fnd_File.LOG,'             *******   Parameters   ********                  ');
    Fnd_File.put_line(Fnd_File.LOG,'             ======================================================');
    Fnd_File.put_line(Fnd_File.LOG,'                  p_output_directory      : '||p_output_directory);
    Fnd_File.put_line(Fnd_File.LOG,'                  p_start_date            : '||p_start_date);
    Fnd_File.put_line(Fnd_File.LOG,'                  p_end_date              : '||p_end_date );
    Fnd_File.put_line(Fnd_File.LOG,'                  p_payroll_id            : '||p_payroll_id );
    Fnd_File.put_line(Fnd_File.LOG,'                  p_employee_number       : '||p_employee_number);
    Fnd_File.put_line(Fnd_File.LOG,'                  p_pay_date              : '||p_pay_date);
    Fnd_File.put_line(Fnd_File.LOG,'                  p_profit_sharing_payout : '||p_profit_sharing_payout);
    Fnd_File.put_line(Fnd_File.LOG,'--------------------------------------------------------------------------------------------------------------------------------------------------');

    v_module := 'InitAlldates';
    v_loc := ' 10 ';
--    --Fnd_File.put_line(Fnd_File.LOG,v_module);

      IF p_start_date is null or p_end_date is NULL THEN

            select decode(sign(to_char(sysdate,'DD') - 16), 1,'01','16') ||'-'||
            decode(sign(to_char(sysdate,'DD') - 16), 1,to_char(sysdate,'MON') ,to_char(add_months(sysdate,-1),'MON'))||'-'||
            decode(sign(to_char(sysdate,'DDD') - 16), 1,to_char(sysdate,'RRRR'),to_char(sysdate,'RRRR') - 1) start_date
            into v_cut_off_date
            from dual;

            select decode(sign(to_char(sysdate,'DD') - 16), 1,'15',to_char(last_day(sysdate - 16),'DD')) ||'-'||
            to_char(sysdate - 16,'MON')||'-'||
            decode(sign(to_char(sysdate,'DDD') - 16), 1,to_char(sysdate - 16,'RRRR'),to_char(sysdate,'RRRR') - 1) end_date
            into v_current_run_date
            from dual;

            select NEXT_DAY(to_date(decode(sign(to_char(sysdate,'DD') - 16), 1,'15',to_char(last_day(sysdate - 16),'DD')) ||'-'||
            to_char(sysdate - 16,'MON')||'-'||
            decode(sign(to_char(sysdate,'DDD') - 16), 1,to_char(sysdate - 16,'RRRR'),to_char(sysdate,'RRRR') - 1)),'Monday') pay_date
            into v_pay_date
            from dual;

            v_start_date := v_cut_off_date; /* 2.0 */
            v_end_date := v_current_run_date; /* 2.0 */

      ELSE
            v_cut_off_date := TO_DATE (p_start_date, 'YYYY/MM/DD HH24:MI:SS');
            v_current_run_date := TO_DATE (p_end_date, 'YYYY/MM/DD HH24:MI:SS');

            v_start_date := v_cut_off_date; /* 2.0 */
            v_end_date := v_current_run_date; /* 2.0 */

            IF p_pay_date IS NULL THEN

                select NEXT_DAY(to_date(decode(sign(to_char(v_current_run_date,'DD') - 16), 1,'15',to_char(last_day(v_current_run_date - 16),'DD')) ||'-'||
                to_char(v_current_run_date - 16,'MON')||'-'||
                decode(sign(to_char(v_current_run_date,'DDD') - 16), 1,to_char(v_current_run_date - 16,'RRRR'),to_char(v_current_run_date,'RRRR') - 1)),'Monday') pay_date
                into v_pay_date
                from dual;

            ELSE
                v_pay_date := TO_DATE (p_pay_date, 'YYYY/MM/DD HH24:MI:SS');
            END IF;

      END IF;

      IF p_profit_sharing_payout is null THEN

            select decode(substr( decode(sign(to_char(sysdate,'DD') - 15), 1,'15',to_char(last_day(sysdate - 16),'DD')) ||'-'||
            to_char(sysdate - 15,'MON')||'-'||
            decode(sign(to_char(sysdate,'DDD') - 15), 1,to_char(sysdate - 15,'RRRR'),to_char(sysdate,'RRRR') - 1),1,6),'15-MAY','Y','N') profit_flag
            into v_profit_sharing_payout
            from dual;
      ELSE
            v_profit_sharing_payout := p_profit_sharing_payout;

      END IF;

      select decode(apps.TTEC_GET_INSTANCE,--instance_name, -- changes made for version 4.1
                    'PROD','P','T') instance
      into v_instance
      from v$instance;

      Fnd_File.put_line(Fnd_File.LOG,  '              v_pay_date: '||v_pay_date);
      Fnd_File.put_line(Fnd_File.LOG,  '          v_cut_off_date: '||v_cut_off_date);
      Fnd_File.put_line(Fnd_File.LOG,  '      v_current_run_date: '||v_current_run_date);
      Fnd_File.put_line(Fnd_File.LOG,  ' v_profit_sharing_payout: '||v_profit_sharing_payout);
      v_module := 'c_emp_rec';
      v_loc := ' 20 ';
--      --Fnd_File.put_line(Fnd_File.LOG,v_module);
      g_current_run_date := v_current_run_date;
      g_1PP_ISR_QUOTA  :=  to_number(get_cfdi_map_code ('ISR Subsidy Adjusted 1PP','TTEC_MEXICO_SAT_CODES','ISR Subsidy Adjusted',v_current_run_date)); /* 5.0.6 */
      g_2PP_ISR_QUOTA  :=  to_number(get_cfdi_map_code ('ISR Subsidy Adjusted 2PP','TTEC_MEXICO_SAT_CODES','ISR Subsidy Adjusted',v_current_run_date)); /* 5.0.6 */
      Fnd_File.put_line(Fnd_File.LOG,  'ISR Subsidy Adjusted 1PP: '||get_amount(g_1PP_ISR_QUOTA));/* 5.0.6 */
      Fnd_File.put_line(Fnd_File.LOG,  'ISR Subsidy Adjusted 2PP: '||get_amount(g_2PP_ISR_QUOTA));/* 5.0.6 */

      BEGIN
         FOR r_emp_rec IN c_emp_rec (v_cut_off_date, v_current_run_date, v_profit_sharing_payout)
         LOOP
            g_emp_no := r_emp_rec.person_id;
            v_text := NULL;
            v_flag := 'N';
            v_ded_flag := 'N';
            Fnd_File.put_line(Fnd_File.LOG,  '---------------------------------------------');
            Fnd_File.put_line(Fnd_File.LOG,  '               person_id: '||r_emp_rec.person_id);
            Fnd_File.put_line(Fnd_File.LOG,  '  term_date/pay_run_date: '||r_emp_rec.actual_termination_date);
            v_module := 'c_emp_info';
            v_loc := ' 30 ';
--            --Fnd_File.put_line(Fnd_File.LOG,v_module);

          BEGIN
              --SELECT  CONVERT (TRIM (pucif.VALUE) || ' ','WE8MSWIN1252', 'UTF8')
             SELECT TRIM (pucif.VALUE)
               INTO v_pago_de_nomina
               FROM pay_user_tables put,
                    pay_user_columns puc,
                    pay_user_rows_f pur,
                    pay_user_column_instances_f pucif
              WHERE   put.user_table_name = 'TTEC_MEXICO_SAT_CODES'
                    AND puc.user_column_name = 'MX CFDI Input Value'
                    AND pur.row_low_range_or_name = 'CFDI_Value_1'
                    AND put.user_table_id = puc.user_table_id
                    AND put.user_table_id = puc.user_table_id
                    AND pucif.user_row_id = pur.user_row_id(+)
                    AND puc.user_column_id = pucif.user_column_id(+)
                    AND TRUNC(sysdate) BETWEEN pur.effective_start_date(+)
                                           AND pur.effective_end_date(+)
                    AND TRUNC(sysdate) BETWEEN pucif.effective_start_date(+)
                                           AND pucif.effective_end_date(+);
           EXCEPTION
             WHEN OTHERS THEN
                 v_pago_de_nomina := 'Pago de nómina';
           END;

            FOR r_emp_info
               IN c_emp_info (r_emp_rec.person_id,
                              r_emp_rec.actual_termination_date)
            LOOP
               g_emp_no :=  r_emp_info.employee_number;
               Fnd_File.put_line(Fnd_File.LOG,'r_emp_info.assignment_id: '||r_emp_info.assignment_id);
               Fnd_File.put_line(Fnd_File.LOG,'         employee_number: '||r_emp_info.employee_number);
               v_file_name :=
                     'MEX_'
                  || REPLACE(r_emp_info.gre,' ','_')
                  || '_'
                  || r_emp_info.employee_number
                  || '_'
                  || r_emp_info.loc_abbrv
                  || '_'
                  || TO_CHAR (v_current_run_date, 'YYYYMMDD')
                  --|| '_PAY.NOM';
                  || '_PAY.txt';
               v_file_type :=
                  UTL_FILE.fopen (p_output_directory,
                                  v_file_name,
                                  'w',
                                  32765);

               Fnd_File.put_line(Fnd_File.LOG,'             v_file_name: '||v_file_name);
--               --Fnd_File.put_line(Fnd_File.LOG,v_module);

               v_Payroll_Type := r_emp_info.PayrollType ;

               v_pay_vacation  := 0;
               v_pay_vacation  := get_value ('MX_PAY_VACATIONS',
                                               'Earning',
                                               'Pay Value',
                                               r_emp_info.assignment_id,
                                               v_cut_off_date,
                                               v_current_run_date,
                                               '[Positive Amount]'/* 2.4.1 */
                                      );
               IF v_pay_vacation != 0 THEN
                  v_Payroll_Type := 'E';
               END IF;

               IF v_Payroll_Type = 'E' THEN
                  v_PaymentFrequency := '99';
               ELSE
                  v_PaymentFrequency := '04';
               END IF;

               BEGIN  /* Record A */

--                  v_TotISRRefunds := get_balance (r_emp_info.assignment_id,
--                                          'ISR Refund',
--                                          '_ASG_GRE_RUN',
--                                          v_current_run_date);

                  v_TotISRRefunds:= NULL;

                  OPEN c_TotISR_Refund (r_emp_info.assignment_id,
                                       v_cut_off_date,
                                       v_current_run_date);
                  FETCH c_TotISR_Refund
                  INTO v_TotISRRefunds;
                  CLOSE c_TotISR_Refund;
                  --Fnd_File.put_line(Fnd_File.LOG,'v_TotISRRefunds >>>>>>>>>>>>> :'||v_TotISRRefunds);

--                  v_TotISRSubsidyRefunds:= NULL;
--
--                  OPEN c_TotISRSubsidy_Refund (r_emp_info.assignment_id,
--                                       v_cut_off_date,
--                                       v_current_run_date);
--                  FETCH c_TotISRSubsidy_Refund
--                  INTO v_TotISRSubsidyRefunds;
--                  CLOSE c_TotISRSubsidy_Refund;
--
--                  Fnd_File.put_line(Fnd_File.LOG,'v_TotISRSubsidyRefunds>>>>>>>>>>>>> :'||v_TotISRSubsidyRefunds);
--                  v_TotOtherPayments := get_balance (r_emp_info.assignment_id,
--                                          'ISR Subsidy for Employment Paid',
--                                          '_ASG_GRE_RUN',
--                                          v_current_run_date);

                  v_module := 'c_TotOtherPayments';
                  v_loc := ' 35 ';
                  v_TotOtherPayments:= 0;
                  --Fnd_File.put_line(Fnd_File.LOG,' Before OPEN c_TotOtherPayments');
                  OPEN c_TotOtherPayments (r_emp_info.assignment_id,
                                       v_cut_off_date,
                                       v_current_run_date,
                                       'Earning');
                  FETCH c_TotOtherPayments
                  INTO v_TotOtherPayments;
                  --Fnd_File.put_line(Fnd_File.LOG,' After OPEN c_TotOtherPayments');
                  CLOSE c_TotOtherPayments;

                  --Fnd_File.put_line(Fnd_File.LOG,' Before v_TotOtherPayments>>>>>>>>>>>>> :'||to_char(v_TotOtherPayments));
                  IF  v_TotOtherPayments <= 0 THEN
                      v_TotOtherPayments  := 0;
                  END IF;

                  v_TotOtherPayments := v_TotOtherPayments + NVL(v_TotISRRefunds,0) ;

                  --Fnd_File.put_line(Fnd_File.LOG,' After v_TotOtherPayments>>>>>>>>>>>>> :'||to_char(v_TotOtherPayments));

                  IF  v_TotOtherPayments < 0 THEN /* 5.0.4 removed = */
                      v_TotOtherPaymentsD := '';
                  ELSE
                      v_TotOtherPaymentsD := get_amount(v_TotOtherPayments);
                  END IF;

/* 3.4 Begin */
--                 v_module := '[A.7]';
--                 v_loc := ' 35 ';
--                 v_TotPercepcions := (get_ear_value (NULL,
--                                                   'Earning',
--                                                   'ISR Subject',
--                                                   r_emp_info.assignment_id,
--                                                   v_cut_off_date,
--                                                   v_current_run_date)
--                                    + get_balance (r_emp_info.assignment_id,
--                                              'ISR Exempt',
--                                              '_ASG_GRE_RUN',
--                                              v_current_run_date)
--                                    - get_balance (r_emp_info.assignment_id,
--                                              'Year End ISR Exempt for Fixed Earnings',
--                                              '_ASG_GRE_RUN',
--                                              v_current_run_date) /* 2.4.5 */
--                                    - get_balance (r_emp_info.assignment_id,
--                                                        '%ISR Exempt%Coupon%',  -- Year End ISR Exempt for Pantry Coupons
--                                                       '_ASG_GRE_RUN',
--                                                       v_current_run_date)
----                                    - get_balance (r_emp_info.assignment_id,
----                                                  'ISR Subsidy for Employment Paid', -- not consider subsidy for employment
----                                                  '_ASG_GRE_RUN',
----                                                  v_current_run_date)
--                                      )
--                           +  (  get_value (NULL,
--                                        'Non-payroll Payments',
--                                        'Pay Value',
--                                        r_emp_info.assignment_id,
--                                        v_cut_off_date,
--                                        v_current_run_date,
--                                        '[Positive Amount]'/* 2.4.1 */
--                                        )
----                               + get_value (NULL,
----                                       'Supplemental Earnings',
----                                       'ISR Exempt',
----                                        r_emp_info.assignment_id,
----                                        v_cut_off_date,
----                                        v_current_run_date,
----                                       '[Positive Amount]'/* 2.4.5 */
----                                       )
--                               + get_value (NULL, -- 1.11
--                                        'Tax Credit',
--                                        'Pay Value',
--                                        r_emp_info.assignment_id,
--                                        v_cut_off_date,
--                                        v_current_run_date,
--                                        '[Positive Amount]'/* 2.4.1 */
--                                        )
--                               + get_value ('MX_RE_SAVING_FUNDS', -- 1.4
--                                        'Information',
--                                        'Pay Value',
--                                        r_emp_info.assignment_id,
--                                        v_cut_off_date,
--                                        v_current_run_date,
--                                        '[Positive Amount]'/* 2.4.1 */
--                                        )
--                               + get_value ('MX_GROSERY_COUPONS', -- 1.4
--                                        'Imputed Earnings',
--                                        'Pay Value',
--                                        r_emp_info.assignment_id,
--                                        v_cut_off_date,
--                                        v_current_run_date,
--                                        '[Positive Amount]'/* 2.4.1 */
--                                        ) /* GROSERY COUPON */
--                               - get_value ('MX_SF_COMPANY_LIQ',  --1.4
--                                            'Non-payroll Payments',
--                                            'Pay Value',
--                                            r_emp_info.assignment_id,
--                                            v_cut_off_date,
--                                            v_current_run_date,
--                                            '[Positive Amount]'/* 2.4.1 */
--                                            )
--                               - get_value ('MX_SF_LIQUIDATION', --1.4
--                                            'Non-payroll Payments',
--                                            'Pay Value',
--                                            r_emp_info.assignment_id,
--                                            v_cut_off_date,
--                                            v_current_run_date,
--                                            '[Positive Amount]'/* 2.4.1 */
--                                            )
--                                        )
--                           + get_neg_value ('MX_CHRISTMAS_BONUS',                    /* 3.2 Begin */
--                                            'Supplemental Earnings',
--                                            'Pay Value',
--                                            r_emp_info.assignment_id,
--                                            v_cut_off_date,
--                                            v_current_run_date)       /* 3.2 End  */
--                           + get_neg_value (NULL,
--                                            'Deduction',
--                                            'Pay Value',
--                                            r_emp_info.assignment_id,
--                                            v_cut_off_date,
--                                            v_current_run_date)
--                                         ;
/* 3.4 End */

                   --Fnd_File.put_line(Fnd_File.LOG,'##########################');
                   --Fnd_File.put_line(Fnd_File.LOG,'    v_TotPercepcions before '||v_TotPercepcions);
                   --Fnd_File.put_line(Fnd_File.LOG,' -  v_TotISRSubsidyRefunds '|| v_TotISRSubsidyRefunds);

                   --v_TotPercepcions := NVL(v_TotPercepcions,0) - NVL(v_TotISRSubsidyRefunds,0);

                   --Fnd_File.put_line(Fnd_File.LOG,' v_TotPercepcions After '||v_TotPercepcions);
---------------------------------------

--          Fnd_File.put_line(Fnd_File.LOG,' ****************v_TotPercepcions := ');

--          Fnd_File.put_line(Fnd_File.LOG,' get_ear_value/NULL /Earning/ISR Subject :='||get_ear_value (NULL,
--                                                   'Earning',
--                                                   'ISR Subject',
--                                                   r_emp_info.assignment_id,
--                                                   v_cut_off_date,
--                                                   v_current_run_date));

--          Fnd_File.put_line(Fnd_File.LOG,' +  get_balance/ISR Exempt/_ASG_GRE_RUN :='||get_balance(r_emp_info.assignment_id,
--                                              'ISR Exempt',
--                                              '_ASG_GRE_RUN',
--                                              v_current_run_date));

--          Fnd_File.put_line(Fnd_File.LOG,' - get_balance/%ISR Exempt%Coupon%/_ASG_GRE_RUN :='||get_balance (r_emp_info.assignment_id,
--                                                        '%ISR Exempt%Coupon%',  -- Year End ISR Exempt for Pantry Coupons
--                                                       '_ASG_GRE_RUN',
--                                                       v_current_run_date));
--          Fnd_File.put_line(Fnd_File.LOG,' - get_balance/ISR Subsidy for Employment Paid/_ASG_GRE_RUN :='|| get_balance (r_emp_info.assignment_id,
--                                                  'ISR Subsidy for Employment Paid', -- not consider subsidy for employment
--                                                  '_ASG_GRE_RUN',
--                                                  v_current_run_date));

--          Fnd_File.put_line(Fnd_File.LOG,' +  get_value/NULL/Non-payroll Payments/Pay Value := '||  get_value (NULL,
--                                        'Non-payroll Payments',
--                                        'Pay Value',
--                                        r_emp_info.assignment_id,
--                                        v_cut_off_date,
--                                        v_current_run_date));

--          Fnd_File.put_line(Fnd_File.LOG,' +  get_value/NULL/Tax Credit/Pay Value :='|| get_value (NULL, -- 1.11
--                                        'Tax Credit',
--                                        'Pay Value',
--                                        r_emp_info.assignment_id,
--                                        v_cut_off_date,
--                                        v_current_run_date));
--
----          Fnd_File.put_line(Fnd_File.LOG,' +  get_value/NULL/Supplemental Earnings/ISR Exempt :='|| get_value (NULL,
----                                       'Supplemental Earnings',
----                                       'ISR Exempt',
----                                        r_emp_info.assignment_id,
----                                        v_cut_off_date,
----                                        v_current_run_date,
----                                       '[Positive Amount]'/* 2.4.5 */
----                                       ));
--          Fnd_File.put_line(Fnd_File.LOG,' +  get_value/MX_RE_SAVING_FUNDS/Information/Pay Value :='|| get_value ('MX_RE_SAVING_FUNDS', -- 1.4
--                                        'Information',
--                                        'Pay Value',
--                                        r_emp_info.assignment_id,
--                                        v_cut_off_date,
--                                        v_current_run_date));
--          Fnd_File.put_line(Fnd_File.LOG,' +  get_value/MX_GROSERY_COUPONS/Imputed Earnings/Pay Value :='|| get_value ('MX_GROSERY_COUPONS', -- 1.4
--                                        'Imputed Earnings',
--                                        'Pay Value',
--                                        r_emp_info.assignment_id,
--                                        v_cut_off_date,
--                                        v_current_run_date)); /* GROSERY COUPON */
--          Fnd_File.put_line(Fnd_File.LOG,' -  get_value/MX_SF_COMPANY_LIQ/Non-payroll Payments/Pay Value :='||  get_value ('MX_SF_COMPANY_LIQ',  --1.4
--                                            'Non-payroll Payments',
--                                            'Pay Value',
--                                            r_emp_info.assignment_id,
--                                            v_cut_off_date,
--                                            v_current_run_date));
--          Fnd_File.put_line(Fnd_File.LOG,' -  get_value/MX_SF_LIQUIDATION/Non-payroll Payments/Pay Value :='|| get_value ('MX_SF_LIQUIDATION', --1.4
--                                            'Non-payroll Payments',
--                                            'Pay Value',
--                                            r_emp_info.assignment_id,
--                                            v_cut_off_date,
--                                            v_current_run_date));

--          Fnd_File.put_line(Fnd_File.LOG,' +  get_neg_value/NULL/Deduction/Pay Value :='|| get_neg_value (NULL,
--                                            'Deduction',
--                                            'Pay Value',
--                                            r_emp_info.assignment_id,
--                                            v_cut_off_date,
--                                            v_current_run_date));

--------------------------------------------
--------------------------------------------

               v_module := '[A.8]';
               v_loc := ' 38 ';

--          Fnd_File.put_line(Fnd_File.LOG,' ****************v_TotDeductions := ');

--          Fnd_File.put_line(Fnd_File.LOG,' get_ded_value/NULL /Deductions/Pay Value :='|| get_ded_value (NULL,
--                                                   'Deductions',
--                                                   'Pay Value',
--                                                   r_emp_info.assignment_id,
--                                                   v_cut_off_date,
--                                                   v_current_run_date));

--          Fnd_File.put_line(Fnd_File.LOG,' +  get_value/ISR Subsidy for Employmen/NULL/Pay Value :='||get_value ('ISR Subsidy for Employment', -- April 05
--                                             NULL,
--                                            'Pay Value',
--                                            r_emp_info.assignment_id,
--                                            v_cut_off_date,
--                                            v_current_run_date));

--          Fnd_File.put_line(Fnd_File.LOG,' +  get_value/MX_Adjusment Subsidy Cause/Information/Pay Value/[Positive Amount] :='||get_value ('MX_Adjusment Subsidy Cause', -- April 05
--                                             'Information',
--                                            'Pay Value',
--                                            r_emp_info.assignment_id,
--                                            v_cut_off_date,
--                                            v_current_run_date,'[Positive Amount]'));

                 v_TotDeductions :=  get_ded_value (NULL,
                                                   'Deductions',
                                                   'Pay Value',
                                                   r_emp_info.assignment_id,
                                                   v_cut_off_date,
                                                   v_current_run_date)
--                                    + get_neg_value (NULL,
--                                                   'Earning',
--                                                   'Pay Value',
--                                                   r_emp_info.assignment_id,
--                                                   v_cut_off_date,
--                                                   v_current_run_date) /* 2.4.4 */
                                    + get_value ('ISR Subsidy for Employment', -- April 05
                                             NULL,
                                            'Pay Value',
                                            r_emp_info.assignment_id,
                                            v_cut_off_date,
                                            v_current_run_date)
                                    + get_1PP_ISR_subsidy_bal (r_emp_info.assignment_id,  /* 5.0.1 */
                                                              'ISR Subsidy for Employment',
                                                              '_ASG_GRE_RUN',
                                                              v_cut_off_date,
                                                              v_current_run_date);


                  --Fnd_File.put_line(Fnd_File.LOG,'v_TotDeductions>>>>> '||v_TotDeductions );
                 v_TotDeductionsD := get_amount (v_TotDeductions);
------------------------------
               v_module := '[D.5]'; --[Percepcions]
               v_loc := ' 39 ';
                 v_TotTaxExempts :=    (  get_balance (r_emp_info.assignment_id,
                                              'ISR Exempt', -- do not attemp to put percentage at all
                                              '_ASG_GRE_RUN',
                                              v_current_run_date) /* 2.4.5 */
--                                        - NVL(v_TotISRSubsidyRefunds,0)
                                       - get_balance (r_emp_info.assignment_id,
                                              'Year End ISR Exempt for Fixed Earnings',
                                              '_ASG_GRE_RUN',
                                              v_current_run_date) /* 2.4.5 */
                                        )
                                    - get_balance (r_emp_info.assignment_id,
                                                        '%ISR Exempt%Coupon%',  -- Year End ISR Exempt for Pantry Coupons
                                                       '_ASG_GRE_RUN',
                                                       v_current_run_date)
--                                    - get_balance (r_emp_info.assignment_id,
--                                                  'ISR Subsidy for Employment Paid', -- not consider subsidy for employment
--                                                  '_ASG_GRE_RUN',
--                                                  v_current_run_date)
                               +
                                      (  get_value (NULL,
                                        'Non-payroll Payments',
                                        'Pay Value',
                                        r_emp_info.assignment_id,
                                        v_cut_off_date,
                                        v_current_run_date,
                                        '[Positive Amount]'/* 2.4.1 */
                                        )
--                               + get_value (NULL,
--                                       'Supplemental Earnings',
--                                       'ISR Exempt',
--                                        r_emp_info.assignment_id,
--                                        v_cut_off_date,
--                                        v_current_run_date,
--                                       '[Positive Amount]'/* 2.4.5 */
--                                       )
                               + get_value (NULL, -- 1.11
                                        'Tax Credit',
                                        'Pay Value',
                                        r_emp_info.assignment_id,
                                        v_cut_off_date,
                                        v_current_run_date,
                                        '[Positive Amount]'/* 2.4.1 */
                                        )
                               + get_value ('MX_RE_SAVING_FUNDS', -- 1.4
                                        'Information',
                                        'Pay Value',
                                        r_emp_info.assignment_id,
                                        v_cut_off_date,
                                        v_current_run_date,
                                        '[Positive Amount]'/* 2.4.1 */
                                        )
                               + get_value ('MX_GROSERY_COUPONS', -- 1.4
                                        'Imputed Earnings',
                                        'Pay Value',
                                        r_emp_info.assignment_id,
                                        v_cut_off_date,
                                        v_current_run_date,
                                        '[Positive Amount]'/* 2.4.1 */
                                        ) /* GROSERY COUPON */
                               - get_value ('MX_SF_COMPANY_LIQ',  --1.4
                                            'Non-payroll Payments',
                                            'Pay Value',
                                            r_emp_info.assignment_id,
                                            v_cut_off_date,
                                            v_current_run_date,
                                            '[Positive Amount]'/* 2.4.1 */
                                            )
                               - get_value ('MX_INTERNET_ALLOWANCE',  --5.3
                                            'Earnings',
                                            'Pay Value',
                                            r_emp_info.assignment_id,
                                            v_cut_off_date,
                                            v_current_run_date,
                                            '[Positive Amount]'/* 5.3 */
                                            )
                               - get_value ('MX_ELECTRICITY_SERVICE_ALLOWANCE',  --5.3
                                            'Earnings',
                                            'Pay Value',
                                            r_emp_info.assignment_id,
                                            v_cut_off_date,
                                            v_current_run_date,
                                            '[Positive Amount]'/* 5.3 */
                                            )
                               - get_value ('MX_SF_LIQUIDATION', --1.4
                                            'Non-payroll Payments',
                                            'Pay Value',
                                            r_emp_info.assignment_id,
                                            v_cut_off_date,
                                            v_current_run_date,
                                            '[Positive Amount]'/* 2.4.1 */
                                            )
                                        )
                           + get_neg_value ('MX_CHRISTMAS_BONUS',     /* 3.2 begin */
                                            'Supplemental Earnings',
                                            'Pay Value',
                                            r_emp_info.assignment_id,
                                            v_cut_off_date,
                                            v_current_run_date)      /* 3.2 end */
                           + get_neg_value (NULL,
                                            'Deduction',
                                            'Pay Value',
                                            r_emp_info.assignment_id,
                                            v_cut_off_date,
                                            v_current_run_date)
                                            ;  --5    TotalTaxExempt     Decimal    SI';

--          Fnd_File.put_line(Fnd_File.LOG,'v_TotTaxExempts :'|| v_TotTaxExempts);
--          Fnd_File.put_line(Fnd_File.LOG,'*********************************************************************  BEGIN    TotalTaxExempt ');
--
--
--          Fnd_File.put_line(Fnd_File.LOG,' - MX_ELECTRICITY_SERVICE_ALLOWANCE/Earnings/Pay Value :get_neg_value'|| get_neg_value ('MX_ELECTRICITY_SERVICE_ALLOWANCE',
--                                            'Earnings',
--                                            'Pay Value',
--                                            r_emp_info.assignment_id,
--                                            v_cut_off_date,
--                                            v_current_run_date) ); /* 5.3 */
--          Fnd_File.put_line(Fnd_File.LOG,' - MX_INTERNET_ALLOWANCE/Non-payroll Payments/Pay Value :get_value'|| get_value ('MX_INTERNET_ALLOWANCE',  --1.4
--                                             'Earnings',
--                                            'Pay Value',
--                                            r_emp_info.assignment_id,
--                                            v_cut_off_date,
--                                            v_current_run_date,
--                                            '[Positive Amount]'/* 2.4.1 */
--                                            ));
--         Fnd_File.put_line(Fnd_File.LOG,' - MX_ELECTRICITY_SERVICE_ALLOWANCE/Non-payroll Payments/Pay Value :get_value'|| get_value ('MX_ELECTRICITY_SERVICE_ALLOWANCE',  --1.4
--                                             'Earnings',
--                                            'Pay Value',
--                                            r_emp_info.assignment_id,
--                                            v_cut_off_date,
--                                            v_current_run_date,
--                                            '[Positive Amount]'/* 2.4.1 */
--                                            ));
-------------------------

--          Fnd_File.put_line(Fnd_File.LOG,'ISR Exempt :get_balance'|| get_balance (r_emp_info.assignment_id,
--                                              'ISR Exempt',
--                                              '_ASG_GRE_RUN',
--                                              v_current_run_date) /* 2.4.5 */
--                                              );
--          Fnd_File.put_line(Fnd_File.LOG,' - Year End ISR Exempt for Fixed Earnings :get_balance'||  get_balance (r_emp_info.assignment_id,
--                                              'Year End ISR Exempt for Fixed Earnings',
--                                              '_ASG_GRE_RUN',
--                                              v_current_run_date) /* 2.4.5 */
--                                        );

--          Fnd_File.put_line(Fnd_File.LOG,' - %ISR Exempt%Coupon :get_balance'||   get_balance (r_emp_info.assignment_id,
--                                                        '%ISR Exempt%Coupon%',  -- Year End ISR Exempt for Pantry Coupons
--                                                       '_ASG_GRE_RUN',
--                                                       v_current_run_date));
----                                    - get_balance (r_emp_info.assignment_id,
----                                                  'ISR Subsidy for Employment Paid', -- not consider subsidy for employment
----                                                  '_ASG_GRE_RUN',
----                                                  v_current_run_date)
--          Fnd_File.put_line(Fnd_File.LOG,' + Non-payroll Payments :get_value'||   get_value (NULL,
--                                        'Non-payroll Payments',
--                                        'Pay Value',
--                                        r_emp_info.assignment_id,
--                                        v_cut_off_date,
--                                        v_current_run_date,
--                                        '[Positive Amount]'/* 2.4.1 */
--                                        ) );
----          Fnd_File.put_line(Fnd_File.LOG,' + NULL/Supplemental Earnings/ISR Exempt :get_value'||   get_value (NULL,
----                                       'Supplemental Earnings',
----                                       'ISR Exempt',
----                                        r_emp_info.assignment_id,
----                                        v_cut_off_date,
----                                        v_current_run_date,
----                                       '[Positive Amount]'/* 2.4.5 */
----                                       ));
--          Fnd_File.put_line(Fnd_File.LOG,' + NULL/Tax Credit/Pay Value :get_value'||   get_value (NULL, -- 1.11
--                                        'Tax Credit',
--                                        'Pay Value',
--                                        r_emp_info.assignment_id,
--                                        v_cut_off_date,
--                                        v_current_run_date,
--                                        '[Positive Amount]'/* 2.4.1 */
--                                        ));
--          Fnd_File.put_line(Fnd_File.LOG,' + MX_RE_SAVING_FUNDS/Information/Pay Value :get_value'|| get_value ('MX_RE_SAVING_FUNDS', -- 1.4
--                                        'Information',
--                                        'Pay Value',
--                                        r_emp_info.assignment_id,
--                                        v_cut_off_date,
--                                        v_current_run_date,
--                                        '[Positive Amount]'/* 2.4.1 */
--                                        ));
--          Fnd_File.put_line(Fnd_File.LOG,' + MX_GROSERY_COUPONS/Imputed Earnings/Pay Value :get_value'|| get_value ('MX_GROSERY_COUPONS', -- 1.4
--                                        'Imputed Earnings',
--                                        'Pay Value',
--                                        r_emp_info.assignment_id,
--                                        v_cut_off_date,
--                                        v_current_run_date,
--                                        '[Positive Amount]'/* 2.4.1 */
--                                        )); /* GROSERY COUPON */
--          Fnd_File.put_line(Fnd_File.LOG,' - MX_SF_COMPANY_LIQ/Non-payroll Payments/Pay Value :get_value'|| get_value ('MX_SF_COMPANY_LIQ',  --1.4
--                                            'Non-payroll Payments',
--                                            'Pay Value',
--                                            r_emp_info.assignment_id,
--                                            v_cut_off_date,
--                                            v_current_run_date,
--                                            '[Positive Amount]'/* 2.4.1 */
--                                            ));
--          Fnd_File.put_line(Fnd_File.LOG,' - MX_SF_LIQUIDATION/Non-payroll Payments/Pay Value :get_value'||  get_value ('MX_SF_LIQUIDATION', --1.4
--                                            'Non-payroll Payments',
--                                            'Pay Value',
--                                            r_emp_info.assignment_id,
--                                            v_cut_off_date,
--                                            v_current_run_date,
--                                            '[Positive Amount]'/* 2.4.1 */
--                                            ));

--          Fnd_File.put_line(Fnd_File.LOG,' - MX_CHRISTMAS_BONUS/Supplemental Earnings/Pay Value :get_neg_value'|| get_neg_value ('MX_CHRISTMAS_BONUS',
--                                            'Supplemental Earnings',
--                                            'Pay Value',
--                                            r_emp_info.assignment_id,
--                                            v_cut_off_date,
--                                            v_current_run_date) ); /* 3.2 */
--
--          Fnd_File.put_line(Fnd_File.LOG,' - NULL/Deduction/Pay Value :get_neg_value'|| get_neg_value (NULL,
--                                            'Deduction',
--                                            'Pay Value',
--                                            r_emp_info.assignment_id,
--                                            v_cut_off_date,
--                                            v_current_run_date) );


--          Fnd_File.put_line(Fnd_File.LOG,'********************************************************************* END    TotalTaxExempt ');

-----------------------
         /* 3.4 Begin */
         IF get_value (NULL, NULL, 'ISR Exempt',
                                        r_emp_info.assignment_id,
                                        v_cut_off_date,
                                        v_current_run_date,
                                        '[Negative Amount]') >
              get_value (NULL, NULL,'ISR Exempt',
                                        r_emp_info.assignment_id,
                                        v_cut_off_date,
                                        v_current_run_date,
                                        '[Positive Amount]')

         THEN
                v_TotTaxExempts :=
                  get_value (NULL, NULL, 'ISR Exempt',
                                            r_emp_info.assignment_id,
                                            v_cut_off_date,
                                            v_current_run_date,
                                          '[Positive Amount]'
                                       ) ;
         END IF;


         v_module := '[A.7]';
         v_loc := ' 35 ';
         v_TotPercepcions := get_ear_value (NULL,
                                           'Earning',
                                           'ISR Subject',
                                           r_emp_info.assignment_id,
                                           v_cut_off_date,
                                           v_current_run_date)
                            + v_TotTaxExempts;
         /* 3.4 End */



                          v_TotSepComps := get_value ('MX_LI_20DAYS',
                                                   'Amends',
                                                   'Pay Value',
                                                   r_emp_info.assignment_id,
                                                   v_cut_off_date,
                                                   v_current_run_date,
                                                   '[Positive Amount]'/* 2.4.1 */
                                                   )
                                        + get_value ('MX_LI_SENIORITY_PREMIUM',
                                                   'Amends',
                                                   'Pay Value',
                                                   r_emp_info.assignment_id,
                                                   v_cut_off_date,
                                                   v_current_run_date,
                                                   '[Positive Amount]'/* 2.4.1 */
                                                   )
                                        + get_value ('MX_LI_SEVERANCE_PAY',
                                                   'Amends',
                                                   'Pay Value',
                                                   r_emp_info.assignment_id,
                                                   v_cut_off_date,
                                                   v_current_run_date,
                                                   '[Positive Amount]'/* 2.4.1 */
                                                   );
                           IF v_TotSepComps = 0 THEN
                             v_TotSepCompsD := '';
                           ELSE
                             v_TotSepCompsD := get_amount(v_TotSepComps);
                           END IF;

                          v_TotISR := get_value ('ISR',
                                        'Tax Deductions',
                                        'Pay Value',
                                        r_emp_info.assignment_id,
                                        v_cut_off_date,
                                        v_current_run_date);



                           IF v_TotISR = 0 THEN
                              v_TotISRD := '';
                           ELSE
                              v_TotISRD := get_amount(v_TotISR);
                           END IF;

-------------------------------
/* .TXT BEGIN ------- */
               --
               -- net amount =
               --

               v_net_pay := v_TotPercepcions + v_TotOtherPayments - v_TotDeductions;
               v_TotIncome := v_TotPercepcions + v_TotOtherPayments;

--                  fnd_file.put_line (fnd_file.LOG,'================[S]'  );
--                  fnd_file.put_line (fnd_file.LOG,'           v_net_pay [' || v_net_pay||']');
--                  fnd_file.put_line (fnd_file.LOG,'=   v_TotPercepcions [' || v_TotPercepcions||']');
--                  fnd_file.put_line (fnd_file.LOG,'+ v_TotOtherPayments [' || v_TotOtherPayments||']');
--                  fnd_file.put_line (fnd_file.LOG,'-    v_TotDeductions [' || v_TotDeductions||']');
--                  fnd_file.put_line (fnd_file.LOG,'   v_TotISR [' ||v_TotISR||']');

               SELECT DECODE (SIGN (v_net_pay - 0), 1, v_net_pay, 0)
                 INTO v_net_pay_dsp
                 FROM DUAL;


--               BEGIN
--                  v_text :=
--                        '[H1]'
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || TO_CHAR (SYSDATE, 'YYYYMMDD')
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || 'Pago en una solo exhibicion'
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || 'RECIBO_NOMINA'
--                     || '|'
--                     || ''
--                     || '|'
--                     --|| 'Deducciones Nomina' --Commented out for 2017 format no text
--                     || ''
--                     || '|'
--                     || v_TotDeductionsD
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || r_emp_info.emp_postal_code  --r_emp_info.H1_F30 --'MEXICO DF'
--                     || '|'
--                     || 'NA' -- modified for 2017 format'TRANSFERENCIA ELECTRONICA'
--                     || '|'
--                     || 'MXN'
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || iby_amount_in_words.get_amount_in_words ( v_net_pay_dsp ,'MXN')
--                     || '|'
--                     || 'D02'
--                     || '|'
--                     || v_instance -- 'T' for NON-PROD or 'P' for PRODUCTION
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || 'NOM'
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || '';
--                  UTL_FILE.put_line (v_file_type, v_text);
--                  fnd_file.put_line (fnd_file.output, v_text);
--               END;

               /* 3.0 */
               BEGIN
                  v_text := --[H1F_Comprobante]|3.3|||2017-10-09T09:12:56|99||6915.38|988.19|MXN||5927.19|N|PUE|45600|
                        '[H1F_Comprobante]'
                     || '|'
                     || '3.3'
                     || '|'
                     || ''
                     || '|'
                     || ''
                     || '|'
                     || TO_CHAR (SYSDATE,'YYYY-MM-DD')||'T'||TO_CHAR (SYSDATE,'HH24:MI:SS')
                     || '|'
                     || '99'
                     || '|'
                     || ''
                     || '|'
                     || get_amount(v_TotIncome)
                     || '|'
                     || v_TotDeductionsD
                     || '|'
                     || 'MXN'
                     || '||' /* 3.5 */
                     || get_amount ( v_net_pay_dsp)
                     || '|'
                     || 'N'
                     || '|'
                     || 'PUE'
                     || '|'
                     || r_emp_info.emp_postal_code
                     || '|';
                  UTL_FILE.put_line (v_file_type, v_text);
                  fnd_file.put_line (fnd_file.output, v_text);
               END;

               BEGIN
                  v_text := --[H1C_Comprobante]||||||||||||||||||||||||||NOM||D02||(CINCO MIL NOVECIENTOS VEINTISIETE PESOS CON 19/100 M.N.)||||||||||||||||||NOM||||RECIBO_NOMINA|
                           '[H1C_Comprobante]||||||||||||||||||||||||||NOM||D02||('
                     || iby_amount_in_words.get_amount_in_words ( v_net_pay_dsp ,'MXN')
                     || ')||||||||||||||||||NOM||||RECIBO_NOMINA|';
                  UTL_FILE.put_line (v_file_type, v_text);
                  fnd_file.put_line (fnd_file.output, v_text);
               END;

               BEGIN
                  FOR r_legal_info IN c_legal_info (r_emp_info.payroll_id)
                  LOOP
--                     v_text := NULL;
--                     v_text :=
--                           '[H2]'
--                        || '|'
--                        || r_legal_info.org_information1
--                        || '|'
--                        || r_legal_info.org_information2
--                        || '|'
--                        || ''
--                        || '|'
--                        || '' --r_legal_info.address_line_1 -- commented out for 2017 format
--                        || '|'
--                        || '' --r_legal_info.address_line_2 -- commented out for 2017 format
--                        || '|'
--                        || ''
--                        || '|'
--                        || ''
--                        || '|'
--                        || ''
--                        || '|'
--                        || ''
--                        || '|'
--                        || '' --r_legal_info.town_or_city -- commented out for 2017 format
--                        || '|'
--                        || '' --r_legal_info.region_1 -- commented out for 2017 format
--                        || '|'
--                        || '' --r_legal_info.country -- commented out for 2017 format
--                        || '|'
--                        || '' --r_legal_info.postal_code -- commented out for 2017 format
--                        || '|'
--                        || 'Sueldos y Salarios'
--                        || '|'
--                        || ''
--                        || '|'
--                        || ''
--                        || '|'
--                        || ''
--                        || '|'
--                        || ''
--                        || '|'
--                        || ''
--                        || '|'
--                        || ''
--                        || '|'
--                        || ''
--                        || '|'
--                        || ''
--                        || '|'
--                        || ''
--                        || '|'
--                        --|| r_emp_info.employer_acc; -- Commeneted out for 2017 format
--                        ||'';
--                     UTL_FILE.put_line (v_file_type, v_text);
--                     fnd_file.put_line (fnd_file.output, v_text);

                    /* 3.0 BEGIN */
                     v_text := NULL;
                     v_text := -- [H3F_Emisor]|SSI041018MF7|SERVICIOS SSI INTEGRALES, S. DE R.L. DE C.V.|601|
                           '[H3F_Emisor]'
                        || '|'
                        || r_legal_info.org_information2
                        || '|'
                        || r_legal_info.org_information1
                        || '|'
                        || '601'
                        || '|'
                        || '';
                     UTL_FILE.put_line (v_file_type, v_text);
                     fnd_file.put_line (fnd_file.output, v_text);
                     /* 3.0 End */

                  END LOOP;
               END;

--               BEGIN
--                  v_text := NULL;
--                  v_text :=
--                        '[H4]'
--                     || '|'
--                     --||  CONVERT (TRIM (r_emp_info.full_name) || ' ','WE8MSWIN1252', 'UTF8') --r_emp_info.full_name
--                     || TRIM (r_emp_info.full_name)
--                     || '|'
--                     || r_emp_info.rfc_id -- not curp - emp data driven by RFC
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || '' --r_emp_info.country -- commented out for 2017 format
--                     || '|'
--                     || '' --r_emp_info.postal_code -- commented out for 2017 format
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     --|| CONVERT (TRIM (r_emp_info.email_address) || ' ','WE8MSWIN1252', 'UTF8') --r_emp_info.email_address /* 1.14 */
--                     || TRIM (r_emp_info.email_address)
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || '';
--                  UTL_FILE.put_line (v_file_type, v_text);
--                  fnd_file.put_line (fnd_file.output, v_text);
--               END;

              /* 3.0 Begin*/
              BEGIN
                  v_text := NULL;
                  v_text := -- [H4F_Receptor]|NUFJ7509068R0|Nuño Fernandez Jorge Enrique|||P01|
                        '[H4F_Receptor]'
                     || '|'
                     || r_emp_info.rfc_id -- not curp - emp data driven by RFC
                     || '|'
                     || TRIM (r_emp_info.full_name)
                     || '|||P01|';
                  UTL_FILE.put_line (v_file_type, v_text);
                  fnd_file.put_line (fnd_file.output, v_text);
               END;

              BEGIN
                  v_text := NULL;
                  v_text := -- [H4C_Receptor]|||coquenuno@gmail.com|
                        '[H4C_Receptor]'
                     || '|||'
                     || TRIM (r_emp_info.email_address)
                     || '|';
                  UTL_FILE.put_line (v_file_type, v_text);
                  fnd_file.put_line (fnd_file.output, v_text);
               END;
              /* 3.0 End */

--               BEGIN
--                  v_text := NULL;
--                  v_text :=
--                        '[D]'
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || v_pago_de_nomina --'Periodo de Pago' -- Modified contect for 2017 format
--                     || '|'
--                     || ''
--                     || '|'
--                     || '1'
--                     || '|'
--                     || 'ACT' --'Service' -- Modified contect for 2017 format
--                     || '|'
--                     || ''
--                     || '|'
--                    -- ||  get_amount(v_TotPercepcions)
--                     ||  get_amount(v_TotIncome) -- Levicom input on 4/10
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     --||  get_amount(v_TotPercepcions)
--                     ||  get_amount(v_TotIncome) -- Levicom input on 4/10
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || get_amount (get_value ('ISR',
--                                               NULL,
--                                               'Pay Value',
--                                               r_emp_info.assignment_id,
--                                               v_cut_off_date,
--                                               v_current_run_date))
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || '';
--                  UTL_FILE.put_line (v_file_type, v_text);
--                  fnd_file.put_line (fnd_file.output, v_text);
--               END;

              /* 3.0 Begin */

               BEGIN
                  v_text := NULL;
                  v_text := --[D1F_Detalle]|84111505||1|ACT||Pago de nómina|6915.38|6915.38|988.19|
                        '[D1F_Detalle]|84111505||1|ACT||'
                     || v_pago_de_nomina
                     || '|'
                     || get_amount(v_TotIncome)
                     || '|'
                     || get_amount(v_TotIncome)
                     || '|'
                     || v_TotDeductionsD;

                  UTL_FILE.put_line (v_file_type, v_text);
                  fnd_file.put_line (fnd_file.output, v_text);
               END;

              /* 3.0 End */

--               BEGIN


--                  v_text := NULL;
--                  v_text :=
--                        '[S]'
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     -- below should be NET PAY = PES amt1 + amt2 - DES amt1
--                     || get_amount ( v_net_pay_dsp)
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || '' --commented out for feedback received on April 06 - not needed
----                     || get_amount (get_value ('ISR',
----                                               NULL,
----                                               'Pay Value',
----                                               r_emp_info.assignment_id,
----                                               v_cut_off_date,
----                                               v_current_run_date)
----                                               )
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     --||  get_amount(v_TotPercepcions)
--                     ||  get_amount(v_TotIncome) -- Levicom input on 4/10
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''
--                     || '|'
--                     || '';
--                  UTL_FILE.put_line (v_file_type, v_text);
--                  fnd_file.put_line (fnd_file.output, v_text);
--               END;

/* .TXT END ------- */
               /* 2.3.2 BEGIN */
               v_NumPaidDaysD := get_value ('MX_DAYS_IN_PERIOD',
                                               NULL,
                                               'Days',
                                               r_emp_info.assignment_id,
                                               v_cut_off_date,
                                               v_current_run_date,
                                               '[Positive Amount]'/* 2.4.1 */
                                               );

               IF v_NumPaidDaysD = '0' THEN
                  v_NumPaidDaysD := '1'; --NumPaidDays cannot have zero, ex-emp needs to be 1 6/2/2017 Levicom feedback /* 2.3.2 */
               END IF;
               /* 2.3.2 END */

               v_module := '[A]';
               v_loc := ' 40 ';

                 /* 2.4.9 Begin */
                  IF v_TotPercepcions != 0 THEN

                     v_TotPercepcionsD:= get_amount(v_TotPercepcions);
                  ELSE
                     v_TotPercepcionsD := '';
                  END IF;

                  /* 2.4.9 END */

                  --v_text := '[A]-Payroll'       --    A    [Payroll]    Alphanumeric    YES
                  v_text := '[Nomina]'       --    A    [Payroll]    Alphanumeric    YES
                     || '|'
                     || '1.2'                --    1    Version    Alphanumeric    YES
                     || '|'
                     || v_Payroll_Type            --    2    PayrollType     "Catalog c_PayrollType"    YES    * TERM  = E, Active EE's = O,
                     || '|'
                     || TO_CHAR (v_pay_date, 'YYYY-MM-DD')   --    3    PaymentDate    "Date (year-month-day)"    YES
                     || '|'
                     || TO_CHAR (v_cut_off_date, 'YYYY-MM-DD') --    4    PaymentStartDate    "Date (year-month-day)"    YES    *  TERM ( E )= Pay Date
                     || '|'
                     || TO_CHAR (v_current_run_date, 'YYYY-MM-DD') --    5    PaymentEndDate    "Date (year-month-day)"    YES    *  TERM ( E )= Pay Date
                     || '|'
                     || v_NumPaidDaysD   --    6    NumPaidDays    Decimal    YES    * TERM ( E ) = 1  /* 2.3.2 */
                     || '|'
                     || get_amount(v_TotPercepcions) --    7    TotalEarnings     Decimal    NO SUM of 2 PE columns /* 2.4.9 */
                     --|| v_TotPercepcionsD  --    7    TotalEarnings     Decimal    NO SUM of 2 PE columns /* 2.4.9 */
                     || '|'
                     || v_TotDeductionsD     --    8    TotalDeductions     Decimal    NO
                     || '|'
                     || v_TotOtherPaymentsD; --    9    TotalOtherPayments     Decimal    NO
-- Commented out - Levicom feedback does not like negative value, since not REQUIRED, send NULL
--                     || get_amount (
--                             get_balance (r_emp_info.assignment_id,
--                                          'ISR Subsidy for Employment Paid',
--                                          '_ASG_GRE_RUN',
--                                          v_current_run_date)); --    9    TotalOtherPayments     Decimal    NO

                  UTL_FILE.put_line (v_file_type, v_text);
                  fnd_file.put_line (fnd_file.output, v_text);


               END;

               v_module := '[B]';
               v_loc := ' 50 ';
--               --Fnd_File.put_line(Fnd_File.LOG,v_module);
               BEGIN /* Record B */

                  --v_text := '[B]-Issuer'          --                     B    [Issuer]    Alphanumeric    NO
                  v_text := '[Emisor]'          --                     B    [Issuer]    Alphanumeric    NO
                     || '|'
                     || ''                           --1    Curp (Population Registry No.)    Alphanumeric    NO    ??
                     || '|'
                     || r_emp_info.org_ssn           --2    EmployerRegistration     Alphanumeric    NO
                     || '|'
                     --|| r_emp_info.rfc_id;                   --    3    OriginEmployerRfc     Alphanumeric    NO
                     || '';                         --3    OriginEmployerRfc     Alphanumeric    NO

                  UTL_FILE.put_line (v_file_type, v_text);
                  fnd_file.put_line (fnd_file.output, v_text);

               END;

--               v_module := '[BA]';
--               v_loc := ' 60 ';
--               --Fnd_File.put_line(Fnd_File.LOG,v_module);
--
--               BEGIN /* Record BA*/

--                  v_text :=
--                        '[BA]-NTCSEnt'          --    BA    [NTCSEnt]    Alphanumeric    YES
--                     || '|'
--                     || 'IM'                        --    1    ResourceOrigin     Catalog c_ResourceOrigin    YES    ??
--                     || '|'
--                     || '';                     --    2    AmountOwnResource     Decimal    NO

--                  UTL_FILE.put_line (v_file_type, v_text);
--                  fnd_file.put_line (fnd_file.output, v_text);


--               END;

               v_module := '[C]';
               v_loc := ' 80 ';
--               --Fnd_File.put_line(Fnd_File.LOG,v_module);

               BEGIN /* Record C */

                  --v_text := '[C]-Recipient'        --    C    [Recipient]    Alphanumeric    YES
                  v_text := '[Receptor]'        --    C    [Recipient]    Alphanumeric    YES
                     || '|'
                     || r_emp_info.national_identifier              --    1    CURP    Alphanumeric    YES    SSN??
                     || '|'
                     || r_emp_info.ssn_id             --    2    SocialSecurityNum    Alphanumeric    NO
                     || '|'
                     || TO_CHAR (r_emp_info.WorkingRelStartDate, 'YYYY-MM-DD')              --    3    WorkingRelStartDate    "date (year-month-day)"    NO    * Verify that this data comes from: People-Benefits-Adjusted Service Date
                     || '|'
                     || 'P'||r_emp_info.length_service_week||'W'              --    4    LengthService    Alphanumeric    NO
                     || '|'
                     || r_emp_info.ContractType             --    5    ContractType    "Catalogc_ContractType"    YES
                     || '|'
                     || 'No'              --    6    Unionized     Alphanumeric    NO /* 5.2 */
                     || '|'
                     --|| r_emp_info.WorkingDayType              --    7    WorkingDayType     Catalog c_WorkingDayType    NO
                     || ''              --    7    WorkingDayType     Catalog c_WorkingDayType    NO
                     || '|'
                     || '02'              --    8    RegimeType    "Catalog c_RegimeType"    YES    * Currently it has "Sueldos y Salarios" name, new catalogue specify the Regimen type as "Sueldos"
                     || '|'
                     || r_emp_info.employee_number             --    9    EmployeeNum     Alphanumeric    YES
                     || '|'
                     || ''              --    10    Department    Alphanumeric    NO
                     || '|'
                     || ''              --    11    Post     Alphanumeric    NO
                     || '|'
                     || '1'              --    12    RiskPost     "Catalog c_RiskPost"    NO
                     || '|'
                     || v_PaymentFrequency       --    13    PaymentFrequency     "Catalog c_PaymentFrequency"    YES    * This have to be 04 = Quincenal for Payroll Type Ordinary "O", 99 = Otra Periodicidad for Payroll Type Extraordinary "E"
                     || '|'
                     || ''              --    14    Bank     "Catalog c_Bank"    NO    * I will verify if it is a required field
                     || '|'
                     || ''              --    15    BankAccount     Alphanumeric    NO    * I will verify if it is a required field
                     || '|'
                     || ''              --    16    BaseSalaryFeeCont     Decimal    NO
                     || '|'
                --     || ''  --    17    IntegratedDailySalary    Decimal    NO --Commented out on June 9,2017 IDW is incorrect for CAP employees /* 2.3.5 */
                     || get_amount(get_value ('Integrated Daily Wage',
                                                       'Information',
                                                       'Pay Value',
                                                       r_emp_info.assignment_id,
                                                       v_cut_off_date,
                                                       v_current_run_date,
                                                       '[Positive Amount]'/* 2.4.1 */
                                                       ))             --    17    IntegratedDailySalary    Decimal    NO /* 2.3.5 */
                     || '|'
                     || r_emp_info.StateCode;             --    18    StateCode     "Catalog c_Status"    YES

                  UTL_FILE.put_line (v_file_type, v_text);
                  fnd_file.put_line (fnd_file.output, v_text);

               END;
/* 2.3.4  Begin */
               /* Edna'original request, not CFDI , Edna confirmed to take out on 3/5 excel feedback response ?*/
--               v_module := '[CA]';
--               v_loc := ' 90 ';
--               --Fnd_File.put_line(Fnd_File.LOG,v_module);
--               BEGIN /* Record CA Subcontracting */

--                  --v_text := '[CA]-Subcontracting'                  --    CA    [Subcontracting]    Alphanumeric    NO
--                  v_text := '[Subcontratacion]'                  --    CA    [Subcontracting]    Alphanumeric    NO
--                     || '|'
--                     || 'TME940222TN5'      --1    WorkRfc     Alphanumeric    YES
--                     || '|'
--                     || 100;                --2    TimePercentage     Decimal    YES

--                  UTL_FILE.put_line (v_file_type, v_text);
--                  fnd_file.put_line (fnd_file.output, v_text);

--               END;
/* 2.3.4  Begin */

               v_module := '[D]';
               v_loc := '100 ';
--               Fnd_File.put_line(Fnd_File.LOG,v_module);

               /* 2.3.3 Begin */
               v_TotalSalariesD := get_amount(v_TotPercepcions - v_TotSepComps);
               v_TotalTaxableD  := get_amount (get_ear_value (NULL,
                                                   'Earning',
                                                   'ISR Subject',
                                                   r_emp_info.assignment_id,
                                                   v_cut_off_date,
                                                   v_current_run_date));

               v_TotalTaxExemptD := get_amount(v_TotTaxExempts);

--              Fnd_File.put_line(Fnd_File.LOG,'v_TotalSalariesD  ['||v_TotalSalariesD||']' );
--              Fnd_File.put_line(Fnd_File.LOG,'v_TotSepCompsD ['||v_TotSepCompsD||']' );
--              Fnd_File.put_line(Fnd_File.LOG,'v_TotalTaxableD  ['||v_TotalTaxableD||']'  );
--              Fnd_File.put_line(Fnd_File.LOG,'v_TotalTaxExemptD  ['||v_TotalTaxExemptD||']'  );

              IF    NVL(v_TotalSalariesD,'0.00') != '0.00'
                     OR NVL(v_TotSepCompsD,'0.00') != '0.00'
                     OR NVL(v_TotalTaxableD,'0.00') != '0.00'
                     OR NVL(v_TotalTaxExemptD,'0.00') != '0.00'
                  THEN
                       BEGIN /* Record D */

                          --v_text := '[D]-Total Earnings'          --    D    [Earnings]    Alphanumeric    NO
                          v_text := '[Percepciones]'          --    D    [Earnings]    Alphanumeric    NO
                             || '|'
                             || v_TotalSalariesD    --1    TotalSalaries     Decimal    NO
                             || '|'
                             || v_TotSepCompsD                         --2    TotalSeparationCompensation     Decimal    NO'
                             || '|'
        --                     || get_amount (get_value ('MX_RE_RETIRE',
        --                                               NULL,
        --                                               'Pay Value',
        --                                               r_emp_info.assignment_id,
        --                                               v_cut_off_date,
        --                                               v_current_run_date))    -- 3    TotalRetirementPensionPayout     Decimal    NO' commented out on 3/25 per Edna's Email Excel response
                             || ''                                               -- 3    TotalRetirementPensionPayout     Decimal    NO'
                             || '|'
                             || v_TotalTaxableD  --4    TotalTaxable     Decimal    SI'
                             || '|'
                             || v_TotalTaxExemptD;   --5    TotalTaxExempt     Decimal    SI';


                          UTL_FILE.put_line (v_file_type, v_text);
                          fnd_file.put_line (fnd_file.output, v_text);


                       END;
              END IF;

              /* 2.3.3 End */

              BEGIN

                  v_module := '[DA]';
                  v_loc := ' 80 ';
--                  --Fnd_File.put_line(Fnd_File.LOG,v_module);

                  --Fnd_File.put_line(Fnd_File.LOG,'r_emp_info.assignment_id:'||r_emp_info.assignment_id);
--                  --Fnd_File.put_line(Fnd_File.LOG,'          v_cut_off_date :'||v_cut_off_date);
--                  --Fnd_File.put_line(Fnd_File.LOG,'      v_current_run_date :'||v_current_run_date);

                  v_process_dc := '';
                  v_previous_ele_name := 'FIRST_ELEMENT';
                  v_current_ele_name  := '';
                  v_first_record      := 'Y';

                  FOR r_emp_element
                     IN c_emp_element (r_emp_info.assignment_id,
                                       v_cut_off_date,
                                       v_current_run_date,
                                       'Earning')
                  LOOP

                       g_label3 := r_emp_element.reporting_name;
                       BEGIN /* Record DA*/

                             IF r_emp_element.reporting_name in ('20 Días por Año',       --MX_LI_20DAYS
                                                               'Prima de Antigüedad',   --MX_LI_SENIORITY_PREMIUM
                                                               'Indemnización C.'       --MX_LI_SEVERANCE_PAY
                                                               )
                             THEN

                              v_process_dc := 'Y';

                             END IF;

--                             --Fnd_File.put_line(Fnd_File.LOG,'       r_emp_element.section :'||r_emp_element.section);
--                             --Fnd_File.put_line(Fnd_File.LOG,'      r_emp_element.sat_code :'||r_emp_element.sat_code);

                             v_text := NULL;
                             --v_text :=    '[DA]-Earning'              --    DA    [Earning]    Alphanumeric    YES
                             v_text :=    '[Percepcion]'              --    DA    [Earning]    Alphanumeric    YES
                                    || '|'
                                    || r_emp_element.sat_code              --    1    EarningType    "Catalog c_EarningType"    YES
                                    || '|'
                                    || r_emp_element.costing             --    2    Code    Alphanumeric    YES
                                    || '|'
                                    || TRIM (cvt_char (r_emp_element.reporting_name))              --    3    Item    Alphanumeric    YES
                                    || '|'
                                    || r_emp_element.ele_amt              --    4    TaxableAmount    Decimal    YES
                                    || '|'
                                    || r_emp_element.exempt_amt;              --    5    TaxExemptAmount    Decimal    YES

                             IF v_flag <> 'Y'
                             THEN
                                  UTL_FILE.put_line (v_file_type, v_text);
                                  fnd_file.put_line (fnd_file.output, v_text);
                             END IF;

                             v_current_ele_name := r_emp_element.element_name;

                             --Fnd_File.put_line(Fnd_File.LOG,'v_current_ele_name >>>>>>>>>>>>'||v_current_ele_name);
                             --Fnd_File.put_line(Fnd_File.LOG,'v_previous_ele_name >>>>>>>>>>>>'||v_previous_ele_name);
                             ----Fnd_File.put_line(Fnd_File.LOG,'v_current_ele_name >>>>>>>>>>>>'||v_current_ele_name);
                             --IF v_first_record = 'N' THEN
                                IF (   v_previous_ele_name = 'FIRST_ELEMENT'
                                    AND UPPER(v_current_ele_name)  like '%OVERTIME%')
                                THEN

                                  --Fnd_File.put_line(Fnd_File.LOG,'****!!!!!process_overtime_total ******');
                                  process_overtime_total (r_emp_info.assignment_id,
                                                           v_cut_off_date,
                                                           v_current_run_date,
                                                           v_current_ele_name); --Process Total OT
                                ELSIF (   UPPER(v_previous_ele_name) like '%OVERTIME%'
                                    OR UPPER(v_current_ele_name)  like '%OVERTIME%')
                                   AND v_previous_ele_name != v_current_ele_name
                                THEN

                                --Fnd_File.put_line(Fnd_File.LOG,'****process_overtime_total ******');
                                   process_overtime_total (r_emp_info.assignment_id,
                                                           v_cut_off_date,
                                                           v_current_run_date,
                                                           v_current_ele_name); --Process Total OT
                                END IF;
                             --ELSE
                                v_first_record := 'N';
                             --END IF;

                             v_previous_ele_name := v_current_ele_name;
                       END;
-- Below was 2016 format
--                     v_text1 := NULL;
--                     v_text1 :=
--                           'PE'
--                        || '|'
--                        || r_emp_element.sat_code
--                        || '|'
--                        || r_emp_element.element_type_id
--                        || '|'
--                        || TRIM (cvt_char (r_emp_element.reporting_name))
--                        || '|'
--                        || r_emp_element.ele_amt
--                        || '|'
--                        || r_emp_element.exempt_amt;

--                     IF v_flag <> 'Y'
--                     THEN
--                        UTL_FILE.put_line (v_file_type, v_text1);
--                        fnd_file.put_line (fnd_file.output, v_text1);
--                     END IF;
                  END LOOP;
               END;

--               v_module := '[DAA]';
--               v_loc := ' 100 ';
--               --Fnd_File.put_line(Fnd_File.LOG,v_module);
--
--               BEGIN /* Record DAA */

--                  v_text :=
--                        '[DAA]- SharesOrInstruments'          --    DAA    [SharesOrInstruments]    Alphanumeric    NO
--                     || '|'
--                     || 'EDNA HAS ASKED FOR EXTERNAL CONSULTANTS CONFIRMATION - 1 "MarketValue"    Decimal    YES'                                           --1    "MarketValue"    Decimal    YES
--                     || '|'
--                     || 'EDNA HAS ASKED FOR EXTERNAL CONSULTANTS CONFIRMATION - 2 PriceWhenGranted     Decimal    YES';                                      --2    PriceWhenGranted     Decimal    YES

--                  UTL_FILE.put_line (v_file_type, v_text);
--                  fnd_file.put_line (fnd_file.output, v_text);

--               END;
/*
               v_module := 'c_emp_overtime';
               v_loc := ' 120';
               --Fnd_File.put_line(Fnd_File.LOG,v_module);

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

                     v_module := '[DAB]';
                     v_loc := ' 130 ';
                     --Fnd_File.put_line(Fnd_File.LOG,v_module);

                     --v_text :=  '[DAB]-Overtime'          --    DAB    [Overtime]    Alphanumeric    NO
                     v_text :=  '[HorasExtra]'          --    DAB    [Overtime]    Alphanumeric    NO
                     || '|'
                     || r_emp_overtime.cnt  --1    Days    Full    YES
                     || '|'
                     || r_emp_overtime.ot_type  --2    HoursType    "Catalogc_HoursType"    YES
                     || '|'
                     || ROUND (get_value (r_emp_overtime.element_name,
                                             NULL,
                                             'Hours',
                                             r_emp_info.assignment_id,
                                             v_cut_off_date,
                                             v_current_run_date)) --3    Overtime    Full    YES
                     || '|'
                     || get_amount (r_emp_overtime.amt);  --4    AmountPaid    Decimal    YES

                     UTL_FILE.put_line (v_file_type, v_text);
                     fnd_file.put_line (fnd_file.output, v_text);


-- Below is old 2016 record
--                     v_text :=
--                           'HE'
--                        || '|'
--                        || r_emp_overtime.cnt
--                        || '|'
--                        || r_emp_overtime.ot_type
--                        || '|'
--                        || ROUND (get_value (r_emp_overtime.element_name,
--                                             NULL,
--                                             'Hours',
--                                             r_emp_info.assignment_id,
--                                             v_cut_off_date,
--                                             v_current_run_date))
--                        || '|'
--                        || get_amount (r_emp_overtime.amt);
--                     UTL_FILE.put_line (v_file_type, v_text);
--                     fnd_file.put_line (fnd_file.output, v_text);

                  END LOOP;
               END;
*/

               IF v_process_dc = 'Y' THEN
                   BEGIN /* Record DC */

                     v_module := '[DC]';
                     v_loc := ' 150 ';
--                     --Fnd_File.put_line(Fnd_File.LOG,v_module);

                     IF    r_emp_info.Salary_Basis = 'MX Hourly Salary' THEN

                                     SELECT get_value ('MX_ADW',
                                                       'Information',
                                                       'Pay Value',
                                                       r_emp_info.assignment_id,
                                                       v_cut_off_date,
                                                       v_current_run_date,
                                                       '[Positive Amount]'/* 2.4.1 */
                                                       ) * 30
                           -- * (LAST_DAY(v_current_run_date)- TRUNC(v_current_run_date,'MONTH') + 1)
                     INTO  v_DC_3
                     FROM DUAL; -- 3 LastOrdMonthSalary  Decimal    YES'

                      fnd_file.put_line (fnd_file.log, 'v_DC_3>>>'||v_DC_3);

                     ELSE

                      v_DC_3  := get_value ('MX_SALARY_GA',
                                                       'Earning',
                                                       'Amount',
                                                       r_emp_info.assignment_id,
                                                       v_cut_off_date,
                                                       v_current_run_date,
                                                       '[Positive Amount]'/* 2.4.1 */
                                                       ); -- 3 LastOrdMonthSalary  Decimal    YES'
                     END IF;

                      v_DC_ISR_subj :=  get_value ('MX_LI_20DAYS',
                                                   'Amends',
                                                   'ISR Subject',
                                                   r_emp_info.assignment_id,
                                                   v_cut_off_date,
                                                   v_current_run_date,
                                                   '[Positive Amount]'/* 2.4.1 */
                                                   )
                                        + get_value ('MX_LI_SENIORITY_PREMIUM',
                                                   'Amends',
                                                   'ISR Subject',
                                                   r_emp_info.assignment_id,
                                                   v_cut_off_date,
                                                   v_current_run_date,
                                                   '[Positive Amount]'/* 2.4.1 */
                                                   )
                                        + get_value ('MX_LI_SEVERANCE_PAY',
                                                   'Amends',
                                                   'ISR Subject',
                                                   r_emp_info.assignment_id,
                                                   v_cut_off_date,
                                                   v_current_run_date,
                                                   '[Positive Amount]'/* 2.4.1 */
                                                   );

                      v_DC_5  := get_value ('MX_LI_20DAYS',
                                                   'Amends',
                                                   'ISR Subject',
                                                   r_emp_info.assignment_id,
                                                   v_cut_off_date,
                                                   v_current_run_date,
                                                   '[Positive Amount]'/* 2.4.1 */
                                                   )
                                        + get_value ('MX_LI_SENIORITY_PREMIUM',
                                                   'Amends',
                                                   'ISR Subject',
                                                   r_emp_info.assignment_id,
                                                   v_cut_off_date,
                                                   v_current_run_date,
                                                   '[Positive Amount]'/* 2.4.1 */
                                                   )
                                        + get_value ('MX_LI_SEVERANCE_PAY',
                                                   'Amends',
                                                   'ISR Subject',
                                                   r_emp_info.assignment_id,
                                                   v_cut_off_date,
                                                   v_current_run_date,
                                                   '[Positive Amount]'/* 2.4.1 */
                                                   )

                                        - v_DC_3  ;  --5 NonaccruableIncome     Decimal    YES
--                                        - get_value ('MX_SALARY_GA',
--                                                       'Earning',
--                                                       'Amount',
--                                                       r_emp_info.assignment_id,
--                                                       v_cut_off_date,
--                                                       v_current_run_date)
--                                                   ;  --5 NonaccruableIncome     Decimal    YES

                      IF v_DC_5 <= 0 THEN
                         v_DC_5 := 0;
                      END IF;

                      IF  v_DC_ISR_subj <= v_DC_3 THEN
                         v_DC_4 := v_DC_ISR_subj;
                      ELSE
                         v_DC_4 := v_DC_3;
                      END IF;

                      --v_text := '[DC]-SeparationCompensation'          --    DC    [SeparationCompensation]    Alphanumeric    NO
                      v_text := '[SeparacionIndemnizacion]'          --    DC    [SeparationCompensation]    Alphanumeric    NO
                         || '|'
--                         || get_amount (get_value ('MX_LI_20DAYS',
--                                                   'Amends',
--                                                   'Pay Value',
--                                                   r_emp_info.assignment_id,
--                                                   v_cut_off_date,
--                                                   v_current_run_date)
--                                        + get_value ('MX_LI_SENIORITY_PREMIUM',
--                                                   'Amends',
--                                                   'Pay Value',
--                                                   r_emp_info.assignment_id,
--                                                   v_cut_off_date,
--                                                   v_current_run_date)
--                                        + get_value ('MX_LI_SEVERANCE_PAY',
--                                                   'Amends',
--                                                   'Pay Value',
--                                                   r_emp_info.assignment_id,
--                                                   v_cut_off_date,
--                                                   v_current_run_date)
--                                                   )  -- 1 TotalPaid      Decimal    YES'  --1    TotalPaid      Decimal    YES
                         || get_amount(v_TotSepComps)                           -- 1 TotalPaid      Decimal    YES'  --1    TotalPaid      Decimal    YES
                         || '|'
                         || r_emp_info.length_service -- 2 NumYearsService     Full    YES'  --2    NumYearsService     Full    YES
                         || '|'
                         || get_amount (v_DC_3)       -- 3 LastOrdMonthSalary  Decimal    YES'  --3    LastOrdMonthSalary      Decimal    YES
                         || '|'
                         || get_amount (v_DC_4)       --4 AccruableIncome     Decimal    YES   DC_4 = The least amount of DC_3 and DC_5
                         || '|'
                         || get_amount (v_DC_ISR_subj - v_DC_4);      -- 5 NonaccruableIncome     Decimal    YES

                      UTL_FILE.put_line (v_file_type, v_text);
                      fnd_file.put_line (fnd_file.output, v_text);

                   END;

               END IF;

               v_module := '[E]';
               v_loc := ' 160 ';
--               --Fnd_File.put_line(Fnd_File.LOG,v_module);

               BEGIN /* Record E*/

--                  Fnd_File.put_line(Fnd_File.LOG,'[E]-OtherDeductionsTotal' );
--                  Fnd_File.put_line(Fnd_File.LOG,'get_ded_value'||get_ded_value (NULL,
--                                                   'Deductions',
--                                                   'Pay Value',
--                                                   r_emp_info.assignment_id,
--                                                   v_cut_off_date,
--                                                   v_current_run_date)
--                   );
--                  Fnd_File.put_line(Fnd_File.LOG,'+ get_value (ISR Subsidy for Employment'||get_value ('ISR Subsidy for Employment', -- April 05
--                                             NULL,
--                                            'Pay Value',
--                                            r_emp_info.assignment_id,
--                                            v_cut_off_date,
--                                            v_current_run_date)
--                   );
--                  Fnd_File.put_line(Fnd_File.LOG,'-   get_value (ISR'||get_value ('ISR',
--                                        'Tax Deductions',
--                                        'Pay Value',
--                                        r_emp_info.assignment_id,
--                                        v_cut_off_date,
--                                        v_current_run_date)
--                   );
                  --v_text := '[E]-OtherDeductionsTotal'          --E [Deductions]    Alphanumeric    NO

                  /* 2.3.1  Begin */
                  v_TotDeductionsOther:= v_TotDeductions - NVL(v_TotISR,0);

                  IF v_TotDeductionsOther != 0 THEN

                     v_TotDeductionsOtherD:= get_amount(v_TotDeductionsOther);
                  ELSE
                     v_TotDeductionsOtherD := '';
                  END IF;

--                  Fnd_File.put_line(Fnd_File.LOG,'v_TotISR  ['||v_TotISR||']' );
--                  Fnd_File.put_line(Fnd_File.LOG,'v_TotDeductionsOther  ['||v_TotDeductionsOther||']'  );

                  IF v_TotISR != 0 OR v_TotDeductionsOther !=0 THEN

                      v_text := '[Deducciones]'          --E [Deductions]    Alphanumeric    NO
                         || '|'
                       --  || get_amount(v_TotDeductions - NVL(v_TotISR,0)) -- 1 OtherDeductionsTotal    Decimal    NO'  --1 OtherDeductionsTotal    Decimal    NO /* 2.3 */
                         || v_TotDeductionsOtherD -- 1 OtherDeductionsTotal    Decimal    NO'  --1 OtherDeductionsTotal    Decimal    NO /* 2.3 */
                         || '|'
                         || v_TotISRD  ; -- 2 TotalWithheldTax     Decimal    NO';  --2 TotalWithheldTax     Decimal    NO

                      UTL_FILE.put_line (v_file_type, v_text);
                      fnd_file.put_line (fnd_file.output, v_text);
                  END IF;

                  /* 2.3.1  End */
               END;

               v_module := '[D]'; /* 5.0.9 */
               v_loc := ' 170 ';
               v_071_appear_flag := 'N'; /* 5.0.9 */
--               --Fnd_File.put_line(Fnd_File.LOG,v_module);

               BEGIN
                  FOR r_ded_element
                     IN c_ded_element (r_emp_info.assignment_id,
                                       v_cut_off_date,
                                       v_current_run_date,
                                       'Deductions')
                  LOOP

                     g_label3 := 'r_ded_element ['||r_ded_element.reporting_name;
                     v_text := NULL;

                     /* 5.0.9 Begin */
                     IF r_ded_element.sat_code = '071' THEN
                        v_071_appear_flag := 'Y';
                     END IF;
                     /* 5.0.9  End */
                     --v_text := '[EA]-Deduction'              --    EA    [Deduction]    Alphanumeric    YES
                     v_text := '[Deduccion]'              --    EA    [Deduction]    Alphanumeric    YES
                        || '|'
                        || r_ded_element.sat_code              --    1    DeductionType      "Catalog c_DeductionType"    YES
                        || '|'
                        || r_ded_element.costing             --    2    Code      Alphanumeric    YES
                        || '|'
                        || TRIM (cvt_char (r_ded_element.reporting_name))              --    3    Item    Alphanumeric    YES
                        || '|'
                        || r_ded_element.ele_amt;             --    4    Amount    Decimal    YES

                     IF v_ded_flag <> 'Y'
                     THEN
                        UTL_FILE.put_line (v_file_type, v_text);
                        fnd_file.put_line (fnd_file.output, v_text);
                     END IF;

              v_process_faa := 'Y'; /* 5.0.8 */  -- CFDI requires to include this foe everyone
-- Old format 2016
--                     v_text1 := NULL;
--                     v_text1 :=
--                           'DE'
--                        || '|'
--                        || r_ded_element.sat_code
--                        || '|'
--                        || r_ded_element.element_type_id
--                        || '|'
--                        || TRIM (cvt_char (r_ded_element.reporting_name))
--                        || '|'
--                        || r_ded_element.ele_amt
--                        || '|'
--                        || '0.00';

--                     IF v_ded_flag <> 'Y'
--                     THEN
--                        UTL_FILE.put_line (v_file_type, v_text1);
--                        fnd_file.put_line (fnd_file.output, v_text1);
--                     END IF;
                  END LOOP;
               END;

              BEGIN

                  v_module := '[FA]';
                     v_loc := ' 180 ';
--                  --Fnd_File.put_line(Fnd_File.LOG,'[FA] =================>'||v_loc);
                  v_process_f := 'N';
                  --v_process_faa := 'N'; /* 5.0.8 */

                  FOR r_other_pymnt_element
                     IN c_other_pymnt_element (r_emp_info.assignment_id,
                                       v_cut_off_date,
                                       v_current_run_date,
                                       'Earning')
                  LOOP

--                      Fnd_File.put_line(Fnd_File.LOG,'[Element Name] =================>['||TRIM (cvt_char (r_other_pymnt_element.element_name))||']');
--                      Fnd_File.put_line(Fnd_File.LOG,'[Reporting Name] =================>['||TRIM (cvt_char (r_other_pymnt_element.reporting_name))||']');
--                      --Fnd_File.put_line(Fnd_File.LOG,'[Comparing To  ] =================>['||'Subsidio para el empleo'||']');
                       IF TRIM (cvt_char (r_other_pymnt_element.reporting_name)) = 'Subsidio para el empleo efectivamente entregado al trabajador' /* 5.0.3 */ --'Subsidio para el empleo'
                       THEN
                           v_process_faa := 'Y';
                       END IF;

                       g_label3 := r_other_pymnt_element.reporting_name;
                       BEGIN /* Record DA*/


                            IF v_process_f = 'N' THEN
                              v_text := NULL;
                                 v_text := '[OtrosPagos]'; -- Conditional node to express other applicable payments.
                                 UTL_FILE.put_line (v_file_type, v_text);
                                 fnd_file.put_line (fnd_file.output, v_text);
                                 v_process_f := 'Y';
                             END IF;

                             v_text := NULL;
                             --v_text := '[FA]-OtherPayment'  --    FA    [OtherPayment]    Alphanumeric    YES
                             v_text := '[OtroPago]'  --    FA    [OtherPayment]    Alphanumeric    YES
                                    || '|'
                                    || r_other_pymnt_element.sat_code              --    1 OtherPaymmentType       "Catalog c_OtherPaymentType"    YES    ' --    1    OtherPaymmentType
                                    || '|'
                                    || r_other_pymnt_element.costing              --    2    Code    Alphanumeric    YES
                                    || '|'
                                    || TRIM (cvt_char (r_other_pymnt_element.reporting_name))              --    3    Item    Alphanumeric    YES
                                    || '|'
                                    || r_other_pymnt_element.exempt_amt;              --    4    Amount    Decimal    YES

                             IF v_flag <> 'Y'
                             THEN
                                  UTL_FILE.put_line (v_file_type, v_text);
                                  fnd_file.put_line (fnd_file.output, v_text);
                             END IF;
                       END;

                  END LOOP;
               END;


            IF v_process_faa = 'Y' THEN
               v_module := '[FAA]';
               v_loc := ' 185 ';
               --Fnd_File.put_line(Fnd_File.LOG,v_module);

               --Fnd_File.put_line(Fnd_File.LOG,'Get FAA :');

               IF v_cut_off_date != trunc(v_current_run_date,'MONTH') THEN

                  v_run_date_p2 := v_current_run_date;
                  v_cut_off_date_p1 := trunc(v_current_run_date,'MONTH');
                  v_run_date_p1 := trunc(v_current_run_date,'MONTH') + 14;
                  v_process_faa_p1 := 'N'; -- Needs to be N, otherwise will break the logic below

--                  --Fnd_File.put_line(Fnd_File.LOG,'v_run_date_p1 :'||v_run_date_p1);
--                  --Fnd_File.put_line(Fnd_File.LOG,'v_run_date_p2 :'||v_run_date_p2);
--                  --Fnd_File.put_line(Fnd_File.LOG,'v_cut_off_date_p1 :'||v_cut_off_date_p1);

                  FOR r_other_pymnt_element
                     IN c_other_pymnt_element (r_emp_info.assignment_id,
                                       v_cut_off_date_p1,
                                       v_run_date_p1,
                                       'Earning')
                  LOOP
                     --Fnd_File.put_line(Fnd_File.LOG,'r_other_pymnt_element.reporting_name :'||cvt_char (r_other_pymnt_element.reporting_name));
                     --Fnd_File.put_line(Fnd_File.LOG,'r_other_pymnt_element.element_name :'|| (r_other_pymnt_element.element_name));
/* Commented out 5.0.9 */ --IF TRIM (cvt_char (r_other_pymnt_element.reporting_name)) like '%Subsidio para el empleo efectivamente entregado al trabajador%' /* 5.0.3 */ --'Subsidio para el empleo'
                     IF v_071_appear_flag = 'Y' /* 5.0.9 */
                     THEN
                        v_process_faa_p1 := 'Y';
                        --Fnd_File.put_line(Fnd_File.LOG,'Found Subsidio para el empleo in P1' );
                     END IF;
                  END LOOP;


                 -- IF v_process_faa_p1 = 'N' THEN /* 5.0.9 */
                    IF v_process_faa_p1 = 'Y' THEN /* 5.0.9 */
                    --Fnd_File.put_line(Fnd_File.LOG,'Go get P1 FAA value' );
                    v_total_subsidy_p1 := 0;

                    FOR r_ISR_Subsidy_for_Employment
                        IN c_ISR_Subsidy_for_Employment (r_emp_info.assignment_id,
                                                         v_cut_off_date_p1,
                                                         v_run_date_p1,
                                            'Earning')
                    LOOP

                         v_total_subsidy_p1 := v_total_subsidy_p1 + r_ISR_Subsidy_for_Employment.exempt_amt;
                         --Fnd_File.put_line(Fnd_File.LOG,r_ISR_Subsidy_for_Employment.section||' r_ISR_Subsidy_for_Employment.exempt_amt :'||r_ISR_Subsidy_for_Employment.exempt_amt);

                    END LOOP;

                   --Fnd_File.put_line(Fnd_File.LOG,'v_total_subsidy_p1 :'||v_total_subsidy_p1);
                        ----

                    v_total_subsidy_p2 := 0;

                        FOR r_ISR_Subsidy_for_Employment
                            IN c_ISR_Subsidy_for_Employment (r_emp_info.assignment_id,
                                              v_cut_off_date,
                                                  v_run_date_p2,
                                                'Earning')
                        LOOP

                             --Fnd_File.put_line(Fnd_File.LOG,r_ISR_Subsidy_for_Employment.section||' r_ISR_Subsidy_for_Employment.exempt_amt :'||r_ISR_Subsidy_for_Employment.exempt_amt);
                             v_total_subsidy_p2 := v_total_subsidy_p2 + r_ISR_Subsidy_for_Employment.exempt_amt;

                        END LOOP;

                    --Fnd_File.put_line(Fnd_File.LOG,'v_total_subsidy_p2 :'||v_total_subsidy_p2);
                        ----


                    v_total_subsidy := v_total_subsidy_p1 + v_total_subsidy_p2;

                    --Fnd_File.put_line(Fnd_File.LOG,'v_total_subsidy :'||v_total_subsidy);
                  ELSE

                    --Fnd_File.put_line(Fnd_File.LOG,'No need for p1, go get ISR Subsiby for p2');
                    v_total_subsidy_p2 := 0;

                    FOR r_ISR_Subsidy_for_Employment
                        IN c_ISR_Subsidy_for_Employment (r_emp_info.assignment_id,
                                              v_cut_off_date,
                                              v_current_run_date,
                                             'Earning')
                    LOOP

                         v_total_subsidy_p2 := v_total_subsidy_p2 + r_ISR_Subsidy_for_Employment.exempt_amt;
                         --Fnd_File.put_line(Fnd_File.LOG,'r_ISR_Subsidy_for_Employment.exempt_amt :'||r_ISR_Subsidy_for_Employment.exempt_amt);

                    END LOOP;

                    --Fnd_File.put_line(Fnd_File.LOG,'v_total_subsidy_p2 :'||v_total_subsidy_p2);
                    v_total_subsidy := v_total_subsidy_p2;
                    --Fnd_File.put_line(Fnd_File.LOG,'v_total_subsidy :'||v_total_subsidy);

                  END IF;

               ELSE

                    ----Fnd_File.put_line(Fnd_File.LOG,'Get ISR Subsiby for p2');
                    v_total_subsidy_p2 := 0;

                    FOR r_ISR_Subsidy_for_Employment
                        IN c_ISR_Subsidy_for_Employment (r_emp_info.assignment_id,
                                              v_cut_off_date,
                                              v_current_run_date,
                                             'Earning')
                    LOOP

                         v_total_subsidy_p2 := v_total_subsidy_p2 + r_ISR_Subsidy_for_Employment.exempt_amt;
                         ----Fnd_File.put_line(Fnd_File.LOG,'r_ISR_Subsidy_for_Employment.exempt_amt :'||r_ISR_Subsidy_for_Employment.exempt_amt);

                    END LOOP;

                    ----Fnd_File.put_line(Fnd_File.LOG,'v_total_subsidy_p2 :'||v_total_subsidy_p2);
                    v_total_subsidy := v_total_subsidy_p2;
                    ----Fnd_File.put_line(Fnd_File.LOG,'v_total_subsidy :'||v_total_subsidy);
               END IF;

               /* 5.0.9 8/25/2020 6 PM  CFDI feedback if amount is zero and v_071_appear_flag = 'Y' do not show */

               IF v_071_appear_flag = 'Y' and v_total_subsidy = 0 /* 5.0.9 */
               THEN
                   NULL; -- Do not show [SubsidioAlEmpleo] /* 5.0.9 */
               ELSE    /* 5.0.9 */

                   IF v_total_subsidy < 0 THEN /* 5.0.10  begin */
                      v_total_subsidy := 0;
                   END IF;  /* 5.0.10  End  */

               --v_text := '[FAA]-EmploymentSubsidy'          --FAA [EmploymentSubsidy]        Alphanumeric    NO
                   v_text := '[SubsidioAlEmpleo]'          --FAA [EmploymentSubsidy]        Alphanumeric    NO
                         || '|'
                         || get_amount ( v_total_subsidy
                                          ); -- 1    SubsidyIncurred         Decimal    YES'

                   UTL_FILE.put_line (v_file_type, v_text);
                   fnd_file.put_line (fnd_file.output, v_text);
               END IF;  /* 5.0.9 */

            END IF;
--               v_module := '[FAB]';
--               v_loc := ' 190 ';
--               --Fnd_File.put_line(Fnd_File.LOG,v_module);
--
--               BEGIN /* Record FAB*/

--                  v_text :=
--                        '[FAB]-CreditBalancesOffset'          --FAB    [CreditBalancesOffset]    Alphanumeric    NO
--                     || '|'
--                     || 'Need input from Edna - 1 CreditBalance      Decimal    YES'  --1 CreditBalance      Decimal    YES
--                     || '|'
--                     || 'Need input from Edna - 2 Year    Full    YES'  --2 Year    Full    YES
--                     || '|'
--                     || 'Need input from Edna - 3 CredBalCarryover     Decimal    YES';  --3 CredBalCarryover     Decimal    YES

--                  UTL_FILE.put_line (v_file_type, v_text);
--                  fnd_file.put_line (fnd_file.output, v_text);

--               END;

--               BEGIN

--                  v_text1 :=
--                        'NO'
--                     || '|'
--                     || r_emp_info.org_ssn
--                     || '|'
--                     || r_emp_info.assignment_number
--                     || '|'
--                     || r_emp_info.national_identifier
--                     || '|'
--                     || '2'
--                     || '|'
--                     || r_emp_info.ssn_id
--                     || '|'
----                     || TO_CHAR (v_current_run_date, 'YYYY-MM-DD')
--                     || TO_CHAR (v_pay_date, 'YYYY-MM-DD') -- 1.12
--                     || '|'
--                     || TO_CHAR (v_cut_off_date, 'YYYY-MM-DD')
--                     || '|'
----                   || TO_CHAR (v_pay_date, 'YYYY-MM-DD')
--                     || TO_CHAR (v_current_run_date, 'YYYY-MM-DD') -- 1.12
--                     || '|'
--                     || get_amount (get_value ('MX_DAYS_IN_PERIOD',
--                                               NULL,
--                                               'Days',
--                                               r_emp_info.assignment_id,
--                                               v_cut_off_date,
--                                               v_current_run_date))
--                     || '|'
--                     || r_emp_info.client
--                     || '|'
--                     || ''
--                     || '|'
--                     || '' --'014' /* 1.13 */
--                     || '|'
--                     || TO_CHAR (r_emp_info.original_date_of_hire,
--                                 'YYYY-MM-DD')
--                     || '|'
--                     || ''
--                     || '|'
--                     || ''  --TRIM (cvt_char (r_emp_info.job_name)) -- 1.4
--                     || '|'
--                     || ''  --TRIM (cvt_char (r_emp_info.ass_cat_mean)) -- 1.4
--                     || '|'
--                     || ''  --TRIM (cvt_char (r_emp_info.type_of_work_day)) -- 1.4
--                     || '|'
--                     || 'Quincenal'
--                     || '|'
----                     || get_amount (get_value ('MX_TOTAL_EARNINGS',  --1.4
----                                               NULL,
----                                               'Pay Value',
----                                               r_emp_info.assignment_id,
----                                               v_cut_off_date,
----                                               v_current_run_date))
--                     || '|'
--                     || '1'
--                     || '|';
----                     || get_amount (get_value ('Integrated Daily Wage', --1.4
----                                               NULL,
----                                               NULL,
----                                               'Pay Value',
----                                               r_emp_info.assignment_id,
----                                               v_cut_off_date,
----                                               v_current_run_date));
--                  UTL_FILE.put_line (v_file_type, v_text1);
--                  fnd_file.put_line (fnd_file.output, v_text1);
--               END;

--               BEGIN
--                  v_text := NULL;
--                  v_text :=
--                        'PES'
--                     || '|'
--                     || get_amount (get_ear_value (NULL,
--                                                   'Earning',
--                                                   'ISR Subject',
--                                                   r_emp_info.assignment_id,
--                                                   v_cut_off_date,
--                                                   v_current_run_date))
--                     || '|'
--                     || get_amount (
--                             get_balance (r_emp_info.assignment_id,
--                                          'ISR Exempt',
--                                          '_ASG_GRE_RUN',
--                                          v_current_run_date)
--                           /* 1.10 */
--                           - get_balance (r_emp_info.assignment_id,
--                                                    '%ISR Exempt%Coupon%',  -- Year End ISR Exempt for Pantry Coupons
--                                                   '_ASG_GRE_RUN',
--                                                   v_current_run_date
--                                                  )
--                           /* 1.10 */
--                           +  (  get_value (NULL,
--                                        'Non-payroll Payments',
--                                        'Pay Value',
--                                        r_emp_info.assignment_id,
--                                        v_cut_off_date,
--                                        v_current_run_date)
--                               + get_value (NULL, -- 1.11
--                                        'Tax Credit',
--                                        'Pay Value',
--                                        r_emp_info.assignment_id,
--                                        v_cut_off_date,
--                                        v_current_run_date)
--                               + get_value ('MX_RE_SAVING_FUNDS', -- 1.4
--                                        'Information',
--                                        'Pay Value',
--                                        r_emp_info.assignment_id,
--                                        v_cut_off_date,
--                                        v_current_run_date)
--                               - get_value ('MX_SF_COMPANY_LIQ',  --1.4
--                                            'Non-payroll Payments',
--                                            'Pay Value',
--                                            r_emp_info.assignment_id,
--                                            v_cut_off_date,
--                                            v_current_run_date)
--                               - get_value ('MX_SF_LIQUIDATION', --1.4
--                                            'Non-payroll Payments',
--                                            'Pay Value',
--                                            r_emp_info.assignment_id,
--                                            v_cut_off_date,
--                                            v_current_run_date)
--                                        )
--                           + get_neg_value (NULL,
--                                            'Deduction',
--                                            'Pay Value',
--                                            r_emp_info.assignment_id,
--                                            v_cut_off_date,
--                                            v_current_run_date))
--                                            ;


--                  IF v_text <> 'PES|0.00|0.00'
--                  THEN
--                     UTL_FILE.put_line (v_file_type, v_text);
--                     fnd_file.put_line (fnd_file.output, v_text);
--                  ELSE
--                     v_flag := 'Y';
--                  END IF;
--               END;

--

--               BEGIN
--                  v_text := NULL;
--                  v_text :=
--                        'DES'
--                     || '|'
--                     || get_amount (get_ded_value (NULL,
--                                                   'Deductions',
--                                                   'Pay Value',
--                                                   r_emp_info.assignment_id,
--                                                   v_cut_off_date,
--                                                   v_current_run_date))
--                     || '|'
--                     || '0.00';

--                  IF v_text <> 'DES|0.00|0.00'
--                  THEN
--                     UTL_FILE.put_line (v_file_type, v_text);
--                     fnd_file.put_line (fnd_file.output, v_text);
--                  ELSE
--                     v_ded_flag := 'Y';
--                  END IF;
--               END;



               v_module := 'c_emp_sick';
               v_loc := ' 100';
               v_process_g := 'N';
--               --Fnd_File.put_line(Fnd_File.LOG,v_module);
               BEGIN
                  FOR r_emp_sick
                     IN c_emp_sick (r_emp_info.assignment_id,
                                    v_cut_off_date,
                                    v_current_run_date)
                  LOOP

                     IF v_process_g = 'N' THEN
                      v_text := NULL;
                         g_label3 := 'r_emp_sick ['||r_emp_sick.element_name;
                         v_text := '[Incapacidades]'; -- Node required to express information on the incapacidties.
                         UTL_FILE.put_line (v_file_type, v_text);
                         fnd_file.put_line (fnd_file.output, v_text);
                         v_process_g := 'Y';
                     END IF;

                     v_text := NULL;
                     g_label3 := 'r_emp_sick ['||r_emp_sick.element_name;
                     --v_text := '[GA]-Incapacity'    --    GA    [Incapacity]    Alphanumeric    YES
                     v_text := '[Incapacidad]'    --    GA    [Incapacity]    Alphanumeric    YES
                        || '|'
                        || r_emp_sick.cnt              --    1    DaysIncapacity    Full    YES
                        || '|'
                        || lpad(r_emp_sick.sat_code,2,'0')              --    2    IncapacityType    "Catalog c_IncapacityType"    YES
                        || '|'
                        || get_amount (get_value (r_emp_sick.element_name,
                                                  NULL,
                                                  'Pay Value',
                                                  r_emp_info.assignment_id,
                                                  v_cut_off_date,
                                                  v_current_run_date,
                                                  '[Negative Amount]' /* 2.4.1 */
                                                  )); --    3    MonetaryAmount     Decimal    NO

                     UTL_FILE.put_line (v_file_type, v_text);
                     fnd_file.put_line (fnd_file.output, v_text);

--                     v_text := NULL;
--                     v_text :=
--                           'IN'
--                        || '|'
--                        || get_amount (r_emp_sick.cnt)
--                        || '|'
--                        || r_emp_sick.sat_code
--                        || '|'
--                        || get_amount (get_value (r_emp_sick.element_name,
--                                                  NULL,
--                                                  'Pay Value',
--                                                  r_emp_info.assignment_id,
--                                                  v_cut_off_date,
--                                                  v_current_run_date));
--                     UTL_FILE.put_line (v_file_type, v_text);
--                     fnd_file.put_line (fnd_file.output, v_text);
                  END LOOP;
               END;

               UTL_FILE.fclose (v_file_type);
            END LOOP;
         END LOOP;
      EXCEPTION
         WHEN OTHERS
         THEN
            fnd_file.put_line (fnd_file.LOG,'Error Location : ['||v_loc ||'] Module [' || v_module||'] ERROR:'||SQLERRM);
            UTL_FILE.fclose (v_file_type);
      END;


   EXCEPTION
      WHEN OTHERS
      THEN
         UTL_FILE.fclose (v_file_type);
         --UTL_FILE.fclose (v_second_type);
         fnd_file.put_line (fnd_file.LOG,
                            'Error out of main loop main_proc -' || SQLERRM);

        RAISE_APPLICATION_ERROR(-20003,'Exception OTHERS in ttec_pay_mex_cfdi_2017_intf.main: '||'Module [' ||v_module||'] ['||g_label1||']['||v_loc||'] PersonID/EmpNo ['||g_emp_no|| '] ERROR:'||SQLERRM);

   END main_proc;
END ttec_pay_mex_cfdi_2017_intf;
/
show errors;
/