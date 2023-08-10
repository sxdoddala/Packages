create or replace PACKAGE BODY ttec_sup_load_pkg
IS
--************************************************************************************--
--*                                                                                  *--
--*     Program Name: ttec_us_supervisor.sql                                         *--
--*                                                                                  *--
--*     Description:  The supervisor script is to load changes to employees       *--
--*              organization in the Oracle HR application. This is            *--
--*               accomplished using a series of Oracle HR APIs:               *--
--*               HR_ASSIGNMENT_API.update_us_emp_asg AND                      *--
--*                                                                                  *--
--*                                                                                  *--
--*     Input/Output Parameters:                                                     *--
--*                                                                                  *--
--*     Tables Accessed:                                                             *--
--*                        HR_ALL_ORGANIZATION_UNITS                                 *--
--*                        TTEC_ERROR_HANDLING                                       *--
--*                       PER_ALL_ASSIGNMENTS_F                                      *--
--*                        PER_ALL_PEOPLE_F                                          *--
--*                                                                                  *--
--*     Tables Modified:                                                    *--
--*                        TTEC_ERROR_HANDLING                                       *--
--*                        PER_ALL_ASSIGNMENTS_F                                     *--
--*     Procedures Called:                                                           *--
--*                        HR_ASSIGNMENT_API.UPDATE_US_EMP_ASG                       *--
--*                        TTEC_PROCESS_ERROR                                        *--
--*                                                                                  *--
--*Created By: Elizur Alfred-Ockiya                                                        *--
--*Date: 02/02/2004                                                                  *--
--*                                                                                  *--
--*Modification Log:                                                                 *--
--*Developer          Date        Description                                     *--
--*---------          ----        -----------                                     *--
--* E Alfred-Ockiya      02-02-04    Created
--* Wasim Manasfi      3-10-2006   Modified to read from file directly
--* MLagostena        10-15-2008  Modified get_assignment_id and import_sup_change to call gb API when BG 1517 (Incident# 1027265)
 --IXPRAVEEN(ARGANO)  05-May-2023		R12.2 Upgrade Remediation
--************************************************************************************--

   --    SET TIMING ON
   -- SET SERVEROUTPUT ON SIZE 1000000;

   --    DECLARE

   --*** VARIABLES USED BY COMMON ERROR HANDLING PROCEDURES ***--
   --START R12.2 Upgrade Remediation
   
   /*c_application_code            cust.ttec_error_handling.application_code%TYPE			-- Commented code by IXPRAVEEN-ARGANO,05-May-2023
                                                                      := 'HR';
   c_interface                   cust.ttec_error_handling.INTERFACE%TYPE
                                                                  := 'US_SUP';
   c_program_name                cust.ttec_error_handling.program_name%TYPE
                                                             := 'ttec_us_sup';
   c_initial_status              cust.ttec_error_handling.status%TYPE
                                                                 := 'INITIAL';
   c_warning_status              cust.ttec_error_handling.status%TYPE
                                                                 := 'WARNING';
   c_failure_status              cust.ttec_error_handling.status%TYPE
                                                                 := 'FAILURE';*/
   c_application_code            apps.ttec_error_handling.application_code%TYPE			--  code Added by IXPRAVEEN-ARGANO,05-May-2023
                                                                  := 'HR';
   c_interface                   apps.ttec_error_handling.INTERFACE%TYPE
                                                              := 'US_SUP';
   c_program_name                apps.ttec_error_handling.program_name%TYPE
                                                         := 'ttec_us_sup';
   c_initial_status              apps.ttec_error_handling.status%TYPE
                                                             := 'INITIAL';
   c_warning_status              apps.ttec_error_handling.status%TYPE
                                                            := 'WARNING';
   c_failure_status              apps.ttec_error_handling.status%TYPE
                                                                 := 'FAILURE';
--END R12.2.10 Upgrade remediation																 
   --User specified variables
   p_org_name                    VARCHAR2 (40)    := 'TeleTech Holdings - US';
   --p_org_name VARCHAR2(40)    := 'TeleTech Holdings - CAN';

   --*** Global Variable Declarations ***--
   g_default_code_comb_seg5      VARCHAR2 (4)                       := '0000';
   g_default_code_comb_seg6      VARCHAR2 (4)                       := '0000';
   g_proportion                  NUMBER                                  := 1;
   g_total_employees_read        NUMBER                                  := 0;
   g_total_employees_processed   NUMBER                                  := 0;
   g_total_record_count          NUMBER                                  := 0;
   g_primary_column              VARCHAR2 (60)                        := NULL;
   l_commit_point                NUMBER                                 := 20;
   l_rows_processed              NUMBER                                  := 0;
   --*** EXCEPTIONS ***--
   skip_record                   EXCEPTION;

   --*** CURSOR DECLARATION TO SELECT ROWS FROM CONV_HR_ASSIGNMENT_STAGE STAGING TABLE ***--
   CURSOR csr_cuhas
   IS
      SELECT sup1.employee_number employee_number,
             sup2.sup_number sup_number, sup1.effective_date effective_date,
             peep2.person_id supervisor_id
       -- FROM hr.per_all_people_f peep2,					-- Commented code by IXPRAVEEN-ARGANO,05-May-2023
		FROM apps.per_all_people_f peep2,				--  code Added by IXPRAVEEN-ARGANO,05-May-2023
             ttec_sup_load sup1,
             ttec_sup_load sup2
       WHERE sup1.employee_number = sup2.employee_number
         AND sup2.sup_number = peep2.employee_number
         AND SYSDATE BETWEEN peep2.effective_start_date
                         AND peep2.effective_end_date;

-- and sup1.employee_number = 1001557;
-- ORDER BY sup1.employee_number
   PROCEDURE print_line (v_data IN VARCHAR2)
   IS
   BEGIN
      fnd_file.put_line (fnd_file.output, v_data);
   END;

--***************************************************************
--*****                  GET Business Group ID              *****
--***************************************************************
/*
   PROCEDURE get_business_group_id (
      v_business_group_id   OUT      NUMBER,
      v_org_name            IN       VARCHAR2
   )
   IS
      l_module_name   cust.ttec_error_handling.module_name%TYPE
                                                   := 'get_business_group_id';
      l_label1        cust.ttec_error_handling.label1%TYPE      := 'Org Name';
      l_reference1    cust.ttec_error_handling.reference1%TYPE;
   BEGIN
      SELECT org.business_group_id
        INTO v_business_group_id
        FROM hr_organization_units org
       WHERE org.NAME = v_org_name;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         l_reference1 := v_org_name;
         print_line ('No business group id for this org: ' || v_org_name);
         v_business_group_id := NULL;
         RAISE skip_record;
      WHEN TOO_MANY_ROWS
      THEN
         l_reference1 := v_org_name;
         print_line (   'More than one business group id for this org: '
                     || v_org_name
                    );
         v_business_group_id := NULL;
         RAISE skip_record;
      WHEN OTHERS
      THEN
         l_reference1 := v_org_name;
         print_line (   'Error in select of business group id for this org: '
                     || v_org_name
                     || ' '
                     || SQLCODE
                     || ' '
                     || SUBSTR (SQLERRM, 1, 80)
                    );
         v_business_group_id := NULL;
         RAISE;
   END;
*/
--************************************************************************************--
--*                            GET PERSON ID                                 *--
--************************************************************************************--
   PROCEDURE get_person_id (
      v_person_id            OUT      NUMBER,
      v_per_eff_start_date   OUT      DATE,
      v_employee_number      IN       VARCHAR2,
      v_business_group_id    IN       NUMBER
   )
   IS
      l_module_name     cust.ttec_error_handling.module_name%TYPE
                                                           := 'get_person_id';
      l_label1          cust.ttec_error_handling.label1%TYPE
                                                            := 'Employee SSN';
      l_error_message   cust.ttec_error_handling.error_message%TYPE;
   BEGIN
--dbms_output.put_line('     '||v_employee_number);
      SELECT peep.person_id, peep.effective_start_date
        INTO v_person_id, v_per_eff_start_date
     --  FROM hr.per_all_people_f peep, hr.per_person_types peeptype				-- Commented code by IXPRAVEEN-ARGANO,05-May-2023
		FROM apps.per_all_people_f peep, apps.per_person_types peeptype				--  code Added by IXPRAVEEN-ARGANO,05-May-2023
       WHERE peep.employee_number = v_employee_number
         AND peep.business_group_id = v_business_group_id
         AND peep.person_type_id = peeptype.person_type_id
         AND peeptype.system_person_type = 'EMP'
         AND peep.effective_start_date = (SELECT MAX (effective_start_date)
                                            --FROM hr.per_all_people_f b			-- Commented code by IXPRAVEEN-ARGANO,05-May-2023
											FROM apps.per_all_people_f b			--  code Added by IXPRAVEEN-ARGANO,05-May-2023
                                           WHERE peep.person_id = b.person_id);
--dbms_output.put_line(v_person_id);
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         print_line (   'Error processing Employee: No employee record found'
                     || '|'
                     || v_employee_number
                    );
         RAISE skip_record;
      WHEN TOO_MANY_ROWS
      THEN
         print_line
             (   'Error processing Employee: Duplicate employee record found'
              || '|'
              || v_employee_number
             );
         RAISE skip_record;
      WHEN OTHERS
      THEN
         print_line
             (   'Error processing Employee: Error in  employee record found'
              || '|'
              || v_employee_number
              || '|'
              || SQLCODE
              || '|'
              || SUBSTR (SQLERRM, 1, 80)
             );
         RAISE;
   END;                                          --*** END GET PERSON ID ***--

--************************************************************************************--
--*                          GET ASSIGNMENT ID                             *--
--************************************************************************************--
   PROCEDURE get_assignment_id (
      v_employee_number         IN       VARCHAR2,
      v_person_id               IN       VARCHAR2,
      v_business_group_id       IN       NUMBER,
      v_assignment_id           OUT      NUMBER,
      v_asg_eff_date            OUT      DATE,
      v_object_version_number   OUT      NUMBER,
      -- Add parameter (MLagostena)
      v_soft_coding_keyflex_id  OUT      NUMBER
   )
   IS
   --START R12.2 Upgrade Remediation
 /*     l_module_name     cust.ttec_error_handling.module_name%TYPE				-- Commented code by IXPRAVEEN-ARGANO,05-May-2023
                                                       := 'get_assignment_id';
      l_label1          cust.ttec_error_handling.label1%TYPE
                                                            := 'Employee SSN';
      l_label2          cust.ttec_error_handling.label2%TYPE   := 'Person ID';
      l_error_message   cust.ttec_error_handling.error_message%TYPE;*/
	  l_module_name     apps.ttec_error_handling.module_name%TYPE				--  code Added by IXPRAVEEN-ARGANO,05-May-2023
                                                       := 'get_assignment_id';
      l_label1          apps.ttec_error_handling.label1%TYPE
                                                            := 'Employee SSN';
      l_label2          apps.ttec_error_handling.label2%TYPE   := 'Person ID';
      l_error_message   apps.ttec_error_handling.error_message%TYPE;
	  --END R12.2.10 Upgrade remediation
   BEGIN
      --dbms_output.put_line(v_employee_number||' '||v_person_id||' '||v_business_group_id);
      SELECT asg.assignment_id, asg.effective_start_date,
             asg.object_version_number,
             -- Add parameter (MLagostena)
             asg.SOFT_CODING_KEYFLEX_ID
             --End Modification (MLagostena)
        INTO v_assignment_id, v_asg_eff_date,
             v_object_version_number,
             -- Add parameter (MLagostena)
             v_soft_coding_keyflex_id
             --End Modification (MLagostena)
       -- FROM hr.per_all_assignments_f asg				-- Commented code by IXPRAVEEN-ARGANO,05-May-2023
		FROM apps.per_all_assignments_f asg				--  code Added by IXPRAVEEN-ARGANO,05-May-2023
       WHERE asg.person_id = v_person_id
         AND asg.primary_flag = 'Y'
         AND asg.assignment_type = 'E'
         AND asg.effective_start_date =
                (SELECT MAX (asg2.effective_start_date)
                   --FROM hr.per_all_assignments_f asg2				-- Commented code by IXPRAVEEN-ARGANO,05-May-2023
				   FROM apps.per_all_assignments_f asg2				--  code Added by IXPRAVEEN-ARGANO,05-May-2023
                  WHERE asg2.person_id = v_person_id
                    AND asg2.primary_flag = 'Y'
                    AND asg2.assignment_type = 'E'
                    AND asg2.business_group_id = v_business_group_id)
         AND asg.business_group_id = v_business_group_id;
   --dbms_output.put_line( v_assignment_id||' '||v_asg_eff_date||' '||v_object_version_number);
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         print_line (   'Error processing Employee: No employee record found'
                     || '|'
                     || v_employee_number
                    );
         RAISE skip_record;
      WHEN TOO_MANY_ROWS
      THEN
         print_line
             (   'Error processing Employee: Duplicate employee record found'
              || '|'
              || v_employee_number
             );
         RAISE skip_record;
      WHEN OTHERS
      THEN
         print_line
             (   'Error processing Employee: Error in  employee record found'
              || '|'
              || v_employee_number
              || '|'
              || SQLCODE
              || '|'
              || SUBSTR (SQLERRM, 1, 80)
             );
         RAISE;
   END;                                       --*** END GET ASSIGNMENT ID***--

--************************************************************************************--
--*                               MAIN PROGRAM PROCEDURE                             *--
--************************************************************************************--
   PROCEDURE import_sup_change (
      errbuf                OUT      VARCHAR2,
      retcode               OUT      NUMBER,
      v_business_group_id   IN       NUMBER
   )
   IS
    --l_module_name                  cust.ttec_error_handling.module_name%TYPE			    -- Commented code by IXPRAVEEN-ARGANO,05-May-2023	
                                                          --:= 'Main Procedure';
	  l_module_name                  apps.ttec_error_handling.module_name%TYPE				--  code Added by IXPRAVEEN-ARGANO,05-May-2023
                                                          := 'Main Procedure';													  
      l_business_group_id            NUMBER                           := NULL;
      --*** API VARIABLE DECLARATION ***--
	  --START R12.2 Upgrade Remediation
      /*l_object_version_number        hr.per_all_assignments_f.object_version_number%TYPE;			-- Commented code by IXPRAVEEN-ARGANO,05-May-2023
      l_assignment_id                hr.per_all_assignments_f.assignment_id%TYPE;
      l_organization_id              hr.per_all_assignments_f.organization_id%TYPE;
      l_orgname                      hr.hr_all_organization_units.NAME%TYPE;
      l_employee_number              hr.per_all_people_f.employee_number%TYPE;
      l_proportion                   hr.pay_cost_allocations_f.proportion%TYPE;
      l_cost_allocation_id           hr.pay_cost_allocations_f.cost_allocation_id%TYPE;*/
	  l_object_version_number        apps.per_all_assignments_f.object_version_number%TYPE;				--  code Added by IXPRAVEEN-ARGANO,05-May-2023
      l_assignment_id                apps.per_all_assignments_f.assignment_id%TYPE;
      l_organization_id              apps.per_all_assignments_f.organization_id%TYPE;
      l_orgname                      apps.hr_all_organization_units.NAME%TYPE;
      l_employee_number              apps.per_all_people_f.employee_number%TYPE;
      l_proportion                   apps.pay_cost_allocations_f.proportion%TYPE;
      l_cost_allocation_id           apps.pay_cost_allocations_f.cost_allocation_id%TYPE;
	  --END R12.2.10 Upgrade remediation
      l_supervisor_id                NUMBER;
      l_person_id                    NUMBER;
      l_cost_allocation_keyflex_id   NUMBER;
      l_effective_date               DATE;
      l_per_eff_start_date           DATE;
      v_datetrack_mode               VARCHAR2 (30);
      l_pc_segment2                  VARCHAR2 (4);
      l_validate                     BOOLEAN;
      l_pc_segment1                  VARCHAR2 (5);
      l_pc_segment3                  VARCHAR2 (3);
      --*** API OUT PARAMETERS DELCARATIONS ***--
      l_pc_combination_name          VARCHAR2 (80);
      l_pc_effective_start_date      DATE;
      l_pc_effective_end_date        DATE;
      l_asg_eff_strt_dt              DATE;
      l_pc_cost_alloc_keyflex_id     NUMBER;
      l_pc_object_version_number     NUMBER;
      l_pc_cost_allocation_id        NUMBER;
      l_concatenated_segments        VARCHAR2 (240);
      l_no_managers_warning          BOOLEAN;
      l_other_manager_warning        BOOLEAN;
      l_soft_coding_keyflex_id       NUMBER;
      l_comment_id                   NUMBER;
      l_effective_start_date         DATE;
      l_effective_end_date           DATE;
   BEGIN
  --  get_business_group_id (l_business_group_id, p_org_name);

  	l_business_group_id := v_business_group_id;

-- dbms_output.put_line('1');
      IF csr_cuhas%ISOPEN
      THEN
         CLOSE csr_cuhas;
      END IF;

      print_line ('Program to upload Supervisor assignments ');
      print_line ('Start time:' || SYSDATE);

      --*** OPEN AND FETCH EACH TEMPORARY ASSIGNMENT ***--
      FOR sel IN csr_cuhas
      LOOP
-- dbms_output.put_line('1');
         g_primary_column := sel.employee_number;
         print_line (   'Start processing Employee:'
                     || '|'
                     || sel.employee_number
                     || '|'
                     || sel.sup_number
                     || '|'
                     || sel.effective_date
                    );
         --*** INITIALIZE VALUES  ***--
         l_supervisor_id := NULL;
         l_object_version_number := NULL;
         l_assignment_id := NULL;
         l_employee_number := NULL;
         l_proportion := NULL;
         l_cost_allocation_id := NULL;
         l_person_id := NULL;
         l_cost_allocation_keyflex_id := NULL;
         l_effective_date := NULL;
         v_datetrack_mode := NULL;
         l_pc_segment1 := NULL;
         l_pc_segment2 := NULL;
         l_pc_segment3 := NULL;
         l_per_eff_start_date := NULL;
         l_validate := NULL;
         --*** INITIALIZE OUT PARAMETERS  ***--
         l_pc_combination_name := NULL;
         l_pc_effective_start_date := NULL;
         l_pc_effective_end_date := NULL;
         l_concatenated_segments := NULL;
         l_soft_coding_keyflex_id := NULL;
         l_comment_id := NULL;
         l_pc_effective_start_date := NULL;
         l_pc_effective_end_date := NULL;
         l_no_managers_warning := NULL;
         l_other_manager_warning := NULL;
         --*** INCREMENT TOTAL ASSIGNMENTS READ BY 1 ***--
         g_total_employees_read := g_total_employees_read + 1;

         BEGIN
            l_validate := FALSE;
            l_effective_date := sel.effective_date;
            l_supervisor_id := sel.supervisor_id;
--dbms_output.put_line(sel.employee_number);
            get_person_id (l_person_id,
                           l_per_eff_start_date,
                           sel.employee_number,
                           l_business_group_id
                          );
--dbms_output.put_line('get_person_id ->'||l_person_id||' '|| l_per_eff_start_date||' '|| sel.employee_number||' '|| l_business_group_id);
            get_assignment_id (sel.employee_number,
                               l_person_id,
                               l_business_group_id,
                               l_assignment_id,
                               l_asg_eff_strt_dt,
                               l_object_version_number,
                                 -- Add parameter (MLagostena)
                               l_soft_coding_keyflex_id
                                 -- End modification (MLagostena)
                              );
--dbms_output.put_line('get_organization_id ->'||sel.orgname||' '|| l_person_id||' '|| l_organization_id);

            --dbms_output.put_line('===============================================');

            v_datetrack_mode := 'UPDATE';

            -- Start Modification (MLagostena)

            IF v_business_group_id = 1517 THEN

            apps.hr_assignment_api.update_emp_asg
                        (p_validate                    => l_validate,
                         p_effective_date              => l_effective_date,
                         p_datetrack_update_mode       => v_datetrack_mode,
                         p_assignment_id               => l_assignment_id,
                         p_object_version_number       => l_object_version_number,
                         p_supervisor_id               => l_supervisor_id,
                         -- ,p_tax_unit                     =>  l_tax_unit_id
                         p_ass_attribute_category      => v_business_group_id,

            --*** API OUT PARAMETERS ***--

                         p_concatenated_segments       => l_concatenated_segments,
                         p_soft_coding_keyflex_id      => l_soft_coding_keyflex_id,
                         p_comment_id                  => l_comment_id,
                         p_effective_start_date        => l_pc_effective_start_date,
                         p_effective_end_date          => l_pc_effective_end_date,
                         p_no_managers_warning         => l_no_managers_warning,
                         p_other_manager_warning       => l_other_manager_warning
                        );

            ELSE


            apps.hr_assignment_api.update_us_emp_asg
                        (p_validate                    => l_validate,
                         p_effective_date              => l_effective_date,
                         p_datetrack_update_mode       => v_datetrack_mode,
                         p_assignment_id               => l_assignment_id,
                         p_object_version_number       => l_object_version_number,
                         p_supervisor_id               => l_supervisor_id
                                                                         -- ,p_tax_unit                     =>  l_tax_unit_id

            --*** API OUT PARAMETERS ***--
            ,
                         p_concatenated_segments       => l_concatenated_segments,
                         p_soft_coding_keyflex_id      => l_soft_coding_keyflex_id,
                         p_comment_id                  => l_comment_id,
                         p_effective_start_date        => l_pc_effective_start_date,
                         p_effective_end_date          => l_pc_effective_end_date,
                         p_no_managers_warning         => l_no_managers_warning,
                         p_other_manager_warning       => l_other_manager_warning
                        );

            END IF;

            -- End Modification (MLagostena)

           -- UPDATE hr.per_all_assignments_f				-- Commented code by IXPRAVEEN-ARGANO,05-May-2023
			UPDATE apps.per_all_assignments_f					--  code Added by IXPRAVEEN-ARGANO,05-May-2023
               SET supervisor_id = sel.supervisor_id
             WHERE person_id = l_person_id
               AND effective_start_date = l_pc_effective_start_date;

            --and effective_end_date = l_pc_effective_end_date;
            COMMIT;
            --*** INCREMENT THE NUMBER OF ROWS PROCESSED BY THE API ***--
            l_rows_processed := l_rows_processed + 1;
            print_line (   'Successful processing of Employee:'
                        || '|'
                        || sel.employee_number
                        || '|'
                        || sel.sup_number
                        || '|'
                        || sel.effective_date
                       );
         EXCEPTION
            WHEN OTHERS
            THEN
               print_line
                  (   'Error Reading and Updating record for employee number '
                   || sel.employee_number
                   || ' '
                   || SQLCODE
                   || ' '
                   || SUBSTR (SQLERRM, 1, 80)
                  );
         END;
      END LOOP;

      --***COMMIT ANY FINAL ROWS ***--
      COMMIT;
      --*** DISPLAY CONTROL TOTALS ***--
      print_line (   ' CONVERSION TIMESTAMP END = '
                  || TO_CHAR (SYSDATE, 'dd-mon-yy hh:mm:ss')
                 );
      print_line ('-------------------------------------------');
      --    dbms_output.put_line (' TOTAL ASSIGNMENT RECORDS COUNT         = '  || g_total_record_count);
      print_line (   ' TOTAL ASSIGNMENT RECORDS READ          = '
                  || TO_CHAR (g_total_employees_read)
                 );
      print_line (   ' TOTAL ASSIGNMENT RECORDS INSERTED      = '
                  || TO_CHAR (l_rows_processed)
                 );
      print_line (   ' TOTAL ASSIGNMENT RECORDS REJECTED      = '
                  || TO_CHAR (g_total_employees_read - l_rows_processed)
                 );
      --    dbms_output.put_line (' TOTAL ASSIGNMENT RECORDS NOT PROCESSED = '  || to_char(g_total_record_count - g_total_employees_read));
      print_line ('-------------------------------------------');

       EXCEPTION
     WHEN OTHERS THEN
      print_line ('Error in reading input file - Check format'
                     || '|' || SQLCODE
                     || '|'
                     || SUBSTR (SQLERRM, 1, 80)  );
      NULL;

   END import_sup_change;
END ttec_sup_load_pkg;
/
show errors;
/
