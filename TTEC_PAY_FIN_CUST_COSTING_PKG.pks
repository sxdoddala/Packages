
create or replace PACKAGE      ttec_pay_fin_cust_costing_pkg
AUTHID CURRENT_USER AS
/* $Header: ttec_pay_fin_custom_costing_pkg.pkb 1.0 2010/05/10 kbabu $ */
/*== START ================================================================================================*\
  Author:  Kaushik Babu
    Date:  May 21, 2010
    Desc:  This package is used for updating seeded payroll costing for all business groups
  Modification History:

 Mod#  Person         Date     Comments
---------------------------------------------------------------------------
 1.0  Kaushik Babu  21-May-10 Created new package TTSD 124797
 
 1.0  RXNETHI-ARGANO  11/MAY/2023    R12.2 Upgrade Remediation
\*== END ==================================================================================================*/
-- Error Constants
   /*
   START R12.2 Upgrade Remediation
   code commented by RXNETHI-ARGANO,11/05/23
   g_application_code   cust.ttec_error_handling.application_code%TYPE   := 'PAY';
   g_interface          cust.ttec_error_handling.INTERFACE%TYPE          := 'PayCustCosting';
   g_package            cust.ttec_error_handling.program_name%TYPE       := 'TTEC_PAY_FIN_CUST_COSTING';
   */
   --code added by RXNETHI-ARGANO,11/05/23
   g_application_code   apps.ttec_error_handling.application_code%TYPE   := 'PAY';
   g_interface          apps.ttec_error_handling.INTERFACE%TYPE          := 'PayCustCosting';
   g_package            apps.ttec_error_handling.program_name%TYPE       := 'TTEC_PAY_FIN_CUST_COSTING';
   --END R12.2 Upgrade Remediation
   g_status_warning     VARCHAR2 (7)                                     := 'WARNING';
   g_status_failure     VARCHAR2 (7)                                     := 'FAILURE';
   g_fail_msg           VARCHAR2 (240)                                   DEFAULT NULL;
   g_reference          VARCHAR2 (250)                                   DEFAULT NULL;
   --g_module             cust.ttec_error_handling.module_name%TYPE        DEFAULT NULL;      --code commented by RXNETHI-ARGANO,11/05/23
   g_module             apps.ttec_error_handling.module_name%TYPE        DEFAULT NULL;        --code added by RXNETHI-ARGANO,11/05/23

   TYPE keyflex_record IS RECORD (
      /*
	  
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,11/05/23
	  payroll_id                   hr.pay_payroll_actions.payroll_id%TYPE,
      assignment_id                hr.per_all_assignments_f.assignment_id%TYPE,
      cost_allocation_keyflex_id   hr.pay_cost_allocation_keyflex.cost_allocation_keyflex_id%TYPE,
      concatenated_segments        hr.pay_cost_allocation_keyflex.concatenated_segments%TYPE,
      id_flex_num                  hr.pay_cost_allocation_keyflex.id_flex_num%TYPE,
      summary_flag                 hr.pay_cost_allocation_keyflex.summary_flag%TYPE,
      enabled_flag                 hr.pay_cost_allocation_keyflex.enabled_flag%TYPE,
      segment1                     hr.pay_cost_allocation_keyflex.segment1%TYPE,
      segment2                     hr.pay_cost_allocation_keyflex.segment2%TYPE,
      segment3                     hr.pay_cost_allocation_keyflex.segment3%TYPE,
      segment4                     hr.pay_cost_allocation_keyflex.segment4%TYPE,
      segment5                     hr.pay_cost_allocation_keyflex.segment5%TYPE,
      segment6                     hr.pay_cost_allocation_keyflex.segment6%TYPE,
      */
	  --code added by RXNETHI-ARGANO,11/05/23
	  payroll_id                   apps.pay_payroll_actions.payroll_id%TYPE,
      assignment_id                apps.per_all_assignments_f.assignment_id%TYPE,
      cost_allocation_keyflex_id   apps.pay_cost_allocation_keyflex.cost_allocation_keyflex_id%TYPE,
      concatenated_segments        apps.pay_cost_allocation_keyflex.concatenated_segments%TYPE,
      id_flex_num                  apps.pay_cost_allocation_keyflex.id_flex_num%TYPE,
      summary_flag                 apps.pay_cost_allocation_keyflex.summary_flag%TYPE,
      enabled_flag                 apps.pay_cost_allocation_keyflex.enabled_flag%TYPE,
      segment1                     apps.pay_cost_allocation_keyflex.segment1%TYPE,
      segment2                     apps.pay_cost_allocation_keyflex.segment2%TYPE,
      segment3                     apps.pay_cost_allocation_keyflex.segment3%TYPE,
      segment4                     apps.pay_cost_allocation_keyflex.segment4%TYPE,
      segment5                     apps.pay_cost_allocation_keyflex.segment5%TYPE,
      segment6                     apps.pay_cost_allocation_keyflex.segment6%TYPE,
	  --END R12.2 Upgrade Remediation
	  location_src                 VARCHAR2 (25),
      client_src                   VARCHAR2 (25),
      department_src               VARCHAR2 (25),
      account_src                  VARCHAR2 (25),
      location_att                 VARCHAR2 (25),
      department_att               VARCHAR2 (25),
      client_att                   VARCHAR2 (25),
      --proportion                   hr.pay_cost_allocations_f.proportion%TYPE            --code commented by RXNETHI-ARGANO,11/05/23
	  proportion                   apps.pay_cost_allocations_f.proportion%TYPE            --code added by RXNETHI-ARGANO,11/05/23
   );

   v_keyflex_record     keyflex_record;

   PROCEDURE insert_keyflex_record (
      l_keyflex_record              IN       keyflex_record,
      --l_business_group              IN       hr.per_all_assignments_f.business_group_id%TYPE,         --code commented by RXNETHI-ARGANO,11/05/23
	  l_business_group              IN       apps.per_all_assignments_f.business_group_id%TYPE,         --code added by RXNETHI-ARGANO,11/05/23
      p_new_allocation_keyflex_id   OUT      NUMBER
   );

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
   );

   PROCEDURE main_proc (
      p_errbuf                 OUT   VARCHAR2,
      p_errcode                OUT   NUMBER,
      p_payroll_id             IN   NUMBER,
      p_consolidation_set_id   IN   NUMBER,
      p_start_date             IN   VARCHAR2,
      p_end_date               IN   VARCHAR2,
      p_business_grp_id        IN   NUMBER,
      p_seg_location           IN   VARCHAR2,
      p_seg_client             IN   VARCHAR2,
      p_seg_dept               IN   VARCHAR2,
      p_seg_acct               IN   VARCHAR2,
      p_employee_id            IN   NUMBER,
      p_job_id                 IN   NUMBER
   );
END ttec_pay_fin_cust_costing_pkg;
/
show errors;
/