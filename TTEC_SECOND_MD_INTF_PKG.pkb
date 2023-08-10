create or replace PACKAGE BODY      ttec_second_md_intf_pkg
IS
   /*---------------------------------------------------------------------------------------
    Objective    : Interface to extract data for all employees opting for 'Kaiser Medical','Balanced HRA','Primary Care','Choice HSA'
   Parameters:
              p_start_date  -- Optional start paramters to run the report. it will be always 1st of current Month
              p_end_date  -- Optional end paramters to run the report. It will be always last day of current Month
     MODIFICATION HISTORY
     Person               Version  Date        Comments
     --------------------------------------------------------------------------------------------------------
     CTS Prachi             1.0    12/1/2017 Created
     C.Chan                 1.1    INC3887978 - exclude the termed employees
     CTS Prachi             1.2    Duplicate records on file
	 RXNETHI-ARGANO         1.0    17/MAY/2023   R12.2 Upgrade Remediation  
  *== END ==================================================================================================*/
  PROCEDURE main_proc (
    errbuf                OUT       VARCHAR2
   ,retcode               OUT       NUMBER
   ,p_business_group_id   IN        NUMBER
   ,p_output_directory    IN        VARCHAR2
   ,p_start_date          IN        VARCHAR2
   ,p_end_date            IN        VARCHAR2
  )
  IS
    CURSOR c_emp_rec (
      p_cut_off_date        DATE
     ,p_current_run_date    DATE
    )
    IS
      SELECT   (date_start) date_start
              ,(NVL (actual_termination_date, p_current_run_date)) actual_termination_date
              ,person_id
          FROM per_periods_of_service ppos
         WHERE business_group_id = p_business_group_id
          AND ppos.person_id IN (SELECT DISTINCT person_id
                                          FROM per_all_people_f papf
                                         WHERE papf.current_employee_flag = 'Y'
                                           AND p_current_run_date between papf.EFFECTIVE_START_DATE and papf.EFFECTIVE_END_DATE /* 1.1 */
                                         )  /* 1.1  Begin */
          AND ppos.PERIOD_OF_SERVICE_ID IS NOT NULL --change 1.2
          AND ppos.date_start =
                     (SELECT MAX (ppos2.date_start)
                        --FROM hr.per_periods_of_service ppos2   --code commented by RXNETHI-ARGANO,17/05/23
                        FROM apps.per_periods_of_service ppos2   --code added by RXNETHI-ARGANO,17/05/23
                         WHERE ppos2.date_start <= p_current_run_date
                         AND ppos.person_id = ppos2.person_id);
         /* 1.1  End */

/*    1.1 commented out begin
           AND (   (    TRUNC (ppos.last_update_date) BETWEEN p_cut_off_date AND p_current_run_date
                    AND ppos.actual_termination_date IS NOT NULL)
                OR (    ppos.actual_termination_date IS NULL
                    AND ppos.person_id IN (SELECT DISTINCT person_id
                                                      FROM per_all_people_f papf
                                                     WHERE papf.current_employee_flag = 'Y'))
                OR (    ppos.actual_termination_date = (SELECT MAX (actual_termination_date)
                                                          FROM per_periods_of_service
                                                         WHERE person_id = ppos.person_id
                                                           AND actual_termination_date IS NOT NULL)
                    AND ppos.actual_termination_date >= p_cut_off_date)
               )
      -- and person_id IN (780256,1635103,1636814)
      GROUP BY person_id;
1.1 commented out End  */

    CURSOR c_bnft_info (
      p_person_id     IN    NUMBER
     ,p_start_date    IN    DATE
     ,p_end_date      IN    DATE
    )
    IS
     SELECT  ppf.person_id
     ,ppf.employee_number emp_id
             ,ppf.first_name first_name
            ,TO_CHAR (TRUNC (SYSDATE), 'RRRRMMDD') file_date
            ,ppf.person_id bnft_person_id
            ,ppf.middle_names middle_name
            ,ppf.last_name mem_last_name
            ,ppf.date_of_birth mem_dob
            ,ppf.sex sex_code
            ,pad.address_line1 mem_addline1
            ,pad.address_line2 mem_addline2
            ,pad.town_or_city mem_city
            ,pad.region_2 state_code
            ,pad.postal_code  zip_code
            ,to_char(LPAD(regexp_replace( pp.phone_number, '[^[:digit:]]', null ),10,0)) mem_home_phone
            ,null mem_cell_phone
            ,ppf.email_address off_email_address
            ,null home_email_address
            ,pj.name job_title
            ,pj.attribute5 job_family
            ,hla.location_code location_code
            ,pln.name pl_name
            ,pen.enrt_cvg_strt_dt enrt_cvg_strt_dt
            ,pen.enrt_cvg_thru_dt enrt_cvg_thru_dt
            ,'EE' mem_type
            ,'Y' mem_surcharge
            , decode(pln.name,'Kaiser Medical',35893,174199) mem_insurance_num
            ,pln.pl_id
      FROM   ben_pl_f pln
            ,ben_prtt_enrt_rslt_f pen
            ,ben_per_in_ler pil
            ,per_all_people_f ppf
            ,ben_opt_f opt
            ,ben_oipl_f oipl
            ,per_all_assignments_f paaf
            ,hr_locations_all hla
            ,apps.per_addresses pad
           -- ,apps.fnd_lookup_values flv
            ,apps.per_phones pp
            ,apps.per_jobs pj
       WHERE paaf.person_id = pen.person_id
         AND paaf.location_id = hla.location_id
         and paaf.job_id = pj.job_id
         AND hla.inactive_date IS NULL
         AND pad.primary_flag(+) = 'Y'
         AND ppf.person_id = pad.person_id(+)
         AND p_end_date BETWEEN pln.effective_start_date AND pln.effective_end_date
         AND TRUNC (SYSDATE) BETWEEN ppf.effective_start_date AND ppf.effective_end_date
         AND TRUNC (SYSDATE) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
         AND TRUNC (SYSDATE) BETWEEN pad.date_from(+) AND NVL (pad.date_to(+), TO_DATE ('31-DEC-4712', 'DD-MON-RRRR'))
         AND TRUNC (SYSDATE) BETWEEN pp.date_from(+) AND NVL (pp.date_to(+), TO_DATE ('31-DEC-4712', 'DD-MON-RRRR'))
         AND TRUNC (SYSDATE) BETWEEN pj.date_from(+) AND NVL (pj.date_to(+), TO_DATE ('31-DEC-4712', 'DD-MON-RRRR'))
         AND pp.parent_id(+) = ppf.person_id
         AND pp.parent_table(+) = 'PER_ALL_PEOPLE_F'
         AND pp.phone_type(+) = 'H1'
         AND pen.oipl_id = oipl.oipl_id
         AND oipl.pl_id = pln.pl_id
         AND oipl.opt_id = opt.opt_id
         AND pen.person_id = ppf.person_id
         AND pln.business_group_id = p_business_group_id
         AND pln.pl_stat_cd = 'A'
         AND pln.pl_id = pen.pl_id(+)
         AND pen.prtt_enrt_rslt_stat_cd IS NULL
         AND pen.business_group_id(+) = p_business_group_id
         AND NVL (pen.enrt_cvg_thru_dt, p_end_date) <= NVL (pen.effective_end_date, p_end_date)
         --AND pen.sspndd_flag(+) = 'N'
         AND pil.per_in_ler_id(+) = pen.per_in_ler_id
         AND pen.person_id = p_person_id
         AND (   pil.per_in_ler_stat_cd IN ('STRTD', 'PROCD')
              OR pil.per_in_ler_stat_cd IS NULL)
         AND (   p_start_date BETWEEN pen.enrt_cvg_strt_dt AND pen.enrt_cvg_thru_dt
              OR p_end_date BETWEEN pen.enrt_cvg_strt_dt AND pen.enrt_cvg_thru_dt
              OR (    p_start_date >= pen.enrt_cvg_strt_dt
                  AND p_end_date <= pen.enrt_cvg_thru_dt)
              OR (    p_start_date <= pen.enrt_cvg_strt_dt
                  AND p_end_date >= pen.enrt_cvg_thru_dt)
              OR     pen.enrt_cvg_strt_dt IS NULL
                 AND pen.enrt_cvg_thru_dt IS NULL
             )
         AND pln.pl_id IN (SELECT pl_id
                             FROM ben_pl_f
                            WHERE business_group_id = p_business_group_id
                              AND name IN ('Kaiser Medical','Balanced HRA','Primary Care','Choice HSA')
                              and p_start_date between effective_start_date and effective_end_Date)
         AND p_end_date BETWEEN oipl.effective_start_date AND oipl.effective_end_date
         /*AND NOT EXISTS (SELECT 1
                           FROM ben_prtt_enrt_rslt_f pen1
                          WHERE pen.person_id = pen1.person_id
                            AND pen1.prtt_enrt_rslt_stat_cd IS NULL
                            AND pen1.prtt_enrt_rslt_id <> pen.prtt_enrt_rslt_id
                            AND pen1.business_group_id(+) = 325
                            AND pen.enrt_cvg_strt_dt < pen1.enrt_cvg_strt_dt
                            AND NVL (pen.bnft_amt, -1) = NVL (pen1.bnft_amt, -1)
                            AND pen.pl_id = pen1.pl_id
                            AND (   p_start_date BETWEEN pen1.enrt_cvg_strt_dt AND pen1.enrt_cvg_thru_dt
                                 OR p_end_date BETWEEN pen1.enrt_cvg_strt_dt AND pen1.enrt_cvg_thru_dt
                                 OR (    p_start_date >= pen1.enrt_cvg_strt_dt
                                     AND p_end_date <= pen1.enrt_cvg_thru_dt)
                                 OR (    p_start_date <= pen1.enrt_cvg_strt_dt
                                     AND p_end_date >= pen1.enrt_cvg_thru_dt)
                                 OR     pen1.enrt_cvg_strt_dt IS NULL
                                    AND pen1.enrt_cvg_thru_dt IS NULL
                                ))*/
      UNION
      SELECT ppf.person_id
            ,ppf.employee_number emp_id
             ,con.first_name first_name --change 1.2
            ,TO_CHAR (TRUNC (SYSDATE), 'RRRRMMDD') file_date
            ,ppf.person_id bnft_person_id
            ,con.middle_names middle_name
            ,con.last_name mem_last_name
            ,con.date_of_birth mem_dob
            ,con.sex sex_code
            ,decode(pad.address_line1,null,pademp.address_line1,pad.address_line1) mem_addline1
            ,decode(pad.address_line1,null,pademp.address_line2,pad.address_line2) mem_addline2
            ,decode(pad.address_line1,null,pademp.town_or_city,pad.town_or_city) mem_city
            ,decode(pad.address_line1,null,pademp.region_2,pad.region_2) state_code
            ,decode(pad.address_line1,null,pademp.postal_code,pad.postal_code) mem_zip_code
            ,to_char(LPAD(regexp_replace( pp.phone_number, '[^[:digit:]]', null ),10,0)) mem_home_phone
            ,null mem_cell_phone
            ,null off_email_address
            ,null home_email_address
            ,pj.name job_title
            ,pj.attribute5 job_family
            ,hla.location_code location_code
            ,pln.name pl_name
            ,pen.enrt_cvg_strt_dt enrt_cvg_strt_dt
            ,pen.enrt_cvg_thru_dt enrt_cvg_thru_dt
            ,decode(pcr.contact_type,'S','SP','D','DP','CH') mem_type
            ,'Y' mem_surcharge
            , decode(pln.name,'Kaiser Medical',35893,174199) mem_insurance_num
            ,pln.pl_id
      FROM   ben_pl_f pln
            ,ben_prtt_enrt_rslt_f pen
            --,ben.ben_elig_cvrd_dpnt_f dpnt   --code commented by RXNETHI-ARGANO,17/05/23
            ,apps.ben_elig_cvrd_dpnt_f dpnt    --code added by RXNETHI-ARGANO,17/05/23
            ,per_all_people_f ppf
            ,per_all_assignments_f paaf
            ,ben_opt_f opt
            ,ben_oipl_f oipl
            ,per_all_people_f con
            ,apps.per_addresses pad
           -- ,apps.fnd_lookup_values flv
            ,apps.per_phones pp
           -- ,apps.per_phones pp1
            ,apps.per_addresses pademp
            ,apps.per_jobs pj
            ,apps.hr_locations_all hla
            ,apps.per_contact_relationships pcr
       WHERE p_end_date BETWEEN pln.effective_start_date AND pln.effective_end_date
         AND pen.person_id = ppf.person_id
         AND pen.prtt_enrt_rslt_id = dpnt.prtt_enrt_rslt_id
         AND con.person_id = dpnt.dpnt_person_id
         AND pad.primary_flag(+) = 'Y'
         AND pad.person_id(+) = con.person_id
         AND pademp.primary_flag(+) = 'Y'
         AND pademp.person_id(+) = ppf.person_id
         and paaf.person_id = ppf.person_id
         and paaf.job_id = pj.job_id
         and paaf.location_id = hla.location_id
         and pcr.person_id = ppf.person_id
         and pcr.contact_person_id = con.person_id
         and trunc(sysdate) between pcr.date_start and nvl(pcr.date_end,to_date('31-dec-4712','dd-mon-rrrr'))
         and pcr.contact_type <> 'EMRG'
         and pcr.contact_type in ('S', 'D','C', 'A', 'R', 'O', 'T')
         and TRUNC (SYSDATE) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
         AND TRUNC (SYSDATE) BETWEEN ppf.effective_start_date AND ppf.effective_end_date
         AND TRUNC (SYSDATE) BETWEEN pad.date_from(+) AND NVL (pad.date_to(+), TO_DATE ('31-DEC-4712', 'DD-MON-RRRR'))
         AND TRUNC (SYSDATE) BETWEEN pademp.date_from(+) AND NVL (pademp.date_to(+), TO_DATE ('31-DEC-4712', 'DD-MON-RRRR'))
         AND TRUNC (SYSDATE) BETWEEN pp.date_from(+) AND NVL (pp.date_to(+), TO_DATE ('31-DEC-4712', 'DD-MON-RRRR'))
         --AND TRUNC (SYSDATE) BETWEEN pp1.date_from(+) AND NVL (pp1.date_to(+), TO_DATE ('31-DEC-4712', 'DD-MON-RRRR'))
         AND TRUNC (SYSDATE) BETWEEN pj.date_from(+) AND NVL (pj.date_to(+), TO_DATE ('31-DEC-4712', 'DD-MON-RRRR'))
         AND dpnt.cvg_strt_dt BETWEEN con.effective_start_date AND con.effective_end_date
         AND pp.parent_id(+) = ppf.person_id
         AND pp.parent_table(+) = 'PER_ALL_PEOPLE_F'
         AND pp.phone_type(+) = 'H1'
         AND pln.business_group_id = p_business_group_id
         AND pln.pl_stat_cd = 'A'
         AND pln.pl_id = pen.pl_id(+)
         AND pen.oipl_id = oipl.oipl_id
         AND oipl.pl_id = pen.pl_id
         AND pen.prtt_enrt_rslt_stat_cd IS NULL
         AND pen.business_group_id(+) = p_business_group_id
         AND (   NVL (dpnt.cvg_thru_dt, dpnt.effective_end_date) <= dpnt.effective_end_date
              OR dpnt.effective_end_date = TO_DATE ('31-DEC-4712', 'DD-MON-RRRR'))
         and pen.person_id = p_person_id
         AND oipl.opt_id = opt.opt_id
         AND EXISTS (SELECT dep.per_in_ler_id
                       FROM ben_per_in_ler dep
                      WHERE dep.per_in_ler_id = pen.per_in_ler_id
                        AND dep.business_group_id = p_business_group_id
                        AND (   dep.per_in_ler_stat_cd IN ('STRTD', 'PROCD')
                             OR dep.per_in_ler_stat_cd IS NULL))
         AND pen.sspndd_flag(+) = 'N'
         AND dpnt.cvg_strt_dt <= p_end_date
         AND NVL (dpnt.cvg_thru_dt, p_end_date) >= p_start_date
         AND dpnt.cvg_strt_dt <= NVL (dpnt.cvg_thru_dt, p_end_date)   --Added for v1.4
         AND NVL (pen.enrt_cvg_thru_dt, p_end_date) <= NVL (pen.effective_end_date, p_end_date)  --change 1.2
         AND pln.pl_id IN (SELECT pl_id
                             FROM ben_pl_f
                            WHERE business_group_id = p_business_group_id
                              AND name IN ('Kaiser Medical','Balanced HRA','Primary Care','Choice HSA')
                              and p_start_date between effective_start_date and effective_end_Date)
         order by emp_id;

    CURSOR c_host
    IS
      SELECT host_name
            ,instance_name
        FROM v$instance;

    v_text                    VARCHAR (32765)                 DEFAULT '';
    v_file_extn               VARCHAR2 (200)                  DEFAULT '';
    v_time                    VARCHAR2 (20);
    l_active_file    VARCHAR2 (200)                  DEFAULT '';
    v_file_type      UTL_FILE.FILE_TYPE;
    v_cut_off_date            DATE;
    v_current_run_date        DATE;
    l_term_date               DATE                            DEFAULT NULL;
    l_skip_record             VARCHAR2 (1);
    v_dpnt_elig_count         NUMBER;
    l_term_already_exists     VARCHAR2 (1);
    l_trans_type              VARCHAR2 (1);
    l_enrt_cvg_thru_dt        VARCHAR2 (11);
    l_host_name               v$instance.host_name%TYPE;
    l_instance_name           v$instance.instance_name%TYPE;
    l_identifier              VARCHAR2 (10);
    l_error_step              VARCHAR2 (10);
    l_mem_home_phone          VARCHAR2 (20);
  BEGIN
    IF    p_start_date IS NULL
       OR p_end_date IS NULL
    THEN
      v_current_run_date   := TRUNC (SYSDATE);
    ELSE
      v_current_run_date   := TO_DATE (p_end_date, 'YYYY/MM/DD HH24:MI:SS');
    END IF;

    v_cut_off_date           := TRUNC (v_current_run_date, 'YYYY');
    v_dpnt_elig_count        := 0;

    OPEN c_host;

    FETCH c_host
     INTO l_host_name
         ,l_instance_name;

    CLOSE c_host;

    IF l_host_name NOT IN (ttec_library.xx_ttec_prod_host_name)
    THEN
      l_identifier   := 'TEST';
    ELSE
      l_identifier   := 'PROD';
    END IF;

    FND_FILE.PUT_LINE (FND_FILE.LOG, 'Host Name:');

    BEGIN
      SELECT '.CSV'
            ,TO_CHAR (SYSDATE, 'MMDDYYYY_HH24MI')
        INTO v_file_extn
            ,v_time
        FROM v$instance;
    EXCEPTION
      WHEN OTHERS
      THEN
        v_file_extn   := '.CSV';
    END;

    FND_FILE.PUT_LINE (FND_FILE.LOG, 'extension name:');
    l_active_file   := l_identifier || '_2MD_' || v_time || v_file_extn;
    FND_FILE.PUT_LINE (FND_FILE.LOG, 'FILE name:');
    v_file_type     := UTL_FILE.fopen(p_output_directory,
                                   l_active_file,
                                   'w',
                                   32765);
    FND_FILE.PUT_LINE (FND_FILE.LOG, 'Opened the File:');
    --Header for the File
    v_text := 'COMPANY NAME|EMP ID|FIRST NAME|MIDDLE NAME|LAST NAME|DOB|GENDER|ADD LINE 1|ADD LINE 2|CITY|STATE|ZIPCODE|HOME PHONE|CELL PHONE|OFFICAL EMAIL|PERSONAL EMAIL|TITLE|EMP TYPE|OFFIC LOC|PLAN|CVG START DT|MEMBER TYPE|TELETECH EMP|INSURANCE ID|';
    UTL_FILE.PUT_LINE (v_file_type, v_text);
    FND_FILE.PUT_LINE (FND_FILE.OUTPUT, v_text);
    FND_FILE.PUT_LINE (FND_FILE.LOG,'v_cut_off_date ->'||v_cut_off_date);
    FND_FILE.PUT_LINE (FND_FILE.LOG,'v_current_run_date ->'||v_current_run_date);
    FOR r_emp_rec IN c_emp_rec (v_cut_off_date, v_current_run_date)
    LOOP
      v_text   := '';

      --fnd_file.put_line(fnd_file.output, 'r_emp_rec.person_id'||r_emp_rec.person_id);
      FOR r_bnft_info IN c_bnft_info (r_emp_rec.person_id, v_cut_off_date, v_current_run_date)
      LOOP

        l_term_already_exists   := '';
        l_skip_record           := 'N';
        l_term_date             := NULL;
        l_mem_home_phone := '';
        --FND_FILE.PUT_LINE (FND_FILE.LOG, 'initialize variables term, skip and trans:');

        IF (   NVL (r_bnft_info.enrt_cvg_thru_dt, TO_DATE ('31/12/4712', 'DD/MM/YYYY')) = TO_DATE ('31/12/4712', 'DD/MM/YYYY')
            OR r_bnft_info.enrt_cvg_thru_dt > v_current_run_date)
        THEN
          --v1.3
          l_enrt_cvg_thru_dt   := NULL;
        ELSE
          l_enrt_cvg_thru_dt   := TO_CHAR (r_bnft_info.enrt_cvg_thru_dt, 'DD/MM/YYYY');
        END IF;


        IF NVL (r_bnft_info.enrt_cvg_thru_dt, TO_DATE ('31/12/4712', 'DD/MM/YYYY')) <= v_current_run_date
        THEN
          l_error_step   := '1.8';

          BEGIN
            SELECT 'Y'
              INTO l_term_already_exists
              --FROM CUST.TTEC_2MD_TERM_BEN    --code commented by RXNETHI-ARGANO,17/05/23
              FROM APPS.TTEC_2MD_TERM_BEN      --code added by RXNETHI-ARGANO,17/05/23
             WHERE employee_number = r_bnft_info.emp_id
               AND coverage_start_dt = GREATEST (r_bnft_info.enrt_cvg_strt_dt, TRUNC (v_current_run_date, 'YYYY'))
               AND coverage_end_dt = r_bnft_info.enrt_cvg_thru_dt
               AND pl_id = r_bnft_info.pl_id;

            l_skip_record   := 'Y';
            FND_FILE.PUT_LINE (FND_FILE.LOG, 'Termination sent earlier for person_id:' || r_bnft_info.person_id || ' Employee Number: ' || r_bnft_info.emp_id);
          EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
              l_error_step            := '1.9';
              l_term_already_exists   := 'N';
              l_term_date             := r_bnft_info.enrt_cvg_thru_dt;

              BEGIN
                --INSERT INTO CUST.TTEC_2MD_TERM_BEN     --code commented by RXNETHI-ARGANO,17/05/23
                INSERT INTO APPS.TTEC_2MD_TERM_BEN       --code added by RXNETHI-ARGANO,17/05/23
                            (employee_number
                            ,benefit_person_id
                            ,coverage_start_dt
                            ,coverage_end_dt
                            ,pl_id
                            ,last_name
                            ,first_name
                            )
                VALUES      (r_bnft_info.emp_id
                            ,r_bnft_info.person_id
                            ,GREATEST (r_bnft_info.enrt_cvg_strt_dt, TRUNC (v_current_run_date, 'YYYY'))
                            ,r_bnft_info.enrt_cvg_thru_dt
                            ,r_bnft_info.pl_id
                            ,r_bnft_info.mem_last_name
                            ,r_bnft_info.first_name

                            );

               l_skip_record   := 'Y';--terminated records need not be on file --change 1.2

              EXCEPTION
                WHEN OTHERS
                THEN
                  FND_FILE.PUT_LINE (FND_FILE.LOG, 'Error in Inserting record' || SQLERRM);
              END;
          END;
        END IF;

        IF l_skip_record = 'N'
        THEN
          --FND_FILE.PUT_LINE (FND_FILE.LOG, 'l_skip_record is no:');

          if r_bnft_info.mem_home_phone IS NULL then
            l_mem_home_phone := null;
          else
            l_mem_home_phone := substr(r_bnft_info.mem_home_phone,1,3)||'-'||substr(r_bnft_info.mem_home_phone,4,3)||'-'||substr(r_bnft_info.mem_home_phone,7,4);
          end if;


          BEGIN
            v_text              := 'ttec'||'|' ||r_bnft_info.emp_id ||
                                   '|' ||
                                   replace(r_bnft_info.first_name,',',' ') ||
                                   '|' ||
                                   replace(r_bnft_info.middle_name,',',' ') ||
                                   '|' ||
                                   replace(r_bnft_info.mem_last_name,',',' ') ||
                                   '|' ||
                                    TO_CHAR (r_bnft_info.mem_dob, 'MM/DD/YYYY') ||
                                   '|' ||
                                   r_bnft_info.sex_code ||
                                   '|' ||
                                   replace(r_bnft_info.mem_addline1,',',' ') ||
                                   '|' ||
                                   replace(r_bnft_info.mem_addline2,',',' ') ||
                                   '|' ||
                                   r_bnft_info.mem_city ||
                                   '|' ||
                                   r_bnft_info.state_code ||
                                   '|' ||
                                   substr(r_bnft_info.zip_code,1,5) ||
                                   '|' ||
                                    l_mem_home_phone ||
                                   '|' ||
                                   ' ' || --cell phone leave blank
                                   '|' ||
                                   NVL(r_bnft_info.off_email_address,' ') ||
                                   '|' ||
                                   ' ' ||--home email address leave blank
                                   '|' ||
                                   REPLACE(r_bnft_info.job_title,',',' ') ||
                                   '|' ||
                                   NVL(r_bnft_info.job_family,' ') ||
                                   '|' ||
                                   replace(NVL(r_bnft_info.location_code,' '),',',' ') ||
                                   '|' ||
                                   r_bnft_info.pl_name ||
                                   '|' ||
                                   TO_CHAR (GREATEST (r_bnft_info.enrt_cvg_strt_dt, TRUNC (v_current_run_date, 'YYYY')), 'MM/DD/YYYY') ||
                                   '|' ||
                                   r_bnft_info.mem_type ||
                                   '|' ||
                                   'Y' ||
                                   '|' ||
                                   r_bnft_info.mem_insurance_num ;

            UTL_FILE.PUT_LINE (v_file_type, v_text);
            v_dpnt_elig_count   := v_dpnt_elig_count + 1;
            FND_FILE.PUT_LINE (FND_FILE.OUTPUT, v_text);
          END;
        END IF;
      END LOOP;
    END LOOP;

    FND_FILE.PUT_LINE (FND_FILE.LOG, 'Total Count:' || v_dpnt_elig_count);
    UTL_FILE.FCLOSE (v_file_type);
  EXCEPTION
    WHEN OTHERS
    THEN
      UTL_FILE.FCLOSE (v_file_type);
      FND_FILE.PUT_LINE (FND_FILE.LOG, 'Error out of main loop main_proc -' || SQLERRM);
  END main_proc;
END ttec_second_md_intf_pkg;
/
show errors;
/