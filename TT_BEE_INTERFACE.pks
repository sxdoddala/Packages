create or replace package TT_BEE_INTERFACE AUTHID CURRENT_USER is

  /************************************************************************************/
  /*                                                                                  */
  /*     Program Name: TT_BEE_INTERFACE.pck                                           */
  /*                                                                                  */
  /*     Description:  This part of the BEE Interface performs preliminary validation */
  /*	 			   on the batch data in the staging	table, retrieves the 		  */
  /*				   appropriate Oracle data, loads the BEE tables, and finally	  */
  /*				   produces a report on the totals per element type per region.	  */
  /*                                                                                  */
  /*     Input/Output Parameters:                                                     */
  /*                                                                                  */
  /*     Tables Accessed:  hr.hr_all_organization_units								  */
  /*	 				   apps.fnd_common_lookups									  */
  /*					   hr.pay_element_types_f									  */
  /*					   hr.per_all_assignments_f									  */
  /*					   hr.pay_batch_headers										  */
  /*                                                                                  */
  /*     Tables Modified:  hr.pay_batch_headers										  */
  /*	 				   hr.pay_batch_lines										  */
  /*                                                                                  */
  /*     Procedures Called: cust.ttec_error_handling								  */
  /*                                                                                  */
  /*     Created by:        Chan Kang                                                 */
  /*                        PricewaterhouseCoopers LLP                                */
  /*     Date:              September 26,2002                                         */
  /*                                                                                  */
  /*     Modification Log:                                                            */
  /*     Developer              Date      Description                                 */
  /*     --------------------   --------  --------------------------------            */
  /*     C.Kang                 12/03/02  Modified program to handle terminated emps  */
  /*                                      and corrected the get_assignment_info proc  */
  /*                                      to refine search for modified person info.  */
  /*                                                                                  */
  /*    D.Thakker				12/20/02  Changed c_action_if_exists_deflt to INSERT  */
  /*    IKONAK                  01/07/03  Modified program to accept business group   */
  /*                                       parameter and to update Row who columns.   */
  /*    IKONAK                  02/24/03  Added remaining Employee statuses           */
  /*    AHERNANDEZ				12/14/06  Modified Program to pass VALUE15 from		  */
  /*									  staging table to DATE_EARNED in  			  */
  /*									  PAY_BATCH_LINES. 
  /*    RXNETHI-ARGANO          29-JUN-23 R12.2 Upgrade Remediation                   */
  /************************************************************************************/

  -- declare error handling variables
  /*
  START R12.2 Upgrade Remediation
  code commented by RXNETHI-ARGANO,29/06/23
  c_application_code     CONSTANT cust.ttec_error_handling.application_code%TYPE  := 'HR';
  c_interface            CONSTANT cust.ttec_error_handling.interface%TYPE := 'BEE-INT';
  c_program_name         CONSTANT cust.ttec_error_handling.program_name%TYPE  := 'tt_bee_interface';
  c_initial_status       CONSTANT cust.ttec_error_handling.status%TYPE  := 'INITIAL';
  c_warning_status       CONSTANT cust.ttec_error_handling.status%TYPE  := 'WARNING';
  c_failure_status       CONSTANT cust.ttec_error_handling.status%TYPE  := 'FAILURE';
  c_processed_stage_flag CONSTANT cust.tt_bee_interface_stage.record_processed%TYPE := 'P';
  c_processed_trsfr_flag CONSTANT cust.tt_bee_interface_stage.record_processed%TYPE := 'Y';
  c_unprocessed_flag     CONSTANT cust.tt_bee_interface_stage.record_processed%TYPE := 'N';
  */
  --code added by RXNETHI-ARGANO,29/06/23
  c_application_code     CONSTANT apps.ttec_error_handling.application_code%TYPE  := 'HR';
  c_interface            CONSTANT apps.ttec_error_handling.interface%TYPE := 'BEE-INT';
  c_program_name         CONSTANT apps.ttec_error_handling.program_name%TYPE  := 'tt_bee_interface';
  c_initial_status       CONSTANT apps.ttec_error_handling.status%TYPE  := 'INITIAL';
  c_warning_status       CONSTANT apps.ttec_error_handling.status%TYPE  := 'WARNING';
  c_failure_status       CONSTANT apps.ttec_error_handling.status%TYPE  := 'FAILURE';
  c_processed_stage_flag CONSTANT apps.tt_bee_interface_stage.record_processed%TYPE := 'P';
  c_processed_trsfr_flag CONSTANT apps.tt_bee_interface_stage.record_processed%TYPE := 'Y';
  c_unprocessed_flag     CONSTANT apps.tt_bee_interface_stage.record_processed%TYPE := 'N';
  --END R12.2 Upgrade Remediation
  c_batch_source         CONSTANT VARCHAR2(30) := 'BEE Interface';
  c_batch_reference      CONSTANT VARCHAR2(20) := to_char(trunc(sysdate));

  -- declare global variables
  --g_module_name					 cust.ttec_error_handling.module_name%TYPE := NULL;  --code commented by RXNETHI-ARGANO,29/06/23
  g_module_name					 apps.ttec_error_handling.module_name%TYPE := NULL;      --code added by RXNETHI-ARGANO,29/06/23
  --g_error_message     			 cust.ttec_error_handling.error_message%TYPE := NULL;  --code commented by RXNETHI-ARGANO,29/06/23
  g_error_message     			 apps.ttec_error_handling.error_message%TYPE := NULL;      --code added by RXNETHI-ARGANO,29/06/23
  g_operating_unit               NUMBER := NULL;
  g_login_id                     VARCHAR2(2) := '-1';
  g_oracle_start_date            CONSTANT DATE := to_date('01-JAN-1950');
  g_oracle_end_date              CONSTANT DATE := to_date('31-DEC-4712');
  g_business_group_type_code     CONSTANT VARCHAR2(2) := 'BG';
  g_ttec_org_name				 CONSTANT VARCHAR2(50) := 'TeleTech Holdings - US';
  g_batch_name           VARCHAR2(30) := NULL;
  /*
  START R12.2 Upgrade Remediation
  code commented by RXNETHI-ARGANO,29/06/23
  g_label1			cust.ttec_error_handling.label1%TYPE := 'Emp_Number';
  g_label2			cust.ttec_error_handling.label2%TYPE := NULL;
  g_primary_column      cust.ttec_error_handling.reference1%TYPE := NULL;
  g_secondary_column			cust.ttec_error_handling.reference2%TYPE := NULL;
  g_param_business_group_name   cust.tt_bee_interface_stage.business_group%TYPE;
  */
  --code added by RXNETHI-ARGANO,29/06/23
  g_label1			            apps.ttec_error_handling.label1%TYPE := 'Emp_Number';
  g_label2			            apps.ttec_error_handling.label2%TYPE := NULL;
  g_primary_column              apps.ttec_error_handling.reference1%TYPE := NULL;
  g_secondary_column			apps.ttec_error_handling.reference2%TYPE := NULL;
  g_param_business_group_name   apps.tt_bee_interface_stage.business_group%TYPE;
  --END R12.2 Upgrade Remediation

  -- lookup types and defaults
  c_batch_status_lt  CONSTANT apps.fnd_common_lookups.lookup_type%TYPE := 'BATCH_STATUS';
  c_batch_status_deflt  CONSTANT apps.fnd_common_lookups.meaning%TYPE := 'Unprocessed';
  c_action_if_exists_lt  CONSTANT apps.fnd_common_lookups.lookup_type%TYPE := 'ACTION_IF_EXISTS';
  c_action_if_exists_deflt  CONSTANT apps.fnd_common_lookups.meaning%TYPE := 'Insert';
  c_purge_after_transfer_lt  CONSTANT apps.fnd_common_lookups.lookup_type%TYPE := 'YES_NO';
  c_purge_after_transfer_deflt  CONSTANT apps.fnd_common_lookups.meaning%TYPE := 'No';
  c_rjt_future_chg_lt  CONSTANT apps.fnd_common_lookups.lookup_type%TYPE := 'YES_NO';
  c_rjt_future_chg_deflt  CONSTANT apps.fnd_common_lookups.meaning%TYPE := 'Yes';
  c_entry_type_lt  CONSTANT apps.fnd_common_lookups.lookup_type%TYPE := 'ENTRY_TYPE';
  c_entry_type_deflt  CONSTANT apps.fnd_common_lookups.meaning%TYPE := 'Element Entry';
  /*
  START R12.2 Upgrade Remediation
  code commented by RXNETHI-ARGANO,29/06/23
  c_vacation_taken  CONSTANT hr.pay_element_types_f.element_name%TYPE := 'Vacation Taken';
  c_sick_taken  CONSTANT hr.pay_element_types_f.element_name%TYPE := 'Sick Taken';
  c_personal_holiday_taken  CONSTANT hr.pay_element_types_f.element_name%TYPE := 'Personal Holiday Taken';
  c_vacation_payout  CONSTANT hr.pay_element_types_f.element_name%TYPE := 'Vacation Payout';
  */
  --code added by RXNETHI-ARGANO,29/06/23
  c_vacation_taken          CONSTANT       apps.pay_element_types_f.element_name%TYPE := 'Vacation Taken';
  c_sick_taken              CONSTANT       apps.pay_element_types_f.element_name%TYPE := 'Sick Taken';
  c_personal_holiday_taken  CONSTANT       apps.pay_element_types_f.element_name%TYPE := 'Personal Holiday Taken';
  c_vacation_payout         CONSTANT       apps.pay_element_types_f.element_name%TYPE := 'Vacation Payout';
  --END R12.2 Upgrade Remediation

  -- declare commit counter
  g_commit_count                 NUMBER := 1;

  -- declare exceptions
  SKIP_RECORD  	  	     EXCEPTION;
  NO_BUSINESS_ORG_ID     EXCEPTION;
  NO_BATCH_NAMES         EXCEPTION;
  TOO_MANY_BATCHES       EXCEPTION;
  ERRORS_IN_STAGE        EXCEPTION;
  ERROR_SETTING_DEFAULTS EXCEPTION;

  -- declare cursors
  -- ikonak 01/07/03 added business group
  -- ikonak 02/24/03 added Employee.Applicant status
  CURSOR csr_bee_int_stage_data(p_batch_name IN VARCHAR2, p_business_group_id IN NUMBER,
                                                          p_business_group IN VARCHAR2) IS
	   SELECT tbis.batch_name, tbis.employee_number, tbis.element_name
           ,tbis.value1, tbis.value2, tbis.value3, tbis.value4, tbis.value5, tbis.value6
           ,tbis.value7, tbis.value8, tbis.value9, tbis.value10, tbis.value11
           ,tbis.value12, tbis.value13, tbis.value14, tbis.value15, tbis.rowid
     --FROM cust.tt_bee_interface_stage tbis, hr.per_all_people_f papf, hr.per_person_types ppt  --code commented by RXNETHI-ARGANO,29/06/23
     FROM apps.tt_bee_interface_stage tbis, apps.per_all_people_f papf, apps.per_person_types ppt  --code added by RXNETHI-ARGANO,29/06/23
     WHERE tbis.record_processed = c_unprocessed_flag
	   AND tbis.batch_name = p_batch_name
     AND papf.business_group_id = p_business_group_id
     AND tbis.employee_number = papf.employee_number
     AND sysdate BETWEEN papf.effective_start_date AND papf.effective_end_date
     AND papf.person_type_id = ppt.person_type_id
	 AND ppt.system_person_type like '%EMP%' --IN ('EMP', 'EX_EMP','EMP_APL')
	 AND tbis.BUSINESS_GROUP = p_business_group;
     -- This cursor will not pick up non-valid employee numbers from the staging table.
     -- The non-valid employee numbers will remain unprocessed.  To process the records,
     -- correct the employee number and resubmit the process.

  -- ***NOT USED******************************************
  -- ikonak 01/07/03
  CURSOR csr_stage_emp_numbers(p_batch_name IN VARCHAR2, p_business_group_id IN NUMBER,
                                                          p_business_group IN VARCHAR2) IS
	   SELECT tbis.employee_number, tbis.rowid
     --FROM cust.tt_bee_interface_stage tbis, hr.per_all_people_f papf, hr.per_person_types ppt     --code commented by RXNETHI-ARGANO,29/06/23
     FROM apps.tt_bee_interface_stage tbis, apps.per_all_people_f papf, apps.per_person_types ppt   --code added by RXNETHI-ARGANO,29/06/23
     WHERE tbis.batch_name = p_batch_name
     AND papf.business_group_id = p_business_group_id
     AND tbis.employee_number = papf.employee_number
     AND sysdate BETWEEN papf.effective_start_date AND papf.effective_end_date
     AND papf.person_type_id = ppt.person_type_id
	 AND ppt.system_person_type like '%EMP%' --IN ('EMP', 'EX_EMP', 'EMP_APL')
	 AND tbis.BUSINESS_GROUP = p_business_group;

  --  ****NOT USED*******************************************
  -- ikonak 01/07/03
  CURSOR csr_stage_unprocessed_batches (p_business_group IN VARCHAR2) IS
     SELECT tbis.batch_name, papf.business_group_id, haou.name
     --FROM cust.tt_bee_interface_stage tbis, hr.per_all_people_f papf, hr.per_person_types ppt    --code commented by RXNETHI-ARGANO,29/06/23
     FROM apps.tt_bee_interface_stage tbis, apps.per_all_people_f papf, apps.per_person_types ppt  --code added by RXNETHI-ARGANO,29/06/23
        -- ,hr.hr_all_organization_units haou   --code commented by RXNETHI-ARGANO,29/06/23
         ,apps.hr_all_organization_units haou   --code added by RXNETHI-ARGANO,29/06/23
     WHERE tbis.record_processed = 'N'
     AND tbis.employee_number = papf.employee_number
     AND sysdate BETWEEN papf.effective_start_date AND papf.effective_end_date
     AND papf.person_type_id = ppt.person_type_id
	   AND ppt.system_person_type like '%EMP%' --IN ('EMP', 'EX_EMP', 'EMP_APL')
     AND papf.business_group_id = haou.organization_id
	 AND tbis.BUSINESS_GROUP = p_business_group
     GROUP BY tbis.batch_name, papf.business_group_id, haou.name;
     -- this cursor assumes that emp num is unique for any business group
     -- otherwise, it will create a batch per business group id per emp num

  -- cursor to get the unprocessed batches.  At the time this cursor is run, all of the records
  --   with valid employee number should have been processed, therefore, this cursor should only
  --   get the records where the employee number is not valid.
  -- ikonak 01/07/03
  CURSOR csr_unprocessed_records (p_business_group IN VARCHAR2) IS
     SELECT tbis.batch_name, tbis.employee_number, tbis.element_name, tbis.value1, tbis.value2
           ,tbis.value3, tbis.value4, tbis.value5, tbis.rowid
     --FROM cust.tt_bee_interface_stage tbis  --code commented by RXNETHI-ARGANO,29/06/23
     FROM apps.tt_bee_interface_stage tbis    --code added by RXNETHI-ARGANO,29/06/23
     WHERE tbis.record_processed = 'N'
	   AND tbis.error_flag = 'N'
	   AND tbis.error_message IS NULL
	   AND tbis.BUSINESS_GROUP = p_business_group;

  FUNCTION is_number(p_value IN VARCHAR2) RETURN VARCHAR2;

  FUNCTION get_element_value_name(p_element_name IN VARCHAR2
                                 ,p_element_type_id IN NUMBER
                                 ,p_display_seq IN NUMBER
                                 ,p_effective_date IN DATE DEFAULT SYSDATE) RETURN VARCHAR2;

  FUNCTION get_lookup_code(p_lookup_type IN VARCHAR2, p_meaning IN VARCHAR2) RETURN VARCHAR2;

  PROCEDURE get_unprocessed_batch_count(p_count OUT NUMBER);

  PROCEDURE validate_employee_number(p_emp_num IN VARCHAR2, p_business_group_id IN NUMBER
                                    ,p_count OUT NUMBER);

  PROCEDURE get_batch_id(p_batch_id OUT NUMBER);

  PROCEDURE get_batch_line_id(p_batch_line_id OUT NUMBER);

  PROCEDURE get_assignment_info(p_employee_number IN VARCHAR2, p_business_group_id IN NUMBER
                               ,p_effective_date IN DATE, p_assignment_id OUT NUMBER
                               ,p_assignment_number OUT VARCHAR2, p_payroll_id OUT NUMBER);

  PROCEDURE get_employee_name(p_employee_number IN VARCHAR2, p_business_group_id IN NUMBER
                             ,p_effective_date IN DATE, p_employee_name OUT VARCHAR2);

  PROCEDURE get_element_type_id(p_element_name IN VARCHAR2, p_business_group_id IN NUMBER
                               ,p_effective_date IN DATE, p_element_type_id OUT NUMBER);

  PROCEDURE create_bee_header(p_batch_id IN NUMBER,p_business_group_id IN NUMBER
                             ,p_batch_status IN VARCHAR2
                             ,p_action_if_exists IN VARCHAR2
                             ,p_purge_after_transfer IN VARCHAR2
                             ,p_reject_if_future_changes IN VARCHAR2);

  PROCEDURE create_bee_line(p_batch_id IN NUMBER, p_batch_line_id IN NUMBER
                           ,p_element_type_id IN NUMBER, p_assignment_id IN NUMBER
                           ,p_batch_status IN VARCHAR2, p_assignment_number IN VARCHAR2
                           ,p_batch_sequence IN NUMBER, p_effective_date IN DATE
                           ,p_element_name IN VARCHAR2, p_entry_type IN VARCHAR2
                           ,p_value1 IN VARCHAR2 DEFAULT NULL
                           ,P_value2 IN VARCHAR2 DEFAULT NULL
                           ,p_value3 IN VARCHAR2 DEFAULT NULL
                           ,p_value4 IN VARCHAR2 DEFAULT NULL
                           ,p_value5 IN VARCHAR2 DEFAULT NULL
                           ,p_value6 IN VARCHAR2 DEFAULT NULL
                           ,p_value7 IN VARCHAR2 DEFAULT NULL
                           ,p_value8 IN VARCHAR2 DEFAULT NULL
                           ,p_value9 IN VARCHAR2 DEFAULT NULL
                           ,p_value10 IN VARCHAR2 DEFAULT NULL
                           ,p_value11 IN VARCHAR2 DEFAULT NULL
                           ,p_value12 IN VARCHAR2 DEFAULT NULL
                           ,p_value13 IN VARCHAR2 DEFAULT NULL
                           ,p_value14 IN VARCHAR2 DEFAULT NULL
                           ,p_value15 IN VARCHAR2 DEFAULT NULL);

  PROCEDURE update_stage_table(p_rowid IN VARCHAR2, p_emp_num IN VARCHAR2
                              ,p_rec_process IN VARCHAR2, p_error_flag IN VARCHAR2
                              ,p_error_message IN VARCHAR2 DEFAULT NULL);

  PROCEDURE output_bee_summary_by_loc(p_batch_name IN VARCHAR2 DEFAULT NULL
                                     ,p_batch_reference IN VARCHAR2 DEFAULT NULL
                                     ,p_batch_source IN VARCHAR2 DEFAULT NULL
                                     ,p_batch_id IN NUMBER DEFAULT NULL
                                     ,ERRBUF OUT VARCHAR2, RETCODE OUT NUMBER);

  PROCEDURE output_bee_summary(p_batch_name IN VARCHAR2 DEFAULT NULL
                              ,p_batch_reference IN VARCHAR2 DEFAULT NULL
                              ,p_batch_source IN VARCHAR2 DEFAULT NULL
                              ,p_batch_id IN NUMBER DEFAULT NULL
                              ,ERRBUF OUT VARCHAR2, RETCODE OUT NUMBER);

  PROCEDURE main (ERRBUF OUT VARCHAR2, RETCODE OUT NUMBER, l_element_effective_date IN DATE,
                                                           l_parameter_business_group_id IN NUMBER);

end TT_BEE_INTERFACE;
/
show errors;
/