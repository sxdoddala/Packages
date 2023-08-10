create or replace PACKAGE BODY      ttec_us_kaiser_intf_pkg
IS
   /*---------------------------------------------------------------------------------------
    Objective    : Interface to extract data for all US employees who have opted for Kaiser Medical Plan
    this file would be generated in output directory from there the SFTP Program will pick up the file and SFTP to
    kaiser. The file will be then moved to archive directory
   Package spec :Attec_us_kaiser_intf_pkg
   Parameters:
              p_start_date  -- Optional start paramters to run the report if the data is missing for particular dates
              p_end_date  -- Optional end paramters to run the report if the data is missing for particular dates
     MODIFICATION HISTORY
     Person               Version  Date        Comments
     ------------------------------------------------
     CTS Prachi             1.0    07/18/2017 Created
     CTS  P Rajhans         1.1    02/20/2018 Modified to change Prod file name to teletech_co.txt
     CTS  P Rajhans         1.2    9/10/2018 Added parameter for Open enrollment file change
     CTS  P Rajhans         1.3    Changes under TASK1272653
     TTEC  Neelofar         1.4    Added Condition for 2021 parameter , subgroup_ident should be 0006 otherwise leave it as is.
	 RXNETHI-ARGANO         1.0    18/MAY/2023   R12.2 Upgrade Remediation
  *== END ==================================================================================================*/
  PROCEDURE main_proc (
    errbuf                OUT       VARCHAR2
   ,retcode               OUT       NUMBER
   ,p_output_directory    IN        VARCHAR2
   ,p_start_date          IN        VARCHAR2
   ,p_end_date            IN        VARCHAR2
   ,p_year             IN VARCHAR2
  )
  IS
    CURSOR c_emp_rec (
      p_cut_off_date        DATE
     ,p_current_run_date    DATE
    )
    IS
      SELECT   MAX (date_start) date_start
              ,MAX (NVL (actual_termination_date, p_current_run_date)) actual_termination_date
              ,person_id
          FROM per_periods_of_service ppos
         WHERE business_group_id = 325
         AND ((TRUNC(ppos.last_update_date) BETWEEN p_cut_off_date AND
             p_current_run_date AND
             ppos.actual_termination_date IS NOT NULL) OR
             (ppos.actual_termination_date IS NULL AND
             ppos.person_id IN
             (SELECT DISTINCT person_id
                  FROM per_all_people_f papf
                 WHERE papf.current_employee_flag = 'Y'
                   and business_group_id = 325)) OR
             (ppos.actual_termination_date =
             (SELECT MAX(actual_termination_date)
                  FROM per_periods_of_service
                 WHERE person_id = ppos.person_id
                   AND actual_termination_date IS NOT NULL) AND
             ppos.actual_termination_date >= p_cut_off_date))
             --and PERSON_ID = 1155017
      -- and rownum < 20
       GROUP BY person_id
      having MAX(NVL(actual_termination_date, p_current_run_date)) between p_cut_off_date and p_current_run_date;

    CURSOR c_bnft_info (
      p_person_id     IN    NUMBER
     ,p_start_date    IN    DATE
     ,p_end_date      IN    DATE
     ,p_year          IN    VARCHAR2
    )
    IS
      SELECT employee_number, TO_CHAR (TRUNC (SYSDATE), 'RRRRMMDD') file_date
            ,ppf.person_id bnft_person_id
            ,pen.ORGNL_ENRT_DT
            ,'16' region_ident
            ,'35893' group_ident
            ,regexp_replace(ppf.national_identifier, '[^[:digit:]]', null ) emp_ssn
            ,regexp_replace(ppf.national_identifier, '[^[:digit:]]', null ) mem_national_identifier
            ,trim(subgroup.sub_group) subgroup_ident
            ,'0001' billgroup_ident
            ,'N' sub_flag
            ,'AA' rel_code
            ,ppf.last_name mem_last_name
            ,ppf.first_name mem_first_name
            ,ppf.middle_names mem_middle_name
            ,ppf.sex sex_code
            ,ppf.date_of_birth mem_dob
            ,pad.address_line1 mem_addline1
            ,pad.address_line2 mem_addline2
            ,pad.town_or_city mem_city
            ,pad.region_2 state_code
      ,      pad.postal_code mem_zip_code
            ,regexp_replace( pp.phone_number, '[^[:digit:]]', null ) mem_home_phone
            ,pen.enrt_cvg_strt_dt enrt_cvg_strt_dt
            ,pen.enrt_cvg_thru_dt enrt_cvg_thru_dt
            ,ppf.original_date_of_hire emp_dt_of_hire
            ,ppf.employee_number emp_number
            ,ppf.current_employee_flag cur_emp_flag
            ,'84-1366615' aca_ein
      ,      pen.pl_id
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
            --,CUST.TTEC_KAISER_POSTAL_CODE subgroup   --code commented by RXNETHI-ARGANO,18/05/23
            ,APPS.TTEC_KAISER_POSTAL_CODE subgroup     --code added by RXNETHI-ARGANO,18/05/23
           -- ,apps.per_phones pp1
       WHERE paaf.person_id = pen.person_id
         AND paaf.location_id = hla.location_id
         AND hla.inactive_date IS NULL
         AND pad.primary_flag(+) = 'Y'
         AND ppf.person_id = pad.person_id(+)
         AND p_end_date BETWEEN pln.effective_start_date AND pln.effective_end_date
         AND TRUNC (SYSDATE) BETWEEN ppf.effective_start_date AND ppf.effective_end_date
         AND TRUNC (SYSDATE) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
         AND TRUNC (SYSDATE) BETWEEN pad.date_from(+) AND NVL (pad.date_to(+), TO_DATE ('31-DEC-4712', 'DD-MON-RRRR'))
         AND TRUNC (SYSDATE) BETWEEN pp.date_from(+) AND NVL (pp.date_to(+), TO_DATE ('31-DEC-4712', 'DD-MON-RRRR'))
         --AND TRUNC (SYSDATE) BETWEEN pp1.date_from(+) AND NVL (pp1.date_to(+), TO_DATE ('31-DEC-4712', 'DD-MON-RRRR'))
         AND pp.parent_id(+) = ppf.person_id
         AND pp.parent_table(+) = 'PER_ALL_PEOPLE_F'
         AND pp.phone_type(+) = 'H1'
        -- AND pp1.parent_id(+) = ppf.person_id
        -- AND pp1.parent_table(+) = 'PER_ALL_PEOPLE_F'
        -- AND pp1.phone_type(+) = 'H1'
         AND pen.oipl_id = oipl.oipl_id
         AND oipl.pl_id = pln.pl_id
         AND oipl.opt_id = opt.opt_id
         AND pen.person_id = ppf.person_id
         AND pln.business_group_id = 325
         AND pln.pl_stat_cd = 'A'
         AND pln.pl_id = pen.pl_id(+)
         AND pen.prtt_enrt_rslt_stat_cd IS NULL
         AND pen.business_group_id(+) = 325
         AND  subgroup.postal_code (+)  = pad.postal_code
         AND subgroup.year=p_year--substr(p_end_date,1,4)--'1.4'
        -- and flv.lookup_code(+) = pad.postal_code
        -- AND flv.lookup_type(+) = 'TTEC_KAISER_PINCODE_MAPPING'
        -- and flv.language(+) = 'US'
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
         AND pln.pl_id =18871
         AND p_end_date BETWEEN oipl.effective_start_date AND oipl.effective_end_date
         AND NOT EXISTS (SELECT 1
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
                                ))
      UNION
      SELECT ppf.employee_number, TO_CHAR (TRUNC (SYSDATE), 'RRRRMMDD') file_date
            ,dpnt.dpnt_person_id bnft_person_id
            ,pen.ORGNL_ENRT_DT
            ,'16' region_ident
            ,'35893' group_ident
            ,regexp_replace(ppf.national_identifier, '[^[:digit:]]', null ) emp_ssn
            ,regexp_replace(nvl(con.national_identifier,'000-00-0000'), '[^[:digit:]]', null ) mem_national_identifier
            --,flv.description subgroup_ident
            ,trim(subgroup.sub_group) subgroup_ident
            ,'0001' billgroup_ident
            ,'N' sub_flag
            , pcr.contact_type rel_code
            ,con.last_name mem_last_name
            ,con.first_name mem_first_name
            ,con.middle_names mem_middle_name
            ,con.sex sex_code
            ,con.date_of_birth mem_dob
            ,decode(pad.address_line1,null,pademp.address_line1,pad.address_line1) mem_addline1
            ,decode(pad.address_line1,null,pademp.address_line2,pad.address_line2) mem_addline2
            ,decode(pad.address_line1,null,pademp.town_or_city,pad.town_or_city) mem_city
            ,decode(pad.address_line1,null,pademp.region_2,pad.region_2) state_code
            ,decode(pad.address_line1,null,pademp.postal_code,pad.postal_code) mem_zip_code
            ,regexp_replace( nvl(pp.phone_number,pp1.phone_number), '[^[:digit:]]', null ) mem_home_phone
            ,dpnt.cvg_strt_dt enrt_cvg_strt_dt
            ,dpnt.cvg_thru_dt enrt_cvg_thru_dt
            ,ppf.original_date_of_hire emp_dt_of_hire
            ,ppf.employee_number emp_number
            ,ppf.current_employee_flag cur_emp_flag
            ,'84-1366615' aca_ein
            --ppf.employee_number,
            --ppf.current_employee_flag,
            --pen.person_id,
            --dpnt.cvg_strt_dt enrl_cvg_strt_dt,
            --pen.orgnl_enrt_dt,
            -- enrl_cvg_thru_dt,
      ,      pen.pl_id
        --ben_batch_utils.get_pl_name(pln.pl_id, 1517, p_end_date) pl_name,
        --'D' type_of_rec,
         --dpnt.dpnt_person_id,
        --opt.name,
        --pln.name plan_name
      FROM   ben_pl_f pln
            ,ben_prtt_enrt_rslt_f pen
            --,ben.ben_elig_cvrd_dpnt_f dpnt    --code commented by RXNETHI-ARGANO,18/05/23
            ,apps.ben_elig_cvrd_dpnt_f dpnt     --code added by RXNETHI-ARGANO,18/05/23
            ,per_all_people_f ppf
            ,ben_opt_f opt
            ,ben_oipl_f oipl
            ,per_all_people_f con
            ,apps.per_addresses pad
           -- ,apps.fnd_lookup_values flv
            ,apps.per_phones pp
            ,apps.per_phones pp1
            ,apps.per_addresses pademp
             --,CUST.TTEC_KAISER_POSTAL_CODE subgroup     --code commented by RXNETHI-ARGANO,18/05/23
             ,APPS.TTEC_KAISER_POSTAL_CODE subgroup       --code added by RXNETHI-ARGANO,18/05/23
             ,per_contact_relationships pcr
       WHERE p_end_date BETWEEN pln.effective_start_date AND pln.effective_end_date
         AND pen.person_id = ppf.person_id
         AND pen.prtt_enrt_rslt_id = dpnt.prtt_enrt_rslt_id
         AND con.person_id = dpnt.dpnt_person_id
         AND pad.primary_flag(+) = 'Y'
         AND pad.person_id(+) = con.person_id
         AND pademp.primary_flag(+) = 'Y'
         AND pademp.person_id(+) = ppf.person_id
         AND PCR.person_id = ppf.person_id --change 1.3
         AND pcr.contact_person_id = dpnt.dpnt_person_id--change 1.3
         and trunc(sysdate) between pcr.date_start and nvl(pcr.date_end,to_date('31-dec-4712','dd-mon-rrrr'))--change 1.3
         and pcr.contact_type <> 'EMRG'--change 1.3
         and pcr.contact_type in ('S', 'D','C', 'A', 'R', 'O', 'T')--change 1.3
         AND NVL (pen.enrt_cvg_thru_dt, p_end_date) <= NVL (pen.effective_end_date, p_end_date)--change 1.3
         AND TRUNC (SYSDATE) BETWEEN ppf.effective_start_date AND ppf.effective_end_date
         AND dpnt.cvg_strt_dt BETWEEN con.effective_start_date AND con.effective_end_date
         AND TRUNC (SYSDATE) BETWEEN pad.date_from(+) AND NVL (pad.date_to(+), TO_DATE ('31-DEC-4712', 'DD-MON-RRRR'))
         AND TRUNC (SYSDATE) BETWEEN pademp.date_from(+) AND NVL (pademp.date_to(+), TO_DATE ('31-DEC-4712', 'DD-MON-RRRR'))
         AND TRUNC (SYSDATE) BETWEEN pp.date_from(+) AND NVL (pp.date_to(+), TO_DATE ('31-DEC-4712', 'DD-MON-RRRR'))
         AND TRUNC (SYSDATE) BETWEEN pp1.date_from(+) AND NVL (pp1.date_to(+), TO_DATE ('31-DEC-4712', 'DD-MON-RRRR'))
         AND pp.parent_id(+) = con.person_id
         AND pp.parent_table(+) = 'PER_ALL_PEOPLE_F'
         AND pp.phone_type(+) = 'H1'
         AND pp1.parent_id(+) = ppf.person_id
         AND pp1.parent_table(+) = 'PER_ALL_PEOPLE_F'
         AND pp1.phone_type(+) = 'H1'
         AND pln.business_group_id = 325
         AND pln.pl_stat_cd = 'A'
         AND pln.pl_id = pen.pl_id(+)
         AND pen.oipl_id = oipl.oipl_id
         AND oipl.pl_id = pen.pl_id
         AND pen.prtt_enrt_rslt_stat_cd IS NULL
         AND pen.business_group_id(+) = 325
         AND (   NVL (dpnt.cvg_thru_dt, dpnt.effective_end_date) <= dpnt.effective_end_date
              OR dpnt.effective_end_date = TO_DATE ('31-DEC-4712', 'DD-MON-RRRR'))
         and pen.person_id = p_person_id
         AND oipl.opt_id = opt.opt_id
        -- AND flv.lookup_type(+) = 'TTEC_KAISER_PINCODE_MAPPING'
          AND subgroup.postal_code(+) =  pademp.postal_code
          AND subgroup.year= p_year--substr(p_end_date,1,4)--1.4
      --   and flv.lookup_code(+) = pademp.postal_code
       --  AND flv.LANGUAGE(+) = 'US'
         --  and ppf.employee_number='3002297'
         AND EXISTS (SELECT dep.per_in_ler_id
                       FROM ben_per_in_ler dep
                      WHERE dep.per_in_ler_id = pen.per_in_ler_id
                        AND dep.business_group_id = 325
                        AND (   dep.per_in_ler_stat_cd IN ('STRTD', 'PROCD')
                             OR dep.per_in_ler_stat_cd IS NULL))
         AND pen.sspndd_flag(+) = 'N'
         AND dpnt.cvg_strt_dt <= p_end_date
         AND NVL (dpnt.cvg_thru_dt, p_end_date) >= p_start_date
         AND dpnt.cvg_strt_dt <= NVL (dpnt.cvg_thru_dt, p_end_date)   --Added for v1.4
         --AND opt.name <> 'Waive'
         AND pln.pl_id =18871
         order by employee_number;

    CURSOR c_host
    IS
      SELECT host_name
            ,instance_name
        FROM v$instance;

    v_text                    VARCHAR (32765)                 DEFAULT '';
    v_file_extn               VARCHAR2 (200)                  DEFAULT '';
     v_time                    VARCHAR2 (20);
    l_asn_life_active_file    VARCHAR2 (200)                  DEFAULT '';
    v_asn_life_file_type      UTL_FILE.FILE_TYPE;
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
    l_rel_code                VARCHAR2 (10);
    l_enroll_reason           VARCHAR2 (1);
    l_person_exist           VARCHAR2 (1);
    l_future_dt  date;
    l_header_eff_date varchar2(8);
    l_enrt_cvg_strt_dt date;
    v_year varchar2(8);

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
    l_future_dt    := ROUND(SYSDATE, 'YYYY');

    /*V1.1 Added for 14 day look ahead period */
    IF(TRUNC(v_current_run_date+14,'YYYY')= TRUNC(v_current_run_date,'YYYY'))
    THEN
    v_current_run_date:=v_current_run_date+14;
    ELSE
    v_current_run_date:=TRUNC(v_current_run_date+14,'YYYY')-1;
    END IF;


    OPEN c_host;

    FETCH c_host
     INTO l_host_name
         ,l_instance_name;

    CLOSE c_host;

    IF l_host_name NOT IN (ttec_library.xx_ttec_prod_host_name)
    THEN
      l_identifier   := 'TEST_';
      --changes 1.1
    /*ELSE
      l_identifier   := 'PROD';*/
    END IF;

    FND_FILE.PUT_LINE (FND_FILE.LOG, 'Host Name:');

      BEGIN
       SELECT '.txt'
             ,TO_CHAR (SYSDATE, 'MMDDYYYY_HH24MI')
         INTO v_file_extn
             ,v_time
         FROM v$instance;
     EXCEPTION
       WHEN OTHERS
       THEN
         v_file_extn   := '.txt';
     END;
    FND_FILE.PUT_LINE (FND_FILE.LOG, 'extension name:');
    FND_FILE.PUT_LINE (FND_FILE.LOG, 'v_year'||v_year);


    l_asn_life_active_file   := l_identifier || 'teletech_co' || '.txt';  --remove '_' for changes 1.1.
    FND_FILE.PUT_LINE (FND_FILE.LOG, 'FILE name:');
    v_asn_life_file_type     := UTL_FILE.FOPEN (p_output_directory, l_asn_life_active_file, 'w', 32765);

    --open employee cursor for 01-Jan-RRRR till current run date
     v_year := substr(p_end_date,1,4);
      FND_FILE.PUT_LINE (FND_FILE.LOG, 'v_year --- - ' || v_year);

       if v_year <= '2020' then
       v_year := '2020';
       else
       v_year := '2021';
       end if;

    FOR r_emp_rec IN c_emp_rec (v_cut_off_date, v_current_run_date)
    LOOP
      v_text   := '';


      FOR r_bnft_info IN c_bnft_info (r_emp_rec.person_id, v_cut_off_date, v_current_run_date,v_year)
      LOOP
        --Initalize all variable.
        --l_contact_type := '';
        l_term_already_exists   := '';
        l_skip_record           := 'N';
        l_trans_type            := 'A';
        l_term_date             := NULL;
        l_rel_code              := NVL(r_bnft_info.rel_code,'00');
        l_person_exist :='N';
        l_enroll_reason :='';

         if p_year = 'Future' then
                l_header_eff_date := TO_CHAR (TRUNC (l_future_dt), 'RRRRMMDD');
         else
                l_header_eff_date := TO_CHAR (TRUNC (SYSDATE), 'RRRRMMDD');
         end if;

         FND_FILE.PUT_LINE (FND_FILE.LOG, 'PERSON ID - ' || r_emp_rec.person_id);

        /*to get the relationship code*/
        IF r_bnft_info.rel_code <> 'AA'
        THEN

          IF l_rel_code = 'S'
          THEN
            l_rel_code   := 'BB';
          ELSIF l_rel_code = 'D'
          THEN
            l_rel_code   := 'DP';
          ELSIF l_rel_code IN ('C', 'A', 'R', 'O', 'T')
          THEN
            l_rel_code   := 'CC';
          ELSE
            l_rel_code   := '';
          END IF;
        END IF;
        /*to get the relationship code*/

        /*Start of code to get the enroll reason*/
        IF NVL (r_bnft_info.enrt_cvg_thru_dt, TO_DATE ('31/12/4712', 'DD/MM/YYYY')) > v_current_run_date THEN
            BEGIN

                SELECT 'Y'
                into l_person_exist
                --FROM CUST.TTEC_KAISER_ACTIVE_BENEFITS    --code commented by RXNETHI-ARGANO,18/05/23
                FROM APPS.TTEC_KAISER_ACTIVE_BENEFITS      --code added by RXNETHI-ARGANO,18/05/23
                WHERE employee_number = r_bnft_info.emp_number
                   AND BENEFIT_PERSON_ID = r_bnft_info.bnft_person_id
                   and ORG_ENRT_DT = r_bnft_info.ORGNL_ENRT_DT
                   AND coverage_start_dt = r_bnft_info.enrt_cvg_strt_dt
                   AND coverage_end_dt = r_bnft_info.enrt_cvg_thru_dt
                   AND pl_id = r_bnft_info.pl_id;
            exception
            when NO_DATA_FOUND then
                l_enroll_reason :='Y';
                l_error_step            := '1.9';
                  l_term_already_exists   := 'N';
                  l_trans_type            := 'T';
                  l_term_date             := r_bnft_info.enrt_cvg_thru_dt;

                  BEGIN
                    --INSERT INTO CUST.TTEC_KAISER_ACTIVE_BENEFITS     --code commented by RXNETHI-ARGANO,18/05/23
                    INSERT INTO APPS.TTEC_KAISER_ACTIVE_BENEFITS       --code added by RXNETHI-ARGANO,18/05/23
                                (employee_number
                                ,benefit_person_id
                                ,ORG_ENRT_DT
                                ,coverage_start_dt
                                ,coverage_end_dt
                                ,pl_id
                                ,last_name
                                ,first_name
                                ,run_date
                                )
                    VALUES      (r_bnft_info.emp_number
                                ,r_bnft_info.bnft_person_id
                                ,r_bnft_info.ORGNL_ENRT_DT
                                ,r_bnft_info.enrt_cvg_strt_dt
                                ,r_bnft_info.enrt_cvg_thru_dt
                                ,r_bnft_info.pl_id
                                ,r_bnft_info.mem_last_name
                                ,r_bnft_info.mem_first_name
                                ,v_current_run_date
                                );

                                EXCEPTION
                    WHEN OTHERS--change 1.3
                    THEN
                      FND_FILE.PUT_LINE (FND_FILE.LOG, 'Error in Inserting record in Active Benefits Table' || SQLERRM);
                  END;
            when OTHERS then
                FND_FILE.PUT_LINE (FND_FILE.LOG, 'Error in Fetching records from active benefits :'||r_bnft_info.emp_number||'-' || SQLERRM);
            end;
        END IF;



        /*end of code to get the enroll reason*/


        --if enrollment coverage thru date is greater then run date + 14 or is eof time then send zeroes else send it as memcanceldate
        IF (   NVL (r_bnft_info.enrt_cvg_thru_dt, TO_DATE ('31/12/4712', 'DD/MM/YYYY')) = TO_DATE ('31/12/4712', 'DD/MM/YYYY')
            OR r_bnft_info.enrt_cvg_thru_dt > v_current_run_date
           )
        THEN   --v1.3
          l_enrt_cvg_thru_dt :=  '00000000';
        ELSE
          l_enrt_cvg_thru_dt   := TO_CHAR (r_bnft_info.enrt_cvg_thru_dt, 'RRRRMMDD');
        END IF;

        IF NVL (r_bnft_info.enrt_cvg_thru_dt, TO_DATE ('31/12/4712', 'DD/MM/YYYY')) <= v_current_run_date
        THEN
          l_error_step   := '1.8';

          BEGIN
            SELECT 'Y'
              INTO l_term_already_exists
              --FROM cust.ttec_kaiser_term_benefits    --code commented by RXNETHI-ARGANO,18/05/23
              FROM apps.ttec_kaiser_term_benefits      --code added by RXNETHI-ARGANO,18/05/23
             WHERE employee_number = r_bnft_info.emp_number
               AND coverage_start_dt = GREATEST (r_bnft_info.enrt_cvg_strt_dt, TRUNC (v_current_run_date, 'YYYY'))
               AND coverage_end_dt = r_bnft_info.enrt_cvg_thru_dt
               AND pl_id = r_bnft_info.pl_id;

            l_skip_record   := 'Y';
            FND_FILE.PUT_LINE (FND_FILE.LOG, 'Termination sent earlier for person_id:' || r_bnft_info.bnft_person_id || ' Employee Number: ' || r_bnft_info.emp_number);
          EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
              l_error_step            := '1.9';
              l_term_already_exists   := 'N';
              l_trans_type            := 'T';
              l_term_date             := r_bnft_info.enrt_cvg_thru_dt;

              BEGIN
                --INSERT INTO cust.ttec_kaiser_term_benefits     --code commented by RXNETHI-ARGANO,18/05/23
                INSERT INTO apps.ttec_kaiser_term_benefits       --code added by RXNETHI-ARGANO,18/05/23
                            (employee_number
                            ,benefit_person_id
                            ,ORG_ENRT_DT
                            ,coverage_start_dt
                            ,coverage_end_dt
                            ,pl_id
                            ,last_name
                            ,first_name
                            ,run_date
                            )
                VALUES      (r_bnft_info.emp_number
                            ,r_bnft_info.bnft_person_id
                            ,r_bnft_info.ORGNL_ENRT_DT
                            ,GREATEST (r_bnft_info.enrt_cvg_strt_dt, TRUNC (v_current_run_date, 'YYYY'))
                            ,r_bnft_info.enrt_cvg_thru_dt
                            ,r_bnft_info.pl_id
                            ,r_bnft_info.mem_last_name
                            ,r_bnft_info.mem_first_name
                            ,v_current_run_date
                            );
              EXCEPTION
                WHEN OTHERS
                THEN
                  FND_FILE.PUT_LINE (FND_FILE.LOG, 'Error in Inserting record' || SQLERRM);
              END;
          WHEN OTHERS THEN  --change 1.3
              FND_FILE.PUT_LINE (FND_FILE.LOG, 'Error in Fetching records from term benefits :'||r_bnft_info.emp_number||'-' || SQLERRM);
          END;
        END IF;

        IF l_skip_record = 'N'
        THEN
          FND_FILE.PUT_LINE (FND_FILE.LOG, 'l_skip_record is no:');
          -- Change v1.2 starts
              IF p_year = 'Future'
              THEN
              l_enrt_cvg_strt_dt := greatest(l_future_dt,r_bnft_info.enrt_cvg_strt_dt);
              ELSE
              l_enrt_cvg_strt_dt:= r_bnft_info.enrt_cvg_strt_dt;
              END IF;
              -- Change v1.2 ends


          BEGIN
            v_text              := RPAD (l_header_eff_date, 8, ' ') ||
                                   RPAD (r_bnft_info.region_ident, 2, ' ') ||
                                   RPAD (r_bnft_info.group_ident, 7, ' ') ||
                                   RPAD (r_bnft_info.emp_ssn, 13, ' ') ||
                                   RPAD ('000000000', 15, ' ') ||   -- Alternet employee number
                                   RPAD (r_bnft_info.mem_national_identifier, 13, ' ') || --mem social security number
                                   RPAD (' ', 15, ' ') || --alternate mem identifier
                                   RPAD ('000000000', 11, '0') || --member old social security number
                                   RPAD (nvl(r_bnft_info.subgroup_ident,'000'), 5, ' ') ||
                                   RPAD (nvl(r_bnft_info.billgroup_ident,'00'), 4, ' ') ||
                                   RPAD (' ', 11, ' ') ||
                                   RPAD (' ', 11, ' ') ||   -- issue in length
                                   RPAD (r_bnft_info.sub_flag, 1, ' ') ||
                                   RPAD (nvl(l_rel_code,' '), 2, ' ') ||
                                   RPAD (r_bnft_info.mem_last_name, 30, ' ') ||
                                   RPAD (r_bnft_info.mem_first_name, 30, ' ') ||
                                   RPAD (nvl(r_bnft_info.mem_middle_name,' '), 30, ' ') ||
                                   RPAD (' ', 5, ' ') ||
                                   RPAD (' ', 6, ' ') ||
                                   RPAD (r_bnft_info.sex_code, 1, ' ') ||
                                   RPAD (TO_CHAR (r_bnft_info.mem_dob, 'RRRRMMDD'), 8, ' ') ||
                                   RPAD (nvl(r_bnft_info.mem_addline1,' '), 30, ' ') ||
                                   RPAD (nvl(r_bnft_info.mem_addline2,' '), 30, ' ') ||
                                   RPAD (nvl(r_bnft_info.mem_city,' '), 20, ' ') ||
                                   RPAD (nvl(r_bnft_info.state_code,' '), 2, ' ') ||
                                   RPAD (nvl(r_bnft_info.mem_zip_code,' '), 5, ' ') ||
                                   RPAD (' ', 4, ' ') ||
                                   RPAD (nvl(r_bnft_info.mem_home_phone,'0'), 10, '0') ||
                                   RPAD (' ', 3, ' ') ||
                                   RPAD (' ', 10, ' ') ||
                                   RPAD (' ', 5, ' ') ||
                                   RPAD (TO_CHAR (l_enrt_cvg_strt_dt, 'RRRRMMDD'), 8, ' ') ||
                                   RPAD (l_enrt_cvg_thru_dt, 8, '0') ||
                                   rpad(TO_CHAR (r_bnft_info.emp_dt_of_hire, 'RRRRMMDD'), 8, ' ') ||
                                   RPAD (r_bnft_info.emp_number,10,' ') ||
                                   RPAD (' ', 2, ' ') ||
                                   RPAD (' ', 13, ' ') ||
                                   RPAD (' ', 2, ' ') ||
                                   RPAD (' ', 2, ' ') ||
                                   RPAD (' ', 8, ' ') ||
                                   RPAD (' ', 8, ' ') ||
                                   RPAD (' ', 8, '0') || --42 field Part B Assignment Effective date
                                   RPAD (' ', 1, ' ') ||
                                   RPAD (' ', 8, '0') ||--44Medicare Part A Assignment Date
                                   RPAD (' ', 8, '0') ||--44 Medicare Part B Assigment Date
                                   RPAD (' ', 20, ' ') ||
                                   RPAD (' ', 8, ' ') ||
                                   RPAD (' ', 8, ' ') ||
                                   RPAD (' ', 30, ' ') ||
                                   RPAD (' ', 8, '0') || --Provider Identifier
                                   RPAD (' ', 8, ' ') ||
                                   RPAD (' ', 1, ' ') ||
                                   RPAD (' ', 1, ' ') ||
                                   RPAD (' ', 8, ' ') ||
                                   RPAD (' ', 15, ' ') ||
                                   RPAD (' ', 15, ' ') ||
                                   RPAD (' ', 10, ' ') ||
                                   RPAD (' ', 10, ' ') ||
                                   RPAD (' ', 30, ' ') ||
                                   RPAD (' ', 20, ' ') ||
                                   RPAD (' ', 20, ' ') ||
                                   RPAD (' ', 10, ' ') ||
                                   RPAD (' ', 6, ' ') ||
                                   RPAD (nvl(l_enroll_reason,' '), 2, ' ') ||
                                   RPAD (' ', 40, ' ') ||
                                   RPAD (' ', 188, ' ') ||
                                   RPAD (' ', 20, ' ') ||
                                   RPAD (' ', 20, ' ') ||
                                   RPAD (' ', 20, ' ') ||
                                   RPAD (r_bnft_info.aca_ein, 20, ' ') ||
                                   RPAD (' ', 20, ' ');
            UTL_FILE.PUT_LINE (v_asn_life_file_type, v_text);
            v_dpnt_elig_count   := v_dpnt_elig_count + 1;
            FND_FILE.PUT_LINE (FND_FILE.OUTPUT, v_text);
          END;
        END IF;
      END LOOP;
    END LOOP;

    FND_FILE.PUT_LINE (FND_FILE.LOG, 'Total Count:' || v_dpnt_elig_count);
    UTL_FILE.FCLOSE (v_asn_life_file_type);
  EXCEPTION
    WHEN OTHERS
    THEN
      UTL_FILE.FCLOSE (v_asn_life_file_type);
      FND_FILE.PUT_LINE (FND_FILE.LOG, 'Error out of main loop main_proc -' || SQLERRM);
  END main_proc;
END ttec_us_kaiser_intf_pkg;
/
show errors;
/