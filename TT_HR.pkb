create or replace PACKAGE BODY      Tt_Hr IS
/***********************************************************************************/
-- Program Name: TT_HR GENERAL PACKAGE
--
--
--
-- Tables Modified:  N/A
--
--
--
-- Modification Log:
-- Developer    Version   Date       Description
-- ----------  --------  ------      --------------------
-- Kaushik Babu  1.0    04-DEC-2008  TT_HR.get_401k_plan_type procedure is been used in TT_401K_INTERFACE_2009 package
--                                   Changed logic to provide plantype for Kalispell employee for the 2009 and onwards.
-- Kaushik Babu  1.1    20-JAN-2009  changed condition to send USA-Kalispell' location Termintated Employees
--                                      correctly to TTI And TT2 files. The code change is going to impact
--                                   TT_401K_INTERFACE_2009 and TT_401K_INTERFACE_2005 packages.
-- Wasim Manasfi 1.2    -5-JUN-2009  added Birmngham to the sites 'USA-Birmingham (Govt)' so agents can go to TT2
-- Kaushik Babu  1.3	 4-FEB-2010  Changed the validation by location id instead of location code.
--				     Reason functional team changed all the location code names.
--iXPRAVEEN(ARGANO)	1.0		16-May-2023 R12.2 Upgrade Remediation
/************************************************************************************/


  /************************************************************************************/
  /*                              GET_ACCRUAL_PLAN                             */
  /************************************************************************************/
    PROCEDURE get_accrual_plan(p_accrual_plan_type IN VARCHAR2
                               ,p_assignment_id IN NUMBER
                               ,p_accrual_plan_id OUT NUMBER) IS
    BEGIN
      -- set global module name for error handling
        g_module_name := 'get_accrual_plan_name';

     SELECT pap.accrual_plan_id INTO p_accrual_plan_id
     FROM
         pay_accrual_plans pap,
         pay_element_links_f     pel,
         pay_element_entries_f     pee
     WHERE
         pap.accrual_category     = p_accrual_plan_type
         AND pel.element_type_id    = pap.accrual_plan_element_type_id
         AND TRUNC(SYSDATE) BETWEEN pel.effective_start_date
                 AND pel.effective_end_date
         AND pee.element_link_id    = pel.element_link_id
         AND pee.assignment_id    = p_assignment_id
         AND TRUNC(SYSDATE) BETWEEN pee.effective_start_date
                 AND pee.effective_end_date;

    EXCEPTION

             WHEN OTHERS THEN
                     NULL;
    END;


  /************************************************************************************/
  /*                               MAIN PROGRAM PROCEDURE                             */
  /************************************************************************************/


   FUNCTION  get_enrolled_flag (p_assignment_id IN NUMBER, p_pl_id IN  NUMBER ,
                                 p_bnft_amt OUT NUMBER)
                                  RETURN  VARCHAR2 IS



   l_enrolled_flag  VARCHAR2(1)  ;
   l_assignment_number VARCHAR2(50);
   l_assignment_id  NUMBER;
   l_prtt_entr_rslt_id  NUMBER;
   l_enrt_cvg_strt_dt   DATE;
   l_enrt_cvg_thru_dt   DATE;
   l_sspndd_flag      VARCHAR2(1);

   CURSOR cur_enrolled_flag         IS
   ( SELECT   paaf.assignment_number, paaf.assignment_id, enrt.prtt_enrt_rslt_id,
                     enrt.enrt_cvg_strt_dt, enrt.enrt_cvg_thru_dt,
                     enrt.sspndd_flag, enrt.bnft_amt
           FROM
         ben_prtt_enrt_rslt_f enrt,
         per_all_assignments_f paaf
      WHERE
          paaf.assignment_id = p_assignment_id
          AND enrt.person_id = paaf.person_id
          AND enrt.enrt_cvg_thru_dt <= enrt.effective_end_date
          AND enrt.prtt_enrt_rslt_stat_cd IS NULL
          AND TRUNC(SYSDATE) BETWEEN enrt.effective_start_date AND enrt.effective_end_date
          AND TRUNC(SYSDATE) BETWEEN enrt.enrt_cvg_strt_dt AND enrt.enrt_cvg_thru_dt
          AND TRUNC(SYSDATE) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
          AND enrt.pl_id  = p_pl_id
          AND ROWNUM < 2
         --and sspndd_flag = 'Y'
         --and enrt_ovridn_flag = 'Y'
       );

  BEGIN
        l_enrolled_flag  :=  'N';

       FOR  rec_enrolled IN cur_enrolled_flag LOOP

           IF rec_enrolled.assignment_id IS NOT NULL THEN
                  l_enrolled_flag  :=  'Y';
            END IF;

           p_bnft_amt := rec_enrolled.bnft_amt;


       END LOOP;

        RETURN l_enrolled_flag;



  EXCEPTION
       WHEN OTHERS THEN
           l_enrolled_flag := 'N';
           RETURN l_enrolled_flag;

  END;

   FUNCTION  get_benefit_increase_flag (p_assignment_id IN NUMBER, p_pl_id IN  NUMBER )
                                  RETURN  VARCHAR2 IS

   CURSOR cur_benefit         IS
   ( SELECT  paaf.assignment_number, paaf.assignment_id, enrt1.prtt_enrt_rslt_id new_prtt_enrt_rslt_id,
                enrt1.enrt_cvg_strt_dt  new_enrt_cvg_strt_dt,   enrt1.enrt_cvg_thru_dt  new_enrt_cvg_thru_dt ,
                enrt1.bnft_amt new_bnft_amt,
                enrt2.prtt_enrt_rslt_id old_prtt_enrt_rslt_id ,
                enrt2.enrt_cvg_strt_dt  old_enrt_cvg_strt_dt,   enrt2.enrt_cvg_thru_dt old_enrt_cvg_thru_dt ,
                enrt2.bnft_amt old_bnft_amt
       FROM
	   --START R12.2 Upgrade Remediation
         /*ben.ben_prtt_enrt_rslt_f enrt1,  --new				-- Commented code by IXPRAVEEN-ARGANO,16-May-2023
         ben.ben_prtt_enrt_rslt_f enrt2,  --old*/               
		 apps.ben_prtt_enrt_rslt_f enrt1,  --new					--  code Added by IXPRAVEEN-ARGANO,   16-May-2023
         apps.ben_prtt_enrt_rslt_f enrt2,  --old
		 --END R12.2.12 Upgrade remediation
         per_all_assignments_f paaf
      WHERE
          paaf.assignment_id = p_assignment_id
          AND enrt1.person_id = paaf.person_id
          AND enrt2.person_id = paaf.person_id
          AND enrt1.pl_id  = p_pl_id
           AND enrt2.pl_id  = p_pl_id
          AND enrt1.prtt_enrt_rslt_stat_cd IS NULL
          AND enrt2.prtt_enrt_rslt_stat_cd IS NULL
          AND enrt1.enrt_cvg_thru_dt <= enrt1.effective_end_date
          AND enrt2.enrt_cvg_thru_dt = enrt1.enrt_cvg_strt_dt - 1
          AND ROUND(SYSDATE,'YY') BETWEEN enrt1.effective_start_date AND enrt1.effective_end_date
          AND ROUND(SYSDATE,'YY') BETWEEN enrt1.enrt_cvg_strt_dt AND enrt1.enrt_cvg_thru_dt
          AND TRUNC(SYSDATE) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
         AND enrt2.sspndd_flag = 'N'
         --and enrt_ovridn_flag = 'Y'
       );

         l_increase_flag  VARCHAR2(1)  ;

  BEGIN
        l_increase_flag := 'N';

        FOR rec_benefit IN cur_benefit LOOP
                     IF rec_benefit.new_bnft_amt > rec_benefit.old_bnft_amt THEN
                           l_increase_flag := 'Y';
                     END IF;

        END LOOP;

        RETURN l_increase_flag;

  EXCEPTION
       WHEN OTHERS THEN
           l_increase_flag := 'N';
           RETURN l_increase_flag;

  END;


    FUNCTION  get_accrual  (p_assignment_id IN NUMBER, p_payroll_id IN  NUMBER,
                                p_business_group_id IN NUMBER,
                                p_accrual_type IN VARCHAR2,  p_calculation_date IN DATE)  RETURN NUMBER  IS

    -- declare local variables
    l_balance        NUMBER;
    l_plan_id          NUMBER;
    l_business_group_id          NUMBER;


  --declare place holders
  d1  DATE;
  d2  DATE;
  d3  DATE;
  n1  NUMBER;


    BEGIN
             -- initialize variables
                   l_balance := NULL;
                   l_plan_id    := NULL;
                   g_error_message := NULL;
                   g_label2 := NULL;
                   g_module_name := 'main';
                   g_primary_column := p_assignment_id;
                   g_secondary_column := NULL;

--DETERMINE L_VACATION_LEAVE_BALANCE


        get_accrual_plan(p_accrual_type
                        ,p_assignment_id
                        ,l_plan_id);


--Wrapping the get_accrual function so that errors are non-fatal.

       g_module_name := 'main - Vac Accural - nonfatal';


       IF l_plan_id IS NOT NULL    THEN


          -- use the new package
          apps.Per_Accrual_Calc_Functions.get_net_accrual(
               P_assignment_id          => p_assignment_id,
               P_plan_id                => l_plan_id,
               P_payroll_id             => p_payroll_id,
               p_business_group_id      => p_business_group_id,
               --p_assignment_action_id   => l_assignment_action_id,
               P_calculation_date       => TRUNC(p_calculation_date),
               p_accrual_start_date     => NULL,
               p_accrual_latest_balance => NULL,
               p_calling_point          => 'BP',  --'SQL' ,  --'BP' ,
               P_start_date             => d1,
               P_End_Date               => d2,
               P_Accrual_End_Date       => d3,
               P_accrual                => n1,
               P_net_entitlement        => l_balance
               );

               RETURN     ROUND(l_balance,3);

       ELSE

                  RETURN  0 ;  --do nothing since these people don't have the sick and vac accural elements

       END IF;

   EXCEPTION

   WHEN OTHERS THEN
            g_label1 :=  'Assignment ID';
            g_label2 :=  'Accrual-nonfatal_exception';
       RETURN  0 ;


   END;      /*** END ACCRUAL ***/

  FUNCTION  get_balance (p_person_id IN NUMBER, p_balance_name IN  VARCHAR2,
                                p_effective_date IN DATE)  RETURN  NUMBER IS

    l_balance NUMBER := 0;

  BEGIN
          g_primary_column := p_person_id;

          SELECT  SUM( t.balance_value ) INTO l_balance
           FROM
             apps.xkb_balances b,
             apps.xkb_balance_details t,
             apps.pay_balance_types bt
            WHERE
            b.assignment_action_id = t.assignment_action_id
            AND t.balance_type_id = bt.balance_type_id
            AND b.person_id = p_person_id
            AND bt.balance_name =  p_balance_name
            AND TRUNC(b.effective_date) <= p_effective_date
              ;

            RETURN l_balance;

  EXCEPTION
      WHEN OTHERS THEN
             RETURN 0;

  END;

  FUNCTION  get_balance_asg (p_assignment_id IN NUMBER, p_balance_name IN  VARCHAR2,
                                p_effective_date IN DATE)  RETURN  NUMBER IS

    l_balance NUMBER := 0;

  BEGIN

          SELECT  SUM( t.balance_value ) INTO l_balance
           FROM
             apps.xkb_balances b,
             apps.xkb_balance_details t,
             apps.pay_balance_types bt
            WHERE
            b.assignment_action_id = t.assignment_action_id
            AND t.balance_type_id = bt.balance_type_id
            AND b.assignment_id = p_assignment_id
            AND bt.balance_name =  p_balance_name
            AND TRUNC(b.effective_date) <= p_effective_date
              ;

            RETURN NVL(l_balance,0);

  EXCEPTION
      WHEN OTHERS THEN

             l_balance := 0;
             RETURN l_balance;

  END;

    FUNCTION  get_balance_asg_entry (p_assignment_id IN NUMBER, p_balance_name IN  VARCHAR2,
                                p_effective_date IN DATE)  RETURN  NUMBER IS

    l_balance NUMBER := 0;

  BEGIN

          SELECT  SUM( t.balance_value ) INTO l_balance
           FROM
             apps.xkb_balances b,
             apps.xkb_balance_details t,
             apps.pay_balance_types bt
            WHERE
            b.assignment_action_id = t.assignment_action_id
            AND t.balance_type_id = bt.balance_type_id
            AND b.assignment_id = p_assignment_id
            AND bt.balance_name =  p_balance_name
            AND TRUNC(b.effective_date) = TRUNC(p_effective_date)
              ;

            RETURN NVL(l_balance,0);

  EXCEPTION
      WHEN OTHERS THEN

             l_balance := 0;
             RETURN l_balance;

  END;

  FUNCTION  get_vacation_taken (p_assignment_id IN NUMBER,
                                p_date IN DATE)  RETURN  NUMBER IS

    l_balance NUMBER := 0;

  BEGIN

  SELECT SUM(val.screen_entry_value)  INTO l_balance
   FROM pay_element_entries_f el,
             pay_element_entry_values_f  val
  WHERE el.element_link_id = 392  --vacation taken
    AND el.element_entry_id = val.element_entry_id
    AND val.input_value_id = 4117   -- hours
    AND el.assignment_id = p_assignment_id
    AND  p_date    BETWEEN el.effective_start_date AND el.effective_end_date
    AND  p_date    BETWEEN val.effective_start_date AND val.effective_end_date ;

    RETURN NVL(l_balance,0);

    EXCEPTION
      WHEN OTHERS THEN

             l_balance := 0;
             RETURN l_balance;

  END;

  FUNCTION  get_bank_adjustment (p_assignment_id IN NUMBER,
                                p_date IN DATE)  RETURN  NUMBER IS

    l_balance NUMBER := 0;

  BEGIN

  SELECT SUM(val.screen_entry_value)  INTO l_balance
   FROM pay_element_entries_f el,
             pay_element_entry_values_f  val
  WHERE el.element_link_id = 738  --
    AND el.element_entry_id = val.element_entry_id
    AND val.input_value_id = 4500    -- hours
    AND el.assignment_id = p_assignment_id
    AND  p_date    BETWEEN el.effective_start_date AND el.effective_end_date
    AND  p_date    BETWEEN val.effective_start_date AND val.effective_end_date ;

    RETURN NVL(l_balance,0);

    EXCEPTION
      WHEN OTHERS THEN

             l_balance := 0;
             RETURN l_balance;

    END;


/* Formatted on 2008/12/16 14:53 (Formatter Plus v4.8.8) */
FUNCTION get_401k_plan_type (
   p_assignment_id   IN   NUMBER,
   p_start_date      IN   DATE,
   p_term_date       IN   DATE,
   p_eligible_date   IN   DATE
)
   RETURN VARCHAR2
IS
   l_balance          NUMBER                            := 0;
   l_job_family       per_jobs.attribute5%TYPE;
   l_location_code    hr_locations.location_code%TYPE;
   l_location_id      hr_locations.location_id%TYPE;
   l_locations        VARCHAR2 (100);
   l_effective_date   DATE;
   l_plan_type        VARCHAR2 (10);
BEGIN
   IF NVL (p_term_date, p_eligible_date) < p_eligible_date
   THEN
-- Commented out by C. Chan on 2/22/2006 for TT#457571
--        l_plan_type :=  'TTI';
--       RETURN l_plan_type;
      IF TO_NUMBER (TO_CHAR (p_start_date, 'YYYY')) <           -- start year
                         TO_NUMBER (TO_CHAR (p_term_date, 'YYYY')) --term_year
      THEN
         l_effective_date := TO_DATE ('01-JAN-' || TO_CHAR (p_term_date, 'YYYY'));
      ELSE
         l_effective_date := p_start_date;
      END IF;
   ELSE
      IF p_start_date < p_eligible_date
      THEN
         l_effective_date := p_eligible_date;
      ELSE
         l_effective_date := p_start_date;
      END IF;
   END IF;

   SELECT job.attribute5, loc.location_code, loc.location_id
     INTO l_job_family, l_location_code, l_location_id
     --FROM hr_locations loc, per_jobs job, hr.per_all_assignments_f paaf					-- Commented code by IXPRAVEEN-ARGANO,16-May-2023			
     FROM hr_locations loc, per_jobs job, apps.per_all_assignments_f paaf                     --  code Added by IXPRAVEEN-ARGANO,   16-May-2023
    WHERE paaf.assignment_id = p_assignment_id
      AND paaf.primary_flag = 'Y'
      AND paaf.assignment_type = 'E'
      AND paaf.location_id = loc.location_id
      AND l_effective_date BETWEEN paaf.effective_start_date
                               AND paaf.effective_end_date
      AND paaf.job_id = job.job_id(+)
      AND ROWNUM < 2;
-- Verison 1.0 <Starts>
   IF TO_NUMBER (TO_CHAR (p_eligible_date, 'YYYY')) <= 2008
   THEN
--      IF l_location_code IN
--            ('USA-Bremerton', 'USA-Deland', 'USA-Enfield', 'USA-Fairfield', 'USA-Hampton', 'USA-Birmingham (Govt)')
      IF l_location_id IN (45665,1649,562,182,282,1652)  	-- Revision 1.3
      THEN
         IF l_job_family = 'Agent'
         THEN
            l_plan_type := 'TT2';
         ELSIF l_job_family IS NULL
         THEN
            l_plan_type := NULL;
         ELSE
            l_plan_type := 'TTI';
         END IF;
      ELSE
         l_plan_type := 'TTI';
      END IF;
   ELSE

--      IF l_location_code IN
--            ('USA-Bremerton', 'USA-Deland', 'USA
--            Enfield', 'USA-Fairfield', 'USA-Hampton', 'USA-Kalispell','USA-Birmingham (Govt)')
      IF l_location_id IN (45665,1649,562,182,282,1652,27493)	-- Revision 1.3
      THEN
         IF l_job_family = 'Agent'
         THEN
            l_plan_type := 'TT2';
         ELSIF l_job_family IS NULL
         THEN
            l_plan_type := NULL;
         ELSE
            l_plan_type := 'TTI';
         END IF;
      ELSE
         l_plan_type := 'TTI';
      END IF;
    --<Version1.1 Start>
      IF     p_term_date <= to_date('31-DEC-2008','DD-MM-YYYY')
         --AND l_location_code IN ('USA-Kalispell')
         AND l_location_id = 27493		-- Revision 1.3
      THEN
         l_plan_type := 'TTI';
      END IF;    --<Version1.1 End>
    --Verison 1.0 <Ends>
   END IF;

   RETURN l_plan_type;
EXCEPTION
   WHEN OTHERS
   THEN
      l_plan_type := NULL;
      RETURN l_plan_type;
END;


END Tt_Hr;
/
show errors;
/