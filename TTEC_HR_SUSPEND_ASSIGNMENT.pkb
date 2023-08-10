create or replace PACKAGE BODY      TTEC_HR_SUSPEND_ASSIGNMENT
IS
    /* $Header: TTEC_HR_SUSPEND_ASSIGNMENT.pkb 1.0 damolina ship */

    /*== START ================================================================================================*\
         Author: Daniel Molina
           Date: 08/09/2012
      Call From: TTEC HR Suspend Assignment
    Description: Assignments changed to suspend status.

    Modification History:

    Version    Date     Author       Description (Include Ticket#)
    -------  --------   -----------  ----------------------------------------------------------------------------
        1.0  08/09/2012 damolina     REQ#1674204 - Initial version.
        1.0  05/15/2023 RXNETHI-ARGANO R12.2 Upgrade Remediation
    \*== END ==================================================================================================*/

    PROCEDURE main ( errcode                    VARCHAR2
                    ,errbuff                    VARCHAR2
                    ,p_business_group_id   IN   VARCHAR2)
    IS

    /************************************************************************************************************
    *      PROCEDURE main                                                                                       *
    *      Description: This is the main procedure to be called directly from the                               *
    *                   Concurrent Manager.                                                                     *
    *                   Assignments changed to suspend status.                                                  *
    *                                                                                                           *
    *      Input/Output Parameters:                                                                             *
    *                                 IN: p_business_group_id                                                   *
    *                                                                                                           *
    *************************************************************************************************************/


    /** Declare local variables **/
    v_rec            VARCHAR2 (10000) := NULL;
    v_header         VARCHAR2 (1000)  :=    'Oracle Id'
                                         || '|'
                                         || 'Full Name'
                                         || '|'
                                         || 'Site HR/Location'
                                         || '|'
                                         || 'Job Name'
                                         || '|'
                                         || 'Job Family'
                                         || '|'
                                         || 'Employee Status'
                                         || '|'
                                         || 'Location Code'
                                         || '|'
                                         || 'Location Description'
                                         || '|'
                                         || 'ClientCode'
                                         || '|'
                                         || 'ClientDescription'
                                         || '|'
                                         || 'ProgramCode'
                                         || '|'
                                         || 'ProgramDescription'
                                         || '|'
                                         || 'ProjectCode'
                                         || '|'
                                         || 'ProjectDescription'
                                         || '|'
                                         || 'LastUpdateDate';

    v_error_step     VARCHAR2 (1000)  := 'Step 1: Running Query';
    v_data           BOOLEAN          := FALSE;

    /** Declare  Explicit Cursor **/
    CURSOR c_emps
    IS
    SELECT  DISTINCT
            papf.employee_number            OracleId
           ,papf.full_name                  FullName
           ,hla.location_code               Location
           ,pj.name                         JobName
           ,pj.attribute5                   JobFamily
           ,NVL (pasta.user_status,
                 past.user_status)          EmployeeStatus
           ,NVL (pcak.segment1,
                 hla.attribute2)            LocationCode
           ,NVL (ffvv_loc_cost.description,
                 ffvv_loc_org.description)  LocationDescription
           ,pcak.segment2                   ClientCode
           ,ffvv_cli_cost.description       ClientDescription
           ,tepa.prog_cd                    ProgramCode
           ,tepa.program_desc               ProgramDescription
           ,tepa.prj_cd                     ProjectCode
           ,tepa.project_desc               ProjectDescription
           ,paaf.last_update_date           LastUpdateDate
    /*
	START R12.2 Upgrade Remediation
	code commented by RXNETHI-ARGANO,15/05/23
	FROM    hr.per_all_people_f             papf
           ,hr.per_all_assignments_f        paaf
           ,hr.hr_locations_all             hla
           ,hr.per_jobs                     pj
           ,hr.per_assignment_status_types  past
           ,hr.per_ass_status_type_amends   pasta
           ,hr.pay_cost_allocations_f       pcaf
           ,hr.pay_cost_allocation_keyflex  pcak
		   */
	--code added by RXNETHI-ARGANO,15/05/23
	FROM    apps.per_all_people_f             papf
           ,apps.per_all_assignments_f        paaf
           ,apps.hr_locations_all             hla
           ,apps.per_jobs                     pj
           ,apps.per_assignment_status_types  past
           ,apps.per_ass_status_type_amends   pasta
           ,apps.pay_cost_allocations_f       pcaf
           ,apps.pay_cost_allocation_keyflex  pcak
	--END R12.2 Upgrade Remediation
           ,apps.fnd_flex_values_vl         ffvv_loc_cost
           ,apps.fnd_flex_values_vl         ffvv_cli_cost
           ,apps.fnd_flex_values_vl         ffvv_loc_org
           --,cust.ttec_emp_proj_asg          tepa --code commented by RXNETHI-ARGANO,15/05/23
		   ,apps.ttec_emp_proj_asg          tepa --code added by RXNETHI-ARGANO,15/05/23
    WHERE TRUNC(SYSDATE) BETWEEN papf.effective_start_date AND  papf.effective_end_date
      AND paaf.business_group_id IN (p_business_group_id)
      /* Active employees */
      AND papf.current_employee_flag = 'Y'
      /* Suspend Assignment as_of_date */
      AND TRUNC(SYSDATE) = TRUNC(paaf.last_update_date)
      AND paaf.assignment_status_type_id = 2
      /* Assignment */
      AND paaf.person_id = papf.person_id
      /* Assignment Type: Employee */
      AND paaf.assignment_type = 'E'
      /* Primary Assignment in case there are more than one */
      AND paaf.primary_flag = 'Y'
      AND TRUNC(SYSDATE) BETWEEN paaf.effective_start_date AND  paaf.effective_end_date
      /* HR Location / Site and Country */
      AND hla.location_id(+) = paaf.location_id
      /* Job */
      AND pj.job_id(+) = paaf.job_id
      /* Employee Status */
      AND past.assignment_status_type_id(+) = paaf.assignment_status_type_id
      AND pasta.assignment_status_type_id(+) = paaf.assignment_status_type_id
      AND pasta.business_group_id(+) = paaf.business_group_id
      /* Costing (Location.Client.Department in Assignment Form)*/
      AND pcaf.assignment_id(+) = paaf.assignment_id
      AND TRUNC(SYSDATE) BETWEEN pcaf.effective_start_date(+) AND  pcaf.effective_end_date(+)
      AND pcak.cost_allocation_keyflex_id(+) = pcaf.cost_allocation_keyflex_id
      /* Costing Location Description */
      AND ffvv_loc_cost.flex_value(+) = pcak.segment1
      AND ffvv_loc_cost.flex_value_set_id(+) = '1002610'
      /* Costing Client Description */
      AND ffvv_cli_cost.flex_value(+) = pcak.segment2
      AND ffvv_cli_cost.flex_value_set_id(+) = '1002611'
      /* Default Location Description */
      AND ffvv_loc_org.flex_value(+) = hla.attribute2
      AND ffvv_loc_org.flex_value_set_id(+) = '1002610'
      /* Project Assignment (Custom Table) */
      AND tepa.person_id(+) = papf.person_id
      AND TRUNC(SYSDATE) BETWEEN tepa.prj_strt_dt(+) AND tepa.prj_end_dt(+);

      /** Create record **/
      emp_rec c_emps%ROWTYPE;

   BEGIN

    /** Log header **/
    apps.fnd_file.put_line (fnd_file.LOG,'TeleTech HR Report Name: TTEC HR Suspend Assignment Status - As of: '|| TO_CHAR (TRUNC(SYSDATE), 'DD-MON-YYYY'));

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

         v_rec :=  emp_rec.OracleId
                || '|'
                || emp_rec.FullName
                || '|'
                || emp_rec.Location
                || '|'
                || emp_rec.JobName
                || '|'
                || emp_rec.JobFamily
                || '|'
                || emp_rec.EmployeeStatus
                || '|'
                || emp_rec.LocationCode
                || '|'
                || emp_rec.LocationDescription
                || '|'
                || emp_rec.ClientCode
                || '|'
                || emp_rec.ClientDescription
                || '|'
                || emp_rec.ProgramCode
                || '|'
                || emp_rec.ProgramDescription
                || '|'
                || emp_rec.ProjectCode
                || '|'
                || emp_rec.ProjectDescription
                || '|'
                || emp_rec.LastUpdateDate;

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

END TTEC_HR_SUSPEND_ASSIGNMENT;
/
show errors;
/