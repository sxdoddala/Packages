create or replace PACKAGE      Tt_Hr AUTHID CURRENT_USER IS
/***********************************************************************************/
-- Program Name: TT_HR GENERAL PACKAGE
--
--
--
-- Tables Modified:  N/A
--
--
--
-- Modification Log:
-- Developer    Version   Date       Description
-- ----------  --------  ------      --------------------
-- Kaushik Babu  1.0    04-DEC-2008  TT_HR.get_401k_plan_type procedure is been used in TT_401K_INTERFACE_2009 package
--                                   Changed logic to provide plantype for Kalispell employee for the 2009 and onwards.
-- Wasim Manasfi 1.2    -5-JUN-2009  added Birmngham to the sites 'USA-Birmingham (Govt)' so agents can go to TT2
--IXPRAVEEN(ARGANO)	1.0		16-May-2023 R12.2 Upgrade Remediation
/************************************************************************************/
 -- declare error handling variables
  --START R12.2 Upgrade Remediation
  /*c_application_code            cust.ttec_error_handling.application_code%TYPE  := 'HR';
  c_interface                   cust.ttec_error_handling.INTERFACE%TYPE := 'HR-LOOKUP';
  c_program_name                cust.ttec_error_handling.program_name%TYPE  := 'TT_HR';
  c_failure_status              cust.ttec_error_handling.status%TYPE  := 'FAILURE';*/
  c_application_code            apps.ttec_error_handling.application_code%TYPE  := 'HR';
  c_interface                   apps.ttec_error_handling.INTERFACE%TYPE := 'HR-LOOKUP';
  c_program_name                apps.ttec_error_handling.program_name%TYPE  := 'TT_HR';
  c_failure_status              apps.ttec_error_handling.status%TYPE  := 'FAILURE';
  --END R12.2.12 Upgrade remediation


  -- declare global variables
  --START R12.2 Upgrade Remediation
  /*g_module_name					 cust.ttec_error_handling.module_name%TYPE := NULL;
  g_error_message     			 cust.ttec_error_handling.error_message%TYPE := NULL;
  g_primary_column               cust.ttec_error_handling.reference1%TYPE := NULL;
  g_secondary_column             cust.ttec_error_handling.reference1%TYPE := NULL;
  g_label1			cust.ttec_error_handling.label1%TYPE := 'Emp_Number';
  g_label2			cust.ttec_error_handling.label1%TYPE := NULL;*/
  g_module_name					 apps.ttec_error_handling.module_name%TYPE := NULL;
  g_error_message     			 apps.ttec_error_handling.error_message%TYPE := NULL;
  g_primary_column               apps.ttec_error_handling.reference1%TYPE := NULL;
  g_secondary_column             apps.ttec_error_handling.reference1%TYPE := NULL;
  g_label1			apps.ttec_error_handling.label1%TYPE := 'Emp_Number';
  g_label2			apps.ttec_error_handling.label1%TYPE := NULL;
  --END R12.2.12 Upgrade remediation


  FUNCTION  get_accrual (p_assignment_id IN NUMBER, p_payroll_id IN  NUMBER,
                                p_business_group_id IN NUMBER,  p_accrual_type IN VARCHAR2,
								p_calculation_date IN DATE)  RETURN  NUMBER ;

  FUNCTION  get_enrolled_flag (p_assignment_id IN NUMBER, p_pl_id IN  NUMBER, p_bnft_amt OUT NUMBER )
                                  RETURN  VARCHAR2 ;

  FUNCTION  get_benefit_increase_flag (p_assignment_id IN NUMBER, p_pl_id IN  NUMBER )
                                   RETURN  VARCHAR2 ;

  FUNCTION  get_balance (p_person_id IN NUMBER, p_balance_name IN  VARCHAR2,
                                p_effective_date IN DATE)  RETURN  NUMBER ;

   FUNCTION  get_balance_asg (p_assignment_id IN NUMBER, p_balance_name IN  VARCHAR2,
                                p_effective_date IN DATE)  RETURN  NUMBER ;

    FUNCTION  get_balance_asg_entry (p_assignment_id IN NUMBER, p_balance_name IN  VARCHAR2,
                                p_effective_date IN DATE)  RETURN  NUMBER ;

   FUNCTION  get_vacation_taken (p_assignment_id IN NUMBER,
                                p_date IN DATE)  RETURN  NUMBER;

   FUNCTION  get_bank_adjustment (p_assignment_id IN NUMBER,
                                p_date IN DATE)  RETURN  NUMBER ;

	FUNCTION  get_401k_plan_type (  p_assignment_id IN NUMBER, p_start_date IN DATE,
                                p_term_date IN DATE, p_eligible_date IN DATE   )  RETURN  VARCHAR2;



END Tt_Hr;

/
show errors;
/