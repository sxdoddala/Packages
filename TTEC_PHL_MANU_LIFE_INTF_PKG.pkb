create or replace PACKAGE BODY           ttec_phl_manu_life_intf_pkg IS
 /*$Header:   APPS.TTEC_PHL_MANU_LIFE_INTF_PKG 1.0 01-OCT-2019
 == START =======================================================================
       Author:  Hari Varma CTS
         Date:  10/1/2019
         Desc:  This package is to provide manulife coverage details for PHL

       Modification History:

      Version    Date          Author      Description (Include Ticket#)
      -----     -------------  --------    ------------------------------------
      1.0        01-OCT-2019   CTS         Draft version
	   1.0   04-May-2023      MXKEERTHI(ARGANO)          R12.2 Upgrade Remediation
   == END ======================================================================*/

    g_user_id           NUMBER := to_number(fnd_profile.value('USER_ID') );
    g_conc_request_id   NUMBER := fnd_global.conc_request_id;
    g_resp_id           NUMBER := fnd_global.resp_id;
    g_resp_appl_id      NUMBER := fnd_global.resp_appl_id;

    PROCEDURE ttec_phl_manulife_intf_error (
        p_application_code   VARCHAR2,
        p_program_name       VARCHAR2,
        p_module_name        VARCHAR2,
        p_status             VARCHAR2,
        p_error_code         VARCHAR2,
        p_error_message      VARCHAR2
    )
        IS
    BEGIN
        INSERT INTO apps.ttec_phl_manu_life_intf_error (
            transaction_id,
            application_code,
            interface,
            program_name,
            module_name,
            concurrent_request_id,
            status,
            error_code,
            error_message,
            last_update_date,
            last_updated_by,
            creation_date,
            created_by
        ) VALUES (
            ttec_phl_manulife_intf_error_s.NEXTVAL,
            p_application_code,
            'PHL Manulife Coverage details',
            p_program_name,
            p_module_name,
            g_conc_request_id,
            p_status,
            p_error_code,
            p_error_message,
            SYSDATE,
            g_user_id,
            SYSDATE,
            g_user_id
        );

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            fnd_file.put_line(
                fnd_file.log,
                'Error while Inserting into ttec_phl_manu_life_intf_error Table-- ' || sqlerrm
            );
    END ttec_phl_manulife_intf_error;

    PROCEDURE ttec_phl_file_gen (
        p_errbuff   OUT VARCHAR2,
        p_retcode   OUT NUMBER
    ) IS

        r_employee        apps.ttec_phl_manulife_intf_stg%rowtype;
        v_host_name       VARCHAR2(50);
        v_instance_name   VARCHAR2(50);
        v_file_extn       VARCHAR2(10);
        v_dir_path        VARCHAR2(250);
        v_out_file        VARCHAR2(120);
        v_out_file1       VARCHAR2(120);
        v_text            VARCHAR2(100);
        v_text1           VARCHAR2(100);
        v_text2           VARCHAR2(30000);
        v_text3           VARCHAR2(100);
        v_text4           VARCHAR2(100);
        v_text5           VARCHAR2(30000);
        v_dt_time         VARCHAR2(15);
        v_phl_file        utl_file.file_type;
        v_phl_file1       utl_file.file_type;
        v_count_utl       NUMBER;
        v_loc             NUMBER;
    BEGIN
        v_loc := 395;
        fnd_file.put_line(
            fnd_file.log,
            'Inside the v_dt_time'
        );
        SELECT
            TO_CHAR(
                SYSDATE,
                'YYYYMMDDHH24MMSS'
            )
        INTO
            v_dt_time
        FROM
            dual;

        v_loc := 400;
        fnd_file.put_line(
            fnd_file.log,
            'Inside the v_dir_path'
        );
        SELECT
            directory_path || '/data/EBS/HC/Benefits/phl/manulife/Outbound'
        INTO
            v_dir_path
        FROM
            dba_directories
        WHERE
            directory_name = 'CUST_TOP';

        v_loc := 405;
        fnd_file.put_line(
            fnd_file.log,
            'Inside the host_name'
        );
        SELECT
            host_name,
            DECODE(
                host_name,
                ttec_library.xx_ttec_prod_host_name,
                NULL,
                '-TEST'
            )
        INTO
            v_host_name,v_instance_name
        FROM
            v$instance;

        v_loc := 410;
        BEGIN
            fnd_file.put_line(
                fnd_file.log,
                'Inside the v_file_extn'
            );
            SELECT
                '.CSV'
            INTO
                v_file_extn
            FROM
                v$instance;

        EXCEPTION
            WHEN OTHERS THEN
                v_file_extn := '.csv';
        END;

        BEGIN
            v_loc := 415;
            v_count_utl := 0;
            fnd_file.put_line(
                fnd_file.log,
                'Extension name:' || v_file_extn
            );
            v_out_file := 'TTEC_PHL_MANULIFE_TestFile_' ||v_dt_time || v_file_extn;

            v_loc := 420;
            fnd_file.put_line(
                fnd_file.log,
                'FILE name:' || v_out_file
            );
            v_phl_file := utl_file.fopen(
                v_dir_path,
                v_out_file,
                'w',
                32000
            );
            fnd_file.put_line(
                fnd_file.log,
                'DIR path: ' || v_dir_path
            );
            v_loc := 425;
            --Header for the File
            v_text := 'ACCOUNT NAME: |TeleTech';
            v_text1 := 'POLICY NO.:|11111';
            v_text2 := 'EMP_NUMBER|LAST_NAME|FIRST_NAME|MIDDLE_NAME|GENDER|BIRTH_DATE|OCCUPATION|LOCATION|CLASSIFICATION|SALARY|PROPOSED_COVERAGE|REMARKS|EFFECTIVE_DATE'
;

            v_loc := 430;
            utl_file.put_line(
                v_phl_file,
                v_text
            );
            utl_file.put_line(
                v_phl_file,
                v_text1
            );
            utl_file.put_line(
                v_phl_file,
                v_text2
            );
            v_loc := 435;

      fnd_file.put_line(fnd_file.OUTPUT,'ACCOUNT NAME: TeleTech');
      fnd_file.put_line(fnd_file.OUTPUT,'POLICY NO.: 11111');

      fnd_file.put_line(fnd_file.OUTPUT,'Emp_Number|Last_Name|First_Name|Middle_Name|Gender|Birth_Date|Occupation|Location|Classification|Salary|Proposed_Coverage|Remarks|Effective_Date');

            FOR r_emp_rec IN (
                SELECT
                    emp_number,
                    last_name,
                    first_name,
                    middle_name,
                    gender,
                    birth_date,
                    occupation,
					location,
                    classification,
                    salary,
                    proposed_coverage,
                    remarks,
                    effective_date
                FROM
                    apps.ttec_phl_manulife_intf_stg where remarks <> 'Deletion' or remarks is null
                ORDER BY emp_number
            ) LOOP                                                --start loop
                v_text2 := '';
                v_loc := 440;
                v_text2 := r_emp_rec.emp_number
                 || '|'
                 || r_emp_rec.last_name
                 || '|'
                 || r_emp_rec.first_name
                 || '|'
                 || r_emp_rec.middle_name
                 || '|'
                 || r_emp_rec.gender
                 || '|'
                 || r_emp_rec.birth_date
                 || '|'
                 || r_emp_rec.occupation
                 || '|'
				 || r_emp_rec.location
                 || '|'
                 || r_emp_rec.classification
                 || '|'
                 || r_emp_rec.salary
                 || '|'
                 || r_emp_rec.proposed_coverage
                 || '|'
                 || r_emp_rec.remarks
                 || '|'
                 || r_emp_rec.effective_date;

                v_loc := 435;
                utl_file.put_line(
                    v_phl_file,
                    v_text2
                );
                v_count_utl := v_count_utl + 1;
                v_loc := 440;


            fnd_file.put_line(fnd_file.OUTPUT,
                    r_emp_rec.emp_number || '|' ||
					r_emp_rec.last_name || '|' ||
					r_emp_rec.first_name || '|' ||
					r_emp_rec.middle_name || '|' ||
					r_emp_rec.gender || '|' ||
					r_emp_rec.birth_date || '|' ||
					r_emp_rec.occupation || '|' ||
					r_emp_rec.location || '|' ||
					r_emp_rec.classification || '|' ||
					r_emp_rec.salary || '|' ||
					r_emp_rec.proposed_coverage || '|' ||
					r_emp_rec.remarks || '|' ||
					r_emp_rec.effective_date );
            END LOOP;                                             --end loop



            fnd_file.put_line(
                fnd_file.output,
                'Please go to below path for the file generated.'
            );
            fnd_file.put_line(
                fnd_file.output,
                v_dir_path
            );
            fnd_file.put_line(
                fnd_file.log,
                'Total number of records processed : ' || v_count_utl
            );
            COMMIT;
            utl_file.fclose(v_phl_file);
            END;
	----------------------------------------------------------------------------------------------------------------------------
    BEGIN
            v_loc := 500;
            v_count_utl := 0;
            fnd_file.put_line(
                fnd_file.log,
                'Extension name:' || v_file_extn
            );
            v_out_file1 := 'TTEC_PHL_MANULIFE_DELETION_TestFile_' ||v_dt_time || v_file_extn;

            v_loc := 505;
            fnd_file.put_line(
                fnd_file.log,
                'FILE name:' || v_out_file1
            );
            v_phl_file1 := utl_file.fopen(
                v_dir_path,
                v_out_file1,
                'w',
                32000
            );
            fnd_file.put_line(
                fnd_file.log,
                'DIR path: ' || v_dir_path
            );
            v_loc := 510;
            --Header for the File
            v_text3 := 'ACCOUNT NAME: |TeleTech';
            v_text4 := 'POLICY NO.:|11111';
            v_text5 := 'EMP NUMBER|LAST_NAME|FIRST_NAME|MIDDLE_NAME|GENDER|BIRTH_DATE|OCCUPATION|LOCATION|CLASSIFICATION|SALARY|PROPOSED_COVERAGE|REMARKS|EFFECTIVE_DATE|END_COVERAGE_DATE';

            v_loc := 515;
            utl_file.put_line(
                v_phl_file1,
                v_text3
            );
            utl_file.put_line(
                v_phl_file1,
                v_text4
            );
            utl_file.put_line(
                v_phl_file1,
                v_text5
            );
            v_loc := 520;

      fnd_file.put_line(fnd_file.OUTPUT,'ACCOUNT NAME: TeleTech');
      fnd_file.put_line(fnd_file.OUTPUT,'POLICY NO.: 11111');

      fnd_file.put_line(fnd_file.OUTPUT,'Emp_Number|Last_Name|First_Name|Middle_Name|Gender|Birth_Date|Occupation|Location|Classification|Salary|Proposed_Coverage|Remarks|Effective_Date|End_Coverage_Date');

            FOR r_emp_rec IN (
                select emp_number,
                    last_name,
                    first_name,
                    middle_name,
                    gender,
                    birth_date,
                    occupation,
					location,
                    classification,
                    salary,
                    proposed_coverage,
                    remarks,
                    effective_date,
					end_coverage_date
                from
                   apps.ttec_phl_manulife_del_intf_stg s1
                where 1=1
                and s1.CONC_REQUEST_ID = g_conc_request_id
                and trunc(s1.creation_date)=trunc(sysdate)
                and not exists (select 1 from apps.ttec_phl_manulife_del_intf_stg s2
                                         where s2.CONC_REQUEST_ID <> g_conc_request_id
                                          and s2.emp_number =  s1.emp_number
                                          and trunc(s2.creation_date)=trunc(sysdate))
                 ORDER BY emp_number
            ) LOOP                                                --start loop
                v_text5 := '';
                v_loc := 525;
                v_text5 := r_emp_rec.emp_number
                 || '|'
                 || r_emp_rec.last_name
                 || '|'
                 || r_emp_rec.first_name
                 || '|'
                 || r_emp_rec.middle_name
                 || '|'
                 || r_emp_rec.gender
                 || '|'
                 || r_emp_rec.birth_date
                 || '|'
                 || r_emp_rec.occupation
                 || '|'
				 || r_emp_rec.location
                 || '|'
                 || r_emp_rec.classification
                 || '|'
                 || r_emp_rec.salary
                 || '|'
                 || r_emp_rec.proposed_coverage
                 || '|'
                 || r_emp_rec.remarks
                 || '|'
                 || r_emp_rec.effective_date
				 || '|'
                 || r_emp_rec.end_coverage_date;

                v_loc := 530;
                utl_file.put_line(
                    v_phl_file1,
                    v_text5
                );
                v_count_utl := v_count_utl + 1;
                v_loc := 535;


            fnd_file.put_line(fnd_file.OUTPUT,
                    r_emp_rec.emp_number || '|' ||
					r_emp_rec.last_name || '|' ||
					r_emp_rec.first_name || '|' ||
					r_emp_rec.middle_name || '|' ||
					r_emp_rec.gender || '|' ||
					r_emp_rec.birth_date || '|' ||
					r_emp_rec.occupation || '|' ||
					r_emp_rec.location || '|' ||
					r_emp_rec.classification || '|' ||
					r_emp_rec.salary || '|' ||
					r_emp_rec.proposed_coverage || '|' ||
					r_emp_rec.remarks || '|' ||
					r_emp_rec.effective_date || '|' ||
					r_emp_rec.end_coverage_date
					);

            END LOOP;                                             --end loop



            fnd_file.put_line(
                fnd_file.output,
                'Please go to below path for the file generated.'
            );
            fnd_file.put_line(
                fnd_file.output,
                v_dir_path
            );
            fnd_file.put_line(
                fnd_file.log,
                'Total number of records processed : ' || v_count_utl
            );
            COMMIT;
            utl_file.fclose(v_phl_file1);


            v_loc := 540;
        EXCEPTION
            WHEN OTHERS THEN
                ttec_phl_manulife_intf_error(
                    NULL,
                    'ttec_phl_manulife_csv_pkg.ttec_phl_file_gen',
                    'TTech PHL MANULIFE CSV Interface -UTL file Issues',
                    'Error',
                    v_loc,
                    sqlerrm
                );
        END;

        v_loc := 545;
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ttec_phl_manulife_intf_error(
                NULL,
                'ttec_phl_manulife_csv_pkg.ttec_phl_file_gen',
                'TTech PHL MANULIFE Interface',
                'Error',
                v_loc,
                sqlerrm
            );
            fnd_file.put_line(
                fnd_file.log,
                sqlerrm || '-' || sqlcode
            );
    END ttec_phl_file_gen;

    PROCEDURE ttec_phl_manulife_main (
        p_errbuff           OUT VARCHAR2,
        p_retcode           OUT NUMBER,
        p_coverage_date     IN VARCHAR2
    ) IS

        r_employee          apps.ttec_phl_manulife_intf_stg%rowtype;
        r_emp_del           apps.ttec_phl_manulife_del_intf_stg%rowtype;
        v_loc               NUMBER;
        l_count             NUMBER := 0;
		v_last_run_date     DATE;
        l_date              VARCHAR2(30);


        CURSOR c_manulife_details IS
            SELECT DISTINCT
                papf.employee_number,
                papf.last_name,
                papf.first_name,
                papf.middle_names,
                papf.sex,
                papf.date_of_birth,
                pj.attribute5,
				REPLACE (hl.location_code , ',', '') location,
                ttec_get_rank_classification(
                    papf.person_id,
                    SYSDATE,
                    ppb.name,
                    pj.attribute6,
                    1517
                ) classification,
                (
                    SELECT
                        round(
                            (ppb.pay_annualization_factor * ppps.proposed_salary_n),
                            2
                        ) salary
                    FROM
					    -- hr.per_pay_proposals ppps --Commented code by MXKEERTHI-ARGANO, 05/04/2023
                         apps.per_pay_proposals ppps   --code added by MXKEERTHI-ARGANO, 05/04/2023
                       
                    WHERE
                            paaf.pay_basis_id = ppb.pay_basis_id
                        AND
                            paaf.assignment_id = ppps.assignment_id
                        AND
                            ppps.change_date = (
                                SELECT
                                    MAX(x.change_date)
                                FROM
								    --
                                    --hr.per_pay_proposals x  --Commented code by MXKEERTHI-ARGANO, 05/04/2023
                                  
                                    apps.per_pay_proposals x  --code added by MXKEERTHI-ARGANO, 05/04/2023
   
   
                                WHERE
                                        paaf.assignment_id = x.assignment_id
                                    AND
                                        ( x.change_date ) <= trunc(SYSDATE)
                            )
                ) salary,
                bnft_amt,
				to_char(ENRT_CVG_STRT_DT, 'DD-MON-YYYY') effective_date,
				to_char (least (ENRT_CVG_THRU_DT,bper.effective_end_date), 'DD-MON-YYYY') end_coverage_date
            FROM
                per_all_people_f papf,
                per_all_assignments_f paaf,
                per_business_groups pbg,
                per_jobs pj,
				hr_locations hl,
                per_pay_bases ppb,
                ben.ben_prtt_enrt_rslt_f bper,
                ben.ben_pl_f bpf
            WHERE
                    1 = 1
                AND
                    papf.person_id = paaf.person_id
                AND
                    papf.business_group_id = pbg.business_group_id
                AND
                    papf.current_employee_flag = 'Y'
                AND
                    paaf.primary_flag = 'Y'
                AND
                    pj.job_id = paaf.job_id
                AND
                    ppb.pay_basis_id = paaf.pay_basis_id
				AND
				    hl.location_id=paaf.location_id
                AND
                    bper.person_id = paaf.person_id
                AND
                    pbg.business_group_id = 1517
                AND
                    bper.pl_id = bpf.pl_id
                AND
                    bpf.name = 'Basic Life Insurance'
                AND
                    bpf.pl_stat_cd = 'A'
                AND
                    bper.prtt_enrt_rslt_stat_cd is null
                AND
                    bper.sspndd_flag(+) = 'N'
                AND
                   FND_DATE.CANONICAL_TO_DATE (P_COVERAGE_DATE) BETWEEN papf.effective_start_date AND papf.effective_end_date
                AND
                   FND_DATE.CANONICAL_TO_DATE (P_COVERAGE_DATE) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
                AND
                   nvl(bper.enrt_cvg_thru_dt,FND_DATE.CANONICAL_TO_DATE(P_COVERAGE_DATE)) <= nvl(bper.effective_end_date,FND_DATE.CANONICAL_TO_DATE(P_COVERAGE_DATE))
                AND
                   (FND_DATE.CANONICAL_TO_DATE(P_COVERAGE_DATE) BETWEEN bper.enrt_cvg_strt_dt and bper.enrt_cvg_thru_dt
                OR
                   (FND_DATE.CANONICAL_TO_DATE(P_COVERAGE_DATE) >= bper.enrt_cvg_strt_dt and FND_DATE.CANONICAL_TO_DATE(P_COVERAGE_DATE) <=bper.enrt_cvg_thru_dt)
                OR
                  (FND_DATE.CANONICAL_TO_DATE(P_COVERAGE_DATE) <= bper.enrt_cvg_strt_dt and FND_DATE.CANONICAL_TO_DATE(P_COVERAGE_DATE) >= bper.enrt_cvg_thru_dt)
                OR
                   bper.enrt_cvg_strt_dt is null and bper.enrt_cvg_thru_dt is null)
                AND
                   FND_DATE.CANONICAL_TO_DATE (P_COVERAGE_DATE) BETWEEN bpf.effective_start_date AND bpf.effective_end_date;

	    CURSOR c_manulife_details_deletion (p_last_run_date IN VARCHAR2 , p_coverage_date IN VARCHAR2 ) IS
            SELECT DISTINCT
                papf.employee_number,
                papf.last_name,
                papf.first_name,
                papf.middle_names,
                papf.sex,
                papf.date_of_birth,
                pj.attribute5,
				REPLACE (hl.location_code , ',', '') location,
                ttec_get_rank_classification(
                    papf.person_id,
                    SYSDATE,
                    ppb.name,
                    pj.attribute6,
                    1517
                ) classification,
                (
                    SELECT
                        round(
                            (ppb.pay_annualization_factor * ppps.proposed_salary_n),
                            2
                        ) salary
					
                    FROM
					--hr.per_pay_proposals ppps  --Commented code by MXKEERTHI-ARGANO, 05/04/2023
                    hr.per_pay_proposals ppps--code added by MXKEERTHI-ARGANO, 05/04/2023
 
                        
                    WHERE
                            paaf.pay_basis_id = ppb.pay_basis_id
                        AND
                            paaf.assignment_id = ppps.assignment_id
                        AND
                            ppps.change_date = (
                                SELECT
                                    MAX(x.change_date)
                                FROM
								    --  hr.per_pay_proposals x   --Commented code by MXKEERTHI-ARGANO, 05/04/2023
                                     apps.per_pay_proposals x --code added by MXKEERTHI-ARGANO, 05/04/2023
                                  
                                WHERE
                                        paaf.assignment_id = x.assignment_id
                                    AND
                                        ( x.change_date ) <= trunc(SYSDATE)
                            )
                ) salary,
                bnft_amt,
				to_char(ENRT_CVG_STRT_DT, 'DD-MON-YYYY') effective_date,
				to_char (least (ENRT_CVG_THRU_DT,bper.effective_end_date), 'DD-MON-YYYY') end_coverage_date
            FROM
                per_all_people_f papf,
                per_all_assignments_f paaf,
                per_business_groups pbg,
                per_jobs pj,
				hr_locations hl,
                per_pay_bases ppb,
				  	  --START R12.2 Upgrade Remediation
	  /*
	    	Commented code by MXKEERTHI-ARGANO, 05/04/2023
                ben.ben_prtt_enrt_rslt_f bper,
                ben.ben_pl_f bpf
	   */
	  --code Added  by MXKEERTHI-ARGANO, 05/04/2023
	            ben.ben_prtt_enrt_rslt_f bper,
                ben.ben_pl_f bpf
	  --END R12.2.10 Upgrade remediation
               
            WHERE
                    1 = 1
                AND
                    papf.person_id = paaf.person_id
                AND
                    papf.business_group_id = pbg.business_group_id
                AND
                    papf.current_employee_flag = 'Y'
                AND
                    paaf.primary_flag = 'Y'
                AND
                    pj.job_id = paaf.job_id
                AND
                    ppb.pay_basis_id = paaf.pay_basis_id
				AND
				    hl.location_id=paaf.location_id
                AND
                    bper.person_id = paaf.person_id
                AND
                    pbg.business_group_id = 1517
                AND
                    bper.pl_id = bpf.pl_id
                AND
                    bpf.name = 'Basic Life Insurance'
                AND
                    bpf.pl_stat_cd = 'A'
                AND
                    bper.prtt_enrt_rslt_stat_cd is null
                AND
                    bper.sspndd_flag(+) = 'N'
                AND
                   FND_DATE.CANONICAL_TO_DATE (p_last_run_date) BETWEEN papf.effective_start_date AND papf.effective_end_date
                AND
                   FND_DATE.CANONICAL_TO_DATE (p_last_run_date) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
                AND
                  ( (trunc(nvl(bper.enrt_cvg_thru_dt,trunc(FND_DATE.CANONICAL_TO_DATE(p_last_run_date)))) > trunc(FND_DATE.CANONICAL_TO_DATE(p_last_run_date))
                     OR
                     trunc(nvl(bper.effective_end_date,trunc(FND_DATE.CANONICAL_TO_DATE(p_last_run_date)))) > trunc(FND_DATE.CANONICAL_TO_DATE(p_last_run_date))
					 )
                AND
                   (trunc(nvl(bper.enrt_cvg_thru_dt,trunc(FND_DATE.CANONICAL_TO_DATE(p_coverage_date)))) <= trunc(FND_DATE.CANONICAL_TO_DATE(p_coverage_date))
				   OR
				   trunc(nvl(bper.effective_end_date,trunc(FND_DATE.CANONICAL_TO_DATE(p_coverage_date)))) <= trunc(FND_DATE.CANONICAL_TO_DATE(p_coverage_date))
				   )
				   )
				AND
				   trunc (bper.last_update_date) between trunc(FND_DATE.CANONICAL_TO_DATE(p_last_run_date)) and trunc(FND_DATE.CANONICAL_TO_DATE(p_coverage_date))
                AND
                   FND_DATE.CANONICAL_TO_DATE (p_last_run_date) BETWEEN bpf.effective_start_date AND bpf.effective_end_date
				AND
				   FND_DATE.CANONICAL_TO_DATE (p_last_run_date) BETWEEN bper.effective_start_date AND bper.effective_end_date;

    BEGIN

        BEGIN
            SELECT
                COUNT(*)
            INTO
                l_count
            FROM
                apps.ttec_phl_manulife_intf_stg;

		------Insert the Manulife data to custom staging table------

            fnd_file.put_line(
                fnd_file.log,
                '...Insertion Manulife data to staging table started...'
            );
            v_loc := 40;
            FOR c_manulife_details_rec IN c_manulife_details LOOP
                BEGIN
                    v_loc := 50;
                    r_employee.emp_number := c_manulife_details_rec.employee_number;
                    r_employee.last_name := c_manulife_details_rec.last_name;
                    r_employee.first_name := c_manulife_details_rec.first_name;
                    r_employee.middle_name := c_manulife_details_rec.middle_names;
                    r_employee.gender := c_manulife_details_rec.sex;
                    r_employee.birth_date := c_manulife_details_rec.date_of_birth;
                    r_employee.occupation := c_manulife_details_rec.attribute5;
					r_employee.location := c_manulife_details_rec.location;
                    r_employee.classification := c_manulife_details_rec.classification;
                    r_employee.salary := c_manulife_details_rec.salary;
                    r_employee.proposed_coverage := c_manulife_details_rec.bnft_amt;
                    r_employee.remarks := 'Addition';
                    r_employee.effective_date := c_manulife_details_rec.effective_date;
                    r_employee.end_coverage_date := c_manulife_details_rec.end_coverage_date;
                    r_employee.conc_request_id := g_conc_request_id;
                    r_employee.last_update_date := SYSDATE;
                    r_employee.last_updated_by := g_user_id;
                    r_employee.creation_date := SYSDATE;
                    r_employee.created_by := g_user_id;

                    v_loc := 90;
                    INSERT INTO apps.ttec_phl_manulife_intf_stg VALUES r_employee;

                    COMMIT;
                END;

            END LOOP;
--           fnd_file.put_line(
--                fnd_file.log,
--                '...Insertion Manulife data to r_employee'
--            );
        FOR c_current IN (select * from apps.ttec_phl_manulife_intf_stg where conc_request_id= g_conc_request_id --and remarks <> 'Deletion' or remarks is null
        ) LOOP

        FOR c_past IN ( select  * from apps.ttec_phl_manulife_intf_stg where conc_request_id <>  g_conc_request_id and emp_number=c_current.emp_number --and remarks <> 'Deletion' or remarks is null
        ) LOOP

--         fnd_file.put_line(
--                fnd_file.log,
--                'inside proposed_coverage '
--            );
             IF c_past.proposed_coverage <> c_current.proposed_coverage THEN
              UPDATE apps.ttec_phl_manulife_intf_stg
                SET
                    remarks = 'Adjustment'
                     WHERE
                          emp_number =c_current.emp_number and conc_request_id= g_conc_request_id;

                  ELSE
                   UPDATE apps.ttec_phl_manulife_intf_stg
                SET
                    remarks = ''
            WHERE
                  emp_number =c_current.emp_number and conc_request_id= g_conc_request_id;

                    END IF;
--                      fnd_file.put_line(
--                fnd_file.log,
--                'inside remarks '
--            );
             END LOOP;
        END LOOP;
           COMMIT;

            DELETE FROM apps.ttec_phl_manulife_intf_stg WHERE
                conc_request_id <> g_conc_request_id;

            DELETE FROM apps.ttec_phl_manu_life_intf_error WHERE creation_date = sysdate-60;

            fnd_file.put_line(
                fnd_file.log,
                'Delete data from ttec_phl_manulife_intf_stg'
            );
            v_loc := 105;
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                ttec_phl_manulife_intf_error(
                    NULL,
                    'ttec_phl_manulife_main.main',
                    'Main Interface',
                    'Error',
                    v_loc,
                    sqlerrm
                );
                v_loc := 110;
        END;

	BEGIN
		SELECT NVL (MAX (actual_start_date), NULL)
           INTO v_last_run_date
           FROM apps.fnd_concurrent_requests fcr,
                apps.fnd_concurrent_programs fcp
          WHERE fcp.concurrent_program_id = fcr.concurrent_program_id
            AND fcp.concurrent_program_name = 'TTEC_PHL_MANULIFE'
            AND fcr.status_code = 'C'
            AND fcr.phase_code = 'C';

   l_date :=to_char(v_last_run_date, 'YYYY/MM/DD HH:MI:SS');
	    FOR c_manulife_deletion_rec IN c_manulife_details_deletion (l_date , p_coverage_date ) LOOP
                BEGIN
                    v_loc := 50;
                    r_emp_del.emp_number := c_manulife_deletion_rec.employee_number;
                    r_emp_del.last_name := c_manulife_deletion_rec.last_name;
                    r_emp_del.first_name := c_manulife_deletion_rec.first_name;
                    r_emp_del.middle_name := c_manulife_deletion_rec.middle_names;
                    r_emp_del.gender := c_manulife_deletion_rec.sex;
                    r_emp_del.birth_date := c_manulife_deletion_rec.date_of_birth;
                    r_emp_del.occupation := c_manulife_deletion_rec.attribute5;
					r_emp_del.location := c_manulife_deletion_rec.location;
                    r_emp_del.classification := c_manulife_deletion_rec.classification;
                    r_emp_del.salary := c_manulife_deletion_rec.salary;
                    r_emp_del.proposed_coverage := c_manulife_deletion_rec.bnft_amt;
                    r_emp_del.remarks := 'DELETION';
                    r_emp_del.effective_date := c_manulife_deletion_rec.effective_date;
					r_emp_del.end_coverage_date := c_manulife_deletion_rec.end_coverage_date;
                    r_emp_del.conc_request_id := g_conc_request_id;
                    r_emp_del.last_update_date := SYSDATE;
                    r_emp_del.last_updated_by := g_user_id;
                    r_emp_del.creation_date := SYSDATE;
                    r_emp_del.created_by := g_user_id;

                    v_loc := 90;

                    fnd_file.put_line (fnd_file.LOG,(v_loc));

                    INSERT INTO apps.ttec_phl_manulife_del_intf_stg VALUES r_emp_del;

                    COMMIT;
                END;
            END LOOP;



             DELETE FROM apps.ttec_phl_manulife_del_intf_stg WHERE trunc(creation_date) < trunc(sysdate);
               -- conc_request_id <> g_conc_request_id;

            fnd_file.put_line(
                fnd_file.log,
                'Delete data from ttec_phl_manulife_del_intf_stg'
            );
          EXCEPTION
            WHEN OTHERS THEN
                ttec_phl_manulife_intf_error(
                    NULL,
                    'ttec_phl_manulife_main.main',
                    'Main Interface Deletion',
                    'Error',
                    v_loc,
                    sqlerrm
                );

	END;
-------------Calling file genaration program to specified path-------
        ttec_phl_file_gen(
            p_errbuff,
            p_retcode
        );
    END ttec_phl_manulife_main;

END ttec_phl_manu_life_intf_pkg;
/
show errors;
/