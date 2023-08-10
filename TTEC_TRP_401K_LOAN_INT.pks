create or replace PACKAGE      ttec_trp_401k_loan_int AUTHID CURRENT_USER
AS
--
-- Program Name:  ttec_trp_401k_loan_int
-- /* $Header: ttec_trp_401k_loan_int.pks 1.0 2020/02/24  chchan ship $ */
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
--------------------------------------------------------------------------------------------------------------------
    -- Error Constants
   /*
   START R12.2 Upgrade Remediation
   code commented by RXNETHI-ARGANO,04/05/23
   g_application_code            cust.ttec_error_handling.application_code%TYPE
                                                                     := 'BEN';
   g_interface                   cust.ttec_error_handling.INTERFACE%TYPE
                                                           := 'BAML Def Intf';
   g_package                     cust.ttec_error_handling.program_name%TYPE
                                             := 'ttec_trp_401k_loan_int';
   g_label1                      cust.ttec_error_handling.label1%TYPE
                                                            := 'Err Location';
   g_label2                      cust.ttec_error_handling.label1%TYPE
                                                              := 'Emp_Number';
   g_warning_status              cust.ttec_error_handling.status%TYPE
                                                                 := 'WARNING';
   g_error_status                cust.ttec_error_handling.status%TYPE
                                                                   := 'ERROR';
   g_failure_status              cust.ttec_error_handling.status%TYPE
                                                                 := 'FAILURE';
	*/
	--code added by RXNETHI-ARGANO,04/05/23
   g_application_code            apps.ttec_error_handling.application_code%TYPE
                                                                     := 'BEN';
   g_interface                   apps.ttec_error_handling.INTERFACE%TYPE
                                                           := 'BAML Def Intf';
   g_package                     apps.ttec_error_handling.program_name%TYPE
                                             := 'ttec_trp_401k_loan_int';
   g_label1                      apps.ttec_error_handling.label1%TYPE
                                                            := 'Err Location';
   g_label2                      apps.ttec_error_handling.label1%TYPE
                                                              := 'Emp_Number';
   g_warning_status              apps.ttec_error_handling.status%TYPE
                                                                 := 'WARNING';
   g_error_status                apps.ttec_error_handling.status%TYPE
                                                                   := 'ERROR';
   g_failure_status              apps.ttec_error_handling.status%TYPE
                                                                 := 'FAILURE';
	--END R12.2 Upgrade Remediation
   -- Process FAILURE variables
   g_fail_flag                   BOOLEAN                             := FALSE;
   g_emp_no                      VARCHAR2 (20);
   -- Filehandle Variables
   p_filedir                     VARCHAR2 (400);
   p_filename                    VARCHAR2 (100);
   p_country                     VARCHAR2 (10);
   /***Variables used by Common Error Procedure***/
   g_validate                    BOOLEAN                             := FALSE;
   g_entry_type                  VARCHAR2 (1)                          := 'E';
   g_process_date               DATE;
   g_plan_entry_date             DATE;
   g_as_of_date                  DATE;
   g_system_person_status        VARCHAR2 (60);
   g_location_code               VARCHAR2 (60)                   DEFAULT NULL;
   g_full_name                   VARCHAR2 (150)                  DEFAULT NULL;
--   g_401k_NewLoan_pct           NUMBER;
--   g_401k_ReAmortized_pct   NUMBER;
--   g_401k_bonus_saving_pct       NUMBER;
   g_401k_LoanTerm_amt           NUMBER;
   g_401k_NewLoan_amt            NUMBER;
   g_401k_ReAmortized_amt   NUMBER; /* 2.0 */
   l_errorlog_output             CHAR (3020);
   l_updated_output              CHAR (3020);
   l_update_status               VARCHAR2 (150)           := 'Did Not Update';
   v_errorlog_count              NUMBER                                  := 0;
   v_updated_count               NUMBER                                  := 0;
--*****************************************************************************************************
g_element_name VARCHAR2(50):= 'Loan 1_401k';
g_input_name VARCHAR2(50) := 'Amount';
g_input_value     NUMBER := NULL;
--   g_input_name                  VARCHAR2 (50)                := 'Percentage';
   g_elementnew_name             VARCHAR2 (50)              := 'Pre Tax 401K';
   g_elementcatchup_name         VARCHAR2 (50)      := 'Pre Tax 401K Catchup';
   g_ele_name_401k_bonus_pct     VARCHAR2 (50)      := 'Pre Tax 401K Bonus'; /* 2.0 */
   g_ele_name_401k_NewLoan_amt  VARCHAR2 (50)      := 'Pre Tax 401K Flat Dollar'; /* 2.0 */ /* 3.0 */
   g_ele_name_401k_catchup_amt   VARCHAR2 (50)      := 'Pre Tax 401K Catch Up Flat Dollar'; /* 2.0 */ /* 3.0 */
   g_ele_name_401k_NewLoan_amt  VARCHAR2 (50)      := 'Pre Tax 401K Flat Dollar Deferral'; /* 3.0 */
   g_ele_name_401k_catchup_amt   VARCHAR2 (50)      := 'Pre Tax 401K Flat Dollar Deferral Catchup'; /* 3.0 */
   errbuf                        VARCHAR2 (50);
   retcode                       NUMBER;
   /***Exceptions***/
   skip_record                   EXCEPTION;
   skip_record3                  EXCEPTION;

   /***Cursor declaration***/

   CURSOR csr_loan
   IS
      SELECT     REC_TYPE,
                            SUBSTR (SSN, 1, 3)
                         || '-'
                         || SUBSTR (SSN, 4, 2)
                         || '-'
                         || SUBSTR (SSN, 6, 4) social_number,
                         employee_number emp_no,
                        decode(REC_TYPE, '387' , loan_amt_principle * .01
                                       ,loan_pymt_amt * .01
                              ) loan_payment_amount
        FROM TTEC_401K_TRP_LOAN_STG
       ORDER BY employee_number, REC_TYPE;

/*  2.2 Commented out begin */
--   CURSOR csr_loan
--   IS
--      SELECT    SUBSTR (field1, 1, 3)
--             || '-'
--             || SUBSTR (field1, 4, 2)
--             || '-'
--             || SUBSTR (field1, 6, 4) social_number,
--             field2 emp_no, TO_NUMBER (field4) / 1000 * 100 deferral_pct,
--             TO_NUMBER (field11) / 1000 * 100 catchup_NewLoan_pct,
--             field6  * .01  deferral_amt,       /* 2.0 */
--             field12 * .01 catchup_NewLoan_amt /* 2.0 */
--        FROM TTEC_401K_TRP_LOAN_STG
--       WHERE rec_type = '10';
/*  2.2 Commented out end */
--************************************************************************************--
--*                          GET ASSIGNMENT ID                                       *--
--************************************************************************************--
   PROCEDURE get_assignment_id (
      v_ssn                    IN       VARCHAR2,
      v_employee_number        OUT      VARCHAR2,
      v_full_name              OUT      VARCHAR2,
      p_assignment_id          OUT      NUMBER,
      p_business_group_id      OUT      NUMBER,
      p_payroll_id             OUT      NUMBER,  /* 1.3 */
      p_location_id            OUT      NUMBER,  /* 1.3 */
      p_effective_start_date   OUT      DATE,
      p_effective_end_date     OUT      DATE,
      p_process_status         OUT      VARCHAR2
   );

   ---***********************************  Get Location Code ********************************-----
   PROCEDURE get_location (
      v_ssn              IN       VARCHAR2,
      v_full_name        OUT      VARCHAR2,
      v_location_code    OUT      VARCHAR2,
      p_process_status   OUT      VARCHAR2
   );

--***************************************************************
--*****                  GET PERSON TYPE                *****
--***************************************************************
--get_person_type(sel.employee_number, v_system_person_type);
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
   );

----*******************************************************************---------------------
--get_employee_status(sel.social_number,l_system_person_status);
   PROCEDURE get_termed_status (
      v_ssn                    IN       VARCHAR2,
      v_system_person_status   OUT      VARCHAR2
   );

----***************************************************************************-------------

   ---**************************************************************************************
--get_employee_status(sel.social_number,l_system_person_status);
   PROCEDURE get_employee_status (
      v_ssn                    IN       VARCHAR2,
      v_full_name              OUT      VARCHAR2,
      v_system_person_status   OUT      VARCHAR2,
      p_process_status         OUT      VARCHAR2
   );

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
   );

--***************************************************Create Element API********************************************

   --***************************************************************
--*****                  MAIN Program                       *****
--***************************************************************
   PROCEDURE create_element_entry (
      v_process_date         IN       DATE,
      v_process_type          IN       VARCHAR2,
      v_ssn                   IN       VARCHAR2,
      v_assignment_id         IN       NUMBER,
      v_business_group_id     IN       NUMBER,
      v_element_name          IN       VARCHAR2,
      v_ele_entry_value       IN       NUMBER,
      v_input_value_type      IN       VARCHAR2, /* 2.0 */
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
   );

   PROCEDURE main (
      errcode          OUT      VARCHAR2,
      errbuff          OUT      VARCHAR2,
      p_process_date   IN       VARCHAR2
   );
END ttec_trp_401k_loan_int;
/
show errors;
/