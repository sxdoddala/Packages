create or replace PACKAGE BODY XXTTEC_FSA_MASS_PLAN_CHNG_2016
/********************************************************************************
  PROGRAM NAME:   XXTTEC_FSA_MASS_PLAN_CHNG_2016
  DESCRIPTION:    This package extracts any changes to FSA and Mass Transit Plans for
                  PEO Employees during every pay cycle.
                  It should be scheduled to run on Cut-off date of a payroll period.
  INPUT      :    None
  OUTPUT     :
  CREATED BY:     Jeeva A
  DATE:           17-NOV-2015
  CALLING FROM   :  Teletech PEO Employee FSA and Mass Transit Changes Program 2016
  ----------------
  MODIFICATION LOG
  ----------------
  DEVELOPER             DATE          DESCRIPTION
  -------------------   ------------  -----------------------------------------
  1.0 Jeeva A    17-Nov-2015   Initial Version
  1.1 Lalitha.N   12-JAN-2016   hr_person_type_usage_info- Changed date parameter
  1.0	IXPRAVEEN(ARGANO)  09-May-2023		R12.2 Upgrade Remediation
  ********************************************************************************/

 AS

  PROCEDURE MAIN(x_errcode   OUT NUMBER,
                 x_errbuff   OUT VARCHAR2,
                 p_prgm_date IN VARCHAR2) IS

    --#################################### VARIABLE DECLARATION ################################ --

    v_dt_time       VARCHAR2(100);
    v_path          VARCHAR2(400);
    v_date          DATE;
    v_date_jan_2014 DATE;
    v_days          NUMBER;
    v_columns_str   VARCHAR2(4000);
    v_header        VARCHAR2(4000);
    v_string        VARCHAR2(10000);
    SQ              VARCHAR2(10) := CHR(39);
    v_prgm_date     DATE;
    v_start_date    DATE;
    v_end_date      DATE;

    --################################### CURSOR DECLARATION #####################################--

    CURSOR emp_det(p_date DATE) IS
      SELECT -- Change Details Fetch
       pap.employee_number employee_number,
       pap.full_name full_name,
       bpl.name VIN_PLAN,
       DECODE(pen.pl_id,
              331,
              (SELECT rt_val
                 FROM BEN_PRTT_RT_VAL
                WHERE prtt_enrt_rslt_id = pen.prtt_enrt_rslt_id
                  AND TRUNC(p_date) BETWEEN RT_STRT_DT AND RT_END_DT),
              pen.bnft_amt) cvg_amt,
       pen.enrt_cvg_strt_dt start_date
	   --START R12.2 Upgrade Remediation			-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
        /*FROM hr.per_all_people_f pap,             
             ben.BEN_PRTT_ENRT_RSLT_F pen,*/
		FROM apps.per_all_people_f pap,				--  code Added by IXPRAVEEN-ARGANO,   09-May-2023
             apps.BEN_PRTT_ENRT_RSLT_F pen,	 
			 --END R12.2.10 Upgrade remediation
             (SELECT *
                --FROM BEN.BEN_PL_F			-- Commented code by IXPRAVEEN-ARGANO,09-May-2023
                FROM apps.BEN_PL_F           --  code Added by IXPRAVEEN-ARGANO,   09-May-2023
               WHERE trunc(p_date) BETWEEN effective_start_date AND
                     EFFECTIVE_END_DATE
                 AND pl_id IN (331, 245, 248, 12872, 332,12871)) BPL
       WHERE pen.pl_id = bpl.pl_id
         AND pen.person_id = pap.person_id
         AND trunc(p_date) BETWEEN pen.enrt_cvg_strt_dt AND
             pen.enrt_cvg_thru_dt
         AND trunc(p_date) BETWEEN pen.effective_start_date AND
             pen.effective_END_date
         AND pen.prtt_enrt_rslt_stat_cd IS NULL
         AND trunc(p_date) BETWEEN pap.effective_start_date AND
             pap.effective_END_date
         AND hr_person_type_usage_info.get_user_person_type(trunc(p_date),
                                                            pap.person_id) =
             'PEO Employee' --v1.1
         AND pap.current_employee_flag = 'Y'
         AND pap.business_group_id = 325
      MINUS
      SELECT * FROM XXTELETECH_FSA_MASS_PLAN_TAB;
    --AND pap.employee_number= '3148737'--'3153282';

    -- #########PLAN TERMINATION CURSOR ###################--

    CURSOR plan_term_det(p_date DATE, p_start_date DATE, p_end_date DATE) IS((
      SELECT --Terminated Plan Details Fetch
       pap.employee_number employee_number,
       pap.full_name full_name,
       bpl.name VIN_PLAN,
       DECODE(pen.pl_id,
              331,
              (SELECT MIN(rt_val)
                 FROM BEN_PRTT_RT_VAL
                WHERE prtt_enrt_rslt_id = pen.prtt_enrt_rslt_id
                  AND ((TRUNC(p_date) BETWEEN RT_STRT_DT AND RT_END_DT) OR
                      (TRUNC(RT_END_DT) BETWEEN p_start_date AND p_end_date))),
              pen.bnft_amt) cvg_amt,
       pen.enrt_cvg_strt_dt start_date
        --START R12.2 Upgrade Remediation
		/*FROM hr.per_all_people_f pap,					 -- Commented code by IXPRAVEEN-ARGANO,09-May-2023
             ben.BEN_PRTT_ENRT_RSLT_F pen,*/             
		FROM apps.per_all_people_f pap,					--  code Added by IXPRAVEEN-ARGANO,   09-May-2023
             apps.BEN_PRTT_ENRT_RSLT_F pen,	
--END R12.2.10 Upgrade remediation			 
             (SELECT *
                --FROM ben.ben_pl_f			 -- Commented code by IXPRAVEEN-ARGANO,09-May-2023
                FROM apps.ben_pl_f            --  code Added by IXPRAVEEN-ARGANO,   09-May-2023
               WHERE TRUNC(P_DATE) BETWEEN EFFECTIVE_START_DATE AND
                     EFFECTIVE_END_DATE
                 AND pl_id IN (331, 245, 248, 12872, 332,12871)) BPL
       WHERE pen.pl_id = bpl.pl_id
         AND pen.person_id = pap.person_id
         AND ((TRUNC(p_date) BETWEEN pen.effective_start_date AND
             pen.effective_end_date) OR (TRUNC(pen.effective_end_date) BETWEEN
             p_start_date AND p_end_date))
         AND TRUNC(pen.enrt_cvg_thru_dt) BETWEEN p_start_date AND
             p_end_date
         AND pen.prtt_enrt_rslt_stat_cd IS NULL
         AND trunc(p_date) BETWEEN pap.effective_start_date AND
             pap.effective_END_date
         AND hr_person_type_usage_info.get_user_person_type(trunc(p_date),
                                                            pap.person_id) =
             'PEO Employee' --v1.1
         AND pap.current_employee_flag = 'Y'
         AND pap.business_group_id = 325
      UNION
      SELECT -- TERMINATED EMPLOYEE Detail Fetch
       pap.employee_number employee_number,
       pap.full_name full_name,
       bpl.name VIN_PLAN,
       DECODE(pen.pl_id,
              331,
              (SELECT MIN(rt_val)
                 FROM BEN_PRTT_RT_VAL
                WHERE prtt_enrt_rslt_id = pen.prtt_enrt_rslt_id
                  AND ((TRUNC(p_date) BETWEEN RT_STRT_DT AND RT_END_DT) OR
                      (TRUNC(RT_END_DT) BETWEEN p_start_date AND p_end_date))),
              pen.bnft_amt) cvg_amt,
       pen.enrt_cvg_strt_dt start_date
		--START R12.2 Upgrade Remediation
		/*FROM hr.per_all_people_f pap,					 -- Commented code by IXPRAVEEN-ARGANO,09-May-2023
             ben.BEN_PRTT_ENRT_RSLT_F pen,*/             
		FROM apps.per_all_people_f pap,					--  code Added by IXPRAVEEN-ARGANO,   09-May-2023
             apps.BEN_PRTT_ENRT_RSLT_F pen,	
--END R12.2.10 Upgrade remediation	 
             (SELECT *
				--FROM ben.ben_pl_f			 -- Commented code by IXPRAVEEN-ARGANO,09-May-2023
                FROM apps.ben_pl_f            --  code Added by IXPRAVEEN-ARGANO,   09-May-2023
               WHERE TRUNC(P_DATE) BETWEEN EFFECTIVE_START_DATE AND
                     EFFECTIVE_END_DATE
                 AND pl_id IN (331, 245, 248, 12872, 332,12871)) BPL
       WHERE pen.pl_id = bpl.pl_id
         AND pen.person_id = pap.person_id
         AND ((TRUNC(p_date) BETWEEN pen.effective_start_date AND
             pen.effective_end_date) OR (TRUNC(pen.effective_end_date) BETWEEN
             p_start_date AND p_end_date))
         AND TRUNC(pen.enrt_cvg_thru_dt) BETWEEN p_start_date AND
             p_end_date
         AND pen.prtt_enrt_rslt_stat_cd IS NULL
         AND TRUNC(pap.effective_END_date) BETWEEN p_start_date AND
             p_end_date
         AND hr_person_type_usage_info.get_user_person_type(trunc(p_date),
                                                            pap.person_id) =
             'PEO Employee' --v1.1
         AND pap.business_group_id = 325)
      MINUS (SELECT * FROM XXTELETECH_FSA_MASS_PLAN_TAB));

    -- ################################## BEGIN ############################################## --

  BEGIN
    select to_char(sysdate, 'YYYYMONDDHH24MISS') into v_dt_time FROM dual;

    FND_FILE.PUT_LINE(FND_FILE.LOG, 'Time : ' || v_dt_time);

    SELECT TRUNC(SYSDATE) INTO v_date FROM dual;

    -- MAKE PARAMETER MANDATORY
    SELECT TRUNC(TO_DATE('01-JAN-2014')) INTO v_date_jan_2014 FROM DUAL;

    SELECT v_date_jan_2014 - to_date(p_prgm_date) INTO v_days FROM DUAL;

    if (v_days > 0) then

      v_date := v_date_jan_2014;

    else

      v_date := to_date(p_prgm_date);

    end if;

    SELECT START_DATE, END_DATE
      INTO V_START_DATE, V_END_DATE
      FROM PER_TIME_PERIODS PTP
     WHERE TRUNC(v_date) BETWEEN start_date AND default_dd_date
       AND payroll_id IN (SELECT payroll_id
                            FROM PAY_ALL_PAYROLLS_F
                           WHERE PAYROLL_NAME LIKE 'PEO%') -- CHANGE THE PAYROLL NAME
       AND TIME_PERIOD_ID =
           (SELECT MIN(TIME_PERIOD_ID)
              FROM PER_TIME_PERIODS
             WHERE TRUNC(v_date) BETWEEN START_DATE AND default_dd_date
               AND PAYROLL_ID = PTP.PAYROLL_ID);

    SELECT v_date - V_END_DATE INTO v_days FROM DUAL;

    IF (v_days > 0) THEN

      v_date := v_end_date;

    END IF;

    fnd_file.put_line(fnd_file.output,
                      '----------------------------------------------------------------------------Teletech PEO Employee FSA and Mass Transit Plans Extract: ' ||
                      v_date ||
                      '----------------------------------------------------------------------------');

    fnd_file.put_line(fnd_file.output,
                      '                                                                 ');
    fnd_file.put_line(fnd_file.output,
                      'Employee Number' || '	' || 'Employee Name' || '	' ||
                      'Plan Type' || '	' || 'Amount' || '	' || 'Start Date');

    FOR cur_emp_det IN emp_det(v_date)

     LOOP

      v_columns_str := cur_emp_det.employee_number || '	' ||
                       cur_emp_det.full_name || '	' || cur_emp_det.vin_plan || '	' ||
                       TO_CHAR(cur_emp_det.cvg_amt, '999999999.99') || '	' ||
                       TO_CHAR(cur_emp_det.start_date, 'MM/DD/YYYY');

      fnd_file.put_line(fnd_file.output, v_columns_str);

    END LOOP;

    FOR cur_term_det IN plan_term_det(v_date, v_start_date, v_end_date)

     LOOP

      v_columns_str := cur_term_det.employee_number || '	' ||
                       cur_term_det.full_name || '	' ||
                       cur_term_det.vin_plan || '	' ||
                       TO_CHAR(cur_term_det.cvg_amt, '999999999.99') || '	' ||
                       TO_CHAR(cur_term_det.start_date, 'MM/DD/YYYY');

      fnd_file.put_line(fnd_file.output, v_columns_str);

    END LOOP;

    fnd_file.put_line(fnd_file.log, 'DROPPING TABLE');

    BEGIN

      EXECUTE IMMEDIATE ('DROP TABLE XXTELETECH_FSA_MASS_PLAN_TAB');

    EXCEPTION
      WHEN OTHERS THEN
        FND_FILE.PUT_LINE(FND_FILE.LOG,
                          'TABLE DOES NOT EXIST, HENCE CREATING');

    END;

    V_STRING := 'CREATE TABLE XXTELETECH_FSA_MASS_PLAN_TAB AS
       SELECT
       pap.employee_number employee_number,
       pap.full_name full_name,
       bpl.name VIN_PLAN,
       DECODE(pen.pl_id,331,(SELECT rt_val FROM BEN_PRTT_RT_VAL
                             WHERE prtt_enrt_rslt_id = pen.prtt_enrt_rslt_id
                             AND ' || SQ || v_date || SQ ||
                ' BETWEEN RT_STRT_DT AND RT_END_DT),pen.bnft_amt) cvg_amt,
       pen.enrt_cvg_strt_dt start_date
--START R12.2 Upgrade Remediation
/*FROM   hr.per_all_people_f pap,				 -- Commented code by IXPRAVEEN-ARGANO,09-May-2023
       ben.BEN_PRTT_ENRT_RSLT_F pen,             
       (SELECT *
       FROM ben.ben_pl_f*/
FROM   apps.per_all_people_f pap,				 --  code Added by IXPRAVEEN-ARGANO,   09-May-2023
       apps.BEN_PRTT_ENRT_RSLT_F pen,
       (SELECT *
       FROM apps.ben_pl_f
--END R12.2.10 Upgrade remediation	   
       WHERE ' || SQ || v_date || SQ || ' BETWEEN effective_start_date AND effective_END_date
       AND pl_id IN (331,245,248,12872,332,12871)) BPL
       WHERE pen.pl_id = bpl.pl_id
       AND pen.person_id = pap.person_id
       AND ' || SQ || v_date || SQ || ' BETWEEN pen.enrt_cvg_strt_dt AND pen.enrt_cvg_thru_dt
       AND ' || SQ || v_date || SQ || ' BETWEEN pen.effective_start_date AND pen.effective_END_date
       AND  pen.prtt_enrt_rslt_stat_cd IS NULL
       AND ' || SQ || v_date || SQ ||
                ' BETWEEN pap.effective_start_date AND pap.effective_END_date
       AND hr_person_type_usage_info.get_user_person_type ( ' || SQ || v_date || SQ || ', pap.person_id ) = ' || SQ ||
                'PEO Employee' || SQ ||
                '  AND pap.current_employee_flag = ' || SQ || 'Y' || SQ ||
                '   AND pap.business_group_id = 325';

    EXECUTE IMMEDIATE (V_STRING);

    fnd_file.put_line(fnd_file.log, 'TABLE CREATION COMPLETED');

    fnd_file.put_line(fnd_file.log, 'PROGRAM SUCCESSFULLY COMPLETED');

  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'Program completed with error ' || sqlerrm);
      raise;
  END MAIN;

-- ############################### END MAIN ########################################## --

END XXTTEC_FSA_MASS_PLAN_CHNG_2016;
/
show errors;
/