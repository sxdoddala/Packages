create or replace PACKAGE      ttec_kr_utils AUTHID CURRENT_USER
AS
   /* $Header: ttec_kr_utils.pks 1.0 2009/12/28 mdodge ship $ */

   /*== START ================================================================================================*\
      Author: Michelle Dodge
        Date: 12/28/2009
   Call From: TTEC_KR_PERSON_INTERFACE pkg, TTEC_KR_ACCRUAL_INTERFACE pkg, PayRule Mapping JDeveloper Form
        Desc: This package is used to hold procedures and functions for:
              (1) Shared components for both the Person and Accrual Interfaces
              (2) Logic for Future Defined Country specific fields including the
                  Special Identifiers and CustomString fields
              (3) Procedures used by the Kronos PayRule Mapping form

              The Application Code and Interface global variables are not set in
              this package as they will be set by the calling package to enable
              full error capturing and reporting by the calling process.

     Modification History:

    Version    Date     Author      Description (Include Ticket#)
    -------  --------  -----------  ------------------------------------------------------------------------------
        1.0  12/28/09  MDodge       Kronos Transformations Project : Utilities - Initial Version.
        1.5  10/2/10   WManasfi     Mexico Payroll - added procedure to test eligible GET_MEX_VAC_ELIGIBLE
        2.0  02/18/11  MDodge       R418946 - Added set_profile_page_context for new jDeveloper PROFILE Mapping form.
        2.1  06/28/11  Kgonuguntla  I 752623 - A coding that designates the supervisor for employees on the night before
                                             the effective date of the supervisor change instead of the night of the
                                             effective date change
        2.2  05/07/12  MDodge       R 1332456 - Add new Mapping Fields to set_page_context and set_profile_page_context
                                               (tks_type, generic_daprofile, delegate_profile, cascase_profile)
		1.0  08/05/23  RXNETHI-ARGANO R12.2 Upgrade Remediation
   \*== END ==================================================================================================*/

   -- Error logging Variables -- Application_code and Interface set by calling procedure
   /*
   START R12.2 Upgrade Remediation
   code commented by RXNETHI-ARGANO, 08/05/23
   g_application_code            cust.ttec_error_handling.application_code%TYPE;
   g_interface                   cust.ttec_error_handling.INTERFACE%TYPE;
   g_package                     cust.ttec_error_handling.program_name%TYPE
                                                   := 'TTEC_KR_COUNTRY_RULES';
   g_warning_status              cust.ttec_error_handling.status%TYPE
                                                                 := 'WARNING';
   g_error_status                cust.ttec_error_handling.status%TYPE
                                                                   := 'ERROR';
   g_failure_status              cust.ttec_error_handling.status%TYPE
                                                                 := 'FAILURE';
																 */
	--code added by RXNETHI-ARGANO,08/05/23
   g_application_code            apps.ttec_error_handling.application_code%TYPE;
   g_interface                   apps.ttec_error_handling.INTERFACE%TYPE;
   g_package                     apps.ttec_error_handling.program_name%TYPE
                                                   := 'TTEC_KR_COUNTRY_RULES';
   g_warning_status              apps.ttec_error_handling.status%TYPE
                                                                 := 'WARNING';
   g_error_status                apps.ttec_error_handling.status%TYPE
                                                                   := 'ERROR';
   g_failure_status              apps.ttec_error_handling.status%TYPE
                                                                 := 'FAILURE';
   --END R12.2 Upgrade Remediation
   -- Ver 2.1
   FUNCTION get_supervisor (p_person_id NUMBER, p_date DATE)
       RETURN NUMBER;

   PROCEDURE get_accrual_plan(
      p_accrual_plan_type   IN       VARCHAR2
    , p_assignment_id       IN       NUMBER
    , p_accrual_plan_id     OUT      NUMBER );

   PROCEDURE build_country_values(
    p_csr_data      IN       ttec_kr_person_outbound.csr_emp_data%ROWTYPE
    --, p_kr_emp_data   IN OUT   cust.ttec_kr_emp_master%ROWTYPE ); --code commented by RXNETHI-ARGANO, 08/05/23
	, p_kr_emp_data   IN OUT   apps.ttec_kr_emp_master%ROWTYPE ); --code added by RXNETHI-ARGANO, 08/05/23

   PROCEDURE save_process_run_time(
      v_request_id   NUMBER );

   PROCEDURE get_last_run_date(
      p_program_name    IN       fnd_concurrent_programs.concurrent_program_name%TYPE
    , p_arg1            IN       fnd_concurrent_requests.argument1%TYPE
            DEFAULT NULL
    , p_arg2            IN       fnd_concurrent_requests.argument2%TYPE
            DEFAULT NULL
    , p_arg3            IN       fnd_concurrent_requests.argument2%TYPE
            DEFAULT NULL
    , p_arg4            IN       fnd_concurrent_requests.argument2%TYPE
            DEFAULT NULL
    , p_arg5            IN       fnd_concurrent_requests.argument2%TYPE
            DEFAULT NULL
    , p_arg6            IN       fnd_concurrent_requests.argument2%TYPE
            DEFAULT NULL
    , p_arg7            IN       fnd_concurrent_requests.argument2%TYPE
            DEFAULT NULL
    , p_arg8            IN       fnd_concurrent_requests.argument2%TYPE
            DEFAULT NULL
    , p_arg9            IN       fnd_concurrent_requests.argument2%TYPE
            DEFAULT NULL
    , p_arg10           IN       fnd_concurrent_requests.argument2%TYPE
            DEFAULT NULL
    , p_last_run_date   OUT      DATE );


   PROCEDURE set_page_context(
      p_country   IN       VARCHAR2
    , p2          OUT      VARCHAR2   -- person_type
    , p3          OUT      VARCHAR2   -- time_zone_prompt
    , p4          OUT      VARCHAR2   -- location_code_prompt
    , p5          OUT      VARCHAR2   -- location_name_prompt
    , p6          OUT      VARCHAR2   -- wage_rate_prompt
    , p7          OUT      VARCHAR2   -- wage_profile_name_prompt
    , p8          OUT      VARCHAR2   -- accrual_profile_prompt
    , p9          OUT      VARCHAR2   -- func_access_profile_prompt
    , p10         OUT      VARCHAR2   -- display_profile_prompt
    , p11         OUT      VARCHAR2   -- fte_percentage_prompt
    , p12         OUT      VARCHAR2   -- fte_expected_hours_prompt
    , p13         OUT      VARCHAR2   -- fte_hours_prompt
    , p14         OUT      VARCHAR2   -- expected_daily_hours_prompt
    , p15         OUT      VARCHAR2   -- expected_weekly_hours_prompt
    , p16         OUT      VARCHAR2   -- expected_pay_period_hours_prompt
    , p17         OUT      VARCHAR2   -- device_group_prompt
    , p18         OUT      VARCHAR2   -- logon_profile_prompt
    , p19         OUT      VARCHAR2   -- emp_xfer_labor_prompt
    , p20         OUT      VARCHAR2   -- emp_pay_code_daprofile_prompt
    , p21         OUT      VARCHAR2   -- emp_work_rule_daprofile_prompt
    , p22         OUT      VARCHAR2   -- time_entry_method_prompt
    , p23         OUT      VARCHAR2   -- location_prompt
    , p24         OUT      VARCHAR2   -- client_prompt
    , p25         OUT      VARCHAR2   -- department_prompt
    , p26         OUT      VARCHAR2   -- program_prompt
    , p27         OUT      VARCHAR2   -- project_prompt
    , p28         OUT      VARCHAR2   -- activity_prompt
    , p29         OUT      VARCHAR2   -- team_prompt
    , p30         OUT      VARCHAR2   -- group_schedule_prompt
    , p31         OUT      VARCHAR2   -- employee_status_prompt
    , p32         OUT      VARCHAR2   -- user_status_prompt
    , p33         OUT      VARCHAR2   -- city_prompt
    , p34         OUT      VARCHAR2   -- state_province_prompt
    , p35         OUT      VARCHAR2   -- postal_code_prompt
    , p36         OUT      VARCHAR2   -- mgrtransferin_prompt
    , p37         OUT      VARCHAR2   -- mgremp_group_llset_prompt
    , p38         OUT      VARCHAR2   -- mgrxfer_llset_prompt
    , p39         OUT      VARCHAR2   -- mgrpay_code_dap_prompt
    , p40         OUT      VARCHAR2   -- mgrworkrule_dap_prompt
    , p41         OUT      VARCHAR2   -- mgrreport_dap_prompt
    , p42         OUT      VARCHAR2   -- gender_prompt
    , p43         OUT      VARCHAR2   -- flsa_prompt
    , p44         OUT      VARCHAR2   -- agency_name_prompt
    , p45         OUT      VARCHAR2   -- manages_multiple_countries_prompt
    , p46         OUT      VARCHAR2   -- payroll_name_prompt
    , p47         OUT      VARCHAR2   -- agent_support_flag_prompt
    , p48         OUT      VARCHAR2   -- employee_type_prompt
    , p49         OUT      VARCHAR2   -- employee_flag_prompt
    , p50         OUT      VARCHAR2   -- assignment_category_1_prompt
    , p51         OUT      VARCHAR2   -- assignment_category_2_prompt
    , p52         OUT      VARCHAR2   -- wah_flag_prompt
    , p53         OUT      VARCHAR2   -- job_title_prompt
    , p54         OUT      VARCHAR2   -- job_code_prompt
    , p55         OUT      VARCHAR2   -- salary_basis_prompt
    , p56         OUT      VARCHAR2   -- spec1_prompt
    , p57         OUT      VARCHAR2   -- spec2_prompt
    , p58         OUT      VARCHAR2   -- spec3_prompt
    , p59         OUT      VARCHAR2   -- spec4_prompt
    , p60         OUT      VARCHAR2   -- spec5_prompt
    , p61         OUT      VARCHAR2   -- spec6_prompt
    , p62         OUT      VARCHAR2   -- spec7_prompt
    , p63         OUT      VARCHAR2   -- spec8_prompt
    , p64         OUT      VARCHAR2   -- spec9_prompt
    , p65         OUT      VARCHAR2   -- spec10_prompt
    , p66         OUT      VARCHAR2   -- customstring1_prompt
    , p67         OUT      VARCHAR2   -- customstring2_prompt
    , p68         OUT      VARCHAR2   -- customstring3_prompt
    , p69         OUT      VARCHAR2   -- customstring4_prompt
    , p70         OUT      VARCHAR2   -- customstring5_prompt
    , p71         OUT      VARCHAR2   -- customstring6_prompt
    , p72         OUT      VARCHAR2   -- customstring7_prompt
    , p73         OUT      VARCHAR2   -- customstring8_prompt
    , p74         OUT      VARCHAR2   -- customstring9_prompt
    , p75         OUT      VARCHAR2   -- customstring10_prompt
    , p76         OUT      VARCHAR2   -- tks_type_prompt             -- 2.2
    , p77         OUT      VARCHAR2   -- generic_daprofile_prompt    -- 2.2
    , p78         OUT      VARCHAR2   -- delegate_profile_prompt     -- 2.2
    , p79         OUT      VARCHAR2   -- cascade_profile_prompt      -- 2.2
                                   );

   /* 2.0 - This procedure is designed to be called by the JDeveloper Profile Mapping from   */
   PROCEDURE set_profile_page_context(
      p1          OUT      VARCHAR2   -- person_type
    , p2          OUT      VARCHAR2   -- time_zone_prompt
    , p3          OUT      VARCHAR2   -- location_code_prompt
    , p4          OUT      VARCHAR2   -- location_name_prompt
    , p5          OUT      VARCHAR2   -- wage_rate_prompt
    , p6          OUT      VARCHAR2   -- accrual_profile_prompt
    , p7          OUT      VARCHAR2   -- fte_percentage_prompt
    , p8          OUT      VARCHAR2   -- fte_expected_hours_prompt
    , p9          OUT      VARCHAR2   -- fte_hours_prompt
    , p10         OUT      VARCHAR2   -- expected_daily_hours_prompt
    , p11         OUT      VARCHAR2   -- expected_weekly_hours_prompt
    , p12         OUT      VARCHAR2   -- expected_pay_period_hours_prompt
    , p13         OUT      VARCHAR2   -- device_group_prompt
    , p14         OUT      VARCHAR2   -- emp_xfer_labor_prompt
    , p15         OUT      VARCHAR2   -- location_prompt
    , p16         OUT      VARCHAR2   -- client_prompt
    , p17         OUT      VARCHAR2   -- department_prompt
    , p18         OUT      VARCHAR2   -- program_prompt
    , p19         OUT      VARCHAR2   -- project_prompt
    , p20         OUT      VARCHAR2   -- activity_prompt
    , p21         OUT      VARCHAR2   -- team_prompt
    , p22         OUT      VARCHAR2   -- group_schedule_prompt
    , p23         OUT      VARCHAR2   -- employee_status_prompt
    , p24         OUT      VARCHAR2   -- user_status_prompt
    , p25         OUT      VARCHAR2   -- city_prompt
    , p26         OUT      VARCHAR2   -- state_province_prompt
    , p27         OUT      VARCHAR2   -- postal_code_prompt
    , p28         OUT      VARCHAR2   -- country_prompt
    , p29         OUT      VARCHAR2   -- mgrtransferin_prompt
    , p30         OUT      VARCHAR2   -- mgremp_group_llset_prompt
    , p31         OUT      VARCHAR2   -- mgrxfer_llset_prompt
    , p32         OUT      VARCHAR2   -- gender_prompt
    , p33         OUT      VARCHAR2   -- flsa_prompt
    , p34         OUT      VARCHAR2   -- agency_name_prompt
    , p35         OUT      VARCHAR2   -- payroll_name_prompt
    , p36         OUT      VARCHAR2   -- agent_support_flag_prompt
    , p37         OUT      VARCHAR2   -- employee_type_prompt
    , p38         OUT      VARCHAR2   -- employee_flag_prompt
    , p39         OUT      VARCHAR2   -- assignment_category_1_prompt
    , p40         OUT      VARCHAR2   -- assignment_category_2_prompt
    , p41         OUT      VARCHAR2   -- wah_flag_prompt
    , p42         OUT      VARCHAR2   -- job_title_prompt
    , p43         OUT      VARCHAR2   -- job_code_prompt
    , p44         OUT      VARCHAR2   -- salary_basis_prompt
    , p45         OUT      VARCHAR2   -- tks_type_prompt
    , p46         OUT      VARCHAR2   -- spec1_prompt
    , p47         OUT      VARCHAR2   -- spec2_prompt
    , p48         OUT      VARCHAR2   -- spec3_prompt
    , p49         OUT      VARCHAR2   -- spec4_prompt
    , p50         OUT      VARCHAR2   -- spec5_prompt
    , p51         OUT      VARCHAR2   -- spec6_prompt
    , p52         OUT      VARCHAR2   -- spec7_prompt
    , p53         OUT      VARCHAR2   -- spec8_prompt
    , p54         OUT      VARCHAR2   -- spec9_prompt
    , p55         OUT      VARCHAR2   -- spec10_prompt
    , p56         OUT      VARCHAR2   -- customstring1_prompt
    , p57         OUT      VARCHAR2   -- customstring2_prompt
    , p58         OUT      VARCHAR2   -- customstring3_prompt
    , p59         OUT      VARCHAR2   -- customstring4_prompt
    , p60         OUT      VARCHAR2   -- customstring5_prompt
    , p61         OUT      VARCHAR2   -- customstring6_prompt
    , p62         OUT      VARCHAR2   -- customstring7_prompt
    , p63         OUT      VARCHAR2   -- customstring8_prompt
    , p64         OUT      VARCHAR2   -- customstring9_prompt
    , p65         OUT      VARCHAR2   -- customstring10_prompt
    , p66         OUT      VARCHAR2   -- generic_daprofile_prompt   -- 2.2
    , p67         OUT      VARCHAR2   -- delegate_profile_prompt    -- 2.2
    , p68         OUT      VARCHAR2   -- cascade_profile_prompt     -- 2.2
                                   );

   /* V 1.5 Mexico Payroll Implementation added  GET_MEX_VAC_ELIGIBLE */
   PROCEDURE get_mex_vac_eligible(
      p_calculation_date   IN       DATE
    , p_person_id          IN       NUMBER
    , p_hire_date          IN       DATE
    , p_empl_elig          OUT      NUMBER );
    procedure ttec_Get_MEX_Accrual
(P_Assignment_ID                  IN  Number
,P_Plan_ID                        IN  Number
,P_Payroll_ID                     IN  Number
,P_Business_Group_ID              IN  Number
,P_Assignment_Action_ID           IN  Number default -1
,P_Calculation_Date               IN  Date
,P_Accrual_Start_Date             IN  Date default null
,P_Accrual_Latest_Balance         IN Number default null
,P_Calling_Point                  IN Varchar2 default 'FRM'
,P_Start_Date                     OUT NOCOPY Date
,P_End_Date                       OUT NOCOPY Date
,P_Accrual_End_Date               OUT NOCOPY Date
,P_Accrual                        OUT NOCOPY Number
,P_Net_Entitlement                OUT NOCOPY Number);
END ttec_kr_utils;