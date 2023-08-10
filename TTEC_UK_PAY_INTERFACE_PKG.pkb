create or replace PACKAGE BODY      ttec_uk_pay_interface_pkg
AS
--------------------------------------------------------------------------------------
--
-- Name:  apps.ttech_uk_pay_inteface_pkg  (Package)
--
--     Description:   Argentina HR Data to the Payroll Vendor
--                                       --
--
--
--     Change History
--
--     Changed By        Date        Reason for Change
--     ----------        ----        -----------------
--     V 1.0 Vijay Mayadam   17-Jan-2005  Initial Creation
--
--     V 1.1 Christiane Chan  02-DEC-2005 WO#134907 - Mid-cycle Terms for salaried employees
--                                  needs to pass partial appropriate payments.
--     V 1.2 Wasim Manasfi    26-JUL-2007   fixed gift issue
--     V 1.3 Wasim Manasfi    2-AUG-2007     added incentive to cursor element2, added comments for code
--     V 1.4 Wasim Manasfi    4-JUN-2010     added employee type Expatriate to main query - ticket 202959
--     V.1.5 Christiane Chan  14 -SEP-2010   TTECH R#344107 - UK recurring element was not included in extract - "Mobile Allowance"
--                                           Need to add to the Logic.
--     V.1.6 Christiane Chan  04-Jun-2012   TTSD R#1544230 - UK non-recurring element quarterly bonus was added for salaried employee (vendor code id '31').
--
-- first populate    cust.ttec_uk_pay_interface_ele
-- INSERT INTO cust.ttec_uk_pay_interface_ele_temp
-- extract_elements_ctl_tot  for totals
-- Incentive is a lump sum that can vary by rate but fixed by 1 hour, so I made specific additional handling for it
-- to not affect the other elements and minimize the testing to be done to the code. testing for major changes to the code is
-- extensive. this minimizes the testing time
--     V 1.6  Daniel Andino  26-OCT-2011 TTECH #739530 - Incorrent hours and rate for AVP Element. Fixed by adding a subquery to the t_element
--                                       cursor.
--    V 1.7 Raja Ponnuswamy 17-JUL-2012 UK non-recurring element Holiday Pay was added for salaried employee (vendor code id '19').
--      1.0 RXNETHI-ARGANO  18/MAY/2023 R12.2 Upgrade Remediation
---------------------------------------------------------------------------------------
   PROCEDURE print_line (iv_data IN VARCHAR2)
   IS
   BEGIN
      fnd_file.put_line (fnd_file.output, iv_data);
   END;                                                          -- print_line

--------------------------------------------------------------------
--                                                                --
-- Name:  delimit_text                 (Function)                 --
--                                                                --
--     Description:         Function called by other procedures   --
--                           to scrub and delimite data           --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation              --
--                                                                --
--                                                                --
--------------------------------------------------------------------
   FUNCTION delimit_text (
      iv_number_of_fields   IN   NUMBER,
      iv_field1             IN   VARCHAR2,
      iv_field2             IN   VARCHAR2 DEFAULT NULL,
      iv_field3             IN   VARCHAR2 DEFAULT NULL,
      iv_field4             IN   VARCHAR2 DEFAULT NULL,
      iv_field5             IN   VARCHAR2 DEFAULT NULL,
      iv_field6             IN   VARCHAR2 DEFAULT NULL,
      iv_field7             IN   VARCHAR2 DEFAULT NULL,
      iv_field8             IN   VARCHAR2 DEFAULT NULL,
      iv_field9             IN   VARCHAR2 DEFAULT NULL,
      iv_field10            IN   VARCHAR2 DEFAULT NULL
   )
      RETURN VARCHAR2
   IS
      v_delimiter          VARCHAR2 (1)    := ',';
      v_replacement_char   VARCHAR2 (1)    := ' ';
      v_delimited_text     VARCHAR2 (2000);
   BEGIN
      -- Removes the Delimiter from the fields and replaces it with
      -- Replacement Char, then concatenates the fields together
      -- separated by the delimiter
      v_delimited_text :=
            REPLACE (iv_field1, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field2, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field3, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field4, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field5, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field6, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field7, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field8, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field9, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field10, v_delimiter, v_replacement_char);
      -- return only the number of fields as requested by
      -- the iv_number_of_fields parameter
      v_delimited_text :=
         SUBSTR (v_delimited_text,
                 1,
                   INSTR (v_delimited_text,
                          v_delimiter,
                          1,
                          iv_number_of_fields
                         )
                 - 1
                );
      RETURN v_delimited_text;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN NULL;
   END;                                                        -- delimit_text

--------------------------------------------------------------------
--                                                                --
-- Name:  scrub_to_number            (Function)                   --
--                                                                --
--     Description:         Function called by other procedures   --
--                           to strip special characters          --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation              --
--                                                                --
--                                                                --
--------------------------------------------------------------------
   FUNCTION scrub_to_number (iv_text IN VARCHAR2)
      RETURN VARCHAR2
   IS
      v_number   VARCHAR2 (255);
      v_length   NUMBER;
      i          NUMBER;
   BEGIN
      v_length := LENGTH (iv_text);

      IF v_length > 0
      THEN
         -- look at each character in text and remove any non-numbers
         FOR i IN 1 .. v_length
         LOOP
            IF ASCII (SUBSTR (iv_text, i, 1)) BETWEEN 48 AND 57
            THEN
               v_number := v_number || SUBSTR (iv_text, i, 1);
            END IF;                                 -- ascii between 48 and 57
         END LOOP;                                                        -- i
      END IF;                                                      -- v_length

      RETURN v_number;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN iv_text;
   END;                                            -- function scrub_to_number

--------------------------------------------------------------------
--                                                                --
-- Name:  set_business_group_id        (Procedure)                --
--                                                                --
--     Description:         Procedure called by other procedures  --
--                           to set global business_group_id      --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation             --
--                                                                --
--                                                                --
--------------------------------------------------------------------
   PROCEDURE set_business_group_id (
      iv_business_group   IN   VARCHAR2 DEFAULT 'TeleTech Holdings - uk'
   )
   IS
   BEGIN
      SELECT organization_id
        INTO g_business_group_id
        FROM hr_all_organization_units
       WHERE NAME = iv_business_group;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG,
                            'Unable to Determine Business Group ID'
                           );
         fnd_file.put_line (fnd_file.LOG, SUBSTR (SQLERRM, 1, 255));
         g_errbuf := SUBSTR (SQLERRM, 1, 255);
         g_retcode := SQLCODE;
         RAISE g_e_abort;
   END;                                     -- procedure set_business_group_id

/*===========================================================================
  PROCEDURE NAME:       validate date
  DESCRIPTION:
                        Validates and converts a char datatype date string
                        to a date datatype that the user has entered
                        is in a valid format based on the NLS_DATE_FORMAT
                        as 'DD-MON-RRRR'.
============================================================================*/
   PROCEDURE validate_date (
      p_char_date    IN              VARCHAR2,
      p_date_date    OUT NOCOPY      DATE,
      p_valid_date   OUT NOCOPY      BOOLEAN
   )
   IS
      l_nls_date_format   VARCHAR2 (80);
      l_date_date         DATE;
   BEGIN
      /*
      ** Set the l_date_date to null
      */
      l_date_date := NULL;
      l_nls_date_format := 'DD-MON-RRRR';
      /*
      ** Now try to convert the char date string to a date datatype.  If any
      ** exception occurs then tell the caller that it is not valid date.
      */
      p_valid_date := TRUE;

      BEGIN
         SELECT NVL (TO_DATE (p_char_date, l_nls_date_format),
                     TRUNC (SYSDATE))
           INTO l_date_date
           FROM DUAL;
      EXCEPTION
         WHEN OTHERS
         THEN
            p_valid_date := FALSE;
      END;

      p_date_date := l_date_date;
   EXCEPTION
      WHEN OTHERS
      THEN
         p_valid_date := FALSE;
   END validate_date;

--------------------------------------------------------------------
--                                                                --
-- Name:  set_payroll_dates            (Procedure)                --
--                                                                --
--     Description:         Procedure called by other procedures  --
--                           to return payroll dates              --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation             --
--                                                                --
--                                                                --
--------------------------------------------------------------------
   PROCEDURE set_payroll_dates (iv_pay_period_id IN VARCHAR2)
   IS
   BEGIN
      NULL;      --not using payroll cut-off dates for uk payroll interface--
/*
  select pay.payroll_name,
         ptp.period_name,
         ptp.start_date,
        ptp.end_date,
        ptp.cut_off_date,
        ptp.pay_advice_date,
        ptp.regular_payment_date
  into   g_payroll_name,
         g_period_name,
         g_start_date,
         g_end_date,
         g_cut_off_date,
         g_pay_advice_date,
         g_regular_payment_date
  from   pay_payrolls_f pay,
         per_time_periods ptp
  where  pay.business_group_id = g_business_group_id
  and    pay.payroll_id = ptp.payroll_id
  and    ptp.time_period_id = iv_pay_period_id
  and    trunc(g_cut_off_date) between pay.effective_start_date and pay.effective_end_date;
*/
   EXCEPTION
      WHEN OTHERS
      THEN
/*
    g_payroll_name           := 'NO PAYROLL FOUND';
    g_period_name            := 'NO PERIOD FOUND';
    g_start_date             := to_date('01JAN2004','DDMONYYYY');
    g_end_date               := to_date('31DEC4712','DDMONYYYY');
    g_cut_off_date           := trunc(sysdate);
    g_pay_advice_date        := trunc(sysdate);
    g_regular_payment_date   := trunc(sysdate);
*/
         g_cut_off_date := SYSDATE;
   END;                                         -- procedure set_payroll_dates

--------------------------------------------------------------------
--                                                                --
-- Name:  extract_elements      (Procedure)                       --
--                                                                --
--     Description:         Procedure called by the concurrent    --
--                            manager to extract elements         --
--                                                                --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   27-Jan-2005  Initial Creation              --
--     Andino, Daniel  26-Oct-2011  Added a subquery to t_element --
--                                  cursor in order to get the    --
--                                  accurate values for the rate  --
--                                  and hours columns.            --
--                                                                --
--------------------------------------------------------------------
   PROCEDURE extract_elements
   IS
-- Ken Mod 7/6/05 added trunc for all date fields
-- Ken Mod 8/9/05 broke down c_element cursor, due to problems that not pulling all necessary rows.
-- cursor c_element is

      -- Retrieves Element entries -- Anual Amount WM
      CURSOR c_element_1
      IS
         SELECT eletab.emp_attribute12, eletab.ele_attribute1, '1' hours,
                eletab.screen_entry_value rate
              --,'REGULAR' new_or_change
           --,eletab.person_id
            --  ,eletab.employee_number
         --FROM   cust.ttec_uk_pay_interface_ele eletab   --code commented by RXNETHI-ARGANO,18/05/23
         FROM   apps.ttec_uk_pay_interface_ele eletab     --code added by RXNETHI-ARGANO,18/05/23
          WHERE eletab.payroll_name = g_payroll_name
            AND TRUNC (cut_off_date) = TRUNC (g_cut_off_date)
            AND input_value_name IN ('Annual Amount')
            AND eletab.ele_attribute1 IS NOT NULL       -- added by Ken 7/6/05
                                                 ;

-- and eletab.ele_attribute1 = '16'  -- added by Ken 7/11/05 and currently commented out, but pay code must be 16.
                                     -- if not the above case, activate this line.

      /*  commeted out starting..
                 select eletab.emp_attribute12
                 ,eletab.ele_attribute1
                 ,'1' Hours
                 ,eltab.screen_entry_value Rate
                  --,'NEW' new_or_change
                 from   cust.ttec_uk_pay_interface_ele eletab
                       where  eletab.payroll_name = g_payroll_name
                       and    trunc(cut_off_date) = trunc(g_cut_off_date)
                 and    input_value_name in ('Annual Amount')
                 and    not exists (select 1
                     from   cust.ttec_uk_pay_interface_ele eletab2
                 where  person_id = eletab.person_id
                 and    element_type_id = eletab.element_type_id
                 and    trunc(cut_off_date) = (select max(trunc(cut_off_date))
                                         from   cust.ttec_uk_pay_interface_ele
                                   where  person_id = eletab2.person_id
                                   and    trunc(cut_off_date) < trunc(g_cut_off_date)))
                 Union

                 -- retrieves changes to element entries
                 select  eletab_curr.emp_attribute12
                       ,eletab_curr.ele_attribute1
                       ,'1' Hours
                       ,eletab_curr.screen_entry_value Rate
                       --,'CHANGE' new_or_change
                 from   cust.ttec_uk_pay_interface_ele eletab_curr,
                        cust.ttec_uk_pay_interface_ele eletab_past
                 where  eletab_curr.payroll_name = g_payroll_name
                 and   eletab_curr.input_value_name in ('Annual Amount')
                 and    eletab_curr.person_id = eletab_past.person_id
                 and    eletab_curr.element_type_id = eletab_past.element_type_id
                 and    eletab_curr.input_value_id = eletab_past.input_value_id
                 and    trunc(eletab_curr.cut_off_date) = trunc(g_cut_off_date)
                 and    trunc(eletab_past.cut_off_date) = (select max(trunc(cut_off_date))
                                     from   cust.ttec_uk_pay_interface_ele
                             where  person_id = eletab_curr.person_id
                             and    trunc(cut_off_date) < trunc(g_cut_off_date))
                 and    (eletab_curr.screen_entry_value != eletab_past.screen_entry_value
                 or eletab_curr.ele_attribute1 != eletab_past.ele_attribute1)
                 */
      -- commeted out ending....

      -- UNION  -- New  -- WM elements that are added to hourly rate, added Incentive to be excluded
      CURSOR c_element_2
      IS
         SELECT eletab1.emp_attribute12, eletab1.ele_attribute1,
                eletab1.screen_entry_value hours,
                NVL (eletab2.screen_entry_value,
                       (  NVL (eletab1.hourly_salary, 0)
                        + NVL (eletab4.screen_entry_value, 0)
                       )
                     * NVL (eletab3.screen_entry_value, 1)
                    ) rate
           /*
		   START R12.2 Upgrade Remediation
		   code commented by RXNETHI-ARGANO,18/05/23
		   FROM cust.ttec_uk_pay_interface_ele eletab1,
                cust.ttec_uk_pay_interface_ele eletab2,
                cust.ttec_uk_pay_interface_ele eletab3,
                cust.ttec_uk_pay_interface_ele eletab4
		   */
		   --code added by RXNETHI-ARGANO,18/05/23
		   FROM apps.ttec_uk_pay_interface_ele eletab1,
                apps.ttec_uk_pay_interface_ele eletab2,
                apps.ttec_uk_pay_interface_ele eletab3,
                apps.ttec_uk_pay_interface_ele eletab4
		   --END R12.2 Upgrade Remediation
          WHERE eletab1.input_value_name = 'Hours'
-- Ken Mod 8/9/05 to limit element names
            AND eletab1.element_name NOT IN
                   ('Car Allowance',
                    'Mobile Allowance', -- V.1.5,
                    'Language Speciality Differential',
                    'Dental Cover', 'Car Parking', 'Stock Share Plan',
                    'Healthcare', 'Life Assurance', 'Incentive')
            AND eletab1.person_id = eletab2.person_id(+)
            AND eletab1.element_type_id = eletab2.element_type_id(+)
            AND eletab2.input_value_name(+) = 'Rate'
            AND eletab1.person_id = eletab3.person_id(+)
            AND eletab1.element_type_id = eletab3.element_type_id(+)
            AND eletab3.input_value_name(+) = 'Multiplier'
            AND eletab1.person_id = eletab4.person_id(+)
            AND eletab1.element_type_id = eletab4.element_type_id(+)
            AND eletab4.input_value_name(+) = 'Add To'
            AND TRUNC (eletab1.cut_off_date) = TRUNC (g_cut_off_date)
            AND TRUNC (eletab2.cut_off_date(+)) = TRUNC (g_cut_off_date)
            AND TRUNC (eletab3.cut_off_date(+)) = TRUNC (g_cut_off_date)
            AND TRUNC (eletab4.cut_off_date(+)) = TRUNC (g_cut_off_date)
            AND eletab1.ele_attribute1 IS NOT NULL
            AND NOT EXISTS (
                   SELECT 1
                     --FROM cust.ttec_uk_pay_interface_ele eletab5   --code commented by RXNETHI-ARGANO,18/05/23
                     FROM apps.ttec_uk_pay_interface_ele eletab5     --code added by RXNETHI-ARGANO,18/05/23
                    WHERE person_id = eletab1.person_id
                      AND element_type_id = eletab1.element_type_id
                      AND payroll_name = g_payroll_name
                      -- Added by Ken 7/6/05
                      AND entry_effective_start_date =
                                            eletab1.entry_effective_start_date
                      AND entry_effective_end_date =
                                              eletab1.entry_effective_end_date
                      AND TRUNC (cut_off_date) =
                             (SELECT MAX (TRUNC (cut_off_date))
                                --FROM cust.ttec_uk_pay_interface_ele    --code commented by RXNETHI-ARGANO,18/05/23
                                FROM apps.ttec_uk_pay_interface_ele      --code added by RXNETHI-ARGANO,18/05/23
                               WHERE person_id = eletab5.person_id
                                 AND payroll_name = g_payroll_name
                                 AND TRUNC (cut_off_date) <
                                                        TRUNC (g_cut_off_date)))
            AND eletab1.payroll_name = g_payroll_name
-- Added by Ken 7/11/05 (point_C) to pull ONLY the following pay codes for salaried employee, when new elements are introduced, add it here
            AND (   (    eletab1.pay_basis_id = 108
                     AND eletab1.ele_attribute1 IN
                            ('8', '10', '11', '12', '13', '14', '15', '17',
                             '18', '20',
                             '31', -- Quaterly Bonus' /* V 1.6 */
                             '19', -- Holiday Pay/*V 1.7*/
                             '61', '62', '63', '64', '66', '67',
                             '68', '69', '71', '72', '73', '74', '21')
                    )
                 OR (eletab1.pay_basis_id != 108)
                );

-- UNION -- New "Language Speciality Differential"
      CURSOR c_element_3
      IS
         SELECT ele1.emp_attribute12, ele1.ele_attribute1,
                ele2.screen_entry_value hours, ele1.screen_entry_value rate
           /*
		   START R12.2 Upgrade Remediation
		   code commented by RXNETHI-ARGANO,18/05/23
		   FROM cust.ttec_uk_pay_interface_ele ele1,
                cust.ttec_uk_pay_interface_ele ele2
		   */
		   --code added by RXNETHI-ARGANO,18/05/23
		   FROM apps.ttec_uk_pay_interface_ele ele1,
                apps.ttec_uk_pay_interface_ele ele2
		   --END R12.2 Upgrade Remediation
          WHERE ele1.element_name = 'Language Speciality Differential'
            AND ele1.person_id = ele2.person_id
            AND ele1.input_value_name = 'Rate'
            AND ele2.input_value_name = 'Hours'
            AND ele1.element_name = 'Language Speciality Differential'
            AND ele2.element_name = 'Total Hours Worked'
            AND TRUNC (ele1.cut_off_date) = TRUNC (ele2.cut_off_date)
            AND TRUNC (ele1.cut_off_date) = TRUNC (g_cut_off_date)
            AND ele1.payroll_name = g_payroll_name
-- Ken Mod 8/9/05 commented out not exists part to pull it for every payroll runs
-- and    not exists (select 1
--                    from   cust.ttec_uk_pay_interface_ele ele3
--                   where  person_id = ele1.person_id                         -- ele3
--                     and    element_type_id = ele1.element_type_id             -- ele3
--                     and    payroll_name    = g_payroll_name                   -- ele3
--           -- Added by Ken 7/6/05
--                     AND    ENTRY_EFFECTIVE_START_DATE = ELE1.ENTRY_EFFECTIVE_START_DATE     -- ele3
--                     AND    ENTRY_EFFECTIVE_END_DATE = ELE1.ENTRY_EFFECTIVE_END_DATE          -- ele3

            --                     and    trunc(cut_off_date) = (select max(trunc(cut_off_date))      -- ele3
--                                                   from   cust.ttec_uk_pay_interface_ele
--                                                  where  person_id = ele3.person_id
--                                                   and    payroll_name    = g_payroll_name
--                                                   and    trunc(cut_off_date) < trunc(g_cut_off_date)
--                                                  )
--                     )
-- Ken Mod 8/9/05 ending..
            AND ele1.ele_attribute1 IS NOT NULL         -- added by Ken 7/6/05
-- Added by Ken 7/11/05 (point_C) to pull ONLY the following pay codes for salaried employee, when new elements are introduced, add it here
            AND (   (    ele1.pay_basis_id = 108
                     AND ele1.ele_attribute1 IN
                            ('8', '10', '11', '12', '13', '14', '15', '17',
                             '18', '20',
                             '31', -- Quaterly Bonus' /* V 1.6 */
                              '19', -- Holiday Pay/*V 1.7*/
                             '61', '62', '63', '64', '66', '67',
                             '68', '69', '71', '72', '73', '74', '21')
                    )
                 OR (ele1.pay_basis_id != 108)
                );

-- UNION  -- Changes
-- WM added to exclude Incentive
      CURSOR c_element_4
      IS
         SELECT a.emp_attribute12, a.ele_attribute1, a.hours, a.rate
           FROM (SELECT eletab1.person_id, eletab1.element_type_id,
                        eletab1.emp_attribute12, eletab1.ele_attribute1,
                        eletab1.screen_entry_value hours,
                        NVL (eletab2.screen_entry_value,
                               (  NVL (eletab1.hourly_salary, 0)
                                + NVL (eletab4.screen_entry_value, 0)
                               )
                             * NVL (eletab3.screen_entry_value, 1)
                            ) rate,
                        eletab1.payroll_name
                                            -- Added by Ken 7/6/05
                        ,
                        eletab1.entry_effective_start_date
                                                   entry_effective_start_date,
                        eletab1.entry_effective_end_date
                                                     entry_effective_end_date
                                                                             -- Added by Ken 7/11/05
                        ,
                        eletab1.pay_basis_id pay_basis_id
                   /*
				   START R12.2 Upgrade Remediation
				   code commented by RXNETHI-ARGANO,18/05/23
				   FROM cust.ttec_uk_pay_interface_ele eletab1,
                        cust.ttec_uk_pay_interface_ele eletab2,
                        cust.ttec_uk_pay_interface_ele eletab3,
                        cust.ttec_uk_pay_interface_ele eletab4
				   */
				   --code added by RXNETHI-ARGANO,18/05/23
				   FROM apps.ttec_uk_pay_interface_ele eletab1,
                        apps.ttec_uk_pay_interface_ele eletab2,
                        apps.ttec_uk_pay_interface_ele eletab3,
                        apps.ttec_uk_pay_interface_ele eletab4
				   --END R12.2 Upgrade Remediation
                  WHERE eletab1.input_value_name = 'Hours'
-- Ken Mod 8/9/05 to limit element names
                    AND eletab1.element_name NOT IN
                           ('Car Allowance',
                            'Mobile Allowance', -- V.1.5
                            'Language Speciality Differential',
                            'Dental Cover', 'Car Parking', 'Stock Share Plan',
                            'Healthcare', 'Life Assurance', 'Incentive')
                    AND eletab1.person_id = eletab2.person_id(+)
                    AND eletab1.element_type_id = eletab2.element_type_id(+)
                    AND eletab2.input_value_name(+) = 'Rate'
                    AND eletab1.person_id = eletab3.person_id(+)
                    AND eletab1.element_type_id = eletab3.element_type_id(+)
                    AND eletab3.input_value_name(+) = 'Multiplier'
                    AND eletab1.person_id = eletab4.person_id(+)
                    AND eletab1.element_type_id = eletab4.element_type_id(+)
                    AND eletab4.input_value_name(+) = 'Add To'
                    AND TRUNC (eletab1.cut_off_date) = TRUNC (g_cut_off_date)
                    AND TRUNC (eletab2.cut_off_date(+)) =
                                                        TRUNC (g_cut_off_date)
                    AND TRUNC (eletab3.cut_off_date(+)) =
                                                        TRUNC (g_cut_off_date)
                    AND TRUNC (eletab4.cut_off_date(+)) =
                                                        TRUNC (g_cut_off_date)
                    AND eletab1.payroll_name = g_payroll_name) a,
                (SELECT eletab1.person_id, eletab1.element_type_id,
                        eletab1.emp_attribute12, eletab1.ele_attribute1,
                        eletab1.screen_entry_value hours,
                        NVL (eletab2.screen_entry_value,
                               (  NVL (eletab1.hourly_salary, 0)
                                + NVL (eletab4.screen_entry_value, 0)
                               )
                             * NVL (eletab3.screen_entry_value, 1)
                            ) rate,
                        eletab1.payroll_name
                                            -- Added by Ken 7/6/05
                        ,
                        eletab1.entry_effective_start_date
                                                   entry_effective_start_date,
                        eletab1.entry_effective_end_date
                                                     entry_effective_end_date
                   /*
				   START R12.2 Upgrade Remediation
				   code commented by RXNETHI-ARGANO,18/05/23
				   FROM cust.ttec_uk_pay_interface_ele eletab1,
                        cust.ttec_uk_pay_interface_ele eletab2,
                        cust.ttec_uk_pay_interface_ele eletab3,
                        cust.ttec_uk_pay_interface_ele eletab4
				   */
				   --code added by RXNETHI-ARGANO,18/05/23
				   FROM apps.ttec_uk_pay_interface_ele eletab1,
                        apps.ttec_uk_pay_interface_ele eletab2,
                        apps.ttec_uk_pay_interface_ele eletab3,
                        apps.ttec_uk_pay_interface_ele eletab4
				   --END R12.2 Upgrade Remediation
                  WHERE eletab1.input_value_name = 'Hours'
-- Ken Mod 8/9/05 to limit element names
                    AND eletab1.element_name NOT IN
                           ('Car Allowance'
                           ,'Mobile Allowance' -- V.1.5
                           ,'Language Speciality Differential',
                            'Dental Cover', 'Car Parking', 'Stock Share Plan',
                            'Healthcare', 'Life Assurance', 'Incentive')
                    AND eletab1.person_id = eletab2.person_id(+)
                    AND eletab1.element_type_id = eletab2.element_type_id(+)
                    AND eletab2.input_value_name(+) = 'Rate'
                    AND eletab1.person_id = eletab3.person_id(+)
                    AND eletab1.element_type_id = eletab3.element_type_id(+)
                    AND eletab3.input_value_name(+) = 'Multiplier'
                    AND eletab1.person_id = eletab4.person_id(+)
                    AND eletab1.element_type_id = eletab4.element_type_id(+)
                    AND eletab4.input_value_name(+) = 'Add To'
                    AND TRUNC (eletab1.cut_off_date) =
                                                   TRUNC (g_prev_cut_off_date)
                    AND TRUNC (eletab2.cut_off_date(+)) =
                                                   TRUNC (g_prev_cut_off_date)
                    AND TRUNC (eletab3.cut_off_date(+)) =
                                                   TRUNC (g_prev_cut_off_date)
                    AND TRUNC (eletab4.cut_off_date(+)) =
                                                   TRUNC (g_prev_cut_off_date)
                    AND eletab1.payroll_name = g_payroll_name) b
          WHERE a.person_id = b.person_id
            AND a.element_type_id = b.element_type_id
            AND (a.hours != b.hours OR a.rate != b.rate)
            AND a.payroll_name = g_payroll_name
-- Added by Ken 7/6/05
            AND a.ele_attribute1 IS NOT NULL
            AND a.entry_effective_start_date = b.entry_effective_start_date
            AND a.entry_effective_end_date = b.entry_effective_end_date
-- Added by Ken 7/11/05 (point_C) to pull ONLY the following pay codes for salaried employee, when new elements are introduced, add it here
            AND (   (    a.pay_basis_id = 108
                     AND a.ele_attribute1 IN
                            ('8', '10', '11', '12', '13', '14', '15', '17',
                             '18', '20',
                             '31', -- Quaterly Bonus' /* V 1.6 */
                              '19', -- Holiday Pay/*V 1.7*/
                             '61', '62', '63', '64', '66', '67',
                             '68', '69', '71', '72', '73', '74', '21')
                    )
                 OR (a.pay_basis_id != 108)
                );

-- UNION  -- Changes "Language Speciality Differential"
      CURSOR c_element_5
      IS
         SELECT a.emp_attribute12, a.ele_attribute1, a.hours, a.rate
           FROM (SELECT ele1.emp_attribute12, ele1.ele_attribute1,
                        ele2.screen_entry_value hours,
                        ele1.screen_entry_value rate, ele1.person_id,
                        ele1.element_type_id
-- Added by Ken 7/6/05
                        ,
                        ele1.entry_effective_start_date
                                                   entry_effective_start_date,
                        ele1.entry_effective_end_date
                                                     entry_effective_end_date
-- Added by Ken 7/11/05
                        ,
                        ele1.pay_basis_id pay_basis_id
                   /*
				   START R12.2 Upgrade Remediation
				   code commented by RXNETHI-ARGANO,18/05/23
				   FROM cust.ttec_uk_pay_interface_ele ele1,
                        cust.ttec_uk_pay_interface_ele ele2
                   */
				   --code added by RXNETHI-ARGANO,18/05/23
				   FROM apps.ttec_uk_pay_interface_ele ele1,
                        apps.ttec_uk_pay_interface_ele ele2
				   --END R12.2 Upgrade Remediation
				  WHERE ele1.element_name = 'Language Speciality Differential'
                    AND ele1.person_id = ele2.person_id
                    AND ele1.input_value_name = 'Rate'
                    AND ele2.input_value_name = 'Hours'
                    AND ele1.element_name = 'Language Speciality Differential'
                    AND ele2.element_name = 'Total Hours Worked'
                    AND TRUNC (ele1.cut_off_date) = TRUNC (ele2.cut_off_date)
                    AND TRUNC (ele1.cut_off_date) = TRUNC (g_cut_off_date)
                    AND ele1.payroll_name = g_payroll_name) a,
                (SELECT ele1.emp_attribute12, ele1.ele_attribute1,
                        ele2.screen_entry_value hours,
                        ele1.screen_entry_value rate, ele1.person_id,
                        ele1.element_type_id
-- Added by Ken 7/6/05
                        ,
                        ele1.entry_effective_start_date
                                                   entry_effective_start_date,
                        ele1.entry_effective_end_date
                                                     entry_effective_end_date
                   /*
				   START R12.2 Upgrade Remediation
				   code commented by RXNETHI-ARGANO,18/05/23
				   FROM cust.ttec_uk_pay_interface_ele ele1,
                        cust.ttec_uk_pay_interface_ele ele2
				   */
				   --code added by RXNETHI-ARGANO18/05/23
				   FROM apps.ttec_uk_pay_interface_ele ele1,
                        apps.ttec_uk_pay_interface_ele ele2
				   --END R12.2 Upgrade Remediation
                  WHERE ele1.element_name = 'Language Speciality Differential'
                    AND ele1.person_id = ele2.person_id
                    AND ele1.input_value_name = 'Rate'
                    AND ele2.input_value_name = 'Hours'
                    AND ele1.element_name = 'Language Speciality Differential'
                    AND ele2.element_name = 'Total Hours Worked'
                    AND TRUNC (ele1.cut_off_date) = TRUNC (ele2.cut_off_date)
                    AND TRUNC (ele1.cut_off_date) =
                                                   TRUNC (g_prev_cut_off_date)
                    AND ele1.payroll_name = g_payroll_name) b
          WHERE a.person_id = b.person_id
            AND a.element_type_id = b.element_type_id
            AND a.rate != b.rate
-- Added by Ken 7/6/05
            AND a.ele_attribute1 IS NOT NULL
            AND a.entry_effective_start_date = b.entry_effective_start_date
            AND a.entry_effective_end_date = b.entry_effective_end_date
-- Added by Ken 7/11/05 (point_C) to pull ONLY the following pay codes for salaried employee, when new elements are introduced, add it here
            AND (   (    a.pay_basis_id = 108
                     AND a.ele_attribute1 IN
                            ('8', '10', '11', '12', '13', '14', '15', '17',
                             '18', '20',
                             '31', -- Quaterly Bonus' /* V 1.6 */
                              '19', -- Holiday Pay/*V 1.7*/
                             '61', '62', '63', '64', '66', '67',
                             '68', '69', '71', '72', '73', '74', '21')
                    )
                 OR (a.pay_basis_id != 108)
                );

-- Ken Mod 8/9/05 to pull listed elements for every payroll runs..
-- 'Car Allowance', 'Dental Cover', 'Car Parking', 'Stock Share Plan', 'Healthcare', 'Life Assurance'
-- Note that 'Language Speciality Differential' is not included - handled in different cursor.
      CURSOR c_element_6
      IS
         SELECT eletab1.emp_attribute12, eletab1.ele_attribute1,
                eletab1.screen_entry_value hours,
                NVL (eletab2.screen_entry_value,
                       (  NVL (eletab1.hourly_salary, 0)
                        + NVL (eletab4.screen_entry_value, 0)
                       )
                     * NVL (eletab3.screen_entry_value, 1)
                    ) rate
           /*
		   START R12.2 Upgrade Remediation
		   code commented by RXNETHI-ARGANO,18/05/23
		   FROM cust.ttec_uk_pay_interface_ele eletab1,
                cust.ttec_uk_pay_interface_ele eletab2,
                cust.ttec_uk_pay_interface_ele eletab3,
                cust.ttec_uk_pay_interface_ele eletab4
           */
		   --code added by RXNETHI-ARGANO,18/05/23
		   FROM apps.ttec_uk_pay_interface_ele eletab1,
                apps.ttec_uk_pay_interface_ele eletab2,
                apps.ttec_uk_pay_interface_ele eletab3,
                apps.ttec_uk_pay_interface_ele eletab4
		   --END R12.2 Upgrade Remediation
		  WHERE eletab1.input_value_name = 'Hours'
-- Ken Mod 8/9/05 to limit element names
            AND eletab1.element_name IN
                   ('Car Allowance'
                   ,'Mobile Allowance' -- V.1.5
                   , 'Dental Cover', 'Car Parking',
                    'Stock Share Plan', 'Healthcare', 'Life Assurance',
                    'Gift Aid', 'Childcare Deduction')
            AND eletab1.person_id = eletab2.person_id(+)
            AND eletab1.element_type_id = eletab2.element_type_id(+)
            AND eletab2.input_value_name(+) = 'Rate'
            AND eletab1.person_id = eletab3.person_id(+)
            AND eletab1.element_type_id = eletab3.element_type_id(+)
            AND eletab3.input_value_name(+) = 'Multiplier'
            AND eletab1.person_id = eletab4.person_id(+)
            AND eletab1.element_type_id = eletab4.element_type_id(+)
            AND eletab4.input_value_name(+) = 'Add To'
            AND TRUNC (eletab1.cut_off_date) = TRUNC (g_cut_off_date)
            AND TRUNC (eletab2.cut_off_date(+)) = TRUNC (g_cut_off_date)
            AND TRUNC (eletab3.cut_off_date(+)) = TRUNC (g_cut_off_date)
            AND TRUNC (eletab4.cut_off_date(+)) = TRUNC (g_cut_off_date)
            AND eletab1.ele_attribute1 IS NOT NULL
            AND eletab1.payroll_name = g_payroll_name
-- Added by Ken 7/11/05 (point_C) to pull ONLY the following pay codes for salaried employee, when new elements are introduced, add it here
            AND (   (    eletab1.pay_basis_id = 108
                     AND eletab1.ele_attribute1 IN
                            ('8', '10', '11', '12', '13', '14', '15', '17',
                             '18', '20',
                             '31', -- Quaterly Bonus' /* V 1.6 */
                              '19', -- Holiday Pay/*V 1.7*/
                             '61', '62', '63', '64', '66', '67',
                             '68', '69', '71', '72', '73', '74', '21')
                    )
                 OR (eletab1.pay_basis_id != 108)
                );

      -- for incentive added by WM
      CURSOR c_element_7
      IS
         SELECT a.emp_attribute12, a.ele_attribute1, a.hours, a.rate
           FROM (SELECT DISTINCT ele1.emp_attribute12, ele1.ele_attribute1,
                                 ele2.screen_entry_value hours,
                                 ele1.screen_entry_value rate,
                                 ele1.element_entry_id,
                                 ele1.element_entry_value_id
                            /*
							START R12.2 Upgrade Remediation
							code commented by RXNETHI-ARGANO,18/05/23
							FROM cust.ttec_uk_pay_interface_ele ele1,
                                 cust.ttec_uk_pay_interface_ele ele2
                            */
							--code added by RXNETHI-ARGANO,18/05/23
							FROM apps.ttec_uk_pay_interface_ele ele1,
                                 apps.ttec_uk_pay_interface_ele ele2
							--END R12.2 Upgrade Remediation
						   WHERE ele1.element_name = 'Incentive'
                             AND ele1.person_id = ele2.person_id
                             AND ele1.input_value_name = 'Rate'
                             AND ele2.input_value_name = 'Hours'
                             AND ele1.element_name = 'Incentive'
                             AND ele2.element_name = 'Incentive'
                             AND TRUNC (ele1.cut_off_date) =
                                                     TRUNC (ele2.cut_off_date)
                             AND TRUNC (ele1.cut_off_date) =
                                                        TRUNC (g_cut_off_date)
                             AND ele1.payroll_name LIKE g_payroll_name) a;

      --DAANDINO 10/24/2011 Added subquery to get the total rate of each element due to TTSD I#739530
      --DAANDINO 10/24/2011 Added case clause due to TTSD I#739530. AVP element should show 1 hour.
      CURSOR t_element
      IS
        SELECT   emp_attribute12, ele_attribute1, s_hours, SUM (s_rate) s_rate
          FROM (SELECT   emp_attribute12, ele_attribute1, (CASE WHEN ele_attribute1 = '9' THEN 1 ELSE SUM (hours) END) s_hours, AVG (rate) s_rate -- V1.6
                  --FROM cust.ttec_uk_pay_interface_ele_temp -- V1.6   --code commented by RXNETHI-ARGANO,18/05/23
                  FROM apps.ttec_uk_pay_interface_ele_temp -- V1.6     --code added by RXNETHI-ARGANO,18/05/23
              GROUP BY emp_attribute12, ele_attribute1, rate) -- V1.6
      GROUP BY emp_attribute12, ele_attribute1,s_hours;

      v_output   VARCHAR2 (4000);
   BEGIN
      SELECT MAX (TRUNC (cut_off_date))
        INTO g_prev_cut_off_date
        --FROM cust.ttec_uk_pay_interface_ele  --code commented by RXNETHI-ARGANO,18/05/23
        FROM apps.ttec_uk_pay_interface_ele    --code added by RXNETHI-ARGANO,18/05/23
       WHERE TRUNC (cut_off_date) < TRUNC (g_cut_off_date)
         AND payroll_name = g_payroll_name;

-- Print_line(g_cut_off_date);
-- Print_line(g_prev_cut_off_date);

      --  Print_line('** Extract for Employee New Element Entries Section(4) **');
-- Ken Mod 8/9/05 go thru broken down cursors (c_element_1 .. 5) and gather informations
      FOR r_element IN c_element_1
      LOOP
         -- fnd_file.put_line(fnd_file.log,'insert into temp c_element_1');
         -- fnd_file.put_line(fnd_file.log,'emp_attribute12=' || r_element.emp_attribute12);
         -- fnd_file.put_line(fnd_file.log,'ele_attribute1=' || r_element.ele_attribute1);
         -- fnd_file.put_line(fnd_file.log,'hours=' || r_element.hours);
         -- fnd_file.put_line(fnd_file.log,'rate=' || r_element.rate);

         -- Ken Mod 7/1/05 Store data into temp table cust.ttec_uk_pay_interface_ele_temp
         --INSERT INTO cust.ttec_uk_pay_interface_ele_temp    --code commented by RXNETHI-ARGANO,18/05/23
         INSERT INTO apps.ttec_uk_pay_interface_ele_temp      --code added by RXNETHI-ARGANO,18/05/23
                     (emp_attribute12, ele_attribute1,
                      hours, rate
                     )
              VALUES (r_element.emp_attribute12, r_element.ele_attribute1,
                      ROUND (r_element.hours, 2), ROUND (r_element.rate, 2)
                     );
      -- fnd_file.put_line(fnd_file.log,'insert into temp c_element_1 - done');

      -- commented out
/*
         v_output := delimit_text(iv_number_of_fields          => 4,
                              iv_field1                => r_element.emp_attribute12,
                              iv_field2                => r_element.ele_attribute1,
               iv_field3                => round(r_element.Hours,2),
               iv_field4                => round(r_element.rate,2)
                             );


     print_line(v_output);


dbms_output.put_line(v_output);
*/  -- commented out
      END LOOP;                                                 -- c_element_1

      FOR r_element IN c_element_2
      LOOP
         -- fnd_file.put_line(fnd_file.log,'insert into temp c_element_2');
         -- fnd_file.put_line(fnd_file.log,'emp_attribute12=' || r_element.emp_attribute12);
         -- fnd_file.put_line(fnd_file.log,'ele_attribute1=' || r_element.ele_attribute1);
         -- fnd_file.put_line(fnd_file.log,'hours=' || r_element.hours);
         -- fnd_file.put_line(fnd_file.log,'rate=' || r_element.rate);

         -- Ken Mod 7/1/05 Store data into temp table cust.ttec_uk_pay_interface_ele_temp
         --INSERT INTO cust.ttec_uk_pay_interface_ele_temp    --code commented by RXNETHI-ARGANO,18/05/23
         INSERT INTO apps.ttec_uk_pay_interface_ele_temp      --code added by RXNETHI-ARGANO,18/05/23
                     (emp_attribute12, ele_attribute1,
                      hours, rate
                     )
              VALUES (r_element.emp_attribute12, r_element.ele_attribute1,
                      ROUND (r_element.hours, 2), ROUND (r_element.rate, 2)
                     );
      -- fnd_file.put_line(fnd_file.log,'insert into temp c_element_2 - done');
      END LOOP;                                                 -- c_element_2

      FOR r_element IN c_element_3
      LOOP
         -- fnd_file.put_line(fnd_file.log,'insert into temp c_element_3');
         -- fnd_file.put_line(fnd_file.log,'emp_attribute12=' || r_element.emp_attribute12);
         -- fnd_file.put_line(fnd_file.log,'ele_attribute1=' || r_element.ele_attribute1);
         -- fnd_file.put_line(fnd_file.log,'hours=' || r_element.hours);
         -- fnd_file.put_line(fnd_file.log,'rate=' || r_element.rate);

         -- Ken Mod 7/1/05 Store data into temp table cust.ttec_uk_pay_interface_ele_temp
         --INSERT INTO cust.ttec_uk_pay_interface_ele_temp   --code commented by RXNETHI-ARGANO,18/05/23
         INSERT INTO apps.ttec_uk_pay_interface_ele_temp     --code added by RXNETHI-ARGANO,18/05/23
                     (emp_attribute12, ele_attribute1,
                      hours, rate
                     )
              VALUES (r_element.emp_attribute12, r_element.ele_attribute1,
                      ROUND (r_element.hours, 2), ROUND (r_element.rate, 2)
                     );
      -- fnd_file.put_line(fnd_file.log,'insert into temp c_element_3 - done');
      END LOOP;                                                 -- c_element_3

      FOR r_element IN c_element_4
      LOOP
         -- fnd_file.put_line(fnd_file.log,'insert into temp c_element_4');
         -- fnd_file.put_line(fnd_file.log,'emp_attribute12=' || r_element.emp_attribute12);
         -- fnd_file.put_line(fnd_file.log,'ele_attribute1=' || r_element.ele_attribute1);
         -- fnd_file.put_line(fnd_file.log,'hours=' || r_element.hours);
         -- fnd_file.put_line(fnd_file.log,'rate=' || r_element.rate);

         -- Ken Mod 7/1/05 Store data into temp table cust.ttec_uk_pay_interface_ele_temp
         --INSERT INTO cust.ttec_uk_pay_interface_ele_temp   --code commented by RXNETHI-ARGANO,18/05/23
         INSERT INTO apps.ttec_uk_pay_interface_ele_temp     --code added by RXNETHI-ARGANO,18/05/23
                     (emp_attribute12, ele_attribute1,
                      hours, rate
                     )
              VALUES (r_element.emp_attribute12, r_element.ele_attribute1,
                      ROUND (r_element.hours, 2), ROUND (r_element.rate, 2)
                     );
      -- fnd_file.put_line(fnd_file.log,'insert into temp c_element_4 - done');
      END LOOP;                                                 -- c_element_4

      FOR r_element IN c_element_5
      LOOP
         -- fnd_file.put_line(fnd_file.log,'insert into temp c_element_5');
         -- fnd_file.put_line(fnd_file.log,'emp_attribute12=' || r_element.emp_attribute12);
         -- fnd_file.put_line(fnd_file.log,'ele_attribute1=' || r_element.ele_attribute1);
         -- fnd_file.put_line(fnd_file.log,'hours=' || r_element.hours);
         -- fnd_file.put_line(fnd_file.log,'rate=' || r_element.rate);

         -- Ken Mod 7/1/05 Store data into temp table cust.ttec_uk_pay_interface_ele_temp
         --INSERT INTO cust.ttec_uk_pay_interface_ele_temp    --code commented by RXNETHI-ARGANO,18/05/23
         INSERT INTO apps.ttec_uk_pay_interface_ele_temp      --code added by RXNETHI-ARGANO,18/05/23
                     (emp_attribute12, ele_attribute1,
                      hours, rate
                     )
              VALUES (r_element.emp_attribute12, r_element.ele_attribute1,
                      ROUND (r_element.hours, 2), ROUND (r_element.rate, 2)
                     );
      -- fnd_file.put_line(fnd_file.log,'insert into temp c_element_5 - done');
      END LOOP;

      -- c_element_5
      FOR r_element IN c_element_6
      LOOP
--          fnd_file.put_line(fnd_file.log,'insert into temp c_element_6');
--          fnd_file.put_line(fnd_file.log,'emp_attribute12=' || r_element.emp_attribute12);
--          fnd_file.put_line(fnd_file.log,'ele_attribute1=' || r_element.ele_attribute1);
--          fnd_file.put_line(fnd_file.log,'hours=[' || r_element.hours||']');
--          fnd_file.put_line(fnd_file.log,'rate=[' || r_element.rate||']');
--          fnd_file.put_line(fnd_file.log,'ROUND(hours)=[' ||ROUND (r_element.hours, 2)||']');
--          fnd_file.put_line(fnd_file.log,'ROUND(rate)=[' || ROUND (r_element.rate, 2)||']');
         -- Ken Mod 7/1/05 Store data into temp table cust.ttec_uk_pay_interface_ele_temp
         --INSERT INTO cust.ttec_uk_pay_interface_ele_temp    --code commented by RXNETHI-ARGANO,18/05/23
         INSERT INTO apps.ttec_uk_pay_interface_ele_temp      --code added by RXNETHI-ARGANO,18/05/23
                     (emp_attribute12, ele_attribute1,
                      hours, rate
                     )
              VALUES (r_element.emp_attribute12, r_element.ele_attribute1,
                      ROUND (r_element.hours, 2), ROUND (r_element.rate, 2)
                     );
      -- fnd_file.put_line(fnd_file.log,'insert into temp c_element_6 - done');
      END LOOP;                                                 -- c_element_6

      FOR r_element IN c_element_7
      LOOP
         --INSERT INTO cust.ttec_uk_pay_interface_ele_temp    --code commented by RXNETHI-ARGANO,18/05/23
         INSERT INTO apps.ttec_uk_pay_interface_ele_temp      --code added by RXNETHI-ARGANO,18/05/23
                     (emp_attribute12, ele_attribute1,
                      hours, rate
                     )
              VALUES (r_element.emp_attribute12, r_element.ele_attribute1,
                      ROUND (r_element.hours, 2), ROUND (r_element.rate, 2)
                     );
      -- fnd_file.put_line(fnd_file.log,'insert into temp c_element_1 - done');
      END LOOP;                                                 -- c_element_7

-- Ken Mod 7/1/05  pull data from temp table.
      FOR o_element IN t_element
      LOOP
         v_output :=
            delimit_text (iv_number_of_fields      => 4,
                          iv_field1                => o_element.emp_attribute12,
                          iv_field2                => o_element.ele_attribute1,
                          iv_field3                => o_element.s_hours,
                          iv_field4                => o_element.s_rate
                         );
         print_line (v_output);
-- dbms_output.put_line(v_output);
      END LOOP;                                                   -- o_element
   END;                                                    -- extract_elements

--------------------------------------------------------------------
--                                                                --
-- Name:  extract_elements_ctl_tot      (Procedure)               --
--                                                                --
--     Description:     To product control totals from            --
--                      table cust.ttec_uk_pay_interface_ele_temp --
--                                                                --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--                                                                --
--                                                                --
--------------------------------------------------------------------
   PROCEDURE extract_elements_ctl_tot
   IS
      CURSOR t_elements_ctl_tot
      IS
         SELECT   ele_attribute1, SUM (hours) s_hours, SUM (rate) s_rate
             --FROM cust.ttec_uk_pay_interface_ele_temp   --code commented by RXNETHI-ARGANO,18/05/23
             FROM apps.ttec_uk_pay_interface_ele_temp     --code added by RXNETHI-ARGANO,18/05/23
         GROUP BY ele_attribute1;

      v_output   VARCHAR2 (4000);
   BEGIN
      fnd_file.put_line (fnd_file.LOG, '                           ');
      fnd_file.put_line
                   (fnd_file.LOG,
                    '#######################################################'
                   );
      fnd_file.put_line
                    (fnd_file.LOG,
                     '####### PAY CODES CONTROL TOTAL SECTION - BEGIN #######'
                    );
      fnd_file.put_line
                    (fnd_file.LOG,
                     '####### Output format --> Pay_code,Hours,Rate   #######'
                    );

      FOR r_elements_ctl_tot IN t_elements_ctl_tot
      LOOP
         v_output :=
            delimit_text (iv_number_of_fields      => 3,
                          iv_field1                => r_elements_ctl_tot.ele_attribute1,
                          iv_field2                => ROUND
                                                         (r_elements_ctl_tot.s_hours,
                                                          2
                                                         ),
                          iv_field3                => ROUND
                                                         (r_elements_ctl_tot.s_rate,
                                                          2
                                                         )
                         );
         fnd_file.put_line (fnd_file.LOG, v_output);
-- print_line(v_output);
      END LOOP;                                          -- t_elements_ctl_tot

      fnd_file.put_line
                    (fnd_file.LOG,
                     '####### PAY CODES CONTROL TOTAL SECTION - END   #######'
                    );
      fnd_file.put_line
                    (fnd_file.LOG,
                     '#######################################################'
                    );
      fnd_file.put_line (fnd_file.LOG, '                           ');
   EXCEPTION
      WHEN OTHERS
      THEN
         g_retcode := SQLCODE;
         g_errbuf := SUBSTR (SQLERRM, 1, 255);
         fnd_file.put_line (fnd_file.LOG, 'extract_elements_ctl_tot Failed');
         fnd_file.put_line (fnd_file.LOG, SUBSTR (SQLERRM, 1, 255));
         RAISE g_e_abort;
   END;                                            -- extract_elements_ctl_tot

--------------------------------------------------------------------
--                                                                --
-- Name:  insert_interface_ele               (Procedure)          --
--                                                                --
--     Description:         Procedure called by the other         --
--                            procedures to insert                --
--                            table ttec_uk_pay_interface_ele    --
--                                                                --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   24-Jan-2005  Initial Creation             --
--                                                                --
--                                                                --
--------------------------------------------------------------------
   PROCEDURE insert_interface_ele (
      --ir_interface_ele   cust.ttec_uk_pay_interface_ele%ROWTYPE    --code commented by RXNETHI-ARGANO,18/05/23
      ir_interface_ele   apps.ttec_uk_pay_interface_ele%ROWTYPE      --code added by RXNETHI-ARGANO,18/05/23
   )
   IS
   BEGIN
      --INSERT INTO cust.ttec_uk_pay_interface_ele    --code commented by RXNETHI-ARGANO,18/05/23
      INSERT INTO apps.ttec_uk_pay_interface_ele      --code added by RXNETHI-ARGANO,18/05/23
                  (payroll_id,
                   payroll_name,
                   pay_period_id,
                   cut_off_date,
                   person_id,
                   assignment_id,
-- added by Ken 7/6/05
                   pay_basis_id,
                   employee_number,
                   emp_attribute12,
                   ele_attribute1,
                   element_name,
                   reporting_name,
                   processing_type,
                   classification_name,
                   element_type_id,
                   element_link_id,
                   element_entry_id,
                   element_entry_value_id,
                   uom, uom_meaning,
                   input_value_id,
                   input_value_name,
                   screen_entry_value,
                   creator_type,
                   entry_effective_start_date,
                   entry_effective_end_date,
                   hourly_salary,
                   creation_date,
                   last_extract_date,
                   last_extract_file_type,
                   uk_sal_fortnightly_indicator
                  )
           VALUES (ir_interface_ele.payroll_id,
                   ir_interface_ele.payroll_name,
                   ir_interface_ele.pay_period_id,
                   ir_interface_ele.cut_off_date,
                   ir_interface_ele.person_id,
                   ir_interface_ele.assignment_id,
-- added by Ken 7/6/05
                   ir_interface_ele.pay_basis_id,
                   ir_interface_ele.employee_number,
                   ir_interface_ele.emp_attribute12,
                   ir_interface_ele.ele_attribute1,
                   ir_interface_ele.element_name,
                   ir_interface_ele.reporting_name,
                   ir_interface_ele.processing_type,
                   ir_interface_ele.classification_name,
                   ir_interface_ele.element_type_id,
                   ir_interface_ele.element_link_id,
                   ir_interface_ele.element_entry_id,
                   ir_interface_ele.element_entry_value_id,
                   ir_interface_ele.uom, ir_interface_ele.uom_meaning,
                   ir_interface_ele.input_value_id,
                   ir_interface_ele.input_value_name,
                   ir_interface_ele.screen_entry_value,
                   ir_interface_ele.creator_type,
                   ir_interface_ele.entry_effective_start_date,
                   ir_interface_ele.entry_effective_end_date,
                   ir_interface_ele.hourly_salary,
                   ir_interface_ele.creation_date,
                   ir_interface_ele.last_extract_date,
                   ir_interface_ele.last_extract_file_type,
                   ir_interface_ele.uk_sal_fortnightly_indicator
                  );
   END;                                                -- insert_interface_ele

--------------------------------------------------------------------
--                                                                --
-- Name:  populate_interface_tables          (Procedure)          --
--                                                                --
--     Description:         Procedure called by the other         --
--                            procedures to load                  --
--                            table ttec_uk_pay_interface_mst     --
--                                                                --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation             --
--                                                                --
--                                                                --
--------------------------------------------------------------------
   PROCEDURE populate_interface_tables
   IS
-- Ken Mod 7/6/05 add trunc for all date fields
      CURSOR c_ele_data
      IS
         SELECT /*+ ordered use_nl(ppf) use_Nl(paf) use_nl(ppayf) use_nl(peef) use_nl(peevf) use_nl(pelf) use_nl(petf) use_nl(pivf) use_nl(pec) */
                ppf.person_id, ppf.employee_number, paf.assignment_id,

-- added by Ken 7/6/05
                paf.pay_basis_id, ppayf.payroll_id, ppayf.payroll_name,
                petf.element_type_id, petf.processing_type,
                ppf.attribute12 emp_attribute12,
                petf.attribute1 ele_attribute1, petf.element_name,
                petf.description, pelf.element_link_id,
                pec.classification_name, petf.reporting_name, pivf.uom,
                hl.meaning uom_meaning, pivf.input_value_id,
                pivf.NAME input_value_name, peevf.element_entry_value_id,
                peevf.screen_entry_value, peef.element_entry_id,
                peef.creator_type,
                DECODE (pay_basis,
                        'HOURLY', NVL (proposed_salary_n, 0),
                        NVL (proposed_salary_n, 0) / 2080
                       ) hourly_salary,
                peef.effective_start_date entry_effective_start_date,
                peef.effective_end_date entry_effective_end_date, pay_basis,
                ptp.start_date, pps.actual_termination_date, ptp.end_date
           /*  DECODE
                (pay_basis,
                 'HOURLY', -999,
                 per_accrual_calc_functions.get_working_days
                                         (ptp.start_date, CASE WHEN pps.actual_termination_date IS NULL THEN
                           ptp.end_date
                 ELSE pps.actual_termination_date > ptp.end_date THEN
               ptp.end_date
                 ELSE pps.actual_termination_date)
                                         )
                ) biweekly_tot_working_days  -- Added by C. Chan WO#134907*/
         FROM   per_all_people_f ppf,
                per_all_assignments_f paf,
                pay_payrolls_f ppayf,
                pay_element_entries_f peef,
                pay_element_entry_values_f peevf,
                pay_element_links_f pelf,
                pay_element_types_f petf,
                pay_input_values_f pivf,
                pay_element_classifications pec,
                hr_lookups hl,
                per_pay_proposals ppp,
                per_pay_bases ppb,
                per_person_types ppt,
                per_person_type_usages_f pptuf,
                per_periods_of_service pps,      -- Added by C. Chan WO#134907
                per_time_periods ptp             -- Added by C. Chan WO#134907
          WHERE ppf.business_group_id = g_business_group_id
            AND TRUNC (g_cut_off_date) BETWEEN TRUNC (ppf.effective_start_date)
                                           AND TRUNC (ppf.effective_end_date)
            AND ppf.person_id = paf.person_id
            AND TRUNC (g_cut_off_date) BETWEEN TRUNC (paf.effective_start_date)
                                           AND TRUNC (paf.effective_end_date)
            AND paf.payroll_id = ppayf.payroll_id
            AND ppayf.payroll_name = g_payroll_name
            AND TRUNC (g_cut_off_date) BETWEEN TRUNC
                                                   (ppayf.effective_start_date)
                                           AND TRUNC (ppayf.effective_end_date)
            AND paf.assignment_id = peef.assignment_id
            AND TRUNC (g_cut_off_date) BETWEEN TRUNC
                                                    (peef.effective_start_date)
                                           AND TRUNC (peef.effective_end_date)
            AND peef.element_entry_id = peevf.element_entry_id
            AND TRUNC (g_cut_off_date) BETWEEN TRUNC
                                                   (peevf.effective_start_date)
                                           AND TRUNC (peevf.effective_end_date)
            AND peef.element_link_id = pelf.element_link_id
            AND TRUNC (g_cut_off_date) BETWEEN TRUNC
                                                    (pelf.effective_start_date)
                                           AND TRUNC (pelf.effective_end_date)
            AND pelf.element_type_id = petf.element_type_id
            AND TRUNC (g_cut_off_date) BETWEEN TRUNC
                                                    (petf.effective_start_date)
                                           AND TRUNC (petf.effective_end_date)
            AND peevf.input_value_id = pivf.input_value_id
            AND TRUNC (g_cut_off_date) BETWEEN TRUNC
                                                    (pivf.effective_start_date)
                                           AND TRUNC (pivf.effective_end_date)
            AND peevf.screen_entry_value IS NOT NULL
            AND petf.classification_id = pec.classification_id
            AND pivf.uom = hl.lookup_code
            AND hl.lookup_type = 'UNITS'
            AND ppp.assignment_id = paf.assignment_id
            AND ppp.approved = 'Y'
            AND TRUNC (ppp.change_date) =
                   (SELECT MAX (TRUNC (change_date))
                      FROM per_pay_proposals ppp1
                     WHERE ppp.assignment_id = ppp1.assignment_id
                       AND ppp1.approved = 'Y'
                       AND TRUNC (ppp1.change_date) <
                                               TRUNC (peef.effective_end_date))
            AND paf.pay_basis_id = ppb.pay_basis_id
            AND ppb.business_group_id = ppf.business_group_id
            AND ppf.person_id = pptuf.person_id
            AND pptuf.person_type_id = ppt.person_type_id
            AND TRUNC (g_cut_off_date) BETWEEN TRUNC
                                                   (pptuf.effective_start_date)
                                           AND TRUNC (pptuf.effective_end_date)
            AND ppt.user_person_type IN
                   ('Employee', 'Ex-employee', 'Expatriate')
                                                        -- V 1.4 ticket 202959
            AND ppt.business_group_id = g_business_group_id
-- Added by C. Chan WO#134907
            AND paf.period_of_service_id = pps.period_of_service_id
            AND paf.person_id = pps.person_id
            AND paf.payroll_id = ptp.payroll_id
            AND TRUNC (g_cut_off_date) BETWEEN ptp.start_date AND ptp.end_date;

      v_salary                      NUMBER;
      v_sal_change_date             DATE;
      v_sal_change_reason           VARCHAR2 (30);
      v_pea_segment1                VARCHAR2 (150);
      v_pea_segment2                VARCHAR2 (150);
      v_pea_segment3                VARCHAR2 (150);
      v_pea_segment4                VARCHAR2 (150);
      v_org_payment_method_name     VARCHAR2 (150);
      v_cost_segment2               VARCHAR2 (150);
      v_cost_segment3               VARCHAR2 (150);
      v_pei_attribute1              VARCHAR2 (150);
      v_contract_type               VARCHAR2 (60);
      v_contract_end_date           DATE;
      v_holiday_ot                  VARCHAR2 (60);
      v_classification              VARCHAR2 (30);
      v_uk_sal                      NUMBER                                := 1;
      v_screen_entry_value          VARCHAR2 (60)                      := NULL;
      --r_interface_ele               cust.ttec_uk_pay_interface_ele%ROWTYPE;    --code commented by RXNETHI-ARGANO,18/05/23
      r_interface_ele               apps.ttec_uk_pay_interface_ele%ROWTYPE;      --code added by RXNETHI-ARGANO,18/05/23
      v_biweekly_tot_working_days   NUMBER;
      v_end_date                    DATE;
   BEGIN
      --DELETE FROM cust.ttec_uk_pay_interface_ele ele    --code commented by RXNETHI-ARGANO,18/05/23
      DELETE FROM apps.ttec_uk_pay_interface_ele ele      --code added by RXNETHI-ARGANO,18/05/23
            WHERE TRUNC (ele.cut_off_date) = TRUNC (g_cut_off_date)
              AND payroll_name = g_payroll_name;

-- Ken Mod 7/1/05 delete temp table cust.ttec_uk_pay_interface_ele_temp entries.
      --DELETE FROM cust.ttec_uk_pay_interface_ele_temp;    --code commented by RXNETHI-ARGANO,18/05/23
      DELETE FROM apps.ttec_uk_pay_interface_ele_temp;      --code added by RXNETHI-ARGANO,18/05/23

      fnd_file.put_line (fnd_file.LOG,
                         'Begin Populate cust.ttec_uk_pay_interface_ele'
                        );

      FOR r_ele_data IN c_ele_data
      LOOP
         BEGIN
            SELECT global_value
              INTO v_uk_sal
              --FROM hr.ff_globals_f   --code commented by RXNETHI-ARGANO,18/05/23
              FROM apps.ff_globals_f   --code added by RXNETHI-ARGANO,18/05/23
             WHERE GLOBAL_NAME LIKE '%UK_SALARY_FORTNIGHTLY_INDICATOR%'
               -- added by Ken 7/6/05
               AND TRUNC (g_cut_off_date) BETWEEN TRUNC (effective_start_date)
                                              AND TRUNC (effective_end_date);
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               NULL;
               fnd_file.put_line
                            (fnd_file.LOG,
                             'UK_SALARY_FORTNIGHTLY_INDICATOR does not exist'
                            );
            WHEN OTHERS
            THEN
               NULL;
               fnd_file.put_line
                             (fnd_file.LOG,
                              'UK_SALARY_FORTNIGHTLY_INDICATOR has Erred out'
                             );
         END;

         BEGIN
            IF     r_ele_data.input_value_name = 'Annual Amount'
               AND v_uk_sal IS NOT NULL
               AND v_uk_sal > 1
            THEN
               -- Added by C. Chan WO#134907
               --   v_SCREEN_ENTRY_VALUE := round((to_number(r_ele_data.SCREEN_ENTRY_VALUE)/v_uk_sal),2);
                -- Added the following conditon for Incient# 821937
                -- Need to pass ptp end date for future termination date to find
                -- total working days
               v_biweekly_tot_working_days := 0;

               IF r_ele_data.pay_basis = 'HOURLY'
               THEN
                  v_biweekly_tot_working_days := -999;
               ELSE
                  v_end_date := NULL;

                  IF r_ele_data.actual_termination_date IS NULL
                  THEN
                     v_end_date := r_ele_data.end_date;
                  ELSIF r_ele_data.actual_termination_date >
                                                           r_ele_data.end_date
                  THEN
                     v_end_date := r_ele_data.end_date;
                  ELSE
                     v_end_date := r_ele_data.actual_termination_date;
                  END IF;

                  v_biweekly_tot_working_days :=
                     per_accrual_calc_functions.get_working_days
                                                       (r_ele_data.start_date,
                                                        v_end_date
                                                       );
               END IF;

               v_screen_entry_value :=
                  ROUND (  (  TO_NUMBER (r_ele_data.screen_entry_value)
                            / v_uk_sal
                           )
                         * v_biweekly_tot_working_days
                         / 10,
                         2
                        );
            ELSE
               v_uk_sal := NULL;
               v_screen_entry_value := r_ele_data.screen_entry_value;
            END IF;
         EXCEPTION
            WHEN OTHERS
            THEN
               v_screen_entry_value := r_ele_data.screen_entry_value;
               fnd_file.put_line
                  (fnd_file.LOG,
                      'SCREEN_ENTRY_VALUE= '
                   || r_ele_data.screen_entry_value
                   || ' for input_value_name="Annual Amount" is indivisible by UK_SALARY_FORTNIGHTLY_INDICATOR for Employee#'
                   || r_ele_data.employee_number
                  );
         END;

         r_interface_ele.payroll_id := r_ele_data.payroll_id;
         r_interface_ele.payroll_name := r_ele_data.payroll_name;
         r_interface_ele.cut_off_date := g_cut_off_date;
         r_interface_ele.person_id := r_ele_data.person_id;
         r_interface_ele.assignment_id := r_ele_data.assignment_id;
-- added by Ken 7/6/05
         r_interface_ele.pay_basis_id := r_ele_data.pay_basis_id;
         r_interface_ele.employee_number := r_ele_data.employee_number;
         r_interface_ele.emp_attribute12 := r_ele_data.emp_attribute12;
         r_interface_ele.ele_attribute1 := r_ele_data.ele_attribute1;
         r_interface_ele.element_name := r_ele_data.element_name;
         r_interface_ele.reporting_name := r_ele_data.reporting_name;
         r_interface_ele.processing_type := r_ele_data.processing_type;
         r_interface_ele.classification_name := v_classification;
         r_interface_ele.element_type_id := r_ele_data.element_type_id;
         r_interface_ele.element_link_id := r_ele_data.element_link_id;
         r_interface_ele.element_entry_id := r_ele_data.element_entry_id;
         r_interface_ele.creator_type := r_ele_data.creator_type;
         r_interface_ele.element_entry_value_id :=
                                             r_ele_data.element_entry_value_id;
         r_interface_ele.uom := r_ele_data.uom;
         r_interface_ele.uom_meaning := r_ele_data.uom_meaning;
         r_interface_ele.input_value_id := r_ele_data.input_value_id;
         r_interface_ele.input_value_name := r_ele_data.input_value_name;
         r_interface_ele.screen_entry_value := v_screen_entry_value;
         r_interface_ele.entry_effective_start_date :=
                                         r_ele_data.entry_effective_start_date;
         r_interface_ele.entry_effective_end_date :=
                                           r_ele_data.entry_effective_end_date;
         r_interface_ele.creation_date := g_sysdate;
         r_interface_ele.last_extract_file_type := 'PAYROLL RUN';
         r_interface_ele.hourly_salary := r_ele_data.hourly_salary;
         r_interface_ele.uk_sal_fortnightly_indicator := v_uk_sal;
         insert_interface_ele (ir_interface_ele => r_interface_ele);
         v_uk_sal := NULL;
         v_screen_entry_value := NULL;
      END LOOP;                                                  -- c_ele_data

      fnd_file.put_line (fnd_file.LOG,
                         'End Populate cust.ttec_uk_pay_interface_ele'
                        );
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         g_retcode := SQLCODE;
         g_errbuf := SUBSTR (SQLERRM, 1, 255);
         fnd_file.put_line (fnd_file.LOG, 'Populate Interface Failed');
         fnd_file.put_line (fnd_file.LOG, SUBSTR (SQLERRM, 1, 255));
         RAISE g_e_abort;
   END;                                 -- procedure populate_interface_tables

-- main()
--------------------------------------------------------------------
--                                                                --
-- Name:  extract_uk_emps             (Procedure)                --
--                                                                --
--     Description:         Procedure called by the concurrent    --
--                            manager to extract new hire data    --
--                                                                --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation             --
--                                                                --
--                                                                --
--------------------------------------------------------------------
   PROCEDURE extract_uk_emps (
      ov_errbuf         OUT      VARCHAR2,
      ov_retcode        OUT      NUMBER,
      iv_cut_off_date   IN       DATE,
      iv_payroll_name   IN       VARCHAR2
   )
   IS
      l_date             DATE;
      l_valid_date       BOOLEAN;
      l_e_invalid_date   EXCEPTION;
      l_cut_off_date     DATE;
   BEGIN
      validate_date (iv_cut_off_date, l_date, l_valid_date);

      IF NOT l_valid_date
      THEN
         RAISE l_e_invalid_date;
      ELSE
         l_cut_off_date := l_date;
      END IF;

      set_business_group_id (iv_business_group => 'TeleTech Holdings - UK');
      g_payroll_name := iv_payroll_name;
      fnd_file.put_line (fnd_file.LOG,
                            'Business Group ID = '
                         || TO_CHAR (g_business_group_id)
                        );

--  set_payroll_dates (iv_pay_period_id          => iv_pay_period);--not required--
      IF     l_cut_off_date IS NOT NULL
         AND TRUNC (l_cut_off_date) <= TRUNC (SYSDATE)
      THEN
         BEGIN
            SELECT end_date
              INTO g_cut_off_date
              FROM per_time_periods ptp, pay_payrolls_f ppf
             WHERE ptp.payroll_id = ppf.payroll_id
               AND SYSDATE BETWEEN ppf.effective_start_date
                               AND ppf.effective_end_date
               AND payroll_name = g_payroll_name
               AND TO_DATE (l_cut_off_date, 'DD-MON-RRRR')
                      BETWEEN ptp.start_date
                          AND ptp.end_date;
         EXCEPTION
            WHEN OTHERS
            THEN
               RAISE g_e_invalid_payroll;
         END;
      ELSE
         RAISE g_e_future_date;
      END IF;

      fnd_file.put_line
                     (fnd_file.LOG,
                         'Cut Off Date(Derived from Payroll End Date)      = '
                      || TO_CHAR (g_cut_off_date, 'MM/DD/YYYY')
                     );
      fnd_file.put_line (fnd_file.LOG,
                         'Payroll Name      = ' || g_payroll_name
                        );
      fnd_file.put_line (fnd_file.LOG, 'Start populate UK interface tables');
      populate_interface_tables;
      fnd_file.put_line (fnd_file.LOG, 'Ended populate UK interface tables');
      fnd_file.put_line (fnd_file.LOG, 'Start extract_elements');
      extract_elements;
      fnd_file.put_line (fnd_file.LOG, 'Ended extract_elements');
-- Ken Mod 8/23/05 added to pruduct pay code control totals in current log file.
      fnd_file.put_line (fnd_file.LOG, 'Start extract_elements_ctl_tot');
      extract_elements_ctl_tot;
      fnd_file.put_line (fnd_file.LOG, 'Ended extract_elements_ctl_tot');
      ov_retcode := g_retcode;
      ov_errbuf := g_errbuf;
   EXCEPTION
      WHEN g_e_abort
      THEN
         fnd_file.put_line (fnd_file.LOG,
                            'Process Aborted - Contact Teletech Help Desk'
                           );
         ov_retcode := g_retcode;
         ov_errbuf := g_errbuf;
      WHEN g_e_future_date
      THEN
         fnd_file.put_line
            (fnd_file.LOG,
             'Process Aborted - Pay Period not found for Specified "Cut off date" and Payroll'
            );
         ov_retcode := g_retcode;
         ov_errbuf := g_errbuf;
      --dbms_output.put_line('Process Aborted - Enter "Cut_off_date" which is not in future');
      WHEN g_e_invalid_payroll
      THEN
         fnd_file.put_line
             (fnd_file.LOG,
              'Process Aborted - Enter "Cut_off_date" which is not in future'
             );
         ov_retcode := g_retcode;
         ov_errbuf := g_errbuf;
      --dbms_output.put_line('Process Aborted - Enter "Cut_off_date" which is not in future');
      WHEN OTHERS
      THEN
         fnd_file.put_line
                         (fnd_file.LOG,
                          'When Others Exception - Contact Teltech Help Desk'
                         );
         ov_retcode := SQLCODE;
         ov_errbuf := SUBSTR (SQLERRM, 1, 255);
   END;                                                -- procedure extract_uk
END;                            -- Package Body apps.ttec_uk_pay_interface_pkg
/
show errors;
/