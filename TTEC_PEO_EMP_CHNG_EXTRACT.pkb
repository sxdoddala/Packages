create or replace PACKAGE BODY      TTEC_PEO_EMP_CHNG_EXTRACT
/********************************************************************************
    PROGRAM NAME:   TTEC_PEO_EMP_CHNG_EXTRACT
    DESCRIPTION:    This package extracts PEO Employee Changed and Terminated
    INPUT      :    Change Date, Terminate Date
    OUTPUT     :   NA
    CREATED BY:     Elango Pandurangan
    DATE:           10-NOV-2013
    CALLING FROM   :  Teletech PEO Employee Change Extract
    ----------------
    MODIFICATION LOG
    ----------------
    DEVELOPER             DATE            DESCRIPTION
    -------------------   ------------  -----------------------------------------
    Nimai Meher		  10-Nov-2013	  Initial Version
    Nimai Meher		  22-Nov-2013	  Indentation and reserved words in upper case
    Nimai Meher		  25-Nov-2013 	Include Termination
    Priyanka A	    02-Dec-2013	  Change in supervisor not coming in o/p is fixed. Reported by Jamie on 28th Nov.
    Nimai Meher     02-Dec-2013   Modified File Naming Convention from TELETECH_YYYYMONDDHH24MISS to TELETECH_YYYYMMDDHH24MISS
	MXKEERTHI(ARGANO)  17-JUN-2023   R12.2 Upgrade Remediation
********************************************************************************/
AS
PROCEDURE main(
    errbuf OUT NOCOPY  VARCHAR2,
    retcode OUT NOCOPY VARCHAR2,
    p_date IN VARCHAR2,
    p_term_date in varchar2)
AS
  v_dt_time VARCHAR2(100);
  --v_path varchar2(300):='$CUST_TOP/data/dac_data/data_in';
  --v_path varchar2(300):='/d41/applcrp1/CRP1/apps/apps_st/appl/teletech/12.0.0/data/dac_data/data_in';
  --v_path varchar2(300):='/d41/applcrp1/CRP1/apps/apps_st/comn/temp'; -- for testing only , file created in this path
  v_path        VARCHAR2(400);
  v_date        DATE;
  v_term_date        DATE;
  v_columns_str VARCHAR2(4000);
  v_header      VARCHAR2(4000);

  CURSOR peo_emp
  IS
    (SELECT DISTINCT papf.FIRST_NAME,
      papf.LAST_NAME,
      papf.MIDDLE_NAMES,
      to_char(papf.DATE_OF_BIRTH,'MM/DD/YYYY') DATE_OF_BIRTH,
      /*(select segment1
      from PER_ANALYSIS_CRITERIA , PER_PERSON_ANALYSES, FND_ID_FLEX_STRUCTURES_VL
      where PER_ANALYSIS_CRITERIA.ANALYSIS_CRITERIA_ID=PER_PERSON_ANALYSES.ANALYSIS_CRITERIA_ID
      and PER_ANALYSIS_CRITERIA.id_flex_num = FND_ID_FLEX_STRUCTURES_VL.id_flex_num
      and FND_ID_FLEX_STRUCTURES_VL.ID_FLEX_STRUCTURE_NAME like 'Teletech Contingent Worker'
      and PER_PERSON_ANALYSES.person_id = PAPF.PERSON_ID) COMPANY_ID,*/
      '1895' COMPANY_ID,              -- as per mail from Liz Grail GNA
     '26' EMPLOYER_ID, -- as per mail from Liz Grail GNA
      (SELECT DECODE (meaning,'Asian (Not Hispanic or Latino)','A','White (Not Hispanic or Latino)','I','Hispanic or Latino','H','Black or African American (Not Hispanic or Latino)','B','X')
      FROM apps.fnd_lookup_values_vl
      WHERE lookup_type     = 'US_ETHNIC_GROUP'
      AND enabled_flag      = 'Y'
      AND security_group_id = 2
      AND lookup_code       = 1 -- papf.per_information1 -- commented for testing extract
      AND rownum            = 1
      ) ETHNIC_CODE,
    papf.MARITAL_STATUS,
    nvl2(papf.USES_TOBACCO_FLAG,'Y','N') tobacco_user,
    pa.address_line1,
    pa.ADDRESS_LINE2,
    pa.POSTAL_CODE,
    pa.TOWN_OR_CITY,
    pa.REGION_2,
    (SELECT decode(phone_number,'n/a',NULL,phone_number)
    FROM per_phones
    WHERE PARENT_TABLE LIKE 'PER_ALL_PEOPLE_F'
    AND parent_id = papf.person_id
    AND rownum    = 1
    ) TELEPHONE,
    papf.REGISTERED_DISABLED_FLAG HANDICAPPED,
    CAST(NULL AS VARCHAR2(100)) BLIND,
    CAST(NULL AS VARCHAR2(100)) VIETNAM_VET,
    CAST(NULL AS VARCHAR2(100)) DISABLED_VET,
    PAPF.NATIONALITY CITIZEN,
    (DECODE (papf.sex,'M','M','F','F',NULL)) GENDER,
    (SELECT full_name
    FROM PER_CONTACT_RELATIONSHIPS ,
      apps.per_all_people_f
    WHERE PER_CONTACT_RELATIONSHIPS.contact_person_id = per_all_people_f.person_id
    AND TRUNC(sysdate) BETWEEN per_all_people_f.effective_start_date AND per_all_people_f.effective_end_date
    AND PER_CONTACT_RELATIONSHIPS.person_id                                                                    = PAPF.PERSON_ID
    AND (contact_type                                                                                          = 'EMRG'
    OR contact_type                                                                                            = 'S')
    AND apps.hr_person_type_usage_info.get_user_person_type ( sysdate ,PER_CONTACT_RELATIONSHIPS.CONTACT_PERSON_ID) = 'Emergency Contact'
    AND rownum                                                                                                 = 1
    ) EMERGENCY_CONTACT,
    (SELECT PER_PHONES.phone_number
    FROM PER_CONTACT_RELATIONSHIPS ,
      PER_PHONES
    WHERE PER_CONTACT_RELATIONSHIPS.person_id = PAPF.PERSON_ID
      --and contact_type = 'EMRG'
    AND PER_PHONES.PARENT_ID = PER_CONTACT_RELATIONSHIPS.CONTACT_PERSON_ID
    AND PER_PHONES.PARENT_TABLE LIKE 'PER_ALL_PEOPLE_F'
    AND rownum = 1
    ) EMERGENCY_PHONE_NUMBER,
    (SELECT HR_LOOKUPS.MEANING
    FROM PER_CONTACT_RELATIONSHIPS ,
      HR_LOOKUPS
    WHERE PER_CONTACT_RELATIONSHIPS.person_id = papf.person_id
    AND HR_LOOKUPS.LOOKUP_CODE                = PER_CONTACT_RELATIONSHIPS.CONTACT_TYPE
    AND LOOKUP_TYPE                           = 'CONTACT'
    AND ROWNUM                                = 1
    ) EMERGENCY_RELATION,
    papf.NATIONAL_IDENTIFIER SOC_SEC_NUM,
    (SELECT decode(user_status,'Active Assignment','A','T')
    FROM per_assignment_status_types
    WHERE assignment_status_type_id = paaf.assignment_status_type_id
    AND rownum          = 1
    ) STATUS_CODE,
    decode(paaf.EMPLOYMENT_CATEGORY,'FR','F','FT','F','P') TYPE_CODE,
    (select 'REVANA'--location_code --for test data
      from hr_locations where location_id = paaf.location_id AND rownum  = 1) location_code, --as per csv file mapping
    (SELECT 'OSR' --NAME  -- for test data
      FROM PER_JOBS
      WHERE JOB_ID = paaf.JOB_ID AND business_group_id = 325 AND rownum = 1
    ) JOB_CODE, --as per csv file mapping
    to_char(papf.ORIGINAL_DATE_OF_HIRE,'MM/DD/YYYY') ORIG_HIRE,
    to_char(DECODE (papf.effective_start_date,paaf.effective_start_date,papf.effective_start_date,papf.start_date),'MM/DD/YYYY') LAST_HIRE,
    to_char( papf.ORIGINAL_DATE_OF_HIRE,'MM/DD/YYYY') PEO_START_DATE,
    --papf.effective_end_date papf_effective_end_date,
    NVL(papf.employee_number,papf.npw_number) employee_number,
    papf.WORK_TELEPHONE,--
    CAST(NULL AS VARCHAR2(100)) WORK_ext,
    pa.ADDRESS_LINE1 mail_addr1,
    pa.ADDRESS_LINE2 mail_addr2,
    pa.TOWN_OR_CITY mail_city,
    pa.region_2 mail_state,
    pa.postal_code mail_zip,
    --paaf.FREQUENCY SHIFT_CODE,
    CAST(NULL AS VARCHAR2(100)) SHIFT_CODE,
    CAST(NULL AS VARCHAR2(100)) FUTURE_USE1,
    (SELECT decode(pay_basis,'HOURLY','H','ANNUAL','S')
    FROM PER_PAY_BASES
    WHERE pay_basis_id = PAAF.pay_basis_id AND business_group_id = 325
    AND rownum         = 1
    ) PAY_METHOD,-- col 43
    to_char(PAAF.NORMAL_HOURS, 'fm99999999.0000')  EXT_PAY_RATE,
    CAST(NULL AS VARCHAR2(100)) DISCONTINUED,
    to_char(PAAF.NORMAL_HOURS, 'fm99999999.00') STD_HOURS,
    (SELECT decode(MEANING,'Single','S','Married','M')
    FROM PAY_US_EMP_FED_TAX_RULES_f,
      HR_LOOKUPS
    WHERE PAY_US_EMP_FED_TAX_RULES_f.assignment_id    = paaf.assignment_id
    AND HR_LOOKUPS.LOOKUP_TYPE                        = 'US_FIT_FILING_STATUS'
    AND PAY_US_EMP_FED_TAX_RULES_f.FILING_STATUS_CODE = HR_LOOKUPS.LOOKUP_CODE
    AND rownum                                        = 1
    ) EIS_FILING_STATUS, -- Col 47
    (SELECT decode(MEANING,'Single','S','Married','M')
    FROM PAY_US_EMP_FED_TAX_RULES_f,
      HR_LOOKUPS
    WHERE PAY_US_EMP_FED_TAX_RULES_f.assignment_id    = paaf.assignment_id
    AND HR_LOOKUPS.LOOKUP_TYPE                        = 'US_FIT_FILING_STATUS'
    AND PAY_US_EMP_FED_TAX_RULES_f.FILING_STATUS_CODE = HR_LOOKUPS.LOOKUP_CODE
    AND rownum                                        = 1
    ) FEDERAL_STATUS,
    (select WITHHOLDING_ALLOWANCES from PAY_US_EMP_FED_TAX_RULES_f
     where assignment_id = paaf.assignment_id
     AND rownum = 1
    ) FEDERAL_ALLOWS, -- col 49
    CAST(NULL AS VARCHAR2(100)) EXTRA_FEDERAL,
    (SELECT decode(MEANING,'Single','S','Married','M')
    FROM PAY_US_EMP_STATE_TAX_RULES_f,
      HR_LOOKUPS
    WHERE  PAY_US_EMP_STATE_TAX_RULES_f.assignment_id    = paaf.assignment_id
     and HR_LOOKUPS.LOOKUP_TYPE                        = 'US_FIT_FILING_STATUS'
    AND PAY_US_EMP_STATE_TAX_RULES_f.FILING_STATUS_CODE = HR_LOOKUPS.LOOKUP_CODE
    AND rownum = 1) HOME_STATE_STATUS,
    (select WITHHOLDING_ALLOWANCES from PAY_US_EMP_STATE_TAX_RULES_f
     where assignment_id =  paaf.assignment_id AND rownum = 1) HOME_STATE_ALLOWS,
    CAST(NULL AS VARCHAR2(100)) HOME_STATE_ADDITIONAL_AMOUNT,
    CAST(NULL AS VARCHAR2(100)) WORK_STATE_STATUS,
    CAST(NULL AS VARCHAR2(100)) WORK_STATE_ALLOWS,
    CAST(NULL AS VARCHAR2(100)) WORK_STATE_ADDITIONAL_AMOUNT,
    CAST(NULL AS VARCHAR2(100)) OFFICER,
    '010' DEPT_CODE,  --as per csv file mapping
    CAST(NULL AS VARCHAR2(100)) FUTURE_USE2,
    CAST(NULL AS VARCHAR2(100)) TERM_CODE,
    CAST(NULL AS VARCHAR2(100)) EMAIL_ADDRESS,
   --(SELECT payroll_name FROM PAY_ALL_PAYROLLS_F WHERE payroll_id=paaf.payroll_id ) BENEFIT_GROUP,
   '1' BENEFIT_GROUP, --as per csv file mapping
    CAST(NULL AS VARCHAR2(100)) USER_FIELD_1,
    CAST(NULL AS VARCHAR2(100)) USER_FIELD_2,
    CAST(NULL AS VARCHAR2(100)) USER_FIELD_3,
    CAST(NULL AS VARCHAR2(100)) USER_FIELD_4,
    CAST(NULL AS VARCHAR2(100)) USER_FIELD_5,
    CAST(NULL AS VARCHAR2(100)) ZIP_SUFFIX,
    (select decode(SIT_OPTIONAL_CALC_IND,
              '01','11',
              '02','12',
              '03','13',
              '04','14',
              '05','8',
              '06','10',
              '07','9',
              '08','19',
              '09','20')
      from PAY_US_EMP_STATE_TAX_RULES_f where assignment_id =paaf.assignment_id and SIT_OPTIONAL_CALC_IND is not null AND rownum = 1) ALT_CALC_HOME_STATE_CODE,
    CAST(NULL AS VARCHAR2(100)) ALT_CALC_HOME_WORK_CODE, -- COL 70
    CAST(NULL AS VARCHAR2(100)) FUTURE_USE3,
    CAST(NULL AS VARCHAR2(100)) FUTURE_USE4,
    CAST(NULL AS VARCHAR2(100)) FUTURE_USE5,
    CAST(NULL AS VARCHAR2(100)) EMPLOYEE_1099,
    CAST(NULL AS VARCHAR2(100)) FUTURE_USE6,
   (SELECT 'BW'--segment1
    FROM pay_people_groups WHERE
      people_group_id = paaf.people_group_id) PAY_GROUP,-- COL 76 -- --as per csv file mapping
    CAST(NULL AS VARCHAR2(100)) DIVISION_CODE,
    CAST(NULL AS VARCHAR2(100)) PROJECT_CODE,
    nvl2(paaf.normal_hours,'Y','N') AUTO_PAY,-- source??
    paaf.normal_hours AUTO_PAY_HOURS,
    CAST(NULL AS VARCHAR2(100)) HOME_STATE_EXEMPT_AMOUNT,
    CAST(NULL AS VARCHAR2(100)) HOME_STATE_SECONDARY_AMOUNT,
    CAST(NULL AS VARCHAR2(100)) HOME_STATE_SUPP_AMOUNT,
    CAST(NULL AS VARCHAR2(100)) HOME_STATE_EXEMPT_AMOUNT1,
    CAST(NULL AS VARCHAR2(100)) WORK_STATE_SECONDARY_ALLOWS, -- COL 85
    CAST(NULL AS VARCHAR2(100)) WS_SUPP_AMOUNT,
    (SELECT decode(pay_basis,'HOURLY','H','WEEKLY','W','BIWEEKLY','B','SEMIMONTHLY','S','MONTHLY','M','ANNUAL','Y')
    FROM PER_PAY_BASES
    WHERE pay_basis_id = PAAF.pay_basis_id
    AND rownum         = 1
    )  PAY_PERIOD, -- Changed as per attachment in email from Elango/Liz on 6th Dec 2013
    CAST(NULL AS VARCHAR2(100)) VETERAN,
    CAST(NULL AS VARCHAR2(100)) NEWLY_SEPARATED_VET,
    CAST(NULL AS VARCHAR2(100)) SERVICE_MEDAL_VET, -- COL 90
    CAST(NULL AS VARCHAR2(100)) OTHER_PROTECTED_VET,
    CAST(NULL AS VARCHAR2(100)) I9_DOCUMENT_TITLE_A,
    CAST(NULL AS VARCHAR2(100)) I9_DOCUMENT_NUMBER_A,
    CAST(NULL AS VARCHAR2(100)) I9_DOCUMENT_AUTHORITY_A,-- COL 94
    CAST(NULL AS VARCHAR2(100)) I9_EXPIRATION_DATE_A,   -- COL 95
    CAST(NULL AS VARCHAR2(100)) I9_DOCUMENT_TITLE_B,
    CAST(NULL AS VARCHAR2(100)) I9_DOCUMENT_NUMBER_B,
    CAST(NULL AS VARCHAR2(100)) I9_ISSUING_AUTHORITY_B,
    CAST(NULL AS VARCHAR2(100)) I9_EXPIRATION_DATE_B,
    CAST(NULL AS VARCHAR2(100)) ALIEN_REG_NO,
    CAST(NULL AS VARCHAR2(100)) FICA_EXEMPT,
    CAST(NULL AS VARCHAR2(100)) UNION_CODE,
    (select nvl(employee_number,npw_number) from per_all_people_f where person_id = paaf.supervisor_id and rownum = 1) SUPERVISOR_ID,
    CAST(NULL AS VARCHAR2(100)) BENE_THRU_DATE,
    CAST(NULL AS VARCHAR2(100)) SCHOOL_DISTRICT,
    CAST(NULL AS VARCHAR2(100)) AGRICULTURAL,
    CAST(NULL AS VARCHAR2(100)) HOME_PHONE_2,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_1,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_2,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_3,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_4,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_5,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_6,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_7,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_8,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_9,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_10,
    CAST(NULL AS VARCHAR2(100)) NEW_HIRE_REPORT_DATE,
    'N' MAIL_CHECK_HOME,-- COL 119
    CAST(NULL AS VARCHAR2(100)) W2_ADDRESS_ONE,
    CAST(NULL AS VARCHAR2(100)) W2_ADDRESS_TWO,
    CAST(NULL AS VARCHAR2(100)) W2_CITY,
    CAST(NULL AS VARCHAR2(100)) W2_STATE,
    CAST(NULL AS VARCHAR2(100)) W2_ZIPCODE,
    CAST(NULL AS VARCHAR2(100)) LICENSE_NUMBER,
    CAST(NULL AS VARCHAR2(100)) LICENSE_EXPIRE_DATE,
    CAST(NULL AS VARCHAR2(100)) LICENSE_STATE,
    CAST(NULL AS VARCHAR2(100)) S_CORP_PRINCIPAL,
    CAST(NULL AS VARCHAR2(100)) ELECT_PAY_STUB,
    CAST(NULL AS VARCHAR2(100)) ELEC_W2_FORM,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOBS_1,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOBS_2,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOBS_3,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOBS_4,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOBS_5, --COL 135
    CAST(NULL AS VARCHAR2(100)) ALLOC_DIVISION_1,
    CAST(NULL AS VARCHAR2(100)) ALLOC_DIVISION_2,
    CAST(NULL AS VARCHAR2(100)) ALLOC_DIVISION_3,
    CAST(NULL AS VARCHAR2(100)) ALLOC_DIVISION_4,
    CAST(NULL AS VARCHAR2(100)) ALLOC_DIVISION_5,
    CAST(NULL AS VARCHAR2(100)) ALLOC_DEPARTMENT_1,
    CAST(NULL AS VARCHAR2(100)) ALLOC_DEPARTMENT_2,
    CAST(NULL AS VARCHAR2(100)) ALLOC_DEPARTMENT_3,
    CAST(NULL AS VARCHAR2(100)) ALLOC_DEPARTMENT_4,
    CAST(NULL AS VARCHAR2(100)) ALLOC_DEPARTMENT_5,
    CAST(NULL AS VARCHAR2(100)) ALLOC_PROJECT_1,
    CAST(NULL AS VARCHAR2(100)) ALLOC_PROJECT_2,
    CAST(NULL AS VARCHAR2(100)) ALLOC_PROJECT_3,
    CAST(NULL AS VARCHAR2(100)) ALLOC_PROJECT_4,
    CAST(NULL AS VARCHAR2(100)) ALLOC_PROJECT_5,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOB_1,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOB_2,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOB_3,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOB_4,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOB_5,
    CAST(NULL AS VARCHAR2(100)) ONHRP_ONBOARDED,
    CAST(NULL AS VARCHAR2(100)) HANDBK_RCD,
    CAST(NULL AS VARCHAR2(100)) AST_REVIEW,
    CAST(NULL AS VARCHAR2(100)) NEXT_REVIEW,
    CAST(NULL AS VARCHAR2(100)) NICKNAME -- col 165
  FROM per_all_people_f papf,
    per_all_assignments_f paaf,
    per_addresses pa,
    PER_PERIODS_OF_SERVICE ppos
  WHERE
    -- nvl(papf.employee_number,papf.npw_number) in ('3160588','3160584') and
    papf.business_group_id = 325 -- /**Need to confirm from Elango **/
  AND ppos.person_id       = papf.person_id
    /*** Date conditions start***/
  AND TRUNC(v_date) BETWEEN papf.effective_start_date AND papf.effective_end_date
  AND TRUNC(v_date) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
  and trunc(v_date) <> trunc(papf.start_date) -- avoid new PEO Employee created
  /*AND (
        TRUNC(papf.creation_date) <> TRUNC(papf.last_update_date)
	OR
	TRUNC(paaf.creation_date) <> TRUNC(paaf.last_update_date) ---  added by Priyanka on 2nd dec, 2013 ---
  OR TRUNC(v_date)               = TRUNC(pa.last_update_date)-- for address update
        OR
	    (    TRUNC(v_date)               = TRUNC(pa.creation_date)
             AND TRUNC(papf.creation_date)   < TRUNC(v_date)
	    ) -- address added later
    )*/ -- To Get all PEO Employees
    -- avoid same condition with creation of new PEO employee
  AND ppos.date_start =
    (SELECT MAX (PPS1.DATE_START)
    FROM PER_PERIODS_OF_SERVICE PPS1
    WHERE PPS1.PERSON_ID = PAPF.PERSON_ID
    AND PPS1.DATE_START <= PAPF.EFFECTIVE_START_DATE
    )
  AND hr_person_type_usage_info.get_user_person_type ( TRUNC(v_date), papf.person_id ) = 'PEO Employee'
  AND (   TRUNC(v_date)                         = TRUNC(papf.last_update_date)
       OR TRUNC(v_date)                         = TRUNC(paaf.last_update_date)
       OR TRUNC(v_date)                         = TRUNC(pa.last_update_date)
       OR (     TRUNC(v_date)                   = TRUNC(pa.last_update_date)
            AND TRUNC(pa.creation_date)         = TRUNC(pa.last_update_date)
	   ) -- if new address is added later
       OR TRUNC(v_date)                         = TRUNC(ppos.last_update_date)
       )
    -- Date conditions end
  AND TRUNC(ppos.PERSON_ID)    = TRUNC(papf.PERSON_ID)
  AND paaf.person_id           = papf.person_id
  AND paaf.business_group_id   = papf.business_group_id
  AND papf.person_id           = pa.person_id (+) -- outer join if no address is defined for employee
  AND NVL(pa.PRIMARY_FLAG,'Y') = 'Y'
    --and trunc(pa.date_from) between trunc(papf.effective_start_date) and trunc(papf.effective_end_date)-- employee rehired will have different effective_start_date than date_start
  AND TRUNC(NVL(pa.date_from,v_date)) BETWEEN
    (SELECT TRUNC(MIN(effective_start_date))
    FROM per_all_people_f
    WHERE person_id = papf.person_id
    )
  AND TRUNC(papf.effective_end_date)
    )
  MINUS
    ( SELECT * FROM CUST.XXTTEC_PEO_EMP_CHNG
    );

CURSOR peo_emp_term
  IS
 SELECT DISTINCT papf.FIRST_NAME,
      papf.LAST_NAME,
      papf.MIDDLE_NAMES,
      to_char(papf.DATE_OF_BIRTH,'MM/DD/YYYY') DATE_OF_BIRTH,
      /*(select segment1
      from PER_ANALYSIS_CRITERIA , PER_PERSON_ANALYSES, FND_ID_FLEX_STRUCTURES_VL
      where PER_ANALYSIS_CRITERIA.ANALYSIS_CRITERIA_ID=PER_PERSON_ANALYSES.ANALYSIS_CRITERIA_ID
      and PER_ANALYSIS_CRITERIA.id_flex_num = FND_ID_FLEX_STRUCTURES_VL.id_flex_num
      and FND_ID_FLEX_STRUCTURES_VL.ID_FLEX_STRUCTURE_NAME like 'Teletech Contingent Worker'
      and PER_PERSON_ANALYSES.person_id = PAPF.PERSON_ID) COMPANY_ID,*/
      '1895' COMPANY_ID,              -- as per mail from Liz Grail GNA
     '26' EMPLOYER_ID, -- as per mail from Liz Grail GNA
      (SELECT DECODE (meaning,'Asian (Not Hispanic or Latino)','A','White (Not Hispanic or Latino)','I','Hispanic or Latino','H','Black or African American (Not Hispanic or Latino)','B','X')
      FROM apps.fnd_lookup_values_vl
      WHERE lookup_type     = 'US_ETHNIC_GROUP'
      AND enabled_flag      = 'Y'
      AND security_group_id = 2
      AND lookup_code       = 1 -- papf.per_information1 -- commented for testing extract
      AND rownum            = 1
      ) ETHNIC_CODE,
    papf.MARITAL_STATUS,
    nvl2(papf.USES_TOBACCO_FLAG,'Y','N') tobacco_user,
    pa.address_line1,
    pa.ADDRESS_LINE2,
    pa.POSTAL_CODE,
    pa.TOWN_OR_CITY,
    pa.REGION_2,
    (SELECT decode(phone_number,'n/a',NULL,phone_number)
    FROM per_phones
    WHERE PARENT_TABLE LIKE 'PER_ALL_PEOPLE_F'
    AND parent_id = papf.person_id
    AND rownum    = 1
    ) TELEPHONE,
    papf.REGISTERED_DISABLED_FLAG HANDICAPPED,
    CAST(NULL AS VARCHAR2(100)) BLIND,
    CAST(NULL AS VARCHAR2(100)) VIETNAM_VET,
    CAST(NULL AS VARCHAR2(100)) DISABLED_VET,
    PAPF.NATIONALITY CITIZEN,
    (DECODE (papf.sex,'M','M','F','F',NULL)) GENDER,
    (SELECT full_name
    FROM PER_CONTACT_RELATIONSHIPS ,
      apps.per_all_people_f
    WHERE PER_CONTACT_RELATIONSHIPS.contact_person_id = per_all_people_f.person_id
    AND TRUNC(sysdate) BETWEEN per_all_people_f.effective_start_date AND per_all_people_f.effective_end_date
    AND PER_CONTACT_RELATIONSHIPS.person_id                                                                    = PAPF.PERSON_ID
    AND (contact_type                                                                                          = 'EMRG'
    OR contact_type                                                                                            = 'S')
    AND apps.hr_person_type_usage_info.get_user_person_type ( sysdate ,PER_CONTACT_RELATIONSHIPS.CONTACT_PERSON_ID) = 'Emergency Contact'
    AND rownum                                                                                                 = 1
    ) EMERGENCY_CONTACT,
    (SELECT PER_PHONES.phone_number
    FROM PER_CONTACT_RELATIONSHIPS ,
      PER_PHONES
    WHERE PER_CONTACT_RELATIONSHIPS.person_id = PAPF.PERSON_ID
      --and contact_type = 'EMRG'
    AND PER_PHONES.PARENT_ID = PER_CONTACT_RELATIONSHIPS.CONTACT_PERSON_ID
    AND PER_PHONES.PARENT_TABLE LIKE 'PER_ALL_PEOPLE_F'
    AND rownum = 1
    ) EMERGENCY_PHONE_NUMBER,
    (SELECT HR_LOOKUPS.MEANING
    FROM PER_CONTACT_RELATIONSHIPS ,
      HR_LOOKUPS
    WHERE PER_CONTACT_RELATIONSHIPS.person_id = papf.person_id
    AND HR_LOOKUPS.LOOKUP_CODE                = PER_CONTACT_RELATIONSHIPS.CONTACT_TYPE
    AND LOOKUP_TYPE                           = 'CONTACT'
    AND ROWNUM                                = 1
    ) EMERGENCY_RELATION,
    papf.NATIONAL_IDENTIFIER SOC_SEC_NUM,
    (SELECT decode(user_status,'Active Assignment','A','T')
    FROM per_assignment_status_types
    WHERE assignment_status_type_id = paaf.assignment_status_type_id
    AND rownum          = 1
    ) STATUS_CODE,
    decode(paaf.EMPLOYMENT_CATEGORY,'FR','F','FT','F','P') TYPE_CODE,
    (select 'REVANA'--location_code --for test data
      from hr_locations where location_id = paaf.location_id AND rownum  = 1) location_code, --as per csv file mapping
    (SELECT 'OSR' --NAME  -- for test data
      FROM PER_JOBS
      WHERE JOB_ID = paaf.JOB_ID AND business_group_id = 325 AND rownum = 1
    ) JOB_CODE, --as per csv file mapping
    to_char(papf.ORIGINAL_DATE_OF_HIRE,'MM/DD/YYYY') ORIG_HIRE,
    to_char(DECODE (papf.effective_start_date,paaf.effective_start_date,papf.effective_start_date,papf.start_date),'MM/DD/YYYY') LAST_HIRE,
    to_char( papf.ORIGINAL_DATE_OF_HIRE,'MM/DD/YYYY') PEO_START_DATE,
    --papf.effective_end_date papf_effective_end_date,
    NVL(papf.employee_number,papf.npw_number) employee_number,
    papf.WORK_TELEPHONE,--
    CAST(NULL AS VARCHAR2(100)) WORK_ext,
    pa.ADDRESS_LINE1 mail_addr1,
    pa.ADDRESS_LINE2 mail_addr2,
    pa.TOWN_OR_CITY mail_city,
    pa.region_2 mail_state,
    pa.postal_code mail_zip,
    --paaf.FREQUENCY SHIFT_CODE,
    CAST(NULL AS VARCHAR2(100)) SHIFT_CODE,
    CAST(NULL AS VARCHAR2(100)) FUTURE_USE1,
    (SELECT decode(pay_basis,'HOURLY','H','ANNUAL','S')
    FROM PER_PAY_BASES
    WHERE pay_basis_id = PAAF.pay_basis_id AND business_group_id = 325
    AND rownum         = 1
    ) PAY_METHOD,-- col 43
    to_char(PAAF.NORMAL_HOURS, 'fm99999999.0000')  EXT_PAY_RATE,
    CAST(NULL AS VARCHAR2(100)) DISCONTINUED,
    to_char(PAAF.NORMAL_HOURS, 'fm99999999.00') STD_HOURS,
    (SELECT decode(MEANING,'Single','S','Married','M')
    FROM PAY_US_EMP_FED_TAX_RULES_f,
      HR_LOOKUPS
    WHERE PAY_US_EMP_FED_TAX_RULES_f.assignment_id    = paaf.assignment_id
    AND HR_LOOKUPS.LOOKUP_TYPE                        = 'US_FIT_FILING_STATUS'
    AND PAY_US_EMP_FED_TAX_RULES_f.FILING_STATUS_CODE = HR_LOOKUPS.LOOKUP_CODE
    AND rownum                                        = 1
    ) EIS_FILING_STATUS, -- Col 47
    (SELECT decode(MEANING,'Single','S','Married','M')
    FROM PAY_US_EMP_FED_TAX_RULES_f,
      HR_LOOKUPS
    WHERE PAY_US_EMP_FED_TAX_RULES_f.assignment_id    = paaf.assignment_id
    AND HR_LOOKUPS.LOOKUP_TYPE                        = 'US_FIT_FILING_STATUS'
    AND PAY_US_EMP_FED_TAX_RULES_f.FILING_STATUS_CODE = HR_LOOKUPS.LOOKUP_CODE
    AND rownum                                        = 1
    ) FEDERAL_STATUS,
    (select WITHHOLDING_ALLOWANCES from PAY_US_EMP_FED_TAX_RULES_f
     where assignment_id = paaf.assignment_id
     AND rownum = 1
    ) FEDERAL_ALLOWS, -- col 49
    CAST(NULL AS VARCHAR2(100)) EXTRA_FEDERAL,
    (SELECT decode(MEANING,'Single','S','Married','M')
    FROM PAY_US_EMP_STATE_TAX_RULES_f,
      HR_LOOKUPS
    WHERE  PAY_US_EMP_STATE_TAX_RULES_f.assignment_id    = paaf.assignment_id
     and HR_LOOKUPS.LOOKUP_TYPE                        = 'US_FIT_FILING_STATUS'
    AND PAY_US_EMP_STATE_TAX_RULES_f.FILING_STATUS_CODE = HR_LOOKUPS.LOOKUP_CODE
    AND rownum = 1) HOME_STATE_STATUS,
    (select WITHHOLDING_ALLOWANCES from PAY_US_EMP_STATE_TAX_RULES_f
     where assignment_id =  paaf.assignment_id AND rownum = 1) HOME_STATE_ALLOWS,
    CAST(NULL AS VARCHAR2(100)) HOME_STATE_ADDITIONAL_AMOUNT,
    CAST(NULL AS VARCHAR2(100)) WORK_STATE_STATUS,
    CAST(NULL AS VARCHAR2(100)) WORK_STATE_ALLOWS,
    CAST(NULL AS VARCHAR2(100)) WORK_STATE_ADDITIONAL_AMOUNT,
    CAST(NULL AS VARCHAR2(100)) OFFICER,
    '010' DEPT_CODE,  --as per csv file mapping
    CAST(NULL AS VARCHAR2(100)) FUTURE_USE2,
    CAST(NULL AS VARCHAR2(100)) TERM_CODE,
    CAST(NULL AS VARCHAR2(100)) EMAIL_ADDRESS,
   --(SELECT payroll_name FROM PAY_ALL_PAYROLLS_F WHERE payroll_id=paaf.payroll_id ) BENEFIT_GROUP,
   '1' BENEFIT_GROUP, --as per csv file mapping
    CAST(NULL AS VARCHAR2(100)) USER_FIELD_1,
    CAST(NULL AS VARCHAR2(100)) USER_FIELD_2,
    CAST(NULL AS VARCHAR2(100)) USER_FIELD_3,
    CAST(NULL AS VARCHAR2(100)) USER_FIELD_4,
    CAST(NULL AS VARCHAR2(100)) USER_FIELD_5,
    CAST(NULL AS VARCHAR2(100)) ZIP_SUFFIX,
    (select decode(SIT_OPTIONAL_CALC_IND,
              '01','11',
              '02','12',
              '03','13',
              '04','14',
              '05','8',
              '06','10',
              '07','9',
              '08','19',
              '09','20')
      from PAY_US_EMP_STATE_TAX_RULES_f where assignment_id =paaf.assignment_id and SIT_OPTIONAL_CALC_IND is not null AND rownum = 1) ALT_CALC_HOME_STATE_CODE,
    CAST(NULL AS VARCHAR2(100)) ALT_CALC_HOME_WORK_CODE, -- COL 70
    CAST(NULL AS VARCHAR2(100)) FUTURE_USE3,
    CAST(NULL AS VARCHAR2(100)) FUTURE_USE4,
    CAST(NULL AS VARCHAR2(100)) FUTURE_USE5,
    CAST(NULL AS VARCHAR2(100)) EMPLOYEE_1099,
    CAST(NULL AS VARCHAR2(100)) FUTURE_USE6,
   (SELECT 'BW'--segment1
    FROM pay_people_groups WHERE
      people_group_id = paaf.people_group_id) PAY_GROUP,-- COL 76 -- --as per csv file mapping
    CAST(NULL AS VARCHAR2(100)) DIVISION_CODE,
    CAST(NULL AS VARCHAR2(100)) PROJECT_CODE,
    nvl2(paaf.normal_hours,'Y','N') AUTO_PAY,-- source??
    paaf.normal_hours AUTO_PAY_HOURS,
    CAST(NULL AS VARCHAR2(100)) HOME_STATE_EXEMPT_AMOUNT,
    CAST(NULL AS VARCHAR2(100)) HOME_STATE_SECONDARY_AMOUNT,
    CAST(NULL AS VARCHAR2(100)) HOME_STATE_SUPP_AMOUNT,
    CAST(NULL AS VARCHAR2(100)) HOME_STATE_EXEMPT_AMOUNT1,
    CAST(NULL AS VARCHAR2(100)) WORK_STATE_SECONDARY_ALLOWS, -- COL 85
    CAST(NULL AS VARCHAR2(100)) WS_SUPP_AMOUNT,
    (SELECT decode(pay_basis,'HOURLY','H','WEEKLY','W','BIWEEKLY','B','SEMIMONTHLY','S','MONTHLY','M','ANNUAL','Y')
    FROM PER_PAY_BASES
    WHERE pay_basis_id = PAAF.pay_basis_id
    AND rownum         = 1
    )  PAY_PERIOD, -- Changed as per attachment in email from Elango/Liz on 6th Dec 2013
    CAST(NULL AS VARCHAR2(100)) VETERAN,
    CAST(NULL AS VARCHAR2(100)) NEWLY_SEPARATED_VET,
    CAST(NULL AS VARCHAR2(100)) SERVICE_MEDAL_VET, -- COL 90
    CAST(NULL AS VARCHAR2(100)) OTHER_PROTECTED_VET,
    CAST(NULL AS VARCHAR2(100)) I9_DOCUMENT_TITLE_A,
    CAST(NULL AS VARCHAR2(100)) I9_DOCUMENT_NUMBER_A,
    CAST(NULL AS VARCHAR2(100)) I9_DOCUMENT_AUTHORITY_A,-- COL 94
    CAST(NULL AS VARCHAR2(100)) I9_EXPIRATION_DATE_A,   -- COL 95
    CAST(NULL AS VARCHAR2(100)) I9_DOCUMENT_TITLE_B,
    CAST(NULL AS VARCHAR2(100)) I9_DOCUMENT_NUMBER_B,
    CAST(NULL AS VARCHAR2(100)) I9_ISSUING_AUTHORITY_B,
    CAST(NULL AS VARCHAR2(100)) I9_EXPIRATION_DATE_B,
    CAST(NULL AS VARCHAR2(100)) ALIEN_REG_NO,
    CAST(NULL AS VARCHAR2(100)) FICA_EXEMPT,
    CAST(NULL AS VARCHAR2(100)) UNION_CODE,
    (select nvl(employee_number,npw_number) from per_all_people_f where person_id = paaf.supervisor_id and rownum = 1) SUPERVISOR_ID,
    CAST(NULL AS VARCHAR2(100)) BENE_THRU_DATE,
    CAST(NULL AS VARCHAR2(100)) SCHOOL_DISTRICT,
    CAST(NULL AS VARCHAR2(100)) AGRICULTURAL,
    CAST(NULL AS VARCHAR2(100)) HOME_PHONE_2,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_1,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_2,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_3,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_4,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_5,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_6,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_7,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_8,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_9,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_10,
    CAST(NULL AS VARCHAR2(100)) NEW_HIRE_REPORT_DATE,
    'N' MAIL_CHECK_HOME,-- COL 119
    CAST(NULL AS VARCHAR2(100)) W2_ADDRESS_ONE,
    CAST(NULL AS VARCHAR2(100)) W2_ADDRESS_TWO,
    CAST(NULL AS VARCHAR2(100)) W2_CITY,
    CAST(NULL AS VARCHAR2(100)) W2_STATE,
    CAST(NULL AS VARCHAR2(100)) W2_ZIPCODE,
    CAST(NULL AS VARCHAR2(100)) LICENSE_NUMBER,
    CAST(NULL AS VARCHAR2(100)) LICENSE_EXPIRE_DATE,
    CAST(NULL AS VARCHAR2(100)) LICENSE_STATE,
    CAST(NULL AS VARCHAR2(100)) S_CORP_PRINCIPAL,
    CAST(NULL AS VARCHAR2(100)) ELECT_PAY_STUB,
    CAST(NULL AS VARCHAR2(100)) ELEC_W2_FORM,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOBS_1,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOBS_2,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOBS_3,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOBS_4,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOBS_5, --COL 135
    CAST(NULL AS VARCHAR2(100)) ALLOC_DIVISION_1,
    CAST(NULL AS VARCHAR2(100)) ALLOC_DIVISION_2,
    CAST(NULL AS VARCHAR2(100)) ALLOC_DIVISION_3,
    CAST(NULL AS VARCHAR2(100)) ALLOC_DIVISION_4,
    CAST(NULL AS VARCHAR2(100)) ALLOC_DIVISION_5,
    CAST(NULL AS VARCHAR2(100)) ALLOC_DEPARTMENT_1,
    CAST(NULL AS VARCHAR2(100)) ALLOC_DEPARTMENT_2,
    CAST(NULL AS VARCHAR2(100)) ALLOC_DEPARTMENT_3,
    CAST(NULL AS VARCHAR2(100)) ALLOC_DEPARTMENT_4,
    CAST(NULL AS VARCHAR2(100)) ALLOC_DEPARTMENT_5,
    CAST(NULL AS VARCHAR2(100)) ALLOC_PROJECT_1,
    CAST(NULL AS VARCHAR2(100)) ALLOC_PROJECT_2,
    CAST(NULL AS VARCHAR2(100)) ALLOC_PROJECT_3,
    CAST(NULL AS VARCHAR2(100)) ALLOC_PROJECT_4,
    CAST(NULL AS VARCHAR2(100)) ALLOC_PROJECT_5,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOB_1,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOB_2,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOB_3,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOB_4,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOB_5,
    CAST(NULL AS VARCHAR2(100)) ONHRP_ONBOARDED,
    CAST(NULL AS VARCHAR2(100)) HANDBK_RCD,
    CAST(NULL AS VARCHAR2(100)) AST_REVIEW,
    CAST(NULL AS VARCHAR2(100)) NEXT_REVIEW,
    CAST(NULL AS VARCHAR2(100)) NICKNAME -- col 165
  FROM per_all_people_f papf,
    per_all_assignments_f paaf,
    per_addresses pa,
    PER_PERIODS_OF_SERVICE ppos
  WHERE
    -- nvl(papf.employee_number,papf.npw_number) = '3159423' and
    papf.business_group_id = 325 -- /**Need to confirm from Elango **/
  AND ppos.person_id       = papf.person_id
    /*** Date conditions start***/
  AND ( -- For Terminated on Past date
    ( TRUNC(v_term_date) > trunc(ppos.actual_termination_date) -- when termination date is past date
  AND  TRUNC(v_term_date)                       = TRUNC(papf.last_update_date)
  AND TRUNC(papf.effective_end_date)    = TRUNC(paaf.effective_end_date)  -- added later
  AND TRUNC(papf.last_update_date)        = TRUNC(ppos.last_update_date)
  AND TRUNC(ppos.actual_termination_date) = TRUNC(papf.effective_end_date)
  AND ppos.date_start                     =
    (SELECT MAX (PPS1.DATE_START)
    FROM PER_PERIODS_OF_SERVICE PPS1
    WHERE PPS1.PERSON_ID = PAPF.PERSON_ID
    AND PPS1.DATE_START  = PAPF.START_DATE
    )
  AND hr_person_type_usage_info.get_user_person_type(TRUNC(papf.effective_end_date+1),papf.person_id) <> 'PEO Employee'
  AND hr_person_type_usage_info.get_user_person_type(TRUNC(papf.effective_end_date),papf.person_id)    = 'PEO Employee' )
  OR -- For Terminated on present/Future date
    ( TRUNC(v_term_date) <= trunc(ppos.actual_termination_date) -- when termination date is present or future date
  AND TRUNC(papf.effective_end_date)      = TRUNC(v_term_date)
-- Below line is commented by Priyanka on 02 Dec, 2013 for issue raised by Jamie chikuma
--  AND TRUNC(papf.start_date)    = TRUNC(paaf.effective_start_date) -- added later
  AND TRUNC(paaf.effective_end_date)      = TRUNC(v_term_date)
  --AND TRUNC(ppos.date_start)              = TRUNC(papf.effective_start_date) -- *******
  AND ppos.date_start =
    (SELECT MAX (PPS1.DATE_START)
    FROM PER_PERIODS_OF_SERVICE PPS1
    WHERE PPS1.PERSON_ID = PAPF.PERSON_ID
    AND PPS1.DATE_START >= PAPF.START_DATE
    )
    --AND trunc(v_term_date) BETWEEN paaf.effective_start_date AND paaf.effective_end_date -- SYSDATE CHANGE 5 -- ******
  AND hr_person_type_usage_info.get_user_person_type ( TRUNC(papf.effective_end_date), papf.person_id ) = 'PEO Employee' -- For PEO Employee
  AND hr_person_type_usage_info.get_user_person_type(TRUNC(papf.effective_end_date+1),papf.person_id)   <> 'PEO Employee'  -- For Terminated or transferred Employee
    ))
    -- Date conditions end
  AND TRUNC(ppos.PERSON_ID)  = TRUNC(papf.PERSON_ID)
  AND paaf.person_id         = papf.person_id
  AND paaf.business_group_id = papf.business_group_id
  AND papf.person_id         = pa.person_id (+) -- outer join if no address is defined for employee
  AND pa.PRIMARY_FLAG        = 'Y'
    AND TRUNC(NVL(pa.date_from,v_term_date)) BETWEEN
    (SELECT TRUNC(MIN(effective_start_date))
    FROM per_all_people_f
    WHERE person_id = papf.person_id
    )
    AND TRUNC(papf.effective_end_date);



BEGIN
  SELECT TO_CHAR(sysdate,'YYYYMMDDHH24MISS') INTO v_dt_time FROM dual;  /* 2.0 */
  /*select fnd_profile.value('ORG_ID') into v_org from dual;
  FND_FILE.PUT_LINE(FND_FILE.LOG,'ORG_ID : '||v_org);*/
  SELECT To_date(p_date,'YYYY/MM/DD HH24:MI:SS')
  INTO V_DATE
  FROM dual;
  SELECT To_date(p_term_date,'YYYY/MM/DD HH24:MI:SS')
  INTO V_TERM_DATE
  FROM dual;
  FND_FILE.PUT_LINE(FND_FILE.LOG,'p_date : '||p_date);
  FND_FILE.PUT_LINE(FND_FILE.LOG,'V_date : '||V_date);
  FND_FILE.PUT_LINE(FND_FILE.LOG,'p_term_date : '||p_term_date);
  FND_FILE.PUT_LINE(FND_FILE.LOG,'V_term_date : '||V_term_date);
  BEGIN
    SELECT directory_path
      || '/data/EBS/HC/HR/PEO/outbound'
    INTO v_path
    FROM dba_directories
    WHERE directory_name = 'CUST_TOP';
    --v_path := '$CUST_TOP/data/EBS/HC/HR';
  EXCEPTION
  WHEN OTHERS THEN
    fnd_file.put_line(fnd_file.log,'Program did not get destination directory : '||sqlerrm);
    raise;
  END ;
  TTEC_PEO_EMP_CHNG_EXTRACT.write_process('TELETECH_PEO_EMP_CHANGE_'||v_dt_time||'.txt','','W',v_path);
  /*-- Writing Header
  v_header := 'FIRST_NAME LAST_NAME MIDDLE_NAMES DATE_OF_BIRTH COMPANY_ID EMPLOYER_ID ETHNIC_CODE MARITAL_STATUS TOBACCO_USER ADDRESS_LINE1 ADDRESS_LINE2 POSTAL_CODE TOWN_OR_CITY REGION_2 TELEPHONE HANDICAPPED NATIONALITY GENDER EMERGENCY_CONTACT EMERGENCY_PHONE_NUMBER EMERGENCY_RELATION NATIONAL_IDENTIFIER STATUS_CODE TYPE_CODE LOCATION_ID JOB_CODE ORIG_HIRE LAST_HIRE PEO_START_DATE PAPF_EFFECTIVE_END_DATE EMPLOYEE_NUMBER WORK_TELEPHONE MAIL_ADDR1 MAIL_ADDR2 MAIL_CITY MAIL_STATE MAIL_ZIP SHIFT_CODE FUTURE_USE1 PAY_METHOD EXT_PAY_RATE TRUNC(PAPF.EFFECTIVE_START_DATE) DISCONTINUED STD_HOURS EIS_FILING_STATUS FEDERAL_STATUS FEDERAL_ALLOWS EXTRA_FEDERAL HOME_STATE_STATUS HOME_STATE_ALLOWS HOME_STATE_ADDITIONAL_AMOUNT WORK_STATE_STATUS WORK_STATE_ALLOWS WORK_STATE_ADDITIONAL_AMOUNT OFFICER DEPT_CODE FUTURE_USE2 TERM_CODE EMAIL_ADDRESS BENEFIT_GROUP USER_FIELD_1 USER_FIELD_2 USER_FIELD_3 USER_FIELD_4 USER_FIELD_5 ZIP_SUFFIX ALT_CALC_HOME_STATE_CODE ALT_CALC_HOME_WORK_CODE FUTURE_USE3
  FUTURE_USE4 FUTURE_USE5 EMPLOYEE_1099 FUTURE_USE6 PAY_GROUP DIVISION_CODE PROJECT_CODE AUTO_PAY AUTO_PAY_HOURS HOME_STATE_EXEMPT_AMOUNT HOME_STATE_SECONDARY_AMOUNT HOME_STATE_SUPP_AMOUNT HOME_STATE_EXEMPT_AMOUNT1 WORK_STATE_SECONDARY_ALLOWS WS_SUPP_AMOUNT PAY_PERIOD VETERAN NEWLY_SEPARATED_VET SERVICE_MEDAL_VET OTHER_PROTECTED_VET I9_DOCUMENT_TITLE_A I9_DOCUMENT_NUMBER_A I9_DOCUMENT_AUTHORITY_A I9_EXPIRATION_DATE_A I9_DOCUMENT_TITLE_B I9_DOCUMENT_NUMBER_B I9_ISSUING_AUTHORITY_B I9_EXPIRATION_DATE_B ALIEN_REG_NO FICA_EXEMPT UNION_CODE SUPERVISOR_ID BENE_THRU_DATE SCHOOL_DISTRICT AGRICULTURAL HOME_PHONE_2 ALT_PAY_RATE_1 ALT_PAY_RATE_2 ALT_PAY_RATE_3 ALT_PAY_RATE_4 ALT_PAY_RATE_5 ALT_PAY_RATE_6 ALT_PAY_RATE_7 ALT_PAY_RATE_8 ALT_PAY_RATE_9 ALT_PAY_RATE_10 NEW_HIRE_REPORT_DATE MAIL_CHECK_HOME W2_ADDRESS_ONE W2_ADDRESS_TWO W2_CITY W2_STATE W2_ZIPCODE LICENSE_NUMBER LICENSE_EXPIRE_DATE LICENSE_STATE S_CORP_PRINCIPAL ELECT_PAY_STUB ELEC_W2_FORM ALLOC_JOBS_1 ALLOC_JOBS_2 ALLOC_JOBS_3
  ALLOC_JOBS_4 ALLOC_JOBS_5 ALLOC_DIVISION_1 ALLOC_DIVISION_2 ALLOC_DIVISION_3 ALLOC_DIVISION_4 ALLOC_DIVISION_5 ALLOC_DEPARTMENT_1 ALLOC_DEPARTMENT_2 ALLOC_DEPARTMENT_3 ALLOC_DEPARTMENT_4 ALLOC_DEPARTMENT_5 ALLOC_PROJECT_1 ALLOC_PROJECT_2 ALLOC_PROJECT_3 ALLOC_PROJECT_4 ALLOC_PROJECT_5 ALLOC_JOB_1 ALLOC_JOB_2 ALLOC_JOB_3 ALLOC_JOB_4 ALLOC_JOB_5 ONHRP_ONBOARDED HANDBK_RCD AST_REVIEW NEXT_REVIEW NICKNAME';
  fnd_file.put_line(fnd_file.output,v_header);
  TTEC_PEO_EMP_CHNG_EXTRACT.write_process('TELETECH_'||v_dt_time, v_header,'A',v_path);*/
  BEGIN
    FOR cur_peo_emp IN peo_emp
    LOOP
      --v_columns_str := cur_peo_emp.FIRST_NAME||' '||cur_peo_emp.LAST_NAME||' '||cur_peo_emp.MIDDLE_NAMES||' '||cur_peo_emp.DATE_OF_BIRTH||' '||cur_peo_emp.COMPANY_ID||' '||cur_peo_emp.EMPLOYER_ID||'  '|| cur_peo_emp.ETHNIC_CODE||'  '|| cur_peo_emp.MARITAL_STATUS||'  '|| cur_peo_emp.TOBACCO_USER||'  '|| cur_peo_emp.ADDRESS_LINE1||'  '|| cur_peo_emp.ADDRESS_LINE2||'  '|| cur_peo_emp.POSTAL_CODE||' '||cur_peo_emp.TOWN_OR_CITY||' '||cur_peo_emp.REGION_2||' '||cur_peo_emp.TELEPHONE||' '||cur_peo_emp.HANDICAPPED||' '||cur_peo_emp.NATIONALITY||' '||cur_peo_emp.GENDER||' '||cur_peo_emp.EMERGENCY_CONTACT||' '||cur_peo_emp.EMERGENCY_PHONE_NUMBER||' '||cur_peo_emp.EMERGENCY_RELATION||' '||cur_peo_emp.NATIONAL_IDENTIFIER||' '||cur_peo_emp.STATUS_CODE||' '||cur_peo_emp.TYPE_CODE||' '||cur_peo_emp.LOCATION_ID||' '||cur_peo_emp.JOB_CODE||' '||cur_peo_emp.ORIG_HIRE||' '||cur_peo_emp.LAST_HIRE||' '||cur_peo_emp.PEO_START_DATE||' '||cur_peo_emp.PAPF_EFFECTIVE_END_DATE||' '||
      -- cur_peo_emp.EMPLOYEE_NUMBER||' '||cur_peo_emp.WORK_TELEPHONE||' '||cur_peo_emp.MAIL_ADDR1||' '||cur_peo_emp.MAIL_ADDR2||' '||cur_peo_emp.MAIL_CITY||' '||cur_peo_emp.MAIL_STATE||' '||cur_peo_emp.MAIL_ZIP||' '||cur_peo_emp.SHIFT_CODE||' '||'FUTURE_USE1'||' '||cur_peo_emp.PAY_METHOD||' '||cur_peo_emp.EXT_PAY_RATE||' '||cur_peo_emp.DISCONTINUED||' '||cur_peo_emp.STD_HOURS||' '||cur_peo_emp.EIS_FILING_STATUS||' '||cur_peo_emp.FEDERAL_STATUS||' '||cur_peo_emp.FEDERAL_ALLOWS||' '||cur_peo_emp.I9_EXPIRATION_DATE_A||' '||cur_peo_emp.I9_DOCUMENT_TITLE_B||' '||cur_peo_emp.I9_DOCUMENT_NUMBER_B||' '||cur_peo_emp.I9_ISSUING_AUTHORITY_B||' '||cur_peo_emp.I9_EXPIRATION_DATE_B||' '||cur_peo_emp.ALIEN_REG_NO||' '||cur_peo_emp.FICA_EXEMPT||' '||cur_peo_emp.UNION_CODE||' '||cur_peo_emp.SUPERVISOR_ID||' '||cur_peo_emp.BENE_THRU_DATE||' '||cur_peo_emp.SCHOOL_DISTRICT||' '||cur_peo_emp.AGRICULTURAL||' '||cur_peo_emp.HOME_PHONE_2||' '||cur_peo_emp.ALT_PAY_RATE_1||' '||cur_peo_emp.ALT_PAY_RATE_2||'
      -- '||cur_peo_emp.ALT_PAY_RATE_3||' '||cur_peo_emp.ALT_PAY_RATE_4||' '||cur_peo_emp.ALT_PAY_RATE_5||' '||cur_peo_emp.ALT_PAY_RATE_6||' '||cur_peo_emp.ALT_PAY_RATE_7||' '||cur_peo_emp.ALT_PAY_RATE_8||' '||cur_peo_emp.ALT_PAY_RATE_9||' '||cur_peo_emp.ALT_PAY_RATE_10||' '||cur_peo_emp.NEW_HIRE_REPORT_DATE||' '||cur_peo_emp.MAIL_CHECK_HOME||' '||cur_peo_emp.ALLOC_JOBS_1||' '||cur_peo_emp.ALLOC_JOBS_2||' '||cur_peo_emp.ALLOC_JOBS_3||' '||cur_peo_emp.ALLOC_JOBS_4||' '||cur_peo_emp.ALLOC_JOBS_5;

      /* --- code commented by Priyanka to change all space to TAB
      v_columns_str := cur_peo_emp.FIRST_NAME||' '||cur_peo_emp.LAST_NAME||' '||cur_peo_emp.MIDDLE_NAMES||' '||cur_peo_emp.DATE_OF_BIRTH||' '||cur_peo_emp.COMPANY_ID||' '||cur_peo_emp.EMPLOYER_ID||' '||cur_peo_emp.ETHNIC_CODE||' '||cur_peo_emp.MARITAL_STATUS||' '||cur_peo_emp.TOBACCO_USER||' '||cur_peo_emp.ADDRESS_LINE1||' '||cur_peo_emp.ADDRESS_LINE2||' '||cur_peo_emp.POSTAL_CODE||' '||cur_peo_emp.TOWN_OR_CITY||' '||cur_peo_emp.REGION_2||' '||cur_peo_emp.TELEPHONE||' '||cur_peo_emp.HANDICAPPED||' '||cur_peo_emp.NATIONALITY||' '||cur_peo_emp.GENDER||' '||cur_peo_emp.EMERGENCY_CONTACT||' '||cur_peo_emp.EMERGENCY_PHONE_NUMBER||' '||cur_peo_emp.EMERGENCY_RELATION||' '||cur_peo_emp.NATIONAL_IDENTIFIER||' '||cur_peo_emp.STATUS_CODE||' '||cur_peo_emp.TYPE_CODE||' '||cur_peo_emp.LOCATION_ID||' '||cur_peo_emp.JOB_CODE||' '||cur_peo_emp.ORIG_HIRE||' '||cur_peo_emp.LAST_HIRE||' '||cur_peo_emp.PEO_START_DATE||' '||cur_peo_emp.PAPF_EFFECTIVE_END_DATE||' '||cur_peo_emp.EMPLOYEE_NUMBER||' '||
      cur_peo_emp.WORK_TELEPHONE||' '||cur_peo_emp.MAIL_ADDR1||' '||cur_peo_emp.MAIL_ADDR2||' '||cur_peo_emp.MAIL_CITY||' '||cur_peo_emp.MAIL_STATE||' '||cur_peo_emp.MAIL_ZIP||' '||cur_peo_emp.SHIFT_CODE||' '||'FUTURE_USE1'||' '||cur_peo_emp.PAY_METHOD||' '||cur_peo_emp.EXT_PAY_RATE||' '||cur_peo_emp.DISCONTINUED||' '||cur_peo_emp.STD_HOURS||' '||cur_peo_emp.EIS_FILING_STATUS||' '||cur_peo_emp.FEDERAL_STATUS||' '||cur_peo_emp.FEDERAL_ALLOWS||' '||cur_peo_emp.EXTRA_FEDERAL||' '||cur_peo_emp.HOME_STATE_STATUS||' '||cur_peo_emp.HOME_STATE_ALLOWS||' '||cur_peo_emp.HOME_STATE_ADDITIONAL_AMOUNT||' '||cur_peo_emp.WORK_STATE_STATUS||' '||cur_peo_emp.WORK_STATE_ALLOWS||' '||cur_peo_emp.WORK_STATE_ADDITIONAL_AMOUNT||' '||cur_peo_emp.OFFICER||' '||cur_peo_emp.DEPT_CODE||' '||cur_peo_emp.FUTURE_USE2||' '||cur_peo_emp.TERM_CODE||' '||cur_peo_emp.EMAIL_ADDRESS||' '||cur_peo_emp.BENEFIT_GROUP||' '||cur_peo_emp.USER_FIELD_1||' '||cur_peo_emp.USER_FIELD_2||' '||cur_peo_emp.USER_FIELD_3||' '||
      cur_peo_emp.USER_FIELD_4||' '||cur_peo_emp.USER_FIELD_5||' '||cur_peo_emp.ZIP_SUFFIX||' '||cur_peo_emp.ALT_CALC_HOME_STATE_CODE||' '||cur_peo_emp.ALT_CALC_HOME_WORK_CODE||' '||cur_peo_emp.FUTURE_USE3||' '||cur_peo_emp.FUTURE_USE4||' '||cur_peo_emp.FUTURE_USE5||' '||cur_peo_emp.EMPLOYEE_1099||' '||cur_peo_emp.FUTURE_USE6||' '||cur_peo_emp.PAY_GROUP||' '||cur_peo_emp.DIVISION_CODE||' '||cur_peo_emp.PROJECT_CODE||' '||cur_peo_emp.AUTO_PAY||' '||cur_peo_emp.AUTO_PAY_HOURS||' '||cur_peo_emp.HOME_STATE_EXEMPT_AMOUNT||' '||cur_peo_emp.HOME_STATE_SECONDARY_AMOUNT||' '||cur_peo_emp.HOME_STATE_SUPP_AMOUNT||' '||cur_peo_emp.HOME_STATE_EXEMPT_AMOUNT1||' '||cur_peo_emp.WORK_STATE_SECONDARY_ALLOWS||' '||cur_peo_emp.WS_SUPP_AMOUNT||' '||cur_peo_emp.PAY_PERIOD||' '||cur_peo_emp.VETERAN||' '||cur_peo_emp.NEWLY_SEPARATED_VET||' '||cur_peo_emp.SERVICE_MEDAL_VET||' '||cur_peo_emp.OTHER_PROTECTED_VET||' '||cur_peo_emp.I9_DOCUMENT_TITLE_A||' '||cur_peo_emp.I9_DOCUMENT_NUMBER_A||' '||
      cur_peo_emp.I9_DOCUMENT_AUTHORITY_A||' '||cur_peo_emp.I9_EXPIRATION_DATE_A||' '||cur_peo_emp.I9_DOCUMENT_TITLE_B||' '||cur_peo_emp.I9_DOCUMENT_NUMBER_B||' '||cur_peo_emp.I9_ISSUING_AUTHORITY_B||' '||cur_peo_emp.I9_EXPIRATION_DATE_B||' '||cur_peo_emp.ALIEN_REG_NO||' '||cur_peo_emp.FICA_EXEMPT||' '||cur_peo_emp.UNION_CODE||' '||cur_peo_emp.SUPERVISOR_ID||' '||cur_peo_emp.BENE_THRU_DATE||' '||cur_peo_emp.SCHOOL_DISTRICT||' '||cur_peo_emp.AGRICULTURAL||' '||cur_peo_emp.HOME_PHONE_2||' '||cur_peo_emp.ALT_PAY_RATE_1||' '||cur_peo_emp.ALT_PAY_RATE_2||' '||cur_peo_emp.ALT_PAY_RATE_3||' '||cur_peo_emp.ALT_PAY_RATE_4||' '||cur_peo_emp.ALT_PAY_RATE_5||' '||cur_peo_emp.ALT_PAY_RATE_6||' '||cur_peo_emp.ALT_PAY_RATE_7||' '||cur_peo_emp.ALT_PAY_RATE_8||' '||cur_peo_emp.ALT_PAY_RATE_9||' '||cur_peo_emp.ALT_PAY_RATE_10||' '||cur_peo_emp.NEW_HIRE_REPORT_DATE||' '||cur_peo_emp.MAIL_CHECK_HOME||' '||cur_peo_emp.W2_ADDRESS_ONE||' '||cur_peo_emp.W2_ADDRESS_TWO||' '||cur_peo_emp.W2_CITY||' '||
      cur_peo_emp.W2_STATE||' '||cur_peo_emp.W2_ZIPCODE||' '||cur_peo_emp.LICENSE_NUMBER||' '||cur_peo_emp.LICENSE_EXPIRE_DATE||' '||cur_peo_emp.LICENSE_STATE||' '||cur_peo_emp.S_CORP_PRINCIPAL||' '||cur_peo_emp.ELECT_PAY_STUB||' '||cur_peo_emp.ELEC_W2_FORM||' '||cur_peo_emp.ALLOC_JOBS_1||' '||cur_peo_emp.ALLOC_JOBS_2||' '||cur_peo_emp.ALLOC_JOBS_3||' '||cur_peo_emp.ALLOC_JOBS_4||' '||cur_peo_emp.ALLOC_JOBS_5||' '||cur_peo_emp.ALLOC_DIVISION_1||' '||cur_peo_emp.ALLOC_DIVISION_2||' '||cur_peo_emp.ALLOC_DIVISION_3||' '||cur_peo_emp.ALLOC_DIVISION_4||' '||cur_peo_emp.ALLOC_DIVISION_5||' '||cur_peo_emp.ALLOC_DEPARTMENT_1||' '||cur_peo_emp.ALLOC_DEPARTMENT_2||' '||cur_peo_emp.ALLOC_DEPARTMENT_3||' '||cur_peo_emp.ALLOC_DEPARTMENT_4||' '||cur_peo_emp.ALLOC_DEPARTMENT_5||' '||cur_peo_emp.ALLOC_PROJECT_1||' '||cur_peo_emp.ALLOC_PROJECT_2||' '||cur_peo_emp.ALLOC_PROJECT_3||' '||cur_peo_emp.ALLOC_PROJECT_4||' '||cur_peo_emp.ALLOC_PROJECT_5||' '||cur_peo_emp.ALLOC_JOB_1||' '||
      cur_peo_emp.ALLOC_JOB_2||' '||cur_peo_emp.ALLOC_JOB_3||' '||cur_peo_emp.ALLOC_JOB_4||' '||cur_peo_emp.ALLOC_JOB_5||' '||cur_peo_emp.ONHRP_ONBOARDED||' '||cur_peo_emp.HANDBK_RCD||' '||cur_peo_emp.AST_REVIEW||' '||cur_peo_emp.NEXT_REVIEW||' '||cur_peo_emp.NICKNAME;
      */

       ---------- New code added by Priyanka on 2nd Dec, 2013 to fix the opening of file in Excel issue ----
      v_columns_str := cur_peo_emp.FIRST_NAME||'	'||cur_peo_emp.LAST_NAME||'	'||cur_peo_emp.MIDDLE_NAMES||'	'||cur_peo_emp.DATE_OF_BIRTH||'	'
                       ||cur_peo_emp.COMPANY_ID||'	'||cur_peo_emp.EMPLOYER_ID||'	'||cur_peo_emp.ETHNIC_CODE||'	'||cur_peo_emp.MARITAL_STATUS||'	'
		       ||cur_peo_emp.TOBACCO_USER||'	'||cur_peo_emp.ADDRESS_LINE1||'	'||cur_peo_emp.ADDRESS_LINE2||'	'||cur_peo_emp.POSTAL_CODE||'	'
		       ||cur_peo_emp.TOWN_OR_CITY||'	'||cur_peo_emp.REGION_2||'	'||cur_peo_emp.TELEPHONE||'	'||cur_peo_emp.HANDICAPPED||'	'
		       ||cur_peo_emp.CITIZEN||'	'||cur_peo_emp.GENDER||'	'||cur_peo_emp.EMERGENCY_CONTACT||'	'||cur_peo_emp.EMERGENCY_PHONE_NUMBER
		       ||'	'||cur_peo_emp.EMERGENCY_RELATION||'	'||cur_peo_emp.SOC_SEC_NUM||'	'||cur_peo_emp.STATUS_CODE||'	'
		       ||cur_peo_emp.TYPE_CODE||'	'||cur_peo_emp.LOCATION_CODE||'	'||cur_peo_emp.JOB_CODE||'	'||cur_peo_emp.ORIG_HIRE||'	'
		       ||cur_peo_emp.LAST_HIRE||'	'||cur_peo_emp.PEO_START_DATE||'	'||
		       cur_peo_emp.EMPLOYEE_NUMBER||'	'||cur_peo_emp.WORK_TELEPHONE||'	'||cur_peo_emp.MAIL_ADDR1||'	'||cur_peo_emp.MAIL_ADDR2
		       ||'	'||cur_peo_emp.MAIL_CITY||'	'||cur_peo_emp.MAIL_STATE||'	'||cur_peo_emp.MAIL_ZIP||'	'||cur_peo_emp.SHIFT_CODE
		       ||'	'||'FUTURE_USE1'||'	'||cur_peo_emp.PAY_METHOD||'	'||cur_peo_emp.EXT_PAY_RATE||'	'||cur_peo_emp.DISCONTINUED||'	'
		       ||cur_peo_emp.STD_HOURS||'	'||cur_peo_emp.EIS_FILING_STATUS||'	'||cur_peo_emp.FEDERAL_STATUS||'	'
		       ||cur_peo_emp.FEDERAL_ALLOWS||'	'||cur_peo_emp.EXTRA_FEDERAL||'	'||cur_peo_emp.HOME_STATE_STATUS||'	'||cur_peo_emp.HOME_STATE_ALLOWS
		       ||'	'||cur_peo_emp.HOME_STATE_ADDITIONAL_AMOUNT||'	'||cur_peo_emp.WORK_STATE_STATUS||'	'||cur_peo_emp.WORK_STATE_ALLOWS
		       ||'	'||cur_peo_emp.WORK_STATE_ADDITIONAL_AMOUNT||'	'||cur_peo_emp.OFFICER||'	'||cur_peo_emp.DEPT_CODE||'	'
		       ||cur_peo_emp.FUTURE_USE2||'	'||cur_peo_emp.TERM_CODE||'	'||cur_peo_emp.EMAIL_ADDRESS||'	'||cur_peo_emp.BENEFIT_GROUP||'	'
		       ||cur_peo_emp.USER_FIELD_1||'	'||cur_peo_emp.USER_FIELD_2||'	'||cur_peo_emp.USER_FIELD_3||'	'||cur_peo_emp.USER_FIELD_4||'	'
		       ||cur_peo_emp.USER_FIELD_5||'	'||cur_peo_emp.ZIP_SUFFIX||'	'||cur_peo_emp.ALT_CALC_HOME_STATE_CODE||'	'||cur_peo_emp.ALT_CALC_HOME_WORK_CODE
		       ||'	'||cur_peo_emp.FUTURE_USE3||'	'||cur_peo_emp.FUTURE_USE4||'	'||cur_peo_emp.FUTURE_USE5||'	'||cur_peo_emp.EMPLOYEE_1099
		       ||'	'||cur_peo_emp.FUTURE_USE6||'	'||cur_peo_emp.PAY_GROUP||'	'||cur_peo_emp.DIVISION_CODE||'	'||cur_peo_emp.PROJECT_CODE
		       ||'	'||cur_peo_emp.AUTO_PAY||'	'||cur_peo_emp.AUTO_PAY_HOURS||'	'||cur_peo_emp.HOME_STATE_EXEMPT_AMOUNT||'	'
		       ||cur_peo_emp.HOME_STATE_SECONDARY_AMOUNT||'	'||cur_peo_emp.HOME_STATE_SUPP_AMOUNT||'	'||cur_peo_emp.HOME_STATE_EXEMPT_AMOUNT1
		       ||'	'||cur_peo_emp.WORK_STATE_SECONDARY_ALLOWS||'	'||cur_peo_emp.WS_SUPP_AMOUNT||'	'||cur_peo_emp.PAY_PERIOD||'	'
		       ||cur_peo_emp.VETERAN||'	'||cur_peo_emp.NEWLY_SEPARATED_VET||'	'||cur_peo_emp.SERVICE_MEDAL_VET||'	'||cur_peo_emp.OTHER_PROTECTED_VET
		       ||'	'||cur_peo_emp.I9_DOCUMENT_TITLE_A||'	'||cur_peo_emp.I9_DOCUMENT_NUMBER_A||'	'||cur_peo_emp.I9_DOCUMENT_AUTHORITY_A||'	'
		       ||cur_peo_emp.I9_EXPIRATION_DATE_A||'	'||cur_peo_emp.I9_DOCUMENT_TITLE_B||'	'||cur_peo_emp.I9_DOCUMENT_NUMBER_B||'	'
		       ||cur_peo_emp.I9_ISSUING_AUTHORITY_B||'	'||cur_peo_emp.I9_EXPIRATION_DATE_B||'	'||cur_peo_emp.ALIEN_REG_NO||'	'||cur_peo_emp.FICA_EXEMPT
		       ||'	'||cur_peo_emp.UNION_CODE||'	'||cur_peo_emp.SUPERVISOR_ID||'	'||cur_peo_emp.BENE_THRU_DATE||'	'||cur_peo_emp.SCHOOL_DISTRICT
		       ||'	'||cur_peo_emp.AGRICULTURAL||'	'||cur_peo_emp.HOME_PHONE_2||'	'||cur_peo_emp.ALT_PAY_RATE_1||'	'
		       ||cur_peo_emp.ALT_PAY_RATE_2||'	'||cur_peo_emp.ALT_PAY_RATE_3||'	'||cur_peo_emp.ALT_PAY_RATE_4||'	'||cur_peo_emp.ALT_PAY_RATE_5
		       ||'	'||cur_peo_emp.ALT_PAY_RATE_6||'	'||cur_peo_emp.ALT_PAY_RATE_7||'	'||cur_peo_emp.ALT_PAY_RATE_8||'	'
		       ||cur_peo_emp.ALT_PAY_RATE_9||'	'||cur_peo_emp.ALT_PAY_RATE_10||'	'||cur_peo_emp.NEW_HIRE_REPORT_DATE||'	'||cur_peo_emp.MAIL_CHECK_HOME
		       ||'	'||cur_peo_emp.W2_ADDRESS_ONE||'	'||cur_peo_emp.W2_ADDRESS_TWO||'	'||cur_peo_emp.W2_CITY||'	'
		       ||cur_peo_emp.W2_STATE||'	'||cur_peo_emp.W2_ZIPCODE||'	'||cur_peo_emp.LICENSE_NUMBER||'	'||cur_peo_emp.LICENSE_EXPIRE_DATE
		       ||'	'||cur_peo_emp.LICENSE_STATE||'	'||cur_peo_emp.S_CORP_PRINCIPAL||'	'||cur_peo_emp.ELECT_PAY_STUB||'	'
		       ||cur_peo_emp.ELEC_W2_FORM||'	'||cur_peo_emp.ALLOC_JOBS_1||'	'||cur_peo_emp.ALLOC_JOBS_2||'	'||cur_peo_emp.ALLOC_JOBS_3||'	'
		       ||cur_peo_emp.ALLOC_JOBS_4||'	'||cur_peo_emp.ALLOC_JOBS_5||'	'||cur_peo_emp.ALLOC_DIVISION_1||'	'||cur_peo_emp.ALLOC_DIVISION_2
		       ||'	'||cur_peo_emp.ALLOC_DIVISION_3||'	'||cur_peo_emp.ALLOC_DIVISION_4||'	'||cur_peo_emp.ALLOC_DIVISION_5||'	'
		       ||cur_peo_emp.ALLOC_DEPARTMENT_1||'	'||cur_peo_emp.ALLOC_DEPARTMENT_2||'	'||cur_peo_emp.ALLOC_DEPARTMENT_3||'	'
		       ||cur_peo_emp.ALLOC_DEPARTMENT_4||'	'||cur_peo_emp.ALLOC_DEPARTMENT_5||'	'||cur_peo_emp.ALLOC_PROJECT_1||'	'
		       ||cur_peo_emp.ALLOC_PROJECT_2||'	'||cur_peo_emp.ALLOC_PROJECT_3||'	'||cur_peo_emp.ALLOC_PROJECT_4||'	'
		       ||cur_peo_emp.ALLOC_PROJECT_5||'	'||cur_peo_emp.ALLOC_JOB_1||'	'||cur_peo_emp.ALLOC_JOB_2||'	'||cur_peo_emp.ALLOC_JOB_3||'	'
		       ||cur_peo_emp.ALLOC_JOB_4||'	'||cur_peo_emp.ALLOC_JOB_5||'	'||cur_peo_emp.ONHRP_ONBOARDED||'	'||cur_peo_emp.HANDBK_RCD||'	'
		       ||cur_peo_emp.AST_REVIEW||'	'||cur_peo_emp.NEXT_REVIEW||'	'||cur_peo_emp.NICKNAME;
      -- New code added by priyanka ends here

      fnd_file.put_line(fnd_file.output,'PEO Employee Changed : '||v_columns_str);
      TTEC_PEO_EMP_CHNG_EXTRACT.write_process('TELETECH_PEO_EMP_CHANGE_'||v_dt_time||'.txt', v_columns_str,'A',v_path);
    END LOOP;

    FOR cur_peo_emp_term IN peo_emp_term
  LOOP

 /* --- code commented by Priyanka to change all space to TAB
    v_columns_str := cur_peo_emp_term.FIRST_NAME||' '||cur_peo_emp_term.LAST_NAME||' '||cur_peo_emp_term.MIDDLE_NAMES||' '||cur_peo_emp_term.DATE_OF_BIRTH||' '||cur_peo_emp_term.COMPANY_ID||' '||cur_peo_emp_term.EMPLOYER_ID||' '||cur_peo_emp_term.ETHNIC_CODE||' '||cur_peo_emp_term.MARITAL_STATUS||' '||cur_peo_emp_term.TOBACCO_USER||' '||cur_peo_emp_term.ADDRESS_LINE1||' '||cur_peo_emp_term.ADDRESS_LINE2||' '||cur_peo_emp_term.POSTAL_CODE||' '||cur_peo_emp_term.TOWN_OR_CITY||' '||cur_peo_emp_term.REGION_2||' '||cur_peo_emp_term.TELEPHONE||' '||cur_peo_emp_term.HANDICAPPED||' '||cur_peo_emp_term.NATIONALITY||' '||cur_peo_emp_term.GENDER||' '||cur_peo_emp_term.EMERGENCY_CONTACT||' '||cur_peo_emp_term.EMERGENCY_PHONE_NUMBER||' '||cur_peo_emp_term.EMERGENCY_RELATION||' '||cur_peo_emp_term.NATIONAL_IDENTIFIER||' '||cur_peo_emp_term.STATUS_CODE||' '||cur_peo_emp_term.TYPE_CODE||' '||cur_peo_emp_term.LOCATION_ID||' '||cur_peo_emp_term.JOB_CODE||' '||cur_peo_emp_term.ORIG_HIRE||' '||
    cur_peo_emp_term.LAST_HIRE||' '||cur_peo_emp_term.PEO_START_DATE||' '||cur_peo_emp_term.PAPF_EFFECTIVE_END_DATE||' '||cur_peo_emp_term.EMPLOYEE_NUMBER||' '||cur_peo_emp_term.WORK_TELEPHONE||' '||cur_peo_emp_term.MAIL_ADDR1||' '||cur_peo_emp_term.MAIL_ADDR2||' '||cur_peo_emp_term.MAIL_CITY||' '||cur_peo_emp_term.MAIL_STATE||' '||cur_peo_emp_term.MAIL_ZIP||' '||cur_peo_emp_term.SHIFT_CODE||' '||'FUTURE_USE1'||' '||cur_peo_emp_term.PAY_METHOD||' '||cur_peo_emp_term.EXT_PAY_RATE||' '||cur_peo_emp_term.DISCONTINUED;
    v_columns_str := v_columns_str ||' '||cur_peo_emp_term.STD_HOURS||' '||cur_peo_emp_term.EIS_FILING_STATUS||' '||cur_peo_emp_term.FEDERAL_STATUS||' '||cur_peo_emp_term.FEDERAL_ALLOWS||' '||cur_peo_emp_term.EXTRA_FEDERAL||' '||cur_peo_emp_term.HOME_STATE_STATUS||' '||cur_peo_emp_term.HOME_STATE_ALLOWS||' '||cur_peo_emp_term.HOME_STATE_ADDITIONAL_AMOUNT||' '||cur_peo_emp_term.WORK_STATE_STATUS||' '||cur_peo_emp_term.WORK_STATE_ALLOWS||' '||cur_peo_emp_term.WORK_STATE_ADDITIONAL_AMOUNT||' '||cur_peo_emp_term.OFFICER||' '||cur_peo_emp_term.DEPT_CODE||' '||cur_peo_emp_term.FUTURE_USE2||' '||cur_peo_emp_term.TERM_CODE||' '||cur_peo_emp_term.EMAIL_ADDRESS||' '||cur_peo_emp_term.BENEFIT_GROUP||' '||cur_peo_emp_term.USER_FIELD_1||' '||cur_peo_emp_term.USER_FIELD_2||' '||cur_peo_emp_term.USER_FIELD_3||' '||cur_peo_emp_term.USER_FIELD_4||' '||cur_peo_emp_term.USER_FIELD_5||' '||cur_peo_emp_term.ZIP_SUFFIX||' '||cur_peo_emp_term.ALT_CALC_HOME_STATE_CODE||' '||
    cur_peo_emp_term.ALT_CALC_HOME_WORK_CODE||' '||cur_peo_emp_term.FUTURE_USE3||' '||cur_peo_emp_term.FUTURE_USE4||' '||cur_peo_emp_term.FUTURE_USE5||' '||cur_peo_emp_term.EMPLOYEE_1099||' '||cur_peo_emp_term.FUTURE_USE6||' '||cur_peo_emp_term.PAY_GROUP||' '||cur_peo_emp_term.DIVISION_CODE||' '||cur_peo_emp_term.PROJECT_CODE||' '||cur_peo_emp_term.AUTO_PAY||' '||cur_peo_emp_term.AUTO_PAY_HOURS||' '||cur_peo_emp_term.HOME_STATE_EXEMPT_AMOUNT||' '||cur_peo_emp_term.HOME_STATE_SECONDARY_AMOUNT||' '||cur_peo_emp_term.HOME_STATE_SUPP_AMOUNT||' '||cur_peo_emp_term.HOME_STATE_EXEMPT_AMOUNT1||' '||cur_peo_emp_term.WORK_STATE_SECONDARY_ALLOWS||' ';
    v_columns_str := v_columns_str ||cur_peo_emp_term.WS_SUPP_AMOUNT||' '||cur_peo_emp_term.PAY_PERIOD||' '||cur_peo_emp_term.VETERAN||' '||cur_peo_emp_term.NEWLY_SEPARATED_VET||' '||cur_peo_emp_term.SERVICE_MEDAL_VET||' '||cur_peo_emp_term.OTHER_PROTECTED_VET||' '||cur_peo_emp_term.I9_DOCUMENT_TITLE_A||' '||cur_peo_emp_term.I9_DOCUMENT_NUMBER_A||' '||cur_peo_emp_term.I9_DOCUMENT_AUTHORITY_A||' '||cur_peo_emp_term.I9_EXPIRATION_DATE_A||' '||cur_peo_emp_term.I9_DOCUMENT_TITLE_B||' '||cur_peo_emp_term.I9_DOCUMENT_NUMBER_B||' '||cur_peo_emp_term.I9_ISSUING_AUTHORITY_B||' '||cur_peo_emp_term.I9_EXPIRATION_DATE_B||' '||cur_peo_emp_term.ALIEN_REG_NO||' '||cur_peo_emp_term.FICA_EXEMPT||' '||cur_peo_emp_term.UNION_CODE||' '||cur_peo_emp_term.SUPERVISOR_ID||' '||cur_peo_emp_term.BENE_THRU_DATE||' '||cur_peo_emp_term.SCHOOL_DISTRICT||' '||cur_peo_emp_term.AGRICULTURAL||' '||cur_peo_emp_term.HOME_PHONE_2||' '||cur_peo_emp_term.ALT_PAY_RATE_1||' '||cur_peo_emp_term.ALT_PAY_RATE_2||' '||
    cur_peo_emp_term.ALT_PAY_RATE_3||' '||cur_peo_emp_term.ALT_PAY_RATE_4||' '||cur_peo_emp_term.ALT_PAY_RATE_5||' '||cur_peo_emp_term.ALT_PAY_RATE_6||' '||cur_peo_emp_term.ALT_PAY_RATE_7||' '||cur_peo_emp_term.ALT_PAY_RATE_8||' '||cur_peo_emp_term.ALT_PAY_RATE_9||' '||cur_peo_emp_term.ALT_PAY_RATE_10||' '||cur_peo_emp_term.NEW_HIRE_REPORT_DATE||' '||cur_peo_emp_term.MAIL_CHECK_HOME||' '||cur_peo_emp_term.W2_ADDRESS_ONE||' '||cur_peo_emp_term.W2_ADDRESS_TWO||' '||cur_peo_emp_term.W2_CITY||' '||cur_peo_emp_term.W2_STATE||' '||cur_peo_emp_term.W2_ZIPCODE||' '||cur_peo_emp_term.LICENSE_NUMBER||' '||cur_peo_emp_term.LICENSE_EXPIRE_DATE||' '||cur_peo_emp_term.LICENSE_STATE||' '||cur_peo_emp_term.S_CORP_PRINCIPAL||' '||cur_peo_emp_term.ELECT_PAY_STUB||' '||cur_peo_emp_term.ELEC_W2_FORM||' '||cur_peo_emp_term.ALLOC_JOBS_1||' '||cur_peo_emp_term.ALLOC_JOBS_2||' '||cur_peo_emp_term.ALLOC_JOBS_3||' '||cur_peo_emp_term.ALLOC_JOBS_4||' '||cur_peo_emp_term.ALLOC_JOBS_5||' '||
    cur_peo_emp_term.ALLOC_DIVISION_1;
    v_columns_str := v_columns_str||' '||cur_peo_emp_term.ALLOC_DIVISION_2||' '||cur_peo_emp_term.ALLOC_DIVISION_3||' '||cur_peo_emp_term.ALLOC_DIVISION_4||' '||cur_peo_emp_term.ALLOC_DIVISION_5||' '||cur_peo_emp_term.ALLOC_DEPARTMENT_1||' '||cur_peo_emp_term.ALLOC_DEPARTMENT_2||' '||cur_peo_emp_term.ALLOC_DEPARTMENT_3||' '||cur_peo_emp_term.ALLOC_DEPARTMENT_4||' '||cur_peo_emp_term.ALLOC_DEPARTMENT_5||' '||cur_peo_emp_term.ALLOC_PROJECT_1||' '||cur_peo_emp_term.ALLOC_PROJECT_2||' '||cur_peo_emp_term.ALLOC_PROJECT_3||' '||cur_peo_emp_term.ALLOC_PROJECT_4||' '||cur_peo_emp_term.ALLOC_PROJECT_5||' '||cur_peo_emp_term.ALLOC_JOB_1||' '||cur_peo_emp_term.ALLOC_JOB_2||' '||cur_peo_emp_term.ALLOC_JOB_3||' '||cur_peo_emp_term.ALLOC_JOB_4||' '||cur_peo_emp_term.ALLOC_JOB_5||' '||cur_peo_emp_term.ONHRP_ONBOARDED||' '||cur_peo_emp_term.HANDBK_RCD||' '||cur_peo_emp_term.AST_REVIEW||' '||cur_peo_emp_term.NEXT_REVIEW||' '||cur_peo_emp_term.NICKNAME;
 ----------*/

  ---------- New code added by Priyanka on 2nd Dec, 2013 to fix the opening of file in Excel issue ----
    v_columns_str := cur_peo_emp_term.FIRST_NAME||'	'||cur_peo_emp_term.LAST_NAME||'	'||cur_peo_emp_term.MIDDLE_NAMES||'	'
                     ||cur_peo_emp_term.DATE_OF_BIRTH||'	'||cur_peo_emp_term.COMPANY_ID||'	'||cur_peo_emp_term.EMPLOYER_ID||'	'
		     ||cur_peo_emp_term.ETHNIC_CODE||'	'||cur_peo_emp_term.MARITAL_STATUS||'	'||cur_peo_emp_term.TOBACCO_USER||'	'
		     ||cur_peo_emp_term.ADDRESS_LINE1||'	'||cur_peo_emp_term.ADDRESS_LINE2||'	'||cur_peo_emp_term.POSTAL_CODE||'	'
		     ||cur_peo_emp_term.TOWN_OR_CITY||'	'||cur_peo_emp_term.REGION_2||'	'||cur_peo_emp_term.TELEPHONE||'	'||cur_peo_emp_term.HANDICAPPED
		     ||'	'||cur_peo_emp_term.CITIZEN||'	'||cur_peo_emp_term.GENDER||'	'||cur_peo_emp_term.EMERGENCY_CONTACT||'	'
		     ||cur_peo_emp_term.EMERGENCY_PHONE_NUMBER||'	'||cur_peo_emp_term.EMERGENCY_RELATION||'	'||cur_peo_emp_term.SOC_SEC_NUM
		     ||'	'||cur_peo_emp_term.STATUS_CODE||'	'||cur_peo_emp_term.TYPE_CODE||'	'||cur_peo_emp_term.LOCATION_CODE||'	'
		     ||cur_peo_emp_term.JOB_CODE||'	'||cur_peo_emp_term.ORIG_HIRE||'	'||cur_peo_emp_term.LAST_HIRE||'	'
		     ||cur_peo_emp_term.PEO_START_DATE||'	'||cur_peo_emp_term.EMPLOYEE_NUMBER||'	'
		     ||cur_peo_emp_term.WORK_TELEPHONE||'	'||cur_peo_emp_term.MAIL_ADDR1||'	'||cur_peo_emp_term.MAIL_ADDR2||'	'
		     ||cur_peo_emp_term.MAIL_CITY||'	'||cur_peo_emp_term.MAIL_STATE||'	'||cur_peo_emp_term.MAIL_ZIP||'	'
		     ||cur_peo_emp_term.SHIFT_CODE||'	'||'FUTURE_USE1'||'	'||cur_peo_emp_term.PAY_METHOD||'	'||cur_peo_emp_term.EXT_PAY_RATE
		     ||'	'||cur_peo_emp_term.DISCONTINUED;

    v_columns_str := v_columns_str ||'	'||cur_peo_emp_term.STD_HOURS||'	'||cur_peo_emp_term.EIS_FILING_STATUS||'	'||cur_peo_emp_term.FEDERAL_STATUS
                     ||'	'||cur_peo_emp_term.FEDERAL_ALLOWS||'	'||cur_peo_emp_term.EXTRA_FEDERAL||'	'||cur_peo_emp_term.HOME_STATE_STATUS||'	'
		     ||cur_peo_emp_term.HOME_STATE_ALLOWS||'	'||cur_peo_emp_term.HOME_STATE_ADDITIONAL_AMOUNT||'	'||cur_peo_emp_term.WORK_STATE_STATUS
		     ||'	'||cur_peo_emp_term.WORK_STATE_ALLOWS||'	'||cur_peo_emp_term.WORK_STATE_ADDITIONAL_AMOUNT||'	'
		     ||cur_peo_emp_term.OFFICER||'	'||cur_peo_emp_term.DEPT_CODE||'	'||cur_peo_emp_term.FUTURE_USE2||'	'
		     ||cur_peo_emp_term.TERM_CODE||'	'||cur_peo_emp_term.EMAIL_ADDRESS||'	'||cur_peo_emp_term.BENEFIT_GROUP||'	'
		     ||cur_peo_emp_term.USER_FIELD_1||'	'||cur_peo_emp_term.USER_FIELD_2||'	'||cur_peo_emp_term.USER_FIELD_3||'	'
		     ||cur_peo_emp_term.USER_FIELD_4||'	'||cur_peo_emp_term.USER_FIELD_5||'	'||cur_peo_emp_term.ZIP_SUFFIX||'	'
		     ||cur_peo_emp_term.ALT_CALC_HOME_STATE_CODE||'	'||cur_peo_emp_term.ALT_CALC_HOME_WORK_CODE||'	'||cur_peo_emp_term.FUTURE_USE3
		     ||'	'||cur_peo_emp_term.FUTURE_USE4||'	'||cur_peo_emp_term.FUTURE_USE5||'	'||cur_peo_emp_term.EMPLOYEE_1099||'	'
		     ||cur_peo_emp_term.FUTURE_USE6||'	'||cur_peo_emp_term.PAY_GROUP||'	'||cur_peo_emp_term.DIVISION_CODE||'	'
		     ||cur_peo_emp_term.PROJECT_CODE||'	'||cur_peo_emp_term.AUTO_PAY||'	'||cur_peo_emp_term.AUTO_PAY_HOURS||'	'
		     ||cur_peo_emp_term.HOME_STATE_EXEMPT_AMOUNT||'	'||cur_peo_emp_term.HOME_STATE_SECONDARY_AMOUNT||'	'
		     ||cur_peo_emp_term.HOME_STATE_SUPP_AMOUNT||'	'||cur_peo_emp_term.HOME_STATE_EXEMPT_AMOUNT1||'	'
		     ||cur_peo_emp_term.WORK_STATE_SECONDARY_ALLOWS||'	';

    v_columns_str := v_columns_str ||cur_peo_emp_term.WS_SUPP_AMOUNT||'	'||cur_peo_emp_term.PAY_PERIOD||'	'||cur_peo_emp_term.VETERAN||'	'
                     ||cur_peo_emp_term.NEWLY_SEPARATED_VET||'	'||cur_peo_emp_term.SERVICE_MEDAL_VET||'	'||cur_peo_emp_term.OTHER_PROTECTED_VET||'	'
		     ||cur_peo_emp_term.I9_DOCUMENT_TITLE_A||'	'||cur_peo_emp_term.I9_DOCUMENT_NUMBER_A||'	'||cur_peo_emp_term.I9_DOCUMENT_AUTHORITY_A
		     ||'	'||cur_peo_emp_term.I9_EXPIRATION_DATE_A||'	'||cur_peo_emp_term.I9_DOCUMENT_TITLE_B||'	'
		     ||cur_peo_emp_term.I9_DOCUMENT_NUMBER_B||'	'||cur_peo_emp_term.I9_ISSUING_AUTHORITY_B||'	'||cur_peo_emp_term.I9_EXPIRATION_DATE_B
		     ||'	'||cur_peo_emp_term.ALIEN_REG_NO||'	'||cur_peo_emp_term.FICA_EXEMPT||'	'||cur_peo_emp_term.UNION_CODE||'	'
		     ||cur_peo_emp_term.SUPERVISOR_ID||'	'||cur_peo_emp_term.BENE_THRU_DATE||'	'||cur_peo_emp_term.SCHOOL_DISTRICT||'	'
		     ||cur_peo_emp_term.AGRICULTURAL||'	'||cur_peo_emp_term.HOME_PHONE_2||'	'||cur_peo_emp_term.ALT_PAY_RATE_1||'	'
		     ||cur_peo_emp_term.ALT_PAY_RATE_2||'	'||cur_peo_emp_term.ALT_PAY_RATE_3||'	'||cur_peo_emp_term.ALT_PAY_RATE_4||'	'
		     ||cur_peo_emp_term.ALT_PAY_RATE_5||'	'||cur_peo_emp_term.ALT_PAY_RATE_6||'	'||cur_peo_emp_term.ALT_PAY_RATE_7||'	'
		     ||cur_peo_emp_term.ALT_PAY_RATE_8||'	'||cur_peo_emp_term.ALT_PAY_RATE_9||'	'||cur_peo_emp_term.ALT_PAY_RATE_10||'	'
		     ||cur_peo_emp_term.NEW_HIRE_REPORT_DATE||'	'||cur_peo_emp_term.MAIL_CHECK_HOME||'	'||cur_peo_emp_term.W2_ADDRESS_ONE||'	'
		     ||cur_peo_emp_term.W2_ADDRESS_TWO||'	'||cur_peo_emp_term.W2_CITY||'	'||cur_peo_emp_term.W2_STATE||'	'||cur_peo_emp_term.W2_ZIPCODE
		     ||'	'||cur_peo_emp_term.LICENSE_NUMBER||'	'||cur_peo_emp_term.LICENSE_EXPIRE_DATE||'	'||cur_peo_emp_term.LICENSE_STATE
		     ||'	'||cur_peo_emp_term.S_CORP_PRINCIPAL||'	'||cur_peo_emp_term.ELECT_PAY_STUB||'	'||cur_peo_emp_term.ELEC_W2_FORM||'	'
		     ||cur_peo_emp_term.ALLOC_JOBS_1||'	'||cur_peo_emp_term.ALLOC_JOBS_2||'	'||cur_peo_emp_term.ALLOC_JOBS_3||'	'
		     ||cur_peo_emp_term.ALLOC_JOBS_4||'	'||cur_peo_emp_term.ALLOC_JOBS_5||'	'||cur_peo_emp_term.ALLOC_DIVISION_1;

    v_columns_str := v_columns_str||'	'||cur_peo_emp_term.ALLOC_DIVISION_2||'	'||cur_peo_emp_term.ALLOC_DIVISION_3||'	'||cur_peo_emp_term.ALLOC_DIVISION_4
                     ||'	'||cur_peo_emp_term.ALLOC_DIVISION_5||'	'||cur_peo_emp_term.ALLOC_DEPARTMENT_1||'	'||cur_peo_emp_term.ALLOC_DEPARTMENT_2
		     ||'	'||cur_peo_emp_term.ALLOC_DEPARTMENT_3||'	'||cur_peo_emp_term.ALLOC_DEPARTMENT_4||'	'
		     ||cur_peo_emp_term.ALLOC_DEPARTMENT_5||'	'||cur_peo_emp_term.ALLOC_PROJECT_1||'	'||cur_peo_emp_term.ALLOC_PROJECT_2||'	'
		     ||cur_peo_emp_term.ALLOC_PROJECT_3||'	'||cur_peo_emp_term.ALLOC_PROJECT_4||'	'||cur_peo_emp_term.ALLOC_PROJECT_5||'	'
		     ||cur_peo_emp_term.ALLOC_JOB_1||'	'||cur_peo_emp_term.ALLOC_JOB_2||'	'||cur_peo_emp_term.ALLOC_JOB_3||'	'
		     ||cur_peo_emp_term.ALLOC_JOB_4||'	'||cur_peo_emp_term.ALLOC_JOB_5||'	'||cur_peo_emp_term.ONHRP_ONBOARDED||'	'
		     ||cur_peo_emp_term.HANDBK_RCD||'	'||cur_peo_emp_term.AST_REVIEW||'	'||cur_peo_emp_term.NEXT_REVIEW||'	'
		     ||cur_peo_emp_term.NICKNAME;
   --------- New code added by priyanka ends here


    fnd_file.put_line(fnd_file.output,'PEO Employee Terminated : '||v_columns_str);
    TTEC_PEO_EMP_CHNG_EXTRACT.write_process('TELETECH_PEO_EMP_CHANGE_'||v_dt_time||'.txt', v_columns_str,'A',v_path);
  END LOOP;

  EXCEPTION
  WHEN OTHERS THEN
    fnd_file.put_line(fnd_file.log,'Issue in writing file : '||sqlerrm);
    raise;
  END ;
  -- Refreshing Custom Table
  BEGIN
    refresh_XXTTEC_PEO_EMP_CHNG;
  EXCEPTION
  WHEN OTHERS THEN
    fnd_file.put_line(fnd_file.log,'Issue in Refreshing Custom Table XXTTEC_PEO_EMP_CHNG : '||sqlerrm);
    raise;
  END ;
  fnd_file.put_line(fnd_file.log,'PROGRAM SUCCESSFULLY COMPLETED');
EXCEPTION
WHEN OTHERS THEN
  fnd_file.put_line(fnd_file.log,'Program completed with error '||sqlerrm);
  raise;
END main;
PROCEDURE write_process(
    p_file_name IN VARCHAR2,
    p_data      IN VARCHAR2,
    p_mode      IN VARCHAR2,
    p_path      IN VARCHAR2)
AS
  F1 UTL_FILE.FILE_TYPE;
  v_path VARCHAR2(200):=p_path;
BEGIN
  --fnd_file.put_line(fnd_file.log,'extract line : '||p_data);
  F1        := UTL_FILE.FOPEN(v_path,p_file_name,p_mode,32767);
  IF p_data IS NOT NULL THEN
    UTL_FILE.put_line(F1,p_data,false);
    --UTL_FILE.NEW_LINE(F1, 1);
  END IF;
  utl_file.fflush(F1);
  UTL_FILE.FCLOSE(F1);
EXCEPTION
WHEN OTHERS THEN
  fnd_file.put_line(fnd_file.log,'Write_process could not complete successfully: '||sqlerrm||' : '||v_path);
END write_process;
PROCEDURE refresh_XXTTEC_PEO_EMP_CHNG
AS
BEGIN
  EXECUTE IMMEDIATE 'TRUNCATE TABLE CUST.XXTTEC_PEO_EMP_CHNG';
  fnd_file.put_line(fnd_file.log,'Going to insert');
   --  INSERT INTO CUST.XXTTEC_PEO_EMP_CHNG --Commented code by MXKEERTHI-ARGANO,07/17/2023
  INSERT INTO apps.XXTTEC_PEO_EMP_CHNG--code added by MXKEERTHI-ARGANO, 07/17/2023

  SELECT DISTINCT papf.FIRST_NAME,
      papf.LAST_NAME,
      papf.MIDDLE_NAMES,
      to_char(papf.DATE_OF_BIRTH,'MM/DD/YYYY') DATE_OF_BIRTH,
      /*(select segment1
      from PER_ANALYSIS_CRITERIA , PER_PERSON_ANALYSES, FND_ID_FLEX_STRUCTURES_VL
      where PER_ANALYSIS_CRITERIA.ANALYSIS_CRITERIA_ID=PER_PERSON_ANALYSES.ANALYSIS_CRITERIA_ID
      and PER_ANALYSIS_CRITERIA.id_flex_num = FND_ID_FLEX_STRUCTURES_VL.id_flex_num
      and FND_ID_FLEX_STRUCTURES_VL.ID_FLEX_STRUCTURE_NAME like 'Teletech Contingent Worker'
      and PER_PERSON_ANALYSES.person_id = PAPF.PERSON_ID) COMPANY_ID,*/
      '1895' COMPANY_ID,              -- as per mail from Liz Grail GNA
     '26' EMPLOYER_ID, -- as per mail from Liz Grail GNA
      (SELECT DECODE (meaning,'Asian (Not Hispanic or Latino)','A','White (Not Hispanic or Latino)','I','Hispanic or Latino','H','Black or African American (Not Hispanic or Latino)','B','X')
      FROM apps.fnd_lookup_values_vl
      WHERE lookup_type     = 'US_ETHNIC_GROUP'
      AND enabled_flag      = 'Y'
      AND security_group_id = 2
      AND lookup_code       = 1 -- papf.per_information1 -- commented for testing extract
      AND rownum            = 1
      ) ETHNIC_CODE,
    papf.MARITAL_STATUS,
    nvl2(papf.USES_TOBACCO_FLAG,'Y','N') tobacco_user,
    pa.address_line1,
    pa.ADDRESS_LINE2,
    pa.POSTAL_CODE,
    pa.TOWN_OR_CITY,
    pa.REGION_2,
    (SELECT decode(phone_number,'n/a',NULL,phone_number)
    FROM per_phones
    WHERE PARENT_TABLE LIKE 'PER_ALL_PEOPLE_F'
    AND parent_id = papf.person_id
    AND rownum    = 1
    ) TELEPHONE,
    papf.REGISTERED_DISABLED_FLAG HANDICAPPED,
    CAST(NULL AS VARCHAR2(100)) BLIND,
    CAST(NULL AS VARCHAR2(100)) VIETNAM_VET,
    CAST(NULL AS VARCHAR2(100)) DISABLED_VET,
    PAPF.NATIONALITY CITIZEN,
    (DECODE (papf.sex,'M','M','F','F',NULL)) GENDER,
    (SELECT full_name
    FROM PER_CONTACT_RELATIONSHIPS ,
      apps.per_all_people_f
    WHERE PER_CONTACT_RELATIONSHIPS.contact_person_id = per_all_people_f.person_id
    AND TRUNC(sysdate) BETWEEN per_all_people_f.effective_start_date AND per_all_people_f.effective_end_date
    AND PER_CONTACT_RELATIONSHIPS.person_id                                                                    = PAPF.PERSON_ID
    AND (contact_type                                                                                          = 'EMRG'
    OR contact_type                                                                                            = 'S')
    AND apps.hr_person_type_usage_info.get_user_person_type ( sysdate ,PER_CONTACT_RELATIONSHIPS.CONTACT_PERSON_ID) = 'Emergency Contact'
    AND rownum                                                                                                 = 1
    ) EMERGENCY_CONTACT,
    (SELECT PER_PHONES.phone_number
    FROM PER_CONTACT_RELATIONSHIPS ,
      PER_PHONES
    WHERE PER_CONTACT_RELATIONSHIPS.person_id = PAPF.PERSON_ID
      --and contact_type = 'EMRG'
    AND PER_PHONES.PARENT_ID = PER_CONTACT_RELATIONSHIPS.CONTACT_PERSON_ID
    AND PER_PHONES.PARENT_TABLE LIKE 'PER_ALL_PEOPLE_F'
    AND rownum = 1
    ) EMERGENCY_PHONE_NUMBER,
    (SELECT HR_LOOKUPS.MEANING
    FROM PER_CONTACT_RELATIONSHIPS ,
      HR_LOOKUPS
    WHERE PER_CONTACT_RELATIONSHIPS.person_id = papf.person_id
    AND HR_LOOKUPS.LOOKUP_CODE                = PER_CONTACT_RELATIONSHIPS.CONTACT_TYPE
    AND LOOKUP_TYPE                           = 'CONTACT'
    AND ROWNUM                                = 1
    ) EMERGENCY_RELATION,
    papf.NATIONAL_IDENTIFIER SOC_SEC_NUM,
    (SELECT decode(user_status,'Active Assignment','A','T')
    FROM per_assignment_status_types
    WHERE assignment_status_type_id = paaf.assignment_status_type_id
    AND rownum          = 1
    ) STATUS_CODE,
    decode(paaf.EMPLOYMENT_CATEGORY,'FR','F','FT','F','P') TYPE_CODE,
    (select 'REVANA'--location_code --for test data
      from hr_locations where location_id = paaf.location_id AND rownum  = 1) location_code, --as per csv file mapping
    (SELECT 'OSR' --NAME  -- for test data
      FROM PER_JOBS
      WHERE JOB_ID = paaf.JOB_ID AND business_group_id = 325 AND rownum = 1
    ) JOB_CODE, --as per csv file mapping
    to_char(papf.ORIGINAL_DATE_OF_HIRE,'MM/DD/YYYY') ORIG_HIRE,
    to_char(DECODE (papf.effective_start_date,paaf.effective_start_date,papf.effective_start_date,papf.start_date),'MM/DD/YYYY') LAST_HIRE,
    to_char( papf.ORIGINAL_DATE_OF_HIRE,'MM/DD/YYYY') PEO_START_DATE,
    --papf.effective_end_date papf_effective_end_date,
    NVL(papf.employee_number,papf.npw_number) employee_number,
    papf.WORK_TELEPHONE,--
    CAST(NULL AS VARCHAR2(100)) WORK_ext,
    pa.ADDRESS_LINE1 mail_addr1,
    pa.ADDRESS_LINE2 mail_addr2,
    pa.TOWN_OR_CITY mail_city,
    pa.region_2 mail_state,
    pa.postal_code mail_zip,
    --paaf.FREQUENCY SHIFT_CODE,
    CAST(NULL AS VARCHAR2(100)) SHIFT_CODE,
    CAST(NULL AS VARCHAR2(100)) FUTURE_USE1,
    (SELECT decode(pay_basis,'HOURLY','H','ANNUAL','S')
    FROM PER_PAY_BASES
    WHERE pay_basis_id = PAAF.pay_basis_id AND business_group_id = 325
    AND rownum         = 1
    ) PAY_METHOD,-- col 43
    to_char(PAAF.NORMAL_HOURS, 'fm99999999.0000')  EXT_PAY_RATE,
    CAST(NULL AS VARCHAR2(100)) DISCONTINUED,
    to_char(PAAF.NORMAL_HOURS, 'fm99999999.00') STD_HOURS,
    (SELECT decode(MEANING,'Single','S','Married','M')
    FROM PAY_US_EMP_FED_TAX_RULES_f,
      HR_LOOKUPS
    WHERE PAY_US_EMP_FED_TAX_RULES_f.assignment_id    = paaf.assignment_id
    AND HR_LOOKUPS.LOOKUP_TYPE                        = 'US_FIT_FILING_STATUS'
    AND PAY_US_EMP_FED_TAX_RULES_f.FILING_STATUS_CODE = HR_LOOKUPS.LOOKUP_CODE
    AND rownum                                        = 1
    ) EIS_FILING_STATUS, -- Col 47
    (SELECT decode(MEANING,'Single','S','Married','M')
    FROM PAY_US_EMP_FED_TAX_RULES_f,
      HR_LOOKUPS
    WHERE PAY_US_EMP_FED_TAX_RULES_f.assignment_id    = paaf.assignment_id
    AND HR_LOOKUPS.LOOKUP_TYPE                        = 'US_FIT_FILING_STATUS'
    AND PAY_US_EMP_FED_TAX_RULES_f.FILING_STATUS_CODE = HR_LOOKUPS.LOOKUP_CODE
    AND rownum                                        = 1
    ) FEDERAL_STATUS,
    (select WITHHOLDING_ALLOWANCES from PAY_US_EMP_FED_TAX_RULES_f
     where assignment_id = paaf.assignment_id
     AND rownum = 1
    ) FEDERAL_ALLOWS, -- col 49
    CAST(NULL AS VARCHAR2(100)) EXTRA_FEDERAL,
    (SELECT decode(MEANING,'Single','S','Married','M')
    FROM PAY_US_EMP_STATE_TAX_RULES_f,
      HR_LOOKUPS
    WHERE  PAY_US_EMP_STATE_TAX_RULES_f.assignment_id    = paaf.assignment_id
     and HR_LOOKUPS.LOOKUP_TYPE                        = 'US_FIT_FILING_STATUS'
    AND PAY_US_EMP_STATE_TAX_RULES_f.FILING_STATUS_CODE = HR_LOOKUPS.LOOKUP_CODE
    AND rownum = 1) HOME_STATE_STATUS,
    (select WITHHOLDING_ALLOWANCES from PAY_US_EMP_STATE_TAX_RULES_f
     where assignment_id =  paaf.assignment_id AND rownum = 1) HOME_STATE_ALLOWS,
    CAST(NULL AS VARCHAR2(100)) HOME_STATE_ADDITIONAL_AMOUNT,
    CAST(NULL AS VARCHAR2(100)) WORK_STATE_STATUS,
    CAST(NULL AS VARCHAR2(100)) WORK_STATE_ALLOWS,
    CAST(NULL AS VARCHAR2(100)) WORK_STATE_ADDITIONAL_AMOUNT,
    CAST(NULL AS VARCHAR2(100)) OFFICER,
    '010' DEPT_CODE,  --as per csv file mapping
    CAST(NULL AS VARCHAR2(100)) FUTURE_USE2,
    CAST(NULL AS VARCHAR2(100)) TERM_CODE,
    CAST(NULL AS VARCHAR2(100)) EMAIL_ADDRESS,
   --(SELECT payroll_name FROM PAY_ALL_PAYROLLS_F WHERE payroll_id=paaf.payroll_id ) BENEFIT_GROUP,
   '1' BENEFIT_GROUP, --as per csv file mapping
    CAST(NULL AS VARCHAR2(100)) USER_FIELD_1,
    CAST(NULL AS VARCHAR2(100)) USER_FIELD_2,
    CAST(NULL AS VARCHAR2(100)) USER_FIELD_3,
    CAST(NULL AS VARCHAR2(100)) USER_FIELD_4,
    CAST(NULL AS VARCHAR2(100)) USER_FIELD_5,
    CAST(NULL AS VARCHAR2(100)) ZIP_SUFFIX,
    (select decode(SIT_OPTIONAL_CALC_IND,
              '01','11',
              '02','12',
              '03','13',
              '04','14',
              '05','8',
              '06','10',
              '07','9',
              '08','19',
              '09','20')
      from PAY_US_EMP_STATE_TAX_RULES_f where assignment_id =paaf.assignment_id and SIT_OPTIONAL_CALC_IND is not null AND rownum = 1) ALT_CALC_HOME_STATE_CODE,
    CAST(NULL AS VARCHAR2(100)) ALT_CALC_HOME_WORK_CODE, -- COL 70
    CAST(NULL AS VARCHAR2(100)) FUTURE_USE3,
    CAST(NULL AS VARCHAR2(100)) FUTURE_USE4,
    CAST(NULL AS VARCHAR2(100)) FUTURE_USE5,
    CAST(NULL AS VARCHAR2(100)) EMPLOYEE_1099,
    CAST(NULL AS VARCHAR2(100)) FUTURE_USE6,
   (SELECT 'BW'--segment1
    FROM pay_people_groups WHERE
      people_group_id = paaf.people_group_id) PAY_GROUP,-- COL 76 -- --as per csv file mapping
    CAST(NULL AS VARCHAR2(100)) DIVISION_CODE,
    CAST(NULL AS VARCHAR2(100)) PROJECT_CODE,
    nvl2(paaf.normal_hours,'Y','N') AUTO_PAY,-- source??
    paaf.normal_hours AUTO_PAY_HOURS,
    CAST(NULL AS VARCHAR2(100)) HOME_STATE_EXEMPT_AMOUNT,
    CAST(NULL AS VARCHAR2(100)) HOME_STATE_SECONDARY_AMOUNT,
    CAST(NULL AS VARCHAR2(100)) HOME_STATE_SUPP_AMOUNT,
    CAST(NULL AS VARCHAR2(100)) HOME_STATE_EXEMPT_AMOUNT1,
    CAST(NULL AS VARCHAR2(100)) WORK_STATE_SECONDARY_ALLOWS, -- COL 85
    CAST(NULL AS VARCHAR2(100)) WS_SUPP_AMOUNT,
    (SELECT decode(pay_basis,'HOURLY','H','WEEKLY','W','BIWEEKLY','B','SEMIMONTHLY','S','MONTHLY','M','ANNUAL','Y')
    FROM PER_PAY_BASES
    WHERE pay_basis_id = PAAF.pay_basis_id
    AND rownum         = 1
    )  PAY_PERIOD, -- Changed as per attachment in email from Elango/Liz on 6th Dec 2013
    CAST(NULL AS VARCHAR2(100)) VETERAN,
    CAST(NULL AS VARCHAR2(100)) NEWLY_SEPARATED_VET,
    CAST(NULL AS VARCHAR2(100)) SERVICE_MEDAL_VET, -- COL 90
    CAST(NULL AS VARCHAR2(100)) OTHER_PROTECTED_VET,
    CAST(NULL AS VARCHAR2(100)) I9_DOCUMENT_TITLE_A,
    CAST(NULL AS VARCHAR2(100)) I9_DOCUMENT_NUMBER_A,
    CAST(NULL AS VARCHAR2(100)) I9_DOCUMENT_AUTHORITY_A,-- COL 94
    CAST(NULL AS VARCHAR2(100)) I9_EXPIRATION_DATE_A,   -- COL 95
    CAST(NULL AS VARCHAR2(100)) I9_DOCUMENT_TITLE_B,
    CAST(NULL AS VARCHAR2(100)) I9_DOCUMENT_NUMBER_B,
    CAST(NULL AS VARCHAR2(100)) I9_ISSUING_AUTHORITY_B,
    CAST(NULL AS VARCHAR2(100)) I9_EXPIRATION_DATE_B,
    CAST(NULL AS VARCHAR2(100)) ALIEN_REG_NO,
    CAST(NULL AS VARCHAR2(100)) FICA_EXEMPT,
    CAST(NULL AS VARCHAR2(100)) UNION_CODE,
    (select nvl(employee_number,npw_number) from per_all_people_f where person_id = paaf.supervisor_id and rownum = 1) SUPERVISOR_ID,
    CAST(NULL AS VARCHAR2(100)) BENE_THRU_DATE,
    CAST(NULL AS VARCHAR2(100)) SCHOOL_DISTRICT,
    CAST(NULL AS VARCHAR2(100)) AGRICULTURAL,
    CAST(NULL AS VARCHAR2(100)) HOME_PHONE_2,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_1,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_2,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_3,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_4,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_5,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_6,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_7,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_8,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_9,
    CAST(NULL AS VARCHAR2(100)) ALT_PAY_RATE_10,
    CAST(NULL AS VARCHAR2(100)) NEW_HIRE_REPORT_DATE,
    'N' MAIL_CHECK_HOME,-- COL 119
    CAST(NULL AS VARCHAR2(100)) W2_ADDRESS_ONE,
    CAST(NULL AS VARCHAR2(100)) W2_ADDRESS_TWO,
    CAST(NULL AS VARCHAR2(100)) W2_CITY,
    CAST(NULL AS VARCHAR2(100)) W2_STATE,
    CAST(NULL AS VARCHAR2(100)) W2_ZIPCODE,
    CAST(NULL AS VARCHAR2(100)) LICENSE_NUMBER,
    CAST(NULL AS VARCHAR2(100)) LICENSE_EXPIRE_DATE,
    CAST(NULL AS VARCHAR2(100)) LICENSE_STATE,
    CAST(NULL AS VARCHAR2(100)) S_CORP_PRINCIPAL,
    CAST(NULL AS VARCHAR2(100)) ELECT_PAY_STUB,
    CAST(NULL AS VARCHAR2(100)) ELEC_W2_FORM,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOBS_1,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOBS_2,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOBS_3,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOBS_4,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOBS_5, --COL 135
    CAST(NULL AS VARCHAR2(100)) ALLOC_DIVISION_1,
    CAST(NULL AS VARCHAR2(100)) ALLOC_DIVISION_2,
    CAST(NULL AS VARCHAR2(100)) ALLOC_DIVISION_3,
    CAST(NULL AS VARCHAR2(100)) ALLOC_DIVISION_4,
    CAST(NULL AS VARCHAR2(100)) ALLOC_DIVISION_5,
    CAST(NULL AS VARCHAR2(100)) ALLOC_DEPARTMENT_1,
    CAST(NULL AS VARCHAR2(100)) ALLOC_DEPARTMENT_2,
    CAST(NULL AS VARCHAR2(100)) ALLOC_DEPARTMENT_3,
    CAST(NULL AS VARCHAR2(100)) ALLOC_DEPARTMENT_4,
    CAST(NULL AS VARCHAR2(100)) ALLOC_DEPARTMENT_5,
    CAST(NULL AS VARCHAR2(100)) ALLOC_PROJECT_1,
    CAST(NULL AS VARCHAR2(100)) ALLOC_PROJECT_2,
    CAST(NULL AS VARCHAR2(100)) ALLOC_PROJECT_3,
    CAST(NULL AS VARCHAR2(100)) ALLOC_PROJECT_4,
    CAST(NULL AS VARCHAR2(100)) ALLOC_PROJECT_5,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOB_1,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOB_2,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOB_3,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOB_4,
    CAST(NULL AS VARCHAR2(100)) ALLOC_JOB_5,
    CAST(NULL AS VARCHAR2(100)) ONHRP_ONBOARDED,
    CAST(NULL AS VARCHAR2(100)) HANDBK_RCD,
    CAST(NULL AS VARCHAR2(100)) AST_REVIEW,
    CAST(NULL AS VARCHAR2(100)) NEXT_REVIEW,
    CAST(NULL AS VARCHAR2(100)) NICKNAME -- col 165
  FROM apps.per_all_people_f papf,
    apps.per_all_assignments_f paaf,
    apps.per_addresses pa,
    apps.PER_PERIODS_OF_SERVICE ppos
  WHERE
    --nvl(papf.employee_number,papf.npw_number) in ('3160584','3160592') and
    papf.business_group_id = 325 -- /**Need to confirm from Elango **/
  AND ppos.person_id       = papf.person_id
    /*** Date conditions start***/
  AND TRUNC(sysdate) BETWEEN papf.effective_start_date AND papf.effective_end_date
  AND TRUNC(sysdate) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
  AND ppos.date_start =
    (SELECT MAX (PPS1.DATE_START)
    FROM PER_PERIODS_OF_SERVICE PPS1
    WHERE PPS1.PERSON_ID = PAPF.PERSON_ID
    AND PPS1.DATE_START <= PAPF.EFFECTIVE_START_DATE
    )
  AND apps.hr_person_type_usage_info.get_user_person_type ( TRUNC(sysdate), papf.person_id ) = 'PEO Employee'
    -- Date conditions end
  AND TRUNC(ppos.PERSON_ID)    = TRUNC(papf.PERSON_ID)
  AND paaf.person_id           = papf.person_id
  AND paaf.business_group_id   = papf.business_group_id
  AND papf.person_id           = pa.person_id (+) -- outer join if no address is defined for employee
  AND NVL(pa.PRIMARY_FLAG,'Y') = 'Y'
    --and trunc(pa.date_from) between trunc(papf.effective_start_date) and trunc(papf.effective_end_date)-- employee rehired will have different effective_start_date than date_start
  AND TRUNC(NVL(pa.date_from,sysdate)) BETWEEN
    (SELECT TRUNC(MIN(effective_start_date))
    FROM apps.per_all_people_f
    WHERE person_id = papf.person_id
    )
  AND TRUNC(papf.effective_end_date);
  COMMIT;
EXCEPTION
WHEN OTHERS THEN
  fnd_file.put_line(fnd_file.log,'Could not refresh custom table XXTTEC_PEO_EMP_CHNG: '||sqlerrm);
  raise;
END refresh_XXTTEC_PEO_EMP_CHNG;
END TTEC_PEO_EMP_CHNG_EXTRACT;
/
show errors;
/