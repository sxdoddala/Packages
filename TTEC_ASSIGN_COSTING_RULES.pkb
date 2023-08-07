create or replace PACKAGE BODY      ttec_assign_costing_rules
AS
/* $Header TTEC_ASSIGN_COSTING_RULES.pkb 1.2 2010/04/27 mdodge ship $ */

   /*== START =====================================================================*\
      Author: Michelle Dodge
        Date: May 28, 2009
   Call From:
        Desc: This is a generic package intended to be used by any and all customs
              to build the Assignment Costing using the same set of business
              rules.

     Modification History:

    Version    Date     Author     Description (Include Ticket#)
    -------  --------  ----------  ---------------------------------------------------
        1.0  05/28/09  MDodge      Initial version
        1.1  11/03/09  Kgonguntla  Added more logic into the package to determine
                                   and generate costing information - WO 637755
        1,2  04/27/10  MDodge      Corrected Date Tracked record selections to use
                                   TRUNC(SYSDATE), instead of SYSDATE, to avoid losing matches.
        1.3  05/21/10  Kgonuguntla Added logic to get costing string for terminated employee.
                                   changed as part of rewrite of custom costing TTSD 124797, TTSD 328917
        1.4  09/30/10  Kgonuguntla Changed logic on ttec_validate_date function to pick employees
                                   who is been terminated on the same day
        1.5  12/06/10  Kgonuguntla TTSD 453327- Fixed the Custom Costing issue erroring out for terminated employees and rehire employee
                                                during payperiod.
        1.6  15/06/10  Kgonuguntla Fixed the custom costing issue erroing out for future dates Hires and Rehires TTSD 476057
                                   This fix was raised part of ARG payroll interfaces.
		1.0	09-May-2023 IXPRAVEEN(ARGANO)   		R12.2 Upgrade Remediation						   
   \*== END =======================================================================*/
   g_fail_msg              VARCHAR2 (240);
   -- Costing Source Constants
   g_cost_override_src     VARCHAR2 (25)  := 'Costing Override';
   g_asgn_loc_src          VARCHAR2 (25)  := 'Assignment';
   g_asgn_org_dept_src     VARCHAR2 (25)  := 'Assignment';
   g_asgn_org_client_src   VARCHAR2 (25)  := 'ProjectClient';
   g_acct_client_src       VARCHAR2 (25)  := 'Client Related';
   g_acct_non_client_src   VARCHAR2 (25)  := 'Non-Client Related';

   --Version 1.3 <Start>
   -- Function to generate last active date for terminated employee & active employee. Its part of rewrite of custom costing
   -- And Kronos Outbound interface
   FUNCTION ttec_valid_date (p_assign_id IN NUMBER)
      RETURN DATE
   IS
      v_valid_date   DATE DEFAULT SYSDATE;
   BEGIN
      SELECT NVL (ppos.actual_termination_date, GREATEST (SYSDATE, ppos.date_start))        -- Version 1.6
        INTO v_valid_date
        --FROM hr.per_all_assignments_f paa, hr.per_periods_of_service ppos			-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
		FROM apps.per_all_assignments_f paa, apps.per_periods_of_service ppos		--  code Added by IXPRAVEEN-ARGANO,09-May-2023
       WHERE paa.person_id = ppos.person_id
         AND paa.period_of_service_id = ppos.period_of_service_id
         AND paa.primary_flag = 'Y'
         AND TRUNC (NVL (ppos.actual_termination_date, GREATEST (SYSDATE, ppos.date_start)))        -- Version 1.6
                                                                                           -- version 1.4
                BETWEEN paa.effective_start_date
                    AND paa.effective_end_date
         AND TRUNC (NVL (ppos.actual_termination_date, GREATEST (SYSDATE, ppos.date_start))) =                  -- Version 1.6
                (SELECT MAX (TRUNC (NVL (actual_termination_date, GREATEST (SYSDATE, ppos1.date_start))))       -- Version 1.6
                                                                                           -- version 1.4
                   FROM per_periods_of_service ppos1, per_all_assignments_f paaf1          -- Version 1.5
                  WHERE paaf1.assignment_id = paa.assignment_id                            -- Version 1.5
                    AND paaf1.period_of_service_id = ppos1.period_of_service_id)           -- Version 1.5
         AND paa.assignment_id = p_assign_id;

      /*IF TRUNC (v_valid_date) > TRUNC (SYSDATE)           --Version 1.6
      THEN
         v_valid_date := SYSDATE;
      END IF;*/

      RETURN (TRUNC (v_valid_date));
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN (TRUNC (v_valid_date));
   END ttec_valid_date;

    --Version 1.3 <End>
-- PROCEDURE get_location
--
-- Description: This INTERNAL procedure will take an input Cost Record (already
--              populated with the Assignment Costing Allocation info and determine
--              if it should update the Location Segment based on current value and
--              TeleTech Assignment Costing Rules.  It will update the record
--              as necessary and return it to the colling process.
--
-- Arguments:
--      In: p_asgn_cost_rec - Assignment Costing Record
--     Out: p_status        - TRUE if successful completion
--                          - FALSE if error encountered
--
   PROCEDURE get_location (
      p_asgn_cost_rec   IN OUT NOCOPY   asgncostrecord,
      p_status          OUT             BOOLEAN,
      p_return_msg      OUT             VARCHAR2,
      p_module          OUT             VARCHAR2,
      p_reference       OUT             VARCHAR2
   )
   IS
   --START R12.2 Upgrade Remediation
      /*v_module     cust.ttec_error_handling.module_name%TYPE   := 'get_location';		-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
      v_location   gl.gl_code_combinations.segment1%TYPE;*/
	  v_module     apps.ttec_error_handling.module_name%TYPE   := 'get_location';		--  code Added by IXPRAVEEN-ARGANO,09-May-2023
      v_location   apps.gl_code_combinations.segment1%TYPE;
	  --END R12.2.10 Upgrade remediation
      v_loc_att    fnd_flex_values.attribute14%TYPE;
      e_loc_att    EXCEPTION;
   BEGIN
      -- Only look up the Assignment Location if the Costing Location is not
      -- already populated as it overrides.
      IF p_asgn_cost_rec.LOCATION IS NULL
      THEN
         SELECT hrl.attribute2
           INTO v_location
           --FROM hr.per_all_assignments_f paa, hr.hr_locations_all hrl			-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
		   FROM apps.per_all_assignments_f paa, apps.hr_locations_all hrl		--  code Added by IXPRAVEEN-ARGANO,09-May-2023
          WHERE paa.assignment_id = p_asgn_cost_rec.assignment_id
            AND g_valid_date BETWEEN paa.effective_start_date                                      -- 1.3
                                                             AND paa.effective_end_date
            AND paa.location_id = hrl.location_id;

         p_asgn_cost_rec.LOCATION := v_location;
         p_asgn_cost_rec.location_src := g_asgn_loc_src;
      END IF;

      -- Revision 1.1 <Start>
      BEGIN
         SELECT   v.attribute14
             INTO v_loc_att
             FROM fnd_flex_values v, fnd_flex_value_sets s, fnd_flex_values_tl t
            WHERE flex_value_set_name LIKE 'TELETECH_LOCATION'
              AND s.flex_value_set_id = v.flex_value_set_id
              AND t.flex_value_id = v.flex_value_id
              AND v.flex_value = p_asgn_cost_rec.LOCATION
              AND t.LANGUAGE = 'US'
         ORDER BY v.flex_value;

         p_asgn_cost_rec.location_att := v_loc_att;
      EXCEPTION
         WHEN OTHERS
         THEN
            RAISE e_loc_att;
      END;

      p_status := TRUE;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         p_asgn_cost_rec.LOCATION := NULL;
         p_asgn_cost_rec.location_src := g_asgn_loc_src;
      WHEN e_loc_att
      THEN
         g_fail_msg := 'Either the LOC value or attribute on the value not exists - TELETECH_LOCATION';
         ttec_error_logging.process_error (application_code      => g_application_code,
                                           INTERFACE             => g_interface,
                                           program_name          => g_package,
                                           module_name           => v_module,
                                           status                => g_status_warning,
                                           ERROR_CODE            => SQLCODE,
                                           error_message         => g_fail_msg,
                                           label1                => 'Assignment ID',
                                           reference1            => p_asgn_cost_rec.assignment_id,
                                           label2                => 'Location attribute',
                                           reference2            => p_asgn_cost_rec.LOCATION
                                          );
         p_return_msg := SUBSTR (g_fail_msg, 1, 240);
         p_module := v_module;
         p_reference :=
               p_asgn_cost_rec.LOCATION
            || '-'
            || p_asgn_cost_rec.department
            || '-'
            || p_asgn_cost_rec.client
            || '-'
            || p_asgn_cost_rec.ACCOUNT;
         p_status := FALSE;
      -- Revision 1.1 <End>
      WHEN OTHERS
      THEN
         g_fail_msg := SUBSTR (SQLERRM, 1, 240);
         ttec_error_logging.process_error (application_code      => g_application_code,
                                           INTERFACE             => g_interface,
                                           program_name          => g_package,
                                           module_name           => v_module,
                                           status                => g_status_warning,
                                           ERROR_CODE            => SQLCODE,
                                           error_message         => g_fail_msg,
                                           label1                => 'Assignment ID',
                                           reference1            => p_asgn_cost_rec.assignment_id,
                                           label2                => 'Location Override',
                                           reference2            => p_asgn_cost_rec.LOCATION
                                          );
         p_return_msg := SUBSTR (g_fail_msg, 1, 240);
         p_module := v_module;
         p_reference :=
               p_asgn_cost_rec.LOCATION
            || '-'
            || p_asgn_cost_rec.department
            || '-'
            || p_asgn_cost_rec.client
            || '-'
            || p_asgn_cost_rec.ACCOUNT;
         p_status := FALSE;
   END get_location;

-- PROCEDURE get_department
--
-- Description: This INTERNAL procedure will take an input Cost Record (already
--              populated with the Assignment Costing Allocation info and determine
--              if it should update the Department Segment based on current value and
--              TeleTech Assignment Costing Rules.  It will update the record
--              as necessary and return it to the colling process.
--
-- Arguments:
--      In: p_asgn_cost_rec - Assignment Costing Record
--     Out: p_status        - TRUE if successful completion
--                          - FALSE if error encountered
--
   PROCEDURE get_department (
      p_asgn_cost_rec   IN OUT NOCOPY   asgncostrecord,
      p_status          OUT             BOOLEAN,
      p_return_msg      OUT             VARCHAR2,
      p_module          OUT             VARCHAR2,
      p_reference       OUT             VARCHAR2
   )
   IS
      --START R12.2 Upgrade Remediation
	  /*v_module       cust.ttec_error_handling.module_name%TYPE   := 'get_department';			-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
      v_department   gl.gl_code_combinations.segment3%TYPE;*/
	  v_module       apps.ttec_error_handling.module_name%TYPE   := 'get_department';			--  code Added by IXPRAVEEN-ARGANO,09-May-2023
      v_department   apps.gl_code_combinations.segment3%TYPE;
	  --END R12.2.10 Upgrade remediation
      v_dep_att      fnd_flex_values.attribute10%TYPE;
      e_dep_att      EXCEPTION;
   BEGIN
      -- Only look up the Assignment Org Department if the Costing Department is not
      -- already populated as it overrides.
      IF p_asgn_cost_rec.department IS NULL
      THEN
         SELECT pcak_org.segment3
           INTO v_department
           --START R12.2 Upgrade Remediation
		   /*FROM hr.per_all_assignments_f paa,					-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
                hr.hr_all_organization_units haou,
                hr.pay_cost_allocation_keyflex pcak_org*/
		   FROM apps.per_all_assignments_f paa,					--  code Added by IXPRAVEEN-ARGANO,09-May-2023
                apps.hr_all_organization_units haou,
                apps.pay_cost_allocation_keyflex pcak_org	
			--END R12.2.10 Upgrade remediation		
          WHERE paa.assignment_id = p_asgn_cost_rec.assignment_id
            AND g_valid_date BETWEEN paa.effective_start_date                                      -- 1.3
                                                             AND paa.effective_end_date
            AND haou.organization_id = paa.organization_id
            AND pcak_org.cost_allocation_keyflex_id = haou.cost_allocation_keyflex_id;

         p_asgn_cost_rec.department := v_department;
         p_asgn_cost_rec.department_src := g_asgn_org_dept_src;
      END IF;

      -- Revision 1.1 <Start>
      BEGIN
         SELECT   DECODE (p_asgn_cost_rec.location_att,
                          'CORPORATE', v.attribute10,
                          'REGIONAL', v.attribute11,
                          'COUNTRY', v.attribute11,
                          'SITE', v.attribute12
                         )
             INTO v_dep_att
             FROM fnd_flex_values v, fnd_flex_value_sets s, fnd_flex_values_tl t
            WHERE flex_value_set_name LIKE 'TELETECH_DEPARTMENT'
              AND s.flex_value_set_id = v.flex_value_set_id
              AND t.flex_value_id = v.flex_value_id
              AND v.flex_value = p_asgn_cost_rec.department
              AND t.LANGUAGE = 'US'
         ORDER BY v.flex_value;

         p_asgn_cost_rec.department_att := v_dep_att;
      EXCEPTION
         WHEN OTHERS
         THEN
            RAISE e_dep_att;
      END;

      p_status := TRUE;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         p_asgn_cost_rec.department := NULL;
         p_asgn_cost_rec.department_src := g_asgn_org_dept_src;
      WHEN e_dep_att
      THEN
         g_fail_msg := 'Either the DEP value or attribute on the value not exists - TELETECH_DEPARTMENT';
         ttec_error_logging.process_error (application_code      => g_application_code,
                                           INTERFACE             => g_interface,
                                           program_name          => g_package,
                                           module_name           => v_module,
                                           status                => g_status_warning,
                                           ERROR_CODE            => SQLCODE,
                                           error_message         => g_fail_msg,
                                           label1                => 'Assignment ID',
                                           reference1            => p_asgn_cost_rec.assignment_id,
                                           label2                => 'Department attribute',
                                           reference2            => p_asgn_cost_rec.department
                                          );
         p_return_msg := SUBSTR (g_fail_msg, 1, 240);
         p_module := v_module;
         p_reference :=
               p_asgn_cost_rec.LOCATION
            || '-'
            || p_asgn_cost_rec.department
            || '-'
            || p_asgn_cost_rec.client
            || '-'
            || p_asgn_cost_rec.ACCOUNT;
         p_status := FALSE;
      -- Revision 1.1 <End>
      WHEN OTHERS
      THEN
         g_fail_msg := SUBSTR (SQLERRM, 1, 240);
         ttec_error_logging.process_error (application_code      => g_application_code,
                                           INTERFACE             => g_interface,
                                           program_name          => g_package,
                                           module_name           => v_module,
                                           status                => g_status_warning,
                                           ERROR_CODE            => SQLCODE,
                                           error_message         => g_fail_msg,
                                           label1                => 'Assignment ID',
                                           reference1            => p_asgn_cost_rec.assignment_id,
                                           label2                => 'Department Override',
                                           reference2            => p_asgn_cost_rec.department
                                          );
         p_return_msg := SUBSTR (g_fail_msg, 1, 240);
         p_module := v_module;
         p_reference :=
               p_asgn_cost_rec.LOCATION
            || '-'
            || p_asgn_cost_rec.department
            || '-'
            || p_asgn_cost_rec.client
            || '-'
            || p_asgn_cost_rec.ACCOUNT;
         p_status := FALSE;
   END get_department;

-- PROCEDURE get_account
--
-- Description: This INTERNAL procedure will take an input Cost Record (already
--              populated with the Assignment Costing Allocation info and determine
--              if it should update the Account Segment based on current value and
--              TeleTech Assignment Costing Rules.  It will update the record
--              as necessary and return it to the colling process.
--
-- Arguments:
--      In: p_asgn_cost_rec - Assignment Costing Record
--     Out: p_status        - TRUE if successful completion
--                          - FALSE if error encountered
--
   PROCEDURE get_client (
      p_asgn_cost_rec   IN OUT NOCOPY   asgncostrecord,
      p_status          OUT             BOOLEAN,
      p_return_msg      OUT             VARCHAR2,
      p_module          OUT             VARCHAR2,
      p_reference       OUT             VARCHAR2
   )
   IS
   --START R12.2 Upgrade Remediation
      /*v_module         cust.ttec_error_handling.module_name%TYPE   := 'get_client';		-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
      v_client_att     fnd_flex_values.attribute10%TYPE;
      v_client         cust.ttec_emp_proj_asg.clt_cd%TYPE;*/
	  v_module         apps.ttec_error_handling.module_name%TYPE   := 'get_client';			--  code Added by IXPRAVEEN-ARGANO,09-May-2023
      v_client_att     fnd_flex_values.attribute10%TYPE;
      v_client         apps.ttec_emp_proj_asg.clt_cd%TYPE;
	--END R12.2.10 Upgrade remediation  
      e_no_client      EXCEPTION;
      e_client_att     EXCEPTION;
      e_invalid_dept   EXCEPTION;
   BEGIN
      -- Revision 1.1 <Start>
      IF p_asgn_cost_rec.client IS NULL
      THEN
         BEGIN
            SELECT tepa.clt_cd
              INTO v_client
              --FROM cust.ttec_emp_proj_asg tepa, per_all_people_f papf, per_all_assignments_f paaf		-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
			  FROM apps.ttec_emp_proj_asg tepa, per_all_people_f papf, per_all_assignments_f paaf  --  code Added by IXPRAVEEN-ARGANO,09-May-2023
             WHERE tepa.person_id = papf.person_id
               AND papf.person_id = paaf.person_id
               AND papf.current_employee_flag = 'Y'
               AND paaf.primary_flag = 'Y'
               AND paaf.assignment_id = p_asgn_cost_rec.assignment_id
               AND tepa.proportion =
                      (SELECT MAX (proportion)
                         --FROM cust.ttec_emp_proj_asg					-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
						 FROM apps.ttec_emp_proj_asg					--  code Added by IXPRAVEEN-ARGANO,09-May-2023
                        WHERE person_id = papf.person_id
                          AND g_valid_date BETWEEN prj_strt_dt AND prj_end_dt)
               -- 1.2
               AND g_valid_date BETWEEN papf.effective_start_date AND papf.effective_end_date      -- 1.3
               AND g_valid_date BETWEEN paaf.effective_start_date AND paaf.effective_end_date      -- 1.3
               AND g_valid_date BETWEEN tepa.prj_strt_dt AND tepa.prj_end_dt;

            -- 1.2
            p_asgn_cost_rec.client := v_client;
            p_asgn_cost_rec.client_src := g_asgn_org_client_src;
         END;
      END IF;

      BEGIN
         SELECT   v.attribute10
             INTO v_client_att
             FROM fnd_flex_values v, fnd_flex_value_sets s, fnd_flex_values_tl t
            WHERE flex_value_set_name LIKE 'TELETECH_CLIENT'
              AND s.flex_value_set_id = v.flex_value_set_id
              AND t.flex_value_id = v.flex_value_id
              AND v.flex_value = p_asgn_cost_rec.client
              AND t.LANGUAGE = 'US'
         ORDER BY v.flex_value;

         p_asgn_cost_rec.client_att := v_client_att;
      EXCEPTION
         WHEN OTHERS
         THEN
            RAISE e_client_att;
      END;

      p_status := TRUE;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         p_asgn_cost_rec.client := NULL;
         p_asgn_cost_rec.client_src := g_asgn_org_client_src;
      WHEN e_client_att
      THEN
         g_fail_msg := 'Either the CLIENT value or attribute on the value not exists - TELETECH_CLIENT';
         ttec_error_logging.process_error (application_code      => g_application_code,
                                           INTERFACE             => g_interface,
                                           program_name          => g_package,
                                           module_name           => v_module,
                                           status                => g_status_warning,
                                           ERROR_CODE            => SQLCODE,
                                           error_message         => g_fail_msg,
                                           label1                => 'Assignment ID',
                                           reference1            => p_asgn_cost_rec.assignment_id,
                                           label2                => 'Client attribute',
                                           reference2            => p_asgn_cost_rec.client
                                          );
         p_return_msg := SUBSTR (g_fail_msg, 1, 240);
         p_module := v_module;
         p_reference :=
               p_asgn_cost_rec.LOCATION
            || '-'
            || p_asgn_cost_rec.department
            || '-'
            || p_asgn_cost_rec.client
            || '-'
            || p_asgn_cost_rec.ACCOUNT;
         p_status := FALSE;
      -- Revision 1.1 <End>
      WHEN OTHERS
      THEN
         g_fail_msg := SUBSTR (SQLERRM, 1, 240);
         ttec_error_logging.process_error (application_code      => g_application_code,
                                           INTERFACE             => g_interface,
                                           program_name          => g_package,
                                           module_name           => v_module,
                                           status                => g_status_warning,
                                           ERROR_CODE            => SQLCODE,
                                           error_message         => g_fail_msg,
                                           label1                => 'Assignment ID',
                                           reference1            => p_asgn_cost_rec.assignment_id,
                                           label2                => 'Client',
                                           reference2            => p_asgn_cost_rec.client
                                          );
         p_return_msg := SUBSTR (g_fail_msg, 1, 240);
         p_module := v_module;
         p_reference :=
               p_asgn_cost_rec.LOCATION
            || '-'
            || p_asgn_cost_rec.department
            || '-'
            || p_asgn_cost_rec.client
            || '-'
            || p_asgn_cost_rec.ACCOUNT;
         p_status := FALSE;
   END get_client;

   -- Revision 1.1 <Start>
   PROCEDURE get_account (
      p_asgn_cost_rec   IN OUT NOCOPY   asgncostrecord,
      p_status          OUT             BOOLEAN,
      p_return_msg      OUT             VARCHAR2,
      p_module          OUT             VARCHAR2,
      p_reference       OUT             VARCHAR2
   )
   IS
      --v_module                cust.ttec_error_handling.module_name%TYPE   := 'get_account';			-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
	  v_module                apps.ttec_error_handling.module_name%TYPE   := 'get_account';				--  code Added by IXPRAVEEN-ARGANO,09-May-2023
      e_invalid_dept          EXCEPTION;
      e_invalid_dept_client   EXCEPTION;
   BEGIN
      IF p_asgn_cost_rec.department IS NULL OR p_asgn_cost_rec.client IS NULL
      THEN
         p_asgn_cost_rec.ACCOUNT := NULL;
         p_asgn_cost_rec.account_src := NULL;
         RAISE e_invalid_dept_client;
      END IF;

      IF p_asgn_cost_rec.department_att = 'SGA'
      THEN
         p_asgn_cost_rec.ACCOUNT := '7680';                                        -- Non-Client Related
         p_asgn_cost_rec.account_src := g_acct_non_client_src;
      ELSIF p_asgn_cost_rec.department_att = 'COGS'
      THEN
         p_asgn_cost_rec.ACCOUNT := '5680';                                            -- Client Related
         p_asgn_cost_rec.account_src := g_acct_client_src;
      -- New Customization added as part of rewrite of custom costing process and for Kronos outbound interface.
      ELSIF (p_asgn_cost_rec.department_att = 'BOTH' OR p_asgn_cost_rec.location_att = 'GBS'       -- 1.3
                                                                                            )
      THEN
         IF p_asgn_cost_rec.client_att = 'NON-CLIENT'                                             -- 1.3
         THEN                                                                      -- Non-Client Related
            p_asgn_cost_rec.ACCOUNT := '7680';
            p_asgn_cost_rec.account_src := g_acct_non_client_src;
         ELSE                                                                           -- Client Related
            p_asgn_cost_rec.ACCOUNT := '5680';
            p_asgn_cost_rec.account_src := g_acct_client_src;
         END IF;
      ELSIF (p_asgn_cost_rec.department_att LIKE 'NA' OR p_asgn_cost_rec.client_att LIKE 'NA')
      THEN
         RAISE e_invalid_dept;
      END IF;

      p_status := TRUE;
   EXCEPTION
      WHEN e_invalid_dept_client
      THEN
         g_fail_msg := 'No Department or Client on the assignment screen';
         ttec_error_logging.process_error (application_code      => g_application_code,
                                           INTERFACE             => g_interface,
                                           program_name          => g_package,
                                           module_name           => v_module,
                                           status                => g_status_warning,
                                           ERROR_CODE            => NULL,
                                           error_message         => g_fail_msg,
                                           label1                => 'Assignment ID',
                                           reference1            => p_asgn_cost_rec.assignment_id,
                                           label2                => 'Dept/Client',
                                           reference2            =>    p_asgn_cost_rec.LOCATION
                                                                    || '-'
                                                                    || p_asgn_cost_rec.department
                                                                    || '-'
                                                                    || p_asgn_cost_rec.client
                                                                    || '-'
                                                                    || p_asgn_cost_rec.ACCOUNT
                                          );
         p_return_msg := SUBSTR (g_fail_msg, 1, 240);
         p_module := v_module;
         p_reference :=
               p_asgn_cost_rec.LOCATION
            || '-'
            || p_asgn_cost_rec.department
            || '-'
            || p_asgn_cost_rec.client
            || '-'
            || p_asgn_cost_rec.ACCOUNT;
         p_status := FALSE;
      WHEN e_invalid_dept
      THEN
         g_fail_msg := 'Invalid department and location combination';
         ttec_error_logging.process_error (application_code      => g_application_code,
                                           INTERFACE             => g_interface,
                                           program_name          => g_package,
                                           module_name           => v_module,
                                           status                => g_status_warning,
                                           ERROR_CODE            => NULL,
                                           error_message         => g_fail_msg,
                                           label1                => 'Assignment ID',
                                           reference1            => p_asgn_cost_rec.assignment_id,
                                           label2                => 'location/Dept',
                                           reference2            =>    p_asgn_cost_rec.LOCATION
                                                                    || '-'
                                                                    || p_asgn_cost_rec.department
                                                                    || '-'
                                                                    || p_asgn_cost_rec.client
                                                                    || '-'
                                                                    || p_asgn_cost_rec.ACCOUNT
                                          );
         p_return_msg := SUBSTR (g_fail_msg, 1, 240);
         p_module := v_module;
         p_reference :=
               p_asgn_cost_rec.LOCATION
            || '-'
            || p_asgn_cost_rec.department
            || '-'
            || p_asgn_cost_rec.client
            || '-'
            || p_asgn_cost_rec.ACCOUNT;
         p_status := FALSE;
      WHEN OTHERS
      THEN
         g_fail_msg := SUBSTR (SQLERRM, 1, 240);
         ttec_error_logging.process_error (application_code      => g_application_code,
                                           INTERFACE             => g_interface,
                                           program_name          => g_package,
                                           module_name           => v_module,
                                           status                => g_status_warning,
                                           ERROR_CODE            => SQLCODE,
                                           error_message         => g_fail_msg,
                                           label1                => 'Assignment ID',
                                           reference1            => p_asgn_cost_rec.assignment_id,
                                           label2                => 'Client',
                                           reference2            => p_asgn_cost_rec.client
                                          );
         p_return_msg := SUBSTR (g_fail_msg, 1, 240);
         p_module := v_module;
         p_reference :=
               p_asgn_cost_rec.LOCATION
            || '-'
            || p_asgn_cost_rec.department
            || '-'
            || p_asgn_cost_rec.client
            || '-'
            || p_asgn_cost_rec.ACCOUNT;
         p_status := FALSE;
   END get_account;

-- Revision 1.1 <End>
-- PROCEDURE build_cost_accts
--
-- Description: This procedure will take an assignment_id as input and will build
--              a table of the Costing Allocations according to the TeleTech
--              Costing Rules.  It will order the output table by:
--                (1) Proportion - Highest to Lowest
--                (2) Cost Allocation Date - Oldest to Newest
--                (3) ROWID - Lowest to Highest
--
   PROCEDURE build_cost_accts (
      p_assignment_id   IN              hr.per_all_assignments_f.assignment_id%TYPE,
      p_asgn_costs      OUT NOCOPY      asgncosttable,
      p_return_msg      OUT             VARCHAR2,
      p_status          OUT             BOOLEAN
   )
   IS
      v_module            cust.ttec_error_handling.module_name%TYPE   := 'build_cost_accts';
      v_person_id         hr.per_all_people_f.person_id%TYPE;
      v_index             NUMBER                                      := 0;
      v_status            BOOLEAN;
      v_asgn_cost_rec     asgncostrecord;
      e_error             EXCEPTION;
      e_loc_dep_acc_err   EXCEPTION;
      v_reference         VARCHAR2 (250)                              DEFAULT NULL;

      CURSOR c_get_cost_alloc (l_assignment_id IN hr.per_all_assignments_f.assignment_id%TYPE)
      IS
         SELECT   pcak_asg.segment1 LOCATION, pcak_asg.segment2 client, pcak_asg.segment3 department,
                  pcaf.proportion proportion
            --START R12.2 Upgrade Remediation
			/* FROM hr.per_all_assignments_f paa,			-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
                  hr.pay_cost_allocations_f pcaf,
                  hr.pay_cost_allocation_keyflex pcak_asg*/
			 FROM apps.per_all_assignments_f paa,			--  code Added by IXPRAVEEN-ARGANO,09-May-2023
                  apps.pay_cost_allocations_f pcaf,
                  apps.pay_cost_allocation_keyflex pcak_asg	 
			--END R12.2.10 Upgrade remediation		
            WHERE paa.assignment_id = l_assignment_id
              AND g_valid_date BETWEEN paa.effective_start_date                                    -- 1.3
                                                               AND paa.effective_end_date
              AND pcaf.assignment_id = paa.assignment_id
              AND g_valid_date BETWEEN pcaf.effective_start_date                                   -- !.3
                                                                AND pcaf.effective_end_date
              AND pcak_asg.cost_allocation_keyflex_id = pcaf.cost_allocation_keyflex_id
         ORDER BY pcaf.proportion DESC, pcaf.effective_start_date ASC, pcaf.cost_allocation_id ASC;
   BEGIN
      BEGIN
         g_valid_date := ttec_valid_date (p_assign_id => p_assignment_id);
      EXCEPTION
         WHEN OTHERS
         THEN
            g_valid_date := TRUNC (SYSDATE);
      END;

      -- Validate this is an Active Assignment for an Active Employee before proceeding
      BEGIN
         SELECT pap.person_id
           INTO v_person_id
           --FROM hr.per_all_people_f pap, hr.per_all_assignments_f paa						-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
		   FROM apps.per_all_people_f pap, apps.per_all_assignments_f paa					--  code Added by IXPRAVEEN-ARGANO,09-May-2023
          WHERE pap.current_employee_flag = 'Y'
            AND g_valid_date BETWEEN pap.effective_start_date                                      -- 1.3
                                                             AND pap.effective_end_date
            AND pap.person_id = paa.person_id
            AND g_valid_date BETWEEN paa.effective_start_date                                      -- 1.3
                                                             AND paa.effective_end_date
            AND paa.assignment_id = p_assignment_id;
      EXCEPTION
--         WHEN NO_DATA_FOUND
--         THEN
--            g_fail_msg := 'Employee or Assignment record is NOT active';
--            RAISE e_error;
         WHEN OTHERS
         THEN
            v_person_id := NULL;
      END;

      FOR r_cost_alloc IN c_get_cost_alloc (p_assignment_id)
      LOOP
         -- Set Table Index
         v_index := v_index + 1;
         -- Set initial Variables for Record
         v_asgn_cost_rec := NULL;
         v_asgn_cost_rec.assignment_id := p_assignment_id;
         v_asgn_cost_rec.LOCATION := r_cost_alloc.LOCATION;
         v_asgn_cost_rec.client := r_cost_alloc.client;
         v_asgn_cost_rec.department := r_cost_alloc.department;
         v_asgn_cost_rec.proportion := r_cost_alloc.proportion;

         IF v_person_id IS NOT NULL
         THEN
            v_asgn_cost_rec.active_emp := 'Y';
         ELSE
            v_asgn_cost_rec.active_emp := 'N';
         END IF;

         IF v_asgn_cost_rec.LOCATION IS NOT NULL
         THEN
            v_asgn_cost_rec.location_src := g_cost_override_src;
         END IF;

         IF v_asgn_cost_rec.client IS NOT NULL
         THEN
            v_asgn_cost_rec.client_src := g_cost_override_src;
         END IF;

         IF v_asgn_cost_rec.department IS NOT NULL
         THEN
            v_asgn_cost_rec.department_src := g_cost_override_src;
         END IF;

         --Evaluate and Set each Segment according to TTEC Assignment Costing Rules
         get_location (v_asgn_cost_rec, v_status, g_fail_msg, v_module, v_reference);
         get_department (v_asgn_cost_rec, v_status, g_fail_msg, v_module, v_reference);
         get_client (v_asgn_cost_rec, v_status, g_fail_msg, v_module, v_reference);
         -- Revision 1.1
         get_account (v_asgn_cost_rec, v_status, g_fail_msg, v_module, v_reference);
         -- Add the Costing record to the Costing Table
         p_asgn_costs (v_index) := v_asgn_cost_rec;

         IF NOT v_status
         THEN
            p_status := FALSE;
         --RAISE e_error;
         END IF;
      END LOOP;

      -- Get the Location, Client, Account and Department even though there is no Costing Allocation
      IF v_index = 0
      THEN                                                                    -- No Costing Records build
         -- Return TRUE if either value is identified
         p_status := FALSE;
         v_index := v_index + 1;
         v_asgn_cost_rec := NULL;
         v_asgn_cost_rec.assignment_id := p_assignment_id;
         get_location (v_asgn_cost_rec, v_status, g_fail_msg, v_module, v_reference);

         IF v_status
         THEN
            p_status := TRUE;
         ELSE
            p_status := FALSE;
         END IF;

         get_department (v_asgn_cost_rec, v_status, g_fail_msg, v_module, v_reference);

         IF v_status
         THEN
            p_status := TRUE;
         ELSE
            p_status := FALSE;
         END IF;

         get_client (v_asgn_cost_rec, v_status, g_fail_msg, v_module, v_reference);

         IF v_status
         THEN
            p_status := TRUE;
         ELSE
            p_status := FALSE;
         END IF;

         -- Revision 1.1
         get_account (v_asgn_cost_rec, v_status, g_fail_msg, v_module, v_reference);

         IF v_status
         THEN
            p_status := TRUE;
         ELSE
            p_status := FALSE;
         END IF;

         -- Insert record to Table if either Location or Department Set
         IF p_status
         THEN
            p_asgn_costs (v_index) := v_asgn_cost_rec;
         ELSE
            g_fail_msg := g_fail_msg || '-' || 'No Costing was build for Assignment';
            RAISE e_error;
         END IF;
      END IF;

      p_status := TRUE;
   EXCEPTION
      WHEN e_error
      THEN
         ttec_error_logging.process_error (application_code      => g_application_code,
                                           INTERFACE             => g_interface,
                                           program_name          => g_package,
                                           module_name           => v_module,
                                           status                => g_status_failure,
                                           ERROR_CODE            => NULL,
                                           error_message         => g_fail_msg,
                                           label1                => 'Assignment ID',
                                           reference1            => p_assignment_id,
                                           label2                => 'Code Combination',
                                           reference2            => v_reference
                                          );
         p_return_msg := SUBSTR (g_fail_msg, 1, 240);
         p_status := FALSE;
      WHEN OTHERS
      THEN
         g_fail_msg := SUBSTR (g_fail_msg || '-' || SQLERRM, 1, 240);
         ttec_error_logging.process_error (application_code      => g_application_code,
                                           INTERFACE             => g_interface,
                                           program_name          => g_package,
                                           module_name           => v_module,
                                           status                => g_status_failure,
                                           ERROR_CODE            => SQLCODE,
                                           error_message         => g_fail_msg,
                                           label1                => 'Assignment ID',
                                           reference1            => p_assignment_id,
                                           label2                => 'Code Combination',
                                           reference2            => v_reference
                                          );
         p_return_msg := SUBSTR (g_fail_msg, 1, 240);
         p_status := FALSE;
   END build_cost_accts;
END ttec_assign_costing_rules;
/
show errors;
/
