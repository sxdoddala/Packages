create or replace PACKAGE BODY      TTEC_HR_EXPATRIATE_EMPLOYEES
IS
    /* $Header: TTEC_HR_EXPATRIATE_EMPLOYEES.pkb 1.0 damolina ship */

    /*== START ================================================================================================*\
         Author: Daniel Molina
           Date: 08/29/2012
      Call From: TTEC HR Expatriate Employees
    Description: Capture only the Expat EEs who have had a change on there assignment

    Modification History:

    Version    Date     Author       Description (Include Ticket#)
    -------  --------   -----------  ----------------------------------------------------------------------------
        1.0  08/29/2012 damolina     REQ#1459572 - Initial version.
		1.0  03/MAY/2023 RXNETHI-ARGANO R12.2 Upgrade Remediation

    \*== END ==================================================================================================*/

    PROCEDURE main ( errcode                    VARCHAR2
                    ,errbuff                    VARCHAR2)
    IS

    /************************************************************************************************************
    *      PROCEDURE main                                                                                       *
    *      Description: This is the main procedure to be called directly from the                               *
    *                   Concurrent Manager.                                                                     *
    *                   Capture only the Expat EEs who have had a change on there assignment                    *
    *                                                                                                           *
    *************************************************************************************************************/


    /** Declare local variables **/
    v_rec            VARCHAR2 (10000) := NULL;
    v_header         VARCHAR2 (1000)  :=    'EE#/Oracle Id'
                                         || '|'
                                         || 'Country'
                                         || '|'
                                         || 'Employee Full Name'
                                         || '|'
                                         || 'Actual Termination Date'
                                         || '|'
                                         || 'Job'
                                         || '|'
                                         || 'Job Family'
                                         || '|'
                                         || 'Old Employee Status'
                                         || '|'
                                         || 'New Employee Status'
                                         || '|'
                                         || 'Currency Code'
                                         || '|'
                                         || 'Old Salary (Local Currency)'
                                         || '|'
                                         || 'New Salary (Local Currency)'
                                         || '|'
                                         || 'Old Annual Salary (Loc. Curr.)'
                                         || '|'
                                         || 'New Annual Salary (Loc. Curr.)'
                                         || '|'
                                         || 'Old Salary (USD)'
                                         || '|'
                                         || 'New Salary (USD)'
                                         || '|'
                                         || 'Old Annual Salary (USD)'
                                         || '|'
                                         || 'New Annual Salary (USD)'
                                         || '|'
                                         || 'Salary Change Date'
                                         || '|'
                                         || 'Location Code'
                                         || '|'
                                         || 'Location Description'
                                         || '|'
                                         || 'Client Code'
                                         || '|'
                                         || 'Client Description'
                                         || '|'
                                         || 'Old Department Code'
                                         || '|'
                                         || 'New Department Code'
                                         || '|'
                                         || 'Old Department Desc.'
                                         || '|'
                                         || 'New Department Desc.';

    v_error_step     VARCHAR2 (1000)  := 'Step 1: Running Query';
    v_data           BOOLEAN          := FALSE;

    /** Declare  Explicit Cursor **/
    CURSOR c_emps
    IS
    SELECT   DISTINCT
         papf.employee_number                               oracleID
       , ftt.territory_short_name                           country
       , papf.full_name                                     employeeFullName
       , ppos.actual_termination_date                       actualTerminationDate
       , pj.name                                            jobName
       , pj.attribute5                                      jobFamily
       , NVL (pasta_old.user_status,past_old.user_status)   oldEmployeeStatus
       , NVL (pasta.user_status,past.user_status)           newEmployeeStatus
       , CASE WHEN hla.country = 'ZA'
         THEN 'ZAR'
         ELSE pbg.currency_code
         END                                                currencyCode
       , ppp_old.proposed_salary_n                          oldSalaryLocalCurrency
       , ppp.proposed_salary_n                              newSalaryLocalCurrency
       , NVL (ppb_old.pay_annualization_factor, 1) *
         NVL (ppp_old.proposed_salary_n, 0)                 oldAnnualSalaryLocCurr
       , NVL (ppb.pay_annualization_factor, 1) *
         NVL (ppp.proposed_salary_n, 0)                     newAnnualSalaryLocCurr
       , ROUND (ppp_old.proposed_salary_n *
         NVL (gl_rates_old.conversion_rate, 1), 2)          oldSalaryUSD
       , ROUND (ppp.proposed_salary_n *
         NVL (gl_rates.conversion_rate, 1), 2)              newSalaryUSD
       , ROUND (NVL(ppb_old.pay_annualization_factor,1)
              * NVL(ppp_old.proposed_salary_n, 0)
              * NVL(gl_rates_old.conversion_rate,1)
            , 2)                                            oldAnnualSalaryUSD
       , ROUND (NVL(ppb.pay_annualization_factor,1)
              * NVL(ppp.proposed_salary_n, 0)
              * NVL(gl_rates.conversion_rate, 1)
            , 2)                                            newAnnualSalaryUSD
       , ppp.change_date                                    salaryChangeDate
       , NVL (pcak.segment1,hla.attribute2)                 locationCode
       , NVL (ffvv_loc_cost.description,
              ffvv_loc_org.description)                     locationDescription
       , pcak.segment2                                      clientCode
       , ffvv_cli_cost.description                          clientDescription
       , NVL (pcak_old.segment3,pcak_org_old.segment3)      oldDepartmentCode
       , NVL (pcak.segment3,pcak_org.segment3)              newDepartmentCode
       , NVL (ffvv_dep_cost_old.description,
              ffvv_dep_org_old.description)                 oldDepartmentDesc
       , NVL (ffvv_dep_cost.description,
              ffvv_dep_org.description)                     newDepartmentDesc
/*
START R12.2 Upgrade Remediation
--code commented by RXNETHI-ARGANO, 03/MAY/2023
FROM     hr.per_all_people_f                papf
       , apps.per_business_groups           pbg
       , hr.per_all_assignments_f           paaf
       , per_periods_of_service             ppos
       , hr.hr_locations_all                hla
       , applsys.fnd_territories_tl         ftt
       , hr.per_jobs                        pj
       , apps.hr_lookups                    hl_asg_cat
       , hr.per_assignment_status_types     past
       , hr.per_ass_status_type_amends      pasta
       , hr.per_pay_bases                   ppb
       , hr.per_pay_proposals               ppp*/
-- code added by RXNETHI-ARGANO, 03/MAY/2023	   
FROM     apps.per_all_people_f                papf
       , apps.per_business_groups           pbg
       , apps.per_all_assignments_f           paaf
       , per_periods_of_service             ppos
       , apps.hr_locations_all                hla
       , apps.fnd_territories_tl         ftt
       , apps.per_jobs                        pj
       , apps.hr_lookups                    hl_asg_cat
       , apps.per_assignment_status_types     past
       , apps.per_ass_status_type_amends      pasta
       , apps.per_pay_bases                   ppb
       , apps.per_pay_proposals               ppp
-- END R12.2 Upgrade Remediation
       /* Salary Conversion to USD */
       , (SELECT   gdr.from_currency,
                   gdr.conversion_rate
          --FROM  gl.gl_daily_rates gdr --code commented by RXNETHI-ARGANO,03/MAY/2023
		  FROM  apps.gl_daily_rates gdr --code added by RXNETHI-ARGANO, 03/MAY/2023
          WHERE gdr.to_currency = 'USD'
            AND gdr.status_code <> 'D'
            AND gdr.conversion_date =
            (SELECT MAX (a.conversion_date)
               --FROM  gl.gl_daily_rates a --code commented by RXNETHI-ARGANO, 03/MAY/2023
			   FROM  apps.gl_daily_rates a
               WHERE a.from_currency = gdr.from_currency
                 AND a.to_currency = 'USD'
                 AND a.status_code <> 'D'
                 AND a.conversion_date <= TRUNC(SYSDATE))
          UNION ALL
          SELECT
          'USD',
           1
          FROM DUAL)                        gl_rates
       /*
		START R12.2 Upgrade Remediation
		code commented by RXNETHI-ARGANO, 03/MAY/2023
	   , hr.pay_cost_allocations_f          pcaf
       , hr.pay_cost_allocation_keyflex     pcak
       , apps.fnd_flex_values_vl            ffvv_loc_cost
       , apps.fnd_flex_values_vl            ffvv_cli_cost
       , apps.fnd_flex_values_vl            ffvv_dep_cost
       , hr.hr_all_organization_units       haou
       , hr.pay_cost_allocation_keyflex     pcak_org
       , apps.fnd_flex_values_vl            ffvv_loc_org
       , apps.fnd_flex_values_vl            ffvv_dep_org
       -- /*** As of previous date *** /
       , hr.per_all_assignments_f           paaf_old
       , hr.per_pay_bases                   ppb_old
       , hr.per_pay_proposals               ppp_old */

	   -- code added by RXNETHI-ARGANO, 03/MAY/2023
	   
	   , apps.pay_cost_allocations_f          pcaf
       , apps.pay_cost_allocation_keyflex     pcak
       , apps.fnd_flex_values_vl            ffvv_loc_cost
       , apps.fnd_flex_values_vl            ffvv_cli_cost
       , apps.fnd_flex_values_vl            ffvv_dep_cost
       , apps.hr_all_organization_units       haou
       , apps.pay_cost_allocation_keyflex     pcak_org
       , apps.fnd_flex_values_vl            ffvv_loc_org
       , apps.fnd_flex_values_vl            ffvv_dep_org
        /*** As of previous date ***/
       , apps.per_all_assignments_f           paaf_old
       , apps.per_pay_bases                   ppb_old
       , apps.per_pay_proposals               ppp_old
	   
	   --END R12.2 Upgrade Remediation
       , (SELECT   gdr.from_currency,
                   gdr.conversion_rate
          --FROM  gl.gl_daily_rates gdr -- code commented by RXNETHI-ARGANO, 03/MAY/2023
          FROM  apps.gl_daily_rates gdr -- code added by RXNETHI-ARGANO, 03/MAY/2023
		  WHERE gdr.to_currency = 'USD'
            AND gdr.status_code <> 'D'
            AND gdr.conversion_date =
            (SELECT MAX (a.conversion_date)
               --FROM  gl.gl_daily_rates a --code commented by RXNETHI-ARGANO, 03/MAY/2023
               FROM  apps.gl_daily_rates a -- code added by RXNETHI-ARGANO, 03/MAY/2023
			   WHERE a.from_currency = gdr.from_currency
                 AND a.to_currency = 'USD'
                 AND a.status_code <> 'D'
                 AND a.conversion_date <= TRUNC(SYSDATE) - 1)
          UNION ALL
          SELECT
          'USD',
           1
          FROM DUAL)                        gl_rates_old
       /*
	   START R12.2 Upgrade Remediation
       --code commented by RXNETHI-ARGANO, 03/MAY/2023
	   
	   , hr.per_assignment_status_types     past_old
       , hr.per_ass_status_type_amends      pasta_old
       , hr.pay_cost_allocations_f          pcaf_old
       , hr.pay_cost_allocation_keyflex     pcak_old
       , apps.fnd_flex_values_vl            ffvv_loc_cost_old
       , apps.fnd_flex_values_vl            ffvv_cli_cost_old
       , apps.fnd_flex_values_vl            ffvv_dep_cost_old
       , hr.hr_all_organization_units       haou_old
       , hr.pay_cost_allocation_keyflex     pcak_org_old
       , apps.fnd_flex_values_vl            ffvv_loc_org_old
       , apps.fnd_flex_values_vl            ffvv_dep_org_old
	   */
	   --code added by RXNETHI-ARGANO,03/MAY/2023
       , apps.per_assignment_status_types     past_old
       , apps.per_ass_status_type_amends      pasta_old
       , apps.pay_cost_allocations_f          pcaf_old
       , apps.pay_cost_allocation_keyflex     pcak_old
       , apps.fnd_flex_values_vl            ffvv_loc_cost_old
       , apps.fnd_flex_values_vl            ffvv_cli_cost_old
       , apps.fnd_flex_values_vl            ffvv_dep_cost_old
       , apps.hr_all_organization_units       haou_old
       , apps.pay_cost_allocation_keyflex     pcak_org_old
       , apps.fnd_flex_values_vl            ffvv_loc_org_old
       , apps.fnd_flex_values_vl            ffvv_dep_org_old
       --END R12.2 Upgrade Remediation	   
WHERE
     /* Active employees as of certain date */
     TRUNC(SYSDATE) BETWEEN papf.effective_start_date AND  papf.effective_end_date
     /* Assignment */
     AND paaf.person_id = papf.person_id
     AND pbg.business_group_id = papf.business_group_id
     /* Assignment Type: Employee */
     AND paaf.assignment_type = 'E'
     /* Primary Assignment */
     AND paaf.primary_flag = 'Y'
     AND TRUNC(SYSDATE) BETWEEN paaf.effective_start_date AND  paaf.effective_end_date
     /* Period of Service */
     AND ppos.person_id = papf.person_id
     AND ppos.period_of_service_id = paaf.period_of_service_id
     /* HR Location / Site and Country */
     AND hla.location_id(+) = paaf.location_id
     AND ftt.territory_code(+) = hla.country
     AND ftt.language(+) = USERENV ('LANG')
     /* Job */
     AND pj.job_id(+) = paaf.job_id
     /* Assignment Category */
     AND hl_asg_cat.lookup_code(+) = paaf.employment_category
     AND hl_asg_cat.lookup_type(+) = 'EMP_CAT'
     /* Employee Status */
     AND past.assignment_status_type_id(+) = paaf.assignment_status_type_id
     AND pasta.assignment_status_type_id(+) = paaf.assignment_status_type_id
     AND pasta.business_group_id(+) = paaf.business_group_id
     /* Salary */
     AND ppb.pay_basis_id(+) = paaf.pay_basis_id
     AND ppp.assignment_id(+) = paaf.assignment_id
     AND ppp.approved(+) = 'Y'
     AND TRUNC(SYSDATE) BETWEEN ppp.change_date(+) AND  NVL (ppp.date_to(+), '31-DEC-4712')
     /* Salary Conversion to USD */
     AND gl_rates.from_currency =
            CASE
               WHEN hla.country = 'ZA' THEN 'ZAR'
               ELSE pbg.currency_code
            END
     /* END Salary Conversion to USD */
     /* Costing */
     AND pcaf.assignment_id(+) = paaf.assignment_id
     AND TRUNC(SYSDATE) BETWEEN pcaf.effective_start_date(+) AND  pcaf.effective_end_date(+)
     AND pcak.cost_allocation_keyflex_id(+) = pcaf.cost_allocation_keyflex_id
     /* Costing Location Description */
     AND ffvv_loc_cost.flex_value(+) = pcak.segment1
     AND ffvv_loc_cost.flex_value_set_id(+) = '1002610'
     /* Costing Client Description */
     AND ffvv_cli_cost.flex_value(+) = pcak.segment2
     AND ffvv_cli_cost.flex_value_set_id(+) = '1002611'
     /* Costing Department Description */
     AND ffvv_dep_cost.flex_value(+) = pcak.segment3
     AND ffvv_dep_cost.flex_value_set_id(+) = '1002612'
     /* Defaul Costing */
     AND haou.organization_id(+) = paaf.organization_id
     AND pcak_org.cost_allocation_keyflex_id(+) = haou.cost_allocation_keyflex_id
     /* Default Location Description */
     AND ffvv_loc_org.flex_value(+) = hla.attribute2
     AND ffvv_loc_org.flex_value_set_id(+) = '1002610'
     /* Default Department Description */
     AND ffvv_dep_org.flex_value(+) = pcak_org.segment3
     AND ffvv_dep_org.flex_value_set_id(+) = '1002612'
     /***  As of previous date ***/
     /* Assignment */
     AND paaf_old.person_id = papf.person_id
     AND paaf_old.assignment_type = 'E'
     /* Primary Assignment */
     AND paaf_old.primary_flag = 'Y'
     AND TRUNC(SYSDATE) - 1 BETWEEN paaf_old.effective_start_date AND  paaf_old.effective_end_date
     /* Employee Status */
     AND past_old.assignment_status_type_id(+) = paaf_old.assignment_status_type_id
     AND pasta_old.assignment_status_type_id(+) = paaf_old.assignment_status_type_id
     AND pasta_old.business_group_id(+) = paaf_old.business_group_id
     /* Salary */
     AND ppb_old.pay_basis_id(+) = paaf_old.pay_basis_id
     AND ppp_old.assignment_id(+) = paaf_old.assignment_id
     AND ppp_old.approved(+) = 'Y'
     AND TRUNC(SYSDATE) - 1 BETWEEN ppp_old.change_date(+) AND  NVL (ppp_old.date_to(+), '31-DEC-4712')
     /* Salary Conversion to USD */
     AND gl_rates_old.from_currency =
            CASE
               WHEN hla.country = 'ZA' THEN 'ZAR'
               ELSE pbg.currency_code
            END
     /* END Salary Conversion to USD */
     /* date of modification */
     AND pcaf_old.assignment_id(+) = paaf_old.assignment_id
     AND TRUNC(SYSDATE) - 1 =  pcaf_old.effective_end_date(+)
     AND pcak_old.cost_allocation_keyflex_id(+) = pcaf_old.cost_allocation_keyflex_id
     /* Costing Location Description */
     AND ffvv_loc_cost_old.flex_value(+) = pcak_old.segment1
     AND ffvv_loc_cost_old.flex_value_set_id(+) = '1002610'
     /* Costing Client Description */
     AND ffvv_cli_cost_old.flex_value(+) = pcak_old.segment2
     AND ffvv_cli_cost_old.flex_value_set_id(+) = '1002611'
     /* Costing Department Description */
     AND ffvv_dep_cost_old.flex_value(+) = pcak_old.segment3
     AND ffvv_dep_cost_old.flex_value_set_id(+) = '1002612'
     /* Defaul Costing */
     AND haou_old.organization_id(+) = paaf_old.organization_id
     AND pcak_org_old.cost_allocation_keyflex_id(+) = haou_old.cost_allocation_keyflex_id
     /* Default Location Description */
     AND ffvv_loc_org_old.flex_value(+) = ffvv_loc_org.flex_value
     AND ffvv_loc_org_old.flex_value_set_id(+) = '1002610'
     /* Default Department Description */
     AND ffvv_dep_org_old.flex_value(+) = pcak_org_old.segment3
     AND ffvv_dep_org_old.flex_value_set_id(+) = '1002612'
     /* Capture only the Expat EEs who have had a change on there assignment */
     AND (
            ( /* Deparment Changes */
               ((NVL(ffvv_dep_cost.description,ffvv_dep_org.description) <>  NVL (ffvv_dep_cost_old.description,ffvv_dep_org_old.description))
                AND
                pcaf_old.cost_allocation_keyflex_id IS NOT NULL)
                OR
                /* Status Employees Changes */
                (TRUNC(SYSDATE) - 1 = paaf_old.effective_end_date
                 AND
                 NVL (pasta.user_status,past.user_status) <> NVL (pasta_old.user_status,past_old.user_status)
                 AND
                 /* Not informed if it has been modified to term status */
                 NVL (pasta.assignment_status_type_id,past.assignment_status_type_id) <> 3)
                 OR
                 /* Salary Changes (Most of these are defined for the future so it will be informed at the moment of the change) */
                 ppp.change_date = TRUNC(SYSDATE)
             )
            AND
             (
                /* From/to Expatriate Department*/
                NVL (pcak.segment3,pcak_org.segment3) LIKE 'X%'
                OR
               (NVL (pcak_old.segment3,pcak_org_old.segment3) LIKE 'X%'
                AND pcaf_old.cost_allocation_keyflex_id IS NOT NULL)
             )
         );


      /** Create record **/
      emp_rec c_emps%ROWTYPE;

   BEGIN

    /** Log header **/
    apps.fnd_file.put_line (fnd_file.LOG,'TeleTech HR Report Name: TTEC HR Expatriate Employees - As of: '|| TO_CHAR (TRUNC(SYSDATE), 'DD-MON-YYYY'));

    /** Open cursor **/
    IF NOT c_emps%ISOPEN THEN
        OPEN c_emps;
    END IF;

    v_error_step := 'Step 2: Entering Loop';

    /** Loop records **/
    LOOP
        /** Fetch rows **/
        FETCH c_emps INTO emp_rec;

        /** No data found **/
        IF c_emps%NOTFOUND AND v_data = FALSE THEN
            apps.fnd_file.put_line (fnd_file.output,'No Data Returned');
        END IF;

        EXIT WHEN c_emps%NOTFOUND;

        /** Header **/
        IF c_emps%FOUND AND v_data = FALSE THEN
            apps.fnd_file.put_line (fnd_file.output,v_header);
        END IF;

        v_error_step   := 'Step 3: Inside Loop';

        v_rec :=       emp_rec.oracleID
                    || '|'
                    || emp_rec.country
                    || '|'
                    || emp_rec.employeeFullName
                    || '|'
                    || emp_rec.actualTerminationDate
                    || '|'
                    || emp_rec.jobName
                    || '|'
                    || emp_rec.jobFamily
                    || '|'
                    || emp_rec.oldEmployeeStatus
                    || '|'
                    || emp_rec.newEmployeeStatus
                    || '|'
                    || emp_rec.currencyCode
                    || '|'
                    || emp_rec.oldSalaryLocalCurrency
                    || '|'
                    || emp_rec.newSalaryLocalCurrency
                    || '|'
                    || emp_rec.oldAnnualSalaryLocCurr
                    || '|'
                    || emp_rec.newAnnualSalaryLocCurr
                    || '|'
                    || emp_rec.oldSalaryUSD
                    || '|'
                    || emp_rec.newSalaryUSD
                    || '|'
                    || emp_rec.oldAnnualSalaryUSD
                    || '|'
                    || emp_rec.newAnnualSalaryUSD
                    || '|'
                    || emp_rec.salaryChangeDate
                    || '|'
                    || emp_rec.locationCode
                    || '|'
                    || emp_rec.locationDescription
                    || '|'
                    || emp_rec.clientCode
                    || '|'
                    || emp_rec.clientDescription
                    || '|'
                    || emp_rec.oldDepartmentCode
                    || '|'
                    || emp_rec.newDepartmentCode
                    || '|'
                    || emp_rec.oldDepartmentDesc
                    || '|'
                    || emp_rec.newDepartmentDesc;

                apps.fnd_file.put_line (fnd_file.output, v_rec);

            v_data := TRUE;

    END LOOP;

    /** Close cursor **/
    CLOSE c_emps;

   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG, 'Operation fails on ' || v_error_step);
   END main;

END TTEC_HR_EXPATRIATE_EMPLOYEES;
/
show errors;
/