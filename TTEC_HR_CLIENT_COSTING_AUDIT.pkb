create or replace PACKAGE BODY      ttec_hr_client_costing_audit
IS
/* $Header: ttec_hr_client_costing_audit.pkb 1.0  06/05/12  falinares ship $ */

/*== START ================================================================================================*\
   Author: Felipe Andr�s Reyes Linares
     Date: 06/05/2012
Call From:  -  Program Name: TTEC_HR_CLIENT_COSTING_AUDIT
     Desc:  This package generates the Client Costing Audit
            Report as an output file of the concurrent program.
            It return the employees whose costing client is
            different from the one in the project assignment table.

 Modification History:

Version    Date     Author      Description (Include Ticket#)
-------  --------  -----------  -----------------------------------------------------------------------------
    1.0  06/05/12  FALINARES    REQ# 1205462 - Initial Version.
	1.0  05/MAY/23  RXNETHI-ARGANO R12.2 Upgrade Remediation

\*== END ==================================================================================================*/


/************************************************************************************************************
 *      PROCEDURE main                                                                                      *
 *      Description: This is the main procedure to be called directly from the                              *
 *                   Concurrent Manager.                                                                    *
 *                   It will generate the Client Costing Audit  report                                      *
 *                   as an output file of the concurrent program.                                           *
 *                                                                                                          *
 *      Input/Output Parameters:                                                                            *
 *                                 IN: p_as_of_date - data retrieval constraint                             *
 *                                                                                                          *
 ************************************************************************************************************/

PROCEDURE main ( errcode           VARCHAR2
                ,errbuff           VARCHAR2
                ,p_as_of_date   IN VARCHAR2)
   IS

      /** Declare local variables **/
      v_rec            VARCHAR2 (10000) := NULL;
      v_header         VARCHAR2 (1000) := NULL;
      v_error_step     VARCHAR2 (1000);
      v_msg            VARCHAR2 (2000);
      v_as_of_date     DATE := NULL;

      /** Declare Cursors **/

      CURSOR c_emps (
        p_as_of_date   IN   DATE
      )
      IS
            SELECT   DISTINCT
                     ftt.territory_short_name  country
                   , hla.location_code         location_code
                   , papf.full_name            ee_full_name
                   , papf.employee_number      ee_oracle_id
                   , pj.name                   job_title
                   , pcak.segment2             cli_code_cost
                   , ffvv_cli_cost.description cli_desc_cost
                   , tepa.clt_cd               cli_code_proj
                   , tepa.client_desc          cli_desc_proj
                   , pcak.segment3             dep_code_cost
                   , ffvv_dep_cost.description dep_desc_cost
                   , pcak.segment1             loc_code_cost
                   , ffvv_loc_cost.description loc_desc_cost
                   , papf_sup1.employee_number sup1_ee_num
                   , papf_sup1.full_name       sup1_full_name
                   , papf_sup2.employee_number sup2_ee_num
                   , papf_sup2.full_name       sup2_full_name
            /*
			START R12.2 Upgrade Remediation
			code commented by RXNETHI-ARGANO, 05/MAY/2023
			FROM     hr.per_all_people_f papf
                   , hr.per_all_assignments_f paaf
                   , per_periods_of_service ppos
                   , hr.hr_locations_all hla
                   , hr.per_jobs pj
                   , applsys.fnd_territories_tl ftt
                   , hr.pay_cost_allocations_f pcaf
                   , hr.pay_cost_allocation_keyflex pcak
                   , apps.fnd_flex_values_vl ffvv_loc_cost
                   , apps.fnd_flex_values_vl ffvv_cli_cost
                   , apps.fnd_flex_values_vl ffvv_dep_cost
                   , cust.ttec_emp_proj_asg tepa
                   , hr.per_all_people_f papf_sup1
                   , hr.per_all_assignments_f paaf_sup1
                   , hr.per_all_people_f papf_sup2
                   , hr.per_all_assignments_f paaf_sup2
            */
			--code commented by RXNETHI-ARGANO, 05/MAY/2023
			FROM     apps.per_all_people_f papf
                   , apps.per_all_assignments_f paaf
                   , per_periods_of_service ppos
                   , apps.hr_locations_all hla
                   , apps.per_jobs pj
                   , apps.fnd_territories_tl ftt
                   , apps.pay_cost_allocations_f pcaf
                   , apps.pay_cost_allocation_keyflex pcak
                   , apps.fnd_flex_values_vl ffvv_loc_cost
                   , apps.fnd_flex_values_vl ffvv_cli_cost
                   , apps.fnd_flex_values_vl ffvv_dep_cost
                   , apps.ttec_emp_proj_asg tepa
                   , apps.per_all_people_f papf_sup1
                   , apps.per_all_assignments_f paaf_sup1
                   , apps.per_all_people_f papf_sup2
                   , apps.per_all_assignments_f paaf_sup2
			--END R12.2 Upgrade Remediation
			WHERE    papf.business_group_id <> 0
                 /* Active employees as of certain date */
                 AND NVL(p_as_of_date,TRUNC(SYSDATE)) BETWEEN papf.effective_start_date
                                       AND  papf.effective_end_date
                 AND papf.current_employee_flag = 'Y' /* Active employees */
                 /* Assignment */
                 AND paaf.person_id = papf.person_id
                 AND paaf.assignment_type = 'E' /* Assignment Type: Employee */
                 AND paaf.primary_flag = 'Y' /* Primary Assignment in case there are more than one */
                 AND NVL(p_as_of_date,TRUNC(SYSDATE)) BETWEEN paaf.effective_start_date
                                       AND  paaf.effective_end_date
                 /* Period of Service */
                 AND ppos.person_id = papf.person_id
                 AND ppos.period_of_service_id = paaf.period_of_service_id
                 /* HR Location / Site and Country */
                 AND hla.location_id = paaf.location_id
                 AND ftt.territory_code = hla.country
                 AND ftt.language = USERENV ('LANG')
                 /* Job */
                 AND pj.job_id = paaf.job_id
                 /* Costing (Location.Client.Department in Assignment Form)*/
                 AND pcaf.assignment_id = paaf.assignment_id
                 AND NVL(p_as_of_date,TRUNC(SYSDATE)) BETWEEN pcaf.effective_start_date
                                       AND  pcaf.effective_end_date
                 AND pcak.cost_allocation_keyflex_id = pcaf.cost_allocation_keyflex_id
                 AND pcak.segment2 IS NOT NULL
                 /* Costing Location Description */
                 AND ffvv_loc_cost.flex_value(+) = pcak.segment1
                 AND ffvv_loc_cost.flex_value_set_id(+) = '1002610'
                 /* Costing Client Description */
                 AND ffvv_cli_cost.flex_value(+) = pcak.segment2
                 AND ffvv_cli_cost.flex_value_set_id(+) = '1002611'
                 /* Costing Department Description */
                 AND ffvv_dep_cost.flex_value(+) = pcak.segment3
                 AND ffvv_dep_cost.flex_value_set_id(+) = '1002612'
                 /* Project Assignment (Custom Table) */
                 AND tepa.person_id = papf.person_id
                 AND NVL(p_as_of_date,TRUNC(SYSDATE)) BETWEEN tepa.prj_strt_dt
                                                      AND NVL(tepa.prj_end_dt,TO_DATE('4712-12-31 00:00:00', 'yyyy-mm-dd hh24:mi:ss'))
                /* Supervisor 1*/
                 AND papf_sup1.person_id(+) = paaf.supervisor_id
                 AND NVL(p_as_of_date,TRUNC(SYSDATE)) BETWEEN papf_sup1.effective_start_date(+)
                                       AND  papf_sup1.effective_end_date(+)
                 AND paaf_sup1.person_id(+) = papf_sup1.person_id
                 AND NVL(p_as_of_date,TRUNC(SYSDATE)) BETWEEN paaf_sup1.effective_start_date(+)
                                       AND  paaf_sup1.effective_end_date(+)
                 /* Supervisor 2*/
                 AND papf_sup2.person_id(+) = paaf_sup1.supervisor_id
                 AND NVL(p_as_of_date,TRUNC(SYSDATE)) BETWEEN papf_sup2.effective_start_date(+)
                                       AND  papf_sup2.effective_end_date(+)
                 AND paaf_sup2.person_id(+) = papf_sup2.person_id
                 AND NVL(p_as_of_date,TRUNC(SYSDATE)) BETWEEN paaf_sup2.effective_start_date(+)
                                       AND  paaf_sup2.effective_end_date(+)
                 AND tepa.clt_cd != pcak.segment2
            ORDER BY 1,2,3,4;

   BEGIN

      /** Check and Format Dates **/
      IF p_as_of_date IS NOT NULL
      THEN
         v_as_of_date := TO_DATE (p_as_of_date, 'YYYY/MM/DD HH24:MI:SS');
      ELSE
         v_as_of_date := TRUNC(SYSDATE);
      END IF;

      v_error_step   := 'Step 1: Create header';

      /** Log header **/
      apps.fnd_file.put_line (
         1
       ,    'TeleTech HR Report Name: TeleTech HR Costing Audit Report - As of: '
         || TO_CHAR (v_as_of_date, 'DD-MON-YY')
      );

      apps.fnd_file.put_line (1, '');

      /** Create file header **/
      v_header       :=
            'TeleTech HR Report Name: TeleTech HR Costing Audit Report - As of: '
         || TO_CHAR (v_as_of_date, 'DD-MON-YY');

      apps.fnd_file.put_line (2, v_header);
      apps.fnd_file.put_line (2, '');

      /** Create header for the output **/

      v_header       :=
            'AS OF DATE'
         || '|'
         || 'COUNTRY'
         || '|'
         || 'HR LOCATION / SITE'
         || '|'
         || 'EE FULL NAME'
         || '|'
         || 'EE ORACLE ID'
         || '|'
         || 'JOB TITLE'
         || '|'
         || 'CLIENT CODE - COSTING'
         || '|'
         || 'CLIENT DESC - COSTING'
         || '|'
         || 'CLIENT CODE - PROJECT ASG'
         || '|'
         || 'CLIENT DESC - PROJECT ASG'
         || '|'
         || 'DEPARTMENT CODE - COSTING'
         || '|'
         || 'DEPARTMENT DESC - PROJECT ASG'
         || '|'
         || 'LOCATION CODE - COSTING'
         || '|'
         || 'LOCATION DESC - PROJECT ASG'
         || '|'
         || 'SUPERVISOR 1 EE NUMBER'
         || '|'
         || 'SUPERVISOR 1 FULL NAME'
         || '|'
         || 'SUPERVISOR 2 EE NUMBER'
         || '|'
         || 'SUPERVISOR 2 FULL NAME';

      apps.fnd_file.put_line (2, v_header);
      apps.fnd_file.put_line (2, '');

      v_error_step   := 'Step 2: End create header, entering Loop';

      /** Loop Records **/
      FOR r_emp IN c_emps (v_as_of_date) LOOP

         v_error_step   := 'Step 3: Inside Loop';

         v_rec :=
            v_as_of_date
         || '|'
         || r_emp.country
         || '|'
         || r_emp.location_code
         || '|'
         || r_emp.ee_full_name
         || '|'
         || r_emp.ee_oracle_id
         || '|'
         || r_emp.job_title
         || '|'
         || r_emp.cli_code_cost
         || '|'
         || r_emp.cli_desc_cost
         || '|'
         || r_emp.cli_code_proj
         || '|'
         || r_emp.cli_desc_proj
         || '|'
         || r_emp.dep_code_cost
         || '|'
         || r_emp.dep_desc_cost
         || '|'
         || r_emp.loc_code_cost
         || '|'
         || r_emp.loc_desc_cost
         || '|'
         || r_emp.sup1_ee_num
         || '|'
         || r_emp.sup1_full_name
         || '|'
         || r_emp.sup2_ee_num
         || '|'
         || r_emp.sup2_full_name;


         apps.fnd_file.put_line (2, v_rec);

      END LOOP;


   EXCEPTION
      WHEN OTHERS
      THEN
         DBMS_OUTPUT.put_line ('Operation fails on ' || v_error_step);
         v_msg   := SQLERRM;
         fnd_file.put_line (fnd_file.LOG
                          , 'Operation fails on ' || v_error_step);
         raise_application_error (
            -20003
          , 'Exception OTHERS in TTEC_HR_CLIENT_COSTING_AUDIT: ' || v_msg
         );
   END main;
END ttec_hr_client_costing_audit;
/
show errors;
/