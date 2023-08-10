create or replace PACKAGE BODY      ttec_phl_philcare_intf_pkg IS
  /*---------------------------------------------------------------------------------------
     Objective    : Interface to extract data for all PHL employees to send to Philcare Vendor enrolled in Medical Plan during open enrollment
   Package spec :ttec_phl_philcare_intf_pkg
   Parameters:
              p_start_date  -- Optional start paramters to run the report if the data is missing for particular dates
              p_end_date  -- Optional end paramters to run the report if the data is missing for particular dates
     MODIFICATION HISTORY
     Person               Version  Date        Comments
     ------------------------------------------------
     TCS                    1.0    11/18/2015 Created
     Elango                 1.1    Commented it out line 342 to 349 to remove contact relationship table for to pull his dependant. It is not getting spouse (Eg ee 2025535 in crp1
   TCS                    1.2    Added contact type  join
   TCS                    1.3    Added for Ticket TASK0300410
   TCS                    1.4    Changed for task TASK0320362
   TCS                    1.5    Added new procedure for AXA Life TASK0304513
   TCS                    1.6
   CTS                    1.7    Added for TASK0346007
   CTS                    1.8   Added for TASK0382259  - Chnages for Rank classification 2017
   CTS                      1.9    Changes made for INC2539188
   CTS                    2.0   Changes made for INC2953194 - PhilCare Dependent not eligible on file
   CTS                    2.1   changes  made for TASK0650595 - SIT override date
   CTS                    2.2   Change made under INC4674661
   Neelofar               2.3  Enhncements added new columns--Indirect/Direct,Department,Positions,
                              --Employee premiums,Employer premiums,Employee Tax,Employer Tax
   RXNETHI-ARGANO         1.0   R12.2 Upgrade Remediation
  *== END ==================================================================================================*/

--function added for 2.1
Function get_tenure_phl(p_hire_date  DATE,
                        p_assignment_id NUMBER
                        )
RETURN NUMBER IS

l_hire_date date;
l_result varchar2(100);
l_tenure number;
l_error_code varchar2(10);
l_err_msg varchar2(100);

BEGIN
l_result := APPS.Get_SIT_Segment(1517,p_assignment_id,TRUNC(SYSDATE),'TTEC_PH_BEN_TENURE_OVERRIDE','SEGMENT1',l_error_code,l_err_msg);

If (l_result = 'EXT_NULL_VALUE' OR l_result is null)THEN
l_hire_date := p_hire_date;
ELSE
l_hire_date := to_date(l_result,'RRRR/MM/DD HH24:MI:SS');
end if;

l_tenure := TRUNC(MONTHS_BETWEEN(trunc(sysdate), l_hire_date) / 12,2);

RETURN l_tenure;

EXCEPTION
when others then
   return -1;

END  get_tenure_phl;

 PROCEDURE main_proc(errbuf             OUT VARCHAR2,
                      retcode            OUT NUMBER,
                      p_output_directory IN VARCHAR2,
                      p_start_date       IN VARCHAR2,
                      p_end_date         IN VARCHAR2) IS
    --    l_contact_name varchar2(100);
    l_bnft_grp_info varchar2(100);
    CURSOR c_emp_rec(p_cut_off_date DATE, p_current_run_date DATE) IS
      SELECT MAX(date_start) date_start,
             MAX(NVL(actual_termination_date, p_current_run_date)) actual_termination_date,
             person_id
        FROM per_periods_of_service ppos
       WHERE business_group_id = 1517
         AND ((TRUNC(ppos.last_update_date) BETWEEN p_cut_off_date AND
             p_current_run_date AND
             ppos.actual_termination_date IS NOT NULL) OR
             (ppos.actual_termination_date IS NULL AND
             ppos.person_id IN
             (SELECT DISTINCT person_id
                  FROM per_all_people_f papf
                 WHERE papf.current_employee_flag = 'Y')) OR
             (ppos.actual_termination_date =
             (SELECT MAX(actual_termination_date)
                  FROM per_periods_of_service
                 WHERE person_id = ppos.person_id
                   AND actual_termination_date IS NOT NULL) AND
             ppos.actual_termination_date >= p_cut_off_date))
      --and rownum < 20
      -- AND ppos.person_id IN (339170)
       GROUP BY person_id;

    CURSOR c_emp_info(p_person_id NUMBER, p_actual_termination_date DATE, p_contact_person_id NUMBER, p_emp_or_dep VARCHAR2) IS
      SELECT DISTINCT papf.person_id,
                      NULL contact_person_id,
                      paaf.assignment_id,
                      papf.employee_number,
                      papf.date_of_birth,
                      translate(papf.national_identifier, '0-', '0') national_identifier,
                      translate(papf.national_identifier, '0-', '0') member_ssn,
                      papf.first_name,
                      papf.suffix, --v1.3
                      papf.last_name,
                      papf.email_address,
                      papf.middle_names middle_names,
                      TO_CHAR(papf.date_of_birth, 'YYYYMMDD') dob,
                      hr_general.decode_lookup('MARITAL_STATUS',
                                               papf.marital_status) civil_status,
                      TO_CHAR(papf.start_date, 'YYYYMMDD') start_date,
                      papf.sex,
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
                      past.user_status,
                      ppt.user_person_type,
                      ppos.actual_termination_date actual_term_date,
                      ppos.date_start emp_hire_date,
                      paaf.employment_category,
                      'E' per_type,
                      'Employee' contact_type,
                      papf.registered_disabled_flag,
                      papf.employee_number subscriber_employee_number,
                      hla.location_code,
                     -- get_tenure_phl(PPOS.DATE_START,paaf.assignment_id) tenure,
                     -- TRUNC(MONTHS_BETWEEN(trunc(sysdate), PPOS.DATE_START) / 12,
                    --        2) tenure,
                      province.description,
                      marital_status_lk.marital_status,
                      job.attribute2,
                      job.attribute4,
                      job.attribute5,
                      job.attribute6,
                      sup.last_name || ', ' || sup.first_name supervisor_name,
                      ppb.name pay_basis_name --V1.3
                     -----------------below code added as part of 2.3-------
                       ,haou.name dept_name
                      ,nvl((SELECT DESCRIPTION
                FROM apps.fnd_lookup_values l
               WHERE l.lookup_type = 'TTEC_DIRECT_INDIRECT_PHILCARE'
                 AND enabled_flag = 'Y'
                   AND LANGUAGE = 'US'
                 AND l.lookup_code IN (substr(trim(haou.name),-3,3))),'Direct')Indirect_or_Direct,
job.name job_name,
case when  TRUNC(MONTHS_BETWEEN(trunc(sysdate), PPOS.DATE_START) / 12,
                            2)<3 then
                            'less than 3 years'
                            else 'more than 3 years'
                            end tenure_desc,
                            papf.benefit_group_id
                            /*,
                                   (SELECT distinct
(PEEVF.SCREEN_ENTRY_VALUE*(12/100)) "Entry Values"
FROM
PAY_ELEMENT_TYPES_F PETF ,
PAY_ELEMENT_ENTRIES_F PEEF ,
PAY_ELEMENT_ENTRY_VALUES_F PEEVF ,
PAY_INPUT_VALUES_F PIVF
WHERE 1 = 1
AND PEEF.ELEMENT_TYPE_ID = PETF.ELEMENT_TYPE_ID
AND TRUNC(SYSDATE) BETWEEN TRUNC(PEEF.EFFECTIVE_START_DATE) AND TRUNC(PEEF.EFFECTIVE_END_DATE)
AND TRUNC(SYSDATE) BETWEEN TRUNC(PIVF.EFFECTIVE_START_DATE) AND TRUNC(PIVF.EFFECTIVE_END_DATE)
AND PAAF.ASSIGNMENT_ID = PEEF.ASSIGNMENT_ID
AND PEEVF.ELEMENT_ENTRY_ID = PEEF.ELEMENT_ENTRY_ID
AND PIVF.INPUT_VALUE_ID = PEEVF.INPUT_VALUE_ID
AND TRUNC(SYSDATE) BETWEEN TRUNC(PEEVF.EFFECTIVE_START_DATE) AND TRUNC(PEEVF.EFFECTIVE_END_DATE)
AND PETF.ELEMENT_NAME = 'HMO Medical Deduction'--HMO Medical Deduction
--and papf.employee_number='2004318'
and pivf.name='Amount')Employee_Tax,
                            (SELECT distinct
(PEEVF.SCREEN_ENTRY_VALUE*(12/100)) "Entry Values"
FROM
PAY_ELEMENT_TYPES_F PETF ,
PAY_ELEMENT_ENTRIES_F PEEF ,
PAY_ELEMENT_ENTRY_VALUES_F PEEVF ,
PAY_INPUT_VALUES_F PIVF
WHERE 1 = 1
AND PEEF.ELEMENT_TYPE_ID = PETF.ELEMENT_TYPE_ID
AND TRUNC(SYSDATE) BETWEEN TRUNC(PEEF.EFFECTIVE_START_DATE) AND TRUNC(PEEF.EFFECTIVE_END_DATE)
AND TRUNC(SYSDATE) BETWEEN TRUNC(PIVF.EFFECTIVE_START_DATE) AND TRUNC(PIVF.EFFECTIVE_END_DATE)
AND PAAF.ASSIGNMENT_ID = PEEF.ASSIGNMENT_ID
AND PEEVF.ELEMENT_ENTRY_ID = PEEF.ELEMENT_ENTRY_ID
AND PIVF.INPUT_VALUE_ID = PEEVF.INPUT_VALUE_ID
AND TRUNC(SYSDATE) BETWEEN TRUNC(PEEVF.EFFECTIVE_START_DATE) AND TRUNC(PEEVF.EFFECTIVE_END_DATE)
AND PETF.ELEMENT_NAME = 'HMO ER Medical Deduction'--HMO Medical Deduction
--and papf.employee_number='2004318'
and pivf.name='Amount')Employer_Tax*/

                            -----------------above code added as part of 2.3-------
        FROM apps.per_all_people_f            papf,
             apps.per_all_assignments_f       paaf,
             apps.per_periods_of_service      ppos,
             apps.per_person_type_usages_f    pptuf,
             apps.per_person_types            ppt,
             apps.per_addresses               pad,
             apps.per_phones                  pp,
             apps.per_assignment_status_types past,
             apps.per_jobs                    job,
             apps.per_all_people_f            sup,
             apps.per_pay_bases               ppb,

             hr_locations hla,
             (SELECT FLEX_vALUE, FLEX_DESC.DESCRIPTION
                FROM FND_FLEX_VALUES     V,
                     FND_FLEX_VALUE_SETS S,
                     FND_FLEX_VALUES_TL  FLEX_DESC
               WHERE V.FLEX_VALUE_SET_ID = S.FLEX_VALUE_sET_ID
                 AND S.FLEX_VALUE_SET_NAME = 'TELETECH_PHL_PROVINCES_VS'
                 AND FLEX_DESC.FLEX_VALUE_ID = V.FLEX_VALUE_ID
                 AND FLEX_DESC.LANGUAGE = 'US') province,
             (SELECT DISTINCT UPPER(l.lookup_code) code,
                              l.meaning marital_status
                FROM apps.fnd_lookup_values l
               WHERE l.lookup_type = 'MARITAL_STATUS'
                 AND enabled_flag = 'Y'
                 AND LANGUAGE = 'US') marital_status_lk
  ,hr_all_organization_units haou ---added as part of 2.3-------
       WHERE papf.person_id = paaf.person_id
            -- and papf.employee_number='2138616'--testing
         AND paaf.location_id = hla.location_id
         AND hla.inactive_date IS NULL
            --V1. Added Supervisor
         AND paaf.supervisor_id = sup.person_id(+)
         AND p_actual_termination_date BETWEEN sup.effective_start_date(+) AND
             sup.effective_end_date
         AND paaf.pay_basis_id = ppb.pay_basis_id

         AND PAPF.marital_status = marital_status_lk.code(+)

         AND paaf.person_id = ppos.person_id
         AND pptuf.person_id = papf.person_id
         AND papf.person_id = pad.person_id(+)
         AND ppt.person_type_id = pptuf.person_type_id
         AND UPPER(ppt.system_person_type) = 'EMP'
         AND ppos.period_of_service_id = paaf.period_of_service_id
         AND paaf.primary_flag = 'Y'
         AND papf.business_group_id <> 0
         AND papf.business_group_id = 1517
            /* AND past.user_status NOT IN
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          ('Detail NTE', 'End', 'TTEC Awaiting integration')*/

         AND papf.current_employee_flag = 'Y'
         AND province.flex_value(+) = pad.region_1
         AND pad.primary_flag(+) = 'Y'
         AND papf.person_id = pp.parent_id(+)
         AND pp.phone_type(+) = 'H1'
         AND paaf.assignment_status_type_id =
             past.assignment_status_type_id
         AND papf.person_id = p_person_id
         AND past.active_flag = 'Y'
         AND p_actual_termination_date BETWEEN pp.date_from(+) AND
             NVL(pp.date_to(+), p_actual_termination_date)
         AND p_actual_termination_date BETWEEN pptuf.effective_start_date AND
             pptuf.effective_end_date
         AND p_actual_termination_date BETWEEN papf.effective_start_date AND
             papf.effective_end_date
         AND p_actual_termination_date BETWEEN paaf.effective_start_date AND
             paaf.effective_end_date
         AND p_actual_termination_date BETWEEN pad.date_from(+) AND
             NVL(pad.date_to(+), p_actual_termination_date)
         AND p_actual_termination_date BETWEEN ppos.date_start AND
             NVL(ppos.actual_termination_date, p_actual_termination_date)
         AND p_emp_or_dep = 'E'
         AND job.job_id = paaf.job_id
          AND haou.ORGANIZATION_ID=paaf.ORGANIZATION_ID --added for 2.3
         AND p_actual_termination_date BETWEEN paaf.effective_start_date AND
             paaf.effective_end_date
      UNION
      SELECT DISTINCT papf.person_id,
                      pcr.contact_person_id,
                      paaf.assignment_id,
                      papf.employee_number,
                      papfc.date_of_birth,
                      translate(papf.national_identifier, '0-', '0') national_identifier,
                      translate(papfc.national_identifier, '0-', '0') member_ssn,
                      papfc.first_name,
                      papfc.suffix, --v1.3
                      papfc.last_name,
                      papf.email_address,
                      substr(papfc.middle_names, 1, 1) middle_names,
                      TO_CHAR(papfc.date_of_birth, 'YYYYMMDD') dob,
                      hr_general.decode_lookup('MARITAL_STATUS',
                                               papfc.marital_status) civil_status,
                      TO_CHAR(papf.start_date, 'YYYYMMDD') start_date,
                      papfc.sex,
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
                      past.user_status,
                      ppt.user_person_type,
                      ppos.actual_termination_date actual_term_date,
                      ppos.date_start emp_hire_date,
                      paaf.employment_category,
                      'D' per_type,
                      hr_general.decode_lookup('CONTACT', pcr.contact_type) contact_type,
                      papfc.registered_disabled_flag,
                      papf.employee_number subscriber_employee_number,
                      hla.location_code,
                      --get_tenure_phl(PPOS.DATE_START,paaf.assignment_id) tenure,
                     -- TRUNC(MONTHS_BETWEEN(trunc(sysdate), PPOS.DATE_START) / 12,
                       --     2) tenure,
                      province.description,
                      marital_status_lk.marital_status,
                      job.attribute2,
                      job.attribute4,
                      job.attribute5,
                      job.attribute6,
                      sup.last_name || ', ' || sup.first_name supervisor_name, --v1.3
                      ppb.name pay_basis_name,-----------------below code added as part of 2.3-------
                       NULL dept_name,
                       NULL Indirect_or_Direct,
                       NULL job_name,
                       NULL tenure_desc,
                       NULL benefit_group_id /*,
                       NULL Employee_Tax,
                       NULL Employer_Tax*/

                            -----------------above code added as part of 2.3-------
        FROM apps.per_all_people_f papf,
             apps.per_all_assignments_f paaf,
             apps.per_all_people_f sup,
             apps.per_periods_of_service ppos,
             apps.per_person_type_usages_f pptuf,
             apps.per_person_types ppt,
             apps.per_addresses pad,
             apps.per_phones pp,
             apps.per_assignment_status_types past,
             apps.per_contact_relationships pcr,
             apps.per_all_people_f papfc,
             hr_locations hla,
             apps.per_pay_bases ppb,
             apps.per_jobs job,
             (SELECT FLEX_vALUE, FLEX_DESC.DESCRIPTION
                FROM FND_FLEX_VALUES     V,
                     FND_FLEX_VALUE_SETS S,
                     FND_FLEX_VALUES_TL  FLEX_DESC
               WHERE V.FLEX_VALUE_SET_ID = S.FLEX_VALUE_sET_ID
                 AND S.FLEX_VALUE_SET_NAME = 'TELETECH_PHL_PROVINCES_VS'
                 AND FLEX_DESC.FLEX_VALUE_ID = V.FLEX_VALUE_ID
                 AND FLEX_DESC.LANGUAGE = 'US') province,
             (SELECT DISTINCT UPPER(l.lookup_code) code,
                              l.meaning marital_status
                FROM apps.fnd_lookup_values l
               WHERE l.lookup_type = 'MARITAL_STATUS'
                 AND enabled_flag = 'Y'
                 AND LANGUAGE = 'US') marital_status_lk
         ,hr_all_organization_units haou----added as part of 2.3-------
       WHERE papf.person_id = paaf.person_id
           -- and papf.employee_number IN('2012777','2086585')--testing
            -- and papf.employee_number='2138616'--testing
         AND paaf.person_id = ppos.person_id
         AND paaf.location_id = hla.location_id
         AND hla.inactive_date IS NULL
            --v1.3 changes
         AND paaf.supervisor_id = sup.person_id(+)
         AND p_actual_termination_date BETWEEN sup.effective_start_date(+) AND
             sup.effective_end_date
         AND paaf.pay_basis_id = ppb.pay_basis_id

         AND PAPFc.marital_status = marital_status_lk.code(+)

         AND pptuf.person_id = papf.person_id
         AND province.flex_value(+) = pad.region_1
         AND papf.person_id = pad.person_id(+)
         AND ppt.person_type_id = pptuf.person_type_id
         AND UPPER(ppt.system_person_type) = 'EMP'
         AND ppos.period_of_service_id = paaf.period_of_service_id
         AND paaf.primary_flag = 'Y'
         AND papf.business_group_id <> 0
         AND papf.business_group_id = 1517

            /* AND past.user_status NOT IN
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 ('Detail NTE', 'End', 'TTEC Awaiting integration')*/

         AND papf.current_employee_flag = 'Y'
         AND pad.primary_flag(+) = 'Y'
         AND papf.person_id = pp.parent_id(+)
         AND pp.phone_type(+) = 'H1'
         AND paaf.assignment_status_type_id =
             past.assignment_status_type_id
         AND papf.person_id = p_person_id
         AND papfc.person_id = p_contact_person_id
         AND p_emp_or_dep = 'D'
         AND past.active_flag = 'Y'
         AND p_actual_termination_date BETWEEN pp.date_from(+) AND
             NVL(pp.date_to(+), p_actual_termination_date)
         AND p_actual_termination_date BETWEEN pptuf.effective_start_date AND
             pptuf.effective_end_date
         AND p_actual_termination_date BETWEEN papf.effective_start_date AND
             papf.effective_end_date
         AND p_actual_termination_date BETWEEN paaf.effective_start_date AND
             paaf.effective_end_date
         AND p_actual_termination_date BETWEEN paaf.effective_start_date AND
             paaf.effective_end_date
         and job.job_id = paaf.job_id
         AND haou.ORGANIZATION_ID=paaf.ORGANIZATION_ID --added for 2.3
         AND p_actual_termination_date BETWEEN pad.date_from(+) AND
             NVL(pad.date_to(+), p_actual_termination_date)
         AND p_actual_termination_date BETWEEN ppos.date_start AND
             NVL(ppos.actual_termination_date, p_actual_termination_date)
         AND pcr.person_id = papf.person_id
         AND pcr.contact_person_id = papfc.person_id
         AND pcr.contact_type IN ('A', 'BROTHER', 'C', 'D', 'JP_FT', 'JP_MT', 'O', 'P', 'R', 'S',
              'SISTER', 'T') --v1.2
            /* AND pcr.contact_type IN ('R', 'A', 'S', 'C', 'D', 'O', 'T', 'LW')
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 AND pcr.date_start =
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     (SELECT MAX(date_start)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        FROM per_contact_relationships
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       WHERE contact_person_id = pcr.contact_person_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         AND contact_type IN
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             ('R', 'A', 'S', 'C', 'D', 'O', 'T', 'LW')
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         AND person_id = papf.person_id) */

         AND p_actual_termination_date BETWEEN papfc.effective_start_date AND
             papfc.effective_end_date

       ORDER BY 1;

    CURSOR c_bnft_info(p_person_id IN NUMBER, p_start_date IN DATE, p_end_date IN DATE) IS
      select pen.bnft_amt,
             ppf.employee_number,
             ppf.current_employee_flag,
             pen.person_id,
             pen.enrt_cvg_strt_dt,
             pen.orgnl_enrt_dt,
             pen.enrt_cvg_thru_dt,
             pen.pl_id,
             ben_batch_utils.get_pl_name(pln.pl_id, 1517, p_end_date) pl_name,

             'E' type_of_rec,

             pen.person_id dpnt_person_id,
             opt.name,
             pln.name plan_name
        from ben_pl_f             pln,
             ben_prtt_enrt_rslt_f pen,
             ben_per_in_ler       pil,
             per_all_people_f     ppf,
             ben_opt_f            opt,
             ben_oipl_f           oipl
       where p_end_date between pln.effective_start_date and
             pln.effective_end_date
         and trunc(sysdate) between ppf.effective_start_date and
             ppf.effective_end_Date
         and pen.oipl_id = oipl.oipl_id
         and oipl.pl_id = pln.pl_id
         and oipl.opt_id = opt.opt_id
         and pen.person_id = ppf.person_id
         and pln.business_group_id = 1517
         and pln.pl_stat_cd = 'A'
         and pln.pl_id = pen.pl_id(+)
         and pen.prtt_enrt_rslt_stat_cd is null
         and pen.business_group_id(+) = 1517
         and nvl(pen.enrt_cvg_thru_dt, p_end_date) <=
             nvl(pen.effective_end_date, p_end_date)
         and pen.sspndd_flag(+) = 'N'
         and pil.per_in_ler_id(+) = pen.per_in_ler_id
         and pen.person_id = p_person_id
         and (pil.per_in_ler_stat_cd in ('STRTD', 'PROCD') or
             pil.per_in_ler_stat_cd is null)
         and (p_start_date between pen.enrt_cvg_strt_dt and
             pen.enrt_cvg_thru_dt or
             p_end_date between pen.enrt_cvg_strt_dt and
             pen.enrt_cvg_thru_dt or (p_start_date >= pen.enrt_cvg_strt_dt and
             p_end_date <= pen.enrt_cvg_thru_dt) or
             (p_start_date <= pen.enrt_cvg_strt_dt and
             p_end_date >= pen.enrt_cvg_thru_dt) or
             pen.enrt_cvg_strt_dt is null and pen.enrt_cvg_thru_dt is null)
         AND pln.pl_id in
             (select pl_id
                from ben_pl_f
               where business_group_id = 1517
                 and name in ('PhilCare HMO', 'Voluntary Dependent'))
         AND opt.name <> 'Waive'
         and trunc(sysdate) between oipl.effective_start_Date and oipl.effective_end_Date --added for INC2539188
         AND NOT EXISTS
       (SELECT 1
                FROM ben_prtt_enrt_rslt_f pen1
               where pen.person_id = pen1.person_id
                 and pen1.prtt_enrt_rslt_stat_cd is null
                 and pen1.prtt_enrt_rslt_id <> pen.prtt_enrt_rslt_id
                 and pen1.business_group_id(+) = 1517
                 and pen.enrt_cvg_strt_dt < pen1.enrt_cvg_strt_dt --changed for INC2539188
		 and nvl(pen1.enrt_cvg_thru_dt, p_end_date) <= nvl(pen1.effective_end_date, p_end_date)--change 2.2
                 and nvl(pen.bnft_amt, -1) = nvl(pen1.bnft_amt, -1)
                 and pen.pl_id = pen1.pl_id
                 --added for INC2539188
                 and (p_start_date between pen1.enrt_cvg_strt_dt and
                    pen1.enrt_cvg_thru_dt or
                    p_end_date between pen1.enrt_cvg_strt_dt and
                    pen1.enrt_cvg_thru_dt or (p_start_date >= pen1.enrt_cvg_strt_dt and
                    p_end_date <= pen1.enrt_cvg_thru_dt) or
                    (p_start_date <= pen1.enrt_cvg_strt_dt and
                    p_end_date >= pen1.enrt_cvg_thru_dt) or
                    pen1.enrt_cvg_strt_dt is null and pen1.enrt_cvg_thru_dt is null)
        )
             --added for INC2539188
      UNION
      select pen.bnft_amt,
             ppf.employee_number,
             ppf.current_employee_flag,
             pen.person_id,

             dpnt.cvg_strt_dt enrl_cvg_strt_dt,

             pen.orgnl_enrt_dt,
             least(dpnt.cvg_thru_dt,pen.enrt_cvg_thru_dt) enrl_cvg_thru_dt, --2.0
             pen.pl_id,
             ben_batch_utils.get_pl_name(pln.pl_id, 1517, p_end_date) pl_name,
             'D' type_of_rec,

             dpnt.dpnt_person_id,
             opt.name,
             pln.name plan_name

        from ben_pl_f                 pln,
             ben_prtt_enrt_rslt_f     pen,
             --ben.ben_elig_cvrd_dpnt_f dpnt,  --code commented by RXNETHI-ARGANO,18/05/23
             apps.ben_elig_cvrd_dpnt_f dpnt,    --code added by RXNETHI-ARGANO,18/05/23
             per_all_people_f         ppf,
             ben_opt_f                opt,
             ben_oipl_f               oipl
       where p_end_date between pln.effective_start_date and
             pln.effective_end_date
         and pen.person_id = ppf.person_id
         /*Changes 2.0*/
         and pen.ENRT_CVG_STRT_DT between opt.effective_start_date and opt.effective_end_date
         and pen.ENRT_CVG_STRT_DT between oipl.effective_start_date and oipl.effective_end_date
         /*Changes 2.0*/
         and trunc(sysdate) between ppf.effective_start_date and
             ppf.effective_end_Date
         and pln.business_group_id = 1517
         and pln.pl_stat_cd = 'A'
         and pln.pl_id = pen.pl_id(+)
         and pen.oipl_id = oipl.oipl_id
         and oipl.pl_id = pen.pl_id
         and pen.prtt_enrt_rslt_stat_cd is null
         and pen.business_group_id(+) = 1517
            /*         AND p_effective_date BETWEEN dpnt.cvg_strt_dt AND Nvl(dpnt.cvg_thru_dt,p_effective_date)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            AND (Nvl(dpnt.cvg_thru_dt,p_effective_date) <= dpnt.effective_end_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            OR p_effective_date BETWEEN dpnt.effective_start_date AND dpnt.effective_end_date)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            */

         and (nvl(dpnt.cvg_thru_dt, dpnt.effective_end_date) <=
             dpnt.effective_end_date OR
             dpnt.effective_end_date = to_date('31/12/4712', 'dd/mm/yyyy'))

         AND pen.prtt_enrt_rslt_id = dpnt.prtt_enrt_rslt_id
         and pen.person_id = p_person_id
         and oipl.opt_id = opt.opt_id
            --  and ppf.employee_number='3002297'
         AND EXISTS
       (SELECT dep.per_in_ler_id
                FROM ben_per_in_ler dep
               WHERE dep.per_in_ler_id = pen.per_in_ler_id
                 AND dep.business_group_id = 1517
                 AND (dep.per_in_ler_stat_cd in ('STRTD', 'PROCD') or
                     dep.per_in_ler_stat_cd is null))
         and pen.sspndd_flag(+) = 'N'
         AND dpnt.cvg_strt_dt <= p_end_date
         and nvl(dpnt.cvg_thru_dt, p_end_date) >= p_start_date
         AND dpnt.cvg_strt_dt <= nvl(dpnt.cvg_thru_dt, p_end_date) --Added for v1.4
         AND opt.name <> 'Waive'
         AND pln.pl_id in
             (select pl_id
                from ben_pl_f
               where business_group_id = 1517
                 and name in ('PhilCare HMO', 'Voluntary Dependent'))
         /* Changes 2.0*/
         AND (p_start_date between pen.enrt_cvg_strt_dt and
             pen.enrt_cvg_thru_dt or
             p_end_date between pen.enrt_cvg_strt_dt and
             pen.enrt_cvg_thru_dt or (p_start_date >= pen.enrt_cvg_strt_dt and
             p_end_date <= pen.enrt_cvg_thru_dt) or
             (p_start_date <= pen.enrt_cvg_strt_dt and
             p_end_date >= pen.enrt_cvg_thru_dt) or
             pen.enrt_cvg_strt_dt is null and pen.enrt_cvg_thru_dt is null)
         and (nvl(pen.enrt_cvg_thru_dt, pen.effective_end_date) <=
             pen.effective_end_date OR
             pen.effective_end_date = to_date('31/12/4712', 'dd/mm/yyyy'));
          /* Changes 2.0*/
    CURSOR c_host IS
      SELECT host_name, instance_name FROM v$instance;

    v_text      VARCHAR(32765) DEFAULT '';
    v_text_hmo  VARCHAR(32765) DEFAULT '';
    v_file_extn VARCHAR2(200) DEFAULT '';
    v_time      VARCHAR2(20);

    l_hmo_active_file VARCHAR2(200) DEFAULT '';

    l_vol_dpnt_active_file VARCHAR2(200) DEFAULT '';

    v_hmo_file_type UTL_FILE.file_type;

    v_vol_dpnt_file_type UTL_FILE.file_type;

    v_cut_off_date     DATE;
    v_current_run_date DATE;
    l_skip_record      VARCHAR2(1); --v1.3

    v_cnt NUMBER DEFAULT 0;

    v_not_eli_fsa     VARCHAR2(1) DEFAULT '';
    V_hmo_elig_count  number;
    V_dpnt_elig_count number;

    l_contact_type        VARCHAR2(2) DEFAULT '';
    l_term_already_exists VARCHAR2(1);

    l_enrt_cvg_thru_dt VARCHAR2(11);
    l_host_name        v$instance.host_name%TYPE;
    l_instance_name    v$instance.instance_name%TYPE;
    l_identifier       VARCHAR2(10);

    l_opt_name      BEN_opt_f.name%TYPE;
    l_bnft_grp_name BEN_BENFTS_GRP.name%TYPE;
    l_mgr_type      BEN_BENFTS_GRP.name%TYPE;
    l_error_step    VARCHAR2(10);
    l_tenure number; --added for  2.1
l_employee_premium number; --added for  2.3
l_employer_premium number;--added for  2.3
l_employee_tax number;--added for  2.3
l_employer_tax number;--added for  2.3
  BEGIN

    IF p_start_date IS NULL OR p_end_date IS NULL THEN
      v_current_run_date := TRUNC(SYSDATE);
    ELSE
      -- v_cut_off_date     := TO_DATE(p_start_date, 'YYYY/MM/DD HH24:MI:SS');
      v_current_run_date := TO_DATE(p_end_date, 'YYYY/MM/DD HH24:MI:SS');
    END IF;

    v_cut_off_date := TRUNC(v_current_run_date, 'YYYY');

    --v_cut_off_date     := TO_DATE(p_start_date, 'YYYY/MM/DD HH24:MI:SS');
    --v_current_run_date := TO_DATE(p_end_date, 'YYYY/MM/DD HH24:MI:SS');
    V_hmo_elig_count  := 0;
    V_dpnt_elig_count := 0;

    v_cnt := 0;
    OPEN c_host;
    FETCH c_host
      INTO l_host_name, l_instance_name;
    CLOSE c_host;
    IF l_host_name not IN (ttec_library.XX_TTEC_PROD_HOST_NAME) THEN
      -- IF l_host_name = 'den-erp046' then
      l_identifier := 'T';

    ELSE
      l_identifier := 'P';

    END IF;

    BEGIN
      SELECT DECODE(l_identifier, 'T', '.tst', '.txt'),
             to_char(sysdate, 'MMDDYYYY_HH24MI')

        INTO v_file_extn, v_time
        FROM v$instance;
    EXCEPTION
      WHEN OTHERS THEN
        v_file_extn := '.tst';
    END;

    l_hmo_active_file      := 'hmo_' || v_time || v_file_extn;
    l_vol_dpnt_active_file := 'vol_dpnt_' || v_time || v_file_extn;

    v_hmo_file_type := UTL_FILE.fopen(p_output_directory,
                                      l_hmo_active_file,
                                      'w',
                                      32765);

    v_vol_dpnt_file_type := UTL_FILE.fopen(p_output_directory,
                                           l_vol_dpnt_active_file,
                                           'w',
                                           32765);
    -- 1.3 version change
    v_text     := 'Agreement No|Sub Office Code|Supervisor Name|Employee No|Coverage Effective Date|Coverage End Date|Last Name|Suffix|First Name|M.I.|Date of Birth|Relation|House No/Street|Bgy/District|City/Province|Region|Gender|Civil Status|Class Code|Request For';--|Indirect/Direct|Department|Positions|Employee premiums|Employer premiums|Employee Tax|Employer Tax';
    v_text_hmo := 'Agreement No|Sub Office Code|Supervisor Name|Employee No|Coverage Effective Date|Coverage End Date|Last Name|Suffix|First Name|M.I.|Date of Birth|Relation|House No/Street|Bgy/District|City/Province|Region|Gender|Civil Status|Class Code|Request For|Rank Classification|Indirect/Direct|Department|Positions|EE Dep Premiums|ER Dep Premiums|EE Dep Tax|ER Dep Tax';
    UTL_FILE.put_line(v_hmo_file_type, v_text_hmo);
    UTL_FILE.put_line(v_vol_dpnt_file_type, v_text);
    fnd_file.put_line(fnd_file.output, v_text);
    FOR r_emp_rec IN c_emp_rec(v_cut_off_date, v_current_run_date) LOOP
      v_text := '';

      --fnd_file.put_line(fnd_file.output, 'r_emp_rec.person_id'||r_emp_rec.person_id);

      FOR r_bnft_info IN c_bnft_info(r_emp_rec.person_id,
                                     --v_pl_id,
                                     -- r_emp_info.per_type,
                                     v_cut_off_date,
                                     v_current_run_Date) LOOP
        --  fnd_file.put_line(fnd_file.output, ' r_bnft_info.person_id'||r_bnft_info.person_id);

        FOR r_emp_info IN c_emp_info(r_emp_rec.person_id,
                                     r_emp_rec.actual_termination_date,

                                     r_bnft_info.dpnt_person_id,
                                     r_bnft_info.type_of_rec) LOOP

          l_contact_type := '';
          -- fnd_file.put_line(fnd_file.output, ' r_emp_info.contact_type'||r_emp_info.contact_type);
          l_term_already_exists := '';

          l_skip_record := 'N'; --v1.3 added
          l_tenure := 0; --added for  2.1

          l_tenure := get_tenure_phl(r_emp_info.emp_hire_date,r_emp_info.assignment_id) ;--added for  2.1

          IF (nvl(r_bnft_info.enrt_cvg_thru_dt,
                  TO_DATE('31/12/4712', 'DD/MM/YYYY')) =
             TO_DATE('31/12/4712', 'DD/MM/YYYY') or
             r_bnft_info.enrt_cvg_thru_dt > trunc(sysdate) + 14) THEN
            --v1.3
            l_enrt_cvg_thru_dt := NULL;
          ELSE
            l_enrt_cvg_thru_dt := TO_CHAR(r_bnft_info.enrt_cvg_thru_dt,
                                          'DD-MON-YYYY');
          END IF;

          l_opt_name := r_bnft_info.name;

          BEGIN
            select name
              INTO l_bnft_grp_name
              from per_all_people_f ppf, BEN_BENFTS_GRP grp
             WHERE grp.BENFTS_GRP_ID = ppf.benefit_group_id
               and grp.BUSINESS_GROUP_ID = 1517
               AND r_emp_rec.actual_termination_date BETWEEN
                   ppf.effective_start_date and ppf.effective_end_Date
               AND ppf.person_id = r_emp_rec.person_id;
          EXCEPTION
            WHEN OTHERS THEN
              l_bnft_grp_name := '';
          END;

          -- Code Start to support old option names
          IF r_bnft_info.name LIKE '%Manager+%' /*and
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     UPPER(r_emp_info.attribute6) NOT in
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     ('SUPERVISOR 1', 'SUPERVISOR 2', 'NON-MANAGER')*/

           THEN

            IF l_bnft_grp_name = 'Manager Benefits' or
               l_bnft_grp_name IS NULL THEN
              l_mgr_type := 'Manager';
            ELSIF l_bnft_grp_name = 'Sr. Manager Benefits' THEN
              l_mgr_type := 'Sr. Manager';
            ELSIF l_bnft_grp_name LIKE 'Director%Benefits' THEN
              l_mgr_type := 'Director';
            END IF;

            SELECT replace(r_bnft_info.name, 'Manager+', l_mgr_type)
              INTO l_opt_name
              FROM DUAL;

          END IF;

          -- Code End to support old option names
          -- Code Start to support new option names

          IF l_bnft_grp_name = 'Manager Benefits' THEN

            l_mgr_type := 'Manager';
          ELSIF l_bnft_grp_name = 'Sr. Manager Benefits' THEN
            l_mgr_type := 'Sr. Manager';
          ELSIF l_bnft_grp_name LIKE 'Director%Benefits' THEN
            l_mgr_type := 'Director';

          ELSIF l_bnft_grp_name LIKE 'Supervisor Benefits' THEN
            l_mgr_type := 'Supervisor';
          ELSE

          ---V1.8 Starts

            IF UPPER(r_emp_info.attribute6) NOT IN
               ('NON-MANAGER', 'SUPERVISOR 1', 'SUPERVISOR 2','MANAGER 1','MANAGER 2') THEN
              l_mgr_type := 'Director';
            ELSIF UPPER(r_emp_info.attribute6) = 'MANAGER 2' THEN
              l_mgr_type := 'Sr. Manager';
            ELSIF UPPER(r_emp_info.attribute6) = 'MANAGER 1' THEN
              l_mgr_type := 'Manager';
          ---V1.8 Ends
            ELSIF r_emp_info.pay_basis_name = 'Monthly Salary Exempt' and
                  UPPER(r_emp_info.attribute6) in
                  ('NON-MANAGER', 'SUPERVISOR 1', 'SUPERVISOR 2') THEN
              l_mgr_type := 'Supervisor';
            ELSIF r_emp_info.pay_basis_name IN
                  ('Hour', 'Monthly Salary Non Exempt') THEN
              l_mgr_type := 'Rank & File';
            END IF;
          END IF;
          -- Code End to support new option names

          IF nvl(r_bnft_info.enrt_cvg_thru_dt,
                 TO_DATE('31/12/4712', 'DD/MM/YYYY')) <=
             trunc(sysdate) + 14 THEN

            /*  IF nvl(r_bnft_info.enrt_cvg_thru_dt,
            TO_DATE('31/12/4712', 'DD/MM/YYYY')) < v_current_run_Date THEN*/
            l_error_step := '1.8';
            BEGIN
              SELECT 'Y'
                INTO l_term_already_exists
                --FROM CUST.ttec_philcare_term_benefits   --code commented by RXNETHI-ARGANO,18/05/23
                FROM APPS.ttec_philcare_term_benefits     --code added by RXNETHI-ARGANO,18/05/23

               WHERE nvl(BENEFIT_person_id, 1) =
                     nvl(r_emp_info.contact_person_id, 1)
                 AND employee_number = r_emp_info.employee_number
                 and coverage_start_dt =

                     GREATEST(r_bnft_info.enrt_cvg_strt_dt,
                              TRUNC(v_current_run_date, 'YYYY'))
                 and coverage_end_Dt = r_bnft_info.enrt_cvg_thru_dt
                 AND pl_id = r_bnft_info.pl_id;
              l_skip_record := 'Y';
              fnd_file.put_line(fnd_file.log,
                                'Termination sent earlier for dpnt_person_id:' ||
                                r_emp_info.contact_person_id ||
                                ' Employee Number: ' ||
                                r_emp_info.employee_number);
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                l_error_step          := '1.9';
                l_term_already_exists := 'N';
                --INSERT INTO cust.ttec_philcare_term_benefits   --code commented by RXNETHI-ARGANO,18/05/23
                INSERT INTO apps.ttec_philcare_term_benefits     --code added by RXNETHI-ARGANO,18/05/23
                  (employee_number,
                   benefit_person_id,
                   coverage_start_dt,
                   coverage_end_Dt,
                   pl_id,
                   last_name,
                   first_name)
                VALUES
                  (r_emp_info.employee_number,
                   r_emp_info.contact_person_id,
                   GREATEST(r_bnft_info.enrt_cvg_strt_dt,
                            TRUNC(v_current_run_date, 'YYYY')),
                   r_bnft_info.enrt_cvg_thru_dt,
                   r_bnft_info.pl_id,
                   r_emp_info.last_name,
                   r_emp_info.first_name);
            END;
          END IF;
     BEGIN
            select name
              INTO l_bnft_grp_info
              from per_all_people_f ppf, BEN_BENFTS_GRP grp
             WHERE grp.BENFTS_GRP_ID = ppf.benefit_group_id
               and grp.BUSINESS_GROUP_ID = 1517
               AND r_emp_rec.actual_termination_date BETWEEN
                   ppf.effective_start_date and ppf.effective_end_Date
               AND ppf.person_id = r_emp_rec.person_id;
          EXCEPTION
            WHEN OTHERS THEN
              l_bnft_grp_name := '';
          END;
          IF l_skip_record = 'N' THEN
            BEGIN

              v_text := '|' || r_emp_info.location_code || '|' ||
                        r_emp_info.supervisor_name || '|' ||
                        r_emp_info.employee_number || '|' ||
                       -- r_bnft_info.enrt_cvg_strt_dt
                        TO_CHAR(GREATEST(r_bnft_info.enrt_cvg_strt_dt,
                                         TRUNC(v_current_run_date, 'YYYY')),
                                'DD-MON-YYYY') || '|' || l_enrt_cvg_thru_dt || '|' ||
                        r_emp_info.last_name || '|' || r_emp_info.suffix || '|' ||
                        r_emp_info.first_name || '|' ||
                        r_emp_info.middle_names || '|' ||
                        to_char(r_emp_info.date_of_birth, 'DD-MON-YYYY') || '|' ||
                        r_emp_info.contact_type || '|' ||
                        r_emp_info.address_line1 || '|' ||
                        r_emp_info.address_line2 || '|' ||
                        r_emp_info.town_or_city || '|' ||
                        r_emp_info.description || '|' || r_emp_info.sex || '|' ||
                        r_emp_info.marital_status || '|' || l_opt_name ||
                        ' : ' || l_tenure || '|' || --added for  2.1
                        l_tenure;--added for  2.1

                /* select decode(l_opt_name,'Employee Only','EE Only','Employee + 1','EE+1','Employee + 2','EE+2','Employee + 3','EE+3','Employee + 4','EE+4','Employee + 5','EE+5','Employee + 6 or More','EE+6')
                 into l_option_code from dual;*/

               --added for  2.1

              --  select case when l_bnft_grp_info='Grandfathered Motif' then
              if r_emp_info.benefit_group_id=11347 then
                           select    apps.hruserdt.get_table_value (1517,
                                         'TTEC_PHILCARE_EMPLOYEE_EMPLOYER_DETAILS',
                                         l_mgr_type||' '||r_emp_info.tenure_desc||' '||'Motif',
                                         decode(l_opt_name,'Employee Only','EE Only','Employee + 1','EE+1','Employee + 2','EE+2','Employee + 3','EE+3','Employee + 4','EE+4','Employee + 5','EE+5','Employee + 6 or More','EE+6'),
                                         sysdate) into l_employee_premium from dual;
                                         else
                                  select    apps.hruserdt.get_table_value (1517,
                                         'TTEC_PHILCARE_EMPLOYEE_EMPLOYER_DETAILS',
                                         l_mgr_type||' '||r_emp_info.tenure_desc,
                                         decode(l_opt_name,'Employee Only','EE Only','Employee + 1','EE+1','Employee + 2','EE+2','Employee + 3','EE+3','Employee + 4','EE+4','Employee + 5','EE+5','Employee + 6 or More','EE+6'),
                                         sysdate)
                                  into l_employee_premium from dual;
                  end if;
               --select case when l_bnft_grp_info='Grandfathered Motif' then
                if r_emp_info.benefit_group_id=11347 then
                             select  (apps.hruserdt.get_table_value (1517,
                                         'TTEC_PHILCARE_EMPLOYEE_EMPLOYER_DETAILS',
                                         l_mgr_type||' '||r_emp_info.tenure_desc||' '||'Motif',
                                         decode(l_opt_name,'Employee Only','EE Only','Employee + 1','EE+1','Employee + 2','EE+2','Employee + 3','EE+3','Employee + 4','EE+4','Employee + 5','EE+5','Employee + 6 or More','EE+6'),
                                         sysdate)*(0.12)) into l_employee_tax from dual;
                                         else
                                     select (apps.hruserdt.get_table_value (1517,
                                         'TTEC_PHILCARE_EMPLOYEE_EMPLOYER_DETAILS',
                                         l_mgr_type||' '||r_emp_info.tenure_desc,
                                         decode(l_opt_name,'Employee Only','EE Only','Employee + 1','EE+1','Employee + 2','EE+2','Employee + 3','EE+3','Employee + 4','EE+4','Employee + 5','EE+5','Employee + 6 or More','EE+6'),
                                         sysdate)*(0.12)) into  l_employee_tax from dual;
                                         end if;


               --select case when l_bnft_grp_info='Grandfathered Motif' then
                if r_emp_info.benefit_group_id=11347 then
                select apps.hruserdt.get_table_value (1517,
                                         'TTEC_PHILCARE_EMPLOYEE_EMPLOYER_DETAILS',
                                         l_mgr_type||' '||r_emp_info.tenure_desc||' '||'Motif',
                                         decode(l_opt_name,'Employee Only','ER Only','Employee + 1','ER+1','Employee + 2','ER+2','Employee + 3','ER+3','Employee + 4','ER+4','Employee + 5','ER+5','Employee + 6 or More','ER+6'),
                                         sysdate) into l_employer_premium from dual;
               else
               select apps.hruserdt.get_table_value (1517,
                                         'TTEC_PHILCARE_EMPLOYEE_EMPLOYER_DETAILS',
                                         l_mgr_type||' '||r_emp_info.tenure_desc,
                                         decode(l_opt_name,'Employee Only','ER Only','Employee + 1','ER+1','Employee + 2','ER+2','Employee + 3','ER+3','Employee + 4','ER+4','Employee + 5','ER+5','Employee + 6 or More','ER+6'),
                                         sysdate) end into l_employer_premium from dual;
                 end if;
         -- select case when l_bnft_grp_info='Grandfathered Motif' then
          if r_emp_info.benefit_group_id=11347 then
            select (apps.hruserdt.get_table_value (1517,
                                         'TTEC_PHILCARE_EMPLOYEE_EMPLOYER_DETAILS',
                                         l_mgr_type||' '||r_emp_info.tenure_desc||' '||'Motif',
                                         decode(l_opt_name,'Employee Only','ER Only','Employee + 1','ER+1','Employee + 2','ER+2','Employee + 3','ER+3','Employee + 4','ER+4','Employee + 5','ER+5','Employee + 6 or More','ER+6'),
                                         sysdate)*(0.12))into l_employer_tax from dual;
               else
              select (apps.hruserdt.get_table_value (1517,
                                         'TTEC_PHILCARE_EMPLOYEE_EMPLOYER_DETAILS',
                                         l_mgr_type||' '||r_emp_info.tenure_desc,
                                         decode(l_opt_name,'Employee Only','ER Only','Employee + 1','ER+1','Employee + 2','ER+2','Employee + 3','ER+3','Employee + 4','ER+4','Employee + 5','ER+5','Employee + 6 or More','ER+6'),
                                         sysdate)*(0.12)) end into l_employer_tax from dual;
                                         end if;
--added for  2.3
              IF r_bnft_info.plan_name = 'PhilCare HMO' THEN
                            v_text_hmo := v_text || '|' || l_mgr_type || '|' || r_emp_info.Indirect_or_Direct|| '|' || r_emp_info.dept_name|| '|' || r_emp_info.job_name|| '|' ||l_employee_premium|| '|' ||l_employer_premium|| '|' ||l_employee_tax|| '|' ||l_employer_tax;
                               UTL_FILE.put_line(v_hmo_file_type, v_text_hmo);
                V_hmo_elig_count := V_hmo_elig_count + 1;
                fnd_file.put_line(fnd_file.output, v_text_hmo);
              ELSE
             -- v_text := v_text;-- || '|' || r_emp_info.Indirect_or_Direct|| '|' || r_emp_info.dept_name|| '|' || r_emp_info.job_name|| '|' ||l_employee_premium|| '|' ||l_employer_premium|| '|' ||r_emp_info.employee_tax|| '|' ||r_emp_info.employer_tax;
                UTL_FILE.put_line(v_vol_dpnt_file_type, v_text);
                V_dpnt_elig_count := V_dpnt_elig_count + 1;
                fnd_file.put_line(fnd_file.output, v_text);
              END IF;

            END;
          END IF;
        END LOOP;

      END LOOP;
    END LOOP;

    --UTL_FILE.put_line(v_file_type, v_text);
    fnd_file.put_line(fnd_file.LOG,
                      'HMO: v_total_cnt -' || V_hmo_elig_count);
    fnd_file.put_line(fnd_file.LOG,
                      'Voluntary Dpnt: v_total_cnt -' || V_dpnt_elig_count);
    UTL_FILE.fclose(v_hmo_file_type);
    UTL_FILE.fclose(v_vol_dpnt_file_type);

  EXCEPTION
    WHEN OTHERS THEN
      UTL_FILE.fclose(v_vol_dpnt_file_type);
      UTL_FILE.fclose(v_hmo_file_type);
      fnd_file.put_line(fnd_file.LOG,
                        'Error out of main loop main_proc -' || SQLERRM);
  END main_proc;

  PROCEDURE axa_main_proc(errbuf OUT VARCHAR2,

                          retcode            OUT NUMBER,
                          p_output_directory IN VARCHAR2,
                          p_start_date       IN VARCHAR2,
                          p_end_date         IN VARCHAR2) IS
    --    l_contact_name varchar2(100);
    CURSOR c_emp_rec(p_cut_off_date DATE, p_current_run_date DATE) IS
      SELECT MAX(date_start) date_start,
             MAX(NVL(actual_termination_date, p_current_run_date)) actual_termination_date,
             person_id
        FROM per_periods_of_service ppos
       WHERE business_group_id = 1517
         AND ((TRUNC(ppos.last_update_date) BETWEEN p_cut_off_date AND
             p_current_run_date AND
             ppos.actual_termination_date IS NOT NULL) OR
             (ppos.actual_termination_date IS NULL AND
             ppos.person_id IN
             (SELECT DISTINCT person_id
                  FROM per_all_people_f papf
                 WHERE papf.current_employee_flag = 'Y')) OR
             (ppos.actual_termination_date =
             (SELECT MAX(actual_termination_date)
                  FROM per_periods_of_service
                 WHERE person_id = ppos.person_id
                   AND actual_termination_date IS NOT NULL) AND
             ppos.actual_termination_date >= p_cut_off_date))
      --and rownum < 20
      -- AND ppos.person_id IN (1219466)
       GROUP BY person_id;

    CURSOR c_emp_info(p_person_id NUMBER, p_actual_termination_date DATE, p_contact_person_id NUMBER, p_emp_or_dep VARCHAR2) IS
      SELECT DISTINCT papf.person_id,
                      NULL contact_person_id,
                      paaf.assignment_id,
                      papf.employee_number,
                      papf.date_of_birth,
                      translate(papf.national_identifier, '0-', '0') national_identifier,
                      translate(papf.national_identifier, '0-', '0') member_ssn,
                      papf.first_name,
                      papf.suffix, --v1.3
                      papf.last_name,
                      papf.email_address,
                      papf.middle_names middle_names,
                      TO_CHAR(papf.date_of_birth, 'YYYYMMDD') dob,
                      hr_general.decode_lookup('MARITAL_STATUS',
                                               papf.marital_status) civil_status,
                      TO_CHAR(papf.start_date, 'YYYYMMDD') start_date,
                      papf.sex,
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
                      past.user_status,
                      ppt.user_person_type,
                      ppos.actual_termination_date actual_term_date,
                      paaf.employment_category,
                      (select meaning from hr_lookups
                       where lookup_type ='EMP_CAT'
                       and lookup_code = paaf.employment_category) --v1.7
                       employment_category_desc, --v1.7
                      'E' per_type,
                      'Employee' contact_type,
                      papf.registered_disabled_flag,
                      papf.employee_number subscriber_employee_number,
                      hla.location_code,
                      TRUNC(MONTHS_BETWEEN(trunc(sysdate), PPOS.DATE_START) / 12,
                            2) tenure,
                      province.description,
                      marital_status_lk.marital_status,
                      job.attribute2,
                      job.attribute4,
                      job.attribute5,
                      job.attribute6,
                      sup.last_name || ', ' || sup.first_name supervisor_name,
                      decode(pay_basis,
                             'MONTHLY',
                             proposed_salary_n,
                             (proposed_salary_n *
                             PER_SALADMIN_UTILITY.get_annualization_factor(paaf.assignment_id,
                                                                            trunc(sysdate))) / 12) proposed_salary_n,
                      pay_basis,
                      grp.name benefits_group, --V1.3
                      pjd.segment1 job_code, --v1.7
                      pjd.segment2 job_description --v1.7
        FROM apps.per_all_people_f papf,
             apps.per_all_assignments_f paaf,
             apps.per_periods_of_service ppos,
             apps.per_person_type_usages_f pptuf,
             apps.per_person_types ppt,
             apps.per_addresses pad,
             apps.per_phones pp,
             apps.per_assignment_status_types past,
             apps.per_jobs job,
             apps.per_job_definitions pjd,--v1.7
             apps.per_all_people_f sup,
             hr_locations hla,
             (SELECT FLEX_vALUE, FLEX_DESC.DESCRIPTION
                FROM FND_FLEX_VALUES     V,
                     FND_FLEX_VALUE_SETS S,
                     FND_FLEX_VALUES_TL  FLEX_DESC
               WHERE V.FLEX_VALUE_SET_ID = S.FLEX_VALUE_sET_ID
                 AND S.FLEX_VALUE_SET_NAME = 'TELETECH_PHL_PROVINCES_VS'
                 AND FLEX_DESC.FLEX_VALUE_ID = V.FLEX_VALUE_ID
                 AND FLEX_DESC.LANGUAGE = 'US') province,
             (SELECT DISTINCT UPPER(l.lookup_code) code,
                              l.meaning marital_status
                FROM apps.fnd_lookup_values l
               WHERE l.lookup_type = 'MARITAL_STATUS'
                 AND enabled_flag = 'Y'
                 AND LANGUAGE = 'US') marital_status_lk,
             apps.per_pay_proposals sal,
             apps.per_pay_bases ppb,
             --ben.BEN_BENFTS_GRP grp --code commented by RXNETHI-ARGANO,18/05/23
             apps.BEN_BENFTS_GRP grp  --code added by RXNETHI-ARGANO,18/05/23

       WHERE papf.person_id = paaf.person_id
         AND paaf.assignment_id = sal.assignment_id(+)
         and P_ACTUAL_TERMINATION_DATE BETWEEN sal.change_date(+) and
             sal.date_to(+)
         and ppb.pay_basis_id = paaf.pay_basis_id
         AND grp.business_group_id(+) = papf.business_group_id /* Added for v 1.5*/
         AND grp.BENFTS_GRP_ID(+) = papf.benefit_group_id /* Added for v 1.5*/

         AND paaf.location_id = hla.location_id
         AND hla.inactive_date IS NULL
            --V1. Added Supervisor
         AND paaf.supervisor_id = sup.person_id(+)
         AND P_ACTUAL_TERMINATION_DATE BETWEEN sup.effective_start_date(+) AND
             sup.effective_end_date
         AND PAPF.marital_status = marital_status_lk.code(+)
        -- and papf.employee_number='2138616'
         AND paaf.person_id = ppos.person_id
         AND pptuf.person_id = papf.person_id
         AND papf.person_id = pad.person_id(+)
         AND ppt.person_type_id = pptuf.person_type_id
         AND UPPER(ppt.system_person_type) = 'EMP'
         AND ppos.period_of_service_id = paaf.period_of_service_id
         AND paaf.primary_flag = 'Y'
         AND papf.business_group_id <> 0
         AND papf.business_group_id = 1517
            /* AND past.user_status NOT IN

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ('Detail NTE', 'End', 'TTEC Awaiting integration')*/
         AND papf.current_employee_flag = 'Y'
         AND province.flex_value(+) = pad.region_1
         AND pad.primary_flag(+) = 'Y'
         AND papf.person_id = pp.parent_id(+)
         AND pp.phone_type(+) = 'H1'
         AND paaf.assignment_status_type_id =
             past.assignment_status_type_id
         AND papf.person_id = P_PERSON_ID
         AND past.active_flag = 'Y'
         AND P_ACTUAL_TERMINATION_DATE BETWEEN pp.date_from(+) AND
             NVL(pp.date_to(+), P_ACTUAL_TERMINATION_DATE)
         AND P_ACTUAL_TERMINATION_DATE BETWEEN pptuf.effective_start_date AND
             pptuf.effective_end_date
         AND P_ACTUAL_TERMINATION_DATE BETWEEN papf.effective_start_date AND
             papf.effective_end_date
         AND P_ACTUAL_TERMINATION_DATE BETWEEN paaf.effective_start_date AND
             paaf.effective_end_date
         AND P_ACTUAL_TERMINATION_DATE BETWEEN pad.date_from(+) AND
             NVL(pad.date_to(+), P_ACTUAL_TERMINATION_DATE)
         AND P_ACTUAL_TERMINATION_DATE BETWEEN ppos.date_start AND
             NVL(ppos.actual_termination_date, P_ACTUAL_TERMINATION_DATE)
         AND P_EMP_OR_DEP = 'E'
         AND job.job_id = paaf.job_id
         AND job.job_definition_id = pjd.job_definition_id --v1.7
         AND P_ACTUAL_TERMINATION_DATE BETWEEN paaf.effective_start_date AND
             paaf.effective_end_date

       ORDER BY 1;

    CURSOR c_bnft_info(p_person_id IN NUMBER, p_start_date IN DATE, p_end_date IN DATE) IS
      select pen.bnft_amt,
             ppf.employee_number,
             ppf.current_employee_flag,
             pen.person_id,
             pen.enrt_cvg_strt_dt,
             pen.orgnl_enrt_dt,
             pen.enrt_cvg_thru_dt,
             pen.pl_id,
             ben_batch_utils.get_pl_name(pln.pl_id, 1517, p_end_date) pl_name,

             'E' type_of_rec,

             pen.person_id dpnt_person_id,
             opt.name,
             pln.name plan_name
        from ben_pl_f             pln,
             ben_prtt_enrt_rslt_f pen,
             ben_per_in_ler       pil,
             per_all_people_f     ppf,
             ben_opt_f            opt,
             ben_oipl_f           oipl
       where p_end_date between pln.effective_start_date and
             pln.effective_end_date
         and p_end_date between opt.effective_start_date and
             opt.effective_end_date
         and p_end_date between oipl.effective_start_date and
             oipl.effective_end_date
         and trunc(sysdate) between ppf.effective_start_date and
             ppf.effective_end_Date
         and pen.oipl_id = oipl.oipl_id
         and oipl.pl_id = pln.pl_id
         and oipl.opt_id = opt.opt_id
         and pen.person_id = ppf.person_id
         and pln.business_group_id = 1517
         and pln.pl_stat_cd = 'A'
         and pln.pl_id = pen.pl_id(+)
         and pen.prtt_enrt_rslt_stat_cd is null
         and pen.business_group_id(+) = 1517
         and nvl(pen.enrt_cvg_thru_dt, p_end_date) <=
             nvl(pen.effective_end_date, p_end_date)
         and pen.sspndd_flag(+) = 'N'
         and pil.per_in_ler_id(+) = pen.per_in_ler_id
         and pen.person_id = p_person_id
         and (pil.per_in_ler_stat_cd in ('STRTD', 'PROCD') or
             pil.per_in_ler_stat_cd is null)
         and (p_start_date between pen.enrt_cvg_strt_dt and
             pen.enrt_cvg_thru_dt or
             p_end_date between pen.enrt_cvg_strt_dt and
             pen.enrt_cvg_thru_dt or (p_start_date >= pen.enrt_cvg_strt_dt and
             p_end_date <= pen.enrt_cvg_thru_dt) or
             (p_start_date <= pen.enrt_cvg_strt_dt and
             p_end_date >= pen.enrt_cvg_thru_dt) or
             pen.enrt_cvg_strt_dt is null and pen.enrt_cvg_thru_dt is null)
         AND pln.pl_id in (select pl_id
                             from ben_pl_f
                            where business_group_id = 1517
                              and name in ('PhilCare HMO'))
         AND opt.name <> 'Waive'
         AND NOT EXISTS
       (SELECT 1
                FROM ben_prtt_enrt_rslt_f pen1
               where pen.person_id = pen1.person_id
                 and pen1.prtt_enrt_rslt_stat_cd is null
                 and pen1.prtt_enrt_rslt_id <> pen.prtt_enrt_rslt_id
                 and pen1.business_group_id(+) = 1517
                 and pen1.enrt_cvg_strt_dt = pen.enrt_cvg_thru_dt + 1
                 and nvl(pen.bnft_amt, -1) = nvl(pen1.bnft_amt, -1)
                 and pen.pl_id = pen1.pl_id);

    CURSOR c_host IS
      SELECT host_name, instance_name FROM v$instance;

    v_text      VARCHAR(32765) DEFAULT '';
    v_file_extn VARCHAR2(200) DEFAULT '';
    v_time      VARCHAR2(20);

    l_axa_active_file VARCHAR2(200) DEFAULT '';

    v_axa_file_type UTL_FILE.file_type;

    v_cut_off_date     DATE;
    v_current_run_date DATE;
    l_skip_record      VARCHAR2(1); --v1.3
    v_cnt              NUMBER DEFAULT 0;

    v_not_eli_fsa    VARCHAR2(1) DEFAULT '';
    V_axa_elig_count number;

    l_contact_type        VARCHAR2(2) DEFAULT '';
    l_term_already_exists VARCHAR2(1);

    l_enrt_cvg_thru_dt VARCHAR2(11);
    l_host_name        v$instance.host_name%TYPE;
    l_instance_name    v$instance.instance_name%TYPE;
    l_identifier       VARCHAR2(10);

    l_opt_name      BEN_opt_f.name%TYPE;
    l_bnft_grp_name BEN_BENFTS_GRP.name%TYPE;
    l_mgr_type      BEN_BENFTS_GRP.name%TYPE;
    l_error_step    VARCHAR2(10);

  BEGIN

    IF p_start_date IS NULL OR p_end_date IS NULL THEN
      v_current_run_date := TRUNC(SYSDATE);
    ELSE
      -- v_cut_off_date     := TO_DATE(p_start_date, 'YYYY/MM/DD HH24:MI:SS');
      v_current_run_date := TO_DATE(p_end_date, 'YYYY/MM/DD HH24:MI:SS');
    END IF;

    v_cut_off_date := TRUNC(v_current_run_date, 'YYYY');

    --v_cut_off_date     := TO_DATE(p_start_date, 'YYYY/MM/DD HH24:MI:SS');
    --v_current_run_date := TO_DATE(p_end_date, 'YYYY/MM/DD HH24:MI:SS');
    V_axa_elig_count := 0;

    v_cnt := 0;
    OPEN c_host;
    FETCH c_host
      INTO l_host_name, l_instance_name;
    CLOSE c_host;
    IF l_host_name not IN (ttec_library.XX_TTEC_PROD_HOST_NAME) THEN
      -- IF l_host_name = 'den-erp046' then
      l_identifier := 'T';

    ELSE
      l_identifier := 'P';

    END IF;

    BEGIN
      SELECT DECODE(l_identifier, 'T', '.tst', '.txt'),
             to_char(sysdate, 'MMDDYYYY_HH24MI')

        INTO v_file_extn, v_time
        FROM v$instance;
    EXCEPTION
      WHEN OTHERS THEN
        v_file_extn := '.tst';
    END;

    l_axa_active_file := 'axa_' || v_time || v_file_extn;

    v_axa_file_type := UTL_FILE.fopen(p_output_directory,
                                      l_axa_active_file,
                                      'w',
                                      32765);

    -- 1.3 version change
    v_text := 'Agreement No|Sub Office Code|Supervisor Name|Employee No|Coverage Effective Date|Coverage End Date|Last Name|Suffix|First Name|M.I.|Date of Birth|Relation|House No/Street|Bgy/District|City/Province|Region|Gender|Civil Status|Class Code|Request For|Monthly Salary|Benefit Group|Job Code|Job Description|Employment Status|Employment Category|Pay Basis';--v1.7
    UTL_FILE.put_line(v_axa_file_type, v_text);

    fnd_file.put_line(fnd_file.output, v_text);
    FOR r_emp_rec IN c_emp_rec(v_cut_off_date, v_current_run_date) LOOP
      v_text := '';

      --fnd_file.put_line(fnd_file.output, 'r_emp_rec.person_id'||r_emp_rec.person_id);

      FOR r_bnft_info IN c_bnft_info(r_emp_rec.person_id,
                                     --v_pl_id,
                                     -- r_emp_info.per_type,
                                     v_cut_off_date,
                                     v_current_run_Date) LOOP
        --  fnd_file.put_line(fnd_file.output, ' r_bnft_info.person_id'||r_bnft_info.person_id);

        FOR r_emp_info IN c_emp_info(r_emp_rec.person_id,
                                     r_emp_rec.actual_termination_date,

                                     r_bnft_info.dpnt_person_id,
                                     r_bnft_info.type_of_rec) LOOP

          l_contact_type := '';
          -- fnd_file.put_line(fnd_file.output, ' r_emp_info.contact_type'||r_emp_info.contact_type);
          l_term_already_exists := '';

          l_skip_record := 'N'; --v1.3 added

          IF (nvl(r_bnft_info.enrt_cvg_thru_dt,
                  TO_DATE('31/12/4712', 'DD/MM/YYYY')) =
             TO_DATE('31/12/4712', 'DD/MM/YYYY') or
             r_bnft_info.enrt_cvg_thru_dt > v_current_run_date + 14) THEN
            --v1.3
            l_enrt_cvg_thru_dt := NULL;
          ELSE
            l_enrt_cvg_thru_dt := TO_CHAR(r_bnft_info.enrt_cvg_thru_dt,
                                          'DD-MON-YYYY');
          END IF;

          l_opt_name := r_bnft_info.name;

          IF r_bnft_info.name LIKE '%Manager+%' /*and


                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           UPPER(r_emp_info.attribute6) NOT in
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           ('SUPERVISOR 1', 'SUPERVISOR 2', 'NON-MANAGER')*/
           THEN

            BEGIN
              select name
                INTO l_bnft_grp_name
                from per_all_people_f ppf, BEN_BENFTS_GRP grp
               WHERE grp.BENFTS_GRP_ID = ppf.benefit_group_id
                 and grp.BUSINESS_GROUP_ID = 1517
                 AND r_emp_rec.actual_termination_date BETWEEN
                     ppf.effective_start_date and ppf.effective_end_Date
                 AND ppf.person_id = r_emp_rec.person_id;
            EXCEPTION
              WHEN OTHERS THEN
                l_bnft_grp_name := '';
            END;

            IF l_bnft_grp_name = 'Manager Benefits' or
               l_bnft_grp_name IS NULL THEN
              l_mgr_type := 'Manager';
            ELSIF l_bnft_grp_name = 'Sr. Manager Benefits' THEN
              l_mgr_type := 'Sr. Manager';
            ELSIF l_bnft_grp_name LIKE 'Director%Benefits' THEN
              l_mgr_type := 'Director';
            END IF;

            SELECT replace(r_bnft_info.name, 'Manager+', l_mgr_type)
              INTO l_opt_name
              FROM DUAL;

          END IF;
          --v1.3 changes
          IF nvl(r_bnft_info.enrt_cvg_thru_dt,
                 TO_DATE('31/12/4712', 'DD/MM/YYYY')) <=
             trunc(sysdate) + 14 THEN

            /*  IF nvl(r_bnft_info.enrt_cvg_thru_dt,
            TO_DATE('31/12/4712', 'DD/MM/YYYY')) < v_current_run_Date THEN*/
            l_error_step := '1.8';
            BEGIN
              SELECT 'Y'
                INTO l_term_already_exists
                --FROM CUST.TTEC_PHL_AXALIFE_TERM_BENEFITS    --code commented by RXNETHI-ARGANO,18/05/23
                FROM APPS.TTEC_PHL_AXALIFE_TERM_BENEFITS      --code added by RXNETHI-ARGANO,18/05/23

               WHERE nvl(BENEFIT_person_id, 1) =
                     nvl(r_emp_info.contact_person_id, 1)
                 AND employee_number = r_emp_info.employee_number
                 and coverage_start_dt =
                     GREATEST(r_bnft_info.enrt_cvg_strt_dt,
                              TRUNC(v_current_run_date, 'YYYY'))
                 and coverage_end_Dt = r_bnft_info.enrt_cvg_thru_dt
                 AND pl_id = r_bnft_info.pl_id;
              l_skip_record := 'Y';
              fnd_file.put_line(fnd_file.log,
                                'Termination sent earlier for dpnt_person_id:' ||
                                r_emp_info.contact_person_id ||
                                ' Employee Number: ' ||
                                r_emp_info.employee_number);
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                l_error_step          := '1.9';
                l_term_already_exists := 'N';
                --INSERT INTO cust.TTEC_PHL_AXALIFE_TERM_BENEFITS    --code commented by RXNETHI-ARGANO,18/05/23
                INSERT INTO apps.TTEC_PHL_AXALIFE_TERM_BENEFITS      --code added by RXNETHI-ARGANO,18/05/23
                  (employee_number,
                   benefit_person_id,
                   coverage_start_dt,
                   coverage_end_Dt,
                   pl_id,
                   last_name,
                   first_name)
                VALUES
                  (r_emp_info.employee_number,
                   r_emp_info.contact_person_id,
                   GREATEST(r_bnft_info.enrt_cvg_strt_dt,
                            TRUNC(v_current_run_date, 'YYYY')),
                   r_bnft_info.enrt_cvg_thru_dt,
                   r_bnft_info.pl_id,
                   r_emp_info.last_name,
                   r_emp_info.first_name);
            END;
          END IF;

          IF l_skip_record = 'N' THEN
            BEGIN

              v_text := '|' || r_emp_info.location_code || '|' ||
                        r_emp_info.supervisor_name || '|' ||
                        r_emp_info.employee_number || '|' ||
                       -- r_bnft_info.enrt_cvg_strt_dt
                        TO_CHAR(GREATEST(r_bnft_info.enrt_cvg_strt_dt,
                                         TRUNC(v_current_run_date, 'YYYY')),
                                'DD-MON-YYYY') || '|' || l_enrt_cvg_thru_dt || '|' ||
                        r_emp_info.last_name || '|' || r_emp_info.suffix || '|' ||
                        r_emp_info.first_name || '|' ||
                        r_emp_info.middle_names || '|' ||
                        to_char(r_emp_info.date_of_birth, 'DD-MON-YYYY') || '|' ||
                        r_emp_info.contact_type || '|' ||
                        r_emp_info.address_line1 || '|' ||
                        r_emp_info.address_line2 || '|' ||
                        r_emp_info.town_or_city || '|' ||
                        r_emp_info.description || '|' || r_emp_info.sex || '|' ||
                        r_emp_info.marital_status || '|' || l_opt_name ||
                        ' : ' || r_emp_info.tenure || '|' ||
                        r_emp_info.tenure || '|' ||
                        r_emp_info.proposed_salary_n || '|' ||
                       -- r_emp_info.pay_basis || '|' ||
                        r_emp_info.benefits_group || '|' ||
                        r_emp_info.job_code || '|' || --v1.7 starts
                        r_emp_info.job_description || '|' ||
                        r_emp_info.user_status || '|' ||
                        r_emp_info.employment_category_desc || '|' ||
                        r_emp_info.pay_basis;  --v1.7 ends

              IF r_bnft_info.plan_name = 'PhilCare HMO' THEN
                UTL_FILE.put_line(v_axa_file_type, v_text);
                V_axa_elig_count := V_axa_elig_count + 1;

              END IF;

              fnd_file.put_line(fnd_file.output, v_text);

            END;
          END IF;
        END LOOP;

      END LOOP;
    END LOOP;

    --UTL_FILE.put_line(v_file_type, v_text);
    fnd_file.put_line(fnd_file.LOG,
                      'AXA: v_total_cnt -' || V_axa_elig_count);

    UTL_FILE.fclose(v_axa_file_type);

  EXCEPTION
    WHEN OTHERS THEN

      UTL_FILE.fclose(v_axa_file_type);
      fnd_file.put_line(fnd_file.LOG,
                        'Error out of main loop axa_main_proc -' || SQLERRM);
  END axa_main_proc;
  PROCEDURE same_sex_hmo_file(errbuf           OUT VARCHAR2,
                              retcode          OUT NUMBER,
                              p_effective_date IN VARCHAR2) IS
    --    l_contact_name varchar2(100);
    CURSOR c_emp_rec(p_effective_date DATE) IS
      SELECT MAX(date_start) date_start,
             MAX(NVL(actual_termination_date, p_effective_date)) actual_termination_date,
             person_id
        FROM per_periods_of_service ppos
       WHERE business_group_id = 1517
         AND ((ppos.actual_termination_date IS NULL) OR
             (ppos.actual_termination_date =
             (SELECT MAX(actual_termination_date)
                  FROM per_periods_of_service
                 WHERE person_id = ppos.person_id
                   AND actual_termination_date IS NOT NULL) AND
             ppos.actual_termination_date >= p_effective_date))
      --and rownum < 20
      -- AND ppos.person_id IN (1219466)
       GROUP BY person_id;

    CURSOR c_emp_bnft_info(p_person_id IN NUMBER, p_effective_date IN DATE) IS
      select pen.enrt_cvg_strt_dt,
             pen.orgnl_enrt_dt,
             pen.enrt_cvg_thru_dt,
             pen.person_id dpnt_person_id
        from ben_pl_f             pln,
             ben_prtt_enrt_rslt_f pen,
             ben_per_in_ler       pil,
             ben_opt_f            opt,
             ben_oipl_f           oipl
       where p_effective_date between pln.effective_start_date and
             pln.effective_end_date
         and p_effective_date between opt.effective_start_date and
             opt.effective_end_date
         and p_effective_date between oipl.effective_start_date and
             oipl.effective_end_date
         and pen.oipl_id = oipl.oipl_id
         and oipl.pl_id = pln.pl_id
         and oipl.opt_id = opt.opt_id
         and pln.business_group_id = 1517
         and pln.pl_stat_cd = 'A'
         and pln.pl_id = pen.pl_id(+)
         and pen.prtt_enrt_rslt_stat_cd is null
         and pen.business_group_id(+) = 1517
         and nvl(pen.enrt_cvg_thru_dt, p_effective_date) <=
             nvl(pen.effective_end_date, p_effective_date)
         and pen.sspndd_flag(+) = 'N'
         and pil.per_in_ler_id(+) = pen.per_in_ler_id
         and pen.person_id = p_person_id
         and (pil.per_in_ler_stat_cd in ('STRTD', 'PROCD') or
             pil.per_in_ler_stat_cd is null)
         and (p_effective_date between pen.enrt_cvg_strt_dt and
             pen.enrt_cvg_thru_dt or

             pen.enrt_cvg_strt_dt is null and pen.enrt_cvg_thru_dt is null)
         AND pln.pl_id in (select pl_id
                             from ben_pl_f
                            where business_group_id = 1517
                              and name in ('PhilCare HMO'))
         AND opt.name <> 'Waive'
      /* AND NOT EXISTS
                                                                                                             (SELECT 1
                                                                                                                      FROM ben_prtt_enrt_rslt_f pen1
                                                                                                                     where pen.person_id = pen1.person_id
                                                                                                                       and pen1.prtt_enrt_rslt_stat_cd is null
                                                                                                                       and pen1.prtt_enrt_rslt_id <> pen.prtt_enrt_rslt_id
                                                                                                                       and pen1.business_group_id(+) = 1517
                                                                                                                       and pen1.enrt_cvg_strt_dt = pen.enrt_cvg_thru_dt + 1
                                                                                                                       and nvl(pen.bnft_amt, -1) = nvl(pen1.bnft_amt, -1)
                                                                                                                       and pen.pl_id = pen1.pl_id)*/
      ;

    CURSOR c_bnft_info(p_person_id IN NUMBER, p_effective_date IN DATE) IS
      select dpnt.cvg_strt_dt enrl_cvg_strt_dt,
             pen.orgnl_enrt_dt,
             dpnt.cvg_thru_dt enrl_cvg_thru_dt,
             dpnt.dpnt_person_id,
             hla.location_code,
             ppf.employee_number,
             ppf.date_of_birth,
             ppf.full_name,
             hr_general.decode_lookup('MARITAL_STATUS', ppf.marital_status) civil_status,
             hr_general.decode_lookup('CONTACT', pcr.contact_type) contact_type,
             ppf.sex,
             papfc.full_name spouse_full_name,
             papfc.sex spouse_sex
        from ben_pl_f                       pln,
             ben_prtt_enrt_rslt_f           pen,
             --ben.ben_elig_cvrd_dpnt_f       dpnt,    --code commented by RXNETHI-ARGANO,18/05/23
             apps.ben_elig_cvrd_dpnt_f       dpnt,     --code added by RXNETHI-ARGANO,18/05/23
             per_all_people_f               ppf,
             ben_opt_f                      opt,
             ben_oipl_f                     oipl,
             apps.per_all_people_f          papfc,
             apps.per_contact_relationships pcr,
             apps.hr_locations_all          hla,
             apps.per_all_assignments_f     paf
       where p_effective_date between pln.effective_start_date and
             pln.effective_end_date
         and trunc(p_effective_date) between ppf.effective_start_date and
             ppf.effective_end_Date
         and trunc(p_effective_date) between paf.effective_start_date and
             paf.effective_end_Date
         and trunc(p_effective_date) between papfc.effective_start_date and
             papfc.effective_end_Date
         and trunc(p_effective_date) between opt.effective_start_date and
             opt.effective_end_Date
         and trunc(p_effective_date) between oipl.effective_start_date and
             oipl.effective_end_Date
         and pen.person_id = ppf.person_id
         AND pcr.person_id = ppf.person_id
         AND paf.person_id = ppf.person_id
         and hla.location_id = paf.location_id
         AND pcr.contact_person_id = papfc.person_id
         AND pcr.contact_type IN ('D', 'S')
         and nvl(pen.enrt_cvg_thru_dt, p_effective_date) <=
             nvl(pen.effective_end_date, p_effective_date)
         and dpnt.dpnt_person_id = papfc.person_id
         and papfc.sex = ppf.sex
         and pln.business_group_id = 1517
         and pln.pl_stat_cd = 'A'
         and pln.pl_id = pen.pl_id(+)
         and pen.oipl_id = oipl.oipl_id
         and oipl.pl_id = pen.pl_id
         and pen.prtt_enrt_rslt_stat_cd is null
         and pen.business_group_id(+) = 1517
         and (nvl(dpnt.cvg_thru_dt, dpnt.effective_end_date) <=
             dpnt.effective_end_date OR
             dpnt.effective_end_date = to_date('31/12/4712', 'dd/mm/yyyy'))

         AND pen.prtt_enrt_rslt_id = dpnt.prtt_enrt_rslt_id
         and pen.person_id = p_person_id
         and oipl.opt_id = opt.opt_id
            --  and ppf.employee_number='3002297'
         AND EXISTS
       (SELECT dep.per_in_ler_id
                FROM ben_per_in_ler dep
               WHERE dep.per_in_ler_id = pen.per_in_ler_id
                 AND dep.business_group_id = 1517
                 AND (dep.per_in_ler_stat_cd in ('STRTD', 'PROCD') or
                     dep.per_in_ler_stat_cd is null))
         and pen.sspndd_flag(+) = 'N'
         AND dpnt.cvg_strt_dt <= p_effective_date
         and nvl(dpnt.cvg_thru_dt, p_effective_date) >= p_effective_date
         AND dpnt.cvg_strt_dt <= nvl(dpnt.cvg_thru_dt, p_effective_date) --Added for v1.4
         AND opt.name <> 'Waive'
         AND pln.pl_id in (select pl_id
                             from ben_pl_f
                            where business_group_id = 1517
                              and name in ('PhilCare HMO'));

    CURSOR c_host IS
      SELECT host_name, instance_name FROM v$instance;

    v_text VARCHAR(32765) DEFAULT '';

    v_current_run_date DATE;

    l_emp_cvg_strt_dt DATE;

  BEGIN

    IF p_effective_date IS NULL then
      v_current_run_date := TRUNC(SYSDATE);
    ELSE
      -- v_cut_off_date     := TO_DATE(p_start_date, 'YYYY/MM/DD HH24:MI:SS');
      v_current_run_date := TO_DATE(p_effective_date,
                                    'YYYY/MM/DD HH24:MI:SS');
    END IF;

    -- 1.3 version change
    v_text := 'Employee Number|Employee Name|Location Code|Sex|Coverage Start Date|Spouse Name|Spouse Sex';

    fnd_file.put_line(fnd_file.output, v_text);

    v_text := '';

    FOR r_emp_rec in c_emp_rec(v_current_run_Date) LOOP

      FOR r_bnft_info IN c_bnft_info(r_emp_rec.person_id,
                                     v_current_run_Date) LOOP

        l_emp_cvg_strt_dt := null;

        FOR r_emp_bnft_info IN c_emp_bnft_info(r_emp_rec.person_id,
                                               v_current_run_Date) LOOP
          l_emp_cvg_strt_dt := r_emp_bnft_info.enrt_cvg_strt_dt;
        END LOOP;

        BEGIN

          v_text := r_bnft_info.employee_number || '|' ||
                    r_bnft_info.full_name || '|' ||
                    r_bnft_info.location_code || '|' || r_bnft_info.sex || '|' ||
                    l_emp_cvg_strt_dt || '|' ||
                    r_bnft_info.spouse_full_name || '|' ||
                    r_bnft_info.spouse_sex;

          fnd_file.put_line(fnd_file.output, v_text);

        END;

      END LOOP;
    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN

      fnd_file.put_line(fnd_file.LOG,
                        'Error out of main loop same_sex_hmo_file -' ||
                        SQLERRM);
  END same_sex_hmo_file;

END ttec_phl_philcare_intf_pkg;
/
show errors;
/