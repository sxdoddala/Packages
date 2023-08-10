create or replace PACKAGE BODY      TTEC_PHL_BEN_ELECTION_COMP_RPT AS
  /*
  -------------------------------------------------------------

  Program Name    : TTEC BENEFIT ELECTION COMPARISON REPORT

  Desciption      : FOR PHL BUSINESS GROUPS

  Input/Output Parameters

  Called From     :


  Created By      : Hari Varma
  Date            : 10-16-19

  Modification Log:
  -----------------
  Developer             Date        Description

  Hari Varma             10-16-19      Created
  
  MXKEERTHI(ARGANO)       03-May-2023    1.0            R12.2 Upgrade Remediation

  --------------------------------------------------------------- */

    g_user_id               NUMBER := to_number(fnd_profile.value('USER_ID') );
    g_conc_request_id       NUMBER := fnd_global.conc_request_id;

    PROCEDURE phl_benefit_election_emp (
        errbuff               IN OUT NOCOPY VARCHAR2,
        retcode               IN OUT NOCOPY NUMBER,
        p_business_group_id   IN NUMBER,
        p_comparison_year     IN VARCHAR2
    ) IS

        r_curr                  apps.ttec_phl_ben_current_intf_stg%rowtype;
        r_compyr                apps.ttec_phl_ben_compyr_intf_stg%rowtype;
        CURSOR csr_emp_rec (
            p_cut_off_date       DATE,
            p_current_run_date   DATE
        ) IS
            SELECT DISTINCT
                pap.person_id,
                pap.employee_number "EMP_NUM",
                pap.full_name "EMP_NAME",
                (
                    SELECT
                        pps.date_start
                    FROM
                        apps.per_periods_of_service pps
                    WHERE
                            pps.business_group_id = pap.business_group_id
                        AND
                            pps.person_id = pap.person_id
                        AND
                            fnd_date.canonical_to_date(p_current_run_date) BETWEEN pps.date_start AND nvl(
                                pps.actual_termination_date,
                                TO_DATE('31-Dec-4712','DD-Mon-RRRR')
                            )
                ) "HIRE_DATE",
                pap.start_date o_hire_date,
                ppb.name pay_basis_name,
                job.attribute6 manager_level,
                hrl.location_code "LOCATION",
                'Self' "TYPE",
                'Self' "COVERED_PERSON",
                pap.national_identifier,
                nvl(
                    amdtl.user_status,
                    sttl.user_status
                ) "ASG_STATUS",
                pap.date_of_birth "DATE_OF_BIRTH",
                trunc(
                    months_between(
                        p_current_run_date,
                        pap.date_of_birth
                    ) / 12,
                    2
                ) "AGE",
                hr_general.decode_lookup(
                    'MAR_STATUS',
                    pap.marital_status
                ) marital_status,
                hr_general.decode_lookup(
                    'EMP_CAT',
                    paa.employment_category
                ) employment_category,
                grp.name benefits_group,
                sup.full_name sup_name,
                sup.employee_number sup_emp_num,
                sup.email_address sup_email_addr,
                job.attribute5 emp_job_family,
                pap.sex emp_gender,
                ppb.name emp_pay_basis,
                paa.assignment_id assignment_id
            FROM
			     --START R12.2 Upgrade Remediation
	  /*
		Commented code by MXKEERTHI-ARGANO, 05/03/2023
                hr.per_all_people_f pap,
                hr.hr_locations_all hrl,
                hr.per_all_assignments_f paa,
                hr.per_pay_bases ppb,
                hr.per_jobs job,
                hr.per_ass_status_type_amends_tl amdtl,
                hr.per_assignment_status_types_tl sttl,
                hr.per_assignment_status_types st,
                hr.per_ass_status_type_amends amd,
                per_all_people_f sup,
                ben.ben_benfts_grp grp
	   */
	  --code Added  by MXKEERTHI-ARGANO, 05/03/2023
	            APPS.per_all_people_f pap,
                APPS.hr_locations_all hrl,
                APPS.per_all_assignments_f paa,
                APPS.per_pay_bases ppb,
                APPS.per_jobs job,
                APPS.per_ass_status_type_amends_tl amdtl,
                APPS.per_assignment_status_types_tl sttl,
                APPS.per_assignment_status_types st,
                APPS.per_ass_status_type_amends amd,
                per_all_people_f sup,
                APPS.ben_benfts_grp grp
	  --END R12.2.10 Upgrade remediation
                
            WHERE
                    1 = 1
         -- and pap.employee_number in ('2000084','2000244','2000281','2001025','2013336','2012183','2030769')
                AND
                    paa.assignment_status_type_id = st.assignment_status_type_id
                AND
                    paa.assignment_status_type_id = amd.assignment_status_type_id (+)
                AND
                    paa.business_group_id + 0 = amd.business_group_id (+) + 0
                AND
                    st.assignment_status_type_id = sttl.assignment_status_type_id
                AND
                    sttl.language = userenv('LANG')
                AND
                    amd.ass_status_type_amend_id = amdtl.ass_status_type_amend_id (+)
                AND
                    DECODE(
                        amdtl.ass_status_type_amend_id,
                        NULL,
                        '1',
                        amdtl.language
                    ) = DECODE(
                        amdtl.ass_status_type_amend_id,
                        NULL,
                        '1',
                        userenv('LANG')
                    )
                AND
                    ppb.pay_basis_id = paa.pay_basis_id
                AND
                    job.job_id = paa.job_id
                AND
                    pap.person_id = paa.person_id
                AND
                    paa.location_id = hrl.location_id
                AND
                    pap.business_group_id = p_business_group_id
                AND
                    pap.current_employee_flag = 'Y'
                AND
                    paa.primary_flag = 'Y'
                AND
                    p_current_run_date BETWEEN pap.effective_start_date (+) AND pap.effective_end_date (+)
                AND
                    p_current_run_date BETWEEN paa.effective_start_date AND paa.effective_end_date
                AND
                    sup.person_id = paa.supervisor_id (+)
                AND
                    p_current_run_date BETWEEN sup.effective_start_date AND sup.effective_end_date
                AND
                    grp.business_group_id (+) = pap.business_group_id
                AND
                    grp.benfts_grp_id (+) = pap.benefit_group_id
                AND
                    pap.person_id IN (
                        SELECT
                            person_id
                        FROM
                            per_periods_of_service ppos
                        WHERE
                                business_group_id = p_business_group_id
                            AND (
                                (
                                        trunc(ppos.last_update_date) BETWEEN p_cut_off_date AND p_current_run_date
                                    AND
                                        ppos.actual_termination_date IS NOT NULL
                                ) OR (
                                        ppos.actual_termination_date IS NULL
                                    AND
                                        ppos.person_id IN (
                                            SELECT DISTINCT
                                                person_id
                                            FROM
                                                per_all_people_f papf
                                            WHERE
                                                papf.current_employee_flag = 'Y'
                                        )
                                ) OR (
                                        ppos.actual_termination_date = (
                                            SELECT
                                                MAX(actual_termination_date)
                                            FROM
                                                per_periods_of_service
                                            WHERE
                                                    person_id = ppos.person_id
                                                AND
                                                    actual_termination_date IS NOT NULL
                                        )
                                    AND
                                        ppos.actual_termination_date >= p_cut_off_date
                                )
                            )
                    );

        CURSOR csr_plan_names IS
            SELECT
                a.name plan_name,
                a.pl_id
            FROM
			    -- ben.ben_pl_f a --Commented code by MXKEERTHI-ARGANO, 05/03/2023
                APPS.ben_pl_f a-- code added by MXKEERTHI-ARGANO, 05/03/2023
                
            WHERE
                    business_group_id = p_business_group_id
                AND
                    pl_stat_cd = 'A'
                AND
                    a.effective_start_date = (
                        SELECT
                            MAX(b.effective_start_date)
                        FROM
                            ben_pl_f b
                        WHERE
                            a.pl_id = b.pl_id
                    )
                AND
                    pl_stat_cd = 'A'
            ORDER BY a.name;

        CURSOR csr_ben_info (
            p_person_id       IN NUMBER,
            p_sel_pl_id       IN NUMBER,
            p_coverage_date   IN DATE
        ) IS
            SELECT
                pen.enrt_cvg_strt_dt,
                bptl.name plan_type_name,
                opt.name option_name,
                pen.bnft_amt ben_amt
            FROM
			    -- hr.per_all_people_f pap, --Commented code by MXKEERTHI-ARGANO, 05/03/2023
                APPS.per_all_people_f pap,-- code added by MXKEERTHI-ARGANO, 05/03/2023
                
				-- ben.ben_prtt_enrt_rslt_f pen, --Commented code by MXKEERTHI-ARGANO, 05/03/2023
               APPS.ben_prtt_enrt_rslt_f pen,-- code added by MXKEERTHI-ARGANO, 05/03/2023
                
                (
                    SELECT
                        *
                    FROM
					    -- ben.ben_pl_typ_f   --Commented code by MXKEERTHI-ARGANO, 05/03/2023
                        APPS.ben_pl_typ_f-- code added by MXKEERTHI-ARGANO, 05/03/2023
                       
                    WHERE
                            SYSDATE BETWEEN effective_start_date AND effective_end_date
                        AND
                            business_group_id = p_business_group_id
                        AND
                            pl_typ_id IN (
                                SELECT
                                    pl_typ_id
                                FROM
								       --ben.ben_pl_f    --Commented code by MXKEERTHI-ARGANO, 05/03/2023
                                       APPS.ben_pl_f -- code added by MXKEERTHI-ARGANO, 05/03/2023
                                 
                                WHERE
                                        business_group_id = p_business_group_id
                                    AND
                                        pl_id = nvl(
                                            p_sel_pl_id,
                                            pl_id
                                        )
                            )
                ) bptl,
                (
                    SELECT
                        *
                    FROM
					    --ben.ben_opt_f    --Commented code by MXKEERTHI-ARGANO, 05/03/2023
                        APPS.ben_opt_f -- code added by MXKEERTHI-ARGANO, 05/03/2023
                    WHERE
                        p_coverage_date BETWEEN effective_start_date AND effective_end_date
                ) opt,
                ben.ben_oipl_f opl
            WHERE
                    pap.person_id = p_person_id
                AND
                    pap.business_group_id = p_business_group_id
                AND
                    pap.current_employee_flag = 'Y'
                AND
                    p_coverage_date BETWEEN pap.effective_start_date AND pap.effective_end_date
                AND
                    pap.person_id = pen.person_id (+)
                AND
                    pen.prtt_enrt_rslt_stat_cd IS NULL
                AND
                    pen.sspndd_flag (+) = 'N'
                AND
                    nvl(
                        pen.enrt_cvg_thru_dt,
                        p_coverage_date
                    ) <= nvl(
                        pen.effective_end_date,
                        p_coverage_date
                    )
                AND (
                        p_coverage_date BETWEEN pen.enrt_cvg_strt_dt AND pen.enrt_cvg_thru_dt
                    OR (
                            p_coverage_date >= pen.enrt_cvg_strt_dt
                        AND
                            p_coverage_date <= pen.enrt_cvg_thru_dt
                    ) OR (
                            p_coverage_date <= pen.enrt_cvg_strt_dt
                        AND
                            p_coverage_date >= pen.enrt_cvg_thru_dt
                    ) OR
                        pen.enrt_cvg_strt_dt IS NULL
                    AND
                        pen.enrt_cvg_thru_dt IS NULL
                ) AND
                    opl.opt_id = opt.opt_id (+)
                AND
                    pen.oipl_id = opl.oipl_id (+)
                AND
                    pen.pl_typ_id = bptl.pl_typ_id (+)
                AND
                    pen.pl_id = p_sel_pl_id
                AND
                    p_coverage_date BETWEEN opl.effective_start_date (+) AND opl.effective_end_date (+)
            ORDER BY
                pen.effective_start_date DESC,
                pen.enrt_cvg_strt_dt DESC;

        l_current_run_date      DATE;
        l_cut_off_date          DATE;
        l_compyr_year_date      DATE;
        l_curr_opt              ben.ben_opt_f.name%TYPE;
        l_compyr_opt            ben.ben_opt_f.name%TYPE;
        l_curr_bnft_amt         ben.ben_prtt_enrt_rslt_f.bnft_amt%TYPE;
        l_compyr_bnft_amt       ben.ben_prtt_enrt_rslt_f.bnft_amt%TYPE;
        l_curr_cvg_strt_dt      ben.ben_prtt_enrt_rslt_f.enrt_cvg_strt_dt%TYPE;
        l_curr_compyr_strt_dt   ben.ben_prtt_enrt_rslt_f.enrt_cvg_strt_dt%TYPE;
        l_curr_yr_row           VARCHAR2(1);
        l_compyr_yr_row         VARCHAR2(1);
        l_tenure                NUMBER;
        v_tenure                VARCHAR2(20);
        l_curr_plan_type        ben.ben_pl_typ_f.name%TYPE;
        l_curr_plan_name        ben.ben_pl_f.name%TYPE;
        l_compyr_plan_type      ben.ben_pl_typ_f.name%TYPE;
        l_compyr_plan_name      ben.ben_pl_f.name%TYPE;
        l_rank                  VARCHAR2(150);
        l_start_date            DATE;
        l_end_date              DATE;

  ----
        ln_curr_rec_count       NUMBER;
  ---
    BEGIN

        DELETE FROM apps.ttec_phl_ben_compyr_intf_stg;

        DELETE FROM apps.ttec_phl_ben_current_intf_stg;

        COMMIT;
        l_current_run_date := trunc(SYSDATE);
        IF
            p_comparison_year = 'Past'
        THEN
            l_compyr_year_date := trunc(
                SYSDATE,
                'Y'
            ) - 1;
            l_start_date := trunc(
                trunc(
                    SYSDATE,
                    'Y'
                ) - 1,
                'Y'
            );
            l_end_date := trunc(SYSDATE);
        ELSIF p_comparison_year = 'Future' THEN
            l_compyr_year_date := add_months(
                trunc(
                    SYSDATE,
                    'y'
                ),
                24
            ) - 1;
            l_start_date := trunc(
                SYSDATE,
                'Y'
            );
            l_end_date := trunc(SYSDATE);
        END IF;

        fnd_file.put_line(
            fnd_file.output,
            'Employee_Number|Employee_Name|Original_Hire_Date|National_Identifier|Location|Curr Cvg Start Date|Curr Plan Type|Curr Plan Name|Curr Option Name|Curr Benefit Amt |compyrYr Start Date|compyrYr Plan Type|compyrYr Plan Name|compyrYr Option Name|compyrYr Benefit Amt |Date_Of_Birth|Age|Assignment_Status|Employment_Category|Benefits_Group|Rank_Classification|Sup_Name|Sup_Emp_Number|Sup_Email_Add|Job Family|Emp_Gender|Salary_Basis|Tenure_Status'

        );
        FOR c_emp_rec IN csr_emp_rec(
            l_start_date,
            l_end_date
        ) LOOP

            FOR c_plan_rec IN csr_plan_names () LOOP
                l_curr_opt := NULL;
                l_compyr_opt := NULL;
                l_curr_bnft_amt := NULL;
                l_compyr_bnft_amt := NULL;
                l_curr_cvg_strt_dt := NULL;
                l_curr_compyr_strt_dt := NULL;
                l_curr_yr_row := 'N';
                l_compyr_yr_row := 'N';
                l_curr_plan_type := NULL;
                l_curr_plan_name := NULL;
                l_compyr_plan_type := NULL;
                l_compyr_plan_name := NULL;
                FOR r_curr_rec IN csr_ben_info(
                    c_emp_rec.person_id,
                    c_plan_rec.pl_id,
                    l_current_run_date
                ) LOOP
                    l_curr_yr_row := 'Y';
                    r_curr.person_id := c_emp_rec.person_id;
                    r_curr.assignment_id := c_emp_rec.assignment_id;
                    r_curr.employee_number := c_emp_rec.emp_num;
                    r_curr.employee_name := replace(
                        c_emp_rec.emp_name,
                        ',',
                        ' '
                    );
                    r_curr.original_hire_date := c_emp_rec.o_hire_date;
                    r_curr.national_identifier := c_emp_rec.national_identifier;
                    r_curr.location := replace(
                        c_emp_rec.location,
                        ',',
                        ' '
                    );
                    r_curr.curr_enrt_cvg_strt_dt := r_curr_rec.enrt_cvg_strt_dt;
                    r_curr.curr_plan_type_name := r_curr_rec.plan_type_name;
                    r_curr.curr_plan_name := c_plan_rec.plan_name;
                    r_curr.curr_option_name := r_curr_rec.option_name;
                    r_curr.curr_ben_amt := r_curr_rec.ben_amt;
                    r_curr.compyr_enrt_cvg_strt_dt := NULL;
                    r_curr.compyr_plan_type_name := NULL;
                    r_curr.compyr_plan_name := NULL;
                    r_curr.compyr_option_name := NULL;
                    r_curr.compyr_ben_amt := NULL;
                    r_curr.date_of_birth := c_emp_rec.date_of_birth;
                    r_curr.age := c_emp_rec.age;
                    r_curr.assignment_status := c_emp_rec.asg_status;
                    r_curr.employment_category := c_emp_rec.employment_category;
                    r_curr.benefits_group := c_emp_rec.benefits_group;
                    r_curr.manager_level := c_emp_rec.manager_level;
                    r_curr.sup_name := c_emp_rec.sup_name;
                    r_curr.sup_emp_number := c_emp_rec.sup_emp_num;
                    r_curr.sup_email_add := c_emp_rec.sup_email_addr;
                    r_curr.job_family := c_emp_rec.emp_job_family;
                    r_curr.emp_gender := c_emp_rec.emp_gender;
                    r_curr.salary_basis := c_emp_rec.emp_pay_basis;
                    r_curr.conc_request_id := g_conc_request_id;
                    r_curr.last_update_date := SYSDATE;
                    r_curr.last_updated_by := g_user_id;
                    r_curr.creation_date := SYSDATE;
                    r_curr.created_by := g_user_id;
                    INSERT INTO apps.ttec_phl_ben_current_intf_stg VALUES r_curr;

                END LOOP;

                FOR r_compyr_rec IN csr_ben_info(
                    c_emp_rec.person_id,
                    c_plan_rec.pl_id,
                    l_compyr_year_date
                ) LOOP
                    l_compyr_yr_row := 'Y';
                    r_compyr.person_id := c_emp_rec.person_id;
                    r_compyr.assignment_id := c_emp_rec.assignment_id;
                    r_compyr.employee_number := c_emp_rec.emp_num;
                    r_compyr.employee_name := replace(
                        c_emp_rec.emp_name,
                        ',',
                        ' '
                    );
                    r_compyr.original_hire_date := c_emp_rec.o_hire_date;
                    r_compyr.national_identifier := c_emp_rec.national_identifier;
                    r_compyr.location := replace(
                        c_emp_rec.location,
                        ',',
                        ' '
                    );
                    r_compyr.curr_enrt_cvg_strt_dt := NULL;
                    r_compyr.curr_plan_type_name := NULL;
                    r_compyr.curr_plan_name := NULL;
                    r_compyr.curr_option_name := NULL;
                    r_compyr.curr_ben_amt := NULL;
                    r_compyr.compyr_enrt_cvg_strt_dt := r_compyr_rec.enrt_cvg_strt_dt;
                    r_compyr.compyr_plan_type_name := r_compyr_rec.plan_type_name;
                    r_compyr.compyr_plan_name := c_plan_rec.plan_name;
                    r_compyr.compyr_option_name := r_compyr_rec.option_name;
                    r_compyr.compyr_ben_amt := r_compyr_rec.ben_amt;
                    r_compyr.date_of_birth := c_emp_rec.date_of_birth;
                    r_compyr.age := c_emp_rec.age;
                    r_compyr.assignment_status := c_emp_rec.asg_status;
                    r_compyr.employment_category := c_emp_rec.employment_category;
                    r_compyr.benefits_group := c_emp_rec.benefits_group;
                    r_compyr.manager_level := c_emp_rec.manager_level;
                    r_compyr.sup_name := c_emp_rec.sup_name;
                    r_compyr.sup_emp_number := c_emp_rec.sup_emp_num;
                    r_compyr.sup_email_add := c_emp_rec.sup_email_addr;
                    r_compyr.job_family := c_emp_rec.emp_job_family;
                    r_compyr.emp_gender := c_emp_rec.emp_gender;
                    r_compyr.salary_basis := c_emp_rec.emp_pay_basis;
                    r_compyr.conc_request_id := g_conc_request_id;
                    r_compyr.last_update_date := SYSDATE;
                    r_compyr.last_updated_by := g_user_id;
                    r_compyr.creation_date := SYSDATE;
                    r_compyr.created_by := g_user_id;
                    INSERT INTO apps.ttec_phl_ben_compyr_intf_stg VALUES r_compyr;

                END LOOP;

            END LOOP;
        END LOOP;

        BEGIN
            SELECT
                COUNT(1)
            INTO
                ln_curr_rec_count
            FROM
                apps.ttec_phl_ben_compyr_intf_stg b
            WHERE
                NOT
                    EXISTS (
                        SELECT
                            1
                        FROM
                            apps.ttec_phl_ben_current_intf_stg a
                        WHERE
                                a.employee_number = b.employee_number
                            AND
                                a.curr_plan_type_name = b.compyr_plan_type_name
                            AND
                                a.curr_plan_name = b.compyr_plan_name
                    );

        EXCEPTION
            WHEN OTHERS THEN
                ln_curr_rec_count := 0;
        END;

        fnd_file.put_line(
            fnd_file.log,
            'ln_curr_rec_count' || '-' || ln_curr_rec_count
        );
        FOR c1 IN (
            SELECT
                employee_number,
                curr_plan_type_name,
                curr_plan_name
            FROM
                apps.ttec_phl_ben_current_intf_stg
            GROUP BY
                employee_number,
                curr_plan_type_name,
                curr_plan_name
        ) LOOP
            fnd_file.put_line(
                fnd_file.log,
                c1.employee_number || '-' || 'first loop'
            );

            FOR c2 IN (
                SELECT
                    *
                FROM
                    apps.ttec_phl_ben_compyr_intf_stg
                WHERE
                        employee_number = c1.employee_number
                    AND
                        c1.curr_plan_type_name = compyr_plan_type_name
                    AND
                        c1.curr_plan_name = compyr_plan_name
            ) LOOP
                fnd_file.put_line(
                    fnd_file.log,
                    c2.employee_number || '-' || 'second loop'
                );

                UPDATE apps.ttec_phl_ben_current_intf_stg
                    SET
                        compyr_enrt_cvg_strt_dt = c2.compyr_enrt_cvg_strt_dt,
                        compyr_plan_type_name = c2.compyr_plan_type_name,
                        compyr_plan_name = c2.compyr_plan_name,
                        compyr_option_name = c2.compyr_option_name,
                        compyr_ben_amt = c2.compyr_ben_amt
                WHERE
                        employee_number = c2.employee_number
                    AND
                        curr_plan_type_name = c2.compyr_plan_type_name
                    AND
                        curr_plan_name = c2.compyr_plan_name
                    AND
                        compyr_enrt_cvg_strt_dt IS NULL
                    AND
                        ROWNUM = 1;

                fnd_file.put_line(
                    fnd_file.log,
                    c2.employee_number
                     || '-a-'
                     || SQL%rowcount
                );

                IF
                    SQL%rowcount <> 1
                THEN
                    INSERT INTO apps.ttec_phl_ben_current_intf_stg ( SELECT
                        *
                    FROM
                        apps.ttec_phl_ben_compyr_intf_stg
                    WHERE
                            employee_number = c2.employee_number
                        AND
                            compyr_plan_type_name = c2.compyr_plan_type_name
                        AND
                            compyr_plan_name = c2.compyr_plan_name
                        AND
                            compyr_option_name = c2.compyr_option_name
                    );

                    fnd_file.put_line(
                        fnd_file.log,
                        'inside insert sql'
                    );
                END IF;

                fnd_file.put_line(
                    fnd_file.log,
                    c2.employee_number
                     || '-b-'
                     || SQL%rowcount
                );

                COMMIT;
            END LOOP; --c2

        END LOOP; --c1

        IF
            ln_curr_rec_count <> 0
        THEN
            INSERT INTO apps.ttec_phl_ben_current_intf_stg ( SELECT
                *
            FROM
                apps.ttec_phl_ben_compyr_intf_stg b
            WHERE
                NOT
                    EXISTS (
                        SELECT
                            1
                        FROM
                            apps.ttec_phl_ben_current_intf_stg a
                        WHERE
                                a.employee_number = b.employee_number
                            AND
                                a.curr_plan_type_name = b.compyr_plan_type_name
                            AND
                                a.curr_plan_name = b.compyr_plan_name
                    )
            );

            fnd_file.put_line(
                fnd_file.log,
                'zero rec insert' || '-' || SQL%rowcount
            );

            COMMIT;
        END IF;

        FOR c_file IN (
            SELECT
                *
            FROM
                apps.ttec_phl_ben_current_intf_stg
            ORDER BY employee_number
        ) LOOP
            v_tenure := NULL;
            IF
                p_business_group_id = 1517
            THEN
                l_tenure := 0;
                l_tenure := ttec_phl_philcare_intf_pkg.get_tenure_phl(
                    c_file.original_hire_date,
                    c_file.assignment_id
                );
                IF
                    l_tenure > 3
                THEN
                    v_tenure := 'Tenured';
                ELSE
                    v_tenure := 'Non-Tenured';
                END IF;

            END IF;

            l_rank := ttec_get_rank_classification(
                c_file.person_id,
                fnd_date.canonical_to_date(l_current_run_date),
                c_file.salary_basis,
                c_file.manager_level,
                p_business_group_id
            );

            fnd_file.put_line(
                fnd_file.output,
                c_file.employee_number
                 || '|'
                 || replace(
                    c_file.employee_name,
                    ',',
                    ' '
                )
                 || '|'
                 || c_file.original_hire_date
                 || '|'
                 || c_file.national_identifier
                 || '|'
                 || replace(
                    c_file.location,
                    ',',
                    ' '
                )
                 || '|'
                 || c_file.curr_enrt_cvg_strt_dt
                 || '|'
                 || c_file.curr_plan_type_name
                 || '|'
                 || c_file.curr_plan_name
                 || '|'
                 || c_file.curr_option_name
                 || '|'
                 || c_file.curr_ben_amt
                 || '|'
                 || c_file.compyr_enrt_cvg_strt_dt
                 || '|'
                 || c_file.compyr_plan_type_name
                 || '|'
                 || c_file.compyr_plan_name
                 || '|'
                 || c_file.compyr_option_name
                 || '|'
                 || c_file.compyr_ben_amt
                 || '|'
                 || c_file.date_of_birth
                 || '|'
                 || c_file.age
                 || '|'
                 || c_file.assignment_status
                 || '|'
                 || c_file.employment_category
                 || '|'
                 || c_file.benefits_group
                 || '|'
                 || l_rank
                 || '|'
                 || c_file.sup_name
                 || '|'
                 || c_file.sup_emp_number
                 || '|'
                 || c_file.sup_email_add
                 || '|'
                 || c_file.job_family
                 || '|'
                 || c_file.emp_gender
                 || '|'
                 || c_file.salary_basis
                 || '|'
                 || v_tenure
            );

        END LOOP;

    END phl_benefit_election_emp;

END TTEC_PHL_BEN_ELECTION_COMP_RPT;
/
show errors;
/