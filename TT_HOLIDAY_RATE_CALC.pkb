create or replace PACKAGE BODY Tt_Holiday_Rate_Calc   IS






/************************************************************************************
        Program Name:   TT_HOLIDAY_RATE_CALC

        Description:   

        Developed by : 
        Date         :  

       Modification Log
       Name                  Version #    Date            Description
       -----                 --------     -----           -------------
    RXNETHI(ARGANO)            1.0      29-JUN-2023      R12.2 Upgrade Remediation
    ****************************************************************************************/






FUNCTION get_rate (
                          P_PERIOD_END_DATE IN DATE, P_ASSIGNMENT_NUMBER IN VARCHAR2 ) RETURN NUMBER IS

l_rate                    NUMBER;


CURSOR cur_main   IS
(SELECT
  SUM(bd.balance_value)  rate
FROM
 apps.xkb_balance_details bd,
 apps.xkb_balances bb,
 --hr.pay_balance_types bt,   --code commented by RXNETHI-ARGANO,29/06/23
 apps.pay_balance_types bt,   --code added by RXNETHI-ARGANO,29/06/23
 --hr.per_all_assignments_f paaf  --code commented by RXNETHI-ARGANO,29/06/23
 apps.per_all_assignments_f paaf  --code added by RXNETHI-ARGANO,29/06/23
WHERE
 bt.balance_name = 'Holiday Eligible Wages'
 AND bt.balance_type_id = bd.balance_type_id
 AND bd.assignment_action_id = bb.assignment_action_id
 AND TRUNC(bb.date_earned) BETWEEN p_period_end_date - 35 AND  p_period_end_date - 5
 AND bb.person_id = paaf.person_id
 AND paaf.assignment_type = 'E'
 AND paaf.primary_flag = 'Y'
 AND TRUNC(bb.effective_date) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
 AND paaf.assignment_number =  p_assignment_number
 AND paaf.business_group_id = 326  );

BEGIN


OPEN  cur_main;
FETCH cur_main INTO l_rate;
CLOSE cur_main;

l_rate := ROUND(l_rate/20,2);

RETURN  NVL(l_rate,0);


EXCEPTION
    WHEN OTHERS THEN
	      RETURN 0;

END;


END Tt_Holiday_Rate_Calc;
/
show errors;
/