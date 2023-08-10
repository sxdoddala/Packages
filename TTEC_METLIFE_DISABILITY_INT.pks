create or replace PACKAGE      TTEC_METLIFE_DISABILITY_INT AUTHID CURRENT_USER AS
--
-- Program Name:  TTEC_METLIFE_DISABILITY_INT
-- /* $Header: TTEC_METLIFE_DISABILITY_INT.pks 1.0 2013/08/20  chchan ship $ */
--
-- /*== START ================================================================================================*\
--    Author: Christiane Chan
--      Date: 20-AUG-2013

-- Call From: Concurrent Program ->TeleTech MetLife LT/ST Disability Outbound Interface
--      Desc: This program generates TeleTech employees information mandated by MetLife LT/ST Disability Standard Layout
--
--     Parameter Description:
--
--         p_business_group_id       :  Business Group ID
--         p_client_number           :  TeleTech Client Number assigned by MetLife
--         p_ltd_plan_id             :  Long Term Plan ID
--         p_vol_ltd_ft_plan_id      :  Vol. LTD FT Plan ID  /* 1.1 */
--         p_vol_ltd_pt_plan_id      :  Vol. LTD PT Plan ID  /* 1.1 */
--         p_std_plan1_id            :  Short Term Plan 1 ID
--         p_std_plan2_id            :  Short Term Plan 2 ID
--         p_std_plan1_id            :  Short Term Plan 1 ID
--         p_sub_div_code            :  Subdivision Code
--         p_branch_code1            :  Branch Code 1
--         p_branch_code2            :  Branch Code 2
--         p_branch_code3            :  Branch Code 3
--         p_branch_code5            :  Branch Code 5
--         p_branch_code6            :  Branch Code 6
--         p_branch_code9            :  Branch Code 9
--
--       Oracle Standard Parameters:
--
--   Modification History:
--
--  Version    Date     Author   Description (Include Ticket--)
--  -------  --------  --------  ------------------------------------------------------------------------------
--      1.0  08/20/13   CChan     Initial Version TTSD R#2645787 - MetLife Disability File Extract
--
--      1.1  11/05/13   CChan     Adding 2014 Voluntary LDT plan for Full Time and Part Time employees
--
--      1.2  11/04/14   CChan     Bug Fix
--
--      1.3  09/29/17   Prajhans  New plan names for Supp Life - METLIFE
--
--      1.4  04/14/22   C.Chan    Adding LOGIC for AVTEX employee to use the 'Adjusted Service Date' to derive the STD Branch Code
--                                       If location code contains AVTEX, then we will derived the service date using 'Adjusted Service Date'.
--                                       And if 'Adjusted Service Date'  is not available, we will use the start date
--      1.0  04/MAY/2023 RXNETHI-ARGANO  R12.2 Upgrade Remediation
-- \*== END =====================================
    -- Error Constants
    /*
	START R12.2 Upgrade Remediation
	code commented by RXNETHI-ARGANO,04/05/23
	g_application_code   cust.ttec_error_handling.application_code%TYPE := 'HR';
    g_interface          cust.ttec_error_handling.INTERFACE%TYPE        := 'MetDis Intf';
    g_package            cust.ttec_error_handling.program_name%TYPE     := 'TTEC_METLIFE_DISABILITY_INT';
    g_label1             cust.ttec_error_handling.label1%TYPE           := 'Err Location';
    g_label2             cust.ttec_error_handling.label1%TYPE           := 'Emp_Number';
    g_warning_status     cust.ttec_error_handling.status%TYPE           := 'WARNING';
    g_error_status       cust.ttec_error_handling.status%TYPE           := 'ERROR';
    g_failure_status     cust.ttec_error_handling.status%TYPE           := 'FAILURE';
	*/
	--code added by RXNETHI-ARGANO,04/05/23
	g_application_code   apps.ttec_error_handling.application_code%TYPE := 'HR';
    g_interface          apps.ttec_error_handling.INTERFACE%TYPE        := 'MetDis Intf';
    g_package            apps.ttec_error_handling.program_name%TYPE     := 'TTEC_METLIFE_DISABILITY_INT';
    g_label1             apps.ttec_error_handling.label1%TYPE           := 'Err Location';
    g_label2             apps.ttec_error_handling.label1%TYPE           := 'Emp_Number';
    g_warning_status     apps.ttec_error_handling.status%TYPE           := 'WARNING';
    g_error_status       apps.ttec_error_handling.status%TYPE           := 'ERROR';
    g_failure_status     apps.ttec_error_handling.status%TYPE           := 'FAILURE';
	--END R12.2 Upgrade Remediation


    -- Process FAILURE variables
    g_fail_flag                   BOOLEAN := FALSE;

    -- Filehandle Variables
    v_file_path                      varchar2(400);
    v_filename                     varchar2(100);
    v_country                      varchar2(2);

    v_output_file                    UTL_FILE.FILE_TYPE;

    -- Declare variables
    g_as_of_date                   varchar2(12); /* 1.1 */
    g_business_group_id            number(5);
    g_ltd_plan_id                  NUMBER;
    g_vol_ltd_ft_plan_id           NUMBER; /* 1.1 */
    g_vol_ltd_pt_plan_id           NUMBER; /* 1.1 */
    g_std_plan1_id                 NUMBER;
    g_std_plan2_id                 NUMBER;
    g_client_number                VARCHAR2(10);
    g_file_prefix                  VARCHAR2(30);
    --g_emp_no                       hr.per_all_people_f.employee_number%TYPE;   --code commented by RXNETHI-ARGANO,04/05/23
    g_emp_no                       apps.per_all_people_f.employee_number%TYPE;   --code added by RXNETHI-ARGANO,04/05/23
    g_termed_since_no_days         NUMBER;

  -- declare cursors
    cursor c_billing is
    select haou.LOCATION_ID billing_location_id,
           hl.location_code billing_location_name,
           hl.address_line_1 billing_contact_name,
           hl.address_line_2 billing_address_1,
           hl.town_or_city billing_city,
           hl.region_2 billing_state,
           hl.POSTAL_CODE billing_postal,
           hl.country billing_country
    from hr_locations hl
       --, hr.hr_all_organization_units haou   --code commented by RXNETHI-ARGANO,04/05/23
       , apps.hr_all_organization_units haou   --code added by RXNETHI-ARGANO,04/05/23
    where haou.TYPE = 'BG'
    and haou.LOCATION_ID = hl.LOCATION_ID
    and haou.BUSINESS_GROUP_ID = g_business_group_id;


    cursor c_bg is
    select haou.name
    --from hr.hr_all_organization_units haou      --code commented by RXNETHI-ARGANO,04/05/23
    from apps.hr_all_organization_units haou      --code added by RXNETHI-ARGANO,04/05/23
    where haou.TYPE = 'BG'
    and haou.BUSINESS_GROUP_ID =  g_business_group_id;

    cursor c_directory_path is
    select ttec_library.get_directory('CUST_TOP')||'/data/EBS/HC/Benefits/metlife' file_path,
           'TELEDIS_dis_elig.dat' file_name
    from dual;

    /* main query to obtain US employees data from HR tables */
    cursor c_emp_cur  is

SELECT pap.person_id,
      -- NVL (ppos.actual_termination_date , TRUNC(SYSDATE)) emp_process_date,  /* 1.1 */
       NVL (ppos.actual_termination_date , TRUNC(TO_DATE(g_as_of_date))) emp_process_date,  /* 1.1 */
        ('E'
       ||NVL(substr(g_client_number,1,7),LPAD('0',7,'0'))
       ||NVL(SUBSTR(LPAD(REPLACE(pap.national_identifier,'-',''),11,'0'),1,11),LPAD('0',11,'0'))
       ||RPAD(pap.employee_number,9,' ')
       ||RPAD(' ',13,' ')
       ||'0'
       ||NVL(SUBSTR(RPAD(REPLACE(ttec_library.remove_non_ascii (TRANSLATE(pap.LAST_name||decode(length(pap.SUFFIX),0,'',' ')||pap.SUFFIX,'`~!@#$%^&*()-_=+[{]}\|;: ,<.>/??','                                ')),'  ',' '),20,' '),1,20),RPAD(' ',20,' '))
       ||NVL(SUBSTR(RPAD(REPLACE(ttec_library.remove_non_ascii (TRANSLATE(pap.first_name,'`~!@#$%^&*()-_=+[{]}\|;: ,<.>/??','                                ')),'  ',' '),12,' '),1,12),RPAD(' ',12,' '))
       ||NVL(SUBSTR(RPAD(REPLACE(ttec_library.remove_non_ascii (TRANSLATE(pap.middle_names,'`~!@#$%^&*()-_=+[{]}\|;: ,<.>/??','                                ')),'  ',' '),1,' '),1,1),RPAD(' ',1,' '))
       ||TO_CHAR(date_of_birth,'MMDDYYYY')
       ||CASE WHEN pap.marital_status NOT IN ('M','S','D','W','C','U') THEN 'U' ELSE RPAD(NVL(pap.marital_status,' '),1,' ') END
       ||RPAD(NVL(pap.sex,' '),1,' ')
       ||TO_CHAR(ppos.date_start,'MMDDYYYY') --hire_date
       ||'        '   --Leave Blank(8)
       ||'          ' --Leave Blank (10)
       ||'D' --Foreign Address Indicator
       ||NVL(SUBSTR(RPAD(REPLACE(ttec_library.remove_non_ascii (TRANSLATE(pa.address_line1,'`~!@#$%^&*()-_=+[{]}\|;: ,<.>/??','                                ')),'  ',' '),32,' '),1,32),RPAD(' ',32,' '))
       ||NVL(SUBSTR(RPAD(REPLACE(ttec_library.remove_non_ascii (TRANSLATE(pa.address_line2,'`~!@#$%^&*()-_=+[{]}\|;: ,<.>/??','                                ')),'  ',' '),32,' '),1,32),RPAD(' ',32,' '))
       ||NVL(SUBSTR(RPAD(REPLACE(ttec_library.remove_non_ascii (TRANSLATE(pa.town_or_city ,'`~!@#$%^&*()-_=+[{]}\|;: ,<.>/??','                                ')),'  ',' '),21,' '),1,21),RPAD(' ',21,' '))
       ||RPAD(NVL(DECODE (pa.country,
                                 'BR', pa.region_2,
                                 'CA', pa.region_1,
                                 'CR', pa.region_1,
                                 'ES', pa.region_1,
                                 'UK', '',
                                 'MX', pa.region_1,
                                 'PH', pa.region_1,
                                 'US', pa.region_2,
                                 'NZ', ''
                                ),' '),2,' ')
       ||RPAD(REPLACE(REPLACE(NVL(pa.postal_code,' '),'.'),'-'),9,' ')
       ||RPAD(NVL(DECODE (hrl.country,
                                 'BR', hrl.region_2,
                                 'CA', hrl.region_1,
                                 'CR', hrl.region_1,
                                 'ES', hrl.region_1,
                                 'UK', '',
                                 'MX', hrl.region_1,
                                 'PH', hrl.region_1,
                                 'US', hrl.region_2,
                                 'NZ', ''
                                ),' '),2,' ')
       ||NVL(SUBSTR(RPAD(REPLACE(ttec_library.remove_non_ascii (TRANSLATE(SUBSTR(hrl.location_code ,5),'`~!@#$%^&*()-_=+[{]}\|;: ,<.>/??','                                ')),'  ',' '),12,' '),1,12),RPAD(' ',12,' '))
       ||'E' --Foreign Language Type
       ||DECODE(filing_status_code,'01','S','02','M','E')
       ||'           ' --Blank position 225-235
       ||REPLACE(REPLACE(REPLACE(TO_CHAR(ROUND(NVL(ppp.proposed_salary_n,0) * NVL(ppb.pay_annualization_factor,1)),'S0000000.00'),'.'),'+'),'-')
       ||'Y'
       ||TO_CHAR(ppp.change_date,'MMDDYYYY')
	   ||'                                                 ' )   emp_basic_info -- Blank position 259 - 302
       ,DECODE(pj.attribute5,'Exec','Y',DECODE(SIGN(INSTR(UPPER(pj.attribute6),'VICE')),1,'Y','N')) VP_indicator
       ,DECODE (pa.country,
                                 'BR', pa.region_2,
                                 'CA', pa.region_1,
                                 'CR', pa.region_1,
                                 'ES', pa.region_1,
                                 'UK', '',
                                 'MX', pa.region_1,
                                 'PH', pa.region_1,
                                 'US', pa.region_2,
                                 'NZ', ''
                                )                                         emp_residence_state
--       ,(  NVL (ppos.actual_termination_date , TRUNC(SYSDATE)) - TRUNC(ppos.date_start))/365       emp_year_of_service /* 1.1 */
       ,(  NVL (ppos.actual_termination_date ,TRUNC(TO_DATE(g_as_of_date))) - TRUNC(ppos.date_start))/365       emp_year_of_service /* 1.1 */
       ,(  NVL (ppos.actual_termination_date ,TRUNC(TO_DATE(g_as_of_date))) - TRUNC(ppos.adjusted_svc_date))/365       emp_adj_year_of_service /* 1.4 */
       ,ppos.adjusted_svc_date  /* 1.4 */
       ,ppos.date_start  /* 1.4 */
       , hrl.location_code /* 1.4 */
FROM   apps.per_all_people_f pap,
       apps.per_addresses pa,
--       ben.ben_prtt_enrt_rslt_f pen,
       /*
	   START R12.2 Upgrade Remediation
	   code commented by RXNETHI-ARGANO,04/05/23
	   hr.hr_locations_all hrl,
       hr.per_all_assignments_f paa,
       pay_us_emp_fed_tax_rules_f pueft,
       hr.per_jobs pj,
       hr.per_periods_of_service ppos,
       hr.per_pay_bases ppb,
	   */
	   --code added by RXNETHI-ARGANO,04/05/23
	   apps.hr_locations_all hrl,
       apps.per_all_assignments_f paa,
       pay_us_emp_fed_tax_rules_f pueft,
       apps.per_jobs pj,
       apps.per_periods_of_service ppos,
       apps.per_pay_bases ppb,
	   --END R12.2 Upgrade Remediation
          (SELECT p.assignment_id, p.proposed_salary_n, p.change_date
             --FROM hr.per_pay_proposals p   --code commented by RXNETHI-ARGANO,04/05/23
             FROM apps.per_pay_proposals p   --code added by RXNETHI-ARGANO,04/05/23
            WHERE p.change_date =
                     (SELECT MAX (x.change_date)
                        --FROM hr.per_pay_proposals x    --code commented by RXNETHI-ARGANO,04/05/23
                        FROM apps.per_pay_proposals x    --code added by RXNETHI-ARGANO,04/05/23
                       WHERE p.assignment_id = x.assignment_id
                             --AND (x.change_date) <= TRUNC(SYSDATE))) ppp /* 1.1 */
                             AND (x.change_date) <= TRUNC(TO_DATE(g_as_of_date)))) ppp /* 1.1 */
--WHERE  NVL (ppos.actual_termination_date , TRUNC(SYSDATE)) BETWEEN pap.effective_start_date AND pap.effective_end_date /* 1.1 */
WHERE  NVL (ppos.actual_termination_date , TRUNC(TO_DATE(g_as_of_date))) BETWEEN pap.effective_start_date AND pap.effective_end_date /* 1.1 */
       AND pap.person_id = paa.person_id
       AND pap.person_id = pa.person_id
       AND paa.job_id = pj.job_id
       AND paa.assignment_type = 'E'
       --AND pap.current_employee_flag = 'Y'
       AND pa.PRIMARY_FLAG = 'Y'
       --AND  NVL (ppos.actual_termination_date , TRUNC(SYSDATE)) BETWEEN pa.date_from AND NVL(pa.date_to,'31-DEC-4712') /* 1.1 */
       AND  NVL (ppos.actual_termination_date , TRUNC(TO_DATE(g_as_of_date))) BETWEEN pa.date_from AND NVL(pa.date_to,'31-DEC-4712') /* 1.1 */
       AND paa.location_id = hrl.location_id
       --AND  NVL (ppos.actual_termination_date , TRUNC(SYSDATE)) BETWEEN paa.effective_start_date AND paa.effective_end_date /* 1.1 */
       AND  NVL (ppos.actual_termination_date , TRUNC(TO_DATE(g_as_of_date))) BETWEEN paa.effective_start_date AND paa.effective_end_date /* 1.1 */
       --AND pap.EMPLOYEE_NUMBER = '3010695'
--       AND pap.EMPLOYEE_NUMBER --= '3010695'
--       IN (
--'3154665',
--'3164037',
--'3168790',
--'3168791',
--'3148019',
--'3149432',
--'3133263'
--       )
       AND paa.assignment_id = pueft.assignment_id
       --AND  NVL (ppos.actual_termination_date , TRUNC(SYSDATE)) BETWEEN pueft.effective_start_date AND pueft.effective_end_date /* 1.1 */
       AND  NVL (ppos.actual_termination_date , TRUNC(TO_DATE(g_as_of_date))) BETWEEN pueft.effective_start_date AND pueft.effective_end_date /* 1.1 */
       AND paa.assignment_id = ppp.assignment_id
       AND paa.pay_basis_id = ppb.pay_basis_id
       AND ppos.person_id = pap.person_id
       AND ppos.date_start= (SELECT MAX (ppos1.date_start)
                               --FROM hr.per_periods_of_service ppos1    --code commented by RXNETHI-ARGANO,04/05/23
                               FROM apps.per_periods_of_service ppos1    --code added by RXNETHI-ARGANO,04/05/23
                              WHERE ppos1.person_id = pap.person_id)
       AND pap.person_id in ( SELECT pen.person_id
   --FROM ben.ben_prtt_enrt_rslt_f pen,      --code commented by RXNETHI-ARGANO,04/05/23
   FROM apps.ben_prtt_enrt_rslt_f pen,       --code added by RXNETHI-ARGANO,04/05/23
           (SELECT *
           --FROM ben.ben_pl_f      --code commented by RXNETHI-ARGANO,04/05/23
           FROM apps.ben_pl_f       --code added by RXNETHI-ARGANO,04/05/23
--           WHERE TRUNC(SYSDATE) BETWEEN effective_start_date AND effective_end_date) BPL, /* 1.1 */
           WHERE TRUNC(TO_DATE(g_as_of_date)) BETWEEN effective_start_date AND effective_end_date) BPL, /* 1.1 */
           (SELECT *
           --FROM ben.ben_opt_f     --code commented by RXNETHI-ARGANO,04/05/23
           FROM apps.ben_opt_f      --code added by RXNETHI-ARGANO,04/05/23
           --WHERE TRUNC(SYSDATE) BETWEEN effective_start_date AND effective_end_date) opt, /* 1.1 */
           WHERE TRUNC(TO_DATE(g_as_of_date)) BETWEEN effective_start_date AND effective_end_date) opt, /* 1.1 */
           --ben.BEN_OIPL_F opl,      --code commented by RXNETHI-ARGANO,04/05/23
           apps.BEN_OIPL_F opl,       --code added by RXNETHI-ARGANO,04/05/23
           BEN_ACTY_BASE_RT_V  babrv
    WHERE  pen.pl_id in (g_ltd_plan_id,g_vol_ltd_ft_plan_id,g_vol_ltd_pt_plan_id,g_std_plan1_id,g_std_plan2_id)
           AND opl.opt_id = opt.opt_id(+)
           AND pen.oipl_id = opl.oipl_id(+)
           AND pen.pl_id = bpl.pl_id
           and babrv.business_group_id = g_business_group_id
       and babrv.CONTEXT_PL_ID = bpl.pl_id
       and babrv.ACTY_BASE_RT_STAT_CD = 'A'
       --AND  NVL (ppos.actual_termination_date , TRUNC(SYSDATE)) between pen.enrt_cvg_strt_dt and pen.enrt_cvg_thru_dt /* 1.1 */
       AND  NVL (ppos.actual_termination_date , TRUNC(TO_DATE(g_as_of_date))) between pen.enrt_cvg_strt_dt and pen.enrt_cvg_thru_dt /* 1.1 */
       AND  NVL (ppos.actual_termination_date , TRUNC(TO_DATE(g_as_of_date))) between pen.effective_start_date and pen.effective_end_date /* 1.3   (added for plan changes*/
       --AND pen.enrt_cvg_thru_dt <=  pen.effective_end_date/*   (added for plan changes 1.3*/
       AND  pen.prtt_enrt_rslt_stat_cd IS NULL
           --AND rownum <= 20
           --and pen.person_id in (1136554,91777,1138210,39085,1064278,1051300)
       )
       --and TRUNC(SYSDATE) - NVL (ppos.actual_termination_date , TRUNC(SYSDATE)) <= g_termed_since_no_days -- To pick up term employee who term number of days prior /* 1.1 */
       and TRUNC(TO_DATE(g_as_of_date)) - NVL (ppos.actual_termination_date , TRUNC(TO_DATE(g_as_of_date))) <= g_termed_since_no_days -- To pick up term employee who term number of days prior /* 1.1 */
        --      AND pap.EMPLOYEE_NUMBER in ('3375742','3382389','3382393' )
       ;

/*
SELECT DECODE(pen.pl_id,258,'ST',625,'ST')
       ||TO_CHAR(pen.orgnl_enrt_dt,'MMDDYYYY')
       ||'        '
       ||'        '
       ||'       '
       ||'    '
       ||'    '
       ||LPAD(ROUND(pen.bnft_amt),8,0)||DECODE(pen.pl_id,258,'Y',625,'N')||'   '||'   '
	   ||DECODE(pen.pl_id,272,'LT')||TO_CHAR(pen.orgnl_enrt_dt,'MMDDYYYY')||TO_CHAR(pen.enrt_cvg_thru_dt,'MMDDYYYY')||'       '||'    '||'    '||'        '||' '||'   '||'   '
         --   ||DECODE(pen.pl_id,272,'LT')||TO_CHAR(pen.orgnl_enrt_dt,'MMDDYYYY')||TO_CHAR(pen.enrt_cvg_thru_dt,'MMDDYYYY')||'       '||'    '||'    '||'  '||'        '||DECODE(pen.pl_id,272,'Y')||'   '||'   '||'                    '||'                                           '  A
*/
    cursor c_std_plan_cur(p_person_id number,p_process_date date)  is
    SELECT --bpl.name,
           pen.pl_id,
           --pen.bnft_amt,
           TRIM(to_char(ROUND(pen.bnft_amt),'00000000')) bnft_amt,
           --pen.ORGNL_ENRT_DT,
           to_char(pen.ORGNL_ENRT_DT,'MMDDYYYY') ORGNL_ENRT_DT,
           --pen.enrt_cvg_thru_dt,
           REPLACE(to_char(pen.enrt_cvg_thru_dt,'MMDDYYYY'),'12314712','        ') enrt_cvg_thru_dt,
    decode(babrv.tx_typ_cd,'PRETAX','Y','N') pre_tx_ind
      ,   decode(substr(babrv.acty_typ_cd,1,2),'ER','100','000') er_pln_pct
      ,   decode(substr(babrv.acty_typ_cd,1,2),'EE','100','000') ee_pre_tx_pct
    --FROM ben.ben_prtt_enrt_rslt_f pen,    --code commented by RXNETHI-ARGANO,04/05/23
    FROM apps.ben_prtt_enrt_rslt_f pen,     --code added by RXNETHI-ARGANO,04/05/23
           (SELECT *
           --FROM ben.ben_pl_f              --code commented by RXNETHI-ARGANO,04/05/23
           FROM apps.ben_pl_f               --code added by RXNETHI-ARGANO,04/05/23
           --WHERE TRUNC(SYSDATE) BETWEEN effective_start_date AND effective_end_date) BPL, /* 1.1 */
           WHERE TRUNC(TO_DATE(g_as_of_date)) BETWEEN effective_start_date AND effective_end_date) BPL, /* 1.1 */
           (SELECT *
           --FROM ben.ben_opt_f       --code commented by RXNETHI-ARGANO,04/05/23
           FROM apps.ben_opt_f        --code added by RXNETHI-ARGANO,04/05/23
           --WHERE TRUNC(SYSDATE) BETWEEN effective_start_date AND effective_end_date) opt, /* 1.1 */
           WHERE TRUNC(TO_DATE(g_as_of_date)) BETWEEN effective_start_date AND effective_end_date) opt, /* 1.1 */
           --ben.BEN_OIPL_F opl,       --code commented by RXNETHI-ARGANO,04/05/23
           apps.BEN_OIPL_F opl,        --code added by RXNETHI-ARGANO,04/05/23
           BEN_ACTY_BASE_RT_V  babrv
    WHERE  pen.pl_id in (g_std_plan1_id,g_std_plan2_id)
           AND opl.opt_id = opt.opt_id(+)
           AND pen.oipl_id = opl.oipl_id(+)
           AND pen.pl_id = bpl.pl_id
           AND babrv.business_group_id = 325
           and babrv.CONTEXT_PL_ID = bpl.pl_id
           and babrv.ACTY_BASE_RT_STAT_CD = 'A'
           --AND  NVL (p_process_date , TRUNC(SYSDATE)) between pen.enrt_cvg_strt_dt and pen.enrt_cvg_thru_dt /* 1.1 */
           AND  NVL (p_process_date , TRUNC(TO_DATE(g_as_of_date))) between pen.enrt_cvg_strt_dt and pen.enrt_cvg_thru_dt /* 1.1 */
           AND  TRUNC(TO_DATE(g_as_of_date)) BETWEEN pen.effective_start_date AND pen.effective_end_date /* 1.2 */
           AND  pen.SSPNDD_FLAG <> 'Y' /* 1.2 */
           --AND pen.enrt_cvg_thru_dt <=  pen.effective_end_date /*Changs for plan name changes --1.3*/
           AND  pen.prtt_enrt_rslt_stat_cd IS NULL
           AND pen.person_id = p_person_id;

    cursor c_ltd_plan_cur(p_person_id number,p_process_date date)  is
    SELECT --bpl.name,
           pen.pl_id,
           TRIM(to_char(ROUND(pen.bnft_amt),'00000000')) bnft_amt,
           to_char(pen.ORGNL_ENRT_DT,'MMDDYYYY'),
           REPLACE(to_char(pen.enrt_cvg_thru_dt,'MMDDYYYY'),'12314712','        '),
          decode(babrv.tx_typ_cd,'PRETAX','Y','N') pre_tx_ind
      ,   decode(substr(babrv.acty_typ_cd,1,2),'ER','100','000') er_pln_pct
      ,   decode(substr(babrv.acty_typ_cd,1,2),'EE','100','000') ee_pre_tx_pct
    --FROM ben.ben_prtt_enrt_rslt_f pen,     --code commented by RXNETHI-ARGANO,04/05/23
    FROM apps.ben_prtt_enrt_rslt_f pen,      --code added by RXNETHI-ARGANO,04/05/23
           (SELECT *
           --FROM ben.ben_pl_f    --code commented by RXNETHI-ARGANO,04/05/23
           FROM apps.ben_pl_f     --code added by RXNETHI-ARGANO,04/05/23
           --WHERE TRUNC(SYSDATE) BETWEEN effective_start_date AND effective_end_date) BPL,  /* 1.1 */
           WHERE  TRUNC(TO_DATE(g_as_of_date)) BETWEEN effective_start_date AND effective_end_date) BPL,  /* 1.1 */
           (SELECT *
           --FROM ben.ben_opt_f    --code commented by RXNETHI-ARGANO,04/05/23
           FROM apps.ben_opt_f     --code added by RXNETHI-ARGANO,04/05/23
           --WHERE TRUNC(SYSDATE) BETWEEN effective_start_date AND effective_end_date) opt,  /* 1.1 */
           WHERE  TRUNC(TO_DATE(g_as_of_date)) BETWEEN effective_start_date AND effective_end_date) opt,  /* 1.1 */
           --ben.BEN_OIPL_F opl,    --code commented by RXNETHI-ARGANO,04/05/23
           apps.BEN_OIPL_F opl,     --code added by RXNETHI-ARGANO,04/05/23
           BEN_ACTY_BASE_RT_V  babrv
    WHERE  pen.pl_id in (g_ltd_plan_id,g_vol_ltd_ft_plan_id,g_vol_ltd_pt_plan_id) /* 1.1 */
           AND opl.opt_id = opt.opt_id(+)
           AND pen.oipl_id = opl.oipl_id(+)
           AND pen.pl_id = bpl.pl_id
           AND babrv.business_group_id = 325
           and babrv.CONTEXT_PL_ID = bpl.pl_id
           and babrv.ACTY_BASE_RT_STAT_CD = 'A'
           --AND NVL (p_process_date , TRUNC(SYSDATE))  between pen.enrt_cvg_strt_dt and pen.enrt_cvg_thru_dt /* 1.1 */
           AND NVL (p_process_date , TRUNC(TO_DATE(g_as_of_date)))  between pen.enrt_cvg_strt_dt and pen.enrt_cvg_thru_dt /* 1.1 */
           AND  TRUNC(TO_DATE(g_as_of_date)) BETWEEN pen.effective_start_date AND pen.effective_end_date /* 1.2 */
           AND  pen.SSPNDD_FLAG <> 'Y' /* 1.2 */
           --AND pen.enrt_cvg_thru_dt <=  pen.effective_end_date/*Changs for plan name changes --1.3*/
           AND pen.prtt_enrt_rslt_stat_cd IS NULL
           AND pen.person_id = p_person_id;

PROCEDURE main(
          errcode                     OUT VARCHAR2,
          errbuff                     OUT VARCHAR2,
          p_as_of_date                IN varchar2,
          p_business_group_id         IN NUMBER,
          p_client_number             IN VARCHAR2,
          p_ltd_plan_id               IN NUMBER,
          p_vol_ltd_ft_plan_id        IN NUMBER,
          p_vol_ltd_pt_plan_id        IN NUMBER,
          p_std_plan1_id              IN NUMBER,
          p_std_plan2_id              IN NUMBER,
--          p_ltd_group_no              IN VARCHAR2,
--          p_std_group1_no             IN VARCHAR2,
--          p_std_group2_no             IN VARCHAR2,
          p_sub_div_code              IN VARCHAR2,
          p_branch_code1              IN VARCHAR2,
          p_branch_code2              IN VARCHAR2,
          p_branch_code3              IN VARCHAR2,
          p_branch_code5              IN VARCHAR2,
          p_branch_code6              IN VARCHAR2,
          p_branch_code9              IN VARCHAR2,
          p_termed_since_no_days  IN number
);
END TTEC_METLIFE_DISABILITY_INT;
/
show errors;
/