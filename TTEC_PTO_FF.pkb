create or replace PACKAGE BODY      ttec_pto_ff is
/********************************************************************************
    PACKAGE NAME:   ttec_pto_ff

    DESCRIPTION:    This package is called by PTO Fast formulas TTEC_PTO_HOURS function


    CREATED BY:     Elango Pandurangan

    DATE:           24-jun-2008

    ----------------
    MODIFICATION LOG
    ----------------


    DEVELOPER             DATE          DESCRIPTION
    -------------------   ------------  -----------------------------------------
    RXNETHI-ARGANO        12/MAY/23     R12.2 Upgrade Remediation
********************************************************************************/


FUNCTION ttec_pto(p_assignment_id IN NUMBER,p_date_earn IN DATE,p_payroll_id IN NUMBER,p_period_end_date IN DATE,p_term_date IN DATE) RETURN NUMBER IS

/********************************************************************************
    PROGRAM NAME:   ttec_ff_pto

    DESCRIPTION:    This function is returns PTO Hours, called by TTEC_PTO_HOURS ff

    INPUT      :   Assignment action id and Legislation code

    OUTPUT     :   hours

    CREATED BY:     Elango Pandurangan

    DATE:           24-jun-2008

    ----------------
    MODIFICATION LOG
    ----------------


    DEVELOPER             DATE          DESCRIPTION
    -------------------   ------------  -----------------------------------------

********************************************************************************/

v_pto_payout NUMBER;
v_pto_vac_adj NUMBER;
v_pto_vac NUMBER;
v_hours NUMBER;

CURSOR c_pto_vac IS
    SELECT SUM(TO_NUMBER(peeV.screen_entry_value))
    FROM per_all_assignments_f paaf,pay_element_entries_f peef,pay_element_entry_values_f peev,pay_input_values_f piv
    WHERE paaf.assignment_id = peef.assignment_id
    AND peev.element_entry_id = peef.element_entry_id
    AND peev.input_value_id = piv.input_value_id
    AND paaf.assignment_id = p_assignment_id
    AND peef.element_type_id IN (3215,611)  -- pto vacation taken 611
    AND piv.element_type_id IN (3215,611)  -- pto vacation taken 611
    AND piv.NAME = 'Hours'
    AND p_date_earn BETWEEN peef.effective_start_date AND peef.effective_end_date
    AND p_date_earn BETWEEN paaf.effective_start_date AND paaf.effective_end_date
        AND TRUNC (SYSDATE) BETWEEN piv.effective_start_date AND piv.effective_end_date ;

CURSOR c_pto_vac_adj IS
    SELECT SUM(TO_NUMBER(peeV.screen_entry_value))
    FROM per_all_assignments_f paaf,pay_element_entries_f peef,pay_element_entry_values_f peev,pay_input_values_f piv
    WHERE paaf.assignment_id = peef.assignment_id
    AND peev.element_entry_id = peef.element_entry_id
    AND peev.input_value_id = piv.input_value_id
    AND paaf.assignment_id = p_assignment_id
    AND peef.element_type_id IN (829,3226)  --  vacation adjustment 829 pto adj 3226
    AND piv.element_type_id IN (829,3226)  --  vacation adjustment 829 pto adj 3226
    AND piv.NAME = 'Hours'
    AND p_date_earn BETWEEN peef.effective_start_date AND peef.effective_end_date
    AND p_date_earn BETWEEN paaf.effective_start_date AND paaf.effective_end_date
        AND TRUNC (SYSDATE) BETWEEN piv.effective_start_date AND piv.effective_end_date ;

CURSOR c_pto_payout IS
    SELECT SUM(TO_NUMBER(peeV.screen_entry_value))
    FROM per_all_assignments_f paaf,pay_element_entries_f peef,pay_element_entry_values_f peev,pay_input_values_f piv
    WHERE paaf.assignment_id = peef.assignment_id
    AND peev.element_entry_id = peef.element_entry_id
    AND peev.input_value_id = piv.input_value_id
    AND paaf.assignment_id = p_assignment_id
    AND peef.element_type_id IN (7764)  --  TTEC_PTO_PAYOUT ID NEEDS TO CHANGED FROM PROD
    AND piv.element_type_id IN (7764)  --  TTEC_PTO_PAYOUT ID NEEDS TO CHANGED FROM PROD
    AND piv.NAME = 'Hours'
    AND p_date_earn BETWEEN peef.effective_start_date AND peef.effective_end_date
    AND p_date_earn BETWEEN paaf.effective_start_date AND paaf.effective_end_date
        AND TRUNC (SYSDATE) BETWEEN piv.effective_start_date AND piv.effective_end_date ;

BEGIN
  OPEN c_pto_vac;
   FETCH c_pto_vac INTO v_pto_vac;
  CLOSE c_pto_vac;

  OPEN c_pto_vac_adj;
   FETCH c_pto_vac_adj INTO v_pto_vac_adj;
  CLOSE c_pto_vac_adj;

  OPEN c_pto_payout;
   FETCH c_pto_payout INTO v_pto_payout;
  CLOSE c_pto_payout;


  IF p_payroll_id = 46 AND p_period_end_date = NVL(p_term_date,'31-DEC-4712') THEN  -- Percepta employee look term date. If it is equal to period end date dont subtract adjustment from PTO

       v_hours := 0 - NVL(v_pto_payout,0)  ;

  ELSE
     v_hours := NVL(v_pto_vac,0) - NVL(v_pto_vac_adj,0);
  END IF;



  RETURN(v_hours);


EXCEPTION
  WHEN OTHERS THEN
  v_hours := 9999.999;
  RETURN(v_hours);
END ttec_pto;


/********************************************************************************
    PROGRAM NAME:   ttec_pto_net_accrual

    DESCRIPTION:    This function is returns PTO Hours, called by TTEC_PTO_HOURS ff

    INPUT      :   Assignment action id and Legislation code

    OUTPUT     :   hours

    CREATED BY:     Elango Pandurangan

    DATE:           24-jun-2008

    ----------------
    MODIFICATION LOG
    ----------------


    DEVELOPER             DATE          DESCRIPTION
    -------------------   ------------  -----------------------------------------

********************************************************************************/
FUNCTION ttec_pto_net_accrual(p_assignment_id IN NUMBER,p_payroll_id IN NUMBER,p_business_group_id IN NUMBER,p_calculation_date IN DATE,p_term_date IN DATE) RETURN NUMBER IS


 v_start_date DATE;
 v_end_date   DATE;
 v_pay_start_date DATE;
 v_pay_end_date   DATE;
 v_calculation_date   DATE;
 v_Accrual_end_Date DATE;
 v_Accrual    NUMBER := 0;
 v_Net_Entitlement NUMBER := 0;

CURSOR c_pay_period IS
 SELECT start_date,end_date
 FROM per_time_periods_v
 WHERE p_term_date BETWEEN start_date AND end_date
 AND payroll_id = p_payroll_id;


BEGIN



IF p_term_date IS NOT NULL THEN
  OPEN c_pay_period;
  FETCH c_pay_period INTO v_pay_start_date,v_pay_end_date;
  CLOSE c_pay_period;
  IF v_pay_end_date = p_term_date THEN
    v_calculation_date := p_term_date;
  ELSE
   v_calculation_date := v_pay_start_date - 1;
  END IF;
ELSE
  v_calculation_date := p_calculation_date;
END IF;



PER_ACCRUAL_CALC_FUNCTIONS.Get_Net_Accrual
(p_assignment_id
,134
,p_payroll_id
,p_business_group_id
, -1
,v_calculation_date
,NULL
,NULL
,'FRM'
,v_start_date
,v_end_date
,v_Accrual_end_Date
,v_Accrual
,v_Net_Entitlement);


  RETURN(v_Net_Entitlement);


EXCEPTION
  WHEN OTHERS THEN
  v_Net_Entitlement := 9999.999;
  RETURN(v_Net_Entitlement);
END ttec_pto_net_accrual;


/********************************************************************************
    PROGRAM NAME:   ttec_pto_net_accrual

    DESCRIPTION:    This function is returns PTO Hours, called by TTEC_PTO_HOURS ff

    INPUT      :   Assignment action id and Legislation code

    OUTPUT     :   hours

    CREATED BY:     Elango Pandurangan

    DATE:           24-jun-2008

    ----------------
    MODIFICATION LOG
    ----------------


    DEVELOPER             DATE          DESCRIPTION
    -------------------   ------------  -----------------------------------------

********************************************************************************/

--PROCEDURE ttec_upd_element(p_bus_grp_id IN NUMBER,p_element_entry_id IN NUMBER,p_date IN DATE,p_value IN NUMBER) AS
FUNCTION ttec_upd_element(p_bus_grp_id IN NUMBER,p_element_entry_id IN NUMBER,p_date IN DATE,p_value IN NUMBER) RETURN NUMBER IS

 v_obj_ver pay_element_entries_f.object_version_number%TYPE;
 v_effective_start_date DATE;
 v_effective_end_date DATE;
 v_update_warning   BOOLEAN;
 V_ERR VARCHAR2(150);

 v_input pay_link_input_values_v.input_value_id%TYPE;

 CURSOR c_input IS
 SELECT pliv.input_value_id
 FROM pay_link_input_values_v pliv, pay_element_entries_f pel
 WHERE pliv.element_link_id = pel.element_link_id
 AND  pel.element_entry_id = p_element_entry_id
 AND pliv.name = 'Hours';


 CURSOR c_obj_ver IS
 SELECT object_version_number
 FROM pay_element_entries_f
 WHERE element_entry_id = p_element_entry_id;

BEGIN

  OPEN c_obj_ver;
  FETCH c_obj_ver INTO v_obj_ver;
  CLOSE c_obj_ver;

  OPEN c_input;
  FETCH c_input INTO v_input;
  CLOSE c_input;

PAY_ELEMENT_ENTRY_API.update_element_entry
  (p_validate                     => FALSE
  ,p_datetrack_update_mode        => 'CORRECTION'
  ,p_effective_date               => p_date
  ,p_business_group_id            => p_bus_grp_id
  ,p_element_entry_id             => p_element_entry_id
  ,p_object_version_number        => v_obj_ver
  ,p_input_value_id1              => v_input
  ,p_entry_value1                 => p_value
  ,p_effective_start_date         => v_effective_start_date
  ,p_effective_end_date           => v_effective_end_date
  ,p_update_warning               => v_update_warning
  );


RETURN(v_input);

EXCEPTION
WHEN OTHERS THEN
  v_err := substr(sqlerrm,1,50);
 RETURN(0);
END ttec_upd_element;

FUNCTION ttec_pop_sick_term(p_asg_id IN NUMBER,p_payroll_id IN NUMBER,p_business_group_id IN NUMBER, p_date_earned IN DATE,p_period_end_date IN DATE,p_term_date IN DATE,p_value IN NUMBER) RETURN NUMBER IS

 v_start_date DATE;
 v_end_date   DATE;
 v_pay_start_date DATE;
 v_pay_end_date   DATE;
 v_calculation_date   DATE;
 v_Accrual_end_Date DATE;
 v_Accrual    NUMBER := 0;
 v_Net_Entitlement NUMBER := 0;
 v_sick_adj NUMBER :=0;
 v_sick_taken NUMBER :=0;
 v_unused NUMBER := 0;
 v_hrs_input_value NUMBER ;
 v_eed_input_value NUMBER;
 v_sick_term  NUMBER := 0;


  v_effective_start_date             DATE;
  v_effective_end_date               DATE;
  v_element_entry_id                 NUMBER;
  v_object_version_number            NUMBER;
  v_create_warning                   BOOLEAN;

 V_ERR VARCHAR2(150);


CURSOR c_pay_period IS
 SELECT start_date,end_date
 FROM per_time_periods_v
 WHERE p_term_date BETWEEN start_date AND end_date
 AND payroll_id = p_payroll_id;

 CURSOR c_sick_taken IS
    SELECT SUM(TO_NUMBER(peeV.screen_entry_value))
    FROM per_all_assignments_f paaf,pay_element_entries_f peef,pay_element_entry_values_f peev,pay_input_values_f piv
    WHERE paaf.assignment_id = peef.assignment_id
    AND peev.element_entry_id = peef.element_entry_id
    AND peev.input_value_id = piv.input_value_id
    AND paaf.assignment_id =  p_asg_id
    AND peef.element_type_id = 589  -- 589 FOR Sick Taken
    AND piv.element_type_id = 589  -- 589 FOR Sick Taken
    AND piv.NAME = 'Hours'
    AND v_calculation_date BETWEEN peef.effective_start_date AND peef.effective_end_date
    AND v_calculation_date  BETWEEN paaf.effective_start_date AND paaf.effective_end_date
    AND TRUNC (SYSDATE) BETWEEN piv.effective_start_date AND piv.effective_end_date ;

 CURSOR c_sick_adj IS
    SELECT SUM(TO_NUMBER(peeV.screen_entry_value))
    FROM per_all_assignments_f paaf,pay_element_entries_f peef,pay_element_entry_values_f peev,pay_input_values_f piv
    WHERE paaf.assignment_id = peef.assignment_id
    AND peev.element_entry_id = peef.element_entry_id
    AND peev.input_value_id = piv.input_value_id
    AND paaf.assignment_id =  p_asg_id
    AND peef.element_type_id = 814  --  814 Sick Adjustment
    AND piv.element_type_id =  814  --  814 Sick Adjustment
    AND piv.NAME = 'Hours'
    AND v_calculation_date BETWEEN peef.effective_start_date AND peef.effective_end_date
    AND v_calculation_date  BETWEEN paaf.effective_start_date AND paaf.effective_end_date
    AND TRUNC (SYSDATE) BETWEEN piv.effective_start_date AND piv.effective_end_date ;


 CURSOR c_hrs_input_value IS
 SELECT input_value_id
 FROM pay_input_values_f  pliv
 where name = 'Hours'
 and element_type_id = 8224;  -- 8224 FOR SICK TERMINATION ELEMENT TYPE was 8124 in HRDEV

  CURSOR c_eed_input_value IS
 SELECT input_value_id
 FROM pay_input_values_f  pliv
 where name = 'Entry Effective Date'
 and element_type_id = 8224;  -- 8224 FOR SICK TERMINATION ELEMENT TYPE was 8124 in HRDEV

   CURSOR c_sick_term IS
    SELECT SUM(TO_NUMBER(peeV.screen_entry_value))
    FROM per_all_assignments_f paaf,pay_element_entries_f peef,pay_element_entry_values_f peev,pay_input_values_f piv
    WHERE paaf.assignment_id = peef.assignment_id
    AND peev.element_entry_id = peef.element_entry_id
    AND peev.input_value_id = piv.input_value_id
    AND paaf.assignment_id = p_asg_id
    AND peef.element_type_id =  8224  -- 8224 FOR SICK TERMINATION ELEMENT TYPE was 8124 in HRDEV
    AND piv.element_type_id =  8224  -- 8224 FOR SICK TERMINATION ELEMENT TYPE was 8124 in HRDEV
    AND piv.NAME = 'Hours'
    AND p_term_date BETWEEN peef.effective_start_date AND peef.effective_end_date
    AND p_term_date BETWEEN paaf.effective_start_date AND paaf.effective_end_date
        AND TRUNC (SYSDATE) BETWEEN piv.effective_start_date AND piv.effective_end_date ;


BEGIN



  OPEN c_sick_term;
  FETCH c_sick_term INTO v_sick_term;
  CLOSE c_sick_term;
  IF NVL(v_sick_term,0) = 0 THEN
   -- Get net previous period net entitlement value 236 for Sick Plan PCTA

          OPEN c_pay_period;
          FETCH c_pay_period INTO v_pay_start_date,v_pay_end_date;
          CLOSE c_pay_period;

           v_calculation_date := v_pay_start_date - 1;

               --  Needs to changed in PROD for Sick Plan PCTA plan id 236. It is for PCTA

                PER_ACCRUAL_CALC_FUNCTIONS.Get_Net_Accrual
                (p_asg_id
                ,236
                ,p_payroll_id
                ,p_business_group_id
                , -1
                ,v_calculation_date
                ,NULL
                ,NULL
                ,'FRM'
                ,v_start_date
                ,v_end_date
                ,v_Accrual_end_Date
                ,v_Accrual
                ,v_Net_Entitlement);


                   OPEN c_sick_taken;
                   FETCH c_sick_taken INTO v_sick_taken;
                   CLOSE c_sick_taken;




                    OPEN c_sick_adj;
                    FETCH c_sick_adj INTO v_sick_adj;
                    CLOSE c_sick_adj;




                  -- v_unused := NVL(v_Net_Entitlement,0) - (NVL(v_sick_adj,0) - NVL(v_sick_taken,0));

                  v_unused :=  NVL(v_Net_Entitlement,0)+(NVL(v_sick_adj,0) - NVL(v_sick_taken,0));




                    IF v_unused <> 0 THEN

                        OPEN c_hrs_input_value;
                        FETCH c_hrs_input_value INTO v_hrs_input_value;
                        CLOSE c_hrs_input_value;


                        OPEN c_eed_input_value;
                        FETCH c_eed_input_value INTO v_eed_input_value;
                        CLOSE c_eed_input_value;

               --  Needs to changed in PROD for Sick Termination Element Link id  7426

                        PAY_ELEMENT_ENTRY_API.create_element_entry
                          (p_validate                     => FALSE
                          ,p_effective_date               => p_term_date
                          ,p_business_group_id            => p_business_group_id
                          ,p_assignment_id                => p_asg_id
                          ,p_element_link_id              => 7426
                          ,p_entry_type                   => 'E'
                          ,p_date_earned                  => p_term_date
                          ,p_input_value_id1              => v_hrs_input_value
                          ,p_entry_value1                 => v_unused
                          ,p_input_value_id2              => v_eed_input_value
                          ,p_entry_value2                 => p_term_date
                          ,p_effective_start_date         =>  v_effective_start_date
                          ,p_effective_end_date          => v_effective_end_date
                          ,p_element_entry_id            => v_element_entry_id
                          ,p_object_version_number       => v_object_version_number
                          ,p_create_warning              => v_create_warning
                          );


                    END IF;

    END IF;
RETURN(1);



EXCEPTION
  WHEN OTHERS THEN
   V_ERR := SUBSTR(SQLERRM,1,30);

    RETURN(0);
END ttec_pop_sick_term;


--FUNCTION ttec_pop_payout(p_asg_id IN NUMBER,_business_group_id IN NUMBER, p_date_earned IN DATE,p_term_dt IN DATE,p_net IN NUMBER) RETURN NUMBER IS
FUNCTION ttec_pop_payout(p_person_id IN NUMBER,p_business_group_id IN NUMBER,p_act_term_dt IN DATE) RETURN NUMBER IS


v_asg_id per_all_assignments_f.assignment_id%TYPE;
v_payroll_id per_all_assignments_f.payroll_id%TYPE;
v_start_date  DATE;
v_end_date    DATE;
v_Accrual_end_Date DATE;
v_Accrual     NUMBER;
v_Net_Entitlement NUMBER;



 v_pay_start_date DATE;
 v_pay_end_date   DATE;
 v_pto_payout NUMBER := 0;
 v_hrs_input_value NUMBER := 0;
 v_eed_input_value NUMBER := 0;
 v_asg_act_id  pay_assignment_actions.assignment_action_id%TYPE;

  v_effective_start_date             DATE;
  v_effective_end_date               DATE;
  v_element_entry_id                 NUMBER;
  v_object_version_number            NUMBER;
  v_create_warning                   BOOLEAN;





 CURSOR c_hrs_input_value IS
 SELECT input_value_id
 FROM pay_input_values_f  pliv
 WHERE name = 'Hours'
 AND element_type_id = 3191;   -- Important :  needs to change from PTO PAYOUT (3191) id in PRODUCTION

  CURSOR c_eed_input_value IS
 SELECT input_value_id
 FROM pay_input_values_f  pliv
 WHERE name = 'Entry Effective Date'
 AND element_type_id = 3191;   -- Important :  needs to change from PTO PAYOUT (3191) id in PRODUCTION

CURSOR c_asg_id IS
SELECT paaf.assignment_id,paaf.payroll_id
FROM per_all_assignments_f paaf
WHERE paaf.person_id = p_person_id
AND p_act_term_dt BETWEEN paaf.effective_start_date AND paaf.effective_end_date;



BEGIN

OPEN c_asg_id;
FETCH c_asg_id INTO v_asg_id,v_payroll_id;
CLOSE c_asg_id;

PER_ACCRUAL_CALC_FUNCTIONS.Get_Net_Accrual
(v_asg_id
,134
,v_payroll_id
,p_business_group_id
, -1
,p_act_term_dt
,NULL
,NULL
,'FRM'
,v_start_date
,v_end_date
,v_Accrual_end_Date
,v_Accrual
,v_Net_Entitlement);

IF v_Net_Entitlement <> 0 THEN

            OPEN c_hrs_input_value;
            FETCH c_hrs_input_value INTO v_hrs_input_value;
            CLOSE c_hrs_input_value;

            OPEN c_eed_input_value;
            FETCH c_eed_input_value INTO v_eed_input_value;
            CLOSE c_eed_input_value;
          BEGIN
            /*
           Important : Element Link id needs to changed in production,
             we are using PTO PAYOUT element link id 7513
            */
            PAY_ELEMENT_ENTRY_API.create_element_entry
              (p_validate                     => FALSE
              ,p_effective_date               => p_act_term_dt
              ,p_business_group_id            => p_business_group_id
              ,p_assignment_id                => v_asg_id
              ,p_element_link_id              => 7513
              ,p_entry_type                   => 'E'
              ,p_date_earned                  => p_act_term_dt
              ,p_input_value_id1              => v_hrs_input_value
              ,p_entry_value1                 => v_Net_Entitlement
              ,p_input_value_id2              => v_eed_input_value
              ,p_entry_value2                 => p_act_term_dt
              ,p_effective_start_date         =>  v_effective_start_date
              ,p_effective_end_date          => v_effective_end_date
              ,p_element_entry_id            => v_element_entry_id
              ,p_object_version_number       => v_object_version_number
              ,p_create_warning              => v_create_warning
              );

            EXCEPTION
            WHEN OTHERS THEN
              RETURN(0);
            END;

END IF;


RETURN(0);
EXCEPTION
    WHEN OTHERS THEN
        RETURN(0);
END ttec_pop_payout;


FUNCTION ttec_remove_payout(p_person_id IN NUMBER,p_business_group_id IN NUMBER,p_act_term_dt IN DATE) RETURN NUMBER IS

  v_effective_start_date             date;
  v_effective_end_date               date;
  v_object_version_number            pay_element_entries_f.object_version_number%TYPE;
  v_delete_warning                   boolean;
  v_asg_id                           per_all_assignments_f.assignment_id%TYPE;
  v_element_entry_id                 pay_element_entries_f.element_entry_id%TYPE;

  v_err VARCHAR2(200);
  CURSOR c_asg_id IS
  SELECT paaf.assignment_id
  FROM per_all_assignments_f paaf
  WHERE person_id = p_person_id
  AND p_act_term_dt BETWEEN paaf.effective_start_date AND effective_end_date;



  CURSOR c_ele_entry IS
   SELECT element_entry_id,object_version_number
   FROM pay_element_entries_f
   WHERE assignment_id = v_asg_id
   AND date_earned = p_act_term_dt
   AND element_type_id = 3191;   -- Important :  needs to change from PTO PAYOUT (3191) id in PRODUCTION

BEGIN
  OPEN c_asg_id;
  FETCH c_asg_id INTO v_asg_id;
  CLOSE c_asg_id;

  OPEN c_ele_entry;
  FETCH c_ele_entry INTO v_element_entry_id,v_object_version_number;
  CLOSE c_ele_entry;


  IF v_element_entry_id IS NOT NULL THEN
        PAY_ELEMENT_ENTRY_API.delete_element_entry
          (p_validate                     => FALSE
          ,p_datetrack_delete_mode        => 'ZAP'
          ,p_effective_date               => p_act_term_dt
          ,p_element_entry_id             => v_element_entry_id
          ,p_object_version_number        => v_object_version_number
          ,p_effective_start_date         => v_effective_start_date
          ,p_effective_end_date           => v_effective_end_date
          ,p_delete_warning               => v_delete_warning
          );
  END IF;

  RETURN(1);
EXCEPTION
    WHEN OTHERS THEN
      RETURN(0);
END ttec_remove_payout;



/*
PROCEDURE ttec_pop_payout(p_person_id IN NUMBER,p_business_group_id IN NUMBER,p_act_term_dt IN DATE) IS


v_asg_id per_all_assignments_f.assignment_id%TYPE;
v_payroll_id per_all_assignments_f.payroll_id%TYPE;
v_start_date  DATE;
v_end_date    DATE;
v_Accrual_end_Date DATE;
v_Accrual     NUMBER;
v_Net_Entitlement NUMBER;

CURSOR c_asg_id IS
SELECT paaf.assignment_id,paaf.payroll_id
FROM per_all_assignments_f paaf
WHERE paaf.person_id = p_person_id
AND p_act_term_dt BETWEEN paaf.effective_start_date AND paaf.effective_end_date;

v_err VARCHAR2(500);

BEGIN

OPEN c_asg_id;
FETCH c_asg_id INTO v_asg_id,v_payroll_id;
CLOSE c_asg_id;
insert into sample a values ('p_person_id' ||p_person_id||' p bus grp '||p_business_group_id||'p_act_term_dt '||p_act_term_dt||' asg id '||v_asg_id||' v_payroll_id '||v_payroll_id);
PER_ACCRUAL_CALC_FUNCTIONS.Get_Net_Accrual
(v_asg_id
,134
,v_payroll_id
,p_business_group_id
, -1
,p_act_term_dt
,NULL
,NULL
,'FRM'
,v_start_date
,v_end_date
,v_Accrual_end_Date
,v_Accrual
,v_Net_Entitlement);

INSERT INTO SAMPLE A VALUES (' V NET IS '||v_Net_Entitlement);


EXCEPTION
    WHEN OTHERS THEN
     v_err := SUBSTR(SQLERRM,1,100);
INSERT INTO SAMPLE A VALUES (' exe '||V_ERR);

END ttec_pop_payout;


*/

FUNCTION ttec_get_emp_category(p_asg_id IN NUMBER,p_effective_dt IN DATE) RETURN VARCHAR2 IS

 v_category per_all_assignments_f.employment_category%TYPE;

 CURSOR c_cat IS
 SELECT employment_category
 FROM per_all_assignments_f
 WHERE assignment_id = p_asg_id
 AND p_effective_dt BETWEEN effective_start_date AND effective_end_date;

BEGIN
 OPEN c_cat;
 FETCH c_cat INTO v_category;
 CLOSE c_cat;
 RETURN v_category;
EXCEPTION
WHEN OTHERS THEN
  v_category := NULL;
  RETURN v_category;
END ttec_get_emp_category;

FUNCTION ttec_adj_payout(p_asg_id IN NUMBER,p_business_group_id IN NUMBER,p_term_dt IN DATE) RETURN NUMBER IS

   v_adj_value  NUMBER := 0;
   v_payout_value NUMBER := 0;
   v_net NUMBER := 0;
   v_payout_dt  DATE := '31-DEC-4712';
   v_err VARCHAR2(100);
   v_element_entry_id pay_element_entries_f.element_entry_id%TYPE := NULL;
   v_object_version_number pay_element_entries_f.object_version_number%TYPE := NULL;
   v_input pay_link_input_values_v.input_value_id%TYPE;
     v_effective_start_date DATE;
     v_effective_end_date DATE;
     v_update_warning   BOOLEAN;


    CURSOR c_payout_dt IS
    SELECT peef.element_entry_id,peef.object_version_number,MAX(peef.last_update_date)
    FROM pay_element_entries_f peef
    WHERE peef.assignment_id = p_asg_id
    AND  peef.element_type_id = 3191   -- Important :  needs to change from PTO PAYOUT (3191) id in PRODUCTION
    GROUP BY  peef.element_entry_id,peef.object_version_number ;


    CURSOR c_adj_value IS
    SELECT SUM(TO_NUMBER(peev.screen_entry_value))
    FROM per_all_assignments_f paaf,pay_element_entries_f peef,pay_element_entry_values_f peev,pay_input_values_f piv
    WHERE paaf.assignment_id = peef.assignment_id
    AND peev.element_entry_id = peef.element_entry_id
    AND peev.input_value_id = piv.input_value_id
    AND paaf.assignment_id =  p_asg_id
    AND peef.element_type_id = 3226   -- PTO Adjustment
    AND piv.element_type_id =  3226   -- PTO Adjustment
    AND piv.NAME = 'Hours'
    AND peef.last_update_Date > v_payout_dt
   AND SYSDATE BETWEEN paaf.effective_start_date AND paaf.effective_end_date;

    CURSOR c_payout_value IS
    SELECT SUM(TO_NUMBER(peev.screen_entry_value))
    FROM per_all_assignments_f paaf,pay_element_entries_f peef,pay_element_entry_values_f peev,pay_input_values_f piv
    WHERE paaf.assignment_id = peef.assignment_id
    AND peev.element_entry_id = peef.element_entry_id
    AND peev.input_value_id = piv.input_value_id
    AND paaf.assignment_id =  p_asg_id
    AND peef.element_type_id = 3191   -- Important :  needs to change from PTO PAYOUT (3191) id in PRODUCTION
    AND piv.element_type_id =  3191   -- Important :  needs to change from PTO PAYOUT (3191) id in PRODUCTION
    AND piv.NAME = 'Hours'
   AND SYSDATE BETWEEN paaf.effective_start_date AND paaf.effective_end_date;

 CURSOR c_input IS
 SELECT pliv.input_value_id
 FROM pay_link_input_values_v pliv, pay_element_entries_f pel
 WHERE pliv.element_link_id = pel.element_link_id
 AND  pel.element_entry_id = v_element_entry_id
 AND pliv.name = 'Hours';

BEGIN

  IF p_term_dt <> '31-DEC-4712' THEN

        OPEN c_payout_dt;
        FETCH c_payout_dt INTO v_element_entry_id,v_object_version_number,v_payout_dt;
        CLOSE c_payout_dt;

        OPEN c_input;
        FETCH c_input INTO v_input;
        CLOSE c_input;

        OPEN c_adj_value;
        FETCH c_adj_value INTO v_adj_value;
        CLOSE c_adj_value;

        OPEN c_payout_value;
        FETCH c_payout_value INTO v_payout_value;
        CLOSE c_payout_value;


        IF NVL(v_adj_value,0) <> 0 AND NVL(v_payout_value,0) <> 0 THEN

        v_net := NVL(v_payout_value,0) + NVL(v_adj_value,0);
          BEGIN
                PAY_ELEMENT_ENTRY_API.update_element_entry
                  (p_validate                     => FALSE
                  ,p_datetrack_update_mode        => 'CORRECTION'
                  ,p_effective_date               => p_term_dt
                  ,p_business_group_id            => p_business_group_id
                  ,p_element_entry_id             => v_element_entry_id
                  ,p_object_version_number        => v_object_version_number
                  ,p_input_value_id1              => v_input
                  ,p_entry_value1                 => v_net
                  ,p_effective_start_date         => v_effective_start_date
                  ,p_effective_end_date           => v_effective_end_date
                  ,p_update_warning               => v_update_warning
                  );

          EXCEPTION
              WHEN OTHERS THEN
                  v_err := SUBSTR(SQLERRM,1,50);

                  RETURN(0);
          END;

        END IF;
    RETURN v_net;

  ELSE
    RETURN(0);
  END IF;

EXCEPTION
    WHEN OTHERS THEN
    v_err := SUBSTR(SQLERRM,1,50);

    RETURN(0);
END ttec_adj_payout;


FUNCTION ttec_validate_adj(p_asg_id IN NUMBER,p_adj_value IN NUMBER) RETURN NUMBER IS

    v_person_id  per_all_people_f.person_id%TYPE := NULL;
    v_business_group_id per_all_people_f.business_group_id%TYPE := NULL;
    v_term_dt DATE := NULL;
    v_term_upd_dt DATE := NULL;
    v_payout_elmnt_entry_id pay_element_entries_f.element_entry_id%TYPE;
    v_object_version_number pay_element_entries_f.object_version_number%TYPE;
    v_input pay_link_input_values_v.input_value_id%TYPE;
    v_last_update_date  pay_element_entries_f.last_update_date%TYPE;
    V_ERR VARCHAR2(200);
    v_payout_value NUMBER := 0;
    v_adj_value    NUMBER := 0;
    v_net         NUMBER := 0;
    v_adj_amt    NUMBER;

      v_effective_start_date DATE;
      v_effective_end_date DATE;
      v_update_warning   BOOLEAN;



     CURSOR c_person_id IS
        SELECT DISTINCT papf.person_id,papf.business_group_id
        FROM per_all_assignments_f paaf,per_all_people_f papf
        WHERE papf.person_id = paaf.person_id
        AND SYSDATE BETWEEN papf.effective_start_date AND papf.effective_end_date
        AND paaf.assignment_id = p_asg_id;

     CURSOR c_term_dt IS
      SELECT ppos.actual_termination_date,ppos.last_update_date
      FROM per_periods_of_service ppos
      WHERE ppos.person_id = v_person_id
      AND ppos.period_of_service_id IN (SELECT MAX( ppos1.period_of_service_id) FROM per_periods_of_service ppos1 WHERE ppos1.person_id = v_person_id);

     CURSOR c_payout_dtl IS
        SELECT peef.element_entry_id,peef.object_version_number
        FROM pay_element_entries_f peef
        WHERE peef.assignment_id = p_asg_id
        AND  peef.element_type_id = 3191;   -- Important :  needs to change from PTO PAYOUT (3191) id in PRODUCTION

      CURSOR c_input IS
         SELECT pliv.input_value_id
         FROM pay_link_input_values_v pliv, pay_element_entries_f pel
         WHERE pliv.element_link_id = pel.element_link_id
         AND  pel.element_entry_id = v_payout_elmnt_entry_id
         AND pliv.name = 'Hours';

    CURSOR c_payout_value IS
        SELECT SUM(TO_NUMBER(peev.screen_entry_value))
        FROM per_all_assignments_f paaf,pay_element_entries_f peef,pay_element_entry_values_f peev,pay_input_values_f piv
        WHERE paaf.assignment_id = peef.assignment_id
        AND peev.element_entry_id = peef.element_entry_id
        AND peev.input_value_id = piv.input_value_id
        AND paaf.assignment_id =  p_asg_id
        AND peef.element_type_id = 3191   -- Important :  needs to change from PTO PAYOUT (3191) id in PRODUCTION
        AND piv.element_type_id =  3191   -- Important :  needs to change from PTO PAYOUT (3191) id in PRODUCTION
        AND piv.NAME = 'Hours'
        AND SYSDATE BETWEEN paaf.effective_start_date AND paaf.effective_end_date;

   CURSOR c_exist IS
     SELECT adj_amt
     FROM ttec_pto_adjust
     WHERE assignment_id = p_asg_id;

BEGIN


    OPEN c_exist;
    FETCH c_exist INTO v_adj_amt;
    CLOSE c_exist;

    IF NVL(v_adj_amt,0) <> p_adj_value THEN
        INSERT INTO ttec_pto_adjust(assignment_id,adj_amt) VALUES (p_asg_id,p_adj_value);

        OPEN c_person_id;
        FETCH c_person_id INTO v_person_id,v_business_group_id;
        CLOSE c_person_id;

        OPEN c_term_dt;
        FETCH c_term_dt INTO v_term_dt,v_term_upd_dt;
        CLOSE c_term_dt;

        IF v_term_dt IS NOT NULL AND sysdate > v_term_upd_dt  THEN

            OPEN c_payout_dtl;
            FETCH c_payout_dtl INTO v_payout_elmnt_entry_id,v_object_version_number;
            CLOSE c_payout_dtl;

            IF v_payout_elmnt_entry_id IS NOT NULL THEN

                OPEN c_input;
                FETCH c_input INTO v_input;
                CLOSE c_input;

                OPEN c_payout_value;
                FETCH c_payout_value INTO v_payout_value;
                CLOSE c_payout_value;

                IF NVL(v_payout_value,0) <> 0 AND NVL(p_adj_value,0) <> 0 THEN

                   v_net := NVL(v_payout_value,0) + NVL(p_adj_value,0);
                   IF NVL(v_net,0) <> 0 THEN
                         BEGIN
                              PAY_ELEMENT_ENTRY_API.update_element_entry
                                  (p_validate                     => FALSE
                                  ,p_datetrack_update_mode        => 'CORRECTION'
                                  ,p_effective_date               => v_term_dt
                                  ,p_business_group_id            => v_business_group_id
                                  ,p_element_entry_id             => v_payout_elmnt_entry_id
                                  ,p_object_version_number        => v_object_version_number
                                  ,p_input_value_id1              => v_input
                                  ,p_entry_value1                 => v_net
                                  ,p_effective_start_date         => v_effective_start_date
                                  ,p_effective_end_date           => v_effective_end_date
                                  ,p_update_warning               => v_update_warning
                                  );
                          EXCEPTION
                              WHEN OTHERS THEN
                                RETURN(0);
                          END;


                   END IF; -- V net end if
                END IF; -- Payout value end if
            END IF; -- Payout elmnt entry id end if
        END IF; -- Term dt end if
    END IF; -- V_exist end if
   RETURN(1);
EXCEPTION
   WHEN OTHERS THEN
    v_err := SUBSTR(SQLERRM,1,100);

    RETURN(0);
END ttec_validate_adj;

PROCEDURE ttec_validate_adj (ov_errbuf   OUT VARCHAR2,
                            ov_retcode   OUT NUMBER,
                            p_mode   IN VARCHAR2,
                            p_batch_id IN VARCHAR2) IS

 v_num NUMBER;
 v_err VARCHAR2(200);
BEGIN

 v_num := p_batch_id;

/*
v_request_id :=  fnd_request.submit_request (
--
        'PER',
        'PAYLINK(PURGE)',
        null,
        null,
        null,
        p_business_group_id,
        'PURGE',
        p_batch_id);
*/

EXCEPTION
   WHEN OTHERS THEN
    v_err := SUBSTR(SQLERRM,1,100);

END ttec_validate_adj;

FUNCTION ttec_get_asg_status(p_asg_id IN NUMBER,p_effective_dt IN DATE) RETURN NUMBER IS

 v_status_id per_all_assignments_f.assignment_status_type_id%TYPE;
 v_error varchar(80);

 CURSOR c_asg_status IS
 SELECT assignment_status_type_id
 FROM per_all_assignments_f
 WHERE ASSIGNMENT_ID = p_asg_id
 AND p_effective_dt BETWEEN effective_start_date AND effective_end_date;

BEGIN
 OPEN c_asg_status;
 FETCH c_asg_status INTO v_status_id;
 CLOSE c_asg_status;
 RETURN v_status_id;
EXCEPTION
WHEN OTHERS THEN
  v_status_id := 0;
  -- v_error := SQLCODE;
 -- insert into cust.ttec_wasim (field1, field2) values  ( v_error, 'bb')   ;
  RETURN v_status_id;
END ttec_get_asg_status;


FUNCTION ttec_exec_member(p_asg_id IN NUMBER) RETURN VARCHAR2 IS

v_emp_num per_all_people_f.employee_number%TYPE;


CURSOR c_exec IS
SELECT ppl.employee_number
FROM   per_all_people_f ppl,
       per_all_assignments_f asg,
       per_jobs pjs,
       (SELECT *
        --FROM  applsys.fnd_flex_values --code commented by RXNETHI-ARGANO,12/05/23
		FROM  apps.fnd_flex_values --code added by RXNETHI-ARGANO,12/05/23
        WHERE flex_value_set_id = 1007568) ffv2,
      (SELECT *
        --FROM applsys.fnd_flex_values_tl --code commented by RXNETHI-ARGANO,12/05/23
		FROM apps.fnd_flex_values_tl --code added by RXNETHI-ARGANO,12/05/23
        WHERE LANGUAGE = 'US') fvt2
WHERE Trunc(SYSDATE) BETWEEN ppl.effective_start_date AND ppl.effective_end_date
AND   ppl.current_employee_flag = 'Y'
AND   ppl.person_id = asg.person_id
AND   Trunc(SYSDATE) BETWEEN asg.effective_start_date AND asg.effective_end_date
AND   pjs.job_id = asg.job_id
AND   pjs.attribute6 = ffv2.flex_value(+)
AND   ffv2.flex_value_id = fvt2.flex_value_id(+)
AND   ffv2.attribute20 < 30
AND ppl.business_group_id <> 0
AND asg.assignment_id = p_asg_id;


BEGIN

OPEN c_exec;
FETCH c_exec INTO v_emp_num;
CLOSE c_exec;

IF v_emp_num IS NOT NULL THEN
   RETURN('Y');
ELSE
   RETURN('N');
END IF;


EXCEPTION
  WHEN OTHERS THEN
      RETURN('N');
END ttec_exec_member;


FUNCTION ttec_accr_state(p_asg_id IN NUMBER) RETURN VARCHAR2 IS

v_loc hr_locations_all.region_2%TYPE;
v_wah per_all_assignments_f.work_at_home%TYPE;
v_person_id per_all_people_f.person_id%TYPE;
v_lookup fnd_lookup_values.lookup_code%TYPE;
v_adr_st hr_locations_all.region_2%TYPE;

CURSOR c_loc IS
SELECT l.region_2
FROM per_all_assignments_f paaf, hr_locations_all l
WHERE paaf.location_id = l.location_id
AND paaf.assignment_id = p_asg_id
AND SYSDATE BETWEEN paaf.effective_start_date AND paaf.effective_end_date;

CURSOR c_lookup(p_loc VARCHAR2) IS
SELECT 'Y'
FROM fnd_lookup_values flv
WHERE flv.lookup_type = 'PTO_TERM_EXCEPTION_STATE'
AND flv.language='US'
AND flv.lookup_code = p_loc;

CURSOR c_wah IS
SELECT work_at_home,papf.person_id
FROM per_all_assignments_f paaf,per_all_people_f papf
WHERE paaf.person_id = papf.person_id
AND assignment_id = p_asg_id
AND SYSDATE BETWEEN papf.effective_start_date AND papf.effective_end_date
AND SYSDATE BETWEEN paaf.effective_start_date AND paaf.effective_end_date;


CURSOR c_adr_st IS
SELECT region_2
FROM per_addresses_v a
WHERE a.person_id = v_person_id
AND a.primary_flag = 'Y'
AND a.date_from IN (SELECT MAX(b.date_from) FROM per_addresses_v b WHERE b.person_id = a.person_id);


BEGIN

    OPEN c_loc;
    FETCH c_loc INTO v_loc;
    CLOSE c_loc;

    OPEN c_lookup(v_loc);
    FETCH c_lookup INTO v_lookup;
    CLOSE c_lookup;

    IF v_lookup IS NULL THEN

        OPEN c_wah;
        FETCH c_wah INTO v_wah,v_person_id;
        CLOSE c_wah;

        IF NVL(v_wah,'x') = 'Y' THEN

            OPEN c_adr_st;
            FETCH c_adr_st INTO v_adr_st;
            CLOSE c_adr_st;

            IF v_adr_st IS NOT NULL THEN

                OPEN c_lookup(v_adr_st);
                FETCH c_lookup INTO v_lookup;
                CLOSE c_lookup;


            END IF;
        ELSE
          v_lookup := 'N';

        END IF;

    END IF;

RETURN v_lookup;

EXCEPTION
  WHEN OTHERS THEN
    RETURN('N');
END ttec_accr_state;


END ttec_pto_ff;
/
show errors;
/