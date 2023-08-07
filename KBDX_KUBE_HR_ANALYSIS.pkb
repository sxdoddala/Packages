create or replace PACKAGE BODY KBDX_KUBE_HR_ANALYSIS
 IS
/*
 * $History: kbdx_kube_hr_analysis.pkb $
 *
 * *****************  Version 82  *****************
 * User: Jkeller      Date: 11/09/11   Time: 7:56a
 * Updated in $/KBX Kube Main/Year End 4.0(No Resident Addr in W2)/Year End With Address
 * 2011 box12dd, box12ee,w2 roth 457b sets retirment_plan='Y'
 *
 *   78  Uaudi        4/19/11    c_get_sdi_limits for RI SDI Box 18, Box 19
 *   75  Uaudi        3/10/11    Date Range parameter
 *   71  Uaudi        1/04/11    Third Party Sick in KB_W2_RAW
 *   69  Jkeller     11/18/10    Box12CC Shiva
 *   66  Uaudi        4/22/09    Removed the nvl condition for state_wages in KB_W2_RAW
 *1.0	IXPRAVEEN(ARGANO)  12-May-2023		R12.2 Upgrade Remediation
 * See SourceSafe for addition comments
*/
l_path                VARCHAR2(80) := NULL;
l_count               NUMBER;
l_date_to             DATE;
l_flag                VARCHAR2(10) := 'Y';
l_tmp                 NUMBER;
l_last_people_end     DATE;
l_last_date_to        DATE;

FUNCTION Get_State_Name (P_state_code IN VARCHAR2) RETURN VARCHAR2;
--
FUNCTION Get_County_Name (P_State_Code IN VARCHAR2,
                          p_County_Code IN VARCHAR2) RETURN VARCHAR2;
--
FUNCTION Get_City_Name (P_State_Code IN VARCHAR2,
                        P_County_Code IN VARCHAR2,
                        P_City_Code IN VARCHAR2) RETURN VARCHAR2;
--
FUNCTION Get_School_Name (P_State_Code IN VARCHAR2,
                          P_School_Dst_Code IN VARCHAR2) RETURN VARCHAR2;
-- Called by KUBE 4.0.x
TYPE ranal_rec IS RECORD (person_id NUMBER, assignment_id NUMBER, payroll_id NUMBER, segment1 NUMBER,
                          user_person_type per_person_types.user_person_type%TYPE, business_group_id NUMBER,
                          actual_termination_date DATE, effective_end_date DATE, headcount NUMBER, organization_id NUMBER);

TYPE g_anal_tabtype IS TABLE OF ranal_rec INDEX BY BINARY_INTEGER;
g_anal_tab        g_anal_tabtype;

TYPE rpaid_rec IS RECORD (time_period_id NUMBER,payroll_id NUMBER, business_group_id NUMBER,tax_unit_id NUMBER,
                          organization_id NUMBER,headcount NUMBER);

TYPE raddr_rec IS RECORD (person_id NUMBER,assignment_id NUMBER, payroll_id NUMBER, segment1 NUMBER,
                          user_person_type per_person_types.user_person_type%TYPE,business_group_id NUMBER,
                          address_line1 per_addresses.address_line1%TYPE, address_line2 per_addresses.address_line2%TYPE,
                          address_line3 per_addresses.address_line3%TYPE, town_or_city per_addresses.town_or_city%TYPE,
                          region_1 per_addresses.region_1%TYPE, region_2 per_addresses.region_2%TYPE,
                          postal_code per_addresses.postal_code%TYPE, date_from DATE, date_to DATE, effective_end_date DATE,
                          organization_id NUMBER);

TYPE g_addr_tabtype IS TABLE OF raddr_rec INDEX BY BINARY_INTEGER;
g_addr_tab      g_addr_tabtype;

PROCEDURE write_addr_details(p_kube_type_id NUMBER,p_end_date DATE, p_gre_id NUMBER DEFAULT NULL, p_person_id NUMBER,Reason VARCHAR2, p_address_id NUMBER);
--
PROCEDURE kbdx_ye_delete_proc IS
BEGIN
  --DELETE FROM  kbace.kbdx_balance_lookups;		-- Commented code by IXPRAVEEN-ARGANO,12-May-2023	
  DELETE FROM  apps.kbdx_balance_lookups;          --  code Added by IXPRAVEEN-ARGANO,   12-May-2023
  --DELETE FROM  kbace.kbdx_ye_full_details;		-- Commented code by IXPRAVEEN-ARGANO,12-May-2023
  DELETE FROM  apps.kbdx_ye_full_details;          --  code Added by IXPRAVEEN-ARGANO,   12-May-2023
	 DELETE FROM  kbdx_ye_fit_details;
	 DELETE FROM  kbdx_ye_lit_details;
	 DELETE FROM  kbdx_ye_sit_details;

END kbdx_ye_delete_proc;

PROCEDURE store_months_asg_data(p_year IN NUMBER) IS
BEGIN

  INSERT INTO kbdx_tmp_months
  SELECT '12-Jan-'||p_year  FROM dual
  UNION
  SELECT '12-Feb-'||p_year  FROM dual
  UNION
  SELECT '12-Mar-'||p_year  FROM dual
  UNION
  SELECT '12-Apr-'||p_year  FROM dual
  UNION
  SELECT '12-May-'||p_year  FROM dual
  UNION
  SELECT '12-Jun-'||p_year  FROM dual
  UNION
  SELECT '12-Jul-'||p_year  FROM dual
  UNION
  SELECT '12-Aug-'||p_year  FROM dual
  UNION
  SELECT '12-Sep-'||p_year  FROM dual
  UNION
  SELECT '12-Oct-'||p_year  FROM dual
  UNION
  SELECT '12-Nov-'||p_year  FROM dual
  UNION
  SELECT '12-Dec-'||p_year  FROM dual;
END store_months_asg_data;

PROCEDURE main(p_process_id IN NUMBER) IS
--
g_person_id_link    NUMBER;
g_id_link           NUMBER;
l_gre_id            NUMBER;
l_from              VARCHAR2(32767);
l_where             VARCHAR2(32767);
l_parameter_id      NUMBER;
l_kube_type_id      NUMBER;
l_year              VARCHAR2(4);
lc_start_date       VARCHAR2(50);
lc_end_date         VARCHAR2(50);
l_start_date        DATE;
l_end_date          DATE;
l_kube_desc         kbdx_kube_types.kube_description%TYPE;
c_ssn               RefCurTyp;
c_dec               RefCurTyp;
c_paid              RefCurTyp;
c_addr              RefCurTyp;
cx_addr             RefCurTyp;
anal_rec            ranal_rec;
addr_rec            raddr_rec;
naddr_rec           raddr_rec;
paid_rec            rpaid_rec;
l_sql_string        VARCHAR2(32767);
l_string            VARCHAR2(32767);
l_count             NUMBER := 0;
l_old_pid           NUMBER := 0;
l_link_id           NUMBER := 0;
l_tmp_counter       NUMBER := 0;
x                   NUMBER;
l_parm_id           NUMBER;
l_date              VARCHAR(20);
l_paid_date         DATE;
l_month             VARCHAR2(50);
l_proc              VARCHAR2(50):= 'kbdx_kube_hr_analysis';
l_to_date           DATE;
l_yn                VARCHAR2(1) := 'Y';
l_code              NUMBER;
l_fname             per_people_f.first_name%TYPE;
l_lname             per_people_f.last_name%TYPE;
l_ssn_no            per_people_f.national_identifier%TYPE;
l_state_code        VARCHAR2(2)    := NULL;
l_county_code       VARCHAR2(3)    := NULL;
l_city_code         VARCHAR2(4)    := NULL;
l_school_dst_code   VARCHAR2(5)    := NULL;
l_state_name        VARCHAR2(2)    := NULL;
l_county_name       VARCHAR2(60)   := NULL;
l_city_name         VARCHAR2(60)   := NULL;
l_school_dst_name   VARCHAR2(60)   := NULL;
ln_parameter        NUMBER;
lv_option           VARCHAR2(60) := NULL;
--Added by Shiva on 12/02/04 to declare new variable starts
l_kb_flag           NUMBER;
-- end

--
--Type number_tabtype is table of number index by binary_integer;

-- Invalid Address Cursors
CURSOR c_address_change(c_eff_date DATE) IS
  SELECT /*+ RULE */
        a.person_id, a.address_id,
        COUNT(*) no_of_addresses
   FROM per_addresses a
  WHERE date_from <= c_eff_date
    AND primary_flag = 'Y'
  GROUP BY a.person_id, a.address_id
  HAVING COUNT(*) > 1;
--
CURSOR c_all_addr(c_eff_date DATE,p_person_id IN NUMBER) IS
 SELECT /*+ RULE */
       a.person_id, a.address_id,
       p.effective_start_date people_start,
       p.effective_end_date people_end,
       date_from,
       NVL(date_to,TO_DATE('31-DEC-4712','DD-MON-YYYY')) date_to
  FROM per_addresses  a, per_people_f p
 WHERE a.person_id = p_person_id
   AND a.person_id = p.person_id
   AND p.current_employee_flag = 'Y'
   AND a.primary_flag = 'Y'
   AND a.date_from <= c_eff_date
   AND a.date_from BETWEEN p.effective_start_date  AND p.effective_end_date
   AND (a.date_from > p.effective_start_date
        OR (a.date_to < p.effective_end_date
         AND p.effective_end_date <> TO_DATE('31-DEC-4712','DD-MON-YYYY')))
 ORDER BY a.address_id;
--
-- Address des not exists
CURSOR c_addr_notexists(cp_end_date DATE, cp_gre_id VARCHAR2 DEFAULT NULL) IS
 SELECT /*+ RULE */ p.business_group_id,
        p.effective_start_date,
        p.effective_end_date,
        ppf.payroll_id,
        p.employee_number,
        p.full_name,
        p.person_id,
        paf.assignment_id,
        paf.organization_id,
        ppt.user_person_type,
        hsck.segment1,
        a.address_line1,
        a.address_line2,
        a.address_line3,
        a.town_or_city,
        a.region_1,
        a.region_2,
        a.postal_code,
        a.date_from,
        a.date_to
  FROM  per_people_f p,
        per_assignments_f paf,
        pay_payrolls_f ppf,
        per_person_types ppt,
        per_addresses a,
        hr_soft_coding_keyflex hsck
WHERE   NOT EXISTS (SELECT /*+ RULE */  addr_null.address_id
                    FROM per_addresses addr_null
                    WHERE addr_null.person_id = p.person_id
                    AND addr_null.primary_flag = 'Y'
                    )
  AND ppf.payroll_id (+)= paf.payroll_id
  AND cp_end_date BETWEEN ppf.effective_start_date AND ppf.effective_end_date
  AND cp_end_date BETWEEN paf.effective_start_date AND paf.effective_end_date
  AND p.person_id = paf.person_id
  AND p.person_id  = a.person_id
  AND cp_end_date BETWEEN a.date_from AND NVL(a.date_to,TO_DATE('31-DEC-4712','DD-MON-YYYY'))
  AND p.business_group_id = Fnd_Profile.value('PER_BUSINESS_GROUP_ID')
  AND p.current_employee_flag             = 'Y'
  AND paf.soft_coding_keyflex_id = hsck.soft_coding_keyflex_id
  AND hsck.segment1 = NVL(cp_gre_id,hsck.segment1)
  AND cp_end_date BETWEEN p.effective_start_date AND p.effective_end_date
  AND p.person_type_id = ppt.person_type_id(+)
  AND p.business_group_id = ppt.business_group_id
  AND ppt.user_person_type NOT IN ('Contact')
  AND ppt.system_person_type NOT IN ('OTHER');

--
CURSOR c_only_one_addr(cp_end_date DATE) IS
  SELECT /*+ RULE */
     a.person_id,
     COUNT(*) no_of_addresses
  FROM per_addresses a
  WHERE date_from <= cp_end_date
  AND primary_flag = 'Y'
  GROUP BY a.person_id
  HAVING COUNT(*) =  1;
--
CURSOR c_specific_addrid(p_person_id NUMBER, p_addr_id NUMBER, cp_end_date DATE) IS
   SELECT /*+ RULE */ adr.address_id,
         adr.object_version_number,
         adr.date_from,
         adr.date_to
    FROM per_addresses adr
   WHERE adr.person_id     = p_person_id
     AND adr.address_id    = p_addr_id
     AND adr.primary_flag  = 'Y'
     AND adr.date_from     <= cp_end_date;
--
CURSOR c_addr_info(p_person_id NUMBER, cp_end_date DATE) IS
   SELECT /*+ RULE */ adr.address_id,
         adr.object_version_number,
         adr.date_from,
         NVL(adr.date_to,TO_DATE('31-DEC-4712','DD-MON-YYYY')) date_to
    FROM per_addresses adr
   WHERE adr.person_id     = p_person_id
     AND adr.primary_flag  = 'Y'
     AND adr.date_from     <= cp_end_date
     ORDER BY address_id;

-- Get Tax Unit Id for W2
CURSOR c_get_tuid (c_process_id IN NUMBER, c_parameter_id IN NUMBER) IS
  SELECT /*+ RULE */ source_id
  FROM kbdx_kube_parameter_data
  WHERE process_id = c_process_id
  AND parameter_id = c_parameter_id;
--
CURSOR c_w2 IS
  SELECT /*+ RULE */ *
  FROM kbdx_ye_full_details
  ORDER BY tax_unit_id, person_id, box1_wages,local_type;
--
CURSOR bcur_info(c_person_id IN NUMBER, c_end_date IN DATE) IS
  SELECT /*+ RULE */ first_name, last_name, national_identifier,
                     person_id, effective_start_date, effective_end_date

  FROM  per_people_f p
  WHERE p.person_id = c_person_id
  AND   p.national_identifier IS NOT NULL
  AND   c_end_date BETWEEN p.effective_start_date AND p.effective_end_date;
rcur_info   bcur_info%ROWTYPE;
--
-- Cursors for Paid Headcount
CURSOR c_month IS
  SELECT 'Jan' meaning ,1 FROM dual
  UNION
  SELECT 'Feb' meaning,2 FROM dual
  UNION
  SELECT 'Mar' meaning,3 FROM dual
  UNION
  SELECT 'Apr' meaning,4 FROM dual
  UNION
  SELECT 'May' meaning,5 FROM dual
  UNION
  SELECT 'Jun' meaning,6 FROM dual
  UNION
  SELECT 'Jul' meaning,7 FROM dual
  UNION
  SELECT 'Aug' meaning,8 FROM dual
  UNION
  SELECT 'Sep' meaning,9 FROM dual
  UNION
  SELECT 'Oct' meaning,10 FROM dual
  UNION
  SELECT 'Nov' meaning,11 FROM dual
  UNION
  SELECT 'Dec' meaning,12 FROM dual
  ORDER BY 2;
--
CURSOR bcur_paid_info IS
  SELECT /*+ RULE */ *
  FROM kbdx_ye_payroll_actions;
--
CURSOR bcur_get_count (p_start_date IN Date, p_end_date IN Date) IS --(p_year IN NUMBER)   IS
  SELECT /*+ */COUNT(DISTINCT B.PERSON_ID) headcount,
  B.TAX_UNIT_ID,  b.effective_date month_date, b.business_group_id, b.payroll_id
  FROM  PER_TIME_PERIODS PTP, XKB_BALANCES B
  WHERE B.PAYROLL_ID = PTP.PAYROLL_ID
  AND B.EFFECTIVE_DATE BETWEEN PTP.START_DATE AND PTP.END_DATE
  AND B.ACTION_TYPE IN ( 'R','Q')
  AND ptp.start_date <= p_end_date --TO_DATE('31-dec-'||p_year,'DD-MON-YYYY')
  AND ptp.END_DATE >= p_start_date --TO_DATE('01-jan-'||p_year,'DD-MON-YYYY')
  AND b.effective_date BETWEEN p_start_date and  p_end_date --TO_DATE('01-jan-'||p_year,'DD-MON-YYYY') AND TO_DATE('31-dec-'||p_year,'DD-MON-YYYY')
  AND EXISTS  (SELECT /*+ RULE  */1   FROM XKB_TAX_BALANCE_DETAILS T
               WHERE T.ASSIGNMENT_ACTION_ID = b.ASSIGNMENT_ACTION_ID  AND ROWNUM = 1 )
  GROUP BY B.TAX_UNIT_ID ,  b.business_group_id, b.payroll_id,PTP.START_DATE  , PTP.END_DATE,b.effective_date;

--
CURSOR c_get_all_gres(c_process_id NUMBER,c_parameter_id NUMBER) IS
SELECT /*+ RULE */ source_id
FROM kbdx_kube_parameter_data
WHERE parameter_id = c_parameter_id
AND process_id = c_process_id;
--
--04/18/2011
CURSOR c_get_sdi_limits (p_end_date in date) is
select /*+ RULE */ pus.state_code, pus.state_abbrev, nvl(pst.sui_er_wage_limit,0) sui_er_wage_limit,
       nvl(pst.sui_ee_wage_limit,0) sui_ee_wage_limit, nvl(pst.sdi_er_wage_limit,0) sdi_er_wage_limit,
       nvl(pst.sdi_ee_wage_limit,0) sdi_ee_wage_limit, to_number(nvl(pst.sta_information4,0)) sdi_er_rate
  from pay_us_state_tax_info_f pst, pay_us_states pus
 where p_end_date between pst.effective_start_date and pst.effective_end_date
   and pus.state_code = pst.state_code;

 BEGIN
    --
    SELECT parameter_id INTO l_parameter_id FROM kbdx_kube_parameters WHERE parameter_name = 'YearEnd_Options';
    lv_option := Kbdx_Kube_Utilities.get_parameter_attribute2 (p_process_id   => p_process_id,
                                                               p_parameter_id => l_parameter_id);
      --
      -- 03/09/11 Changed parameter to date range
/*    SELECT parameter_id INTO l_parameter_id FROM kbdx_kube_parameters WHERE parameter_name = 'YTD Years';
    l_year := Kbdx_Kube_Utilities.get_parameter_attribute2 (p_process_id   => p_process_id,
                                                            p_parameter_id => l_parameter_id);
    lc_start_date := '01-JAN-'||l_year;
    lc_end_date   := '31-DEC-'||l_year; */

 SELECT trunc(NVL(date_attr1, SYSDATE))
       ,trunc(NVL(date_attr2, SYSDATE))
   INTO l_start_date
       ,l_end_date
   FROM kbdx_kube_parameters a, kbdx_kube_parameter_data b
  WHERE a.parameter_id = b.parameter_id
    AND process_id = p_process_id
    AND parameter_name = 'DATE';

  lc_start_date := to_char(l_start_date, 'DD-MON-YYYY');
  lc_end_date := to_char(l_end_date, 'DD-MON-YYYY');

--  dbms_output.put_line ('lc_start_date: ' || lc_start_date);
--  dbms_output.put_line ('lc_end_date: ' || lc_end_date);

/* UAUDI 03/09/11 Do not need the below */
--    IF NVL(lc_start_date,'~') = '~' THEN
--      l_start_date := TRUNC(SYSDATE);
--    ELSE
--      l_start_date := Kbdx_Process_Pkg.convert_date(p_date => lc_start_date);
--    END IF;

--    IF NVL(lc_end_date,'~') = '~' THEN
--      l_end_date := TRUNC(SYSDATE);
--    ELSE
--      l_end_date := Kbdx_Process_Pkg.convert_date(p_date => lc_end_date);
--    END IF;

--    dbms_output.put_line ('l_start_date: ' || l_start_date);
--    dbms_output.put_line ('l_end_date: ' || l_end_date);
      --
      -- UAUDI 03/09/11 Added the below to populate the temp table kbdx_tmp_months
    l_year := to_char(l_end_date, 'YYYY');

--    dbms_output.put_line ('l_year: ' || l_year);


    IF lv_option IN ('--ALL--','US W2 Info') THEN
       SELECT /*+ RULE */ parameter_id INTO l_parm_id FROM kbdx_kube_parameters WHERE parameter_name = 'TAX_UNIT_ID';

        --For i in c_get_tuid(p_process_id, l_parm_id) Loop
       l_string := NULL;
        -- Call to this package will populate the table kbdx_ye_full_details(W2 Info)
        --commit;
        -- Commented above package commit by Siva on 12/02/04
   		  kbdx_ye_delete_proc;

       --03/09/2011 Changed the kube parameters to date range.
       --Kbdx_Kube_Year_End_Details.main(p_year => l_year, p_process_id => p_process_id, p_parameter_id => l_parm_id);
       Kbdx_Kube_Year_End_Details.main(p_start_date => l_start_date, p_end_date => l_end_date, p_process_id => p_process_id, p_parameter_id => l_parm_id);
    END IF;

    Kbdx_Kube_Utilities.Initialize_Kube_Files(p_process_id => p_process_id, p_process_type =>  'KBDX_HRANALYS_KUBE',
                                              p_aol_owner_id => Fnd_Profile.value('PER_BUSINESS_GROUP_ID'),
                                              p_kube_type_id => l_kube_type_id,p_kube_description => l_kube_desc,
                                              p_path => l_path);

    Kbdx_Kube_Utilities.get_sql_parameters(p_from_clause => l_from,
                                           p_where_clause => l_where,
                                           p_process_id => p_process_id,
                                           p_kube_type_id => l_kube_type_id);
  --
  -- 04/18/2011 Added to get the RI SDI wages and tax
  for i in c_get_sdi_limits (l_end_date) loop
    l_string := NULL;
    l_string := i.state_code||'|'||i.state_abbrev||'|'||i.sui_er_wage_limit||'|'||i.sui_ee_wage_limit||'|'||
                i.sdi_er_wage_limit||'|'||i.sdi_ee_wage_limit||'|'||i.sdi_er_rate;
    kbdx_file_utils.kbdx_write_mult_file(p_file_type => 'KB_PAY_US_STATE_TAX_INFO', p_buffer => l_string);
  end loop;
  --
  -- Start W2
  IF lv_option IN ('--ALL--','US W2 Info') THEN
    SELECT /*+ RULE */ parameter_id INTO l_parm_id FROM kbdx_kube_parameters WHERE parameter_name = 'TAX_UNIT_ID';

    -- For i in c_get_tuid(p_process_id, l_parm_id) Loop
          l_string := NULL;
          -- Call to this package will populate the table kbdx_ye_full_details(W2 Info)
          --     commit;
          -- Commented above package commit by Siva on 12/02/04
          --		 kbdx_ye_delete_proc;

          --  Kbdx_kube_year_end_details.main(p_year => l_year, p_process_id => p_process_id, p_parameter_id => l_parm_id);
          --
          FOR j IN c_w2 LOOP
              --
              Kbdx_Kube_Utilities.g_tax_unit_tab(NVL(j.tax_unit_id,-999)) := j.tax_unit_id;
              --Added Below two lines by Siva on 12/02/04 to avoid multiple row population from W2 Info. Starts
              -- 	      if i.source_id=j.tax_unit_id then l_kb_flag:=1;
              --	      end if;
              --End
              l_string := NULL; --04/18/2011
              OPEN  bcur_info(j.person_id, l_end_date);
              FETCH bcur_info INTO rcur_info;
              IF bcur_info%NOTFOUND THEN
                l_fname := NULL;
                l_lname := NULL;
                l_ssn_no := NULL;
              ELSE
                l_fname := rcur_info.first_name;
                l_lname := rcur_info.last_name;
                l_ssn_no := rcur_info.national_identifier;
              END IF;
              CLOSE bcur_info;
              l_state_name := NULL;
              l_county_name := NULL;
              l_city_name := NULL;
              l_school_dst_name := NULL;
              --l_state_code := substr(j.local_jd_code,1,2);
              --If l_state_code is NOT NULL Then
              l_state_name := get_state_name(p_state_code => j.state);
              --End If;
              l_county_code := SUBSTR(j.local_jd_code,4,3);
              IF l_county_code IS NOT NULL THEN
                l_county_name := get_county_name(j.state,l_county_code);
              END IF;
              l_city_code  := SUBSTR(j.local_jd_code,8,4);
              IF l_city_code IS NOT NULL THEN
                l_city_name := get_city_name(j.state,l_county_code,l_city_code);
              END IF;
              l_school_dst_code  := SUBSTR(j.local_jd_code,4,5);
              IF l_school_dst_code IS NOT NULL THEN
                l_school_dst_name := get_school_name(j.state,l_school_dst_code);
              ELSE l_school_dst_name := NULL;
              END IF;

              g_person_id_link := Kbdx_Kube_Utilities.get_person_link (p_person_id => rcur_info.person_id,
                                                              p_effective_date => rcur_info.effective_end_date,
                                                              p_kube_type_id => l_kube_type_id );

              IF l_count = 1 THEN
                l_old_pid := rcur_info.person_id;
                l_count := 0;
                l_link_id := 1;
              ELSIF ((l_count=0) AND (l_old_pid <> rcur_info.person_id)) THEN
                l_link_id := l_link_id + 1;
                l_old_pid := rcur_info.person_id;
              ELSIF ((l_count=0) AND (l_old_pid = rcur_info.person_id)) THEN
                l_link_id := l_link_id;
              END IF;

--              kbdx_kube_hr_analysis.g_w2_person_id(j.person_id) := j.person_id;
              Kbdx_Kube_Hr_Analysis.g_w2_person_id(NVL(rcur_info.person_id,-999)) := NVL(rcur_info.person_id,-999);

              	l_string := j.tax_unit_id||'|'||j.box1_wages||'|'||j.box2_fit_wh||'|'||j.box3_ss_wages
                    ||'|'||j.box4_ss_wh||'|'||j.box5_medicare_wages||'|'||j.box6_medicare_wh
                    ||'|'||j.box7_ss_tips||'|'||j.box8_alloc_tips
                    ||'|'||j.box9_eic||'|'||j.box10_dep_care||'|'||j.box11_nonqual_plans
                    ||'|'||j.box12a||'|'||j.box12b||'|'||j.box12c||'|'||j.box12d||'|'||j.box12e||'|'||j.box12f||'|'||j.box12g
                    ||'|'||j.box12h||'|'||j.box12j||'|'||j.box12k||'|'||j.box12l||'|'||j.box12m||'|'||j.box12n
                    ||'|'||j.box12p||'|'||j.box12r||'|'||j.box12s||'|'||j.box12t||'|'||j.box12v
                    ||'|'||j.state||'|'||j.state_wages||'|'||j.state_wh
                    ||'|'||j.local_wages||'|'||j.local_wh||'|'||j.local_type
                    ||'|'||j.box14a_name||'|'||j.box14a||'|'||j.box14b_name||'|'||j.box14b
                    ||'|'||j.box14c_name||'|'||j.box14c||'|'||j.box14d_name||'|'||j.box14d
                    ||'|'||j.box14e_name||'|'||j.box14e||'|'||j.box14f_name||'|'||j.box14f
                    ||'|'||j.box14g_name||'|'||j.box14g||'|'||j.box14h_name||'|'||j.box14h
                    ||'|'||j.box14i_name||'|'||j.box14i||'|'||j.box14j_name||'|'||j.box14j
                    ||'|'||j.box14z_name||'|'||j.box14z
                    ||'|'||j.stat_ee||'|'||j.retirement_plan
                    ||'|'||j.person_id||'|'||l_fname||'|'||l_lname||'|'||l_ssn_no
                    ||'|'||l_state_name||'|'||l_county_name||'|'||l_city_name||'|'||l_school_dst_name||'|'||l_link_id
                    ||'|'||j.sdi_ee||'|'||j.sui_ee||'|'||j.steic||'|'||j.box12q||'|'||j.box12w||'|'||j.box12y||'|'||j.box12z
                    ||'|'||j.box12aa||'|'||j.box12bb||'|'||j.sdi1_ee||'|'||j.box12cc||'|'||j.third_party_sick
                    ||'|'||j.box12dd||'|'||j.box12ee;
              	Kbdx_File_Utils.kbdx_write_mult_file(p_file_type => 'KB_W2_RAW', p_buffer => l_string);
--  W2 Info. End
                  --
          END LOOP;
          --
--    End Loop;
  END IF;
  -- End W2
  --
  -- Count persons who were paid in a period that included the 12th of each month
  IF lv_option IN ('--ALL--','US Paid Monthly Headcount') THEN
    l_string := NULL;
    store_months_asg_data(p_year => l_year);
    SELECT /*+ RULE */ parameter_id INTO l_parm_id FROM kbdx_kube_parameters WHERE parameter_name = 'TAX_UNIT_ID';
    kbdx_ye_delete_proc;
    FOR j IN bcur_get_count(l_start_date, l_end_date)  LOOP --(l_year)  LOOP
      Kbdx_Kube_Utilities.g_bg_tab(j.business_group_id) := j.business_group_id;
      IF j.payroll_id IS NOT NULL THEN
         Kbdx_Kube_Utilities.g_pay_tab(j.payroll_id) := j.payroll_id;
      END IF;
        --
      Kbdx_Kube_Utilities.g_tax_unit_tab(j.tax_unit_id) := j.tax_unit_id;
        --
      l_string := j.business_group_id||'|'||j.payroll_id||'|'||j.tax_unit_id||'|'||
                  TO_CHAR(j.month_date,'Month')||'|'||j.headcount||'|'||' '||'|'||l_code||'|';
      Kbdx_File_Utils.kbdx_write_mult_file( p_file_type => 'KB_PAID_HEADCOUNT_RAW', p_buffer => l_string);
    END LOOP; -- end of bcur_get_hc
      --
  END IF;
  -- End Paid Headcount

 -- Start Invalid SSN
 -- Only numerics, No Hyphens as prefixes or suffixes
 -- Maynot be '000000000','111111111', '333333333', '123456789'
 -- First three digits of a SSN may not be '000', '666'
  IF lv_option IN ('--ALL--','US Invalid SSNs') THEN
    l_sql_string := NULL;
    l_sql_string :=
 'SELECT /*+ RULE */ ppf.person_id, paf.assignment_id, paf.payroll_id, hsck.segment1,
                    ppt.user_person_type, ppf.business_group_id, NULL actual_termination_date,
                    ppf.effective_end_date, NULL headcount, paf.organization_id
  <<FROM>> per_people_f ppf,
           per_person_types ppt,
           per_assignments_f paf,
           hr_soft_coding_keyflex hsck
  <<WHERE>>
  AND   hsck.soft_coding_keyflex_id                 = paf.soft_coding_keyflex_id
  AND   paf.person_id                               = ppf.person_id
  AND   ppf.business_group_id+0                     = Fnd_Profile.value(''PER_BUSINESS_GROUP_ID'')
  AND   TO_DATE('''||lc_end_date||''',''DD-MON-YYYY'') BETWEEN ppf.effective_start_date
                                                        AND ppf.effective_end_date
  AND   TO_DATE('''||lc_end_date||''',''DD-MON-YYYY'') BETWEEN paf.effective_start_date
                                                        AND paf.effective_end_date
  AND   ppf.person_type_id                          = ppt.person_type_id(+)
  AND   ppf.business_group_id                       = ppt.business_group_id
  AND   ppt.user_person_type                        NOT IN (''Contact'')
  AND   ppt.system_person_type                      NOT IN (''OTHER'')
  AND   ppf.current_employee_flag                   = ''Y''
  AND   (LENGTH(NVL(ppf.national_identifier,''_'')) != 11
  OR    (ppf.national_identifier                    IN (''123-45-6789'',''000-00-0000'',''111-11-1111'',''333-33-3333'')
  OR    SUBSTR(ppf.national_identifier,1,3)           IN (''000'',''666'')
  OR    SUBSTR(ppf.national_identifier,5,2) = ''00''
  OR    SUBSTR(ppf.national_identifier,8,4) = ''0000''
  OR    (SUBSTR(REPLACE(ppf.national_identifier,''-'',''''),1,3)) BETWEEN ''773'' AND ''999''
  OR    INSTR(ppf.national_identifier,''-'',1,1)    != 4
  OR    INSTR(ppf.national_identifier,''-'',1,2)    != 7
  OR    SUBSTR(ppf.national_identifier,1,1)         = ''-''
  OR    SUBSTR(ppf.national_identifier,-1,1)        = ''-''))';
      --
    l_sql_string := REPLACE(l_sql_string,'<<WHERE>>',' where '||l_where);
    l_sql_string := REPLACE(l_sql_string,'<<FROM>>',' from '||l_from);
        --
    g_anal_tab.DELETE;
    OPEN c_ssn FOR l_sql_string;
    LOOP
    FETCH c_ssn INTO anal_rec;
    EXIT WHEN c_ssn%NOTFOUND;
      x:= 0;
      x:= x + 1;
      g_anal_tab(x).assignment_id := anal_rec.assignment_id;
      g_anal_tab(x).user_person_type := anal_rec.user_person_type;
      g_anal_tab(x).payroll_id := anal_rec.payroll_id;
      Hr_Utility.set_location(l_proc,1);
      g_person_id_link := Kbdx_Kube_Utilities.get_person_link (p_person_id => anal_rec.person_id,
                                                               p_effective_date => anal_rec.effective_end_date,
                                                               p_kube_type_id => l_kube_type_id );
        --
      Kbdx_Kube_Utilities.g_bg_tab(anal_rec.business_group_id) := anal_rec.business_group_id;
      IF anal_rec.payroll_id IS NOT NULL THEN
         Kbdx_Kube_Utilities.g_pay_tab(anal_rec.payroll_id) := anal_rec.payroll_id;
      END IF;
        --
      IF anal_rec.organization_id IS NOT NULL THEN
        Kbdx_Kube_Utilities.g_organiztion_tab(anal_rec.organization_id) := anal_rec.organization_id;
      END IF;
        --
      Kbdx_Kube_Utilities.g_tax_unit_tab(anal_rec.segment1) := anal_rec.segment1;
        --
      l_string := anal_rec.business_group_id||'|'||g_person_id_link||'|'||anal_rec.person_id||'|'||
                  anal_rec.assignment_id||'|'||anal_rec.payroll_id||'|'||anal_rec.segment1||'|'||
                  anal_rec.user_person_type||'|'||anal_rec.actual_termination_date||'|'||anal_rec.organization_id||'|';
       Kbdx_File_Utils.kbdx_write_mult_file( p_file_type => 'KB_INVALID_SSN_RAW', p_buffer => l_string);
    END LOOP;
    CLOSE c_ssn;
  END IF;
  -- End Invalid SSN

  -- Start Deceased People Info
  IF lv_option IN ('--ALL--','US Deceased People') THEN
    g_anal_tab.DELETE;
    l_sql_string := NULL;

  -- RR - Removed rule hint for performance issues
    l_sql_string :=  'select ppf.person_id,paf.assignment_id, paf.payroll_id, hsck.segment1,
                                         ppt.user_person_type,ppf.business_group_id,pps.actual_termination_date,
                                         ppf.effective_end_date, NULL headcount, paf.organization_id
                      <<FROM>>   per_person_types       ppt,
                                 per_assignments_f      paf,
                                 hr_soft_coding_keyflex hsck,
                                 hr_lookups             hl,
                                 per_people_f           ppf,
                                 per_periods_of_service pps
                      <<WHERE>>
                      AND    ppf.person_type_id            = ppt.person_type_id(+)
                      AND    ppt.user_person_type         <> (''Contact'')
                      AND    ppt.system_person_type       <> (''OTHER'')
                      AND    hsck.soft_coding_keyflex_id   = paf.soft_coding_keyflex_id
                      AND    UPPER(hl.meaning)             = UPPER(''DECEASED'')
                      AND    hl.lookup_type                = ''LEAV_REAS''
                      AND    pps.leaving_reason            = hl.lookup_code
                      AND    ppf.person_id                 = pps.person_id
                      AND    paf.period_of_service_id      = pps.period_of_service_id
                      AND    ppf.business_group_id+0       = Fnd_Profile.value(''PER_BUSINESS_GROUP_ID'')
                      AND    TO_DATE('''||lc_end_date||''',''DD-MON-YYYY'') BETWEEN ppf.effective_start_date
                                                                                AND ppf.effective_end_date
                      AND    pps.actual_termination_date BETWEEN paf.effective_start_date
                                                              AND paf.effective_end_date
					  AND    pps.actual_termination_date BETWEEN  TO_DATE('''||lc_start_date||''',''DD-MON-YYYY'') AND  TO_DATE('''||lc_end_date||''',''DD-MON-YYYY'')
                      AND    ppf.person_id = paf.person_id';

    l_sql_string := REPLACE(l_sql_string,'<<WHERE>>',' where '||l_where);
    l_sql_string := REPLACE(l_sql_string,'<<FROM>>',' from '||l_from);



    OPEN c_dec FOR l_sql_string;
    LOOP
    FETCH c_dec INTO anal_rec;
    EXIT WHEN c_dec%NOTFOUND;
      x:= 0;
      x:= x + 1;
      g_anal_tab(x).assignment_id := anal_rec.assignment_id;
      g_anal_tab(x).user_person_type := anal_rec.user_person_type;
      g_anal_tab(x).payroll_id := anal_rec.payroll_id;

      g_person_id_link := Kbdx_Kube_Utilities.get_person_link (p_person_id => anal_rec.person_id,
                                                               p_effective_date => anal_rec.effective_end_date,
                                                               p_kube_type_id => l_kube_type_id );

      Kbdx_Kube_Utilities.g_bg_tab(anal_rec.business_group_id) := anal_rec.business_group_id;
      IF anal_rec.payroll_id IS NOT NULL THEN
         Kbdx_Kube_Utilities.g_pay_tab(anal_rec.payroll_id) := anal_rec.payroll_id;
      END IF;

      IF anal_rec.organization_id IS NOT NULL THEN
         Kbdx_Kube_Utilities.g_organiztion_tab(anal_rec.organization_id) := anal_rec.organization_id;
      END IF;

      Kbdx_Kube_Utilities.g_tax_unit_tab(anal_rec.segment1) := anal_rec.segment1;

      l_string := anal_rec.business_group_id||'|'||g_person_id_link||'|'||anal_rec.person_id||'|'||
                  anal_rec.assignment_id||'|'||anal_rec.payroll_id||'|'||anal_rec.segment1||'|'||
                  anal_rec.user_person_type||'|'||anal_rec.actual_termination_date||'|'||anal_rec.organization_id||'|';
      kbdx_file_utils.kbdx_write_mult_file( p_file_type => 'KB_DECEASED_PEOPLE_RAW', p_buffer => l_string);
    END LOOP;
    CLOSE c_dec;
 END IF;
 -- End Deceased People Info

  -- Start Invalid Addresses
  -- Non-contiguous addresses, addresses with end dates before or after assignment effective date
  --JAK 11/09/2011 the invalid addresses code block was commented years ago. Now also removed from View and Template.
  l_sql_string := NULL;
  l_string := NULL;
--  If lv_option   in ('--ALL--','US Invalid Addresses') then   ---0 SKIPPING!!!a
IF 1 = 2 THEN
    g_addr_tab.DELETE;

    SELECT /*+ RULE */ parameter_id
    INTO l_parameter_id
    FROM kbdx_kube_parameters
    WHERE parameter_name = 'TAX_UNIT_ID';
    --
    --l_gre_id := kbdx_kube_utilities.get_specific_parameter (p_process_id,l_parameter_id);
   FOR i IN c_get_all_gres(p_process_id,l_parameter_id)  LOOP
    -- Address does not exist
    FOR j IN c_addr_notexists(l_end_date, NVL(i.source_id,NULL)) LOOP

        g_person_id_link := Kbdx_Kube_Utilities.get_person_link (p_person_id => j.person_id,
                                                                 p_effective_date => j.effective_end_date,
                                                                 p_kube_type_id => l_kube_type_id );

         Kbdx_Kube_Utilities.g_bg_tab(j.business_group_id) := j.business_group_id;

         IF j.payroll_id IS NOT NULL THEN
            Kbdx_Kube_Utilities.g_pay_tab(j.payroll_id) := j.payroll_id;
         END IF;

         IF j.segment1 IS NOT NULL THEN
               Kbdx_Kube_Utilities.g_organiztion_tab(j.organization_id) := j.organization_id;
         END IF;

        Kbdx_Kube_Utilities.g_tax_unit_tab(j.segment1) := j.segment1;

        l_string := j.person_id||'|'||j.assignment_id||'|'||j.payroll_id||'|'||
                    j.segment1||'|'||NULL||'|'||
                    j.business_group_id||'|'||j.address_line1||'|'||j.address_line2||'|'||
                    j.address_line3||'|'||j.town_or_city||'|'||j.region_1||'|'||j.region_2||'|'||
                    j.postal_code||'|'||TO_CHAR(j.effective_start_date,'MM/DD/YYYY')||'|'||TO_CHAR(j.effective_end_date,'MM/DD/YYYY')||'|'||
                    TO_CHAR(j.date_from,'MM/DD/YYYY')||'|'||TO_CHAR(j.date_to,'MM/DD/YYYY')||'|'||'Address not found'||'|'||
                    g_person_id_link||'|'||j.organization_id||'|'||'Address Does Not Exist';
        Kbdx_File_Utils.kbdx_write_mult_file( p_file_type => 'KB_INVALID_ADDR_RAW', p_buffer => l_string);

    END LOOP;
    --
    FOR j IN c_only_one_addr(l_end_date) LOOP
    -- check for gap before and after the address
     FOR k IN c_all_addr(l_end_date,j.person_id) LOOP
        --If (k.date_from > k.people_start) or (k.date_to < k.people_end) then
          write_addr_details(l_kube_type_id,l_end_date, NVL(i.source_id,NULL), j.person_id,'Gap Before or after the address(Single address)', k.address_id);

        --End If;
     END LOOP;
   END LOOP;
   --
   --  if more than one address
   FOR k IN c_address_change(l_end_date) LOOP
    IF k.no_of_addresses > 1 THEN
       l_date_to   := NULL;
       l_count := 0;
       FOR j IN c_all_addr(l_end_date,k.person_id) LOOP
           IF l_count = 0 THEN
               l_flag := 'Y';
               -- First Address: check for gap before the address
               IF (j.date_from > j.people_start)  THEN
                    l_count := 1;
                    write_addr_details(l_kube_type_id,l_end_date, NVL(i.source_id,NULL), k.person_id,'Gap before the address(Multiple Addresses)', k.address_id);
                END IF;
           END IF;
           IF (l_count = 1) THEN
              -- check for gap before and after the address
              IF  ((l_flag = 'N' AND j.date_from != l_date_to + 1) AND ( l_date_to + 1 NOT BETWEEN j.date_from AND j.date_to)) THEN
                 l_date_to := j.date_to;
                 l_flag      := 'N';
                 write_addr_details(l_kube_type_id,l_end_date, NVL(i.source_id,NULL), k.person_id, 'Gap before or after the address(Multiple addresses)', k.address_id);
              END IF;
           END IF;
           l_count := 1;
           l_flag := 'N';
           l_date_to := j.date_to;
           l_last_people_end := j.people_end;
       END LOOP;
       -- Last Address: check for gap after the address
       IF ((l_date_to < l_last_people_end)) THEN
           write_addr_details(l_kube_type_id,l_end_date, NVL(i.source_id,NULL), k.person_id,'Gap after the address(Multiple Addresses)', k.address_id);
       END IF;

       -- Check for overlapping of dates between addresses
        FOR j IN c_all_addr(l_end_date,k.person_id) LOOP
           FOR l IN c_specific_addrid(k.person_id, j.address_id,l_end_date) LOOP
             FOR m IN c_addr_info(k.person_id,l_end_date) LOOP

                 IF((m.date_from > l.date_from) AND (m.date_from BETWEEN l.date_from AND l.date_to)) THEN
                    --
                    write_addr_details(l_kube_type_id,l_end_date, NVL(i.source_id,NULL), k.person_id,'Overlapping of dates between addresses', k.address_id);
                    --
                END IF;
             END LOOP;
           END LOOP;
        END LOOP;
    END IF;
   END LOOP;
--
  END LOOP; -- Gre Loop
 --
 END IF;

  -- End Invalid Addresses

    --
    Kbdx_Kube_Utilities.finish(p_process_id => p_process_id,
                               p_process_type => 'KBDX_HRANALYS_KUBE',
                               p_path => l_path,
                               p_aol_owner_id => Fnd_Profile.value('PER_BUSINESS_GROUP_ID'),
                               p_kube_type_id => l_kube_type_id,
                               p_description =>l_kube_desc);
  --
END main;
  --
PROCEDURE write_addr_details(p_kube_type_id NUMBER,
                             p_end_date DATE,
                             p_gre_id NUMBER DEFAULT NULL,
                             p_person_id NUMBER,
                             Reason VARCHAR2,
                             p_address_id NUMBER) IS
   --
 CURSOR c_info(c_eff_date DATE, c_person_id NUMBER, c_gre_id NUMBER DEFAULT NULL) IS
 SELECT /*+ RULE */
       p.full_name, p.employee_number, hsck.segment1, a.person_id,
       p.effective_start_date people_start,
       p.effective_end_date people_end,
       date_from,
       NVL(date_to,TO_DATE('31-DEC-4712','DD-MON-YYYY')) date_to,
       a.address_line1,
       a.address_line2,
       a.address_line3,
       a.town_or_city,
       a.postal_code,
       a.region_1 county,
       a.region_2 state,
       paf.payroll_id,
       p.business_group_id,
       paf.organization_id,
       paf.assignment_id
  FROM per_addresses  a,
       per_people_f p,
       per_assignments_f paf,
       hr_soft_coding_keyflex hsck
 WHERE paf.soft_coding_keyflex_id = hsck.soft_coding_keyflex_id
 AND hsck.segment1 = NVL(c_gre_id,hsck.segment1)
 AND c_eff_date BETWEEN paf.effective_start_date AND paf.effective_end_date
 AND p.person_id = paf.person_id
 AND a.person_id = c_person_id
 AND a.person_id = p.person_id
 AND p.current_employee_flag = 'Y'
    -- and a.primary_flag = 'Y'
 AND c_eff_date BETWEEN p.effective_start_date AND p.effective_end_date
 AND a.address_id = p_address_id;
   --
 g_person_id_link NUMBER;
 l_string         VARCHAR2(32767);
BEGIN
  FOR j IN c_info(p_end_date, p_person_id, p_gre_id) LOOP
    g_person_id_link := Kbdx_Kube_Utilities.get_person_link (
                                    p_person_id      => j.person_id,
                                    p_effective_date => j.people_end,
                                    p_kube_type_id   => p_kube_type_id );
      --
    Kbdx_Kube_Utilities.g_bg_tab(j.business_group_id) := j.business_group_id;
      --
    IF j.payroll_id IS NOT NULL THEN
       Kbdx_Kube_Utilities.g_pay_tab(j.payroll_id) := j.payroll_id;
    END IF;
      --
    IF j.segment1 IS NOT NULL THEN
      Kbdx_Kube_Utilities.g_organiztion_tab(j.organization_id) := j.organization_id;
    END IF;
      --
    Kbdx_Kube_Utilities.g_tax_unit_tab(j.segment1) := j.segment1;
      --
    l_string :=
      j.person_id||'|'||j.assignment_id||'|'||j.payroll_id||'|'||
      j.segment1||'|'||NULL||'|'||
      j.business_group_id||'|'||j.address_line1||'|'||j.address_line2||'|'||
      j.address_line3||'|'||j.town_or_city||'|'||j.county||'|'||j.state||'|'||
      j.postal_code||'|'||TO_CHAR(j.people_start,'MM/DD/YYYY')||'|'||TO_CHAR(j.people_end,'MM/DD/YYYY')||'|'||
      TO_CHAR(j.date_from,'MM/DD/YYYY')||'|'||TO_CHAR(j.date_to,'MM/DD/YYYY')||'|'||Reason||'|'||
      g_person_id_link||'|'||j.organization_id;
    kbdx_file_utils.kbdx_write_mult_file( p_file_type => 'KB_INVALID_ADDR_RAW', p_buffer => l_string);
  END LOOP;
    --
END write_addr_details;
  --
FUNCTION Get_State_Name (P_state_code IN VARCHAR2) RETURN VARCHAR2 IS
 l_state_name VARCHAR2(60);
BEGIN
  SELECT /*+ RULE*/ state_abbrev INTO l_state_name FROM pay_us_states WHERE state_code = p_state_code;
  RETURN l_state_name;
 EXCEPTION
   WHEN OTHERS THEN
     RETURN ' ';
END Get_State_Name;
  --
FUNCTION Get_County_Name (P_State_Code IN VARCHAR2, P_County_Code IN VARCHAR2) RETURN VARCHAR2 IS
 l_county_name VARCHAR2(60);
BEGIN
  SELECT /*+ RULE*/ county_name INTO l_county_name FROM pay_us_counties WHERE state_code = p_state_code AND county_code = p_county_code;
  RETURN l_county_name;
 EXCEPTION
   WHEN OTHERS THEN
     RETURN ' ';
END Get_County_Name;
  --
FUNCTION Get_City_Name (P_State_Code IN VARCHAR2,
                        P_County_Code IN VARCHAR2,
                        P_City_Code IN VARCHAR2) RETURN VARCHAR2 IS
 l_city_name VARCHAR2(60);
BEGIN
  SELECT /*+ RULE*/ city_name
    INTO l_city_name
    FROM pay_us_city_names
   WHERE state_code = p_state_code
     AND county_code = p_county_code
     AND city_code = p_city_code
     AND primary_flag = 'Y';
  RETURN l_city_name;
 EXCEPTION
   WHEN OTHERS THEN
     RETURN ' ';
END Get_City_Name;
  --
FUNCTION Get_School_Name (P_State_Code IN VARCHAR2,P_School_Dst_Code IN VARCHAR2) RETURN VARCHAR2 IS
 l_school_dst_name   VARCHAR2(60);
BEGIN
  SELECT /*+ RULE*/ DISTINCT school_dst_name
  INTO l_school_dst_name
  FROM pay_us_school_dsts
  WHERE state_code = p_state_code
  AND school_dst_code = p_school_dst_code;
  RETURN l_school_dst_name;
 EXCEPTION
   WHEN OTHERS THEN
     RETURN ' ';
END Get_School_Name;
  --
END Kbdx_Kube_Hr_Analysis;
/
show errors;
/