create or replace PACKAGE BODY ttec_active_hc_pkg AS
/*
   REM $Header:   APPS.ttec_active_hc_pkg 1.0 11-NOV-2021 $
   REM
   REM Name          : ttec_active_hc_pkg
   REM Special Notes : package created for Active headcount report for Global and US.
   REM
   REM TASK ID #     :
   REM ECMS Package  :
   REM
   REM ===========================================================================SOFT==========================================
   REM Task       Version   History         Performed by        REFERENCE
   REM Created    1.0       08-NOV-2021     Venkata Kovvuri     Initial Creation
                  1.0       11-JUL-2023     RXNETHI-ARGANO      R12.2 Upgrade Remediation
   REM =====================================================================================================================
   */

    PROCEDURE ttec_us_active_hc_proc (
        p_err_buf    OUT          VARCHAR2,
        p_ret_code   OUT          NUMBER
    ) AS

        CURSOR active_emp_cur IS
        SELECT DISTINCT
            (
                SELECT
                    name
                FROM
                    apps.per_business_groups pbg
                WHERE
                    pbg.business_group_id = paaf.business_group_id
            ) AS business_group,
            papf.employee_number       AS employee_number,
            papf.last_name             AS last_name,
            papf.first_name            AS first_name,
            papf.middle_names          AS middle_names,
            papf.date_of_birth         AS date_of_birth,
            papf.attribute30           hire_point_candidate_id,
            papf.national_identifier   social_security_number,
            papf.attribute1            personal_email,
            TO_CHAR(ppos.date_start, 'MM/DD/YYYY') AS date_start,
            (
                SELECT
                    MAX(cu.clt_cd)
                FROM
                    --cust.ttec_emp_proj_asg cu  --code commented by RXNETHI-ARGANO,11/07/23
                    apps.ttec_emp_proj_asg cu    --code added by RXNETHI-ARGANO,11/07/23
                WHERE
                    papf.person_id = cu.person_id
                    AND SYSDATE BETWEEN cu.prj_strt_dt AND cu.prj_end_dt
            ) AS client_code,
            (
                SELECT
                    MAX(cu.client_desc)
                FROM
                    --cust.ttec_emp_proj_asg cu   --code commented by RXNETHI-ARGANO,11/07/23
                    apps.ttec_emp_proj_asg cu     --code added by RXNETHI-ARGANO,11/07/23
                WHERE
                    papf.person_id = cu.person_id
                    AND SYSDATE BETWEEN cu.prj_strt_dt AND cu.prj_end_dt
            ) AS client_name,
         -------------
            (
                SELECT
                    MAX(cu.prog_cd)
                FROM
                    --cust.ttec_emp_proj_asg cu  --code commented by RXNETHI-ARGANO,11/07/23
                    apps.ttec_emp_proj_asg cu    --code added by RXNETHI-ARGANO,11/07/23
                WHERE
                    papf.person_id = cu.person_id
                    AND SYSDATE BETWEEN cu.prj_strt_dt AND cu.prj_end_dt
            ) AS program_code,
            (
                SELECT
                    MAX(cu.program_desc)
                FROM
                    --cust.ttec_emp_proj_asg cu   --code commented by RXNETHI-ARGANO,11/07/23
                    apps.ttec_emp_proj_asg cu     --code added by RXNETHI-ARGANO,11/07/23
                WHERE
                    papf.person_id = cu.person_id
                    AND SYSDATE BETWEEN cu.prj_strt_dt AND cu.prj_end_dt
            ) AS program_name,
            (
                SELECT
                    MAX(cu.prj_cd)
                FROM
                    --cust.ttec_emp_proj_asg cu  --code commented by RXNETHI-ARGANO,11/07/23
                    apps.ttec_emp_proj_asg cu    --code added by RXNETHI-ARGANO,11/07/23
                WHERE
                    papf.person_id = cu.person_id
                    AND SYSDATE BETWEEN cu.prj_strt_dt AND cu.prj_end_dt
            ) AS project_code,
            (
                SELECT
                    MAX(cu.project_desc)
                FROM
                    --cust.ttec_emp_proj_asg cu  --code commented by RXNETHI-ARGANO,11/07/23
                    apps.ttec_emp_proj_asg cu    --code added by RXNETHI-ARGANO,11/07/23
                WHERE
                    papf.person_id = cu.person_id
                    AND SYSDATE BETWEEN cu.prj_strt_dt AND cu.prj_end_dt
            ) AS project_name,
         -------------
            (
                SELECT
                    attribute2
                FROM
                    apps.hr_locations_all pa
                WHERE
                    pa.location_id = paaf.location_id
            ) AS location_code_org_derived,
            (
                SELECT
                    location_code
                FROM
                    apps.hr_locations_all pa
                WHERE
                    pa.location_id = paaf.location_id
            ) AS location_name_org_derived,
            (
                SELECT
                    pad.address_line1
                    || pad.address_line2
                    || pad.address_line3
                FROM
                    apps.per_addresses pad
                WHERE
                    pad.person_id (+) = papf.person_id
                    AND pad.date_to IS NULL
                    AND pad.primary_flag = 'Y'
            ) AS address,
        -- pad.ADDRESS_LINE1||pad.ADDRESS_LINE2||pad.ADDRESS_LINE3 AS "Address",
        ---pad.TOWN_OR_CITY AS "Town or City",
        --pad.POSTAL_CODE AS "Postal Code",
       -- pad.REGION_2 AS "State Zone",
            (
                SELECT
                    pad.town_or_city
                FROM
                    apps.per_addresses pad
                WHERE
                    pad.person_id (+) = papf.person_id
                    AND pad.date_to IS NULL
                    AND pad.primary_flag = 'Y'
            ) AS town_or_city,
            (
                SELECT
                    pad.postal_code
                FROM
                    apps.per_addresses pad
                WHERE
                    pad.person_id (+) = papf.person_id
                    AND pad.date_to IS NULL
                    AND pad.primary_flag = 'Y'
            ) AS postal_code,
            (
                SELECT
                    pad.region_2
                FROM
                    apps.per_addresses pad
                WHERE
                    pad.person_id (+) = papf.person_id
                    AND pad.date_to IS NULL
                    AND pad.primary_flag = 'Y'
            ) AS state_zone,
            (
                SELECT
                    country
                FROM
                    apps.hr_locations_all pa
                WHERE
                    pa.location_id = paaf.location_id
            ) AS country,
  --  to_char(papf.creation_date, 'MM/DD/YYYY') AS "Creation Date",
            (
                SELECT
                    papf2.employee_number
                FROM
                    apps.per_all_people_f papf2
                WHERE
                    papf2.person_id = paaf.supervisor_id
                    AND SYSDATE BETWEEN papf2.effective_start_date AND papf2.effective_end_date
            ) AS supervisor_oracle_id,
            (
                SELECT
                    papf1.full_name
                FROM
                    apps.per_all_people_f papf1
                WHERE
                    papf1.person_id = paaf.supervisor_id
                    AND SYSDATE BETWEEN papf1.effective_start_date AND papf1.effective_end_date
            ) AS supervisor_name,
            (
                SELECT
                    segment2
                FROM
                    apps.per_job_definitions   pjd1,
                    apps.per_jobs              pj1
                WHERE
                    1 = 1
                    AND pj1.job_definition_id = pjd1.job_definition_id
                    AND pj1.job_id = paaf.job_id
            ) AS job_title,
            haou.name                  legal_employer_name,
            (
                SELECT
                    ppp.proposed_salary_n
                FROM
                    per_pay_proposals ppp
                WHERE
                    paaf.assignment_id = ppp.assignment_id
                    AND ppp.change_date = (
                        SELECT
                            MAX(d.change_date)
                        FROM
                            per_pay_proposals d
                        WHERE
                            d.assignment_id = paaf.assignment_id
                            AND d.approved = 'Y'
                    )
            ) AS proposed_salary,
            paaf.ass_attribute22       AS work_arrangement,
            paaf.ass_attribute23       AS work_arrangement_reason,
            (
                SELECT
                    payroll_name
                FROM
                    apps.pay_payrolls_f ppf
                WHERE
                    ppf.payroll_id = paaf.payroll_id
                    AND trunc(SYSDATE) BETWEEN ppf.effective_start_date AND ppf.effective_end_date
            ) current_payroll,
            paaf.work_at_home          work_at_home,
            paaf.ass_attribute25       AS psa,
            (
                SELECT
                    name
                FROM
                    apps.gl_ledgers gl
                WHERE
                    gl.ledger_id = paaf.set_of_books_id
            ) current_set_of_books,
            apps.ttec_daily_reports_pkg.ttec_ecm_dr(paaf.person_id, 12) ecm_direct_report1,
            apps.ttec_daily_reports_pkg.ttec_ecm_dr(paaf.person_id, 10) ecm_direct_report2
        FROM
            per_all_people_f                 papf,
            apps.per_periods_of_service      ppos,
            per_all_assignments_f            paaf,
            apps.hr_soft_coding_keyflex      hsck,
            apps.hr_all_organization_units   haou
        WHERE
            1 = 1
            --AND papf.employee_number = '3080491'
            AND papf.current_employee_flag = 'Y'
            AND SYSDATE BETWEEN papf.effective_start_date AND papf.effective_end_date
            AND SYSDATE BETWEEN paaf.effective_start_date AND paaf.effective_end_date
            AND papf.person_id = ppos.person_id
            AND papf.person_id = paaf.person_id
            -- and papf.employee_number='3317013'
            AND paaf.soft_coding_keyflex_id = hsck.soft_coding_keyflex_id (+)
            AND haou.organization_id (+) = hsck.segment1
            AND paaf.effective_start_date = (
                SELECT
                    MAX(paaf4.effective_start_date)
                FROM
                    per_all_assignments_f paaf4
                WHERE
                    paaf4.person_id = paaf.person_id
            )
            AND ppos.period_of_service_id = (
                SELECT
                    MAX(ppos1.period_of_service_id)
                FROM
                    apps.per_periods_of_service ppos1
                WHERE
                    ( ppos1.actual_termination_date IS NULL
                      OR ppos1.actual_termination_date >= SYSDATE )
                    AND ppos1.person_id = papf.person_id
            )
            AND papf.business_group_id = 325;

        v_file            utl_file.file_type;
        v_file_name       VARCHAR2(100);
        v_line            VARCHAR2(32767);
        v_instance_name   VARCHAR2(50);
    BEGIN
        SELECT
            ttec_get_instance
        INTO v_instance_name
        FROM
            dual;

        IF v_instance_name = 'PROD' THEN
            v_file_name := 'TTEC_US_Employee_HeadCount_Report_'
                           || TO_CHAR(SYSDATE, 'YYYYMMDDHH24MISS')
                           || '.txt';
        ELSE
            v_file_name := 'Test_TTEC_US_Employee_HeadCount_Report_'
                           || TO_CHAR(SYSDATE, 'YYYYMMDDHH24MISS')
                           || '.txt';
        END IF;

        v_file := utl_file.fopen(location => 'US_HEAD_COUNT', filename => v_file_name, open_mode => 'w');

        v_line := 'Business_Group|Employee_Number|Last_Name|First_Name|Middle_Names|Date_of_Birth|Hire_Point_Candidate_ID|Social_Security_Number|Personal_Email|Date_Start|Client_Code|Client_Name|Program_Code|Program_Name|Project_Code|Project_Name|Location_Code_Org_Derived|Location_Name_Org_Derived|Address|Town_or_City|Postal_Code|State_Zone|Country|Supervisor_Oracle_ID|supervisor_name|job_Title|Legal_Employer_name|Proposed_Salary|Work_Arrangement|Work_Arrangement_Reason|Current_Payroll|Work_at_Home|PSA|Current_Set_of_Books|ECM_Direct_Report1|ECM_Direct_Report2'

        ;
        utl_file.put_line(v_file, v_line);
        FOR i IN active_emp_cur LOOP
            v_line := NULL;
            v_line := i.business_group
                      || '|'
                      || i.employee_number
                      || '|'
                      || i.last_name
                      || '|'
                      || i.first_name
                      || '|'
                      || i.middle_names
                      || '|'
                      || i.date_of_birth
                      || '|'
                      || i.hire_point_candidate_id
                      || '|'
                      || i.social_security_number
                      || '|'
                      || i.personal_email
                      || '|'
                      || i.date_start
                      || '|'
                      || i.client_code
                      || '|'
                      || i.client_name
                      || '|'
                      || i.program_code
                      || '|'
                      || i.program_name
                      || '|'
                      || i.project_code
                      || '|'
                      || i.project_name
                      || '|'
                      || i.location_code_org_derived
                      || '|'
                      || i.location_name_org_derived
                      || '|'
                      || i.address
                      || '|'
                      || i.town_or_city
                      || '|'
                      || i.postal_code
                      || '|'
                      || i.state_zone
                      || '|'
                      || i.country
                      || '|'
                      || i.supervisor_oracle_id
                      || '|'
                      || i.supervisor_name
                      || '|'
                      || i.job_title
                      || '|'
                      || i.legal_employer_name
                      || '|'
                      || i.proposed_salary
                      || '|'
                      || i.work_arrangement
                      || '|'
                      || i.work_arrangement_reason
                      || '|'
                      || i.current_payroll
                      || '|'
                      || i.work_at_home
                      || '|'
                      || i.psa
                      || '|'
                      || i.current_set_of_books
                      || '|'
                      || i.ecm_direct_report1
                      || '|'
                      || i.ecm_direct_report2;

            utl_file.put_line(v_file, v_line);
        END LOOP;

        utl_file.fclose(v_file);
    EXCEPTION
        WHEN OTHERS THEN
            utl_file.fclose(v_file);
            dbms_output.put_line('Exception - ' || sqlerrm);
            fnd_file.put_line(fnd_file.log, 'Exception Occured -- ' || sqlerrm);
    END ttec_us_active_hc_proc;

    PROCEDURE ttec_global_active_hc_proc (
        p_err_buf    OUT          VARCHAR2,
        p_ret_code   OUT          NUMBER
    ) AS

        CURSOR active_emp_cur IS
        SELECT DISTINCT
            (
                SELECT
                    name
                FROM
                    apps.per_business_groups pbg
                WHERE
                    pbg.business_group_id = paaf.business_group_id
            ) AS business_group,
            papf.employee_number       AS employee_number,
            papf.last_name             AS last_name,
            papf.first_name            AS first_name,
            papf.middle_names          AS middle_names,
            papf.date_of_birth         AS date_of_birth,
            papf.attribute30           hire_point_candidate_id,
            papf.national_identifier   social_security_number,
            papf.attribute1            personal_email,
            TO_CHAR(ppos.date_start, 'MM/DD/YYYY') AS date_start,
            (
                SELECT
                    MAX(cu.clt_cd)
                FROM
                    --cust.ttec_emp_proj_asg cu  ----code commented by RXNETHI-ARGANO,11/07/23
                    apps.ttec_emp_proj_asg cu      --code added by RXNETHI-ARGANO,11/07/23
                WHERE
                    papf.person_id = cu.person_id
                    AND SYSDATE BETWEEN cu.prj_strt_dt AND cu.prj_end_dt
            ) AS client_code,
            (
                SELECT
                    MAX(cu.client_desc)
                FROM
                    --cust.ttec_emp_proj_asg cu  --code commented by RXNETHI-ARGANO,11/07/23
                    apps.ttec_emp_proj_asg cu    --code added by RXNETHI-ARGANO,11/07/23
                WHERE
                    papf.person_id = cu.person_id
                    AND SYSDATE BETWEEN cu.prj_strt_dt AND cu.prj_end_dt
            ) AS client_name,
         ----------------------------
            (
                SELECT
                    MAX(cu.prog_cd)
                FROM
                    --cust.ttec_emp_proj_asg cu  --code commented by RXNETHI-ARGANO,11/07/23
                    apps.ttec_emp_proj_asg cu    --code added by RXNETHI-ARGANO,11/07/23
                WHERE
                    papf.person_id = cu.person_id
                    AND SYSDATE BETWEEN cu.prj_strt_dt AND cu.prj_end_dt
            ) AS program_code,
            (
                SELECT
                    MAX(cu.program_desc)
                FROM
                    --cust.ttec_emp_proj_asg cu   --code commented by RXNETHI-ARGANO,11/07/23
                    apps.ttec_emp_proj_asg cu     --code added by RXNETHI-ARGANO,11/07/23
                WHERE
                    papf.person_id = cu.person_id
                    AND SYSDATE BETWEEN cu.prj_strt_dt AND cu.prj_end_dt
            ) AS program_name,
            (
                SELECT
                    MAX(cu.prj_cd)
                FROM
                    --cust.ttec_emp_proj_asg cu  --code commented by RXNETHI-ARGANO,11/07/23
                    apps.ttec_emp_proj_asg cu    --code added by RXNETHI-ARGANO,11/07/23
                WHERE
                    papf.person_id = cu.person_id
                    AND SYSDATE BETWEEN cu.prj_strt_dt AND cu.prj_end_dt
            ) AS project_code,
            (
                SELECT
                    MAX(cu.project_desc)
                FROM
                    --cust.ttec_emp_proj_asg cu   --code commented by RXNETHI-ARGANO,11/07/23
                    apps.ttec_emp_proj_asg cu     --code added by RXNETHI-ARGANO,11/07/23
                WHERE
                    papf.person_id = cu.person_id
                    AND SYSDATE BETWEEN cu.prj_strt_dt AND cu.prj_end_dt
            ) AS project_name,
         -----------------------------------------------------
            (
                SELECT
                    attribute2
                FROM
                    apps.hr_locations_all pa
                WHERE
                    pa.location_id = paaf.location_id
            ) AS location_code_org_derived,
            (
                SELECT
                    location_code
                FROM
                    apps.hr_locations_all pa
                WHERE
                    pa.location_id = paaf.location_id
            ) AS location_name_org_derived,
            (
                SELECT
                    pad.address_line1
                    || pad.address_line2
                    || pad.address_line3
                FROM
                    apps.per_addresses pad
                WHERE
                    pad.person_id (+) = papf.person_id
                    AND pad.date_to IS NULL
                    AND pad.primary_flag = 'Y'
            ) AS address,
        /* pad.ADDRESS_LINE1||pad.ADDRESS_LINE2||pad.ADDRESS_LINE3 AS "Address",
        pad.TOWN_OR_CITY AS "Town or City",
        pad.POSTAL_CODE AS "Postal Code",
        pad.REGION_2 AS "State Zone", */
            (
                SELECT
                    pad.town_or_city
                FROM
                    apps.per_addresses pad
                WHERE
                    pad.person_id (+) = papf.person_id
                    AND pad.date_to IS NULL
                    AND pad.primary_flag = 'Y'
            ) AS town_or_city,
            (
                SELECT
                    pad.postal_code
                FROM
                    apps.per_addresses pad
                WHERE
                    pad.person_id (+) = papf.person_id
                    AND pad.date_to IS NULL
                    AND pad.primary_flag = 'Y'
            ) AS postal_code,
            (
                SELECT
                    pad.region_2
                FROM
                    apps.per_addresses pad
                WHERE
                    pad.person_id (+) = papf.person_id
                    AND pad.date_to IS NULL
                    AND pad.primary_flag = 'Y'
            ) AS state_zone,
            (
                SELECT
                    country
                FROM
                    apps.hr_locations_all pa
                WHERE
                    pa.location_id = paaf.location_id
            ) AS country,
  --  to_char(papf.creation_date, 'MM/DD/YYYY') AS "Creation Date",
            (
                SELECT
                    papf2.employee_number
                FROM
                    apps.per_all_people_f papf2
                WHERE
                    papf2.person_id = paaf.supervisor_id
                    AND SYSDATE BETWEEN papf2.effective_start_date AND papf2.effective_end_date
            ) AS supervisor_oracle_id,
            (
                SELECT
                    papf1.full_name
                FROM
                    apps.per_all_people_f papf1
                WHERE
                    papf1.person_id = paaf.supervisor_id
                    AND SYSDATE BETWEEN papf1.effective_start_date AND papf1.effective_end_date
            ) AS supervisor_name,
            (
                SELECT
                    segment2
                FROM
                    apps.per_job_definitions   pjd1,
                    apps.per_jobs              pj1
                WHERE
                    1 = 1
                    AND pj1.job_definition_id = pjd1.job_definition_id
                    AND pj1.job_id = paaf.job_id
            ) AS job_title,
            haou.name                  legal_employer_name,
            (
                SELECT
                    ppp.proposed_salary_n
                FROM
                    per_pay_proposals ppp
                WHERE
                    paaf.assignment_id = ppp.assignment_id
                    AND ppp.change_date = (
                        SELECT
                            MAX(d.change_date)
                        FROM
                            per_pay_proposals d
                        WHERE
                            d.assignment_id = paaf.assignment_id
                            AND d.approved = 'Y'
                    )
            ) AS proposed_salary,
            paaf.ass_attribute22       AS work_arrangement,
            paaf.ass_attribute23       AS work_arrangement_reason
        FROM
            per_all_people_f                 papf,
            apps.per_periods_of_service      ppos,
            per_all_assignments_f            paaf,
            apps.hr_soft_coding_keyflex      hsck,
            apps.hr_all_organization_units   haou
        WHERE
            1 = 1
            -- and papf.employee_number IN('3324509'
            AND papf.current_employee_flag = 'Y'
            AND SYSDATE BETWEEN papf.effective_start_date AND papf.effective_end_date
            AND SYSDATE BETWEEN paaf.effective_start_date AND paaf.effective_end_date
            AND papf.person_id = ppos.person_id
            AND papf.person_id = paaf.person_id
            --AND papf.employee_number = '3080491'
            AND paaf.soft_coding_keyflex_id = hsck.soft_coding_keyflex_id (+)
            AND haou.organization_id (+) = hsck.segment1
            AND paaf.effective_start_date = (
                SELECT
                    MAX(paaf4.effective_start_date)
                FROM
                    per_all_assignments_f paaf4
                WHERE
                    paaf4.person_id = paaf.person_id
            )
            AND ppos.period_of_service_id = (
                SELECT
                    MAX(ppos1.period_of_service_id)
                FROM
                    apps.per_periods_of_service ppos1
                WHERE
                    ( ppos1.actual_termination_date IS NULL
                      OR ppos1.actual_termination_date >= SYSDATE )
                    AND ppos1.person_id = papf.person_id
            )
            AND papf.business_group_id != 0;

        v_file            utl_file.file_type;
        v_file_name       VARCHAR2(100);
        v_line            VARCHAR2(32767);
        v_instance_name   VARCHAR2(50);
    BEGIN
        SELECT
            ttec_get_instance
        INTO v_instance_name
        FROM
            dual;

        IF v_instance_name = 'PROD' THEN
            v_file_name := 'TTEC_Global_Employee_HeadCount_Report_'
                           || TO_CHAR(SYSDATE, 'YYYYMMDDHH24MISS')
                           || '.txt';
        ELSE
            v_file_name := 'Test_TTEC_Global_Employee_HeadCount_Report_'
                           || TO_CHAR(SYSDATE, 'YYYYMMDDHH24MISS')
                           || '.txt';
        END IF;

        v_file := utl_file.fopen(location => 'GLOBAL_HEAD_COUNT', filename => v_file_name, open_mode => 'w');

        v_line := 'Business_Group|Employee_Number|Last_Name|First_Name|Middle_Names|Date_of_Birth|Hire_Point_Candidate_ID|Social_Security_Number|Personal_Email|Date_Start|Client_Code|Client_Name|Program_Code|Program_Name|Project_Code|Project_Name|Location_Code_Org_Derived|Location_Name_Org_Derived|Address|Town_or_City|Postal_Code|State_Zone|Country|Supervisor_Oracle_ID|Supervisor_Name|job_Title|Legal_Employer_name|Proposed_Salary|Work_Arrangement|Work_Arrangement_Reason'

        ;
        utl_file.put_line(v_file, v_line);
        FOR i IN active_emp_cur LOOP
            v_line := NULL;
            v_line := i.business_group
                      || '|'
                      || i.employee_number
                      || '|'
                      || i.last_name
                      || '|'
                      || i.first_name
                      || '|'
                      || i.middle_names
                      || '|'
                      || i.date_of_birth
                      || '|'
                      || i.hire_point_candidate_id
                      || '|'
                      || i.social_security_number
                      || '|'
                      || i.personal_email
                      || '|'
                      || i.date_start
                      || '|'
                      || i.client_code
                      || '|'
                      || i.client_name
                      || '|'
                      || i.program_code
                      || '|'
                      || i.program_name
                      || '|'
                      || i.project_code
                      || '|'
                      || i.project_name
                      || '|'
                      || i.location_code_org_derived
                      || '|'
                      || i.location_name_org_derived
                      || '|'
                      || i.address
                      || '|'
                      || i.town_or_city
                      || '|'
                      || i.postal_code
                      || '|'
                      || i.state_zone
                      || '|'
                      || i.country
                      || '|'
                      || i.supervisor_oracle_id
                      || '|'
                      || i.supervisor_name
                      || '|'
                      || i.job_title
                      || '|'
                      || i.legal_employer_name
                      || '|'
                      || i.proposed_salary
                      || '|'
                      || i.work_arrangement
                      || '|'
                      || i.work_arrangement_reason;

            utl_file.put_line(v_file, v_line);
        END LOOP;

        utl_file.fclose(v_file);
    EXCEPTION
        WHEN OTHERS THEN
            utl_file.fclose(v_file);
            dbms_output.put_line('Exception - ' || sqlerrm);
            fnd_file.put_line(fnd_file.log, 'Exception Occured -- ' || sqlerrm);
    END ttec_global_active_hc_proc;

END ttec_active_hc_pkg;
/
show errors;
/