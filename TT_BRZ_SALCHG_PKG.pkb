create or replace PACKAGE BODY tt_brz_salchg_pkg IS
/************************************************************************************
     Program Name: tt_brz_salchg_Pkg

     Description:  This program  reads ttec_sal_load.csv from data/benefitinterce
                   directory and inset into HR table using hr_upload_proposal_api

     Developed by : Elango Pandu
     Date         : Dec-29-2005

    Modification Log
    Name            Date       Description
    -----           -----      -------------
    Elango     Apr-10-2006     Added business group id as parameter
    Manish     Mar-08-2018     Restrict salary upload for any future dated salary change and modified the Program output#TASK0656850
    Manish     Nov-29-2018     Restrict same salary upload #STRY0040791
    Riswan     Nov-28-2019     Process salary load for new hire employee who don't have existing salary details and reason code issue #TASK1279003
	Riswan     Dec-11-2019     Salary reason code not updating issue #TASK1279003
	Riswan     Feb-03-2020     Invalid reason code error display in the output file #TASK1279003
    Saket      Jan-18-2022     Adding support for salary percentage TASK2946319
	RXNETHI-ARGANO  MAY-17-2023  R12.2 Upgrade Remediation
****************************************************************************************/

    PROCEDURE print_line (
        v_data IN VARCHAR2
    ) IS
    BEGIN
        fnd_file.put_line(fnd_file.output, v_data);
    END;

    PROCEDURE import_sal_change (
        errbuf                OUT   VARCHAR2,
        retcode               OUT   NUMBER,
        p_business_group_id   IN    NUMBER
    ) IS

        v_validate                    BOOLEAN := false;
        v_inv_next_sal_date_warning   BOOLEAN;
        v_proposed_salary_warning     BOOLEAN;
        v_approved_warning            BOOLEAN;
        v_payroll_warning             BOOLEAN;
        v_object_version_number       NUMBER := NULL;
        v_pay_proposal_id             NUMBER := NULL;
        v_cnt                         NUMBER := 0;
        v_tot_record                  NUMBER := 0;
        v_name                        VARCHAR2(200);
        v_element_entry_id            NUMBER := NULL;
        v_person_id                   apps.per_all_people_f.person_id%TYPE;
        /*
		START R12,2 Upgrade Remediation
		code commented by RXNETHI-ARGANO17/05/23
		v_assignment_id               hr.per_all_assignments_f.assignment_id%TYPE;
        v_pay_basis_id                hr.per_all_assignments_f.pay_basis_id%TYPE;
		*/
		--code added by RXNETHI-ARGANO,17/05/23
		v_assignment_id               apps.per_all_assignments_f.assignment_id%TYPE;
        v_pay_basis_id                apps.per_all_assignments_f.pay_basis_id%TYPE;
		--END R12.2 Upgrade Remediation
        v_code                        VARCHAR2(200);
        v_meaning                     VARCHAR2(200);
        v_change_date                 apps.per_pay_proposals.change_date%TYPE;
        v_proposed_sal                apps.per_pay_proposals.proposed_salary_n%TYPE;
        v_basis                       per_pay_bases.name%TYPE;
        v_old_basis                   per_pay_bases.name%TYPE;
        v_old_salary                  apps.per_pay_proposals.proposed_salary_n%TYPE;
        v_old_change_date             apps.per_pay_proposals.change_date%TYPE;
        v_new_basis                   per_pay_bases.name%TYPE;
        v_sal_count                   NUMBER;
        l_end_date                    DATE := hr_general.end_of_time;
        e_duplicatesal EXCEPTION;
        v_reason_code                 VARCHAR2(200);
        v_rsn_code_cnt                NUMBER;
        v_rsn_code_err                VARCHAR2(200);
        v_rsn_err                     VARCHAR2(200);
        v_bg_per                      apps.per_all_people_f.person_id%TYPE;
        --v_bg_id                       hr.per_all_assignments_f.business_group_id%TYPE;  --code commented by RXNETHI-ARGANO,17/05/23
        v_bg_id                       apps.per_all_assignments_f.business_group_id%TYPE;  --code added by RXNETHI-ARGANO,17/05/23
        v_api_err                     VARCHAR2(2000);
        v_sal_percent_error_flag      VARCHAR2(30);
        CURSOR c_get_data IS
        SELECT
            emp_no,
            salary,
            proposal_reason_code proposal_reason,
            change_date,
            salary_percentage -- Added for TASK2946319
        FROM
            ttec_sal_load;

        CURSOR c_proposal_reason (
            p_reason    VARCHAR2,
            p_country   IN VARCHAR2
        ) IS
        SELECT DISTINCT
            a.lookup_code,
            a.meaning
        FROM
            apps.fnd_lookup_values        a,
            apps.fnd_security_groups_vl   b,
            per_business_groups           c
        WHERE
            a.security_group_id = b.security_group_id
            AND a.enabled_flag = 'Y'
            AND a.lookup_type = 'PROPOSAL_REASON'
            AND b.security_group_id = c.security_group_id
            AND upper(a.meaning) = upper(p_reason)
            AND ( ( upper(c.name) = upper(p_country) )
                  OR ( upper(c.name) = 'STANDARD' ) )
            AND ROWNUM = 1;

        CURSOR c_process_data IS
        SELECT
            *
        FROM
            apps.xx_sal_upd_tbl
        WHERE
            status = 'SUCCESS';

        CURSOR c_process_data2 IS
        SELECT
            *
        FROM
            apps.xx_sal_upd_tbl
        WHERE
            status = 'FAILED'
            AND err_msg LIKE '%Employee%have%future%Salary%'; --#TASK1279003

        CURSOR c_process_data3 IS
        SELECT
            *
        FROM
            apps.xx_sal_upd_tbl
        WHERE
            status = 'SAMESALARY';

        CURSOR c_process_data4 IS
        SELECT
            *
        FROM
            apps.xx_sal_upd_tbl
        WHERE
            status = 'FAILED'
            AND err_msg LIKE '%reason%code%'
        UNION ALL
        SELECT
            *
        FROM
            apps.xx_sal_upd_tbl
        WHERE
            status = 'FAILED'
            AND err_msg LIKE '%Invalid%Business%Group%chosen%for%EE#%'
        UNION ALL
        SELECT
            *
        FROM
            apps.xx_sal_upd_tbl
        WHERE
            status = 'FAILED'
            AND err_msg LIKE '%Employee%EE#%is%not%active%for%current%date%'
        UNION ALL
        SELECT
            *
        FROM
            apps.xx_sal_upd_tbl
        WHERE
            status = 'FAILED'
            AND err_msg LIKE '%Employee%EE#%is%not%active%for%the%salary%change%date%EE#%'
        UNION ALL
        SELECT
            *
        FROM
            apps.xx_sal_upd_tbl
        WHERE
            status = 'FAILED'
            AND err_msg LIKE '%Employee%EE#%is%invalid,pass%the%valid%Employee%No%'
        UNION ALL
        SELECT
            *
        FROM
            apps.xx_sal_upd_tbl
        WHERE
            status = 'FAILED'
            AND err_msg LIKE '%Salary%basis%'
        UNION ALL
        SELECT
            *
        FROM
            apps.xx_sal_upd_tbl
        WHERE
            status = 'FAILED'
            AND err_msg LIKE '%Error%in%API%for%EE%';--#TASK1279003

    BEGIN
        DELETE FROM apps.xx_sal_upd_tbl;

        COMMIT;
        BEGIN
            INSERT INTO apps.xx_sal_upd_tbl (
                emp_no,
                salary,
                proposal_reason_code,
                change_date,
                salary_percentage -- Added for TASK2946319
            )
                SELECT
                    emp_no,
                    salary,
                    proposal_reason_code,
                    change_date,
                    salary_percentage -- Added for TASK2946319
                FROM
                    apps.ttec_sal_load;

            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                fnd_file.put_line(fnd_file.log, 'Error while inserting data into custom table'
                                                || ''
                                                || substr(sqlerrm, 1, 100));
        END;

        fnd_file.put_line(fnd_file.log, 'p_business_group_id ' || p_business_group_id);
        BEGIN
            SELECT
                name
            INTO v_name
            FROM
                hr_all_organization_units
            WHERE
                organization_id = p_business_group_id;

        EXCEPTION
            WHEN OTHERS THEN
                fnd_file.put_line(fnd_file.log, 'Error in Business group id for TeleTech Holdings - BRZ');
        END;

        fnd_file.put_line(fnd_file.log, 'v_name ' || v_name);
        IF v_name IS NOT NULL THEN
            print_line('');
            print_line(' TELETECH SALARY UPLOAD INTERFACE FOR ' || v_name);
            print_line('');
            print_line('INTERFACE TIMESTAMP =  ' || to_char(sysdate, 'DD-MON-YYYY HH:MM:SS'));
            print_line('');
            FOR r_data IN c_get_data LOOP
                v_person_id := NULL;
                v_assignment_id := NULL;
                v_element_entry_id := NULL;
                v_pay_proposal_id := NULL;
                v_object_version_number := NULL;
                v_inv_next_sal_date_warning := NULL;
                v_proposed_salary_warning := NULL;
                v_approved_warning := NULL;
                v_payroll_warning := NULL;
                v_code := NULL;
                v_meaning := NULL;
                v_sal_count := NULL;
                v_reason_code := NULL;
                v_rsn_code_cnt := NULL;
                v_rsn_code_err := NULL;
                v_rsn_err := NULL;
                v_bg_per := NULL;
                v_bg_id := NULL;
                v_api_err := NULL;
                v_sal_percent_error_flag := NULL;

                --#TASK1279003 sql query to find whether Employee No is valid
                BEGIN
                    SELECT DISTINCT
                        papf.person_id,
                        paaf.business_group_id
                    INTO
                        v_bg_per,
                        v_bg_id
                    FROM
                        per_all_assignments_f   paaf,
                        per_all_people_f        papf
                    WHERE
                        papf.person_id = paaf.person_id
                        AND papf.employee_number = r_data.emp_no;

                EXCEPTION
                    WHEN no_data_found THEN
                        fnd_file.put_line(fnd_file.log, 'Employee EE# '
                                                        || r_data.emp_no
                                                        || ' is invalid,pass the valid Employee No'
                                                        || ' error is '
                                                        || sqlerrm);

                        v_bg_per := NULL;
                        UPDATE apps.xx_sal_upd_tbl
                        SET
                            err_msg = 'Employee EE# '
                                      || r_data.emp_no
                                      || ' is invalid,pass the valid Employee No',
                            status = 'FAILED'
                        WHERE
                            emp_no = r_data.emp_no;

                    WHEN OTHERS THEN
                        fnd_file.put_line(fnd_file.log, 'Employee EE# '
                                                        || r_data.emp_no
                                                        || ' is invalid,pass the valid Employee No'
                                                        || ' error is '
                                                        || sqlerrm);

                        v_bg_per := NULL;
                        UPDATE apps.xx_sal_upd_tbl
                        SET
                            err_msg = 'Employee EE# '
                                      || r_data.emp_no
                                      || ' is invalid,pass the valid Employee No',
                            status = 'FAILED'
                        WHERE
                            emp_no = r_data.emp_no;

                END;

                --#TASK1279003 sql query to find whether Employee is valid for the current date

                IF v_bg_per IS NOT NULL THEN
                    BEGIN
                        SELECT DISTINCT
                            papf.person_id,
                            paaf.business_group_id
                        INTO
                            v_bg_per,
                            v_bg_id
                        FROM
                            per_all_assignments_f   paaf,
                            per_all_people_f        papf
                        WHERE
                            papf.person_id = paaf.person_id
                            AND papf.employee_number = r_data.emp_no
                            AND papf.current_employee_flag = 'Y'
                            AND paaf.assignment_type = 'E'
                            AND trunc(sysdate) BETWEEN papf.effective_start_date AND papf.effective_end_date
                            AND trunc(sysdate) BETWEEN paaf.effective_start_date AND paaf.effective_end_date;

                    EXCEPTION
                        WHEN no_data_found THEN
                            fnd_file.put_line(fnd_file.log, 'Employee EE# '
                                                            || r_data.emp_no
                                                            || ' is not active for current date.'
                                                            || ' error is '
                                                            || sqlerrm);

                            v_bg_per := NULL;
                            UPDATE apps.xx_sal_upd_tbl
                            SET
                                err_msg = 'Employee EE# '
                                          || r_data.emp_no
                                          || ' is not active for current date.',
                                status = 'FAILED'
                            WHERE
                                emp_no = r_data.emp_no;

                        WHEN OTHERS THEN
                            fnd_file.put_line(fnd_file.log, 'Employee EE# '
                                                            || r_data.emp_no
                                                            || ' is not active for current date.'
                                                            || ' error is '
                                                            || sqlerrm);

                            v_bg_per := NULL;
                            UPDATE apps.xx_sal_upd_tbl
                            SET
                                err_msg = 'Employee EE# '
                                          || r_data.emp_no
                                          || ' is not active for current date.',
                                status = 'FAILED'
                            WHERE
                                emp_no = r_data.emp_no;

                    END;
                END IF;
                 --#TASK1279003 sql query to find whether Employee is valid for the salary change date

                IF v_bg_per IS NOT NULL THEN
                    fnd_file.put_line(fnd_file.log, 'v_bg_per ' || v_bg_per);
                    BEGIN
                        SELECT DISTINCT
                            papf.person_id,
                            paaf.business_group_id
                        INTO
                            v_bg_per,
                            v_bg_id
                        FROM
                            per_all_assignments_f   paaf,
                            per_all_people_f        papf
                        WHERE
                            papf.person_id = paaf.person_id
                            AND papf.employee_number = r_data.emp_no
                            AND papf.current_employee_flag = 'Y'
                            AND paaf.assignment_type = 'E'
                            AND r_data.change_date BETWEEN papf.effective_start_date AND papf.effective_end_date
                            AND r_data.change_date BETWEEN paaf.effective_start_date AND paaf.effective_end_date;

                    EXCEPTION
                        WHEN no_data_found THEN
                            fnd_file.put_line(fnd_file.log, 'Employee EE# '
                                                            || r_data.emp_no
                                                            || ' is not active for the salary change date EE# '
                                                            || r_data.change_date
                                                            || ' .Error is '
                                                            || sqlerrm);

                            v_bg_per := NULL;
                            UPDATE apps.xx_sal_upd_tbl
                            SET
                                err_msg = 'Employee EE# '
                                          || r_data.emp_no
                                          || ' is not active for the salary change date EE# '
                                          || r_data.change_date,
                                status = 'FAILED'
                            WHERE
                                emp_no = r_data.emp_no;

                        WHEN OTHERS THEN
                            fnd_file.put_line(fnd_file.log, 'Employee EE# '
                                                            || r_data.emp_no
                                                            || ' is not active for the salary change date EE# '
                                                            || r_data.change_date
                                                            || ' .Error is '
                                                            || sqlerrm);

                            v_bg_per := NULL;
                            UPDATE apps.xx_sal_upd_tbl
                            SET
                                err_msg = 'Employee EE# '
                                          || r_data.emp_no
                                          || ' is not active for the salary change date EE# '
                                          || r_data.change_date,
                                status = 'FAILED'
                            WHERE
                                emp_no = r_data.emp_no;

                    END;
                    fnd_file.put_line(fnd_file.log, 'v_bg_id ' || v_bg_id);
                END IF;

                IF v_bg_per IS NOT NULL THEN     --#TASK1279003 if condition to check whether the Employee and Business Group is valid
                    IF v_bg_id = p_business_group_id THEN --#TASK1279003 if condition to check whether the chosen Business Group is valid

                        -- Added for TASK2946319
                        v_sal_percent_error_flag := 'N';
                        fnd_file.put_line(fnd_file.log, 'v_sal_percent_error_flag: Before ' || v_sal_percent_error_flag);
                        BEGIN
                            IF ( r_data.salary IS NOT NULL AND r_data.salary_percentage IS NOT NULL ) THEN
                                UPDATE apps.xx_sal_upd_tbl
                                SET
                                    err_msg = 'Please provide value for either Salary or Salary Percentage.',
                                    status = 'FAILED'
                                WHERE
                                    emp_no = r_data.emp_no;

                                v_sal_percent_error_flag := 'Y';
                            ELSIF ( r_data.salary_percentage IS NOT NULL and r_data.salary_percentage > 100) THEN
                                UPDATE apps.xx_sal_upd_tbl
                                SET
                                    err_msg = 'Salary Percentage cannot be more than 100%.',
                                    status = 'FAILED'
                                WHERE
                                    emp_no = r_data.emp_no;

                                v_sal_percent_error_flag := 'Y';
                            END IF;
                        exception
                                WHEN OTHERS THEN
                                    fnd_file.put_line(fnd_file.log, 'Error while doing salary percentage validation '
                                                                    || sqlerrm);

                                    UPDATE apps.xx_sal_upd_tbl
                                    SET
                                        err_msg = 'Error while doing salary percentage validation',
                                        status = 'FAILED'
                                    WHERE
                                        emp_no = r_data.emp_no;
                        END;
                        fnd_file.put_line(fnd_file.log, 'v_sal_percent_error_flag: After ' || v_sal_percent_error_flag);

                        IF ( v_sal_percent_error_flag = 'N' ) THEN
                            BEGIN --#TASK1279003 sql query to find whether Employee has Salary basis informations
                                SELECT
                                    paaf.pay_basis_id,
                                    paaf.assignment_id
                                INTO
                                    v_pay_basis_id,
                                    v_assignment_id
                                FROM
                                    per_all_assignments_f   paaf,
                                    per_all_people_f        papf
                                WHERE
                                    papf.person_id = paaf.person_id
                                    AND papf.employee_number = r_data.emp_no
                                    AND papf.current_employee_flag = 'Y'
                                    AND paaf.assignment_type = 'E'
                                    AND trunc(sysdate) BETWEEN papf.effective_start_date AND papf.effective_end_date
                                    AND trunc(sysdate) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
                                    AND papf.business_group_id = p_business_group_id;

                            EXCEPTION
                                WHEN OTHERS THEN
                                    fnd_file.put_line(fnd_file.log, 'Error in finding salary basis for EE# '
                                                                    || r_data.emp_no
                                                                    || ' is '
                                                                    || sqlerrm);

                                    UPDATE apps.xx_sal_upd_tbl
                                    SET
                                        err_msg = 'Error in finding salary basis for EE# ' || r_data.emp_no,
                                        status = 'FAILED'
                                    WHERE
                                        emp_no = r_data.emp_no;

                            END;

                            IF v_pay_basis_id IS NOT NULL THEN
                                fnd_file.put_line(fnd_file.log, 'Salary basis available for EE# ' || r_data.emp_no);
                     --#TASK1279003 sql query to find whether Employee has Salary details
                                BEGIN
                                    SELECT
                                        COUNT(ppp.assignment_id)
                                    INTO v_sal_count
                                    FROM
                                        per_all_people_f        papf,
                                        per_all_assignments_f   paaf,
                                        per_pay_proposals       ppp
                                    WHERE
                                        1 = 1
                                        AND papf.person_id = paaf.person_id
                                        AND papf.employee_number = r_data.emp_no
                                        AND papf.current_employee_flag = 'Y'
                                        AND paaf.assignment_type = 'E'
                                        AND paaf.assignment_id = ppp.assignment_id
                                        AND ppp.pay_proposal_id = (
                                            SELECT
                                                MAX(pay_proposal_id)
                                            FROM
                                                per_pay_proposals
                                            WHERE
                                                assignment_id = paaf.assignment_id
                                        )
                                        AND trunc(sysdate) BETWEEN papf.effective_start_date AND papf.effective_end_date
                                        AND trunc(sysdate) BETWEEN paaf.effective_start_date AND paaf.effective_end_date;

                                EXCEPTION
                                    WHEN OTHERS THEN
                                        fnd_file.put_line(fnd_file.log, 'Error in finding salary details for EE# '
                                                                        || r_data.emp_no
                                                                        || ' is '
                                                                        || sqlerrm);
                                END;

                            ELSE
                                fnd_file.put_line(fnd_file.log, 'Salary basis not available for EE# ' || r_data.emp_no);
                                UPDATE apps.xx_sal_upd_tbl
                                SET
                                    err_msg = 'Salary basis not available for EE# ' || r_data.emp_no,
                                    status = 'FAILED'
                                WHERE
                                    emp_no = r_data.emp_no;

                            END IF;  --check Employee has slary basis End if #TASK1279003

                            IF  -- salary exists or not if TASK1279003

                             v_sal_count > 0 THEN
                                fnd_file.put_line(fnd_file.log, 'Salary details already exists for EE# '
                                                                || r_data.emp_no
                                                                || ' updating with new changed salary details');

        -- SQL1: query to get future dated Salary changes.

                                BEGIN
                                    SELECT
                                        ppp.change_date,
                                        ppp.proposed_salary_n
                                    INTO
                                        v_change_date,
                                        v_proposed_sal
                                    FROM
                                        per_all_people_f        papf,
                                        per_all_assignments_f   paaf,
                                        per_pay_proposals       ppp,
                                        per_pay_bases           ppb
                                    WHERE
                                        1 = 1
                                        AND papf.employee_number = r_data.emp_no--'3190457'
                                        AND papf.person_id = paaf.person_id
                                        AND papf.current_employee_flag = 'Y'
                                        AND paaf.assignment_id = ppp.assignment_id
                                        AND paaf.pay_basis_id = ppb.pay_basis_id (+)
                                        AND ppp.change_date = (
                                            SELECT
                                                MAX(change_date)
                                            FROM
                                                per_pay_proposals
                                            WHERE
                                                assignment_id = paaf.assignment_id
                                        )
                                        AND trunc(sysdate) BETWEEN papf.effective_start_date AND papf.effective_end_date
                                        AND trunc(sysdate) BETWEEN paaf.effective_start_date AND paaf.effective_end_date;

                                EXCEPTION
                                    WHEN OTHERS THEN
                                        fnd_file.put_line(fnd_file.log, 'Error in finding future Salary Change Date for EE# '
                                                                        || r_data.emp_no
                                                                        || ' Business Group is '
                                                                        || v_name);

                                        UPDATE apps.xx_sal_upd_tbl
                                        SET
                                            err_msg = 'Error:While Checking If employee have future Salary Changes',
                                            status = 'FAILED'
                                        WHERE
                                            emp_no = r_data.emp_no;

                                END;

          -- SQL2: Query to get old salary basis/salary/last salary change date

                                BEGIN
                                    SELECT
                                        ppb.name                "Old Salary Basis",
                                        ppp.proposed_salary_n   "Old_Salary",
                                        ppp.change_date         "Last Salary Change Date"
                                    INTO
                                        v_old_basis,
                                        v_old_salary,
                                        v_old_change_date
                                    FROM
                                        per_pay_bases           ppb,
                                        per_all_people_f        papf,
                                        per_all_assignments_f   paaf,
                                        per_pay_proposals       ppp
                                    WHERE
                                        1 = 1
                                        AND papf.person_id = paaf.person_id
                                        AND papf.employee_number = r_data.emp_no --'2122309'
                                        AND papf.current_employee_flag = 'Y'
                                        AND paaf.pay_basis_id = ppb.pay_basis_id
                                        AND paaf.assignment_id = ppp.assignment_id
                                        AND ppp.pay_proposal_id = (
                                            SELECT
                                                MAX(pay_proposal_id)
                                            FROM
                                                per_pay_proposals
                                            WHERE
                                                assignment_id = paaf.assignment_id
                                        )
                                        AND trunc(sysdate) BETWEEN papf.effective_start_date AND papf.effective_end_date
                                        AND trunc(sysdate) BETWEEN paaf.effective_start_date AND paaf.effective_end_date;

                                EXCEPTION
                                    WHEN OTHERS THEN
                           -- fnd_file.put_line(fnd_file.log,'Error while fetching old Salary details for EE#'||' '||r_data.emp_no);
                                        UPDATE apps.xx_sal_upd_tbl
                                        SET
                                            err_msg = 'Error:While fetching old Salary details',
                                            status = 'FAILED',
                                            old_salary_basis = v_old_basis,
                                            old_salary = v_old_salary,
                                            last_sal_change_date = v_old_change_date
                                        WHERE
                                            emp_no = r_data.emp_no;

                                END;

             --STRY0040791 #added condition- same salary can not uploaded.

                                IF ( v_old_salary = r_data.salary ) THEN
                                    UPDATE apps.xx_sal_upd_tbl
                                    SET
                                        err_msg = 'Error:Same salary can not uploaded',
                                        status = 'SAMESALARY',
                                        old_salary = v_old_salary,
                                        future_salary = r_data.salary
                                    WHERE
                                        emp_no = r_data.emp_no;

                                ELSE
          ---Added condition - to check if future dated salary changes exist#TASK0656850
                                    IF ( v_change_date >= r_data.change_date ) THEN
                                        UPDATE apps.xx_sal_upd_tbl
                                        SET
                                            err_msg = 'Error:Employee have future Salary Changes',
                                            status = 'FAILED',
                                            future_salary = v_proposed_sal,
                                            future_sal_date = v_change_date
                                        WHERE
                                            emp_no = r_data.emp_no;

                                        fnd_file.put_line(fnd_file.log, 'Error:Employee have future Salary Changes');
                                    ELSE
                                        OPEN c_proposal_reason(r_data.proposal_reason, v_name);
                                        FETCH c_proposal_reason INTO
                                            v_code,
                                            v_meaning;
                                        CLOSE c_proposal_reason;
                                        fnd_file.put_line(fnd_file.log, 'v_code ' || v_code);
                                        fnd_file.put_line(fnd_file.log, 'v_meaning ' || v_meaning);
                                        IF v_code IS NULL THEN
                                            fnd_file.put_line(fnd_file.log, 'Change reason code '
                                                                            ||(r_data.proposal_reason)
                                                                            || ' is not defined in  '
                                                                            || v_name);
----#TASK1279003 To print the reason code error in the output

                                            UPDATE apps.xx_sal_upd_tbl
                                            SET
                                                err_msg = 'Change reason code '
                                                          || ( r_data.proposal_reason )
                                                          || ' is not defined in  '
                                                          || v_name,
                                                status = 'FAILED'
                                            WHERE
                                                emp_no = r_data.emp_no;

                                            v_rsn_err := 'Change reason code '
                                                         || ( r_data.proposal_reason )
                                                         || ' is not defined in  '
                                                         || v_name;
                                        ELSE
                                            BEGIN
                                                SELECT DISTINCT
                                                    pf.person_id
                                                INTO v_person_id
                                                FROM
                                                    --hr.per_all_people_f   pf,  --code commented by RXNETHI-ARGANO,17/05/23
                                                    apps.per_all_people_f   pf,  --code added by RXNETHI-ARGANO,17/05/23
                                                    per_person_types      pt
                                                WHERE
                                                    pf.employee_number = r_data.emp_no
                                                    AND pf.business_group_id = p_business_group_id
                                                    AND pf.person_type_id = pt.person_type_id
                                                    AND pf.business_group_id = pt.business_group_id
                                                    AND pt.user_person_type = 'Employee'
                                                    AND pt.system_person_type = 'EMP'
                                                    AND trunc(r_data.change_date) BETWEEN effective_start_date AND effective_end_date
                                                    ;

                                            EXCEPTION
                                                WHEN OTHERS THEN
                                                    fnd_file.put_line(fnd_file.log, 'Error in finding person id for EE# '
                                                                                    || r_data.emp_no
                                                                                    || ' Business Group is '
                                                                                    || v_name);

                                                    UPDATE apps.xx_sal_upd_tbl
                                                    SET
                                                        err_msg = 'Error:While finding Active Employee Details',
                                                        status = 'FAILED'
                                                    WHERE
                                                        emp_no = r_data.emp_no;

                                            END;

                                            IF v_person_id IS NOT NULL THEN
                                                v_assignment_id := NULL;
                                                v_pay_basis_id := NULL;
                                                BEGIN
                                                    SELECT
                                                        assignment_id,
                                                        pay_basis_id
                                                    INTO
                                                        v_assignment_id,
                                                        v_pay_basis_id
                                                    FROM
                                                        --hr.per_all_assignments_f  --code commented by RXNETHI-ARGANO,17/05/23
                                                        apps.per_all_assignments_f  --code added by RXNETHI-ARGANO,17/05/23
                                                    WHERE
                                                        person_id = v_person_id
                                                        AND assignment_type = 'E'
                                                        AND trunc(r_data.change_date) BETWEEN effective_start_date AND effective_end_date
                                                        ;

                                                EXCEPTION
                                                    WHEN OTHERS THEN
                                                        fnd_file.put_line(fnd_file.log, 'Error in finding assignment id for EE# '
                                                                                        || r_data.emp_no
                                                                                        || '
                                                     and  Person id is '
                                                                                        || v_person_id);

                                                        UPDATE apps.xx_sal_upd_tbl
                                                        SET
                                                            err_msg = 'Error:While finding Assignment Details',
                                                            status = 'FAILED'
                                                        WHERE
                                                            emp_no = r_data.emp_no;

                                                END;

                                                IF v_assignment_id IS NOT NULL OR v_pay_basis_id IS NOT NULL THEN
                                                    BEGIN
                                                        SELECT
                                                            peef.element_entry_id
                                                        INTO v_element_entry_id
                                                        FROM
                                                            pay_element_entries_f   peef,
                                                            pay_element_links_f     pel,
                                                            pay_input_values_f      piv,
                                                            per_pay_bases           ppb
                                                        WHERE
                                                            peef.assignment_id = v_assignment_id
                                                            AND ppb.pay_basis_id = v_pay_basis_id
                                                            AND ppb.input_value_id = piv.input_value_id
                                                            AND piv.element_type_id = pel.element_type_id
                                                            AND peef.element_link_id = pel.element_link_id
                                                            AND trunc(r_data.change_date) BETWEEN peef.effective_start_date AND peef
                                                            .effective_end_date
                                                            AND trunc(r_data.change_date) BETWEEN pel.effective_start_date AND pel
                                                            .effective_end_date
                                                            AND trunc(r_data.change_date) BETWEEN piv.effective_start_date AND piv
                                                            .effective_end_date;

                                                    EXCEPTION
                                                        WHEN OTHERS THEN
                                                            fnd_file.put_line(fnd_file.log, 'Error in finding element entry id for EE#'
                                                                                            || r_data.emp_no
                                                                                            || ' and  assignment id is '
                                                                                            || v_assignment_id);

                                                            UPDATE apps.xx_sal_upd_tbl
                                                            SET
                                                                err_msg = 'Error:While finding Element Entry Details',
                                                                status = 'FAILED'
                                                            WHERE
                                                                emp_no = r_data.emp_no;

                                                    END;
--Salary reason code not updating issue #TASK1279003

                                                    BEGIN
                                                        SELECT DISTINCT
                                                            a.lookup_code
                                                        INTO v_reason_code
                                                        FROM
                                                            apps.fnd_lookup_values        a,
                                                            apps.fnd_security_groups_vl   b,
                                                            per_business_groups           c
                                                        WHERE
                                                            a.security_group_id = b.security_group_id
                                                            AND a.enabled_flag = 'Y'
                                                            AND a.lookup_type = 'PROPOSAL_REASON'
                                                            AND b.security_group_id = c.security_group_id
                                                            AND upper(a.meaning) = upper(r_data.proposal_reason)
                                                            AND ( ( upper(c.name) = upper(v_name) )
                                                                  OR ( upper(c.name) = 'STANDARD' ) )
                                                            AND ROWNUM = 1;

                                                        fnd_file.put_line(fnd_file.log, 'v_reason_code ' || v_reason_code);
                                                    EXCEPTION
                                                        WHEN no_data_found THEN
                                                            v_reason_code := NULL;
                                                            fnd_file.put_line(fnd_file.log, 'No reason code found for EE# '
                                                                                            || r_data.emp_no
                                                                                            || ' Business Group is '
                                                                                            || v_name
                                                                                            || ' is'
                                                                                            || sqlerrm);

                                                            UPDATE apps.xx_sal_upd_tbl
                                                            SET
                                                                err_msg = 'Change reason code not found',
                                                                status = 'FAILED'
                                                            WHERE
                                                                emp_no = r_data.emp_no;

                                                        WHEN OTHERS THEN
                                                            v_reason_code := NULL;
                                                            fnd_file.put_line(fnd_file.log, 'Error in finding reason code for EE# '
                                                                                            || r_data.emp_no
                                                                                            || ' Business Group is '
                                                                                            || v_name
                                                                                            || ' is'
                                                                                            || sqlerrm);

                                                            UPDATE apps.xx_sal_upd_tbl
                                                            SET
                                                                err_msg = 'Error:While finding reason code ',
                                                                status = 'FAILED'
                                                            WHERE
                                                                emp_no = r_data.emp_no;

                                                    END;





                                                    IF ( ( v_element_entry_id IS NOT NULL ) AND ( v_reason_code IS NOT NULL ) ) THEN
                                                        BEGIN



                  --Call Maintain Salary Proposal API
                                                            hr_maintain_proposal_api.insert_salary_proposal(p_assignment_id => v_assignment_id
                                                            , p_business_group_id => p_business_group_id, p_change_date => r_data.change_date, p_proposal_reason => v_reason_code,
--                                                            p_proposed_salary_n => r_data.salary,
                                                             p_proposed_salary_n =>(
                                                                CASE
                                                                    WHEN(r_data.salary IS NOT NULL
                                                                         AND r_data.salary_percentage IS NULL) THEN
                                                                        to_number(r_data.salary)
                                                                    WHEN(r_data.salary IS NULL
                                                                         AND r_data.salary_percentage IS NOT NULL) THEN
                                                                        (v_old_salary +(v_old_salary *(r_data.salary_percentage / 100))
                                                                        )
                                                                END
                                                            ),
                                                                                                            p_multiple_components
                                                                                                            => 'N', p_approved =>
                                                                                                            'Y', p_validate => v_validate
                                                                                                            , p_element_entry_id => v_element_entry_id,
                                                                                                            p_inv_next_sal_date_warning
                                                                                                            => v_inv_next_sal_date_warning
                                                                                                            ,
                                                                                                            p_proposed_salary_warning
                                                                                                            => v_proposed_salary_warning
                                                                                                            , p_approved_warning => v_approved_warning,
                                                                                                            p_payroll_warning => v_payroll_warning
                                                                                                            , p_object_version_number
                                                                                                            => v_object_version_number
                                                                                                            , p_pay_proposal_id => v_pay_proposal_id);


                                                            fnd_file.put_line(fnd_file.log, 'v_assignment_id ' || v_assignment_id
                                                            );
                                                            fnd_file.put_line(fnd_file.log, 'p_business_group_id ' || p_business_group_id
                                                            );
                                                            fnd_file.put_line(fnd_file.log, 'r_data.change_date ' || r_data.change_date
                                                            );
                                                            fnd_file.put_line(fnd_file.log, 'v_reason_code ' || v_reason_code);
                                                            fnd_file.put_line(fnd_file.log, 'r_data.salary ' ||  (
                                                                CASE
                                                                    WHEN(r_data.salary IS NOT NULL
                                                                         AND r_data.salary_percentage IS NULL) THEN
                                                                        to_number(r_data.salary)
                                                                    WHEN(r_data.salary IS NULL
                                                                         AND r_data.salary_percentage IS NOT NULL) THEN
                                                                        (v_old_salary +(v_old_salary *(r_data.salary_percentage / 100))
                                                                        )
                                                                END
                                                            ));
                                                            fnd_file.put_line(fnd_file.log, 'v_element_entry_id ' || v_element_entry_id
                                                            );
                                                            fnd_file.put_line(fnd_file.log, 'v_object_version_number ' || v_object_version_number
                                                            );
                                                            fnd_file.put_line(fnd_file.log, 'v_pay_proposal_id ' || v_pay_proposal_id
                                                            );


                                                /*
                                                BEGIN
                                                    UPDATE hr.per_pay_proposals
                                                        SET
                                                            proposal_reason = v_code
                                                    WHERE
                                                        pay_proposal_id = v_pay_proposal_id;

                                                EXCEPTION
                                                    WHEN OTHERS THEN
                                                        fnd_file.put_line(
                                                            fnd_file.log,
                                                            'Error in Updating reason code in per_pay_proposals for EE#'
                                                             || r_data.emp_no
                                                             || ' Proposal id is '
                                                             || v_pay_proposal_id
                                                             || ' reason is '
                                                             || r_data.proposal_reason
                                                        );

                                                        UPDATE apps.xx_sal_upd_tbl
                                                            SET
                                                                err_msg = 'Error:In Updating Salary Reason Code',
                                                                status = 'FAILED'
                                                        WHERE
                                                            emp_no = r_data.emp_no;

                                                END;

*/
                                               --Salary reason code not updating issue #TASK1279003
                                                            BEGIN
                                                                SELECT DISTINCT
                                                                    COUNT(proposal_reason)
                                                                INTO v_rsn_code_cnt
                                                                FROM
                                                                    per_all_people_f        a,
                                                                    per_all_assignments_f   b,
                                                                    per_pay_proposals       c
                                                                WHERE
                                                                    a.person_id = b.person_id
                                                                    AND trunc(sysdate) BETWEEN a.effective_start_date AND a.effective_end_date
                                                                    AND trunc(sysdate) BETWEEN b.effective_start_date AND b.effective_end_date
                                                                    AND r_data.change_date BETWEEN c.change_date AND c.date_to
                                                                    AND b.assignment_id = c.assignment_id
                                                                    AND a.current_employee_flag = 'Y'
                                                                    AND a.employee_number = r_data.emp_no
                                                                    AND a.business_group_id = p_business_group_id
                                                                    AND c.creation_date >= sysdate - 2
--                                                                    AND proposed_salary_n = r_data.salary
                                                                    And proposed_salary_n = (case when (r_data.salary is not null and r_data.salary_percentage is null) then to_number(r_data.salary)
                                                                    when (r_data.salary is null and r_data.salary_percentage is not null) then ( v_old_salary + (v_old_salary * (r_data.salary_percentage/100))) end)
                                                                    AND upper(proposal_reason) = upper(v_reason_code)
                                                                    AND c.pay_proposal_id = v_pay_proposal_id;

                                                                fnd_file.put_line(fnd_file.log, 'Updated proposal reason count check EE# '
                                                                                                || r_data.emp_no
                                                                                                || ' is '
                                                                                                || v_rsn_code_cnt);

                                                            EXCEPTION
                                                                WHEN no_data_found THEN
                                                                    v_rsn_code_cnt := 0;
                                                                WHEN OTHERS THEN
                                                                    v_rsn_code_cnt := 0;
                                                                    fnd_file.put_line(fnd_file.log, 'Reason code not updated after the salary load for EE# '
                                                                                                    || r_data.emp_no
                                                                                                    || ' Business Group is '
                                                                                                    || v_name
                                                                                                    || ' is'
                                                                                                    || sqlerrm);

                                                                    UPDATE apps.xx_sal_upd_tbl
                                                                    SET
                                                                        err_msg = 'Record is not updated as Reason code not updated
                                                            after the salary load program for EE# '
                                                                                  || r_data.emp_no
                                                                                  || ' Business Group is '
                                                                                  || v_name,
                                                                        status = 'FAILED'
                                                                    WHERE
                                                                        emp_no = r_data.emp_no;

                                                            END;

                                                            IF v_rsn_code_cnt > 0 THEN
                                                                v_rsn_code_err := NULL;
                                                                COMMIT;
                                                            ELSE
                                                                ROLLBACK;
                                                                UPDATE apps.xx_sal_upd_tbl
                                                                SET
                                                                    err_msg = 'Record is not updated as Reason code not updated
                                                            after the salary load program for EE# '
                                                                              || r_data.emp_no
                                                                              || ' Business Group is '
                                                                              || v_name,
                                                                    status = 'FAILED'
                                                                WHERE
                                                                    emp_no = r_data.emp_no;

                                                                fnd_file.put_line(fnd_file.log, 'Record is not updated as Reason code is not updated after the salary load program for EE# '
                                                                || r_data.emp_no);
                                                                v_rsn_code_err := 'Record is not updated as Reason code is not updated after the salary load program'
                                                                ;
                                                            END IF;

                                                            v_cnt := v_cnt + 1;
                                                            COMMIT;
                                                            BEGIN
                                                                SELECT
                                                                    ppb.name
                                                                INTO v_new_basis
                                                                FROM
                                                                    per_pay_bases           ppb,
                                                                    per_all_people_f        papf,
                                                                    per_all_assignments_f   paaf
                                                                WHERE
                                                                    1 = 1
                                                                    AND papf.person_id = paaf.person_id
                                                                    AND papf.employee_number = r_data.emp_no--'3190457'
                                                                    AND paaf.pay_basis_id = ppb.pay_basis_id (+)
                                                                    AND trunc(sysdate) BETWEEN papf.effective_start_date AND papf
                                                                    .effective_end_date
                                                                    AND trunc(sysdate) BETWEEN paaf.effective_start_date AND paaf
                                                                    .effective_end_date;

                                                            EXCEPTION
                                                                WHEN OTHERS THEN
                                                                    fnd_file.put_line(fnd_file.log, 'Error while fetching latest Salary basis for EE#'
                                                                                                    || ' '
                                                                                                    || r_data.emp_no);
                                                            END;

                                                            IF v_rsn_code_err IS NULL THEN
                                                                UPDATE apps.xx_sal_upd_tbl
                                                                SET
                                                                    status = 'SUCCESS',
                                                                    old_salary_basis = v_old_basis,
                                                                    new_salary_basis = v_new_basis,
                                                                    old_salary = v_old_salary,
                                                                    last_sal_change_date = v_old_change_date
                                                                WHERE
                                                                    emp_no = r_data.emp_no;

                                                            ELSE
                                                                UPDATE apps.xx_sal_upd_tbl
                                                                SET
                                                                    status = 'FAILED',
                                                                    err_msg = v_rsn_code_err
                                                                WHERE
                                                                    emp_no = r_data.emp_no;

                                                            END IF;

                                                        EXCEPTION
                                                            WHEN OTHERS THEN
                                                                fnd_file.put_line(fnd_file.log, 'Error in API for EE#'
                                                                                                || r_data.emp_no
                                                                                                || ' Error is '
                                                                                                || sqlerrm);

                                                                v_api_err := 'Error in API for EE#'
                                                                             || r_data.emp_no
                                                                             || ' Error is '
                                                                             || sqlerrm;
                                                                UPDATE apps.xx_sal_upd_tbl
                                                                SET
                                                                    err_msg = v_api_err,
                                                               --     err_msg = 'Error:In API while updating Salary',
                                                                    status = 'FAILED'
                                                                WHERE
                                                                    emp_no = r_data.emp_no;

                                                        END;
                                                    END IF; -- Elementary id end if

                                                END IF; -- Assignment id end if

                                            END IF;--   person id end if

                                        END IF; -- Proposal code end if

                                    END IF; -- future salary changes end if TASK0656850
                                END IF;

                            ELSE --new salary details #TASK1279003
                                fnd_file.put_line(fnd_file.log, 'Salary details not exists for EE# '
                                                                || r_data.emp_no
                                                                || ' loading with new salary details');

                                IF v_assignment_id IS NOT NULL AND v_pay_basis_id IS NOT NULL THEN
                                    BEGIN
                                        SELECT DISTINCT
                                            a.lookup_code
                                        INTO v_reason_code
                                        FROM
                                            apps.fnd_lookup_values        a,
                                            apps.fnd_security_groups_vl   b,
                                            per_business_groups           c
                                        WHERE
                                            a.security_group_id = b.security_group_id
                                            AND a.enabled_flag = 'Y'
                                            AND a.lookup_type = 'PROPOSAL_REASON'
                                            AND b.security_group_id = c.security_group_id
                                            AND upper(a.meaning) = upper(r_data.proposal_reason)
                                            AND ( ( upper(c.name) = upper(v_name) )
                                                  OR ( upper(c.name) = 'STANDARD' ) )
                                            AND ROWNUM = 1;

                                    EXCEPTION
                                        WHEN no_data_found THEN
                                            v_reason_code := NULL;
                                        WHEN OTHERS THEN
                                            v_reason_code := NULL;
                                            fnd_file.put_line(fnd_file.log, 'Error in finding reason code for EE# '
                                                                            || r_data.emp_no
                                                                            || ' Business Group is '
                                                                            || v_name
                                                                            || ' is'
                                                                            || sqlerrm);

                                            UPDATE apps.xx_sal_upd_tbl
                                            SET
                                                err_msg = 'Error:While finding reason code ',
                                                status = 'FAILED'
                                            WHERE
                                                emp_no = r_data.emp_no;

                                    END;

                                    IF v_reason_code IS NOT NULL THEN
                                        BEGIN
                  --Call update Salary Proposal API
                                            hr_maintain_proposal_api.cre_or_upd_salary_proposal(    -- Input data elements
         -- ------------------------------
                                            p_business_group_id => p_business_group_id, p_assignment_id => v_assignment_id, p_change_date => r_data.change_date, p_proposal_reason
                                            => v_reason_code, p_proposed_salary_n => r_data.salary,
                                                                                                p_approved => 'Y',
         -- Output data elements
         -- --------------------------------
                                                                                                 p_pay_proposal_id => v_pay_proposal_id, p_object_version_number => v_object_version_number, p_inv_next_sal_date_warning => v_inv_next_sal_date_warning
                                                                                                , p_proposed_salary_warning => v_proposed_salary_warning
                                                                                                ,
                                                                                                p_approved_warning => v_approved_warning
                                                                                                , p_payroll_warning => v_payroll_warning
                                                                                                );

                                            fnd_file.put_line(fnd_file.log, 'v_pay_proposal_id ' || v_pay_proposal_id);
                            /*
                            BEGIN
                                UPDATE hr.per_pay_proposals
                                    SET
                                        proposal_reason = v_code
                                WHERE
                                    pay_proposal_id = v_pay_proposal_id;

                            EXCEPTION
                                WHEN OTHERS THEN
                                    fnd_file.put_line(
                                        fnd_file.log,
                                        'Error in Updating reason code in per_pay_proposals for EE#'
                                         || r_data.emp_no
                                         || ' Proposal id is '
                                         || v_pay_proposal_id
                                         || ' reason is '
                                         || r_data.proposal_reason
                                    );

                                    UPDATE apps.xx_sal_upd_tbl
                                        SET
                                            err_msg = 'Error:In Updating Salary Reason Code',
                                            status = 'FAILED'
                                    WHERE
                                        emp_no = r_data.emp_no;

                            END;
*/
                           -- Salary reason code not updating issue #TASK1279003
                                            BEGIN
                                                SELECT DISTINCT
                                                    COUNT(proposal_reason)
                                                INTO v_rsn_code_cnt
                                                FROM
                                                    per_all_people_f        a,
                                                    per_all_assignments_f   b,
                                                    per_pay_proposals       c
                                                WHERE
                                                    a.person_id = b.person_id
                                                    AND trunc(sysdate) BETWEEN a.effective_start_date AND a.effective_end_date
                                                    AND trunc(sysdate) BETWEEN b.effective_start_date AND b.effective_end_date
                                                    AND r_data.change_date BETWEEN c.change_date AND c.date_to
                                                    AND b.assignment_id = c.assignment_id
                                                    AND a.current_employee_flag = 'Y'
                                                    AND a.employee_number = r_data.emp_no
                                                    AND a.business_group_id = p_business_group_id
                                                    AND c.creation_date >= sysdate - 2
                                                    AND proposed_salary_n = r_data.salary
                                                    AND upper(proposal_reason) = upper(v_reason_code)
                                                    AND c.pay_proposal_id = v_pay_proposal_id;

                                                fnd_file.put_line(fnd_file.log, 'Updated proposal reason count check EE# '
                                                                                || r_data.emp_no
                                                                                || ' is '
                                                                                || v_rsn_code_cnt);

                                            EXCEPTION
                                                WHEN no_data_found THEN
                                                    v_rsn_code_cnt := 0;
                                                WHEN OTHERS THEN
                                                    v_rsn_code_cnt := 0;
                                                    fnd_file.put_line(fnd_file.log, 'Reason code not updated after the salary load for EE# '
                                                                                    || r_data.emp_no
                                                                                    || ' Business Group is '
                                                                                    || v_name
                                                                                    || ' is'
                                                                                    || sqlerrm);

                                                    UPDATE apps.xx_sal_upd_tbl
                                                    SET
                                                        err_msg = 'Record is not updated as Reason code not updated after the salary load program for EE# '
                                                                  || r_data.emp_no
                                                                  || ' Business Group is '
                                                                  || v_name,
                                                        status = 'FAILED'
                                                    WHERE
                                                        emp_no = r_data.emp_no;

                                            END;

                                            IF v_rsn_code_cnt > 0 THEN
                                                v_rsn_code_err := NULL;
                                                COMMIT;
                                            ELSE
                                                ROLLBACK;
                                                UPDATE apps.xx_sal_upd_tbl
                                                SET
                                                    err_msg = 'Record is not updated as Reason code not updated after the salary load program for EE# '
                                                              || r_data.emp_no
                                                              || ' Business Group is '
                                                              || v_name,
                                                    status = 'FAILED'
                                                WHERE
                                                    emp_no = r_data.emp_no;

                                                fnd_file.put_line(fnd_file.log, 'Record is not updated as Reason code is not updated after the salary load program for EE# '
                                                || r_data.emp_no);
                                                v_rsn_code_err := 'Record is not updated as Reason code is not updated after the salary load program'
                                                ;
                                            END IF;

                                            v_cnt := v_cnt + 1;
                                            COMMIT;
                                            BEGIN
                                                SELECT
                                                    ppb.name
                                                INTO v_new_basis
                                                FROM
                                                    per_pay_bases           ppb,
                                                    per_all_people_f        papf,
                                                    per_all_assignments_f   paaf
                                                WHERE
                                                    1 = 1
                                                    AND papf.person_id = paaf.person_id
                                                    AND papf.employee_number = r_data.emp_no
                                                    AND paaf.pay_basis_id = ppb.pay_basis_id (+)
                                                    AND trunc(sysdate) BETWEEN papf.effective_start_date AND papf.effective_end_date
                                                    AND trunc(sysdate) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
                                                    ;

                                            EXCEPTION
                                                WHEN OTHERS THEN
                                                    fnd_file.put_line(fnd_file.log, 'Error while fetching latest Salary basis for EE#'
                                                                                    || ' '
                                                                                    || r_data.emp_no);
                                            END;

                                            IF v_rsn_code_err IS NULL THEN
                                                UPDATE apps.xx_sal_upd_tbl
                                                SET
                                                    status = 'SUCCESS',
                                                    old_salary_basis = NULL,
                                                    new_salary_basis = v_new_basis,
                                                    old_salary = NULL,
                                                    last_sal_change_date = NULL
                                                WHERE
                                                    emp_no = r_data.emp_no;

                                            ELSE
                                                UPDATE apps.xx_sal_upd_tbl
                                                SET
                                                    status = 'FAILED',
                                                    err_msg = v_rsn_code_err
                                                WHERE
                                                    emp_no = r_data.emp_no;

                                            END IF;

                                        EXCEPTION
                                            WHEN OTHERS THEN
                                                fnd_file.put_line(fnd_file.log, 'Error in API for EE#'
                                                                                || r_data.emp_no
                                                                                || ' Error is '
                                                                                || sqlerrm);

                                                v_api_err := 'Error in API for EE#'
                                                             || r_data.emp_no
                                                             || ' Error is '
                                                             || sqlerrm;
                                                UPDATE apps.xx_sal_upd_tbl
                                                SET
                                                    err_msg = v_api_err,

                                               --     err_msg = 'Error:In API while inserting Salary',
                                                    status = 'FAILED'
                                                WHERE
                                                    emp_no = r_data.emp_no;

                                        END;

                                        v_rsn_err := NULL;
                                    ELSE
                                        fnd_file.put_line(fnd_file.log, 'Passing reason code - '
                                                                        || r_data.proposal_reason
                                                                        || 'is not valid for EE#'
                                                                        || ' '
                                                                        || r_data.emp_no);

                                        UPDATE apps.xx_sal_upd_tbl
                                        SET
                                            err_msg = 'Passing reason code - '
                                                      || r_data.proposal_reason
                                                      || ' is not valid',
                                            status = 'FAILED'
                                        WHERE
                                            emp_no = r_data.emp_no;

                                        v_rsn_err := 'Passing reason code - '
                                                     || r_data.proposal_reason
                                                     || ' is not valid';
                                    END IF; --reason code end if

                                END IF; --  assignment_id end if

                            END IF;                -- salary exists or not end if TASK1279003

                        ELSE
                            UPDATE apps.xx_sal_upd_tbl
                            SET
                                err_msg = 'Invalid Business Group chosen for EE# ' || r_data.emp_no,
                                status = 'FAILED'
                            WHERE
                                emp_no = r_data.emp_no;

                        END IF; -- Business Groupd is valid or not end if TASK1279003

                    END IF; -- Employee Number is valid or not end if TASK1279003

                    COMMIT;
                END IF;

            END LOOP;

            BEGIN
                print_line('Salaries processed successfully for below employees');
                print_line('---------------------------------------------------------------');
                print_line('Employee_Number|Old_Salary_Basis|New_Salary_Basis|Old_Salary|Last_Salary_Change_Date|New_Salary|New_Salary_Change_Date|Change%'
                );
                FOR s_data IN c_process_data LOOP print_line(s_data.emp_no
                                                             || '|'
                                                             || s_data.old_salary_basis
                                                             || '|'
                                                             || s_data.new_salary_basis
                                                             || '|'
                                                             || s_data.old_salary
                                                             || '|'
                                                             || to_char(s_data.last_sal_change_date, 'DD-MON-YYYY')
                                                             || '|'
                                                             || s_data.salary
                                                             || '|'
                                                             || to_char(s_data.change_date, 'DD-MON-YYYY')
                                                             || '|'
                                                             || s_data.SALARY_PERCENTAGE);
                END LOOP;

            END;

            print_line('                                                         ');
            print_line('                                                         ');
            BEGIN
                print_line('Salary not processed due to future dated changes Or due to same salary upload');
                print_line('-------------------------------------------------------------------------------------------------');
                print_line('Employee_Number|Future_Salary|Future_Date');
                FOR f_data IN c_process_data2 LOOP print_line(f_data.emp_no
                                                              || '|'
                                                              || f_data.future_salary
                                                              || '|'
                                                              || to_char(f_data.future_sal_date, 'DD-MON-YYYY'));
                END LOOP;

            END;

            print_line('                                                         ');
            print_line('                                                         ');
            BEGIN
                print_line('Salary not processed due to same salary upload');
                print_line('-------------------------------------------------------------------------------------------------');
                print_line('Employee_Number|Old_Salary|New_Salary');
                FOR f_data IN c_process_data3 LOOP print_line(f_data.emp_no
                                                              || '|'
                                                              || f_data.old_salary
                                                              || '|'
                                                              || f_data.future_salary);
                END LOOP;

            END;
--#TASK1279003 To print the reason code error in the output

            print_line('                                                         ');
            print_line('                                                         ');
            BEGIN
                print_line('Salary not processed due to other reasons');
                print_line('-------------------------------------------------------------------------------------------------');
                print_line('Employee_Number|Reason_Code|Error_Message');
                FOR f_data IN c_process_data4 LOOP print_line(f_data.emp_no
                                                              || '|'
                                                              || f_data.proposal_reason_code
                                                              || '|'
                                                              || f_data.err_msg);
                END LOOP;

            END;

        END IF;  -- Org name end if

        BEGIN
            SELECT
                COUNT(*)
            INTO v_tot_record
            FROM
                ttec_sal_load;

        EXCEPTION
            WHEN OTHERS THEN
                print_line('Error in counting interface table (ttec_sal_load)');
        END;

        print_line('');
        print_line('TOTAL RECORDS ARE IN THE FILE = ' || v_tot_record);
        print_line('TOTAL EMPLOYEES ARE SUCCESSFULLY LOADED =  ' || v_cnt);
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END import_sal_change;

END tt_brz_salchg_pkg;
/
show errors;
/