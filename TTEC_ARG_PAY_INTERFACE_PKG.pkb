create or replace PACKAGE BODY      ttec_arg_pay_interface_pkg
AS
--------------------------------------------------------------------
--                                                                --
-- Name:  apps.ttech_arg_pay_inteface_pkg  (Package)              --
--                                                                --
--     Description:   Argentina HR Data to the Payroll Vendor      --
--                                                                  --
--                                                                --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--    V 1.0  Vijay Mayadam   17-Jan-2005  Initial Creation              --
--    V 1.1  Wasim Manasfi    4-JUN-2010     added employee type Expatriate to main query - ticket 202959
--      1.0  IXPRAVEEN(ARGANO)      10-May-2023     R12.2 Upgrade Remediation                                                             --
--                                                                --
--------------------------------------------------------------------

   --------------------------------------------------------------------
--                                                                --
-- Name:  print_line                   (Procedure)                --
--                                                                --
--     Description:         Procedure called by other procedures  --
--                           to extract data                      --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation              --
--                                                                --
--     C.Chan           28-Dec-2005  TT#425307
--                                  Argentinian users can't run   --
--                                  extract interface in Spanish  --
--                                  Language.It finishes in error --
--
--------------------------------------------------------------------
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
--IXPRAVEEN(ARGANO)	1.0	10-May-2023 R12.2 Upgrade Remediation                                                                --
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
      iv_field10            IN   VARCHAR2 DEFAULT NULL,
      iv_field11            IN   VARCHAR2 DEFAULT NULL,
      iv_field12            IN   VARCHAR2 DEFAULT NULL,
      iv_field13            IN   VARCHAR2 DEFAULT NULL,
      iv_field14            IN   VARCHAR2 DEFAULT NULL,
      iv_field15            IN   VARCHAR2 DEFAULT NULL,
      iv_field16            IN   VARCHAR2 DEFAULT NULL,
      iv_field17            IN   VARCHAR2 DEFAULT NULL,
      iv_field18            IN   VARCHAR2 DEFAULT NULL,
      iv_field19            IN   VARCHAR2 DEFAULT NULL,
      iv_field20            IN   VARCHAR2 DEFAULT NULL,
      iv_field21            IN   VARCHAR2 DEFAULT NULL,
      iv_field22            IN   VARCHAR2 DEFAULT NULL,
      iv_field23            IN   VARCHAR2 DEFAULT NULL,
      iv_field24            IN   VARCHAR2 DEFAULT NULL,
      iv_field25            IN   VARCHAR2 DEFAULT NULL,
      iv_field26            IN   VARCHAR2 DEFAULT NULL,
      iv_field27            IN   VARCHAR2 DEFAULT NULL,
      iv_field28            IN   VARCHAR2 DEFAULT NULL,
      iv_field29            IN   VARCHAR2 DEFAULT NULL,
      iv_field30            IN   VARCHAR2 DEFAULT NULL,
      iv_field31            IN   VARCHAR2 DEFAULT NULL,
      iv_field32            IN   VARCHAR2 DEFAULT NULL,
      iv_field33            IN   VARCHAR2 DEFAULT NULL,
      iv_field34            IN   VARCHAR2 DEFAULT NULL,
      iv_field35            IN   VARCHAR2 DEFAULT NULL,
      iv_field36            IN   VARCHAR2 DEFAULT NULL,
      iv_field37            IN   VARCHAR2 DEFAULT NULL,
      iv_field38            IN   VARCHAR2 DEFAULT NULL,
      iv_field39            IN   VARCHAR2 DEFAULT NULL,
      iv_field40            IN   VARCHAR2 DEFAULT NULL,
      iv_field41            IN   VARCHAR2 DEFAULT NULL,
      iv_field42            IN   VARCHAR2 DEFAULT NULL,
      iv_field43            IN   VARCHAR2 DEFAULT NULL,
      iv_field44            IN   VARCHAR2 DEFAULT NULL,
      iv_field45            IN   VARCHAR2 DEFAULT NULL,
      iv_field46            IN   VARCHAR2 DEFAULT NULL,
      iv_field47            IN   VARCHAR2 DEFAULT NULL,
      iv_field48            IN   VARCHAR2 DEFAULT NULL,
      iv_field49            IN   VARCHAR2 DEFAULT NULL,
      iv_field50            IN   VARCHAR2 DEFAULT NULL,
      iv_field51            IN   VARCHAR2 DEFAULT NULL,
      iv_field52            IN   VARCHAR2 DEFAULT NULL,
      iv_field53            IN   VARCHAR2 DEFAULT NULL,
      iv_field54            IN   VARCHAR2 DEFAULT NULL,
      iv_field55            IN   VARCHAR2 DEFAULT NULL,
      iv_field56            IN   VARCHAR2 DEFAULT NULL,
      iv_field57            IN   VARCHAR2 DEFAULT NULL,
      iv_field58            IN   VARCHAR2 DEFAULT NULL,
      iv_field59            IN   VARCHAR2 DEFAULT NULL,
      iv_field60            IN   VARCHAR2 DEFAULT NULL,
      iv_field61            IN   VARCHAR2 DEFAULT NULL,
      iv_field62            IN   VARCHAR2 DEFAULT NULL,
      iv_field63            IN   VARCHAR2 DEFAULT NULL,
      iv_field64            IN   VARCHAR2 DEFAULT NULL,
      iv_field65            IN   VARCHAR2 DEFAULT NULL,
      iv_field66            IN   VARCHAR2 DEFAULT NULL,
      iv_field67            IN   VARCHAR2 DEFAULT NULL,
      iv_field68            IN   VARCHAR2 DEFAULT NULL,
      iv_field69            IN   VARCHAR2 DEFAULT NULL,
      iv_field70            IN   VARCHAR2 DEFAULT NULL,
      iv_field71            IN   VARCHAR2 DEFAULT NULL,
      iv_field72            IN   VARCHAR2 DEFAULT NULL,
      iv_field73            IN   VARCHAR2 DEFAULT NULL,
      iv_field74            IN   VARCHAR2 DEFAULT NULL,
      iv_field75            IN   VARCHAR2 DEFAULT NULL,
      iv_field76            IN   VARCHAR2 DEFAULT NULL,
      iv_field77            IN   VARCHAR2 DEFAULT NULL,
      iv_field78            IN   VARCHAR2 DEFAULT NULL,
      iv_field79            IN   VARCHAR2 DEFAULT NULL,
      iv_field80            IN   VARCHAR2 DEFAULT NULL
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
         || REPLACE (iv_field10, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field11, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field12, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field13, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field14, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field15, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field16, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field17, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field18, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field19, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field20, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field21, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field22, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field23, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field24, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field25, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field26, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field27, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field28, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field29, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field30, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field31, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field32, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field33, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field34, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field35, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field36, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field37, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field38, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field39, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field40, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field41, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field42, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field43, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field44, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field45, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field46, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field47, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field48, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field49, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field50, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field51, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field52, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field53, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field54, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field55, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field56, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field57, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field58, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field59, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field60, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field61, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field62, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field63, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field64, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field65, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field66, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field67, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field68, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field69, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field70, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field71, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field72, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field73, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field74, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field75, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field76, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field77, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field78, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field79, v_delimiter, v_replacement_char)
         || v_delimiter
         || REPLACE (iv_field80, v_delimiter, v_replacement_char);
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
-- Name:  term_code                  (Function)                   --
--                                                                --
--     Description:         Function called by other procedures   --
--                           it passes decode value of leaving reason --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--     Pradip Hati     19-May-2005  Initial Creation              --
--                                                                --
--                                                                --
--------------------------------------------------------------------
   FUNCTION term_code (iv_text IN VARCHAR2)
      RETURN VARCHAR2
   IS
      l_term_code   VARCHAR2 (2) := NULL;
   BEGIN
      SELECT DECODE (SUBSTR (iv_text, 4, 2),
                     '38', '93',
                     DECODE (SUBSTR (iv_text, 1, 3),
                             '202', '91',
                             '209', '91',
                             '216', '92',
                             '221', '91',
                             '228', '92',
                             '235', '91',
                             '239', '91',
                             '240', '94',
                             NULL
                            )
                    )
        INTO l_term_code
        FROM DUAL;

      RETURN l_term_code;
   END;                                            -- function scrub_to_number

--------------------------------------------------------------------
--                                                                --
-- Name:  set_business_group_id        (Procedure)                --
--                                                                --
--     Description:         Procedure called by other procedures  --
--                           to set global business_group_id      --
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
      iv_business_group   IN   VARCHAR2 DEFAULT 'TeleTech Holdings - ARG'
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

                        as 'DD-MM-RRRR' --  Modified by C.Chan on 28-DEC-2005 for TT#425307

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
      l_nls_date_format := 'DD-MM-RRRR';
                          --  Modified by C.Chan on 28-DEC-2005 for TT#425307
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
      NULL;     --not using payroll cut-off dates for ARG payroll interface--
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
-- Name:  get_salary        (Procedure)                           --
--                                                                --
--     Description:         Procedure called by other procedures  --
--                           to return salary and change date     --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation             --
--                                                                --
--                                                                --
--------------------------------------------------------------------
   PROCEDURE get_salary (
      iv_assignment_id   IN       VARCHAR2,
      ov_salary          OUT      NUMBER,
      ov_change_date     OUT      DATE,
      ov_change_reason   OUT      VARCHAR2
   )
   IS
   BEGIN
      SELECT ppp.proposed_salary_n, ppp.change_date, ppp.proposal_reason
        INTO ov_salary, ov_change_date, ov_change_reason
        FROM per_pay_proposals ppp
       WHERE assignment_id = iv_assignment_id
         AND approved = 'Y'
         AND change_date =
                (SELECT MAX (change_date)
                   FROM per_pay_proposals
                  WHERE assignment_id = iv_assignment_id
                    AND approved = 'Y'
                    AND change_date <= TRUNC (g_cut_off_date));
   EXCEPTION
      WHEN OTHERS
      THEN
         ov_salary := 0;
         ov_change_date := TO_DATE (NULL);
         ov_change_reason := NULL;
   END;                                                -- procedure get_salary

--------------------------------------------------------------------
--                                                                --
-- Name:  get_cost_allocation          (Procedure)                --
--                                                                --
--     Description:         Procedure called by other procedures  --
--                           to return cost allocation segments   --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation              --
--                                                                --
--                                                                --
--------------------------------------------------------------------
   PROCEDURE get_cost_allocation (
      iv_assignment_id     IN       NUMBER,
      iv_organization_id   IN       NUMBER,
      ov_cost_segment2     OUT      VARCHAR2,
      ov_cost_segment3     OUT      VARCHAR2
   )
   IS
   BEGIN
      BEGIN
         SELECT kflx.segment2, kflx.segment3
           INTO ov_cost_segment2, ov_cost_segment3
		   --START R12.2 Upgrade Remediation
           /*FROM hr.pay_cost_allocations_f pcaf,					-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                hr.pay_cost_allocation_keyflex kflx*/               
		   FROM apps.pay_cost_allocations_f pcaf,						--  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                apps.pay_cost_allocation_keyflex kflx	
		   --END R12.2.10 Upgrade remediation
          WHERE pcaf.cost_allocation_keyflex_id =
                                               kflx.cost_allocation_keyflex_id
            AND TRUNC (g_cut_off_date) BETWEEN pcaf.effective_start_date
                                           AND pcaf.effective_end_date
            AND pcaf.assignment_id = iv_assignment_id;
      EXCEPTION
         WHEN OTHERS
         THEN
            ov_cost_segment2 := '9500';
            ov_cost_segment3 := '000';
      END;

      IF ov_cost_segment3 IS NULL
      THEN
         BEGIN
            SELECT segment3
              INTO ov_cost_segment3
              FROM hr_organization_units_v houv,
                   pay_cost_allocation_keyflex pcak
             WHERE houv.organization_id = 1663
               AND pcak.cost_allocation_keyflex_id =
                                               houv.cost_allocation_keyflex_id;
         EXCEPTION
            WHEN OTHERS
            THEN
               NULL;
         END;
      END IF;
   END;                                      -- procedure  get_cost_allocation

--------------------------------------------------------------------
--                                                                --
-- Name:  get_bank          (Procedure)                           --
--                                                                --
--     Description:         Function called by other procedures   --
--                           to return bank information           --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation             --
--                                                                --
--                                                                --
--------------------------------------------------------------------
   PROCEDURE get_bank (
      iv_assignment_id             IN       NUMBER,
      ov_pea_segment1              OUT      VARCHAR2,
      ov_pea_segment2              OUT      VARCHAR2,
      ov_pea_segment3              OUT      VARCHAR2,
      ov_pea_segment4              OUT      VARCHAR2,
      ov_org_payment_method_name   OUT      VARCHAR2
   )
   IS
   BEGIN
      SELECT pea.segment1, pea.segment2, pea.segment3,
             pea.segment4, popmf.org_payment_method_name
        INTO ov_pea_segment1, ov_pea_segment2, ov_pea_segment3,
             ov_pea_segment4, ov_org_payment_method_name
		--START R12.2 Upgrade Remediation	 
        /*FROM hr.pay_personal_payment_methods_f pppmf,				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
             hr.pay_external_accounts pea,                          
             hr.pay_org_payment_methods_f popmf*/
		FROM apps.pay_personal_payment_methods_f pppmf,				--  code Added by IXPRAVEEN-ARGANO,   10-May-2023
             apps.pay_external_accounts pea,
             apps.pay_org_payment_methods_f popmf	 
		--END R12.2.10 Upgrade remediation	 
       WHERE pppmf.assignment_id = iv_assignment_id
         AND TRUNC (g_cut_off_date) BETWEEN pppmf.effective_start_date
                                        AND pppmf.effective_end_date
         AND pppmf.external_account_id = pea.external_account_id(+)
         AND pppmf.org_payment_method_id = popmf.org_payment_method_id
         AND TRUNC (g_cut_off_date) BETWEEN popmf.effective_start_date
                                        AND popmf.effective_end_date
         AND popmf.business_group_id = g_business_group_id
--  and   popmf.org_payment_method_name = 'Direct Deposit'
      ;
   EXCEPTION
      WHEN TOO_MANY_ROWS
      THEN
         BEGIN
            SELECT pea.segment1, pea.segment2, pea.segment3,
                   pea.segment4, popmf.org_payment_method_name
              INTO ov_pea_segment1, ov_pea_segment2, ov_pea_segment3,
                   ov_pea_segment4, ov_org_payment_method_name
				--START R12.2 Upgrade Remediation   
              /*FROM hr.pay_personal_payment_methods_f pppmf,			-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                   hr.pay_external_accounts pea,                        
                   hr.pay_org_payment_methods_f popmf*/
			  FROM apps.pay_personal_payment_methods_f pppmf,			--  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                   apps.pay_external_accounts pea,
                   apps.pay_org_payment_methods_f popmf
			--END R12.2.10 Upgrade remediation		
             WHERE pppmf.assignment_id = iv_assignment_id
               AND TRUNC (g_cut_off_date) BETWEEN pppmf.effective_start_date
                                              AND pppmf.effective_end_date
               AND pppmf.external_account_id = pea.external_account_id(+)
               AND pppmf.org_payment_method_id = popmf.org_payment_method_id
               AND TRUNC (g_cut_off_date) BETWEEN popmf.effective_start_date
                                              AND popmf.effective_end_date
               AND popmf.business_group_id = g_business_group_id
               AND popmf.org_payment_method_name = 'Dep�sito Directo';
         EXCEPTION
            WHEN OTHERS
            THEN
               ov_pea_segment1 := NULL;
               ov_pea_segment2 := NULL;
               ov_pea_segment3 := NULL;
               ov_pea_segment4 := NULL;
               ov_org_payment_method_name := NULL;
         END;
      WHEN OTHERS
      THEN
         ov_pea_segment1 := NULL;
         ov_pea_segment2 := NULL;
         ov_pea_segment3 := NULL;
         ov_pea_segment4 := NULL;
         ov_org_payment_method_name := NULL;
   END;                                                   -- function get_bank

--------------------------------------------------------------------
--                                                                --
-- Name:  get_person_extra_info         (Procedure)               --
--                                                                --
--     Description:         Function called by other procedures   --
--                           to return person extra information   --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation             --
--                                                                --
--                                                                --
--------------------------------------------------------------------
   PROCEDURE get_person_extra_info (
      iv_person_id        IN       NUMBER,
      ov_pei_attribute1   OUT      VARCHAR2
   )
   IS
   BEGIN
-- Ken Mod 6/30/05 changed to pull OBRA_SOC field value from pei_information1, not pei_attribute1

      -- However, keeping variable name as it is (pei_attribute1)

      /*
Select p.pei_attribute1 into ov_pei_attribute1
from hr.per_people_extra_info p
where p.person_extra_info_id in
      (select max(person_extra_info_id)
      from hr.per_people_extra_info s
      where s.person_id=iv_person_id
      and s.pei_attribute_category='TTE_AR_HR_AFILIACION_ENTIDADES');
*/
      SELECT p.pei_information1
        INTO ov_pei_attribute1
        --FROM hr.per_people_extra_info p				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
        FROM apps.per_people_extra_info p                 --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
       WHERE p.person_extra_info_id IN (
                SELECT MAX (person_extra_info_id)
                  --FROM hr.per_people_extra_info s				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                  FROM apps.per_people_extra_info s               --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                 WHERE s.person_id = iv_person_id
                   AND s.pei_information_category = 'TTEC_ARG_ENTITIES');
   EXCEPTION
      WHEN OTHERS
      THEN
         ov_pei_attribute1 := NULL;
   END;                                      -- function get_person_extra_info

--------------------------------------------------------------------
--                                                                --
-- Name:  get_contract_info         (Procedure)                   --
--                                                                --
--     Description:         Function called by other procedures   --
--                           to return contract information       --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation             --
--                                                                --
--                                                                --
--------------------------------------------------------------------
   PROCEDURE get_contract_info (
      iv_person_id       IN       NUMBER,
      iv_start_date      IN       DATE,
      ov_contract_type   OUT      VARCHAR2,
      ov_sijp_vig        OUT      DATE
   )
   IS
      v_start_date       DATE;
      v_duration         VARCHAR2 (60);
      v_duration_units   VARCHAR2 (60);
   BEGIN
      SELECT TYPE, DURATION, duration_units
        INTO ov_contract_type, v_duration, v_duration_units
       -- FROM hr.per_contracts_f pc						-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
        FROM apps.per_contracts_f pc                      --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
       WHERE pc.person_id = iv_person_id
         AND TRUNC (g_cut_off_date) BETWEEN pc.effective_start_date
                                        AND pc.effective_end_date;

      BEGIN
         v_start_date := iv_start_date;

         IF v_duration IS NOT NULL AND v_duration_units IS NOT NULL
         THEN
            BEGIN
               IF v_duration_units = 'Y'
               THEN
                  v_duration := v_duration * 12;
                  ov_sijp_vig := ADD_MONTHS (v_start_date, v_duration);
               ELSIF v_duration_units = 'M'
               THEN
                  ov_sijp_vig := ADD_MONTHS (v_start_date, v_duration);
               ELSIF v_duration_units = 'W'
               THEN
                  v_duration := v_duration * 7;
                  ov_sijp_vig := (ov_sijp_vig + v_duration);
               END IF;
            END;
         END IF;
      END;
   EXCEPTION
      WHEN OTHERS
      THEN
         ov_contract_type := NULL;
         ov_sijp_vig := NULL;
   END;                                          -- function get_contract_info

--------------------------------------------------------------------
--                                                                --
-- Name:  extract_salary_changes          (Procedure)                --
--                                                                --
--     Description:         Procedure called by the main          --
--                            procedure to extract salary       --
--                            changes                             --
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
   PROCEDURE extract_salary_changes
   IS
      CURSOR c_chg
      IS
         SELECT   *
             FROM (SELECT *
                     --FROM cust.ttec_arg_pay_interface_mst a				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                     FROM apps.ttec_arg_pay_interface_mst a                 --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                    WHERE TRUNC (a.cut_off_date) = TRUNC (g_cut_off_date)
                      AND a.system_person_type IN ('EMP', 'EMP_APL')
                      AND apps.ttec_arg_intf_util.record_changed_n
                                                        ('SALARY',
                                                         a.person_id,
                                                         a.assignment_id,
                                                         TRUNC (g_cut_off_date)
                                                        ) = 'Y'
                   UNION
                   SELECT *
                     --FROM cust.ttec_arg_pay_interface_mst a				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                     FROM apps.ttec_arg_pay_interface_mst a                 --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                    WHERE TRUNC (a.cut_off_date) = TRUNC (g_cut_off_date)
                      AND system_person_type IN ('EMP', 'EMP_APL')
                      AND NOT EXISTS (
                             SELECT 'x'
                               --FROM cust.ttec_arg_pay_interface_mst s					-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                               FROM apps.ttec_arg_pay_interface_mst s                   --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                              WHERE person_id = a.person_id
                                AND TRUNC (s.cut_off_date) !=
                                                        TRUNC (g_cut_off_date))) y
         ORDER BY y.attribute12;

      v_output   VARCHAR2 (1000);
   BEGIN
      print_line (' ** Extract for  Salary Data Changes (Section 2)** ');

      FOR r_chg IN c_chg
      LOOP
         v_output :=
            delimit_text (iv_number_of_fields      => 3,
                          iv_field1                => r_chg.attribute12,
                          iv_field2                => r_chg.salary,
                          iv_field3                => TO_CHAR
                                                         (r_chg.salary_change_date,
                                                          'DD/MM/RRRR'
                                                         )
                         );
         print_line (v_output);
      END LOOP;                                                      -- c_curr
   END;                                    -- procedure extract_salary_changes

--------------------------------------------------------------------
--                                                                --
-- Name:  extract_emp_changes          (Procedure)                --
--                                                                --
--     Description:         Procedure called by the main          --
--               procedure to extract Basic Employee Data Changes --
--                                                                --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation              --
--                                                                --
--                                                                --
--------------------------------------------------------------------
   PROCEDURE extract_emp_changes
   IS
      v_delimit        VARCHAR2 (5)    := '.';

      CURSOR c_chg
      IS
         SELECT   z.*,
                  DECODE (z.marital_status,
                          'S', '1',
                          'M', '2',
                          'W', '3',
                          'D', '4',
                          '5', '5',
                          NULL
                         ) marital_status_code,
                  DECODE
                     (z.org_payment_method_name,
                      'Dep�sito Directo', 'D',
                      'Cheque', 'C',
                      org_payment_method_name
                     ) org_payment_method_name_code
             FROM (SELECT a.*, 'M' addition_modification
                     --FROM cust.ttec_arg_pay_interface_mst a						-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                     FROM apps.ttec_arg_pay_interface_mst a                     --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                    WHERE TRUNC (a.cut_off_date) = TRUNC (g_cut_off_date)
                      AND a.system_person_type IN ('EMP', 'EMP_APL')
                      AND (   apps.ttec_arg_intf_util.record_changed_v
                                                        ('ATTRIBUTE12',
                                                         a.person_id,
                                                         a.assignment_id,
                                                         TRUNC (g_cut_off_date)
                                                        ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                        ('MARITAL_STATUS',
                                                         a.person_id,
                                                         a.assignment_id,
                                                         TRUNC (g_cut_off_date)
                                                        ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                        ('LAST_NAME',
                                                         a.person_id,
                                                         a.assignment_id,
                                                         TRUNC (g_cut_off_date)
                                                        ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                        ('FIRST_NAME',
                                                         a.person_id,
                                                         a.assignment_id,
                                                         TRUNC (g_cut_off_date)
                                                        ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                        ('MIDDLE_NAMES',
                                                         a.person_id,
                                                         a.assignment_id,
                                                         TRUNC (g_cut_off_date)
                                                        ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                       ('NATIONAL_IDENTIFIER',
                                                        a.person_id,
                                                        a.assignment_id,
                                                        TRUNC (g_cut_off_date)
                                                       ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_d
                                                        ('DATE_OF_BIRTH',
                                                         a.person_id,
                                                         a.assignment_id,
                                                         TRUNC (g_cut_off_date)
                                                        ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                        ('SEX',
                                                         a.person_id,
                                                         a.assignment_id,
                                                         TRUNC (g_cut_off_date)
                                                        ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                        ('ATTRIBUTE6',
                                                         a.person_id,
                                                         a.assignment_id,
                                                         TRUNC (g_cut_off_date)
                                                        ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                        ('ATTRIBUTE7',
                                                         a.person_id,
                                                         a.assignment_id,
                                                         TRUNC (g_cut_off_date)
                                                        ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                        ('COST_SEGMENT2',
                                                         a.person_id,
                                                         a.assignment_id,
                                                         TRUNC (g_cut_off_date)
                                                        ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                        ('COST_SEGMENT3',
                                                         a.person_id,
                                                         a.assignment_id,
                                                         TRUNC (g_cut_off_date)
                                                        ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                        ('JOB_SEGMENT1',
                                                         a.person_id,
                                                         a.assignment_id,
                                                         TRUNC (g_cut_off_date)
                                                        ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                   ('ORG_PAYMENT_METHOD_NAME',
                                                    a.person_id,
                                                    a.assignment_id,
                                                    TRUNC (g_cut_off_date)
                                                   ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                        ('PEA_SEGMENT1',
                                                         a.person_id,
                                                         a.assignment_id,
                                                         TRUNC (g_cut_off_date)
                                                        ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                        ('PEA_SEGMENT3',
                                                         a.person_id,
                                                         a.assignment_id,
                                                         TRUNC (g_cut_off_date)
                                                        ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                        ('PEA_SEGMENT4',
                                                         a.person_id,
                                                         a.assignment_id,
                                                         TRUNC (g_cut_off_date)
                                                        ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                        ('ASS_ATTRIBUTE7',
                                                         a.person_id,
                                                         a.assignment_id,
                                                         TRUNC (g_cut_off_date)
                                                        ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                        ('ASS_ATTRIBUTE8',
                                                         a.person_id,
                                                         a.assignment_id,
                                                         TRUNC (g_cut_off_date)
                                                        ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                        ('ASS_ATTRIBUTE9',
                                                         a.person_id,
                                                         a.assignment_id,
                                                         TRUNC (g_cut_off_date)
                                                        ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                        ('ASS_ATTRIBUTE10',
                                                         a.person_id,
                                                         a.assignment_id,
                                                         TRUNC (g_cut_off_date)
                                                        ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                        ('ASS_ATTRIBUTE11',
                                                         a.person_id,
                                                         a.assignment_id,
                                                         TRUNC (g_cut_off_date)
                                                        ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                        ('ASS_ATTRIBUTE12',
                                                         a.person_id,
                                                         a.assignment_id,
                                                         TRUNC (g_cut_off_date)
                                                        ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                        ('PEI_ATTRIBUTE11',
                                                         a.person_id,
                                                         a.assignment_id,
                                                         TRUNC (g_cut_off_date)
                                                        ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                        ('CONTRACT_TYPE',
                                                         a.person_id,
                                                         a.assignment_id,
                                                         TRUNC (g_cut_off_date)
                                                        ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                        ('SALARY',
                                                         a.person_id,
                                                         a.assignment_id,
                                                         TRUNC (g_cut_off_date)
                                                        ) = 'Y'
                          )
                   UNION
--new_hires--
                   SELECT a.*, 'A' addition_modification
                     --FROM cust.ttec_arg_pay_interface_mst a					-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                     FROM apps.ttec_arg_pay_interface_mst a                     --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                    WHERE TRUNC (a.cut_off_date) = TRUNC (g_cut_off_date)
                      AND system_person_type = 'EMP'
                      AND NOT EXISTS (
                             SELECT 'x'
                               --FROM cust.ttec_arg_pay_interface_mst s				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                               FROM apps.ttec_arg_pay_interface_mst s               --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                              WHERE person_id = a.person_id
                                AND TRUNC (s.cut_off_date) !=
                                       (SELECT MAX (TRUNC (cut_off_date))
                                       --   FROM cust.ttec_arg_pay_interface_mst			-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                                          FROM apps.ttec_arg_pay_interface_mst          --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                                         WHERE person_id = s.person_id
                                           AND TRUNC (cut_off_date) <
                                                        TRUNC (g_cut_off_date)))
                   UNION
--ex_employees--
                   SELECT a.*, 'M' addition_modification
                     --FROM cust.ttec_arg_pay_interface_mst a						-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                     FROM apps.ttec_arg_pay_interface_mst a                         --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                    WHERE TRUNC (a.cut_off_date) = TRUNC (g_cut_off_date)
                      AND a.system_person_type IN ('EX_EMP', 'EX_EMP_APL')
                      AND apps.ttec_arg_intf_util.record_changed_v
                                                        ('SYSTEM_PERSON_TYPE',
                                                         a.person_id,
                                                         a.assignment_id,
                                                         TRUNC (g_cut_off_date)
                                                        ) = 'Y'
                   UNION
--rehires-
                   SELECT a.*, 'A' addition_modification
                     --FROM cust.ttec_arg_pay_interface_mst a				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                     FROM apps.ttec_arg_pay_interface_mst a                 --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                    WHERE TRUNC (a.cut_off_date) = TRUNC (g_cut_off_date)
                      AND system_person_type = 'EMP'
                      AND EXISTS (
                             SELECT 'x'
                               --FROM cust.ttec_arg_pay_interface_mst s						-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                               FROM apps.ttec_arg_pay_interface_mst s                       --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                              WHERE person_id = a.person_id
                                AND s.system_person_type = 'EX_EMP'
                                AND TRUNC (s.cut_off_date) <
                                                        TRUNC (g_cut_off_date))
                      AND apps.ttec_arg_intf_util.record_changed_v
                                                        ('REHIRE',
                                                         a.person_id,
                                                         a.assignment_id,
                                                         TRUNC (g_cut_off_date)
                                                        ) =
                                            'Y'
                                               --not reqd as taken in cursor--
                                               ) z
         ORDER BY z.attribute12;

      v_output         VARCHAR2 (4000);
      var_field32      VARCHAR2 (100);                         -- Added by USi
      var_keyfled_id   VARCHAR2 (100);                         -- Added by USi
      var_log          VARCHAR2 (300);                     -- Added by C. CHAN
   BEGIN
--select to_char(�.�) Into v_delimit from fnd_dual;
      print_line
         ('** Extract for  Basic Employee Data Changes, New Hires, Terminations, Rehires (Section 1)**'
         );

      FOR r_chg IN c_chg
      LOOP
---**** Added by USi

         /*
Select cost_allocation_keyflex_id into var_keyfled_id
From hr.pay_cost_allocations_f pcaf
Where object_version_number=
 (select max(object_version_number)
 from hr.pay_cost_allocations_f
 where assignment_id=r_chg.assignment_id)
And assignment_id=r_chg.assignment_id;
*/
         var_log :=
               var_log
            || ' '
            || 'Person National Identifier'
            || r_chg.national_identifier;
         var_log := 'assignment_id -> ' || r_chg.assignment_id;
         var_log := var_log || ' ' || 'Obtaining cost_allocation_keyflex_id ';

         BEGIN
            SELECT cost_allocation_keyflex_id
              INTO var_keyfled_id
              --FROM hr.pay_cost_allocations_f pcaf1				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
              FROM apps.pay_cost_allocations_f pcaf1              --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
             WHERE effective_end_date =
                                  (SELECT MAX (effective_end_date)
                                     --FROM hr.pay_cost_allocations_f pcaf2				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                                     FROM apps.pay_cost_allocations_f pcaf2               --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                                    WHERE assignment_id = r_chg.assignment_id)
               AND assignment_id = r_chg.assignment_id;

            var_log :=
                  var_log
               || ' '
               || 'Obtaining concatenated_segments var_keyfled_id -> '
               || var_keyfled_id;

            SELECT concatenated_segments
              INTO var_field32
           --   FROM hr.pay_cost_allocation_keyflex kflx					-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
              FROM apps.pay_cost_allocation_keyflex kflx                  --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
             WHERE kflx.cost_allocation_keyflex_id = var_keyfled_id;
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               var_field32 := NULL;
               var_keyfled_id := NULL;
            WHEN OTHERS
            THEN
               var_field32 := NULL;
               var_keyfled_id := NULL;
         END;

--****
         v_output :=
            delimit_text
               (iv_number_of_fields      => 79,
                iv_field1                => NVL (r_chg.attribute12, '????'),
                                           --substr(r_chg.employee_number,2)--
                iv_field2                => r_chg.last_name,
                iv_field3                => r_chg.first_name,
                                               -- ||' ,'||r_chg.Middle_Names--
                iv_field4                => r_chg.address_line1,
                iv_field5                => r_chg.address_line2,
                iv_field6                => r_chg.address_line3,
                iv_field7                => r_chg.add_information14,
                iv_field8                => r_chg.add_information16,
                iv_field9                => r_chg.region_1,
                iv_field10               => r_chg.postal_code,
                iv_field11               => r_chg.phone_number,
                iv_field12               => TO_CHAR (r_chg.date_of_birth,
                                                     'DD/MM/RRRR'
                                                    ), --r_chg.date_of_birth ,
                iv_field13               => r_chg.town_of_birth,
                iv_field14               => r_chg.nationality,
                iv_field15               => r_chg.marital_status_code,
                iv_field16               => r_chg.sex,
                iv_field17               => r_chg.attribute6,
                iv_field18               => r_chg.national_identifier,
                iv_field19               => NULL,
                iv_field20               => r_chg.attribute7,
                iv_field21               => TO_CHAR (r_chg.start_date,
                                                     'DD/MM/RRRR'
                                                    ),    --r_chg.start_date ,
                iv_field22               => TO_CHAR
                                               (TO_DATE
                                                      (r_chg.ass_attribute10,
                                                       'yyyy/mm/dd hh24:mi:ss'
                                                      ),
                                                'dd/mm/yyyy'
                                               ),
                --r_chg.ass_attribute10 ,
                iv_field23               => r_chg.fec_accid,
                iv_field24               => TO_CHAR
                                               (r_chg.actual_termination_date,
                                                'DD/MM/RRRR'
                                               ),
                                             --r_chg.actual_termination_date ,
                iv_field25               => term_code (r_chg.leaving_reason),
                iv_field26               => r_chg.nro_tarj,
                iv_field27               => r_chg.ass_attribute7,
                iv_field28               => NULL,
                iv_field29               => r_chg.cost_segment3,
                iv_field30               => NULL,
                iv_field31               => NULL,
/*
   iv_field32          => r_chg.job_segment1 || v_delimit ||  r_chg.cost_segment2 || v_delimit || r_chg.cost_segment3,
*/
                iv_field32               => var_field32,
                iv_field33               => r_chg.job_segment1,
                iv_field34               => NULL,
                iv_field35               => NULL,
                iv_field36               => NULL,
                iv_field37               => NULL,
                iv_field38               => r_chg.org_payment_method_name_code,
                iv_field39               => r_chg.lug_pago_constant,
                iv_field40               => NULL,
                iv_field41               => NULL,
                iv_field42               => NULL,
                iv_field43               => NULL,
                iv_field44               => NULL,
                iv_field45               => NULL,
                iv_field46               => r_chg.pea_segment4,
                iv_field47               => r_chg.ass_attribute11,
                                                      --r_chg.pei_attribute1 ,
                -- Ken 6/30/05 pei_attribute1 actually contains pei_information1 value.
                iv_field48               => r_chg.pei_attribute1,
                iv_field49               => NULL,
                iv_field50               => NULL,
                iv_field51               => NULL,
                iv_field52               => NULL,
                iv_field53               => NULL,
                iv_field54               => NULL,
                iv_field55               => NULL,
                iv_field56               => NULL,
                iv_field57               => NULL,
                iv_field58               => NULL,
                iv_field59               => NULL,
                iv_field60               => NULL,
                iv_field61               => r_chg.cost_segment3,
                iv_field62               => NULL,
                iv_field63               => NULL,
                iv_field64               => r_chg.ass_attribute9,
                iv_field65               => r_chg.ass_attribute12,
                iv_field66               => r_chg.sijp_constant,
--                               iv_field67          => r_chg.Contract_Type ,
                iv_field67               => NULL,
--                               iv_field68          => to_char(r_chg.Contract_end_date ,'DD/MM/RRRR'),--r_chg.Contract_end_date ,
                iv_field68               => r_chg.contract_type,
                iv_field69               => r_chg.cuit_flag,
                iv_field70               => r_chg.pea_segment1,
                iv_field71               => r_chg.pea_segment2,
                iv_field72               => r_chg.pea_segment3,
                iv_field73               => NULL,
                iv_field74               => NULL,
                iv_field75               => NULL,
                iv_field76               => r_chg.ass_attribute8,
                iv_field77               => r_chg.caraserv_constant,
                iv_field78               => TO_CHAR
                                               (r_chg.creation_date,
                                                'DD/MM/RRRR'
                                               )         --r_chg.creation_date
                                                ,
                iv_field79               => r_chg.addition_modification
               );
         print_line (v_output);
      END LOOP;                                                      -- c_curr
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, var_log);
         fnd_file.put_line (fnd_file.LOG, SUBSTR (SQLERRM, 1, 255));
   END;                                       -- procedure extract_emp_changes

----------------------------------------------------------------------
--                                                                --
-- Name:  extract_dep_changes          (Procedure)                --
--                                                                --
--     Description:         Procedure called by the main          --
--            procedure to extract Employee Contacts Data Changes --
--                                                                --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   17-Jan-2005  Initial Creation              --
--                                                                --
--                                                                --
--------------------------------------------------------------------
   PROCEDURE extract_dep_changes
   IS
      CURSOR c_chg
      IS
         SELECT   *
             FROM (SELECT a.*,
                          DECODE (a.relationship,
                                  'C', 'H',
                                  'D', 'C',
                                  'S', 'C',
                                  'HD', 'D',
                                  'P', 'PR',
                                  NULL
                                 ) relationship_code
                     --FROM cust.ttec_arg_pay_interface_dep a				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                     FROM apps.ttec_arg_pay_interface_dep a                 --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                    WHERE TRUNC (a.cut_off_date) = TRUNC (g_cut_off_date)
                      AND (   apps.ttec_arg_intf_util.record_changed_v
                                                   ('RELATIONSHIP',
                                                    a.contact_relationship_id,
                                                    NULL,
                                                    TRUNC (g_cut_off_date)
                                                   ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                   ('REL_LAST_NAME',
                                                    a.contact_relationship_id,
                                                    NULL,
                                                    TRUNC (g_cut_off_date)
                                                   ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                   ('REL_FIRST_NAME',
                                                    a.contact_relationship_id,
                                                    NULL,
                                                    TRUNC (g_cut_off_date)
                                                   ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                   ('REL_MIDDLE_NAMES',
                                                    a.contact_relationship_id,
                                                    NULL,
                                                    TRUNC (g_cut_off_date)
                                                   ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_d
                                                   ('REL_DATE_OF_BIRTH',
                                                    a.contact_relationship_id,
                                                    NULL,
                                                    TRUNC (g_cut_off_date)
                                                   ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                   ('REL_DOCUMENT_TYPE',
                                                    a.contact_relationship_id,
                                                    NULL,
                                                    TRUNC (g_cut_off_date)
                                                   ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                   ('REL_DOCUMENT_NUMBER',
                                                    a.contact_relationship_id,
                                                    NULL,
                                                    TRUNC (g_cut_off_date)
                                                   ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_v
                                                   ('REL_SCHOLASTIC_INFO',
                                                    a.contact_relationship_id,
                                                    NULL,
                                                    TRUNC (g_cut_off_date)
                                                   ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_d
                                                   ('REL_DATE_FROM',
                                                    a.contact_relationship_id,
                                                    NULL,
                                                    TRUNC (g_cut_off_date)
                                                   ) = 'Y'
                           OR apps.ttec_arg_intf_util.record_changed_d
                                                   ('REL_DATE_TO',
                                                    a.contact_relationship_id,
                                                    NULL,
                                                    TRUNC (g_cut_off_date)
                                                   ) = 'Y'
                          )
--new_hires--
                   UNION
                   SELECT b.*,
                          DECODE (b.relationship,
                                  'C', 'H',
                                  'D', 'C',
                                  'S', 'C',
                                  'HD', 'D',
                                  'P', 'PR',
                                  NULL
                                 ) relationship_code
                     --FROM cust.ttec_arg_pay_interface_dep b				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                     FROM apps.ttec_arg_pay_interface_dep b                 --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                    WHERE TRUNC (b.cut_off_date) = TRUNC (g_cut_off_date)
                      AND b.emp_person_id IN (
                             SELECT sub.person_id
                               --FROM cust.ttec_arg_pay_interface_mst sub		-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                               FROM apps.ttec_arg_pay_interface_mst sub         --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                              WHERE TRUNC (sub.cut_off_date) =
                                                        TRUNC (g_cut_off_date)
                                AND sub.system_person_type IN
                                                           ('EMP', 'EMP_APL')
                                AND NOT EXISTS (
                                       SELECT 'x'
                                         --FROM cust.ttec_arg_pay_interface_mst s		-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                                         FROM apps.ttec_arg_pay_interface_mst s         --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                                        WHERE s.person_id = sub.person_id
                                          AND TRUNC (s.cut_off_date) !=
                                                 (SELECT MAX
                                                            (TRUNC
                                                                 (cut_off_date)
                                                            )
                                                    --FROM cust.ttec_arg_pay_interface_mst			-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                                                    FROM apps.ttec_arg_pay_interface_mst            --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                                                   WHERE person_id =
                                                                   s.person_id
                                                     AND TRUNC (cut_off_date) <
                                                            TRUNC
                                                               (g_cut_off_date))))
--new_hires employee later additions of dependents--
                   UNION
                   SELECT b.*,
                          DECODE (b.relationship,
                                  'C', 'H',
                                  'D', 'C',
                                  'S', 'C',
                                  'HD', 'D',
                                  'P', 'PR',
                                  NULL
                                 ) relationship_code
                     --FROM cust.ttec_arg_pay_interface_dep b					-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                     FROM apps.ttec_arg_pay_interface_dep b                     --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                    WHERE TRUNC (b.cut_off_date) = TRUNC (g_cut_off_date)
                      AND b.emp_person_id IN (
                             SELECT sub.person_id
                               --FROM cust.ttec_arg_pay_interface_mst sub		-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                               FROM apps.ttec_arg_pay_interface_mst sub         --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                              WHERE TRUNC (sub.cut_off_date) =
                                                        TRUNC (g_cut_off_date)
                                AND sub.system_person_type IN
                                                           ('EMP', 'EMP_APL')
                                AND EXISTS (
                                       SELECT 'x'
                                         --FROM cust.ttec_arg_pay_interface_mst s			-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                                         FROM apps.ttec_arg_pay_interface_mst s             --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                                        WHERE s.person_id = sub.person_id
                                          AND TRUNC (s.cut_off_date) !=
                                                 (SELECT MAX
                                                            (TRUNC
                                                                 (cut_off_date)
                                                            )
                                                    --FROM cust.ttec_arg_pay_interface_mst				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                                                    FROM apps.ttec_arg_pay_interface_mst                --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                                                   WHERE person_id =
                                                                   s.person_id
                                                     AND TRUNC (cut_off_date) <
                                                            TRUNC
                                                               (g_cut_off_date))))
                      AND contact_person_id NOT IN (
                             SELECT z.contact_person_id
                               --FROM cust.ttec_arg_pay_interface_dep z					-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                               FROM apps.ttec_arg_pay_interface_dep z                   --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                              WHERE TRUNC (cut_off_date) <
                                                        TRUNC (g_cut_off_date))) x
         ORDER BY x.emp_attribute12;

      v_output   VARCHAR2 (4000);
   BEGIN
      print_line
         ('** Extract for  Employee Contacts Data Changes, New Contacts (Section 3)**'
         );

      FOR r_chg IN c_chg
      LOOP
         v_output :=
            delimit_text
               (iv_number_of_fields      => 17,
                iv_field1                => r_chg.emp_attribute12,
                                           --substr(r_chg.employee_number,2)--
                iv_field2                => r_chg.relationship_code,
                iv_field3                => r_chg.last_name,
                iv_field4                =>    r_chg.first_name
                                            || ' ,'
                                            || r_chg.middle_names,
                iv_field5                => TO_CHAR (r_chg.date_of_birth,
                                                     'DD/MM/RRRR'
                                                    ), --r_chg.date_of_birth ,
                iv_field6                => r_chg.document_type,
                iv_field7                => r_chg.document_number,
                iv_field8                => r_chg.scholastic_info,
                iv_field9                => TO_CHAR
                                                (r_chg.relationship_date_from,
                                                 'DD/MM/RRRR'
                                                ),
                                              --r_chg.relationship_Date_from ,
                iv_field10               => TO_CHAR
                                                  (r_chg.relationship_date_to,
                                                   'DD/MM/RRRR'
                                                  ),
                                                --r_chg.relationship_Date_to ,
                iv_field11               => TO_CHAR
                                                  (r_chg.scholastic_date_from,
                                                   'DD/MM/RRRR'
                                                  ),
                                                 --r_chg.Scholastic_date_from,
                iv_field12               => TO_CHAR (r_chg.scholastic_date_to,
                                                     'DD/MM/RRRR'
                                                    ),
                                                  --r_chg.Scholastic_date_to ,
                iv_field13               => r_chg.active_info,
                iv_field14               => r_chg.generates_social,
                iv_field15               => r_chg.sex,
                iv_field16               => r_chg.cuil_number,
                iv_field17               => TO_CHAR
                                               (r_chg.creation_date,
                                                'DD/MM/RRRR'
                                               )         --r_chg.creation_date
               );
         print_line (v_output);
      END LOOP;                                                      -- c_curr
   END;                                       -- procedure extract_dep_changes

--------------------------------------------------------------------
--                                                                --
-- Name:  extract_elements_new      (Procedure)                   --
--                                                                --
--     Description:         Procedure called by the concurrent    --
--                            manager to extract elements         --
--                                                                --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   27-Jan-2005  Initial Creation             --
--                                                                --
--                                                                --
--------------------------------------------------------------------
   PROCEDURE extract_elements_new (
      iv_assignment_id    IN   NUMBER,
      iv_include_salary   IN   VARCHAR2
   )
   IS
      CURSOR c_element (cv_assignment_id NUMBER, cv_include_salary VARCHAR2)
      IS
-- Retrieves New element entries
         SELECT eletab.employee_number, eletab.last_name, eletab.first_name,
                eletab.middle_names, eletab.element_name,
                eletab.screen_entry_value, eletab.entry_effective_start_date,
                eletab.emp_attribute12,
-- Ken mod 06/23/05 changed from '002' to '103'
                '103' control_constant, eletab.ele_attribute1,
                'U' tipo_constant, 'P' period_constant, eletab.cost_segment2,
                DECODE (eletab.uom, 'M', eletab.screen_entry_value) importe,
                DECODE (eletab.uom,
                        'M', NULL,
                        eletab.screen_entry_value
                       ) cantidad,
                NULL old_screen_entry_value, 'NEW' new_or_change
          -- FROM cust.ttec_arg_pay_interface_ele eletab				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
           FROM apps.ttec_arg_pay_interface_ele eletab                  --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
          WHERE assignment_id = NVL (cv_assignment_id, assignment_id)
            AND TRUNC (cut_off_date) = TRUNC (g_cut_off_date)
            AND input_value_name IN
                   ('D�', 'Dias', 'Horas', 'Plan Days', 'Unidades',
                    'Pay Value')
            AND (   (    NVL (creator_type, 'XX') != 'SP'
                     AND iv_include_salary = 'N'
                    )
                 OR (iv_include_salary = 'Y')
                )
            AND NOT EXISTS (
                   SELECT 1
                     --FROM cust.ttec_arg_pay_interface_ele eletab2				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                     FROM apps.ttec_arg_pay_interface_ele eletab2               --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                    WHERE person_id = eletab.person_id
                      AND element_type_id = eletab.element_type_id
                      -- Added on 27-jun-2005 by Vijay
                      AND entry_effective_start_date =
                                             eletab.entry_effective_start_date
                      AND entry_effective_end_date =
                                               eletab.entry_effective_end_date
                      AND TRUNC (cut_off_date) =
                             (SELECT MAX (TRUNC (cut_off_date))
                                --FROM cust.ttec_arg_pay_interface_ele			-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                                FROM apps.ttec_arg_pay_interface_ele            --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                               WHERE person_id = eletab2.person_id
                                 AND TRUNC (cut_off_date) <
                                                        TRUNC (g_cut_off_date)))
--added on 03-jun-2005
            AND eletab.input_value_id NOT IN (
                   SELECT DISTINCT m.input_value_id
                              --FROM cust.ttec_arg_pay_interface_ele m			-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                              FROM apps.ttec_arg_pay_interface_ele m            --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                             WHERE m.input_value_name = 'Horas'
                               AND TRUNC (m.cut_off_date) =
                                                        TRUNC (g_cut_off_date)
                               AND EXISTS (
                                      SELECT 'x'
                                        --FROM cust.ttec_arg_pay_interface_ele s			-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                                        FROM apps.ttec_arg_pay_interface_ele s              --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                                       WHERE s.element_entry_id =
                                                            m.element_entry_id
-- Ken mod 6/20/05 added Dias

                                         -- and s.input_value_name='D�'
                                         AND s.input_value_name IN
                                                               ('D�', 'Dias')
-- Ken mod 6/20/05
                                         AND TRUNC (s.cut_off_date) =
                                                        TRUNC (g_cut_off_date)))
/* not required
-- Ensuring that New Hire Elements get pulled just once
and (    (cv_assignment_id is not null )
      or
    (cv_assignment_id is null and not exists (select 1
                                          from cust.ttec_arg_pay_interface_mst
                      where  person_id = eletab.person_id and trunc(cut_off_date) < trunc(g_cut_off_date))
         )
     )
*/
      ;

      v_output   VARCHAR2 (4000);
   BEGIN
      print_line ('** Extract for Employee New Element Entries Section(4) **');

      FOR r_element IN c_element (iv_assignment_id, iv_include_salary)
      LOOP
         v_output :=
            delimit_text
               (iv_number_of_fields      => 10,
                iv_field1                => r_element.control_constant,
                iv_field2                => r_element.emp_attribute12,
                                       --substr(r_element.employee_number,2)--
                iv_field3                => r_element.ele_attribute1,
                iv_field4                => r_element.tipo_constant,
                iv_field5                => r_element.period_constant,
                iv_field6                => r_element.cantidad,
                iv_field7                => r_element.importe,
                iv_field8                => r_element.cost_segment2,
                iv_field9                => NULL,
                iv_field10               => NULL,
                iv_field11               => TO_CHAR
                                               (r_element.entry_effective_start_date,
                                                'DD/MM/RRRR'
                                               ),
                iv_field12               => r_element.element_name
               );
         print_line (v_output);

-- Ken Mod 8/24/05 Store data into temp table cust.ttec_arg_pay_interface_ele_tmp

         -- the above table is used to genernate control totals
         --INSERT INTO cust.ttec_arg_pay_interface_ele_tmp				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
         INSERT INTO apps.ttec_arg_pay_interface_ele_tmp                --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                     (emp_attribute12, ele_attribute1,
                      importe,
                      cantidad
                     )
              VALUES (r_element.emp_attribute12, r_element.ele_attribute1,
                      ROUND (TO_NUMBER (r_element.importe), 2),
                      ROUND (TO_NUMBER (r_element.cantidad), 2)
                     );
      END LOOP;                                                   -- c_element
   END;                                                -- extract_elements_new

--------------------------------------------------------------------
--                                                                --
-- Name:  extract_elements_chg      (Procedure)                   --
--                                                                --
--     Description:         Procedure called by the concurrent    --
--                            manager to extract elements         --
--                                                                --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   27-Jan-2005  Initial Creation             --
--                                                                --
--                                                                --
--------------------------------------------------------------------
   PROCEDURE extract_elements_chg (
      iv_assignment_id    IN   NUMBER,
      iv_include_salary   IN   VARCHAR2
   )
   IS
      CURSOR c_element (cv_assignment_id NUMBER, cv_include_salary VARCHAR2)
      IS
-- retrieves changes to element entries
         SELECT eletab_curr.employee_number, eletab_curr.last_name,
                eletab_curr.first_name, eletab_curr.middle_names,
                eletab_curr.element_name, eletab_curr.screen_entry_value,
                eletab_curr.entry_effective_start_date,
                eletab_curr.emp_attribute12, '002' control_constant,
                eletab_curr.ele_attribute1, 'U' tipo_constant,
                'P' period_constant, eletab_curr.cost_segment2,
                DECODE (eletab_curr.uom,
                        'M', eletab_curr.screen_entry_value
                       ) importe,
                DECODE (eletab_curr.uom,
                        'M', NULL,
                        eletab_curr.screen_entry_value
                       ) cantidad,
                eletab_past.screen_entry_value old_screen_entry_value,
                'CHANGE' new_or_change
				--START R12.2 Upgrade Remediation
           /*FROM cust.ttec_arg_pay_interface_ele eletab_curr,					-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                cust.ttec_arg_pay_interface_ele eletab_past*/                   
		   FROM apps.ttec_arg_pay_interface_ele eletab_curr,					--  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                apps.ttec_arg_pay_interface_ele eletab_past	
				--END R12.2.10 Upgrade remediation		
          WHERE eletab_curr.assignment_id =
                             NVL (cv_assignment_id, eletab_curr.assignment_id)
            AND eletab_curr.input_value_name IN
                   ('D�', 'Dias''Horas', 'Plan Days', 'Unidades', 'Pay Value')
            AND eletab_curr.person_id = eletab_past.person_id
            AND eletab_curr.element_type_id = eletab_past.element_type_id
            AND eletab_curr.input_value_id = eletab_past.input_value_id
            AND TRUNC (eletab_curr.cut_off_date) = TRUNC (g_cut_off_date)
            AND (   (    NVL (eletab_curr.creator_type, 'XX') != 'SP'
                     AND iv_include_salary = 'N'
                    )
                 OR (iv_include_salary = 'Y')
                )
            AND TRUNC (eletab_past.cut_off_date) =
                   (SELECT MAX (TRUNC (cut_off_date))
                      --FROM cust.ttec_arg_pay_interface_ele				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                      FROM apps.ttec_arg_pay_interface_ele                  --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                     WHERE person_id = eletab_curr.person_id
                       AND TRUNC (cut_off_date) < TRUNC (g_cut_off_date))
            AND (   eletab_curr.screen_entry_value !=
                                                eletab_past.screen_entry_value
                 OR eletab_curr.ele_attribute1 != eletab_past.ele_attribute1
                )
--added on 03-jun-2005
            AND eletab_curr.input_value_id NOT IN (
                   SELECT DISTINCT m.input_value_id
                              --FROM cust.ttec_arg_pay_interface_ele m				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                              FROM apps.ttec_arg_pay_interface_ele m                --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                             WHERE m.input_value_name = 'Horas'
                               AND TRUNC (m.cut_off_date) =
                                                        TRUNC (g_cut_off_date)
                               AND EXISTS (
                                      SELECT 'x'
                                        --FROM cust.ttec_arg_pay_interface_ele s			-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                                        FROM apps.ttec_arg_pay_interface_ele s              --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                                       WHERE s.element_entry_id =
                                                            m.element_entry_id
-- Ken mod 6/20/05 added Dias

                                         -- and s.input_value_name='D�'
                                         AND s.input_value_name IN
                                                               ('D�', 'Dias')
-- Ken mod 6/20/05
                                         AND TRUNC (s.cut_off_date) =
                                                        TRUNC (g_cut_off_date)));

      v_output   VARCHAR2 (4000);
   BEGIN
      print_line
              ('** Extract for Employee Change Element Entries Section(4) **');

      FOR r_element IN c_element (iv_assignment_id, iv_include_salary)
      LOOP
         v_output :=
            delimit_text
               (iv_number_of_fields      => 10,
                iv_field1                => r_element.control_constant,
                iv_field2                => r_element.emp_attribute12,
                                       --substr(r_element.employee_number,2)--
                iv_field3                => r_element.ele_attribute1,
                iv_field4                => r_element.tipo_constant,
                iv_field5                => r_element.period_constant,
                iv_field6                => r_element.cantidad,
                iv_field7                => r_element.importe,
                iv_field8                => r_element.cost_segment2,
                iv_field9                => NULL,
                iv_field10               => NULL,
                iv_field11               => TO_CHAR
                                               (r_element.entry_effective_start_date,
                                                'DD/MM/RRRR'
                                               ),
                iv_field12               => r_element.element_name
               );
         print_line (v_output);

-- Ken Mod 8/24/05 Store data into temp table cust.ttec_arg_pay_interface_ele_tmp

         -- the above table is used to genernate control totals
         --INSERT INTO cust.ttec_arg_pay_interface_ele_tmp				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
         INSERT INTO apps.ttec_arg_pay_interface_ele_tmp                --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                     (emp_attribute12, ele_attribute1,
                      importe,
                      cantidad
                     )
              VALUES (r_element.emp_attribute12, r_element.ele_attribute1,
                      ROUND (TO_NUMBER (r_element.importe), 2),
                      ROUND (TO_NUMBER (r_element.cantidad), 2)
                     );
      END LOOP;                                                   -- c_element
   END;                                                -- extract_elements_chg

--------------------------------------------------------------------
--                                                                --
-- Name:  extract_elements_ctl_tot      (Procedure)               --
--                                                                --
--     Description:     To product control totals from            --
--                     table cust.ttec_arg_pay_interface_ele_tmp  --
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
         SELECT   ele_attribute1, SUM (importe) s_importe,
                  SUM (cantidad) s_cantidad
             --FROM cust.ttec_arg_pay_interface_ele_tmp				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
             FROM apps.ttec_arg_pay_interface_ele_tmp               --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
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
                     '##### Output format --> Pay_code,Importe,Cantidad #####'
                    );

      FOR r_elements_ctl_tot IN t_elements_ctl_tot
      LOOP
         v_output :=
            delimit_text (iv_number_of_fields      => 3,
                          iv_field1                => r_elements_ctl_tot.ele_attribute1,
                          iv_field2                => ROUND
                                                         (r_elements_ctl_tot.s_importe,
                                                          2
                                                         ),
                          iv_field3                => ROUND
                                                         (r_elements_ctl_tot.s_cantidad,
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
-- Name:  insert_interface_mst               (Procedure)          --
--                                                                --
--     Description:         Procedure called by the other         --
--                            procedures to insert                --
--                            table ttec_arg_pay_interface_mst     --
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
   PROCEDURE insert_interface_mst (
     -- ir_interface_mst   cust.ttec_arg_pay_interface_mst%ROWTYPE				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
      ir_interface_mst   apps.ttec_arg_pay_interface_mst%ROWTYPE                --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
   )
   IS
   BEGIN
      --INSERT INTO cust.ttec_arg_pay_interface_mst				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
      INSERT INTO apps.ttec_arg_pay_interface_mst               --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                  (payroll_id,
                   payroll_name,
                   pay_period_id,
                   cut_off_date,
                   person_id,
                   person_creation_date,
                   person_update_date,
                   assignment_id,
                   assignment_creation_date,
                   assignment_update_date,
--    ,
                   attribute12, last_name,
                   first_name,
                   middle_names,
                   address_line1,
                   address_line2,
                   address_line3,
                   add_information14,
                   add_information16,
                   region_1, postal_code,
                   phone_number,
                   date_of_birth,
                   town_of_birth,
                   nationality,
                   marital_status, sex,
                   attribute6,
                   national_identifier,
                   attribute7, start_date,
                   ass_attribute10,
                   fec_accid,
                   actual_termination_date,
                   leaving_reason,
                   nro_tarj,
                   ass_attribute7,
                   cost_segment3,
                   cost_segment2,
                   job_segment1,
                   org_payment_method_name,
                   lug_pago_constant,
                   pea_segment4,
                   ass_attribute11,
                   pei_attribute1,
                   ass_attribute9,
                   ass_attribute12,
                   sijp_constant,
                   contract_type,
                   contract_end_date,
                   cuit_flag,
                   pea_segment1,
                   pea_segment2,
                   pea_segment3,
                   ass_attribute8,
                   caraserv_constant,
--
                   salary,
                   salary_change_date,
                   salary_change_reason,
                   person_type_id,
                   period_of_service_id,
                   system_person_type,
                   user_person_type,
                   per_system_status,
                   creation_date,
                   last_extract_date,
                   last_extract_file_type
                  )
           VALUES (ir_interface_mst.payroll_id,
                   ir_interface_mst.payroll_name,
                   ir_interface_mst.pay_period_id,
                   ir_interface_mst.cut_off_date,
                   ir_interface_mst.person_id,
                   ir_interface_mst.person_creation_date,
                   ir_interface_mst.person_update_date,
                   ir_interface_mst.assignment_id,
                   ir_interface_mst.assignment_creation_date,
                   ir_interface_mst.assignment_update_date,
                   ir_interface_mst.attribute12, ir_interface_mst.last_name,
                   ir_interface_mst.first_name,
                   ir_interface_mst.middle_names,
                   ir_interface_mst.address_line1,
                   ir_interface_mst.address_line2,
                   ir_interface_mst.address_line3,
                   ir_interface_mst.add_information14,
                   ir_interface_mst.add_information16,
                   ir_interface_mst.region_1, ir_interface_mst.postal_code,
                   ir_interface_mst.phone_number,
                   ir_interface_mst.date_of_birth,
                   ir_interface_mst.town_of_birth,
                   ir_interface_mst.nationality,
                   ir_interface_mst.marital_status, ir_interface_mst.sex,
                   ir_interface_mst.attribute6,
                   ir_interface_mst.national_identifier,
                   ir_interface_mst.attribute7, ir_interface_mst.start_date,
                   ir_interface_mst.ass_attribute10,
                   ir_interface_mst.fec_accid,
                   ir_interface_mst.actual_termination_date,
                   ir_interface_mst.leaving_reason,
                   ir_interface_mst.nro_tarj,
                   ir_interface_mst.ass_attribute7,
                   ir_interface_mst.cost_segment3,
                   ir_interface_mst.cost_segment2,
                   ir_interface_mst.job_segment1,
                   ir_interface_mst.org_payment_method_name,
                   ir_interface_mst.lug_pago_constant,
                   ir_interface_mst.pea_segment4,
                   ir_interface_mst.ass_attribute11,
                   ir_interface_mst.pei_attribute1,
                   ir_interface_mst.ass_attribute9,
                   ir_interface_mst.ass_attribute12,
                   ir_interface_mst.sijp_constant,
                   ir_interface_mst.contract_type,
                   ir_interface_mst.contract_end_date,
                   ir_interface_mst.cuit_flag,
                   ir_interface_mst.pea_segment1,
                   ir_interface_mst.pea_segment2,
                   ir_interface_mst.pea_segment3,
                   ir_interface_mst.ass_attribute8,
                   ir_interface_mst.caraserv_constant,
--
                   ir_interface_mst.salary,
                   ir_interface_mst.salary_change_date,
                   ir_interface_mst.salary_change_reason,
                   ir_interface_mst.person_type_id,
                   ir_interface_mst.period_of_service_id,
                   ir_interface_mst.system_person_type,
                   ir_interface_mst.user_person_type,
                   ir_interface_mst.per_system_status,
                   ir_interface_mst.creation_date,
                   ir_interface_mst.last_extract_date,
                   ir_interface_mst.last_extract_file_type
                  );
   END;                                      -- procedure insert_interface_mst

--------------------------------------------------------------------
--                                                                --
-- Name:  insert_interface_dep               (Procedure)          --
--                                                                --
--     Description:         Procedure called by the other         --
--                            procedures to insert                --
--                            table ttec_arg_pay_interface_dep    --
--                                                                --
--                                                                --
--     Change History                                             --
--                                                                --
--     Changed By        Date        Reason for Change            --
--     ----------        ----        -----------------            --
--     Vijay Mayadam   20-Jan-2005  Initial Creation             --
--                                                                --
--                                                                --
--------------------------------------------------------------------
   PROCEDURE insert_interface_dep (
      --ir_interface_dep   cust.ttec_arg_pay_interface_dep%ROWTYPE				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
      ir_interface_dep   apps.ttec_arg_pay_interface_dep%ROWTYPE                --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
   )
   IS
   BEGIN
      --INSERT INTO cust.ttec_arg_pay_interface_dep					-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
      INSERT INTO apps.ttec_arg_pay_interface_dep                   --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                  (contact_relationship_id,
                   cut_off_date,
                   pay_period_id,
                   emp_person_id,
                   emp_attribute12,
                   emp_creation_date,
                   contact_person_id,
                   cont_creation_date,
                   relationship,
                   relationship_meaning,
                   last_name, first_name,
                   middle_names,
                   date_of_birth,
                   document_type,
                   document_number,
                   scholastic_info,
                   relationship_date_from,
                   relationship_date_to,
                   scholastic_date_from,
                   scholastic_date_to,
                   active_info,
                   generates_social, sex,
                   cuil_number,
                   creation_date,
                   last_extract_date,
                   last_extract_file_type
                  )
           VALUES (ir_interface_dep.contact_relationship_id,
                   ir_interface_dep.cut_off_date,
                   ir_interface_dep.pay_period_id,
                   ir_interface_dep.emp_person_id,
                   ir_interface_dep.emp_attribute12,
                   ir_interface_dep.emp_creation_date,
                   ir_interface_dep.contact_person_id,
                   ir_interface_dep.cont_creation_date,
                   ir_interface_dep.relationship,
                   ir_interface_dep.relationship_meaning,
                   ir_interface_dep.last_name, ir_interface_dep.first_name,
                   ir_interface_dep.middle_names,
                   ir_interface_dep.date_of_birth,
                   ir_interface_dep.document_type,
                   ir_interface_dep.document_number,
                   ir_interface_dep.scholastic_info,
                   ir_interface_dep.relationship_date_from,
                   ir_interface_dep.relationship_date_to,
                   ir_interface_dep.scholastic_date_from,
                   ir_interface_dep.scholastic_date_to,
                   ir_interface_dep.active_info,
                   ir_interface_dep.generates_social, ir_interface_dep.sex,
                   ir_interface_dep.cuil_number,
                   ir_interface_dep.creation_date,
                   ir_interface_dep.last_extract_date,
                   ir_interface_dep.last_extract_file_type
                  );
   END;                                      -- procedure insert_interface_dep

--------------------------------------------------------------------
--                                                                --
-- Name:  insert_interface_ele               (Procedure)          --
--                                                                --
--     Description:         Procedure called by the other         --
--                            procedures to insert                --
--                            table ttec_arg_pay_interface_ele    --
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
      --ir_interface_ele   cust.ttec_arg_pay_interface_ele%ROWTYPE			-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
      ir_interface_ele   apps.ttec_arg_pay_interface_ele%ROWTYPE            --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
   )
   IS
   BEGIN
      --INSERT INTO cust.ttec_arg_pay_interface_ele					-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
      INSERT INTO apps.ttec_arg_pay_interface_ele                   --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                  (payroll_id,
                   payroll_name,
                   pay_period_id,
                   cut_off_date,
                   person_id,
                   assignment_id,
                   last_name, first_name,
                   middle_names,
                   full_name,
                   employee_number,
                   emp_attribute12,
                   cost_segment2,
                   cost_segment3,
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
                   creation_date,
                   last_extract_date,
                   last_extract_file_type
                  )
           VALUES (ir_interface_ele.payroll_id,
                   ir_interface_ele.payroll_name,
                   ir_interface_ele.pay_period_id,
                   ir_interface_ele.cut_off_date,
                   ir_interface_ele.person_id,
                   ir_interface_ele.assignment_id,
                   ir_interface_ele.last_name, ir_interface_ele.first_name,
                   ir_interface_ele.middle_names,
                   ir_interface_ele.full_name,
                   ir_interface_ele.employee_number,
                   ir_interface_ele.emp_attribute12,
                   ir_interface_ele.cost_segment2,
                   ir_interface_ele.cost_segment3,
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
                   ir_interface_ele.creation_date,
                   ir_interface_ele.last_extract_date,
                   ir_interface_ele.last_extract_file_type
                  );
   END;                                                -- insert_interface_ele

--------------------------------------------------------------------
--                                                                --
-- Name:  populate_interface_tables          (Procedure)          --
--                                                                --
--     Description:         Procedure called by the other         --
--                            procedures to load                  --
--                            table ttec_arg_pay_interface_mst     --
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
      CURSOR c_emp_data
      IS
         SELECT   /*+ index(ppf) ordered use_nl(ppt) use_nl(paf) use_nl(ppayf) use_nl(ppos) use_nl(past) use_nl(pj) use_nl(pjd) use_nl(haou) use_nl(hl)*/
                  papf.person_id, papf.creation_date person_creation_date,
                  papf.last_update_date person_update_date,
                  paaf.assignment_id,
                  paaf.creation_date assignment_creation_date,
                  paaf.last_update_date assignment_update_date,
                  ppayf.payroll_id, ppayf.payroll_name, ppt.person_type_id,
                  ppt.system_person_type, ppt.user_person_type,
                  past.per_system_status employee_status,
                  paaf.organization_id organization_id, papf.attribute12,
                  papf.last_name, papf.first_name, papf.middle_names,
                  addr.address_line1, addr.address_line2, addr.address_line3,
                  addr.add_information14, addr.add_information16,
                  addr.region_1, addr.postal_code, addr.telephone_number_1,
                  papf.date_of_birth, papf.town_of_birth, papf.nationality,
                  papf.marital_status, papf.sex, papf.attribute6,
                  papf.national_identifier, papf.attribute7,
                  paaf.ass_attribute10, paaf.ass_attribute7,
                  pjd.segment1 job_segment1, paaf.ass_attribute11,
                  paaf.ass_attribute9, paaf.ass_attribute12,
                  paaf.ass_attribute8, ppos.period_of_service_id,
                  ppos.date_start, ppos.actual_termination_date,
                  ppos.leaving_reason
             --START R12.2 Upgrade Remediation
			 /*FROM hr.per_all_people_f papf,					-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                  hr.per_person_types ppt,                      
                  hr.per_all_assignments_f paaf,
                  hr.pay_all_payrolls_f ppayf,
                  hr.per_periods_of_service ppos,
                  hr.per_assignment_status_types past,
                  hr.per_jobs pj,
                  hr.per_job_definitions pjd,
                  hr.hr_all_organization_units haou,
                  apps.per_addresses addr,
                  hr.per_person_type_usages_f pptuf*/
			 FROM apps.per_all_people_f papf,						--  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                  apps.per_person_types ppt,
                  apps.per_all_assignments_f paaf,
                  apps.pay_all_payrolls_f ppayf,
                  apps.per_periods_of_service ppos,
                  apps.per_assignment_status_types past,
                  apps.per_jobs pj,
                  apps.per_job_definitions pjd,
                  apps.hr_all_organization_units haou,
                  apps.per_addresses addr,
                  apps.per_person_type_usages_f pptuf	 
			--END R12.2.10 Upgrade remediation		
            WHERE papf.business_group_id = g_business_group_id
              AND TRUNC (g_cut_off_date) BETWEEN papf.effective_start_date
                                             AND papf.effective_end_date
              AND pptuf.person_type_id = ppt.person_type_id
              AND pptuf.person_id = papf.person_id
              AND TRUNC (g_cut_off_date) BETWEEN pptuf.effective_start_date
                                             AND pptuf.effective_end_date
              AND ppt.user_person_type IN
                     ('Employee', 'Ex-employee', 'Employee and Applicant',
                      'Ex-employee and Applicant', 'Expatriate')
                                                              -- ticket 202959
              AND ppt.business_group_id = g_business_group_id
              AND papf.business_group_id = ppt.business_group_id
              AND papf.person_id = paaf.person_id
              AND paaf.assignment_type = 'E'
              AND paaf.payroll_id = ppayf.payroll_id(+)
              AND ppayf.payroll_name(+) = 'Mensual'
              AND TRUNC (g_cut_off_date) BETWEEN ppayf.effective_start_date(+) AND ppayf.effective_end_date(+)
              AND papf.person_id = ppos.person_id
              AND ppos.period_of_service_id = paaf.period_of_service_id
              AND ppos.date_start =
                     (SELECT MAX (date_start)
                        FROM per_periods_of_service
                       WHERE person_id = papf.person_id
                         AND date_start <= TRUNC (g_cut_off_date))
              AND paaf.assignment_status_type_id =
                                                past.assignment_status_type_id
              AND paaf.job_id = pj.job_id(+)
              AND pj.job_definition_id = pjd.job_definition_id(+)
              --and    trunc(g_cut_off_date) between paaf.effective_start_date and paaf.effective_end_date--
              AND paaf.effective_start_date =
                     (SELECT MAX (effective_start_date)
                        FROM per_assignments_f
                       -- k                                  where  assignment_id = paaf.assignment_id
                      WHERE  person_id = papf.person_id          -- Mod by Ken
                         AND effective_start_date <= TRUNC (g_cut_off_date))
              AND paaf.organization_id = haou.organization_id
              AND papf.person_id = addr.person_id(+)
              AND addr.primary_flag(+) = 'Y'
         ORDER BY papf.employee_number;

      CURSOR c_dep_data
      IS
         SELECT   pcr.contact_relationship_id, emp.person_id emp_person_id,
                  emp.attribute12 emp_attribute12,
                  emp.creation_date emp_creation_date, pcr.contact_person_id,
                  pcr.creation_date cont_creation_date,
                  pcr.contact_type relationship,
                  hl.meaning relationship_meaning, cont.last_name,
                  cont.first_name, cont.middle_names, cont.date_of_birth,
                  cont.attribute6 document_type, cont.national_identifier,
                  pcr.cont_attribute1 scholastic_info,
                  pcr.date_start relationship_date_from,
                  pcr.date_end relationship_date_to,
                  NULL scholastic_date_from, NULL scholastic_date_to,
                  DECODE (pcr.cont_attribute2,
                          'A', 'VERADERO',
                          'FALSO'
                         ) active_info,
                  '0' generates_social, cont.sex, cont.attribute7 cuil_number
             --START R12.2 Upgrade Remediation							-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
			 /*FROM hr.per_all_people_f emp,                            
                  hr.per_all_people_f cont,
                  hr.per_person_types ppt,
                  hr.per_contact_relationships pcr,
                  apps.hr_lookups hl,
                  hr.per_person_type_usages_f pptuf*/
			 FROM apps.per_all_people_f emp,							--  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                  apps.per_all_people_f cont,
                  apps.per_person_types ppt,
                  apps.per_contact_relationships pcr,
                  apps.hr_lookups hl,
                  apps.per_person_type_usages_f pptuf
--END R12.2.10 Upgrade remediation				  
            WHERE emp.business_group_id = g_business_group_id
              AND TRUNC (g_cut_off_date) BETWEEN emp.effective_start_date
                                             AND emp.effective_end_date
              AND emp.person_id = pcr.person_id
              AND emp.current_employee_flag = 'Y'
              AND pcr.contact_person_id = cont.person_id
              AND TRUNC (g_cut_off_date) BETWEEN cont.effective_start_date
                                             AND cont.effective_end_date
              AND pcr.contact_type = hl.lookup_code
              AND hl.lookup_type = 'CONTACT'
              AND pptuf.person_type_id = ppt.person_type_id
              AND pptuf.person_id = emp.person_id
              AND TRUNC (g_cut_off_date) BETWEEN pptuf.effective_start_date
                                             AND pptuf.effective_end_date
              AND ppt.user_person_type IN
                     ('Employee', 'Ex-employee', 'Employee and Applicant',
                      'Ex-employee and Applicant', 'Expatriate')
              AND ppt.business_group_id = g_business_group_id
         ORDER BY emp.person_id, cont.person_id, pcr.contact_relationship_id;

      CURSOR c_ele_data
      IS
         SELECT /*+ ordered use_nl(ppf) use_Nl(paf) use_nl(ppayf) use_nl(peef) use_nl(peevf) use_nl(pelf) use_nl(petf) use_nl(pivf) use_nl(pec) */
                ppf.person_id, ppf.employee_number, ppf.last_name,
                ppf.first_name, ppf.middle_names, ppf.full_name,
                paf.assignment_id, paf.organization_id, ppayf.payroll_id,
                ppayf.payroll_name, petf.element_type_id,
                petf.processing_type, ppf.attribute12 emp_attribute12,
                petf.attribute1 ele_attribute1, petf.element_name,
                petf.description, pelf.element_link_id,
                pec.classification_name, petf.reporting_name, pivf.uom,
                hl.meaning uom_meaning, pivf.input_value_id,
                pivf.NAME input_value_name, peevf.element_entry_value_id,
                peevf.screen_entry_value, peef.element_entry_id,
                peef.creator_type,
                peef.effective_start_date entry_effective_start_date,
                peef.effective_end_date entry_effective_end_date
           FROM per_all_people_f ppf,
                per_all_assignments_f paf,
                pay_payrolls_f ppayf,
                pay_element_entries_f peef,
                pay_element_entry_values_f peevf,
                pay_element_links_f pelf,
                pay_element_types_f petf,
                pay_input_values_f pivf,
                pay_element_classifications pec,
                hr_lookups hl,
				--START R12.2 Upgrade Remediation
                /*hr.per_person_types ppt,							-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                hr.per_person_type_usages_f pptuf*/                 
				apps.per_person_types ppt,							--  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                apps.per_person_type_usages_f pptuf
				--END R12.2.10 Upgrade remediation
          WHERE ppf.business_group_id = g_business_group_id
            AND TRUNC (g_cut_off_date) BETWEEN ppf.effective_start_date
                                           AND ppf.effective_end_date
            AND ppf.person_id = paf.person_id
            AND TRUNC (g_cut_off_date) BETWEEN paf.effective_start_date
                                           AND paf.effective_end_date
            AND paf.payroll_id = ppayf.payroll_id(+)
            AND ppayf.payroll_name(+) = 'Mensual'
            AND TRUNC (g_cut_off_date) BETWEEN ppayf.effective_start_date(+) AND ppayf.effective_end_date(+)
            AND paf.assignment_id = peef.assignment_id
            AND TRUNC (g_cut_off_date) BETWEEN peef.effective_start_date
                                           AND peef.effective_end_date
            AND peef.element_entry_id = peevf.element_entry_id
            AND TRUNC (g_cut_off_date) BETWEEN peevf.effective_start_date
                                           AND peevf.effective_end_date
            AND peef.element_link_id = pelf.element_link_id
            AND TRUNC (g_cut_off_date) BETWEEN pelf.effective_start_date
                                           AND pelf.effective_end_date
            AND pelf.element_type_id = petf.element_type_id
            AND TRUNC (g_cut_off_date) BETWEEN petf.effective_start_date
                                           AND petf.effective_end_date
            AND peevf.input_value_id = pivf.input_value_id
            AND TRUNC (g_cut_off_date) BETWEEN pivf.effective_start_date
                                           AND pivf.effective_end_date
            AND peevf.screen_entry_value IS NOT NULL
            AND petf.classification_id = pec.classification_id
            AND pivf.uom = hl.lookup_code
            AND hl.lookup_type = 'UNITS'
            AND pptuf.person_type_id = ppt.person_type_id
            AND pptuf.person_id = ppf.person_id
            AND TRUNC (g_cut_off_date) BETWEEN pptuf.effective_start_date
                                           AND pptuf.effective_end_date
            AND ppt.user_person_type IN
                   ('Employee', 'Ex-employee', 'Employee and Applicant',
                    'Ex-employee and Applicant', 'Expatriate')
            AND ppt.business_group_id = g_business_group_id;

      v_salary                    NUMBER;
      v_sal_change_date           DATE;
      v_sal_change_reason         VARCHAR2 (30);
      v_pea_segment1              VARCHAR2 (150);
      v_pea_segment2              VARCHAR2 (150);
      v_pea_segment3              VARCHAR2 (150);
      v_pea_segment4              VARCHAR2 (150);
      v_org_payment_method_name   VARCHAR2 (150);
      v_cost_segment2             VARCHAR2 (150);
      v_cost_segment3             VARCHAR2 (150);
      v_pei_attribute1            VARCHAR2 (150);
      v_contract_type             VARCHAR2 (60);
      v_contract_end_date         DATE;
      v_holiday_ot                VARCHAR2 (60);
      v_classification            VARCHAR2 (30);
      r_interface_mst             cust.ttec_arg_pay_interface_mst%ROWTYPE;
      r_interface_dep             cust.ttec_arg_pay_interface_dep%ROWTYPE;
      r_interface_ele             cust.ttec_arg_pay_interface_ele%ROWTYPE;
   BEGIN
      --DELETE FROM cust.ttec_arg_pay_interface_mst del						-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
      DELETE FROM apps.ttec_arg_pay_interface_mst del                       --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
            WHERE TRUNC (del.cut_off_date) = TRUNC (g_cut_off_date);

      fnd_file.put_line (fnd_file.LOG,
                         'Begin Populate cust.ttec_arg_pay_interface_mst'
                        );

      FOR r_emp_data IN c_emp_data
      LOOP
         get_cost_allocation
                           (iv_assignment_id        => r_emp_data.assignment_id,
                            iv_organization_id      => r_emp_data.organization_id,
                            ov_cost_segment2        => v_cost_segment2,
                            ov_cost_segment3        => v_cost_segment3
                           );
         get_bank (iv_assignment_id                => r_emp_data.assignment_id,
                   ov_pea_segment1                 => v_pea_segment1,
                   ov_pea_segment2                 => v_pea_segment2,
                   ov_pea_segment3                 => v_pea_segment3,
                   ov_pea_segment4                 => v_pea_segment4,
                   ov_org_payment_method_name      => v_org_payment_method_name
                  );
         get_salary (iv_assignment_id      => r_emp_data.assignment_id,
                     ov_salary             => v_salary,
                     ov_change_date        => v_sal_change_date,
                     ov_change_reason      => v_sal_change_reason
                    );
-- Ken Mod 6/30/05 changed to pull OBRA_SOC field value from pei_information1, not pei_attribute1

         -- However, keeping variable name as it is (pei_attribute1) - modifications were in get_per_son_extra_info routine.
         get_person_extra_info (iv_person_id           => r_emp_data.person_id,
                                ov_pei_attribute1      => v_pei_attribute1
                               );
         get_contract_info (iv_person_id          => r_emp_data.person_id,
                            iv_start_date         => r_emp_data.date_start,
                            ov_contract_type      => v_contract_type,
                            ov_sijp_vig           => v_contract_end_date
                           );
         r_interface_mst.payroll_id := r_emp_data.payroll_id;
         r_interface_mst.payroll_name := r_emp_data.payroll_name;
         r_interface_mst.pay_period_id := NULL;
         r_interface_mst.cut_off_date := g_cut_off_date;
         r_interface_mst.person_id := r_emp_data.person_id;
         r_interface_mst.person_creation_date :=
                                               r_emp_data.person_creation_date;
         r_interface_mst.person_update_date := r_emp_data.person_update_date;
         r_interface_mst.assignment_id := r_emp_data.assignment_id;
         r_interface_mst.assignment_creation_date :=
                                           r_emp_data.assignment_creation_date;
         r_interface_mst.assignment_update_date :=
                                             r_emp_data.assignment_update_date;
         r_interface_mst.attribute12 := r_emp_data.attribute12;
         r_interface_mst.last_name := r_emp_data.last_name;
         r_interface_mst.first_name := r_emp_data.first_name;
         r_interface_mst.middle_names := r_emp_data.middle_names;
         r_interface_mst.address_line1 := r_emp_data.address_line1;
         r_interface_mst.address_line2 := r_emp_data.address_line2;
         r_interface_mst.address_line3 := r_emp_data.address_line3;
         r_interface_mst.add_information14 := r_emp_data.add_information14;
         r_interface_mst.add_information16 := r_emp_data.add_information16;
         r_interface_mst.region_1 := r_emp_data.region_1;
         r_interface_mst.postal_code := r_emp_data.postal_code;
         r_interface_mst.phone_number := r_emp_data.telephone_number_1;
         r_interface_mst.date_of_birth := r_emp_data.date_of_birth;
         r_interface_mst.town_of_birth := r_emp_data.town_of_birth;
         r_interface_mst.nationality := r_emp_data.nationality;
         r_interface_mst.marital_status := r_emp_data.marital_status;
         r_interface_mst.sex := r_emp_data.sex;
         r_interface_mst.attribute6 := r_emp_data.attribute6;
         r_interface_mst.national_identifier := r_emp_data.national_identifier;
         r_interface_mst.attribute7 := r_emp_data.attribute7;
         r_interface_mst.start_date := r_emp_data.date_start;
         r_interface_mst.ass_attribute10 := r_emp_data.ass_attribute10;
         r_interface_mst.fec_accid := NULL;
         r_interface_mst.actual_termination_date :=
                                            r_emp_data.actual_termination_date;
         r_interface_mst.leaving_reason := r_emp_data.leaving_reason;
         r_interface_mst.nro_tarj := NULL;
         r_interface_mst.ass_attribute7 := r_emp_data.ass_attribute7;
         r_interface_mst.cost_segment3 := v_cost_segment3;
         r_interface_mst.cost_segment2 := v_cost_segment2;
         r_interface_mst.job_segment1 := r_emp_data.job_segment1;
         r_interface_mst.org_payment_method_name := v_org_payment_method_name;
         r_interface_mst.lug_pago_constant := 1;
         r_interface_mst.pea_segment4 := v_pea_segment4;
         r_interface_mst.ass_attribute11 := r_emp_data.ass_attribute11;
         r_interface_mst.pei_attribute1 := v_pei_attribute1;
         r_interface_mst.ass_attribute9 := r_emp_data.ass_attribute9;
         r_interface_mst.ass_attribute12 := r_emp_data.ass_attribute12;
         r_interface_mst.sijp_constant := 1;
         r_interface_mst.contract_type := v_contract_type;
         r_interface_mst.contract_end_date := v_contract_end_date;
         r_interface_mst.cuit_flag := 'FALSO';
         r_interface_mst.pea_segment1 := v_pea_segment1;
         r_interface_mst.pea_segment2 := v_pea_segment2;
         r_interface_mst.pea_segment3 := v_pea_segment3;
         r_interface_mst.ass_attribute8 := r_emp_data.ass_attribute8;
         r_interface_mst.caraserv_constant := 0;
         r_interface_mst.salary := v_salary;
         r_interface_mst.salary_change_date := v_sal_change_date;
         r_interface_mst.salary_change_reason := v_sal_change_reason;
         r_interface_mst.person_type_id := r_emp_data.person_type_id;
         r_interface_mst.period_of_service_id :=
                                               r_emp_data.period_of_service_id;
         r_interface_mst.system_person_type := r_emp_data.system_person_type;
         r_interface_mst.user_person_type := r_emp_data.user_person_type;
         r_interface_mst.per_system_status := r_emp_data.employee_status;
         r_interface_mst.creation_date := g_sysdate;
         r_interface_mst.last_extract_date := TO_DATE (NULL);
         r_interface_mst.last_extract_file_type := 'PAYROLL RUN';
         insert_interface_mst (ir_interface_mst => r_interface_mst);
      END LOOP;                                                  -- c_emp_data

      fnd_file.put_line (fnd_file.LOG,
                         'End Populate cust.ttec_arg_pay_interface_mst'
                        );

      --DELETE FROM cust.ttec_arg_pay_interface_dep del2						-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
      DELETE FROM apps.ttec_arg_pay_interface_dep del2                          --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
            WHERE TRUNC (del2.cut_off_date) = TRUNC (g_cut_off_date);

      fnd_file.put_line (fnd_file.LOG,
                         'Begin Populate cust.ttec_arg_pay_interface_dep'
                        );

      FOR r_dep_data IN c_dep_data
      LOOP
         r_interface_dep.contact_relationship_id :=
                                           r_dep_data.contact_relationship_id;
         r_interface_dep.pay_period_id := NULL;
         r_interface_dep.cut_off_date := g_cut_off_date;
         r_interface_dep.emp_person_id := r_dep_data.emp_person_id;
         r_interface_dep.emp_attribute12 := r_dep_data.emp_attribute12;
         r_interface_dep.emp_creation_date := r_dep_data.emp_creation_date;
         r_interface_dep.contact_person_id := r_dep_data.contact_person_id;
         r_interface_dep.cont_creation_date := r_dep_data.cont_creation_date;
         r_interface_dep.relationship := r_dep_data.relationship;
         r_interface_dep.relationship_meaning :=
                                              r_dep_data.relationship_meaning;
         r_interface_dep.last_name := r_dep_data.last_name;
         r_interface_dep.first_name := r_dep_data.first_name;
         r_interface_dep.middle_names := r_dep_data.middle_names;
         r_interface_dep.date_of_birth := r_dep_data.date_of_birth;
         r_interface_dep.document_type := r_dep_data.document_type;
         r_interface_dep.document_number := r_dep_data.national_identifier;
         r_interface_dep.scholastic_info := r_dep_data.scholastic_info;
         r_interface_dep.relationship_date_from :=
                                            r_dep_data.relationship_date_from;
         r_interface_dep.relationship_date_to :=
                                              r_dep_data.relationship_date_to;
         r_interface_dep.scholastic_date_from :=
                                              r_dep_data.scholastic_date_from;
         r_interface_dep.scholastic_date_to := r_dep_data.scholastic_date_to;
         r_interface_dep.active_info := r_dep_data.active_info;
         r_interface_dep.generates_social := r_dep_data.generates_social;
         r_interface_dep.sex := r_dep_data.sex;
         r_interface_dep.cuil_number := r_dep_data.cuil_number;
         r_interface_dep.creation_date := g_sysdate;
         r_interface_dep.last_extract_date := TO_DATE (NULL);
         r_interface_dep.last_extract_file_type := 'PAYROLL RUN';
         insert_interface_dep (ir_interface_dep => r_interface_dep);
      END LOOP;                                                  -- c_dep_data

      fnd_file.put_line (fnd_file.LOG,
                         'End Populate cust.ttec_arg_pay_interface_dep'
                        );

      --DELETE FROM cust.ttec_arg_pay_interface_ele ele					-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
      DELETE FROM apps.ttec_arg_pay_interface_ele ele                   --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
            WHERE TRUNC (ele.cut_off_date) = TRUNC (g_cut_off_date);

-- Ken Mod 8/24/05 delete temp table cust.ttec_arg_pay_interface_ele_tmp entries.

      -- the above table is used to generate control totals in log file
      --DELETE FROM cust.ttec_arg_pay_interface_ele_tmp;				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
      DELETE FROM apps.ttec_arg_pay_interface_ele_tmp;                  --  code Added by IXPRAVEEN-ARGANO,   10-May-2023

      fnd_file.put_line (fnd_file.LOG,
                         'Begin Populate cust.ttec_arg_pay_interface_ele'
                        );

      FOR r_ele_data IN c_ele_data
      LOOP
         get_cost_allocation
                           (iv_assignment_id        => r_ele_data.assignment_id,
                            iv_organization_id      => r_ele_data.organization_id,
                            ov_cost_segment2        => v_cost_segment2,
                            ov_cost_segment3        => v_cost_segment3
                           );
/*-- not required--

    if upper(r_ele_data.element_name) like '%LOAN%' then

      v_classification := 'LOAN';

    elsif r_ele_data.classification_name in ('Earnings','Imputed Earnings', 'Non-payroll Payments','Supplemental Earnings', 'Tax Credit') then

      v_classification := 'EARNINGS';

    elsif

      r_ele_data.classification_name in ('Involuntary Deductions', 'Pre-Tax Deductions','Tax Deductions', 'Taxable Benefits','Voluntary Deductions') then

      v_classification := 'DEDUCTIONS';

    end if;

*/
         r_interface_ele.payroll_id := r_ele_data.payroll_id;
         r_interface_ele.payroll_name := r_ele_data.payroll_name;
         r_interface_ele.pay_period_id := NULL;
         r_interface_ele.cut_off_date := g_cut_off_date;
         r_interface_ele.person_id := r_ele_data.person_id;
         r_interface_ele.assignment_id := r_ele_data.assignment_id;
         r_interface_ele.last_name := r_ele_data.last_name;
         r_interface_ele.first_name := r_ele_data.first_name;
         r_interface_ele.middle_names := r_ele_data.middle_names;
         r_interface_ele.full_name := r_ele_data.full_name;
         r_interface_ele.employee_number := r_ele_data.employee_number;
         r_interface_ele.emp_attribute12 := r_ele_data.emp_attribute12;
         r_interface_ele.cost_segment2 := v_cost_segment2;
         r_interface_ele.cost_segment3 := v_cost_segment3;
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
         r_interface_ele.screen_entry_value := r_ele_data.screen_entry_value;
         r_interface_ele.entry_effective_start_date :=
                                         r_ele_data.entry_effective_start_date;
         r_interface_ele.entry_effective_end_date :=
                                           r_ele_data.entry_effective_end_date;
         r_interface_ele.creation_date := g_sysdate;
         r_interface_ele.last_extract_date := TO_DATE (NULL);
         r_interface_ele.last_extract_file_type := 'PAYROLL RUN';
         insert_interface_ele (ir_interface_ele => r_interface_ele);
      END LOOP;                                                  -- c_ele_data

      fnd_file.put_line (fnd_file.LOG,
                         'End Populate cust.ttec_arg_pay_interface_ele'
                        );
      COMMIT;
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

--------------------------------------------------------------------
--                                                                --
-- Name:  extract_arg_emps             (Procedure)                --
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
   PROCEDURE extract_arg_emps (
      ov_errbuf         OUT      VARCHAR2,
      ov_retcode        OUT      NUMBER,
      iv_cut_off_date   IN       VARCHAR2
   )
   IS
      l_date             DATE;
      l_valid_date       BOOLEAN;
      l_e_invalid_date   EXCEPTION;
      l_cut_off_date     DATE;
   BEGIN
      --  Added by C.Chan on 28-DEC-2005 for TT#425307
      DBMS_SESSION.set_nls ('nls_date_format', '''dd/mm/rrrr''');
      validate_date (iv_cut_off_date, l_date, l_valid_date);

      IF NOT l_valid_date
      THEN
         RAISE l_e_invalid_date;
      ELSE
         l_cut_off_date := l_date;
      END IF;

      set_business_group_id (iv_business_group => 'TeleTech Holdings - ARG');
      fnd_file.put_line (fnd_file.LOG,
                            'Business Group ID = '
                         || TO_CHAR (g_business_group_id)
                        );

--  set_payroll_dates (iv_pay_period_id          => iv_pay_period);--not required--
      IF     l_cut_off_date IS NOT NULL
         AND TRUNC (l_cut_off_date) <= TRUNC (SYSDATE)
      THEN
         g_cut_off_date := TO_DATE (l_cut_off_date, 'DD-MM-RRRR');
                         -- to_date(iv_cut_off_date,'YYYY/MM/DD HH24:MI:SS');
      ELSE
         RAISE g_e_future_date;
      END IF;

      fnd_file.put_line (fnd_file.LOG,
                            'Cut Off Date      = '
                         || TO_CHAR (g_cut_off_date, 'MM/DD/YYYY')
                        );
      fnd_file.put_line (fnd_file.LOG, 'Start populate interface tables');
      populate_interface_tables;
      fnd_file.put_line (fnd_file.LOG, 'Ended populate interface tables');
      fnd_file.put_line (fnd_file.LOG, 'Start Extracting employee changes');
      extract_emp_changes;
      fnd_file.put_line (fnd_file.LOG, 'Ended Extracting employee changes');
      fnd_file.put_line (fnd_file.LOG, 'Start Extracting salary changes');
      extract_salary_changes;
      fnd_file.put_line (fnd_file.LOG, 'Ended Extracting salary changes');
      fnd_file.put_line (fnd_file.LOG, 'Start Extracting dependent changes');
      extract_dep_changes;
      fnd_file.put_line (fnd_file.LOG, 'Ended Extracting dependent changes');
      fnd_file.put_line (fnd_file.LOG, 'Start Extracting elements new');
      extract_elements_new (iv_assignment_id       => NULL,
                            iv_include_salary      => 'N');
      fnd_file.put_line (fnd_file.LOG, 'Ended Extracting elements new');
      fnd_file.put_line (fnd_file.LOG, 'Start Extracting elements change');
      extract_elements_chg (iv_assignment_id       => NULL,
                            iv_include_salary      => 'N');
      fnd_file.put_line (fnd_file.LOG, 'Ended Extracting elements change');
-- Ken Mod 8/24/05 added to pruduct pay code control totals in current log file.
      fnd_file.put_line (fnd_file.LOG, 'Start extract_elements_ctl_tot');
      extract_elements_ctl_tot;
      fnd_file.put_line (fnd_file.LOG, 'Ended extract_elements_ctl_tot');
      ov_retcode := g_retcode;
      ov_errbuf := g_errbuf;
   EXCEPTION
      WHEN l_e_invalid_date
      THEN
         fnd_file.put_line
                       (fnd_file.LOG,
                        'Process Aborted - Invalid Format of  "Cut_off_date"'
                       );
         ov_retcode := g_retcode;
         ov_errbuf := g_errbuf;
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
   END;                                               -- procedure extract_arg
END;                           -- Package Body apps.ttec_arg_pay_interface_pkg
/
show errors;
/