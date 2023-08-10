create or replace PACKAGE BODY      xxteletech_emp_ben_en_change
/********************************************************************************
PROGRAM NAME:   XXTELETECH_EMP_BEN_EN_CHANGE
DESCRIPTION:    This package extracts any Changes to PEO Employee Benefit Enrollment information
for the PAY CYCLE.
The Run Date parameter should be set to be run on Cut-Off Date for a Payroll Cycle.
INPUT      :    None
OUTPUT     :
CREATED BY:     Vinayak Hiremath
DATE:           18-NOV-2013
CALLING FROM :  Teletech PEO Employee Benefits Change Interface
----------------
MODIFICATION LOG
----------------
DEVELOPER            Version  DATE          DESCRIPTION
-------------------  -------- ------------  -----------------------------------------
Vinayak Hiremath     1.0      18-Nov-2013   Initial Version
Kaushik              1.1      22-APR-2014   changed all query to pull the latest salary information INC0226215
RXNETHI-ARGANO       1.0      11-APR-2023   R12.2 Upgrade Remediation
********************************************************************************/
AS
   PROCEDURE main (
      x_errcode     OUT      NUMBER,
      x_errbuff     OUT      VARCHAR2,
      p_prgm_date   IN       VARCHAR2
   )
   IS
      v_dt_time         VARCHAR2 (100);
      v_path            VARCHAR2 (400);
      v_date            DATE;
      v_date_jan_2014   DATE;
      v_days            NUMBER;
      v_columns_str     VARCHAR2 (4000);
      v_header          VARCHAR2 (4000);
      v_string          VARCHAR2 (10000);
      sq                VARCHAR2 (10)    := CHR (39);
      v_action          VARCHAR2 (100);
      v_count_plan      NUMBER;
      v_count_dep       NUMBER;
      v_change_flag     VARCHAR2 (1)     := 'N';
      v_dep_flag        VARCHAR2 (1);
      v_prgm_date       DATE;
      v_start_date      DATE;
      v_end_date        DATE;
      v_contact_type    VARCHAR2 (100)
                        := '''R'',''A'',''S'',''C'',''D'',''O'',''T'',''LW''';

      CURSOR emp_det (p_date DATE)
      IS
         SELECT pen.prtt_enrt_rslt_id, xx_dep.elig_cvrd_dpnt_id,
                pap.employee_number employee_number, pap.full_name full_name,
                DECODE
                   (bpl.pl_id,
                    691, DECODE
                       ((SELECT DECODE
                                   ((SELECT COUNT (*)
                                       FROM per_person_analyses paa,
                                            per_analysis_criteria pac,
                                            per_all_people_f pap3
                                      WHERE paa.business_group_id = 325
                                        AND paa.id_flex_num =
                                               (SELECT id_flex_num
                                                  FROM fnd_id_flex_structures
                                                 WHERE id_flex_structure_code =
                                                          'TTEC_HEALTH_ASSESSMENT'
                                                   --'US Health Assessment'
                                                   AND enabled_flag = 'Y')
                                        AND TRUNC (p_date) BETWEEN paa.date_from
                                                               AND paa.date_to
                                        AND pac.analysis_criteria_id =
                                                      paa.analysis_criteria_id
                                        AND pac.enabled_flag = 'Y'
                                        AND pac.segment1 = 'Y'
                                        AND paa.person_id = pap3.person_id
                                        AND TRUNC (p_date)
                                               BETWEEN pap3.effective_start_date
                                                   AND effective_end_date
                                        AND paa.person_id = pap.person_id),
                                    0, 'A',
                                    'B'
                                   )
                           FROM DUAL),
                        'A', 'BAL0002',
                        'BAL0001'
                       ),
                    247, 'METLIFE48',
                    246, 'METLIFE47',
                    4871, 'DELTA07',
                    262, 'DELTA06',
                    275, 'AIG001',
                    272, 'METLIFE46',
                    258, 'METLIFE45',
                    254, 'METLIFE50',
                    256, 'METLIFE53',
                    260, 'METLIFE52',
                    250, 'METLIFE51',
                    252, 'METLIFE49',
                    264, 'VSP008',
                    277, 'METLIFE53',
                    278, 'METLIFE51'
                   ) vin_plan,
                DECODE (bpl.pl_id,
                        247, NULL,
                        246, NULL,
                        272, NULL,
                        254, NULL,
                        opt.NAME
                       ) vin_option,
                pap.first_name first_name, pap.last_name last_name,
                pap.national_identifier social_num,
                DECODE
                   (bpl.pl_id,
                    260, pen.bnft_amt,
                    245, pen.bnft_amt,
                    248, pen.bnft_amt,
                    256, pen.bnft_amt,
                    277, pen.bnft_amt,
                    247, (SELECT TRUNC ((proposed_salary_n * 2080), 3)
                            FROM per_pay_proposals ppp,
                                 per_all_assignments_f paa
                           WHERE ppp.assignment_id = paa.assignment_id
                             AND paa.person_id = pap.person_id
                             AND TRUNC (p_date) BETWEEN paa.effective_start_date
                                                    AND paa.effective_end_date
                             AND TRUNC (p_date) BETWEEN ppp.change_date
                                                    AND NVL (ppp.date_to,
                                                             TRUNC (SYSDATE)
                                                            )),
                    246, (SELECT TRUNC ((proposed_salary_n * 2080), 3)
                            FROM per_pay_proposals ppp,
                                 per_all_assignments_f paa
                           WHERE ppp.assignment_id = paa.assignment_id
                             AND paa.person_id = pap.person_id
                             AND TRUNC (p_date) BETWEEN paa.effective_start_date
                                                    AND paa.effective_end_date
                             AND TRUNC (p_date) BETWEEN ppp.change_date
                                                    AND NVL (ppp.date_to,
                                                             TRUNC (SYSDATE)
                                                            )),
                    272, (SELECT TRUNC ((0.6 * (proposed_salary_n) * 2080)
                                        / 12,
                                        3
                                       )
                            FROM per_pay_proposals ppp,
                                 per_all_assignments_f paa
                           WHERE ppp.assignment_id = paa.assignment_id
                             AND paa.person_id = pap.person_id
                             AND TRUNC (p_date) BETWEEN paa.effective_start_date
                                                    AND paa.effective_end_date
                             AND TRUNC (p_date) BETWEEN ppp.change_date
                                                    AND NVL (ppp.date_to,
                                                             TRUNC (SYSDATE)
                                                            )),
                    258, (SELECT TRUNC ((1 * (proposed_salary_n) * 2080) / 52,
                                        3
                                       )
                            FROM per_pay_proposals ppp,
                                 per_all_assignments_f paa
                           WHERE ppp.assignment_id = paa.assignment_id
                             AND paa.person_id = pap.person_id
                             AND TRUNC (p_date) BETWEEN paa.effective_start_date
                                                    AND paa.effective_end_date
                             AND TRUNC (p_date) BETWEEN ppp.change_date
                                                    AND NVL (ppp.date_to,
                                                             TRUNC (SYSDATE)
                                                            ))
                   ) emp_cvg,
                DECODE (bpl.pl_id,
                        250, pen.bnft_amt,
                        278, pen.bnft_amt,
                        252, pen.bnft_amt
                       ) sps_cvg,
                DECODE (bpl.pl_id, 254, pen.bnft_amt) dep_cvg,

                --  pen.effective_start_date effective_date,
                pen.enrt_cvg_strt_dt effective_date,
                (SELECT MAX (rates.rt_strt_dt)
                   --FROM ben.ben_prtt_rt_val rates --code commented by RXNETHI-ARGANO,11/05/23
				   FROM apps.ben_prtt_rt_val rates --code added by RXNETHI-ARGANO,11/05/23
                  WHERE rates.prtt_enrt_rslt_id =
                                         pen.prtt_enrt_rslt_id
                    AND TRUNC (p_date) BETWEEN rt_strt_dt AND rt_end_dt)
                                                              ded_start_date,
                DECODE (pen.pl_id,
                        691, DECODE (SUBSTR (opt.NAME, 1, 8),
                                     'Post Tax', 'N',
                                     'Y'
                                    ),
                        247, 'N',
                        246, 'N',
                        4871, DECODE (SUBSTR (opt.NAME, 1, 8),
                                      'Post Tax', 'N',
                                      'Y'
                                     ),
                        262, DECODE (SUBSTR (opt.NAME, 1, 8),
                                     'Post Tax', 'N',
                                     'Y'
                                    ),
                        248, 'Y',
                        275, 'N',
                        245, 'Y',
                        272, 'N',
                        258, 'N',
                        254, 'N',
                        256, 'N',
                        277, 'N',
                        260, 'N',
                        250, 'N',
                        278, 'N',
                        252, 'N',
                        264, DECODE (SUBSTR (opt.NAME, 1, 8),
                                     'Post Tax', 'N',
                                     'Y'
                                    ),
                        263, 'N',
                        249, 'N',
                        276, 'N',
                        273, 'N',
                        268, 'N',
                        259, 'N',
                        255, 'N',
                        257, 'N',
                        261, 'N',
                        251, 'N',
                        253, 'N',
                        265, 'N'
                       ) sec_125,
                dep_social_num, dep_cont_f_name, dep_cont_l_name,
                dep_contact_type, dep_dob, pen.pl_id
           --FROM hr.per_all_people_f pap,       --code commented by RXNETHI-ARGANO,11/05/23
           --     ben.ben_prtt_enrt_rslt_f pen,  --code commented by RXNETHI-ARGANO,11/05/23
		   FROM apps.per_all_people_f pap,       --code added by RXNETHI-ARGANO,11/05/23
                apps.ben_prtt_enrt_rslt_f pen,  --code added by RXNETHI-ARGANO,11/05/23
                (SELECT *
                   --FROM ben.ben_pl_f --code commented by RXNETHI-ARGANO,11/05/23
				   FROM apps.ben_pl_f --code added by RXNETHI-ARGANO,11/05/23
                  WHERE TRUNC (p_date) BETWEEN effective_start_date
                                           AND effective_end_date
                    AND pl_id IN
                           (691, 247, 246, 4871, 262, 275, 272, 258, 254, 256,
                            277, 260, 250, 278, 252, 264)
                    AND pl_typ_id IN
                           (86, 22, 26, 32, 87, 85, 31, 24, 37, 30, 25, 23,
                            29, 27, 28)) bpl,
                (SELECT *
                   --FROM ben.ben_opt_f  --code commented by RXNETHI-ARGANO,11/05/23
                   FROM apps.ben_opt_f   --code added by RXNETHI-ARGANO,11/05/23
                  WHERE TRUNC (p_date) BETWEEN effective_start_date
                                           AND effective_end_date) opt,
                --ben.ben_oipl_f opl,  --code commented by RXNETHI-ARGANO,11/05/23
                apps.ben_oipl_f opl,   --code added by RXNETHI-ARGANO,11/05/23
                (SELECT papf_cont.national_identifier dep_social_num,
                        papf_cont.first_name dep_cont_f_name,
                        papf_cont.last_name dep_cont_l_name,
                        hl.meaning dep_contact_type,
                        papf_cont.date_of_birth dep_dob,
                        dep.prtt_enrt_rslt_id prtt_enrt_rslt_id,
                        dep.elig_cvrd_dpnt_id, dep.cvg_thru_dt,
                        pap1.person_id, dep.last_update_date,
                        papf_cont.person_id dep_person_id
                   FROM per_all_people_f papf_cont,
                        per_contact_relationships pcr,
                        --ben.ben_elig_cvrd_dpnt_f dep, --code commented by RXNETHI-ARGANO,11/05/23
						apps.ben_elig_cvrd_dpnt_f dep, --code added by RXNETHI-ARGANO,11/05/23
                        per_all_people_f pap1,
                        hr_lookups hl
                  WHERE pcr.person_id = pap1.person_id
                    AND pcr.contact_person_id = papf_cont.person_id
                    AND TRUNC (p_date) BETWEEN papf_cont.effective_start_date
                                           AND papf_cont.effective_end_date
                    AND pcr.contact_type IN
                                    ('R', 'A', 'S', 'C', 'D', 'O', 'T', 'LW')
                    AND TRUNC (p_date) BETWEEN pap1.effective_start_date
                                           AND pap1.effective_end_date
                    AND TRUNC (p_date) BETWEEN dep.effective_start_date
                                           AND dep.effective_end_date
                    AND TRUNC (p_date) BETWEEN dep.cvg_strt_dt AND dep.cvg_thru_dt
                    AND dep.dpnt_person_id = pcr.contact_person_id
                    AND hl.lookup_type(+) = 'CONTACT'
                    AND hl.lookup_code(+) = pcr.contact_type) xx_dep
          WHERE
                --   AND opl.oipl_id IN (783,785,1141,787,786,788,784,1275,1297,1276,1296,1281,1302,1280,1301,1279,1300,1278,1299,1277,1298,1282,1303,1283,1304,1288,1309,1287,1308,1286,1307,1285,1306,1284,1305,711,710,3515,7520,3530,3519,3518,3517,7519,3520,7517,3531,3524,3523,3522,7518,713,4522,1137,717,716,715,4521,718,4524,1138,722,721,720,4523,782,712,723,724,1139,727,726,725,800,801,1144,804,803,802,728,729,1140,732,731,730)
                pen.pl_id = bpl.pl_id
            AND pen.person_id = pap.person_id
            AND xx_dep.person_id(+) = pen.person_id
            AND TRUNC (p_date) BETWEEN pen.enrt_cvg_strt_dt
                                   AND pen.enrt_cvg_thru_dt
            AND TRUNC (p_date) BETWEEN pen.effective_start_date
                                   AND pen.effective_end_date
            AND pen.prtt_enrt_rslt_stat_cd IS NULL
            AND opl.opt_id = opt.opt_id(+)
            AND pen.oipl_id = opl.oipl_id(+)
            AND TRUNC (p_date) BETWEEN pap.effective_start_date
                                   AND pap.effective_end_date
            AND hr_person_type_usage_info.get_user_person_type
                                             (TRUNC (pap.effective_start_date),
                                              pap.person_id
                                             ) = 'PEO Employee'
            AND pap.current_employee_flag = 'Y'
            AND pap.business_group_id = 325
            AND xx_dep.prtt_enrt_rslt_id(+) = pen.prtt_enrt_rslt_id
         --AND pap.employee_number= '3160581'--'3148737'--'3153282'
         MINUS
         SELECT *
           FROM xxteletech_emp_ben_en_tab;

      CURSOR c_dep (p_elig_cvrd_dpnt_id NUMBER)
      IS
         SELECT *
           FROM xxteletech_emp_ben_en_tab
          WHERE elig_cvrd_dpnt_id = p_elig_cvrd_dpnt_id;

      CURSOR c_plan (p_prtt_enrt_rslt_id NUMBER)
      IS
         SELECT *
           FROM xxteletech_emp_ben_en_tab
          WHERE prtt_enrt_rslt_id = p_prtt_enrt_rslt_id;

      -- Coverage termination cursor
      CURSOR c_plan_term (p_date DATE, p_start_date DATE, p_end_date DATE)
      IS
         SELECT DISTINCT pap.employee_number employee_number,
                         pap.full_name full_name,
                         DECODE
                            (bpl.pl_id,
                             691, DECODE
                                ((SELECT DECODE
                                            ((SELECT COUNT (*)
                                                FROM per_person_analyses paa,
                                                     per_analysis_criteria pac,
                                                     per_all_people_f pap3
                                               WHERE paa.business_group_id =
                                                                           325
                                                 AND paa.id_flex_num =
                                                        (SELECT id_flex_num
                                                           FROM fnd_id_flex_structures
                                                          WHERE id_flex_structure_code =
                                                                   'TTEC_HEALTH_ASSESSMENT'
                                                            --'US Health Assessment'
                                                            AND enabled_flag =
                                                                           'Y')
                                                 AND TRUNC (p_date)
                                                        BETWEEN paa.date_from
                                                            AND paa.date_to
                                                 AND pac.analysis_criteria_id =
                                                        paa.analysis_criteria_id
                                                 AND pac.enabled_flag = 'Y'
                                                 AND pac.segment1 = 'Y'
                                                 AND paa.person_id =
                                                                pap3.person_id
                                                 AND TRUNC (p_date)
                                                        BETWEEN pap3.effective_start_date
                                                            AND effective_end_date
                                                 AND paa.person_id =
                                                                 pap.person_id),
                                             0, 'A',
                                             'B'
                                            )
                                    FROM DUAL),
                                 'A', 'BAL0002',
                                 'BAL0001'
                                ),
                             247, 'METLIFE48',
                             246, 'METLIFE47',
                             4871, 'DELTA07',
                             262, 'DELTA06',
                             275, 'AIG001',
                             272, 'METLIFE46',
                             258, 'METLIFE45',
                             254, 'METLIFE50',
                             256, 'METLIFE53',
                             260, 'METLIFE52',
                             250, 'METLIFE51',
                             252, 'METLIFE49',
                             264, 'VSP008',
                             277, 'METLIFE53',
                             278, 'METLIFE51'
                            ) vin_plan,
                         DECODE (bpl.pl_id,
                                 247, NULL,
                                 246, NULL,
                                 272, NULL,
                                 254, NULL,
                                 opt.NAME
                                ) vin_option,
                         pap.first_name first_name, pap.last_name last_name,
                         pap.national_identifier social_num,
                         DECODE
                            (bpl.pl_id,
                             260, pen.bnft_amt,
                             245, pen.bnft_amt,
                             248, pen.bnft_amt,
                             256, pen.bnft_amt,
                             277, pen.bnft_amt,
                             247, (SELECT TRUNC ((proposed_salary_n * 2080),
                                                 3
                                                )
                                     FROM per_pay_proposals ppp,
                                          per_all_assignments_f paa
                                    WHERE ppp.assignment_id =
                                                             paa.assignment_id
                                      AND paa.person_id = pap.person_id
                                      AND TRUNC (p_date)
                                             BETWEEN paa.effective_start_date
                                                 AND paa.effective_end_date
                                      AND TRUNC (p_date) BETWEEN ppp.change_date
                                                             AND NVL
                                                                   (ppp.date_to,
                                                                    TRUNC
                                                                       (SYSDATE
                                                                       )
                                                                   )),
                             246, (SELECT TRUNC ((proposed_salary_n * 2080),
                                                 3
                                                )
                                     FROM per_pay_proposals ppp,
                                          per_all_assignments_f paa
                                    WHERE ppp.assignment_id =
                                                             paa.assignment_id
                                      AND paa.person_id = pap.person_id
                                      AND TRUNC (p_date)
                                             BETWEEN paa.effective_start_date
                                                 AND paa.effective_end_date
                                      AND TRUNC (p_date) BETWEEN ppp.change_date
                                                             AND NVL
                                                                   (ppp.date_to,
                                                                    TRUNC
                                                                       (SYSDATE
                                                                       )
                                                                   )),
                             272, (SELECT TRUNC (  (  0.6
                                                    * (proposed_salary_n)
                                                    * 2080
                                                   )
                                                 / 12,
                                                 3
                                                )
                                     FROM per_pay_proposals ppp,
                                          per_all_assignments_f paa
                                    WHERE ppp.assignment_id =
                                                             paa.assignment_id
                                      AND paa.person_id = pap.person_id
                                      AND TRUNC (p_date)
                                             BETWEEN paa.effective_start_date
                                                 AND paa.effective_end_date
                                      AND TRUNC (p_date) BETWEEN ppp.change_date
                                                             AND NVL
                                                                   (ppp.date_to,
                                                                    TRUNC
                                                                       (SYSDATE
                                                                       )
                                                                   )),
                             258, (SELECT TRUNC (  (  1
                                                    * (proposed_salary_n)
                                                    * 2080
                                                   )
                                                 / 52,
                                                 3
                                                )
                                     FROM per_pay_proposals ppp,
                                          per_all_assignments_f paa
                                    WHERE ppp.assignment_id =
                                                             paa.assignment_id
                                      AND paa.person_id = pap.person_id
                                      AND TRUNC (p_date)
                                             BETWEEN paa.effective_start_date
                                                 AND paa.effective_end_date
                                      AND TRUNC (p_date) BETWEEN ppp.change_date
                                                             AND NVL
                                                                   (ppp.date_to,
                                                                    TRUNC
                                                                       (SYSDATE
                                                                       )
                                                                   ))
                            ) emp_cvg,
                         DECODE (bpl.pl_id,
                                 250, pen.bnft_amt,
                                 278, pen.bnft_amt,
                                 252, pen.bnft_amt
                                ) sps_cvg,
                         DECODE (bpl.pl_id, 254, pen.bnft_amt) dep_cvg,
                         pen.enrt_cvg_strt_dt effective_date,
                         (SELECT MIN (rates.rt_strt_dt)
                            --FROM ben.ben_prtt_rt_val rates --code commented by RXNETHI-ARGANO,11/05/23
							FROM apps.ben_prtt_rt_val rates --code added by RXNETHI-ARGANO,11/05/23
                           WHERE rates.prtt_enrt_rslt_id =
                                         pen.prtt_enrt_rslt_id
                             AND (   (TRUNC (p_date) BETWEEN rt_strt_dt
                                                         AND rt_end_dt
                                     )
                                  OR (TRUNC (rt_end_dt) BETWEEN p_start_date
                                                            AND p_end_date
                                     )
                                 )) ded_start_date,
                         DECODE (pen.pl_id,
                                 691, DECODE (SUBSTR (opt.NAME, 1, 8),
                                              'Post Tax', 'N',
                                              'Y'
                                             ),
                                 247, 'N',
                                 246, 'N',
                                 4871, DECODE (SUBSTR (opt.NAME, 1, 8),
                                               'Post Tax', 'N',
                                               'Y'
                                              ),
                                 262, DECODE (SUBSTR (opt.NAME, 1, 8),
                                              'Post Tax', 'N',
                                              'Y'
                                             ),
                                 248, 'Y',
                                 275, 'N',
                                 245, 'Y',
                                 272, 'N',
                                 258, 'N',
                                 254, 'N',
                                 256, 'N',
                                 277, 'N',
                                 260, 'N',
                                 250, 'N',
                                 278, 'N',
                                 252, 'N',
                                 264, DECODE (SUBSTR (opt.NAME, 1, 8),
                                              'Post Tax', 'N',
                                              'Y'
                                             ),
                                 263, 'N',
                                 249, 'N',
                                 276, 'N',
                                 273, 'N',
                                 268, 'N',
                                 259, 'N',
                                 255, 'N',
                                 257, 'N',
                                 261, 'N',
                                 251, 'N',
                                 253, 'N',
                                 265, 'N'
                                ) sec_125,
                         dep_social_num, dep_cont_f_name, dep_cont_l_name,
                         dep_contact_type, dep_dob, pen.pl_id
                    --FROM hr.per_all_people_f pap,     --code commented by RXNETHI-ARGANO,11/05/23
                    --     ben.ben_prtt_enrt_rslt_f pen, --code commented by RXNETHI-ARGANO,11/05/23
					FROM apps.per_all_people_f pap,     --code added by RXNETHI-ARGANO,11/05/23
                         apps.ben_prtt_enrt_rslt_f pen, --code added by RXNETHI-ARGANO,11/05/23
                         (SELECT *
                            --FROM ben.ben_pl_f --code commented by RXNETHI-ARGANO,11/05/23
                            FROM apps.ben_pl_f --code added by RXNETHI-ARGANO,11/05/23
						   WHERE TRUNC (p_date) BETWEEN effective_start_date
                                                    AND effective_end_date
                             AND pl_id IN
                                    (691, 247, 246, 4871, 262, 275, 272, 258,
                                     254, 256, 277, 260, 250, 278, 252, 264)
                             AND pl_typ_id IN
                                    (86, 22, 26, 32, 87, 85, 31, 24, 37, 30,
                                     25, 23, 29, 27, 28)) bpl,
                         (SELECT *
                            --FROM ben.ben_opt_f --code commented by RXNETHI-ARGANO,11/05/23
							FROM apps.ben_opt_f --code added by RXNETHI-ARGANO,11/05/23
                           WHERE TRUNC (p_date) BETWEEN effective_start_date
                                                    AND effective_end_date) opt,
                         --ben.ben_oipl_f opl,  --code commented by RXNETHI-ARGANO,11/05/23
                         apps.ben_oipl_f opl,   --code added by RXNETHI-ARGANO,11/05/23
                         (SELECT papf_cont.national_identifier dep_social_num,
                                 papf_cont.first_name dep_cont_f_name,
                                 papf_cont.last_name dep_cont_l_name,
                                 hl.meaning dep_contact_type,
                                 papf_cont.date_of_birth dep_dob,
                                 dep.prtt_enrt_rslt_id prtt_enrt_rslt_id,
                                 dep.elig_cvrd_dpnt_id, dep.cvg_thru_dt,
                                 pap1.person_id, dep.last_update_date,
                                 papf_cont.person_id dep_person_id
                            FROM per_all_people_f papf_cont,
                                 per_contact_relationships pcr,
                                 --ben.ben_elig_cvrd_dpnt_f dep, --code commented by RXNETHI-ARGANO,11/05/23
								 apps.ben_elig_cvrd_dpnt_f dep, --code added by RXNETHI-ARGANO,11/05/23
                                 per_all_people_f pap1,
                                 hr_lookups hl
                           WHERE pcr.person_id = pap1.person_id
                             AND pcr.contact_person_id = papf_cont.person_id
                             AND TRUNC (p_date)
                                    BETWEEN papf_cont.effective_start_date
                                        AND papf_cont.effective_end_date
                             AND TRUNC (p_date)
                                    BETWEEN pap1.effective_start_date
                                        AND pap1.effective_end_date
                             AND pcr.contact_type IN
                                    ('R', 'A', 'S', 'C', 'D', 'O', 'T', 'LW')
                             --     AND trunc(p_date) BETWEEN dep.effective_start_date AND dep.effective_end_date
                             --  AND trunc(p_date) BETWEEN dep.cvg_strt_dt AND dep.cvg_thru_dt
                             AND dep.dpnt_person_id = pcr.contact_person_id
                             AND hl.lookup_type(+) = 'CONTACT'
                             AND hl.lookup_code(+) = pcr.contact_type) xx_dep
                   WHERE
                         --   AND opl.oipl_id IN (783,785,1141,787,786,788,784,1275,1297,1276,1296,1281,1302,1280,1301,1279,1300,1278,1299,1277,1298,1282,1303,1283,1304,1288,1309,1287,1308,1286,1307,1285,1306,1284,1305,711,710,3515,7520,3530,3519,3518,3517,7519,3520,7517,3531,3524,3523,3522,7518,713,4522,1137,717,716,715,4521,718,4524,1138,722,721,720,4523,782,712,723,724,1139,727,726,725,800,801,1144,804,803,802,728,729,1140,732,731,730)
                         pen.pl_id = bpl.pl_id
                     AND pen.person_id = pap.person_id
                     AND xx_dep.person_id(+) = pen.person_id
                     AND (   (TRUNC (p_date) BETWEEN pen.effective_start_date
                                                 AND pen.effective_end_date
                             )
                          OR (TRUNC (pen.effective_end_date)
                                 BETWEEN p_start_date
                                     AND p_end_date
                             )
                         )
                     AND TRUNC (pen.enrt_cvg_thru_dt) BETWEEN p_start_date
                                                          AND p_end_date
                     --TO_DATE('2013/12/30','YYYY/MM/DD') AND TO_DATE('2014/01/13','YYYY/MM/DD')
                                       --AND  pen.prtt_enrt_rslt_stat_cd IS NULL
                     AND opl.opt_id = opt.opt_id(+)
                     AND pen.oipl_id = opl.oipl_id(+)
                     AND TRUNC (p_date) BETWEEN pap.effective_start_date
                                            AND pap.effective_end_date
                     AND hr_person_type_usage_info.get_user_person_type
                                             (TRUNC (pap.effective_start_date),
                                              pap.person_id
                                             ) = 'PEO Employee'
                     AND pap.current_employee_flag = 'Y'
                     AND pap.business_group_id = 325
                     AND xx_dep.prtt_enrt_rslt_id(+) = pen.prtt_enrt_rslt_id;

      -- AND pap.employee_number= '3160581';

      --DEP DELETION CURSOR DETAILS
      CURSOR c_dep_del (p_date DATE, p_start_date DATE, p_end_date DATE)
      IS
         SELECT DISTINCT pap.employee_number employee_number,
                         pap.full_name full_name,
                         DECODE
                            (bpl.pl_id,
                             691, DECODE
                                ((SELECT DECODE
                                            ((SELECT COUNT (*)
                                                FROM per_person_analyses paa,
                                                     per_analysis_criteria pac,
                                                     per_all_people_f pap3
                                               WHERE paa.business_group_id =
                                                                           325
                                                 AND paa.id_flex_num =
                                                        (SELECT id_flex_num
                                                           FROM fnd_id_flex_structures
                                                          WHERE id_flex_structure_code =
                                                                   'TTEC_HEALTH_ASSESSMENT'
                                                            --'US Health Assessment'
                                                            AND enabled_flag =
                                                                           'Y')
                                                 AND TRUNC (p_date)
                                                        BETWEEN paa.date_from
                                                            AND paa.date_to
                                                 AND pac.analysis_criteria_id =
                                                        paa.analysis_criteria_id
                                                 AND pac.enabled_flag = 'Y'
                                                 AND pac.segment1 = 'Y'
                                                 AND paa.person_id =
                                                                pap3.person_id
                                                 AND TRUNC (p_date)
                                                        BETWEEN pap3.effective_start_date
                                                            AND effective_end_date
                                                 AND paa.person_id =
                                                                 pap.person_id),
                                             0, 'A',
                                             'B'
                                            )
                                    FROM DUAL),
                                 'A', 'BAL0002',
                                 'BAL0001'
                                ),
                             247, 'METLIFE48',
                             246, 'METLIFE47',
                             4871, 'DELTA07',
                             262, 'DELTA06',
                             275, 'AIG001',
                             272, 'METLIFE46',
                             258, 'METLIFE45',
                             254, 'METLIFE50',
                             256, 'METLIFE53',
                             260, 'METLIFE52',
                             250, 'METLIFE51',
                             252, 'METLIFE49',
                             264, 'VSP008',
                             277, 'METLIFE53',
                             278, 'METLIFE51'
                            ) vin_plan,
                         DECODE (bpl.pl_id,
                                 247, NULL,
                                 246, NULL,
                                 272, NULL,
                                 254, NULL,
                                 opt.NAME
                                ) vin_option,
                         pap.first_name first_name, pap.last_name last_name,
                         pap.national_identifier social_num,
                         DECODE
                            (bpl.pl_id,
                             260, pen.bnft_amt,
                             245, pen.bnft_amt,
                             248, pen.bnft_amt,
                             256, pen.bnft_amt,
                             277, pen.bnft_amt,
                             247, (SELECT TRUNC ((proposed_salary_n * 2080),
                                                 3
                                                )
                                     FROM per_pay_proposals ppp,
                                          per_all_assignments_f paa
                                    WHERE ppp.assignment_id =
                                                             paa.assignment_id
                                      AND paa.person_id = pap.person_id
                                      AND TRUNC (p_date)
                                             BETWEEN paa.effective_start_date
                                                 AND paa.effective_end_date
                                      AND TRUNC (p_date) BETWEEN ppp.change_date
                                                             AND NVL
                                                                   (ppp.date_to,
                                                                    TRUNC
                                                                       (SYSDATE
                                                                       )
                                                                   )),
                             246, (SELECT TRUNC ((proposed_salary_n * 2080),
                                                 3
                                                )
                                     FROM per_pay_proposals ppp,
                                          per_all_assignments_f paa
                                    WHERE ppp.assignment_id =
                                                             paa.assignment_id
                                      AND paa.person_id = pap.person_id
                                      AND TRUNC (p_date)
                                             BETWEEN paa.effective_start_date
                                                 AND paa.effective_end_date
                                      AND TRUNC (p_date) BETWEEN ppp.change_date
                                                             AND NVL
                                                                   (ppp.date_to,
                                                                    TRUNC
                                                                       (SYSDATE
                                                                       )
                                                                   )),
                             272, (SELECT TRUNC (  (  0.6
                                                    * (proposed_salary_n)
                                                    * 2080
                                                   )
                                                 / 12,
                                                 3
                                                )
                                     FROM per_pay_proposals ppp,
                                          per_all_assignments_f paa
                                    WHERE ppp.assignment_id =
                                                             paa.assignment_id
                                      AND paa.person_id = pap.person_id
                                      AND TRUNC (p_date)
                                             BETWEEN paa.effective_start_date
                                                 AND paa.effective_end_date
                                      AND TRUNC (p_date) BETWEEN ppp.change_date
                                                             AND NVL
                                                                   (ppp.date_to,
                                                                    TRUNC
                                                                       (SYSDATE
                                                                       )
                                                                   )),
                             258, (SELECT TRUNC (  (  1
                                                    * (proposed_salary_n)
                                                    * 2080
                                                   )
                                                 / 52,
                                                 3
                                                )
                                     FROM per_pay_proposals ppp,
                                          per_all_assignments_f paa
                                    WHERE ppp.assignment_id =
                                                             paa.assignment_id
                                      AND paa.person_id = pap.person_id
                                      AND TRUNC (p_date)
                                             BETWEEN paa.effective_start_date
                                                 AND paa.effective_end_date
                                      AND TRUNC (p_date) BETWEEN ppp.change_date
                                                             AND NVL
                                                                   (ppp.date_to,
                                                                    TRUNC
                                                                       (SYSDATE
                                                                       )
                                                                   ))
                            ) emp_cvg,
                         DECODE (bpl.pl_id,
                                 250, pen.bnft_amt,
                                 278, pen.bnft_amt,
                                 252, pen.bnft_amt
                                ) sps_cvg,
                         DECODE (bpl.pl_id, 254, pen.bnft_amt) dep_cvg,
                         pen.enrt_cvg_strt_dt effective_date,
                         pen.effective_end_date plan_end_date,
                         (SELECT DISTINCT rates.rt_strt_dt
                                     --FROM ben.ben_prtt_rt_val rates --code commented by RXNETHI-ARGANO,11/05/23
									 FROM apps.ben_prtt_rt_val rates --code added by RXNETHI-ARGANO,11/05/23
                                    WHERE rates.prtt_enrt_rslt_id =
                                                         pen.prtt_enrt_rslt_id
                                      AND TRUNC (p_date) BETWEEN rt_strt_dt
                                                             AND rt_end_dt)
                                                               ded_start_date,
                         DECODE (pen.pl_id,
                                 691, DECODE (SUBSTR (opt.NAME, 1, 8),
                                              'Post Tax', 'N',
                                              'Y'
                                             ),
                                 247, 'N',
                                 246, 'N',
                                 4871, DECODE (SUBSTR (opt.NAME, 1, 8),
                                               'Post Tax', 'N',
                                               'Y'
                                              ),
                                 262, DECODE (SUBSTR (opt.NAME, 1, 8),
                                              'Post Tax', 'N',
                                              'Y'
                                             ),
                                 248, 'Y',
                                 275, 'N',
                                 245, 'Y',
                                 272, 'N',
                                 258, 'N',
                                 254, 'N',
                                 256, 'N',
                                 277, 'N',
                                 260, 'N',
                                 250, 'N',
                                 278, 'N',
                                 252, 'N',
                                 264, DECODE (SUBSTR (opt.NAME, 1, 8),
                                              'Post Tax', 'N',
                                              'Y'
                                             ),
                                 263, 'N',
                                 249, 'N',
                                 276, 'N',
                                 273, 'N',
                                 268, 'N',
                                 259, 'N',
                                 255, 'N',
                                 257, 'N',
                                 261, 'N',
                                 251, 'N',
                                 253, 'N',
                                 265, 'N'
                                ) sec_125,
                         dep_social_num, dep_cont_f_name, dep_cont_l_name,
                         dep_contact_type, dep_dob, pen.pl_id
                    --FROM hr.per_all_people_f pap,       --code commented by RXNETHI-ARGANO,11/05/23
                    --     ben.ben_prtt_enrt_rslt_f pen,  --code commented by RXNETHI-ARGANO,11/05/23
					FROM apps.per_all_people_f pap,       --code added by RXNETHI-ARGANO,11/05/23
                         apps.ben_prtt_enrt_rslt_f pen,   --code added by RXNETHI-ARGANO,11/05/23
                         (SELECT *
                            --FROM ben.ben_pl_f --code commented by RXNETHI-ARGANO,11/05/23
							FROM apps.ben_pl_f --code added by RXNETHI-ARGANO,11/05/23
                           WHERE TRUNC (p_date) BETWEEN effective_start_date
                                                    AND effective_end_date
                             AND pl_id IN
                                    (691, 247, 246, 4871, 262, 275, 272, 258,
                                     254, 256, 277, 260, 250, 278, 252, 264)
                             AND pl_typ_id IN
                                    (86, 22, 26, 32, 87, 85, 31, 24, 37, 30,
                                     25, 23, 29, 27, 28)) bpl,
                         (SELECT *
                            --FROM ben.ben_opt_f --code commented by RXNETHI-ARGANO,11/05/23
							FROM apps.ben_opt_f --code added by RXNETHI-ARGANO,11/05/23
                           WHERE TRUNC (p_date) BETWEEN effective_start_date
                                                    AND effective_end_date) opt,
                         --ben.ben_oipl_f opl,   --code commented by RXNETHI-ARGANO,11/05/23
                         apps.ben_oipl_f opl,    --code added by RXNETHI-ARGANO,11/05/23
                         (SELECT papf_cont.national_identifier dep_social_num,
                                 papf_cont.first_name dep_cont_f_name,
                                 papf_cont.last_name dep_cont_l_name,
                                 hl.meaning dep_contact_type,
                                 papf_cont.date_of_birth dep_dob,
                                 dep.prtt_enrt_rslt_id prtt_enrt_rslt_id,
                                 dep.elig_cvrd_dpnt_id, dep.cvg_thru_dt,
                                 pap1.person_id, dep.last_update_date,
                                 papf_cont.person_id dep_person_id
                            FROM per_all_people_f papf_cont,
                                 per_contact_relationships pcr,
                                 --ben.ben_elig_cvrd_dpnt_f dep, --code commented by RXNETHI-ARGANO,11/05/23
								 apps.ben_elig_cvrd_dpnt_f dep, --code added by RXNETHI-ARGANO,11/05/23
                                 per_all_people_f pap1,
                                 hr_lookups hl
                           WHERE pcr.person_id = pap1.person_id
                             AND pcr.contact_person_id = papf_cont.person_id
                             AND TRUNC (p_date)
                                    BETWEEN papf_cont.effective_start_date
                                        AND papf_cont.effective_end_date
                             AND TRUNC (p_date)
                                    BETWEEN pap1.effective_start_date
                                        AND pap1.effective_end_date
                             AND pcr.contact_type IN
                                    ('R', 'A', 'S', 'C', 'D', 'O', 'T', 'LW')
                             AND (   (TRUNC (p_date)
                                         BETWEEN dep.effective_start_date
                                             AND dep.effective_end_date
                                     )
                                  OR (TRUNC (dep.effective_end_date)
                                         BETWEEN p_start_date
                                             AND p_end_date
                                     )
                                 )
                             AND TRUNC (dep.cvg_thru_dt) BETWEEN p_start_date
                                                             AND p_end_date
                             AND dep.dpnt_person_id = pcr.contact_person_id
                             AND hl.lookup_type(+) = 'CONTACT'
                             AND hl.lookup_code(+) = pcr.contact_type) xx_dep
                   WHERE
                         --   AND opl.oipl_id IN (783,785,1141,787,786,788,784,1275,1297,1276,1296,1281,1302,1280,1301,1279,1300,1278,1299,1277,1298,1282,1303,1283,1304,1288,1309,1287,1308,1286,1307,1285,1306,1284,1305,711,710,3515,7520,3530,3519,3518,3517,7519,3520,7517,3531,3524,3523,3522,7518,713,4522,1137,717,716,715,4521,718,4524,1138,722,721,720,4523,782,712,723,724,1139,727,726,725,800,801,1144,804,803,802,728,729,1140,732,731,730)
                         pen.pl_id = bpl.pl_id
                     AND pen.person_id = pap.person_id
                     AND xx_dep.person_id = pen.person_id
                     AND TRUNC (p_date) BETWEEN pen.enrt_cvg_strt_dt
                                            AND pen.enrt_cvg_thru_dt
                     AND TRUNC (p_date) BETWEEN pen.effective_start_date
                                            AND pen.effective_end_date
                     AND pen.prtt_enrt_rslt_stat_cd IS NULL
                     AND opl.opt_id = opt.opt_id(+)
                     AND pen.oipl_id = opl.oipl_id(+)
                     AND TRUNC (p_date) BETWEEN pap.effective_start_date
                                            AND pap.effective_end_date
                     AND hr_person_type_usage_info.get_user_person_type
                                             (TRUNC (pap.effective_start_date),
                                              pap.person_id
                                             ) = 'PEO Employee'
                     AND pap.current_employee_flag = 'Y'
                     AND pap.business_group_id = 325
                     AND xx_dep.prtt_enrt_rslt_id = pen.prtt_enrt_rslt_id;
   --AND pap.employee_number= '3160581';
   BEGIN
      SELECT TO_CHAR (SYSDATE, 'YYYYMONDDHH24MISS')
        INTO v_dt_time
        FROM DUAL;

      fnd_file.put_line (fnd_file.LOG, 'Time : ' || v_dt_time);

      SELECT TRUNC (SYSDATE)
        INTO v_date
        FROM DUAL;

      -- MAKE PARAMETER MANDATORY
      SELECT TRUNC (TO_DATE ('01-JAN-2014'))
        INTO v_date_jan_2014
        FROM DUAL;

      SELECT v_date_jan_2014 - TO_DATE (p_prgm_date)
        INTO v_days
        FROM DUAL;

      IF (v_days > 0)
      THEN
         v_date := v_date_jan_2014;
      ELSE
         v_date := TO_DATE (p_prgm_date);
      END IF;

      BEGIN
         SELECT directory_path || '/data/EBS/HC/HR/PEO/outbound/'
           INTO v_path
           FROM dba_directories
          WHERE directory_name = 'CUST_TOP';
      EXCEPTION
         WHEN OTHERS
         THEN
            fnd_file.put_line
                           (fnd_file.LOG,
                               'Program did not get destination directory : '
                            || SQLERRM
                           );
            RAISE;
      END;

      SELECT start_date, end_date
        INTO v_start_date, v_end_date
        FROM per_time_periods ptp
       WHERE TRUNC (v_date) BETWEEN start_date AND default_dd_date
         AND payroll_id IN (SELECT payroll_id
                              FROM pay_all_payrolls_f
                             WHERE payroll_name LIKE 'PEO%')
         -- CHANGE THE PAYROLL NAME
         AND time_period_id =
                (SELECT MIN (time_period_id)
                   FROM per_time_periods
                  WHERE TRUNC (v_date) BETWEEN start_date AND default_dd_date
                    AND payroll_id = ptp.payroll_id);

      SELECT v_date - v_end_date
        INTO v_days
        FROM DUAL;

      IF (v_days > 0)
      THEN
         v_date := v_end_date;
      END IF;

      xxteletech_emp_ben_en_change.write_process
                                       (   'TELETECH_PEO_EMP_BENEFIT_CHANGE_'
                                        || v_dt_time
                                        || '.txt',
                                        '',
                                        'W',
                                        v_path
                                       );

      FOR cur_emp_det IN emp_det (v_date)
      LOOP                                                   -- main loop open
         BEGIN
            -- SET FLAGS TO NULL
            v_dep_flag := NULL;
            v_change_flag := 'N';

            IF (cur_emp_det.elig_cvrd_dpnt_id IS NULL)
            THEN            --CHECK TO FIND THE DISTINCT OPTION FOR THE TABLE
               v_dep_flag := 'N';
            ELSE
               v_dep_flag := 'Y';
            END IF;                                   --distinct option end if

            -- CHECK IF ITS NEW PLAN/DEPENDENT
            SELECT COUNT (*)
              INTO v_count_plan
              FROM xxteletech_emp_ben_en_tab
             WHERE prtt_enrt_rslt_id = cur_emp_det.prtt_enrt_rslt_id;

            IF (v_count_plan > 0)
            THEN                                              -- PLAN COUNT IF
               -- PLAN EXISTS
               -- CHECK IF NEW DEPENDENT
               IF (v_dep_flag = 'Y')
               THEN                                        -- 1ST DEP FLAG IF
                  SELECT COUNT (*)
                    INTO v_count_dep
                    FROM xxteletech_emp_ben_en_tab
                   WHERE elig_cvrd_dpnt_id = cur_emp_det.elig_cvrd_dpnt_id;

                  IF (v_count_dep = 0)
                  THEN                                          --dep count if
                     -- DEPENDENT DOESNT EXIST, HENCE ADDITION OF DEPENDENT.
                     v_action := 'DEPEN+';
                     v_change_flag := 'Y';
                     v_columns_str :=
                           v_action
                        || '	'
                        || 1895
                        || '	'
                        || cur_emp_det.vin_plan
                        || '	'
                        || cur_emp_det.vin_option
                        || '	'
                        || cur_emp_det.first_name
                        || '	'
                        || cur_emp_det.last_name
                        || '	'
                        || cur_emp_det.social_num
                        || '	'
                        || cur_emp_det.emp_cvg
                        || '	'
                        || cur_emp_det.sps_cvg
                        || '	'
                        || cur_emp_det.dep_cvg
                        || '	'
                        || TO_CHAR (cur_emp_det.effective_date, 'MM/DD/YYYY')
                        || '	'
                        || TO_CHAR (cur_emp_det.ded_start_date, 'MM/DD/YYYY')
                        || '	'
                        || cur_emp_det.sec_125
                        || '	'
                        || cur_emp_det.dep_social_num
                        || '	'
                        || cur_emp_det.dep_cont_f_name
                        || '	'
                        || cur_emp_det.dep_cont_l_name
                        || '	'
                        || cur_emp_det.dep_contact_type
                        || '	'
                        || TO_CHAR (cur_emp_det.dep_dob, 'MM/DD/YYYY');
                     fnd_file.put_line (fnd_file.output, v_columns_str);
                     xxteletech_emp_ben_en_change.write_process
                                       (   'TELETECH_PEO_EMP_BENEFIT_CHANGE_'
                                        || v_dt_time
                                        || '.txt',
                                        v_columns_str,
                                        'A',
                                        v_path
                                       );
                  END IF;                                       --dep count IF
               END IF;                                -- 1ST DEPENDENT FLAG IF

               IF (v_change_flag = 'N')
               THEN                                       --1st change flag if
                  IF (v_dep_flag = 'Y')
                  THEN                                     -- 2nd dep flag if
                     FOR cur_dep_det IN c_dep (cur_emp_det.elig_cvrd_dpnt_id)
                     --DEP DETAIL CURSOR
                     LOOP
                        BEGIN
                           IF (        -- PLAN CHANGE DETAILS FOR DEP FLAG IF
                                  NVL (cur_dep_det.vin_option, 'AAA') <>
                                           NVL (cur_emp_det.vin_option, 'AAA')
                               -- OPTION NAME
                               OR NVL (cur_dep_det.first_name, 'AAA') <>
                                           NVL (cur_emp_det.first_name, 'AAA')
                               -- FIRST NAME
                               OR NVL (cur_dep_det.last_name, 'AAA') <>
                                            NVL (cur_emp_det.last_name, 'AAA')
                               -- LAST NAME
                               OR NVL (cur_dep_det.social_num, 'AAA') <>
                                           NVL (cur_emp_det.social_num, 'AAA')
                               -- SOCIAL IDENTIFIER
                               OR NVL (cur_dep_det.emp_cvg, 000) <>
                                                NVL (cur_emp_det.emp_cvg, 000)
                               -- EMP CVG
                               OR NVL (cur_dep_det.dep_cvg, 000) <>
                                                NVL (cur_emp_det.dep_cvg, 000)
                               -- DEP CVG
                               OR NVL (cur_dep_det.sps_cvg, 000) <>
                                                NVL (cur_emp_det.sps_cvg, 000)
                               -- SPS CVG
                               OR NVL (cur_dep_det.effective_date,
                                       TO_DATE (SYSDATE, 'DD-MON-YYYY')
                                      ) <>
                                     NVL
                                        (cur_emp_det.effective_date,
                                         TO_DATE (SYSDATE, 'DD-MON-YYYY')
                                        )                    -- EFFECTIVE DATE
                               OR NVL (cur_dep_det.ded_start_date,
                                       TO_DATE (SYSDATE, 'DD-MON-YYYY')
                                      ) <>
                                     NVL
                                        (cur_emp_det.ded_start_date,
                                         TO_DATE (SYSDATE, 'DD-MON-YYYY')
                                        )                    -- DED START DATE
                               OR NVL (cur_dep_det.sec_125, 'A') <>
                                                NVL (cur_emp_det.sec_125, 'A')
                               -- SEC_125
                               OR NVL (cur_dep_det.dep_social_num, 'AAA') <>
                                       NVL (cur_emp_det.dep_social_num, 'AAA')
                               -- DEP SOCIAL NUM
                               OR NVL (cur_dep_det.dep_cont_f_name, 'AAA') <>
                                      NVL (cur_emp_det.dep_cont_f_name, 'AAA')
                               -- DEP FIRST NAME
                               OR NVL (cur_dep_det.dep_cont_l_name, 'AAA') <>
                                      NVL (cur_emp_det.dep_cont_l_name, 'AAA')
                               -- DEP LAST NAME
                               OR NVL (cur_dep_det.dep_contact_type, 'AAA') <>
                                     NVL (cur_emp_det.dep_contact_type, 'AAA')
                               -- DEP CONTACT TYPE
                               OR NVL (cur_dep_det.dep_dob,
                                       TO_DATE (SYSDATE, 'DD-MON-YYYY')
                                      ) <>
                                     NVL (cur_emp_det.dep_dob,
                                          TO_DATE (SYSDATE, 'DD-MON-YYYY')
                                         )                          -- DEP DOB
                              )
                           THEN
                              v_action := 'CHANGE';
                              v_change_flag := 'Y';
                              v_columns_str :=
                                    v_action
                                 || '	'
                                 || 1895
                                 || '	'
                                 || cur_emp_det.vin_plan
                                 || '	'
                                 || cur_emp_det.vin_option
                                 || '	'
                                 || cur_emp_det.first_name
                                 || '	'
                                 || cur_emp_det.last_name
                                 || '	'
                                 || cur_emp_det.social_num
                                 || '	'
                                 || cur_emp_det.emp_cvg
                                 || '	'
                                 || cur_emp_det.sps_cvg
                                 || '	'
                                 || cur_emp_det.dep_cvg
                                 || '	'
                                 || TO_CHAR (cur_emp_det.effective_date,
                                             'MM/DD/YYYY'
                                            )
                                 || '	'
                                 || TO_CHAR (cur_emp_det.ded_start_date,
                                             'MM/DD/YYYY'
                                            )
                                 || '	'
                                 || cur_emp_det.sec_125
                                 || '	'
                                 || cur_emp_det.dep_social_num
                                 || '	'
                                 || cur_emp_det.dep_cont_f_name
                                 || '	'
                                 || cur_emp_det.dep_cont_l_name
                                 || '	'
                                 || cur_emp_det.dep_contact_type
                                 || '	'
                                 || TO_CHAR (cur_emp_det.dep_dob,
                                             'MM/DD/YYYY');
                              fnd_file.put_line (fnd_file.output,
                                                 v_columns_str
                                                );
                              xxteletech_emp_ben_en_change.write_process
                                       (   'TELETECH_PEO_EMP_BENEFIT_CHANGE_'
                                        || v_dt_time
                                        || '.txt',
                                        v_columns_str,
                                        'A',
                                        v_path
                                       );
                           END IF;      -- PLAN CHANGE DETAILS FOR DEP FLAG IF
                        EXCEPTION
                           WHEN OTHERS
                           THEN
                              fnd_file.put_line
                                              (fnd_file.LOG,
                                                  'c_dep cursor -'
                                               || cur_emp_det.employee_number
                                               || '-'
                                               || cur_emp_det.dep_cont_f_name
                                               || '-'
                                               || SQLERRM
                                              );
                        END;
                     END LOOP;                              -- DEP CURSOR LOOP
                  ELSE            -- PLAN CHANGE DETAILS FOR No DEPENDENT Plan
                     FOR cur_plan_det IN
                        c_plan (cur_emp_det.prtt_enrt_rslt_id)
                     --PLAN DETAIL CURSOR
                     LOOP
                        BEGIN
                           IF (
                                  -- PLAN CHANGE DETAILS FOR Plan Only (No Dependent) FLAG IF
                                  NVL (cur_plan_det.vin_option, 'AAA') <>
                                           NVL (cur_emp_det.vin_option, 'AAA')
                               -- OPTION NAME
                               OR NVL (cur_plan_det.first_name, 'AAA') <>
                                           NVL (cur_emp_det.first_name, 'AAA')
                               -- FIRST NAME
                               OR NVL (cur_plan_det.last_name, 'AAA') <>
                                            NVL (cur_emp_det.last_name, 'AAA')
                               -- LAST NAME
                               OR NVL (cur_plan_det.social_num, 'AAA') <>
                                           NVL (cur_emp_det.social_num, 'AAA')
                               -- SOCIAL IDENTIFIER
                               OR NVL (cur_plan_det.emp_cvg, 000) <>
                                                NVL (cur_emp_det.emp_cvg, 000)
                               -- EMP CVG
                               OR NVL (cur_plan_det.dep_cvg, 000) <>
                                                NVL (cur_emp_det.dep_cvg, 000)
                               -- DEP CVG
                               OR NVL (cur_plan_det.sps_cvg, 000) <>
                                                NVL (cur_emp_det.sps_cvg, 000)
                               -- SPS CVG
                               OR NVL (cur_plan_det.effective_date,
                                       TO_DATE (SYSDATE, 'DD-MON-YYYY')
                                      ) <>
                                     NVL
                                        (cur_emp_det.effective_date,
                                         TO_DATE (SYSDATE, 'DD-MON-YYYY')
                                        )                    -- EFFECTIVE DATE
                               OR NVL (cur_plan_det.ded_start_date,
                                       TO_DATE (SYSDATE, 'DD-MON-YYYY')
                                      ) <>
                                     NVL
                                        (cur_emp_det.ded_start_date,
                                         TO_DATE (SYSDATE, 'DD-MON-YYYY')
                                        )                    -- DED START DATE
                               OR NVL (cur_plan_det.sec_125, 'A') <>
                                                NVL (cur_emp_det.sec_125, 'A')
                               -- SEC_125
                               OR NVL (cur_plan_det.dep_social_num, 'AAA') <>
                                       NVL (cur_emp_det.dep_social_num, 'AAA')
                               -- DEP SOCIAL NUM
                               OR NVL (cur_plan_det.dep_cont_f_name, 'AAA') <>
                                      NVL (cur_emp_det.dep_cont_f_name, 'AAA')
                               -- DEP FIRST NAME
                               OR NVL (cur_plan_det.dep_cont_l_name, 'AAA') <>
                                      NVL (cur_emp_det.dep_cont_l_name, 'AAA')
                               -- DEP LAST NAME
                               OR NVL (cur_plan_det.dep_contact_type, 'AAA') <>
                                     NVL (cur_emp_det.dep_contact_type, 'AAA')
                               -- DEP CONTACT TYPE
                               OR NVL (cur_plan_det.dep_dob,
                                       TO_DATE (SYSDATE, 'DD-MON-YYYY')
                                      ) <>
                                     NVL (cur_emp_det.dep_dob,
                                          TO_DATE (SYSDATE, 'DD-MON-YYYY')
                                         )                          -- DEP DOB
                              )
                           THEN
                              v_action := 'CHANGE';
                              v_change_flag := 'Y';
                              v_columns_str :=
                                    v_action
                                 || '	'
                                 || 1895
                                 || '	'
                                 || cur_emp_det.vin_plan
                                 || '	'
                                 || cur_emp_det.vin_option
                                 || '	'
                                 || cur_emp_det.first_name
                                 || '	'
                                 || cur_emp_det.last_name
                                 || '	'
                                 || cur_emp_det.social_num
                                 || '	'
                                 || cur_emp_det.emp_cvg
                                 || '	'
                                 || cur_emp_det.sps_cvg
                                 || '	'
                                 || cur_emp_det.dep_cvg
                                 || '	'
                                 || TO_CHAR (cur_emp_det.effective_date,
                                             'MM/DD/YYYY'
                                            )
                                 || '	'
                                 || TO_CHAR (cur_emp_det.ded_start_date,
                                             'MM/DD/YYYY'
                                            )
                                 || '	'
                                 || cur_emp_det.sec_125
                                 || '	'
                                 || cur_emp_det.dep_social_num
                                 || '	'
                                 || cur_emp_det.dep_cont_f_name
                                 || '	'
                                 || cur_emp_det.dep_cont_l_name
                                 || '	'
                                 || cur_emp_det.dep_contact_type
                                 || '	'
                                 || TO_CHAR (cur_emp_det.dep_dob,
                                             'MM/DD/YYYY');
                              fnd_file.put_line (fnd_file.output,
                                                 v_columns_str
                                                );
                              xxteletech_emp_ben_en_change.write_process
                                       (   'TELETECH_PEO_EMP_BENEFIT_CHANGE_'
                                        || v_dt_time
                                        || '.txt',
                                        v_columns_str,
                                        'A',
                                        v_path
                                       );
                           END IF;      -- PLAN CHANGE DETAILS FOR DEP FLAG IF
                        EXCEPTION
                           WHEN OTHERS
                           THEN
                              fnd_file.put_line
                                              (fnd_file.LOG,
                                                  'c_plan cursor -'
                                               || cur_emp_det.employee_number
                                               || '-'
                                               || cur_emp_det.dep_cont_f_name
                                               || '-'
                                               || SQLERRM
                                              );
                        END;
                     END LOOP;                              -- DEP CURSOR LOOP
                  END IF;                                   -- 2nd DEP FLAG IF
               END IF;                                   -- 1st change flag if
            ELSE                                            -- PLAN COUNT ELSE
               v_action := 'ADD';
               v_change_flag := 'Y';
               v_columns_str :=
                     v_action
                  || '	'
                  || 1895
                  || '	'
                  || cur_emp_det.vin_plan
                  || '	'
                  || cur_emp_det.vin_option
                  || '	'
                  || cur_emp_det.first_name
                  || '	'
                  || cur_emp_det.last_name
                  || '	'
                  || cur_emp_det.social_num
                  || '	'
                  || cur_emp_det.emp_cvg
                  || '	'
                  || cur_emp_det.sps_cvg
                  || '	'
                  || cur_emp_det.dep_cvg
                  || '	'
                  || TO_CHAR (cur_emp_det.effective_date, 'MM/DD/YYYY')
                  || '	'
                  || TO_CHAR (cur_emp_det.ded_start_date, 'MM/DD/YYYY')
                  || '	'
                  || cur_emp_det.sec_125
                  || '	'
                  || cur_emp_det.dep_social_num
                  || '	'
                  || cur_emp_det.dep_cont_f_name
                  || '	'
                  || cur_emp_det.dep_cont_l_name
                  || '	'
                  || cur_emp_det.dep_contact_type
                  || '	'
                  || TO_CHAR (cur_emp_det.dep_dob, 'MM/DD/YYYY');
               fnd_file.put_line (fnd_file.output, v_columns_str);
               xxteletech_emp_ben_en_change.write_process
                                       (   'TELETECH_PEO_EMP_BENEFIT_CHANGE_'
                                        || v_dt_time
                                        || '.txt',
                                        v_columns_str,
                                        'A',
                                        v_path
                                       );
            END IF;                                        --PLAN COUNT END IF
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line (fnd_file.LOG,
                                     'cur_emp_det cursor -'
                                  || cur_emp_det.employee_number
                                  || '-'
                                  || cur_emp_det.dep_cont_f_name
                                  || '-'
                                  || SQLERRM
                                 );
         END;
      END LOOP;                                             --MAIN CURSOR LOOP

      --## TERMINATED PLAN DETAILS FETCH## --
      FOR cur_plan_term IN c_plan_term (v_date, v_start_date, v_end_date)
      LOOP
         BEGIN
            v_action := 'TERM';
            v_change_flag := 'Y';
            v_columns_str :=
                  v_action
               || '	'
               || 1895
               || '	'
               || cur_plan_term.vin_plan
               || '	'
               || cur_plan_term.vin_option
               || '	'
               || cur_plan_term.first_name
               || '	'
               || cur_plan_term.last_name
               || '	'
               || cur_plan_term.social_num
               || '	'
               || cur_plan_term.emp_cvg
               || '	'
               || cur_plan_term.sps_cvg
               || '	'
               || cur_plan_term.dep_cvg
               || '	'
               || TO_CHAR (cur_plan_term.effective_date, 'MM/DD/YYYY')
               || '	'
               || TO_CHAR (cur_plan_term.ded_start_date, 'MM/DD/YYYY')
               || '	'
               || cur_plan_term.sec_125
               || '	'
               || cur_plan_term.dep_social_num
               || '	'
               || cur_plan_term.dep_cont_f_name
               || '	'
               || cur_plan_term.dep_cont_l_name
               || '	'
               || cur_plan_term.dep_contact_type
               || '	'
               || TO_CHAR (cur_plan_term.dep_dob, 'MM/DD/YYYY');
            fnd_file.put_line (fnd_file.output, v_columns_str);
            xxteletech_emp_ben_en_change.write_process
                                       (   'TELETECH_PEO_EMP_BENEFIT_CHANGE_'
                                        || v_dt_time
                                        || '.txt',
                                        v_columns_str,
                                        'A',
                                        v_path
                                       );
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line (fnd_file.LOG,
                                     'c_plan_term cursor -'
                                  || cur_plan_term.employee_number
                                  || '-'
                                  || cur_plan_term.dep_cont_f_name
                                  || '-'
                                  || SQLERRM
                                 );
         END;
      END LOOP;

      --## TERMINATED PLAN DETAILS FINISH## --
      --## DELETED DEPENDENTS DETAILS FETCH## --
      FOR cur_dep_del IN c_dep_del (v_date, v_start_date, v_end_date)
      --DEP DETAILS
      LOOP
         BEGIN
            v_action := 'DEPEN-';
            v_change_flag := 'Y';
            v_columns_str :=
                  v_action
               || '	'
               || 1895
               || '	'
               || cur_dep_del.vin_plan
               || '	'
               || cur_dep_del.vin_option
               || '	'
               || cur_dep_del.first_name
               || '	'
               || cur_dep_del.last_name
               || '	'
               || cur_dep_del.social_num
               || '	'
               || cur_dep_del.emp_cvg
               || '	'
               || cur_dep_del.sps_cvg
               || '	'
               || cur_dep_del.dep_cvg
               || '	'
               || TO_CHAR (cur_dep_del.effective_date, 'MM/DD/YYYY')
               || '	'
               || TO_CHAR (cur_dep_del.ded_start_date, 'MM/DD/YYYY')
               || '	'
               || cur_dep_del.sec_125
               || '	'
               || cur_dep_del.dep_social_num
               || '	'
               || cur_dep_del.dep_cont_f_name
               || '	'
               || cur_dep_del.dep_cont_l_name
               || '	'
               || cur_dep_del.dep_contact_type
               || '	'
               || cur_dep_del.dep_dob;
            fnd_file.put_line (fnd_file.output, v_columns_str);
            xxteletech_emp_ben_en_change.write_process
                                       (   'TELETECH_PEO_EMP_BENEFIT_CHANGE_'
                                        || v_dt_time
                                        || '.txt',
                                        v_columns_str,
                                        'A',
                                        v_path
                                       );
         EXCEPTION
            WHEN OTHERS
            THEN
               fnd_file.put_line (fnd_file.LOG,
                                     'c_dep_del cursor -'
                                  || cur_dep_del.employee_number
                                  || '-'
                                  || cur_dep_del.dep_cont_f_name
                                  || '-'
                                  || SQLERRM
                                 );
         END;
      END LOOP;                                      -- DEP DETAILS CURSOR END

      --## DELETED DEPENDENTS DETAILS FINISH## --
      fnd_file.put_line (fnd_file.LOG, 'DROPPING TABLE');

      BEGIN
         EXECUTE IMMEDIATE ('DROP TABLE XXTELETECH_EMP_BEN_EN_TAB');
      EXCEPTION
         WHEN OTHERS
         THEN
            fnd_file.put_line (fnd_file.LOG,
                               'TABLE DOES NOT EXIST, HENCE CREATING'
                              );
      END;

      BEGIN
         v_string :=
               'CREATE TABLE XXTELETECH_EMP_BEN_EN_TAB AS SELECT          pen.prtt_enrt_rslt_id,'
            || '    xx_dep.ELIG_CVRD_DPNT_ID, '
            || '   pap.employee_number employee_number, '
            || '  pap.full_name full_name, '
            || '   DECODE(BPL.PL_ID,691,DECODE(( '
            || ' SELECT DECODE((SELECT COUNT(*) '
            || ' FROM PER_PERSON_ANALYSES PAA,
PER_ANALYSIS_CRITERIA PAC,
PER_ALL_PEOPLE_F PAP3
WHERE PAA.BUSINESS_GROUP_ID=325
AND PAA.ID_FLEX_NUM IN (SELECT ID_FLEX_NUM
FROM FND_ID_FLEX_STRUCTURES
WHERE ID_FLEX_STRUCTURE_CODE = '
            || sq
            || 'TTEC_HEALTH_ASSESSMENT'
            || sq
            || '  AND ENABLED_FLAG ='
            || sq
            || 'Y'
            || sq
            || ')
AND '
            || sq
            || v_date
            || sq
            || ' BETWEEN PAA.DATE_FROM AND PAA.DATE_TO
AND PAC.ANALYSIS_CRITERIA_ID = PAA.ANALYSIS_CRITERIA_ID
AND PAC.ENABLED_FLAG= '
            || sq
            || 'Y'
            || sq
            || ' AND PAC.SEGMENT1='
            || sq
            || 'Y'
            || sq
            || ' AND PAA.PERSON_ID = PAP3.PERSON_ID
AND '
            || sq
            || v_date
            || sq
            || ' BETWEEN PAP3.EFFECTIVE_START_DATE AND EFFECTIVE_END_DATE
AND PAA.PERSON_ID = PAP.PERSON_ID),0,'
            || sq
            || 'A'
            || sq
            || ','
            || sq
            || 'B'
            || sq
            || ') FROM DUAL
),'
            || sq
            || 'A'
            || sq
            || ','
            || sq
            || 'BAL0002'
            || sq
            || ','
            || sq
            || 'BAL0001'
            || sq
            || '),
247,'
            || sq
            || 'METLIFE48'
            || sq
            || ',246,'
            || sq
            || 'METLIFE47'
            || sq
            || ',4871,'
            || sq
            || 'DELTA07'
            || sq
            || ',262,'
            || sq
            || 'DELTA06'
            || sq
            || ',275,'
            || sq
            || 'AIG001'
            || sq
            || ',272,'
            || sq
            || 'METLIFE46'
            || sq
            || ',258,'
            || sq
            || 'METLIFE45'
            || sq
            || ',254,'
            || sq
            || 'METLIFE50'
            || sq
            || ',256,'
            || sq
            || 'METLIFE53'
            || sq
            || ',260,'
            || sq
            || 'METLIFE52'
            || sq
            || ',250,'
            || sq
            || 'METLIFE51'
            || sq
            || ',252,'
            || sq
            || 'METLIFE49'
            || sq
            || ',264,'
            || sq
            || 'VSP008'
            || sq
            || ',277,'
            || sq
            || 'METLIFE53'
            || sq
            || ',278,'
            || sq
            || 'METLIFE51'
            || sq
            || ') VIN_PLAN, '
            || '  decode(bpl.pl_id,247,null,246,null,272,null,254,null,opt.name) vin_OPTION,'
            || '   pap.first_name first_name, '
            || '   pap.last_name last_name, '
            || '  pap.national_identifier social_num, '
            || '   DECODE(bpl.pl_id, 260,pen.bnft_amt,245,pen.bnft_amt,248,pen.bnft_amt,256,pen.bnft_amt,277,pen.bnft_amt,247,(SELECT TRUNC((PROPOSED_SALARY_N * 2080),3)
FROM PER_PAY_PROPOSALS PPP,
PER_ALL_ASSIGNMENTS_F PAA
WHERE PPP.ASSIGNMENT_ID = PAA.ASSIGNMENT_ID
AND   PAA.PERSON_ID     = PAP.PERSON_ID
AND '
            || sq
            || v_date
            || sq
            || ' BETWEEN PAA.EFFECTIVE_START_DATE AND PAA.EFFECTIVE_END_DATE AND'
            || sq
            || v_date
            || sq
            || 'BETWEEN ppp.change_date and NVL(ppp.date_to,TRUNC(SYSDATE)))
,246, (SELECT TRUNC((PROPOSED_SALARY_N * 2080),3)
FROM PER_PAY_PROPOSALS PPP,
PER_ALL_ASSIGNMENTS_F PAA
WHERE PPP.ASSIGNMENT_ID = PAA.ASSIGNMENT_ID
AND   PAA.PERSON_ID     = PAP.PERSON_ID
AND '
            || sq
            || v_date
            || sq
            || ' BETWEEN PAA.EFFECTIVE_START_DATE AND PAA.EFFECTIVE_END_DATE AND'
            || sq
            || v_date
            || sq
            || 'BETWEEN ppp.change_date and NVL(ppp.date_to,TRUNC(SYSDATE)))
,272, (SELECT TRUNC((0.6 * (PROPOSED_SALARY_N) * 2080)/12,3)
FROM PER_PAY_PROPOSALS PPP,
PER_ALL_ASSIGNMENTS_F PAA
WHERE PPP.ASSIGNMENT_ID = PAA.ASSIGNMENT_ID
AND   PAA.PERSON_ID     = PAP.PERSON_ID
AND '
            || sq
            || v_date
            || sq
            || ' BETWEEN PAA.EFFECTIVE_START_DATE AND PAA.EFFECTIVE_END_DATE AND'
            || sq
            || v_date
            || sq
            || 'BETWEEN ppp.change_date and NVL(ppp.date_to,TRUNC(SYSDATE)))
,258, (SELECT TRUNC((1 * (PROPOSED_SALARY_N) * 2080)/52,3)
FROM PER_PAY_PROPOSALS PPP,
PER_ALL_ASSIGNMENTS_F PAA
WHERE PPP.ASSIGNMENT_ID = PAA.ASSIGNMENT_ID
AND   PAA.PERSON_ID     = PAP.PERSON_ID
AND '
            || sq
            || v_date
            || sq
            || ' BETWEEN PAA.EFFECTIVE_START_DATE AND PAA.EFFECTIVE_END_DATE AND'
            || sq
            || v_date
            || sq
            || 'BETWEEN ppp.change_date and NVL(ppp.date_to,TRUNC(SYSDATE)))) emp_cvg, '
            || '  DECODE(bpl.pl_id, 250,pen.bnft_amt,278,pen.bnft_amt,252,pen.bnft_amt) sps_cvg, '
            || '  DECODE(bpl.pl_id, 254,pen.bnft_amt) dep_cvg, '
            || '   pen.enrt_cvg_strt_dt effective_date, '
            || '   (SELECT MAX(rates.rt_strt_dt) '
            --|| '  FROM ben.ben_prtt_rt_val rates ' --code commented by RXNETHI-ARGANO,11/05/23
			|| '  FROM apps.ben_prtt_rt_val rates ' --code added by RXNETHI-ARGANO,11/05/23
            || ' WHERE rates.prtt_enrt_rslt_id = pen.prtt_enrt_rslt_id '
            || '   AND '
            || sq
            || v_date
            || sq
            || ' BETWEEN RT_STRT_DT AND RT_END_DT) ded_start_date, '
            || '  DECODE(pen.pl_id,691,DECODE(SUBSTR(opt.name,1,8),'
            || sq
            || 'Post Tax'
            || sq
            || ','
            || sq
            || 'N'
            || sq
            || ','
            || sq
            || 'Y'
            || sq
            || '),247,'
            || sq
            || 'N'
            || sq
            || ',246,'
            || sq
            || 'N'
            || sq
            || ',4871,DECODE(SUBSTR(opt.name,1,8),'
            || sq
            || 'Post Tax'
            || sq
            || ','
            || sq
            || 'N'
            || sq
            || ','
            || sq
            || 'Y'
            || sq
            || '),262,DECODE(SUBSTR(opt.name,1,8),'
            || sq
            || 'Post Tax'
            || sq
            || ','
            || sq
            || 'N'
            || sq
            || ','
            || sq
            || 'Y'
            || sq
            || '),248,'
            || sq
            || 'Y'
            || sq
            || ',275,'
            || sq
            || 'N'
            || sq
            || ',245,'
            || sq
            || 'Y'
            || sq
            || ',272,'
            || sq
            || 'N'
            || sq
            || ',258,'
            || sq
            || 'N'
            || sq
            || ',254,'
            || sq
            || 'N'
            || sq
            || ',256,'
            || sq
            || 'N'
            || sq
            || ',277,'
            || sq
            || 'N'
            || sq
            || ',260,'
            || sq
            || 'N'
            || sq
            || ',250,'
            || sq
            || 'N'
            || sq
            || ',278,'
            || sq
            || 'N'
            || sq
            || ',252,'
            || sq
            || 'N'
            || sq
            || ',264,DECODE(SUBSTR(opt.name,1,8),'
            || sq
            || 'Post Tax'
            || sq
            || ','
            || sq
            || 'N'
            || sq
            || ','
            || sq
            || 'Y'
            || sq
            || '),263,'
            || sq
            || 'N'
            || sq
            || ',249,'
            || sq
            || 'N'
            || sq
            || ',276,'
            || sq
            || 'N'
            || sq
            || ',273,'
            || sq
            || 'N'
            || sq
            || ',268,'
            || sq
            || 'N'
            || sq
            || ',259,'
            || sq
            || 'N'
            || sq
            || ',255,'
            || sq
            || 'N'
            || sq
            || ',257,'
            || sq
            || 'N'
            || sq
            || ',261,'
            || sq
            || 'N'
            || sq
            || ',251,'
            || sq
            || 'N'
            || sq
            || ',253,'
            || sq
            || 'N'
            || sq
            || ',265,'
            || sq
            || 'N'
            || sq
            || ') sec_125, '
            || '  dep_social_num,
dep_cont_f_name,
dep_cont_l_name,
dep_contact_type,
dep_dob,
pen.pl_id
FROM   apps.per_all_people_f pap,   --code edited by RXNETHI-ARGANO,11/05/2023
apps.BEN_PRTT_ENRT_RSLT_F pen, '   --code edited by RXNETHI-ARGANO,11/05/2023
            || ' (SELECT * '
            || '  FROM apps.ben_pl_f '  --code edited by RXNETHI-ARGANO,11/05/23
            || '  WHERE '
            || sq
            || v_date
            || sq
            || ' BETWEEN effective_start_date AND effective_END_date '
            || '  AND pl_id IN (691,247,246,4871,262,275,272,258,254,256,277,260,250,278,252,264)'
            || '  AND pl_typ_id IN (86,22,26,32,87,85,31,24,37,30,25,23,29,27,28)) BPL, '
            || '  (SELECT *
FROM apps.ben_opt_f --code edited by RXNETHI-ARGANO,11/05/23
WHERE '
            || sq
            || v_date
            || sq
            || ' BETWEEN effective_start_date AND effective_END_date) opt,
apps.BEN_OIPL_F opl, --code edited by RXNETHI-ARGANO,11/05/23
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
apps.BEN_ELIG_CVRD_DPNT_F dep,  --code edited by RXNETHI-ARGANO,11/05/23
PER_ALL_PEOPLE_F pap1,
HR_LOOKUPS hl
WHERE pcr.contact_type IN ('
            || v_contact_type
            || ')
AND pcr.person_id = pap1.person_id
AND pcr.contact_person_id = papf_cont.person_id
AND '
            || sq
            || v_date
            || sq
            || ' BETWEEN papf_cont.effective_start_date AND papf_cont.effective_END_date
AND '
            || sq
            || v_date
            || sq
            || ' BETWEEN pap1.effective_start_date AND pap1.effective_END_date
AND '
            || sq
            || v_date
            || sq
            || ' BETWEEN dep.effective_start_date AND dep.effective_END_date
AND '
            || sq
            || v_date
            || sq
            || ' BETWEEN dep.cvg_strt_dt AND dep.cvg_thru_dt
AND dep.dpnt_person_id = pcr.contact_person_id
AND hl.lookup_type(+) = '
            || sq
            || 'CONTACT'
            || sq
            || ' AND hl.lookup_code(+) = pcr.contact_type
) xx_dep
WHERE
pen.pl_id = bpl.pl_id
AND pen.person_id = pap.person_id
AND xx_dep.person_id(+)=pen.person_id
AND '
            || sq
            || v_date
            || sq
            || ' BETWEEN pen.enrt_cvg_strt_dt AND pen.enrt_cvg_thru_dt
AND '
            || sq
            || v_date
            || sq
            || ' BETWEEN pen.effective_start_date AND pen.effective_END_date
AND  pen.prtt_enrt_rslt_stat_cd IS NULL
AND opl.opt_id = opt.opt_id(+)
AND pen.oipl_id = opl.oipl_id(+)
AND '
            || sq
            || v_date
            || sq
            || ' BETWEEN pap.effective_start_date AND pap.effective_END_date
AND hr_person_type_usage_info.get_user_person_type ( trunc(pap.effective_start_date), pap.person_id ) = '
            || sq
            || 'PEO Employee'
            || sq
            || ' AND pap.current_employee_flag = '
            || sq
            || 'Y'
            || sq
            || ' AND pap.business_group_id = 325
AND xx_dep.prtt_enrt_rslt_id(+) = pen.prtt_enrt_rslt_id
ORDER BY
pap.employee_number';

         EXECUTE IMMEDIATE (v_string);

         fnd_file.put_line (fnd_file.LOG, 'TABLE CREATION COMPLETED');
         fnd_file.put_line (fnd_file.LOG, 'PROGRAM SUCCESSFULLY COMPLETED');
      EXCEPTION
         WHEN OTHERS
         THEN
            fnd_file.put_line (fnd_file.LOG,
                                  'Dynamic create completed with error '
                               || SQLERRM
                              );
      END;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG,
                            'Program completed with error ' || SQLERRM
                           );
         RAISE;
   END main;

   PROCEDURE write_process (
      p_file_name   IN   VARCHAR2,
      p_data        IN   VARCHAR2,
      p_mode        IN   VARCHAR2,
      p_path        IN   VARCHAR2
   )
   IS
      f1       UTL_FILE.file_type;
      v_path   VARCHAR2 (200)     := p_path;
   BEGIN
      --fnd_file.put_line(fnd_file.log,'extract line : '||p_data);
      f1 := UTL_FILE.fopen (v_path, p_file_name, p_mode, 32767);

      IF p_data IS NOT NULL
      THEN
         UTL_FILE.put_line (f1, p_data, FALSE);
      --UTL_FILE.NEW_LINE(F1, 1);
      END IF;

      UTL_FILE.fflush (f1);
      UTL_FILE.fclose (f1);
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line
                        (fnd_file.LOG,
                            'Write_process could not complete successfully: '
                         || SQLERRM
                         || ' : '
                         || v_path
                        );
   END write_process;
END xxteletech_emp_ben_en_change;
/
show errors;
/
