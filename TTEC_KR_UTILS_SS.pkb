create or replace PACKAGE BODY      ttec_kr_utils_SS
AS
   /* $Header: ttec_kr_utils.pkb 1.0 2009/12/28 mdodge ship $ */

   /*== START ================================================================================================*\
      Author: Michelle Dodge
        Date: 12/28/2009
   Call From: TTEC_KR_PERSON_INTERFACE pkg, TTEC_KR_ACCRUAL_INTERFACE pkg, PayRule Mapping JDeveloper Form
        Desc: This package is used to hold procedures and functions for:
              (1) Shared components for both the Person and Accrual Interfaces
              (2) Logic for Future Defined Country specific fields including the
                  Special Identifiers and CustomString fields
              (3) Procedures used by the Kronos PayRule Mapping form

              The Application Code and Interface global variables are not set in
              this package as they will be set by the calling package to enable
              full error capturing and reporting by the calling process.

     Modification History:

    Version    Date     Author   Description (Include Ticket#)
    -------  --------  --------  ------------------------------------------------------------------------------
        1.0  12/28/09  MDodge    Kronos Transformations Project - Initial Version.
        1.1  07/07/10  MDodge    R240693 - Defined Special Identifier 1 for PHL to be Project View Manager.
        1.2  08/02/10  MDodge    R298560 - Change Project View Manager to <= 80 from prior value of <= 90.
        1.3  9/22/10   WManasfi  R359662 - added Argentina Trilingual test and setting of ag_kr_emp_data.special_identifier4 to Y/N
        1.4  9/29/10   CChan     R371566 - Argentina New Collective Bargaining Agreement - Adding special_identifier3
                                           to pass the Daily working hour of the employee which can be derived from
                                           paaf.ass_attribute14 (aka arg_daily_hours) to Taleo to calculate the OT of the employee.
        1.5  10/2/10   WManasfi  Mexico Payroll - added procedure to test eligible employees added  GET_MEX_VAC_ELIGIBLE

        1.6  12/2/10   WManasfi  PHL PTO - vacation sick merge
        1.7  01/01/10  Wamanasfi hard coded dates to 1-JAN
		1.0  11/MAY/23 RXNETHI-ARGANO          R12.2 Upgrade Remediation
   \*== END ==================================================================================================*/
   --g_kr_emp_data                 cust.ttec_kr_emp_master%ROWTYPE; --code commented by RXNETHI-ARGANO,11/05/23
   g_kr_emp_data                 apps.ttec_kr_emp_master%ROWTYPE; --code added by RXNETHI-ARGANO,11/05/23
   g_csr_data                    ttec_kr_person_outbound.csr_emp_data%ROWTYPE;
   -- Error Constants -- Passed in by calling package
   --g_label1                      cust.ttec_error_handling.label1%TYPE  --code commented by RXNETHI-ARGANO,11/05/23
   g_label1                      apps.ttec_error_handling.label1%TYPE    --code added by RXNETHI-ARGANO,11/05/23
                                                            := 'Err Location';
   --g_label2                      cust.ttec_error_handling.label1%TYPE  --code commented by RXNETHI-ARGANO,11/05/23
   g_label2                      apps.ttec_error_handling.label1%TYPE    --code added by RXNETHI-ARGANO,11/05/23
                                                              := 'Emp_Number';
   -- declare who columns
   g_request_id                  NUMBER := fnd_global.conc_request_id;
   g_created_by                  NUMBER := fnd_global.user_id;
  -- g_calc_date                   DATE := trunc(sysdate); -- '15-JAN-2011';   -- for testing in PROD set it to TRUNC(SYSDATE)
   g_calc_date                   DATE := '01-JAN-2011';   -- for testing in PROD set it to TRUNC(SYSDATE)
 --  g_run_date                    DATE := trunc(sysdate); -- ;   -- for testing in PROD set it to TRUNC(SYSDATE)
   g_run_date                    DATE := '01-JAN-2011';   -- for testing in PROD set it to TRUNC(SYSDATE)

   /*********************************************************
   **  Private Procedures and Functions
   *********************************************************/
   PROCEDURE get_location_desc(
      p_location_code   IN       VARCHAR2
    , p_location_desc   OUT      VARCHAR2 )
   IS
      --v_module                      cust.ttec_error_handling.module_name%TYPE --code commented by RXNETHI-ARGANO,11/05/23
	  v_module                      apps.ttec_error_handling.module_name%TYPE --code added by RXNETHI-ARGANO,11/05/23
                                                       := 'get_location_desc';
      v_loc                         NUMBER;
   BEGIN
      v_loc    := 10;

      SELECT t.description
      INTO   p_location_desc
      FROM   fnd_flex_values v, fnd_flex_value_sets s, fnd_flex_values_tl t
      WHERE  s.flex_value_set_name LIKE 'TELETECH_LOCATION'
      AND    v.flex_value_set_id = s.flex_value_set_id
      AND    v.flex_value = p_location_code
      AND    t.flex_value_id = v.flex_value_id
      AND    t.LANGUAGE = 'US';
   EXCEPTION
      WHEN OTHERS
      THEN
         p_location_desc    := NULL;
         ttec_error_logging.process_error( g_application_code
                                         , g_interface
                                         , g_package
                                         , v_module
                                         , g_warning_status
                                         , SQLCODE
                                         , SQLERRM
                                         , g_label1
                                         , v_loc
                                         , 'Location Code'
                                         , p_location_code );
   END get_location_desc;

   -- Argentina
   PROCEDURE build_ar_values
   IS
      --v_module                      cust.ttec_error_handling.module_name%TYPE --code commented by RXNETHI-ARGANO,11/05/23
	  v_module                      apps.ttec_error_handling.module_name%TYPE --code added by RXNETHI-ARGANO,11/05/23
                                                         := 'build_ar_values';
      v_loc                         NUMBER;
      --v_job_name                    hr.per_jobs.NAME%TYPE; --code commented by RXNETHI-ARGANO.11/05/23
	  v_job_name                    apps.per_jobs.NAME%TYPE; --code added by RXNETHI-ARGANO.11/05/23
      v_vacation_plan_id            NUMBER;
      v_sick_plan_id                NUMBER;
      v_vacation_plan_category      pay_accrual_plans.accrual_category%TYPE
                                                                       := 'V';
      v_sick_plan_category          pay_accrual_plans.accrual_category%TYPE
                                                                       := 'S';
   BEGIN
      v_loc                                := 10;
      -- Union / Non Union
      g_kr_emp_data.special_identifier1    := g_csr_data.arg_union;
      v_loc                                := 20;

      IF g_kr_emp_data.job_id IS NOT NULL
      THEN
         BEGIN
            SELECT NAME
            INTO   v_job_name
            --FROM   hr.per_jobs pj --code commented by RXNETHI-ARGANO,11/05/23
			FROM   apps.per_jobs pj --code added by RXNETHI-ARGANO,11/05/23
            WHERE  pj.job_id = g_kr_emp_data.job_id;
         EXCEPTION
            WHEN OTHERS
            THEN
               ttec_error_logging.process_error
                                         ( g_application_code
                                         , g_interface
                                         , g_package
                                         , v_module
                                         , g_warning_status
                                         , SQLCODE
                                         , 'Unable to get Employee Job Name'
                                         , g_label1
                                         , v_loc
                                         , g_label2
                                         , g_kr_emp_data.employee_number
                                         , 'Job ID'
                                         , g_kr_emp_data.job_id );
         END;
      END IF;

      v_loc                                := 30;
      g_kr_emp_data.special_identifier2    := 'N';   -- V1.3
      g_kr_emp_data.special_identifier4    := 'N';   -- V1.3

      -- Bilingual special_identifier 2 (Y / N)
      -- Trilingualspecial_identifier 4 (Y / N )
      IF v_job_name LIKE '%Bilingual%'
      THEN
         g_kr_emp_data.special_identifier2    := 'Y';
      ELSIF v_job_name LIKE '%Trilingual%'
      THEN   -- V1.3
         g_kr_emp_data.special_identifier4    := 'Y';
      END IF;

      v_loc                                := 40;

      -- Build Accrual Profile
      IF g_csr_data.arg_union = 'Union'
      THEN
         g_kr_emp_data.accrual_profile    := 'AR-Union';
      ELSIF g_csr_data.arg_union = 'Non Union'
      THEN
         g_kr_emp_data.accrual_profile    := 'AR-NonUnion';
      END IF;

      /* V1.4 Begin */
      v_loc                                := 50;

      IF g_csr_data.arg_daily_hours IS NOT NULL
      THEN
         g_kr_emp_data.special_identifier3    := g_csr_data.arg_daily_hours;
      ELSE
         ttec_error_logging.process_error
            ( g_application_code
            , g_interface
            , g_package
            , v_module
            , g_warning_status
            , NULL
            , 'Carga Horaria Diaria(Daily Hours) not set on Employee Assignment'
            , g_label1
            , v_loc
            , g_label2
            , g_kr_emp_data.employee_number
            , 'Country'
            , g_kr_emp_data.country );
      END IF;
   /* V1.4 End */
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error( g_application_code
                                         , g_interface
                                         , g_package
                                         , v_module
                                         , g_warning_status
                                         , SQLCODE
                                         , SQLERRM
                                         , g_label1
                                         , v_loc
                                         , g_label2
                                         , g_kr_emp_data.employee_number
                                         , 'Country'
                                         , g_kr_emp_data.country );
   END build_ar_values;

   -- Australia
   PROCEDURE build_au_values
   IS
      --v_module                      cust.ttec_error_handling.module_name%TYPE --code commented by RXNETHI-ARGANO,11/05/23
	  v_module                      apps.ttec_error_handling.module_name%TYPE --code added by RXNETHI-ARGANO,11/05/23
                                                         := 'build_au_values';
      v_loc                         NUMBER;
      v_salary_limit                NUMBER;   -- Set on Attribute1 of the BARGAINING_UNIT_CODE lu for AUS
      v_emp_salary                  per_pay_proposals.proposed_salary_n%TYPE;
      v_bargain_unit_code           per_all_assignments_f.bargaining_unit_code%TYPE;
      v_vacation_plan_id            NUMBER;
      v_vacation_plan_category      pay_accrual_plans.accrual_category%TYPE
                                                                    := 'AUAL';
   BEGIN
      v_loc    := 10;

      -- Get Contract Type and Hours
      BEGIN
         SELECT flv.meaning
              , SUBSTR( paa.ass_attribute2
                      , 1
                      , INSTR( paa.ass_attribute2, ' ' )
                        - 1 )
              , flv.attribute1
              , paa.bargaining_unit_code
         INTO   g_kr_emp_data.special_identifier1   -- Contract Type
              , g_kr_emp_data.special_identifier2   -- Contract Hours
              , v_salary_limit
              , v_bargain_unit_code
         FROM   per_all_assignments_f paa, fnd_lookup_values flv
         WHERE  paa.assignment_id = g_kr_emp_data.assignment_id
         AND    paa.effective_start_date =
                   ( SELECT MAX( paa2.effective_start_date )
                    --FROM   hr.per_all_assignments_f paa2  --code commented by RXNETHI-ARGANO,11/05/23
                    FROM   apps.per_all_assignments_f paa2  --code added by RXNETHI-ARGANO,11/05/23
                    WHERE  paa2.person_id = paa.person_id
                    AND    paa2.effective_start_date <= TRUNC( SYSDATE )
                    AND    paa2.primary_flag = 'Y' )
         AND    flv.lookup_type(+) = 'BARGAINING_UNIT_CODE'
         AND    flv.lookup_code(+) = paa.bargaining_unit_code
         AND    flv.LANGUAGE(+) = 'US'
         AND    flv.security_group_id(+) = 28;

         IF v_bargain_unit_code IS NULL
         THEN
            ttec_error_logging.process_error
                          ( g_application_code
                          , g_interface
                          , g_package
                          , v_module
                          , g_warning_status
                          , NULL
                          , 'Bargaining Unit not set on Employee Assignment'
                          , g_label1
                          , v_loc
                          , g_label2
                          , g_kr_emp_data.employee_number
                          , 'Country'
                          , g_kr_emp_data.country );
         ELSIF g_kr_emp_data.special_identifier1 IS NULL
         THEN
            ttec_error_logging.process_error
                                          ( g_application_code
                                          , g_interface
                                          , g_package
                                          , v_module
                                          , g_warning_status
                                          , NULL
                                          , 'Invalid Employee Contract Type'
                                          , g_label1
                                          , v_loc
                                          , g_label2
                                          , g_kr_emp_data.employee_number
                                          , 'Country'
                                          , g_kr_emp_data.country
                                          , 'Bargain Unit Code'
                                          , v_bargain_unit_code );
         END IF;
      EXCEPTION
         WHEN OTHERS
         THEN
            ttec_error_logging.process_error( g_application_code
                                            , g_interface
                                            , g_package
                                            , v_module
                                            , g_warning_status
                                            , SQLCODE
                                            , SQLERRM
                                            , g_label1
                                            , v_loc
                                            , g_label2
                                            , g_kr_emp_data.employee_number
                                            , 'Country'
                                            , g_kr_emp_data.country );
      END;

      -- Determine if Employees Salary exceeds Salary Limit
      IF v_salary_limit IS NOT NULL
      THEN
         v_loc    := 20;

         BEGIN
            -- Get Employees Salary
            SELECT proposed_salary_n
            INTO   v_emp_salary
            FROM   per_pay_proposals
            WHERE  assignment_id = g_kr_emp_data.assignment_id
            AND    TRUNC( SYSDATE ) BETWEEN change_date AND date_to
            AND    approved = 'Y';
         EXCEPTION
            WHEN OTHERS
            THEN
               ttec_error_logging.process_error
                                             ( g_application_code
                                             , g_interface
                                             , g_package
                                             , v_module
                                             , g_warning_status
                                             , SQLCODE
                                             , SQLERRM
                                             , g_label1
                                             , v_loc
                                             , g_label2
                                             , g_kr_emp_data.employee_number
                                             , 'Country'
                                             , g_kr_emp_data.country );
         END;

         v_loc    := 30;

         IF v_emp_salary > v_salary_limit
         THEN
            g_kr_emp_data.special_identifier3    := 'Y';
         ELSE
            g_kr_emp_data.special_identifier3    := 'N';
         END IF;
      ELSE
         ttec_error_logging.process_error
                                 ( g_application_code
                                 , g_interface
                                 , g_package
                                 , v_module
                                 , g_warning_status
                                 , NULL
                                 , 'Salary Limit not set on Bargaining Unit'
                                 , g_label1
                                 , v_loc
                                 , g_label2
                                 , g_kr_emp_data.employee_number
                                 , 'Country'
                                 , g_kr_emp_data.country
                                 , 'Bargain Unit Code'
                                 , v_bargain_unit_code );
      END IF;

      v_loc    := 40;
      -- Build Accrual Profile
      ttec_kr_utils.get_accrual_plan( v_vacation_plan_category
                                    , g_kr_emp_data.assignment_id
                                    , v_vacation_plan_id );

      IF v_vacation_plan_id IS NOT NULL
      THEN
         g_kr_emp_data.accrual_profile    := 'AU-CA Annual Leave Sick Bank';
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error( g_application_code
                                         , g_interface
                                         , g_package
                                         , v_module
                                         , g_warning_status
                                         , SQLCODE
                                         , SQLERRM
                                         , g_label1
                                         , v_loc
                                         , g_label2
                                         , g_kr_emp_data.employee_number
                                         , 'Country'
                                         , g_kr_emp_data.country );
   END build_au_values;

   -- Brazil
   PROCEDURE build_br_values
   IS
      --v_module                      cust.ttec_error_handling.module_name%TYPE  --code commented by RXNETHI-ARGANO,11/05/23
      v_module                      apps.ttec_error_handling.module_name%TYPE    --code added by RXNETHI-ARGANO,11/05/23
                                                         := 'build_br_values';
      v_loc                         NUMBER;
   BEGIN
      v_loc    := 10;

      -- Build Accrual Profile
      IF g_kr_emp_data.employee_type = 'Agent'
      THEN
         g_kr_emp_data.accrual_profile    := 'BR-Banco de Horas';
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error( g_application_code
                                         , g_interface
                                         , g_package
                                         , v_module
                                         , g_warning_status
                                         , SQLCODE
                                         , SQLERRM
                                         , g_label1
                                         , v_loc
                                         , g_label2
                                         , g_kr_emp_data.employee_number
                                         , 'Country'
                                         , g_kr_emp_data.country );
   END build_br_values;

   -- Canada
   PROCEDURE build_ca_values
   IS
      --v_module                      cust.ttec_error_handling.module_name%TYPE --code commented by RXNETHI-ARGANO,11/05/23
	  v_module                      apps.ttec_error_handling.module_name%TYPE --code added by RXNETHI-ARGANO,11/05/23
                                                         := 'build_ca_values';
      v_loc                         NUMBER;
      v_location_desc               fnd_flex_values_tl.description%TYPE;
      v_vacation_plan_id            NUMBER;
      v_sick_plan_id                NUMBER;
      v_vacation_plan_category      pay_accrual_plans.accrual_category%TYPE
                                                                       := 'V';
      v_sick_plan_category          pay_accrual_plans.accrual_category%TYPE
                                                                       := 'S';
   BEGIN
      v_loc    := 10;

      -- Check for Percepta
      IF g_kr_emp_data.LOCATION IS NOT NULL
      THEN
         get_location_desc( g_kr_emp_data.LOCATION, v_location_desc );
      ELSE
         ttec_error_logging.process_error
                               ( g_application_code
                               , g_interface
                               , g_package
                               , v_module
                               , g_warning_status
                               , NULL
                               , 'Location Code not determined for Employee'
                               , g_label1
                               , v_loc
                               , g_label2
                               , g_kr_emp_data.employee_number
                               , 'Country'
                               , g_kr_emp_data.country );
      END IF;

      v_loc    := 20;

      IF v_location_desc LIKE 'PERCEPTA%'
      THEN
         g_kr_emp_data.special_identifier2    := 'Y';
      ELSE
         g_kr_emp_data.special_identifier2    := 'N';
      END IF;

      v_loc    := 30;
      -- Build Accrual Profile
      ttec_kr_utils.get_accrual_plan( v_vacation_plan_category
                                    , g_kr_emp_data.assignment_id
                                    , v_vacation_plan_id );
      ttec_kr_utils.get_accrual_plan( v_sick_plan_category
                                    , g_kr_emp_data.assignment_id
                                    , v_sick_plan_id );

      IF v_vacation_plan_id IS NOT NULL
      THEN
         IF v_sick_plan_id IS NOT NULL
         THEN
            g_kr_emp_data.accrual_profile    := 'CA-Vacation and Sick';
         ELSE
            g_kr_emp_data.accrual_profile    := 'CA-Vacation';
         END IF;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error( g_application_code
                                         , g_interface
                                         , g_package
                                         , v_module
                                         , g_warning_status
                                         , SQLCODE
                                         , SQLERRM
                                         , g_label1
                                         , v_loc
                                         , g_label2
                                         , g_kr_emp_data.employee_number
                                         , 'Country'
                                         , g_kr_emp_data.country );
   END build_ca_values;

   -- Costa Rica
   PROCEDURE build_cr_values
   IS
      --v_module                      cust.ttec_error_handling.module_name%TYPE --code commented by RXNETHI-ARGANO,11/05/23
	  v_module                      apps.ttec_error_handling.module_name%TYPE --code added by RXNETHI-ARGANO,11/05/23
                                                         := 'build_cr_values';
      v_loc                         NUMBER;
   BEGIN
      v_loc                                := 10;

      -- Shift Type (Day, Mixed, Night)
      SELECT DECODE( SUBSTR( g_csr_data.shift_indicator, 1, 1 )
                   , 'D', 'Day'
                   , 'M', 'Mixed'
                   , 'N', 'Night'
                   , NULL )
      INTO   g_kr_emp_data.special_identifier1
      FROM   DUAL;

      -- Hours per Day
      g_kr_emp_data.special_identifier2    :=
                                    SUBSTR( g_csr_data.shift_indicator, 2, 1 );
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error( g_application_code
                                         , g_interface
                                         , g_package
                                         , v_module
                                         , g_warning_status
                                         , SQLCODE
                                         , SQLERRM
                                         , g_label1
                                         , v_loc
                                         , g_label2
                                         , g_kr_emp_data.employee_number
                                         , 'Country'
                                         , g_kr_emp_data.country );
   END build_cr_values;

   -- Hong Kong
   PROCEDURE build_hk_values
   IS
      --v_module                      cust.ttec_error_handling.module_name%TYPE --code commented by RXNETHI-ARGANO,11/05/23
	  v_module                      apps.ttec_error_handling.module_name%TYPE --code added by RXNETHI-ARGANO,11/05/23
                                                         := 'build_hk_values';
      v_loc                         NUMBER;
   BEGIN
      v_loc                            := 10;
      -- Build Accrual Profile -> Default for HK
      g_kr_emp_data.accrual_profile    := 'HK-Compensation Leave';
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error( g_application_code
                                         , g_interface
                                         , g_package
                                         , v_module
                                         , g_warning_status
                                         , SQLCODE
                                         , SQLERRM
                                         , g_label1
                                         , v_loc
                                         , g_label2
                                         , g_kr_emp_data.employee_number
                                         , 'Country'
                                         , g_kr_emp_data.country );
   END build_hk_values;

   -- Mexico
   -- Mexico
   PROCEDURE build_mx_values
   IS
      --v_module                      cust.ttec_error_handling.module_name%TYPE --code commented by RXNETHI-ARGANO,11/05/23
	  v_module                      apps.ttec_error_handling.module_name%TYPE --code added by RXNETHI-ARGANO,11/05/23
                                                         := 'build_mx_values';
      v_vacation_plan_id            NUMBER;   /* v 1.5 Mexico Payroll */
      v_vacation_plan_category      pay_accrual_plans.accrual_category%TYPE
                                                                       := 'V';
      /* v 1.5 Mexico Payroll */
      v_loc                         NUMBER;
      v_calculation_date            DATE;
      v_hire_date                   DATE;
      v_empl_elig                   NUMBER := 0;
   BEGIN
      v_loc    := 10;

      -- Shift Type (Day, Mixed, Night)
      SELECT DECODE( SUBSTR( g_csr_data.shift_indicator, 1, 1 )
                   , 'D', 'Day'
                   , 'M', 'Mixed'
                   , 'N', 'Night'
                   , NULL )
      INTO   g_kr_emp_data.special_identifier1
      FROM   DUAL;

      /* v 1.5 Mexico Payroll */
      ttec_kr_utils.get_accrual_plan( v_vacation_plan_category
                                    , g_kr_emp_data.assignment_id
                                    , v_vacation_plan_id );

      -- old code  IF V_VACATION_PLAN_ID IS NOT NULL
      --   THEN
      --      G_KR_EMP_DATA.ACCRUAL_PROFILE := 'MX-Vacation';
       --  END IF;
       -- new code
       -- v1.5 added following
      BEGIN
         SELECT ptp.start_date
         INTO   v_calculation_date
         --FROM   hr.per_time_periods ptp --code commented by RXNETHI-ARGANO,11/05/23
		 FROM   apps.per_time_periods ptp --code added by RXNETHI-ARGANO,11/05/23
         WHERE  ptp.payroll_id = g_kr_emp_data.payroll_id
         AND    TRUNC( SYSDATE ) BETWEEN ptp.start_date AND ptp.end_date;

         v_calculation_date    := v_calculation_date - 1;
      EXCEPTION
         WHEN OTHERS
         THEN
            v_calculation_date    := NULL;
            ttec_error_logging.process_error
                                     ( g_application_code
                                     , g_interface
                                     , g_package
                                     , v_module
                                     , g_warning_status
                                     , SQLCODE
                                     , 'Unable to get Employee Payroll Info'
                                     , g_label1
                                     , v_loc
                                     , g_label2
                                     , g_kr_emp_data.employee_number
                                     , 'Payroll ID'
                                     , g_kr_emp_data.payroll_id );
      END;

      IF v_vacation_plan_id IS NOT NULL
      THEN
         -- v1.5
         ttec_kr_utils.get_mex_vac_eligible( v_calculation_date
                                           , g_kr_emp_data.person_id
                                           , v_hire_date
                                           , v_empl_elig );

         -- get if eligible
         IF v_empl_elig > 0
         THEN
            IF g_kr_emp_data.employee_type = 'Agent'
            THEN
               g_kr_emp_data.accrual_profile    := 'MX-Vacation';
            ELSE
               g_kr_emp_data.accrual_profile    := 'MX-Vacation GA';
            END IF;
         ELSE
            g_kr_emp_data.accrual_profile    := 'MX-Empty';
         END IF;
      END IF;
   /* v 1.5 Mexico Payroll end changes */
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error( g_application_code
                                         , g_interface
                                         , g_package
                                         , v_module
                                         , g_warning_status
                                         , SQLCODE
                                         , SQLERRM
                                         , g_label1
                                         , v_loc
                                         , g_label2
                                         , g_kr_emp_data.employee_number
                                         , 'Country'
                                         , g_kr_emp_data.country );
   END build_mx_values;

   /* V 1.5 Mexico Payroll Implementation */
   /*
   determine if employee has been on the current job for over a year
   return 1 if employee has been there for over a year and is eligible for vacation
   return 0 if employee has been there for less than a year and is NOT eligible for vacation

   */
   PROCEDURE get_mex_vac_eligible(
      p_calculation_date   IN       DATE
    , p_person_id          IN       NUMBER
    , p_hire_date          OUT      DATE
    , p_empl_elig          OUT      NUMBER )
   IS
      --v_module                      cust.ttec_error_handling.module_name%TYPE --code commented by RXNETHI-ARGANO,11/05/23
	  v_module                      apps.ttec_error_handling.module_name%TYPE --code added by RXNETHI-ARGANO,11/05/23
                                                    := 'get_mex_vac_eligible';
      v_last_hire_date              DATE;
      v_num_yrs                     NUMBER;
      v_loc                         NUMBER;
   BEGIN
      v_loc          := 10;
      p_empl_elig    := 0;
      p_hire_date    := TRUNC( SYSDATE );

      BEGIN
         -- Get employee last hire date from per_periods_of_service
         SELECT MAX( date_start )
         INTO   v_last_hire_date
         FROM   per_periods_of_service
         WHERE  person_id = p_person_id
         AND    business_group_id = 1633
         AND    (    actual_termination_date IS NULL
                  OR actual_termination_date <= p_calculation_date );

         p_hire_date    := v_last_hire_date;

         SELECT ( ( p_calculation_date
                    - v_last_hire_date ) / 365 )
         INTO   v_num_yrs
         FROM   DUAL;

         IF v_num_yrs >= 1.0
         THEN
            p_empl_elig    := 1.0;
         END IF;
      EXCEPTION
         WHEN OTHERS
         THEN
            p_hire_date    := SYSDATE;
            p_empl_elig    := 0;
            ttec_error_logging.process_error
               ( g_application_code
               , g_interface
               , g_package
               , v_module
               , g_warning_status
               , SQLCODE
               , 'Unable to get Employee Start date info- per_periods_of_service'
               , g_label1
               , v_loc
               , g_label2
               , g_kr_emp_data.employee_number
               , 'Person ID'
               , g_kr_emp_data.person_id );
      END;

   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error
                ( g_application_code
                , g_interface
                , g_package
                , v_module
                , g_warning_status
                , SQLCODE
                , 'Unable Sysdate - Date Start (per_periods_of_service info'
                , g_label1
                , v_loc
                , g_label2
                , g_kr_emp_data.employee_number
                , 'Person ID'
                , g_kr_emp_data.person_id );
   END get_mex_vac_eligible;

   -- New Zealand
   PROCEDURE build_nz_values
   IS
      --v_module                      cust.ttec_error_handling.module_name%TYPE --code commented by RXNETHI-ARGANO,11/05/23
	  v_module                      apps.ttec_error_handling.module_name%TYPE --code added by RXNETHI-ARGANO,11/05/23
                                                         := 'build_nz_values';
      v_loc                         NUMBER;
   BEGIN
      v_loc                            := 10;
      -- Build Accrual Profile -> Default for NZ
      g_kr_emp_data.accrual_profile    := 'NZ-Annual Sick and Lieu';
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error( g_application_code
                                         , g_interface
                                         , g_package
                                         , v_module
                                         , g_warning_status
                                         , SQLCODE
                                         , SQLERRM
                                         , g_label1
                                         , v_loc
                                         , g_label2
                                         , g_kr_emp_data.employee_number
                                         , 'Country'
                                         , g_kr_emp_data.country );
   END build_nz_values;

   -- Philippines
   PROCEDURE build_ph_values
   IS
      --v_module                      cust.ttec_error_handling.module_name%TYPE --code commented by RXNETHI-ARGANO,11/05/23
	  v_module                      apps.ttec_error_handling.module_name%TYPE --code added by RXNETHI-ARGANO,11/05/23
                                                         := 'build_ph_values';
      v_loc                         NUMBER;
      v_mgr_level                   NUMBER;
      v_vacation_plan_id            NUMBER;
      v_sick_plan_id                NUMBER;
      v_pto_plan_id                 NUMBER;   -- v1.6
      v_vacation_plan_category      pay_accrual_plans.accrual_category%TYPE
                                                                       := 'V';
      v_sick_plan_category          pay_accrual_plans.accrual_category%TYPE
                                                                       := 'S';
      v_pto_plan_category           pay_accrual_plans.accrual_category%TYPE
                                                                     := 'P';   -- v1.6
      v_date_01_jan_2011            DATE := '01-JAN-2011';
   BEGIN
      v_loc    := 10;

      -- Build Special Identifier 1 - Project View Manager    /* 1.1 */
      IF g_kr_emp_data.job_id IS NOT NULL
      THEN
         BEGIN
            SELECT ffv.attribute20
            INTO   v_mgr_level
            /*
			START R12.2 Upgrade Remediation
			code commented by RXNETHI-ARGANO,11/05/23
			FROM   hr.per_jobs pj
                 , applsys.fnd_flex_value_sets ffvs
                 , applsys.fnd_flex_values ffv
            */
			--code added by RXNETHI-ARGANO,11/05/23
			FROM   apps.per_jobs pj
                 , apps.fnd_flex_value_sets ffvs
                 , apps.fnd_flex_values ffv
			--END R12.2 Upgrade Remediation
			WHERE  pj.job_id = g_kr_emp_data.job_id
            AND    ffvs.flex_value_set_name = 'TELETECH_MANAGER_LEVEL_VS'
            AND    ffv.flex_value_set_id = ffvs.flex_value_set_id
            AND    ffv.flex_value = pj.attribute6;
         EXCEPTION
            WHEN OTHERS
            THEN
               ttec_error_logging.process_error
                           ( g_application_code
                           , g_interface
                           , g_package
                           , v_module
                           , g_warning_status
                           , SQLCODE
                           , 'Unable to get Employee Manager Level from Job'
                           , g_label1
                           , v_loc
                           , g_label2
                           , g_kr_emp_data.employee_number
                           , 'Job ID'
                           , g_kr_emp_data.job_id );
         END;

         IF v_mgr_level <= 80
         THEN   /* 1.2 */
            g_kr_emp_data.special_identifier1    := 'Y';
         ELSE
            g_kr_emp_data.special_identifier1    := 'N';
         END IF;
      END IF;

      /* End 1.1 */
      v_loc    := 20;
      -- Build Accrual Profile
      ttec_kr_utils.get_accrual_plan( v_vacation_plan_category
                                    , g_kr_emp_data.assignment_id
                                    , v_vacation_plan_id );
      ttec_kr_utils.get_accrual_plan( v_sick_plan_category
                                    , g_kr_emp_data.assignment_id
                                    , v_sick_plan_id );
      ttec_kr_utils.get_accrual_plan( v_pto_plan_category
                                    , g_kr_emp_data.assignment_id
                                    , v_pto_plan_id );   -- v1.6

      -- we set it even if one is populate                 -- v1.6
      IF g_run_date >= v_date_01_jan_2011   -- this is sysdate in PROD
      THEN   -- v1.6
         IF (    ( v_pto_plan_id IS NOT NULL )
              OR   -- v1.6
                 ( v_vacation_plan_id IS NOT NULL )
              OR   -- v1.6
                 ( v_sick_plan_id IS NOT NULL )   -- v1.6
                                               )   -- v1.6
         THEN   --                            -- v1.6
            g_kr_emp_data.accrual_profile    := 'PH-PTO';   -- v1.6
         ELSE   -- v1.6
            g_kr_emp_data.accrual_profile    := 'PH-Empty';   -- v1.6
         END IF;   -- v1.6
      ELSE   -- v1.6
         IF     v_vacation_plan_id IS NOT NULL
            AND v_sick_plan_id IS NOT NULL
         THEN
            g_kr_emp_data.accrual_profile    := 'PH-Vacation and Sick';
         END IF;
      END IF;   -- date > 1-1-2011  --v1.6
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error( g_application_code
                                         , g_interface
                                         , g_package
                                         , v_module
                                         , g_warning_status
                                         , SQLCODE
                                         , SQLERRM
                                         , g_label1
                                         , v_loc
                                         , g_label2
                                         , g_kr_emp_data.employee_number
                                         , 'Country'
                                         , g_kr_emp_data.country );
   END build_ph_values;

   -- Great Britain / UK
   PROCEDURE build_uk_values
   IS
      --v_module                      cust.ttec_error_handling.module_name%TYPE --code commented by RXNETHI-ARGANO,11/05/23
	  v_module                      apps.ttec_error_handling.module_name%TYPE --code added by RXNETHI-ARGANO,11/05/23
                                                         := 'build_uk_values';
      v_loc                         NUMBER;
      v_vacation_plan_id            NUMBER;
      v_sick_plan_id                NUMBER;
      v_vacation_plan_category      pay_accrual_plans.accrual_category%TYPE
                                                                       := 'V';
      v_sick_plan_category          pay_accrual_plans.accrual_category%TYPE
                                                                       := 'S';
   BEGIN
      v_loc    := 10;
      -- Build Accrual Profile
      ttec_kr_utils.get_accrual_plan( v_vacation_plan_category
                                    , g_kr_emp_data.assignment_id
                                    , v_vacation_plan_id );
      ttec_kr_utils.get_accrual_plan( v_sick_plan_category
                                    , g_kr_emp_data.assignment_id
                                    , v_sick_plan_id );

      IF     v_vacation_plan_id IS NOT NULL
         AND v_sick_plan_id IS NOT NULL
      THEN
         g_kr_emp_data.accrual_profile    := 'GB-Annual and Sick Leave';
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error( g_application_code
                                         , g_interface
                                         , g_package
                                         , v_module
                                         , g_warning_status
                                         , SQLCODE
                                         , SQLERRM
                                         , g_label1
                                         , v_loc
                                         , g_label2
                                         , g_kr_emp_data.employee_number
                                         , 'Country'
                                         , g_kr_emp_data.country );
   END build_uk_values;

   -- United States
   PROCEDURE build_us_values
   IS
      --v_module                      cust.ttec_error_handling.module_name%TYPE --code commented by RXNETHI-ARGANO,11/05/23
	  v_module                      apps.ttec_error_handling.module_name%TYPE --code added by RXNETHI-ARGANO,11/05/23
                                                         := 'build_us_values';
      v_loc                         NUMBER;
      v_location_desc               fnd_flex_values_tl.description%TYPE;
      v_vacation_plan_id            NUMBER;
      v_sick_plan_id                NUMBER;
      v_holiday_plan_id             NUMBER;
      v_pluto_plan_id               NUMBER;
      v_vacation_plan_category      pay_accrual_plans.accrual_category%TYPE
                                                                       := 'V';
      v_sick_plan_category          pay_accrual_plans.accrual_category%TYPE
                                                                       := 'S';
      v_holiday_plan_category       pay_accrual_plans.accrual_category%TYPE
                                                                     := 'HML';
      v_pluto_plan_category         pay_accrual_plans.accrual_category%TYPE
                                                                   := 'PLUTO';
   BEGIN
      v_loc                                := 10;

      -- Check for DAC / Percepta / Govt Solutions
      IF g_kr_emp_data.LOCATION IS NOT NULL
      THEN
         get_location_desc( g_kr_emp_data.LOCATION, v_location_desc );
      ELSE
         ttec_error_logging.process_error
                               ( g_application_code
                               , g_interface
                               , g_package
                               , v_module
                               , g_warning_status
                               , NULL
                               , 'Location Code not determined for Employee'
                               , g_label1
                               , v_loc
                               , g_label2
                               , g_kr_emp_data.employee_number
                               , 'Country'
                               , g_kr_emp_data.country );
      END IF;

      v_loc                                := 20;
      g_kr_emp_data.special_identifier2    := 'N';
      g_kr_emp_data.special_identifier3    := 'N';
      g_kr_emp_data.special_identifier4    := 'N';

      IF v_location_desc LIKE 'PERCEPTA%'
      THEN
         g_kr_emp_data.special_identifier3    := 'Y';   -- Percepta Flag
      END IF;

      IF v_location_desc LIKE 'DIRECT ALLIANCE%'
      THEN
         g_kr_emp_data.special_identifier2    := 'Y';   -- DAC Flag
      END IF;

      IF g_kr_emp_data.payroll_name = 'Government Solutions'
      THEN
         g_kr_emp_data.special_identifier4    := 'Y';
      END IF;

      -- Get the Person Type Usage (ie Expatriate)
      v_loc                                := 30;

      BEGIN
         SELECT user_person_type
         INTO   g_kr_emp_data.special_identifier1
         FROM   per_person_type_usages_f pptu, per_person_types ppt
         WHERE  pptu.person_id = g_kr_emp_data.person_id
         AND    TRUNC( SYSDATE ) BETWEEN pptu.effective_start_date
                                     AND pptu.effective_end_date
         AND    ppt.person_type_id = pptu.person_type_id
         AND    ppt.active_flag = 'Y'
         AND    ppt.system_person_type = 'EMP';
      EXCEPTION
         WHEN OTHERS
         THEN
            ttec_error_logging.process_error( g_application_code
                                            , g_interface
                                            , g_package
                                            , v_module
                                            , g_warning_status
                                            , SQLCODE
                                            , SQLERRM
                                            , g_label1
                                            , v_loc
                                            , g_label2
                                            , g_kr_emp_data.employee_number
                                            , 'Country'
                                            , g_kr_emp_data.country );
      END;

      v_loc                                := 40;
/**********************************/
/*   Build Accrual Profile        */
/**********************************/

      -- Get Vacation Plan for DAC, Percepta and all other US employees
      ttec_kr_utils.get_accrual_plan( v_vacation_plan_category
                                    , g_kr_emp_data.assignment_id
                                    , v_vacation_plan_id );

      -- DAC - Vacation Only
      IF g_kr_emp_data.special_identifier2 = 'Y'
      THEN
         IF v_vacation_plan_id IS NOT NULL
         THEN
            g_kr_emp_data.accrual_profile    := 'US-DAC PTO';
         END IF;
      ELSE   -- Non-DAC
         -- Get Sick Plan for all Non-DAC US employees
         ttec_kr_utils.get_accrual_plan( v_sick_plan_category
                                       , g_kr_emp_data.assignment_id
                                       , v_sick_plan_id );

         -- Percepta - Vacation / Sick / Personal Holiday
         IF g_kr_emp_data.special_identifier3 = 'Y'
         THEN
            -- Ger Personal Holiday (Percepta Only)
            ttec_kr_utils.get_accrual_plan( v_holiday_plan_category
                                          , g_kr_emp_data.assignment_id
                                          , v_holiday_plan_id );

            IF     v_vacation_plan_id IS NOT NULL
               AND v_sick_plan_id IS NOT NULL
               AND v_holiday_plan_id IS NOT NULL
            THEN
               IF g_kr_emp_data.assignment_category_1 = 'PT'
               THEN
                  g_kr_emp_data.accrual_profile    := 'US-Vac Sick PersHolPT';
               ELSE
                  g_kr_emp_data.accrual_profile    := 'US-Vac Sick PersHol';
               END IF;
            END IF;
         ELSE   -- Non-Percepta (Non-DAC)
            -- Ger PLUTO (Non-Percepta)
            ttec_kr_utils.get_accrual_plan( v_pluto_plan_category
                                          , g_kr_emp_data.assignment_id
                                          , v_pluto_plan_id );

            IF v_vacation_plan_id IS NOT NULL
            THEN
               IF v_sick_plan_id IS NOT NULL
               THEN
                  IF v_pluto_plan_id IS NOT NULL
                  THEN
                     g_kr_emp_data.accrual_profile    :=
                                                     'US-PTO, Pluto and Sick';
                  ELSE   -- Vacation and Sick Only
                     g_kr_emp_data.accrual_profile    := 'US-PTO and Sick';
                  END IF;
               ELSE   -- No Sick Accrual assigned
                  IF v_pluto_plan_id IS NOT NULL
                  THEN
                     g_kr_emp_data.accrual_profile    := 'US-PTO and Pluto';
                  ELSE   -- Vacation Only
                     g_kr_emp_data.accrual_profile    := 'US-PTO';
                  END IF;
               END IF;
            END IF;
         END IF;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error( g_application_code
                                         , g_interface
                                         , g_package
                                         , v_module
                                         , g_warning_status
                                         , SQLCODE
                                         , SQLERRM
                                         , g_label1
                                         , v_loc
                                         , g_label2
                                         , g_kr_emp_data.employee_number
                                         , 'Country'
                                         , g_kr_emp_data.country );
   END build_us_values;

   -- South Africa
   PROCEDURE build_za_values
   IS
      --v_module                      cust.ttec_error_handling.module_name%TYPE--code commented by RXNETHI-ARGANO,11/05/23
	  v_module                      apps.ttec_error_handling.module_name%TYPE --code added by RXNETHI-ARGANO,11/05/23
                                                         := 'build_za_values';
      v_loc                         NUMBER;
   BEGIN
      v_loc                            := 10;
      -- Build Accrual Profile -> Default for NZ
      g_kr_emp_data.accrual_profile    := 'ZA-Annual Sick and Family Leave';
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error( g_application_code
                                         , g_interface
                                         , g_package
                                         , v_module
                                         , g_warning_status
                                         , SQLCODE
                                         , SQLERRM
                                         , g_label1
                                         , v_loc
                                         , g_label2
                                         , g_kr_emp_data.employee_number
                                         , 'Country'
                                         , g_kr_emp_data.country );
   END build_za_values;

   /*********************************************************
   **  Public Procedures and Functions
   *********************************************************/
   PROCEDURE get_accrual_plan(
      p_accrual_plan_type   IN       VARCHAR2
    , p_assignment_id       IN       NUMBER
    , p_accrual_plan_id     OUT      NUMBER )
   IS
      --v_module                      cust.ttec_error_handling.module_name%TYPE--code commented by RXNETHI-ARGANO,11/05/23
	  v_module                      apps.ttec_error_handling.module_name%TYPE --code added by RXNETHI-ARGANO,11/05/23
                                                        := 'get_accrual_plan';
      v_loc                         NUMBER;
   BEGIN
      v_loc    := 10;

      SELECT pap.accrual_plan_id
      INTO   p_accrual_plan_id
      FROM   pay_accrual_plans pap
           , pay_element_links_f pel
           , pay_element_entries_f pee
      WHERE  pap.accrual_category = p_accrual_plan_type
      AND    pel.element_type_id = pap.accrual_plan_element_type_id
      AND    g_calc_date BETWEEN pel.effective_start_date
                             AND pel.effective_end_date
      AND    pee.element_link_id = pel.element_link_id
      AND    pee.assignment_id = p_assignment_id
      AND    g_calc_date BETWEEN pee.effective_start_date
                             AND pee.effective_end_date;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         -- Accrual not active for this Emp.  Continue without logging.
         NULL;
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error( g_application_code
                                         , g_interface
                                         , g_package
                                         , v_module
                                         , g_error_status
                                         , SQLCODE
                                         , SQLERRM
                                         , g_label1
                                         , v_loc
                                         , 'Assignment ID'
                                         , p_assignment_id
                                         , 'Accrual Plan Type'
                                         , p_accrual_plan_type );
   END get_accrual_plan;

   PROCEDURE build_country_values(
      p_csr_data      IN       ttec_kr_person_outbound.csr_emp_data%ROWTYPE
    --, p_kr_emp_data   IN OUT   cust.ttec_kr_emp_master%ROWTYPE )  --code commented by RXNETHI-ARGANO,11/05/23
    , p_kr_emp_data   IN OUT   apps.ttec_kr_emp_master%ROWTYPE )    --code added by RXNETHI-ARGANO,11/05/23
   IS
      --v_module                      cust.ttec_error_handling.module_name%TYPE--code commented by RXNETHI-ARGANO,11/05/23
	  v_module                      apps.ttec_error_handling.module_name%TYPE --code added by RXNETHI-ARGANO,11/05/23
                                                    := 'build_country_values';
      v_loc                         NUMBER;
   BEGIN
      v_loc            := 10;
      -- Set input structure to global variables
      g_kr_emp_data    := p_kr_emp_data;
      g_csr_data       := p_csr_data;

      -- Argentina
      IF p_kr_emp_data.business_group_id = 1632
      THEN
         build_ar_values;
      -- Australia
      ELSIF p_kr_emp_data.business_group_id = 1839
      THEN
         build_au_values;
      -- Brazil
      ELSIF p_kr_emp_data.business_group_id = 1631
      THEN
         build_br_values;
      -- Canada
      ELSIF p_kr_emp_data.business_group_id = 326
      THEN
         build_ca_values;
      -- Costa Rica (Pseudo BG ID)
      ELSIF p_kr_emp_data.business_group_id = 5075
      THEN
         build_cr_values;
        -- Spain
      --  ELSIF p_kr_emp_data.business_group_id = 1804 THEN
      --    build_es_values;

      -- Hong Kong
      ELSIF p_kr_emp_data.business_group_id = 2287
      THEN
         build_hk_values;
      -- Mexico
      ELSIF p_kr_emp_data.business_group_id = 1633
      THEN
         build_mx_values;
        -- Malaysia
      --  ELSIF p_kr_emp_data.business_group_id = 2328 THEN
      --    build_my_values;

      -- New Zealand
      ELSIF p_kr_emp_data.business_group_id = 2311
      THEN
         build_nz_values;
      -- Philippines
      ELSIF p_kr_emp_data.business_group_id = 1517
      THEN
         build_ph_values;
        -- United Kingdom / Great Britain
      --  ELSIF p_kr_emp_data.business_group_id = 1761 THEN
      --    build_uk_values;

      -- United States
      ELSIF p_kr_emp_data.business_group_id = 325
      THEN
         build_us_values;
      -- South Africa (Pseudo BG ID)
      ELSIF p_kr_emp_data.business_group_id = 6536
      THEN
         build_za_values;
      -- Country Not identified
      ELSE
         NULL;
      END IF;

      -- Copy global variables back to Output Structures
      p_kr_emp_data    := g_kr_emp_data;
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error( g_application_code
                                         , g_interface
                                         , g_package
                                         , v_module
                                         , g_warning_status
                                         , SQLCODE
                                         , SQLERRM
                                         , g_label1
                                         , v_loc
                                         , g_label2
                                         , g_kr_emp_data.employee_number
                                         , 'Country'
                                         , g_kr_emp_data.country );
   END build_country_values;

/************************************************************************************/
/*                               SAVE_PROCESS_RUN_TIME                              */
/************************************************************************************/
   PROCEDURE save_process_run_time(
      v_request_id   NUMBER )
   IS
--v_module                      cust.ttec_error_handling.module_name%TYPE--code commented by RXNETHI-ARGANO,11/05/23
	  v_module                      apps.ttec_error_handling.module_name%TYPE --code added by RXNETHI-ARGANO,11/05/23
                                                   := 'save_process_run_time';
      v_loc                         NUMBER;

      CURSOR c_get_request
      IS
         SELECT program_application_id
              , concurrent_program_id
              , number_of_arguments
              , actual_start_date
              , argument1
              , argument2
              , argument3
              , argument4
              , argument5
              , argument6
              , argument7
              , argument8
              , argument9
              , argument10
         FROM   fnd_concurrent_requests
         WHERE  request_id = v_request_id;

      r_request                     c_get_request%ROWTYPE;
   BEGIN
      v_loc    := 10;

      OPEN c_get_request;

      FETCH c_get_request
      INTO  r_request;

      v_loc    := 20;

      IF c_get_request%FOUND
      THEN
         --INSERT INTO cust.ttec_kr_process_times --code commented by RXNETHI-ARGANO,11/05/23
		 INSERT INTO apps.ttec_kr_process_times --code added by RXNETHI-ARGANO,11/05/23
                     ( request_id
                     , program_application_id
                     , concurrent_program_id
                     , number_of_arguments
                     , actual_start_date
                     , actual_completion_date
                     , argument1
                     , argument2
                     , argument3
                     , argument4
                     , argument5
                     , argument6
                     , argument7
                     , argument8
                     , argument9
                     , argument10
                     , creation_date
                     , created_by
                     , last_update_date
                     , last_updated_by
                     , last_update_login )
              VALUES ( g_request_id
                     , r_request.program_application_id
                     , r_request.concurrent_program_id
                     , r_request.number_of_arguments
                     , r_request.actual_start_date
                     , SYSDATE
                     , r_request.argument1
                     , r_request.argument2
                     , r_request.argument3
                     , r_request.argument4
                     , r_request.argument5
                     , r_request.argument6
                     , r_request.argument7
                     , r_request.argument8
                     , r_request.argument9
                     , r_request.argument10
                     , SYSDATE
                     , g_created_by
                     , SYSDATE
                     , g_created_by
                     , NULL );
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error( g_application_code
                                         , g_interface
                                         , g_package
                                         , v_module
                                         , g_warning_status
                                         , SQLCODE
                                         , SQLERRM
                                         , g_label1
                                         , v_loc );
   END save_process_run_time;

/************************************************************************************/
/*                                  GET_LAST_RUN_DATE                               */
/************************************************************************************/
   PROCEDURE get_last_run_date(
      p_program_name    IN       fnd_concurrent_programs.concurrent_program_name%TYPE
    , p_arg1            IN       fnd_concurrent_requests.argument1%TYPE
            DEFAULT NULL
    , p_arg2            IN       fnd_concurrent_requests.argument2%TYPE
            DEFAULT NULL
    , p_arg3            IN       fnd_concurrent_requests.argument2%TYPE
            DEFAULT NULL
    , p_arg4            IN       fnd_concurrent_requests.argument2%TYPE
            DEFAULT NULL
    , p_arg5            IN       fnd_concurrent_requests.argument2%TYPE
            DEFAULT NULL
    , p_arg6            IN       fnd_concurrent_requests.argument2%TYPE
            DEFAULT NULL
    , p_arg7            IN       fnd_concurrent_requests.argument2%TYPE
            DEFAULT NULL
    , p_arg8            IN       fnd_concurrent_requests.argument2%TYPE
            DEFAULT NULL
    , p_arg9            IN       fnd_concurrent_requests.argument2%TYPE
            DEFAULT NULL
    , p_arg10           IN       fnd_concurrent_requests.argument2%TYPE
            DEFAULT NULL
    , p_last_run_date   OUT      DATE )
   IS
      --v_module                      cust.ttec_error_handling.module_name%TYPE  --code commented by RXNETHI-ARGANO,11/05/23
      v_module                      apps.ttec_error_handling.module_name%TYPE    --code added by RXNETHI-ARGANO,11/05/23
                                                       := 'get_last_run_date';
      v_loc                         NUMBER;
   BEGIN
      v_loc    := 10;

      -- Take date that preceeds implementation for first run.
      SELECT NVL( MAX( actual_start_date ), '01-JAN-2010' )
      INTO   p_last_run_date
      --FROM   cust.ttec_kr_process_times kpt      --code commented  by RXNETHI-ARGANO,11/05/23
      --     , applsys.fnd_concurrent_programs fcp --code commented  by RXNETHI-ARGANO,11/05/23
	  FROM   apps.ttec_kr_process_times kpt      --code added  by RXNETHI-ARGANO,11/05/23
           , apps.fnd_concurrent_programs fcp --code added  by RXNETHI-ARGANO,11/05/23
      WHERE  fcp.concurrent_program_name =
                                         p_program_name   --'TTEC_KR_ACCRUAL_OUT'
      AND    kpt.concurrent_program_id = fcp.concurrent_program_id
      -- Define but not passed params are NULL, however, non-defined params
      -- are set to ASCII value of 0 which does not evaluate as a SQL NULL
      AND    DECODE( ASCII( kpt.argument1 )
                   , NULL, NVL( TO_CHAR( '&p_arg1' ), 'x' )
                   , 0, NVL( TO_CHAR( '&p_arg1' ), 'x' )
                   , kpt.argument1 ) = NVL( TO_CHAR( '&p_arg1' ), 'x' )
      AND    DECODE( ASCII( kpt.argument2 )
                   , NULL, NVL( TO_CHAR( '&p_arg2' ), 'x' )
                   , 0, NVL( TO_CHAR( '&p_arg2' ), 'x' )
                   , kpt.argument2 ) = NVL( TO_CHAR( '&p_arg2' ), 'x' )
      AND    DECODE( ASCII( kpt.argument3 )
                   , NULL, NVL( TO_CHAR( '&p_arg3' ), 'x' )
                   , 0, NVL( TO_CHAR( '&p_arg3' ), 'x' )
                   , kpt.argument3 ) = NVL( TO_CHAR( '&p_arg3' ), 'x' )
      AND    DECODE( ASCII( kpt.argument4 )
                   , NULL, NVL( TO_CHAR( '&p_arg4' ), 'x' )
                   , 0, NVL( TO_CHAR( '&p_arg4' ), 'x' )
                   , kpt.argument4 ) = NVL( TO_CHAR( '&p_arg4' ), 'x' )
      AND    DECODE( ASCII( kpt.argument5 )
                   , NULL, NVL( TO_CHAR( '&p_arg5' ), 'x' )
                   , 0, NVL( TO_CHAR( '&p_arg5' ), 'x' )
                   , kpt.argument5 ) = NVL( TO_CHAR( '&p_arg5' ), 'x' )
      AND    DECODE( ASCII( kpt.argument6 )
                   , NULL, NVL( TO_CHAR( '&p_arg6' ), 'x' )
                   , 0, NVL( TO_CHAR( '&p_arg6' ), 'x' )
                   , kpt.argument6 ) = NVL( TO_CHAR( '&p_arg6' ), 'x' )
      AND    DECODE( ASCII( kpt.argument7 )
                   , NULL, NVL( TO_CHAR( '&p_arg7' ), 'x' )
                   , 0, NVL( TO_CHAR( '&p_arg7' ), 'x' )
                   , kpt.argument7 ) = NVL( TO_CHAR( '&p_arg7' ), 'x' )
      AND    DECODE( ASCII( kpt.argument8 )
                   , NULL, NVL( TO_CHAR( '&p_arg8' ), 'x' )
                   , 0, NVL( TO_CHAR( '&p_arg8' ), 'x' )
                   , kpt.argument8 ) = NVL( TO_CHAR( '&p_arg8' ), 'x' )
      AND    DECODE( ASCII( kpt.argument9 )
                   , NULL, NVL( TO_CHAR( '&p_arg9' ), 'x' )
                   , 0, NVL( TO_CHAR( '&p_arg9' ), 'x' )
                   , kpt.argument9 ) = NVL( TO_CHAR( '&p_arg9' ), 'x' )
      AND    DECODE( ASCII( kpt.argument10 )
                   , NULL, NVL( TO_CHAR( '&p_arg10' ), 'x' )
                   , 0, NVL( TO_CHAR( '&p_arg10' ), 'x' )
                   , kpt.argument10 ) = NVL( TO_CHAR( '&p_arg10' ), 'x' );
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error
                                     ( g_application_code
                                     , g_interface
                                     , g_package
                                     , v_module
                                     , g_warning_status
                                     , SQLCODE
                                     , 'Unable to get Process Last Run Date'
                                     , g_label1
                                     , v_loc );
   END get_last_run_date;

   PROCEDURE set_page_context(
      p_country   IN       VARCHAR2   /* Obsolete param */
    , p2          OUT      VARCHAR2   -- person_type
    , p3          OUT      VARCHAR2   -- time_zone_prompt
    , p4          OUT      VARCHAR2   -- location_code_prompt
    , p5          OUT      VARCHAR2   -- location_name_prompt
    , p6          OUT      VARCHAR2   -- wage_rate_prompt
    , p7          OUT      VARCHAR2   -- wage_profile_name_prompt
    , p8          OUT      VARCHAR2   -- accrual_profile_prompt
    , p9          OUT      VARCHAR2   -- func_access_profile_prompt
    , p10         OUT      VARCHAR2   -- display_profile_prompt
    , p11         OUT      VARCHAR2   -- fte_percentage_prompt
    , p12         OUT      VARCHAR2   -- fte_expected_hours_prompt
    , p13         OUT      VARCHAR2   -- fte_hours_prompt
    , p14         OUT      VARCHAR2   -- expected_daily_hours_prompt
    , p15         OUT      VARCHAR2   -- expected_weekly_hours_prompt
    , p16         OUT      VARCHAR2   -- expected_pay_period_hours_prompt
    , p17         OUT      VARCHAR2   -- device_group_prompt
    , p18         OUT      VARCHAR2   -- logon_profile_prompt
    , p19         OUT      VARCHAR2   -- emp_xfer_labor_prompt
    , p20         OUT      VARCHAR2   -- emp_pay_code_daprofile_prompt
    , p21         OUT      VARCHAR2   -- emp_work_rule_daprofile_prompt
    , p22         OUT      VARCHAR2   -- time_entry_method_prompt
    , p23         OUT      VARCHAR2   -- location_prompt
    , p24         OUT      VARCHAR2   -- client_prompt
    , p25         OUT      VARCHAR2   -- department_prompt
    , p26         OUT      VARCHAR2   -- program_prompt
    , p27         OUT      VARCHAR2   -- project_prompt
    , p28         OUT      VARCHAR2   -- activity_prompt
    , p29         OUT      VARCHAR2   -- team_prompt
    , p30         OUT      VARCHAR2   -- group_schedule_prompt
    , p31         OUT      VARCHAR2   -- employee_status_prompt
    , p32         OUT      VARCHAR2   -- user_status_prompt
    , p33         OUT      VARCHAR2   -- city_prompt
    , p34         OUT      VARCHAR2   -- state_province_prompt
    , p35         OUT      VARCHAR2   -- postal_code_prompt
    , p36         OUT      VARCHAR2   -- mgrtransferin_prompt
    , p37         OUT      VARCHAR2   -- mgremp_group_llset_prompt
    , p38         OUT      VARCHAR2   -- mgrxfer_llset_prompt
    , p39         OUT      VARCHAR2   -- mgrpay_code_dap_prompt
    , p40         OUT      VARCHAR2   -- mgrworkrule_dap_prompt
    , p41         OUT      VARCHAR2   -- mgrreport_dap_prompt
    , p42         OUT      VARCHAR2   -- gender_prompt
    , p43         OUT      VARCHAR2   -- flsa_prompt
    , p44         OUT      VARCHAR2   -- agency_name_prompt
    , p45         OUT      VARCHAR2   -- manages_multiple_countries_prompt
    , p46         OUT      VARCHAR2   -- payroll_name_prompt
    , p47         OUT      VARCHAR2   -- agent_support_flag_prompt
    , p48         OUT      VARCHAR2   -- employee_type_prompt
    , p49         OUT      VARCHAR2   -- employee_flag_prompt
    , p50         OUT      VARCHAR2   -- assignment_category_1_prompt
    , p51         OUT      VARCHAR2   -- assignment_category_2_prompt
    , p52         OUT      VARCHAR2   -- wah_flag_prompt
    , p53         OUT      VARCHAR2   -- job_title_prompt
    , p54         OUT      VARCHAR2   -- job_code_prompt
    , p55         OUT      VARCHAR2   -- salary_basis_prompt
    , p56         OUT      VARCHAR2   -- spec1_prompt
    , p57         OUT      VARCHAR2   -- spec2_prompt
    , p58         OUT      VARCHAR2   -- spec3_prompt
    , p59         OUT      VARCHAR2   -- spec4_prompt
    , p60         OUT      VARCHAR2   -- spec5_prompt
    , p61         OUT      VARCHAR2   -- spec6_prompt
    , p62         OUT      VARCHAR2   -- spec7_prompt
    , p63         OUT      VARCHAR2   -- spec8_prompt
    , p64         OUT      VARCHAR2   -- spec9_prompt
    , p65         OUT      VARCHAR2   -- spec10_prompt
    , p66         OUT      VARCHAR2   -- customstring1_prompt
    , p67         OUT      VARCHAR2   -- customstring2_prompt
    , p68         OUT      VARCHAR2   -- customstring3_prompt
    , p69         OUT      VARCHAR2   -- customstring4_prompt
    , p70         OUT      VARCHAR2   -- customstring5_prompt
    , p71         OUT      VARCHAR2   -- customstring6_prompt
    , p72         OUT      VARCHAR2   -- customstring7_prompt
    , p73         OUT      VARCHAR2   -- customstring8_prompt
    , p74         OUT      VARCHAR2   -- customstring9_prompt
    , p75         OUT      VARCHAR2   -- customstring10_prompt
                                   )
   IS
      v_disp                        BOOLEAN;
      v_prompt                      fnd_descr_flex_column_usages.end_user_column_name%TYPE;

      CURSOR csr_tab_columns
      IS
         SELECT column_name
         FROM   all_tab_columns
         WHERE  owner = 'CUST'
         AND    table_name = 'TTEC_KR_PAYRULE_MAPPING'
         -- Exclude WHO columns, Context Columns and PayRule columns from DFF setups.
         AND    column_name NOT IN
                   ( 'PAY_RULE_MAP_ID', 'PAY_RULE', 'COUNTRY'
                   , 'SPECIAL_IDENT_CATEGORY', 'CREATION_DATE', 'CREATED_BY'
                   , 'LAST_UPDATE_DATE', 'LAST_UPDATED_BY'
                   , 'LAST_UPDATE_LOGIN' );

      CURSOR csr_dff_cols(
         p_col_name   VARCHAR2 )
      IS
         SELECT   dfcu.end_user_column_name prompt
         FROM     fnd_descr_flex_column_usages dfcu
         WHERE    dfcu.descriptive_flexfield_name = 'TTEC_KR_PAYRULE_MAPPING'
         --       AND dfcu.descriptive_flex_context_code IN (p_country, 'Global Data Elements')
         AND      dfcu.application_column_name = p_col_name
         AND      dfcu.enabled_flag = 'Y'
         ORDER BY 1;
   BEGIN
      --  p_spec1_flag  := TRUE;
      FOR rec_tab_column IN csr_tab_columns
      LOOP
         v_prompt    := NULL;

         OPEN csr_dff_cols( rec_tab_column.column_name );

         FETCH csr_dff_cols
         INTO  v_prompt;

         IF rec_tab_column.column_name = 'PERSON_TYPE'
         THEN
            p2    := v_prompt;
         ELSIF rec_tab_column.column_name = 'TIME_ZONE'
         THEN
            p3    := v_prompt;
         ELSIF rec_tab_column.column_name = 'LOCATION_CODE'
         THEN
            p4    := v_prompt;
         ELSIF rec_tab_column.column_name = 'LOCATION_NAME'
         THEN
            p5    := v_prompt;
         ELSIF rec_tab_column.column_name = 'WAGE_RATE'
         THEN
            p6    := v_prompt;
         ELSIF rec_tab_column.column_name = 'WAGE_PROFILE_NAME'
         THEN
            p7    := v_prompt;
         ELSIF rec_tab_column.column_name = 'ACCRUAL_PROFILE'
         THEN
            p8    := v_prompt;
         ELSIF rec_tab_column.column_name = 'FUNC_ACCESS_PROFILE'
         THEN
            p9    := v_prompt;
         ELSIF rec_tab_column.column_name = 'DISPLAY_PROFILE'
         THEN
            p10    := v_prompt;
         ELSIF rec_tab_column.column_name = 'FTE_PERCENTAGE'
         THEN
            p11    := v_prompt;
         ELSIF rec_tab_column.column_name = 'FTE_EXPECTED_HOURS'
         THEN
            p12    := v_prompt;
         ELSIF rec_tab_column.column_name = 'FTE_HOURS'
         THEN
            p13    := v_prompt;
         ELSIF rec_tab_column.column_name = 'EXPECTED_DAILY_HOURS'
         THEN
            p14    := v_prompt;
         ELSIF rec_tab_column.column_name = 'EXPECTED_WEEKLY_HOURS'
         THEN
            p15    := v_prompt;
         ELSIF rec_tab_column.column_name = 'EXPECTED_PAY_PERIOD_HOURS'
         THEN
            p16    := v_prompt;
         ELSIF rec_tab_column.column_name = 'DEVICE_GROUP'
         THEN
            p17    := v_prompt;
         ELSIF rec_tab_column.column_name = 'LOGON_PROFILE'
         THEN
            p18    := v_prompt;
         ELSIF rec_tab_column.column_name = 'EMP_XFER_LABOR'
         THEN
            p19    := v_prompt;
         ELSIF rec_tab_column.column_name = 'EMP_PAY_CODE_DAPROFILE'
         THEN
            p20    := v_prompt;
         ELSIF rec_tab_column.column_name = 'EMP_WORK_RULE_DAPROFILE'
         THEN
            p21    := v_prompt;
         ELSIF rec_tab_column.column_name = 'TIME_ENTRY_METHOD'
         THEN
            p22    := v_prompt;
         ELSIF rec_tab_column.column_name = 'LOCATION'
         THEN
            p23    := v_prompt;
         ELSIF rec_tab_column.column_name = 'CLIENT'
         THEN
            p24    := v_prompt;
         ELSIF rec_tab_column.column_name = 'DEPARTMENT'
         THEN
            p25    := v_prompt;
         ELSIF rec_tab_column.column_name = 'PROGRAM'
         THEN
            p26    := v_prompt;
         ELSIF rec_tab_column.column_name = 'PROJECT'
         THEN
            p27    := v_prompt;
         ELSIF rec_tab_column.column_name = 'ACTIVITY'
         THEN
            p28    := v_prompt;
         ELSIF rec_tab_column.column_name = 'TEAM'
         THEN
            p29    := v_prompt;
         ELSIF rec_tab_column.column_name = 'GROUP_SCHEDULE'
         THEN
            p30    := v_prompt;
         ELSIF rec_tab_column.column_name = 'EMPLOYEE_STATUS'
         THEN
            p31    := v_prompt;
         ELSIF rec_tab_column.column_name = 'USER_STATUS'
         THEN
            p32    := v_prompt;
         ELSIF rec_tab_column.column_name = 'CITY'
         THEN
            p33    := v_prompt;
         ELSIF rec_tab_column.column_name = 'STATE_PROVINCE'
         THEN
            p34    := v_prompt;
         ELSIF rec_tab_column.column_name = 'POSTAL_CODE'
         THEN
            p35    := v_prompt;
         ELSIF rec_tab_column.column_name = 'MGRTRANSFERIN'
         THEN
            p36    := v_prompt;
         ELSIF rec_tab_column.column_name = 'MGREMP_GROUP_LLSET'
         THEN
            p37    := v_prompt;
         ELSIF rec_tab_column.column_name = 'MGRXFER_LLSET'
         THEN
            p38    := v_prompt;
         ELSIF rec_tab_column.column_name = 'MGRPAY_CODE_DAP'
         THEN
            p39    := v_prompt;
         ELSIF rec_tab_column.column_name = 'MGRWORKRULE_DAP'
         THEN
            p40    := v_prompt;
         ELSIF rec_tab_column.column_name = 'MGRREPORT_DAP'
         THEN
            p41    := v_prompt;
         ELSIF rec_tab_column.column_name = 'GENDER'
         THEN
            p42    := v_prompt;
         ELSIF rec_tab_column.column_name = 'FLSA'
         THEN
            p43    := v_prompt;
         ELSIF rec_tab_column.column_name = 'AGENCY_NAME'
         THEN
            p44    := v_prompt;
         ELSIF rec_tab_column.column_name = 'MANAGES_MULTIPLE_COUNTRIES'
         THEN
            p45    := v_prompt;
         ELSIF rec_tab_column.column_name = 'PAYROLL_NAME'
         THEN
            p46    := v_prompt;
         ELSIF rec_tab_column.column_name = 'AGENT_SUPPORTING_FLAG'
         THEN
            p47    := v_prompt;
         ELSIF rec_tab_column.column_name = 'EMPLOYEE_TYPE'
         THEN
            p48    := v_prompt;
         ELSIF rec_tab_column.column_name = 'EMPLOYEE_FLAG'
         THEN
            p49    := v_prompt;
         ELSIF rec_tab_column.column_name = 'ASSIGNMENT_CATEGORY_1'
         THEN
            p50    := v_prompt;
         ELSIF rec_tab_column.column_name = 'ASSIGNMENT_CATEGORY_2'
         THEN
            p51    := v_prompt;
         ELSIF rec_tab_column.column_name = 'WAH_FLAG'
         THEN
            p52    := v_prompt;
         ELSIF rec_tab_column.column_name = 'JOB_TITLE'
         THEN
            p53    := v_prompt;
         ELSIF rec_tab_column.column_name = 'JOB_CODE'
         THEN
            p54    := v_prompt;
         ELSIF rec_tab_column.column_name = 'SALARY_BASIS'
         THEN
            p55    := v_prompt;
         ELSIF rec_tab_column.column_name = 'SPECIAL_IDENTIFIER1'
         THEN
            p56    := v_prompt;
         ELSIF rec_tab_column.column_name = 'SPECIAL_IDENTIFIER2'
         THEN
            p57    := v_prompt;
         ELSIF rec_tab_column.column_name = 'SPECIAL_IDENTIFIER3'
         THEN
            p58    := v_prompt;
         ELSIF rec_tab_column.column_name = 'SPECIAL_IDENTIFIER4'
         THEN
            p59    := v_prompt;
         ELSIF rec_tab_column.column_name = 'SPECIAL_IDENTIFIER5'
         THEN
            p60    := v_prompt;
         ELSIF rec_tab_column.column_name = 'SPECIAL_IDENTIFIER6'
         THEN
            p61    := v_prompt;
         ELSIF rec_tab_column.column_name = 'SPECIAL_IDENTIFIER7'
         THEN
            p62    := v_prompt;
         ELSIF rec_tab_column.column_name = 'SPECIAL_IDENTIFIER8'
         THEN
            p63    := v_prompt;
         ELSIF rec_tab_column.column_name = 'SPECIAL_IDENTIFIER9'
         THEN
            p64    := v_prompt;
         ELSIF rec_tab_column.column_name = 'SPECIAL_IDENTIFIER10'
         THEN
            p65    := v_prompt;
         ELSIF rec_tab_column.column_name = 'CUSTOMSTRING1'
         THEN
            p66    := v_prompt;
         ELSIF rec_tab_column.column_name = 'CUSTOMSTRING2'
         THEN
            p67    := v_prompt;
         ELSIF rec_tab_column.column_name = 'CUSTOMSTRING3'
         THEN
            p68    := v_prompt;
         ELSIF rec_tab_column.column_name = 'CUSTOMSTRING4'
         THEN
            p69    := v_prompt;
         ELSIF rec_tab_column.column_name = 'CUSTOMSTRING5'
         THEN
            p70    := v_prompt;
         ELSIF rec_tab_column.column_name = 'CUSTOMSTRING6'
         THEN
            p71    := v_prompt;
         ELSIF rec_tab_column.column_name = 'CUSTOMSTRING7'
         THEN
            p72    := v_prompt;
         ELSIF rec_tab_column.column_name = 'CUSTOMSTRING8'
         THEN
            p73    := v_prompt;
         ELSIF rec_tab_column.column_name = 'CUSTOMSTRING9'
         THEN
            p74    := v_prompt;
         ELSIF rec_tab_column.column_name = 'CUSTOMSTRING10'
         THEN
            p75    := v_prompt;
         END IF;

         CLOSE csr_dff_cols;
      END LOOP;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
   END set_page_context;
END ttec_kr_utils_SS;
/
show errors;
/