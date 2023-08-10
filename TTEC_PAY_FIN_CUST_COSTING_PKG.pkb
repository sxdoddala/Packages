create or replace PACKAGE BODY      ttec_pay_fin_cust_costing_pkg
AS
/* $Header: ttec_pay_fin_custom_costing_pkg.pkb 1.0 2010/05/10 kbabu $ */
/*== START ================================================================================================*\
   Author:  Kaushik Babu
     Date:  Date:  May 21, 2010
     Desc: This package containes all PL/SQL code necessary for the 'TeleTech Custom Costing - Offset Balance Program - 2010'
           customization.This package is used for updating payroll costing for all business group
Call From:  TeleTech Custom Costing - Offset Balance Program - 2010
Parameters: Payroll ID - Payroll name for LOV
            Consolidation Set ID - Consolidation Set name from LOV
            Payment Start Date - Payment Date
            Payment End Date - Payment Date
            GL Segment Location - Segment1 location on GL Code combinations
            GL Segment Client   - Segment2 Client on GL Code Combinations
            GL Segment Dept - Segment3 Department on GL Code combinations
            GL Segment Account   - Segment2 Account on GL Code Combinations
            Employee id   - Select Employee Full Name
            Job id  - Select Job Name
  Modification History:

 Mod#  Person         Date     Comments
---------------------------------------------------------------------------
 1.0  Kaushik Babu  21-May-10 TTSD - 124797 - Rewrite of Custom costing Process for all business groups - Initial Version
 2.0  Kaushik Babu  17-Nov-10 TTSD -I#434099 - customized to generate correct costing information for split costin records.
 2.1  Kaushik Babu  06-DEC-10 TTSD 453327- Fixed the Custom Costing issue erroring out for employee who have job id null
 2.2  Kaushik Babu  24-FEB-11 TTSD R407205 - 1. Fixed to generate costing for missing costing of an employee
                                             2. Checked on the performance issues of custom costing
                                             3. Fixed report to generate errors on the output file and also purge errors from ttec_error_handling table
                                                before 60 days.
 2.3  Kaushik Babu  03-MAY-11 TTSD I 688671 - Fixed performance issue
 1.0  RXNETHI-ARGANO 11-MAY-23 R12.2 Upgrade Remediation  
\*== END ==================================================================================================*/
-- Procedure to retrieve new cost allocation id based on the segment1 to segment4 generated for each cost or balance string.
   PROCEDURE insert_keyflex_record (
      l_keyflex_record              IN       keyflex_record,
      --l_business_group              IN       hr.per_all_assignments_f.business_group_id%TYPE, --code commented by RXNETHI-ARGANO,11/05/23
	  l_business_group              IN       apps.per_all_assignments_f.business_group_id%TYPE, --code added by RXNETHI-ARGANO,11/05/23
      p_new_allocation_keyflex_id   OUT      NUMBER
   )
   IS
      l_costflex_id    NUMBER                                                      := NULL;
      --l_concatenated   hr.pay_cost_allocation_keyflex.concatenated_segments%TYPE   := NULL; --code commented by RXNETHI-ARGANO,11/05/23
	  l_concatenated   apps.pay_cost_allocation_keyflex.concatenated_segments%TYPE   := NULL; --code added by RXNETHI-ARGANO,11/05/23
      l_val            VARCHAR2 (1);
   BEGIN
      g_module := 'INSERT_KEYFLEX_RECORD';
      l_costflex_id := NULL;
      l_concatenated := NULL;

      BEGIN
         l_costflex_id :=
            apps.pay_csk_flex.get_cost_allocation_id
                                          (p_business_group_id               => l_business_group,
                                           p_cost_allocation_keyflex_id      => l_keyflex_record.id_flex_num,
                                           p_concatenated_segments           => NULL,
                                           p_segment1                        => l_keyflex_record.segment1,
                                           p_segment2                        => l_keyflex_record.segment2,
                                           p_segment3                        => l_keyflex_record.segment3,
                                           p_segment4                        => l_keyflex_record.segment4,
                                           p_segment5                        => l_keyflex_record.segment5,
                                           p_segment6                        => l_keyflex_record.segment6,
                                           p_segment7                        => NULL,
                                           p_segment8                        => NULL,
                                           p_segment9                        => NULL,
                                           p_segment10                       => NULL,
                                           p_segment11                       => NULL,
                                           p_segment12                       => NULL,
                                           p_segment13                       => NULL,
                                           p_segment14                       => NULL,
                                           p_segment15                       => NULL,
                                           p_segment16                       => NULL,
                                           p_segment17                       => NULL,
                                           p_segment18                       => NULL,
                                           p_segment19                       => NULL,
                                           p_segment20                       => NULL,
                                           p_segment21                       => NULL,
                                           p_segment22                       => NULL,
                                           p_segment23                       => NULL,
                                           p_segment24                       => NULL,
                                           p_segment25                       => NULL,
                                           p_segment26                       => NULL,
                                           p_segment27                       => NULL,
                                           p_segment28                       => NULL,
                                           p_segment29                       => NULL,
                                           p_segment30                       => NULL
                                          );
         p_new_allocation_keyflex_id := l_costflex_id;
         l_concatenated :=
               l_keyflex_record.segment1
            || '.'
            || l_keyflex_record.segment2
            || '.'
            || l_keyflex_record.segment3
            || '.'
            || l_keyflex_record.segment4
            || '.'
            || l_keyflex_record.segment5
            || '.'
            || l_keyflex_record.segment6;
      EXCEPTION
         WHEN OTHERS
         THEN
            fnd_file.put_line (fnd_file.output,
                               'Error in pay_csk_flex.get_cost_allocation_id package - ' || SQLERRM
                              );
      END;

      g_reference := l_costflex_id || '-' || l_concatenated;

      BEGIN
         UPDATE apps.pay_cost_allocation_keyflex
            SET concatenated_segments = l_concatenated
          WHERE cost_allocation_keyflex_id = l_costflex_id;
      EXCEPTION
         WHEN OTHERS
         THEN
            fnd_file.put_line (fnd_file.output,
                                  'Error in update string apps.pay_cost_allocation_keyflex- '
                               || g_reference
                               || '-'
                               || SQLERRM
                              );
      END;

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         g_fail_msg := SUBSTR ('Insert keyflex' || '-' || SQLERRM, 1, 240);
         ttec_error_logging.process_error (application_code      => g_application_code,
                                           INTERFACE             => g_interface,
                                           program_name          => g_package,
                                           module_name           => g_module,
                                           status                => g_status_warning,
                                           ERROR_CODE            => SQLCODE,
                                           error_message         => g_fail_msg,
                                           label1                => 'Assign ID',
                                           reference1            => l_keyflex_record.assignment_id,
                                           label2                => 'ConcString',
                                           reference2            => g_reference
                                          );
   END;

-- procedure to update new cost allocation id on the pay_costs table for each cost or balance string.
   PROCEDURE update_pay_costs (
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,11/05/23
	  l_new_allocation_keyflex_id   IN   hr.pay_cost_allocation_keyflex.cost_allocation_keyflex_id%TYPE,
      l_cost_id                     IN   hr.pay_costs.cost_id%TYPE
	  */
	  --code added by RXNETHI-ARGANO,11/05/23
	  l_new_allocation_keyflex_id   IN   apps.pay_cost_allocation_keyflex.cost_allocation_keyflex_id%TYPE,
      l_cost_id                     IN   apps.pay_costs.cost_id%TYPE
	  --END R12.2 Upgrade Remediation
   )
   IS
   BEGIN
      g_module := 'UPDATE_PAY_COSTS';
      g_reference := l_new_allocation_keyflex_id || '-' || l_cost_id;

      --UPDATE hr.pay_costs --code commented by RXNETHI-ARGANO,11/05/23
	  UPDATE apps.pay_costs --code added by RXNETHI-ARGANO,11/05/23
         SET cost_allocation_keyflex_id = l_new_allocation_keyflex_id
       WHERE cost_id = l_cost_id;

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         g_fail_msg := SUBSTR ('Update Pay Costs' || '-' || SQLERRM, 1, 240);
         ttec_error_logging.process_error (application_code      => g_application_code,
                                           INTERFACE             => g_interface,
                                           program_name          => g_package,
                                           module_name           => g_module,
                                           status                => g_status_warning,
                                           ERROR_CODE            => SQLCODE,
                                           error_message         => g_fail_msg,
                                           label1                => 'NewAllocID',
                                           reference1            => l_new_allocation_keyflex_id,
                                           label2                => 'NewKeyFlex',
                                           reference2            => g_reference
                                          );
   END;

   -- PROCEDURE NAME       : GET_JOB_ACCOUNT
   -- INCOMING PARAMETERS  : assignment_id,  effective_date
   -- OUTGOING PARAMETERS  : Account
   -- DESCRIPTION          : This procedure retrieves account from job
   PROCEDURE get_job_account (
      l_assignment_id    IN       NUMBER,
      l_effective_date   IN       DATE,
      l_account          IN OUT   VARCHAR2
   )
   IS
      v_acct_exist    VARCHAR2 (1)                         DEFAULT NULL;
      v_description   fnd_lookup_values.description%TYPE   DEFAULT NULL;
   BEGIN
      g_module := 'GET JOB ACCOUNT';

      BEGIN
         BEGIN
            v_acct_exist := NULL;
            v_description := NULL;

            /*Query given below retrieve account to be updated from description column on the lookup table*/
            SELECT 'Y'
              INTO v_acct_exist
              FROM fnd_lookup_values
             WHERE lookup_type LIKE 'TTEC_GL_ELEMENT_OVERRIDE'
               AND LANGUAGE = 'US'
               AND lookup_code = l_account
               AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE) AND NVL (end_date_active, SYSDATE);
         EXCEPTION
            WHEN OTHERS
            THEN
               v_acct_exist := 'N';
         END;
      END;

      IF v_acct_exist = 'Y'
      THEN
         SELECT pj.attribute7
           INTO l_account
           --FROM hr.per_all_assignments_f paaf, hr.per_jobs pj --code commented by RXNETHI-ARGANO,11/05/23
		   FROM apps.per_all_assignments_f paaf, apps.per_jobs pj --code added by RXNETHI-ARGANO,11/05/23
          WHERE paaf.assignment_id = l_assignment_id
            AND l_effective_date BETWEEN paaf.effective_start_date AND paaf.effective_end_date
            AND paaf.job_id = pj.job_id;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         l_account := l_account;
         g_fail_msg := SUBSTR ('Generate Job account' || '-' || SQLERRM, 1, 240);
         ttec_error_logging.process_error (application_code      => g_application_code,
                                           INTERFACE             => g_interface,
                                           program_name          => g_package,
                                           module_name           => g_module,
                                           status                => g_status_warning,
                                           ERROR_CODE            => SQLCODE,
                                           error_message         => g_fail_msg,
                                           label1                => 'Assign ID',
                                           reference1            => l_assignment_id,
                                           label2                => 'Account',
                                           reference2            => l_account
                                          );
   END;

   PROCEDURE main_proc (
      p_errbuf                 OUT      VARCHAR2,
      p_errcode                OUT      NUMBER,
      p_payroll_id             IN       NUMBER,
      p_consolidation_set_id   IN       NUMBER,
      p_start_date             IN       VARCHAR2,
      p_end_date               IN       VARCHAR2,
      p_business_grp_id        IN       NUMBER,
      p_seg_location           IN       VARCHAR2,
      p_seg_client             IN       VARCHAR2,
      p_seg_dept               IN       VARCHAR2,
      p_seg_acct               IN       VARCHAR2,
      p_employee_id            IN       NUMBER,
      p_job_id                 IN       NUMBER
   )
   IS
      /*query to generate complete list of cost and balance lines for each pay period based on different parameters*/
      CURSOR c_get_cost_lines
      IS
         SELECT   pc.cost_allocation_keyflex_id, ppa.business_group_id, paa.assignment_id, pc.cost_id,
                  pcak.segment1, pcak.segment2, pcak.segment3, pcak.segment4, pcak.segment5,
                  pcak.segment6, pcak.id_flex_num, pcak.summary_flag, pcak.enabled_flag,
                  pc.run_result_id, pc.distributed_run_result_id, ppa.effective_date,
                  papf.employee_number, ppa.payroll_id, pc.balance_or_cost
             /*
			 START R12.2 Upgrade Remediation
			 code commented by RXNETHI-ARGANO,11/05/23
			 FROM hr.pay_cost_allocation_keyflex pcak,
                  hr.pay_costs pc,
                  hr.pay_assignment_actions paa,
                  hr.pay_payroll_actions ppa,
                  hr.per_all_assignments_f paaf,
                  hr.per_all_people_f papf
				  */
			 --code added by RXNETHI-ARGANO,11/05/23
			 FROM apps.pay_cost_allocation_keyflex pcak,
                  apps.pay_costs pc,
                  apps.pay_assignment_actions paa,
                  apps.pay_payroll_actions ppa,
                  apps.per_all_assignments_f paaf,
                  apps.per_all_people_f papf
			 --END R12.2 Upgrade Remediation
            WHERE pc.assignment_action_id = paa.assignment_action_id
              AND pcak.cost_allocation_keyflex_id = pc.cost_allocation_keyflex_id
              AND ppa.payroll_action_id = paa.payroll_action_id
              AND ppa.effective_date BETWEEN fnd_date.canonical_to_date (p_start_date)
                                         AND fnd_date.canonical_to_date (p_end_date)
              AND ppa.action_type = 'C'
              AND paa.assignment_id = paaf.assignment_id
              AND paaf.person_id = papf.person_id
              AND NVL (pcak.segment1, -1) = NVL (NVL (p_seg_location, pcak.segment1), -1)
              AND NVL (pcak.segment2, -1) = NVL (NVL (p_seg_client, pcak.segment2), -1)
              AND NVL (pcak.segment3, -1) = NVL (NVL (p_seg_dept, pcak.segment3), -1)
              AND NVL (pcak.segment4, -1) = NVL (NVL (p_seg_acct, pcak.segment4), -1)
              AND papf.person_id = NVL (p_employee_id, papf.person_id)
              AND NVL (paaf.job_id, -1) = NVL (NVL (p_job_id, paaf.job_id), -1)            -- Version 2.1
              AND ppa.effective_date BETWEEN paaf.effective_start_date AND paaf.effective_end_date
              AND ppa.effective_date BETWEEN papf.effective_start_date AND papf.effective_end_date
              AND NVL (ppa.consolidation_set_id, -1) =
                                          NVL (NVL (p_consolidation_set_id, ppa.consolidation_set_id),
                                               -1)
              AND NVL (ppa.payroll_id, -1) = NVL (NVL (p_payroll_id, ppa.payroll_id), -1)     -- Version 2.3
              AND papf.business_group_id = NVL (p_business_grp_id, papf.business_group_id)
         ORDER BY papf.employee_number, pc.cost_allocation_keyflex_id;

      v_asgn_costs                   ttec_assign_costing_rules.asgncosttable;
      v_return_msg                   VARCHAR2 (240);
      v_status                       BOOLEAN                                                 DEFAULT TRUE;
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,11/05/23
	  v_cost_allocation_keyflex_id   hr.pay_cost_allocation_keyflex.cost_allocation_keyflex_id%TYPE
                                                                                                  := NULL;
      v_new_allocation_keyflex_id    hr.pay_cost_allocation_keyflex.cost_allocation_keyflex_id%TYPE
                                                                                                  := NULL;
      v_cost_id                      hr.pay_costs.cost_id%TYPE                                    := NULL;
	  */
	  --code added by RXNETHI-ARGANO,11/05/23
	  v_cost_allocation_keyflex_id   apps.pay_cost_allocation_keyflex.cost_allocation_keyflex_id%TYPE
                                                                                                  := NULL;
      v_new_allocation_keyflex_id    apps.pay_cost_allocation_keyflex.cost_allocation_keyflex_id%TYPE
                                                                                                  := NULL;
      v_cost_id                      apps.pay_costs.cost_id%TYPE                                    := NULL;
	  --END R12.2 Upgrade Remediation
      v_acct_exist                   VARCHAR2 (1)                                            DEFAULT NULL;
      v_description                  fnd_lookup_values.description%TYPE                      DEFAULT NULL;
      v_cost_location                pay_cost_allocation_keyflex.segment1%TYPE               DEFAULT NULL;
      e_assign_costing               EXCEPTION;
      g_lines_processed              NUMBER                                                          := 0;
      g_lines_skipped                NUMBER                                                          := 0;
      g_lines_errored                NUMBER                                                          := 0;
      g_keep_days                    NUMBER                                                         := 60;
      -- Number of days to keep error logging.
      g_fail_flag                    BOOLEAN                                                     := FALSE;
      g_request_id                   NUMBER                                 := fnd_global.conc_request_id;
      g_created_by                   NUMBER                                         := fnd_global.user_id;
   BEGIN
      FOR r_get_cost_lines IN c_get_cost_lines
      LOOP
         IF r_get_cost_lines.balance_or_cost = 'C'
         THEN
            BEGIN
               g_reference := NULL;
               g_module := 'Costing Line';
               v_keyflex_record.segment1 := r_get_cost_lines.segment1;
               v_keyflex_record.segment2 := r_get_cost_lines.segment2;
               v_keyflex_record.segment3 := r_get_cost_lines.segment3;
               v_keyflex_record.segment4 := r_get_cost_lines.segment4;
               v_keyflex_record.segment5 := r_get_cost_lines.segment5;
               v_keyflex_record.segment6 := r_get_cost_lines.segment6;
               v_keyflex_record.id_flex_num := r_get_cost_lines.id_flex_num;
               v_keyflex_record.summary_flag := r_get_cost_lines.summary_flag;
               v_keyflex_record.enabled_flag := r_get_cost_lines.enabled_flag;
               v_keyflex_record.assignment_id := r_get_cost_lines.assignment_id;
               v_keyflex_record.payroll_id := r_get_cost_lines.payroll_id;
               v_keyflex_record.cost_allocation_keyflex_id :=
                                                             r_get_cost_lines.cost_allocation_keyflex_id;
               fnd_file.put_line (fnd_file.LOG,
                                     'Old Cost String - '
                                  || v_keyflex_record.cost_allocation_keyflex_id
                                  || '-'
                                  || v_keyflex_record.payroll_id
                                  || '-'
                                  || v_keyflex_record.assignment_id
                                  || '-'
                                  || (   v_keyflex_record.segment1
                                      || '.'
                                      || v_keyflex_record.segment2
                                      || '.'
                                      || v_keyflex_record.segment3
                                      || '.'
                                      || v_keyflex_record.segment4
                                     )
                                 );
               g_reference :=
                     v_keyflex_record.cost_allocation_keyflex_id
                  || '-'
                  || v_keyflex_record.assignment_id
                  || '-'
                  || r_get_cost_lines.balance_or_cost;

               IF SUBSTR (r_get_cost_lines.segment4, 1, 1) = '2'
               THEN
                  BEGIN
                     v_cost_location := NULL;

                     /*Query given below retrieve the Costing value on the payroll screen*/
                     SELECT pcak.segment1
                       INTO v_cost_location
                       FROM pay_payrolls_f ppf, pay_cost_allocation_keyflex pcak
                      WHERE ppf.cost_allocation_keyflex_id = pcak.cost_allocation_keyflex_id
                        AND SYSDATE BETWEEN ppf.effective_start_date AND ppf.effective_end_date
                        AND ppf.payroll_id = r_get_cost_lines.payroll_id;
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        v_cost_location := NULL;
                  END;

                  v_keyflex_record.segment1 := v_cost_location;
                  v_keyflex_record.segment2 := '0000';
                  v_keyflex_record.segment3 := '000';
                  insert_keyflex_record (v_keyflex_record, p_business_grp_id,
                                         v_new_allocation_keyflex_id);
                  update_pay_costs (v_new_allocation_keyflex_id, r_get_cost_lines.cost_id);
                  v_keyflex_record.cost_allocation_keyflex_id := v_new_allocation_keyflex_id;
                  fnd_file.put_line (fnd_file.LOG,
                                        'New Cost String - '
                                     || v_keyflex_record.cost_allocation_keyflex_id
                                     || '-'
                                     || v_keyflex_record.payroll_id
                                     || '-'
                                     || v_keyflex_record.assignment_id
                                     || '-'
                                     || (   v_keyflex_record.segment1
                                         || '.'
                                         || v_keyflex_record.segment2
                                         || '.'
                                         || v_keyflex_record.segment3
                                         || '.'
                                         || v_keyflex_record.segment4
                                        )
                                    );
               ELSIF SUBSTR (r_get_cost_lines.segment4, 1, 1) = '5'
               THEN
                  BEGIN
                     get_job_account (v_keyflex_record.assignment_id,
                                      r_get_cost_lines.effective_date,
                                      v_keyflex_record.segment4
                                     );
                  END;

                  BEGIN
                     BEGIN
                        v_acct_exist := NULL;
                        v_description := NULL;

                        /*Query given below retrieve account to be updated from description column on the lookup table*/
                        SELECT 'Y', description
                          INTO v_acct_exist, v_description
                          FROM fnd_lookup_values
                         WHERE lookup_type LIKE 'TTEC_GL_PAYROLL_ACCTS'
                           AND LANGUAGE = 'US'
                           AND lookup_code = v_keyflex_record.segment4
                           AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                                           AND NVL (end_date_active, SYSDATE);
                     EXCEPTION
                        WHEN OTHERS
                        THEN
                           v_acct_exist := 'N';
                     END;
                  END;

                  BEGIN
                     /*Package to build cost accounts for each assignment to update cost string*/
                     g_module := 'Custom Costing Pkg';
                     ttec_assign_costing_rules.build_cost_accts
                                                     (p_assignment_id      => r_get_cost_lines.assignment_id,
                                                      p_asgn_costs         => v_asgn_costs,
                                                      p_return_msg         => v_return_msg,
                                                      p_status             => v_status
                                                     );

                     IF v_status
                     THEN
                        FOR i IN 1 .. v_asgn_costs.COUNT
                        LOOP
                           v_keyflex_record.assignment_id := v_asgn_costs (i).assignment_id;
                           v_keyflex_record.segment1 := v_asgn_costs (i).LOCATION;
                           v_keyflex_record.segment2 := v_asgn_costs (i).client;
                           v_keyflex_record.segment3 := v_asgn_costs (i).department;
                           /*v_keyflex_record.segment4 :=
                                                     v_asgn_costs (i).ACCOUNT;*/
                           v_keyflex_record.location_src := v_asgn_costs (i).location_src;
                           v_keyflex_record.location_att := v_asgn_costs (i).location_att;
                           v_keyflex_record.client_src := v_asgn_costs (i).client_src;
                           v_keyflex_record.client_att := v_asgn_costs (i).client_att;
                           v_keyflex_record.department_src := v_asgn_costs (i).department_src;
                           v_keyflex_record.department_att := v_asgn_costs (i).department_att;
                           v_keyflex_record.proportion := v_asgn_costs (i).proportion;
                           v_keyflex_record.account_src := v_asgn_costs (i).account_src;

                           IF NVL (v_keyflex_record.proportion, 1) = 1          -- Version 2.2 (1)
                           THEN
                              BEGIN
                                 IF     (   (v_keyflex_record.department_att = 'SGA')
                                         OR (    (   v_keyflex_record.department_att = 'BOTH'
                                                  OR v_keyflex_record.location_att = 'GBS'
                                                 )
                                             AND v_keyflex_record.client_att = 'NON-CLIENT'
                                            )
                                        )
                                    AND SUBSTR (v_keyflex_record.segment4, 1, 1) = '5'
                                 THEN
                                    IF v_acct_exist = 'Y'
                                    THEN
                                       v_keyflex_record.segment4 := v_description;
                                    ELSE
                                       v_keyflex_record.segment4 :=
                                                            '7' || SUBSTR (v_keyflex_record.segment4, 2);
                                    END IF;
                                 END IF;

                                 -- Version 1.2
                                 insert_keyflex_record (v_keyflex_record,
                                                        p_business_grp_id,
                                                        v_new_allocation_keyflex_id
                                                       );
                                 update_pay_costs (v_new_allocation_keyflex_id, r_get_cost_lines.cost_id);
                                 v_keyflex_record.cost_allocation_keyflex_id :=
                                                                              v_new_allocation_keyflex_id;
                                 fnd_file.put_line (fnd_file.LOG,
                                                       'New Cost String - '
                                                    || v_keyflex_record.cost_allocation_keyflex_id
                                                    || '-'
                                                    || v_keyflex_record.payroll_id
                                                    || '-'
                                                    || v_keyflex_record.assignment_id
                                                    || '-'
                                                    || (   v_keyflex_record.segment1
                                                        || '.'
                                                        || v_keyflex_record.segment2
                                                        || '.'
                                                        || v_keyflex_record.segment3
                                                        || '.'
                                                        || v_keyflex_record.segment4
                                                       )
                                                   );
                                 v_new_allocation_keyflex_id := NULL;
                                 v_cost_id := NULL;
                              END;
                           ELSE
                              IF     r_get_cost_lines.segment1 = v_keyflex_record.segment1
                                 AND r_get_cost_lines.segment2 = v_keyflex_record.segment2
                                 AND r_get_cost_lines.segment3 = v_keyflex_record.segment3
                              THEN
                                 BEGIN
                                    IF     (   (v_keyflex_record.department_att = 'SGA')
                                            OR (    (   v_keyflex_record.department_att = 'BOTH'
                                                     OR v_keyflex_record.location_att = 'GBS'
                                                    )
                                                AND v_keyflex_record.client_att = 'NON-CLIENT'
                                               )
                                           )
                                       AND SUBSTR (v_keyflex_record.segment4, 1, 1) = '5'
                                    THEN
                                       IF v_acct_exist = 'Y'
                                       THEN
                                          v_keyflex_record.segment4 := v_description;
                                       ELSE
                                          v_keyflex_record.segment4 :=
                                                            '7' || SUBSTR (v_keyflex_record.segment4, 2);
                                       END IF;
                                    END IF;

                                    -- Version 1.2
                                    insert_keyflex_record (v_keyflex_record,
                                                           p_business_grp_id,
                                                           v_new_allocation_keyflex_id
                                                          );
                                    update_pay_costs (v_new_allocation_keyflex_id,
                                                      r_get_cost_lines.cost_id
                                                     );
                                    v_keyflex_record.cost_allocation_keyflex_id :=
                                                                              v_new_allocation_keyflex_id;
                                    fnd_file.put_line (fnd_file.LOG,
                                                          'New Cost String - '
                                                       || v_keyflex_record.cost_allocation_keyflex_id
                                                       || '-'
                                                       || v_keyflex_record.payroll_id
                                                       || '-'
                                                       || v_keyflex_record.assignment_id
                                                       || '-'
                                                       || (   v_keyflex_record.segment1
                                                           || '.'
                                                           || v_keyflex_record.segment2
                                                           || '.'
                                                           || v_keyflex_record.segment3
                                                           || '.'
                                                           || v_keyflex_record.segment4
                                                          )
                                                      );
                                    v_new_allocation_keyflex_id := NULL;
                                    v_cost_id := NULL;
                                 END;
                              END IF;
                           END IF;
                        END LOOP;
                     ELSE
                        g_fail_msg :=
                           SUBSTR (   'Error in generating value using TTEC_ASSIGN_COSTING_RULES PKG'
                                   || '-'
                                   || SQLERRM,
                                   1,
                                   240
                                  );
                        RAISE e_assign_costing;
                     END IF;
                  END;
               END IF;
            EXCEPTION
               WHEN e_assign_costing
               THEN
                  ttec_error_logging.process_error (application_code      => g_application_code,
                                                    INTERFACE             => g_interface,
                                                    program_name          => g_package,
                                                    module_name           => g_module,
                                                    status                => g_status_warning,
                                                    ERROR_CODE            => SQLCODE,
                                                    error_message         => g_fail_msg,
                                                    label1                => 'Assign ID',
                                                    reference1            => r_get_cost_lines.assignment_id,
                                                    label2                => 'Combination',
                                                    reference2            => g_reference
                                                   );
               WHEN OTHERS
               THEN
                  g_fail_msg := SUBSTR ('Error in Cost String' || '-' || SQLERRM, 1, 240);
                  ttec_error_logging.process_error (application_code      => g_application_code,
                                                    INTERFACE             => g_interface,
                                                    program_name          => g_package,
                                                    module_name           => g_module,
                                                    status                => g_status_warning,
                                                    ERROR_CODE            => SQLCODE,
                                                    error_message         => g_fail_msg,
                                                    label1                => 'Assign ID',
                                                    reference1            => r_get_cost_lines.assignment_id,
                                                    label2                => 'Combination',
                                                    reference2            => g_reference
                                                   );
            END;
         ELSIF r_get_cost_lines.balance_or_cost = 'B'
         THEN
            BEGIN
               g_reference := NULL;
               g_module := 'Balance Line';
               v_keyflex_record.segment1 := r_get_cost_lines.segment1;
               v_keyflex_record.segment2 := r_get_cost_lines.segment2;
               v_keyflex_record.segment3 := r_get_cost_lines.segment3;
               v_keyflex_record.segment4 := r_get_cost_lines.segment4;
               v_keyflex_record.segment5 := r_get_cost_lines.segment5;
               v_keyflex_record.segment6 := r_get_cost_lines.segment6;
               v_keyflex_record.id_flex_num := r_get_cost_lines.id_flex_num;
               v_keyflex_record.summary_flag := r_get_cost_lines.summary_flag;
               v_keyflex_record.enabled_flag := r_get_cost_lines.enabled_flag;
               v_keyflex_record.assignment_id := r_get_cost_lines.assignment_id;
               v_keyflex_record.payroll_id := r_get_cost_lines.payroll_id;
               v_keyflex_record.cost_allocation_keyflex_id :=
                                                             r_get_cost_lines.cost_allocation_keyflex_id;
               fnd_file.put_line (fnd_file.LOG,
                                     'Old Balance String - '
                                  || v_keyflex_record.cost_allocation_keyflex_id
                                  || '-'
                                  || v_keyflex_record.payroll_id
                                  || '-'
                                  || v_keyflex_record.assignment_id
                                  || '-'
                                  || (   v_keyflex_record.segment1
                                      || '.'
                                      || v_keyflex_record.segment2
                                      || '.'
                                      || v_keyflex_record.segment3
                                      || '.'
                                      || v_keyflex_record.segment4
                                     )
                                 );
               g_reference :=
                     v_keyflex_record.cost_allocation_keyflex_id
                  || '-'
                  || v_keyflex_record.assignment_id
                  || '-'
                  || r_get_cost_lines.balance_or_cost;

               BEGIN
                  v_cost_location := NULL;

                  SELECT pcak.segment1
                    INTO v_cost_location
                    FROM pay_payrolls_f ppf, pay_cost_allocation_keyflex pcak
                   WHERE ppf.cost_allocation_keyflex_id = pcak.cost_allocation_keyflex_id
                     AND SYSDATE BETWEEN ppf.effective_start_date AND ppf.effective_end_date
                     AND ppf.payroll_id = r_get_cost_lines.payroll_id;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     v_cost_location := NULL;
               END;

               IF SUBSTR (v_keyflex_record.segment4, 1, 1) = '2'
               THEN
                  v_keyflex_record.segment1 := v_cost_location;
                  v_keyflex_record.segment2 := '0000';
                  v_keyflex_record.segment3 := '000';
               ELSE
                  v_keyflex_record.segment1 := v_cost_location;
               END IF;

               insert_keyflex_record (v_keyflex_record, p_business_grp_id, v_new_allocation_keyflex_id);
               v_keyflex_record.cost_allocation_keyflex_id := v_new_allocation_keyflex_id;
               update_pay_costs (v_new_allocation_keyflex_id, r_get_cost_lines.cost_id);
               fnd_file.put_line (fnd_file.LOG,
                                     'New Balance String - '
                                  || v_keyflex_record.cost_allocation_keyflex_id
                                  || '-'
                                  || v_keyflex_record.payroll_id
                                  || '-'
                                  || v_keyflex_record.assignment_id
                                  || '-'
                                  || (   v_keyflex_record.segment1
                                      || '.'
                                      || v_keyflex_record.segment2
                                      || '.'
                                      || v_keyflex_record.segment3
                                      || '.'
                                      || v_keyflex_record.segment4
                                     )
                                 );
               v_new_allocation_keyflex_id := NULL;
               v_cost_id := NULL;
            EXCEPTION
               WHEN OTHERS
               THEN
                  g_fail_msg := SUBSTR ('Error in Balance String' || '-' || SQLERRM, 1, 240);
                  ttec_error_logging.process_error (application_code      => g_application_code,
                                                    INTERFACE             => g_interface,
                                                    program_name          => g_package,
                                                    module_name           => g_module,
                                                    status                => g_status_warning,
                                                    ERROR_CODE            => SQLCODE,
                                                    error_message         => g_fail_msg,
                                                    label1                => 'Assign ID',
                                                    reference1            => r_get_cost_lines.assignment_id,
                                                    label2                => 'Combination',
                                                    reference2            => g_reference
                                                   );
            END;
         END IF;
      END LOOP;
        -- Version 2.2 (3) <Start>
      BEGIN
         -- Critical Failures from this Package
         ttec_error_logging.log_error_details (p_application        => g_application_code,
                                               p_interface          => g_interface,
                                               p_message_type       => g_status_failure,
                                               p_message_label      => 'CRITICAL ERRORS - FAILURE',
                                               p_request_id         => g_request_id
                                              );
         -- Warnings from this Package
         ttec_error_logging.log_error_details (p_application        => g_application_code,
                                               p_interface          => g_interface,
                                               p_message_type       => g_status_warning,
                                               p_message_label      => 'Additional Warning Messages',
                                               p_request_id         => g_request_id
                                              );
         ttec_error_logging.log_error_details (p_application        => 'HR',
                                               p_interface          => 'Asgn Cost Rules',
                                               p_message_type       => g_status_failure,
                                               p_message_label      => 'CRITICAL ERRORS - FAILURE',
                                               p_request_id         => g_request_id
                                              );
         -- Warnings from this Package
         ttec_error_logging.log_error_details (p_application        => 'HR',
                                               p_interface          => 'Asgn Cost Rules',
                                               p_message_type       => g_status_warning,
                                               p_message_label      => 'Additional Warning Messages',
                                               p_request_id         => g_request_id
                                              );
      EXCEPTION
         WHEN OTHERS
         THEN
            fnd_file.put_line (fnd_file.LOG, '   Error Reporting Errors / Warnings');
            p_errcode := 1;
      END;

      -- Cleanup Log Table
      BEGIN
         -- Purge old Logging Records for this Interface
         ttec_error_logging.purge_log_errors (p_application      => g_application_code,
                                              p_interface        => g_interface,
                                              p_keep_days        => g_keep_days
                                             );
      EXCEPTION
         WHEN OTHERS
         THEN
            fnd_file.put_line (fnd_file.LOG, 'Error Cleaning up Log tables');
            fnd_file.put_line (fnd_file.LOG, SQLCODE || ': ' || SQLERRM);
            p_errcode := 2;
            p_errbuf := SQLERRM;
      END;
      -- Version 2.2 (3) <End>
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, SQLCODE || ': ' || SQLERRM);
         p_errcode := 2;
         p_errbuf := SQLERRM;
   END main_proc;
END ttec_pay_fin_cust_costing_pkg;
/
show errors;
/