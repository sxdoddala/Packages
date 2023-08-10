create or replace PACKAGE BODY XXTELETECH_EMP_BEN_EN_EXTR
 /********************************************************************************
  PROGRAM NAME:   XXTELETECH_EMP_BEN_EN_EXTR
  DESCRIPTION:    This package extracts PEO Employee Benefit Enrollment information
  for all Employees effective from JAN-01-2014.
  INPUT      :    None
  OUTPUT     :
  CREATED BY:     Vinayak Hiremath
  DATE:           10-NOV-2013
  CALLING FROM   :  Teletech PEO Employee Benefit Enrollment Details Extract Program
  ----------------
  MODIFICATION LOG
  ----------------
  DEVELOPER             DATE          DESCRIPTION
  -------------------   ------------  -----------------------------------------
  Vinayak Hiremath    10-Nov-2013   Initial Version
  IXPRAVEEN(ARGANO)	1.0		09-May-2023 R12.2 Upgrade Remediation
  ********************************************************************************/

 AS

PROCEDURE MAIN (x_errcode     OUT      NUMBER,
                x_errbuff     OUT      VARCHAR2)
IS

--#################################### VARIABLE DECLARATION ################################ --

v_dt_time        VARCHAR2(100);
v_path           VARCHAR2(400);
v_date           DATE;
v_date_jan_2014  DATE;
v_days           NUMBER;
v_columns_str    VARCHAR2(4000);
v_header         VARCHAR2(4000);
v_string         VARCHAR2(10000);
SQ               VARCHAR2(10):=CHR(39);

--################################### CURSOR DECLARATION #####################################--

CURSOR emp_det(p_date DATE)
IS
SELECT   'ADD' action,
       pen.prtt_enrt_rslt_id,
       xx_dep.ELIG_CVRD_DPNT_ID,
       pap.employee_number employee_number,
       pap.full_name full_name,
       DECODE(BPL.PL_ID,691,DECODE((
SELECT DECODE((SELECT COUNT(*)
FROM PER_PERSON_ANALYSES PAA,
     PER_ANALYSIS_CRITERIA PAC,
      PER_ALL_PEOPLE_F PAP3
WHERE PAA.BUSINESS_GROUP_ID=325
AND PAA.ID_FLEX_NUM =    (SELECT ID_FLEX_NUM
                           FROM FND_ID_FLEX_STRUCTURES
                           WHERE ID_FLEX_STRUCTURE_CODE = 'TTEC_HEALTH_ASSESSMENT' --'US Health Assessment'
                          AND ENABLED_FLAG ='Y')
AND TRUNC(p_date) BETWEEN PAA.DATE_FROM AND PAA.DATE_TO
AND PAC.ANALYSIS_CRITERIA_ID = PAA.ANALYSIS_CRITERIA_ID
AND PAC.ENABLED_FLAG='Y'
AND PAC.SEGMENT1='Y'
AND PAA.PERSON_ID = PAP3.PERSON_ID
AND TRUNC(p_date) BETWEEN PAP3.EFFECTIVE_START_DATE AND EFFECTIVE_END_DATE
AND PAA.PERSON_ID = PAP.PERSON_ID),0,'A','B') FROM DUAL
),'A','BAL0002','BAL0001'),
247,'METLIFE48',246,'METLIFE47',4871,'DELTA07',262,'DELTA06',275,'AIG001',272,'METLIFE46',258,'METLIFE45',254,'METLIFE50',256,'METLIFE53',260,'METLIFE52',250,'METLIFE51',252,'METLIFE49',264,'VSP008',277,'METLIFE53',278,'METLIFE51') VIN_PLAN,
       decode(bpl.pl_id,247,null,246,null,272,null,254,null,opt.name) vin_OPTION,
       pap.first_name first_name,
       pap.last_name last_name,
       pap.national_identifier social_num,
       DECODE(bpl.pl_id, 260,pen.bnft_amt,245,pen.bnft_amt,248,pen.bnft_amt,256,pen.bnft_amt,277,pen.bnft_amt,247,(SELECT TRUNC((PROPOSED_SALARY_N * 2080),3)
                                                                                       FROM PER_PAY_PROPOSALS PPP,
                                                                                            PER_ALL_ASSIGNMENTS_F PAA
                                                                                       WHERE PPP.ASSIGNMENT_ID = PAA.ASSIGNMENT_ID
                                                                                       AND   PAA.PERSON_ID     = PAP.PERSON_ID
                                                                                       AND TRUNC(p_date) BETWEEN PAA.EFFECTIVE_START_DATE AND PAA.EFFECTIVE_END_DATE)
                                                                                        ,246, (SELECT TRUNC((PROPOSED_SALARY_N * 2080),3)
                                                                                       FROM PER_PAY_PROPOSALS PPP,
                                                                                            PER_ALL_ASSIGNMENTS_F PAA
                                                                                       WHERE PPP.ASSIGNMENT_ID = PAA.ASSIGNMENT_ID
                                                                                       AND   PAA.PERSON_ID     = PAP.PERSON_ID
                                                                                       AND TRUNC(p_date) BETWEEN PAA.EFFECTIVE_START_DATE AND PAA.EFFECTIVE_END_DATE)
                                                                                        ,272, (SELECT TRUNC((0.6 * (PROPOSED_SALARY_N) * 2080)/12,3)
                                                                                       FROM PER_PAY_PROPOSALS PPP,
                                                                                            PER_ALL_ASSIGNMENTS_F PAA
                                                                                       WHERE PPP.ASSIGNMENT_ID = PAA.ASSIGNMENT_ID
                                                                                       AND   PAA.PERSON_ID     = PAP.PERSON_ID
                                                                                       AND TRUNC(p_date) BETWEEN PAA.EFFECTIVE_START_DATE AND PAA.EFFECTIVE_END_DATE)
                                                                                       ,258, (SELECT TRUNC((1 * (PROPOSED_SALARY_N) * 2080)/52,3)
                                                                                       FROM PER_PAY_PROPOSALS PPP,
                                                                                            PER_ALL_ASSIGNMENTS_F PAA
                                                                                       WHERE PPP.ASSIGNMENT_ID = PAA.ASSIGNMENT_ID
                                                                                       AND   PAA.PERSON_ID     = PAP.PERSON_ID
                                                                                       AND TRUNC(p_date) BETWEEN PAA.EFFECTIVE_START_DATE AND PAA.EFFECTIVE_END_DATE) ) emp_cvg,
        DECODE(bpl.pl_id, 250,pen.bnft_amt,278,pen.bnft_amt,252,pen.bnft_amt) sps_cvg,
        DECODE(bpl.pl_id, 254,pen.bnft_amt) dep_cvg,
       -- pen.effective_start_date effective_date,
        pen.enrt_cvg_strt_dt effective_date,
        (SELECT MAX(rates.rt_strt_dt)
       -- FROM ben.ben_prtt_rt_val rates			-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
        FROM apps.ben_prtt_rt_val rates          --  code Added by IXPRAVEEN-ARGANO,   09-May-2023
        WHERE rates.prtt_enrt_rslt_id = pen.prtt_enrt_rslt_id
        AND TRUNC(p_date) BETWEEN RT_STRT_DT AND RT_END_DT) ded_start_date,
        DECODE(pen.pl_id,691,DECODE(SUBSTR(opt.name,1,8),'Post Tax','N','Y'),247,'N',246,'N',4871,DECODE(SUBSTR(opt.name,1,8),'Post Tax','N','Y'),262,DECODE(SUBSTR(opt.name,1,8),'Post Tax','N','Y'),248,'Y',275,'N',245,'Y',272,'N',258,'N',254,'N',256,'N',277,'N',260,'N',250,'N',278,'N',252,'N',264,DECODE(SUBSTR(opt.name,1,8),'Post Tax','N','Y'),263,'N',249,'N',276,'N',273,'N',268,'N',259,'N',255,'N',257,'N',261,'N',251,'N',253,'N',265,'N') sec_125,
        dep_social_num,
        dep_cont_f_name,
        dep_cont_l_name,
        dep_contact_type,
        dep_dob,
        pen.pl_id
--START R12.2 Upgrade Remediation
/*FROM   hr.per_all_people_f pap,				-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
       ben.BEN_PRTT_ENRT_RSLT_F pen,*/
FROM   apps.per_all_people_f pap,				--  code Added by IXPRAVEEN-ARGANO,   09-May-2023
       apps.BEN_PRTT_ENRT_RSLT_F pen,
--END R12.2.10 Upgrade remediation	   
       (SELECT *
       --FROM ben.ben_pl_f					-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
       FROM apps.ben_pl_f                 --  code Added by IXPRAVEEN-ARGANO,   09-May-2023
       WHERE trunc(p_date) BETWEEN effective_start_date AND effective_END_date
       AND pl_id IN (691,247,246,4871,262,275,272,258,254,256,277,260,250,278,252,264)
       AND pl_typ_id IN (86,22,26,32,87,85,31,24,37,30,25,23,29,27,28)) BPL,
       (SELECT *
       --FROM ben.ben_opt_f					-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
       FROM apps.ben_opt_f                   --  code Added by IXPRAVEEN-ARGANO,   09-May-2023
       WHERE trunc(p_date) BETWEEN effective_start_date AND effective_END_date) opt,
       --ben.BEN_OIPL_F opl,				-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
       apps.BEN_OIPL_F opl,              --  code Added by IXPRAVEEN-ARGANO,   09-May-2023
       (SELECT papf_cont.national_identifier dep_social_num,
               papf_cont.first_name dep_cont_f_name,
               papf_cont.last_name dep_cont_l_name,
               hl.meaning dep_contact_type,
               papf_cont.date_of_birth dep_dob,
               dep.prtt_enrt_rslt_id prtt_enrt_rslt_id,
               dep.ELIG_CVRD_DPNT_ID,
               dep.cvg_thru_dt,
               pap1.person_id,
               dep.last_update_date,
               papf_cont.person_id dep_person_id
                FROM PER_ALL_PEOPLE_F papf_cont,
                      PER_CONTACT_RELATIONSHIPS pcr,
                      --ben.BEN_ELIG_CVRD_DPNT_F dep,				-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
                      apps.BEN_ELIG_CVRD_DPNT_F dep,             --  code Added by IXPRAVEEN-ARGANO,   09-May-2023
                      PER_ALL_PEOPLE_F pap1,
                      HR_LOOKUPS hl
                  WHERE pcr.person_id = pap1.person_id
                  AND pcr.contact_person_id = papf_cont.person_id
                  AND trunc(p_date) BETWEEN papf_cont.effective_start_date AND papf_cont.effective_END_date
                  AND trunc(p_date) BETWEEN pap1.effective_start_date AND pap1.effective_END_date
                  AND trunc(p_date) BETWEEN dep.effective_start_date AND dep.effective_END_date
                  AND trunc(p_date) BETWEEN dep.cvg_strt_dt AND dep.cvg_thru_dt
                  AND dep.dpnt_person_id = pcr.contact_person_id
                  AND hl.lookup_type(+) = 'CONTACT'
                  AND hl.lookup_code(+) = pcr.contact_type
                  ) xx_dep
       WHERE
    --   AND opl.oipl_id IN (783,785,1141,787,786,788,784,1275,1297,1276,1296,1281,1302,1280,1301,1279,1300,1278,1299,1277,1298,1282,1303,1283,1304,1288,1309,1287,1308,1286,1307,1285,1306,1284,1305,711,710,3515,7520,3530,3519,3518,3517,7519,3520,7517,3531,3524,3523,3522,7518,713,4522,1137,717,716,715,4521,718,4524,1138,722,721,720,4523,782,712,723,724,1139,727,726,725,800,801,1144,804,803,802,728,729,1140,732,731,730)
       pen.pl_id = bpl.pl_id
       AND pen.person_id = pap.person_id
       AND xx_dep.person_id(+)=pen.person_id
       AND trunc(p_date) BETWEEN pen.enrt_cvg_strt_dt AND pen.enrt_cvg_thru_dt
       AND trunc(p_date) BETWEEN pen.effective_start_date AND pen.effective_END_date
       AND  pen.prtt_enrt_rslt_stat_cd IS NULL
       AND opl.opt_id = opt.opt_id(+)
       AND pen.oipl_id = opl.oipl_id(+)
       AND trunc(p_date) BETWEEN pap.effective_start_date AND pap.effective_END_date
       AND hr_person_type_usage_info.get_user_person_type ( trunc(pap.effective_start_date), pap.person_id ) = 'PEO Employee'
       AND pap.current_employee_flag = 'Y'
       AND pap.business_group_id = 325
       AND xx_dep.prtt_enrt_rslt_id(+) = pen.prtt_enrt_rslt_id
      --AND pap.employee_number= '3148737'--'3153282'
ORDER BY
      pap.employee_number;

-- ################################## BEGIN ############################################## --

BEGIN

SELECT to_char(sysdate,'YYYYMONDDHH24MISS') into v_dt_time FROM dual;



FND_FILE.PUT_LINE(FND_FILE.LOG,'Time : '||v_dt_time);

SELECT TRUNC(SYSDATE) INTO v_date FROM dual;

SELECT TRUNC(TO_DATE('01-JAN-2014')) INTO v_date_jan_2014 FROM DUAL;

SELECT v_date_jan_2014 - v_date INTO v_days FROM DUAL;

if ( v_days > 0) then

v_date:= v_date_jan_2014;

else

SELECT TRUNC(SYSDATE) INTO v_date FROM dual;

END if;

BEGIN
SELECT directory_path || '/data/EBS/HC/HR/PEO/outbound/' into v_path --add PEO
FROM dba_directories
WHERE directory_name = 'CUST_TOP';

EXCEPTION
WHEN OTHERS THEN
fnd_file.put_line(fnd_file.log,'Program did not get destination directory : '||sqlerrm);
raise;
END ;

XXTELETECH_EMP_BEN_EN_EXTR.write_process('TELETECH_PEO_ENROLLMENT_'||v_dt_time||'.txt','','W',v_path);


  FOR cur_emp_det IN emp_det(v_date)

  loop

--v_columns_str := cur_emp_det.action||'	'||cur_emp_det.vin_plan||'	'||cur_emp_det.vin_option||'	'||cur_emp_det.first_name||'	'||cur_emp_det.last_name||'	'||cur_emp_det.social_num||'	'||cur_emp_det.effective_date||'	'||cur_emp_det.ded_start_date||'	'||cur_emp_det.sec_125||'	'||cur_emp_det.dep_social_num||'	'||cur_emp_det.dep_cont_f_name||'	'||cur_emp_det.dep_cont_l_name||'	'||cur_emp_det.dep_contact_type||'	'||cur_emp_det.dep_dob;
v_columns_str := cur_emp_det.action||'	'||1895||'	'||cur_emp_det.vin_plan||'	'||cur_emp_det.vin_option||'	'||cur_emp_det.first_name||'	'||cur_emp_det.last_name||'	'||cur_emp_det.social_num||'	'||cur_emp_det.emp_cvg||'	'||cur_emp_det.sps_cvg||'	'||cur_emp_det.dep_cvg||'	'||TO_CHAR(cur_emp_det.effective_date,'MM/DD/YYYY')||'	'||TO_CHAR(cur_emp_det.ded_start_date,'MM/DD/YYYY')||'	'||cur_emp_det.sec_125||'	'||cur_emp_det.dep_social_num||'	'||cur_emp_det.dep_cont_f_name||'	'||cur_emp_det.dep_cont_l_name||'	'||cur_emp_det.dep_contact_type||'	'||TO_CHAR(cur_emp_det.dep_dob,'MM/DD/YYYY');


fnd_file.put_line(fnd_file.output,v_columns_str);

    XXTELETECH_EMP_BEN_EN_EXTR.write_process('TELETECH_PEO_ENROLLMENT_'||v_dt_time||'.txt', v_columns_str,'A',v_path);

  END loop;



fnd_file.put_line(fnd_file.log, 'DROPPING TABLE');

BEGIN

EXECUTE IMMEDIATE ('DROP TABLE XXTELETECH_EMP_BEN_EN_TAB');

EXCEPTION
WHEN OTHERS THEN
FND_FILE.PUT_LINE(FND_FILE.LOG,'TABLE DOES NOT EXIST, HENCE CREATING');

END;

V_STRING:= 'CREATE TABLE XXTELETECH_EMP_BEN_EN_TAB AS SELECT          pen.prtt_enrt_rslt_id,'||
    '    xx_dep.ELIG_CVRD_DPNT_ID, '||
    '   pap.employee_number employee_number, '||
     '  pap.full_name full_name, '||
    '   DECODE(BPL.PL_ID,691,DECODE(( '||
' SELECT DECODE((SELECT COUNT(*) '||
 ' FROM PER_PERSON_ANALYSES PAA,
     PER_ANALYSIS_CRITERIA PAC,
      PER_ALL_PEOPLE_F PAP3
WHERE PAA.BUSINESS_GROUP_ID=325
AND PAA.ID_FLEX_NUM IN (SELECT ID_FLEX_NUM
                           FROM FND_ID_FLEX_STRUCTURES
                           WHERE ID_FLEX_STRUCTURE_CODE = '||SQ||'TTEC_HEALTH_ASSESSMENT'||SQ||
                        '  AND ENABLED_FLAG ='||SQ||'Y'||SQ||')
AND '||SQ||v_date||SQ||' BETWEEN PAA.DATE_FROM AND PAA.DATE_TO
AND PAC.ANALYSIS_CRITERIA_ID = PAA.ANALYSIS_CRITERIA_ID
AND PAC.ENABLED_FLAG= '||SQ||'Y'||SQ||
' AND PAC.SEGMENT1='||SQ||'Y'||SQ||
' AND PAA.PERSON_ID = PAP3.PERSON_ID
AND '||SQ||v_date||SQ||' BETWEEN PAP3.EFFECTIVE_START_DATE AND EFFECTIVE_END_DATE
AND PAA.PERSON_ID = PAP.PERSON_ID),0,'||SQ||'A'||SQ||','||SQ||'B'||SQ||') FROM DUAL
),'||SQ||'A'||SQ||','||SQ||'BAL0002'||SQ||','||SQ||'BAL0001'||SQ|| '),
247,'||SQ||'METLIFE48'||SQ||',246,'||SQ||'METLIFE47'||SQ||',4871,'||SQ||'DELTA07'||SQ||',262,'||SQ||'DELTA06'||SQ||',275,'||SQ||'AIG001'||SQ||',272,'||SQ||'METLIFE46'||SQ||',258,'||SQ||'METLIFE45'||SQ||',254,'||SQ||'METLIFE50'||SQ||',256,'||SQ||'METLIFE53'||SQ||',260,'||SQ||'METLIFE52'||SQ||',250,'||SQ||'METLIFE51'||SQ||',252,'||SQ||'METLIFE49'||SQ||',264,'||SQ||'VSP008'||SQ||',277,'||SQ||'METLIFE53'||SQ||',278,'||SQ||'METLIFE51'||SQ||') VIN_PLAN, '||
     '  decode(bpl.pl_id,247,null,246,null,272,null,254,null,opt.name) vin_OPTION,'||
    '   pap.first_name first_name, '||
    '   pap.last_name last_name, '||
     '  pap.national_identifier social_num, '||
    '   DECODE(bpl.pl_id, 260,pen.bnft_amt,245,pen.bnft_amt,248,pen.bnft_amt,256,pen.bnft_amt,277,pen.bnft_amt,247,(SELECT TRUNC((PROPOSED_SALARY_N * 2080),3)
                                                                                       FROM PER_PAY_PROPOSALS PPP,
                                                                                            PER_ALL_ASSIGNMENTS_F PAA
                                                                                       WHERE PPP.ASSIGNMENT_ID = PAA.ASSIGNMENT_ID
                                                                                       AND   PAA.PERSON_ID     = PAP.PERSON_ID
                                                                                        AND '||SQ||v_date||SQ||' BETWEEN PAA.EFFECTIVE_START_DATE AND PAA.EFFECTIVE_END_DATE)
                                                                                        ,246, (SELECT TRUNC((PROPOSED_SALARY_N * 2080),3)
                                                                                       FROM PER_PAY_PROPOSALS PPP,
                                                                                            PER_ALL_ASSIGNMENTS_F PAA
                                                                                       WHERE PPP.ASSIGNMENT_ID = PAA.ASSIGNMENT_ID
                                                                                       AND   PAA.PERSON_ID     = PAP.PERSON_ID
                                                                                        AND '||SQ||v_date||SQ||' BETWEEN PAA.EFFECTIVE_START_DATE AND PAA.EFFECTIVE_END_DATE)
                                                                                        ,272, (SELECT TRUNC((0.6 * (PROPOSED_SALARY_N) * 2080)/12,3)
                                                                                       FROM PER_PAY_PROPOSALS PPP,
                                                                                            PER_ALL_ASSIGNMENTS_F PAA
                                                                                       WHERE PPP.ASSIGNMENT_ID = PAA.ASSIGNMENT_ID
                                                                                       AND   PAA.PERSON_ID     = PAP.PERSON_ID
                                                                                        AND '||SQ||v_date||SQ||' BETWEEN PAA.EFFECTIVE_START_DATE AND PAA.EFFECTIVE_END_DATE)
                                                                                       ,258, (SELECT TRUNC((1 * (PROPOSED_SALARY_N) * 2080)/52,3)
                                                                                       FROM PER_PAY_PROPOSALS PPP,
                                                                                            PER_ALL_ASSIGNMENTS_F PAA
                                                                                       WHERE PPP.ASSIGNMENT_ID = PAA.ASSIGNMENT_ID
                                                                                       AND   PAA.PERSON_ID     = PAP.PERSON_ID
                                                                                        AND '||SQ||v_date||SQ||' BETWEEN PAA.EFFECTIVE_START_DATE AND PAA.EFFECTIVE_END_DATE) ) emp_cvg, '||
     '  DECODE(bpl.pl_id, 250,pen.bnft_amt,278,pen.bnft_amt,252,pen.bnft_amt) sps_cvg, '||
     '  DECODE(bpl.pl_id, 254,pen.bnft_amt) dep_cvg, '||
    '   pen.enrt_cvg_strt_dt effective_date, '||
     '   (SELECT MAX(rates.rt_strt_dt) '||
      --'  FROM ben.ben_prtt_rt_val rates '||			-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
      '  FROM apps.ben_prtt_rt_val rates '||             --  code Added by IXPRAVEEN-ARGANO,   09-May-2023
       ' WHERE rates.prtt_enrt_rslt_id = pen.prtt_enrt_rslt_id '||
     '   AND '||SQ||v_date||SQ||' BETWEEN RT_STRT_DT AND RT_END_DT) ded_start_date, '||
      '  DECODE(pen.pl_id,691,DECODE(SUBSTR(opt.name,1,8),'||SQ||'Post Tax'||SQ||','||SQ||'N'||SQ||','||SQ||'Y'||SQ||'),247,'||SQ||'N'||SQ||',246,'||SQ||'N'||SQ||',4871,DECODE(SUBSTR(opt.name,1,8),'||SQ||'Post Tax'||SQ||','||SQ||'N'||SQ||','||SQ||'Y'||SQ||'),262,DECODE(SUBSTR(opt.name,1,8),'||SQ||'Post Tax'||SQ||','||SQ||'N'||SQ||','||SQ||'Y'||SQ||'),248,'||SQ||'Y'||SQ||',275,'||SQ||'N'||SQ||',245,'||SQ||'Y'||SQ||',272,'||SQ||'N'||SQ||',258,'||SQ||'N'||SQ||',254,'||SQ||'N'||SQ||',256,'||SQ||'N'||SQ||',277,'||SQ||'N'||SQ||',260,'||SQ||'N'||SQ||',250,'||SQ||'N'||SQ||',278,'||SQ||'N'||SQ||',252,'||SQ||'N'||SQ||',264,DECODE(SUBSTR(opt.name,1,8),'||SQ||'Post Tax'||SQ||','||SQ||'N'||SQ||','||SQ||'Y'||SQ||'),263,'||SQ||'N'||SQ||',249,'||SQ||'N'||SQ||',276,'||SQ||'N'||SQ||',273,'||SQ||'N'||SQ||',268,'||SQ||'N'||SQ||',259,'||SQ||'N'||SQ||',255,'||SQ||'N'||SQ||',257,'||SQ||'N'||SQ||',261,'||SQ||'N'||SQ||',251,'||SQ||'N'||SQ||',253,'||SQ||'N'||SQ||',265,'||SQ||'N'||SQ||') sec_125, '||
      '  dep_social_num,
        dep_cont_f_name,
        dep_cont_l_name,
        dep_contact_type,
        dep_dob,
        pen.pl_id
FROM   hr.per_all_people_f pap,
       ben.BEN_PRTT_ENRT_RSLT_F pen, '||
	   
      ' (SELECT * '||
     --'  FROM ben.ben_pl_f '||						-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
     '  FROM apps.ben_pl_f '||                       --  code Added by IXPRAVEEN-ARGANO,   09-May-2023
     '  WHERE '||SQ||v_date||SQ||' BETWEEN effective_start_date AND effective_END_date '||
     '  AND pl_id IN (691,247,246,4871,262,275,272,258,254,256,277,260,250,278,252,264)'||
     '  AND pl_typ_id IN (86,22,26,32,87,85,31,24,37,30,25,23,29,27,28)) BPL, '||
     '  (SELECT *
       --FROM ben.ben_opt_f			-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
       FROM apps.ben_opt_f            --  code Added by IXPRAVEEN-ARGANO,   09-May-2023
       WHERE '||SQ||v_date||SQ||' BETWEEN effective_start_date AND effective_END_date) opt,
       ben.BEN_OIPL_F opl,
       (SELECT papf_cont.national_identifier dep_social_num,
               papf_cont.first_name dep_cont_f_name,
               papf_cont.last_name dep_cont_l_name,
               hl.meaning dep_contact_type,
               papf_cont.date_of_birth dep_dob,
               dep.prtt_enrt_rslt_id prtt_enrt_rslt_id,
               dep.ELIG_CVRD_DPNT_ID,
               dep.cvg_thru_dt,
               pap1.person_id,
               dep.last_update_date,
               papf_cont.person_id dep_person_id
                FROM PER_ALL_PEOPLE_F papf_cont,
                      PER_CONTACT_RELATIONSHIPS pcr,
                     -- ben.BEN_ELIG_CVRD_DPNT_F dep,				-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
                      apps.BEN_ELIG_CVRD_DPNT_F dep,                  --  code Added by IXPRAVEEN-ARGANO,   09-May-2023
                      PER_ALL_PEOPLE_F pap1,
                      HR_LOOKUPS hl
                  WHERE pcr.person_id = pap1.person_id
                  AND pcr.contact_person_id = papf_cont.person_id
                  AND '||SQ||v_date||SQ||' BETWEEN papf_cont.effective_start_date AND papf_cont.effective_END_date
                  AND '||SQ||v_date||SQ||' BETWEEN pap1.effective_start_date AND pap1.effective_END_date
                  AND '||SQ||v_date||SQ||' BETWEEN dep.effective_start_date AND dep.effective_END_date
                  AND '||SQ||v_date||SQ||' BETWEEN dep.cvg_strt_dt AND dep.cvg_thru_dt
                  AND dep.dpnt_person_id = pcr.contact_person_id
                  AND hl.lookup_type(+) = '||SQ||'CONTACT'||SQ||
                 ' AND hl.lookup_code(+) = pcr.contact_type
                  ) xx_dep
       WHERE
       pen.pl_id = bpl.pl_id
       AND pen.person_id = pap.person_id
       AND xx_dep.person_id(+)=pen.person_id
       AND '||SQ||v_date||SQ||' BETWEEN pen.enrt_cvg_strt_dt AND pen.enrt_cvg_thru_dt
       AND '||SQ||v_date||SQ||' BETWEEN pen.effective_start_date AND pen.effective_END_date
       AND  pen.prtt_enrt_rslt_stat_cd IS NULL
       AND opl.opt_id = opt.opt_id(+)
       AND pen.oipl_id = opl.oipl_id(+)
       AND '||SQ||v_date||SQ||' BETWEEN pap.effective_start_date AND pap.effective_END_date
       AND hr_person_type_usage_info.get_user_person_type ( trunc(pap.effective_start_date), pap.person_id ) = '||SQ||'PEO Employee'||SQ||
      ' AND pap.current_employee_flag = '||SQ||'Y'||SQ||
      ' AND pap.business_group_id = 325
       AND xx_dep.prtt_enrt_rslt_id(+) = pen.prtt_enrt_rslt_id
ORDER BY
      pap.employee_number';



EXECUTE IMMEDIATE(V_STRING);

fnd_file.put_line(fnd_file.log,'TABLE CREATION COMPLETED');

fnd_file.put_line(fnd_file.log,'PROGRAM SUCCESSFULLY COMPLETED');

EXCEPTION
WHEN OTHERS THEN
fnd_file.put_line(fnd_file.log,'Program completed with error '||sqlerrm);
raise;
END MAIN;

-- ############################### END MAIN ########################################## --

PROCEDURE write_process(p_file_name   in VARCHAR2,
                          p_data      in VARCHAR2,
                          p_mode      in VARCHAR2,
                          p_path      in VARCHAR2)
IS

F1 UTL_FILE.FILE_TYPE;

v_path VARCHAR2(200):=p_path;

  BEGIN
    --fnd_file.put_line(fnd_file.log,'extract line : '||p_data);
    F1 := UTL_FILE.FOPEN(v_path,p_file_name,p_mode,32767);
    IF p_data is not null then
    UTL_FILE.put_line(F1,p_data,false);
    --UTL_FILE.NEW_LINE(F1, 1);
    END if;
    utl_file.fflush(F1);
    UTL_FILE.FCLOSE(F1);

  EXCEPTION
WHEN OTHERS THEN
  fnd_file.put_line(fnd_file.log,'Write_process could not complete successfully: '||sqlerrm||' : '||v_path);
END write_process;

END XXTELETECH_EMP_BEN_EN_EXTR;
/
show errors;
/