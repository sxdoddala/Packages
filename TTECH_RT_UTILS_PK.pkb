create or replace PACKAGE BODY      ttech_rt_utils_pk
AS
  /* $Header: TTECH_RT_UTILS_PK.pkb 1.0 2011/05/23 mdodge ship $ */

 /*===================================================================================================================*
  * Copyright (c) 2006 TeleTech, Holdings                                                                             *
  *== START ================================================================================================*\
     Author: M Barone
       Date: 05/23/2011
  Call From:
       Desc: General Package for functions based on HRMS, Payroll, Benefits

    Modification History:

   Version    Date     Author       Description (Include Ticket#)
   -------  --------  ------------  ------------------------------------------------------------------------------
      1.0   08/22/06  M Barone      Creation of the package.
      1.1   05/22/08  G Casaretto   Creation of the function f_lenght_of_service.
      1.2   06/07/08  H Albanesi    Creation of the function f_calculate_attrition_loc
                                      for Almendra Judith. It uses other functions defined in the package
      1.3   08/09/08  H Albanesi    Creation of the function f_job_lenght_assg for Alllison Heintz,
                                      as she wanted to add the length of time that one employee
                                      was assigned to a job in many reports.
      1.4   09/18/08  H Albanesi    Modification of the name of the function f_job_lenght_assg to
                                      f_job_length_assg (only the description was modified)
      1.5   12/11/08  F Bodner      Modification of the following functions for Leticia Chajchir:
                                      -   f_headcount_loc
                                      -   f_terms_loc_day
                                      -   f_calculate_attrition_loc
                                      -   f_terms_loc_month
      1.6   02/27/09  F Bodner      Creation of the following functions for Emilce Lopez:
                                      -   f_headcount_job_prg
                                      -   f_terms_job_prg_day
                                      -   f_calculate_attrition_job_prg
                                      -   f_terms_job_prg_month
      1.7   09/22/09  F Bodner      Adding Project Name parameter to the following functions for Guillermo Discoli:
                                      -   f_headcount_loc
                                      -   f_terms_loc_day
                                      -   f_calculate_attrition_loc
                                      -   f_terms_loc_month
      1.8   10/28/09  F Bodner      Adding the tepa.prj_strt_dt (+) AND NVL (tepa.prj_end_dt (+), '31-DEC-4712')
                                      condition to the following functions for Guillermo Discoli:
                                      -   f_headcount_loc
                                      -   f_terms_loc_day
                                      -   f_terms_loc_month
      1.9   03/18/10  GECASARETTO   Creation of the get_executive function for the Mercer ePRISM reports.
      1.10  10/17/11  MRDODGE       Added Loop Counter to f_get_executive to prevent infinite loop condition
	  1.0	10-May-2023 IXPRAVEEN(ARGANO)   		R12.2 Upgrade Remediation
  \*== END ==================================================================================================*/

   /* *****************************************************************************
    * NAME: SET_CONTEXT                                                           *
    * PURPOSE: Sets a value for the enviornment variable received by parameter.   *
    * *****************************************************************************/
   FUNCTION set_context (p_name VARCHAR2, p_value VARCHAR2)
      RETURN VARCHAR2
   IS
   BEGIN
      DBMS_SESSION.set_context ('DISCO_CONTEXT', p_name, p_value);
      RETURN 'TRUE';
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN 'FALSE';
   END set_context;

   /* *****************************************************************************
    * NAME: SHOW_CONTEXT                                                          *
    * PURPOSE: Provides the value for the environment variable recieved by          *
    *          parameter.                                                         *
    * *****************************************************************************/
   -- show xxmod_disco context
   FUNCTION show_context (p_name VARCHAR2)
      RETURN VARCHAR2
      PARALLEL_ENABLE
   IS
   BEGIN
      RETURN SYS_CONTEXT ('DISCO_CONTEXT', p_name);
   END show_context;

   /* *****************************************************************************
    * NAME: RAISE_ERROR                                                           *
    * PURPOSE: Raises an error description recieved by parameter.               *
    *                                             *
    * *****************************************************************************/
   FUNCTION raise_error (p_message VARCHAR2)
      RETURN VARCHAR2
      PARALLEL_ENABLE
   IS
   BEGIN
      IF p_message IS NOT NULL
      THEN
         raise_application_error (-20001, p_message);
         RETURN ('FALSE');
      ELSE
         RETURN ('TRUE');
      END IF;
   END raise_error;

   PROCEDURE initialize
   IS
      l_result   VARCHAR2 (10);
   BEGIN
      FOR xcon
      IN (SELECT   context_name, context_value FROM disco_initial_contexts)
      LOOP
         l_result   := set_context (xcon.context_name, xcon.context_value);
      END LOOP;
   END initialize;

   /********************************************************************************
    * NAME: f_days_to_months                                                       *
    * PURPOSE: Given a number of days returns quantity of complete months.          *
    *                                                                              *
    ********************************************************************************/
   FUNCTION f_days_to_months (p_days IN NUMBER)
      RETURN NUMBER
   IS
      v_months   NUMBER := 0;
   BEGIN
      v_months   := FLOOR (p_days / 30.45);

      RETURN v_months;
   END f_days_to_months;

   /********************************************************************************
    * NAME: f_days_to_years                                                        *
    * PURPOSE: Given a number of days returns quantity of complete years.          *
    *                                                                              *
    ********************************************************************************/
   FUNCTION f_days_to_years (p_days IN NUMBER)
      RETURN NUMBER
   IS
      v_years   NUMBER := 0;
   BEGIN
      v_years   := FLOOR (p_days / 365);

      RETURN v_years;
   END f_days_to_years;

   /********************************************************************************
    * NAME: f_lenght_of_service                                                    *
    * PURPOSE: Given a Person_Id and an As Of Date, calculates Lenth of Service    *
    *          for that employee to the As Of Date.
    ********************************************************************************/
   FUNCTION f_lenght_of_service (p_person_id IN NUMBER, p_as_of_date IN DATE)
      RETURN NUMBER
   IS
      total_los           NUMBER := 0;
      period1_from_date   DATE := NULL;
      period1_to_date     DATE := NULL;
      period2_from_date   DATE := NULL;
      period2_to_date     DATE := NULL;
      period2_los         NUMBER := 0;
      inactive_time       NUMBER := 0;

      CURSOR c_periods_of_service (
         c_person_id                  NUMBER
       , c_as_of_date                 DATE
      )
      IS
         SELECT     ppof.date_start "DATE_FROM"
                  , CASE
                       WHEN ppof.actual_termination_date IS NOT NULL
                        AND ppof.actual_termination_date <= c_as_of_date
                       THEN
                          ppof.actual_termination_date
                       ELSE
                          TRUNC (c_as_of_date)
                    END
                       "DATE_TO"
                  , CASE
                       WHEN ppof.actual_termination_date IS NOT NULL
                        AND ppof.actual_termination_date <= c_as_of_date
                       THEN
                          (ppof.actual_termination_date - ppof.date_start)
                       ELSE
                          TRUNC (c_as_of_date - ppof.date_start)
                    END
                       "LOS"
         FROM       per_all_people_f papf, per_periods_of_service ppof
         WHERE      ppof.person_id = papf.person_id
                AND SYSDATE BETWEEN papf.effective_start_date(+)
                                AND  papf.effective_end_date(+)
                AND ppof.date_start <= c_as_of_date
                AND papf.person_id = c_person_id
         ORDER BY   ppof.date_start;
   BEGIN
      FOR rec IN c_periods_of_service (p_person_id, p_as_of_date)
      LOOP
         IF period1_from_date IS NULL
         THEN -- it is the first record, it is being saved without comparing
            period1_from_date   := rec.date_from;
            period1_to_date     := rec.date_to;
            total_los           := rec.los;
         ELSE
            period2_from_date   := rec.date_from;
            period2_to_date     := rec.date_to;
            period2_los         := rec.los;
            inactive_time       := (period2_from_date - period1_to_date);

            IF (period2_los >= 365
            AND inactive_time > 180)
            OR (period2_los < 365
            AND inactive_time > 30)
            THEN -- It's a Rehire
               total_los   := period2_los;
            ELSE -- It's a Reinstate
               total_los   := total_los + period2_los;
            END IF;

            period1_from_date   := rec.date_from;
            period1_to_date     := rec.date_to;
         END IF;
      END LOOP;

      RETURN total_los;
   END f_lenght_of_service;

   /* *****************************************************************************
    * NAME: f_headcount_bg
    * PURPOSE: Provides active employees as of the specific date received as
    * parameter per business group
    * *****************************************************************************/

   FUNCTION f_headcount_bg (p_bg_id IN NUMBER, p_date IN VARCHAR2)
      RETURN NUMBER
   IS
      l_headcount   NUMBER := 0;
   BEGIN
      SELECT     COUNT (DISTINCT papf.person_id)
      INTO       l_headcount
      --FROM       hr.per_all_people_f papf, hr.per_all_assignments_f paaf		-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
      FROM       apps.per_all_people_f papf, apps.per_all_assignments_f paaf        --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
      WHERE      papf.business_group_id = p_bg_id
             AND papf.current_employee_flag = 'Y'
             AND p_date BETWEEN papf.effective_start_date
                            AND  papf.effective_end_date
             AND papf.person_id = paaf.person_id
             AND p_date BETWEEN paaf.effective_start_date
                            AND  paaf.effective_end_date
             AND paaf.primary_flag = 'Y'
             AND paaf.assignment_type = 'E'
      GROUP BY   papf.business_group_id;

      RETURN l_headcount;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN 0;
   END f_headcount_bg;

   /************************************************************************************************
   * NAME: f_hires_loc_month
   * PURPOSE: Provides number of hires employees for a specific business group and location
   * according to the month and year received as a parameter.
   * ***********************************************************************************************/

   FUNCTION f_hires_loc_month (p_bg_id    IN NUMBER
                             , p_loc_id   IN NUMBER
                             , p_month    IN VARCHAR2
                             , p_year     IN VARCHAR2)
      RETURN NUMBER
   IS
      l_hires   NUMBER := 0;
   BEGIN
      SELECT     COUNT (papf.person_id)
      INTO       l_hires
      --START R12.2 Upgrade Remediation
	  /*FROM       hr.per_all_people_f papf					-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
               , hr.per_all_assignments_f paaf              
               , hr.per_periods_of_service ppos*/
	  FROM       apps.per_all_people_f papf					--  code Added by IXPRAVEEN-ARGANO,   10-May-2023
               , apps.per_all_assignments_f paaf
               , apps.per_periods_of_service ppos
	 --END R12.2.10 Upgrade remediation
      WHERE      papf.business_group_id = p_bg_id
             AND papf.person_id = paaf.person_id
             AND ppos.person_id = papf.person_id
             AND paaf.period_of_service_id = ppos.period_of_service_id
             AND ppos.date_start BETWEEN papf.effective_start_date
                                     AND  papf.effective_end_date
             AND ppos.date_start BETWEEN paaf.effective_start_date
                                     AND  paaf.effective_end_date
             AND paaf.primary_flag = 'Y'
             AND paaf.assignment_type = 'E'
             AND ppos.date_start BETWEEN TO_DATE (
                                               '01'
                                            || '-'
                                            || p_month
                                            || '-'
                                            || p_year
                                          , 'DD-MON-YYYY'
                                         )
                                     AND  (SELECT   LAST_DAY(TO_DATE (
                                                                   '01'
                                                                || '-'
                                                                || p_month
                                                                || '-'
                                                                || p_year
                                                              , 'DD-MON-YYYY'
                                                             ))
                                           FROM     DUAL)
             AND paaf.location_id = p_loc_id
      GROUP BY   papf.business_group_id
               , paaf.location_id;

      RETURN l_hires;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN 0;
   END f_hires_loc_month;

   /* ***************************************************************************************
   * NAME: f_job_length_assg
   * PURPOSE: Provides the lenght of days that one employee was assigned to a job.
   * Parameters: p_bg_id = business_group_id => i.e 325
   *               p_assignment_id
   *               p_job_id
   * ****************************************************************************************/

   FUNCTION f_job_length_assg (p_bg_id           IN NUMBER
                             , p_assignment_id   IN NUMBER
                             , p_job_id          IN NUMBER)
      RETURN NUMBER
   IS
      l_day   NUMBER := 0;
   BEGIN
      SELECT     SUM( (CASE TO_CHAR (paaf.effective_end_date, 'DD-MON-YYYY')
                          WHEN '31-DEC-4712'
                          THEN
                             NVL (ppos.actual_termination_date
                                , TRUNC (SYSDATE)) -- in case that a term EE does not contain a final process date
                          ELSE
                             paaf.effective_end_date
                       END)
                     - paaf.effective_start_date)
      INTO       l_day
      --FROM       hr.per_periods_of_service ppos, hr.per_all_assignments_f paaf				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
      FROM       apps.per_periods_of_service ppos, apps.per_all_assignments_f paaf              --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
      WHERE      paaf.business_group_id = p_bg_id
             AND paaf.assignment_id = p_assignment_id
             AND paaf.job_id = p_job_id
             AND paaf.assignment_type = 'E'
             AND paaf.primary_flag = 'Y'
             AND ppos.period_of_service_id = paaf.period_of_service_id
      GROUP BY   paaf.assignment_id
               , paaf.job_id;

      RETURN l_day;
   END f_job_length_assg;

   /* *****************************************************************************
   * NAME: f_headcount_loc
   * PURPOSE: Provides active employees as of the specific date and job name
   * received as parameters per business group and location.
   * *****************************************************************************/

   FUNCTION f_headcount_loc (p_bg_id      IN NUMBER
                           , p_loc_id     IN NUMBER
                           , p_date       IN VARCHAR2
                           , p_job_name   IN VARCHAR2 DEFAULT NULL
                           , p_prj_name   IN VARCHAR2 DEFAULT NULL )
      RETURN NUMBER
   IS
      l_headcount   NUMBER := 0;
   BEGIN
      IF p_job_name IS NOT NULL
      THEN
         SELECT     COUNT (DISTINCT papf.person_id)
         INTO       l_headcount
         --START R12.2 Upgrade Remediation
		 /*FROM       hr.per_all_people_f papf							-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                  , hr.per_all_assignments_f paaf                       
                  , per_jobs pj
                  , cust.ttec_emp_proj_asg tepa*/
		 FROM       apps.per_all_people_f papf							--  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                  , apps.per_all_assignments_f paaf
                  , per_jobs pj
                  , apps.ttec_emp_proj_asg tepa	
		--END R12.2.10 Upgrade remediation
         WHERE      papf.business_group_id = p_bg_id
                AND papf.current_employee_flag = 'Y'
                AND p_date BETWEEN papf.effective_start_date
                               AND  papf.effective_end_date
                AND papf.person_id = paaf.person_id
                AND paaf.primary_flag = 'Y'
                AND paaf.assignment_type = 'E'
                AND p_date BETWEEN paaf.effective_start_date
                               AND  paaf.effective_end_date
                AND p_loc_id = paaf.location_id
                AND paaf.job_id = pj.job_id
                AND UPPER (pj.name) LIKE '%' || UPPER (p_job_name) || '%'
                AND papf.person_id = tepa.person_id(+)
                AND tepa.project_desc = NVL (p_prj_name, tepa.project_desc)
                AND p_date BETWEEN tepa.prj_strt_dt(+)
                               AND  NVL (tepa.prj_end_dt(+), '31-DEC-4712')
         GROUP BY   papf.business_group_id
                  , paaf.location_id;
      ELSE
         SELECT     COUNT (DISTINCT papf.person_id)
         INTO       l_headcount
		 --START R12.2 Upgrade Remediation
         /*FROM       hr.per_all_people_f papf						-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                  , hr.per_all_assignments_f paaf                   
                  , cust.ttec_emp_proj_asg tepa*/
		 FROM       apps.per_all_people_f papf						--  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                  , apps.per_all_assignments_f paaf
                  , apps.ttec_emp_proj_asg tepa	
			--END R12.2.10 Upgrade remediation
         WHERE      papf.business_group_id = p_bg_id
                AND papf.current_employee_flag = 'Y'
                AND p_date BETWEEN papf.effective_start_date
                               AND  papf.effective_end_date
                AND papf.person_id = paaf.person_id
                AND paaf.primary_flag = 'Y'
                AND paaf.assignment_type = 'E'
                AND p_date BETWEEN paaf.effective_start_date
                               AND  paaf.effective_end_date
                AND p_loc_id = paaf.location_id
                AND papf.person_id = tepa.person_id(+)
                AND tepa.project_desc = NVL (p_prj_name, tepa.project_desc)
                AND p_date BETWEEN tepa.prj_strt_dt(+)
                               AND  NVL (tepa.prj_end_dt(+), '31-DEC-4712')
         GROUP BY   papf.business_group_id
                  , paaf.location_id;
      END IF;

      RETURN l_headcount;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN 0;
   END f_headcount_loc;


   /* ***************************************************************************************
   * NAME: f_terms_loc_day
   * PURPOSE: Provides number of terms employees as of one day for a specific business group
   * according to the date and job name received as parameters. If the p_term_type parameter
   * contains the values Voluntary or Involuntary, it will return the number according
   * to this parameter
   * ****************************************************************************************/

   FUNCTION f_terms_loc_day (p_bg_id       IN NUMBER
                           , p_loc_id      IN NUMBER
                           , p_date        IN VARCHAR2
                           , p_term_type   IN VARCHAR2
                           , p_job_name    IN VARCHAR2 DEFAULT NULL
                           , p_prj_name    IN VARCHAR2 DEFAULT NULL )
      RETURN NUMBER
   IS
      l_terms   NUMBER := 0;
   BEGIN
      IF p_job_name IS NOT NULL
      THEN
         IF (p_term_type = 'Voluntary')
         OR (p_term_type = 'Involuntary')
         THEN
            SELECT     COUNT (papf.person_id)
            INTO       l_terms
			--START R12.2 Upgrade Remediation
            /*FROM       hr.per_all_people_f papf						-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                     , hr.per_all_assignments_f paaf                    
                     , hr.per_periods_of_service ppos
                     , apps.fnd_lookup_values fnd_terms
                     , per_business_groups pbg
                     , per_jobs pj
                     , cust.ttec_emp_proj_asg tepa*/
			FROM       apps.per_all_people_f papf						--  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                     , apps.per_all_assignments_f paaf
                     , apps.per_periods_of_service ppos
                     , apps.fnd_lookup_values fnd_terms
                     , per_business_groups pbg
                     , per_jobs pj
                     , apps.ttec_emp_proj_asg tepa
			--END R12.2.10 Upgrade remediation
            WHERE      papf.business_group_id = p_bg_id
                   AND papf.person_id = paaf.person_id
                   AND ppos.person_id = papf.person_id
                   AND paaf.period_of_service_id = ppos.period_of_service_id
                   AND ppos.actual_termination_date BETWEEN papf.effective_start_date
                                                        AND  papf.effective_end_date
                   AND ppos.actual_termination_date BETWEEN paaf.effective_start_date
                                                        AND  paaf.effective_end_date
                   AND paaf.primary_flag = 'Y'
                   AND paaf.assignment_type = 'E'
                   AND ppos.actual_termination_date = p_date
                   AND paaf.location_id = p_loc_id
                   AND fnd_terms.lookup_code = ppos.leaving_reason
                   AND fnd_terms.lookup_type = 'LEAV_REAS'
                   AND fnd_terms.language = USERENV ('LANG')
                   AND papf.business_group_id = pbg.business_group_id
                   AND fnd_terms.security_group_id(+) = pbg.security_group_id
                   AND fnd_terms.enabled_flag = 'Y'
                   AND fnd_terms.attribute3 = p_term_type
                   AND paaf.job_id = pj.job_id
                   AND UPPER (pj.name) LIKE '%' || UPPER (p_job_name) || '%'
                   AND ppos.person_id = tepa.person_id(+)
                   AND tepa.project_desc = NVL (p_prj_name, tepa.project_desc)
                   AND ppos.actual_termination_date BETWEEN tepa.prj_strt_dt(+)
                                                        AND  NVL (
                                                                tepa.prj_end_dt(+)
                                                              , '31-DEC-4712'
                                                             )
            GROUP BY   papf.business_group_id
                     , paaf.location_id;
         ELSE
            SELECT     COUNT (papf.person_id)
            INTO       l_terms
            --START R12.2 Upgrade Remediation
			/*FROM       hr.per_all_people_f papf						-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                     , hr.per_all_assignments_f paaf                    
                     , hr.per_periods_of_service ppos
                     , per_jobs pj
                     , cust.ttec_emp_proj_asg tepa*/
			FROM       apps.per_all_people_f papf							--  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                     , apps.per_all_assignments_f paaf
                     , apps.per_periods_of_service ppos
                     , per_jobs pj
                     , apps.ttec_emp_proj_asg tepa	
			--END R12.2.10 Upgrade remediation
            WHERE      papf.business_group_id = p_bg_id
                   AND papf.person_id = paaf.person_id
                   AND ppos.person_id = papf.person_id
                   AND paaf.period_of_service_id = ppos.period_of_service_id
                   AND ppos.actual_termination_date = p_date
                   AND ppos.actual_termination_date BETWEEN papf.effective_start_date
                                                        AND  papf.effective_end_date
                   AND ppos.actual_termination_date BETWEEN paaf.effective_start_date
                                                        AND  paaf.effective_end_date
                   AND paaf.primary_flag = 'Y'
                   AND paaf.assignment_type = 'E'
                   AND paaf.location_id = p_loc_id
                   AND paaf.job_id = pj.job_id
                   AND UPPER (pj.name) LIKE '%' || UPPER (p_job_name) || '%'
                   AND ppos.person_id = tepa.person_id(+)
                   AND tepa.project_desc = NVL (p_prj_name, tepa.project_desc)
                   AND ppos.actual_termination_date BETWEEN tepa.prj_strt_dt(+)
                                                        AND  NVL (
                                                                tepa.prj_end_dt(+)
                                                              , '31-DEC-4712'
                                                             )
            GROUP BY   papf.business_group_id
                     , paaf.location_id;
         END IF;
      ELSE
         IF (p_term_type = 'Voluntary')
         OR (p_term_type = 'Involuntary')
         THEN
            SELECT     COUNT (papf.person_id)
            INTO       l_terms
            --START R12.2 Upgrade Remediation
			/*FROM       hr.per_all_people_f papf						-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                     , hr.per_all_assignments_f paaf
                     , hr.per_periods_of_service ppos
                     , apps.fnd_lookup_values fnd_terms
                     , per_business_groups pbg
                     , cust.ttec_emp_proj_asg tepa*/
			FROM       apps.per_all_people_f papf						                    --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                     , apps.per_all_assignments_f paaf
                     , apps.per_periods_of_service ppos
                     , apps.fnd_lookup_values fnd_terms
                     , per_business_groups pbg
                     , apps.ttec_emp_proj_asg tepa	
				--END R12.2.10 Upgrade remediation
            WHERE      papf.business_group_id = p_bg_id
                   AND papf.person_id = paaf.person_id
                   AND ppos.person_id = papf.person_id
                   AND paaf.period_of_service_id = ppos.period_of_service_id
                   AND ppos.actual_termination_date BETWEEN papf.effective_start_date
                                                        AND  papf.effective_end_date
                   AND ppos.actual_termination_date BETWEEN paaf.effective_start_date
                                                        AND  paaf.effective_end_date
                   AND paaf.primary_flag = 'Y'
                   AND paaf.assignment_type = 'E'
                   AND ppos.actual_termination_date = p_date
                   AND paaf.location_id = p_loc_id
                   AND fnd_terms.lookup_code = ppos.leaving_reason
                   AND fnd_terms.lookup_type = 'LEAV_REAS'
                   AND fnd_terms.language = USERENV ('LANG')
                   AND papf.business_group_id = pbg.business_group_id
                   AND fnd_terms.security_group_id(+) = pbg.security_group_id
                   AND fnd_terms.enabled_flag = 'Y'
                   AND fnd_terms.attribute3 = p_term_type
                   AND ppos.person_id = tepa.person_id(+)
                   AND tepa.project_desc = NVL (p_prj_name, tepa.project_desc)
                   AND ppos.actual_termination_date BETWEEN tepa.prj_strt_dt(+)
                                                        AND  NVL (
                                                                tepa.prj_end_dt(+)
                                                              , '31-DEC-4712'
                                                             )
            GROUP BY   papf.business_group_id
                     , paaf.location_id;
         ELSE
            SELECT     COUNT (papf.person_id)
            INTO       l_terms
           --START R12.2 Upgrade Remediation
		   /* FROM       hr.per_all_people_f papf			-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                     , hr.per_all_assignments_f paaf        
                     , hr.per_periods_of_service ppos
                     , cust.ttec_emp_proj_asg tepa*/
			FROM       apps.per_all_people_f papf				--  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                     , apps.per_all_assignments_f paaf
                     , apps.per_periods_of_service ppos
                     , apps.ttec_emp_proj_asg tepa	
						--END R12.2.10 Upgrade remediation
            WHERE      papf.business_group_id = p_bg_id
                   AND papf.person_id = paaf.person_id
                   AND ppos.person_id = papf.person_id
                   AND paaf.period_of_service_id = ppos.period_of_service_id
                   AND ppos.actual_termination_date = p_date
                   AND ppos.actual_termination_date BETWEEN papf.effective_start_date
                                                        AND  papf.effective_end_date
                   AND ppos.actual_termination_date BETWEEN paaf.effective_start_date
                                                        AND  paaf.effective_end_date
                   AND paaf.primary_flag = 'Y'
                   AND paaf.assignment_type = 'E'
                   AND paaf.location_id = p_loc_id
                   AND ppos.person_id = tepa.person_id(+)
                   AND tepa.project_desc = NVL (p_prj_name, tepa.project_desc)
                   AND ppos.actual_termination_date BETWEEN tepa.prj_strt_dt(+)
                                                        AND  NVL (
                                                                tepa.prj_end_dt(+)
                                                              , '31-DEC-4712'
                                                             )
            GROUP BY   papf.business_group_id
                     , paaf.location_id;
         END IF;
      END IF;

      RETURN l_terms;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN 0;
   END f_terms_loc_day;


   /* ***************************************************************************************
   * NAME: f_calculate_attrition_loc
   * PURPOSE: Provides the monthly attrition per location according to the business group
   * location, month, year and job name received as a parameter.
   * Parameters:  p_bg_id = business_group_id => i.e 325
   *              p_loc_id = location_id => i.e.29870
   *              p_month = month => i.e 'FEB'
   *              p_year = year => i.e '2008'
   *              p_ret_type = if ATTRITION_AVG then return % of attrition, if HEADCOUNT_AVG
   *                           then return % of headcount. If not, it will return 0.
   *              p_term_type = Voluntary, Involuntary or nothing. It will applied at the call
   *                            of the f_terms_loc_day function
   *              p_job_name = job code => i.e 'GBS'
   *              p_prj_name = project name => i.e 'Arg Dev - Client Solutions'
   * ****************************************************************************************/

   FUNCTION f_calculate_attrition_loc (
      p_bg_id       IN NUMBER
    , p_loc_id      IN NUMBER
    , p_month       IN VARCHAR2
    , p_year        IN VARCHAR2
    , p_ret_type    IN VARCHAR2
    , p_term_type   IN VARCHAR2
    , p_job_name    IN VARCHAR2 DEFAULT NULL
    , p_prj_name    IN VARCHAR2 DEFAULT NULL
   )
      RETURN NUMBER
   IS
      l_headcount        NUMBER := 0;
      l_terms            NUMBER := 0;
      l_day              NUMBER := 0;
      i                  NUMBER := 0;

      l_acum_headcount   FLOAT := 0;
      l_acum_terms       FLOAT := 0;
      l_acum_attrition   FLOAT := 0;
   BEGIN
      i   := i + 1;

      SELECT   TO_CHAR (LAST_DAY (i || '-' || p_month || '-' || p_year)
                      , 'DD')
      INTO     l_day
      FROM     DUAL;

      IF p_ret_type = 'ATTRITION_AVG'
      THEN
         LOOP
            SELECT   apps.ttech_rt_utils_pk.f_headcount_loc (
                        p_bg_id
                      , p_loc_id
                      , TO_DATE (i || '-' || p_month || '-' || p_year
                               , 'DD-MON-YYYY')
                      , p_job_name
                      , p_prj_name
                     )
                   , apps.ttech_rt_utils_pk.f_terms_loc_day (
                        p_bg_id
                      , p_loc_id
                      , TO_DATE (i || '-' || p_month || '-' || p_year
                               , 'DD-MON-YYYY')
                      , p_term_type
                      , p_job_name
                      , p_prj_name
                     )
            INTO     l_headcount, l_terms
            FROM     DUAL;

            l_acum_headcount   := l_acum_headcount + l_headcount;
            l_acum_terms       := l_acum_terms + l_terms;

            l_acum_attrition   :=
               l_acum_attrition
               + (100 * (l_acum_terms / (l_acum_headcount / i)));

            i                  := i + 1;

            EXIT WHEN i > l_day;
         END LOOP;

         l_acum_headcount   := l_acum_headcount / l_day;
         l_acum_terms       := l_acum_terms;
         l_acum_attrition   := l_acum_attrition / l_day;

         RETURN l_acum_attrition;
      END IF;

      IF p_ret_type = 'HEADCOUNT_AVG'
      THEN
         LOOP
            SELECT   apps.ttech_rt_utils_pk.f_headcount_loc (
                        p_bg_id
                      , p_loc_id
                      , TO_DATE (i || '-' || p_month || '-' || p_year
                               , 'DD-MON-YYYY')
                      , p_job_name
                      , p_prj_name
                     )
            INTO     l_headcount
            FROM     DUAL;

            l_acum_headcount   := l_acum_headcount + l_headcount;

            i                  := i + 1;

            EXIT WHEN i > l_day;
         END LOOP;

         l_acum_headcount   := l_acum_headcount / l_day;
         RETURN l_acum_headcount;
      END IF;

      RETURN 0;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN 0;
      WHEN ZERO_DIVIDE
      THEN
         RETURN 0;
   END f_calculate_attrition_loc;

   /************************************************************************************************
   * NAME: f_terms_loc_month
   * PURPOSE: Provides number of terms employees for a specific business group and location
   * according to the month, year and job name received as parameters. If the p_term_type parameter
   * contains the values Voluntary or Involuntary, it will return the number according to this parameter
   * ***********************************************************************************************/

   FUNCTION f_terms_loc_month (p_bg_id       IN NUMBER
                             , p_loc_id      IN NUMBER
                             , p_month       IN VARCHAR2
                             , p_year        IN VARCHAR2
                             , p_term_type   IN VARCHAR2
                             , p_job_name    IN VARCHAR2 DEFAULT NULL
                             , p_prj_name    IN VARCHAR2 DEFAULT NULL )
      RETURN NUMBER
   IS
      l_terms   NUMBER := 0;
      l_days    NUMBER := 0;
   BEGIN
      IF p_job_name IS NOT NULL
      THEN
         IF (p_term_type = 'Voluntary')
         OR (p_term_type = 'Involuntary')
         THEN
            SELECT     COUNT (papf.person_id)
            INTO       l_terms
			--START R12.2 Upgrade Remediation
           /* FROM       hr.per_all_people_f papf						-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                     , hr.per_all_assignments_f paaf                    
                     , hr.per_periods_of_service ppos
                     , apps.fnd_lookup_values fnd_terms
                     , per_business_groups pbg
                     , per_jobs pj
                     , cust.ttec_emp_proj_asg tepa*/
			FROM       apps.per_all_people_f papf						--  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                     , apps.per_all_assignments_f paaf
                     , apps.per_periods_of_service ppos
                     , apps.fnd_lookup_values fnd_terms
                     , per_business_groups pbg
                     , per_jobs pj
                     , apps.ttec_emp_proj_asg tepa	
						--END R12.2.10 Upgrade remediation
            WHERE      papf.business_group_id = p_bg_id
                   AND papf.person_id = paaf.person_id
                   AND ppos.person_id = papf.person_id
                   AND paaf.period_of_service_id = ppos.period_of_service_id
                   AND ppos.actual_termination_date BETWEEN papf.effective_start_date
                                                        AND  papf.effective_end_date
                   AND ppos.actual_termination_date BETWEEN paaf.effective_start_date
                                                        AND  paaf.effective_end_date
                   AND paaf.primary_flag = 'Y'
                   AND paaf.assignment_type = 'E'
                   AND ppos.actual_termination_date BETWEEN TO_DATE (
                                                                  '01'
                                                               || '-'
                                                               || p_month
                                                               || '-'
                                                               || p_year
                                                             , 'DD-MON-YYYY'
                                                            )
                                                        AND  (SELECT   LAST_DAY(TO_DATE (
                                                                                   '01'
                                                                                   || '-'
                                                                                   || p_month
                                                                                   || '-'
                                                                                   || p_year
                                                                                 , 'DD-MON-YYYY'
                                                                                ))
                                                              FROM     DUAL)
                   AND paaf.location_id = p_loc_id
                   AND fnd_terms.lookup_code = ppos.leaving_reason
                   AND fnd_terms.lookup_type = 'LEAV_REAS'
                   AND fnd_terms.language = USERENV ('LANG')
                   AND papf.business_group_id = pbg.business_group_id
                   AND fnd_terms.security_group_id(+) = pbg.security_group_id
                   AND fnd_terms.enabled_flag = 'Y'
                   AND fnd_terms.attribute3 = p_term_type
                   AND paaf.job_id = pj.job_id
                   AND UPPER (pj.name) LIKE '%' || UPPER (p_job_name) || '%'
                   AND ppos.person_id = tepa.person_id(+)
                   AND tepa.project_desc = NVL (p_prj_name, tepa.project_desc)
                   AND ppos.actual_termination_date BETWEEN tepa.prj_strt_dt(+)
                                                        AND  NVL (
                                                                tepa.prj_end_dt(+)
                                                              , '31-DEC-4712'
                                                             )
            GROUP BY   papf.business_group_id
                     , paaf.location_id;
         ELSE
            SELECT     COUNT (papf.person_id)
            INTO       l_terms
           --START R12.2 Upgrade Remediation
		   /* FROM       hr.per_all_people_f papf				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                     , hr.per_all_assignments_f paaf            
                     , hr.per_periods_of_service ppos
                     , per_jobs pj
                     , cust.ttec_emp_proj_asg tepa*/
			FROM       apps.per_all_people_f papf				--  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                     , apps.per_all_assignments_f paaf
                     , apps.per_periods_of_service ppos
                     , per_jobs pj
                     , apps.ttec_emp_proj_asg tepa
						--END R12.2.10 Upgrade remediation
            WHERE      papf.business_group_id = p_bg_id
                   AND papf.person_id = paaf.person_id
                   AND ppos.person_id = papf.person_id
                   AND paaf.period_of_service_id = ppos.period_of_service_id
                   AND ppos.actual_termination_date BETWEEN papf.effective_start_date
                                                        AND  papf.effective_end_date
                   AND ppos.actual_termination_date BETWEEN paaf.effective_start_date
                                                        AND  paaf.effective_end_date
                   AND paaf.primary_flag = 'Y'
                   AND paaf.assignment_type = 'E'
                   AND ppos.actual_termination_date BETWEEN TO_DATE (
                                                                  '01'
                                                               || '-'
                                                               || p_month
                                                               || '-'
                                                               || p_year
                                                             , 'DD-MON-YYYY'
                                                            )
                                                        AND  (SELECT   LAST_DAY(TO_DATE (
                                                                                   '01'
                                                                                   || '-'
                                                                                   || p_month
                                                                                   || '-'
                                                                                   || p_year
                                                                                 , 'DD-MON-YYYY'
                                                                                ))
                                                              FROM     DUAL)
                   AND paaf.location_id = p_loc_id
                   AND paaf.job_id = pj.job_id
                   AND UPPER (pj.name) LIKE '%' || UPPER (p_job_name) || '%'
                   AND ppos.person_id = tepa.person_id(+)
                   AND tepa.project_desc = NVL (p_prj_name, tepa.project_desc)
                   AND ppos.actual_termination_date BETWEEN tepa.prj_strt_dt(+)
                                                        AND  NVL (
                                                                tepa.prj_end_dt(+)
                                                              , '31-DEC-4712'
                                                             )
            GROUP BY   papf.business_group_id
                     , paaf.location_id;
         END IF;
      ELSE
         IF (p_term_type = 'Voluntary')
         OR (p_term_type = 'Involuntary')
         THEN
            SELECT     COUNT (papf.person_id)
            INTO       l_terms
            --START R12.2 Upgrade Remediation
			/*FROM       hr.per_all_people_f papf				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                     , hr.per_all_assignments_f paaf            
                     , hr.per_periods_of_service ppos
                     , apps.fnd_lookup_values fnd_terms
                     , per_business_groups pbg
                     , cust.ttec_emp_proj_asg tepa*/
			FROM       apps.per_all_people_f papf					--  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                     , apps.per_all_assignments_f paaf
                     , apps.per_periods_of_service ppos
                     , apps.fnd_lookup_values fnd_terms
                     , per_business_groups pbg
                     , apps.ttec_emp_proj_asg tepa	
			--END R12.2.10 Upgrade remediation
            WHERE      papf.business_group_id = p_bg_id
                   AND papf.person_id = paaf.person_id
                   AND ppos.person_id = papf.person_id
                   AND paaf.period_of_service_id = ppos.period_of_service_id
                   AND ppos.actual_termination_date BETWEEN papf.effective_start_date
                                                        AND  papf.effective_end_date
                   AND ppos.actual_termination_date BETWEEN paaf.effective_start_date
                                                        AND  paaf.effective_end_date
                   AND paaf.primary_flag = 'Y'
                   AND paaf.assignment_type = 'E'
                   AND ppos.actual_termination_date BETWEEN TO_DATE (
                                                                  '01'
                                                               || '-'
                                                               || p_month
                                                               || '-'
                                                               || p_year
                                                             , 'DD-MON-YYYY'
                                                            )
                                                        AND  (SELECT   LAST_DAY(TO_DATE (
                                                                                   '01'
                                                                                   || '-'
                                                                                   || p_month
                                                                                   || '-'
                                                                                   || p_year
                                                                                 , 'DD-MON-YYYY'
                                                                                ))
                                                              FROM     DUAL)
                   AND paaf.location_id = p_loc_id
                   AND fnd_terms.lookup_code = ppos.leaving_reason
                   AND fnd_terms.lookup_type = 'LEAV_REAS'
                   AND fnd_terms.language = USERENV ('LANG')
                   AND papf.business_group_id = pbg.business_group_id
                   AND fnd_terms.security_group_id(+) = pbg.security_group_id
                   AND fnd_terms.enabled_flag = 'Y'
                   AND fnd_terms.attribute3 = p_term_type
                   AND ppos.person_id = tepa.person_id(+)
                   AND tepa.project_desc = NVL (p_prj_name, tepa.project_desc)
                   AND ppos.actual_termination_date BETWEEN tepa.prj_strt_dt(+)
                                                        AND  NVL (
                                                                tepa.prj_end_dt(+)
                                                              , '31-DEC-4712'
                                                             )
            GROUP BY   papf.business_group_id
                     , paaf.location_id;
         ELSE
            SELECT     COUNT (papf.person_id)
            INTO       l_terms
            --START R12.2 Upgrade Remediation
			/*FROM       hr.per_all_people_f papf						-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                     , hr.per_all_assignments_f paaf                    
                     , hr.per_periods_of_service ppos
                     , cust.ttec_emp_proj_asg tepa*/
			FROM       apps.per_all_people_f papf						--  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                     , apps.per_all_assignments_f paaf
                     , apps.per_periods_of_service ppos
                     , apps.ttec_emp_proj_asg tepa	
						--END R12.2.10 Upgrade remediation
            WHERE      papf.business_group_id = p_bg_id
                   AND papf.person_id = paaf.person_id
                   AND ppos.person_id = papf.person_id
                   AND paaf.period_of_service_id = ppos.period_of_service_id
                   AND ppos.actual_termination_date BETWEEN papf.effective_start_date
                                                        AND  papf.effective_end_date
                   AND ppos.actual_termination_date BETWEEN paaf.effective_start_date
                                                        AND  paaf.effective_end_date
                   AND paaf.primary_flag = 'Y'
                   AND paaf.assignment_type = 'E'
                   AND ppos.actual_termination_date BETWEEN TO_DATE (
                                                                  '01'
                                                               || '-'
                                                               || p_month
                                                               || '-'
                                                               || p_year
                                                             , 'DD-MON-YYYY'
                                                            )
                                                        AND  (SELECT   LAST_DAY(TO_DATE (
                                                                                   '01'
                                                                                   || '-'
                                                                                   || p_month
                                                                                   || '-'
                                                                                   || p_year
                                                                                 , 'DD-MON-YYYY'
                                                                                ))
                                                              FROM     DUAL)
                   AND paaf.location_id = p_loc_id
                   AND ppos.person_id = tepa.person_id(+)
                   AND tepa.project_desc = NVL (p_prj_name, tepa.project_desc)
                   AND ppos.actual_termination_date BETWEEN tepa.prj_strt_dt(+)
                                                        AND  NVL (
                                                                tepa.prj_end_dt(+)
                                                              , '31-DEC-4712'
                                                             )
            GROUP BY   papf.business_group_id
                     , paaf.location_id;
         END IF;
      END IF;

      RETURN l_terms;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN 0;
   END f_terms_loc_month;

   /*******************************************************************************
   * NAME: f_headcount_job_prg
   * AUTHOR: Facundo Bodner
   * DATE: March 06, 2009
   * PURPOSE: Provides active employees as of the specific date, program code and
   * job family received as parameters per business group and location.
   * *****************************************************************************/

   FUNCTION f_headcount_job_prg (p_bg_id        IN NUMBER
                               , p_loc_id       IN NUMBER
                               , p_date         IN VARCHAR2
                               , p_job_family   IN VARCHAR2 DEFAULT NULL
                               , p_prg_code     IN NUMBER DEFAULT NULL )
      RETURN NUMBER
   IS
      l_headcount   NUMBER := 0;
   BEGIN
      SELECT     COUNT (DISTINCT papf.person_id)
      INTO       l_headcount
		--START R12.2 Upgrade Remediation
	 /*FROM       hr.per_all_people_f papf					-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
               , hr.per_all_assignments_f paaf              
               , per_jobs pj
               , cust.ttec_emp_proj_asg tepa*/
	  FROM       apps.per_all_people_f papf					--  code Added by IXPRAVEEN-ARGANO,   10-May-2023
               , apps.per_all_assignments_f paaf
               , per_jobs pj
               , apps.ttec_emp_proj_asg tepa	
			--END R12.2.10 Upgrade remediation
      WHERE      papf.business_group_id = p_bg_id
             AND papf.current_employee_flag = 'Y'
             AND p_date BETWEEN papf.effective_start_date
                            AND  papf.effective_end_date
             AND papf.person_id = paaf.person_id
             AND paaf.primary_flag = 'Y'
             AND paaf.assignment_type = 'E'
             AND p_date BETWEEN paaf.effective_start_date
                            AND  paaf.effective_end_date
             AND p_loc_id = paaf.location_id
             AND paaf.job_id = pj.job_id(+)
             AND pj.attribute5 = NVL (p_job_family, pj.attribute5)
             AND papf.person_id = tepa.person_id(+)
             AND p_date BETWEEN tepa.prj_strt_dt(+) AND tepa.prj_end_dt(+)
             AND tepa.prog_cd = NVL (p_prg_code, tepa.prog_cd)
      GROUP BY   papf.business_group_id
               , paaf.location_id;

      RETURN l_headcount;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN 0;
   END f_headcount_job_prg;


   /*****************************************************************************************
   * NAME: f_terms_job_prg_day
   * AUTHOR: Facundo Bodner
   * DATE: March 06, 2009
   * PURPOSE: Provides number of terms employees as of one day for a specific business group
   * according to the date,job family, program code and leaving reason received as parameters.
   * ****************************************************************************************/

   FUNCTION f_terms_job_prg_day (p_bg_id         IN NUMBER
                               , p_loc_id        IN NUMBER
                               , p_date          IN VARCHAR2
                               , p_job_family    IN VARCHAR2 DEFAULT NULL
                               , p_prg_code      IN NUMBER DEFAULT NULL
                               , p_term_reason   IN VARCHAR2 DEFAULT NULL )
      RETURN NUMBER
   IS
      l_terms   NUMBER := 0;
   BEGIN
      SELECT     COUNT (papf.person_id)
      INTO       l_terms
      --START R12.2 Upgrade Remediation
	  /*FROM       hr.per_all_people_f papf
               , hr.per_all_assignments_f paaf					-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
               , hr.per_periods_of_service ppos                 
               , per_jobs pj
               , apps.fnd_lookup_values fnd_terms
               , per_business_groups pbg
               , cust.ttec_emp_proj_asg tepa*/
	  FROM       apps.per_all_people_f papf						 --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
               , apps.per_all_assignments_f paaf
               , apps.per_periods_of_service ppos
               , per_jobs pj
               , apps.fnd_lookup_values fnd_terms
               , per_business_groups pbg
               , cust.ttec_emp_proj_asg tepa	
				--END R12.2.10 Upgrade remediation
      WHERE      papf.business_group_id = p_bg_id
             AND papf.person_id = paaf.person_id
             AND ppos.person_id = papf.person_id
             AND paaf.period_of_service_id = ppos.period_of_service_id
             AND ppos.actual_termination_date = p_date
             AND ppos.actual_termination_date BETWEEN papf.effective_start_date
                                                  AND  papf.effective_end_date
             AND ppos.actual_termination_date BETWEEN paaf.effective_start_date
                                                  AND  paaf.effective_end_date
             AND paaf.primary_flag = 'Y'
             AND paaf.assignment_type = 'E'
             AND papf.business_group_id = pbg.business_group_id
             AND fnd_terms.security_group_id(+) = pbg.security_group_id
             AND fnd_terms.enabled_flag = 'Y'
             AND fnd_terms.lookup_code = ppos.leaving_reason
             AND fnd_terms.lookup_type = 'LEAV_REAS'
             AND fnd_terms.language = USERENV ('LANG')
             AND paaf.location_id = p_loc_id
             AND paaf.job_id = pj.job_id(+)
             AND pj.attribute5 = NVL (p_job_family, pj.attribute5)
             AND papf.person_id = tepa.person_id(+)
             AND p_date BETWEEN tepa.prj_strt_dt(+) AND tepa.prj_end_dt(+)
             AND tepa.prog_cd = NVL (p_prg_code, tepa.prog_cd)
             AND fnd_terms.meaning = NVL (p_term_reason, fnd_terms.meaning)
      GROUP BY   papf.business_group_id
               , paaf.location_id;

      RETURN l_terms;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN 0;
   END f_terms_job_prg_day;


   /* ***************************************************************************************
   * NAME: f_calculate_attrition_job_prg
   * AUTHOR: Facundo Bodner
   * DATE: March 06, 2009
   * PURPOSE: Provides the monthly attrition per location according to the business group
   * location, month, year, job family, program code and term reason received as a parameter.
   ******************************************************************************************/

   FUNCTION f_calculate_attrition_job_prg (
      p_bg_id         IN NUMBER
    , p_loc_id        IN NUMBER
    , p_month         IN VARCHAR2
    , p_year          IN VARCHAR2
    , p_ret_type      IN VARCHAR2
    , p_job_family    IN VARCHAR2 DEFAULT NULL
    , p_prg_code      IN NUMBER DEFAULT NULL
    , p_term_reason   IN VARCHAR2 DEFAULT NULL
   )
      RETURN NUMBER
   IS
      l_headcount        NUMBER := 0;
      l_terms            NUMBER := 0;
      l_day              NUMBER := 0;
      i                  NUMBER := 0;

      l_acum_headcount   FLOAT := 0;
      l_acum_terms       FLOAT := 0;
      l_acum_attrition   FLOAT := 0;
   BEGIN
      i   := i + 1;

      SELECT   TO_CHAR (LAST_DAY (i || '-' || p_month || '-' || p_year)
                      , 'DD')
      INTO     l_day
      FROM     DUAL;

      IF p_ret_type = 'ATTRITION_AVG'
      THEN
         LOOP
            SELECT   apps.ttech_rt_utils_pk.f_headcount_job_prg (
                        p_bg_id
                      , p_loc_id
                      , TO_DATE (i || '-' || p_month || '-' || p_year
                               , 'DD-MON-YYYY')
                      , p_job_family
                      , p_prg_code
                     )
                   , apps.ttech_rt_utils_pk.f_terms_job_prg_day (
                        p_bg_id
                      , p_loc_id
                      , TO_DATE (i || '-' || p_month || '-' || p_year
                               , 'DD-MON-YYYY')
                      , p_job_family
                      , p_prg_code
                      , p_term_reason
                     )
            INTO     l_headcount, l_terms
            FROM     DUAL;

            l_acum_headcount   := l_acum_headcount + l_headcount;
            l_acum_terms       := l_acum_terms + l_terms;

            l_acum_attrition   :=
               l_acum_attrition
               + (100 * (l_acum_terms / (l_acum_headcount / i)));

            i                  := i + 1;

            EXIT WHEN i > l_day;
         END LOOP;

         l_acum_headcount   := l_acum_headcount / l_day;
         l_acum_terms       := l_acum_terms;
         l_acum_attrition   := l_acum_attrition / l_day;

         RETURN l_acum_attrition;
      ELSIF p_ret_type = 'HEADCOUNT_AVG'
      THEN
         LOOP
            SELECT   apps.ttech_rt_utils_pk.f_headcount_job_prg (
                        p_bg_id
                      , p_loc_id
                      , TO_DATE (i || '-' || p_month || '-' || p_year
                               , 'DD-MON-YYYY')
                      , p_job_family
                      , p_prg_code
                     )
            INTO     l_headcount
            FROM     DUAL;

            l_acum_headcount   := l_acum_headcount + l_headcount;

            i                  := i + 1;

            EXIT WHEN i > l_day;
         END LOOP;

         l_acum_headcount   := l_acum_headcount / l_day;

         RETURN l_acum_headcount;
      END IF;

      RETURN 0;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN 0;
      WHEN ZERO_DIVIDE
      THEN
         RETURN 0;
   END f_calculate_attrition_job_prg;


   /************************************************************************************************
  * NAME: f_terms_job_prg_month
  * AUTHOR: Facundo Bodner
  * DATE: March 06, 2009
  * PURPOSE: Provides number of terms employees for a specific business group and location
  * according to the month, year, program code, leaving reason and job family received as parameters.
  ************************************************************************************************/

   FUNCTION f_terms_job_prg_month (p_bg_id         IN NUMBER
                                 , p_loc_id        IN NUMBER
                                 , p_month         IN VARCHAR2
                                 , p_year          IN VARCHAR2
                                 , p_job_family    IN VARCHAR2 DEFAULT NULL
                                 , p_prg_code      IN NUMBER DEFAULT NULL
                                 , p_term_reason   IN VARCHAR2 DEFAULT NULL )
      RETURN NUMBER
   IS
      l_terms   NUMBER := 0;
      l_days    NUMBER := 0;
   BEGIN
      SELECT     COUNT (papf.person_id)
      INTO       l_terms
      --START R12.2 Upgrade Remediation
	  /*FROM       hr.per_all_people_f papf
               , hr.per_all_assignments_f paaf					-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
               , hr.per_periods_of_service ppos                 
               , per_jobs pj
               , apps.fnd_lookup_values fnd_terms
               , per_business_groups pbg
               , cust.ttec_emp_proj_asg tepa*/
	  FROM       apps.per_all_people_f papf						--  code Added by IXPRAVEEN-ARGANO,   10-May-2023
               , apps.per_all_assignments_f paaf
               , apps.per_periods_of_service ppos
               , per_jobs pj
               , apps.fnd_lookup_values fnd_terms
               , per_business_groups pbg
               , apps.ttec_emp_proj_asg tepa
				--END R12.2.10 Upgrade remediation
      WHERE      papf.business_group_id = p_bg_id
             AND papf.person_id = paaf.person_id
             AND ppos.person_id = papf.person_id
             AND paaf.period_of_service_id = ppos.period_of_service_id
             AND ppos.actual_termination_date BETWEEN papf.effective_start_date
                                                  AND  papf.effective_end_date
             AND ppos.actual_termination_date BETWEEN paaf.effective_start_date
                                                  AND  paaf.effective_end_date
             AND paaf.primary_flag = 'Y'
             AND paaf.assignment_type = 'E'
             AND papf.business_group_id = pbg.business_group_id
             AND fnd_terms.security_group_id(+) = pbg.security_group_id
             AND fnd_terms.enabled_flag = 'Y'
             AND fnd_terms.lookup_code = ppos.leaving_reason
             AND fnd_terms.lookup_type = 'LEAV_REAS'
             AND fnd_terms.language = USERENV ('LANG')
             AND ppos.actual_termination_date BETWEEN TO_DATE (
                                                            '01'
                                                         || '-'
                                                         || p_month
                                                         || '-'
                                                         || p_year
                                                       , 'DD-MON-YYYY'
                                                      )
                                                  AND  (SELECT   LAST_DAY(TO_DATE (
                                                                             '01'
                                                                             || '-'
                                                                             || p_month
                                                                             || '-'
                                                                             || p_year
                                                                           , 'DD-MON-YYYY'
                                                                          ))
                                                        FROM     DUAL)
             AND paaf.location_id = p_loc_id
             AND paaf.job_id = pj.job_id(+)
             AND pj.attribute5 = NVL (p_job_family, pj.attribute5)
             AND papf.person_id = tepa.person_id(+)
             AND ppos.actual_termination_date BETWEEN NVL (
                                                         tepa.prj_strt_dt
                                                       , ppos.actual_termination_date
                                                      )
                                                  AND  NVL (tepa.prj_end_dt
                                                          , TRUNC (SYSDATE))
             AND tepa.prog_cd = NVL (p_prg_code, tepa.prog_cd)
             AND fnd_terms.meaning = NVL (p_term_reason, fnd_terms.meaning)
      GROUP BY   papf.business_group_id
               , paaf.location_id;

      RETURN l_terms;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN 0;
   END f_terms_job_prg_month;

   /********************************************************************************
    * NAME: f_get_executive                                                         *
    * PURPOSE: Given a person_id returns the executive associated to that employee. *
    *          The Executive is defined as the second level down from the IExpense  *
    *          Approver in the employee's hierarchy.                                *
    *                                                                               *
    ********************************************************************************/

   FUNCTION f_get_executive (p_person_id IN NUMBER)
      RETURN NUMBER
   IS
      v_cnt           NUMBER := 0;     -- 1.10 Add Loop Counter
      v_max_cnt       NUMBER := 100;   -- 1.10 Add Max Number of Loops before exit

      v_person_id     NUMBER := p_person_id;
      v_supervisor1   NUMBER := 0;
      v_supervisor2   NUMBER := 0;
   BEGIN
      SELECT   DISTINCT paaf_sup.person_id, paaf_sup.supervisor_id
      INTO     v_supervisor1, v_supervisor2
      --START R12.2 Upgrade Remediation
	  /*FROM     hr.per_all_assignments_f paaf				-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
             , hr.per_all_assignments_f paaf_sup*/          
	  FROM     apps.per_all_assignments_f paaf				--  code Added by IXPRAVEEN-ARGANO,   10-May-2023
             , apps.per_all_assignments_f paaf_sup
			 --END R12.2.10 Upgrade remediation
      WHERE    paaf.person_id = v_person_id
           AND TRUNC (SYSDATE) BETWEEN paaf.effective_start_date
                                   AND  paaf.effective_end_date
           AND paaf.primary_flag = 'Y'
           AND paaf.assignment_type = 'E'
           AND paaf_sup.person_id = paaf.supervisor_id
           AND TRUNC (SYSDATE) BETWEEN paaf_sup.effective_start_date
                                   AND  paaf_sup.effective_end_date
           AND paaf_sup.primary_flag = 'Y'
           AND paaf_sup.assignment_type = 'E';

      WHILE v_supervisor2 <> 121938 /* Approver, IExpense */
      LOOP
         v_cnt := v_cnt + 1;        -- 1.10 Increment Loop counter

         /* 1.10 Limit Number of Loops to Max Counter to prevent infinitie looping */
         IF v_cnt > v_max_cnt THEN
           RAISE NO_DATA_FOUND;
         END IF;

         v_person_id   := v_supervisor1;

         SELECT   DISTINCT paaf_sup.person_id, paaf_sup.supervisor_id
         INTO     v_supervisor1, v_supervisor2
         --START R12.2 Upgrade Remediation
		 /*FROM     hr.per_all_assignments_f paaf					-- Commented code by IXPRAVEEN-ARGANO,10-May-2023
                , hr.per_all_assignments_f paaf_sup*/              
		 FROM     apps.per_all_assignments_f paaf				 --  code Added by IXPRAVEEN-ARGANO,   10-May-2023
                , apps.per_all_assignments_f paaf_sup
		--END R12.2.10 Upgrade remediation
         WHERE    paaf.person_id = v_person_id
              AND TRUNC (SYSDATE) BETWEEN paaf.effective_start_date
                                      AND  paaf.effective_end_date
              AND paaf.primary_flag = 'Y'
              AND paaf.assignment_type = 'E'
              AND paaf_sup.person_id = paaf.supervisor_id
              AND TRUNC (SYSDATE) BETWEEN paaf_sup.effective_start_date
                                      AND  paaf_sup.effective_end_date
              AND paaf_sup.primary_flag = 'Y'
              AND paaf_sup.assignment_type = 'E';
      END LOOP;

      RETURN v_person_id;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN 0;
   END f_get_executive;
END ttech_rt_utils_pk;
/
show errors;
/