create or replace PACKAGE BODY XXTELETECH_FSA_MASS_PLAN_EXT
 /********************************************************************************
  PROGRAM NAME:   XXTELETECH_FSA_MASS_PLAN_EXT
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
  IXPRAVEEN(ARGANO)            1.0     11-May-2023     R12.2 Upgrade Remediation
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
SELECT
       pap.employee_number employee_number,
       pap.full_name full_name,
       bpl.name VIN_PLAN,
       DECODE(pen.pl_id,331,(SELECT rt_val FROM BEN_PRTT_RT_VAL
                             WHERE prtt_enrt_rslt_id = pen.prtt_enrt_rslt_id
                             AND TRUNC(p_date) BETWEEN RT_STRT_DT AND RT_END_DT),pen.bnft_amt) cvg_amt,
       pen.enrt_cvg_strt_dt start_date
--START R12.2 Upgrade Remediation
/*FROM   hr.per_all_people_f pap,					-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
       ben.BEN_PRTT_ENRT_RSLT_F pen,*/
FROM   apps.per_all_people_f pap,					 --  code Added by IXPRAVEEN-ARGANO,   11-May-2023
       apps.BEN_PRTT_ENRT_RSLT_F pen,
--END R12.2.11 Upgrade remediation
       (SELECT *
       --FROM ben.ben_pl_f					-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
       FROM apps.ben_pl_f                   --  code Added by IXPRAVEEN-ARGANO,   11-May-2023
       WHERE trunc(p_date) BETWEEN effective_start_date AND effective_END_date
       AND pl_id IN (331,245,248)) BPL
       WHERE pen.pl_id = bpl.pl_id
       AND pen.person_id = pap.person_id
       AND trunc(p_date) BETWEEN pen.enrt_cvg_strt_dt AND pen.enrt_cvg_thru_dt
       AND trunc(p_date) BETWEEN pen.effective_start_date AND pen.effective_END_date
       AND  pen.prtt_enrt_rslt_stat_cd IS NULL
       AND trunc(p_date) BETWEEN pap.effective_start_date AND pap.effective_END_date
       AND hr_person_type_usage_info.get_user_person_type ( trunc(pap.effective_start_date), pap.person_id ) = 'PEO Employee'
       AND pap.current_employee_flag = 'Y'
       AND pap.business_group_id = 325
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

fnd_file.put_line(fnd_file.output,'----------------------------------------------------------------------------Teletech PEO Employee FSA and Mass Transit Plans Extract: '||v_date||'----------------------------------------------------------------------------');

   fnd_file.put_line(fnd_file.output,'                                                                 ');
   fnd_file.put_line(fnd_file.output,'Employee Number'||'	'||'Employee Name'||'	'||'Plan Type'||'	'||'Amount'||'	'||'Start Date');
  FOR cur_emp_det IN emp_det(v_date)

  LOOP


v_columns_str := cur_emp_det.employee_number||'	'||cur_emp_det.full_name||'	'||cur_emp_det.vin_plan||'	'||TO_CHAR(cur_emp_det.cvg_amt,'999999999.99')||'	'||TO_CHAR(cur_emp_det.start_date,'MM/DD/YYYY');

fnd_file.put_line(fnd_file.output,v_columns_str);


  END LOOP;



fnd_file.put_line(fnd_file.log, 'DROPPING TABLE');

BEGIN

EXECUTE IMMEDIATE ('DROP TABLE XXTELETECH_FSA_MASS_PLAN_TAB');

EXCEPTION
WHEN OTHERS THEN
FND_FILE.PUT_LINE(FND_FILE.LOG,'TABLE DOES NOT EXIST, HENCE CREATING');

END;

V_STRING:= 'CREATE TABLE XXTELETECH_FSA_MASS_PLAN_TAB AS
       SELECT
       pap.employee_number employee_number,
       pap.full_name full_name,
       bpl.name VIN_PLAN,
       DECODE(pen.pl_id,331,(SELECT rt_val FROM BEN_PRTT_RT_VAL
                             WHERE prtt_enrt_rslt_id = pen.prtt_enrt_rslt_id
                             AND '||SQ||v_date||SQ||' BETWEEN RT_STRT_DT AND RT_END_DT),pen.bnft_amt) cvg_amt,
       pen.enrt_cvg_strt_dt start_date
--START R12.2 Upgrade Remediation
/*FROM   hr.per_all_people_f pap,					-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
       ben.BEN_PRTT_ENRT_RSLT_F pen,*/
FROM   apps.per_all_people_f pap,					 --  code Added by IXPRAVEEN-ARGANO,   11-May-2023
       apps.BEN_PRTT_ENRT_RSLT_F pen,
--END R12.2.11 Upgrade remediation
       (SELECT *
        --FROM ben.ben_pl_f					-- Commented code by IXPRAVEEN-ARGANO,11-May-2023
       FROM apps.ben_pl_f                   --  code Added by IXPRAVEEN-ARGANO,   11-May-2023
       WHERE '||SQ||v_date||SQ||' BETWEEN effective_start_date AND effective_END_date
       AND pl_id IN (331,245,248)) BPL
       WHERE pen.pl_id = bpl.pl_id
       AND pen.person_id = pap.person_id
       AND '||SQ||v_date||SQ||' BETWEEN pen.enrt_cvg_strt_dt AND pen.enrt_cvg_thru_dt
       AND '||SQ||v_date||SQ||' BETWEEN pen.effective_start_date AND pen.effective_END_date
       AND  pen.prtt_enrt_rslt_stat_cd IS NULL
       AND '||SQ||v_date||SQ||' BETWEEN pap.effective_start_date AND pap.effective_END_date
       AND hr_person_type_usage_info.get_user_person_type ( trunc(pap.effective_start_date), pap.person_id ) = '||SQ||'PEO Employee'||SQ||
     '  AND pap.current_employee_flag = '||SQ||'Y'||SQ||
    '   AND pap.business_group_id = 325';




EXECUTE IMMEDIATE(V_STRING);

fnd_file.put_line(fnd_file.log,'TABLE CREATION COMPLETED');

fnd_file.put_line(fnd_file.log,'PROGRAM SUCCESSFULLY COMPLETED');

EXCEPTION
WHEN OTHERS THEN
fnd_file.put_line(fnd_file.log,'Program completed with error '||sqlerrm);
raise;
END MAIN;

-- ############################### END MAIN ########################################## --


END XXTELETECH_FSA_MASS_PLAN_EXT;
/
show errors;
/