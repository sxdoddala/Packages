create or replace PACKAGE BODY      ttec_trp_401k_loan_int
AS
--
-- Program Name:  ttec_trp_401k_loan_int
-- /* $Header: ttec_trp_401k_loan_int.pkb 1.0 2020/02/24  chchan ship $ */
--
-- /*== START ================================================================================================*\
--    Author: Christiane Chan
--      Date: 24-FEB-2020

   -- Call From: Concurrent Program ->TTEC TRP 401K Loan Update
--      Desc: Copy from the Old sql code ->TTEC_BAML_401K_DEFERRAL_INT Package
--            This program will accomplish the following:
--            Read employee information which was supplied by TRP
--            from a temporary table
--            A report is generated for all termed employees received
--            from TRP.
--           Then the program checks if active employee as supplied by
--           TRP is active in the system, If not,the information on this
--           employee is written in an error file.
--           If employee is active, the employee's information is process
--           as follows:
--
--          If amortize an existing 401K loan amount call
--                      PAY_ELEMENT_ENTRY_API.UPDATE_ELEMENT_ENTRY
--
--          IF newly issued 401K loan amount Rec Type 384 call
--                  PAY_ELEMENT_ENTRY_API.CREATE_ELEMENT_ENTRY
--
--          IF payoff/offset existing 401K amount  call
--                  PAY_ELEMENT_ENTRY_API.DELETE_ELEMENT_ENTRY
--
--Input/Output Parameters
--
--Tables Accessed: CUST.ttec_us_NewLoan_tbl def
--                 hr.per_all_people_f emp
--                 per_all_assignments_f asg
--                 hr.hr_locations_all loc
--                 hr.per_person_types
--                 hr.pay_element_links_f
--                 hr.pay_element_types_f
--                 hr.pay_element_entry_values_f
--                 hr.pay_input_values_f
--                 sys.v$database
--
--
--Tables Modified: PAY_ELEMENT_ENTRY_VALUES_F
--
--Procedures Called: PY_ELEMENT_ENTRY.create_element_entry
--                   PAY_ELEMENT_ENTRY_API.DELETE_ELEMENT_ENTRY
--                  PAY_ELEMENT_ENTRY_API.UPDATE_ELEMENT_ENTRY
--
--     Parameter Description:
--
--      p_process_date: Process Date
--
--       Oracle Standard Parameters:
--
--   Modification History:
--
--  Version    Date       Author      Description (Include Ticket--)
--  -------  ----------  --------     ------------------------------------------------------------------------------
--      1.0  02/25/2020   CChan       Initial Version T-ROWE Price Loan Update
--      1.0  04/MAY/2023   RXNETHI-ARGANO R12.2 Upgrade Remediation
--------------------------------------------------------------------------------------------------------------------
   --v_module            cust.ttec_error_handling.module_name%TYPE   := 'Main';   --code commented by RXNETHI-ARGANO,04/05/23
   v_module            apps.ttec_error_handling.module_name%TYPE   := 'Main';     --code added by RXNETHI-ARGANO,04/05/23
   v_loc               NUMBER;
   v_msg               VARCHAR2 (2000);
   v_rec               VARCHAR2 (5000);
   v_employee_number   VARCHAR2 (60);
   v_NewLoan_pct      NUMBER;
   v_process_date     DATE;
   v_process_type     VARCHAR2 (03);
   v_plan_entry_date   DATE;
   v_element_name      VARCHAR2 (60);
   v_update_status     VARCHAR2 (60);

--************************************************************************************--
--*                          GET ASSIGNMENT ID                                       *--
--************************************************************************************--
   FUNCTION get_prior_input_value (
      p_emp_no         VARCHAR2,
      p_element_name   VARCHAR2,
      p_input_value_type   VARCHAR2, /* 2.0 */
      p_date           DATE
   )
      RETURN VARCHAR2
   AS
      v_text   VARCHAR2 (10);
   BEGIN

     apps.fnd_file.put_line (apps.fnd_file.log, '*****************Procedure >>>get_prior_input_value');
     apps.fnd_file.put_line (apps.fnd_file.log, 'p_element_name...........:'||p_element_name);
     apps.fnd_file.put_line (apps.fnd_file.log, 'p_input_value_type ......:'||p_input_value_type );
     apps.fnd_file.put_line (apps.fnd_file.log, 'p_date ..................:'||p_date  );
      SELECT DISTINCT peevf.screen_entry_value
                 INTO v_text
                 FROM per_all_people_f papfe,
                      per_all_assignments_f paf,
                      per_periods_of_service ppos,
                      pay_element_types_f pet,
                      pay_element_entries_f pee,
                      pay_input_values_f pivf,
                      pay_element_entry_values_f peevf
                WHERE papfe.business_group_id = 325
                  AND papfe.person_id = paf.person_id
                  AND paf.primary_flag = 'Y'
                  AND pet.element_type_id = pee.element_type_id
                  AND pee.assignment_id = paf.assignment_id
                  AND pivf.element_type_id = pet.element_type_id
                  AND pee.element_entry_id = peevf.element_entry_id
                  AND pivf.input_value_id = peevf.input_value_id
                  AND papfe.employee_number = p_emp_no
                  AND paf.person_id = ppos.person_id
                  AND pet.element_name = p_element_name
                  --AND pivf.NAME = 'Percentage'  /* 2.0 */
                  AND pivf.NAME = p_input_value_type /* 2.0 */
                  AND paf.period_of_service_id = ppos.period_of_service_id
                  AND p_date - 1 BETWEEN pet.effective_start_date
                                     AND NVL (pet.effective_end_date,
                                              p_date - 1
                                             )
                  AND p_date - 1 BETWEEN pee.effective_start_date
                                     AND NVL (pee.effective_end_date,
                                              p_date - 1
                                             )
                  AND p_date - 1 BETWEEN paf.effective_start_date
                                     AND NVL (paf.effective_end_date,
                                              p_date - 1
                                             )
                  AND p_date - 1 BETWEEN pivf.effective_start_date
                                     AND NVL (pivf.effective_end_date,
                                              p_date - 1
                                             )
                  AND p_date - 1 BETWEEN peevf.effective_start_date
                                     AND NVL (peevf.effective_end_date,
                                              p_date - 1
                                             )
                  AND p_date - 1 BETWEEN papfe.effective_start_date
                                     AND papfe.effective_end_date;
     apps.fnd_file.put_line (apps.fnd_file.log, 'Return Value.........:'||v_text  );
      RETURN (v_text);
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         apps.fnd_file.put_line (apps.fnd_file.log, 'NO_DATA_FOUND'  );
         v_text := NULL;
         RETURN (v_text);
      WHEN TOO_MANY_ROWS
      THEN
         apps.fnd_file.put_line (apps.fnd_file.log, 'TOO_MANY_ROWS'  );
         v_text := NULL;
         RETURN (v_text);
      WHEN OTHERS
      THEN
         apps.fnd_file.put_line (apps.fnd_file.log, 'OTHERS'  );
         v_text := NULL;
         RETURN (v_text);
   END;

   PROCEDURE get_assignment_id (
      v_ssn                    IN       VARCHAR2,
      v_employee_number        OUT      VARCHAR2,
      v_full_name              OUT      VARCHAR2,
      p_assignment_id          OUT      NUMBER,
      p_business_group_id      OUT      NUMBER,
      p_payroll_id             OUT      NUMBER, /* 1.3 */
      p_location_id            OUT      NUMBER, /* 1.3 */
      p_effective_start_date   OUT      DATE,
      p_effective_end_date     OUT      DATE,
      p_process_status         OUT      VARCHAR2
   )
   IS
   BEGIN
      --             l_error_message    := NULL;
      SELECT DISTINCT asg.assignment_id, emp.employee_number,
                      (emp.first_name || ' ' || emp.last_name
                      ),
                      asg.business_group_id, asg.effective_start_date,
                      asg.effective_end_date
                      ,asg.payroll_id,asg.location_id /* 1.3 */
                 INTO p_assignment_id, v_employee_number,
                      v_full_name,
                      p_business_group_id, p_effective_start_date,
                      p_effective_end_date
                      ,p_payroll_id,p_location_id /* 1.3 */
                 --FROM hr.per_all_assignments_f asg, hr.per_all_people_f emp --code commented by RXNETHI-ARGANO, 04/MAY/2023
                 FROM apps.per_all_assignments_f asg, apps.per_all_people_f emp --code added by RXNETHI-ARGANO, 04/MAY/2023
				WHERE emp.national_identifier = v_ssn
                  AND emp.person_id = asg.person_id
                  AND g_as_of_date BETWEEN emp.effective_start_date
                                          AND emp.effective_end_date
                  AND asg.primary_flag = 'Y'
                  AND asg.assignment_type = 'E'
                  AND asg.effective_start_date =
                         (SELECT MAX (asg1.effective_start_date)
                            FROM per_all_assignments_f asg1
                           WHERE asg1.person_id = asg.person_id
                             AND asg1.primary_flag = 'Y'
                             AND asg1.assignment_type = 'E');

      p_process_status := 'Found';
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         p_process_status := 'No Assignment';
         l_errorlog_output := (RPAD (v_ssn, 29) || 'No Assignment');
         v_errorlog_count := v_errorlog_count + 1;
         apps.fnd_file.put_line (apps.fnd_file.LOG, l_errorlog_output);
      -- RAISE skip_record;
      WHEN TOO_MANY_ROWS
      THEN
         p_process_status := 'Too Many Assignments';
         l_errorlog_output := (RPAD (v_ssn, 29) || 'Too Many Assignments');
         v_errorlog_count := v_errorlog_count + 1;
         apps.fnd_file.put_line (apps.fnd_file.LOG, l_errorlog_output);
      --RAISE skip_record;
      WHEN OTHERS
      THEN
         p_process_status := 'Other Assignment Issue';
         l_errorlog_output := (RPAD (v_ssn, 29) || 'Other Assignment Issue');
         v_errorlog_count := v_errorlog_count + 1;
         apps.fnd_file.put_line (apps.fnd_file.LOG, l_errorlog_output);
   --RAISE skip_record;
   END;

   ---***********************************  Get Location Code ********************************-----
   PROCEDURE get_location (
      v_ssn              IN       VARCHAR2,
      v_full_name        OUT      VARCHAR2,
      v_location_code    OUT      VARCHAR2,
      p_process_status   OUT      VARCHAR2
   )
   IS
      l_location_code   VARCHAR2 (150) := NULL;
      l_full_name       VARCHAR2 (150) := NULL;
   BEGIN
      SELECT DISTINCT loc.location_code,
                      (emp.first_name || ' ' || emp.last_name
                      )
                 INTO l_location_code,
                      l_full_name
                 /*
				 START R12.2 Upgrade Remediation
				 code commented by RXNETHI-ARGANO, 04/MAY/2023
				 FROM hr.per_all_people_f emp,
                      hr.per_all_assignments_f asg,
                      hr.hr_locations_all loc*/
                 --code added by RXNETHI-ARGANO, 04/MAY/2023
				 FROM apps.per_all_people_f emp,
                      apps.per_all_assignments_f asg,
                      apps.hr_locations_all loc
				 --END R12.2 Upgrade Remediation
                WHERE emp.person_id = asg.person_id
                  AND loc.location_id = asg.location_id
                  AND asg.primary_flag = 'Y'
                  AND asg.assignment_type = 'E'
                  AND g_as_of_date BETWEEN emp.effective_start_date
                                          AND emp.effective_end_date
                  AND g_as_of_date BETWEEN asg.effective_start_date
                                          AND asg.effective_end_date
                  AND emp.national_identifier = v_ssn;

      v_location_code := l_location_code;
      v_full_name := l_full_name;
      p_process_status := 'Found';
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         p_process_status := 'No Location';
         l_errorlog_output := (RPAD (v_ssn, 29) || 'No Location');
         v_errorlog_count := v_errorlog_count + 1;
         apps.fnd_file.put_line (apps.fnd_file.LOG, l_errorlog_output);
      --RAISE skip_record;
      WHEN TOO_MANY_ROWS
      THEN
         p_process_status := 'Too Many Locations';
         l_errorlog_output := (RPAD (v_ssn, 29) || 'Too Many Locations');
         v_errorlog_count := v_errorlog_count + 1;
         apps.fnd_file.put_line (apps.fnd_file.LOG, l_errorlog_output);
      --RAISE skip_record;
      WHEN OTHERS
      THEN
         p_process_status := 'No Other Location';
         l_errorlog_output := (RPAD (v_ssn, 29) || 'No Other Location');
         v_errorlog_count := v_errorlog_count + 1;
         apps.fnd_file.put_line (apps.fnd_file.LOG, l_errorlog_output);
   --RAISE skip_record;
   END;

--***************************************************************
--*****                  GET PERSON TYPE                *****
--***************************************************************
--get_person_type(sel.employee_number, l_system_person_type);
   PROCEDURE get_person_type (
      v_ssn                   IN       VARCHAR2,
      v_person_id             OUT      NUMBER,
      v_assignment_id         IN       NUMBER,
      v_pay_basis_id          OUT      NUMBER,
      v_employment_category   OUT      VARCHAR2,
      v_people_group_id       OUT      NUMBER,
      v_full_name             OUT      VARCHAR,
      v_system_person_type    OUT      VARCHAR2,
      p_process_status        OUT      VARCHAR2
   )
   IS
      v_effective_end_date   DATE := NULL;
   BEGIN
      SELECT DISTINCT asg.person_id, asg.effective_end_date,
                      asg.pay_basis_id, asg.employment_category,
                      asg.people_group_id, TYPES.system_person_type,
                      (emp.first_name || ' ' || emp.last_name
                      )
                 INTO v_person_id, v_effective_end_date,
                      v_pay_basis_id, v_employment_category,
                      v_people_group_id, v_system_person_type,
                      v_full_name
                 /*
				 START R12.2 Upgrade Remediation
				 code commented by RXNETHI-ARGANO, 04/MAY/2023
				 FROM hr.per_all_assignments_f asg,
                      hr.per_all_people_f emp,
                      hr.per_person_types TYPES*/
                 --code added by RXNETHI-ARGANO, 04/MAY/2023
				 FROM apps.per_all_assignments_f asg,
                      apps.per_all_people_f emp,
                      apps.per_person_types TYPES
                WHERE emp.person_id = asg.person_id
                  AND TYPES.person_type_id = emp.person_type_id
                  AND asg.primary_flag = 'Y'
                  AND asg.assignment_type = 'E'
                  AND g_as_of_date BETWEEN emp.effective_start_date
                                          AND emp.effective_end_date
                  AND g_as_of_date BETWEEN asg.effective_start_date
                                          AND asg.effective_end_date
                  AND emp.national_identifier = v_ssn;

      p_process_status := 'Found';
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         p_process_status := 'No Person Type';
         l_errorlog_output :=
            (   RPAD (v_ssn, 29)
             || RPAD (v_person_id, 20)
             || LPAD (v_effective_end_date, 12)
             || 'No Person Type'
            );
         v_errorlog_count := v_errorlog_count + 1;
         apps.fnd_file.put_line (apps.fnd_file.LOG, l_errorlog_output);
      -- RAISE skip_record;
      WHEN TOO_MANY_ROWS
      THEN
         p_process_status := 'Too Many Person Types';
         l_errorlog_output := (RPAD (v_ssn, 29) || 'Too Many Person Types');
         v_errorlog_count := v_errorlog_count + 1;
         apps.fnd_file.put_line (apps.fnd_file.LOG, l_errorlog_output);
      -- RAISE skip_record;
      WHEN OTHERS
      THEN
         p_process_status := 'No Person Type';
         l_errorlog_output :=
            (   RPAD (v_ssn, 29)
             || RPAD (v_person_id, 20)
             || LPAD (v_effective_end_date, 12)
             || 'No Person Type'
            );
         v_errorlog_count := v_errorlog_count + 1;
         apps.fnd_file.put_line (apps.fnd_file.LOG, l_errorlog_output);
   --RAISE skip_record;
   END;

----*******************************************************************---------------------
--get_employee_status(sel.social_number,l_system_person_status);
   PROCEDURE get_termed_status (
      v_ssn                    IN       VARCHAR2,
      v_system_person_status   OUT      VARCHAR2
   )
   IS
      l_system_person_status   VARCHAR2 (50) := NULL;
   BEGIN
      SELECT DISTINCT NVL (amdtl.user_status, sttl.user_status)
                 INTO l_system_person_status
                 /*
				 START R12.2 Upgrade Remediaiton
				 code commented by FROM hr.per_all_people_f emp,
                      hr.per_all_assignments_f asg,
                      hr.per_person_types TYPES,
                      hr.per_ass_status_type_amends_tl amdtl,
                      hr.per_assignment_status_types_tl sttl,
                      hr.per_assignment_status_types st,
                      hr.per_ass_status_type_amends amd*/
				 --code added by RXNETHI-ARGANO, 04/MAY/2023
                 FROM apps.per_all_people_f emp,
                      apps.per_all_assignments_f asg,
                      apps.per_person_types TYPES,
                      apps.per_ass_status_type_amends_tl amdtl,
                      apps.per_assignment_status_types_tl sttl,
                      apps.per_assignment_status_types st,
                      apps.per_ass_status_type_amends amd
                --END R12.2 Upgrade Remediation					  
                WHERE emp.person_id = asg.person_id
                  AND asg.assignment_status_type_id =
                                                  st.assignment_status_type_id
                  AND asg.assignment_status_type_id = amd.assignment_status_type_id(+)
                  AND asg.business_group_id + 0 = amd.business_group_id(+) + 0
                  AND TYPES.person_type_id = emp.person_type_id
                  AND asg.primary_flag = 'Y'
                  AND asg.assignment_type = 'E'
                  AND asg.business_group_id = 325
                  AND st.assignment_status_type_id =
                                                sttl.assignment_status_type_id
                  AND sttl.LANGUAGE = USERENV ('LANG')
                  AND amd.ass_status_type_amend_id = amdtl.ass_status_type_amend_id(+)
                  AND DECODE (amdtl.ass_status_type_amend_id,
                              NULL, '1',
                              amdtl.LANGUAGE
                             ) =
                         DECODE (amdtl.ass_status_type_amend_id,
                                 NULL, '1',
                                 USERENV ('LANG')
                                )
                  AND g_as_of_date BETWEEN emp.effective_start_date
                                          AND emp.effective_end_date
                  AND g_as_of_date BETWEEN asg.effective_start_date
                                          AND asg.effective_end_date
                  AND emp.national_identifier = v_ssn;

      --and rownum < 2;
      v_system_person_status := l_system_person_status;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         l_errorlog_output := (RPAD (v_ssn, 29) || 'No Employee Status');
         v_errorlog_count := v_errorlog_count + 1;
         apps.fnd_file.put_line (apps.fnd_file.LOG, l_errorlog_output);
         RAISE skip_record3;
      WHEN TOO_MANY_ROWS
      THEN
         l_errorlog_output :=
                            (RPAD (v_ssn, 29) || 'Too Many Employees Status'
                            );
         v_errorlog_count := v_errorlog_count + 1;
         apps.fnd_file.put_line (apps.fnd_file.LOG, l_errorlog_output);
         RAISE skip_record3;
      WHEN OTHERS
      THEN
         l_errorlog_output := (RPAD (v_ssn, 29) || 'Other Reason for Status');
         v_errorlog_count := v_errorlog_count + 1;
         apps.fnd_file.put_line (apps.fnd_file.LOG, l_errorlog_output);
         RAISE skip_record3;
   END;

----***************************************************************************-------------

   ---**************************************************************************************
--get_employee_status(sel.social_number,l_system_person_status);
   PROCEDURE get_employee_status (
      v_ssn                    IN       VARCHAR2,
      v_full_name              OUT      VARCHAR2,
      v_system_person_status   OUT      VARCHAR2,
      p_process_status         OUT      VARCHAR2
   )
   IS
      l_system_person_status   VARCHAR2 (50) := NULL;
   BEGIN
      SELECT DISTINCT NVL (amdtl.user_status, sttl.user_status),
                      (emp.first_name || ' ' || emp.last_name
                      )
                 INTO l_system_person_status,
                      v_full_name
                 /*
				 START R12.2 Upgrade Remediation
				 code commented by RXNETHI-ARGANO, 04/MAY/2023
				 FROM hr.per_all_people_f emp,
                      hr.per_all_assignments_f asg,
                      hr.per_person_types TYPES,
                      hr.per_ass_status_type_amends_tl amdtl,
                      hr.per_assignment_status_types_tl sttl,
                      hr.per_assignment_status_types st,
                      hr.per_ass_status_type_amends amd */
				 --code added by RXNETHI-ARGANO, 04/MAY/2023
				 FROM apps.per_all_people_f emp,
                      apps.per_all_assignments_f asg,
                      apps.per_person_types TYPES,
                      apps.per_ass_status_type_amends_tl amdtl,
                      apps.per_assignment_status_types_tl sttl,
                      apps.per_assignment_status_types st,
                      apps.per_ass_status_type_amends amd
                 --END R12.2 Upgrade Remediation					  
                WHERE emp.person_id = asg.person_id
                  AND asg.assignment_status_type_id =
                                                  st.assignment_status_type_id
                  AND asg.assignment_status_type_id = amd.assignment_status_type_id(+)
                  AND asg.business_group_id + 0 = amd.business_group_id(+) + 0
                  AND TYPES.person_type_id = emp.person_type_id
                  AND asg.primary_flag = 'Y'
                  AND asg.assignment_type = 'E'
                  AND asg.business_group_id = 325
                  AND st.assignment_status_type_id =
                                                sttl.assignment_status_type_id
                  AND sttl.LANGUAGE = USERENV ('LANG')
                  AND amd.ass_status_type_amend_id = amdtl.ass_status_type_amend_id(+)
                  AND DECODE (amdtl.ass_status_type_amend_id,
                              NULL, '1',
                              amdtl.LANGUAGE
                             ) =
                         DECODE (amdtl.ass_status_type_amend_id,
                                 NULL, '1',
                                 USERENV ('LANG')
                                )
                  AND g_as_of_date BETWEEN emp.effective_start_date
                                          AND emp.effective_end_date
                  AND asg.effective_start_date = (SELECT MAX(asg2.effective_start_date)
                                                  --FROM hr.per_all_assignments_f asg2 --code commented by RXNETHI-ARGANO, 04/MAY/2023
												  FROM apps.per_all_assignments_f asg2 --code added by RXNETHI-ARGANO, 04/MAY/2023
                                                  WHERE asg2.PERSON_ID = emp.PERSON_ID
                                                  AND asg2.effective_start_date <= g_as_of_date )
--                  AND g_as_of_date BETWEEN asg.effective_start_date
--                                          AND asg.effective_end_date
                  AND emp.national_identifier = v_ssn;

      --and rownum < 2;
      v_system_person_status := l_system_person_status;
      p_process_status := 'Found';
   --v_system_person_status := l_system_person_status;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         p_process_status := 'No Employee Status';
         l_errorlog_output := (RPAD (v_ssn, 29) || 'No Employee Status');
         v_errorlog_count := v_errorlog_count + 1;
         apps.fnd_file.put_line (apps.fnd_file.LOG, l_errorlog_output);
      -- RAISE skip_record;
      WHEN TOO_MANY_ROWS
      THEN
         p_process_status := 'Too Many Employees Status';
         l_errorlog_output :=
                            (RPAD (v_ssn, 29) || 'Too Many Employees Status'
                            );
         v_errorlog_count := v_errorlog_count + 1;
         apps.fnd_file.put_line (apps.fnd_file.LOG, l_errorlog_output);
      --RAISE skip_record;
      WHEN OTHERS
      THEN
         p_process_status := 'Other Reason for Status';
         l_errorlog_output := (RPAD (v_ssn, 29) || 'Other Reason for Status');
         v_errorlog_count := v_errorlog_count + 1;
         apps.fnd_file.put_line (apps.fnd_file.LOG, l_errorlog_output);
   --RAISE skip_record;
   END;

----***************************************************************************-------------

   --***************************************************************
--*****                  GET Element Link ID                *****
--***************************************************************
   PROCEDURE get_element_link_id (
      v_ssn                   IN       VARCHAR2,
      v_element_name          IN       VARCHAR2,
      v_business_group_id     IN       NUMBER,
      v_pay_basis_id          IN       NUMBER,
      v_employment_category   IN       VARCHAR2,
      v_people_group_id       IN       NUMBER,
      v_payroll_id            IN       NUMBER, /* 1.3 */
      v_location_id           IN       NUMBER, /* 1.3 */
      v_element_link_id       OUT      NUMBER,
      p_process_status        OUT      VARCHAR2
   )
   IS
   BEGIN

         apps.fnd_file.put_line (apps.fnd_file.LOG, '       v_pay_basis_id>> '||v_pay_basis_id); /* 1.3 */
         apps.fnd_file.put_line (apps.fnd_file.LOG, 'v_employment_category>> '||v_employment_category); /* 1.3 */
         apps.fnd_file.put_line (apps.fnd_file.LOG, '    v_people_group_id>> '||v_people_group_id );     /* 1.3 */
         apps.fnd_file.put_line (apps.fnd_file.LOG, '         Element Name>> '||v_element_name );     /* 1.3 */
         apps.fnd_file.put_line (apps.fnd_file.LOG, '         v_payroll_id>> '||v_payroll_id  );     /* 1.3 */
         apps.fnd_file.put_line (apps.fnd_file.LOG, '        v_location_id>> '||v_location_id );     /* 1.3 */

      SELECT LINK.element_link_id
        INTO v_element_link_id
        --FROM hr.pay_element_links_f LINK, hr.pay_element_types_f TYPES --code commented by RXNETHI-ARGANO, 04/MAY/2023
        FROM apps.pay_element_links_f LINK, apps.pay_element_types_f TYPES --code added by RXNETHI-ARGANO, 04/MAY/2023
	   WHERE LINK.element_type_id = TYPES.element_type_id
         AND LINK.business_group_id = v_business_group_id
         AND TYPES.element_name = v_element_name
         AND ( (v_payroll_id is null and link.LOCATION_ID = v_location_id)  /* 1.3 */
              OR (v_payroll_id is not null and link.LINK_TO_ALL_PAYROLLS_FLAG = 'Y') /* 1.3 */
         )
         AND NVL (LINK.employment_category, v_employment_category) =
                                                         v_employment_category
         AND NVL (LINK.people_group_id, v_people_group_id) = v_people_group_id
         AND (   (TYPES.effective_end_date >= g_as_of_date)
              OR (TYPES.effective_end_date IS NULL)
             )                                       --  v2.0 Wasim added this
         AND NVL (LINK.pay_basis_id, v_pay_basis_id) = v_pay_basis_id;

      p_process_status := 'Found';
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         p_process_status := 'Element Link ID does not exist';
         l_errorlog_output :=
            (   RPAD (v_ssn, 29)
             || RPAD (v_element_name, 20)
             || LPAD (v_business_group_id, 3)
            );
         v_errorlog_count := v_errorlog_count + 1;
         apps.fnd_file.put_line (apps.fnd_file.LOG, l_errorlog_output);
      --RAISE skip_record;
      WHEN TOO_MANY_ROWS
      THEN
         p_process_status := 'Too Many Link IDs';
         l_errorlog_output := (RPAD (v_ssn, 29) || 'Too Many Link IDs');
         v_errorlog_count := v_errorlog_count + 1;
         apps.fnd_file.put_line (apps.fnd_file.LOG, '       v_pay_basis_id>> '||v_pay_basis_id); /* 1.3 */
         apps.fnd_file.put_line (apps.fnd_file.LOG, 'v_employment_category>> '||v_employment_category); /* 1.3 */
         apps.fnd_file.put_line (apps.fnd_file.LOG, '   v_people_group_id >> '||v_people_group_id );     /* 1.3 */
         apps.fnd_file.put_line (apps.fnd_file.LOG, '        Element Name >> '||v_element_name );     /* 1.3 */
         apps.fnd_file.put_line (apps.fnd_file.LOG, '               Error >> '||p_process_status||' '||l_errorlog_output);
      --RAISE skip_record;
      WHEN OTHERS
      THEN
         p_process_status := 'Element Link ID Error';
         l_errorlog_output :=
            (   RPAD (v_ssn, 29)
             || RPAD (v_element_name, 20)
             || LPAD (v_business_group_id, 3)
            );
         v_errorlog_count := v_errorlog_count + 1;
         apps.fnd_file.put_line (apps.fnd_file.LOG, '       v_pay_basis_id>> '||v_pay_basis_id); /* 1.3 */
         apps.fnd_file.put_line (apps.fnd_file.LOG, 'v_employment_category>> '||v_employment_category); /* 1.3 */
         apps.fnd_file.put_line (apps.fnd_file.LOG, '   v_people_group_id >> '||v_people_group_id );     /* 1.3 */
         apps.fnd_file.put_line (apps.fnd_file.LOG, '        Element Name >> '||v_element_name );     /* 1.3 */
         apps.fnd_file.put_line (apps.fnd_file.LOG, '               Error >> '||p_process_status||' '||l_errorlog_output);

   --RAISE skip_record;
   END;

--***************************************************Create Element API********************************************

   --***************************************************************
--*****               Create Element Entry            *****
--***************************************************************
   PROCEDURE do_create_element_entry (
      v_ssn                 IN       VARCHAR2,
      l_validate            IN       BOOLEAN,
      l_process_date       IN       DATE,
      l_business_group_id   IN       NUMBER,
      l_assignment_id       IN       NUMBER,
      l_element_link_id     IN       NUMBER,
      l_input_value_id      IN       NUMBER,
      l_entry_value         IN       NUMBER,
      p_process_status      OUT      VARCHAR2
   )
   IS
      l_effective_start_date    DATE;
      l_effective_end_date      DATE;
      l_element_entry_id        NUMBER;
      l_object_version_number   NUMBER;
      l_create_warning          BOOLEAN;
   BEGIN
      -- create the entry in the HR Schema

       --apps.fnd_file.put_line (apps.fnd_file.LOG, 'l_validate');
       --apps.fnd_file.put_line (apps.fnd_file.LOG, 'l_process_date'||l_process_date);
       --apps.fnd_file.put_line (apps.fnd_file.LOG, 'l_business_group_id'||l_business_group_id);
       --apps.fnd_file.put_line (apps.fnd_file.LOG, 'l_assignment_id'||l_assignment_id);
       --apps.fnd_file.put_line (apps.fnd_file.LOG, 'l_element_link_id'||l_element_link_id);
       --apps.fnd_file.put_line (apps.fnd_file.LOG, 'l_input_value_id'||l_input_value_id);
       --apps.fnd_file.put_line (apps.fnd_file.LOG, 'l_entry_value'||l_l_entry_value);
      pay_element_entry_api.create_element_entry
                         (p_validate                   => l_validate,
                          p_effective_date             => l_process_date,
                          p_business_group_id          => l_business_group_id,
                          p_assignment_id              => l_assignment_id,
                          p_element_link_id            => l_element_link_id,
                          p_entry_type                 => 'E',
                          p_input_value_id1            => l_input_value_id,
                          p_entry_value1               => l_entry_value,
                          p_input_value_id2            => l_input_value_id,
                          p_entry_value2               => '',
                        --Out Parameters
                          p_effective_start_date       => l_effective_start_date,
                          p_effective_end_date         => l_effective_end_date,
                          p_element_entry_id           => l_element_entry_id,
                          p_object_version_number      => l_object_version_number,
                          p_create_warning             => l_create_warning
                         );

                         --apps.fnd_file.put_line (apps.fnd_file.LOG, 'Element Entry Created');
      p_process_status := 'Element Entry Created';
      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         p_process_status := 'Element Entry Failed';
         l_errorlog_output :=
                     (RPAD (v_ssn, 29) || 'Element Entry Fallout' || SQLERRM
                     );
         v_errorlog_count := v_errorlog_count + 1;
         apps.fnd_file.put_line (apps.fnd_file.LOG, l_errorlog_output);
         --RAISE skip_record;
   END;

----------------End Create Element Entry ********************************************

   ----****************************************************************************************************
--*****               Delete Element Entry            *****
--***************************************************************
   PROCEDURE do_delete_element_entry (
      v_ssn                     IN   VARCHAR2,
      l_process_date            IN   DATE,
      l_element_entry_id        IN   NUMBER,
      l_object_version_number   IN   NUMBER,
      p_process_status          OUT  VARCHAR2
   )
   IS
      l_effective_start_date   DATE;
      l_effective_end_date     DATE;
      l_version_number         NUMBER  := l_object_version_number;
      l_delete_warning         BOOLEAN;
   BEGIN
      pay_element_entry_api.delete_element_entry
                           (p_validate                   => FALSE,
                            p_datetrack_delete_mode      => 'DELETE',
                            p_effective_date             => l_process_date,
                            p_element_entry_id           => l_element_entry_id,
                            p_object_version_number      => l_version_number,
                            p_effective_start_date       => l_effective_start_date,
                            p_effective_end_date         => l_effective_end_date,
                            p_delete_warning             => l_delete_warning
                           );
      v_update_status := 'Element Entry Deleted';
      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         l_errorlog_output :=
                    (RPAD (v_ssn, 29) || 'Delete Element Fallout' || SQLERRM
                    );
         v_errorlog_count := v_errorlog_count + 1;
         apps.fnd_file.put_line (apps.fnd_file.LOG, l_errorlog_output);
         l_errorlog_output :=
            (   v_employee_number
             || '|'
             || RPAD (g_system_person_status, 20)
             || '|'
             || RPAD (g_location_code, 20)
             || '|'
             || TO_CHAR (g_process_date, 'MM/DD/YYYY')
             || '|'
             || TO_CHAR (g_plan_entry_date, 'MM/DD/YYYY')
             || '|'
             || RPAD (v_element_name, 30)
             || '|'
             || g_input_value
             || '|'
             || 'Delete Element Fallout ERROR:'
             || SQLERRM
            );
         apps.fnd_file.put_line (apps.fnd_file.output, l_errorlog_output);
         RAISE skip_record;
   END;

   ---****************End Delete Element Entry *************************------

   --**********           Update Element Entry            *******************
--************************************************************************------
   PROCEDURE do_update_element_entry (
      v_ssn                     IN       VARCHAR2,
      l_process_date           IN       DATE,
      l_business_group_id       IN       NUMBER,
      l_element_entry_id        IN       NUMBER,
      l_object_version_number   IN       NUMBER,
      l_input_value_id          IN       NUMBER,
      l_entry_value             IN       NUMBER,
      p_process_status          OUT      VARCHAR2
   )
   IS
      l_effective_start_date   DATE;
      l_effective_end_date     DATE;
      l_update_warning         BOOLEAN;
      l_version_number         NUMBER  := l_object_version_number;
      l_input_value_id_owed    NUMBER  := NULL;
   BEGIN

      BEGIN
         SELECT input.input_value_id
           INTO l_input_value_id_owed
           /*
		   START R12.2 Upgrade Remediation
		   code commented by RXNETHI-ARGANO, 04/MAY/2023
		   FROM hr.pay_input_values_f input
              , hr.pay_element_types_f etypes
			  */
		   -- code added by RXNETHI-ARGANO, 04/MAY/2023
		   FROM apps.pay_input_values_f input
              , apps.pay_element_types_f etypes
           --END R12.2 Upgrade Remediation			  
          WHERE etypes.element_type_id = input.element_type_id
            AND etypes.element_name = 'Loan 1_401k'
            AND input.NAME = 'Total Owed'          ---g_input_name
            AND input.business_group_id = 325;
      END;

      pay_element_entry_api.update_element_entry
                           (p_validate                   => FALSE,
                            p_datetrack_update_mode      => 'UPDATE',
                            p_effective_date             => l_process_date,
                            p_business_group_id          => l_business_group_id,
                            p_element_entry_id           => l_element_entry_id,
                            p_object_version_number      => l_version_number,
                            p_input_value_id1            => l_input_value_id,
                            p_entry_value1               => l_entry_value,
                            p_input_value_id2            => l_input_value_id_owed,
                            p_entry_value2               => '',
                            --Out Parameters
                            p_effective_start_date       => l_effective_start_date,
                            p_effective_end_date         => l_effective_end_date,
                            p_update_warning             => l_update_warning
                           );
      p_process_status := 'Element Entry Updated';
      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         p_process_status := 'Element Entry Update Failed';
         l_errorlog_output :=
                    (RPAD (v_ssn, 29) || 'Update Element Fallout' || SQLERRM
                    );
         v_errorlog_count := v_errorlog_count + 1;
         apps.fnd_file.put_line (apps.fnd_file.LOG, l_errorlog_output);
         apps.fnd_file.put_line (apps.fnd_file.output, l_errorlog_output);
         RAISE skip_record;
   END;

----------------End Create Element Entry ********************************************
   PROCEDURE create_element_entry (
      v_process_date         IN       DATE,
      v_process_type          IN       VARCHAR2,
      v_ssn                   IN       VARCHAR2,
      v_assignment_id         IN       NUMBER,
      v_business_group_id     IN       NUMBER,
      v_element_name          IN       VARCHAR2,
      v_ele_entry_value       IN       NUMBER,
      v_input_value_type      IN       VARCHAR2,
      v_pay_basis_id          IN       NUMBER,
      l_prior                 IN       VARCHAR2,
      v_employment_category   IN       VARCHAR2,
      v_people_group_id       IN       NUMBER,
      v_full_name             IN       VARCHAR2,
      v_location_code         IN       VARCHAR2,
      v_emp_no                IN       VARCHAR2,
      v_payroll_id            IN       NUMBER, /* 1.3 */
      v_location_id           IN       NUMBER, /* 1.3 */
      v_actual_status         IN OUT   VARCHAR2
   )
   IS
      l_input_value_id           NUMBER         := NULL;
      l_element_type_id          NUMBER         := NULL;
      l_element_link_id          NUMBER         := NULL;
      l_screen_entry_value       NUMBER         := NULL;
      l_process_status           VARCHAR2 (400) := NULL;
      p_process_status           VARCHAR2 (400) := NULL;
      l_oratermed_output         VARCHAR2 (500); /* 3.0 */
      v_element_entry_id         NUMBER         := NULL;
      v_object_version_number    NUMBER         := NULL;
      v_element_update_date      DATE;
      v_effective_element_date   DATE;
   BEGIN
      apps.fnd_file.put_line (apps.fnd_file.LOG, 'v_element_name........: '||v_element_name );
      apps.fnd_file.put_line (apps.fnd_file.LOG, 'v_process_type........: '||v_process_type );
      apps.fnd_file.put_line (apps.fnd_file.LOG, 'v_ele_entry_value.....: '||v_ele_entry_value );
      apps.fnd_file.put_line (apps.fnd_file.LOG, 'l_prior...............: '||l_prior );
      apps.fnd_file.put_line (apps.fnd_file.LOG, 'v_input_value_type....: '||v_input_value_type );
      v_actual_status := 'Queried';
      apps.fnd_file.put_line (apps.fnd_file.LOG, v_actual_status);

      g_input_value:= v_ele_entry_value;
--- select element details
      BEGIN
         SELECT input.input_value_id, etypes.element_type_id
           INTO l_input_value_id, l_element_type_id
           --FROM hr.pay_input_values_f input, hr.pay_element_types_f etypes            --code commented by RXNETHI-ARGANO, 04/MAY/2023
           FROM apps.pay_input_values_f input, apps.pay_element_types_f etypes          --code added by RXNETHI-ARGANO, 04/MAY/2023
		  WHERE etypes.element_type_id = input.element_type_id
            AND etypes.element_name = v_element_name
            --AND input.NAME = 'Percentage' /* 2.0 */
            AND input.NAME =  v_input_value_type /* 2.0 */
            AND v_process_date BETWEEN etypes.effective_start_date
                                    AND etypes.effective_end_date
            AND v_process_date BETWEEN input.effective_start_date
                                    AND input.effective_end_date
            AND input.business_group_id = 325;
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'After'||v_actual_status);
      EXCEPTION
         WHEN OTHERS
         THEN
          apps.fnd_file.put_line (apps.fnd_file.LOG, 'WHEN OTHERS'||v_actual_status);
            apps.fnd_file.put_line (apps.fnd_file.output,
                                       v_emp_no
                                    || '|'
                                    || v_full_name
                                    || '|'
                                    || v_ssn
                                    || '|'
                                    || g_system_person_status
                                    || '|'
                                    || v_location_code
                                    || '|'
                                    || TO_CHAR (v_process_date, 'MM/DD/YYYY')
                                    || '|'
                                    || RPAD (SUBSTR(v_element_name,1,50), 50) /* 3.0 */
                                    || '|'
                                    || l_prior
                                    || '|'
                                    || LPAD (v_ele_entry_value, 10)
                                    || '|'
                                    || 'Cannot be processed: '
                                    || 'Error in getting element query '
                                    || v_element_name
                                   );
            RAISE skip_record;
      END;

apps.fnd_file.put_line (apps.fnd_file.LOG, 'get_element_link_id'||v_actual_status);
      get_element_link_id (v_ssn,
                           v_element_name,
                           v_business_group_id,
                           v_pay_basis_id,
                           v_employment_category,
                           v_people_group_id,
                           v_payroll_id, /* 1.3 */
                           v_location_id,/* 1.3 */
                           l_element_link_id,
                           l_process_status
                          );

      IF l_process_status != 'Found'
      THEN
apps.fnd_file.put_line (apps.fnd_file.LOG, 'In If l_process_status != Found');
         l_oratermed_output :=
            (   v_emp_no
             || '|'
             || v_full_name
             || '|'
             || v_ssn
             || '|'
             || g_system_person_status
             || '|'
             || v_location_code
             || '|'
             || TO_CHAR (v_process_date, 'MM/DD/YYYY')
             || '|'
             || RPAD (SUBSTR(v_element_name,1,50), 50) /* 3.0 */
             || '|'
             || l_prior
             || '|'
             || LPAD (v_ele_entry_value, 10)
             || '|'
             || 'Cannot be processed: '
             || 'Error in getting element link query '
             || l_process_status
            );
--apps.fnd_file.put_line (apps.fnd_file.LOG, 'After assign value to l_oratermed_output');
         apps.fnd_file.put_line (apps.fnd_file.output, l_oratermed_output);
         RAISE skip_record;
      END IF;
--apps.fnd_file.put_line (apps.fnd_file.LOG, 'entry.object_version_number'||v_actual_status);
      BEGIN
         SELECT entry.object_version_number, entry.last_update_date,
                entry.effective_start_date, entry.element_entry_id,
                entval.screen_entry_value
           INTO v_object_version_number, v_element_update_date,
                v_effective_element_date, v_element_entry_id,
                l_screen_entry_value
           /*
		   START R12.2 Upgrade Remediation
		   code commented by RXNETHI-ARGANO, 04/MAY/2023
		   FROM hr.pay_element_entries_f entry,
                hr.pay_element_entry_values_f entval*/
		   --code added by RXNETHI-ARGANO, 04/MAY/2023
		   FROM apps.pay_element_entries_f entry,
                apps.pay_element_entry_values_f entval
		   --END R12.2 Upgrade Remedation
          WHERE entry.assignment_id = v_assignment_id
            AND entry.element_type_id = l_element_type_id
            AND entval.element_entry_id = entry.element_entry_id
            AND entval.input_value_id = l_input_value_id
            AND entry.element_link_id = l_element_link_id
            AND entry.effective_end_date =
                           (SELECT MAX (effective_end_date)
                              FROM pay_element_entries_f entry2
                             WHERE entry.assignment_id = entry2.assignment_id)
            AND entval.effective_start_date =
                   (SELECT MAX (effective_start_date)
                      FROM pay_element_entry_values_f entval2
                     WHERE entval.element_entry_id = entval2.element_entry_id);
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN

            IF v_ele_entry_value > 0
            THEN
            --apps.fnd_file.put_line (apps.fnd_file.LOG, 'v_ele_entry_value > 0'||v_actual_status);
               -- create the entry in the HR Schema
               BEGIN
                  l_process_status := NULL;
                  do_create_element_entry (v_ssn,
                                           g_validate,
                                           v_process_date,
                                           v_business_group_id,
                                           v_assignment_id,
                                           l_element_link_id,
                                           l_input_value_id,
                                           v_ele_entry_value,
                                           l_process_status
                                          );
                  COMMIT;
                  v_actual_status := 'Created';
                  --apps.fnd_file.put_line (apps.fnd_file.LOG, v_actual_status);

                  IF l_process_status != 'Element Entry Created'
                  THEN
                     l_oratermed_output :=
                        (   v_emp_no
                         || '|'
                         || v_full_name
                         || '|'
                         || v_ssn
                         || '|'
                         || g_system_person_status
--                         || '|'
--                         || NULL
                         || '|'
                         || v_location_code
                         || '|'
                         || TO_CHAR (v_process_date, 'MM/DD/YYYY')
                         || '|'
                         || RPAD (SUBSTR(v_element_name,1,50), 50) /* 3.0 */
                         || '|'
                         || l_prior
                         || '|'
                         || LPAD (v_ele_entry_value, 10)
                         || '|'
                         || 'Cannot be processed: '
                         || 'Error in do create element query: '
                         || l_process_status
                        );
                     apps.fnd_file.put_line (apps.fnd_file.output,
                                             l_oratermed_output
                                            );
                     RAISE skip_record;
                  END IF;
               END;
            END IF;

            p_process_status := 'Found';
         -- RAISE SKIP_RECORD;
         WHEN TOO_MANY_ROWS
         THEN
            p_process_status := 'Too Many Row in Element Entry';
            l_errorlog_output :=
                        (RPAD (v_ssn, 29) || 'Too Many Row in Element Entry'
                        );
            v_errorlog_count := v_errorlog_count + 1;
            apps.fnd_file.put_line (apps.fnd_file.LOG, l_errorlog_output);
         WHEN OTHERS
         THEN
            p_process_status := 'Other in Element Entry';
            l_errorlog_output :=
                               (RPAD (v_ssn, 29) || 'Other in Element Entry'
                               );
            v_errorlog_count := v_errorlog_count + 1;
            apps.fnd_file.put_line (apps.fnd_file.LOG, l_errorlog_output);
      END;
/* CC new Begin */

      IF v_process_type in ('386','387')
         AND v_element_entry_id IS NOT NULL
      THEN
         do_delete_element_entry (v_ssn,
                                  v_process_date,
                                  v_element_entry_id,
                                  v_object_version_number,
                                  l_process_status
                                 );
         v_actual_status := 'Deleted';
         --apps.fnd_file.put_line (apps.fnd_file.LOG, v_actual_status);

         IF l_process_status != 'Element Entry Deleted'
         THEN
            l_oratermed_output :=
               (   v_emp_no
                || '|'
                || v_full_name
                || '|'
                || v_ssn
                || '|'
                || g_system_person_status
                || '|'
                || NULL
                || '|'
                || v_location_code
                || '|'
                || TO_CHAR (v_process_date, 'MM/DD/YYYY')
                || '|'
                || RPAD (SUBSTR(v_element_name,1,50), 50) /* 3.0 */
                || '|'
                || l_prior
                || '|'
                || LPAD (v_ele_entry_value, 10)
                || '|'
                || 'Cannot be processed: '
                || 'Error in do_delete_element_entry : '
                || l_process_status
               );
            apps.fnd_file.put_line (apps.fnd_file.output, l_oratermed_output);
            RAISE skip_record;
         END IF;
/* CC new End */
      --- update the entry
      ELSIF     v_element_entry_id IS NOT NULL
         AND v_ele_entry_value <> l_screen_entry_value
      THEN
      --apps.fnd_file.put_line (apps.fnd_file.LOG, 'do_update_element_entry'||v_actual_status);
         do_update_element_entry (v_ssn,
                                  v_process_date,
                                  v_business_group_id,
                                  v_element_entry_id,
                                  v_object_version_number,
                                  l_input_value_id,
                                  v_ele_entry_value,
                                  l_process_status
                                 );
         v_actual_status := 'Updated';
         --apps.fnd_file.put_line (apps.fnd_file.LOG, v_actual_status);

         IF l_process_status != 'Element Entry Updated'
         THEN
            l_oratermed_output :=
               (   v_emp_no
                || '|'
                || v_full_name
                || '|'
                || v_ssn
                || '|'
                || g_system_person_status
                || '|'
                || NULL
                || '|'
                || v_location_code
                || '|'
                || TO_CHAR (v_process_date, 'MM/DD/YYYY')
                || '|'
                || RPAD (SUBSTR(v_element_name,1,50), 50) /* 3.0 */
                || '|'
                || l_prior
                || '|'
                || LPAD (v_ele_entry_value, 10)
                || '|'
                || 'Cannot be processed: '
                || 'Error in do update query: '
                || l_process_status
               );
            apps.fnd_file.put_line (apps.fnd_file.output, l_oratermed_output);
            RAISE skip_record;
         END IF;
      END IF;
   END create_element_entry;

   --***************************************************************
--*****                  MAIN Program                       *****
--***************************************************************
   PROCEDURE main (
      errcode          OUT      VARCHAR2,
      errbuff          OUT      VARCHAR2,
      p_process_date   IN       VARCHAR2
   )
   IS
      l_active_output            VARCHAR2 (500); /* 3.0 */
      l_termed_output            VARCHAR2 (500); /* 3.0 */
      l_oratermed_output         VARCHAR2 (500); /* 3.0 */
      v_oratermed_count          NUMBER                                  := 0;
      v_termed_count             NUMBER                                  := 0;
      v_active_count             NUMBER                                  := 0;
      l_rows_active_read         NUMBER                                  := 0;
      l_rows_read                NUMBER                                  := 0;
      l_rows_termed_read         NUMBER                                  := 0;
      l_rows_active_processed    NUMBER                                  := 0;
      l_rows_termed_processed    NUMBER                                  := 0;
      l_rows_active_skipped      NUMBER                                  := 0;
      l_rows_termed_skipped      NUMBER                                  := 0;
      l_rows_skipped             NUMBER                                  := 0;
      l_module_name              cust.ttec_error_handling.module_name%TYPE
                                                        := 'Main inside loop';
      l_business_group_id        NUMBER                               := NULL;
      l_element_name             VARCHAR2 (60);
      l_process_status           VARCHAR2 (400);
      l_location_code            VARCHAR2 (150);
      l_employee_number          VARCHAR2 (60);
      l_person_id                NUMBER;
      l_assignment_id            NUMBER;
      l_full_name                per_all_people_f.full_name%TYPE      := NULL;
      l_system_person_type       VARCHAR2 (30)                        := NULL;
      l_system_person_status     VARCHAR2 (50)                        := NULL;
      l_element_link_id          NUMBER;
      l_input_value_id1          NUMBER                               := NULL;
      l_input_value_id2          NUMBER                               := NULL;
      v_effective_start_date     DATE                                 := NULL;
      l_effective_element_date   DATE                                 := NULL;
      l_element_update_date      DATE                                 := NULL;
      l_pay_basis_id             NUMBER                               := NULL;
      l_employment_category      VARCHAR2 (10)                        := NULL;
      l_people_group_id          NUMBER                               := NULL;
      l_screen_entry_value       NUMBER;
      l_effective_start_date     DATE;
      l_effective_end_date       DATE;
      l_element_entry_id         NUMBER;
      l_object_version_number    NUMBER;
      l_payroll_id               NUMBER; /* 1.3 */
      l_location_id              NUMBER; /* 1.3 */
      l_create_warning           BOOLEAN;
      l_delete_warning           BOOLEAN;
      l_update_warning           BOOLEAN;
      v_todays_date              DATE;
      l_actual_status            VARCHAR2 (100)                       := NULL;
      l_post_notes               VARCHAR2 (200)                       := NULL;
      l_prior_401k               VARCHAR2 (10)                        := NULL;
      l_prior_401k_catchup       VARCHAR2 (10)                        := NULL;
      l_prior_401k_bonus_pct     VARCHAR2 (10)                        := NULL;  /* 2.0 */
      l_prior_401k_amt           NUMBER                               := NULL;  /* 2.0 */
      l_prior_401k_catchup_amt   NUMBER                               := NULL;  /* 2.0 */
      l_prior                    VARCHAR2 (10)                        := NULL;
      v_grant_tot                NUMBER                               := NULL;
   BEGIN                                                      ---Starting main
      --  BEGIN
      --  SELECT '/d01/ora'||DECODE(name,'PROD','cle',LOWER(name))
      --  ||'/'||LOWER(name)
      -- ||'appl/teletech/11.5.0/data/BenefitInterface'
      --  INTO v_output_dir
      --  FROM V$DATABASE;
      --  END;

      --      v_output_dir := TTEC_LIBRARY.GET_DIRECTORY ('CUST_TOP');         -- v2.0
--      v_output_dir := v_output_dir || '/data/401k/IN/Deferral';        -- v2.0

      ---------------------------------------------------------------------------------------------------------------
      BEGIN
                                ---begin loading into oracle
          --p_FileName := p_NewLoan_active;
          --v_active_file :=
           --UTL_FILE.FOPEN (v_output_dir, p_NewLoan_active, 'w');
          --p_FileName := p_NewLoan_oratermed;
         -- v_oratermed_file :=
           --UTL_FILE.FOPEN (v_output_dir, p_NewLoan_oratermed, 'w');
         v_module := 'Obtain Process Date';

         IF p_process_date = 'DD-MON-RRRR'
         THEN
            v_process_date := TRUNC (SYSDATE);
         ELSE
            v_process_date := TO_DATE (p_process_date);
         END IF;

         g_as_of_date := v_process_date;

         apps.fnd_file.put_line (apps.fnd_file.output,
                                    'Begin Processing 401K Loan >>> '
                                 || TO_CHAR (SYSDATE,
                                             'DD-MON-RRRR HH24:MI:SS')
                                );
         apps.fnd_file.put_line (apps.fnd_file.output,
                                    'Process Date              : '
                                 || p_process_date
                                );
         apps.fnd_file.put_line (apps.fnd_file.output,
                                    'Loan Effective Date   : '
                                 || TO_CHAR (v_process_date, 'DD-MON-RRRR')
                                );
         l_active_output :=
            (   'Emp_Num|'
             || 'Fullname|'
             || 'Social_Sec_Num|'
             || 'Assignment_Status|'
             || 'Location|'
             || 'Effective_Date|'
             || 'Processing_Element|'
             || 'Prior_Entry_Value|'
             || 'Update_Entry_Value|'
             || 'Loan_Process_Result'
            );
         apps.fnd_file.put_line (apps.fnd_file.output, l_active_output);

         ----********************************** Start Processing Active Employees ***************************************
         apps.fnd_file.put_line (apps.fnd_file.log, 'Before Cursor');
         FOR sel IN csr_loan
         LOOP
            l_prior_401k := NULL;
            l_prior_401k_catchup := NULL;
            l_prior_401k_bonus_pct   := NULL; /* 2.0 */
            l_prior_401k_amt         := NULL; /* 2.0 */
            l_prior_401k_catchup_amt := NULL; /* 2.0 */
            g_401k_NewLoan_amt       := NULL;
            g_401k_ReAmortized_amt   := NULL;
            g_401k_LoanTerm_amt      := NULL;
            l_payroll_id := NULL; /* 1.3 */
            l_location_id := NULL; /* 1.3 */

            g_emp_no := sel.emp_no;
            v_employee_number := sel.emp_no;
            v_process_type := sel.rec_type;
            g_input_value := sel.loan_payment_amount;

            apps.fnd_file.put_line (apps.fnd_file.log, '********************Processing Emp: '||v_employee_number ||' with record type ->'||v_process_type|| ' **************************');

            /* 2.2 Begin */

            BEGIN
                  apps.fnd_file.put_line (apps.fnd_file.log, 'Stage 10');

                  IF v_process_type = '384'
                  THEN
                      g_401k_NewLoan_amt       := sel.loan_payment_amount;
                      apps.fnd_file.put_line (apps.fnd_file.log, '        g_401k_NewLoan_amt >>> '||g_401k_NewLoan_amt);

                  ELSIF v_process_type = '383'
                  THEN
                      g_401k_ReAmortized_amt    := sel.loan_payment_amount;
                      apps.fnd_file.put_line (apps.fnd_file.log, 'g_401k_ReAmortized_amt >>> '||g_401k_ReAmortized_amt);

                  ELSIF v_process_type in ('386','387')
                  THEN
                      g_401k_LoanTerm_amt    := sel.loan_payment_amount;
                      apps.fnd_file.put_line (apps.fnd_file.log, 'g_401k_LoanTerm_amt >>> '||g_401k_LoanTerm_amt);

                  END IF;

               v_module := 'employee_status';
               apps.fnd_file.put_line (apps.fnd_file.LOG, v_module );
               get_employee_status (sel.social_number,
                                    l_full_name,
                                    l_system_person_status,
                                    l_process_status
                                   );

               IF l_process_status != 'Found'
               THEN
                  v_module := 'employee_status != Found';
                  apps.fnd_file.put_line (apps.fnd_file.LOG, v_module );
                  l_oratermed_output :=
                     (   sel.emp_no
                      || '|'
                      || l_full_name
                      || '|'
                      || sel.social_number
                      || '|'
                      || l_process_status
                      || '|'
                      || g_location_code
                      || '|'
                      || TO_CHAR (v_process_date, 'MM/DD/YYYY')
                      || '|'
                      || ''
                      || '|'
                      || ''
                      || '|'
                      || ''
                      || '|'
                      || 'Cannot be processed due to the following reason: '
                      || l_process_status
                     );
                  apps.fnd_file.put_line (apps.fnd_file.output,
                                          l_oratermed_output
                                         );
                  RAISE skip_record;
               END IF;

               g_system_person_status := l_system_person_status;

               apps.fnd_file.put_line (apps.fnd_file.LOG, 'g_system_person_status >>' ||g_system_person_status);

               IF l_system_person_status = 'Terminate - Process'
               THEN
                  apps.fnd_file.put_line (apps.fnd_file.LOG, 'IN -> Terminate - Process>>' ||l_system_person_status);
                  l_oratermed_output :=
                     (   sel.emp_no
                      || '|'
                      || l_full_name
                      || '|'
                      || sel.social_number
                      || '|'
                      || RPAD (l_system_person_status, 20)
                      || '|'
                      || g_location_code
                      || '|'
                      || TO_CHAR (v_process_date, 'MM/DD/YYYY')
                      || '|'
                      || RPAD (g_element_name, 50)
                      || '|'
                      || l_prior_401k
                      || '|'
                      || g_input_value
                      || '|'
                      || 'No Update due to Employee is no longer active'
                     );
                  v_oratermed_count := v_oratermed_count + 1;
                  apps.fnd_file.put_line (apps.fnd_file.output,
                                          l_oratermed_output
                                         );
                  RAISE skip_record;
               END IF;
----------------------------------------------------------------------------
                apps.fnd_file.put_line (apps.fnd_file.log, 'Get_prior_input_value --> '||g_input_name ||' for element -> '||g_element_name);
                l_prior_401k_amt := get_prior_input_value (sel.emp_no,
                                                           g_element_name,
                                                           g_input_name,
                                                           v_process_date
                                                           );
               v_module := 'get_assignment_id';

               apps.fnd_file.put_line (apps.fnd_file.LOG, v_module );
               get_assignment_id (sel.social_number,
                                  l_employee_number,
                                  l_full_name,
                                  l_assignment_id,
                                  l_business_group_id,
                                  l_payroll_id, /* 1.3 */
                                  l_location_id,/* 1.3 */
                                  l_effective_start_date,
                                  l_effective_end_date,
                                  l_process_status
                                 );

               IF l_process_status != 'Found'
               THEN
                  l_oratermed_output :=
                     (   sel.emp_no
                      || '|'
                      || l_full_name
                      || '|'
                      || sel.social_number
                      || '|'
                      || l_process_status
                      || '|'
                      || ''
                      || '|'
                      || TO_CHAR (v_process_date, 'MM/DD/YYYY')
                      || '|'
                      || ''
                      || '|'
                      || ''
                      || '|'
                      || ''
                      || '|'
                      || 'Cannot be processed due to the following reason: '
                      || l_process_status
                     );
                  apps.fnd_file.put_line (apps.fnd_file.output,
                                          l_oratermed_output
                                         );
                  RAISE skip_record;
               END IF;

               v_module := 'get_location';
               apps.fnd_file.put_line (apps.fnd_file.LOG, v_module );
               get_location (sel.social_number,
                             l_full_name,
                             l_location_code,
                             l_process_status
                            );

               IF l_process_status != 'Found'
               THEN
                  l_oratermed_output :=
                     (   sel.emp_no
                      || '|'
                      || l_full_name
                      || '|'
                      || sel.social_number
                      || '|'
                      || l_process_status
                      || '|'
                      || l_location_code
                      || '|'
                      || TO_CHAR (v_process_date, 'MM/DD/YYYY')
                      || '|'
                      || ''
                      || '|'
                      || ''
                      || '|'
                      || ''
                      || '|'
                      || 'Cannot be processed due to the following reason: '
                      || l_process_status
                     );
                  apps.fnd_file.put_line (apps.fnd_file.output,
                                          l_oratermed_output
                                         );
                  RAISE skip_record;
               END IF;

               g_location_code := l_location_code;
               g_full_name := l_full_name;
               apps.fnd_file.put_line(apps.fnd_file.LOG, 'Location Code '||l_location_code);
               v_module := 'get_person_type';
               apps.fnd_file.put_line (apps.fnd_file.LOG, v_module );
               get_person_type (sel.social_number,
                                l_person_id,
                                l_assignment_id,
                                l_pay_basis_id,
                                l_employment_category,
                                l_people_group_id,
                                l_full_name,
                                l_system_person_type,
                                l_process_status
                               );

               IF l_process_status != 'Found'
               THEN
                  l_oratermed_output :=
                     (   sel.emp_no
                      || '|'
                      || l_full_name
                      || '|'
                      || sel.social_number
                      || '|'
                      || l_process_status
                      || '|'
                      || g_location_code
                      || '|'
                      || TO_CHAR (v_process_date, 'MM/DD/YYYY')
                      || '|'
                      || ''
                      || '|'
                      || ''
                      || '|'
                      || ''
                      || '|'
                      || 'Cannot be processed due to the following reason: '
                      || l_process_status
                     );
                  apps.fnd_file.put_line (apps.fnd_file.output,
                                          l_oratermed_output
                                         );
                  RAISE skip_record;
               END IF;

               IF l_system_person_status <> 'Terminate - Process'
               THEN
                  apps.fnd_file.put_line (apps.fnd_file.LOG, 'IN -> <> Terminate - Process>>' ||l_system_person_status);

                  IF v_process_type = '383'
                  THEN
                      apps.fnd_file.put_line (apps.fnd_file.LOG, 'Examining l_prior_401k_amt IS NOT NULL value >>>' || to_char(l_prior_401k_amt) );
                      apps.fnd_file.put_line (apps.fnd_file.LOG, '      and 0 g_401k_ReAmortized_amt value>>>' ||g_401k_ReAmortized_amt);

                      IF l_prior_401k_amt IS NULL
                      THEN
                         l_active_output :=
                            (   sel.emp_no
                             || '|'
                             || l_full_name
                             || '|'
                             || sel.social_number
                             || '|'
                             || RPAD (l_system_person_status, 20)
                             || '|'
                             || g_location_code
                             || '|'
                             || TO_CHAR (v_process_date, 'MM/DD/YYYY')
                             || '|'
                             || RPAD ('Reamortized 401k Loan', 50) /* 2.0 */
                             || '|'
                             || l_prior_401k_amt /* 2.0 */
                             || '|'
                             || LPAD (g_401k_ReAmortized_amt, 10) /* 2.0 */
                             || '|'
                             || 'Cannot Process Reamotization, no previous Loan Found '
                             || '|'
                             ||  g_element_name /* 2.1 */
                            );
                         v_errorlog_count := v_errorlog_count + 1;
                         apps.fnd_file.put_line (apps.fnd_file.output,
                                                 l_active_output
                                                );

                      ELSIF l_prior_401k_amt IS NOT NULL OR
                         TO_NUMBER (g_401k_ReAmortized_amt) >= 0
                      THEN
                         l_actual_status := NULL;
                         --- create/update 401k catchup element entry
                         apps.fnd_file.put_line (apps.fnd_file.LOG, 'create_element_entry - Reamortized 401k Loan' );
                         create_element_entry (v_process_date,
                                               v_process_type,
                                               sel.social_number,
                                               l_assignment_id,
                                               l_business_group_id,
                                               g_element_name,
                                               g_401k_ReAmortized_amt,
                                               'Amount',
                                               l_pay_basis_id,
                                               l_prior_401k_amt,
                                               l_employment_category,
                                               l_people_group_id,
                                               g_full_name,
                                               g_location_code,
                                               sel.emp_no,
                                               l_payroll_id,
                                               l_location_id,
                                               l_actual_status
                                              );

                         BEGIN
                             SELECT DECODE(l_actual_status,'Queried',' No action is taken, already in place','')
                             INTO l_post_notes
                             FROM DUAL;
                         END;

                         l_active_output :=
                            (   sel.emp_no
                             || '|'
                             || l_full_name
                             || '|'
                             || sel.social_number
                             || '|'
                             || RPAD (l_system_person_status, 20)
                             || '|'
                             || g_location_code
                             || '|'
                             || TO_CHAR (v_process_date, 'MM/DD/YYYY')
                             || '|'
                             || RPAD ('Reamortized 401k Loan', 50)
                             || '|'
                             || l_prior_401k_amt
                             || '|'
                             || LPAD (g_401k_ReAmortized_amt, 10)
                             || '|'
                             || 'Successfully '
                             || l_actual_status
                             || ' '
                             || g_element_name
                             || l_post_notes
                            );
                         v_active_count := v_active_count + 1;
                         apps.fnd_file.put_line (apps.fnd_file.output,
                                                 l_active_output
                                                );
                      END IF;
                  ELSIF v_process_type = '384' THEN
                      apps.fnd_file.put_line (apps.fnd_file.LOG, 'Examining l_prior_401k_amt IS NULL value >>>' ||l_prior_401k_amt );
                      apps.fnd_file.put_line (apps.fnd_file.LOG, '      AND Amount >= 0 g_401k_NewLoan_amt value>>>' ||g_401k_NewLoan_amt);

                      IF l_prior_401k_amt IS NOT NULL
                      THEN
                         l_active_output :=
                            (   sel.emp_no
                             || '|'
                             || l_full_name
                             || '|'
                             || sel.social_number
                             || '|'
                             || RPAD (l_system_person_status, 20)
                             || '|'
                             || g_location_code
                             || '|'
                             || TO_CHAR (v_process_date, 'MM/DD/YYYY')
                             || '|'
                             || RPAD ('NEWLY ISSUED LOAN', 50)
                             || '|'
                             || l_prior_401k_amt
                             || '|'
                             || g_401k_NewLoan_amt
                             || '|'
                             || 'Cannot Process New Loan, Existing Loan Found '
                             || '|'
                             ||  g_element_name /* 2.1 */
                            );
                         v_errorlog_count := v_errorlog_count + 1;
                         apps.fnd_file.put_line (apps.fnd_file.output,
                                                 l_active_output
                                                );
                      ELSIF l_prior_401k_amt IS NULL AND
                         TO_NUMBER (g_401k_NewLoan_amt) >= 0		-- v1.2
                      THEN
                         l_actual_status := NULL;
                         --- create/update 401k catchup element entry
                         apps.fnd_file.put_line (apps.fnd_file.LOG, 'create_element_entry - NEWLY ISSUED LOAN ' );
                             create_element_entry (v_process_date,
                                                   v_process_type,
                                                   sel.social_number,
                                                   l_assignment_id,
                                                   l_business_group_id,
                                                   g_element_name,
                                                   g_401k_NewLoan_amt,
                                                   'Amount',
                                                   l_pay_basis_id,
                                                   l_prior_401k_amt,
                                                   l_employment_category,
                                                   l_people_group_id,
                                                   g_full_name,
                                                   g_location_code,
                                                   sel.emp_no,
                                                   l_payroll_id,
                                                   l_location_id,
                                                   l_actual_status
                                                  );
                         BEGIN
                             SELECT DECODE(l_actual_status,'Queried',' No action is taken, already in place','')
                             INTO l_post_notes
                             FROM DUAL;
                         END;

                         l_active_output :=
                            (   sel.emp_no
                             || '|'
                             || l_full_name
                             || '|'
                             || sel.social_number
                             || '|'
                             || RPAD (l_system_person_status, 20)
                             || '|'
                             || g_location_code
                             || '|'
                             || TO_CHAR (v_process_date, 'MM/DD/YYYY')
                             || '|'
                             || RPAD ('NEWLY ISSUED LOAN', 50)
                             || '|'
                             || l_prior_401k_amt
                             || '|'
                             || LPAD (g_401k_NewLoan_amt, 10)
                             || '|'
                             || 'Successfully '
                             || l_actual_status
                             || ' '
                             || g_element_name
                             || l_post_notes
                            );
                         v_active_count := v_active_count + 1;
                         apps.fnd_file.put_line (apps.fnd_file.output,
                                                 l_active_output
                                                );
                      END IF;
                  ELSIF v_process_type = '386' THEN
                      apps.fnd_file.put_line (apps.fnd_file.LOG, 'Examining l_prior_401k_amt IS NOT NULL value >>>' ||l_prior_401k_amt );
                      apps.fnd_file.put_line (apps.fnd_file.LOG, '      AND Amount >= 0 g_401k_LoanTerm_amt value>>>' ||g_401k_LoanTerm_amt);


                      IF l_prior_401k_amt IS NULL
                      THEN
                         l_active_output :=
                            (   sel.emp_no
                             || '|'
                             || l_full_name
                             || '|'
                             || sel.social_number
                             || '|'
                             || RPAD (l_system_person_status, 20)
                             || '|'
                             || g_location_code
                             || '|'
                             || TO_CHAR (v_process_date, 'MM/DD/YYYY')
                             || '|'
                             || RPAD ('PLAN LOAN OFFSET', 50) /* 2.0 */
                             || '|'
                             || l_prior_401k_amt /* 2.0 */
                             || '|'
                             || LPAD (g_401k_LoanTerm_amt, 10) /* 2.0 */
                             || '|'
                             || 'Cannot Process PLAN LOAN OFFSET, no previous Loan Found '
                             || '|'
                             ||  g_element_name /* 2.1 */
                            );
                         v_errorlog_count:= v_errorlog_count + 1;
                         apps.fnd_file.put_line (apps.fnd_file.output,
                                                 l_active_output
                                                );

                      ELSIF l_prior_401k_amt IS NOT NULL AND
                         TO_NUMBER (g_401k_LoanTerm_amt) >= 0		-- v1.2
                      THEN
                         l_actual_status := NULL;
                         --- create/update 401k catchup element entry
                         apps.fnd_file.put_line (apps.fnd_file.LOG, 'create_element_entry - PLAN LOAN OFFSET ' );
                             create_element_entry (v_process_date,
                                                   v_process_type,
                                                   sel.social_number,
                                                   l_assignment_id,
                                                   l_business_group_id,
                                                   g_element_name,
                                                   g_401k_LoanTerm_amt,
                                                   'Amount',
                                                   l_pay_basis_id,
                                                   l_prior_401k_amt,
                                                   l_employment_category,
                                                   l_people_group_id,
                                                   g_full_name,
                                                   g_location_code,
                                                   sel.emp_no,
                                                   l_payroll_id,
                                                   l_location_id,
                                                   l_actual_status
                                                  );
                         BEGIN
                             SELECT DECODE(l_actual_status,'Queried',' No action is taken, already in place','')
                             INTO l_post_notes
                             FROM DUAL;
                         END;

                         l_active_output :=
                            (   sel.emp_no
                             || '|'
                             || l_full_name
                             || '|'
                             || sel.social_number
                             || '|'
                             || RPAD (l_system_person_status, 20)
                             || '|'
                             || g_location_code
                             || '|'
                             || TO_CHAR (v_process_date, 'MM/DD/YYYY')
                             || '|'
                             || RPAD ('PLAN LOAN OFFSET', 50) /* 2.0 */
                             || '|'
                             || l_prior_401k_amt /* 2.0 */
                             || '|'
                             || LPAD (g_401k_LoanTerm_amt, 10) /* 2.0 */
                             || '|'
                             || 'Successfully '
                             || l_actual_status
                             || ' '
                             || g_element_name
                             || l_post_notes
                            );
                         v_active_count := v_active_count + 1;
                         apps.fnd_file.put_line (apps.fnd_file.output,
                                                 l_active_output
                                                );
                      END IF;
                  ELSIF v_process_type = '387' THEN
                      apps.fnd_file.put_line (apps.fnd_file.LOG, 'Examining l_prior_401k_amt IS NOT NULL value >>>' ||l_prior_401k_amt );
                      apps.fnd_file.put_line (apps.fnd_file.LOG, '      AND Amount >= 0 g_401k_LoanTerm_amt>>>' ||g_401k_LoanTerm_amt);

                      IF l_prior_401k_amt IS NULL
                      THEN
                         l_active_output :=
                            (   sel.emp_no
                             || '|'
                             || l_full_name
                             || '|'
                             || sel.social_number
                             || '|'
                             || RPAD (l_system_person_status, 20)
                             || '|'
                             || g_location_code
                             || '|'
                             || TO_CHAR (v_process_date, 'MM/DD/YYYY')
                             || '|'
                             || RPAD ('LOAN PAYOFF', 50) /* 2.0 */
                             || '|'
                             || l_prior_401k_amt /* 2.0 */
                             || '|'
                             || LPAD (g_401k_LoanTerm_amt, 10) /* 2.0 */
                             || '|'
                             || 'Cannot Process LOAN PAYOFF, no previous Loan Found '
                             || '|'
                             ||  g_element_name /* 2.1 */
                            );
                         v_errorlog_count := v_errorlog_count + 1;
                         apps.fnd_file.put_line (apps.fnd_file.output,
                                                 l_active_output
                                                );

                      ELSIF l_prior_401k_amt IS NOT NULL AND
                         TO_NUMBER (g_401k_LoanTerm_amt) >= 0		-- v1.2
                      THEN
                         l_actual_status := NULL;
                         --- create/update 401k catchup element entry
                         apps.fnd_file.put_line (apps.fnd_file.LOG, 'create_element_entry - LOAN PAYOFF ' );
                             create_element_entry (v_process_date,
                                                   v_process_type,
                                                   sel.social_number,
                                                   l_assignment_id,
                                                   l_business_group_id,
                                                   g_element_name,
                                                   g_401k_LoanTerm_amt,
                                                   'Amount',
                                                   l_pay_basis_id,
                                                   l_prior_401k_amt,
                                                   l_employment_category,
                                                   l_people_group_id,
                                                   g_full_name,
                                                   g_location_code,
                                                   sel.emp_no,
                                                   l_payroll_id,
                                                   l_location_id,
                                                   l_actual_status
                                                  );

                         BEGIN
                             SELECT DECODE(l_actual_status,'Queried',' No action is taken, already in place','')
                             INTO l_post_notes
                             FROM DUAL;
                         END;

                         l_active_output :=
                            (   sel.emp_no
                             || '|'
                             || l_full_name
                             || '|'
                             || sel.social_number
                             || '|'
                             || RPAD (l_system_person_status, 20)
                             || '|'
                             || g_location_code
                             || '|'
                             || TO_CHAR (v_process_date, 'MM/DD/YYYY')
                             || '|'
                             || RPAD ('LOAN PAYOFF', 50)
                             || '|'
                             || l_prior_401k_amt
                             || '|'
                             || LPAD (g_401k_NewLoan_amt, 10)
                             || '|'
                             || 'Successfully '
                             || l_actual_status
                             || ' '
                             || g_element_name
                             || l_post_notes
                            );
                         v_active_count := v_active_count + 1;
                         apps.fnd_file.put_line (apps.fnd_file.output,
                                                 l_active_output
                                                );
                      END IF;
                  ELSE
                      apps.fnd_file.put_line (apps.fnd_file.LOG, 'Unknown Record Type Please contact ERP Development >>>' ||v_process_type );

                         l_active_output :=
                            (   sel.emp_no
                             || '|'
                             || l_full_name
                             || '|'
                             || sel.social_number
                             || '|'
                             || RPAD (l_system_person_status, 20)
                             || '|'
                             || g_location_code
                             || '|'
                             || TO_CHAR (v_process_date, 'MM/DD/YYYY')
                             || '|'
                             || RPAD ('Unknown Record Type -> '||v_process_type, 50) /* 2.0 */
                             || '|'
                             || l_prior_401k_amt /* 2.0 */
                             || '|'
                             || LPAD (g_401k_NewLoan_amt, 10) /* 2.0 */
                             || '|'
                             || 'Please contact ERP Development!'
                             || 'No Update due to UNKNOWN/un-programmed Record Type'
                             || ' '
                             --|| ' Pre Tax 401K Flat Dollar Element Entry' /* 2.0 */
                             ||  g_element_name /* 2.1 */
                            );
                         v_active_count := v_active_count + 1;
                         apps.fnd_file.put_line (apps.fnd_file.output,
                                                 l_active_output
                                                );
                  END IF;   --ELSE
               END IF; -- l_system_person_status <> 'Terminate - Process'

            EXCEPTION
               WHEN skip_record
               THEN
                  NULL;
            END;
         END LOOP;

         COMMIT;                                      -- commit any final rows
         ---************************************ Summary of Active Employees **************************--------
         apps.fnd_file.put_line (apps.fnd_file.output,
                                 'Tot Loan Processed:   '
                                 || v_active_count
                                );
         ---***********************************End Summary of Active Employees ****************************--------

         ---************************************** Summary of Error Records ***************************---------
         apps.fnd_file.put_line (apps.fnd_file.output,
                                    'Tot Loan Unprocessed: '
                                 || v_errorlog_count
                                );
         -----*********************************** End Summary of Error Records ************************-----------
         ---**************************************** Summary of Oracle Termed ********************--
         apps.fnd_file.put_line (apps.fnd_file.output,
                                    'Tot Oracle Termed:        '
                                 || v_oratermed_count
                                );
         ---**************************************** Total ********************--
         v_grant_tot := v_active_count + v_errorlog_count + v_oratermed_count;
         apps.fnd_file.put_line (apps.fnd_file.output,
                                    'Tot Number Of Records:        '
                                 ||  v_grant_tot
                                );
--*******************************************************************************************---

      -- ********************************************End Element Entries   ----------
      END;                                           --end loading into oracle
   EXCEPTION
      WHEN UTL_FILE.invalid_operation
      THEN
         raise_application_error (-20051,
                                  p_filename || ':  Invalid Operation'
                                 );
         ROLLBACK;
      WHEN UTL_FILE.invalid_filehandle
      THEN
         raise_application_error (-20052,
                                  p_filename || ':  Invalid File Handle'
                                 );
         ROLLBACK;
      WHEN UTL_FILE.read_error
      THEN
         raise_application_error (-20053, p_filename || ':  Read Error');
         ROLLBACK;
      WHEN UTL_FILE.invalid_path
      THEN
         raise_application_error (-20054, p_filedir || ':  Invalid Path');
         ROLLBACK;
      WHEN UTL_FILE.invalid_mode
      THEN
         raise_application_error (-20055, p_filename || ':  Invalid Mode');
         ROLLBACK;
      WHEN UTL_FILE.write_error
      THEN
         raise_application_error (-20056, p_filename || ':  Write Error');
         ROLLBACK;
      WHEN UTL_FILE.internal_error
      THEN
         raise_application_error (-20057, p_filename || ':  Internal Error');
         ROLLBACK;
      WHEN UTL_FILE.invalid_maxlinesize
      THEN
         raise_application_error (-20058,
                                  p_filename || ':  Maxlinesize Error'
                                 );
         ROLLBACK;
      WHEN INVALID_CURSOR
      THEN
         ttec_error_logging.process_error
                                  (g_application_code                 -- 'BEN'
                                                     ,
                                   g_interface             -- 'BOA 401K Intf';
                                              ,
                                   g_package  -- 'ttec_trp_401k_loan_int'
                                            ,
                                   v_module,
                                   g_failure_status,
                                   SQLCODE,
                                   SQLERRM,
                                   g_label1,
                                   v_loc,
                                   g_label2,
                                   g_emp_no
                                  );
         errcode := SQLCODE;
         errbuff := SUBSTR (SQLERRM, 1, 255);
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error
                                  (g_application_code                 -- 'BEN'
                                                     ,
                                   g_interface             -- 'BOA 401K Intf';
                                              ,
                                   g_package  -- 'ttec_trp_401k_loan_int'
                                            ,
                                   v_module,
                                   g_failure_status,
                                   SQLCODE,
                                   SQLERRM,
                                   g_label1,
                                   v_loc,
                                   g_label2,
                                   g_emp_no
                                  );
         errcode := SQLCODE;
         errbuff := SUBSTR (SQLERRM, 1, 255);
         apps.fnd_file.put_line
                  (apps.fnd_file.LOG,
                      'Exception OTHERS in ttec_trp_401k_loan_int.main: '
                   || 'Module >-'
                   || v_module
                   || ' ['
                   || g_label1
                   || ']['
                   || v_loc
                   || ']['
                   || g_label2
                   || ']['
                   || g_emp_no
                   || '] ERROR:'
                   || errbuff
                  );
         raise_application_error
                  (-20003,
                      'Exception OTHERS in ttec_trp_401k_loan_int.main: '
                   || 'Module >-'
                   || v_module
                   || ' ['
                   || g_label1
                   || ']['
                   || v_loc
                   || ']['
                   || g_label2
                   || ']['
                   || g_emp_no
                   || '] ERROR:'
                   || errbuff
                  );
   END main;
END ttec_trp_401k_loan_int;
/
show errors;
/