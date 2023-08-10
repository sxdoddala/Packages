create or replace PACKAGE BODY  ttec_us_umr_intf_pkg
IS
   /*---------------------------------------------------------------------------------------
    Objective    : Interface to extract data for UMR which is Third Party provider which need all the Employee data who are enrolled into
    Medical Plans   'Primary Care','Choice HSA','Balanced HRA'
    this file would be generated in output directory from there the SFTP Program will pick up the file and SFTP to
    UMR. The file will be then moved to archive directory
   Package spec :ttec_us_umr_intf_pkg
   Parameters:
              p_start_date  -- Optional start paramters to run the report if the data is missing for particular dates
              p_end_date  -- Optional end paramters to run the report if the data is missing for particular dates
     MODIFICATION HISTORY
     Person               Version  Date        Comments
     ------------------------------------------------
     Neelofar            1.0    25/12/2020 Created
     Neelofar            1.1    3/2/2021   Cathy suggested changes
     Neelofar            1.2    5/2/2021 Cathy feedback changes
     Kush                1.3    24/3/2021 Kush modifications added
     Kush                1.4    4/5/2021  Termination conditions added
     Kush                1.5    28/5/2021 Post prod issues
	 RXNETHI-ARGANO      1.0    10/05/2023  R12.2 Upgrade Remediation 
      *== ==================================================================================================*/
 PROCEDURE main_proc(
    errbuf              OUT   VARCHAR2,
    retcode             OUT   NUMBER,
    p_output_directory IN VARCHAR2,
    p_start_date       IN VARCHAR2,
    p_end_date         IN VARCHAR2
) AS

    v_dt_time         VARCHAR2(15);
    v_dir_path        VARCHAR2(250);
    v_instance_name   VARCHAR2(250);
  --  v_file_extn       VARCHAR2(15);
    v_emp_file        utl_file.file_type;
    v_out_file        VARCHAR2(32000);
    v_count_utl       NUMBER;
    v_header          VARCHAR2(30000);
    v_text                    VARCHAR (32765)                 DEFAULT '';
    v_text2                    VARCHAR (32765)                 DEFAULT '';
    v_header_rec              VARCHAR (32765)                 DEFAULT '';
    v_file_extn               VARCHAR2 (200)                  DEFAULT '';

    l_host_name               v$instance.host_name%TYPE;
    l_instance_name           v$instance.instance_name%TYPE;
     v_time                    VARCHAR2 (20);
      l_identifier              VARCHAR2 (10);
      v_count NUMBER;
       v_cut_off_date             VARCHAR2 (20);
    v_current_run_date         VARCHAR2 (20);
     v_text3                   VARCHAR (32765)                 DEFAULT '';

          CURSOR c_emp_rec (
      p_cut_off_date        VARCHAR2
     ,p_current_run_date    VARCHAR2

    )
    IS

       SELECT   MAX (date_start) date_start
              ,MAX (NVL (actual_termination_date, to_date(p_current_run_date,'YYYY/MM/DD HH24:MI:SS'))) actual_termination_date
              ,person_id
          FROM per_periods_of_service ppos
         WHERE business_group_id = 325
         AND ((TRUNC(ppos.last_update_date) BETWEEN to_date(p_cut_off_date,'YYYY/MM/DD HH24:MI:SS') AND
             to_date(p_current_run_date,'YYYY/MM/DD HH24:MI:SS') AND
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
             ppos.actual_termination_date >= to_date(p_cut_off_date,'YYYY/MM/DD HH24:MI:SS')))
            -- and PERSON_ID = 1155017
     -- and rownum < 20
       GROUP BY person_id;
     -- having MAX(NVL(actual_termination_date, to_date(p_current_run_date,'YYYY/MM/DD HH24:MI:SS'))) between to_date(p_cut_off_date,'YYYY/MM/DD HH24:MI:SS') and to_date(p_current_run_date,'YYYY/MM/DD HH24:MI:SS'); --v1.5



    CURSOR c_bnft_info  (p_person_id     IN    NUMBER
                        ,p_start_date    IN    VARCHAR2
                        ,p_end_date      IN    VARCHAR2)
     IS
           SELECT
    'EMP' cvr_person,
    pen.effective_start_date,
    pen.effective_end_date,--pen.prtt_enrt_rslt_id,pen.per_in_ler_id,--pen.person_id person_id,pen.prtt_enrt_rslt_id,pen.OBJECT_VERSION_NUMBER,pen.effective_start_date,pen.effective_end_date,
    regexp_replace(ppf.national_identifier, '[^[:digit:]]', NULL) enrollee_ssn,
    ppf.employee_number    employee_id,
    ppf.employee_number    employee_number,
    NULL enrollee_medical_id,
    NULL enrollee_supplemental_id,
    --null member_ssn,--regexp_replace(ppf.national_identifier, '[^[:digit:]]', NULL) member_ssn,
    NULL member_ssn,
   -- regexp_replace(ppf.national_identifier, '[^[:digit:]]', NULL) member_ssn,
    CASE
        WHEN substr(opt.name, 9, 1) = '+' THEN
            'Y'
        ELSE
            ''
    END AS enrollee_indicator,
    '18' member_relationship_code,--'Employee'  Member_Relationship_Code,
    'A' member_rel_code,
    NULL member_supplemental_id,
    /* CASE
        WHEN substr(TO_CHAR(pen.enrt_cvg_thru_dt,'DD-MON-YYYY'),8,4)='4712' THEN 'A'
       ELSE 'T'
        END AS Work_Status_Code,*/
   --change 1.4
    CASE
        WHEN ppos.actual_termination_date IS NOT NULL THEN
            'T'
        WHEN substr(to_char(pen.enrt_cvg_thru_dt, 'DD-MON-YYYY'), 8, 4) = '4712' THEN
            'A'
        ELSE
            'T'
    END AS work_status_code,
        /* CASE
        WHEN pen.enrt_cvg_thru_dt>= to_date(to_date(p_end_date,'YYYY/MM/DD HH24:MI:SS'),'YYYY/MM/DD HH24:MI:SS') THEN 'A'
       ELSE 'T'
        END AS Work_Status_Code,*/
    pen.enrt_cvg_strt_dt,
    pen.enrt_cvg_thru_dt,
    --pen.enrt_cvg_strt_dt        medical_cvg_effective_date,
    --pen.enrt_cvg_thru_dt        medical_cvg_termination_date,
    --- TO_CHAR(pen.enrt_cvg_strt_dt,'YYYYMMDD')medical_cvg_effective_date,---changes 1.2
    CASE
        WHEN pen.enrt_cvg_strt_dt < to_date('01-MAR-21') THEN
            '20210301'
        ELSE
            to_char(pen.enrt_cvg_strt_dt, 'YYYYMMDD')
    END AS medical_cvg_effective_date,
    --TO_CHAR(pen.enrt_cvg_thru_dt,'DD-MON-YYYY')medical_cvg_termination_date,
     /*CASE
        WHEN substr(TO_CHAR(pen.enrt_cvg_thru_dt,'DD-MON-YYYY'),8,4)='4712' THEN ''
       ELSE to_char(pen.enrt_cvg_thru_dt,'YYYYMMDD')-- --TO_CHAR(pen.enrt_cvg_thru_dt,'DD-MON-YYYY')
        END AS medical_cvg_termination_date,*/
        --change 1.4
    CASE
        WHEN ppos.actual_termination_date IS NOT NULL AND ppos.actual_termination_date < pen.enrt_cvg_thru_dt THEN
            to_char(ppos.actual_termination_date, 'YYYYMMDD')
        WHEN substr(to_char(pen.enrt_cvg_thru_dt, 'DD-MON-YYYY'), 8, 4) = '4712' THEN
            ''
        ELSE
            to_char(pen.enrt_cvg_thru_dt, 'YYYYMMDD')-- --TO_CHAR(pen.enrt_cvg_thru_dt,'DD-MON-YYYY')
    END AS medical_cvg_termination_date,--change 1.4
    NULL cobra_coc_event_date,
    NULL cobra_coc_exp_date,
    NULL medicare_plan_code,
    decode(ppf.registered_disabled_flag, 'Y', 'Yes', 'N', 'No',
           'F', 'Yes - Fully Disabled', 'P', 'Yes - Partially Disabled') handicap_indicator,
    ppf.pre_name_adjunct   member_prefix,
    upper(ppf.first_name) member_first_name,
    upper(ppf.middle_names) member_middle_name,
    upper(ppf.last_name) member_last_name,
    upper(ppf.suffix) member_suffix,
    ppf.sex                member_gender_code,
    to_char(ppf.date_of_birth, 'YYYYMMDD') member_birth_date,
    --ppf.marital_status,
    CASE
        WHEN ppf.marital_status = 'S' THEN
            'S'
        WHEN ppf.marital_status = 'M' THEN
            'M'
        WHEN ppf.marital_status = 'D' THEN
            'D'
        WHEN ppf.marital_status = 'L' THEN
            'L'
        WHEN ppf.marital_status = 'W' THEN
            'W'
        WHEN ppf.marital_status = 'B' THEN
            'B'
        ELSE
            'U'
    END AS marital_status,
  /*  -- upper(pad.address_line1) Residence_Address1,
      regexp_replace(upper(pad.address_line1), '[^[:digit:]]', NULL) Residence_Address1,
     upper(pad.address_line2) Residence_Address2,
     upper(pad.town_or_city) Residence_City_Name,
     upper(pad.region_2) Residence_State_Code,
    --pad.country country,----------1.1
     CASE
        WHEN pad.country='US' THEN ''
       ELSE pad.country
        END AS country,
    substr(pad.postal_code,1,5) zip_code,*/
    ttec_library.remove_non_ascii(TRIM(translate(upper(pad.address_line1), '???~!@?.?#$%^&*()+{}|:"<>?=[]\/"', ' '))) residence_address1
    ,
    ttec_library.remove_non_ascii(TRIM(translate(upper(pad.address_line2), '???~!@?.?#$%^&*()+{}|:"<>?=[]\/"', ' '))) residence_address2
    ,
    ttec_library.remove_non_ascii(TRIM(translate(upper(pad.town_or_city), '???~!@?.?#$%^&*()+{}|:"<>?=[]\/"', ' '))) residence_city_name
    ,
    ttec_library.remove_non_ascii(TRIM(translate(upper(pad.region_2), '???~!@?.?#$%^&*()+{}|:"<>?=[]\/"', ' '))) residence_state_code
    ,
    CASE
        WHEN pad.country = 'US' THEN
            ''
        ELSE
            pad.country
    END AS country,
    ttec_library.remove_non_ascii(TRIM(translate(substr(pad.postal_code, 1, 5), '???~!@?.?#$%^&*()+{}|:"<>?=[]\/"', ' '))) zip_code
    ,
    regexp_replace(pp.phone_number, '[^[:digit:]]', NULL) primary_phone_number,
    NULL supplemental_phone_number,
    NULL primary_email_address,
    NULL supplemental_email_address,
    pln.pl_id              plan_id,
    pln.name               plan_name,
    CASE
        WHEN pln.name LIKE '%Primary Care%' THEN
            'A01'
        WHEN pln.name LIKE '%Balanced HRA%' THEN
            'A02'
        WHEN pln.name LIKE '%Choice HSA%'
             AND opt.name = 'Employee' THEN
            'A03'
        ELSE
            'A04'
    END AS class_code,
       -- pln.name || ' '|| opt.name coverage_level_code,
    CASE
        WHEN opt.name = 'Employee'                                 THEN
            '1'--'EMP'
        WHEN opt.name = 'Employee+Family'                          THEN
            '3'-- 'FAM'
        WHEN opt.name = 'Employee+Spouse'                          THEN
            '5'--'ESP'
        WHEN opt.name = 'Employee+Children'                        THEN
            '6'--'ECH'
        WHEN opt.name = 'Employee+Dom Part+Employee Children Only' THEN
            '3'-- 'FAM'
        WHEN opt.name = 'Exec Employee+Spouse'                     THEN
            '5'-- 'ESP'
        WHEN opt.name = 'Exec Employee+Fam'                        THEN
            '3'--'FAM'
        WHEN opt.name = 'Post Tax Employee+Spouse'                 THEN
            '5'-- 'ESP'
        WHEN opt.name = 'Post Tax Employee+Children'               THEN
            '6'-- 'ECH'
        WHEN opt.name = 'Employee+Dom Part+Family'                 THEN
            '3'-- 'FAM'
        WHEN opt.name = 'Employee+Dom Part+Children incl DP Child' THEN
            '3'-- 'FAM'
        WHEN opt.name = 'Exec Employee'                            THEN
            '1'--'EMP'
        WHEN opt.name = 'Post Tax Employee'                        THEN
            '1'-- 'EMP'
        WHEN opt.name = 'Employee+Dom Partner'                     THEN
            '5'-- 'ESP'
        ELSE
            opt.name
    END AS coverage_level_code,
    NULL enrollee_emp_status_code,
    to_char(ppf.original_date_of_hire, 'YYYYMMDD') enrollee_hire_date,
    replace(hla.location_code, ',', '') enrollee_work_location,
    to_char(sysdate, 'YYYYMMDD') file_effective_datetime,
    to_char(sysdate, 'YYYYMMDD') file_run_datetime
FROM
    ben_pl_f                      pln,
    ben_prtt_enrt_rslt_f          pen,
    ben_per_in_ler                pil,
    per_all_people_f              ppf,
    ben_opt_f                     opt,
    ben_oipl_f                    oipl,
    per_all_assignments_f         paaf,
    hr_locations_all              hla,
    apps.per_addresses            pad
           -- ,apps.fnd_lookup_values flv
    ,
    apps.per_phones               pp
          --  ,CUST.TTEC_KAISER_POSTAL_CODE subgroup
           -- ,apps.per_phones pp1
    ,
    apps.per_periods_of_service   ppos --change 1.4
WHERE
    paaf.person_id = pen.person_id
    AND ppf.person_id = ppos.person_id --change 1.4
    AND ppos.date_start = (
        SELECT
            MAX(date_start)
        FROM
            per_periods_of_service p
        WHERE
            p.person_id = ppos.person_id
    )
  --  AND ppf.employee_number = :p_emp_num
    AND paaf.location_id = hla.location_id
    AND hla.inactive_date IS NULL
    AND pad.primary_flag (+) = 'Y'
     --AND ppf.current_employee_flag = 'Y' --change 1.4
    AND ppf.person_id = pad.person_id (+)
    AND to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS') BETWEEN pln.effective_start_date AND pln.effective_end_date
    AND trunc(sysdate) BETWEEN ppf.effective_start_date AND ppf.effective_end_date
    AND trunc(sysdate) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
    AND trunc(sysdate) BETWEEN pad.date_from (+) AND nvl(pad.date_to(+), TO_DATE('31-DEC-4712', 'DD-MON-RRRR'))
    AND trunc(sysdate) BETWEEN pp.date_from (+) AND nvl(pp.date_to(+), TO_DATE('31-DEC-4712', 'DD-MON-RRRR'))
       --AND TRUNC (SYSDATE+14) BETWEEN pp1.date_from(+) AND NVL (pp1.date_to(+), TO_DATE ('31-DEC-4712', 'DD-MON-RRRR'))
    AND pp.parent_id (+) = ppf.person_id
    AND pp.parent_table (+) = 'PER_ALL_PEOPLE_F'
    AND pp.phone_type (+) = 'H1'
       -- AND pp1.parent_id(+) = ppf.person_id
       -- AND pp1.parent_table(+) = 'PER_ALL_PEOPLE_F'
       -- AND pp1.phone_type(+) = 'H1'
    AND pen.oipl_id = oipl.oipl_id
    AND oipl.pl_id = pln.pl_id
    AND oipl.opt_id = opt.opt_id
    AND pen.person_id = ppf.person_id
    AND pln.business_group_id = 325
    AND pln.pl_stat_cd = 'A'
    AND pln.pl_id = pen.pl_id (+)
    AND pen.prtt_enrt_rslt_stat_cd IS NULL
    AND pen.business_group_id (+) = 325
       -- AND  subgroup.postal_code (+)  = pad.postal_code
       ---  AND subgroup.year=p_year--substr(to_date(p_end_date,'YYYY/MM/DD HH24:MI:SS'),1,4)--'1.4'
       -- and flv.lookup_code(+) = pad.postal_code
       -- AND flv.lookup_type(+) = 'TTEC_KAISER_PINCODE_MAPPING'
       -- and flv.language(+) = 'US'
    AND nvl(pen.enrt_cvg_thru_dt, to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS')) <= nvl(pen.effective_end_date, to_date(p_end_date
    , 'YYYY/MM/DD HH24:MI:SS'))
       --AND pen.sspndd_flag(+) = 'N'
    AND pil.per_in_ler_id (+) = pen.per_in_ler_id
     AND pen.person_id        = p_person_id
    AND ( pil.per_in_ler_stat_cd IN (
        'STRTD',
        'PROCD'
    )
          OR pil.per_in_ler_stat_cd IS NULL )
    AND ( to_date(p_start_date, 'YYYY/MM/DD HH24:MI:SS') BETWEEN pen.enrt_cvg_strt_dt AND pen.enrt_cvg_thru_dt
          OR to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS') BETWEEN pen.enrt_cvg_strt_dt AND pen.enrt_cvg_thru_dt
          OR ( to_date(p_start_date, 'YYYY/MM/DD HH24:MI:SS') >= pen.enrt_cvg_strt_dt
               AND to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS') <= pen.enrt_cvg_thru_dt )
          OR ( to_date(p_start_date, 'YYYY/MM/DD HH24:MI:SS') <= pen.enrt_cvg_strt_dt
               AND to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS') >= pen.enrt_cvg_thru_dt )
          OR ( to_date(p_start_date, 'YYYY/MM/DD HH24:MI:SS') <= pen.enrt_cvg_strt_dt
               AND to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS') <= pen.enrt_cvg_thru_dt )
          OR pen.enrt_cvg_strt_dt IS NULL
          AND pen.enrt_cvg_thru_dt IS NULL )
       -- AND pln.pl_id =18871
    AND pln.name IN (
        'Primary Care',
        'Choice HSA',
        'Balanced HRA'
    )
    AND to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS') BETWEEN oipl.effective_start_date AND oipl.effective_end_date
   AND pen.prtt_enrt_rslt_id = (
        SELECT
            MAX(pen1.prtt_enrt_rslt_id)
        FROM
            apps.ben_prtt_enrt_rslt_f pen1
        WHERE
            pen1.person_id = pen.person_id
            AND pen1.pl_id = pen.pl_id
              AND nvl(pen1.enrt_cvg_thru_dt, to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS')) <= nvl(pen1.effective_end_date, to_date(p_end_date
    , 'YYYY/MM/DD HH24:MI:SS'))
	   AND ( to_date(p_start_date, 'YYYY/MM/DD HH24:MI:SS') BETWEEN pen1.enrt_cvg_strt_dt AND pen1.enrt_cvg_thru_dt
          OR to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS') BETWEEN pen1.enrt_cvg_strt_dt AND pen1.enrt_cvg_thru_dt
          OR ( to_date(p_start_date, 'YYYY/MM/DD HH24:MI:SS') >= pen1.enrt_cvg_strt_dt
               AND to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS') <= pen1.enrt_cvg_thru_dt )
          OR ( to_date(p_start_date, 'YYYY/MM/DD HH24:MI:SS') <= pen1.enrt_cvg_strt_dt
               AND to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS') >= pen1.enrt_cvg_thru_dt )
          OR ( to_date(p_start_date, 'YYYY/MM/DD HH24:MI:SS') <= pen1.enrt_cvg_strt_dt
               AND to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS') <= pen1.enrt_cvg_thru_dt )
          OR pen1.enrt_cvg_strt_dt IS NULL
          AND pen1.enrt_cvg_thru_dt IS NULL )
            AND pen1.prtt_enrt_rslt_stat_cd IS NULL--kush v 1.3
            AND pen1.business_group_id (+) = 325

    )
       --kush v1.3
     /* AND NOT EXISTS
       (
              SELECT
                     1
              FROM
                     apps.ben_prtt_enrt_rslt_f pen1
              WHERE
                     pen.person_id                         = pen1.person_id
                     AND pen1.prtt_enrt_rslt_stat_cd IS NULL
                     AND pen1.prtt_enrt_rslt_id           <> pen.prtt_enrt_rslt_id
                     AND pen1.business_group_id (+)        = 325
                     AND pen.enrt_cvg_strt_dt              < pen1.enrt_cvg_strt_dt
                     AND nvl(pen.bnft_amt, - 1)            = nvl(pen1.bnft_amt, - 1)
                     AND pen.pl_id                         = pen1.pl_id
                     AND
                     (
                            to_date(p_start_date, 'YYYY/MM/DD HH24:MI:SS') BETWEEN pen1.enrt_cvg_strt_dt AND pen1.enrt_cvg_thru_dt
                            OR to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS') BETWEEN pen1.enrt_cvg_strt_dt AND pen1.enrt_cvg_thru_dt
                            OR
                            (
                                   to_date(p_start_date, 'YYYY/MM/DD HH24:MI:SS')   >= pen1.enrt_cvg_strt_dt
                                   AND to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS') <= pen1.enrt_cvg_thru_dt
                            )
                            OR
                            (
                                   to_date(p_start_date, 'YYYY/MM/DD HH24:MI:SS')   <= pen1.enrt_cvg_strt_dt
                                   AND to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS') >= pen1.enrt_cvg_thru_dt
                            )
                            OR
                            (
                                   to_date(p_start_date, 'YYYY/MM/DD HH24:MI:SS')   <= pen.enrt_cvg_strt_dt
                                   AND to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS') <= pen.enrt_cvg_thru_dt
                            )
                            OR pen1.enrt_cvg_strt_dt  IS NULL
                            AND pen1.enrt_cvg_thru_dt IS NULL
                     )
     --  )*/
    AND pen.enrt_cvg_thru_dt >= to_date('01-MAR-21')
UNION
SELECT
    'DPNT' cvr_person,
    dpnt.effective_start_date,
    dpnt.effective_end_date,--dpnt.prtt_enrt_rslt_id,dpnt.per_in_ler_id,--dpnt.DPNT_PERSON_ID person_id,dpnt.prtt_enrt_rslt_id,DPNT.OBJECT_VERSION_NUMBER,dpnt.effective_start_date,dpnt.effective_end_date,
    regexp_replace(ppf.national_identifier, '[^[:digit:]]', NULL) enrollee_ssn,
    --ppf.employee_number         employee_id,
    NULL employee_id,
    ppf.employee_number    employee_number,
    NULL enrollee_medical_id,
    NULL enrollee_supplemental_id,
    regexp_replace(con.national_identifier, '[^[:digit:]]', NULL) member_ssn,
    CASE
        WHEN substr(opt.name, 9, 1) = '+' THEN
            'Y'
        ELSE
            ''
    END AS enrollee_indicator,
     -- HR_GENERAL.DECODE_LOOKUP('CONTACT',pcr.CONTACT_TYPE) Member_Relationship_Code,
   -- DECODE(HR_GENERAL.DECODE_LOOKUP('CONTACT',pcr.CONTACT_TYPE),'Employee','18','Spouse','01','Child','19') Member_Relationship_Code,
    CASE
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Employee' THEN
            '18'
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Spouse'  THEN
            '01'
        ELSE
            '19'
    END AS member_relationship_code,

       -- DECODE(HR_GENERAL.DECODE_LOOKUP('CONTACT',pcr.CONTACT_TYPE),'Employee','A','Spouse','B','Child','C') Member_Rel_Code,
    CASE
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Employee' THEN
            'A'
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = ( 'Spouse' ) THEN
            'B'
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) LIKE ( '%Domestic Partner' ) THEN
            'B'
        ELSE
            'C'
    END AS member_rel_code,
    NULL member_supplemental_id,
      /*CASE
        WHEN substr(TO_CHAR(pen.enrt_cvg_thru_dt,'DD-MON-YYYY'),8,4)='4712' THEN 'A'
       ELSE 'T'
        END AS Work_Status_Code,*/
      /*   CASE
        WHEN substr(TO_CHAR(dpnt.cvg_thru_dt,'DD-MON-YYYY'),8,4)='4712' THEN 'A'
       ELSE 'T'
        END AS Work_Status_Code, */
        --change 1.4
    CASE
        WHEN ppos.actual_termination_date IS NOT NULL THEN
            'T'
        WHEN substr(to_char(dpnt.cvg_thru_dt, 'DD-MON-YYYY'), 8, 4) = '4712' THEN
            'A'
        ELSE
            'T'
    END AS work_status_code,
 --change 1.4
       /* CASE
        WHEN dpnt.cvg_thru_dt>= to_date(to_date(p_end_date,'YYYY/MM/DD HH24:MI:SS'),'YYYY/MM/DD HH24:MI:SS') THEN 'A'
       ELSE 'T'
        END AS Work_Status_Code,*/
    dpnt.cvg_strt_dt,
    dpnt.cvg_thru_dt,

    --TO_CHAR(pen.enrt_cvg_strt_dt,'YYYYMMDD')medical_cvg_effective_date,--changes 1.2
    -- CASE WHEN pen.enrt_cvg_strt_dt<to_date('01-MAR-21') then '20210301' else TO_CHAR(pen.enrt_cvg_strt_dt,'YYYYMMDD')
    --END AS medical_cvg_effective_date,
    CASE
        WHEN dpnt.cvg_strt_dt < to_date('01-MAR-21') THEN
            '20210301'
        ELSE
            to_char(dpnt.cvg_strt_dt, 'YYYYMMDD')
    END AS medical_cvg_effective_date,

   -- TO_CHAR(pen.enrt_cvg_thru_dt,'DD-MON-YYYY')medical_cvg_termination_date,
    /* CASE
        WHEN substr(TO_CHAR(pen.enrt_cvg_thru_dt,'DD-MON-YYYY'),8,4)='4712' THEN ''
       ELSE  to_char(pen.enrt_cvg_thru_dt,'YYYYMMDD')---TO_CHAR(pen.enrt_cvg_thru_dt,'DD-MON-YYYY')
        END AS medical_cvg_termination_date,*/
     /* CASE
        WHEN substr(TO_CHAR(dpnt.cvg_thru_dt,'DD-MON-YYYY'),8,4)='4712' THEN ''
       ELSE  to_char(dpnt.cvg_thru_dt,'YYYYMMDD')---TO_CHAR(pen.enrt_cvg_thru_dt,'DD-MON-YYYY')
        END AS medical_cvg_termination_date, */
         --change 1.4
    CASE
        WHEN ppos.actual_termination_date IS NOT NULL    AND ppos.actual_termination_date < dpnt.cvg_thru_dt THEN
            to_char(ppos.actual_termination_date, 'YYYYMMDD')
        WHEN substr(to_char(dpnt.cvg_thru_dt, 'DD-MON-YYYY'), 8, 4) = '4712' THEN
            ''
        ELSE
            to_char(dpnt.cvg_thru_dt, 'YYYYMMDD')-- --TO_CHAR(pen.enrt_cvg_thru_dt,'DD-MON-YYYY')
    END AS medical_cvg_termination_date, --change 1.4
    NULL cobra_coc_event_date,
    NULL cobra_coc_exp_date,
    NULL medicare_plan_code,
    decode(con.registered_disabled_flag, 'Y', 'Yes', 'N', 'No',
           'F', 'Yes - Fully Disabled', 'P', 'Yes - Partially Disabled') handicap_indicator,
    ppf.pre_name_adjunct   member_prefix,
    upper(con.first_name) member_first_name,
    upper(con.middle_names) member_middle_name,
    upper(con.last_name) member_last_name,
    upper(con.suffix) member_suffix,
    con.sex                member_gender_code,
    to_char(con.date_of_birth, 'YYYYMMDD') member_birth_date,
    --con.marital_status,
    CASE
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Spouse'                              THEN
            '2'--2 = Spouse
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Domestic Partner'                    THEN
            '9'--9 = Domestic Partner or Domestic Partner IRS
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) LIKE '%Domestic Partner' THEN
            '9'--9 = Domestic Partner or Domestic Partner IRS
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Domestic Partner IRS'                THEN
            '9'--9 = Domestic Partner or Domestic Partner IRS
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Domestic Partner non IRS'            THEN
            'F'--2 = Spouse
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Deceased Spouse'                     THEN
            'T'
    ----KIDS-------------------
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Child'                               THEN
            '3'
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Stepchild'                           THEN
            '4'
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Step Child'                          THEN
            '4'
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Handicapped'                         THEN
            '5'
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Student'                             THEN
            '6'
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Adopted'                             THEN
            '7'
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Adopted Child'                       THEN
            '7'
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Grandchild'                          THEN
            '8'
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Niece'                               THEN
            'A'
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Nephew'                              THEN
            'A'
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'In-law'                              THEN
            'C'
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Parent'                              THEN
            'B'
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Other'                               THEN
            'D'
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Foster Child'                        THEN
            '3'--Add Foster child--kush v 1.3
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Domestic Partner child IRS'          THEN
            'G'
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Domestic Partner Child'              THEN
            'G'
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Domestic Partner child non IRS'      THEN
            'H'
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Domestic Partner student IRS'        THEN
            'I'
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Domestic Partner student non IRS'    THEN
            'J'
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Domestic Partner handicapped IRS'    THEN
            'K'
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Domestic Partner handicapped non IRS' THEN
            'L'
        WHEN hr_general.decode_lookup('CONTACT', pcr.contact_type) = 'Deceased Dependent'                  THEN
            'M'
        ELSE
            hr_general.decode_lookup('CONTACT', pcr.contact_type)
    END AS marital_status,
    ttec_library.remove_non_ascii(TRIM(translate(upper(pad.address_line1), '???~!@?.?#$%^&*()+{}|:"<>?=[]\/"', ' '))) residence_address1
    ,
    ttec_library.remove_non_ascii(TRIM(translate(upper(pad.address_line2), '???~!@?.?#$%^&*()+{}|:"<>?=[]\/"', ' '))) residence_address2
    ,
    ttec_library.remove_non_ascii(TRIM(translate(upper(pad.town_or_city), '???~!@?.?#$%^&*()+{}|:"<>?=[]\/"', ' '))) residence_city_name
    ,
    ttec_library.remove_non_ascii(TRIM(translate(upper(pad.region_2), '???~!@?.?#$%^&*()+{}|:"<>?=[]\/"', ' '))) residence_state_code
    ,
    CASE
        WHEN pad.country = 'US' THEN
            ''
        ELSE
            pad.country
    END AS country,
    ttec_library.remove_non_ascii(TRIM(translate(substr(pad.postal_code, 1, 5), '???~!@?.?#$%^&*()+{}|:"<>?=[]\/"', ' '))) zip_code
    ,
   /*  upper(pad.address_line1) Residence_Address1,
     upper(pad.address_line2) Residence_Address2,
     upper(pad.town_or_city) Residence_City_Name,
     upper(pad.region_2) Residence_State_Code,
     --pad.country country, --1.1
      CASE
        WHEN pad.country='US' THEN ''
       ELSE pad.country
        END AS country,
     substr(pad.postal_code,1,5) zip_code,*/
   --regexp_replace( pp.phone_number, '[^[:digit:]]', null ) mem_home_phone,
    regexp_replace(nvl(pp.phone_number, pp1.phone_number), '[^[:digit:]]', NULL) primary_phone_number,
    NULL supplemental_phone_number,
    NULL primary_email_address,
    NULL supplemental_email_address,
    pln.pl_id              plan_id,
    pln.name               plan_name,
    CASE
        WHEN pln.name LIKE '%Primary Care%' THEN
            'A01'
        WHEN pln.name LIKE '%Balanced HRA%' THEN
            'A02'
        WHEN pln.name LIKE '%Choice HSA%'
             AND opt.name = 'Employee' THEN
            'A03'
        ELSE
            'A04'
    END AS class_code,
        --pln.name|| ' '|| opt.name coverage_level_code,
    CASE
        WHEN opt.name = 'Employee'                                 THEN
            '1'--'EMP'
        WHEN opt.name = 'Employee+Family'                          THEN
            '3'-- 'FAM'
        WHEN opt.name = 'Employee+Spouse'                          THEN
            '5'--'ESP'
        WHEN opt.name = 'Employee+Children'                        THEN
            '6'--'ECH'
        WHEN opt.name = 'Employee+Dom Part+Employee Children Only' THEN
            '3'-- 'FAM'
        WHEN opt.name = 'Exec Employee+Spouse'                     THEN
            '5'-- 'ESP'
        WHEN opt.name = 'Exec Employee+Fam'                        THEN
            '3'--'FAM'
        WHEN opt.name = 'Post Tax Employee+Spouse'                 THEN
            '5'-- 'ESP'
        WHEN opt.name = 'Post Tax Employee+Children'               THEN
            '6'-- 'ECH'
        WHEN opt.name = 'Employee+Dom Part+Family'                 THEN
            '3'-- 'FAM'
        WHEN opt.name = 'Employee+Dom Part+Children incl DP Child' THEN
            '3'-- 'FAM'
        WHEN opt.name = 'Exec Employee'                            THEN
            '1'--'EMP'
        WHEN opt.name = 'Post Tax Employee'                        THEN
            '1'-- 'EMP'
        WHEN opt.name = 'Employee+Dom Partner'                     THEN
            '5'-- 'ESP'
        ELSE
            opt.name
    END AS coverage_level_code,
    NULL enrollee_emp_status_code,
    to_char(ppf.original_date_of_hire, 'YYYYMMDD') enrollee_hire_date,
    NULL enrollee_work_location,
    to_char(sysdate, 'YYYYMMDD') file_effective_datetime,
    to_char(sysdate, 'YYYYMMDD') file_run_datetime
FROM
    ben_pl_f                      pln,
    ben_prtt_enrt_rslt_f          pen,
    --ben.ben_elig_cvrd_dpnt_f      dpnt,   --code commented by RXNETHI-ARGANO,10/05/23
    apps.ben_elig_cvrd_dpnt_f      dpnt,    --code added by RXNETHI-ARGANO,10/05/23
    per_all_people_f              ppf,
    ben_opt_f                     opt,
    ben_oipl_f                    oipl,
    per_all_assignments_f         paaf,--changes 1.4
    per_all_people_f              con,
    apps.per_addresses            pad
           -- ,apps.fnd_lookup_values flv
    ,
    apps.per_phones               pp,
    apps.per_phones               pp1,
    apps.per_addresses            pademp
            -- ,CUST.TTEC_KAISER_POSTAL_CODE subgroup
    ,
    per_contact_relationships     pcr,
    apps.per_periods_of_service   ppos  --change 1.4
WHERE
    to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS') BETWEEN pln.effective_start_date AND pln.effective_end_date
    --AND ppf.employee_number = :p_emp_num
    AND pen.person_id = ppf.person_id
    AND ppf.person_id = ppos.person_id --change 1.4
    AND ppos.date_start = (
        SELECT
            MAX(date_start)
        FROM
            per_periods_of_service p
        WHERE
            p.person_id = ppos.person_id
    ) --changes 1.4
    AND paaf.person_id=pen.person_id--changes 1.4
    AND pen.prtt_enrt_rslt_id = dpnt.prtt_enrt_rslt_id
    AND con.person_id = dpnt.dpnt_person_id
    AND pad.primary_flag (+) = 'Y'
    --AND ppf.current_employee_flag = 'Y' --change 1.4
    AND pad.person_id (+) = con.person_id
    AND pademp.primary_flag (+) = 'Y'
    AND pademp.person_id (+) = ppf.person_id
    AND pcr.person_id = ppf.person_id      --change 1.3
    AND pcr.contact_person_id = dpnt.dpnt_person_id--change 1.3
         -- and trunc(SYSDATE+14) between pcr.date_start and nvl(pcr.date_end,to_date('31-dec-4712','dd-mon-rrrr'))--change 1.3--23feb2021b
        /* AND pcr.object_version_number =
         (
                SELECT
                       MAX(object_version_number)
                FROM
                       apps.per_contact_relationships
                WHERE
                       person_id             = pcr.person_id
                       AND contact_person_id = pcr.contact_person_id
         )*/--kush v 1.3
    AND nvl(pcr.date_end, TO_DATE('31-dec-4712', 'dd-mon-rrrr')) = (
        SELECT
            MAX(nvl(date_end, TO_DATE('31-dec-4712', 'dd-mon-rrrr')))
        FROM
            apps.per_contact_relationships
        WHERE
            person_id = pcr.person_id
            AND contact_person_id = pcr.contact_person_id
    )
    AND pcr.date_start <= trunc(sysdate)
    AND pcr.contact_type <> 'EMRG'--change 1.3
    AND pcr.contact_type IN (
        'S',
        'D',
        'C',
        'A',
        'R',
        'O',
        'T'
    )                                                                                                                            --change 1.3
    AND nvl(pen.enrt_cvg_thru_dt, to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS')) <= nvl(pen.effective_end_date, to_date(p_end_date
    , 'YYYY/MM/DD HH24:MI:SS'))--change 1.3
    AND trunc(sysdate) BETWEEN ppf.effective_start_date AND ppf.effective_end_date
    AND trunc(sysdate) BETWEEN con.effective_start_date AND con.effective_end_date--Replace with sysdate--kush v 1.3
    AND trunc(sysdate) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
    AND trunc(sysdate) BETWEEN pad.date_from (+) AND nvl(pad.date_to(+), TO_DATE('31-DEC-4712', 'DD-MON-RRRR'))
    AND trunc(sysdate) BETWEEN pademp.date_from (+) AND nvl(pademp.date_to(+), TO_DATE('31-DEC-4712', 'DD-MON-RRRR'))
    AND trunc(sysdate) BETWEEN pp.date_from (+) AND nvl(pp.date_to(+), TO_DATE('31-DEC-4712', 'DD-MON-RRRR'))
    AND trunc(sysdate) BETWEEN pp1.date_from (+) AND nvl(pp1.date_to(+), TO_DATE('31-DEC-4712', 'DD-MON-RRRR'))
    AND pp.parent_id (+) = con.person_id
    AND pp.parent_table (+) = 'PER_ALL_PEOPLE_F'
    AND pp.phone_type (+) = 'H1'
    AND pp1.parent_id (+) = ppf.person_id
    AND pp1.parent_table (+) = 'PER_ALL_PEOPLE_F'
    AND pp1.phone_type (+) = 'H1'
    AND pln.business_group_id = 325
    AND pln.pl_stat_cd = 'A'
    AND pln.pl_id = pen.pl_id (+)
    AND pen.oipl_id = oipl.oipl_id
    AND oipl.pl_id = pen.pl_id
    AND pen.prtt_enrt_rslt_stat_cd IS NULL
    AND pen.business_group_id (+) = 325
    AND ( nvl(dpnt.cvg_thru_dt, dpnt.effective_end_date) <= dpnt.effective_end_date
          OR dpnt.effective_end_date = TO_DATE('31-DEC-4712', 'DD-MON-RRRR') )
         and pen.person_id = p_person_id
    AND oipl.opt_id = opt.opt_id
         -- AND flv.lookup_type(+) = 'TTEC_KAISER_PINCODE_MAPPING'
         --  AND subgroup.postal_code(+) =  pademp.postal_code
         --   AND subgroup.year= p_year--substr(to_date(p_end_date,'YYYY/MM/DD HH24:MI:SS'),1,4)--1.4
         --   and flv.lookup_code(+) = pademp.postal_code
         --  AND flv.LANGUAGE(+) = 'US'
         --  and ppf.employee_number='3002297'
   /* AND dpnt.elig_cvrd_dpnt_id = (
        SELECT
            MAX(dpnt1.elig_cvrd_dpnt_id)
        FROM
            ben.ben_elig_cvrd_dpnt_f    dpnt1,
            apps.ben_prtt_enrt_rslt_f   pen1
        WHERE
            pen1.prtt_enrt_rslt_id = dpnt1.prtt_enrt_rslt_id
            AND dpnt1.dpnt_person_id = dpnt.dpnt_person_id
            AND pen1.pl_id = pen.pl_id
            AND pen.prtt_enrt_rslt_stat_cd IS NULL
            AND pen.business_group_id = 325
            AND pen1.prtt_enrt_rslt_id = pen.prtt_enrt_rslt_id --kush v 1.3
                       --            and  dpnt.prtt_enrt_rslt_id =  pen.prtt_enrt_rslt_id
    )*/ --v1.5
    AND ( to_date(p_start_date, 'YYYY/MM/DD HH24:MI:SS') BETWEEN pen.enrt_cvg_strt_dt AND pen.enrt_cvg_thru_dt
          OR to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS') BETWEEN pen.enrt_cvg_strt_dt AND pen.enrt_cvg_thru_dt
          OR ( to_date(p_start_date, 'YYYY/MM/DD HH24:MI:SS') >= pen.enrt_cvg_strt_dt
               AND to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS') <= pen.enrt_cvg_thru_dt )
          OR ( to_date(p_start_date, 'YYYY/MM/DD HH24:MI:SS') <= pen.enrt_cvg_strt_dt
               AND to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS') >= pen.enrt_cvg_thru_dt )
          OR ( to_date(p_start_date, 'YYYY/MM/DD HH24:MI:SS') <= pen.enrt_cvg_strt_dt
               AND to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS') <= pen.enrt_cvg_thru_dt )
          OR pen.enrt_cvg_strt_dt IS NULL
          AND pen.enrt_cvg_thru_dt IS NULL )
    AND EXISTS (
        SELECT
            dep.per_in_ler_id
        FROM
            apps.ben_per_in_ler dep
        WHERE
            dep.per_in_ler_id = pen.per_in_ler_id
            AND dep.business_group_id = 325
            AND ( dep.per_in_ler_stat_cd IN (
                'STRTD',
                'PROCD'
            )
                  OR dep.per_in_ler_stat_cd IS NULL )
    )
         ----------------------------Adding below condition to dependent query---------------------
  /*  AND pen.prtt_enrt_rslt_id = (
           SELECT
            MAX(pen1.prtt_enrt_rslt_id)
        FROM
            apps.ben_prtt_enrt_rslt_f pen1
        WHERE
            pen1.person_id = pen.person_id
            AND pen1.pl_id = pen.pl_id
              AND nvl(pen1.enrt_cvg_thru_dt, to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS')) <= nvl(pen1.effective_end_date, to_date(p_end_date
    , 'YYYY/MM/DD HH24:MI:SS'))
	   AND ( to_date(p_start_date, 'YYYY/MM/DD HH24:MI:SS') BETWEEN pen1.enrt_cvg_strt_dt AND pen1.enrt_cvg_thru_dt
          OR to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS') BETWEEN pen1.enrt_cvg_strt_dt AND pen1.enrt_cvg_thru_dt
          OR ( to_date(p_start_date, 'YYYY/MM/DD HH24:MI:SS') >= pen1.enrt_cvg_strt_dt
               AND to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS') <= pen1.enrt_cvg_thru_dt )
          OR ( to_date(p_start_date, 'YYYY/MM/DD HH24:MI:SS') <= pen1.enrt_cvg_strt_dt
               AND to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS') >= pen1.enrt_cvg_thru_dt )
          OR ( to_date(p_start_date, 'YYYY/MM/DD HH24:MI:SS') <= pen1.enrt_cvg_strt_dt
               AND to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS') <= pen1.enrt_cvg_thru_dt )
          OR pen1.enrt_cvg_strt_dt IS NULL
          AND pen1.enrt_cvg_thru_dt IS NULL )
            AND pen1.prtt_enrt_rslt_stat_cd IS NULL--kush v 1.3
            AND pen1.business_group_id (+) = 325

    )*/--v1.5

       ----------------------------End  Adding below condition to dependent query---------------------
       ---------------------------- ---------v1.5------------------Replace with the above code 27052021----------------------------
    AND dpnt.prtt_enrt_rslt_id =
           (
                  SELECT
                         MAX(dpnt1.prtt_enrt_rslt_id)
                  FROM
                         --ben.ben_elig_cvrd_dpnt_f  dpnt1 --code commented by RXNETHI-ARGANO,10/05/23
						 apps.ben_elig_cvrd_dpnt_f  dpnt1 --code added by RXNETHI-ARGANO,10/05/23
                       , apps.ben_prtt_enrt_rslt_f pen1
                       --, ben.ben_pl_f              pln1 --code commented by RXNETHI-ARGANO,10/05/23
					   , apps.ben_pl_f              pln1  --code added by RXNETHI-ARGANO,10/05/23
                  WHERE
                         pen1.prtt_enrt_rslt_id   = dpnt1.prtt_enrt_rslt_id
                         AND dpnt1.dpnt_person_id = dpnt.dpnt_person_id
                         --    AND pl_id IN ( 11871, 9871, 10871 )
                         --                         AND pen1.pl_id                       = pen1.pl_id
                         AND pen1.prtt_enrt_rslt_stat_cd IS NULL
                         AND pen1.business_group_id            = 325
                         AND pln1.business_group_id            = 325
                         AND pln1.pl_stat_cd                   = 'A'
                         AND pln1.pl_id                        = pen1.pl_id (+)
                         AND pln1.name IN ( 'Primary Care'
                                         , 'Choice HSA'
                                         , 'Balanced HRA' )
           )
           --------------------------------End Replace with the above code 27052021-------------------------------------------
    AND pen.sspndd_flag (+) = 'N'
         --    AND dpnt.cvg_strt_dt <= to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS')
    AND nvl(dpnt.cvg_thru_dt, to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS')) >= to_date(p_start_date, 'YYYY/MM/DD HH24:MI:SS')
    AND dpnt.cvg_strt_dt <= nvl(dpnt.cvg_thru_dt, to_date(p_end_date, 'YYYY/MM/DD HH24:MI:SS')) --Added for v1.4
         --AND opt.name <> 'Waive'
         -- AND pln.pl_id =18871
    AND pln.name IN (
        'Primary Care',
        'Choice HSA',
        'Balanced HRA'
    )
    AND pen.enrt_cvg_thru_dt >= to_date('01-MAR-21')
ORDER BY
    employee_number,
    cvr_person DESC;
     --note: sysdate+days always equals to p_end_date for testing
     n number;
     CURSOR c_host
    IS
      SELECT host_name
            ,instance_name
        FROM v$instance;


BEGIN
 IF    p_start_date IS NULL
       OR p_end_date IS NULL
   THEN
      v_current_run_date   :=  to_char(TRUNC(sysdate,'YYYY'),'YYYY/MM/DD HH24:MI:SS');
    ELSE
      v_current_run_date   := p_end_date;--TO_DATE (p_end_date, 'YYYY/MM/DD HH24:MI:SS');
    END IF;

    v_cut_off_date           := to_char(TRUNC(sysdate,'YYYY'),'YYYY/MM/DD HH24:MI:SS');-- to_date('01-Jan-21');--TRUNC(SYSDATE+14);

     fnd_file.put_line(fnd_file.log, 'v_current_run_date:' || v_current_run_date);
      fnd_file.put_line(fnd_file.log, 'v_cut_off_date ' || v_cut_off_date);
       fnd_file.put_line(fnd_file.log, 'p_end_date ' || p_end_date);

    fnd_file.put_line(fnd_file.log, 'Inside the v_dt_time');
    SELECT
        to_char(sysdate, 'YYYYMMDD-HH24MMSS')
    INTO v_dt_time
    FROM
        dual;

    fnd_file.put_line(fnd_file.log, 'Inside the v_dir_path');
    SELECT
        directory_path || '/data/EBS/HC/Benefits/umr/outbound'
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
            '.txt'
        INTO v_file_extn
        FROM
            v$instance;

    EXCEPTION
        WHEN OTHERS THEN
            v_file_extn := '.txt';
    END;

    BEGIN

    /*<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
     OPEN c_host;

    FETCH c_host
     INTO l_host_name
         ,l_instance_name;

    CLOSE c_host;

    IF l_host_name NOT IN (ttec_library.xx_ttec_prod_host_name)
    THEN
      l_identifier   := 'K35_T_';
      ELSE
      l_identifier   := 'K35_P_';
    END IF;

    FND_FILE.PUT_LINE (FND_FILE.LOG, 'Host Name:');
      BEGIN
       SELECT '.txt'
             ,TO_CHAR (SYSDATE, 'YYYYMMDD_HH24MI')
         INTO v_file_extn
             ,v_time
         FROM v$instance;
     EXCEPTION
       WHEN OTHERS
       THEN
         v_file_extn   := '.txt';
     END;
    FND_FILE.PUT_LINE (FND_FILE.LOG, 'extension name:');
    v_out_file   := l_identifier || 'TTEC_' ||v_time||'.txt';
    FND_FILE.PUT_LINE (FND_FILE.LOG, 'FILE name:');
   -- v_asn_life_file_type     := UTL_FILE.FOPEN (p_output_directory, l_asn_life_active_file, 'w', 32765);

   /* <<<<<<<<<<<<<<<<<<<<<<<<<<*/



        v_count_utl := 0;
        fnd_file.put_line(fnd_file.log, 'Extension name:' || v_file_extn);
       /* v_out_file := 'ttec_perceptadata_ora_to_awardco_'
                      || v_dt_time
                      || v_file_extn;*/
        fnd_file.put_line(fnd_file.log, 'FILE name:' || v_out_file);
        v_emp_file := utl_file.fopen(p_output_directory,v_out_file , 'w', 32000);
        dbms_output.put_line('Before Opening UTL File');
  --  v_utlfile := utl_file.fopen(p_directory_name, v_filename, 'W');
      BEGIN

   v_text:= RPAD('H',1,' ')                                      -- Field 1: 1        1          A (1)       Record Type                         Valid Value: H = Header               R
           || RPAD('6013',4,' ')                                 -- Field 2: 2        5          A (4)       Client Number                      Will be provided ? Identifies the customer   R
           || RPAD('TTEC',30,' ')                                -- Field 3: 6        35         A (30)     Client Name                         Customer Name     R
           || RPAD('UMR',30,' ')                                 -- Field 4: 36       65         A (30)     Vendor Name                       If applicable, name of Benefit Administrator          O
           || RPAD('ELIG',10,' ')                                -- Field 5: 66       75         A (10)     Product Type                        Valid Value:  ELIG indicates eligibility file               R
           || RPAD('UPDATE',20,' ')                              -- Field 6: 76       95         A (20)     Process Type                       Valid Value:  UPDATE indicates eligibility update R
           || LPAD(to_char(SYSDATE,'RRRRMMDD'),8,'0')            -- Field 7: 96       103        N (8)       File Creation Date               Date file was created: Format is YYYYMMDD       R
           || LPAD(to_char(SYSDATE,'RRMMDDHHMI'),10,'0')         -- Field 8: 104      113        N (10)     File Sequence Number      Unique number assigned to this file             O
           || RPAD(' ', 1387,' ');                               -- Field 9: 114      1500      A (1387)    Filler       Reserved default spaces



 dbms_output.put_line('Header*******************');
         UTL_FILE.put_line (v_emp_file, v_text);
        fnd_file.put_line (fnd_file.output, v_text);
    END;
     n := 0;


  FOR r_emp_rec IN c_emp_rec (v_cut_off_date, v_current_run_date)

    LOOP
      dbms_output.put_line('For loop1*******************');
    v_text3 := '';
   --fnd_file.put_line(fnd_file.log, 'r_emp_rec.person_id ' || r_emp_rec.person_id);
        FOR r_bnft_info IN c_bnft_info(r_emp_rec.person_id,v_cut_off_date,v_current_run_date)
        LOOP
                                                            utl_file.put_line(v_emp_file,('BEK0035 ')                      --Field1:	8	A (8)	Record Control Data	Valid Value:  BEK0035
                                                            ||RPAD(' ', 3,' ')                             --Field2:9	11	A (3)	Filler	Reserved - default spaces
                                                            ||RPAD(r_bnft_info.Member_Rel_Code,1,' ')                 --Field3:12	12	A (1)	Member Code	Identifies member
                                                            ||LPAD('0',2,'0')                               --Field4:13	14	N (2)	Member Sequence Number	Represents a unique identifier for the dependent
                                                            ||RPAD(NVL(r_bnft_info.enrollee_ssn,' '),9,' ')                    --Field5:15	23	A (9)	Participant SSN	Participant Social Security Number
                                                            ||RPAD(NVL(r_bnft_info.member_last_name,' '),20,' ')     --Field6-24	43	A (20)	Last Name	Last Name
                                                            ||RPAD(NVL(r_bnft_info.member_first_name,' '),14,' ')    --Field7 44	57	A (14)	First Name	First Name
                                                            ||RPAD(' ',1,' ')                               --Field8 58	58	A (1)	Middle Initial	Middle Initial default spaces
                                                            ||RPAD(' ',3,' ')                               --Field9 59	61	A (3)	Name Qualifier	Valid Values: SR, JR, II, III, IV, MD ? default spaces
                                                            ||RPAD(NVL(r_bnft_info.Residence_Address1,' '),35,' ')   --Field10 --62	96	A (35)	Street Address	Participant only, Dependent only when different
                                                            ||RPAD(NVL(r_bnft_info.Residence_Address2,' '),35,' ')     --Field11 97	131	A (35)	Street Address	Participant only, Dependent only when different ? Default Spaces
                                                            ||RPAD(NVL(r_bnft_info.Residence_City_Name,' '),20,' ')  --Field12 132	151	A (20)	City	Participant only, Dependent only when different
                                                            ||RPAD(NVL(r_bnft_info.Residence_State_Code,' '),2,' ')  --Field13 152	153	A (2)	State	State Code Abbreviation ? Participant only, Dependent only when different
                                                            ||RPAD(NVL(r_bnft_info.country,' '),2,' ')               --Field14 154	155	A (2)	Country	Foreign countries only ? Participant only, Dependent only when different.  Default Spaces
                                                            ||RPAD(' ',8,' ')                               --Field15 156	163	A(8)	Filler	Reserved. Default Spaces.
                                                            ||RPAD(NVL(r_bnft_info.zip_code,' '),9,' ')             --Field16--164	172	A (9)	Zip Code	Participant only, Dependent only when different
                                                            ||RPAD(NVL(r_bnft_info.member_birth_date,' '),8,' ')               --Field17 173	180	N (8)	Date of Birth	Participant birth
                                                            ||RPAD(NVL(r_bnft_info.member_gender_code,' '),1,' ')              --Field18 181	181	A (1)	Gender
                                                            ||RPAD(NVL(r_bnft_info.marital_status,' '),1,' ')                  --Field19 182	182	A (1)	Individual Relationship Code neel
                                                            ||('76414872')                                  --Field20 183	190	N (8)	Group Number
                                                            ||'001'                                         --Field21 191	193	A (3)	Participant Location
                                                            ||RPAD(NVL(r_bnft_info.Work_Status_Code,' '),1,' ')           --Field22 194	194	A (1)	Work Status
                                                            ||RPAD(NVL(r_bnft_info.Residence_State_Code,' '),2,' ')         --Field23 195	196	A (2)	Work State
                                                            --||LPAD(' ',8,' ')                  --Field24 197	204	N (8)	Original Hire Date--changes 1.1
                                                            ||RPAD(NVL(r_bnft_info.enrollee_hire_date,' '),8,' ')
                                                            ||LPAD('0',8,'0') --Field25 205	212	N (8)	Dependent Current Status Date
                                                            ||LPAD('0',9,'0') --Field26 213	221	N (9)	Salary
                                                            ||RPAD(' ',1,' ') --Field27 222	222	A (1)	Salary Period
                                                            ||LPAD('0',1,'0') --Field28 223	223	N (1)	Reserved
                                                            ||RPAD(NVL(r_bnft_info.member_ssn,' '),9,' ')     --Field29 224	232	A (9)	Dependent SSN
                                                            ||RPAD(' ',4,' ') --Field30   --233	236	A (4)	Filler	Reserved Default Spaces
                                                            ---Coverage1
                                                            ||RPAD(NVL('H',' '),1,' ')--Field31 237	237	A (1)	Line Description Code
                                                            ||('767000414872')--Field32 238	249	N (12)	Plan/Contract Number
                                                            ||LPAD(NVL(r_bnft_info.medical_cvg_effective_date,'0'),8,'0') --Field33 250	257	N (8)	Effective Date	Effective date of coverage
                                                            ||LPAD(NVL(r_bnft_info.medical_cvg_termination_date,'0'),8,'0')--Field34 258	265	N (8)	Termination Date
                                                            ||RPAD(NVL(r_bnft_info.class_code,' '),3,' ')      --Field35 266	268	A (3)	Class Code
                                                            ||LPAD(NVL(r_bnft_info.coverage_level_code,'0'),1,'0')  --Field36 269	269	N (1)	Coverage Type
                                                            -----Coverage2
                                                           /*  ||RPAD(NVL('H',' '),1,' ')--Field37 270	270	A (1)	Line Description Code
                                                            ||('767000414872')--Field38 271	282	N (12)	Plan/Contract Number
                                                            ||RPAD(NVL(r_bnft_info.medical_cvg_effective_date,' '),8,' ') --Field39 283	290	N (8)	Effective Date	Effective date of coverage
                                                            ||RPAD(NVL(r_bnft_info.medical_cvg_termination_date,' '),8,' ')--Field40 291	298	N (8)	Termination Date
                                                            ||RPAD(NVL(r_bnft_info.class_code,' '),3,' ')      --Field41 299	301	A (3)	Class Code
                                                            ||RPAD(NVL(r_bnft_info.coverage_level_code,' '),1,' ')  --Field42 302	302	N (1)	Coverage Type*/
                                                            -----Coverage2
                                                            ||RPAD(' ',1,' ')--Field37 270	270	A (1)	Line Description Code
                                                            ||LPAD('0',12,'0')--Field38 271	282	N (12)	Plan/Contract Number
                                                            ||LPAD('0',8,'0') --Field39 283	290	N (8)	Effective Date	Effective date of coverage
                                                            ||LPAD('0',8,'0')--Field40 291	298	N (8)	Termination Date
                                                            ||RPAD(' ',3,' ')      --Field41 299	301	A (3)	Class Code
                                                            ||LPAD('0',1,'0')  --Field42 302	302	N (1)	Coverage Type
                                                             -----Coverage3
                                                            ||RPAD(' ',1,' ')--Field43 303	303	A (1)	Line Description Code
                                                            ||LPAD('0',12,'0')--Field44 304	315	N (12)	Plan/Contract Number
                                                            ||LPAD('0',8,'0') --Field45 316	323	N (8)	Effective Date
                                                            ||LPAD('0',8,'0')--Field46 324	331	N (8)	Termination Date
                                                            ||RPAD(' ',3,' ') --Field47 332	334	A (3)	Class Code
                                                            ||LPAD('0',1,'0')  --Field48 335	335	N (1)	Coverage Type
                                                             -----Coverage4
                                                            ||RPAD(' ',1,' ')--Field43 336	336	A (1)	Line Description Code
                                                            ||LPAD('0',12,'0')--Field44 337	348	N (12)	Plan/Contract Number
                                                            ||LPAD('0',8,'0') --Field45 349	356	N (8)	Effective Date
                                                            ||LPAD('0',8,'0')--Field46 357	364	N (8)	Termination Date
                                                            ||RPAD(' ',3,' ') --Field47 365	367	A (3)	Class Code
                                                            ||LPAD('0',1,'0')  --Field48 368	368	N (1)	Coverage Type
                                                             -----Coverage5
                                                            ||RPAD(' ',1,' ')--Field49 369	369	A (1)	Line Description Code
                                                            ||LPAD('0',12,'0')--Field50 370	381	N (12)	Plan/Contract Number
                                                            ||LPAD('0',8,'0') --Field51 382	389	N (8)	Effective Date
                                                            ||LPAD('0',8,'0')--Field52 390	397	N (8)	Termination Date
                                                            ||RPAD(' ',3,' ') --Field53 398	400	A (3)	Class Code
                                                            ||LPAD('0',1,'0')  --Field54 401	401	N (1)	Coverage Type
                                                              -----Coverage6
                                                            ||RPAD(' ',1,' ')--Field55 402	402	A (1)	Line Description Code
                                                            ||LPAD('0',12,'0')--Field56 403	414	N (12)	Plan/Contract Number
                                                            ||LPAD('0',8,'0') --Field57 415	422	N (8)	Effective Date
                                                            ||LPAD('0',8,'0')--Field58 423	430	N (8)	Termination Date
                                                            ||RPAD(' ',3,' ') --Field59 431	433	A (3)	Class Code
                                                            ||LPAD('0',1,'0') --Field60 434 434	N (1)	Coverage Type
                                                           -----------------End of Coverage6------------------
                                                            ||RPAD(' ',10,' ')--Field61 435	444	A (10)	PCP/PCC Number
                                                            ||RPAD(' ',1,' ')--Field62 445	445	A (1)	Medicare Indicator
                                                            ||LPAD('0',8,'0')--Field63 446	453	N (8)	Medicare Effective Date
                                                            ||LPAD('0',6,'0')--Field64 454	459	N (6)	Reserved	Reserved. Default Spaces.
                                                            ||LPAD('0',8,'0')--Field65 460	467	N (8)	Disability Eligibility Date
                                                            ||RPAD(' ',1,' ')--Field66 468	468	A (1)	Totally Disabled Indicator
                                                            ||RPAD(' ',1,' ')--Field67 469	469	A (1)	Reserved	Reserved. Default Spaces.
                                                            ||RPAD(' ',1,' ')--Field68 470	470	A (1)	Filler	Reserved. Default Spaces.
                                                            ||LPAD('0',8,'0')--Field69 471	478	N (8)	PCP/PCC Effective Date
                                                            ||RPAD(' ',4,' ')-- Field70 479	482	A (4)	Filler	Reserved Default Zeroes
                                                            ||RPAD(' ',2,' ')--Field71 483	484	A (2)	Termination Reason Code
                                                            ||RPAD(' ',1,' ')--Field72 485	485	A (1)	Late Enrollee Code
                                                            ||LPAD('0',2,'0')--Field73 486	487	N (2)	Creditable Coverage Months
                                                            ||LPAD('0',8,'0')--Field74 488	495	N (8)	Waiting Period Begin
                                                            ||LPAD('0',8,'0')--Field75 496	503	N (8)	Pre-existing Met Date
                                                            ||RPAD(' ',9,' ')--Field76 504	512	A (9)	Old SSN
                                                            ||RPAD(' ',10,' ')--Field77 513	522	A (10)	Telephone Number 1
                                                            ||RPAD(' ',2,' ')--Field78 523	524	A (2)	Filler
                                                            ||LPAD('0',2,'0')--Field79 525	526	N (2)	Filler
                                                            ||LPAD('0',2,'0')--Field80 527	528	N (2)	Highest Cost Group Number
                                                            ||RPAD(' ',8,' ')--Field81  529	536	A (8)	Retirement Date
                                                           -- ||RPAD(' ',15,' ')--Field82  537	551	A (15)	Customer Rptg Field 1--1,2 CHANGES  employee_id
                                                            ||RPAD(NVL(r_bnft_info.employee_id,' '),15,' ')--Field82  537	551	A (15)	Customer Rptg Field 1.1
                                                            ||RPAD(' ',15,' ')--Field83  552	566	A (15)	Customer Rptg Field 2
                                                            ||RPAD(' ',15,' ')--Field84 567	581	A (15)	Customer Rptg Field 3
                                                            ||RPAD(' ',15,' ')--Field85 582	596	A (15)	Customer Rptg Field 4
                                                            ||RPAD(' ',15,' ')--Field86 597	611	A (15)	Customer Rptg Field 5
                                                            ||RPAD(' ',15,' ')--Field87 612	626	A (15)	Customer Rptg Field 6
                                                            ||RPAD(' ',15,' ')--Field88 627	641	A (15)	Customer Rptg Field 7
                                                            --------------------
                                                            ||RPAD(' ',12,' ')--Field89 642	653	A (12)	Medicare ID Number
                                                            ||LPAD('0',8,'0')--Field90 654	661	N (8)	Effective Change Date
                                                            --Coordination of Benefits Information
                                                             ||RPAD(' ',1,' ')--Field91 662	662	A (1)	COB Line Code
                                                             ||RPAD(' ',1,' ')--Field92 663	663	A (1)	COB Indicator
                                                             ||RPAD(' ',1,' ')--Field93 664	664	A (1)	COB Level
                                                             ||RPAD(' ',20,' ')--Field93 665 684	A (20)	COB Carrier Name
                                                             ||LPAD('0',8,'0')--Field94 685	692	N (8)	COB Effective Date
                                                             ||LPAD('0',8,'0')--Field95 693	700	N (8)	COB Termination Date
                                                             ----------------------
                                                             ||LPAD('0',3,'0')--Field96 701 703	A/N (3)	Group ID Code
                                                             ||LPAD('0',9,'0')--Field97 704	712	N (9)	Member ID Number
                                                             ||LPAD('0',3,' ')--Field98 713	715	N (3)	Filler	Reserved. Default Spaces
                                                             ||RPAD(' ',1,' ')--Field99 716	716	A (1)	HRA Debit Card Indicator
                                                             ||LPAD('0',8,'0')--Field100 717	724	N (8)	Debit Card Date
                                                             ||RPAD(' ',1,' ')--Field101 725	725	A (1)	Subsidy Eligible Indicator
                                                             ||LPAD('0',8,'0')--Field102 726	733	N (8)	Subsidy Eligibility Date
                                                             ||RPAD(' ',1,' ')--Field103 734	734	A (1)	PCP New Patient Code
                                                             ||RPAD(' ',1,' ')--Field104 735	735	A (1)	Other Dependent Status Indicator
                                                             ||RPAD(' ',1,' ')--Field105 736	736	A (1)	Filler
                                                             ||RPAD(' ',4,' ')--Field106 737	740	A (4)	Health Care System
                                                             ||RPAD(' ',60,' ')--Field107 741	800	A (60)	Email Address
                                                             --800---------------------------
                                                             ||LPAD('0',2,'0')--Field108 801	802	N (2)	Alt Seq #
                                                             ||LPAD('0',8,'0')--Field109 803	810	N (8)	Health Coverage Begin Date
                                                             ||LPAD('0',8,'0')--Field110 811	818	N (8)	Dental Coverage Begin Date
                                                             ||LPAD('0',8,'0')--Field111 819	826	N (8)	Vision Coverage Begin Date
                                                             ||RPAD(' ',3,' ')--Field112 827	829	A (3)	Primary Language Code
                                                             ||LPAD('0',8,'0')--Field113 830	837	N (8)	Customer Reporting Field Effective Date
                                                             ||LPAD('0',30,'0')--Field114 838	867	N (30)	Filler
                                                             ||RPAD(' ',7,' ')--Field115 868	874	A (7)	FSA Employee Health Care Annual Amount
                                                             ||LPAD('0',8,'0')--Field116 875	882	N (8)	FSA Health Care Effective Date
                                                             ||LPAD('0',8,'0')--Field117 883	890	N (8)	FSA Health Care Termination Date

                                                            ||RPAD(' ',15,' ')--Field118 891	905	A (15)	User Field 1	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field119 906	920	A (15)	User Field 2	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field120 921	935	A (15)	User Field 3	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field121 936	950	A (15)	User Field 4	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field122 951	965	A (15)	User Field 5	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field123 966	980	A (15)	User Field 6	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field124 981	995	A (15)	User Field 7	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field125 996	1010A (15)	User Field 8	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field126 1011	1025A (15)	User Field 9	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field127 1026	1040A (15)	User Field 10	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field128 1041	1055A (15)	User Field 11	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field129 1056	1070A (15)	User Field 12	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field130 1071	1085A (15)	User Field 13	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field131 1086	1100A (15)	User Field 14	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field132 1101	1115A (15)	User Field 15	Default Spaces

                                                             ||RPAD(' ',15,' ')--Field133 1116	1130	A (15)	User Field 16	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field133 1131	1145	A (15)	User Field 17	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field134 1146	1160	A (15)	User Field 18	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field135 1161	1175	A (15)	User Field 19	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field136 1176	1190	A (15)	User Field 20	Default Spaces
                                                             ||RPAD(' ',1,' ')--Field137 1191	1191	A (1)	Group Number Change
                                                             ||RPAD(' ',9,' ')--Field138 1192	1200	A (9)	Originating SSN
                                                             ||RPAD(' ',1,' ')--Field139 1201	1201	A (1)	HSA
                                                             ||RPAD(' ',35,' ')--Field140 1202	1236	A (35)	User Field 21
                                                             ||RPAD(' ',10,' ')--Field141 1237	1246	A (10)	Telephone Number 2
                                                             ||RPAD(' ',30,' ')--Field142 1247	1276	A (30)	Other ID
                                                             ||RPAD(' ',8,' ')--Field143 1277	1284	A(8)	Date of Death	Format: YYYYMMDD
                                                             ||RPAD(' ',216,' ')--Field144 1285	1500	A (215)	Filler	Reserved Default Spaces

                                     );
                                   v_text2 :=  ('BEK0035 ')                      --Field1:	8	A (8)	Record Control Data	Valid Value:  BEK0035
                                                            ||RPAD(' ', 3,' ')                             --Field2:9	11	A (3)	Filler	Reserved - default spaces
                                                            ||RPAD(r_bnft_info.Member_Rel_Code,1,' ')                 --Field3:12	12	A (1)	Member Code	Identifies member
                                                            ||LPAD('0',2,'0')                               --Field4:13	14	N (2)	Member Sequence Number	Represents a unique identifier for the dependent
                                                            ||RPAD(NVL(r_bnft_info.enrollee_ssn,' '),9,' ')                    --Field5:15	23	A (9)	Participant SSN	Participant Social Security Number
                                                            ||RPAD(NVL(r_bnft_info.member_last_name,' '),20,' ')     --Field6-24	43	A (20)	Last Name	Last Name
                                                            ||RPAD(NVL(r_bnft_info.member_first_name,' '),14,' ')    --Field7 44	57	A (14)	First Name	First Name
                                                            ||RPAD(' ',1,' ')                               --Field8 58	58	A (1)	Middle Initial	Middle Initial default spaces
                                                            ||RPAD(' ',3,' ')                               --Field9 59	61	A (3)	Name Qualifier	Valid Values: SR, JR, II, III, IV, MD ? default spaces
                                                            ||RPAD(NVL(r_bnft_info.Residence_Address1,' '),35,' ')   --Field10 --62	96	A (35)	Street Address	Participant only, Dependent only when different
                                                            ||RPAD(NVL(r_bnft_info.Residence_Address2,' '),35,' ')     --Field11 97	131	A (35)	Street Address	Participant only, Dependent only when different ? Default Spaces
                                                            ||RPAD(NVL(r_bnft_info.Residence_City_Name,' '),20,' ')  --Field12 132	151	A (20)	City	Participant only, Dependent only when different
                                                            ||RPAD(NVL(r_bnft_info.Residence_State_Code,' '),2,' ')  --Field13 152	153	A (2)	State	State Code Abbreviation ? Participant only, Dependent only when different
                                                            ||RPAD(NVL(r_bnft_info.country,' '),2,' ')               --Field14 154	155	A (2)	Country	Foreign countries only ? Participant only, Dependent only when different.  Default Spaces
                                                            ||RPAD(' ',8,' ')                               --Field15 156	163	A(8)	Filler	Reserved. Default Spaces.
                                                            ||RPAD(NVL(r_bnft_info.zip_code,' '),9,' ')             --Field16--164	172	A (9)	Zip Code	Participant only, Dependent only when different
                                                            ||RPAD(NVL(r_bnft_info.member_birth_date,' '),8,' ')               --Field17 173	180	N (8)	Date of Birth	Participant birth
                                                            ||RPAD(NVL(r_bnft_info.member_gender_code,' '),1,' ')              --Field18 181	181	A (1)	Gender
                                                            ||RPAD(NVL(r_bnft_info.marital_status,' '),1,' ')                  --Field19 182	182	A (1)	Individual Relationship Code neel
                                                            ||('76414872')                                  --Field20 183	190	N (8)	Group Number
                                                            ||'001'                                         --Field21 191	193	A (3)	Participant Location
                                                            ||RPAD(NVL(r_bnft_info.Work_Status_Code,' '),1,' ')           --Field22 194	194	A (1)	Work Status
                                                            ||RPAD(NVL(r_bnft_info.Residence_State_Code,' '),2,' ')         --Field23 195	196	A (2)	Work State
                                                            --||LPAD(' ',8,' ')                  --Field24 197	204	N (8)	Original Hire Date--changes 1.1
                                                            ||RPAD(NVL(r_bnft_info.enrollee_hire_date,' '),8,' ')
                                                            ||LPAD('0',8,'0') --Field25 205	212	N (8)	Dependent Current Status Date
                                                            ||LPAD('0',9,'0') --Field26 213	221	N (9)	Salary
                                                            ||RPAD(' ',1,' ') --Field27 222	222	A (1)	Salary Period
                                                            ||LPAD('0',1,'0') --Field28 223	223	N (1)	Reserved
                                                            ||RPAD(NVL(r_bnft_info.enrollee_ssn,' '),9,' ')     --Field29 224	232	A (9)	Dependent SSN
                                                            ||RPAD(' ',4,' ') --Field30   --233	236	A (4)	Filler	Reserved Default Spaces
                                                            ---Coverage1
                                                            ||RPAD(NVL('H',' '),1,' ')--Field31 237	237	A (1)	Line Description Code
                                                            ||('767000414872')--Field32 238	249	N (12)	Plan/Contract Number
                                                            ||LPAD(NVL(r_bnft_info.medical_cvg_effective_date,'0'),8,'0') --Field33 250	257	N (8)	Effective Date	Effective date of coverage
                                                            ||LPAD(NVL(r_bnft_info.medical_cvg_termination_date,'0'),8,'0')--Field34 258	265	N (8)	Termination Date
                                                            ||RPAD(NVL(r_bnft_info.class_code,' '),3,' ')      --Field35 266	268	A (3)	Class Code
                                                            ||LPAD(NVL(r_bnft_info.coverage_level_code,'0'),1,'0')  --Field36 269	269	N (1)	Coverage Type
                                                            -----Coverage2
                                                           /*  ||RPAD(NVL('H',' '),1,' ')--Field37 270	270	A (1)	Line Description Code
                                                            ||('767000414872')--Field38 271	282	N (12)	Plan/Contract Number
                                                            ||RPAD(NVL(r_bnft_info.medical_cvg_effective_date,' '),8,' ') --Field39 283	290	N (8)	Effective Date	Effective date of coverage
                                                            ||RPAD(NVL(r_bnft_info.medical_cvg_termination_date,' '),8,' ')--Field40 291	298	N (8)	Termination Date
                                                            ||RPAD(NVL(r_bnft_info.class_code,' '),3,' ')      --Field41 299	301	A (3)	Class Code
                                                            ||RPAD(NVL(r_bnft_info.coverage_level_code,' '),1,' ')  --Field42 302	302	N (1)	Coverage Type*/
                                                            -----Coverage2
                                                            ||RPAD(' ',1,' ')--Field37 270	270	A (1)	Line Description Code
                                                            ||LPAD('0',12,'0')--Field38 271	282	N (12)	Plan/Contract Number
                                                            ||LPAD('0',8,'0') --Field39 283	290	N (8)	Effective Date	Effective date of coverage
                                                            ||LPAD('0',8,'0')--Field40 291	298	N (8)	Termination Date
                                                            ||RPAD(' ',3,' ')      --Field41 299	301	A (3)	Class Code
                                                            ||LPAD('0',1,'0')  --Field42 302	302	N (1)	Coverage Type
                                                             -----Coverage3
                                                            ||RPAD(' ',1,' ')--Field43 303	303	A (1)	Line Description Code
                                                            ||LPAD('0',12,'0')--Field44 304	315	N (12)	Plan/Contract Number
                                                            ||LPAD('0',8,'0') --Field45 316	323	N (8)	Effective Date
                                                            ||LPAD('0',8,'0')--Field46 324	331	N (8)	Termination Date
                                                            ||RPAD(' ',3,' ') --Field47 332	334	A (3)	Class Code
                                                            ||LPAD('0',1,'0')  --Field48 335	335	N (1)	Coverage Type
                                                             -----Coverage4
                                                            ||RPAD(' ',1,' ')--Field43 336	336	A (1)	Line Description Code
                                                            ||LPAD('0',12,'0')--Field44 337	348	N (12)	Plan/Contract Number
                                                            ||LPAD('0',8,'0') --Field45 349	356	N (8)	Effective Date
                                                            ||LPAD('0',8,'0')--Field46 357	364	N (8)	Termination Date
                                                            ||RPAD(' ',3,' ') --Field47 365	367	A (3)	Class Code
                                                            ||LPAD('0',1,'0')  --Field48 368	368	N (1)	Coverage Type
                                                             -----Coverage5
                                                            ||RPAD(' ',1,' ')--Field49 369	369	A (1)	Line Description Code
                                                            ||LPAD('0',12,'0')--Field50 370	381	N (12)	Plan/Contract Number
                                                            ||LPAD('0',8,'0') --Field51 382	389	N (8)	Effective Date
                                                            ||LPAD('0',8,'0')--Field52 390	397	N (8)	Termination Date
                                                            ||RPAD(' ',3,' ') --Field53 398	400	A (3)	Class Code
                                                            ||LPAD('0',1,'0')  --Field54 401	401	N (1)	Coverage Type
                                                              -----Coverage6
                                                            ||RPAD(' ',1,' ')--Field55 402	402	A (1)	Line Description Code
                                                            ||LPAD('0',12,'0')--Field56 403	414	N (12)	Plan/Contract Number
                                                            ||LPAD('0',8,'0') --Field57 415	422	N (8)	Effective Date
                                                            ||LPAD('0',8,'0')--Field58 423	430	N (8)	Termination Date
                                                            ||RPAD(' ',3,' ') --Field59 431	433	A (3)	Class Code
                                                            ||LPAD('0',1,'0') --Field60 434 434	N (1)	Coverage Type
                                                           -----------------End of Coverage6------------------
                                                            ||RPAD(' ',10,' ')--Field61 435	444	A (10)	PCP/PCC Number
                                                            ||RPAD(' ',1,' ')--Field62 445	445	A (1)	Medicare Indicator
                                                            ||LPAD('0',8,'0')--Field63 446	453	N (8)	Medicare Effective Date
                                                            ||LPAD('0',6,'0')--Field64 454	459	N (6)	Reserved	Reserved. Default Spaces.
                                                            ||LPAD('0',8,'0')--Field65 460	467	N (8)	Disability Eligibility Date
                                                            ||RPAD(' ',1,' ')--Field66 468	468	A (1)	Totally Disabled Indicator
                                                            ||RPAD(' ',1,' ')--Field67 469	469	A (1)	Reserved	Reserved. Default Spaces.
                                                            ||RPAD(' ',1,' ')--Field68 470	470	A (1)	Filler	Reserved. Default Spaces.
                                                            ||LPAD('0',8,'0')--Field69 471	478	N (8)	PCP/PCC Effective Date
                                                            ||RPAD(' ',4,' ')-- Field70 479	482	A (4)	Filler	Reserved Default Zeroes
                                                            ||RPAD(' ',2,' ')--Field71 483	484	A (2)	Termination Reason Code
                                                            ||RPAD(' ',1,' ')--Field72 485	485	A (1)	Late Enrollee Code
                                                            ||LPAD('0',2,'0')--Field73 486	487	N (2)	Creditable Coverage Months
                                                            ||LPAD('0',8,'0')--Field74 488	495	N (8)	Waiting Period Begin
                                                            ||LPAD('0',8,'0')--Field75 496	503	N (8)	Pre-existing Met Date
                                                            ||RPAD(' ',9,' ')--Field76 504	512	A (9)	Old SSN
                                                            ||RPAD(' ',10,' ')--Field77 513	522	A (10)	Telephone Number 1
                                                            ||RPAD(' ',2,' ')--Field78 523	524	A (2)	Filler
                                                            ||LPAD('0',2,'0')--Field79 525	526	N (2)	Filler
                                                            ||LPAD('0',2,'0')--Field80 527	528	N (2)	Highest Cost Group Number
                                                            ||RPAD(' ',8,' ')--Field81  529	536	A (8)	Retirement Date
                                                           -- ||RPAD(' ',15,' ')--Field82  537	551	A (15)	Customer Rptg Field 1--1,2 CHANGES  employee_id
                                                            ||RPAD(NVL(r_bnft_info.employee_id,' '),15,' ')--Field82  537	551	A (15)	Customer Rptg Field 1.1
                                                            ||RPAD(' ',15,' ')--Field83  552	566	A (15)	Customer Rptg Field 2
                                                            ||RPAD(' ',15,' ')--Field84 567	581	A (15)	Customer Rptg Field 3
                                                            ||RPAD(' ',15,' ')--Field85 582	596	A (15)	Customer Rptg Field 4
                                                            ||RPAD(' ',15,' ')--Field86 597	611	A (15)	Customer Rptg Field 5
                                                            ||RPAD(' ',15,' ')--Field87 612	626	A (15)	Customer Rptg Field 6
                                                            ||RPAD(' ',15,' ')--Field88 627	641	A (15)	Customer Rptg Field 7
                                                            --------------------
                                                            ||RPAD(' ',12,' ')--Field89 642	653	A (12)	Medicare ID Number
                                                            ||LPAD('0',8,'0')--Field90 654	661	N (8)	Effective Change Date
                                                            --Coordination of Benefits Information
                                                             ||RPAD(' ',1,' ')--Field91 662	662	A (1)	COB Line Code
                                                             ||RPAD(' ',1,' ')--Field92 663	663	A (1)	COB Indicator
                                                             ||RPAD(' ',1,' ')--Field93 664	664	A (1)	COB Level
                                                             ||RPAD(' ',20,' ')--Field93 665 684	A (20)	COB Carrier Name
                                                             ||LPAD('0',8,'0')--Field94 685	692	N (8)	COB Effective Date
                                                             ||LPAD('0',8,'0')--Field95 693	700	N (8)	COB Termination Date
                                                             ----------------------
                                                             ||LPAD('0',3,'0')--Field96 701 703	A/N (3)	Group ID Code
                                                             ||LPAD('0',9,'0')--Field97 704	712	N (9)	Member ID Number
                                                             ||LPAD('0',3,' ')--Field98 713	715	N (3)	Filler	Reserved. Default Spaces
                                                             ||RPAD(' ',1,' ')--Field99 716	716	A (1)	HRA Debit Card Indicator
                                                             ||LPAD('0',8,'0')--Field100 717	724	N (8)	Debit Card Date
                                                             ||RPAD(' ',1,' ')--Field101 725	725	A (1)	Subsidy Eligible Indicator
                                                             ||LPAD('0',8,'0')--Field102 726	733	N (8)	Subsidy Eligibility Date
                                                             ||RPAD(' ',1,' ')--Field103 734	734	A (1)	PCP New Patient Code
                                                             ||RPAD(' ',1,' ')--Field104 735	735	A (1)	Other Dependent Status Indicator
                                                             ||RPAD(' ',1,' ')--Field105 736	736	A (1)	Filler
                                                             ||RPAD(' ',4,' ')--Field106 737	740	A (4)	Health Care System
                                                             ||RPAD(' ',60,' ')--Field107 741	800	A (60)	Email Address
                                                             --800---------------------------
                                                             ||LPAD('0',2,'0')--Field108 801	802	N (2)	Alt Seq #
                                                             ||LPAD('0',8,'0')--Field109 803	810	N (8)	Health Coverage Begin Date
                                                             ||LPAD('0',8,'0')--Field110 811	818	N (8)	Dental Coverage Begin Date
                                                             ||LPAD('0',8,'0')--Field111 819	826	N (8)	Vision Coverage Begin Date
                                                             ||RPAD(' ',3,' ')--Field112 827	829	A (3)	Primary Language Code
                                                             ||LPAD('0',8,'0')--Field113 830	837	N (8)	Customer Reporting Field Effective Date
                                                             ||LPAD('0',30,'0')--Field114 838	867	N (30)	Filler
                                                             ||RPAD(' ',7,' ')--Field115 868	874	A (7)	FSA Employee Health Care Annual Amount
                                                             ||LPAD('0',8,'0')--Field116 875	882	N (8)	FSA Health Care Effective Date
                                                             ||LPAD('0',8,'0')--Field117 883	890	N (8)	FSA Health Care Termination Date

                                                            ||RPAD(' ',15,' ')--Field118 891	905	A (15)	User Field 1	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field119 906	920	A (15)	User Field 2	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field120 921	935	A (15)	User Field 3	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field121 936	950	A (15)	User Field 4	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field122 951	965	A (15)	User Field 5	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field123 966	980	A (15)	User Field 6	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field124 981	995	A (15)	User Field 7	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field125 996	1010A (15)	User Field 8	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field126 1011	1025A (15)	User Field 9	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field127 1026	1040A (15)	User Field 10	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field128 1041	1055A (15)	User Field 11	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field129 1056	1070A (15)	User Field 12	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field130 1071	1085A (15)	User Field 13	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field131 1086	1100A (15)	User Field 14	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field132 1101	1115A (15)	User Field 15	Default Spaces

                                                             ||RPAD(' ',15,' ')--Field133 1116	1130	A (15)	User Field 16	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field133 1131	1145	A (15)	User Field 17	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field134 1146	1160	A (15)	User Field 18	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field135 1161	1175	A (15)	User Field 19	Default Spaces
                                                             ||RPAD(' ',15,' ')--Field136 1176	1190	A (15)	User Field 20	Default Spaces
                                                             ||RPAD(' ',1,' ')--Field137 1191	1191	A (1)	Group Number Change
                                                             ||RPAD(' ',9,' ')--Field138 1192	1200	A (9)	Originating SSN
                                                             ||RPAD(' ',1,' ')--Field139 1201	1201	A (1)	HSA
                                                             ||RPAD(' ',35,' ')--Field140 1202	1236	A (35)	User Field 21
                                                             ||RPAD(' ',10,' ')--Field141 1237	1246	A (10)	Telephone Number 2
                                                             ||RPAD(' ',30,' ')--Field142 1247	1276	A (30)	Other ID
                                                             ||RPAD(' ',8,' ')--Field143 1277	1284	A(8)	Date of Death	Format: YYYYMMDD
                                                             ||RPAD(' ',216,' ')--Field144 1285	1500	A (215)	Filler	Reserved Default Spaces



                                    ;
                                   fnd_file.put_line (fnd_file.output, v_text2);
                    n := n+1;
        END LOOP;

END LOOP;
        dbms_output.put_line('..After Cursor cur_vendor');

        BEGIN
v_text :=RPAD('T',1,' ')
        ||LPAD(n,7,'0')
        ||RPAD(' ',1492,' ');

         UTL_FILE.put_line (v_emp_file, v_text);
        fnd_file.put_line (fnd_file.output, v_text);
    END;

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

END main_proc;

END ttec_us_umr_intf_pkg;
/
show errors;
/
