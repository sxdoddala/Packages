create or replace PACKAGE BODY      ttec_baml_401k_loan_int
AS
--
-- Program Name:  TTEC_BAML_401K_LOAN_INT
-- /* $Header: TTEC_BAML_401K_LOAN_INT.pkb 1.0 2011/11/04  chchan ship $ */
--
-- /*== START ================================================================================================*\
--    Author: Christiane Chan
--      Date: 04-NOV-2011

-- Call From: Concurrent Program ->TeleTech BAML 401K Loan1 Update
--      Desc: Copy from the Old sql code ->ttec_401k_newloan_load.sql
--            This program will accomplish the following:
--            Read employee information which was supplied by BAML
--            from a temporary table
--            The program checks if a new loan setup is sent by BAML
--           for a former employee (terminated or deceased status) - then
--           an Oracle termination report is generated.
--
--           If a new loan setup is sent by BAML with an invalid SSN
--           or if there is already an active loan existing
--           an error log report is generated.
--           Report is generated for all new valid loans
--
--          For new 401K loan  call
--                  PAY_ELEMENT_ENTRY_API.CREATE_ELEMENT_ENTRY
--
--Input/Output Parameters
--
--Tables Accessed: CUST.ttec_us_401k_newloan_tbl def
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
--                  PAY_ELEMENT_ENTRY_API.UPDATE_ELEMENT_ENTRY
--     Parameter Description:
--
--      p_process_date: Process Date
--
--       Oracle Standard Parameters:
--
--   Modification History:
--
--  Version    Date     Author   Description (Include Ticket--)
--  -------  --------  --------  ------------------------------------------------------------------------------
--      1.0  11/04/11   CChan     Initial Version R#971563 - BOA-Merril Lynch 401K Project
--      2.0  05/21/11   Ravi Pasula    R#1506713
--      2.1  03/10/14   CChan     INC0088400 - Need to be modified to include the assignment status "TTEC Awaiting Integration"
--      1.0	09-May-2023 IXPRAVEEN(ARGANO)   		R12.2 Upgrade Remediation
--
   --v_module            cust.ttec_error_handling.module_name%TYPE   := 'Main';					-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
   v_module            apps.ttec_error_handling.module_name%TYPE   := 'Main';					--  code Added by IXPRAVEEN-ARGANO,09-May-2023
   v_loc               NUMBER;
   v_msg               VARCHAR2 (2000);
   v_rec               VARCHAR2 (5000);
   v_employee_number   VARCHAR2 (60);
   v_deferral_pct      NUMBER;
   v_deferral_date     DATE;
   v_plan_entry_date   DATE;
   v_element_name      VARCHAR2 (60);

--************************************************************************************--
 --*                          GET ASSIGNMENT ID                                       *--
 --************************************************************************************--
   PROCEDURE get_assignment_id (
      v_ssn                    IN       VARCHAR2
    , v_employee_number        OUT      VARCHAR2
    , p_assignment_id          OUT      NUMBER
    , p_business_group_id      OUT      NUMBER
    , p_payroll_id             OUT      NUMBER  /* 2.1 */
    , p_location_id            OUT      NUMBER  /* 2.1 */
    , p_effective_start_date   OUT      DATE
    , p_effective_end_date     OUT      DATE
    , p_process_status         OUT      VARCHAR2
   )
   IS
   BEGIN
      --             l_error_message    := NULL;
      SELECT DISTINCT asg.assignment_id, emp.employee_number
                    , asg.business_group_id, asg.effective_start_date
                    , asg.effective_end_date
                      ,asg.payroll_id,asg.location_id /* 2.1 */
                 INTO p_assignment_id, v_employee_number
                    , p_business_group_id, p_effective_start_date
                    , p_effective_end_date
                      ,p_payroll_id,p_location_id /* 2.1 */
                 --FROM hr.per_all_assignments_f asg, hr.per_all_people_f emp			-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
				 FROM apps.per_all_assignments_f asg, apps.per_all_people_f emp				--  code Added by IXPRAVEEN-ARGANO,09-May-2023
                WHERE emp.national_identifier = v_ssn
                  AND emp.person_id = asg.person_id
                  AND TRUNC (SYSDATE) BETWEEN emp.effective_start_date
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
         p_process_status  := 'No Assignment';
         l_errorlog_output := (RPAD (v_ssn, 29) || 'No Assignment');
         v_errorlog_count := v_errorlog_count + 1;
         apps.fnd_file.put_line (apps.fnd_file.LOG, l_errorlog_output);
        -- RAISE skip_record;
      WHEN TOO_MANY_ROWS
      THEN
         p_process_status  := 'Too Many Assignments';
         l_errorlog_output := (RPAD (v_ssn, 29) || 'Too Many Assignments');
         v_errorlog_count := v_errorlog_count + 1;
         apps.fnd_file.put_line (apps.fnd_file.LOG, l_errorlog_output);
         --RAISE skip_record;
      WHEN OTHERS
      THEN
         p_process_status  := 'Other Assignment Issue';
         l_errorlog_output := (RPAD (v_ssn, 29) || 'Other Assignment Issue');
         v_errorlog_count := v_errorlog_count + 1;
         apps.fnd_file.put_line (apps.fnd_file.LOG, l_errorlog_output);
         --RAISE skip_record;
   END;                                       --*** END GET ASSIGNMENT ID***--

---***********************************  Get Location Code ********************************-----
   PROCEDURE get_location (
      v_ssn             IN       VARCHAR2
    , v_location_code   OUT      VARCHAR2
    , p_process_status  OUT      VARCHAR2
   )
   IS
      l_location_code   VARCHAR2 (150) := NULL;
   BEGIN
      SELECT DISTINCT loc.location_code
                 INTO l_location_code
                --START R12.2 Upgrade Remediation
				/*FROM hr.per_all_people_f emp					-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
                    , hr.per_all_assignments_f asg
                    , hr.hr_locations_all loc*/
				 FROM apps.per_all_people_f emp					--  code Added by IXPRAVEEN-ARGANO,09-May-2023
                    , apps.per_all_assignments_f asg
                    , apps.hr_locations_all loc	
				--END R12.2.10 Upgrade remediation	
                WHERE emp.person_id = asg.person_id
                  AND loc.location_id = asg.location_id
                  AND asg.primary_flag = 'Y'
                  AND asg.assignment_type = 'E'
                  --   and loc.attribute2  = v_unit_division
                  AND TRUNC (SYSDATE) BETWEEN emp.effective_start_date
                                          AND emp.effective_end_date
                  AND TRUNC (SYSDATE) BETWEEN asg.effective_start_date
                                          AND asg.effective_end_date
                  AND emp.national_identifier = v_ssn;

      --and emp.national_identifier = '053-60-6407'--v_ssn
      v_location_code := l_location_code;
      p_process_status := 'Found';
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         p_process_status := 'No Location';
         l_errorlog_output :=
                       (RPAD (v_ssn, 29) ||  'No Location'
                       );
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
         l_errorlog_output :=
                 (RPAD (v_ssn, 29) ||  'No Other Location'
                 );
         v_errorlog_count := v_errorlog_count + 1;
         apps.fnd_file.put_line (apps.fnd_file.LOG, l_errorlog_output);
         --RAISE skip_record;
   END;

--***************************************************************
--*****                  GET PERSON TYPE                *****
--***************************************************************
 --get_person_type(sel.employee_number, l_system_person_type);
   PROCEDURE get_person_type (
      v_ssn                   IN       VARCHAR2
    , v_person_id             OUT      NUMBER
    , v_assignment_id         IN       NUMBER
    , v_pay_basis_id          OUT      NUMBER
    , v_employment_category   OUT      VARCHAR2
    , v_people_group_id       OUT      NUMBER
    , v_system_person_type    OUT      VARCHAR2
    , p_process_status        OUT      VARCHAR2
   )
   IS
      v_effective_end_date   DATE := NULL;
   BEGIN
      SELECT DISTINCT asg.person_id, asg.effective_end_date
                    , asg.pay_basis_id, asg.employment_category
                    , asg.people_group_id, TYPES.system_person_type
                 INTO v_person_id, v_effective_end_date
                    , v_pay_basis_id, v_employment_category
                    , v_people_group_id, v_system_person_type
                 --START R12.2 Upgrade Remediation
				 /*FROM hr.per_all_assignments_f asg				-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
                    , hr.per_all_people_f emp
                    , hr.per_person_types TYPES*/
				 FROM apps.per_all_assignments_f asg					--  code Added by IXPRAVEEN-ARGANO,09-May-2023
                    , apps.per_all_people_f emp
                    , apps.per_person_types TYPES	
				 --END R12.2.10 Upgrade remediation	
				 	
                WHERE emp.person_id = asg.person_id
                  AND TYPES.person_type_id = emp.person_type_id
                  AND asg.primary_flag = 'Y'
                  AND asg.assignment_type = 'E'
                  AND TRUNC (SYSDATE) BETWEEN emp.effective_start_date
                                          AND emp.effective_end_date
                  AND TRUNC (SYSDATE) BETWEEN asg.effective_start_date
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

---**************************************************************************************
   PROCEDURE get_employee_status (
      v_ssn                    IN       VARCHAR2
    , v_system_person_status   OUT      VARCHAR2
    , p_process_status         OUT      VARCHAR2
   )
   IS
      l_system_person_status   VARCHAR2 (50) := NULL;
   BEGIN
      SELECT DISTINCT NVL (amdtl.user_status, sttl.user_status)
                 INTO v_system_person_status
                 --START R12.2 Upgrade Remediation
				 /*FROM hr.per_all_people_f emp						-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
                    , hr.per_all_assignments_f asg
                    , hr.per_person_types TYPES
                    , hr.per_ass_status_type_amends_tl amdtl
                    , hr.per_assignment_status_types_tl sttl
                    , hr.per_assignment_status_types st
                    , hr.per_ass_status_type_amends amd*/
				 FROM apps.per_all_people_f emp				        --  code Added by IXPRAVEEN-ARGANO,09-May-2023
                    , apps.per_all_assignments_f asg
                    , apps.per_person_types TYPES
                    , apps.per_ass_status_type_amends_tl amdtl
                    , apps.per_assignment_status_types_tl sttl
                    , apps.per_assignment_status_types st
                    , apps.per_ass_status_type_amends amd	
					--END R12.2.10 Upgrade remediation
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
                  AND DECODE (amdtl.ass_status_type_amend_id
                            , NULL, '1'
                            , amdtl.LANGUAGE
                             ) =
                         DECODE (amdtl.ass_status_type_amend_id
                               , NULL, '1'
                               , USERENV ('LANG')
                                )
                  AND TRUNC (SYSDATE) BETWEEN emp.effective_start_date
                                          AND emp.effective_end_date
                  AND TRUNC (SYSDATE) BETWEEN asg.effective_start_date
                                          AND asg.effective_end_date
                  AND emp.national_identifier = v_ssn;
--and rownum < 2;

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

----************************************Find if employee has loan ****************************-------
   PROCEDURE get_element_entry_id (
      v_ssn                IN       VARCHAR2
    , v_element_entry_id   OUT      NUMBER
    , p_isthere_newloan    IN OUT   VARCHAR2
    , p_process_status        OUT   VARCHAR2
   )
   IS
   BEGIN
      SELECT DISTINCT entry.element_entry_id              --- element_entry_id
                 INTO v_element_entry_id
                 --START R12.2 Upgrade Remediation
				 /*FROM hr.pay_element_entries_f entry				-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
                    , hr.pay_element_links_f LINK
                    , hr.per_all_assignments_f asg
                    , hr.per_all_people_f emp
                    , hr.pay_element_types_f etypes
                    , hr.pay_element_entry_values_f entval
                    , hr.pay_input_values_f input*/
				 FROM apps.pay_element_entries_f entry				--  code Added by IXPRAVEEN-ARGANO,09-May-2023
                    , apps.pay_element_links_f LINK
                    , apps.per_all_assignments_f asg
                    , apps.per_all_people_f emp
                    , apps.pay_element_types_f etypes
                    , apps.pay_element_entry_values_f entval
                    , apps.pay_input_values_f input	
				--END R12.2.10 Upgrade remediation	
                WHERE entry.assignment_id = asg.assignment_id
                  AND LINK.element_type_id = etypes.element_type_id
                  AND entval.element_entry_id = entry.element_entry_id
                  AND etypes.element_type_id = input.element_type_id
                  AND input.input_value_id = entval.input_value_id
                  AND input.NAME = 'Amount'
                  AND LINK.element_link_id = entry.element_link_id
                  AND entry.effective_start_date
                         BETWEEN asg.effective_start_date
                             AND asg.effective_end_date
                  AND TRUNC (SYSDATE) BETWEEN emp.effective_start_date
                                          AND emp.effective_end_date
                  AND entry.effective_start_date
                         BETWEEN LINK.effective_start_date
                             AND LINK.effective_end_date
                  AND emp.person_id = asg.person_id
                  AND entry.effective_end_date =
                           (SELECT MAX (effective_end_date)
                              FROM pay_element_entries_f entry2
                             WHERE entry.assignment_id = entry2.assignment_id)
                  AND entval.effective_start_date =
                         (SELECT MAX (effective_start_date)
                            FROM pay_element_entry_values_f entval2
                           WHERE entval.element_entry_id =
                                                      entval2.element_entry_id)
                  AND etypes.element_name IN ('Loan 1_401k')
                  AND emp.national_identifier = v_ssn;

      -- and  emp.national_identifier = '012-48-4640'--'373-80-6304';
      p_isthere_newloan := 'YES';
      p_process_status := 'Found';
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         p_isthere_newloan := 'NO';
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
         --RAISE skip_record;
      WHEN OTHERS
      THEN
         p_process_status := 'Other in Element Entry';
         l_errorlog_output := (RPAD (v_ssn, 29) || 'Other in Element Entry');
         v_errorlog_count := v_errorlog_count + 1;
         apps.fnd_file.put_line (apps.fnd_file.LOG, l_errorlog_output);
         --RAISE skip_record;
   END;

--***************************************************************
--*****                  GET Element Link ID                *****
--***************************************************************
   PROCEDURE get_element_link_id (
      v_ssn                   IN       VARCHAR2
    , v_element_name          IN       VARCHAR2
    , v_business_group_id     IN       NUMBER
    , v_pay_basis_id          IN       NUMBER
    , v_employment_category   IN       VARCHAR2
    , v_people_group_id       IN       NUMBER
    , v_payroll_id            IN       NUMBER  /* 2.1 */
    , v_location_id           IN       NUMBER  /* 2.1 */
    , v_element_link_id       OUT      NUMBER
    , p_process_status        OUT      VARCHAR2
   )
   IS
   BEGIN
      SELECT LINK.element_link_id
        INTO v_element_link_id
        --FROM hr.pay_element_links_f LINK, hr.pay_element_types_f TYPES			-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
		FROM apps.pay_element_links_f LINK, apps.pay_element_types_f TYPES			--  code Added by IXPRAVEEN-ARGANO,09-May-2023
       WHERE LINK.element_type_id = TYPES.element_type_id
         AND LINK.business_group_id = v_business_group_id
         AND TYPES.element_name = v_element_name
         AND ( (v_payroll_id is null and link.LOCATION_ID = v_location_id)  /* 2.1 */
              OR (v_payroll_id is not null and link.LINK_TO_ALL_PAYROLLS_FLAG = 'Y') /* 2.1 */
         )
         AND NVL (LINK.employment_category, v_employment_category) =
                                                         v_employment_category
         AND NVL (LINK.people_group_id, v_people_group_id) = v_people_group_id
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
         apps.fnd_file.put_line (apps.fnd_file.LOG, '       v_pay_basis_id>> '||v_pay_basis_id); /* 2.1 */
         apps.fnd_file.put_line (apps.fnd_file.LOG, 'v_employment_category>> '||v_employment_category); /* 2.1 */
         apps.fnd_file.put_line (apps.fnd_file.LOG, '   v_people_group_id >> '||v_people_group_id );     /* 2.1 */
         apps.fnd_file.put_line (apps.fnd_file.LOG, '        Element Name >> '||v_element_name );     /* 2.1 */
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
         apps.fnd_file.put_line (apps.fnd_file.LOG, '       v_pay_basis_id>> '||v_pay_basis_id); /* 2.1 */
         apps.fnd_file.put_line (apps.fnd_file.LOG, 'v_employment_category>> '||v_employment_category); /* 2.1 */
         apps.fnd_file.put_line (apps.fnd_file.LOG, '   v_people_group_id >> '||v_people_group_id );     /* 2.1 */
         apps.fnd_file.put_line (apps.fnd_file.LOG, '        Element Name >> '||v_element_name );     /* 2.1 */
         apps.fnd_file.put_line (apps.fnd_file.LOG, '               Error >> '||p_process_status||' '||l_errorlog_output);
         --RAISE skip_record;
   END;

--***************************************************************
--*****               Create Element Entry            *****
--***************************************************************
   PROCEDURE do_create_element_entry (
      v_ssn                     IN       VARCHAR2
    , l_validate                IN       BOOLEAN
    , l_loan_effective_date     IN       DATE
    , l_business_group_id       IN       NUMBER
    , l_assignment_id           IN       NUMBER
    , l_element_link_id         IN       NUMBER
    , l_input_value_id_amount   IN       NUMBER
    , l_payment_amt             IN       NUMBER
    , l_input_value_id_owed     IN       NUMBER
    , l_goal_amt                IN       NUMBER
    , l_update_status           IN OUT   VARCHAR2
   )
   IS
      l_effective_start_date    DATE;
      l_effective_end_date      DATE;
      l_element_entry_id        NUMBER;
      l_object_version_number   NUMBER;
      l_create_warning          BOOLEAN;
   BEGIN
      -- create the entry in the HR Schema
      pay_element_entry_api.create_element_entry
                         (p_validate                   => l_validate
                        , p_effective_date             => l_loan_effective_date
                        , p_business_group_id          => l_business_group_id
                        , p_assignment_id              => l_assignment_id
                        , p_element_link_id            => l_element_link_id
                        , p_entry_type                 => 'E'
                        , p_input_value_id1            => l_input_value_id_amount
                        , p_entry_value1               => l_payment_amt
                        , p_input_value_id2            => l_input_value_id_owed
                        , p_entry_value2               => l_goal_amt
--Out Parameters
      ,                   p_effective_start_date       => l_effective_start_date
                        , p_effective_end_date         => l_effective_end_date
                        , p_element_entry_id           => l_element_entry_id
                        , p_object_version_number      => l_object_version_number
                        , p_create_warning             => l_create_warning
                         );
      l_update_status := 'Element Entry Created';
      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         l_errorlog_output :=
                     (RPAD (v_ssn, 29) || 'Element Entry Fallout' || SQLERRM
                     );
         v_errorlog_count := v_errorlog_count + 1;
         apps.fnd_file.put_line (apps.fnd_file.LOG, l_errorlog_output);
         RAISE skip_record;
         apps.fnd_file.put_line (apps.fnd_file.LOG
                               ,    'After NEW ENTRY Start Date->'
                                 || l_effective_start_date
                                 || ' '
                                 || l_element_entry_id
                                );
   END;
----------------End Create Element Entry ********************************************

--***************************************************************
--*****                  MAIN Program                       *****
--***************************************************************
   PROCEDURE main (
      errcode          OUT      VARCHAR2
    , errbuff          OUT      VARCHAR2
    , p_process_date   IN       VARCHAR2
   )
   IS
      --
      v_output_dir               VARCHAR2 (400) := p_output_dir;
                                                             ---VARCHAR2(240)
      l_active_output            VARCHAR2 (400);                ---CHAR(400);
      v_active_count             NUMBER         := 0;
      l_oratermed_output         VARCHAR2 (400);                 --CHAR(400);
      l_process_status           VARCHAR2 (400);
      v_oratermed_count          NUMBER         := 0;
      -- v_termed_count    number := 0;
      -- l_errorlog_output     CHAR(242);
      -- v_errorlog_count    number := 0;
        --l_termed_output     CHAR(242);
      total_payment_amt          NUMBER         := 0;
      total_goal_amt             NUMBER         := 0;
      lcalc_payment_amt          NUMBER         := 0;
      lcalc_goal_amt             NUMBER         := 0;
      l_rows_active_read         NUMBER         := 0;     -- rows read by api
      l_rows_active_processed    NUMBER         := 0;
                                                     -- rows processed by api
      l_rows_active_skipped      NUMBER         := 0;         -- rows skipped
      l_rows_read                NUMBER         := 0;     -- rows read by api
      l_rows_skipped             NUMBER         := 0;         -- rows skipped
      l_business_group_id        NUMBER         := NULL;
      l_location_code            VARCHAR2 (150);
      l_employee_number          VARCHAR2 (60);
      l_person_id                NUMBER;
      l_assignment_id            NUMBER;
      l_system_person_type       VARCHAR2 (30)  := NULL;
      l_system_person_status     VARCHAR2 (50)  := NULL;
      l_element_link_id          NUMBER;
      l_input_value_id1          NUMBER         := NULL;
      l_input_value_id2          NUMBER         := NULL;
      l_input_value_id_amount    NUMBER         := NULL;
      l_input_value_id_owed      NUMBER         := NULL;
      v_effective_start_date     DATE           := NULL;
      l_effective_element_date   DATE           := NULL;
      l_element_update_date      DATE           := NULL;
      l_pay_basis_id             NUMBER         := NULL;
      l_employment_category      VARCHAR2 (10)  := NULL;
      l_people_group_id          NUMBER         := NULL;
      l_payroll_id               NUMBER         := NULL; /* 2.1 */
      l_location_id              NUMBER         := NULL; /* 2.1 */
      l_screen_entry_value       NUMBER;
      -- l_update_status                 varchar2(150):= 'Did Not Update';
       -- OUT parameters
       --
      l_effective_start_date     DATE;
      l_effective_end_date       DATE;
      l_element_entry_id         NUMBER;
      l_object_version_number    NUMBER;
      l_create_warning           BOOLEAN;
      l_delete_warning           BOOLEAN;
      l_update_warning           BOOLEAN;
      v_todays_date              DATE;                        --varchar2(11);
      l_deferral_date            DATE           := TRUNC (SYSDATE);
   BEGIN                                                      ---Starting main
      v_module := 'Obtain Process Date';

      IF p_process_date = 'DD-MON-RRRR'
      THEN
         g_newloan_date := TRUNC (SYSDATE);
         v_plan_entry_date := TRUNC (SYSDATE);
      ELSE
         g_newloan_date := TO_DATE (p_process_date);
         v_plan_entry_date := TO_DATE (p_process_date);
      END IF;

      apps.fnd_file.put_line (apps.fnd_file.output
                            , 'Begin Processing 401K Loan1 >>> '
                              || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS')
                             );
      apps.fnd_file.put_line (apps.fnd_file.output
                            , 'Process Date          : ' || p_process_date
                             );
      apps.fnd_file.put_line (apps.fnd_file.output
                            , 'Loan Effective Date   : '
                              || TO_CHAR (g_newloan_date, 'DD-MON-RRRR')
                             );
 -- version 2.0 added emp name and ssn
      l_active_output :=
      (    'Name|'
          ||'Emp No|'
          ||'SSN|'
          || 'Assignment Status|'
          || 'Location|'
          || 'Effective Date|'
          || 'Payment Amt|'
          || 'Goal Amt|'
          || 'Update Status'
         );
      apps.fnd_file.put_line (apps.fnd_file.output, l_active_output);

      FOR sel IN csr_newloan
      LOOP

         l_payroll_id := NULL; /* 2.1 */
         l_location_id := NULL; /* 2.1 */
         l_rows_read := l_rows_read + 1;

         BEGIN

            get_assignment_id (sel.social_number
                             , l_employee_number
                             , l_assignment_id
                             , l_business_group_id
                             , l_payroll_id /* 2.1 */
                             , l_location_id /* 2.1 */
                             , l_effective_start_date
                             , l_effective_end_date
                             , l_process_status
                              );

            IF  l_process_status != 'Found' THEN
-- version 2.0 added emp name and ssn
               l_oratermed_output :=
                  ( sel.full_name
                  || '|'
                   ||sel.emp_no
                   || '|'
                   ||sel.social_number
                   || '|'
                   || l_process_status
                   || '|'
                   || ''
                   || '|'
                   || LPAD (TO_CHAR (g_newloan_date, 'MM/DD/YYYY'), 10)
                   || '|'
                   || LPAD (sel.payment_amt, 7)
                   || '|'
                   || LPAD (sel.goal_amt, 7)
                   || '|'
                   || 'Cannot be processed due to the following reason: '||l_process_status
                  );
                   apps.fnd_file.put_line (apps.fnd_file.output
                         , l_oratermed_output
                          );
                RAISE skip_record;
            END IF;
--            apps.fnd_file.put_line (apps.fnd_file.LOG
--                                  , 'Employee Number ' || l_employee_number
--                                   );
            get_location (sel.social_number
                        , l_location_code
                        , l_process_status
                         );
            IF  l_process_status != 'Found' THEN
-- version 2.0 added emp name and ssn
               l_oratermed_output :=
                  (
                   sel.full_name
                   || '|'
                   ||sel.emp_no
                    || '|'
                   ||sel.social_number
                   || '|'
                   || ''
                   || '|'
                   || l_process_status
                   || '|'
                   || LPAD (TO_CHAR (g_newloan_date, 'MM/DD/YYYY'), 10)
                   || '|'
                   || LPAD (sel.payment_amt, 7)
                   || '|'
                   || LPAD (sel.goal_amt, 7)
                   || '|'
                   || 'Cannot be processed due to the following reason: '||l_process_status
                  );
                   apps.fnd_file.put_line (apps.fnd_file.output
                         , l_oratermed_output
                          );
                RAISE skip_record;
            END IF;

            get_person_type (sel.social_number
                           , l_person_id
                           , l_assignment_id
                           , l_pay_basis_id
                           , l_employment_category
                           , l_people_group_id
                           , l_system_person_type
                           , l_process_status
                            );

            IF  l_process_status != 'Found' THEN
-- version 2.0 added emp name and ssn
               l_oratermed_output :=
                  (
                    sel.full_name
                   || '|'
                   ||sel.emp_no
                   || '|'
                   ||sel.social_number
                   || '|'
                   || l_process_status
                   || '|'
                   || l_location_code
                   || '|'
                   || LPAD (TO_CHAR (g_newloan_date, 'MM/DD/YYYY'), 10)
                   || '|'
                   || LPAD (sel.payment_amt, 7)
                   || '|'
                   || LPAD (sel.goal_amt, 7)
                   || '|'
                   || 'Cannot be processed due to the following reason: '||l_process_status
                  );
                   apps.fnd_file.put_line (apps.fnd_file.output
                         , l_oratermed_output
                          );
                RAISE skip_record;
            END IF;
--            apps.fnd_file.put_line (apps.fnd_file.LOG
--                                  ,    'Employee Assgn '
--                                    || l_assignment_id
--                                    || ' Person Type'
--                                    || l_system_person_type
--                                    || ' Pay Basis '
--                                    || l_pay_basis_id
--                                    || ' P_Group_Id '
--                                    || l_people_group_id
--                                   );
            get_employee_status (sel.social_number, l_system_person_status, l_process_status );

            IF  l_process_status != 'Found' THEN
-- version 2.0 added emp name and ssn
              l_oratermed_output :=
                  (
                    sel.full_name
                   || '|'
                   ||sel.emp_no
                   || '|'
                   ||sel.social_number
                   || '|'
                   || l_system_person_type
                   || '|'
                   || l_location_code
                   || '|'
                   || LPAD (TO_CHAR (g_newloan_date, 'MM/DD/YYYY'), 10)
                   || '|'
                   || LPAD (sel.payment_amt, 7)
                   || '|'
                   || LPAD (sel.goal_amt, 7)
                   || '|'
                   || 'Cannot be processed due to the following reason: '||l_process_status
                  );
                   apps.fnd_file.put_line (apps.fnd_file.output
                         , l_oratermed_output
                          );
                RAISE skip_record;
            END IF;


--            apps.fnd_file.put_line (apps.fnd_file.LOG
--                                  ,    'Employee SSN '
--                                    || sel.social_number
--                                    || ' EMP_NO: '
--                                    || l_employee_number
--                                    || ' Empl Category '
--                                    || l_employment_category
--                                    || ' Employee Status'
--                                    || l_system_person_status
--                                   );

            IF l_system_person_status = 'Terminate - Process'
            THEN
            -- version 2.0 added emp name and ssn
               l_oratermed_output :=
                  (
                   sel.full_name
                   || '|'
                   ||l_employee_number
                   || '|'
                   ||sel.social_number
                   || '|'
                   || RPAD (l_system_person_status, 20)
                   || '|'
                   || RPAD (l_location_code, 25)
                   || '|'
                   || LPAD (TO_CHAR (g_newloan_date, 'MM/DD/YYYY'), 10)
                   || '|'
                   || LPAD (sel.payment_amt, 7)
                   || '|'
                   || LPAD (sel.goal_amt, 7)
                   || '|'
                   || 'No Update due to Employee is no longer active'
                  );

               v_oratermed_count := v_oratermed_count + 1;
               apps.fnd_file.put_line (apps.fnd_file.output
                                     , l_oratermed_output
                                      );
            END IF;

            IF l_system_person_status <> 'Terminate - Process'
            THEN                                              ---person_status
               l_isthere_newloan := 'NO';
               l_element_entry_id := NULL;
               --begin
               get_element_entry_id (sel.social_number
                                   , l_element_entry_id
                                   , l_isthere_newloan
                                   , l_process_status
                                    );

                IF  l_process_status != 'Found' THEN
-- version 2.0 added emp name and ssn
                   l_oratermed_output :=
                      (
                      sel.full_name
                       || '|'
                       ||sel.emp_no
                       || '|'
                       ||sel.social_number
                       || '|'
                       || l_system_person_type
                       || '|'
                       || l_location_code
                       || '|'
                       || LPAD (TO_CHAR (g_newloan_date, 'MM/DD/YYYY'), 10)
                       || '|'
                       || LPAD (sel.payment_amt, 7)
                       || '|'
                       || LPAD (sel.goal_amt, 7)
                       || '|'
                       || 'Cannot be processed due to the following reason: '||l_process_status
                      );
                       apps.fnd_file.put_line (apps.fnd_file.output
                             , l_oratermed_output
                              );
                    RAISE skip_record;
                END IF;

--               apps.fnd_file.put_line (apps.fnd_file.LOG
--                                     ,    'Employee Number '
--                                       || sel.social_number
--                                       || 'Element ID'
--                                       || l_element_entry_id
--                                      );
--               apps.fnd_file.put_line (apps.fnd_file.LOG
--                                     , 'Loan Status ' || l_isthere_newloan
--                                      );

               IF l_isthere_newloan = 'YES'
               THEN
               -- version 2.0 added emp name and ssn
                  l_errorlog_output :=
                     (
                    sel.full_name
                   || '|'
                   || l_employee_number
                   || '|'
                   ||sel.social_number
                   || '|'
                   || RPAD (l_system_person_status, 20)
                   || '|'
                   || RPAD (l_location_code, 25)
                   || '|'
                   || LPAD (TO_CHAR (g_newloan_date, 'MM/DD/YYYY'), 10)
                   || '|'
                   || LPAD (sel.payment_amt, 7)
                   || '|'
                   || LPAD (sel.goal_amt, 7)
                   || '|'
                   || RPAD ('Has existing loan', 20)
                     );
                  v_errorlog_count := v_errorlog_count + 1;
                  apps.fnd_file.put_line (apps.fnd_file.output
                                        , l_errorlog_output
                                         );
               --  end if;

               --   if l_isthere_newloan = 'NO' and l_element_entry_id = null then
               ELSE
                  lcalc_payment_amt := 0;
                  lcalc_goal_amt := 0;

                  --    l_rows_read := l_rows_read + 1;
                  BEGIN
                     SELECT input.input_value_id
                       INTO l_input_value_id_amount
					   --START R12.2 Upgrade Remediation
                       /*FROM hr.pay_input_values_f input					-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
                          , hr.pay_element_types_f etypes*/
					   FROM apps.pay_input_values_f input					--  code Added by IXPRAVEEN-ARGANO,09-May-2023
                          , apps.pay_element_types_f etypes	
                     --END R12.2.10 Upgrade remediation						  
                      WHERE etypes.element_type_id = input.element_type_id
                        AND etypes.element_name = 'Loan 1_401k'
                        AND input.NAME = 'Amount'              ---g_input_name
                        AND input.business_group_id = 325;
                  END;

                  BEGIN
                     SELECT input.input_value_id
                       INTO l_input_value_id_owed
					   --START R12.2 Upgrade Remediation
                      /* FROM hr.pay_input_values_f input				-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
                          , hr.pay_element_types_f etypes*/
					   FROM apps.pay_input_values_f input				--  code Added by IXPRAVEEN-ARGANO,09-May-2023
                          , apps.pay_element_types_f etypes	  
						  --END R12.2.10 Upgrade remediation
                      WHERE etypes.element_type_id = input.element_type_id
                        AND etypes.element_name = 'Loan 1_401k'
                        AND input.NAME = 'Total Owed'          ---g_input_name
                        AND input.business_group_id = 325;
                  END;

                  get_element_link_id (sel.social_number
                                     , g_element_name
                                     , l_business_group_id
                                     , l_pay_basis_id
                                     , l_employment_category
                                     , l_people_group_id
                                     , l_payroll_id /* 2.1 */
                                     , l_location_id /* 2.1 */
                                     , l_element_link_id
                                     , l_process_status
                                      );

                IF  l_process_status != 'Found' THEN

                  -- version 2.0 added emp name and ssn
                   l_oratermed_output :=
                      (
                      sel.full_name
                       || '|'
                       ||sel.emp_no
                       || '|'
                       ||sel.social_number
                       || '|'
                       || l_system_person_type
                       || '|'
                       || l_location_code
                       || '|'
                       || LPAD (TO_CHAR (g_newloan_date, 'MM/DD/YYYY'), 10)
                       || '|'
                       || LPAD (sel.payment_amt, 7)
                       || '|'
                       || LPAD (sel.goal_amt, 7)
                       || '|'
                       || 'Cannot be processed due to the following reason: '||l_process_status
                      );
                       apps.fnd_file.put_line (apps.fnd_file.output
                             , l_oratermed_output
                              );
                    RAISE skip_record;
                END IF;

--                  apps.fnd_file.put_line (apps.fnd_file.LOG
--                                        ,    'Employee Number     '
--                                          || l_employee_number
--                                          || ' Element Name '
--                                          || g_element_name
--                                          || ' Element Link '
--                                          || l_element_link_id
--                                          || ' Input Value '
--                                          || l_input_value_id1
--                                         );
                  l_update_status := 'Did Not Update';
                  do_create_element_entry (sel.social_number
                                         , g_validate
                                         , g_newloan_date
                                         , l_business_group_id
                                         , l_assignment_id
                                         , l_element_link_id
                                         , l_input_value_id_amount
                                         , sel.payment_amt
                                         , l_input_value_id_owed
                                         , sel.goal_amt
                                         , l_update_status
                                          );
                   --   end if;
                  --    end;

                  ----- Active enteries -----------

                  -----*********************************Print Active Files *****************************************--------

                  ---*******************************************************************************************-------
--  end if; --    keeping track of datetrack issues ---- 26-apr-2005

                  --  lcalc_payment_amt   := nvl(sel.payment_amt,0),'09999.99');
                  -- lcalc_goal_amt      := nvl(sel.goal_amt,0),'09999.99');
         -- version 2.0 added emp name and ssn
                  l_active_output :=
                     (
                       sel.full_name
                       || '|'
                       ||l_employee_number
                       || '|'
                       ||sel.social_number
                       || '|'
                       || RPAD (l_system_person_status, 20)
                       || '|'
                       || RPAD (l_location_code, 25)
                       || '|'
                       || LPAD (TO_CHAR (g_newloan_date, 'MM/DD/YYYY'), 10)
                       || '|'
                       || LPAD (sel.payment_amt, 7)
                       || '|'
                       || LPAD (sel.goal_amt, 7)
                       || '|'
                       || LPAD (SUBSTR (NVL (l_update_status, ' '), 1, 25), 25)
                     );

                  apps.fnd_file.put_line (apps.fnd_file.output
                                        , l_active_output
                                         );

                 -- total_payment_amt := total_payment_amt + to_number(sel.payment_amt);  -- 2.0
                 -- total_goal_amt    := total_goal_amt + to_number(sel.goal_amt);  -- 2.0
                  v_active_count    := v_active_count + 1;
               END IF;
--end;
 ---**********************************************************************************************************
            END IF;                                           -- person_status
         EXCEPTION
            WHEN skip_record
            THEN
               NULL;
         END;
      END LOOP;

      COMMIT;                                         -- commit any final rows
      ---************************************ Summary of Active Employees **************************--------
      apps.fnd_file.put_line (apps.fnd_file.output, 'Tot Loan Processed:   ' ||  v_active_count );
      --apps.fnd_file.put_line (apps.fnd_file.output, 'Tot Payment Amt:      ' ||  total_payment_amt);
     -- apps.fnd_file.put_line (apps.fnd_file.output, 'Tot Goal Amt:         ' ||  total_goal_amt);
      ---***********************************End Summary of Active Employees ****************************--------

      ---************************************** Summary of Error Records ***************************---------
      apps.fnd_file.put_line (apps.fnd_file.output, 'Tot Loan Unprocessed: ' || v_errorlog_count);
      -----*********************************** End Summary of Error Records ************************-----------
      ---**************************************** Summary of Oracle Termed ********************--
      apps.fnd_file.put_line (apps.fnd_file.output, 'Tot Oracle Termed:    ' || v_oratermed_count);
      apps.fnd_file.put_line (apps.fnd_file.output, 'Tot Number of Records:    ' || l_rows_read);
--*******************************************************************************************---

      -- ********************************************End Element Entries   ----------

   EXCEPTION
      WHEN UTL_FILE.invalid_operation
      THEN
         raise_application_error (-20051
                                , p_filename || ':  Invalid Operation'
                                 );
         ROLLBACK;
      WHEN UTL_FILE.invalid_filehandle
      THEN
         raise_application_error (-20052
                                , p_filename || ':  Invalid File Handle'
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
         raise_application_error (-20058
                                , p_filename || ':  Maxlinesize Error'
                                 );
         ROLLBACK;
      WHEN INVALID_CURSOR
      THEN
         ttec_error_logging.process_error
                                  (g_application_code                 -- 'BEN'
                                 , g_interface             -- 'BOA 401K Intf';
                                 , g_package  -- 'TTEC_BAML_401K_DEFERRAL_INT'
                                 , v_module
                                 , g_failure_status
                                 , SQLCODE
                                 , SQLERRM
                                 , g_label1
                                 , v_loc
                                 , g_label2
                                 , g_emp_no
                                  );
         errcode := SQLCODE;
         errbuff := SUBSTR (SQLERRM, 1, 255);
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error
                                  (g_application_code                 -- 'BEN'
                                 , g_interface             -- 'BOA 401K Intf';
                                 , g_package  -- 'TTEC_BAML_401K_DEFERRAL_INT'
                                 , v_module
                                 , g_failure_status
                                 , SQLCODE
                                 , SQLERRM
                                 , g_label1
                                 , v_loc
                                 , g_label2
                                 , g_emp_no
                                  );
         errcode := SQLCODE;
         errbuff := SUBSTR (SQLERRM, 1, 255);
         apps.fnd_file.put_line
                  (apps.fnd_file.LOG
                 ,    'Exception OTHERS in TTEC_BAML_401K_DEFERRAL_INT.main: '
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
                  (-20003
                 ,    'Exception OTHERS in TTEC_BAML_401K_DEFERRAL_INT.main: '
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
END ttec_baml_401k_loan_int;
/
show errors;
/