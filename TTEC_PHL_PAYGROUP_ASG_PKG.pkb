create or replace PACKAGE BODY TTEC_PHL_PAYGROUP_ASG_PKG AS
/* $Header: ttec_phl_paygroup_asg_pkg.pkb 1.0 2008/06/05 mdodge ship $ */

/*== START ================================================================================================*\
  Author:  Michelle Dodge
    Date:  June 04, 2008
    Desc:  This package is intended to be ran once for reassigning all Philippine employees, active during
           2008, from the old PHL Payrolls to the new PHL Payrolls.

  Modification History:

  Mod#  Date        Author      Description (Include Ticket#)
 -----  ----------  ----------  ----------------------------------------------
   001  06/05/2008  M Dodge     Initial Creation
   002  05/12/2023  RXNETHI-ARGANO R12.2 Upgrade Remediation
\*== END ==================================================================================================*/

  -- Testing Variables - NOT FOR PROD
  t_employee_number_low   NUMBER       := 2000000;
  t_employee_number_high  NUMBER       := 2100000;
  t_test_mode             BOOLEAN      := TRUE;

  -- Global Constants
  g_effective_date       DATE                                    := TO_DATE('01-JAN-2008');
  /*
  START R12.2 Upgrade Remediation
  code commented by RXNETHI-ARGANO,12/05/23
  g_bus_grp_name         hr.hr_all_organization_units.name%TYPE  := 'TeleTech Holdings - PHL';
  g_old_mgmt_payroll     hr.pay_all_payrolls_f.payroll_name%TYPE := 'PHL Management_OLD';
  g_old_non_mgmt_payroll hr.pay_all_payrolls_f.payroll_name%TYPE := 'PHL Non-Management_OLD';
  g_new_mgmt_payroll     hr.pay_all_payrolls_f.payroll_name%TYPE := 'PHL Management';
  g_new_non_mgmt_payroll hr.pay_all_payrolls_f.payroll_name%TYPE := 'PHL Non-Management';
  */
  --code added by RXNETHI-ARGANO,12/05/23
  g_bus_grp_name         apps.hr_all_organization_units.name%TYPE  := 'TeleTech Holdings - PHL';
  g_old_mgmt_payroll     apps.pay_all_payrolls_f.payroll_name%TYPE := 'PHL Management_OLD';
  g_old_non_mgmt_payroll apps.pay_all_payrolls_f.payroll_name%TYPE := 'PHL Non-Management_OLD';
  g_new_mgmt_payroll     apps.pay_all_payrolls_f.payroll_name%TYPE := 'PHL Management';
  g_new_non_mgmt_payroll apps.pay_all_payrolls_f.payroll_name%TYPE := 'PHL Non-Management';
  --END R12.2 Upgrade Remediation
  g_validate_delete_ees  BOOLEAN := FALSE;
  g_validate_update_asg  BOOLEAN := FALSE;
  g_batch_run_number     NUMBER  := 0;

  -- Global Count Variables for logging information
  g_total_emp_cnt        NUMBER  := 0;
  g_success_emp_cnt      NUMBER  := 0;
  g_fail_emp_cnt         NUMBER  := 0;
  g_total_asgn_cnt       NUMBER  := 0;
  g_success_asgn_cnt     NUMBER  := 0;
  g_fail_asgn_cnt        NUMBER  := 0;

  g_emp_asgn_fail_flag   BOOLEAN;

--
-- PROCEDURE log_message
--
-- Description: User the hr_batch_message_line_api to log a error / warning message
--   to the HR_API_BATCH_MESSAGE_LINES table.
--
PROCEDURE log_message ( p_batch_run_number        IN NUMBER
                      , p_api_name                IN VARCHAR2
                      , p_status                  IN VARCHAR2
                      , p_error_number            IN NUMBER
                      , p_error_message           IN VARCHAR2
                      , p_extended_error_message  IN VARCHAR2
                      , p_source_row_info         IN VARCHAR2 ) IS

  PRAGMA AUTONOMOUS_TRANSACTION;

  l_validate    BOOLEAN := FALSE;
  l_line_id     NUMBER;

BEGIN

  INSERT INTO hr_api_batch_message_lines
  VALUES ( hr_api_batch_message_lines_s.nextval
         , p_api_name
         , p_batch_run_number
         , p_status
         , p_error_message
         , p_error_number
         , p_extended_error_message
         , p_source_row_info
         , NULL );
/*
  hr_batch_message_line_api.create_message_line
    ( p_validate                      => l_validate
    , p_batch_run_number              => p_batch_run_number
    , p_api_name                      => p_api_name
    , p_status                        => p_status
    , p_error_number                  => p_error_number
    , p_error_message                 => p_error_message
    , p_extended_error_message        => p_extended_error_message
    , p_source_row_information        => p_source_row_info
    , p_line_id                       => l_line_id );
*/
  COMMIT;

EXCEPTION
  WHEN OTHERS THEN
    NULL;
END log_message;

--
-- FUNCTION get_bus_grp_id
--
-- Description: Get the Busines Group ID for the Philippines
--
--FUNCTION get_bus_grp_id(p_bus_grp_name   IN hr.hr_all_organization_units.name%TYPE) --code commented by RXNETHI-ARGANO,12/05/23
FUNCTION get_bus_grp_id(p_bus_grp_name   IN apps.hr_all_organization_units.name%TYPE) --code added by RXNETHI-ARGANO,12/05/23
  RETURN NUMBER IS

  l_bus_grp_id  NUMBER;

BEGIN

  SELECT hou.business_group_id
    INTO l_bus_grp_id
    --FROM hr.hr_all_organization_units hou --code commented by RXNETHI-ARGANO,12/05/23
	FROM apps.hr_all_organization_units hou --code added by RXNETHI-ARGANO,12/05/23
   WHERE hou.name = p_bus_grp_name;

  RETURN l_bus_grp_id;

EXCEPTION
  WHEN OTHERS THEN
    RETURN '0';
END get_bus_grp_id;

--
-- FUNCTION get_payroll_id
--
-- Description: Get the Payroll ID for the input Payroll Name
--
FUNCTION get_payroll_id( p_bus_grp_id     IN NUMBER
                       --, p_payroll_name   IN hr.pay_all_payrolls_f.payroll_name%TYPE) --code commented by RXNETHI-ARGANO,12/05/23
					   , p_payroll_name   IN apps.pay_all_payrolls_f.payroll_name%TYPE) --code added by RXNETHI-ARGANO,12/05/23
  RETURN NUMBER IS

  l_payroll_id   NUMBER;

BEGIN

  SELECT pay.payroll_id
    INTO l_payroll_id
    --FROM hr.pay_all_payrolls_f pay --code commented by RXNETHI-ARGANO,12/05/23
    FROM apps.pay_all_payrolls_f pay --code added by RXNETHI-ARGANO,12/05/23
   WHERE pay.business_group_id = p_bus_grp_id
     AND pay.payroll_name = p_payroll_name
     AND SYSDATE BETWEEN pay.effective_start_date AND pay.effective_end_date;

  RETURN l_payroll_id;

EXCEPTION
  WHEN OTHERS THEN
    RETURN '0';
END get_payroll_id;

--
-- PROCEDURE zap_nonrecurring_ees
--
-- Description: Oracle prevents Updating the Payroll ID on an assignment if there are Unprocessed
--   Non-Recurring Element Entries for the effective dates of that assignment.  As all PHL
--   element entries in Oracle to date are unprocessed, these entries must be deleted.
--
PROCEDURE zap_nonrecurring_ees( p_person_id      IN  NUMBER
                              , p_start_date     IN  DATE
                              , p_ees_del        OUT NUMBER ) IS

  l_validate                      BOOLEAN       := g_validate_delete_ees;
  l_datetrack_delete_mode         VARCHAR2(25)  := 'ZAP';

  l_effective_start_date          DATE;
  l_effective_end_date            DATE;
  l_delete_warning                BOOLEAN;

  l_api_name                      VARCHAR2(50)    := 'pay_element_entry_api.delete_element_entry';

  CURSOR get_nonrecur_ees IS
    SELECT UNIQUE
           ee.element_entry_id
         , ee.object_version_number
         , ee.effective_start_date
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,12/05/23
	  FROM hr.pay_element_entries_f ee
         , hr.pay_element_types_f et
         , hr.per_all_assignments_f paa
		 */
		 --code added by RXNETHI-ARGANO,12/05/23
		 FROM apps.pay_element_entries_f ee
         , apps.pay_element_types_f et
         , apps.per_all_assignments_f paa
		 --END R12.2 Upgrade Remediation
     WHERE paa.person_id = p_person_id
       AND paa.effective_start_date >= p_start_date
       AND ee.assignment_id = paa.assignment_id
       AND ee.effective_end_date >= p_start_date
       AND et.element_type_id = ee.element_type_id
       AND et.processing_type != 'R'
    ORDER BY ee.effective_start_date DESC;

  nonrecur_ee_rec get_nonrecur_ees%ROWTYPE;

BEGIN

  OPEN get_nonrecur_ees;
  LOOP
    FETCH get_nonrecur_ees
     INTO nonrecur_ee_rec;
    EXIT WHEN get_nonrecur_ees%NOTFOUND;

    BEGIN
      pay_element_entry_api.delete_element_entry
        ( p_validate                      => l_validate
        , p_datetrack_delete_mode         => l_datetrack_delete_mode
        , p_effective_date                => nonrecur_ee_rec.effective_start_date
        , p_element_entry_id              => nonrecur_ee_rec.element_entry_id
        , p_object_version_number         => nonrecur_ee_rec.object_version_number
        , p_effective_start_date          => l_effective_start_date
        , p_effective_end_date            => l_effective_end_date
        , p_delete_warning                => l_delete_warning
        );

      IF l_delete_warning THEN
        -- Log Warning
        log_message ( g_batch_run_number
                    , l_api_name                  -- p_api_name
                    , 'W'                         -- p_status
                    , NULL                        -- p_error_number
                    , NULL                        -- p_error_message
                    , 'Deletion Warning'          -- p_extended_error_message
                    , 'EE ID: '||nonrecur_ee_rec.element_entry_id||
                      '; OVN: '||nonrecur_ee_rec.object_version_number );
      END IF;

    EXCEPTION
      WHEN OTHERS THEN
        -- Log SQLERRM Error
        log_message ( g_batch_run_number
                    , l_api_name                  -- p_api_name
                    , 'F'                         -- p_status
                    , SQLCODE                     -- p_error_number
                    , SQLERRM                     -- p_error_message
                    , fnd_message.get             -- p_extended_error_message
                    , 'EE ID: '||nonrecur_ee_rec.element_entry_id||
                      '; OVN: '||nonrecur_ee_rec.object_version_number );
    END;

  END LOOP;
  p_ees_del := get_nonrecur_ees%ROWCOUNT;
  CLOSE get_nonrecur_ees;

EXCEPTION
  WHEN OTHERS THEN
    log_message ( g_batch_run_number
                , l_api_name                  -- p_api_name
                , 'F'                         -- p_status
                , SQLCODE                     -- p_error_number
                , SQLERRM                     -- p_error_message
                , fnd_message.get             -- p_extended_error_message
                , 'EE ID: '||nonrecur_ee_rec.element_entry_id||
                  '; OVN: '||nonrecur_ee_rec.object_version_number );
    RAISE;

END zap_nonrecurring_ees;

--
-- PROCEDURE update_asg_payroll
--
-- Description: This procedure will use the hr_assignment_api to Update the Payroll on the
--   input assignment record with the specified OVN.  It will use the CORRECTION mode.
--
--
/*
START R12.2 Upgrade Remediation
code commented by RXNETHI-ARGANO,12/05/23
PROCEDURE update_asg_payroll( p_effective_date IN DATE
                            , p_assignment_id  IN hr.per_all_assignments_f.assignment_id%TYPE
                            , p_ovn            IN hr.per_all_assignments_f.object_version_number%TYPE
                            , p_payroll_id     IN hr.pay_all_payrolls_f.payroll_id%TYPE
                            , p_update_mode    IN VARCHAR2 ) IS
							*/
--code added by RXNETHI-ARGANO,12/05/23
PROCEDURE update_asg_payroll( p_effective_date IN DATE
                            , p_assignment_id  IN apps.per_all_assignments_f.assignment_id%TYPE
                            , p_ovn            IN apps.per_all_assignments_f.object_version_number%TYPE
                            , p_payroll_id     IN apps.pay_all_payrolls_f.payroll_id%TYPE
                            , p_update_mode    IN VARCHAR2 ) IS
--END R12.2 Upgrade Remediation

  l_validate                         BOOLEAN       := g_validate_update_asg;
  l_object_version_number            NUMBER        := p_ovn;
  l_called_from_mass_update          BOOLEAN       := FALSE;

  l_special_ceiling_step_id          NUMBER;
  l_people_group_id                  NUMBER;
  l_soft_coding_keyflex_id           NUMBER;
  l_group_name                       pay_people_groups.group_name%TYPE;
  l_effective_start_date             DATE;
  l_effective_end_date               DATE;
  l_org_now_no_manager_warning       BOOLEAN;
  l_other_manager_warning            BOOLEAN;
  l_spp_delete_warning               BOOLEAN;
  l_entries_changed_warning          VARCHAR2(1);
  l_tax_district_changed_warning     BOOLEAN;
  l_concatenated_segments            hr_soft_coding_keyflex.concatenated_segments%TYPE;
  l_gsp_post_process_warning         VARCHAR2(2000);

  l_api_name                         VARCHAR2(50) := 'hr_assignment_api.update_emp_asg_criteria';

BEGIN

  g_total_asgn_cnt := g_total_asgn_cnt + 1;

  hr_assignment_api.update_emp_asg_criteria
    ( p_effective_date               => p_effective_date
     ,p_datetrack_update_mode        => p_update_mode
     ,p_assignment_id                => p_assignment_id
     ,p_validate                     => l_validate
     ,p_called_from_mass_update      => l_called_from_mass_update
     ,p_payroll_id                   => p_payroll_id
     ,p_object_version_number        => l_object_version_number
     ,p_special_ceiling_step_id      => l_special_ceiling_step_id
     ,p_people_group_id              => l_people_group_id            -- Needed ?
     ,p_soft_coding_keyflex_id       => l_soft_coding_keyflex_id
     ,p_group_name                   => l_group_name
     ,p_effective_start_date         => l_effective_start_date
     ,p_effective_end_date           => l_effective_end_date
     ,p_org_now_no_manager_warning   => l_org_now_no_manager_warning
     ,p_other_manager_warning        => l_other_manager_warning
     ,p_spp_delete_warning           => l_spp_delete_warning
     ,p_entries_changed_warning      => l_entries_changed_warning
     ,p_tax_district_changed_warning => l_tax_district_changed_warning
     ,p_concatenated_segments        => l_concatenated_segments
     ,p_gsp_post_process_warning     => l_gsp_post_process_warning
    );

  -- Check for Warnings Returned and Log for review
  IF l_org_now_no_manager_warning THEN
    log_message ( g_batch_run_number
                , l_api_name                  -- p_api_name
                , 'S'                         -- p_status
                , NULL                        -- p_error_number
                , NULL                        -- p_error_message
                , 'No Manager - Old Organization'  -- p_extended_error_message
                , 'Asg ID: '||p_assignment_id||
                  '; OVN: '||l_object_version_number||
                  '; Eff Date: '||p_effective_date ||
                  '; Mode: '||p_update_mode||
                  '; Payroll ID: '||p_payroll_id );
  END IF;
  IF l_other_manager_warning THEN
    -- Log Warning
    log_message ( g_batch_run_number
                , l_api_name                  -- p_api_name
                , 'W'                         -- p_status
                , NULL                        -- p_error_number
                , NULL                        -- p_error_message
                , 'Manager already exists in Organization'  -- p_extended_error_message
                , 'Asg ID: '||p_assignment_id||
                  '; OVN: '||l_object_version_number||
                  '; Eff Date: '||p_effective_date ||
                  '; Mode: '||p_update_mode||
                  '; Payroll ID: '||p_payroll_id );
  END IF;
  IF l_spp_delete_warning THEN
    -- Log Warning
    log_message ( g_batch_run_number
                , l_api_name                  -- p_api_name
                , 'W'                         -- p_status
                , NULL                        -- p_error_number
                , NULL                        -- p_error_message
                , 'SPP Deletion Warning'  -- p_extended_error_message
                , 'Asg ID: '||p_assignment_id||
                  '; OVN: '||l_object_version_number||
                  '; Eff Date: '||p_effective_date ||
                  '; Mode: '||p_update_mode||
                  '; Payroll ID: '||p_payroll_id );
  END IF;
  IF l_tax_district_changed_warning THEN
    -- Log Warning
    log_message ( g_batch_run_number
                , l_api_name                  -- p_api_name
                , 'W'                         -- p_status
                , NULL                        -- p_error_number
                , NULL                        -- p_error_message
                , 'GP Tax District Changed'  -- p_extended_error_message
                , 'Asg ID: '||p_assignment_id||
                  '; OVN: '||l_object_version_number||
                  '; Eff Date: '||p_effective_date ||
                  '; Mode: '||p_update_mode||
                  '; Payroll ID: '||p_payroll_id );
  END IF;

  IF l_entries_changed_warning = 'Y' THEN
    -- Log Warning
    log_message ( g_batch_run_number
                , l_api_name                  -- p_api_name
                , 'W'                         -- p_status
                , NULL                        -- p_error_number
                , NULL                        -- p_error_message
                , 'Element Entries Changed'  -- p_extended_error_message
                , 'Asg ID: '||p_assignment_id||
                  '; OVN: '||l_object_version_number ||
                  '; Eff Date: '||p_effective_date ||
                  '; Mode: '||p_update_mode||
                  '; Payroll ID: '||p_payroll_id );
  ELSIF l_entries_changed_warning = 'S' THEN
    -- Log Warning
    log_message ( g_batch_run_number
                , l_api_name                  -- p_api_name
                , 'W'                         -- p_status
                , NULL                        -- p_error_number
                , NULL                        -- p_error_message
                , 'Salary Element Entries Changed'  -- p_extended_error_message
                , 'Asg ID: '||p_assignment_id||
                  '; OVN: '||l_object_version_number||
                  '; Eff Date: '||p_effective_date ||
                  '; Mode: '||p_update_mode||
                  '; Payroll ID: '||p_payroll_id );
  END IF;

  IF l_gsp_post_process_warning IS NOT NULL THEN
    -- Log Warning
    log_message ( g_batch_run_number
                , l_api_name                  -- p_api_name
                , 'W'                         -- p_status
                , NULL                        -- p_error_number
                , NULL                        -- p_error_message
                , 'GSP Post Process Warning'  -- p_extended_error_message
                , 'Asg ID: '||p_assignment_id||
                  '; OVN: '||l_object_version_number ||
                  '; Eff Date: '||p_effective_date ||
                  '; Mode: '||p_update_mode||
                  '; Payroll ID: '||p_payroll_id );
  END IF;

  g_success_asgn_cnt := g_success_asgn_cnt + 1;

EXCEPTION
  WHEN OTHERS THEN
    log_message ( g_batch_run_number
                , l_api_name                  -- p_api_name
                , 'F'                         -- p_status
                , SQLCODE                     -- p_error_number
                , SQLERRM                     -- p_error_message
                , fnd_message.get             -- p_extended_error_message
                , 'Asg ID: '||p_assignment_id||
                  '; OVN: '||l_object_version_number ||
                  '; Eff Date: '||p_effective_date ||
                  '; Mode: '||p_update_mode||
                  '; Payroll ID: '||p_payroll_id );

  g_fail_asgn_cnt := g_fail_asgn_cnt + 1;
  g_emp_asgn_fail_flag := TRUE;

--    RAISE;
END update_asg_payroll;

--
-- PROCEDURE Main
--
-- Description: This is the front end procedure that will be called to reassign all active Philippine
--   employees, as of the run date, from the old PHL Payrolls to the new PHL Payrolls.
--
--
PROCEDURE main IS

  l_cnt                       NUMBER;

  l_bus_grp_id                NUMBER;
  l_new_mgmt_payroll_id       NUMBER;
  l_new_non_mgmt_payroll_id   NUMBER;

  l_new_payroll_id            NUMBER;

  l_api_name                  VARCHAR2(50) := 'ttec_phl_paygroup_asg_pkg.main';

  e_bus_grp_error             EXCEPTION;
  e_mgmt_payroll_error        EXCEPTION;
  e_non_mgmt_payroll_error    EXCEPTION;

  CURSOR get_phl_emps IS
    SELECT tab.person_id
         , tab.employee_number
         , tab.assignment_id
         , ( SELECT COUNT(*)
               --FROM hr.per_all_assignments_f paa2 --code commented by RXNETHI-ARGANO,12/05/23
			   FROM apps.per_all_assignments_f paa2 --code added by RXNETHI-ARGANO,12/05/23
              WHERE paa2.person_id = tab.person_id
                AND paa2.assignment_id = tab.assignment_id
                AND paa2.effective_end_date >= '01-JAN-2008' ) asg_cnt
      FROM
       ( SELECT UNIQUE
                pap.person_id
              , pap.employee_number
              , paa.assignment_id
          /*
		  START R12.2 Upgrade Remediation
		  code commented by RXNETHI-ARGANO,12/05/23
		  FROM hr.pay_all_payrolls_f pay
             , hr.per_all_people_f pap
             , hr.per_all_assignments_f paa
			 */
			 --code added by RXNETHI-ARGANO,12/05/23
		  FROM apps.pay_all_payrolls_f pay
             , apps.per_all_people_f pap
             , apps.per_all_assignments_f paa
			 --END R12.2 Upgrade Remediation
         WHERE pap.business_group_id = 1517
           AND pap.effective_end_date >= '01-JAN-2008'
           AND paa.person_id = pap.person_id
           AND paa.effective_end_date >= '01-JAN-2008'
           AND pay.payroll_id = paa.payroll_id
           AND pay.payroll_name IN (g_old_mgmt_payroll, g_old_non_mgmt_payroll) ) tab
     WHERE tab.employee_number BETWEEN NVL(t_employee_number_low, tab.employee_number )
                                   AND NVL(t_employee_number_high, tab.employee_number )  -- Testing ONLY
    ORDER BY tab.employee_number;

  phl_emp_rec get_phl_emps%ROWTYPE;

  CURSOR get_emp_asgs ( p_person_id NUMBER
                      , p_assignment_id NUMBER ) IS
    SELECT paa.assignment_id
         , paa.object_version_number ovn
         , paa.effective_start_date
         , pay.payroll_name
      --FROM hr.pay_all_payrolls_f pay    --code commented by RXNETHI-ARGANO,12/05/23
      --   , hr.per_all_assignments_f paa --code commented by RXNETHI-ARGANO,12/05/23
	  FROM apps.pay_all_payrolls_f pay    --code added by RXNETHI-ARGANO,12/05/23
         , apps.per_all_assignments_f paa --code added by RXNETHI-ARGANO,12/05/23
     WHERE paa.person_id = p_person_id
       AND paa.assignment_id = p_assignment_id
       AND paa.effective_end_date >= g_effective_date
       AND pay.payroll_id = paa.payroll_id
       AND pay.payroll_name IN (g_old_mgmt_payroll, g_old_non_mgmt_payroll)
    ORDER BY paa.effective_start_date;

  emp_asg_rec get_emp_asgs%ROWTYPE;

BEGIN

  -- Set the batch run number if not already set.
  IF g_batch_run_number = 0 THEN
    SELECT NVL(MAX(batch_run_number), 0) + 1
      INTO g_batch_run_number
      --FROM hr.hr_api_batch_message_lines;   --code commented by RXNETHI-ARGANO,12/05/23
      FROM apps.hr_api_batch_message_lines;   --code commented by RXNETHI-ARGANO,12/05/23
  END IF;

  -- Get the Business Group ID for the Philippines
  l_bus_grp_id := get_bus_grp_id(g_bus_grp_name);

  IF l_bus_grp_id = 0 THEN
    RAISE e_bus_grp_error;
  END IF;

  -- Get the Payroll IDs for the new Payrolls.
  l_new_mgmt_payroll_id     := get_payroll_id(l_bus_grp_id, g_new_mgmt_payroll);
  l_new_non_mgmt_payroll_id := get_payroll_id(l_bus_grp_id, g_new_non_mgmt_payroll);

  IF l_new_mgmt_payroll_id = 0 THEN
    RAISE e_mgmt_payroll_error;
  END IF;

  IF l_new_non_mgmt_payroll_id = 0 THEN
    RAISE e_non_mgmt_payroll_error;
  END IF;

  -- Get all PHL Employees who have been assigned to one of the 2 specified Payrolls
  -- during 2008.  Any PHL Employees assignments to other Payrolls during 2008 will
  -- need to be manually Updated via the forms.
  OPEN get_phl_emps;
  LOOP
    FETCH get_phl_emps
     INTO phl_emp_rec;
    EXIT WHEN get_phl_emps%NOTFOUND;

    g_emp_asgn_fail_flag := FALSE;

    BEGIN
      -- Get all of the assignments for this employee that cross or follow the
      -- effective_date of '01-JAN-2008'.
      OPEN get_emp_asgs( phl_emp_rec.person_id
                       , phl_emp_rec.assignment_id );
      LOOP
        FETCH get_emp_asgs
         INTO emp_asg_rec;
        EXIT WHEN get_emp_asgs%NOTFOUND;

        -- Determine the Employees New Payroll from their Old Payroll   -- MOVE
        IF emp_asg_rec.payroll_name = g_old_mgmt_payroll THEN
          l_new_payroll_id := l_new_mgmt_payroll_id;
        ELSE l_new_payroll_id := l_new_non_mgmt_payroll_id;
        END IF;

        IF get_emp_asgs%ROWCOUNT = 1 AND
           g_effective_date > emp_asg_rec.effective_start_date THEN  -- Started prior to 2008

          -- Zap all non-recurring element entries for this person from the
          -- first affected assignment record forward.
--          zap_nonrecurring_ees( phl_emp_rec.person_id
--                              , g_effective_date
--                              , l_cnt );

          IF phl_emp_rec.asg_cnt = 1 THEN
            -- Update the only asgn record with mode = UPDATE
            update_asg_payroll( g_effective_date
                              , emp_asg_rec.assignment_id
                              , emp_asg_rec.ovn
                              , l_new_payroll_id
                              , 'UPDATE' );
          ELSE
            -- Update the first of many asg records with mode = UPDATE_CHANGE_INSERT
            update_asg_payroll( g_effective_date
                              , emp_asg_rec.assignment_id
                              , emp_asg_rec.ovn
                              , l_new_payroll_id
                              , 'UPDATE_CHANGE_INSERT' );
          END IF;

        ELSE

          -- Update ALL remaining employee assignments using mode = CORRECTION
          update_asg_payroll( emp_asg_rec.effective_start_date
                            , emp_asg_rec.assignment_id
                            , emp_asg_rec.ovn
                            , l_new_payroll_id
                            , 'CORRECTION' );

        END IF;

      END LOOP;
      CLOSE get_emp_asgs;

      -- COMMIT all updates for the Employee at one time.
      IF NOT t_test_mode THEN
        COMMIT;                 -- No Auto Commit in Test Mode
      ELSE
        ROLLBACK;
      END IF;

    EXCEPTION
      WHEN OTHERS THEN
        IF get_emp_asgs%ISOPEN
        THEN CLOSE get_emp_asgs;
        END IF;

        -- Unknown Failure.  Rollback ALL Employee updates.
--        ROLLBACK;
    END;

    IF g_emp_asgn_fail_flag THEN
      g_fail_emp_cnt := g_fail_emp_cnt + 1;
    ELSE
      g_success_emp_cnt := g_success_emp_cnt + 1;
    END IF;

  END LOOP;

  g_total_emp_cnt := get_phl_emps%ROWCOUNT;

  CLOSE get_phl_emps;

EXCEPTION
  WHEN e_bus_grp_error THEN
    -- Log error
    log_message ( g_batch_run_number
                , l_api_name                  -- p_api_name
                , 'F'                         -- p_status
                , SQLCODE                     -- p_error_number
                , SQLERRM                     -- p_error_message
                , fnd_message.get             -- p_extended_error_message
                , g_bus_grp_name );
  WHEN e_mgmt_payroll_error THEN
    -- Log error
    log_message ( g_batch_run_number
                , l_api_name                  -- p_api_name
                , 'F'                         -- p_status
                , SQLCODE                     -- p_error_number
                , SQLERRM                     -- p_error_message
                , fnd_message.get             -- p_extended_error_message
                , g_new_mgmt_payroll );
  WHEN e_non_mgmt_payroll_error THEN
    -- Log error
    log_message ( g_batch_run_number
                , l_api_name                  -- p_api_name
                , 'F'                         -- p_status
                , SQLCODE                     -- p_error_number
                , SQLERRM                     -- p_error_message
                , fnd_message.get             -- p_extended_error_message
                , g_new_non_mgmt_payroll );
  WHEN OTHERS THEN
    -- Log SQLERRM error
    log_message ( g_batch_run_number
                , l_api_name                  -- p_api_name
                , 'F'                         -- p_status
                , SQLCODE                     -- p_error_number
                , SQLERRM                     -- p_error_message
                , fnd_message.get             -- p_extended_error_message
                , NULL );
    -- Unknown Error Point and State.  Rollback and Review.
--    ROLLBACK;

END main;

--
-- PROCEDURE conc_mgr_wrapper
--
-- Description: This is a wrapper procedure to be called directly from the Concurrent
--   Mgr.  It will set Test Globals from input parameters and will output the final log.
--   This approach will allow the Main process to be ran/tested from a SQL prompt and
--   the Cong Mgr.
--
PROCEDURE conc_mgr_wrapper( p_error_msg      OUT VARCHAR2
                          , p_error_code     OUT VARCHAR2
                          , p_emp_no_low     IN  NUMBER
                          , p_emp_no_high    IN  NUMBER
                          , p_test_mode      IN  VARCHAR2 ) IS

  l_ee_warning_cnt    NUMBER := 0;
  l_term_assign_cnt   NUMBER := 0;

  CURSOR get_error_message IS
    SELECT UNIQUE error_message
      FROM hr_api_batch_message_lines
     WHERE batch_run_number = g_batch_run_number
       AND status = 'F'
       AND NVL(extended_error_message,' ') != 'An assignment with status TERM_ASSIGN cannot have any other attributes updated.'
    ORDER BY error_message;

  error_message_rec get_error_message%ROWTYPE;

  CURSOR get_errors(p_err_mess VARCHAR2) IS
    SELECT source_row_information
      FROM hr_api_batch_message_lines
     WHERE batch_run_number = g_batch_run_number
       AND status = 'F'
       AND error_message = p_err_mess;

  error_rec get_errors%ROWTYPE;

  CURSOR get_warn_message IS
    SELECT UNIQUE extended_error_message
      FROM hr_api_batch_message_lines
     WHERE batch_run_number = g_batch_run_number
       AND status = 'W'
       AND NVL(extended_error_message,' ') != 'Element Entries Changed'
    ORDER BY extended_error_message;

  warn_message_rec get_warn_message%ROWTYPE;

  CURSOR get_warns(p_warn_mess VARCHAR2) IS
    SELECT source_row_information
      FROM hr_api_batch_message_lines
     WHERE batch_run_number = g_batch_run_number
       AND status = 'W'
       AND extended_error_message = p_warn_mess
    ORDER BY extended_error_message;

  warn_rec get_warns%ROWTYPE;

BEGIN

  -- Set Global Test Variables
  IF p_test_mode = 'N'
    THEN t_test_mode := FALSE;
  ELSE t_test_mode := TRUE;
  END IF;

  t_employee_number_low  := p_emp_no_low;
  t_employee_number_high := p_emp_no_high;

  fnd_file.new_line(fnd_file.log, 1);
  fnd_file.put_line(fnd_file.log, 'Emp # Low : '||t_employee_number_low);
  fnd_file.put_line(fnd_file.log, 'Emp # High: '||t_employee_number_high);
  fnd_file.put_line(fnd_file.log, 'Test Mode?: '||p_test_mode);

  -- Submit the Main Process
  main;

  -- Log Counts
  BEGIN
    IF g_batch_run_number = 0 THEN
      fnd_file.put_line(fnd_file.log, 'Message Batch #: No Messages Generated');
    ELSE
      fnd_file.put_line(fnd_file.log, 'Message Batch #: '||g_batch_run_number);
    END IF;

    fnd_file.new_line(fnd_file.log,1);
    fnd_file.put_line(fnd_file.log,'COUNTS');
    fnd_file.put_line(fnd_file.log,'---------------------------------------------------------');
    fnd_file.put_line(fnd_file.log,'# Employees Processed       : '||g_total_emp_cnt);
    fnd_file.put_line(fnd_file.log,'   # Successful             : '||g_success_emp_cnt);
    fnd_file.put_line(fnd_file.log,'   # Failed                 : '||g_fail_emp_cnt);
    fnd_file.new_line(fnd_file.log,1);
    fnd_file.put_line(fnd_file.log,'# Emp Assignments Processed : '||g_total_asgn_cnt);
    fnd_file.put_line(fnd_file.log,'   # Successful             : '||g_success_asgn_cnt);
    fnd_file.put_line(fnd_file.log,'   # Failed                 : '||g_fail_asgn_cnt);
    fnd_file.put_line(fnd_file.log,'---------------------------------------------------------');
    fnd_file.new_line(fnd_file.log,2);
    fnd_file.put_line(fnd_file.log, 'Expected Warning and Error Counts');

    fnd_file.put_line(fnd_file.output,'COUNTS');
    fnd_file.put_line(fnd_file.output,'---------------------------------------------------------');
    fnd_file.put_line(fnd_file.output,'# Employees Processed: '||g_total_emp_cnt);
    fnd_file.put_line(fnd_file.output,'   # Successful      : '||g_success_emp_cnt);
    fnd_file.put_line(fnd_file.output,'   # Failed          : '||g_fail_emp_cnt);
    fnd_file.new_line(fnd_file.output,1);
    fnd_file.put_line(fnd_file.output,'# Emp Assignments Processed : '||g_total_asgn_cnt);
    fnd_file.put_line(fnd_file.output,'   # Successful             : '||g_success_asgn_cnt);
    fnd_file.put_line(fnd_file.output,'   # Failed                 : '||g_fail_asgn_cnt);
    fnd_file.put_line(fnd_file.output,'---------------------------------------------------------');
    fnd_file.new_line(fnd_file.output,2);

    SELECT COUNT(*)
      INTO l_ee_warning_cnt
      FROM hr_api_batch_message_lines
     WHERE batch_run_number = g_batch_run_number
       AND status = 'W'
       AND NVL(extended_error_message,' ') = 'Element Entries Changed';

    fnd_file.put_line(fnd_file.log, '   Element Entries Changed warning count: '||l_ee_warning_cnt);

    SELECT COUNT(*)
      INTO l_term_assign_cnt
      FROM hr_api_batch_message_lines
     WHERE batch_run_number = g_batch_run_number
       AND status = 'F'
       AND NVL(extended_error_message,' ') = 'An assignment with status TERM_ASSIGN cannot have any other attributes updated.';

    fnd_file.put_line(fnd_file.log, '   Number of Employee Asgs in TERM_ASSIGN status: '||l_term_assign_cnt);
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, '   Error reporting expected Warnings and Errors');
  END;

  -- Log Errors
  BEGIN
    fnd_file.new_line(fnd_file.log,1);
    fnd_file.put_line(fnd_file.log,'Refer to Output for Detailed Errors and Warnings');
    fnd_file.new_line(fnd_file.log, 1);

    fnd_file.put_line(fnd_file.output,'ERRORS');
    fnd_file.put_line(fnd_file.output,'--------------------');

    OPEN get_error_message;
    LOOP
      FETCH get_error_message
       INTO error_message_rec;
      EXIT WHEN get_error_message%NOTFOUND;

      fnd_file.put_line(fnd_file.output,error_message_rec.error_message);

      FOR error_rec IN get_errors(error_message_rec.error_message) LOOP
        fnd_file.put_line(fnd_file.output,'      '||error_rec.source_row_information);
      END LOOP;

    END LOOP;

    IF get_error_message%ROWCOUNT = 0 THEN
      fnd_file.put_line(fnd_file.output,'No Errors to Report');
    END IF;

    CLOSE get_error_message;
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, '   Error Reporting Detailed Errors');
  END;

  BEGIN
    fnd_file.new_line(fnd_file.output,1);
    fnd_file.put_line(fnd_file.output,'WARNINGS');
    fnd_file.put_line(fnd_file.output,'--------------------');

    OPEN get_warn_message;
    LOOP
      FETCH get_warn_message
       INTO warn_message_rec;
      EXIT WHEN get_warn_message%NOTFOUND;

      fnd_file.put_line(fnd_file.output,warn_message_rec.extended_error_message);

      FOR warn_rec IN get_warns(warn_message_rec.extended_error_message) LOOP
        fnd_file.put_line(fnd_file.output,'      '||warn_rec.source_row_information);
      END LOOP;

    END LOOP;

    IF get_warn_message%ROWCOUNT = 0 THEN
      fnd_file.put_line(fnd_file.output,'No Warnings to Report');
    END IF;

    CLOSE get_warn_message;
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, '   Error Reporting Detailed Warnings');
  END;

EXCEPTION
  WHEN OTHERS THEN
    fnd_file.put_line(fnd_file.log, SQLCODE||': '||SQLERRM);
END conc_mgr_wrapper;

END TTEC_PHL_PAYGROUP_ASG_PKG;
/
show errors;
/