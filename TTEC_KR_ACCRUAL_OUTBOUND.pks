create or replace PACKAGE       ttec_kr_accrual_outbound AUTHID CURRENT_USER AS
  /* $Header: TTEC_KR_ACCRUAL_OUTBOUND.pks 1.9 2020/02/14 Vaitheghi $ */

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

   Version    Date     Author           Description (Include Ticket#)
   -------  --------  --------          ------------------------------------------------------------------------------
       1.0  12/28/09  MDodge            Kronos Transformations Project - Initial Version.
       1.3  10/2/10   WManasfi          Mexico Payroll Implementation
       1.6 06/06/2011 CChan             R#735222 - Need to have a separate accrual process run just for Mexico to pick up employee
                                        with anniversarry date only
       1.7  03/19/19  CChan             Performance Tuning for BG 325, it takes 15 + hours to run in PRODUCTION
       1.8  12/13/19  CChan             Performance Tuning for BG 1715, it takes 18 + hours to run in PRODUCTION
       1.9	02/14/20  Vaitheghi	        Changes for TASK1334715
       2.0  06/21/22  Neelofar          Added condition to exclude AU and NZ Employees
	   2.1  07/07/22  VKollai	        Excluded Employees belongs to Faneuil locations from lookup TTEC_FANEUIL_CL_ID.
	   2.2  08/03/22  VKollai	        Including the M2/P2 employees eventhough belongs to Faneuil locations.
       2.3  10/10/22  Neelofar          Rollback of Cloud Migration project
       2.4  02/15/23  Venkat Kovvuri    Added new condition to include Ex Faneuil employees.
	   1.0  16/MAY/23 RXNETHI-ARGANO    R12.2 Upgrade Remediation
  \*== END ==================================================================================================*/

  -- Error Constants
  /*
  START R12.2 Upgrade Remediation
  code commented by RXNETHI-ARGANO,16/05/23
  g_application_code   cust.ttec_error_handling.application_code%TYPE := 'HR';
  g_interface          cust.ttec_error_handling.INTERFACE%TYPE
                                                         := 'Kronos Accruals';
  g_package            cust.ttec_error_handling.program_name%TYPE
                                                := 'TTEC_KR_ACCRUAL_OUTBOUND';
  g_warning_status     cust.ttec_error_handling.status%TYPE      := 'WARNING';
  g_error_status       cust.ttec_error_handling.status%TYPE        := 'ERROR';
  g_failure_status     cust.ttec_error_handling.status%TYPE      := 'FAILURE';
  */
  --code added by RXNETHI-ARGANO,16/05/23
  g_application_code   apps.ttec_error_handling.application_code%TYPE := 'HR';
  g_interface          apps.ttec_error_handling.INTERFACE%TYPE
                                                         := 'Kronos Accruals';
  g_package            apps.ttec_error_handling.program_name%TYPE
                                                := 'TTEC_KR_ACCRUAL_OUTBOUND';
  g_warning_status     apps.ttec_error_handling.status%TYPE      := 'WARNING';
  g_error_status       apps.ttec_error_handling.status%TYPE        := 'ERROR';
  g_failure_status     apps.ttec_error_handling.status%TYPE      := 'FAILURE';
  --END R12.2 Upgrade Remediation

  -- declare cursors
  CURSOR csr_emp_data(
    p_business_group_id                  NUMBER
  , p_last_run_date                      DATE
  , p_bucket_number                      NUMBER
  , p_buckets                            NUMBER
  , p_mex_anniversary_only               VARCHAR2 /* V 1.6 */
  ) IS
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
         ,  --Added for v1.9
            (SELECT NVL (ppos.adjusted_svc_date, ppos.date_start)
                  FROM per_periods_of_service ppos
                 WHERE person_id = papf.person_id
                   AND ppos.date_start = (SELECT MAX (date_start)
                                            FROM per_periods_of_service ppos
                                           WHERE person_id = papf.person_id))LATEST_START_DATE
            --End for v1.9
      FROM (                                            -- List of Active Emps
            SELECT ppos.person_id
                 , actual_termination_date
                 , TRUNC( SYSDATE ) asg_date
                 , NVL( ppos.adjusted_svc_date, ppos.date_start ) rehire_date
              --FROM hr.per_periods_of_service ppos  --code commented by RXNETHI-ARGANO,16/05/23
              FROM apps.per_periods_of_service ppos  --code added by RXNETHI-ARGANO,16/05/23
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
              /*
			  START R12.2 Upgrade Remediation
			  code commented by RXNETHI-ARGANO,16/05/23
			  FROM cust.ttec_kr_emp_terms ket
                 , hr.per_periods_of_service ppos2
				 */
			  --code added by RXNETHI-ARGANO,16/05/23
			  FROM apps.ttec_kr_emp_terms ket
                 , apps.per_periods_of_service ppos2
              --END R12.2 Upgrade Remediation				 
             WHERE ket.creation_date >= p_last_run_date
               AND ket.trigger_source = 'PER_PERIODS_OF_SERVICE'
               -- Select most recent term record for emp, if more than one
               AND ket.creation_date =
                     ( SELECT MAX( creation_date )
                        --FROM cust.ttec_kr_emp_terms ket2
                        FROM apps.ttec_kr_emp_terms ket2
                       WHERE person_id = ket.person_id
                         AND trigger_source = 'PER_PERIODS_OF_SERVICE' )
               AND ppos2.period_of_service_id = ket.source_id
               -- Exclude emps already selected in 1st query of union
               AND NOT EXISTS(
                     SELECT 'X'
                       --FROM hr.per_periods_of_service
                       FROM apps.per_periods_of_service
                      WHERE person_id = ket.person_id
                        AND TRUNC( SYSDATE ) BETWEEN date_start
                                                 AND NVL
                                                      ( actual_termination_date
                                                      , TRUNC( SYSDATE )
                                                      ) ) ) emps
         /*
		 START R12.2 Upgrade Remediation
		 code commented by RXNETHI-ARGANO,16/05/23
		 , hr.per_all_assignments_f paaf
         , hr.per_all_people_f papf
		 */
		 --code added by RXNETHI-ARGANO,16/05/23
		 , apps.per_all_assignments_f paaf
		 , apps.per_all_people_f papf
		 --END R12.2 Upgrade Remediaiton
     WHERE paaf.person_id = emps.person_id
       AND paaf.assignment_type = 'E'
       AND paaf.primary_flag = 'Y'
       AND emps.asg_date BETWEEN paaf.effective_start_date
                             AND paaf.effective_end_date
       AND papf.person_id = paaf.person_id
       AND emps.asg_date BETWEEN papf.effective_start_date
                             AND papf.effective_end_date
       /* V 1.6 Begin */
       AND 'Y' IN
                 (CASE WHEN p_mex_anniversary_only = 'N' AND MOD( papf.employee_number, NVL( p_buckets, 1 ) ) = NVL( p_bucket_number, 0 ) THEN
                            'Y'
                       WHEN p_mex_anniversary_only = 'Y' AND p_business_group_id = '1633' AND to_char(TRUNC(SYSDATE),'MMDD') <> '0301'
                                                         AND to_char(emps.rehire_date,'MMDD') = to_char(TRUNC(SYSDATE),'MMDD')
                                                         AND to_char(emps.rehire_date,'YYYY') < to_char(TRUNC(SYSDATE),'YYYY') THEN
                            'Y'
                       WHEN p_mex_anniversary_only = 'Y' AND p_business_group_id = '1633' AND to_char(TRUNC(SYSDATE),'MMDD') = '0301'
                                                         AND to_char(emps.rehire_date,'MMDD') in ('0229','0301')
                                                         AND to_char(emps.rehire_date,'YYYY') < to_char(TRUNC(SYSDATE),'YYYY') THEN
                            'Y'
                       ELSE
                            'N'
                  END)  /* V 1.6 End */
       AND ttec_get_bg( papf.business_group_id, paaf.organization_id ) =
             NVL( p_business_group_id
                , ttec_get_bg( papf.business_group_id, paaf.organization_id )
                )
       AND paaf.business_group_id != 0
       AND paaf.business_group_id != 325 /* 1.7 */
       AND paaf.business_group_id != 1517 /* 1.8 */
       /*AND paaf.business_group_id not in (select lookup_code from fnd_lookup_values
													where lookup_type = 'TTEC_EBS_DECOMMISION_COUNTRY'
													and language = 'US') -- Added as part of Cloud Migration--2.0*/--2.3
UNION
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
         ,  --Added for v1.9
            (SELECT NVL (ppos.adjusted_svc_date, ppos.date_start)
                  FROM per_periods_of_service ppos
                 WHERE person_id = papf.person_id
                   AND ppos.date_start = (SELECT MAX (date_start)
                                            FROM per_periods_of_service ppos
                                           WHERE person_id = papf.person_id))LATEST_START_DATE
            --End for v1.9
      FROM (                                            -- List of Active Emps
            SELECT ppos.person_id
                 , actual_termination_date
                 , TRUNC( SYSDATE ) asg_date
                 , NVL( ppos.adjusted_svc_date, ppos.date_start ) rehire_date
              --FROM hr.per_periods_of_service ppos  --code commented by RXNETHI-ARGANO,16/05/23
              FROM apps.per_periods_of_service ppos  --code added by RXNETHI-ARGANO,16/05/23
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
              /*
			  START R12.2 Upgrade Remediation
			  code commented by RXNETHI-ARGANO,16/05/23
			  FROM cust.ttec_kr_emp_terms ket
                 , hr.per_periods_of_service ppos2
			  */
			  --code added by RXNETHI-ARGANO,16/05/23
			  FROM apps.ttec_kr_emp_terms ket
                 , apps.per_periods_of_service ppos2
			  --END R12.2 Upgrade Remediaition
             WHERE ket.creation_date >= p_last_run_date
               AND ket.trigger_source = 'PER_PERIODS_OF_SERVICE'
               -- Select most recent term record for emp, if more than one
               AND ket.creation_date =
                     ( SELECT MAX( creation_date )
                        --FROM cust.ttec_kr_emp_terms ket2  --code commented by RXNETHI-ARGANO,16/05/23
                        FROM apps.ttec_kr_emp_terms ket2    --code added by RXNETHI-ARGANO,16/05/23
                       WHERE person_id = ket.person_id
                         AND trigger_source = 'PER_PERIODS_OF_SERVICE' )
               AND ppos2.period_of_service_id = ket.source_id
               -- Exclude emps already selected in 1st query of union
               AND NOT EXISTS(
                     SELECT 'X'
                       --FROM hr.per_periods_of_service    --code commented by RXNETHI-ARGANO,16/05/23
                       FROM apps.per_periods_of_service    --code added by RXNETHI-ARGANO,16/05/23
                      WHERE person_id = ket.person_id
                        AND TRUNC( SYSDATE ) BETWEEN date_start
                                                 AND NVL
                                                      ( actual_termination_date
                                                      , TRUNC( SYSDATE )
                                                      ) ) ) emps
         /*
		 START R12.2 Upgrade Remediation
		 code commented by RXNETHI-ARGANO,16/05/23
		 , hr.per_all_assignments_f paaf
         , hr.per_all_people_f papf
		 */
		 --code added by RXNETHI-ARGANO,16/05/23
		 , apps.per_all_assignments_f paaf
         , apps.per_all_people_f papf
		 --END R12.2 Upgrade Remediaiton
     WHERE paaf.person_id = emps.person_id
       AND paaf.assignment_type = 'E'
       AND paaf.primary_flag = 'Y'
       AND emps.asg_date BETWEEN paaf.effective_start_date
                             AND paaf.effective_end_date
       AND papf.person_id = paaf.person_id
       AND emps.asg_date BETWEEN papf.effective_start_date
                             AND papf.effective_end_date
       AND paaf.ASSIGNMENT_ID in (select pai.assignment_id
                              --from hr.pay_action_information pai  --code commented by RXNETHI-ARGANO,16/05/23
                              from apps.pay_action_information pai  --code added by RXNETHI-ARGANO,16/05/23
                              where pai.assignment_id = paaf.ASSIGNMENT_ID
                              and pai.effective_date >= TRUNC(SYSDATE) - 90)
       AND paaf.business_group_id in (325,1517)
     /*  and paaf.business_group_id not in (select lookup_code from fnd_lookup_values
													where lookup_type = 'TTEC_EBS_DECOMMISION_COUNTRY'
													and language = 'US') -- Added as part of Cloud Migration--2.0 */--2.3
	   AND paaf.assignment_id NOT IN (SELECT DISTINCT paaf1.assignment_id                   --2.1 Begin
        FROM apps.per_all_assignments_f paaf1,
        apps.fnd_lookup_values     flv,
        apps.ttec_emp_proj_asg   tepa,
        apps.pay_cost_allocations_f pcaf,
        apps.pay_cost_allocation_keyflex pcak
					WHERE   1 = 1
					and pcak.cost_allocation_keyflex_id(+)=pcaf.cost_allocation_keyflex_id
					and pcaf.assignment_id(+)=paaf1.assignment_id
					AND flv.language = 'US'
					and tepa.person_id(+)=paaf1.person_id
                    and trunc(sysdate) between tepa.prj_strt_dt (+) and tepa.prj_end_dt (+) -- Added for 2.4
					and paaf1.assignment_type='E'
					and paaf1.primary_flag='Y'
					AND flv.lookup_type = 'TTEC_FANEUIL_CL_ID'
					AND flv.lookup_code in(  tepa.prj_cd , pcak.segment2)
					and paaf1.business_group_id='325'
					AND trunc(sysdate) BETWEEN paaf1.effective_start_date AND paaf1.effective_end_date
					AND trunc(sysdate) BETWEEN pcaf.effective_start_date AND pcaf.effective_end_date
					AND paaf1.assignment_id =  paaf.assignment_id
					AND NOT EXISTS                                                                         --2.2 Begin
								( select 1 from APPS.PER_JOBS PJ, APPS.fnd_lookup_values flv1
										where 1=1
										AND flv1.language = 'US'
										AND flv1.lookup_type = 'TTEC_P2M2_ABOVE_JOB_CODE'
										AND pj.job_id = PAAF.job_id
										AND pj.attribute20 = flv1.lookup_code
								)                                                                          --2.2 End
		and rownum=1    )                                                    							   --2.1 End
       AND ttec_get_bg( papf.business_group_id, paaf.organization_id ) =
             NVL( p_business_group_id
                , ttec_get_bg( papf.business_group_id, paaf.organization_id )
                )
                ;


  PROCEDURE get_net_accrual(
    p_assignment_id             IN       NUMBER
  , p_business_group_id         IN       NUMBER
  , p_payroll_id                IN       NUMBER
  , p_calculation_date          IN       DATE
  , p_accrual_plan_category     IN       VARCHAR2
  , p_accrual_plan_balance      OUT      NUMBER
  );

  PROCEDURE main(
    p_business_group_id         IN       VARCHAR2
  , p_bucket_number             IN       NUMBER
  , p_buckets                   IN       NUMBER
  , p_mex_anniversary_only      IN       VARCHAR2 -- V 1.6
  );

  PROCEDURE conc_mgr_wrapper(
    errbuf                      OUT      VARCHAR2
  , retcode                     OUT      NUMBER
  , p_business_group_id         IN       VARCHAR2
  , p_bucket_number             IN       NUMBER
  , p_buckets                   IN       NUMBER
  , p_mex_anniversary_only      IN       VARCHAR2 -- V 1.6
  );
END ttec_kr_accrual_outbound;
/
show errors;
/