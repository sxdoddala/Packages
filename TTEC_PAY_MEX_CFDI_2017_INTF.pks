create or replace PACKAGE      ttec_pay_mex_cfdi_2017_intf
AS
/*---------------------------------------------------------------------------------------
 Objective    : Interface to extract data for all Mexico employees to send to LEVICOM
 Package spec :ttec_pay_mex_cfdi_2017_intf
 Parameters:p_output_dir    --  output directory to generate the files.
            p_start_date  -- required payroll start paramters to run the report if the data is missing for particular dates
            p_end_date  -- required payroll end paramters to run the report if the data is missing for particular dates
   MODIFICATION HISTORY
   Person               Version  Date        Comments
   ------------------------------------------------
   Christiane Chan        1.0    2/3/2015  Copy from Kaushik Original package to send mexico 2015 payroll employee data to Levicom
   RXNETHI-ARGANO         1.0    11/MAY/2023  R12.2 Upgrade Remediation
*== END ==================================================================================================*/
    /*
	START R12.2 Upgrade Remediation
	code commented by RXNETHI-ARGANO,12/05/23g_application_code   cust.ttec_error_handling.application_code%TYPE := 'PAY';
    g_interface          cust.ttec_error_handling.INTERFACE%TYPE        := 'PAYCFDI2017';
    g_package            cust.ttec_error_handling.program_name%TYPE     := 'ttec_pay_mex_cfdi_2017_intf';
    g_label1             cust.ttec_error_handling.label1%TYPE           := 'Err Location';
    g_label2             cust.ttec_error_handling.label1%TYPE           := 'Emp_Number';
	*/
	--code added by RXNETHI-ARGANO,12/05/23
	g_application_code   apps.ttec_error_handling.application_code%TYPE := 'PAY';
    g_interface          apps.ttec_error_handling.INTERFACE%TYPE        := 'PAYCFDI2017';
    g_package            apps.ttec_error_handling.program_name%TYPE     := 'ttec_pay_mex_cfdi_2017_intf';
    g_label1             apps.ttec_error_handling.label1%TYPE           := 'Err Location';
    g_label2             apps.ttec_error_handling.label1%TYPE           := 'Emp_Number';
	--END R12.2 Upgrade Remediaton
    g_label3             varchar2(100);
    --g_emp_no                       hr.per_all_people_f.employee_number%TYPE; --code commented by RXNETHI-ARGANO,12/05/23
	g_emp_no                       apps.per_all_people_f.employee_number%TYPE; --code added by RXNETHI-ARGANO,12/05/23
    g_current_run_date   date;
    g_1PP_ISR_QUOTA      number:= NULL; /* 5.0.6 */
    g_2PP_ISR_QUOTA      number:= NULL; /* 5.0.6 */
   FUNCTION get_value (
      p_element_name    IN   VARCHAR2,
      p_class_name      IN   VARCHAR2,
      p_input_value     IN   VARCHAR2,
      p_assignment_id   IN   VARCHAR2,
      p_start_date      IN   DATE,
      p_end_date        IN   DATE,
      p_section         IN   VARCHAR2 DEFAULT '' /* 2.4.1*/
   )
      RETURN NUMBER;
   FUNCTION get_neg_value (p_element_name    IN VARCHAR2,
                           p_class_name      IN VARCHAR2,
                           p_input_value     IN VARCHAR2,
                           p_assignment_id   IN VARCHAR2,
                           p_start_date      IN DATE,
                           p_end_date        IN DATE)
      RETURN NUMBER;
   FUNCTION get_amount (p_value VARCHAR2)
      RETURN VARCHAR2;

   FUNCTION get_balance (p_assignment_id       NUMBER,
                         p_balance_name     IN VARCHAR2,
                         p_dimension_name   IN VARCHAR2,
                         p_effective_date   IN DATE)
      RETURN NUMBER;

   FUNCTION get_cntr_name (
      p_column_name     VARCHAR2,
      p_information11   VARCHAR2,
      p_element_name    VARCHAR2,
      p_session_date    DATE
   )
      RETURN VARCHAR2;

   FUNCTION get_subsidy_value (p_total_earning  VARCHAR2,
                               p_session_date   DATE
   )
      RETURN VARCHAR2;

   FUNCTION get_cntr_code (
      p_column_name     VARCHAR2,
      p_information11   VARCHAR2,
      p_element_name    VARCHAR2,
      p_session_date    DATE
   )
      RETURN VARCHAR2;

   FUNCTION get_sat_code (
      p_element_name           VARCHAR2,
      p_information_category   VARCHAR2,
      p_information11          VARCHAR2,
      p_session_date           DATE
   )
      RETURN VARCHAR2;

   FUNCTION get_cfdi_map_code (
      p_oracle_value           VARCHAR2,
      p_information_category   VARCHAR2,
      p_information11          VARCHAR2,
      p_session_date           DATE
   )
      RETURN VARCHAR2;

   FUNCTION get_rep_name (p_element_name VARCHAR2, p_session_date DATE)
      RETURN VARCHAR2;

   FUNCTION get_ele_name (p_reporting_name VARCHAR2, p_session_date DATE)
      RETURN VARCHAR2;

   FUNCTION get_costing_info (p_payroll_id NUMBER,p_element_name VARCHAR2, p_session_date DATE)
      RETURN VARCHAR2;

   FUNCTION get_information (p_element_name VARCHAR2, p_session_date DATE)
      RETURN VARCHAR2;
   FUNCTION get_ded_value (p_element_name    IN VARCHAR2,
                           p_class_name      IN VARCHAR2,
                           p_input_value     IN VARCHAR2,
                           p_assignment_id   IN VARCHAR2,
                           p_start_date      IN DATE,
                           p_end_date        IN DATE)
      RETURN NUMBER;
   FUNCTION get_1PP_ISR_subsidy_bal (p_assignment_id       NUMBER,
                                     p_balance_name     IN VARCHAR2,
                                     p_dimension_name   IN VARCHAR2,
                                     p_start_date      IN DATE,
                                     p_end_date        IN DATE)
   RETURN NUMBER; /* 5.0.1 */
   PROCEDURE main_proc (
      errbuf               OUT      VARCHAR2,
      retcode              OUT      NUMBER,
      p_output_directory   IN       VARCHAR2,
      p_start_date         IN       VARCHAR2,
      p_end_date           IN       VARCHAR2,
      p_payroll_id         IN       NUMBER,
      p_employee_number    IN       VARCHAR2,
      p_pay_date           IN       VARCHAR2,
      p_profit_sharing_payout IN    VARCHAR2
   );
END ttec_pay_mex_cfdi_2017_intf;
/
show errors;
/