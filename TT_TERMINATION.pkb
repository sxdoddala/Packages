create or replace PACKAGE BODY      Tt_Termination
IS
/* $Header: tt_termination.pkb 1.1 2009/10/07 mdodge ship $ */

/*== START ================================================================================================*\
  Author:  ?
    Date:  ?
    Desc:  This package holds the procedures and functions
           for the custom Mass Termination process

  Modification History:

  Mod#    Date     Author   Description (Include Ticket#)
 -----  --------  --------  --------------------------------------------------------------------------------
   1.0  ?         ?         Initial Version
   1.1  10/07/09  MDodge    Added DFF Context value (now required) to API call for Termed employees
   1.2  05/10/18  Arpita    Chnages to include PHL BG and few chnages in output format
  1.0   04/05/2023 IXPRAVEEN(ARGANO) 	R12.2 Upgrade Remediation
\*== END ==================================================================================================*/

/************************************************************************************/
/*                                  GET TERM REASON CODE                            */
/************************************************************************************/
   PROCEDURE get_term_code (
      p_reason_desc       IN       VARCHAR2,
      p_assignment_type   IN       VARCHAR2,
      p_reason_code       OUT      VARCHAR2
   )
   IS
      l_reason_code   fnd_lookup_values.lookup_code%TYPE;

      CURSOR c_reason_emp
      IS
         (SELECT lookup_code
            FROM fnd_lookup_values
           WHERE meaning = p_reason_desc
             AND lookup_type = 'LEAV_REAS'
             AND enabled_flag = 'Y'
             AND TRUNC (SYSDATE) BETWEEN start_date_active
                                     AND NVL (end_date_active, SYSDATE)
            --AND LANGUAGE = USERENV ('LANG')
         );

      CURSOR c_reason_cwk
      IS
         (SELECT lookup_code
            FROM fnd_lookup_values
           WHERE description = p_reason_desc
             AND lookup_type = 'HR_CWK_TERMINATION_REASONS'
             AND enabled_flag = 'Y'
             AND TRUNC (SYSDATE) BETWEEN start_date_active
                                     AND NVL (end_date_active, SYSDATE)
            --AND LANGUAGE = USERENV ('LANG')
         );
   BEGIN
      -- set global module name for error handling
      g_module_name := 'get_term_reason';

      IF p_assignment_type = 'E'
      THEN
         OPEN c_reason_emp;

         FETCH c_reason_emp
          INTO l_reason_code;

         CLOSE c_reason_emp;
      ELSIF p_assignment_type = 'C'
      THEN
         OPEN c_reason_cwk;

         FETCH c_reason_cwk
          INTO l_reason_code;

         CLOSE c_reason_cwk;
      END IF;

      IF l_reason_code IS NULL
      THEN
         g_error_message := 'Invalid Reason Code in the file';
         g_label2 := 'Reason Code';
         g_secondary_column := p_reason_desc;
         RAISE skip_record;
      ELSE
         p_reason_code := l_reason_code;
      END IF;
   END;

/************************************************************************************/
/*                                  GET Payroll End Date                            */
/************************************************************************************/
   PROCEDURE get_payroll_end_date (
      p_payroll_id       IN       NUMBER,
      p_term_date        IN       DATE,
      p_end_date         OUT      DATE
   ) IS

      CURSOR c_end_date IS
         SELECT end_date
           FROM per_time_periods
          WHERE payroll_id = p_payroll_id
            AND p_term_date BETWEEN start_date AND end_date;

      l_end_date DATE;

   BEGIN
      -- set global module name for error handling
      g_module_name := 'get_payroll_end_date';

         OPEN c_end_date;

         FETCH c_end_date
          INTO l_end_date;

         CLOSE c_end_date;

      IF l_end_date IS NULL
      THEN
         g_error_message := 'Invalid Payroll End Date';
         g_label2 := 'Term Date';
         g_secondary_column := p_term_date;
         RAISE skip_record;
      ELSE
         p_end_date := l_end_date;
      END IF;
   END;

/************************************************************************************/
/*                                  VALIDATE_EMP_NUMBER                             */
/************************************************************************************/
   PROCEDURE get_emp_info (
      p_emp_number              IN       VARCHAR2,
      p_person_id               OUT      NUMBER,
      p_assignment_type         OUT      VARCHAR2,
      p_date_start              OUT      DATE,
      p_object_version_number   OUT      NUMBER,
      p_period_id               OUT      NUMBER,
      p_payroll_id              OUT      NUMBER,
      /* 1.1 Added new OUT param which is the DFF Context value now required in API call */
      p_business_group_id       OUT      NUMBER
   )
   IS
      CURSOR c_emp_info
      IS
         (SELECT --employee
                 papf.person_id,
                 paaf.assignment_type,
                 ppos.date_start,
                 ppos.object_version_number,
                 ppos.period_of_service_id,
                 paaf.payroll_id,
                 ppos.business_group_id    /* 1.1 Return BG_ID value from query as well */
				 --START R12.2 Upgrade Remediation
            /*FROM hr.per_all_people_f papf,		-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
                 hr.per_all_assignments_f paaf,
                 hr.per_periods_of_service ppos*/
			FROM apps.per_all_people_f papf,		--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
                 apps.per_all_assignments_f paaf,
                 apps.per_periods_of_service ppos
--END R12.2.10 Upgrade remediation				 
           WHERE papf.person_id = paaf.person_id
             AND papf.business_group_id IN (325,326,1517)
             AND paaf.period_of_service_id = ppos.period_of_service_id
             AND ppos.actual_termination_date IS NULL
             AND paaf.assignment_type = 'E'
             AND paaf.primary_flag = 'Y'
             AND paaf.effective_start_date =
                                    (SELECT MAX (paaf1.effective_start_date)
                                       FROM per_all_assignments_f paaf1
                                      WHERE papf.person_id = paaf1.person_id)
             AND SYSDATE BETWEEN papf.effective_start_date
                             AND papf.effective_end_date
             AND papf.employee_number = p_emp_number
          UNION
          SELECT --contingent worker
                 papf.person_id,
                 paaf.assignment_type,
                 ppop.date_start,
                 ppop.object_version_number,
                 ppop.period_of_placement_id,
                 paaf.payroll_id,
                 ppop.business_group_id    /* 1.1 Return BG_ID value from query as well */
				 --START R12.2 Upgrade Remediation
            /*FROM hr.per_all_people_f papf,		-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
                 hr.per_all_assignments_f paaf,
                 hr.per_periods_of_placement ppop*/
			FROM apps.per_all_people_f papf,		--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
                 apps.per_all_assignments_f paaf,
                 apps.per_periods_of_placement ppop
--END R12.2.10 Upgrade remediation					 
           WHERE papf.person_id = paaf.person_id
             AND papf.business_group_id IN (325,326,1517)
             AND paaf.assignment_type = 'C'
             AND paaf.primary_flag = 'Y'
             AND paaf.effective_start_date =
                                    (SELECT MAX (paaf1.effective_start_date)
                                       FROM per_all_assignments_f paaf1
                                      WHERE paaf1.person_id = papf.person_id)
             AND TRUNC (SYSDATE) BETWEEN papf.effective_start_date
                                     AND papf.effective_end_date
             AND ppop.date_start = paaf.period_of_placement_date_start
             AND ppop.person_id = paaf.person_id
             AND ppop.actual_termination_date IS NULL
             AND papf.npw_number = p_emp_number);
   BEGIN
      -- set global module name for error handling
      g_module_name := 'get_emp_info';

      OPEN c_emp_info;

      FETCH c_emp_info
       INTO p_person_id,
            p_assignment_type,
            p_date_start,
            p_object_version_number,
            p_period_id,
            p_payroll_id,    /* 1.1 Return BG_ID value from query as well */
            p_business_group_id;

      IF c_emp_info%NOTFOUND
      THEN
         g_label2 := 'Emp Info';
         g_error_message := 'Invalid or Termed Emp Number';
         RAISE skip_record;
      END IF;

      CLOSE c_emp_info;
   END;

--***************************************************************
--*****                  Main procedure                     *****
--***************************************************************
   PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT NUMBER)
   IS
      l_object_version_number        NUMBER                           := NULL;
      l_last_standard_process_date   DATE                             := NULL;
      l_final_process_date           DATE                             := NULL;
      --l_module_name                  cust.ttec_error_handling.module_name%TYPE		-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
                                                          --:= 'Main Procedure';
	  l_module_name                  apps.ttec_error_handling.module_name%TYPE			--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
                                                          := 'Main Procedure';													  
      l_supervisor_warning           BOOLEAN                          := NULL;
      l_event_warning                BOOLEAN                          := NULL;
      l_interview_warning            BOOLEAN                          := NULL;
      l_review_warning               BOOLEAN                          := NULL;
      l_recruiter_warning            BOOLEAN                          := NULL;
      l_asg_future_changes_warning   BOOLEAN                          := NULL;
      l_entries_changed_warning      VARCHAR2 (20)                    := NULL;
      l_pay_proposal_warning         BOOLEAN                          := NULL;
      l_dod_warning                  BOOLEAN                          := NULL;
      l_org_now_no_manager_warning   BOOLEAN                          := NULL;
      l_addl_rights_warning          BOOLEAN                          := NULL;
      l_last_std_process_date_out    DATE := NULL;
      l_person_id                    NUMBER;
      l_assignment_type              VARCHAR2 (20);
      l_date_start                   DATE;
      l_period_id                    NUMBER;
      l_payroll_id                   NUMBER;
      l_bus_grp_id                   NUMBER;
      l_reason_code                  fnd_lookup_values.lookup_code%TYPE;
      l_term_date varchar2 (11);
   BEGIN
      g_records_read := 0;
      g_records_processed := 0;
      g_module_name := NULL;
      -- Out put header information
      apps.Fnd_File.put_line (2, '');
      apps.Fnd_File.put_line (2, 'TeleTech  Termination API Program');
      apps.Fnd_File.put_line (2, '');
      apps.Fnd_File.put_line (2,
                                 ' INTERFACE TIMESTAMP = '
                              || TO_CHAR (SYSDATE, 'dd-mon-yy hh:mm:ss')
                             );
      -- Error output header during Termination API
      apps.Fnd_File.put_line (2, '');
      apps.Fnd_File.put_line (2, 'ERROR REPORT WHILE TERMINATION:');
      apps.Fnd_File.put_line (2, '-------------------------------------');
      apps.Fnd_File.put_line (2, '');
      apps.Fnd_File.put_line
         (2,
          'Emp Num|Term Date|Leaving Reason|Rehire Eligibility|Suceess_Failure_Reason'
         );
      /*apps.Fnd_File.put_line
         (2,
          '---------- ----------------- ----------------               -----------------------------------------------------------------'
         );*/

      FOR sel IN csr_term_people
      LOOP

         g_error_message := NULL;
         g_label2 := NULL;
         g_secondary_column := NULL;
         g_records_read := g_records_read + 1;
         l_term_date := NULL;

         BEGIN
            l_object_version_number := NULL;
            l_person_id := NULL;
            l_assignment_type := NULL;
            l_date_start := NULL;
            l_object_version_number := NULL;
            l_period_id := NULL;
            l_last_standard_process_date := NULL;
            l_final_process_date := NULL;
            l_supervisor_warning := NULL;
            l_event_warning := NULL;
            l_interview_warning := NULL;
            l_review_warning := NULL;
            l_recruiter_warning := NULL;
            l_asg_future_changes_warning := NULL;
            l_entries_changed_warning := NULL;
            l_pay_proposal_warning := NULL;
            l_dod_warning := NULL;
            l_org_now_no_manager_warning := NULL;
            l_addl_rights_warning := NULL;
            l_last_std_process_date_out := NULL;

            g_primary_column := sel.employee_number;
            l_term_date := to_char(sel.term_date,'DD-MON-YYYY');

            get_emp_info (sel.employee_number,
                          l_person_id,
                          l_assignment_type,
                          l_date_start,
                          l_object_version_number,
                          l_period_id,
                          l_payroll_id,
                          l_bus_grp_id  /* 1.1 Return BG_ID value from procedure as well */
                         );

            get_term_code (sel.term_reason, l_assignment_type, l_reason_code);

            get_payroll_end_date(l_payroll_id, sel.term_date, l_last_standard_process_date);

            IF l_assignment_type = 'E'
            THEN        --employee
               Hr_Ex_Employee_Api.actual_termination_emp
                  (p_validate                        => FALSE,
                   p_effective_date                  => SYSDATE,
                   p_period_of_service_id            => l_period_id,
                   p_object_version_number           => l_object_version_number,
                   p_actual_termination_date         => sel.term_date,
                   p_last_standard_process_date      => l_last_standard_process_date,
                   p_leaving_reason                  => l_reason_code,
                   p_attribute_category              => l_bus_grp_id, /* 1.1 Pass BG_ID into API call as Context */
                   p_attribute9                      => sel.rehire_eligible,
                   p_attribute13                     => sel.emp_leave_an,
                   p_attribute10                     => sel.exit_intw_comp,
                   --OUT Parameters
                   p_last_std_process_date_out       => l_last_std_process_date_out,
                   p_supervisor_warning              => l_supervisor_warning,
                   p_event_warning                   => l_event_warning,
                   p_interview_warning               => l_interview_warning,
                   p_review_warning                  => l_review_warning,
                   p_recruiter_warning               => l_recruiter_warning,
                   p_asg_future_changes_warning      => l_asg_future_changes_warning,
                   p_entries_changed_warning         => l_entries_changed_warning,
                   p_pay_proposal_warning            => l_pay_proposal_warning,
                   p_dod_warning                     => l_dod_warning
                  );

            ELSIF l_assignment_type = 'C'
            THEN     -- contingent worker
               Hr_Contingent_Worker_Api.terminate_placement
                  (p_validate                        => FALSE,
                   p_effective_date                  => SYSDATE,
                   p_person_id                       => l_person_id,
                   p_date_start                      => l_date_start,
                   p_object_version_number           => l_object_version_number,
                   p_actual_termination_date         => sel.term_date,
                   /*
                   The following two parameters are available for internal-use only until
                       payroll support for contingent workers is introduced. Setting them has
                       no impact.
                   */
                   p_final_process_date              => l_final_process_date,
                   p_last_standard_process_date      => l_last_standard_process_date,
                   p_attribute1                      => sel.rehire_eligible,
                   p_termination_reason              => l_reason_code,
                   p_supervisor_warning              => l_supervisor_warning,
                   p_event_warning                   => l_event_warning,
                   p_interview_warning               => l_interview_warning,
                   p_review_warning                  => l_review_warning,
                   p_recruiter_warning               => l_recruiter_warning,
                   p_asg_future_changes_warning      => l_asg_future_changes_warning,
                   p_entries_changed_warning         => l_entries_changed_warning,
                   p_pay_proposal_warning            => l_pay_proposal_warning,
                   p_dod_warning                     => l_dod_warning,
                   p_org_now_no_manager_warning      => l_org_now_no_manager_warning,
                   p_addl_rights_warning             => l_addl_rights_warning
                  );


            END IF;

            COMMIT;

            apps.Fnd_File.put_line (2,
                                          sel.employee_number
                                       ||'|'
                                       || l_term_date
                                       || '|'
                                       || NVL(sel.term_reason, ' ')
                                       || '|'
                                       || NVL(sel.rehire_eligible, ' ')
                                       || '|'
                                       || 'SUCCESS'
                                      );
            g_records_processed := g_records_processed + 1;
         EXCEPTION
            WHEN skip_record
            THEN
			--cust.ttec_process_error (c_application_code,		-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
               apps.ttec_process_error (c_application_code,			--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
                                        c_interface,
                                        c_program_name,
                                        g_module_name,
                                        c_warning_status,
                                        SQLCODE,
                                        g_error_message,
                                        g_label1,
                                        g_primary_column,
                                        g_label2,
                                        g_secondary_column
                                       );
               apps.Fnd_File.put_line (2,
                                          sel.employee_number
                                       ||'|'
                                       || l_term_date
                                       || '|'
                                       || NVL(sel.term_reason, ' ')
                                       || '|'
                                       || NVL(sel.rehire_eligible, ' ')
                                       || '|'
                                       || RPAD (NVL (g_error_message, ' '),
                                                150)
                                      );

            DBMS_OUTPUT.PUT_LINE(  sel.employee_number
                                       || ' '
                                       || l_term_date
                                       || ' '
                                       || NVL(sel.term_reason, ' ')
                                       || '|'
                                       || NVL(sel.rehire_eligible, ' ')
                                       || ' '
                                       || RPAD (NVL (g_error_message, ' '),
                                                150));

            WHEN OTHERS
            THEN
               l_module_name := 'API Section';
               --cust.ttec_process_error (c_application_code,		-- Commented code by IXPRAVEEN-ARGANO, 04-May-2023
			   apps.ttec_process_error (c_application_code,			--  code Added by IXPRAVEEN-ARGANO, 04-May-2023
                                        c_interface,
                                        c_program_name,
                                        l_module_name,
                                        c_failure_status,
                                        SQLCODE,
                                        SQLERRM,
                                        g_label1,
                                        g_primary_column
                                       );
               apps.Fnd_File.put_line (2,
                                          sel.employee_number
                                       || '|'
                                       || l_term_date
                                       || '|'
                                       || NVL(sel.term_reason, ' ')
                                       || '|'
                                       || NVL(sel.rehire_eligible, ' ')
                                       || '|'
                                       || 'API Error:'|| RPAD (NVL (SQLERRM, ' '), 240)
                                      );

         DBMS_OUTPUT.PUT_LINE  (sel.employee_number
                                       || ' '
                                       || l_term_date
                                       || ' '
                                       || NVL(sel.term_reason, ' ')
                                       || '|'
                                       || NVL(sel.rehire_eligible, ' ')
                                       || ' '
                                       || 'API Error:'|| RPAD (NVL (SQLERRM, ' '), 240));

         END;
      END LOOP;

      COMMIT;

      DBMS_OUTPUT.PUT_LINE('Total Read: ' || g_records_read );
      DBMS_OUTPUT.PUT_LINE('Total Processed: ' || g_records_processed);

      Fnd_File.put_line (2, '');
      Fnd_File.put_line (2, 'Summary:');
      Fnd_File.put_line (2, 'Total Read: ' || g_records_read);
      Fnd_File.put_line (2, 'Total Processed: ' || g_records_processed);
      Fnd_File.put_line (2, 'Total Errors: ' || TO_CHAR(g_records_read - g_records_processed));
   END;                                                                 --main
END Tt_Termination;                                                    -- body
/
show errors;
/