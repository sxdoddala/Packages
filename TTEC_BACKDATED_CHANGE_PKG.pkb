/************************************************************************************
        Program Name:ttec_backdated_change_pkg  

        

       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
    IXPRAVEEN(ARGANO)            1.0     18-May-2023     R12.2 Upgrade Remediation
    ****************************************************************************************/
create or replace PACKAGE BODY ttec_backdated_change_pkg IS

    PROCEDURE main_proc (
        errbuf        OUT  VARCHAR2,
        retcode       OUT  NUMBER,
        p_start_date  IN   VARCHAR2,
        p_end_date    IN   VARCHAR2
    ) AS
-------------------- CURSOR promotion_changes Start -------------------------------------------------
        CURSOR promotion_changes (
            p_start_date  IN VARCHAR2,
            p_end_date    IN VARCHAR2
        ) IS
        SELECT
            papf.employee_number             oracle_id,
            papf.last_name,
            papf.first_name,
            pps.date_start                   hire_date,
            paaf_new.organization_id         organization_code,
            haou.name                        organization_name,
            paaf_new.location_id,
            hl.location_code                 location_name,
            hl.country                       country_code,
            tepa.clt_cd                      gl_client_code,
            tepa.client_desc                 gl_client_name,
            tepa.prog_cd                     program_code,
            tepa.program_desc                program_name,
            tepa.prj_cd                      project_code,
            tepa.project_desc                project_name,
            (
                SELECT
                    substr(MAX(name), 1, instr(MAX(name), '.') - 1)
                FROM
                    per_jobs pj
                WHERE
                    pj.job_id = paaf_new.job_id
            )                                job_code,
            (
                SELECT
                    substr(MAX(name), instr(MAX(name), '.', 1) + 1)
                FROM
                    per_jobs pj
                WHERE
                    pj.job_id = paaf_new.job_id
            )                                job_title,
            (
                SELECT
                    attribute5
                FROM
                    per_jobs pj
                WHERE
                    pj.job_id = paaf_new.job_id
            )                                job_family,
            (
                SELECT
                    attribute20
                FROM
                    per_jobs pj
                WHERE
                    pj.job_id = paaf_new.job_id
            )                                gca_level,
            paaf_new.ass_attribute22         work_arrangement_type,
            past.user_status                 assignment_status,
            (
                SELECT
                    p1.employee_number
                FROM
                    per_all_people_f p1
                WHERE
                        p1.person_id = paaf_new.supervisor_id
                  --  AND trunc(sysdate) BETWEEN paaf_new.effective_start_date AND paaf_new.effective_end_date
                    AND trunc(sysdate) BETWEEN p1.effective_start_date AND p1.effective_end_date
            )                                supervisor_id,
            (
                SELECT
                    full_name
                FROM
                    per_all_people_f p1
                WHERE
                        p1.person_id = paaf_new.supervisor_id
                  --  AND trunc(sysdate) BETWEEN paaf_new.effective_start_date AND paaf_new.effective_end_date
                    AND trunc(sysdate) BETWEEN p1.effective_start_date AND p1.effective_end_date
            )                                supv_full_name,
            paaf_new.last_update_date        oracle_transaction_date,
            paaf_new.effective_start_date    effective_date,
            nvl((
                SELECT
                    description
                FROM
                    fnd_user fu
                WHERE
                    fu.user_id = paaf_new.last_updated_by
            ),
                (
                SELECT
                    user_name
                FROM
                    fnd_user fu
                WHERE
                    fu.user_id = paaf_new.last_updated_by
            ))                               updated_by,
            (
                SELECT
                    p3.employee_number
                FROM
                    per_all_people_f p3
                WHERE
                        ROWNUM = 1
                    AND p3.person_id = (
                        SELECT DISTINCT
                            fu.employee_id
                        FROM
                            apps.fnd_user fu
                        WHERE
                 --old.employee_id=new.employee_id
                                fu.user_id = paaf_new.last_updated_by
                            AND ROWNUM = 1
                    )
            )                                last_updt_by_oracle_id
        FROM
            per_all_people_f              papf,
            per_all_assignments_f         paaf_old,
            apps.per_all_assignments_f    paaf_new,
            per_periods_of_service        pps,
            hr_all_organization_units     haou,
            hr_locations                  hl,
            per_business_groups           pbg,
            per_assignment_status_types   past,
            ttec_emp_proj_asg             tepa
        WHERE
                1 = 1
            AND papf.person_id = pps.person_id
            AND papf.person_id = paaf_old.person_id
            AND papf.person_id = paaf_new.person_id
            AND paaf_old.assignment_id = paaf_new.assignment_id
            AND haou.organization_id = paaf_new.organization_id
            AND hl.location_id = paaf_new.location_id
            AND pbg.business_group_id = paaf_new.business_group_id
            AND paaf_new.assignment_status_type_id = past.assignment_status_type_id
            AND papf.employee_number = tepa.employee_number
            AND paaf_new.job_id != paaf_old.job_id
            AND trunc(sysdate) BETWEEN tepa.prj_strt_dt AND tepa.prj_end_dt
            AND ( pps.actual_termination_date IS NULL
                  OR pps.actual_termination_date > sysdate )
            AND trunc(sysdate) BETWEEN papf.effective_start_date AND papf.effective_end_date
            AND trunc(paaf_old.effective_end_date) + 1 = trunc(paaf_new.effective_start_date)
            AND paaf_new.last_update_date BETWEEN to_date(p_start_date, 'YYYY/MM/DD HH24:MI:SS') AND to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS')
        ORDER BY
            paaf_new.effective_start_date ASC;
-------------------- CURSOR promotion_changes End -------------------------------------------------

-------------------- CURSOR location_changes Start -------------------------------------------------
        CURSOR location_changes (
            p_start_date  IN VARCHAR2,
            p_end_date    IN VARCHAR2
        ) IS
        SELECT
            papf.employee_number             oracle_id,
            papf.last_name,
            papf.first_name,
            pps.date_start                   hire_date,
            paaf_new.organization_id         organization_code,
            haou.name                        organization_name,
            paaf_new.location_id,
            hl.location_code                 location_name,
            hl.country                       country_code,
            tepa.clt_cd                      gl_client_code,
            tepa.client_desc                 gl_client_name,
            tepa.prog_cd                     program_code,
            tepa.program_desc                program_name,
            tepa.prj_cd                      project_code,
            tepa.project_desc                project_name,
            (
                SELECT
                    substr(MAX(name), 1, instr(MAX(name), '.') - 1)
                FROM
                    per_jobs pj
                WHERE
                    pj.job_id = paaf_new.job_id
            )                                job_code,
            (
                SELECT
                    substr(MAX(name), instr(MAX(name), '.', 1) + 1)
                FROM
                    per_jobs pj
                WHERE
                    pj.job_id = paaf_new.job_id
            )                                job_title,
            (
                SELECT
                    attribute5
                FROM
                    per_jobs pj
                WHERE
                    pj.job_id = paaf_new.job_id
            )                                job_family,
            (
                SELECT
                    attribute20
                FROM
                    per_jobs pj
                WHERE
                    pj.job_id = paaf_new.job_id
            )                                gca_level,
            paaf_new.ass_attribute22         work_arrangement_type,
            past.user_status                 assignment_status,
            (
                SELECT
                    p1.employee_number
                FROM
                    per_all_people_f p1
                WHERE
                        p1.person_id = paaf_new.supervisor_id
                  --  AND trunc(sysdate) BETWEEN paaf_new.effective_start_date AND paaf_new.effective_end_date
                    AND trunc(sysdate) BETWEEN p1.effective_start_date AND p1.effective_end_date
            )                                supervisor_id,
            (
                SELECT
                    full_name
                FROM
                    per_all_people_f p1
                WHERE
                        p1.person_id = paaf_new.supervisor_id
               --     AND trunc(sysdate) BETWEEN paaf_new.effective_start_date AND paaf_new.effective_end_date
                    AND trunc(sysdate) BETWEEN p1.effective_start_date AND p1.effective_end_date
            )                                supv_full_name,
            paaf_new.last_update_date        oracle_transaction_date,
            paaf_new.effective_start_date    effective_date,
            nvl((
                SELECT
                    description
                FROM
                    fnd_user fu
                WHERE
                    fu.user_id = paaf_new.last_updated_by
            ),
                (
                SELECT
                    user_name
                FROM
                    fnd_user fu
                WHERE
                    fu.user_id = paaf_new.last_updated_by
            ))                               updated_by,
            (
                SELECT
                    p3.employee_number
                FROM
                    per_all_people_f p3
                WHERE
                        ROWNUM = 1
                    AND p3.person_id = (
                        SELECT DISTINCT
                            fu.employee_id
                        FROM
                            apps.fnd_user fu
                        WHERE
                 --old.employee_id=new.employee_id
                                fu.user_id = paaf_new.last_updated_by
                            AND ROWNUM = 1
                    )
            )                                last_updt_by_oracle_id
        FROM
            per_all_people_f              papf,
            per_all_assignments_f         paaf_old,
            apps.per_all_assignments_f    paaf_new,
            per_periods_of_service        pps,
            hr_all_organization_units     haou,
            hr_locations                  hl,
            per_business_groups           pbg,
            per_assignment_status_types   past,
            ttec_emp_proj_asg             tepa
        WHERE
                1 = 1
            AND papf.person_id = pps.person_id
            AND papf.person_id = paaf_old.person_id
            AND papf.person_id = paaf_new.person_id
            AND paaf_old.assignment_id = paaf_new.assignment_id
            AND haou.organization_id = paaf_new.organization_id
            AND hl.location_id = paaf_new.location_id
            AND pbg.business_group_id = paaf_new.business_group_id
            AND paaf_new.assignment_status_type_id = past.assignment_status_type_id
            AND papf.employee_number = tepa.employee_number
            AND paaf_new.location_id != paaf_old.location_id
            AND trunc(sysdate) BETWEEN tepa.prj_strt_dt AND tepa.prj_end_dt
            AND ( pps.actual_termination_date IS NULL
                  OR pps.actual_termination_date > sysdate )
            AND trunc(paaf_old.effective_end_date) + 1 = trunc(paaf_new.effective_start_date)
            AND trunc(sysdate) BETWEEN papf.effective_start_date AND papf.effective_end_date
            AND paaf_new.last_update_date BETWEEN to_date(p_start_date, 'YYYY/MM/DD HH24:MI:SS') AND to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS')
        ORDER BY
            paaf_new.effective_start_date ASC;

-------------------- CURSOR location_changes End -------------------------------------------------

-------------------- CURSOR work_arrangement_changes Start -------------------------------------------------

        CURSOR work_arrangement_changes (
            p_start_date  IN VARCHAR2,
            p_end_date    IN VARCHAR2
        ) IS
        SELECT
            papf.employee_number             oracle_id,
            papf.last_name,
            papf.first_name,
            pps.date_start                   hire_date,
            paaf_new.organization_id         organization_code,
            haou.name                        organization_name,
            paaf_new.location_id,
            hl.location_code                 location_name,
            hl.country                       country_code,
            tepa.clt_cd                      gl_client_code,
            tepa.client_desc                 gl_client_name,
            tepa.prog_cd                     program_code,
            tepa.program_desc                program_name,
            tepa.prj_cd                      project_code,
            tepa.project_desc                project_name,
            (
                SELECT
                    substr(MAX(name), 1, instr(MAX(name), '.') - 1)
                FROM
                    per_jobs pj
                WHERE
                    pj.job_id = paaf_new.job_id
            )                                job_code,
            (
                SELECT
                    substr(MAX(name), instr(MAX(name), '.', 1) + 1)
                FROM
                    per_jobs pj
                WHERE
                    pj.job_id = paaf_new.job_id
            )                                job_title,
            (
                SELECT
                    attribute5
                FROM
                    per_jobs pj
                WHERE
                    pj.job_id = paaf_new.job_id
            )                                job_family,
            (
                SELECT
                    attribute20
                FROM
                    per_jobs pj
                WHERE
                    pj.job_id = paaf_new.job_id
            )                                gca_level,
            paaf_new.ass_attribute22         work_arrangement_type,
            past.user_status                 assignment_status,
            (
                SELECT
                    full_name
                FROM
                    per_all_people_f p1
                WHERE
                        p1.person_id = paaf_new.supervisor_id
                 --   AND trunc(sysdate) BETWEEN paaf_new.effective_start_date AND paaf_new.effective_end_date
                    AND trunc(sysdate) BETWEEN p1.effective_start_date AND p1.effective_end_date
            )                                supv_full_name,
            (
                SELECT
                    p2.employee_number
                FROM
                    per_all_people_f p2
                WHERE
                        p2.person_id = paaf_new.supervisor_id
                  --  AND trunc(sysdate) BETWEEN paaf_new.effective_start_date AND paaf_new.effective_end_date
                    AND trunc(sysdate) BETWEEN p2.effective_start_date AND p2.effective_end_date
            )                                supervisor_id,
            paaf_new.last_update_date        oracle_transaction_date,
            paaf_new.effective_start_date    effective_date,
            nvl((
                SELECT
                    description
                FROM
                    fnd_user fu
                WHERE
                    fu.user_id = paaf_new.last_updated_by
            ),
                (
                SELECT
                    user_name
                FROM
                    fnd_user fu
                WHERE
                    fu.user_id = paaf_new.last_updated_by
            ))                               updated_by,
            (
                SELECT
                    p3.employee_number
                FROM
                    per_all_people_f p3
                WHERE
                        ROWNUM = 1
                    AND p3.person_id = (
                        SELECT DISTINCT
                            fu.employee_id
                        FROM
                            apps.fnd_user fu
                        WHERE
                 --old.employee_id=new.employee_id
                                fu.user_id = paaf_new.last_updated_by
                            AND ROWNUM = 1
                    )
            )                                last_updt_by_oracle_id
        FROM
            per_all_people_f              papf,
            per_all_assignments_f         paaf_old,
            apps.per_all_assignments_f    paaf_new,
            per_periods_of_service        pps,
            hr_all_organization_units     haou,
            hr_locations                  hl,
            per_business_groups           pbg,
            per_assignment_status_types   past,
            ttec_emp_proj_asg             tepa
        WHERE
                1 = 1
            AND papf.person_id = pps.person_id
            AND papf.person_id = paaf_old.person_id
            AND papf.person_id = paaf_new.person_id
            AND paaf_old.assignment_id = paaf_new.assignment_id
            AND haou.organization_id = paaf_new.organization_id
            AND hl.location_id = paaf_new.location_id
            AND pbg.business_group_id = paaf_new.business_group_id
            AND paaf_new.assignment_status_type_id = past.assignment_status_type_id
            AND papf.employee_number = tepa.employee_number
            AND paaf_new.ass_attribute22 != paaf_old.ass_attribute22
            AND trunc(sysdate) BETWEEN tepa.prj_strt_dt AND tepa.prj_end_dt
            AND ( pps.actual_termination_date IS NULL
                  OR pps.actual_termination_date > sysdate )
            AND trunc(sysdate) BETWEEN papf.effective_start_date AND papf.effective_end_date
            AND trunc(paaf_old.effective_end_date) + 1 = trunc(paaf_new.effective_start_date)
            AND paaf_new.last_update_date BETWEEN to_date(p_start_date, 'YYYY/MM/DD HH24:MI:SS') AND to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS')
        ORDER BY
            paaf_new.effective_start_date ASC;

-------------------- CURSOR work_arrangement_changes End -------------------------------------------------

-------------------- CURSOR salary_changes Start -------------------------------------------------

        CURSOR salary_changes (
            p_start_date  IN VARCHAR2,
            p_end_date    IN VARCHAR2
        ) IS
        SELECT
            papf.employee_number    oracle_id,
            papf.last_name,
            papf.first_name,
            pps.date_start          hire_date,
            paaf.organization_id    organization_code,
            haou.name               organization_name,
            paaf.location_id,
            hl.location_code        location_name,
            hl.country              country_code,
            tepa.clt_cd             gl_client_code,
            tepa.client_desc        gl_client_name,
            tepa.prog_cd            program_code,
            tepa.program_desc       program_name,
            tepa.prj_cd             project_code,
            tepa.project_desc       project_name,
            (
                SELECT
                    substr(MAX(name), 1, instr(MAX(name), '.') - 1)
                FROM
                    per_jobs pj
                WHERE
                    pj.job_id = paaf.job_id
            )                       job_code,
            (
                SELECT
                    substr(MAX(name), instr(MAX(name), '.', 1) + 1)
                FROM
                    per_jobs pj
                WHERE
                    pj.job_id = paaf.job_id
            )                       job_title,
            (
                SELECT
                    attribute5
                FROM
                    per_jobs pj
                WHERE
                    pj.job_id = paaf.job_id
            )                       job_family,
            (
                SELECT
                    attribute20
                FROM
                    per_jobs pj
                WHERE
                    pj.job_id = paaf.job_id
            )                       gca_level,
            paaf.ass_attribute22    work_arrangement_type,
            past.user_status        assignment_status,
            (
                SELECT
                    p1.employee_number
                FROM
                    per_all_people_f p1
                WHERE
                        p1.person_id = paaf.supervisor_id
                  --  AND trunc(sysdate) BETWEEN paaf_new.effective_start_date AND paaf_new.effective_end_date
                    AND trunc(sysdate) BETWEEN p1.effective_start_date AND p1.effective_end_date
            )                       supervisor_id,
            (
                SELECT
                    full_name
                FROM
                    per_all_people_f p1
                WHERE
                        p1.person_id = paaf.supervisor_id
                   -- AND trunc(sysdate) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
                    AND trunc(sysdate) BETWEEN p1.effective_start_date AND p1.effective_end_date
            )                       supv_full_name,
            new.last_update_date    oracle_transaction_date,
            new.change_date         effective_date,
            nvl((
                SELECT
                    description
                FROM
                    fnd_user fu
                WHERE
                    fu.user_id = new.last_updated_by
            ),
                (
                SELECT
                    user_name
                FROM
                    fnd_user fu
                WHERE
                    fu.user_id = new.last_updated_by
            ))                      updated_by,
            (
                SELECT
                    p3.employee_number
                FROM
                    per_all_people_f p3
                WHERE
                        ROWNUM = 1
                    AND p3.person_id = (
                        SELECT DISTINCT
                            fu.employee_id
                        FROM
                            apps.fnd_user fu
                        WHERE
                 --old.employee_id=new.employee_id
                                fu.user_id = new.last_updated_by
                            AND ROWNUM = 1
                    )
            )                       last_updt_by_oracle_id
        FROM
            per_all_people_f             papf,
            per_pay_proposals            old,
            per_pay_proposals            new,
            per_all_assignments_f        paaf,
            per_periods_of_service       pps,
            hr_all_organization_units    haou,
            hr_locations                 hl,
            per_business_groups          pbg,
            per_assignment_status_types  past,
            ttec_emp_proj_asg            tepa
        WHERE
                1 = 1
            AND papf.person_id = pps.person_id
            AND papf.person_id = paaf.person_id
            AND haou.organization_id = paaf.organization_id
            AND hl.location_id = paaf.location_id
            AND pbg.business_group_id = paaf.business_group_id
            AND paaf.assignment_status_type_id = past.assignment_status_type_id
            AND papf.employee_number = tepa.employee_number
            AND old.assignment_id = new.assignment_id
            AND paaf.assignment_id = new.assignment_id
            AND paaf.assignment_id = new.assignment_id
            AND trunc(sysdate) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
            AND trunc(old.date_to) + 1 = trunc(new.change_date)
            AND old.pay_proposal_id != new.pay_proposal_id
            AND trunc(sysdate) BETWEEN tepa.prj_strt_dt AND tepa.prj_end_dt
            AND ( pps.actual_termination_date IS NULL
                  OR pps.actual_termination_date > sysdate )
            AND trunc(sysdate) BETWEEN papf.effective_start_date AND papf.effective_end_date
            AND new.last_update_date BETWEEN to_date(p_start_date, 'YYYY/MM/DD HH24:MI:SS') AND to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS')
        ORDER BY
            new.last_update_date ASC;

-------------------- CURSOR salary_changes End -------------------------------------------------

-------------------- CURSOR termination_changes Start -------------------------------------------------


        CURSOR termination_changes (
            p_start_date  IN VARCHAR2,
            p_end_date    IN VARCHAR2
        ) IS
        SELECT --pps.actual_termination_date,tepa.PRJ_END_DT,tket.NEW_TERM_DATE,tket.person_id,--old.PAY_PROPOSAL_ID,old.PROPOSED_SALARY_N,old.DATE_TO,new.PAY_PROPOSAL_ID,new.PROPOSED_SALARY_N,new.CHANGE_DATE,
            papf.employee_number    oracle_id,
            papf.last_name,
            papf.first_name,
            pps.date_start          hire_date,
            paaf.organization_id    organization_code,
            haou.name               organization_name,
            paaf.location_id,
            hl.location_code        location_name,
            hl.country              country_code,
            tepa.clt_cd             gl_client_code,
            tepa.client_desc        gl_client_name,
            tepa.prog_cd            program_code,
            tepa.program_desc       program_name,
            tepa.prj_cd             project_code,
            tepa.project_desc       project_name,
            (
                SELECT
                    substr(MAX(name), 1, instr(MAX(name), '.') - 1)
                FROM
                    per_jobs pj
                WHERE
                    pj.job_id = paaf.job_id
            )                       job_code,
            (
                SELECT
                    substr(MAX(name), instr(MAX(name), '.', 1) + 1)
                FROM
                    per_jobs pj
                WHERE
                    pj.job_id = paaf.job_id
            )                       job_title,
            (
                SELECT
                    attribute5
                FROM
                    per_jobs pj
                WHERE
                    pj.job_id = paaf.job_id
            )                       job_family,
            (
                SELECT
                    attribute20
                FROM
                    per_jobs pj
                WHERE
                    pj.job_id = paaf.job_id
            )                       gca_level,
            paaf.ass_attribute22    work_arrangement_type,
            past.user_status        assignment_status,
            (
                SELECT
                    p1.employee_number
                FROM
                    per_all_people_f p1
                WHERE
                        p1.person_id = paaf.supervisor_id
                    AND trunc(sysdate) BETWEEN p1.effective_start_date AND p1.effective_end_date
            )                       supervisor_id,
            (
                SELECT
                    full_name
                FROM
                    per_all_people_f p1
                WHERE
                        p1.person_id = paaf.supervisor_id
                 --   AND trunc(sysdate) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
                    AND trunc(sysdate) BETWEEN p1.effective_start_date AND p1.effective_end_date
            )                       supv_full_name,
            tket.creation_date      oracle_transaction_date,
            tket.new_term_date      effective_date,
            nvl((
                SELECT
                    description
                FROM
                    fnd_user fu
                WHERE
                    fu.user_id = tket.created_by
            ),
                (
                SELECT
                    user_name
                FROM
                    fnd_user fu
                WHERE
                    fu.user_id = tket.created_by
            ))                      updated_by,
            (
                SELECT
                    p3.employee_number
                FROM
                    per_all_people_f p3
                WHERE
                        ROWNUM = 1
                    AND p3.person_id = (
                        SELECT DISTINCT
                            fu.employee_id
                        FROM
                            apps.fnd_user fu
                        WHERE
                 --old.employee_id=new.employee_id
                                fu.user_id = tket.last_updated_by
                            AND ROWNUM = 1
                    )
            )                       last_updt_by_oracle_id,
            (
                SELECT
                    attribute3
                FROM
                    apps.fnd_lookup_values flv1
                WHERE
                        flv1.lookup_type = 'LEAV_REAS'
                    AND flv1.end_date_active IS NULL
                    AND flv1.enabled_flag = 'Y'
                    AND flv1.attribute_category = 'LEAV_REAS'
                    AND flv1.security_group_id = pbg.security_group_id
                    AND flv1.language = 'US'
                    AND flv1.lookup_code = pps.leaving_reason
            )                       voluntary_non_val,
            (
                SELECT
                    meaning
                FROM
                    apps.fnd_lookup_values flv1
                WHERE
                        flv1.lookup_type = 'LEAV_REAS'
                    AND flv1.end_date_active IS NULL
                    AND flv1.enabled_flag = 'Y'
                    AND flv1.attribute_category = 'LEAV_REAS'
                    AND flv1.security_group_id = pbg.security_group_id
                    AND flv1.language = 'US'
                    AND flv1.lookup_code = pps.leaving_reason
            )                       leaving_reason
        FROM
            per_all_people_f             papf,
            per_all_assignments_f        paaf,
            per_periods_of_service       pps,
            hr_all_organization_units    haou,
            hr_locations                 hl,
            per_business_groups          pbg,
            per_assignment_status_types  past,
            ttec_emp_proj_asg            tepa,
            --cust.ttec_kr_emp_terms       tket				-- Commented code by IXPRAVEEN-ARGANO,18-May-2023		
            apps.ttec_kr_emp_terms       tket               --  code Added by IXPRAVEEN-ARGANO,   18-May-2023
        WHERE
                1 = 1
            AND papf.person_id = tket.person_id
            AND papf.person_id = pps.person_id
            AND papf.person_id = paaf.person_id
            AND haou.organization_id = paaf.organization_id
            AND hl.location_id = paaf.location_id
            AND pbg.business_group_id = paaf.business_group_id
            AND paaf.assignment_status_type_id = past.assignment_status_type_id
            AND papf.employee_number = tepa.employee_number
            AND trunc(pps.actual_termination_date) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
            AND trunc(pps.actual_termination_date) = trunc(tket.new_term_date)
            AND trunc(pps.actual_termination_date) = (
                SELECT
                    MAX(pps2.actual_termination_date)
                FROM
                    per_periods_of_service pps2
                WHERE
                    pps.person_id = pps2.person_id
            )
            AND trunc(tepa.prj_end_dt) = (
                SELECT
                    MAX(tepa2.prj_end_dt)
                FROM
                    ttec_emp_proj_asg tepa2
                WHERE
                    tepa2.employee_number = tepa.employee_number
            )
--and trunc(pps.actual_termination_date)=trunc(tepa.PRJ_END_DT)
            AND trunc(pps.actual_termination_date) BETWEEN papf.effective_start_date AND papf.effective_end_date
            AND pps.actual_termination_date IS NOT NULL
            AND tket.creation_date BETWEEN to_date(p_start_date, 'YYYY/MM/DD HH24:MI:SS') AND to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS')
        ORDER BY
            tket.creation_date ASC;

-------------------- CURSOR termination_changes End -------------------------------------------------

    BEGIN
        EXECUTE IMMEDIATE 'truncate table apps.ttec_backdated_changes_stg';
        FOR promotion_rec IN promotion_changes(p_start_date, p_end_date) LOOP
            IF promotion_changes%rowcount > 0 THEN
                INSERT INTO apps.ttec_backdated_changes_stg VALUES (
                    promotion_rec.oracle_id,
                    promotion_rec.last_name,
                    promotion_rec.first_name,
                    promotion_rec.hire_date,
                    promotion_rec.organization_code,
                    promotion_rec.organization_name,
                    promotion_rec.location_id,
                    promotion_rec.location_name,
                    promotion_rec.country_code,
                    promotion_rec.gl_client_code,
                    promotion_rec.gl_client_name,
                    promotion_rec.program_code,
                    promotion_rec.program_name,
                    promotion_rec.project_code,
                    promotion_rec.project_name,
                    promotion_rec.job_code,
                    promotion_rec.job_title,
                    promotion_rec.job_family,
                    promotion_rec.gca_level,
                    promotion_rec.work_arrangement_type,
                    promotion_rec.assignment_status,
                    promotion_rec.supv_full_name,
                    NULL,
                    NULL,
                    NULL,
                    NULL,
                    promotion_rec.oracle_transaction_date,
                    promotion_rec.effective_date,
                    promotion_rec.updated_by,
                    'Promotion change',
                    NULL,
                    promotion_rec.supervisor_id,
                    promotion_rec.last_updt_by_oracle_id,
                    NULL,
                    NULL
                );

            END IF;
        END LOOP;

        FOR location_rec IN location_changes(p_start_date, p_end_date) LOOP
            IF location_changes%rowcount > 0 THEN
                INSERT INTO apps.ttec_backdated_changes_stg VALUES (
                    location_rec.oracle_id,
                    location_rec.last_name,
                    location_rec.first_name,
                    location_rec.hire_date,
                    location_rec.organization_code,
                    location_rec.organization_name,
                    location_rec.location_id,
                    location_rec.location_name,
                    location_rec.country_code,
                    location_rec.gl_client_code,
                    location_rec.gl_client_name,
                    location_rec.program_code,
                    location_rec.program_name,
                    location_rec.project_code,
                    location_rec.project_name,
                    location_rec.job_code,
                    location_rec.job_title,
                    location_rec.job_family,
                    location_rec.gca_level,
                    location_rec.work_arrangement_type,
                    location_rec.assignment_status,
                    location_rec.supv_full_name,
                    NULL,
                    NULL,
                    NULL,
                    NULL,
                    location_rec.oracle_transaction_date,
                    location_rec.effective_date,
                    location_rec.updated_by,
                    'Location change',
                    NULL,
                    location_rec.supervisor_id,
                    location_rec.last_updt_by_oracle_id,
                    NULL,
                    NULL
                );

            END IF;
        END LOOP;

        FOR work_arrangement_rec IN work_arrangement_changes(p_start_date, p_end_date) LOOP
            IF work_arrangement_changes%rowcount > 0 THEN
                INSERT INTO apps.ttec_backdated_changes_stg VALUES (
                    work_arrangement_rec.oracle_id,
                    work_arrangement_rec.last_name,
                    work_arrangement_rec.first_name,
                    work_arrangement_rec.hire_date,
                    work_arrangement_rec.organization_code,
                    work_arrangement_rec.organization_name,
                    work_arrangement_rec.location_id,
                    work_arrangement_rec.location_name,
                    work_arrangement_rec.country_code,
                    work_arrangement_rec.gl_client_code,
                    work_arrangement_rec.gl_client_name,
                    work_arrangement_rec.program_code,
                    work_arrangement_rec.program_name,
                    work_arrangement_rec.project_code,
                    work_arrangement_rec.project_name,
                    work_arrangement_rec.job_code,
                    work_arrangement_rec.job_title,
                    work_arrangement_rec.job_family,
                    work_arrangement_rec.gca_level,
                    work_arrangement_rec.work_arrangement_type,
                    work_arrangement_rec.assignment_status,
                    work_arrangement_rec.supv_full_name,
                    NULL,
                    NULL,
                    NULL,
                    NULL,
                    work_arrangement_rec.oracle_transaction_date,
                    work_arrangement_rec.effective_date,
                    work_arrangement_rec.updated_by,
                    'Work Arrangement Change',
                    NULL,
                    work_arrangement_rec.supervisor_id,
                    work_arrangement_rec.last_updt_by_oracle_id,
                    NULL,
                    NULL
                );

            END IF;
        END LOOP;

        FOR salary_rec IN salary_changes(p_start_date, p_end_date) LOOP
            IF salary_changes%rowcount > 0 THEN
                INSERT INTO apps.ttec_backdated_changes_stg VALUES (
                    salary_rec.oracle_id,
                    salary_rec.last_name,
                    salary_rec.first_name,
                    salary_rec.hire_date,
                    salary_rec.organization_code,
                    salary_rec.organization_name,
                    salary_rec.location_id,
                    salary_rec.location_name,
                    salary_rec.country_code,
                    salary_rec.gl_client_code,
                    salary_rec.gl_client_name,
                    salary_rec.program_code,
                    salary_rec.program_name,
                    salary_rec.project_code,
                    salary_rec.project_name,
                    salary_rec.job_code,
                    salary_rec.job_title,
                    salary_rec.job_family,
                    salary_rec.gca_level,
                    salary_rec.work_arrangement_type,
                    salary_rec.assignment_status,
                    salary_rec.supv_full_name,
                    NULL,
                    NULL,
                    NULL,
                    NULL,
                    salary_rec.oracle_transaction_date,
                    salary_rec.effective_date,
                    salary_rec.updated_by,
                    'Salary change',
                    NULL,
                    salary_rec.supervisor_id,
                    salary_rec.last_updt_by_oracle_id,
                    NULL,
                    NULL
                );

            END IF;
        END LOOP;

        FOR termination_rec IN termination_changes(p_start_date, p_end_date) LOOP
            IF termination_changes%rowcount > 0 THEN
                INSERT INTO apps.ttec_backdated_changes_stg VALUES (
                    termination_rec.oracle_id,
                    termination_rec.last_name,
                    termination_rec.first_name,
                    termination_rec.hire_date,
                    termination_rec.organization_code,
                    termination_rec.organization_name,
                    termination_rec.location_id,
                    termination_rec.location_name,
                    termination_rec.country_code,
                    termination_rec.gl_client_code,
                    termination_rec.gl_client_name,
                    termination_rec.program_code,
                    termination_rec.program_name,
                    termination_rec.project_code,
                    termination_rec.project_name,
                    termination_rec.job_code,
                    termination_rec.job_title,
                    termination_rec.job_family,
                    termination_rec.gca_level,
                    termination_rec.work_arrangement_type,
                    termination_rec.assignment_status,
                    termination_rec.supv_full_name,
                    NULL,
                    NULL,
                    NULL,
                    NULL,
                    termination_rec.oracle_transaction_date,
                    termination_rec.effective_date,
                    termination_rec.updated_by,
                    'Terminated',
                    NULL,
                    termination_rec.supervisor_id,
                    termination_rec.last_updt_by_oracle_id,
                    termination_rec.voluntary_non_val,
                    termination_rec.leaving_reason
                );

            END IF;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN no_data_found THEN
            fnd_file.put_line(fnd_file.log, 'No data' || sqlerrm);
        WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log, 'other error' || sqlerrm);
    END;

    PROCEDURE csv_generation (
        errbuf              OUT  VARCHAR2,
        retcode             OUT  NUMBER,
        p_output_directory  IN   VARCHAR2
    ) AS

        v_text               VARCHAR(32765) DEFAULT '';
        v_text2              VARCHAR(32765) DEFAULT '';
        v_emp_file           utl_file.file_type;
        v_file_extn          VARCHAR2(200) DEFAULT '';
        v_instance_name      VARCHAR2(250);
        v_out_file           VARCHAR2(32000);
        v_time               VARCHAR2(20);
        v_dt_time            VARCHAR2(15);
        v_dir_path           VARCHAR2(250);
        l_host_name          v$instance.host_name%TYPE;
        l_instance_name      v$instance.instance_name%TYPE;
        l_identifier         VARCHAR2(10);
        v_count_utl          NUMBER;
        l_transaction_date1  DATE;
        l_effective_date1    DATE;
        l_transaction_date2  DATE;
        l_effective_date2    DATE;
        l_compliance         VARCHAR2(250);
        CURSOR staging_table IS
        SELECT
            *
        FROM
            apps.ttec_backdated_changes_stg
        WHERE
            1 = 1
        ORDER BY
            transaction_type DESC;

        CURSOR c_compliance IS
        SELECT
            oracle_transaction_date,
            effective_date
        FROM
            apps.ttec_backdated_changes_stg
        WHERE
            trunc(oracle_transaction_date) <= trunc(effective_date);

        CURSOR c_non_compliance IS
        SELECT
            oracle_transaction_date,
            effective_date
        FROM
            apps.ttec_backdated_changes_stg
        WHERE
            trunc(oracle_transaction_date) > trunc(effective_date);

        CURSOR c_host IS
        SELECT
            host_name,
            instance_name
        FROM
            v$instance;

    BEGIN
        fnd_file.put_line(fnd_file.log, 'Inside the v_dt_time');
        SELECT
            to_char(sysdate, 'yyyymmddHHMISS')
        INTO v_dt_time
        FROM
            dual;

        fnd_file.put_line(fnd_file.log, 'Inside the v_dir_path');
        SELECT
            directory_path || '/data/EBS/HC/HR/awardco/outbound'
        INTO v_dir_path
        FROM
            dba_directories
        WHERE
            directory_name = 'CUST_TOP';

        fnd_file.put_line(fnd_file.log, 'Inside the instance name');
        SELECT
            instance_name
        INTO v_instance_name
        FROM
            v$instance;

        BEGIN
            fnd_file.put_line(fnd_file.log, 'Inside the v_file_extn');
            SELECT
                '.csv'
            INTO v_file_extn
            FROM
                v$instance;

        EXCEPTION
            WHEN OTHERS THEN
                v_file_extn := '.csv';
        END;

        BEGIN

    /*<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
            OPEN c_host;
            FETCH c_host INTO
                l_host_name,
                l_instance_name;
            CLOSE c_host;
            IF l_host_name NOT IN ( ttec_library.xx_ttec_prod_host_name ) THEN
                l_identifier := 'TEST_TTEC_';  --changes 2.0
      --changes 1.1
            ELSE
                l_identifier := 'TTEC_'; --changes 2.0
            END IF;

            OPEN c_compliance;
            FETCH c_compliance INTO
                l_transaction_date1,
                l_effective_date1;
            CLOSE c_compliance;
			--Loop
            IF trunc(l_transaction_date1) <= trunc(l_effective_date1) THEN
                UPDATE apps.ttec_backdated_changes_stg
                SET
                    compliance = 'Compliance'
                WHERE
                    trunc(oracle_transaction_date) <= trunc(effective_date);					--changes 2.0
      --changes 1.1
            ELSE
                UPDATE apps.ttec_backdated_changes_stg
                SET
                    compliance = 'Non-Compliance'
                WHERE
                    trunc(oracle_transaction_date) > trunc(effective_date); --changes 2.0
            END IF;
         --  End Loop;

            OPEN c_non_compliance;
            FETCH c_non_compliance INTO
                l_transaction_date2,
                l_effective_date2;
            CLOSE c_non_compliance;
			--Loop
            IF trunc(l_transaction_date2) > trunc(l_effective_date2) THEN
                UPDATE apps.ttec_backdated_changes_stg
                SET
                    compliance = 'Non-Compliance'
                WHERE
                    trunc(oracle_transaction_date) > trunc(effective_date);					--changes 2.0
      --changes 1.1
            ELSE
                UPDATE apps.ttec_backdated_changes_stg
                SET
                    compliance = 'Compliance'
                WHERE
                    trunc(oracle_transaction_date) <= trunc(effective_date); --changes 2.0
            END IF;

            fnd_file.put_line(fnd_file.log, 'Host Name:');
            BEGIN
                SELECT
                    '.csv',
                    to_char(sysdate, 'yyyymmdd_HHMISS') -- ,TO_CHAR (SYSDATE, 'yyyymmdd_HH24MI')
                INTO
                    v_file_extn,
                    v_time
                FROM
                    v$instance;

            EXCEPTION
                WHEN OTHERS THEN
                    v_file_extn := '.csv';
            END;

            fnd_file.put_line(fnd_file.log, 'extension name:');
            v_out_file := l_identifier
                          || 'Backdated_R12_'
                          || v_time
                          || '.csv';  --changes 2.0
            fnd_file.put_line(fnd_file.log, 'FILE name:');
   -- v_asn_life_file_type     := UTL_FILE.FOPEN (p_output_directory, l_asn_life_active_file, 'w', 32765);

   /* <<<<<<<<<<<<<<<<<<<<<<<<<<*/



            v_count_utl := 0;
            fnd_file.put_line(fnd_file.log, 'Extension name:' || v_file_extn);
       /* v_out_file := 'ttec_perceptadata_ora_to_awardco_'
                      || v_dt_time
                      || v_file_extn;*/
            fnd_file.put_line(fnd_file.log, 'FILE name:' || v_out_file);
            v_emp_file := utl_file.fopen(p_output_directory, v_out_file, 'w', 32000);
            dbms_output.put_line('Before Opening UTL File');
  --  v_utlfile := utl_file.fopen(p_directory_name, v_filename, 'W');
            utl_file.put_line(v_emp_file,('Employee Id')
                                         || '|'
                                         ||('Last Name')
                                         || '|'
                                         ||('First Name')
                                         || '|'
                                         ||('Hire Date')
                                         || '|'
                                         ||('Organization Code')
                                         || '|'
                                         ||('Organization Name')
                                         || '|'
                                         ||('Location ID')
                                         || '|'
                                         ||('Location Name')
                                         || '|'
                                         ||('Country Code')
                                         || '|'
                                         ||('GL Client Code')
                                         || '|'
                                         ||('GL Client Name')
                                         || '|'
                                         ||('Program Code')
                                         || '|'
                                         ||('Program Name')
                                         || '|'
                                         ||('Project Code')
                                         || '|'
                                         ||('Project Name')
                                         || '|'
                                         ||('Job Code')
                                         || '|'
                                         ||('Job Title')
                                         || '|'
                                         ||('Job Family')
                                         || '|'
                                         ||('GCA Level')
                                         || '|'
                                         ||('Work Arrangement Type')
                                         || '|'
                                         ||('Assignment Status')
                                         || '|'
                                         ||('Supervisor Oracle ID')
                                         || '|'
                                         ||('Supervisor Name')
                                         || '|'
                                         ||('Transaction Type')
                                         || '|'
                                         ||('Oracle Transaction Date')
                                         || '|'
                                         ||('Effective Date')
                                         || '|'
                                         ||('Updated By Oracle ID')
                                         || '|'
                                         ||('Updated By')
                                         || '|'
                                         ||('Compliance/Non-Compliance')
                                         || '|'
                                         ||('Voluntary/Involuntary')
                                         || '|'
                                         ||('Termination Reason'));

            v_text := ( ( 'Employee Id' )
                        || '|'
                        || ( 'Last Name' )
                        || '|'
                        || ( 'First Name' )
                        || '|'
                        || ( 'Hire Date' )
                        || '|'
                        || ( 'Organization Code' )
                        || '|'
                        || ( 'Organization Name' )
                        || '|'
                        || ( 'Location ID' )
                        || '|'
                        || ( 'Location Name' )
                        || '|'
                        || ( 'Country Code' )
                        || '|'
                        || ( 'GL Client Code' )
                        || '|'
                        || ( 'GL Client Name' )
                        || '|'
                        || ( 'Program Code' )
                        || '|'
                        || ( 'Program Name' )
                        || '|'
                        || ( 'Project Code' )
                        || '|'
                        || ( 'Project Name' )
                        || '|'
                        || ( 'Job Code' )
                        || '|'
                        || ( 'Job Title' )
                        || '|'
                        || ( 'Job Family' )
                        || '|'
                        || ( 'GCA Level' )
                        || '|'
                        || ( 'Work Arrangement Type' )
                        || '|'
                        || ( 'Assignment Status' )
                        || '|'
                        || ( 'Supervisor Oracle ID' )
                        || '|'
                        || ( 'Supervisor Name' )
                        || '|'
                        || ( 'Transaction Type' )
                        || '|'
                        || ( 'Oracle Transaction Date' )
                        || '|'
                        || ( 'Effective Date' )
                        || '|'
                        || ( 'Updated By Oracle ID' )
                        || '|'
                        || ( 'Updated By' )
                        || '|'
                        || ( 'Compliance/Non-Compliance' )
                        || '|'
                        || ( 'Voluntary/Involuntary' )
                        || '|'
                        || ( 'Termination Reason' ) );

            fnd_file.put_line(fnd_file.output, v_text);
            FOR c1 IN staging_table LOOP
                utl_file.put_line(v_emp_file,(c1.oracle_id)
                                             || '|'
                                             || replace((c1.last_name), ',', '')
                                             || '|'
                                             || replace((c1.first_name), ',', '')
                                             || '|'
                                             ||(c1.hire_date)
                                             || '|'
                                             ||(c1.organization_code)
                                             || '|'
                                             || replace((c1.organization_name), ',', '')
                                             || '|'
                                             ||(c1.location_id)
                                             || '|'
                                             || replace((c1.location_name), ',', '')
                                             || '|'
                                             ||(c1.country_code)
                                             || '|'
                                             ||(c1.gl_client_code)
                                             || '|'
                                             || replace((c1.gl_client_name), ',', '')
                                             || '|'
                                             ||(c1.program_code)
                                             || '|'
                                             || replace((c1.program_name), ',', '')
                                             || '|'
                                             ||(c1.project_code)
                                             || '|'
                                             || replace((c1.project_name), ',', '')
                                             || '|'
                                             || replace((c1.job_code), ',', '')
                                             || '|'
                                             || replace((c1.job_title), ',', '')
                                             || '|'
                                             || replace((c1.job_family), ',', '')
                                             || '|'
                                             || replace((c1.gca_level), ',', '')
                                             || '|'
                                             || replace((c1.work_arrangement_type), ',', '')
                                             || '|'
                                             || replace((c1.assinment_status), ',', '')
                                             || '|'
                                             || replace((c1.supervisor_id), ',', '')
                                             || '|'
                                             || replace((c1.supv_full_name), ',', '')
                                             || '|'
                                             || replace((c1.transaction_type), ',', '')
                                             || '|'
                                             ||(c1.oracle_transaction_date)
                                             || '|'
                                             ||(c1.effective_date)
                                             || '|'
                                             || replace((c1.last_updt_by_oracle_id), ',', '')
                                             || '|'
                                             || replace((c1.updated_by), ',', '')
                                             || '|'
                                             || replace((c1.compliance), ',', '')
                                             || '|'
                                             || replace((c1.voluntary_non_val), ',', '')
                                             || '|'
                                             || replace((c1.leaving_reason), ',', ''));

                v_text2 := ( ( c1.oracle_id )
                             || '|'
                             || replace((c1.last_name), ',', '')
                             || '|'
                             || replace((c1.first_name), ',', '')
                             || '|'
                             || ( c1.hire_date )
                             || '|'
                             || ( c1.organization_code )
                             || '|'
                             || replace((c1.organization_name), ',', '')
                             || '|'
                             || ( c1.location_id )
                             || '|'
                             || replace((c1.location_name), ',', '')
                             || '|'
                             || ( c1.country_code )
                             || '|'
                             || ( c1.gl_client_code )
                             || '|'
                             || replace((c1.gl_client_name), ',', '')
                             || '|'
                             || ( c1.program_code )
                             || '|'
                             || replace((c1.program_name), ',', '')
                             || '|'
                             || ( c1.project_code )
                             || '|'
                             || replace((c1.project_name), ',', '')
                             || '|'
                             || replace((c1.job_code), ',', '')
                             || '|'
                             || replace((c1.job_title), ',', '')
                             || '|'
                             || replace((c1.job_family), ',', '')
                             || '|'
                             || replace((c1.gca_level), ',', '')
                             || '|'
                             || replace((c1.work_arrangement_type), ',', '')
                             || '|'
                             || replace((c1.assinment_status), ',', '')
                             || '|'
                             || replace((c1.supervisor_id), ',', '')
                             || '|'
                             || replace((c1.supv_full_name), ',', '')
                             || '|'
                             || replace((c1.transaction_type), ',', '')
                             || '|'
                             || ( c1.oracle_transaction_date )
                             || '|'
                             || ( c1.effective_date )
                             || '|'
                             || replace((c1.last_updt_by_oracle_id), ',', '')
                             || '|'
                             || replace((c1.updated_by), ',', '')
                             || '|'
                             || replace((c1.compliance), ',', '')
                             || '|'
                             || replace((c1.voluntary_non_val), ',', '')
                             || '|'
                             || replace((c1.leaving_reason), ',', '') );

                fnd_file.put_line(fnd_file.output, v_text2);
            END LOOP;

            dbms_output.put_line('..After Cursor cur_vendor');
            utl_file.fclose(v_emp_file);
        EXCEPTION
            WHEN utl_file.invalid_path THEN
                dbms_output.put_line('employee_extract-Invalid Output Path: '
                                     || ' - '
                                     || sqlcode
                                     || ' - '
                                     || sqlerrm);

                dbms_output.put_line(' No OutPut File is Generated..... ');
                utl_file.fclose(v_emp_file);
            WHEN utl_file.invalid_mode THEN
                dbms_output.put_line('employee_extract-INVALID_MODE: '
                                     || sqlcode
                                     || ' - '
                                     || sqlerrm);
                dbms_output.put_line(' No OutPut File is Generated..... ');
                utl_file.fclose(v_emp_file);
            WHEN utl_file.invalid_filehandle THEN
                dbms_output.put_line('employee_extract-INVALID_FILEHANDLE: '
                                     || sqlcode
                                     || ' - '
                                     || sqlerrm);
                dbms_output.put_line(' No OutPut File is Generated..... ');
                utl_file.fclose(v_emp_file);
            WHEN utl_file.invalid_operation THEN
                dbms_output.put_line('employee_extract-INVALID_OPERATION: '
                                     || sqlcode
                                     || ' - '
                                     || sqlerrm);
                dbms_output.put_line(' No OutPut File is Generated..... ');
                utl_file.fclose(v_emp_file);
            WHEN utl_file.write_error THEN
                dbms_output.put_line('employee_extract-An error occured writing data into output file: '
                                     || sqlcode
                                     || ' - '
                                     || sqlerrm);
                dbms_output.put_line(' No OutPut File is Generated..... ');
                utl_file.fclose(v_emp_file);
            WHEN OTHERS THEN
                dbms_output.put_line('Unexpected Error in Procedure XX_SUPP_DEMO_EXTRACT_PKG'
                                     || ' - '
                                     || sqlerrm);
                utl_file.fclose(v_emp_file);
        END;

    END csv_generation;

END ttec_backdated_change_pkg;
/
show errors;
/