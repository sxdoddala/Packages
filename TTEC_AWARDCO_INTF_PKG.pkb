create or replace PACKAGE BODY  ttec_awardco_intf_pkg
IS
   /*---------------------------------------------------------------------------------------
    Objective    : Interface to extract data of Percepta Employees for Awardco.
    this file would be generated in output directory from there the SFTP Program will pick up the file and SFTP to
    Awardco. The file will be then moved to archive directory
   Package spec :ttec_awardco_intf_pkg
   Parameters:

     MODIFICATION HISTORY
     Person               Version  Date        Comments
     ------------------------------------------------
     Neelofar            1.0    23/10/2020 Created
     Neelofar            2.0    28/2/2021  Changing File Name Format
     Neelofar            3.0    10/3/2021  Role is renamed as Job Name and Job Code is added before Job Name
     Neelofar            4.0    19/12/2021 Old Criteria commented and new criteria added as per HOP Report logic
     Neelofar            5.0    04/01/2022 Replacing supervisor name to supervisor id
     Neelofar            6.0    13/01/2022 changing Email logic to use primary oracle email for MX and BR.
     Neelofar            7.0    01/04/2022 Adding parent clients 10030 Ford and 12430 Ford Motor Company along with 10110 Percepta-RITM1279393
     Neelofar            8.0    06/17/2022 Excluded AU,NZ Business Groups as part of Cloud Migration
     Neelofar            9.0    10/10/2022 Rollback of Cloud Migration project
     Neelofar            10.0   10/11/2022 changing Email logic to use primary oracle email for GREECE and BULGARIA.
	 IXPRAVEEN(ARGANO)	1.0		10-May-2023 R12.2 Upgrade Remediation
      *== ==================================================================================================*/
 PROCEDURE main_proc(
    errbuf              OUT   VARCHAR2,
    retcode             OUT   NUMBER,
    p_output_directory IN VARCHAR2
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
    v_file_extn               VARCHAR2 (200)                  DEFAULT '';
    l_host_name               v$instance.host_name%TYPE;
    l_instance_name           v$instance.instance_name%TYPE;
     v_time                    VARCHAR2 (20);
      l_identifier              VARCHAR2 (10);
    CURSOR c_emp_info IS
--4.0
   select  employee_number,
    first_name,
    last_name,
    q.EMAIL_ADDRESS,
    decode(q.business_group_id,1633,q.EMAIL_ADDRESS, --6.0
                             1631,q.EMAIL_ADDRESS,
                             54749,q.EMAIL_ADDRESS, --10.0
                             5054,q.EMAIL_ADDRESS,
                             q.Email)Email,
    Username,
    Password,
    Hire_date,
    Birth_Date,
    Job_Code,
    Job_Name,
    Country_code,
    supervisor,
    group_name,
    Language,
    Location_code,
    Department
from (SELECT
    papf.employee_number,
    papf.first_name,
    papf.last_name,
  -- apps.ttec_daily_reports_pkg.ttec_SIT_email_id(papf.person_id)  Email,
  papf.EMAIL_ADDRESS,
   (SELECT Max(pac.segment1)
        FROM   per_person_analyses ppa,
               per_special_info_types psit,
               per_analysis_criteria pac
        WHERE  pac.id_flex_num = '51172'
               AND psit.id_flex_num = pac.id_flex_num
               AND ppa.person_id (+) = papf.person_id
               AND pac.analysis_criteria_id (+) = ppa.analysis_criteria_id) AS  Email,
 -- null Email,
         NULL  Username,
       NULL    Password,
       ppos.date_start Hire_date,
        papf.date_of_birth   Birth_Date,
         pjd.segment1 Job_Code,pjd.segment2 Job_Name,
         hra.country Country_code,
         papf1.employee_number supervisor, -- papf1.full_name supervisor,--5.0
ppg.segment1  AS   Group_name,
       NULL Language,
       hra.location_code,hou.name Department,
   tce.CLT_PNT_ORG_CD ParentClientCode,tpcd.DESC_SHRT ParentClient,
             NVL((CASE
          WHEN UPPER(MAX(T.DESCRIPTION)) LIKE '%PCTA%' THEN 'Percepta'
          WHEN UPPER(MAX(T.DESCRIPTION)) LIKE '%PERCEPTA%' THEN 'Percepta'
          ELSE NULL
     END),
     NVL((CASE
          WHEN UPPER(MAX(hra.location_code)) LIKE '%PCTA%' THEN 'Percepta'
          WHEN UPPER(MAX(hra.location_code)) LIKE '%PERCEPTA%' THEN 'Percepta'
          ELSE NULL
     END),
     CASE WHEN UPPER(MAX(hra.attribute8)) LIKE '%PCTA%' THEN 'Percepta'
          WHEN UPPER(MAX(hra.attribute8)) LIKE '%PERCEPTA%' THEN 'Percepta'
          ELSE 'TeleTech'
     END)) LocationSubsidiary,
        papf.business_group_id
--START R12.2 Upgrade Remediation
/*FROM													-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
    apps.per_all_people_f papf,                         
    apps.per_all_people_f papf1,
    apps.per_all_assignments_f  paaf,
     apps.per_periods_of_service ppos,
      cust.ttec_emp_proj_asg   tepa,
      apps.ttec_client_ext TCE,
      CUST.TTEC_PARENT_CLIENT_DET tpcd,
       hr.hr_locations_all hra,
        APPS.FND_FLEX_VALUES_TL T,
         apps.per_jobs pj,apps.per_job_definitions pjd,apps.pay_people_groups PPG,
apps.hr_all_organization_units hou*/
FROM
    apps.per_all_people_f papf,							--  code Added by IXPRAVEEN-ARGANO,   10-May-2023
    apps.per_all_people_f papf1,
    apps.per_all_assignments_f  paaf,
     apps.per_periods_of_service ppos,
      apps.ttec_emp_proj_asg   tepa,
      apps.ttec_client_ext TCE,
      apps.TTEC_PARENT_CLIENT_DET tpcd,
       apps.hr_locations_all hra,
        APPS.FND_FLEX_VALUES_TL T,
         apps.per_jobs pj,apps.per_job_definitions pjd,apps.pay_people_groups PPG,
apps.hr_all_organization_units hou
--END R12.2.10 Upgrade remediation
WHERE 1=1
--and papf.employee_number IN('1044141','7060148')
       AND papf.current_employee_flag = 'Y'
      AND papf.person_id = paaf.person_id
        AND papf.person_id = ppos.person_id
        AND papf1.person_id = paaf.supervisor_id
    AND papf.person_id = tepa.person_id
        and tce.CLT_PNT_ORG_CD= tpcd.CLT_PNT_ORG_CD
         and TCE.GL_CLT_CD =  tepa.clt_cd
         and hra.location_id=paaf.location_id
          AND pj.job_id = paaf.job_id
       and pj.job_definition_id=pjd.job_definition_id
        AND hou.organization_id = paaf.organization_id
        and  paaf.period_of_Service_id= ppos.period_of_Service_id
    AND sysdate BETWEEN papf.effective_start_date AND papf.effective_end_date
      AND sysdate BETWEEN paaf.effective_start_date AND paaf.effective_end_date
          AND sysdate BETWEEN papf1.effective_start_date AND papf1.effective_end_date
         and    ppos.period_of_Service_id =
    (SELECT max(PPOS1.period_of_Service_id) FROM APPS.PER_PERIODS_OF_SERVICE PPOS1
                WHERE (PPOS1.actual_termination_date is null or PPOS1.actual_termination_date>=sysdate)
                AND PPOS1.PERSON_ID = PAPF.PERSON_ID)
                --  AND sysdate between tepa.PRJ_STRT_DT(+) and tepa.PRJ_END_DT(+)
               --AND tepa.PRJ_STRT_DT=(select max(tepa.PRJ_STRT_DT) from cust.ttec_emp_proj_asg   tepa where tepa.person_id=papf.person_id)					-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
               AND tepa.PRJ_STRT_DT=(select max(tepa.PRJ_STRT_DT) from apps.ttec_emp_proj_asg   tepa where tepa.person_id=papf.person_id)                   --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
               AND T.LANGUAGE = 'US'
    AND hra.attribute2(+)=T.FLEX_VALUE_MEANING
    AND NVL(hra.inactive_date(+),trunc(sysdate))>= trunc(sysdate)
    AND LENGTH(TRIM(TRANSLATE(T.FLEX_VALUE_MEANING, ' +-.0123456789',' '))) IS NULL
    AND PAAF.people_group_id(+) = PPG.people_group_id
                and papf.business_group_id!=0
                /*  and papf.business_group_id not in (select lookup_code from fnd_lookup_values
													where lookup_type = 'TTEC_EBS_DECOMMISION_COUNTRY'
													and language = 'US') -- Added as part of Cloud Migration --8.0*/--9.0

                                group by  papf.employee_number, papf.first_name, papf.business_group_id,papf.email_address,
    papf.last_name,tce.CLT_PNT_ORG_CD ,tpcd.DESC_SHRT,
    ppos.date_start,pjd.segment1,pjd.segment2,papf.date_of_birth,
    ppg.segment1, hra.country,papf1.employee_number,hra.location_code,papf.person_id,hou.name,tepa.PRJ_STRT_DT , tepa.PRJ_END_DT
    order by employee_number)q
                             --   where q.ParentClient='Percepta' or q.LocationSubsidiary='Percepta'
    where q.ParentClient IN('Percepta','Ford','Ford Motor Company')  or q.LocationSubsidiary='Percepta'
 UNION ALL
 select  employee_number,
    first_name,
    last_name,
  --  Email,
   q.EMAIL_ADDRESS,
   decode(q.business_group_id,1633,q.EMAIL_ADDRESS, --6.0
                             1631,q.EMAIL_ADDRESS,
                             54749,q.EMAIL_ADDRESS, --10.0
                             5054,q.EMAIL_ADDRESS,
                             q.Email)Email,
    Username,
    Password,
    Hire_date,
    Birth_Date,
    Job_Code,
    Job_Name,
    Country_code,
    supervisor,
    group_name,
    Language,
    Location_code,
    Department
from (SELECT
    papf.npw_number employee_number,
    papf.first_name,
    papf.last_name,
      papf.EMAIL_ADDRESS,
      (SELECT Max(pac.segment1)
        FROM   per_person_analyses ppa,
               per_special_info_types psit,
               per_analysis_criteria pac
        WHERE  pac.id_flex_num = '51172'
               AND psit.id_flex_num = pac.id_flex_num
               AND ppa.person_id (+) = papf.person_id
               AND pac.analysis_criteria_id (+) = ppa.analysis_criteria_id) AS  Email,
 --  apps.ttec_daily_reports_pkg.ttec_SIT_email_id(papf.person_id)  Email,
 -- null Email,
         NULL  Username,
       NULL    Password,
       ppos.date_start Hire_date,
        papf.date_of_birth   Birth_Date,
         pjd.segment1 Job_Code,pjd.segment2 Job_Name,
         hra.country Country_code,
          papf1.employee_number supervisor, --papf1.full_name supervisor,--5.0
ppg.segment1  AS   Group_name,
       NULL Language,
       hra.location_code,hou.name Department,
             NVL((CASE
          WHEN UPPER(MAX(T.DESCRIPTION)) LIKE '%PCTA%' THEN 'Percepta'
          WHEN UPPER(MAX(T.DESCRIPTION)) LIKE '%PERCEPTA%' THEN 'Percepta'
          ELSE NULL
     END),
     NVL((CASE
          WHEN UPPER(MAX(hra.location_code)) LIKE '%PCTA%' THEN 'Percepta'
          WHEN UPPER(MAX(hra.location_code)) LIKE '%PERCEPTA%' THEN 'Percepta'
          ELSE NULL
     END),
     CASE WHEN UPPER(MAX(hra.attribute8)) LIKE '%PCTA%' THEN 'Percepta'
          WHEN UPPER(MAX(hra.attribute8)) LIKE '%PERCEPTA%' THEN 'Percepta'
          ELSE 'TeleTech'
     END)) LocationSubsidiary,
     papf.business_group_id
--START R12.2 Upgrade Remediation	 
/*FROM													-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
    apps.per_all_people_f papf,                         
    apps.per_all_people_f papf1,
    apps.per_all_assignments_f  paaf,
     apps.per_periods_of_placement ppos,
       hr.hr_locations_all hra,
        APPS.FND_FLEX_VALUES_TL T,
         apps.per_jobs pj,apps.per_job_definitions pjd,apps.pay_people_groups PPG,
apps.hr_all_organization_units hou*/
FROM
    apps.per_all_people_f papf,							--  code Added by IXPRAVEEN-ARGANO,   10-May-2023
    apps.per_all_people_f papf1,
    apps.per_all_assignments_f  paaf,
     apps.per_periods_of_placement ppos,
       apps.hr_locations_all hra,
        APPS.FND_FLEX_VALUES_TL T,
         apps.per_jobs pj,apps.per_job_definitions pjd,apps.pay_people_groups PPG,
apps.hr_all_organization_units hou
--END R12.2.10 Upgrade remediation
WHERE 1=1
   -- and papf.npw_number = '9836396'
    AND papf.current_npw_flag = 'Y'
      AND papf.person_id = paaf.person_id
        AND papf.person_id = ppos.person_id
        AND papf1.person_id = paaf.supervisor_id
           and hra.location_id=paaf.location_id
          AND pj.job_id = paaf.job_id
       and pj.job_definition_id=pjd.job_definition_id
        AND hou.organization_id = paaf.organization_id
    AND sysdate BETWEEN papf.effective_start_date AND papf.effective_end_date
      AND sysdate BETWEEN paaf.effective_start_date AND paaf.effective_end_date
          AND sysdate BETWEEN papf1.effective_start_date AND papf1.effective_end_date
             and    ppos.period_of_placement_id =
    (SELECT max(PPOS1.period_of_placement_id) FROM APPS.PER_PERIODS_OF_PLACEMENT PPOS1
                WHERE (PPOS1.actual_termination_date is null or PPOS1.actual_termination_date >= sysdate)
                AND PPOS1.PERSON_ID = PAPF.PERSON_ID)
                AND T.LANGUAGE = 'US'
    AND hra.attribute2(+)=T.FLEX_VALUE_MEANING
    AND NVL(hra.inactive_date(+),trunc(sysdate))>= trunc(sysdate)
    AND LENGTH(TRIM(TRANSLATE(T.FLEX_VALUE_MEANING, ' +-.0123456789',' '))) IS NULL
    AND PAAF.people_group_id = PPG.people_group_id
                and papf.business_group_id!=0
                /*  and papf.business_group_id not in (select lookup_code from fnd_lookup_values
													where lookup_type = 'TTEC_EBS_DECOMMISION_COUNTRY'
													and language = 'US') -- Added as part of Cloud Migration--8.0 */ --9.0
                                group by  papf.npw_number, papf.first_name,
    papf.last_name,ppos.date_start,pjd.segment1,pjd.segment2,papf.date_of_birth, papf.business_group_id,papf.email_address,
    ppg.segment1, hra.country,papf1.employee_number,hra.location_code,papf.person_id,hou.name
    order by employee_number)q
                                where q.LocationSubsidiary='Percepta';
    /* (SELECT distinct pap.employee_number,
       pap.first_name,
       pap.last_name,
       (SELECT Max(pac.segment1)
        FROM   per_person_analyses ppa,
               per_special_info_types psit,
               per_analysis_criteria pac
        WHERE  pac.id_flex_num = '51172'
               AND psit.id_flex_num = pac.id_flex_num
               AND ppa.person_id (+) = pap.person_id
               AND pac.analysis_criteria_id (+) = ppa.analysis_criteria_id) AS  Email,
         NULL  Username,
       NULL    Password,
       -- ppos.date_start Hire_date,
      -- pap.start_date   Hire_date,
 (select max(ppos.date_start) from apps.per_periods_of_service ppos where  ppos.person_id = pap.person_id    )Hire_date,
       pap.date_of_birth   Birth_Date,
       --hou.name                  departmernt,
       --pj.name     ROLE
       --substr(pj.name, instr(pj.name, '.')+1,length(pj.name)) ROLE,
       pjd.segment1 Job_Code,pjd.segment2 Job_Name,
       --,--job,
       pa.country  Country_code,
       pap1.employee_number  supervisor,
       ppg.segment1  AS   Group_name,
       NULL Language,
       hla.location_code,
       hou.name Department
FROM   apps.per_all_people_f pap,
       apps.per_all_people_f pap1,
       apps.per_assignments_f paaf,
       apps.hr_all_organization_units hou,
       apps.per_person_types ppt,
       apps.per_person_type_usages_f pptu,
       ----apps.per_periods_of_service ppos,
       apps.per_jobs pj,apps.per_job_definitions pjd,
       apps.hr_locations_all hla,
       apps.pay_all_payrolls_f pprf,
       apps.per_pay_bases pb,
       apps.per_addresses pa,
       apps.pay_people_groups PPG
WHERE  pap.person_id = paaf.person_id
       AND pap.employee_number IS NOT NULL
       AND apps.paaf.supervisor_id = pap1.person_id
      -- AND apps.pap1.current_employee_flag = 'Y'  --16-08-2021 TASK2495082
       AND hou.organization_id = paaf.organization_id
       AND SYSDATE BETWEEN pap.effective_start_date AND pap.effective_end_date
       AND SYSDATE BETWEEN pap1.effective_start_date AND pap1.effective_end_date
       AND SYSDATE BETWEEN paaf.effective_start_date AND paaf.effective_end_date
       AND SYSDATE BETWEEN pprf.effective_start_date AND pprf.effective_end_date
       AND pap.person_id = pptu.person_id
       AND SYSDATE BETWEEN pptu.effective_start_date AND pptu.effective_end_date
       AND pptu.person_type_id = ppt.person_type_id
       AND ppt.system_person_type = 'EMP'
       --AND ppos.person_id = paaf.person_id
       AND pj.job_id = paaf.job_id
       and pj.job_definition_id=pjd.job_definition_id
       AND hla.location_id = paaf.location_id
       AND pprf.payroll_id = paaf.payroll_id (+)
       AND paaf.pay_basis_id = pb.pay_basis_id (+)
       AND pap.person_id = pa.person_id (+)
       AND SYSDATE BETWEEN pa.date_from AND Nvl(pa.date_to, To_date(
                                            '31-DEC-4712',
                                                            'DD-MON-RRRR'))
       AND pa.primary_flag = 'Y'
       AND pap.current_employee_flag = 'Y'
       -- and payroll_name like '%Percepta%'
       AND paaf.organization_id IN (SELECT organization_id
                                    FROM   apps.hr_all_organization_units
                                    WHERE  name LIKE '%PCTA%')
       AND PAAF.people_group_id = PPG.people_group_id

UNION
SELECT distinct pap.employee_number,
       pap.first_name,
       pap.last_name,
       (SELECT Max(pac.segment1)
        FROM   per_person_analyses ppa,
               per_special_info_types psit,
               per_analysis_criteria pac
        WHERE  pac.id_flex_num = '51172'
               AND psit.id_flex_num = pac.id_flex_num
               AND ppa.person_id (+) = pap.person_id
               AND pac.analysis_criteria_id (+) = ppa.analysis_criteria_id) AS  Email ,
       NULL  Username,
       NULL   Password,
       --ppos.start_date Hire_Date,
      -- pap.start_date      Hire_Date,
	   (select max(ppos.date_start) from apps.per_periods_of_service ppos where  ppos.person_id = pap.person_id    )Hire_date,
       pap.date_of_birth   Birth_Date,
       -- hou.name                  departmernt,
       --pj.name     ROLE
      -- substr(pj.name, instr(pj.name, '.')+1,length(pj.name)) ROLE
       pjd.segment1 Job_Code,pjd.segment2 Job_Name,
      -- ,--job,
       pa.country  Country_Code,
       pap1.employee_number  supervisor,
       ppg.segment1    AS   Group_name,
       NULL Language,
       hla.location_code,
       hou.name Department
FROM   apps.per_all_people_f pap,
       apps.per_all_people_f pap1,
       apps.per_assignments_f paaf,
       apps.hr_all_organization_units hou,
       apps.per_person_types ppt,
       apps.per_person_type_usages_f pptu,
       --apps.per_periods_of_service ppos,
       apps.per_jobs pj,apps.per_job_definitions pjd,
       apps.hr_locations_all hla,
       apps.pay_all_payrolls_f pprf,
       apps.per_pay_bases pb,
       apps.per_addresses pa,
       apps.pay_people_groups PPG
WHERE  pap.person_id = paaf.person_id
       AND pap.employee_number IS NOT NULL
       AND apps.paaf.supervisor_id = pap1.person_id
    --  AND apps.pap1.current_employee_flag = 'Y'  --16-08-2021 TASK2495082
       AND hou.organization_id = paaf.organization_id
       AND SYSDATE BETWEEN pap.effective_start_date AND pap.effective_end_date
       AND SYSDATE BETWEEN pap1.effective_start_date AND pap1.effective_end_date
       AND SYSDATE BETWEEN paaf.effective_start_date AND paaf.effective_end_date
       AND SYSDATE BETWEEN pprf.effective_start_date AND pprf.effective_end_date
       AND pap.person_id = pptu.person_id
       AND SYSDATE BETWEEN pptu.effective_start_date AND pptu.effective_end_date
       AND pptu.person_type_id = ppt.person_type_id
       AND ppt.system_person_type = 'EMP'
       --AND ppos.person_id = paaf.person_id
       AND pj.job_id = paaf.job_id
       and pj.job_definition_id=pjd.job_definition_id
       AND hla.location_id = paaf.location_id
       AND pprf.payroll_id = paaf.payroll_id (+)
       AND paaf.pay_basis_id = pb.pay_basis_id (+)
       AND pap.person_id = pa.person_id (+)
       AND SYSDATE BETWEEN pa.date_from AND Nvl(pa.date_to, To_date(
                                            '31-DEC-4712',
                                                            'DD-MON-RRRR'))
       AND pa.primary_flag = 'Y'
       AND pap.current_employee_flag = 'Y'
       AND payroll_name LIKE '%Percepta%'
       AND PAAF.people_group_id = PPG.people_group_id
     --  and pap.employee_number='1057158' )
UNION
SELECT distinct pap.employee_number,
       pap.first_name,
       pap.last_name,
       (SELECT Max(pac.segment1)
        FROM   per_person_analyses ppa,
               per_special_info_types psit,
               per_analysis_criteria pac
        WHERE  pac.id_flex_num = '51172'
               AND psit.id_flex_num = pac.id_flex_num
               AND ppa.person_id (+) = pap.person_id
               AND pac.analysis_criteria_id (+) = ppa.analysis_criteria_id) AS  Email ,
       NULL  Username,
       NULL   Password,
       --ppos.start_date Hire_Date,
      -- pap.start_date        Hire_Date,
	   (select max(ppos.date_start) from apps.per_periods_of_service ppos where  ppos.person_id = pap.person_id   )Hire_date,
       pap.date_of_birth   Birth_Date,
       -- hou.name                  departmernt,
       --pj.name     ROLE
      -- substr(pj.name, instr(pj.name, '.')+1,length(pj.name)) ROLE
       pjd.segment1 Job_Code,pjd.segment2 Job_Name,
      -- ,--job,
       pa.country  Country_Code,
       pap1.employee_number  supervisor,
       ppg.segment1    AS   Group_name,
       NULL Language,
       hla.location_code,
       hou.name Department
FROM   apps.per_all_people_f pap,
       apps.per_all_people_f pap1,
       apps.per_assignments_f paaf,
       apps.hr_all_organization_units hou,
       apps.per_person_types ppt,
       apps.per_person_type_usages_f pptu,
       --apps.per_periods_of_service ppos,
       apps.per_jobs pj,apps.per_job_definitions pjd,
       apps.hr_locations_all hla,
       apps.pay_all_payrolls_f pprf,
       apps.per_pay_bases pb,
       apps.per_addresses pa,
       apps.pay_people_groups PPG
WHERE  pap.person_id = paaf.person_id
       AND pap.employee_number IS NOT NULL
       AND apps.paaf.supervisor_id = pap1.person_id
     --  AND apps.pap1.current_employee_flag = 'Y' --16-08-2021 TASK2495082
       AND hou.organization_id = paaf.organization_id
       AND SYSDATE BETWEEN pap.effective_start_date AND pap.effective_end_date
       AND SYSDATE BETWEEN pap1.effective_start_date AND pap1.effective_end_date
       AND SYSDATE BETWEEN paaf.effective_start_date AND paaf.effective_end_date
       AND SYSDATE BETWEEN pprf.effective_start_date AND pprf.effective_end_date
       AND pap.person_id = pptu.person_id
       AND SYSDATE BETWEEN pptu.effective_start_date AND pptu.effective_end_date
       AND pptu.person_type_id = ppt.person_type_id
       AND ppt.system_person_type = 'EMP'
       --AND ppos.person_id = paaf.person_id
       AND pj.job_id = paaf.job_id
       and pj.job_definition_id=pjd.job_definition_id
       AND hla.location_id = paaf.location_id
       AND pprf.payroll_id = paaf.payroll_id (+)
       AND paaf.pay_basis_id = pb.pay_basis_id (+)
       AND pap.person_id = pa.person_id (+)
       AND SYSDATE BETWEEN pa.date_from AND Nvl(pa.date_to, To_date(
                                            '31-DEC-4712',
                                                            'DD-MON-RRRR'))
       AND pa.primary_flag = 'Y'
       AND pap.current_employee_flag = 'Y'
      AND paaf.ass_attribute27 like '%Percepta%'
       AND PAAF.people_group_id = PPG.people_group_id

--  and pap.employee_number='1057158' )

UNION
SELECT distinct pap.employee_number,
       pap.first_name,
       pap.last_name,
       (SELECT Max(pac.segment1)
        FROM   per_person_analyses ppa,
               per_special_info_types psit,
               per_analysis_criteria pac
        WHERE  pac.id_flex_num = '51172'
               AND psit.id_flex_num = pac.id_flex_num
               AND ppa.person_id (+) = pap.person_id
               AND pac.analysis_criteria_id (+) = ppa.analysis_criteria_id) AS  Email ,
       NULL  Username,
       NULL   Password,
       --ppos.start_date Hire_Date,
      -- pap.start_date        Hire_Date,
	   (select max(ppos.date_start) from apps.per_periods_of_service ppos where  ppos.person_id = pap.person_id   )Hire_date,
       pap.date_of_birth   Birth_Date,
       -- hou.name                  departmernt,
       --pj.name     ROLE
      -- substr(pj.name, instr(pj.name, '.')+1,length(pj.name)) ROLE
       pjd.segment1 Job_Code,pjd.segment2 Job_Name,
      -- ,--job,
       pa.country  Country_Code,
       pap1.employee_number  supervisor,
       ppg.segment1    AS   Group_name,
       NULL Language,
       hla.location_code,
       hou.name Department
FROM   apps.per_all_people_f pap,
       apps.per_all_people_f pap1,
       apps.per_assignments_f paaf,
       apps.hr_all_organization_units hou,
       apps.per_person_types ppt,
       apps.per_person_type_usages_f pptu,
       --apps.per_periods_of_service ppos,
       apps.per_jobs pj,apps.per_job_definitions pjd,
       apps.hr_locations_all hla,
       apps.pay_all_payrolls_f pprf,
       apps.per_pay_bases pb,
       apps.per_addresses pa,
       apps.pay_people_groups PPG
WHERE  pap.person_id = paaf.person_id
       AND pap.employee_number IS NOT NULL
       AND apps.paaf.supervisor_id = pap1.person_id
     --  AND apps.pap1.current_employee_flag = 'Y' --16-08-2021 TASK2495082
       AND hou.organization_id = paaf.organization_id
       AND SYSDATE BETWEEN pap.effective_start_date AND pap.effective_end_date
       AND SYSDATE BETWEEN pap1.effective_start_date AND pap1.effective_end_date
       AND SYSDATE BETWEEN paaf.effective_start_date AND paaf.effective_end_date
       AND SYSDATE BETWEEN pprf.effective_start_date AND pprf.effective_end_date
       AND pap.person_id = pptu.person_id
       AND SYSDATE BETWEEN pptu.effective_start_date AND pptu.effective_end_date
       AND pptu.person_type_id = ppt.person_type_id
       AND ppt.system_person_type = 'EMP'
       --AND ppos.person_id = paaf.person_id
       AND pj.job_id = paaf.job_id
       and pj.job_definition_id=pjd.job_definition_id
       AND hla.location_id = paaf.location_id
       AND pprf.payroll_id = paaf.payroll_id (+)
       AND paaf.pay_basis_id = pb.pay_basis_id (+)
       AND pap.person_id = pa.person_id (+)
       AND SYSDATE BETWEEN pa.date_from AND Nvl(pa.date_to, To_date(
                                            '31-DEC-4712',
                                                            'DD-MON-RRRR'))
       AND pa.primary_flag = 'Y'
       AND pap.current_employee_flag = 'Y'
      AND upper(hla.location_code) like upper('%percep%')
       AND PAAF.people_group_id = PPG.people_group_id

--  and pap.employee_number='1057158' )
UNION
(SELECT distinct pap.employee_number,
       pap.first_name,
       pap.last_name,
       (SELECT Max(pac.segment1)
        FROM   per_person_analyses ppa,
               per_special_info_types psit,
               per_analysis_criteria pac
        WHERE  pac.id_flex_num = '51172'
               AND psit.id_flex_num = pac.id_flex_num
               AND ppa.person_id (+) = pap.person_id
               AND pac.analysis_criteria_id (+) = ppa.analysis_criteria_id) AS  Email ,
       NULL  Username,
       NULL   Password,
       --ppos.start_date Hire_Date,
      -- pap.start_date        Hire_Date,
	   (select max(ppos.date_start) from apps.per_periods_of_service ppos where  ppos.person_id = pap.person_id    )Hire_date,
       pap.date_of_birth   Birth_Date,
       -- hou.name                  departmernt,
       --pj.name     ROLE
      -- substr(pj.name, instr(pj.name, '.')+1,length(pj.name)) ROLE
       --,--job,
        pjd.segment1 Job_Code,pjd.segment2 Job_Name,
       pa.country  Country_Code,
       pap1.employee_number  supervisor,
       ppg.segment1    AS   Group_name,
       NULL Language,
       hla.location_code,
       hou.name Department
FROM   apps.per_all_people_f pap,
       apps.per_all_people_f pap1,
       apps.per_assignments_f paaf,
       apps.hr_all_organization_units hou,
       apps.per_person_types ppt,
       apps.per_person_type_usages_f pptu,
       --apps.per_periods_of_service ppos,
       apps.per_jobs pj,apps.per_job_definitions pjd,
       apps.hr_locations_all hla,
       apps.pay_all_payrolls_f pprf,
       apps.per_pay_bases pb,
       apps.per_addresses pa,
       apps.pay_people_groups PPG
WHERE  pap.person_id = paaf.person_id
       AND pap.employee_number IS NOT NULL
       AND apps.paaf.supervisor_id = pap1.person_id
      -- AND apps.pap1.current_employee_flag = 'Y' --16-08-2021 TASK2495082
       AND hou.organization_id = paaf.organization_id
       AND SYSDATE BETWEEN pap.effective_start_date AND pap.effective_end_date
       AND SYSDATE BETWEEN pap1.effective_start_date AND pap1.effective_end_date
       AND SYSDATE BETWEEN paaf.effective_start_date AND paaf.effective_end_date
       AND SYSDATE BETWEEN pprf.effective_start_date AND pprf.effective_end_date
       AND pap.person_id = pptu.person_id
       AND SYSDATE BETWEEN pptu.effective_start_date AND pptu.effective_end_date
       AND pptu.person_type_id = ppt.person_type_id
       AND ppt.system_person_type = 'EMP'
       --AND ppos.person_id = paaf.person_id
       AND pj.job_id = paaf.job_id
       and pj.job_definition_id=pjd.job_definition_id
       AND hla.location_id = paaf.location_id
       AND pprf.payroll_id = paaf.payroll_id (+)
       AND paaf.pay_basis_id = pb.pay_basis_id (+)
       AND pap.person_id = pa.person_id (+)
       AND SYSDATE BETWEEN pa.date_from AND Nvl(pa.date_to, To_date(
                                            '31-DEC-4712',
                                                            'DD-MON-RRRR'))
       AND pa.primary_flag = 'Y'
       AND pap.current_employee_flag = 'Y'
      -- AND payroll_name LIKE '%Percepta%'
     -- AND paaf.ass_attribute27 like '%Percepta%'
       AND PAAF.people_group_id = PPG.people_group_id
       AND (SELECT Max(pac.segment1)
            FROM   per_person_analyses ppa,
                   per_special_info_types psit,
                   per_analysis_criteria pac
            WHERE  pac.id_flex_num = '51172'
                   AND psit.id_flex_num = pac.id_flex_num
                   AND ppa.person_id (+) = pap.person_id
                   AND pac.analysis_criteria_id (+) = ppa.analysis_criteria_id)  IS NOT NULL))

UNION
---Adding CWK logic
SELECT distinct pap.npw_number,
       pap.first_name,
       pap.last_name,
       (SELECT Max(pac.segment1)
        FROM   per_person_analyses ppa,
               per_special_info_types psit,
               per_analysis_criteria pac
        WHERE  pac.id_flex_num = '51172'
               AND psit.id_flex_num = pac.id_flex_num
               AND ppa.person_id (+) = pap.person_id
               AND pac.analysis_criteria_id (+) = ppa.analysis_criteria_id) AS  Email,
         NULL  Username,
         NULL    Password,
       -- ppos.date_start Hire_date,
      -- pap.start_date   Hire_date,
	   (select max(ppos.date_start) from apps.per_periods_of_placement ppos where  ppos.person_id = pap.person_id    )Hire_date,
       pap.date_of_birth   Birth_Date,
       --hou.name                  departmernt,
       --pj.name     ROLE
       --substr(pj.name, instr(pj.name, '.')+1,length(pj.name)) ROLE
      -- ,--job,
       pjd.segment1 Job_Code,pjd.segment2 Job_Name,
       pa.country  Country_code,
       pap1.employee_number  supervisor,
       NULL   Group_name,
       NULL Language,
       hla.location_code,
       hou.name Department
FROM   apps.per_all_people_f pap,
       apps.per_all_people_f pap1,
       apps.per_assignments_f paaf,
       apps.hr_all_organization_units hou,
          apps.per_jobs pj,apps.per_job_definitions pjd,
         apps.hr_locations_all hla,
           apps.per_addresses pa
       WHERE  pap.person_id = paaf.person_id
         AND pap.npw_number IS NOT NULL
        -- AND  pap.npw_number='9832312'--'9832351'
         AND apps.paaf.supervisor_id = pap1.person_id
      -- AND apps.pap1.current_employee_flag = 'Y'
        AND hou.organization_id = paaf.organization_id
        AND pj.job_id = paaf.job_id
        and pj.job_definition_id=pjd.job_definition_id
        AND hla.location_id = paaf.location_id
        AND pap.person_id = pa.person_id (+)

      -- AND pa.primary_flag = 'Y'
       AND pap.current_npw_flag = 'Y'
       AND upper(hla.location_code) like upper('%percep%')
       AND SYSDATE BETWEEN pap.effective_start_date AND pap.effective_end_date
       AND SYSDATE BETWEEN pap1.effective_start_date AND pap1.effective_end_date
       AND SYSDATE BETWEEN paaf.effective_start_date AND paaf.effective_end_date
        ;*/

     CURSOR c_host
    IS
      SELECT host_name
            ,instance_name
        FROM v$instance;


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

    FETCH c_host
     INTO l_host_name
         ,l_instance_name;

    CLOSE c_host;

    IF l_host_name NOT IN (ttec_library.xx_ttec_prod_host_name)
    THEN
      l_identifier   := 'TEST_TTEC_';  --changes 2.0
      --changes 1.1
    ELSE
      l_identifier   := 'TTEC_'; --changes 2.0
    END IF;

    FND_FILE.PUT_LINE (FND_FILE.LOG, 'Host Name:');
      BEGIN
       SELECT '.csv'
           ,TO_CHAR (SYSDATE, 'yyyymmdd_HHMISS') -- ,TO_CHAR (SYSDATE, 'yyyymmdd_HH24MI')
         INTO v_file_extn
             ,v_time
         FROM v$instance;
     EXCEPTION
       WHEN OTHERS
       THEN
         v_file_extn   := '.csv';
     END;
    FND_FILE.PUT_LINE (FND_FILE.LOG, 'extension name:');
    v_out_file   := l_identifier || 'Awardco_R12_' ||v_time||'.csv';  --changes 2.0
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
       utl_file.put_line(v_emp_file,('Employee Id')
                                     || '|'
                                     ||('First Name')
                                     || '|'
                                     ||('Last Name')
                                     || '|'
                                     ||('Email')
                                      || '|'
                                     ||('Username')
                                      || '|'
                                     ||('Password')
                                      || '|'
                                     ||('Hire Date')
                                      || '|'
                                     ||('Birth Date')
                                      || '|'
                                    --||('Role')
                                      --|| '|'
                                     ||('Job Code')
                                      || '|'
                                     ||('Job Name')
                                      || '|'
                                     ||('Country Code')
                                      || '|'
                                     ||('Supervisor Id')
                                      || '|'
                                     ||('Language')
                                     || '|'
                                     ||('Location')
                                     || '|'
                                     ||('Department')
                                     );
                                          v_text :=  (('Employee Id')
                                     || '|'
                                     ||('First Name')
                                     || '|'
                                     ||('Last Name')
                                     || '|'
                                     ||('Email')
                                      || '|'
                                     ||('Username')
                                      || '|'
                                     ||('Password')
                                      || '|'
                                     ||('Hire Date')
                                      || '|'
                                     ||('Birth Date')
                                      || '|'
                                     --||('Role')
                                      --|| '|'
                                     ||('Job Code')
                                      || '|'
                                     ||('Job Name')
                                      || '|'
                                     ||('Country Code')
                                      || '|'
                                     ||('Supervisor Id')
                                      || '|'
                                     ||('Language')
                                     || '|'
                                     ||('Location')
                                     || '|'
                                     ||('Department'));

            fnd_file.put_line (fnd_file.output, v_text);

        FOR c1 IN c_emp_info LOOP utl_file.put_line(v_emp_file,'"'||(c1.employee_number)||'"'
                                                            || '|'
                                                            ||'"'||REPLACE((c1.first_name),',','')||'"'
                                                            || '|'
                                                            ||'"'||REPLACE((c1.last_name),',','')||'"'
                                                            || '|'
                                                            ||'"'||REPLACE((REPLACE(LTRIM(RTRIM(REPLACE((replace(replace(c1.email, chr(13), ''), chr(10), '')), '"', ''))), '', '"')),',','')||'"'
                                                            || '|'
                                                            ||'"'||c1.Username||'"'
                                                             || '|'
                                                            ||'"'||c1.Password||'"'
                                                             || '|'
                                                            ||'"'||to_char(c1.Hire_date,'mm/dd/yyyy')||'"'
                                                             || '|'
                                                            ||'"'||to_char(c1.Birth_Date,'mm/dd')||'"'
                                                             || '|'
                                                          --  ||REPLACE((c1.ROLE),',','')
                                                            ||'"'||REPLACE((c1.Job_Code),',','')||'"'
                                                              || '|'
                                                              ||'"'||REPLACE((c1.Job_Name),',','')||'"'
                                                              || '|'
                                                            ||'"'||REPLACE((c1.Country_code),',','')||'"'
                                                             || '|'
                                                            ||'"'||REPLACE((c1.supervisor),',','')||'"'
                                                             || '|'
                                                            ||'"'||(c1.Language)||'"'
                                                              || '|'
                                                            ||'"'||REPLACE((c1.Location_code),',','')||'"'
                                                              || '|'
                                                            ||'"'||REPLACE((c1.Department),',','')||'"'
                                                           );





                 v_text2 :=                                 ('"'||(c1.employee_number)||'"'
                                                            || '|'
                                                            ||'"'||REPLACE((c1.first_name),',','')||'"'
                                                            || '|'
                                                            ||'"'||REPLACE((c1.last_name),',','')||'"'
                                                            || '|'
                                                           -- ||REPLACE((c1.Email),',','')
                                                            ||'"'||REPLACE((REPLACE(LTRIM(RTRIM(REPLACE((replace(replace(c1.email, chr(13), ''), chr(10), '')), '"', ''))), '', '"')),',','')||'"'
                                                            || '|'
                                                            ||'"'||c1.Username||'"'
                                                            || '|'
                                                            ||'"'||c1.Password||'"'
                                                            || '|'
                                                            ||'"'||to_char(c1.Hire_date,'mm/dd/yyyy')||'"'
                                                            || '|'
                                                            ||'"'||to_char(c1.Birth_Date,'mm/dd')||'"'
                                                            || '|'
                                                           -- ||REPLACE((c1.ROLE),',','')
                                                            ||'"'||REPLACE((c1.Job_Code),',','')||'"'
                                                              || '|'
                                                              ||'"'||REPLACE((c1.Job_Name),',','')||'"'
                                                              || '|'
                                                             ||'"'||REPLACE((c1.Country_code),',','')||'"'
                                                             || '|'
                                                            ||'"'||REPLACE((c1.supervisor),',','')||'"'
                                                             || '|'
                                                            ||'"'||(c1.Language)||'"'
                                                              || '|'
                                                            ||'"'||REPLACE((c1.Location_code),',','')||'"'
                                                              || '|'
                                                            ||'"'||REPLACE((c1.Department),',','')||'"');



                fnd_file.put_line (fnd_file.output, v_text2);

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

END main_proc;

END ttec_awardco_intf_pkg;
/
show errors;
/