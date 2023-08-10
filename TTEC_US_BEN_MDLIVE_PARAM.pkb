create or replace PACKAGE BODY      TTEC_US_BEN_MDLIVE_PARAM IS
  /*---------------------------------------------------------------------------------------
   Objective    : Interface to extract data for all US employees to send to MDLIVE Vendor
   Package body :TTEC_US_BEN_MDLIVE_PARAM
  Parameters:
              p_start_date  -- Optional start paramters to run the report if the data is missing for particular dates
     MODIFICATION HISTORY
     Person               Version  Date        Comments
     ------------------------------------------------
    TCS         1.0      11/30/2015         Created from ttec_ben_mdlive_data
                                            New package for sending employee information for Tele Medicine vendor
	CTS         1.1      6/1/2017           Changes required to only send only employees not having 'Primary Care','Balanced HRA' or 'Choise HSA'
	RXNETHI-ARGANO 1.0   05/15/2023         R12.2 Upgrade Remediation
   *== END ==================================================================================================*/
  FUNCTION get_plan_val(p_pl_id NUMBER, p_person_id NUMBER, p_date DATE)
    RETURN VARCHAR2 AS

    l_location_id   per_all_assignments_f.location_id%TYPE;
    l_loc_code      hr_locations.location_code%TYPE;
    l_pl_code       VARCHAR2(200);
    l_location_code VARCHAR2(200);
    l_result        VARCHAR2(200);

    /**** SELECT LOCATION ****/
    CURSOR c_per IS
      SELECT asg.location_id, hla.location_code
        FROM per_all_assignments_f asg, hr_locations hla
       WHERE asg.person_id = p_person_id
         AND asg.location_id = hla.location_id
         AND hla.inactive_date IS NULL
         AND p_date BETWEEN asg.effective_start_date AND
             asg.effective_end_date;
    /**** DETERMINE PLAN_CODE ****/
  BEGIN

    OPEN c_per;

    FETCH c_per
      INTO l_location_id, l_loc_code;

    CLOSE c_per;

    begin
      l_pl_code       := '';
      l_result        := '';
      l_location_code := '';

      SELECT u.lookup_code
        INTO l_pl_code
        FROM ben_pl_f p, hr_lookups u
       WHERE u.lookup_type = 'TTEC_ANTHEM_PLAN_MAPPING'
            -- and u.language = 'US'
         and p.pl_id = p_pl_id
         and p_date between p.effective_start_date and p.effective_end_date
            -- and security_group_id = 2
         and u.meaning = p.name;

    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_pl_code := '';
      WHEN TOO_MANY_ROWS THEN
        l_pl_code := '';
      WHEN OTHERS THEN
        l_pl_code := '';
    END;

    BEGIN

      SELECT distinct ANTHEM_LOC.lookup_code
        INTO l_location_code

        FROM hr_lookups ANTHEM_LOC, hr_lookups oracle_anthem
       WHERE ANTHEM_LOC.lookup_type = 'TTEC_ANTHEM_LOC_MAPPING'
            -- and ANTHEM_LOC.language = 'US'
         and oracle_anthem.lookup_type = 'TTEC_HR_ANTHEM_LOC_MAPPING'
            -- and oracle_anthem.language = 'US'
         and upper(oracle_anthem.description) =
             upper(ANTHEM_LOC.description)
         and upper(oracle_anthem.meaning) = upper(l_loc_code);

    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_location_code := '';
      WHEN TOO_MANY_ROWS THEN
        l_location_code := '';
      WHEN OTHERS THEN
        l_location_code := '';
    END;

    if l_pl_code is not null and l_location_code is not null then
      l_result := l_pl_code || l_location_code;
    END IF;
    RETURN l_result;
    /*    v_pl_val VARCHAR2(10);
      BEGIN
        v_pl_val := NULL;

        SELECT pucif.VALUE
          INTO v_pl_val
          FROM pay_user_tables             put,
               pay_user_columns            puc,
               pay_user_rows_f             pur,
               pay_user_column_instances_f pucif
         WHERE put.user_table_name = 'TeleTech UHC Reporting Codes'
           AND puc.user_column_name = p_med_plan
           AND pur.row_low_range_or_name = p_location_code
           AND put.user_table_id = puc.user_table_id
           AND put.user_table_id = puc.user_table_id
           AND pucif.user_row_id = pur.user_row_id(+)
           AND puc.user_column_id = pucif.user_column_id(+)
           AND p_date BETWEEN pur.effective_start_date(+) AND
               pur.effective_end_date(+)
           AND p_date BETWEEN pucif.effective_start_date(+) AND
               pucif.effective_end_date(+);

        RETURN(v_pl_val);
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_pl_val := NULL;
          RETURN(v_pl_val);
        WHEN TOO_MANY_ROWS THEN
          v_pl_val := NULL;
          RETURN(v_pl_val);
        WHEN OTHERS THEN
          v_pl_val := NULL;
          RETURN(v_pl_val);
    */
  END;

  PROCEDURE main_proc(errbuf             OUT VARCHAR2,
                      retcode            OUT NUMBER,
                      p_output_directory IN VARCHAR2,
                      p_start_date       IN VARCHAR2
                      --      p_end_date           IN       VARCHAR2
                      ) IS
    CURSOR c_rec(p_date IN DATE) IS
      SELECT papf.person_id,
             papf.employee_number oracleid,
             papf.national_identifier emp_ssn,
             papf.first_name,
             papf.last_name,
             papf.email_address email,
             papf.sex,
             TO_CHAR(papf.date_of_birth, 'MM/DD/YYYY') dob,
             DECODE(pad.country,
                    'BR',
                    pad.region_2,
                    'CA',
                    pad.region_1,
                    'CR',
                    pad.region_1,
                    'ES',
                    pad.region_1,
                    'UK',
                    '',
                    'MX',
                    pad.region_1,
                    'PH',
                    pad.region_1,
                    'US',
                    pad.region_2,
                    'NZ',
                    '') state,
             pad.address_line1,
             NVL(pad.address_line2, pad.address_line2) address_line2,
             pad.town_or_city,
             SUBSTRB(pad.postal_code, 1, 5) postal_code,
             DECODE(INSTR(DECODE(INSTR(TRIM(TRANSLATE(UPPER(pp.phone_number),
                                                      '+,/,(,),.,=,-,_,#,NA,SAME,NONE,YES,SKYPE,*,\,`,'' ',
                                                      ' ')),
                                       0),
                                 1,
                                 '',
                                 TRIM(TRANSLATE(UPPER(pp.phone_number),
                                                '+,/,(,),.,=,-,_,#,NA,SAME,NONE,YES,SKYPE,*,\,`,'' ',
                                                ' '))),
                          1),
                    1,
                    SUBSTRB(TRIM(TRANSLATE(UPPER(pp.phone_number),
                                           '+,/,(,),.,=,-,_,#,NA,SAME,NONE,YES,SKYPE,*,\,`,'' ',
                                           ' ')),
                            2,
                            10),
                    '',
                    '',
                    TRIM(TRANSLATE(UPPER(pp.phone_number),
                                   '+,/,(,),.,=,-,_,#,NA,SAME,NONE,YES,SKYPE,*,\,`,'' ',
                                   ' '))) phone_num,
             pp.phone_id,
             pp.phone_type,
             hrl.location_code,
             ppos.date_start
        FROM apps.per_all_people_f       papf,
             apps.per_all_assignments_f  paaf,
             apps.per_periods_of_service ppos,
             apps.per_addresses          pad,
             apps.per_phones             pp,
             --hr.hr_locations_all         hrl --code commented by RXNETHI-ARGANO,15/05/23
			 apps.hr_locations_all         hrl --code added by RXNETHI-ARGANO,15/05/23
       WHERE papf.person_id = paaf.person_id
         AND paaf.person_id = ppos.person_id
         AND paaf.primary_flag = 'Y'
         AND papf.business_group_id <> 0
         AND papf.business_group_id = 325
         AND pad.primary_flag(+) = 'Y'
         AND papf.current_employee_flag = 'Y'
         AND papf.person_id = pad.person_id(+)
         AND papf.person_id = pp.parent_id(+)
         AND pp.phone_type(+) = 'H1'
         AND paaf.payroll_id <> 137
         AND paaf.employment_category IN ('FR', 'PR', 'VB') -- V1.3
         AND paaf.location_id = hrl.location_id
            --AND paaf.location_id NOT IN (131337, 134268) -- V1.1 (b) /* 1.4 */
            --AND papf.person_id = NVL (p_person_id, papf.person_id)
         AND p_date BETWEEN papf.effective_start_date AND
             papf.effective_end_date
         AND p_date BETWEEN paaf.effective_start_date AND
             paaf.effective_end_date
         AND TRUNC(NVL(hrl.inactive_date, p_date)) >= p_date
         AND p_date BETWEEN pad.date_from(+) AND
             NVL(pad.date_to(+), p_date)
         AND p_date BETWEEN pp.date_from(+) AND NVL(pp.date_to(+), p_date)
         AND p_date BETWEEN ppos.date_start AND
             NVL(ppos.actual_termination_date, p_date)
         AND (ppos.actual_termination_date IS NULL or nvl(ppos.actual_termination_date,p_date) >= p_date) --changes 1.1
      --            AND ppos.date_start <= p_date - 30        -- v1.1
      --              AND TRUNC (SYSDATE) BETWEEN TO_DATE (p_start_date,
      --                                                   'YYYY/MM/DD HH24:MI:SS'
      --                                                  )
      --                                      AND TO_DATE (p_end_date,
      --                                                   'YYYY/MM/DD HH24:MI:SS'
      --                                                  )
       ORDER BY 2;

    v_text        VARCHAR2(20000) DEFAULT NULL;
    v_file_name   VARCHAR2(200) := 'telemedicine' ||
                                   TO_CHAR(SYSDATE, 'YYYYMMDDHH24MISS') ||
                                   '.csv';
    v_file_type   UTL_FILE.file_type;
    v_pl_name       ben_pl_f.name%TYPE DEFAULT NULL;--changes 1.1
    v_diff        NUMBER DEFAULT 0;
    v_actual_date DATE;
    p_date        DATE;
  BEGIN
   IF p_start_date IS NULL THEN
       p_date      := TRUNC(SYSDATE);
   ELSE
    p_date      := fnd_date.canonical_to_date(p_start_date);
    END IF;
    v_file_type := UTL_FILE.fopen(p_output_directory, v_file_name, 'w');
    --p_start_date := TO_DATE (p_start_date, 'YYYY/MM/DD HH24:MI:SS');
    --p_end_date := TO_DATE (p_end_date, 'YYYY/MM/DD HH24:MI:SS');
    v_text := NULL;
    v_text := 'MEMBERID' || ',' || 'PRIMARYMEMBERID' || ',' || 'PLANID' || ',' ||
              'FIRSTNAME' || ',' || 'LASTNAME' || ',' || 'EMAIL' || ',' ||
              'PRIMARYCONTACTPHONE' || ',' || 'DOB' || ',' || 'GENDER' || ',' ||
              'ADDRESS1' || ',' || 'ADDRESS2' || ',' || 'CITY' || ',' ||
              'STATE' || ',' || 'ZIP' || ',' || 'PHONE' || ',' ||
              'LOCATION';
    UTL_FILE.put_line(v_file_type, TRIM(v_text));
    fnd_file.put_line(fnd_file.output, v_text);

    FOR r_rec IN c_rec(p_date) LOOP
      v_text := NULL;

      /* 1.5 Comment Out Begin  */
      --      BEGIN
      --        -- V1.1 (a)
      --        v_diff        := 0;
      --        v_actual_date := NULL;

      --        SELECT (LAST_DAY(r_rec.date_start) - r_rec.date_start) + 1
      --          INTO v_diff
      --          FROM DUAL;

      --        IF v_diff >= 30 THEN
      --          v_actual_date := LAST_DAY(r_rec.date_start) + 1;
      --        ELSE
      --          v_actual_date := LAST_DAY(LAST_DAY(r_rec.date_start) + 1) + 1;
      --        END IF;
      --      END; -- V1.1 (a)
      /* 1.5 Comment Out End */

      --IF v_actual_date <= p_date THEN /* 1.5 */

      IF LENGTH(r_rec.phone_num) < 10 OR LENGTH(r_rec.phone_num) > 10 OR
         r_rec.phone_num IS NULL THEN
        r_rec.phone_num := NULL;
      ELSE
        r_rec.phone_num := ('(' || SUBSTRB(r_rec.phone_num, 1, 3) || ')' ||
                           SUBSTRB(r_rec.phone_num, 4, 3) || '-' ||
                           SUBSTRB(r_rec.phone_num, 7, 4));
      END IF;

      /* 1.5 Commented Out Begin */
      BEGIN
        v_pl_name := NULL;

       SELECT bpf.name --changes 1.1
          INTO v_pl_name --changes 1.1
          --FROM ben.ben_prtt_enrt_rslt_f bper, ben.ben_pl_f bpf --code commented by RXNETHI-ARGANO,15/05/23
		  FROM apps.ben_prtt_enrt_rslt_f bper, apps.ben_pl_f bpf --code added by RXNETHI-ARGANO,15/05/23
         WHERE bper.person_id =  r_rec.person_id --603890
           AND bper.business_group_id = 325
           AND bper.business_group_id = bpf.business_group_id
           AND bper.pl_id = bpf.pl_id
           AND p_date BETWEEN bpf.effective_start_date AND bpf.effective_end_date
               and bpf.EFFECTIVE_START_DATE >= TO_DATE('01-Jan-2016','DD-Mon-RRRR')
                          and bpf.name in ('Primary Care', 'Balanced HRA', 'Choice HSA')
            AND bper.prtt_enrt_rslt_stat_cd IS NULL
            --added following
         and bper.sspndd_flag(+) = 'N' --10967 ----changes 1.1
         and nvl(bper.enrt_cvg_thru_dt,p_date) <= nvl(bper.effective_end_date,p_date)
         and (p_date between
             bper.enrt_cvg_strt_dt and bper.enrt_cvg_thru_dt or
             (p_date >=
             bper.enrt_cvg_strt_dt and p_date <=
             bper.enrt_cvg_thru_dt) or
             (p_date <=
             bper.enrt_cvg_strt_dt and p_date >=
             bper.enrt_cvg_thru_dt) or
             (bper.enrt_cvg_strt_dt is null and bper.enrt_cvg_thru_dt is null))
;


      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_pl_name := 'Waive'; --changes 1.1
        WHEN TOO_MANY_ROWS THEN
          v_pl_name := NULL; --changes 1.1
        WHEN OTHERS THEN
          v_pl_name := NULL; --changes 1.1
      END;

          if v_pl_name = 'Waive' then

          /* 1.5 Commented Out Begin */
          -- fnd_file.put_line(fnd_file.log, v_pl_id || ';' || r_rec.person_id);
          v_text := r_rec.oracleid || ',' || '' || ',' ||
                    --get_plan_val(v_pl_id, r_rec.person_id, p_date) || ',' || --changes 1.1
                    v_pl_name || ',' || --changes 1.1
                    REPLACE(r_rec.first_name, ',', '') || ',' ||
                    REPLACE(r_rec.last_name, ',', '') || ',' ||
                    REPLACE(r_rec.email, ',', '') || ',' || r_rec.phone_num || ',' ||
                    r_rec.dob || ',' || r_rec.sex || ',' ||
                    REPLACE(r_rec.address_line1, ',', '') || ',' ||
                    REPLACE(r_rec.address_line2, ',', '') || ',' ||
                    REPLACE(r_rec.town_or_city, ',', '') || ',' || r_rec.state || ',' ||
                    r_rec.postal_code || ',' || ' ' || ',' ||
                    r_rec.location_code;
          UTL_FILE.put_line(v_file_type, TRIM(v_text));
          fnd_file.put_line(fnd_file.output, v_text);

          end if;

    --END IF; /* 1.5 */
    END LOOP;

    UTL_FILE.fclose(v_file_type);
  EXCEPTION
    WHEN OTHERS THEN
      UTL_FILE.fclose(v_file_type);
      fnd_file.put_line(fnd_file.LOG,
                        'Error out of main loop main_proc -' || SQLERRM);
  END main_proc;
END TTEC_US_BEN_MDLIVE_PARAM;
/
show errors;
/