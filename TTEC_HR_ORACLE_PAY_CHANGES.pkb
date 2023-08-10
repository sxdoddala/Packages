create or replace PACKAGE BODY ttec_hr_oracle_pay_changes
IS
   /************************************************************************************
    *                                                                                  *
    *     Program Name: TTEC_HR_ORACLE_PAY_CHANGES                                     *
    *                                                                                  *
    *     Description:  This package generates the HR - Oracle Pay Changes report as   *
    *                   an output file of the concurrent program.                      *
    *                   This report pulls all Salary change transactions from MSS and  *
    *                   Core Forms wihin a time period, and for a Business Group or    *
    *                   Employee entered as parameter. If no Business Group or         *
    *                   Employee are entered, the report runs globally.                *
    *                                                                                  *
    *     Input/Output Parameters:                                                     *
    *                                                                                  *
    *     Tables Accessed:   hr.per_all_people_f                                       *
    *                        hr.per_all_assignments_f                                  *
    *                        hr.hr_locations_all                                       *
    *                        hr.per_jobs                                               *
    *                        hr.per_pay_proposals                                      *
    *                        hr.per_pay_bases                                          *
    *                        hr.hr_organization_information                            *
    *                        apps.fnd_territories_tl                                   *
    *                        apps.fnd_user                                             *
    *                        apps.fnd_currencies_vl                                    *
    *                        apps.hr_lookups                                           *
    *                        apps.pqh_ss_transaction_history                           *
    *                        apps.pqh_ss_step_history                                  *
    *                        apps.pqh_ss_value_history                                 *
    *                        apps.pqh_ss_approval_history                              *
    *                        cust.ttec_wf_items                                        *
    *                        cust.ttec_wf_item_att_values                              *
    *                        cust.ttec_wf_notifications                                *
    *                                                                                  *
    *     Tables Modified:   N/A                                                       *
    *     Procedures Called: None                                                      *
    *     Created by:        GECASARETTO                                               *
    *     Date:              Fabreuary 9, 2010                                         *
    *                                                                                  *
    *     Modification Log:                                                            *
    *     Developer      Date       Version  Description                               *
    *     -------------  ---------  -------  ---------------------------------------   *
    *     GECASARETTO    09-FEB-10  1.0      Creation                                	*
    *     RXNETHI-ARGANO 17-MAY-23  1.0      R12.2 Upgrade Remediation                 *
	************************************************************************************/

   /***********************************************************************************
    *      PROCEDURE main                                                              *
    *      Description: This is the main procedure to be called directly from the      *
    *                   Concurrent Manager.                                            *
    *                   It will generate the HR - Oracle Pay Changes report as an      *
    *                   output file of the concurrent program.                         *
    *                                                                                  *
    *      Input/Output Parameters:                                                    *
    *                              IN: p_start_date        - data retrieval constraint *
    *                                  p_end_date          - data retrieval constraint *
    *                                  p_business_group_id - data retrieval constraint *
    *                                  p_employee_number   - data retrieval constraint *
    *                                                                                  *
    ************************************************************************************/

   /********************************************************************************
   * NAME: f_get_notification_employee_number                                      *
   * PURPOSE: Given a workflow notification id returns the employee number of the  *
   *          submitter user.                                                      *
   *                                                                               *
   ********************************************************************************/
   FUNCTION f_get_notification_ee_num (p_notification_id IN NUMBER)
      RETURN VARCHAR2
   IS
      v_emp_num   VARCHAR2 (2000) := NULL;
   BEGIN
      SELECT   papf.employee_number
      INTO     v_emp_num
      --FROM     cust.ttec_wf_notifications wfn  --code commented by RXNETHI-ARGANO,17/05/23
      FROM     apps.ttec_wf_notifications wfn    --code added by RXNETHI-ARGANO,17/05/23
             , apps.fnd_user fu
             --, hr.per_all_people_f papf  --code commented by RXNETHI-ARGANO,17/05/23
             , apps.per_all_people_f papf  --code added by RXNETHI-ARGANO,17/05/23
      WHERE    wfn.notification_id = p_notification_id
           AND fu.user_name = wfn.recipient_role
           AND papf.person_id = fu.employee_id
           AND TRUNC (SYSDATE) BETWEEN papf.effective_start_date
                                   AND  papf.effective_end_date;

      RETURN v_emp_num;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN NULL;
   END f_get_notification_ee_num;

   /********************************************************************************
   * NAME: f_get_notification_employee_name                                        *
   * PURPOSE: Given a workflow notification id returns the employee name of the    *
   *          submitter user.                                                      *
   *                                                                               *
   ********************************************************************************/
   FUNCTION f_get_notification_ee_name (p_notification_id IN NUMBER)
      RETURN VARCHAR2
   IS
      v_emp_name   VARCHAR2 (2000) := NULL;
   BEGIN
      SELECT   papf.full_name
      INTO     v_emp_name
      --FROM     cust.ttec_wf_notifications wfn  --code commented by RXNETHI-ARGANO,17/05/23
      FROM     apps.ttec_wf_notifications wfn    --code added by RXNETHI-ARGANO,17/05/23
             , apps.fnd_user fu
             --, hr.per_all_people_f papf  --code commented by RXNETHI-ARGANO,17/05/23
             , apps.per_all_people_f papf  --code added by RXNETHI-ARGANO,17/05/23
      WHERE    wfn.notification_id = p_notification_id
           AND fu.user_name = wfn.recipient_role
           AND papf.person_id = fu.employee_id
           AND TRUNC (SYSDATE) BETWEEN papf.effective_start_date
                                   AND  papf.effective_end_date;

      RETURN v_emp_name;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN NULL;
   END f_get_notification_ee_name;

   PROCEDURE main (errcode                  VARCHAR2
                 , errbuff                  VARCHAR2
                 , p_start_date          IN VARCHAR2
                 , p_end_date            IN VARCHAR2
                 , p_business_group_id   IN NUMBER
                 , p_employee_number     IN VARCHAR2)
   IS
      /** Declare local variables **/
      l_rec                VARCHAR2 (10000) := NULL;
      l_header             VARCHAR2 (1000) := NULL;
      l_error_step         VARCHAR2 (1000);
      l_start_date         DATE;
      l_end_date           DATE;
      l_msg                VARCHAR2 (2000);
      l_type               VARCHAR2 (2000);
      l_perc_inc           NUMBER;
      l_transaction_flag   VARCHAR2 (2000);
      l_sub_ee_num         VARCHAR2 (2000);
      l_sub_full_name      VARCHAR2 (2000);
      l_app_ee_num         VARCHAR2 (2000);
      l_app_full_name      VARCHAR2 (2000);

      /** Declare EXCEPTIONS **/
      wrong_dates exception;

      /** Declare Cursors **/

      /** Salary Changes from Core Forms between time period that do not exist in MSS for the same assignment and date **/
      CURSOR c_core_forms_changes (
         l_start_date        IN            DATE
       , l_end_date          IN            DATE
       , c_business_group    IN            NUMBER
       , c_employee_number   IN            VARCHAR2
      )
      IS
         SELECT     DISTINCT
                    ft.territory_short_name country
                  , papf.employee_number ee_num
                  , papf.full_name full_name
                  , pj_ant.name prev_job
                  , pj.name cur_job
                  , ppp_prev.change_date prev_salary_date
                  , ppp.change_date cur_salary_date
                  , ppb_prev.pay_basis prev_salary_basis
                  , ppb.pay_basis cur_salary_basis
                  , TRUNC (ppp_prev.proposed_salary_n, 2) prev_salary
                  , ppb_prev.pay_annualization_factor prev_annual_factor
                  , TRUNC (ppp.proposed_salary_n, 2) cur_salary
                  , ppb.pay_annualization_factor cur_annual_factor
                  , hl_sal.meaning proposal_reason
                  , loc.location_code hr_location
                  , pj.attribute5 job_family
                  , pbg.currency_code currency_code
                  , fcv.description currency_desc
         /*
		 START R12.2 Upgrade Remediation
		 code commented by RXNETHI-ARGANO,17/05/23
		 FROM       hr.per_all_people_f papf
                  , hr.per_all_assignments_f paaf_ant
                  , hr.per_all_assignments_f paaf_basis_prev
                  , hr.per_all_assignments_f paaf
                  , hr.hr_locations_all loc
                  , hr.per_jobs pj
                  , hr.per_jobs pj_ant
                  , hr.per_pay_proposals ppp
                  , hr.per_pay_proposals ppp_prev
                  , hr.per_pay_bases ppb
                  , hr.per_pay_bases ppb_prev
		 */
		 --code adde dby RXNETHI-ARGANO,17/05/23
		 FROM       apps.per_all_people_f papf
                  , apps.per_all_assignments_f paaf_ant
                  , apps.per_all_assignments_f paaf_basis_prev
                  , apps.per_all_assignments_f paaf
                  , apps.hr_locations_all loc
                  , apps.per_jobs pj
                  , apps.per_jobs pj_ant
                  , apps.per_pay_proposals ppp
                  , apps.per_pay_proposals ppp_prev
                  , apps.per_pay_bases ppb
                  , apps.per_pay_bases ppb_prev
		 --END R12.2 Upgrade Remediation
                  , apps.fnd_territories_tl ft
                  , apps.per_business_groups pbg
                  , apps.fnd_currencies_vl fcv
                  , apps.hr_lookups hl_sal
         WHERE      ppp.business_group_id =
                       NVL (c_business_group, ppp.business_group_id)
                AND ppp.change_date BETWEEN l_start_date AND l_end_date
                AND ppp.approved = 'Y'
                AND paaf.assignment_id = ppp.assignment_id
                AND ppp.change_date BETWEEN paaf.effective_start_date
                                        AND  paaf.effective_end_date
                AND paaf.assignment_type = 'E'
                AND paaf.primary_flag = 'Y'
                AND papf.person_id = paaf.person_id
                AND ppp.change_date BETWEEN papf.effective_start_date
                                        AND  papf.effective_end_date
                AND papf.employee_number =
                       NVL (c_employee_number, papf.employee_number)
                AND loc.location_id(+) = paaf.location_id
                AND ft.territory_code(+) = loc.country
                AND ft.language(+) = USERENV ('LANG')
                AND pj.job_id(+) = paaf.job_id
                AND ppb.pay_basis_id(+) = paaf.pay_basis_id
                AND papf.business_group_id = pbg.business_group_id
                AND fcv.currency_code(+) = pbg.currency_code
                AND hl_sal.lookup_code(+) = ppp.proposal_reason
                AND hl_sal.lookup_type(+) = 'PROPOSAL_REASON'
                AND paaf_ant.person_id = paaf.person_id
                AND paaf_ant.period_of_service_id = paaf.period_of_service_id
                AND (ppp.change_date - 1) BETWEEN paaf_ant.effective_start_date
                                              AND  paaf_ant.effective_end_date
                AND paaf_ant.assignment_type = 'E'
                AND paaf_ant.primary_flag = 'Y'
                AND pj_ant.job_id(+) = paaf_ant.job_id
                AND ppb_prev.pay_basis_id(+) = paaf_basis_prev.pay_basis_id
                AND ppp_prev.assignment_id = ppp.assignment_id
                AND ppp_prev.approved = 'Y'
                AND ppp_prev.change_date =
                       (SELECT   MAX (ppp_prev_sub.change_date)
                        --FROM     hr.per_pay_proposals ppp_prev_sub  --code commented by RXNETHI-ARGANO,17/05/23
                        FROM     apps.per_pay_proposals ppp_prev_sub  --code added by RXNETHI-ARGANO,17/05/23
                        WHERE    ppp_prev_sub.assignment_id =
                                    ppp_prev.assignment_id
                             AND ppp_prev_sub.change_date < ppp.change_date
                             AND ppp_prev_sub.approved = 'Y')
                AND ppp_prev.assignment_id = paaf_basis_prev.assignment_id(+)
                AND ppp_prev.change_date BETWEEN paaf_basis_prev.effective_start_date(+)
                                             AND  paaf_basis_prev.effective_end_date(+)
                AND NOT EXISTS
                       /* This select filters salary changes that came from MSS; the Employee shouldn't have the same change via MSS and Core Forms */
                    (SELECT   1
                     FROM     apps.pqh_ss_transaction_history tranhist
                            , apps.pqh_ss_step_history stephist
                            , apps.pqh_ss_value_history valhist
                            /*
							START R12.2 Upgrade Remediation
							code commented by RXNETHI-ARGANO,17/05/23
							, cust.ttec_wf_items wfi
                            , cust.ttec_wf_item_att_values wfiv
							*/
							--code added by RXNETHI-ARGANO,17/05/23
							, apps.ttec_wf_items wfi
                            , apps.ttec_wf_item_att_values wfiv
							--END R12.2 Upgrade Remediation
                     WHERE    tranhist.assignment_id = paaf.assignment_id
                          AND tranhist.transaction_history_id =
                                 stephist.transaction_history_id
                          AND stephist.step_history_id =
                                 valhist.step_history_id
                          AND valhist.name = 'P_PROPOSED_SALARY'
                          AND wfi.item_key = tranhist.item_key
                          AND wfi.item_type = 'HRSSA'
                          AND wfi.end_date IS NOT NULL
                          AND wfiv.item_key = tranhist.item_key
                          AND wfiv.name = 'P_EFFECTIVE_DATE'
                          AND ppp.change_date =
                                 TO_DATE (wfiv.text_value
                                        , 'YYYY/MM/DD HH24:MI:SS')
                          AND NOT EXISTS
                                 (SELECT   1
                                  --FROM     cust.ttec_wf_item_att_values wfiv_sub  --code commented by RXNETHI-ARGANO,17/05/23
                                  FROM     apps.ttec_wf_item_att_values wfiv_sub    --code added by RXNETHI-ARGANO,17/05/23
                                  WHERE    wfiv.item_key = wfiv_sub.item_key
                                       AND wfiv_sub.name = 'RESULT'
                                       AND (wfiv_sub.text_value = 'REJECTED'))
                          AND EXISTS
                                 (SELECT   1
                                  --FROM     cust.ttec_wf_item_att_values wfiv_sub  --code commented by RXNETHI-ARGANO,17/05/23
                                  FROM     apps.ttec_wf_item_att_values wfiv_sub    --code added by RXNETHI-ARGANO,17/05/23
                                  WHERE    wfiv.item_key = wfiv_sub.item_key
                                       AND wfiv_sub.name = 'RESULT'
                                       AND wfiv_sub.text_value = 'APPROVED'))
         ORDER BY   ft.territory_short_name, papf.employee_number;

      /** Salary Changes from MSS between time period **/
      CURSOR c_mss_changes (
         l_start_date        IN            DATE
       , l_end_date          IN            DATE
       , c_business_group    IN            NUMBER
       , c_employee_number   IN            VARCHAR2
      )
      IS
         SELECT     DISTINCT
                    ft.territory_short_name country
                  , papf.employee_number ee_num
                  , papf.full_name full_name
                  , pj_ant.name prev_job
                  , pj.name cur_job
                  , ppp_prev.change_date prev_salary_date
                  , ppp.change_date cur_salary_date
                  , ppb_prev.pay_basis prev_salary_basis
                  , ppb.pay_basis cur_salary_basis
                  , TRUNC (ppp_prev.proposed_salary_n, 2) prev_salary
                  , ppb_prev.pay_annualization_factor prev_annual_factor
                  , TRUNC (ppp.proposed_salary_n, 2) cur_salary
                  , ppb.pay_annualization_factor cur_annual_factor
                  , hl_sal.meaning proposal_reason
                  , loc.location_code hr_location
                  , pj.attribute5 job_family
                  , pbg.currency_code currency_code
                  , fcv.description currency_desc
                  , psah_sub.user_name sub_user_name
                  , papf_sub.employee_number sub_ee_num
                  , papf_sub.full_name sub_full_name
                  , psah.user_name app_user_name
                  , papf_user.employee_number app_ee_num
                  , papf_user.full_name app_full_name
                  , psah.action status
                  , psah.notification_id notification_id
         /*
		 START R12.2 Upgrade Remediation
		 code commented by RXNETHI-ARGANO,17/05/23
		 FROM       hr.per_all_people_f papf
                  , hr.per_all_people_f papf_user
                  , hr.per_all_people_f papf_sub
                  , hr.per_all_assignments_f paaf
                  , apps.pqh_ss_transaction_history tranhist
                  , apps.pqh_ss_step_history stephist
                  , apps.pqh_ss_approval_history psah
                  , apps.pqh_ss_approval_history psah_sub
                  , apps.pqh_ss_value_history valhist
                  , cust.ttec_wf_items wfi
                  , cust.ttec_wf_item_att_values wfiv
                  , hr.hr_locations_all loc
                  , hr.per_jobs pj
                  , hr.per_jobs pj_ant
                  , apps.fnd_user fu
                  , apps.fnd_user fu_sub
                  , hr.per_pay_proposals ppp
                  , hr.per_all_assignments_f paaf_ant
                  , hr.per_all_assignments_f paaf_basis_prev
                  , hr.per_pay_proposals ppp_prev
                  , hr.per_pay_bases ppb
                  , hr.per_pay_bases ppb_prev
		 */
		 --code added by RXNETHI-ARGANO,17/05/23
		 FROM       apps.per_all_people_f papf
                  , apps.per_all_people_f papf_user
                  , apps.per_all_people_f papf_sub
                  , apps.per_all_assignments_f paaf
                  , apps.pqh_ss_transaction_history tranhist
                  , apps.pqh_ss_step_history stephist
                  , apps.pqh_ss_approval_history psah
                  , apps.pqh_ss_approval_history psah_sub
                  , apps.pqh_ss_value_history valhist
                  , apps.ttec_wf_items wfi
                  , apps.ttec_wf_item_att_values wfiv
                  , apps.hr_locations_all loc
                  , apps.per_jobs pj
                  , apps.per_jobs pj_ant
                  , apps.fnd_user fu
                  , apps.fnd_user fu_sub
                  , apps.per_pay_proposals ppp
                  , apps.per_all_assignments_f paaf_ant
                  , apps.per_all_assignments_f paaf_basis_prev
                  , apps.per_pay_proposals ppp_prev
                  , apps.per_pay_bases ppb
                  , apps.per_pay_bases ppb_prev
		 --END R12.2 Upgrade Remediation
                  , apps.fnd_territories_tl ft
                  , apps.per_business_groups pbg
                  , apps.fnd_currencies_vl fcv
                  , apps.hr_lookups hl_sal
         WHERE      papf.business_group_id =
                       NVL (c_business_group, papf.business_group_id)
                AND ppp.change_date BETWEEN papf.effective_start_date
                                        AND  papf.effective_end_date
                AND papf.employee_number =
                       NVL (c_employee_number, papf.employee_number)
                AND papf.person_id = paaf.person_id
                AND tranhist.assignment_id = paaf.assignment_id
                AND ppp.change_date BETWEEN TRUNC (paaf.effective_start_date)
                                        AND  TRUNC (paaf.effective_end_date)
                AND paaf.assignment_type = 'E'
                AND paaf.primary_flag = 'Y'
                AND tranhist.transaction_history_id =
                       stephist.transaction_history_id
                AND valhist.step_history_id = stephist.step_history_id
                AND valhist.name = 'P_PROPOSED_SALARY'
                AND wfi.item_key = tranhist.item_key
                AND wfi.item_type = 'HRSSA'
                AND wfi.end_date IS NOT NULL
                AND wfiv.item_key = tranhist.item_key
                AND wfiv.name = 'P_EFFECTIVE_DATE'
                AND ppp.change_date =
                       TO_DATE (wfiv.text_value, 'YYYY/MM/DD HH24:MI:SS')
                AND ppp.change_date BETWEEN l_start_date AND l_end_date
                AND NOT EXISTS (SELECT   1
                                --FROM     cust.ttec_wf_item_att_values wfiv_sub  --code commented by RXNETHI-ARGANO,17/05/23
                                FROM     apps.ttec_wf_item_att_values wfiv_sub    --code added by RXNETHI-ARGANO,17/05/23
                                WHERE    wfiv.item_key = wfiv_sub.item_key
                                     AND wfiv_sub.name = 'RESULT'
                                     AND (wfiv_sub.text_value = 'REJECTED'))
                AND EXISTS (SELECT   1
                            --FROM     cust.ttec_wf_item_att_values wfiv_sub  --code commented by RXNETHI-ARGANO,17/05/23
                            FROM     apps.ttec_wf_item_att_values wfiv_sub    --code added by RXNETHI-ARGANO,17/05/23
                            WHERE    wfiv.item_key = wfiv_sub.item_key
                                 AND wfiv_sub.name = 'RESULT'
                                 AND wfiv_sub.text_value = 'APPROVED')
                AND stephist.transaction_history_id =
                       psah.transaction_history_id
                AND psah.action <> 'SUBMIT'
                AND stephist.transaction_history_id =
                       psah_sub.transaction_history_id
                AND psah_sub.action = 'SUBMIT'
                AND paaf.location_id = loc.location_id(+)
                AND paaf.job_id = pj.job_id(+)
                AND fu.user_name(+) = psah.user_name
                AND fu.employee_id = papf_user.person_id(+)
                AND TRUNC (SYSDATE) BETWEEN papf_user.effective_start_date(+)
                                        AND  papf_user.effective_end_date(+)
                AND fu_sub.user_name(+) = psah_sub.user_name
                AND fu_sub.employee_id = papf_sub.person_id(+)
                AND TRUNC (SYSDATE) BETWEEN papf_sub.effective_start_date(+)
                                        AND  papf_sub.effective_end_date(+)
                AND paaf.assignment_id = ppp.assignment_id
                AND paaf_ant.person_id = paaf.person_id
                AND paaf_ant.period_of_service_id = paaf.period_of_service_id
                AND (ppp.change_date - 1) BETWEEN paaf_ant.effective_start_date
                                              AND  paaf_ant.effective_end_date
                AND paaf_ant.assignment_type = 'E'
                AND paaf_ant.primary_flag = 'Y'
                AND paaf.job_id = pj.job_id(+)
                AND paaf_ant.job_id = pj_ant.job_id(+)
                AND paaf.pay_basis_id = ppb.pay_basis_id(+)
                AND ppp.assignment_id = ppp_prev.assignment_id
                AND ppp_prev.change_date =
                       (SELECT   MAX (ppp_prev_sub.change_date)
                        --FROM     hr.per_pay_proposals ppp_prev_sub  --code commented by RXNETHI-ARGANO,17/05/23
                        FROM     apps.per_pay_proposals ppp_prev_sub  --code added by RXNETHI-ARGANO,17/05/23
                        WHERE    ppp_prev_sub.assignment_id =
                                    ppp_prev.assignment_id
                             AND ppp_prev_sub.change_date < ppp.change_date
                             AND ppp_prev_sub.approved = 'Y')
                AND ppp_prev.assignment_id = paaf_basis_prev.assignment_id(+)
                AND ppp_prev.change_date BETWEEN paaf_basis_prev.effective_start_date(+)
                                             AND  paaf_basis_prev.effective_end_date(+)
                AND paaf_basis_prev.pay_basis_id = ppb_prev.pay_basis_id(+)
                AND ft.territory_code(+) = loc.country
                AND ft.language(+) = USERENV ('LANG')
                AND papf.business_group_id = pbg.business_group_id
                AND fcv.currency_code(+) = pbg.currency_code
                AND ppp.approved = 'Y'
                AND ppp_prev.approved = 'Y'
                AND ppp.proposal_reason = hl_sal.lookup_code(+)
                AND hl_sal.lookup_type(+) = 'PROPOSAL_REASON'
         ORDER BY   ft.territory_short_name, papf.employee_number;
   BEGIN
      /** Formatting Dates **/
      IF p_start_date IS NOT NULL
      THEN
         l_start_date   := TO_DATE (p_start_date, 'YYYY/MM/DD HH24:MI:SS');
      END IF;

      IF p_end_date IS NOT NULL
      THEN
         l_end_date   := TO_DATE (p_end_date, 'YYYY/MM/DD HH24:MI:SS');
      END IF;

      /** Check for wrong dates **/
      IF l_start_date > l_end_date
      THEN
         RAISE wrong_dates;
      END IF;

      l_error_step         := 'Step 1: Create header';

      /** Log header **/
      apps.fnd_file.put_line (
         1
       ,    'HR Report Name: Oracle Pay Changes - Dates '
         || TO_CHAR (l_start_date, 'DD-MON-YY')
         || ' and '
         || TO_CHAR (l_end_date, 'DD-MON-YY')
      );
      apps.fnd_file.put_line (1, '');

      /** Create file header **/
      l_header             :=
            'TeleTech HR - Oracle Pay Changes'
         || ' - '
         || 'From '
         || l_start_date
         || ' to '
         || l_end_date;
      fnd_file.put_line (2, l_header);
      apps.fnd_file.put_line (2, '');

      /** Create header for the output **/

      l_header             :=
            'Type'
         || '|'
         || 'Country'
         || '|'
         || 'EE'
         || '|'
         || 'Full Name'
         || '|'
         || 'Previous Job Code/Title'
         || '|'
         || 'Current Job Code/Title'
         || '|'
         || 'Previous Salary Effective Date'
         || '|'
         || 'Current Salary Effective Date'
         || '|'
         || 'Previous Salary Basis'
         || '|'
         || 'Current Salary Basis'
         || '|'
         || 'Previous Salary (Local)'
         || '|'
         || 'Current Salary (Local)'
         || '|'
         || '% of Increase'
         || '|'
         || 'Pay Proposal Reason'
         || '|'
         || 'HR Location'
         || '|'
         || 'Job Family'
         || '|'
         || 'Currency Code'
         || '|'
         || 'Currency Description'
         || '|'
         || 'MSS Transaction Flag'
         || '|'
         || 'Submitter EE#'
         || '|'
         || 'Submitter Full Name'
         || '|'
         || 'Approver EE#'
         || '|'
         || 'Approver Full Name'
         || '|'
         || 'Status'
         || '|'
         || 'Date From'
         || '|'
         || 'Date To';

      apps.fnd_file.put_line (2, l_header);
      apps.fnd_file.put_line (2, '');

      l_error_step         := 'Step 2: End create header, entering Loop';

      /** Loop Core Forms Records **/

      l_transaction_flag   := 'Manual';

      FOR rec_core IN c_core_forms_changes (l_start_date
                                          , l_end_date
                                          , p_business_group_id
                                          , p_employee_number)
      LOOP
         l_error_step   := 'Step 3: Inside Core Forms Loop';

         IF rec_core.prev_job <> rec_core.cur_job
         THEN
            l_type   := 'Job and Salary Change';
         ELSE
            l_type   := 'Salary Change';
         END IF;

         /** Get salary increase percentage. If either current or previous salary or
             annualization factor equals 0 or is NULL, then it defaults to 0 **/
         IF NVL (rec_core.cur_salary, 0) = 0
         OR NVL (rec_core.cur_annual_factor, 0) = 0
         OR NVL (rec_core.prev_salary, 0) = 0
         OR NVL (rec_core.prev_annual_factor, 0) = 0
         THEN
            l_perc_inc   := 0;
         ELSE
            l_perc_inc   :=
               ROUND (
                  (  (rec_core.cur_salary * rec_core.cur_annual_factor)
                   / (rec_core.prev_salary * rec_core.prev_annual_factor)
                   * 100)
                  - 100
                , 2
               );
         END IF;

         l_rec          :=
               l_type
            || '|'
            || rec_core.country
            || '|'
            || rec_core.ee_num
            || '|'
            || rec_core.full_name
            || '|'
            || rec_core.prev_job
            || '|'
            || rec_core.cur_job
            || '|'
            || rec_core.prev_salary_date
            || '|'
            || rec_core.cur_salary_date
            || '|'
            || rec_core.prev_salary_basis
            || '|'
            || rec_core.cur_salary_basis
            || '|'
            || rec_core.prev_salary
            || '|'
            || rec_core.cur_salary
            || '|'
            || l_perc_inc
            || '|'
            || rec_core.proposal_reason
            || '|'
            || rec_core.hr_location
            || '|'
            || rec_core.job_family
            || '|'
            || rec_core.currency_code
            || '|'
            || rec_core.currency_desc
            || '|'
            || l_transaction_flag
            || '|'
            || NULL
            || '|'
            || NULL
            || '|'
            || NULL
            || '|'
            || NULL
            || '|'
            || NULL
            || '|'
            || TO_CHAR (l_start_date, 'DD-MON-YY')
            || '|'
            || TO_CHAR (l_end_date, 'DD-MON-YY');

         apps.fnd_file.put_line (2, l_rec);
      END LOOP;

      /** Loop MSS Records **/

      l_transaction_flag   := 'MSS';

      FOR rec_mss IN c_mss_changes (l_start_date
                                  , l_end_date
                                  , p_business_group_id
                                  , p_employee_number)
      LOOP
         l_error_step   := 'Step 4: Inside MSS Loop';

         IF rec_mss.prev_job <> rec_mss.cur_job
         THEN
            l_type   := 'Job and Salary Change';
         ELSE
            l_type   := 'Salary Change';
         END IF;

         /** Get salary increase percentage. If either current or previous salary or
            annualization factor equals 0 or is NULL, then it defaults to 0 **/
         IF NVL (rec_mss.cur_salary, 0) = 0
         OR NVL (rec_mss.cur_annual_factor, 0) = 0
         OR NVL (rec_mss.prev_salary, 0) = 0
         OR NVL (rec_mss.prev_annual_factor, 0) = 0
         THEN
            l_perc_inc   := 0;
         ELSE
            l_perc_inc   :=
               ROUND (
                  (  (rec_mss.cur_salary * rec_mss.cur_annual_factor)
                   / (rec_mss.prev_salary * rec_mss.prev_annual_factor)
                   * 100)
                  - 100
                , 2
               );
         END IF;

         /** Get Submitter and Approver Employee Numbers and Full Names **/
         IF rec_mss.sub_user_name NOT LIKE 'email%'
         THEN
            l_sub_ee_num   := rec_mss.sub_ee_num;
         ELSE
            l_sub_ee_num   :=
               NVL (f_get_notification_ee_num (rec_mss.notification_id)
                  , rec_mss.sub_user_name);
         END IF;

         IF rec_mss.sub_user_name NOT LIKE 'email%'
         THEN
            l_sub_full_name   := rec_mss.sub_full_name;
         ELSE
            l_sub_full_name   :=
               NVL (f_get_notification_ee_num (rec_mss.notification_id)
                  , rec_mss.sub_user_name);
         END IF;

         IF rec_mss.app_user_name NOT LIKE 'email%'
         THEN
            l_app_ee_num   := rec_mss.app_ee_num;
         ELSE
            l_app_ee_num   :=
               NVL (f_get_notification_ee_num (rec_mss.notification_id)
                  , rec_mss.app_user_name);
         END IF;

         IF rec_mss.app_user_name NOT LIKE 'email%'
         THEN
            l_app_full_name   := rec_mss.app_full_name;
         ELSE
            l_app_full_name   :=
               NVL (f_get_notification_ee_num (rec_mss.notification_id)
                  , rec_mss.app_user_name);
         END IF;

         l_rec          :=
               l_type
            || '|'
            || rec_mss.country
            || '|'
            || rec_mss.ee_num
            || '|'
            || rec_mss.full_name
            || '|'
            || rec_mss.prev_job
            || '|'
            || rec_mss.cur_job
            || '|'
            || rec_mss.prev_salary_date
            || '|'
            || rec_mss.cur_salary_date
            || '|'
            || rec_mss.prev_salary_basis
            || '|'
            || rec_mss.cur_salary_basis
            || '|'
            || rec_mss.prev_salary
            || '|'
            || rec_mss.cur_salary
            || '|'
            || l_perc_inc
            || '|'
            || rec_mss.proposal_reason
            || '|'
            || rec_mss.hr_location
            || '|'
            || rec_mss.job_family
            || '|'
            || rec_mss.currency_code
            || '|'
            || rec_mss.currency_desc
            || '|'
            || l_transaction_flag
            || '|'
            || l_sub_ee_num
            || '|'
            || l_sub_full_name
            || '|'
            || l_app_ee_num
            || '|'
            || l_app_full_name
            || '|'
            || rec_mss.status
            || '|'
            || TO_CHAR (l_start_date, 'DD-MON-YY')
            || '|'
            || TO_CHAR (l_end_date, 'DD-MON-YY');

         apps.fnd_file.put_line (2, l_rec);
      END LOOP;
   EXCEPTION
      WHEN wrong_dates
      THEN
         apps.fnd_file.put_line (1, ' ');
         apps.fnd_file.put_line (1, 'TeleTech HR - Oracle Pay Changes');
         apps.fnd_file.put_line (1, ' ');
         apps.fnd_file.put_line (
            1
          , 'Start Date is subsequent to End Date, please correct this and re-run.'
         );
         apps.fnd_file.put_line (1, '');
         apps.fnd_file.put_line (2, ' ');
         apps.fnd_file.put_line (2
                               , 'TeleTech HR - Oracle Pay Changes Report');
         apps.fnd_file.put_line (2, ' ');
         apps.fnd_file.put_line (
            2
          , 'Start Date is subsequent to End Date, please correct this and re-run.'
         );
         apps.fnd_file.put_line (2, '');
      WHEN OTHERS
      THEN
         DBMS_OUTPUT.put_line ('Operation fails on ' || l_error_step);
         l_msg   := SQLERRM;
         fnd_file.put_line (fnd_file.LOG
                          , 'Operation fails on ' || l_error_step);
         raise_application_error (
            -20003
          , 'Exception OTHERS in TTEC_HR_ORACLE_PAY_CHANGES: ' || l_msg
         );
   END main;
END ttec_hr_oracle_pay_changes;
/
show errors;
/