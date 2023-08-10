create or replace PACKAGE BODY      ttec_mex_sav_fund AS
/*
-------------------------------------------------------------

Program Name    :  ttec_mex_sav_fund  specification

Desciption      : For Mexico Savings Fund And Loan Request form


Input/Output Parameters

Called From     :  Teletech Mexico Saving Fund framework page


Created By      :  Elango Pandu
Date            : 03-Mar-2011

Modification Log:
-----------------
Developer             Version     Date                Description
Elango Pandu        1.0           Apr-27-2011   change sit update with payment amount and total payment value
Elango Pandu        1.1          Jul-26-2011     Modified to include last day of Monday in July (Inc# 1840604)
Elango Pandu       1.2          Jul-29-2011     Modified to remove getting error on Ora 2001 Mandatory person id on Updating SIT Program  853624
Elango Pandu       1.3         May-15-2012   Modified to include Decembeer Month saving from last year (I#1431747)
RXNETHI-ARGANO     1.0         MAY-17-2023   R12.2 Upgrade Remediation
---------------------------------------------------------------
SET SERVEROUTPUT ON SIZE 1000000;

*/


FUNCTION sab_srvc(p_person_id IN NUMBER) RETURN NUMBER IS

/********************************************************************************
    PROGRAM NAME:   sab_srvc

    DESCRIPTION:    This function is returns number of months in service worked on SAB

    INPUT      :   person id

    OUTPUT     :   no of months in service in sab employee

    CREATED BY:     Elango Pandurangan

    DATE:           08-APR-2010

    CALLING FROM   :  ttec_mex_sav_fund package

    ----------------
    MODIFICATION LOG
    ----------------


    DEVELOPER             DATE          DESCRIPTION
    -------------------   ------------  -----------------------------------------
    RXNETHI-ARGANO        17/MAY/2023   R12.2 Upgrade Remediation
********************************************************************************/

 v_amt NUMBER;


CURSOR c_tot_srv IS
    SELECT MONTHS_BETWEEN(SYSDATE,a.date_start) tot_srv
    FROM per_periods_of_service a
    WHERE a.person_id = p_person_id
    and actual_termination_date is null;

 CURSOR c1 IS
    SELECT  SUBSTR(concatenated_segments,1,(INSTR(concatenated_segments,'.')-1)) seg1,effective_start_date,effective_end_date
    ,ROUND(MONTHS_BETWEEN(DECODE(TRUNC(paaf.effective_end_Date),TO_DATE('31-DEC-4712'),TRUNC(SYSDATE),paaf.effective_end_date),paaf.effective_start_date),2) srv
    FROM apps.per_all_assignments_f paaf,hr_soft_coding_keyflex hsck
    WHERE person_id = p_person_id
    AND paaf.soft_coding_keyflex_id = hsck.soft_coding_keyflex_id
    ORDER BY effective_start_date DESC;

v_tot_srv NUMBER := 0;
v_srv NUMBER := 0;

BEGIN

   OPEN c_tot_srv;
   FETCH c_tot_srv INTO v_tot_srv;
   CLOSE c_tot_srv;

   IF v_tot_srv > 6 THEN

       FOR v1 IN c1 LOOP

       IF SUBSTR(v1.seg1,1,7) IN ('SAB GRE') OR v1.seg1 IN ('SERVICIOS Y ADMINISTRACIONES DEL BAJIO') THEN
         v_srv := v_srv + v1.srv;
       ELSE
         EXIT;
       END IF;
       END LOOP;

   END IF;


   RETURN v_srv;

EXCEPTION
 WHEN OTHERS THEN
  RETURN 0;

END sab_srvc;


FUNCTION ttec_mex_sav_fnd(p_asg_id IN NUMBER, p_ele_name IN VARCHAR2,p_date_earn IN DATE) RETURN NUMBER IS

/********************************************************************************
    PROGRAM NAME:   ttec_mex_sav_fnd

    DESCRIPTION:    This function is returns amount for asg id ,element name and date earned parameter passed

    INPUT      :   asg id ,element name and date earned

    OUTPUT     :   element amount

    CREATED BY:     Elango Pandurangan

    DATE:           22-FEB-2011

    CALLING FROM   :  TeleTech Mexico Saving Fund and Loan Form

    ----------------
    MODIFICATION LOG
    ----------------


    DEVELOPER             DATE          DESCRIPTION
    -------------------   ------------  -----------------------------------------

********************************************************************************/




 v_amt NUMBER;

 CURSOR c1 IS
   SELECT  NVL(TO_NUMBER(rrv.result_value),0)
     FROM pay_element_types_f ety,
          pay_run_result_values rrv,
          pay_input_values_f inv,
          pay_run_results rrs,
          pay_assignment_actions asact,
          pay_payroll_actions pact
    WHERE  inv.element_type_id = ety.element_type_id
      AND rrs.element_type_id = ety.element_type_id
      AND asact.assignment_action_id = rrs.assignment_action_id
      AND rrs.run_result_id = rrv.run_result_id
      AND rrv.input_value_id = inv.input_value_id
      AND ety.element_name = p_ele_name
      AND SYSDATE BETWEEN ety.effective_start_date AND ety.effective_end_date
      AND inv.NAME = 'Pay Value'
      AND asact.assignment_id = p_asg_id
      AND pact.payroll_action_id = asact.payroll_action_id
      AND rrs.status = 'P'
      AND pact.date_earned = p_date_earn;


BEGIN

   OPEN c1;
   FETCH c1 INTO v_amt;
   CLOSE c1;

   RETURN v_amt;

EXCEPTION
 WHEN OTHERS THEN
  RETURN 0;

END ttec_mex_sav_fnd;



FUNCTION tot_balance(p_asg_id IN NUMBER, p_ele_name IN VARCHAR2,p_inv_name IN VARCHAR2) RETURN VARCHAR2 IS

--'Pay Value' for total saving fund balance  and MWA,MWB,MWC and MWD for min. ded amt

CURSOR C1 is
   SELECT  pact.date_earned,NVL(TO_NUMBER(rrv.result_value),0)
     FROM pay_element_types_f ety,
          pay_run_result_values rrv,
          pay_input_values_f inv,
          pay_run_results rrs,
          pay_assignment_actions asact,
          pay_payroll_actions pact
    WHERE  inv.element_type_id = ety.element_type_id
      AND rrs.element_type_id = ety.element_type_id
      AND asact.assignment_action_id = rrs.assignment_action_id
      AND rrs.run_result_id = rrv.run_result_id
      AND rrv.input_value_id = inv.input_value_id
      AND ety.element_name = p_ele_name
      AND SYSDATE BETWEEN ety.effective_start_date AND ety.effective_end_date
      AND UPPER(inv.NAME) = UPPER(p_inv_name)   --'Pay Value' for total saving fund balance  and WMA,WMB,WMC or WMD for min. ded amt
      AND asact.assignment_id = p_asg_id
      AND pact.payroll_action_id = asact.payroll_action_id
      AND rrs.status = 'P'
      ORDER BY 1 DESC;

v_amt pay_run_result_values.result_value%TYPE;
v_date pay_payroll_actions.date_earned%TYPE;

BEGIN

  OPEN c1;
  FETCH c1 INTO v_date,v_amt;
  CLOSE c1;

  RETURN (v_amt);


EXCEPTION
 WHEN OTHERS THEN
  RETURN (0);

END tot_balance;


FUNCTION mon_sal (p_asg_id IN NUMBER) RETURN NUMBER AS


CURSOR c1 IS
SELECT ROUND((ppp.proposed_salary_n* ppb.pay_annualization_factor)/ 12,2) mnthly_sal
FROM apps.per_pay_bases ppb,
                   (SELECT p.assignment_id, p.proposed_salary_n,
                           p.change_date
                      --FROM hr.per_pay_proposals p   --code commented by RXNETHI-ARGANO,17/05/23
                      FROM apps.per_pay_proposals p   --code added by RXNETHI-ARGANO,17/05/23
                     WHERE p.change_date =
                              (SELECT MAX (x.change_date)
                                 --FROM hr.per_pay_proposals x     --code commented by RXNETHI-ARGANO,17/05/23
                                 FROM apps.per_pay_proposals x     --code added by RXNETHI-ARGANO,17/05/23
                                WHERE p.assignment_id = x.assignment_id
                                  AND (x.change_date) <= TRUNC (SYSDATE))) ppp,
 apps.per_all_assignments_f paaf
WHERE paaf.assignment_id =  p_asg_id
AND paaf.assignment_id =  ppp.assignment_id
AND paaf.pay_basis_id = ppb.pay_basis_id
AND TRUNC(SYSDATE)  BETWEEN paaf.effective_start_date AND paaf.effective_end_date;

v_sal NUMBER ;

BEGIN

OPEN c1;
FETCH c1 INTO v_sal;
CLOSE c1;

RETURN v_sal;


EXCEPTION
 WHEN OTHERS THEN
   RETURN 0;
END mon_sal;


FUNCTION total_saving(p_asg_id IN NUMBER) RETURN NUMBER IS

/*   calling from availvo in mexico loan page */

   v_tot_sav NUMBER := 0;

   CURSOR c1 IS
   SELECT SUM(NVL(TO_NUMBER(rrv.result_value),0))
     FROM pay_element_types_f ety,
          pay_run_result_values rrv,
          pay_input_values_f inv,
          pay_run_results rrs,
          pay_assignment_actions asact,
          pay_payroll_actions pact
    WHERE  inv.element_type_id = ety.element_type_id
      AND rrs.element_type_id = ety.element_type_id
      AND asact.assignment_action_id = rrs.assignment_action_id
      AND rrs.run_result_id = rrv.run_result_id
      AND rrv.input_value_id = inv.input_value_id
      AND ety.element_name IN ('MX_SF_EMP_DED','MX_RE_SAVING_FUNDS','MX_SF_INITIAL_BALANCE')
      AND SYSDATE BETWEEN ety.effective_start_date AND ety.effective_end_date
      AND UPPER(inv.NAME) = 'PAY VALUE'
      AND asact.assignment_id = p_asg_id
      AND pact.payroll_action_id = asact.payroll_action_id
      AND rrs.status = 'P'
       AND pact.date_earned >=TO_DATE('01-DEC'|| (to_char(SYSDATE,'YYYY') - 1),'DD-MON-YYYY')
      --AND pact.date_earned >= TRUNC(SYSDATE,'YEAR')
      AND pact.date_earned <= SYSDATE;



BEGIN
  OPEN c1;
  FETCH c1 INTO v_tot_sav;
  CLOSE c1;

  RETURN v_tot_sav;


EXCEPTION
 WHEN OTHERS THEN
 RETURN 0;
END total_saving;


FUNCTION ded_amt (p_asg_id IN NUMBER) RETURN NUMBER IS

-- From Bob's email on 3/3/2011
-- changed the logic as per Bob's mail on Mar 25th
-- calling from availvo



v_zone_amt NUMBER := 0;
v_mon_sal NUMBER := 0;
v_hr_sal  NUMBER := 0;
v_annual_sal  NUMBER := 0;

v_result NUMBER := 0;
v_pay_basis per_pay_bases.pay_basis%TYPE;
v_location hr_locations_all.location_code%TYPE;
v_zone  VARCHAR2(5);
v_run_result_id pay_run_result_values.run_result_id%TYPE;

CURSOR c_zone_amt IS
   SELECT  rrv.run_result_id
   ,NVL(TO_NUMBER(rrv.result_value),0)
     FROM apps.pay_element_types_f ety,
          apps.pay_run_result_values rrv,
          apps.pay_input_values_f inv,
          apps.pay_run_results rrs,
          apps.pay_assignment_actions asact,
          apps.pay_payroll_actions pact
    WHERE  inv.element_type_id = ety.element_type_id
      AND rrs.element_type_id = ety.element_type_id
      AND asact.assignment_action_id = rrs.assignment_action_id
      AND rrs.run_result_id = rrv.run_result_id
      AND rrv.input_value_id = inv.input_value_id
      AND UPPER(ety.element_name) = 'MX_MW'
      AND SYSDATE BETWEEN ety.effective_start_date AND ety.effective_end_date
      AND UPPER(inv.NAME) = UPPER(v_zone)   --'Pay Value' for total saving fund balance  and WMA,WMB,WMC or WMD for min. ded amt
      AND asact.assignment_id = p_asg_id
      AND pact.payroll_action_id = asact.payroll_action_id
      AND rrs.status = 'P'
      AND TO_CHAR(pact.date_earned,'YYYY') = TO_CHAR(SYSDATE,'YYYY')
      ORDER BY 1 DESC;



CURSOR c_mon_sal IS
SELECT ppp.proposed_salary_n,ROUND((ppp.proposed_salary_n* ppb.pay_annualization_factor)/ 12,2) mnthly_sal,
ROUND((ppp.proposed_salary_n* ppb.pay_annualization_factor),2) annual_sal
FROM apps.per_pay_bases ppb,
                   (SELECT p.assignment_id, p.proposed_salary_n,
                           p.change_date
                      --FROM hr.per_pay_proposals p     --code commented by RXNETHI-ARGANO,17/05/23
                      FROM apps.per_pay_proposals p     --code added by RXNETHI-ARGANO,17/05/23
                     WHERE p.change_date =
                              (SELECT MAX (x.change_date)
                                 --FROM hr.per_pay_proposals x     --code commented by RXNETHI-ARGANO,17/05/23
                                 FROM apps.per_pay_proposals x     --code added by RXNETHI-ARGANO,17/05/23
                                WHERE p.assignment_id = x.assignment_id
                                  AND (x.change_date) <= TRUNC (SYSDATE))) ppp,
 apps.per_all_assignments_f paaf
WHERE paaf.assignment_id =  p_asg_id
AND paaf.assignment_id =  ppp.assignment_id
AND paaf.pay_basis_id = ppb.pay_basis_id
AND TRUNC(SYSDATE)  BETWEEN paaf.effective_start_date AND paaf.effective_end_date;


CURSOR c_pay_basis IS
  SELECT ppb.pay_basis
  FROM apps.per_pay_bases ppb, apps.per_all_assignments_f paaf
  WHERE ppb.pay_basis_id =   paaf.pay_basis_id
  AND paaf.assignment_id = p_asg_id
  AND paaf.business_group_id = 1633
  AND TRUNC(SYSDATE)  BETWEEN paaf.effective_start_date AND paaf.effective_end_date;

CURSOR c_loc IS
    SELECT UPPER(loc.location_code)
    FROM apps.per_all_assignments_f paaf, apps.hr_locations_all loc
    WHERE paaf.assignment_id = p_asg_id
    AND paaf.location_id = loc.location_id
    AND TRUNC(SYSDATE) BETWEEN paaf.effective_start_date AND paaf.effective_end_date;



BEGIN


    OPEN c_mon_sal;
    FETCH c_mon_sal INTO v_hr_sal,v_mon_sal,v_annual_sal;
    CLOSE c_mon_sal;

    OPEN c_loc;
    FETCH c_loc INTO v_location;
    CLOSE c_loc;

    IF v_location = 'MEX-GUADALAJARA 03115' THEN
       v_zone := 'MWB';
    ELSIF v_location = 'MEX-REPUBLICA MEXICO CITY 03105' THEN
       v_zone := 'MWA';
    ELSIF v_location = 'MEX-LEON 03120'  THEN
       v_zone := 'MWC';
    ELSE
       v_zone := 'MWA';
    END IF;


    OPEN c_zone_amt;
    FETCH c_zone_amt INTO v_run_result_id,v_zone_amt;
    CLOSE c_zone_amt;


    v_result := ROUND((((v_annual_sal/24) - (NVL(v_zone_amt,0) * 15 ))* 0.3),2);


   IF NVL(v_result,0) = 0 THEN
      v_result := 0;
   END IF;

   RETURN v_result;
/*
    OPEN c_pay_basis;
    FETCH c_pay_basis INTO v_pay_basis;
    CLOSE c_pay_basis;

    --MONTHLY

    IF NVL(v_mon_sal,0) <> 0 THEN
        IF v_pay_basis = 'MONTHLY' THEN
          IF NVL(v_zone_amt,0) <> 0 THEN
            v_result := v_mon_sal - (v_zone_amt * 30 );
          END IF;

        ELSIF v_pay_basis = 'HOURLY' THEN
          v_result := (v_mon_sal * .3)/2;
        END IF;
    END IF;

   IF NVL(v_result,0) = 0 THEN
      v_result := 0;
   END IF;

   RETURN v_result;

  IF NVL(v_hr_sal,0) <> 0 THEN
    v_result := ((v_hr_sal * 208) * .3) / 2;
   ELSE
    v_result := 0 ;
   END IF;

ELSE

*/

EXCEPTION
  WHEN OTHERS THEN
   RETURN 0;
END ded_amt;




FUNCTION int_rate (p_asg_id IN NUMBER) RETURN NUMBER IS


CURSOR c1 IS
   SELECT  TO_NUMBER(b.global_value)
     FROM ff_globals_f b
     WHERE b.GLOBAL_NAME = 'MX_SF_LOAN_INTEREST_RATE' --'INFONAVIT_INSURANCE_AMOUNT'
     AND business_group_id = 1633
     AND TRUNC(SYSDATE) BETWEEN effective_start_date AND effective_end_date;


v_result NUMBER := 0;

BEGIN

-- Hard code value to 6 for interest rate as of now --Mar 4 2010
--  if you change this value, pls change to emp_chk procedure line number 523

 OPEN c1;
 FETCH c1 INTO v_result;
 CLOSE c1;



RETURN v_result ;


EXCEPTION
  WHEN OTHERS THEN
   RETURN 0;
END int_rate;



FUNCTION pymt_no(p_asg_id IN NUMBER) RETURN NUMBER IS


v_result NUMBER := 0;


BEGIN

-- Hard code value to 6 for interest rate as of now --Mar 4 2010
--  if you change this value, pls change to emp_chk procedure line number 523

v_result := 6;

RETURN v_result;


EXCEPTION
  WHEN OTHERS THEN
   RETURN 0;
END pymt_no;




PROCEDURE pymt_rate1(p_loan_amt IN VARCHAR2,p_rate IN VARCHAR2,p_no_pymt IN VARCHAR2,p_pymt_amt OUT VARCHAR2) IS
-- calling from EmployeeAMimpl class from TTECMEXLOAN JPR
v_loan_int NUMBER;

BEGIN

  v_loan_int := ((((p_rate/24) * 0.01) * p_loan_amt) * 6);

  p_pymt_amt :=  ROUND(((v_loan_int + p_loan_amt)/6),2);

EXCEPTION
  WHEN OTHERS THEN
   p_pymt_amt :=  0;


END pymt_rate1;

PROCEDURE emp_chk(p_person_id IN VARCHAR2,p_loanamt IN VARCHAR2,p_flag OUT VARCHAR2,p_msg OUT VARCHAR2) IS

-- Calling from TtecMexLoanEOImpl class validatePersonId method
c_dt DATE;
v_dt DATE;


CURSOR c_strt_dt IS
SELECT ROUND(MONTHS_BETWEEN (SYSDATE,MAX (pps.date_start)),2)
FROM apps.per_all_people_f papf,apps.per_all_assignments_f paaf,apps.per_periods_of_service pps
WHERE  papf.person_id = p_person_id
AND papf.person_id = paaf.person_id
AND papf.person_id = pps.person_id
AND paaf.payroll_id = 421
AND SYSDATE BETWEEN papf.effective_start_date AND papf.effective_end_date
AND SYSDATE BETWEEN paaf.effective_start_date AND paaf.effective_end_date;



CURSOR c_exists IS
SELECT person_id
FROM ttec_mex_loan_dtl
WHERE person_id = p_person_id
AND creation_date >= TRUNC(SYSDATE,'YEAR')
AND creation_date <= SYSDATE;

CURSOR c_asg_id IS
SELECT paaf.assignment_id
FROM per_all_people_f papf,per_all_assignments_f paaf
WHERE papf.person_id = p_person_id
AND papf.person_id = paaf.person_id
AND TRUNC(SYSDATE) BETWEEN papf.effective_start_date AND papf.effective_end_date
AND TRUNC(SYSDATE) BETWEEN paaf.effective_start_date AND paaf.effective_end_date;

-- Include +1 to include last day of monday in July
-- 1840604
CURSOR c_date IS
SELECT 1 FROM DUAL WHERE
SYSDATE BETWEEN (SELECT NEXT_DAY(ADD_MONTHS(TRUNC(SYSDATE,'YEAR'),2),'MONDAY') FROM DUAL)
AND (SELECT NEXT_DAY(LAST_DAY(ADD_MONTHS(TRUNC(SYSDATE,'YEAR'),6)) -7,'MONDAY') + 1 FROM DUAL);


CURSOR c_srv(c_dt IN DATE) IS
SELECT paaf.effective_start_date
,ROUND(MONTHS_BETWEEN(DECODE(TRUNC(paaf.effective_end_Date),TO_DATE('31-DEC-4712'),TRUNC(SYSDATE),paaf.effective_end_date),paaf.effective_start_date),2) srv
FROM per_all_assignments_f paaf
WHERE paaf.person_id = p_person_id
AND paaf.payroll_id = 421
AND c_dt BETWEEN paaf.effective_start_date AND paaf.effective_end_date;


v_asg_id apps.per_all_assignments_f.assignment_id%TYPE := NULL;
v_months_svc NUMBER := 0;
v_person_id apps.ttec_mex_loan_dtl.person_id%TYPE := NULL;
v_tot_sav NUMBER := 0 ;
v_ded_amt NUMBER := 0;
v_date    NUMBER := 0;
v_pymt_amt VARCHAR2(20);
v_strt_dt  DATE;
v_srv  NUMBER;
v_tot_srv NUMBER := 0;

BEGIN

 p_flag := 'S';
 p_msg  := NULL;
v_tot_srv := 0;
v_tot_srv := ttec_mex_sav_fund.sab_srvc(p_person_id);


IF v_tot_srv < 6 THEN
   p_flag := 'F';
   --p_msg := 'Service is less than 6 months';
   p_msg := 'Lo sentimos, pero debes tener al menos 6 meses en la actual Razon Social (SAB) para poder solicitar un Prestamo';
END IF;

OPEN c_exists;
FETCH c_exists INTO v_person_id;
CLOSE c_exists;

IF v_person_id IS NOT NULL THEN
   p_flag := 'F';
   IF p_msg IS NULL THEN
     --p_msg := 'Loan already paid for this Year';
     p_msg := 'Solicitud denegada.  Por politica solamente puede solicitar 1 (un) credito por a?o, y ya se tiene registrada una solicitud previa';

   ELSE
     --p_msg := p_msg||'. And Loan already paid for this Year';
     p_msg := p_msg||'. y Solicitud denegada.  Por politica solamente puede solicitar 1 (un) credito por a?o, y ya se tiene registrada una solicitud previa';
   END IF;
END IF;


OPEN c_asg_id;
FETCH c_asg_id INTO v_asg_id;
CLOSE c_asg_id;

v_tot_sav := ttec_mex_sav_fund.total_saving(v_asg_id);
v_tot_sav := (v_tot_sav * .8); -- 80% of total saving  max available for loan
v_ded_amt := ttec_mex_sav_fund.ded_amt(v_asg_id);

ttec_mex_sav_fund.pymt_rate1(p_loanamt,6,6,v_pymt_amt);


IF TO_NUMBER(p_loanamt) > NVL(v_tot_sav,0) THEN
   p_flag := 'F';
   IF p_msg IS NULL THEN
    -- p_msg := 'Loan Amount should be less than 80% Total Saving';
      p_msg := 'El monto solicitado como prestamo, excede el 80% de las Aportaciones actuales a su Fondo de Ahorro';
   ELSE
     --p_msg := p_msg||'. And Loan Amount should be less than 80% Total Saving';
     p_msg := p_msg||'. y El monto solicitado como prestamo, excede el 80% de las Aportaciones actuales a su Fondo de Ahorro';
   END IF;

END IF;

IF TO_NUMBER(NVL(v_pymt_amt,0)) > NVL(v_ded_amt,0) THEN

   p_flag := 'F';
   IF p_msg IS NULL THEN
    -- p_msg := 'payment  Amount should be less than deduction amount';
      p_msg := 'El prestamo no puede ser procesado, debido a que los importes quincenales excederian el monto maximo permitido para ser descontado por periodo de pago';
   ELSE
     --p_msg := p_msg||'. payment  Amount should be less than deduction amount';;
     p_msg := p_msg||'. y El prestamo no puede ser procesado, debido a que los importes quincenales excederian el monto maximo permitido para ser descontado por periodo de pago';
   END IF;

END IF;


OPEN c_date;
FETCH c_date INTO v_date;
CLOSE c_date;

IF NVL(v_date,0) = 0 THEN

   p_flag := 'F';
   IF p_msg IS NULL THEN
     --p_msg := 'Loan is not requested between the first Monday in March and the last Monday in July.';
     p_msg := 'La Solicitud no puede ser procesada ya que la fecha actual esta fuera del periodo para solicitar Prestamos del Fondo de Ahorro';
   ELSE
     --p_msg := p_msg||'. And Loan is not requested between the first Monday in March and the last Monday in July.';
     p_msg := p_msg||chr(13)||chr(10)||'. Y La Solicitud no puede ser procesada ya que la fecha actual esta fuera del periodo para solicitar Prestamos del Fondo de Ahorro';
   END IF;


END IF;



EXCEPTION
 WHEN OTHERS THEN
   p_flag := 'F';
   p_msg := 'Exception in emp_chk';


END emp_chk;

FUNCTION sub_btn(p_person_id IN NUMBER) RETURN VARCHAR2 AS


v_person_id ttec_mex_loan_dtl.person_id%TYPE;
v_employee_number apps.per_all_people_f.employee_number%TYPE;


CURSOR c1 IS
SELECT person_id
FROM ttec_mex_loan_dtl
WHERE person_id = p_person_id
AND creation_date >= TRUNC(SYSDATE,'YEAR')
AND creation_date <= SYSDATE;



CURSOR c_sab_emp IS
SELECT papf.employee_number
FROM apps.per_all_people_f papf,apps.per_all_assignments_f paaf,apps.per_periods_of_service pps
WHERE  papf.person_id = p_person_id
AND papf.person_id = paaf.person_id
AND papf.person_id = pps.person_id
AND paaf.payroll_id = 421
AND SYSDATE BETWEEN papf.effective_start_date AND papf.effective_end_date
AND SYSDATE BETWEEN paaf.effective_start_date AND paaf.effective_end_date;

BEGIN

OPEN c_sab_emp;
FETCH c_sab_emp INTO v_employee_number;
CLOSE c_sab_emp;

IF v_employee_number IS NOT NULL THEN

        OPEN c1;
        FETCH c1 INTO v_person_id;
        CLOSE c1;

        IF v_person_id IS NULL THEN
          RETURN('Enabled');

        ELSE
          RETURN('Disabled');
        END IF;
ELSE
        RETURN('Disabled');
END IF;



EXCEPTION
  WHEN OTHERS THEN
  RETURN('Disabled');
END sub_btn;



FUNCTION calc_btn(p_person_id IN NUMBER) RETURN VARCHAR2 AS


v_person_id ttec_mex_loan_dtl.person_id%TYPE;

CURSOR c1 IS
SELECT person_id
FROM ttec_mex_loan_dtl
WHERE person_id = p_person_id
AND creation_date >= TRUNC(SYSDATE,'YEAR')
AND creation_date <= SYSDATE;

BEGIN

OPEN c1;
FETCH c1 INTO v_person_id;
CLOSE c1;

IF v_person_id IS NULL THEN
  RETURN('Calc_Enabled');

ELSE
  RETURN('Calc_Disabled');
END IF;

EXCEPTION
  WHEN OTHERS THEN
  RETURN('Calc_Disabled');
END calc_btn;



PROCEDURE emp_chk_x(p_emp_num IN VARCHAR2,p_loanamt IN VARCHAR2,p_flag OUT VARCHAR2,p_msg OUT VARCHAR2) AS

CURSOR c_strt_dt IS
SELECT ROUND(MONTHS_BETWEEN (SYSDATE,MAX (pps.date_start)),2)
FROM apps.per_all_people_f papf,apps.per_all_assignments_f paaf,apps.per_periods_of_service pps
WHERE  papf.employee_number = p_emp_num
AND papf.person_id = paaf.person_id
AND papf.person_id = pps.person_id
AND paaf.payroll_id = 421
AND SYSDATE BETWEEN papf.effective_start_date AND papf.effective_end_date
AND SYSDATE BETWEEN paaf.effective_start_date AND paaf.effective_end_date;


CURSOR c_exists IS
SELECT person_id
FROM ttec_mex_loan_dtl
WHERE employee_number = p_emp_num
AND creation_date >= TRUNC(SYSDATE,'YEAR')
AND creation_date <= SYSDATE;

CURSOR c_asg_id IS
SELECT paaf.assignment_id
FROM per_all_people_f papf,per_all_assignments_f paaf
WHERE papf.employee_number = p_emp_num
AND papf.person_id = paaf.person_id
AND TRUNC(SYSDATE) BETWEEN papf.effective_start_date AND papf.effective_end_date
AND TRUNC(SYSDATE) BETWEEN paaf.effective_start_date AND paaf.effective_end_date;


CURSOR c_date IS
SELECT 1 FROM DUAL WHERE
SYSDATE BETWEEN (SELECT NEXT_DAY(ADD_MONTHS(TRUNC(SYSDATE,'YEAR'),2),'MONDAY') FROM DUAL)
AND (SELECT NEXT_DAY(LAST_DAY(ADD_MONTHS(TRUNC(SYSDATE,'YEAR'),6)) -7,'MONDAY') FROM DUAL);

v_asg_id apps.per_all_assignments_f.assignment_id%TYPE := NULL;
v_months_svc NUMBER := 0;
v_person_id apps.ttec_mex_loan_dtl.person_id%TYPE := NULL;
v_tot_sav NUMBER := 0 ;
v_ded_amt NUMBER := 0;
v_date    NUMBER := 0;

BEGIN

 p_flag := 'S';
 p_msg  := NULL;

OPEN c_strt_dt;
FETCH c_strt_dt INTO v_months_svc;
CLOSE c_strt_dt;

IF v_months_svc < 6 THEN
   p_flag := 'F';
   p_msg := 'Service is less than 6 months';
END IF;

OPEN c_exists;
FETCH c_exists INTO v_person_id;
CLOSE c_exists;

IF v_person_id IS NOT NULL THEN
   p_flag := 'F';
   IF p_msg IS NULL THEN
     p_msg := 'Loan already paid for this Year';
   ELSE
     p_msg := p_msg||'. And Loan already paid for this Year';
   END IF;
END IF;


OPEN c_asg_id;
FETCH c_asg_id INTO v_asg_id;
CLOSE c_asg_id;

v_tot_sav := ttec_mex_sav_fund.total_saving(v_asg_id);
v_tot_sav := (v_tot_sav * .8); -- 80% of total saving
v_ded_amt := ttec_mex_sav_fund.ded_amt(v_asg_id);



IF TO_NUMBER(p_loanamt) > NVL(v_tot_sav,0) THEN
   p_flag := 'F';
   IF p_msg IS NULL THEN
     p_msg := 'Loan Amount should be less than 80% Total Saving';
   ELSE
     p_msg := p_msg||'. And Loan Amount should be less than 80% Total Saving';
   END IF;

END IF;

IF TO_NUMBER(p_loanamt) > NVL(v_ded_amt,0) THEN
   p_flag := 'F';
   IF p_msg IS NULL THEN
     p_msg := 'Loan Amount should be less than Deduction Amount';
   ELSE
     p_msg := p_msg||'. And Loan Amount should be less than Deduction Amount';
   END IF;

END IF;

OPEN c_date;
FETCH c_date INTO v_date;
CLOSE c_date;

IF NVL(v_date,0) = 0 THEN

   p_flag := 'F';
   IF p_msg IS NULL THEN
     p_msg := 'Loan is not requested between the first Monday in March and the last Monday in July.';
   ELSE
     p_msg := p_msg||'. And Loan is not requested between the first Monday in March and the last Monday in July.';
   END IF;


END IF;



EXCEPTION
 WHEN OTHERS THEN
   p_flag := 'F';
   p_msg := 'Exception in emp_chk';


END emp_chk_x;

FUNCTION loan_amt(p_person_id IN NUMBER) RETURN NUMBER AS

CURSOR c1 IS
  SELECT loan_amount
  FROM ttec_mex_loan_dtl
  WHERE person_id = p_person_id
  AND TO_CHAR(creation_date,'RRRR') = TO_CHAR(sysdate,'RRRR');

v_loan_amt ttec_mex_loan_dtl.loan_amount%TYPE := 0;


BEGIN

OPEN c1;
FETCH c1 INTO v_loan_amt;
CLOSE c1;

RETURN(v_loan_amt);


EXCEPTION
   WHEN OTHERS THEN
    RETURN(v_loan_amt);
END loan_amt;

PROCEDURE ttec_mex_loan_sit_upd(errbuf OUT VARCHAR2,retcode OUT NUMBER ) AS

    v_analysis_criteria_id      per_person_analyses.analysis_criteria_id%TYPE;
    v_person_analysis_id        per_person_analyses.person_analysis_id%TYPE;
    v_pea_object_version_number per_person_analyses.object_version_number%TYPE;
    v_id_flex   fnd_id_flex_structures_vl.id_flex_num%TYPE;
    v_err VARCHAR2(100);
    v_flex  fnd_id_flex_structures_vl.id_flex_num%TYPE;

v_rowid rowid;
v_person_id ttec_mex_loan_dtl.person_id%TYPE;
v_creation_date ttec_mex_loan_dtl.creation_date%TYPE;
v_loan_amount ttec_mex_loan_dtl.loan_amount%TYPE;
v_int_rate ttec_mex_loan_dtl.int_rate%TYPE;
v_employee_number ttec_mex_loan_dtl.employee_number%TYPE;
v_tot_loan NUMBER;
v_pymt_amount ttec_mex_loan_dtl.pymt_amount%TYPE;
v_no_pymts  ttec_mex_loan_dtl.no_pymts%TYPE;

    CURSOR c_flex IS
    SELECT id_flex_num
    FROM fnd_id_flex_structures_vl
    WHERE UPPER(ID_FLEX_STRUCTURE_NAME) LIKE 'SAVINGS FUND LOAN INFO' ;
    --structure_view_name = 'TTEC_MX_SF_LOAN';


--  changed this total loan amount calcluation on apr 27 by Bob
--  total payment is payment amount * 6 (hard coded value)
-- added payment amount into segment 5

-- R# 853624 Ver 1.2
-- Modified to remove getting error on Ora 2001 Mandatory person id on Updating SIT Program  853624

  CURSOR c_loan IS
    SELECT rowid,person_id,TO_DATE(creation_date,'YYY-MON-DD') creation_date,loan_amount,int_rate,no_pymts,employee_number,pymt_amount
    FROM apps.ttec_mex_loan_dtl
    WHERE NVL(upd_sit,'N') = 'N'
    AND employee_number IS NOT NULL;


BEGIN

  OPEN c_flex;
  FETCH c_flex INTO v_flex;
  CLOSE c_flex;


  OPEN c_loan;
  LOOP
  FETCH c_loan INTO v_rowid,v_person_id,v_creation_date,v_loan_amount,v_int_rate,v_no_pymts,v_employee_number,v_pymt_amount;
  EXIT WHEN c_loan%NOTFOUND;

       BEGIN

        v_tot_loan := v_pymt_amount * 6;

        hr_sit_api.create_sit
            (p_person_id                  =>  v_person_id,
             p_business_group_id          =>  1633,
             p_id_flex_num                =>  v_flex,
             p_effective_date             =>  TRUNC(SYSDATE),
             p_date_from                  =>  TRUNC(SYSDATE),
             p_segment1 => v_creation_date
            ,p_segment2 => v_loan_amount
            ,p_segment3 => v_int_rate
            ,p_segment4 => v_no_pymts
            ,p_segment5 => v_pymt_amount
            ,p_segment6 => v_tot_loan
            ,p_analysis_criteria_id       =>  v_analysis_criteria_id,
             p_person_analysis_id         =>  v_person_analysis_id,
             p_pea_object_version_number  =>  v_pea_object_version_number);

           UPDATE ttec_mex_loan_dtl
           SET upd_sit = 'Y'
           WHERE rowid = v_rowid;
        EXCEPTION
          WHEN OTHERS THEN
              v_err := SUBSTR(sqlerrm,1,50);
              fnd_file.put_line(2,'Employee :'||v_employee_number||'Error  : '||v_err) ;

        END;

            fnd_file.put_line(2,'Successfully Updated Employee : '||v_employee_number||'Payment Amount is '||v_pymt_amount||' v_tot_loan is '||v_tot_loan);

        v_person_id    := NULL;
        v_creation_date := NULL;
        v_tot_loan      := 0;
        v_int_rate      := NULL;
        v_no_pymts      := NULL;
        v_pymt_amount   := 0;
        v_rowid         := NULL;
        v_analysis_criteria_id := NULL;


  END LOOP;
  CLOSE c_loan;

EXCEPTION
  WHEN OTHERS THEN

   v_err := SUBSTR(sqlerrm,1,50);
    fnd_file.put_line(2,'Error : '||v_err);
END ttec_mex_loan_sit_upd;



PROCEDURE emp_chk_bk(p_person_id IN VARCHAR2,p_loanamt IN VARCHAR2,p_flag OUT VARCHAR2,p_msg OUT VARCHAR2) IS

c_dt DATE;
v_dt DATE;


CURSOR c_strt_dt IS
SELECT ROUND(MONTHS_BETWEEN (SYSDATE,MAX (pps.date_start)),2)
FROM apps.per_all_people_f papf,apps.per_all_assignments_f paaf,apps.per_periods_of_service pps
WHERE  papf.person_id = p_person_id
AND papf.person_id = paaf.person_id
AND papf.person_id = pps.person_id
AND paaf.payroll_id = 421
AND SYSDATE BETWEEN papf.effective_start_date AND papf.effective_end_date
AND SYSDATE BETWEEN paaf.effective_start_date AND paaf.effective_end_date;



CURSOR c_exists IS
SELECT person_id
FROM ttec_mex_loan_dtl
WHERE person_id = p_person_id
AND creation_date >= TRUNC(SYSDATE,'YEAR')
AND creation_date <= SYSDATE;

CURSOR c_asg_id IS
SELECT paaf.assignment_id
FROM per_all_people_f papf,per_all_assignments_f paaf
WHERE papf.person_id = p_person_id
AND papf.person_id = paaf.person_id
AND TRUNC(SYSDATE) BETWEEN papf.effective_start_date AND papf.effective_end_date
AND TRUNC(SYSDATE) BETWEEN paaf.effective_start_date AND paaf.effective_end_date;


CURSOR c_date IS
SELECT 1 FROM DUAL WHERE
SYSDATE BETWEEN (SELECT NEXT_DAY(ADD_MONTHS(TRUNC(SYSDATE,'YEAR'),2),'MONDAY') FROM DUAL)
AND (SELECT NEXT_DAY(LAST_DAY(ADD_MONTHS(TRUNC(SYSDATE,'YEAR'),6)) -7,'MONDAY') FROM DUAL);


CURSOR c_srv(c_dt IN DATE) IS
SELECT paaf.effective_start_date
,ROUND(MONTHS_BETWEEN(DECODE(TRUNC(paaf.effective_end_Date),TO_DATE('31-DEC-4712'),TRUNC(SYSDATE),paaf.effective_end_date),paaf.effective_start_date),2) srv
FROM per_all_assignments_f paaf
WHERE paaf.person_id = p_person_id
AND paaf.payroll_id = 421
AND c_dt BETWEEN paaf.effective_start_date AND paaf.effective_end_date;


v_asg_id apps.per_all_assignments_f.assignment_id%TYPE := NULL;
v_months_svc NUMBER := 0;
v_person_id apps.ttec_mex_loan_dtl.person_id%TYPE := NULL;
v_tot_sav NUMBER := 0 ;
v_ded_amt NUMBER := 0;
v_date    NUMBER := 0;
v_pymt_amt VARCHAR2(20);
v_strt_dt  DATE;
v_srv  NUMBER;
v_tot_srv NUMBER := 0;

BEGIN

 p_flag := 'S';
 p_msg  := NULL;
v_tot_srv := 0;
v_tot_srv := ttec_mex_sav_fund.sab_srvc(p_person_id);


/*
--insert into sample a values ('v_tot_srv2 is '||v_tot_srv);

v_dt := SYSDATE;
v_strt_dt := NULL;
OPEN c_srv(v_dt);
FETCH c_srv INTO v_strt_dt,v_srv;
CLOSE c_srv;
v_tot_srv :=  v_srv;
v_dt := v_strt_dt - 1;


WHILE v_tot_srv < 6
  LOOP
    v_strt_dt := NULL;
    OPEN c_srv(v_dt);
    FETCH c_srv INTO v_strt_dt,v_srv;
    CLOSE c_srv;

    IF v_strt_dt IS NULL THEN
      EXIT;
    ELSE
      v_tot_srv := v_tot_srv + v_srv;
      v_dt := v_strt_dt - 1;
    END IF;
  END LOOP;

--insert into sample a values ('v_tot_srv4 is '||v_tot_srv||'v_dt is '||TO_CHAR(v_dt,'DD-MON-YYYY')||'v_strt_dt is '||TO_CHAR(v_strt_dt,'DD-MON-YYYY'));



OPEN c_strt_dt;
FETCH c_strt_dt INTO v_months_svc;
CLOSE c_strt_dt;

*/
IF v_tot_srv < 6 THEN
--IF v_months_svc < 6 THEN
   p_flag := 'F';
   --p_msg := 'Service is less than 6 months';
   p_msg := 'Lo sentimos, pero debes tener al menos 6 meses en la actual Razon Social (SAB) para poder solicitar un Prestamo';
END IF;

OPEN c_exists;
FETCH c_exists INTO v_person_id;
CLOSE c_exists;

IF v_person_id IS NOT NULL THEN
   p_flag := 'F';
   IF p_msg IS NULL THEN
     --p_msg := 'Loan already paid for this Year';
     p_msg := 'Solicitud denegada.  Por politica solamente puede solicitar 1 (un) credito por a?o, y ya se tiene registrada una solicitud previa';

   ELSE
     --p_msg := p_msg||'. And Loan already paid for this Year';
     p_msg := p_msg||chr(13)||chr(10)||'. Y Solicitud denegada.  Por politica solamente puede solicitar 1 (un) credito por a?o, y ya se tiene registrada una solicitud previa';
   END IF;
END IF;


OPEN c_asg_id;
FETCH c_asg_id INTO v_asg_id;
CLOSE c_asg_id;

v_tot_sav := ttec_mex_sav_fund.total_saving(v_asg_id);
v_tot_sav := (v_tot_sav * .8); -- 80% of total saving
v_ded_amt := ttec_mex_sav_fund.ded_amt(v_asg_id);

ttec_mex_sav_fund.pymt_rate1(p_loanamt,6,6,v_pymt_amt);


IF TO_NUMBER(p_loanamt) > NVL(v_tot_sav,0) THEN
   p_flag := 'F';
   IF p_msg IS NULL THEN
    -- p_msg := 'Loan Amount should be less than 80% Total Saving';
      p_msg := 'El monto solicitado como prestamo, excede el 80% de las Aportaciones actuales a su Fondo de Ahorro';
   ELSE
     --p_msg := p_msg||'. And Loan Amount should be less than 80% Total Saving';
     p_msg := p_msg||chr(13)||chr(10)||'. Y El monto solicitado como prestamo, excede el 80% de las Aportaciones actuales a su Fondo de Ahorro';
   END IF;

END IF;



IF TO_NUMBER(p_loanamt) < NVL(v_tot_sav,0) AND TO_NUMBER(NVL(v_pymt_amt,0)) > NVL(v_ded_amt,0) THEN

   p_flag := 'F';
   IF p_msg IS NULL THEN
    -- p_msg := 'Loan Amount should be less than 80% Total Saving';
      p_msg := 'El monto solicitado como prestamo, excede el 80% de las Aportaciones actuales a su Fondo de Ahorro';
   ELSE
     --p_msg := p_msg||'. And Loan Amount should be less than 80% Total Saving';
     p_msg := p_msg||chr(13)||chr(10)||'. Y El monto solicitado como prestamo, excede el 80% de las Aportaciones actuales a su Fondo de Ahorro';
   END IF;

END IF;



/*

IF TO_NUMBER(p_loanamt) > NVL(v_tot_sav,0) THEN
   p_flag := 'F';
   IF p_msg IS NULL THEN
    -- p_msg := 'Loan Amount should be less than 80% Total Saving';
      p_msg := 'El monto solicitado como prestamo, excede el 80% de las Aportaciones actuales a su Fondo de Ahorro';
   ELSE
     --p_msg := p_msg||'. And Loan Amount should be less than 80% Total Saving';
     p_msg := p_msg||'. And El monto solicitado como prestamo, excede el 80% de las Aportaciones actuales a su Fondo de Ahorro';
   END IF;

END IF;

IF TO_NUMBER(p_loanamt) > NVL(v_ded_amt,0) THEN
   p_flag := 'F';
   IF p_msg IS NULL THEN
     -- p_msg := 'Loan Amount should be less than Deduction Amount';
     p_msg := 'El prestamo no puede ser procesado, debido a que los importes quincenales excederian el monto maximo permitido para ser descontado por periodo de pago';
   ELSE
     --p_msg := p_msg||'. And Loan Amount should be less than Deduction Amount';
     p_msg := p_msg||'. And El prestamo no puede ser procesado, debido a que los importes quincenales excederian el monto maximo permitido para ser descontado por periodo de pago';
   END IF;

END IF;
*/

OPEN c_date;
FETCH c_date INTO v_date;
CLOSE c_date;

IF NVL(v_date,0) = 0 THEN

   p_flag := 'F';
   IF p_msg IS NULL THEN
     --p_msg := 'Loan is not requested between the first Monday in March and the last Monday in July.';
     p_msg := 'La Solicitud no puede ser procesada ya que la fecha actual esta fuera del periodo para solicitar Prestamos del Fondo de Ahorro';
   ELSE
     --p_msg := p_msg||'. And Loan is not requested between the first Monday in March and the last Monday in July.';
     p_msg := p_msg||chr(13)||chr(10)||'. Y La Solicitud no puede ser procesada ya que la fecha actual esta fuera del periodo para solicitar Prestamos del Fondo de Ahorro';
   END IF;


END IF;



EXCEPTION
 WHEN OTHERS THEN
   p_flag := 'F';
   p_msg := 'Exception in emp_chk';


END emp_chk_bk;




END ttec_mex_sav_fund;
/
show errors;
/