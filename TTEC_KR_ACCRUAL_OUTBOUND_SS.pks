create or replace PACKAGE      ttec_kr_accrual_outbound_SS AUTHID CURRENT_USER
AS
   /* $Header: TTEC_KR_ACCRUAL_OUTBOUND_SS.pks 1.0 2009/12/28 mdodge ship $ */

   /*== START ================================================================================================*\
      Author: Michelle Dodge
        Date: 12/28/2009
   Call From:
        Desc: This is the package for the Kronos Accrual Outbound procedures and functions.
              It provides the necessary Oracle data to the Kronos application for
              processing Payroll.

              This package replaces the Accrual portion of the TT_KR_OUTBOUND_INTERFACE
              package and was built referencing elements of the original package.

              This process is intended to be ran by country once per Payroll (versus nightly).

     Modification History:

    Version    Date     Author   Description (Include Ticket#)
    -------  --------  --------  ------------------------------------------------------------------------------
        1.0  12/28/09  MDodge    Kronos Transformations Project - Initial Version.
        1.3  10/2/10   WManasfi  Mexico Payroll Implementation
		1.0  04/may/23 RXNETHI-ARGANO  R12.2 Upgrade Remediation
   \*== END ==================================================================================================*/

   -- Error Constants
   /*
   START R12.2 Upgrade Remediation
   code commented by RXNETHI-ARGANO,04/05/23
   g_application_code            cust.ttec_error_handling.application_code%TYPE
                                                                      := 'HR';
   g_interface                   cust.ttec_error_handling.INTERFACE%TYPE
                                                         := 'Kronos Accruals';
   g_package                     cust.ttec_error_handling.program_name%TYPE
                                                := 'TTEC_KR_ACCRUAL_OUTBOUND';
   g_warning_status              cust.ttec_error_handling.status%TYPE
                                                                 := 'WARNING';
   g_error_status                cust.ttec_error_handling.status%TYPE
                                                                   := 'ERROR';
   g_failure_status              cust.ttec_error_handling.status%TYPE
                                                                 := 'FAILURE';
   */
   --code added by RXNETHI-ARGANO,04/05/23
   g_application_code            apps.ttec_error_handling.application_code%TYPE
                                                                      := 'HR';
   g_interface                   apps.ttec_error_handling.INTERFACE%TYPE
                                                         := 'Kronos Accruals';
   g_package                     apps.ttec_error_handling.program_name%TYPE
                                                := 'TTEC_KR_ACCRUAL_OUTBOUND';
   g_warning_status              apps.ttec_error_handling.status%TYPE
                                                                 := 'WARNING';
   g_error_status                apps.ttec_error_handling.status%TYPE
                                                                   := 'ERROR';
   g_failure_status              apps.ttec_error_handling.status%TYPE
                                                                 := 'FAILURE';

   --END R12.2 Upgrade Remediation
   -- declare cursors
   CURSOR csr_emp_data(
      p_business_group_id   NUMBER
    , p_last_run_date       DATE
    , p_bucket_number       NUMBER
    , p_buckets             NUMBER )
   IS
    SELECT papf.person_id
         , paaf.assignment_id
         , papf.business_group_id parent_bus_group_id
         , ttec_get_bg( papf.business_group_id, paaf.organization_id )
                                                            business_group_id
         , paaf.organization_id
         , paaf.payroll_id
         , paaf.location_id
         , paaf.effective_start_date
         , paaf.effective_end_date
         , paaf.assignment_type
         , papf.employee_number
         , emps.actual_termination_date
         , emps.rehire_date
         , paaf.work_at_home
         , paaf.ass_attribute6 nz_al_balance
         , paaf.ass_attribute7 nz_sick_balance
         , paaf.ass_attribute8 nz_lieu_balance
         , paaf.ass_attribute22 za_sick_balance
         , paaf.ass_attribute21 za_vacation_balance
         , paaf.ass_attribute24 za_family_balance
      FROM (                                            -- List of Active Emps
            SELECT ppos.person_id
                 , actual_termination_date
                 , TRUNC( SYSDATE ) asg_date
                 , NVL( ppos.adjusted_svc_date, ppos.date_start ) rehire_date
              --FROM hr.per_periods_of_service ppos   --code commented by RXNETHI-ARGANO,04/05/23
              FROM apps.per_periods_of_service ppos   --code added by RXNETHI-ARGANO,04/05/23
             WHERE NVL( actual_termination_date, TRUNC( SYSDATE ) + 1 ) >
                                                              TRUNC( SYSDATE )
            UNION
            -- Terms entered since last run including future and past date terms.
            SELECT ket.person_id
                 , new_term_date actual_termination_date
                 , NVL( new_term_date, ppos2.actual_termination_date )
                                                                     asg_date
                 , NVL( ppos2.adjusted_svc_date, ppos2.date_start )
                                                                  rehire_date
              --FROM cust.ttec_kr_emp_terms ket     --code commented by RXNETHI-ARGANO,04/05/23
              FROM apps.ttec_kr_emp_terms ket       --code added by RXNETHI-ARGANO,04/05/23
                 --, hr.per_periods_of_service ppos2     --code commented by RXNETHI-ARGANO,04/05/23
                 , apps.per_periods_of_service ppos2     --code added by RXNETHI-ARGANO,04/05/23
             WHERE ket.creation_date >= p_last_run_date
               AND ket.trigger_source = 'PER_PERIODS_OF_SERVICE'
               -- Select most recent term record for emp, if more than one
               AND ket.creation_date =
                     ( SELECT MAX( creation_date )
                        --FROM cust.ttec_kr_emp_terms ket2     --code commented by RXNETHI-ARGANO,04/05/23
                        FROM apps.ttec_kr_emp_terms ket2       --code added by RXNETHI-ARGANO,04/05/23
                       WHERE person_id = ket.person_id
                         AND trigger_source = 'PER_PERIODS_OF_SERVICE' )
               AND ppos2.period_of_service_id = ket.source_id
               -- Exclude emps already selected in 1st query of union
               AND NOT EXISTS(
                     SELECT 'X'
                       --FROM hr.per_periods_of_service     --code commented by RXNETHI-ARGANO,04/05/23
                       FROM apps.per_periods_of_service     --code added by RXNETHI-ARGANO,04/05/23
                      WHERE person_id = ket.person_id
                        AND TRUNC( SYSDATE ) BETWEEN date_start
                                                 AND NVL
                                                      ( actual_termination_date
                                                      , TRUNC( SYSDATE )
                                                      ) ) ) emps
         --, hr.per_all_assignments_f paaf     --code commented by RXNETHI-ARGANO,04/05/23
         , apps.per_all_assignments_f paaf     --code added by RXNETHI-ARGANO,04/05/23
         --, hr.per_all_people_f papf          --code commented by RXNETHI-ARGANO,04/05/23
         , apps.per_all_people_f papf          --code added by RXNETHI-ARGANO,04/05/23
     WHERE paaf.person_id = emps.person_id
       AND paaf.assignment_type = 'E'
       AND paaf.primary_flag = 'Y'
       AND paaf.business_group_id != 0
       AND emps.asg_date BETWEEN paaf.effective_start_date
                             AND paaf.effective_end_date
       AND papf.person_id = paaf.person_id
       AND emps.asg_date BETWEEN papf.effective_start_date
                             AND papf.effective_end_date
       AND ttec_get_bg( papf.business_group_id, paaf.organization_id ) =
             NVL( p_business_group_id
                , ttec_get_bg( papf.business_group_id, paaf.organization_id )
                )
       AND MOD( papf.employee_number, NVL( p_buckets, 1 ) ) =
                                                     NVL( p_bucket_number, 0 );

   PROCEDURE get_net_accrual(
      p_assignment_id           IN       NUMBER
    , p_business_group_id       IN       NUMBER
    , p_payroll_id              IN       NUMBER
    , p_calculation_date        IN       DATE
    , p_accrual_plan_category   IN       VARCHAR2
    , p_accrual_plan_balance    OUT      NUMBER );

   PROCEDURE main(
      p_business_group_id   IN   VARCHAR2
    , p_bucket_number       IN   NUMBER
    , p_buckets             IN   NUMBER );

   PROCEDURE conc_mgr_wrapper(
      errbuf                OUT      VARCHAR2
    , retcode               OUT      NUMBER
    , p_business_group_id   IN       VARCHAR2
    , p_bucket_number       IN       NUMBER
    , p_buckets             IN       NUMBER );
END ttec_kr_accrual_outbound_SS;
/
show errors;
/