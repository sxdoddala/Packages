create or replace PACKAGE BODY      ttec_kr_accrual_outbound_SS
AS
   /* $Header: TTEC_KR_ACCRUAL_OUTBOUND.pkb 1.0 2009/12/28 mdodge ship $ */

   /*== START ================================================================================================*\
      Author: Michelle Dodge
        Date: 12/28/2009
   Call From:
        Desc: This is the package for the Kronos Accrual Outbound procedures and functions.
              It provides the necessary Oracle data to the Kronos application for
              processing Payroll.

              This package replaces the Accrual portion of the TT_KR_OUTBOUND_INTERFACE
              package and was built referencing elements of the original package.

              This process is intended to be ran by country once per Payroll (versus nightly).

     Modification History:

    Version    Date     Author   Description (Include Ticket#)
    -------  --------  --------  ------------------------------------------------------------------------------
        1.0  12/28/09  MDodge    Kronos Transformations Project - Initial Version.
        1.1  04/05/10  MDodge    R#150907 - Added additional Arg Accruals; Removed ELSE conditions causing
                                 overwrite of special_country_occurrence1 with 0's.
        1.3  10/2/10   WManasfi  Mexico Payroll Implementation
        1.4  12/12/10  WManasfi  PHL merge Vacation and Sick into PTO
                       remove hard coded calculation date on line 548. Removed probation execulsion
        1.5 12/23/10   Wasim     Special run for 1-JAN-2011
		1.0 05/05/23   RXNETHI-ARGANO  R12.2 Upgrade Remediation
   \*== END ==================================================================================================*/
   /*
   START R12.2 Upgrade Remediation
   code commented by RXNETHI-ARGANO, 05/MAY/2023
   g_kr_emp_data                 cust.ttec_kr_emp_accruals%ROWTYPE;
   -- Error Constants
   g_label1                      cust.ttec_error_handling.label1%TYPE
                                                            := 'Err Location';
   g_label2                      cust.ttec_error_handling.label1%TYPE
                                                              := 'Emp_Number';
															  */
															  
	--code added by RXNETHI-ARGANO, 05/MAY/2023
   g_kr_emp_data                 apps.ttec_kr_emp_accruals%ROWTYPE;
   -- Error Constants
   g_label1                      apps.ttec_error_handling.label1%TYPE
                                                            := 'Err Location';
   g_label2                      apps.ttec_error_handling.label1%TYPE
                                                              := 'Emp_Number';														  
   --END R12.2 Upgrade Remediation
   g_keep_days                   NUMBER := 7;
   -- Number of days to keep error logging.
   g_keep_run_times              NUMBER := 90;
   -- Number of days to keep process run times
   g_conc_prog_name              fnd_concurrent_programs.concurrent_program_name%TYPE
                                                     := 'TTEC_KR_ACCRUAL_OUT';
   -- Process FAILURE variables
   g_fail_flag                   BOOLEAN := FALSE;
   g_fail_msg                    VARCHAR2( 240 );
   -- declare who columns
   g_request_id                  NUMBER := fnd_global.conc_request_id;
   g_created_by                  NUMBER := fnd_global.user_id;
   -- Global Count Variables for logging information
   g_records_read                NUMBER := 0;
   g_records_processed           NUMBER := 0;
   g_records_skipped             NUMBER := 0;
   -- Emps with No Accruals
   g_records_errored             NUMBER := 0;
   g_commit_count                NUMBER := 0;
   -- declare commit counter
   g_commit_point                NUMBER := 100;
   -- declare exceptions
   error_record                  EXCEPTION;
   term_record                   EXCEPTION;
  -- g_run_date                    DATE := TRUNC( SYSDATE );   -- variable for phl ptO only set to TRUNC(SYSDATE) for PROD
  g_run_date                    DATE := '01-JAN-2011';   -- variable for phl ptO only set to TRUNC(SYSDATE) for PROD
   --g_calc_date                   DATE := TRUNC( SYSDATE );   -- '15-JAN-2011';   -- take out this is date for PHL PTO test hard wired SET TO TRUNC(SYSDATE) for PROD

 g_calc_date                   DATE := '01-JAN-2011';   -- take out this is date for PHL PTO test hard wired SET TO TRUNC(SYSDATE) for PROD

   /*********************************************************
   **  Private Procedures and Functions
   *********************************************************/

   /************************************************************************************/
/*                                  GET_COUNTRY                                     */
/************************************************************************************/
   PROCEDURE get_country
   IS
      --v_module                      cust.ttec_error_handling.module_name%TYPE   --code commented by RXNETHI-ARGANO,05/05/23
      v_module                      apps.ttec_error_handling.module_name%TYPE     --code added by RXNETHI-ARGANO,05/05/23
                                                             := 'get_country';
      v_loc                         NUMBER;
   BEGIN
      v_loc    := 10;

      IF NVL( g_kr_emp_data.wah_flag, 'N' ) = 'Y'
      THEN
         -- Get Country from Employee Primary Address
         SELECT country
         INTO   g_kr_emp_data.country
         FROM   per_addresses
         WHERE  person_id = g_kr_emp_data.person_id
         AND    primary_flag = 'Y'
         AND    TRUNC( SYSDATE ) BETWEEN date_from AND NVL( date_to, SYSDATE );
      ELSE
         -- Get Country from Employee Location
         SELECT country
         INTO   g_kr_emp_data.country
         FROM   hr_locations_all
         WHERE  location_id = g_kr_emp_data.location_id;
      END IF;
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
                                     , 'Unable to get Employee Payroll Info'
                                     , g_label1
                                     , v_loc
                                     , g_label2
                                     , g_kr_emp_data.employee_number
                                     , 'Work At Home'
                                     , g_kr_emp_data.wah_flag
                                     , 'Person ID'
                                     , g_kr_emp_data.person_id
                                     , 'Location ID'
                                     , g_kr_emp_data.location_id );
   END get_country;

/************************************************************************************/
/*                                  GET_PAYROLL_DTL                                 */
/************************************************************************************/
   PROCEDURE get_payroll_dtl
   IS
      --v_module                      cust.ttec_error_handling.module_name%TYPE     --code commented by RXNETHI-ARGANO,05/05/23
      v_module                      apps.ttec_error_handling.module_name%TYPE       --code added by RXNETHI-ARGANO,05/05/23
                                                         := 'get_payroll_dtl';
      v_loc                         NUMBER;
   BEGIN
      v_loc    := 10;

      SELECT ptp.start_date
      INTO   g_kr_emp_data.accrual_effective_date
      --FROM   hr.per_time_periods ptp --code commented by RXNETHI-ARGANO, 05/MAY/2023
	  FROM   apps.per_time_periods ptp --code added by RXNETHI-ARGANO, 05/MAY/2023
      WHERE  ptp.payroll_id = g_kr_emp_data.payroll_id
      AND    TRUNC( g_run_date ) BETWEEN ptp.start_date AND ptp.end_date;
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
                                     , 'Unable to get Employee Payroll Info'
                                     , g_label1
                                     , v_loc
                                     , g_label2
                                     , g_kr_emp_data.employee_number
                                     , 'Payroll ID'
                                     , g_kr_emp_data.payroll_id );
   END get_payroll_dtl;

/************************************************************************************/
/*                                  GET_LOCATION_DTL                                */
/************************************************************************************/
   PROCEDURE get_location_dtl
   IS
      --v_module                      cust.ttec_error_handling.module_name%TYPE    --code commented by RXNETHI-ARGANO,05/05/23
      v_module                      apps.ttec_error_handling.module_name%TYPE      --code added by RXNETHI-ARGANO,05/05/23
                                                        := 'get_location_dtl';
      v_loc                         NUMBER;
   BEGIN
      v_loc    := 10;

      SELECT hla.attribute2
           , hla.location_code
      INTO   g_kr_emp_data.location_code
           , g_kr_emp_data.location_name
      --FROM   hr.hr_locations_all hla --code commented by RXNETHI-ARGANO, 05/MAY/2023
	  FROM   apps.hr_locations_all hla --code added by RXNETHI-ARGANO, 05/MAY/2023
      WHERE  hla.location_id = g_kr_emp_data.location_id;
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
                                    , 'Unable to get Employee Location Info'
                                    , g_label1
                                    , v_loc
                                    , g_label2
                                    , g_kr_emp_data.employee_number
                                    , 'Location ID'
                                    , g_kr_emp_data.location_id );
   END get_location_dtl;

/************************************************************************************/
/*                              INSERT_KR_EMP_ACCRUALS                              */
/************************************************************************************/
   PROCEDURE insert_kr_emp_accruals
   IS
      --v_module                      cust.ttec_error_handling.module_name%TYPE    --code commented by RXNETHI-ARGANO,05/05/23
      v_module                      apps.ttec_error_handling.module_name%TYPE      --code added by RXNETHI-ARGANO,05/05/23
                                                  := 'insert_kr_emp_accruals';
      v_loc                         NUMBER;
   BEGIN
      v_loc                              := 10;
      -- Add Who columns to record
      g_kr_emp_data.create_request_id    := g_request_id;
      g_kr_emp_data.created_by           := g_created_by;
      g_kr_emp_data.last_updated_by      := g_created_by;
      g_kr_emp_data.creation_date        := SYSDATE;
      g_kr_emp_data.last_update_date     := SYSDATE;
      v_loc                              := 20;

      --INSERT INTO cust.ttec_kr_emp_accruals --code commented by RXNETHI-ARGANO, 05/MAY/2023
	  INSERT INTO apps.ttec_kr_emp_accruals --code added by RXNETHI-ARGANO, 05/MAY/2023
           VALUES g_kr_emp_data;
   EXCEPTION
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
                                         , g_label2
                                         , g_kr_emp_data.employee_number );
         RAISE error_record;
   END insert_kr_emp_accruals;

/************************************************************************************/
/*                               TRUNCATE_KR_EMP_ACCRUALS                           */
/************************************************************************************/
   PROCEDURE truncate_kr_emp_accruals(
      p_business_group_id   IN   VARCHAR2
    , p_bucket_number       IN   NUMBER
    , p_buckets             IN   NUMBER )
   IS
      --v_module                      cust.ttec_error_handling.module_name%TYPE
      --                                          := 'truncate_kr_emp_accruals'; -- code commented by RXNETHI-ARGANO,05/05/23
      v_module                      apps.ttec_error_handling.module_name%TYPE
                                                := 'truncate_kr_emp_accruals'; --code added by RXNETHI-ARGANO,05/05/23
	  v_loc                         NUMBER;
   BEGIN
      v_loc    := 10;

      -- Remove records from the backup table that you are about to process.
      --DELETE      cust.ttec_kr_emp_accruals_bk --code commented by RXNETHI-ARGANO, 05/MAY/2023
	  DELETE      apps.ttec_kr_emp_accruals_bk --code added by RXNETHI-ARGANO, 05/MAY/2023
            WHERE business_group_id =
                                NVL( p_business_group_id, business_group_id )
      AND         MOD( employee_number, NVL( p_buckets, 1 )) =
                                                     NVL( p_bucket_number, 0 );

      v_loc    := 20;

      --Move records from the master to backup table that you are about to process.
      --INSERT INTO cust.ttec_kr_emp_accruals_bk --code commented by RXNETHI-ARGANO, 05/MAY/2023
	  INSERT INTO apps.ttec_kr_emp_accruals_bk --code added by RXNETHI-ARGANO, 05/MAY/2023
         ( SELECT *
          --FROM   cust.ttec_kr_emp_accruals --code commented by RXNETHI-ARGANO, 05/MAY/2023
		  FROM   apps.ttec_kr_emp_accruals --code added by RXNETHI-ARGANO, 05/MAY/2023
          WHERE  business_group_id =
                                 NVL( p_business_group_id, business_group_id )
          AND    MOD( employee_number, NVL( p_buckets, 1 )) =
                                                     NVL( p_bucket_number, 0 ));

      v_loc    := 30;

      --Delete the master records for the bucket being processed.
      --DELETE      cust.ttec_kr_emp_accruals --code commented by RXNETHI-ARGANO, 05/MAY/2023
	  DELETE      apps.ttec_kr_emp_accruals --code added by RXNETHI-ARGANO, 05/MAY/2023
            WHERE business_group_id =
                                 NVL( p_business_group_id, business_group_id )
      AND         MOD( employee_number, NVL( p_buckets, 1 )) =
                                                     NVL( p_bucket_number, 0 );

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error( g_application_code
                                         , g_interface
                                         , g_package
                                         , v_module
                                         , g_failure_status
                                         , SQLCODE
                                         , SQLERRM
                                         , g_label1
                                         , v_loc );
         RAISE;
   END truncate_kr_emp_accruals;

   /*********************************************************
   **  Public Functions and Procedures
   *********************************************************/

   /************************************************************************************/
/*                              GET_NET_ACCRUAL                                     */
/************************************************************************************/
   PROCEDURE get_net_accrual(
      p_assignment_id           IN       NUMBER
    , p_business_group_id       IN       NUMBER
    , p_payroll_id              IN       NUMBER
    , p_calculation_date        IN       DATE
    , p_accrual_plan_category   IN       VARCHAR2
    , p_accrual_plan_balance    OUT      NUMBER )
   IS
      --v_module                      cust.ttec_error_handling.module_name%TYPE
      --                                                 := 'get_net_accrual';  -- code commented by RXNETHI-ARGANO,05/05/2023
      v_module                      apps.ttec_error_handling.module_name%TYPE
                                                       := 'get_net_accrual';  -- code added by RXNETHI-ARGANO,05/05/2023
	  v_loc                         NUMBER;
      v_accrual_plan_id             NUMBER;
      --declare place holders
      d1                            DATE;
      d2                            DATE;
      d3                            DATE;
      n1                            NUMBER;
   BEGIN
      v_loc    := 10;
      ttec_kr_utils_ss.get_accrual_plan( p_accrual_plan_category
                                    , p_assignment_id
                                    , v_accrual_plan_id );

      IF v_accrual_plan_id IS NOT NULL
      THEN
         IF p_business_group_id = 1839
         THEN   -- Australia
            v_loc                     := 20;
            p_accrual_plan_balance    :=
               apps.hr_au_holidays.get_net_accrual( p_assignment_id
                                                  , p_payroll_id
                                                  , p_business_group_id
                                                  , v_accrual_plan_id
                                                  , p_calculation_date );
         ELSE
            v_loc    := 30;

--            fnd_file.put_line( fnd_file.LOG, 'in if statement PHL accural plan payroll id'  || to_char(p_payroll_id) );
--            fnd_file.put_line( fnd_file.LOG, 'in if statement PHL accural plan asg id'  || to_char(p_assignment_id) );
--            fnd_file.put_line( fnd_file.LOG, 'in if statement PHL accural plan accrual  id'  || to_char(v_accrual_plan_id) );
--            fnd_file.put_line( fnd_file.LOG, 'in if statement PHL accural plan cacl'  || to_char(p_calculation_date) );
--            fnd_file.put_line( fnd_file.LOG, 'in if statement PHL accural plan biz id'  || to_char(p_business_group_id));
            apps.per_accrual_calc_functions.get_net_accrual
                                ( p_assignment_id          => p_assignment_id
                                , p_plan_id                => v_accrual_plan_id
                                , p_payroll_id             => p_payroll_id
                                , p_business_group_id      => p_business_group_id
                                , p_calculation_date       => p_calculation_date
                                , p_calling_point          => 'BP'
                                , p_start_date             => d1
                                , p_end_date               => d2
                                , p_accrual_end_date       => d3
                                , p_accrual                => n1
                                , p_net_entitlement        => p_accrual_plan_balance );

     --  fnd_file.put_line( fnd_file.LOG, 'in if statement PHL accural plan balance'  || to_char(p_accrual_plan_balance));
         END IF;
      ELSE
         p_accrual_plan_balance    := 0;
      END IF;
   EXCEPTION
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
                                         , g_label2
                                         , g_kr_emp_data.employee_number
                                         , 'Assignment ID'
                                         , p_assignment_id
                                         , 'Business Group ID'
                                         , p_business_group_id
                                         , 'Payroll ID'
                                         , p_payroll_id
                                         , 'Accrual Plan'
                                         , p_accrual_plan_category );
   END get_net_accrual;

/************************************************************************************/
/*                               MAIN PROGRAM PROCEDURE                             */
/************************************************************************************/
   PROCEDURE main(
      p_business_group_id   IN   VARCHAR2
    , p_bucket_number       IN   NUMBER
    , p_buckets             IN   NUMBER )
   IS
      --v_module                      cust.ttec_error_handling.module_name%TYPE
      --                                                            := 'main';  --code commented by RXNETHI-ARGANO,05/05/23
	  v_module                      apps.ttec_error_handling.module_name%TYPE
                                                                  := 'main';  --code added by RXNETHI-ARGANO,05/05/23
      v_loc                         NUMBER;
      -- declare local variables
      v_last_run_date               DATE;
      v_probation_date              DATE;
      v_pass_to_kronos              VARCHAR2( 30 );
      v_control_id                  NUMBER;
      --v_process_status              cust.ttec_kr_accrual_control.process_status%TYPE;
      --v_process_country             cust.ttec_kr_accrual_control.country%TYPE; --code commented by RXNETHI-ARGANO,05/05/23
      v_process_status              apps.ttec_kr_accrual_control.process_status%TYPE;
      v_process_country             apps.ttec_kr_accrual_control.country%TYPE;  --code added by RXNETHI-ARGANO, 05/05/23
	  -- Accrual Variables
      v_accrual_flag                BOOLEAN;
      v_calculation_date            DATE;
      v_vacation_balance            NUMBER;
      v_vacation_plan_category      VARCHAR2( 30 );
      v_phl_pto_plan_category       VARCHAR2( 30 );   -- v1.4 phl pto
      v_phl_pto_balance             NUMBER;   -- v1.4 phl pto
      v_sick_balance                NUMBER;
      v_sick_plan_category          VARCHAR2( 30 );
      v_holiday_balance             NUMBER;
      v_holiday_plan_category       VARCHAR2( 30 );
      v_us_pluto_balance            NUMBER;
      v_us_pluto_plan_category      VARCHAR2( 30 );
      v_can_emer_balance            NUMBER;
      v_can_emer_plan_category      VARCHAR2( 30 );
      v_arg_fam_med_lv_balance      NUMBER;
      v_arg_fam_med_lv_category     VARCHAR2( 30 );
      v_arg_univ_lv_balance         NUMBER;
      v_arg_univ_lv_category        VARCHAR2( 30 );
      v_empl_elig                   NUMBER := 0;
      v_date_01_jan_2011            DATE := '01-JAN-2011';
      v_mex_calculation_date        DATE;
      v_mex_hire_date               DATE;
   BEGIN
      v_loc                               := 10;
      -- Set Globals of Shared Package for Error Logging
      ttec_kr_utils_ss.g_application_code    := 'HR';
      ttec_kr_utils_ss.g_interface           := 'Kronos Accruals';
      v_loc                               := 14;
      v_process_status                    := 'IN PROCESS';

      --SELECT cust.ttec_kr_accrual_control_s.NEXTVAL --code commented by RXNETHI-ARGANO, 05/05/23
	  SELECT apps.ttec_kr_accrual_control_s.NEXTVAL --code added by RXNETHI-ARGANO, 05/05/23
      INTO   v_control_id
      FROM   DUAL;

      IF p_business_group_id IS NULL
      THEN
         v_process_country    := 'ALL';
      ELSE
         SELECT hl.country
         INTO   v_process_country
         --FROM   hr.hr_all_organization_units hou, hr.hr_locations_all hl --code commented by RXNETHI-ARGANO,05/05/23
		 FROM   apps.hr_all_organization_units hou, apps.hr_locations_all hl --code added by RXNETHI-ARGANO,05/05/23
         WHERE  hou.organization_id = p_business_group_id
         AND    hl.location_id = hou.location_id;
      END IF;

      v_loc                               := 16;

      -- Insert process control record for Kronos
      --INSERT INTO cust.ttec_kr_accrual_control --code commented by RXNETHI-ARGANO, 05/05/23
	  INSERT INTO apps.ttec_kr_accrual_control --code added by RXNETHI-ARGANO, 05/05/23
                  ( accrual_control_id
                  , request_id
                  , actual_start_date
                  , actual_completion_date
                  , process_status
                  , country
                  , creation_date
                  , created_by
                  , last_update_date
                  , last_updated_by
                  , last_update_login )
           VALUES ( v_control_id
                  , g_request_id
                  , SYSDATE
                  , NULL
                  , v_process_status
                  , v_process_country
                  , SYSDATE
                  , g_created_by
                  , SYSDATE
                  , g_created_by
                  , NULL );

      COMMIT;
      v_loc                               := 20;
      -- Backup and truncate employee staging table
      truncate_kr_emp_accruals( p_business_group_id
                              , p_bucket_number
                              , p_buckets );
      -- initialize counters
      g_records_read                      := 0;
      g_records_processed                 := 0;
      g_records_errored                   := 0;
      g_commit_count                      := 0;
      v_loc                               := 30;
      -- Get Last Run Date
      ttec_kr_utils_ss.get_last_run_date( p_program_name       => g_conc_prog_name
                                     , p_arg1               => p_business_group_id
                                     , p_arg2               => p_bucket_number
                                     , p_arg3               => p_buckets
                                     , p_last_run_date      => v_last_run_date );
      fnd_file.put_line( fnd_file.LOG, 'BG ID: '
                          || p_business_group_id );
      fnd_file.put_line( fnd_file.LOG
                       , 'Last Run Date :'
                         || TO_CHAR( v_last_run_date
                                   , 'DD-MON-YYYY HH24:MI:SS' ));
      fnd_file.put_line( fnd_file.LOG, 'Bucket Number :'
                          || p_bucket_number );
      fnd_file.put_line( fnd_file.LOG, 'Number of Buckets :'
                          || p_buckets );
      fnd_file.new_line( fnd_file.LOG );
      v_loc                               := 40;

      -- check to see if cursor is open
      IF csr_emp_data%ISOPEN
      THEN
         CLOSE csr_emp_data;
      END IF;

      fnd_file.put_line( fnd_file.LOG
                       , TO_CHAR( SYSDATE, 'DD-MON-YYYY HH24:MI:SS' )
                         || ' -> Entering Main Loop' );

      -- retrieve data from cursor of active employees and term emps within final process date
      FOR sel IN csr_emp_data( p_business_group_id
                             , v_last_run_date
                             , p_bucket_number
                             , p_buckets )
      LOOP
         BEGIN
            v_loc                                := 50;
            -- update records read counter
            g_records_read                       := g_records_read
                                                    + 1;
            -- initialize variables
            g_kr_emp_data                        := NULL;
            -- Initial Accrual Variables
            v_accrual_flag                       := FALSE;
            -- Set to TRUE when an active Accrual is identified
            v_vacation_balance                   := NULL;
            v_sick_balance                       := NULL;
            v_holiday_balance                    := NULL;
            v_can_emer_balance                   := NULL;
            v_us_pluto_balance                   := NULL;
            v_arg_fam_med_lv_balance             := NULL;
            v_arg_univ_lv_balance                := NULL;
            v_phl_pto_balance                    := NULL;   -- v1.4 phl pto
            v_phl_pto_plan_category              := NULL;   -- v1.4 phl pto
            -- set all record data with all employee data
            g_kr_emp_data.person_id              := sel.person_id;
            g_kr_emp_data.assignment_id          := sel.assignment_id;
            g_kr_emp_data.parent_bus_group_id    := sel.parent_bus_group_id;
            g_kr_emp_data.business_group_id      := sel.business_group_id;
            g_kr_emp_data.organization_id        := sel.organization_id;
            g_kr_emp_data.payroll_id             := sel.payroll_id;
            g_kr_emp_data.location_id            := sel.location_id;
            g_kr_emp_data.employee_number        := sel.employee_number;
            g_kr_emp_data.hire_date              := sel.rehire_date;
            g_kr_emp_data.wah_flag               := sel.work_at_home;
            v_loc                                := 70;
            get_location_dtl;
            get_payroll_dtl;

            IF g_kr_emp_data.business_group_id = 1632
            THEN
               -- Argentina calculates accruals to the end of the current year
               v_calculation_date    :=
                            TO_DATE( '31-DEC-'
                                     || TO_CHAR( SYSDATE, 'YYYY' ));
            ELSE
               -- Accrual Calculation Date should be last day of prior pay period
               -- which is one day before the Accrual_effective_date set in the emp record
               v_calculation_date    :=
                                     g_kr_emp_data.accrual_effective_date
                                     - 1;
            END IF;

            -- get employee country
            get_country;
            v_loc                                := 80;

            -- Set Accrual Categories based on BG_ID
            IF sel.business_group_id = 1839
            THEN
               v_vacation_plan_category    := 'AUAL';
               v_sick_plan_category        := 'AUSL';
               v_holiday_plan_category     := 'TTA_OTHER_LEAVE';
            ELSIF     sel.business_group_id = 1517   --v1.4 phl pto
                  AND g_run_date >= v_date_01_jan_2011   --v1.4 phl pto
            THEN   --v1.4 phl pto
               v_phl_pto_plan_category    := 'P';   --v1.4 phl pto
               v_calculation_date := TO_DATE('01-JAN-2011');              -- v1.5

            ELSE
               v_vacation_plan_category     := 'V';
               v_sick_plan_category         := 'S';
               v_holiday_plan_category      := 'HML';
               v_can_emer_plan_category     := 'EMER';
               v_us_pluto_plan_category     := 'PLUTO';
               v_arg_fam_med_lv_category    := 'FML';
               v_arg_univ_lv_category       := 'UNIV_LV';
            END IF;

            v_loc                                := 90;

                        -- Calculate Probation Date for PHL employees only  removed
            --            IF sel.business_group_id = 1517
            --            THEN
            --               v_probation_date    :=
            --                   ttec_pto_util.ttec_probation_end_date( sel.assignment_id );
            --            END IF;
            IF sel.payroll_id IS NOT NULL
            THEN
------------------------------------------------
-- Vacation Bank                            ----
------------------------------------------------
               v_loc                                 := 100;

               -- PHL probation conditions removed per request from jessica and bob
               IF sel.business_group_id = 1517
               THEN
                  --                  IF v_probation_date > TRUNC( SYSDATE )
                  --                  THEN   -- PHL
                  --                     -- If employee on probation do not carry balance
                  --                     v_vacation_balance    := NULL;
                  IF g_run_date >= v_date_01_jan_2011
                  THEN   -- v1.4
                     v_vacation_balance    := NULL;   -- v1.4
                  --                  ELSIF( g_run_date BETWEEN TO_DATE( '25-DEC-2010' )
                  --                                        AND TO_DATE( '31-DEC-2010' ))
                  --                  THEN   -- v1.4
                  --                     get_net_accrual
                  --                        ( sel.assignment_id   -- v1.4
                  --                        , sel.business_group_id   -- v1.4
                  --                        , sel.payroll_id   -- v1.4
                  --                        , TO_DATE
                  --                             ( '16-DEC-2010' )   -- v_calculation_date  use 16 as it is effective first day of next perios-- v1.4
                  --                        , v_vacation_plan_category   -- v1.4
                  --                        , v_vacation_balance );   -- v1.4
                  ELSE
                     get_net_accrual( sel.assignment_id
                                    , sel.business_group_id   -- v1.4
                                    , sel.payroll_id   -- v1.4
                                    , v_calculation_date   -- v1.4
                                    , v_vacation_plan_category   -- v1.4
                                    , v_vacation_balance );   -- v1.4                                                                                                                              -- v1.4
                  END IF;
               ELSIF sel.business_group_id = 2311
               THEN   -- NZ
                  v_vacation_balance    := sel.nz_al_balance;
               ELSIF g_kr_emp_data.country = 'ZA'
               THEN
                  v_vacation_balance    := sel.za_vacation_balance;
               ELSIF sel.business_group_id = 1633
               THEN   /* v1.3 Mexico Payroll */
                  ttec_kr_utils_ss.get_mex_vac_eligible
                                                   ( v_calculation_date
                                                   , g_kr_emp_data.person_id
                                                   , v_mex_hire_date
                                                   , v_empl_elig );

                  -- get if eligible   v1.3
                  IF v_empl_elig > 0
                  THEN
                     -- v1.3   for Mexico any one past one year, is  Eligible for accruals.
                     -- compute the accrual as of the anniversary date of the current year
                     -- TO_DATE( TO_CHAR( v_mex_hire_date, 'DD-MON-' )
                     --   || TO_CHAR( SYSDATE, 'YYYY' ));
                     v_mex_calculation_date    :=
                        TO_DATE( TO_CHAR( v_mex_hire_date, 'DD-MON-' )
                                 || TO_CHAR( SYSDATE, 'YYYY' ))                        - 1;
                --     fnd_file.put_line( fnd_file.LOG
                --                      , 'calc date : '
                --                        || TO_CHAR( v_mex_calculation_date )
                --                        || 'emp '
                --                        || TO_CHAR( sel.assignment_id ));
                     -- v1.3  for Mexico each employee has calculation date that is specific based on above
                     get_net_accrual
                        ( sel.assignment_id
                        , sel.business_group_id
                        , sel.payroll_id
                        , v_mex_calculation_date   -- v1.3 replaced it with the requirement  above  v_calculation_date
                        , v_vacation_plan_category
                        , v_vacation_balance );
                  END IF;   /* v1.3 Mexico Payroll end */
               ELSE
                  get_net_accrual( sel.assignment_id
                                 , sel.business_group_id
                                 , sel.payroll_id
                                 , v_calculation_date
                                 , v_vacation_plan_category
                                 , v_vacation_balance );
               END IF;

               IF NVL( v_vacation_balance, 0 ) != 0
               THEN
                  v_accrual_flag    := TRUE;
               END IF;

               g_kr_emp_data.vacation_balance        :=
                                      ROUND( NVL( v_vacation_balance, 0 ), 3 );
------------------------------------------------
-- Sick Bank                                ----
------------------------------------------------
               v_loc                                 := 110;

               --              remove probation date special treatment
               IF sel.business_group_id = 1517
               THEN
                  --                  IF v_probation_date > TRUNC( SYSDATE )
                  --                  THEN   -- PHL
                  --                     -- If employee on probation do not carry balance
                  --                     v_sick_balance    := NULL;
                  IF g_run_date >= v_date_01_jan_2011
                  THEN   -- v1.4
                     v_sick_balance    := NULL;   -- v1.4
                  --                  ELSIF( g_run_date BETWEEN TO_DATE( '25-DEC-2010' )
                  --                                        AND TO_DATE( '31-DEC-2010' ))
                  --                  THEN   -- v1.4
                  --                     get_net_accrual
                  --                        ( sel.assignment_id   -- v1.4
                  --                        , sel.business_group_id   -- v1.4
                  --                        , sel.payroll_id   -- v1.4
                  --                        , TO_DATE
                  --                             ( '16-DEC-2010' )   -- v_calculation_date                  -- v1.4
                  --                        , v_sick_plan_category   -- v1.4
                  --                        , v_sick_balance );   -- v1.4
                  ELSE
                     get_net_accrual( sel.assignment_id   -- v1.4
                                    , sel.business_group_id   -- v1.4
                                    , sel.payroll_id   -- v1.4
                                    , v_calculation_date   -- v1.4
                                    , v_sick_plan_category   -- v1.4
                                    , v_sick_balance );   -- v1.4                                                                                                              -- v1.4
                  END IF;
               --               ELS
               ELSIF sel.business_group_id = 2311
               THEN   -- NZ
                  v_sick_balance    := sel.nz_sick_balance;
               ELSIF g_kr_emp_data.country = 'ZA'
               THEN
                  v_sick_balance    := sel.za_sick_balance;
               -- v1.4 following if statement is to be taken out after Jan 5th
               ELSE
                  get_net_accrual( sel.assignment_id
                                 , sel.business_group_id
                                 , sel.payroll_id
                                 , v_calculation_date
                                 , v_sick_plan_category
                                 , v_sick_balance );
               END IF;

               IF NVL( v_sick_balance, 0 ) != 0
               THEN
                  v_accrual_flag    := TRUE;
               END IF;

               g_kr_emp_data.sick_balance            :=
                                          ROUND( NVL( v_sick_balance, 0 ), 3 );
------------------------------------------------
-- Personal Holiday Bank                    ----
------------------------------------------------
               v_loc                                 := 120;

               IF sel.business_group_id = 2311
               THEN   -- NZ
                  v_holiday_balance    := sel.nz_lieu_balance;
               ELSIF g_kr_emp_data.country = 'ZA'
               THEN
                  v_holiday_balance    := sel.za_family_balance;
               -- put PHL PTO here
               ELSIF sel.business_group_id = 1517
               THEN   -- PHL    -- v1.4
                  -- remove 12/28    IF v_probation_date > TRUNC( SYSDATE )
                  --                  THEN   -- PHL
                  --                     -- If employee on probation do not carry balance
                  --                     v_holiday_balance    := NULL;   -- phl pto is not passed if not passed probation date
                  IF ( g_run_date >= v_date_01_jan_2011 )
                  THEN   -- PHL    -- v1.4
                         get_net_accrual( sel.assignment_id   -- v1.4
                                    , sel.business_group_id   -- v1.4
                                    , sel.payroll_id   -- v1.4
                                    , v_calculation_date   -- v1.4
                                    , v_phl_pto_plan_category   -- v1.4
                                    , v_phl_pto_balance );   -- v1.4
                     -- Putting the PHL PTO in the personal holiday bucket
                     v_holiday_balance    := NVL( v_phl_pto_balance, 0 );   -- v1.4

                  ELSE   -- v 1.4
                     v_holiday_balance    := NULL;   -- v1.4
                  END IF;
               ELSE
                  get_net_accrual( sel.assignment_id
                                 , sel.business_group_id
                                 , sel.payroll_id
                                 , v_calculation_date
                                 , v_holiday_plan_category
                                 , v_holiday_balance );
               END IF;

               IF NVL( v_holiday_balance, 0 ) != 0
               THEN
                  v_accrual_flag    := TRUE;
               END IF;

               g_kr_emp_data.personal_hol_balance    :=
                                       ROUND( NVL( v_holiday_balance, 0 ), 3 );
-----------------------------------------------------------------------------
-- Emer Accrual (Canada Only)                                            ----
-----------------------------------------------------------------------------
               v_loc                                 := 130;

               IF     sel.business_group_id = 326
                  AND g_kr_emp_data.location_code IN( '05255' )
               THEN
                  get_net_accrual( sel.assignment_id
                                 , sel.business_group_id
                                 , sel.payroll_id
                                 , v_calculation_date
                                 , v_can_emer_plan_category
                                 , v_can_emer_balance );

                  IF NVL( v_can_emer_balance, 0 ) != 0
                  THEN
                     v_accrual_flag    := TRUE;
                  END IF;

                  g_kr_emp_data.special_country_occurrence1    :=
                                                  NVL( v_can_emer_balance, 0 );
               END IF;   -- 1.1 Removed ELSE condition

------------------------------------------------------------------------------
-- Pluto Accrual (US Only)                                                ----
------------------------------------------------------------------------------
               v_loc                                 := 140;

               IF sel.business_group_id = 325
               THEN
                  get_net_accrual( sel.assignment_id
                                 , sel.business_group_id
                                 , sel.payroll_id
                                 , v_calculation_date
                                 , v_us_pluto_plan_category
                                 , v_us_pluto_balance );

                  IF NVL( v_us_pluto_balance, 0 ) != 0
                  THEN
                     v_accrual_flag    := TRUE;
                  END IF;

                  g_kr_emp_data.special_country_occurrence1    :=
                                                  NVL( v_us_pluto_balance, 0 );
               END IF;   -- 1.1 Removed ELSE condition

------------------------------------------------------------------------------
-- Family Medical Leave (ARG Only)    -- 1.1                              ----
------------------------------------------------------------------------------
               v_loc                                 := 142;

               IF sel.business_group_id = 1632
               THEN
                  get_net_accrual( sel.assignment_id
                                 , sel.business_group_id
                                 , sel.payroll_id
                                 , v_calculation_date
                                 , v_arg_fam_med_lv_category
                                 , v_arg_fam_med_lv_balance );

                  IF NVL( v_arg_fam_med_lv_balance, 0 ) != 0
                  THEN
                     v_accrual_flag    := TRUE;
                  END IF;

                  g_kr_emp_data.special_country_occurrence1    :=
                                            NVL( v_arg_fam_med_lv_balance, 0 );
               END IF;

------------------------------------------------------------------------------
-- University Leave (ARG Only)       -- 1.1                               ----
------------------------------------------------------------------------------
               v_loc                                 := 144;

               IF sel.business_group_id = 1632
               THEN
                  get_net_accrual( sel.assignment_id
                                 , sel.business_group_id
                                 , sel.payroll_id
                                 , v_calculation_date
                                 , v_arg_univ_lv_category
                                 , v_arg_univ_lv_balance );

                  IF NVL( v_arg_univ_lv_balance, 0 ) != 0
                  THEN
                     v_accrual_flag    := TRUE;
                  END IF;

                  g_kr_emp_data.special_country_occurrence2    :=
                                               NVL( v_arg_univ_lv_balance, 0 );
               END IF;
------------------------------------------------------------------------------
-- No Payroll ID on assignment                                            ----
------------------------------------------------------------------------------
            ELSE   -- Payroll is NULL
               ttec_error_logging.process_error
                                    ( g_application_code
                                    , g_interface
                                    , g_package
                                    , v_module
                                    , g_error_status
                                    , SQLCODE
                                    , 'No Payroll ID on Employee Assignment'
                                    , g_label1
                                    , v_loc
                                    , g_label2
                                    , g_kr_emp_data.employee_number );
               RAISE error_record;
            END IF;

--------------------------------------------------------------------
--------------------------------------------------------------------
            v_loc                                := 150;

            -- insert record data into employee master table
            IF v_accrual_flag
            THEN
               g_records_processed    := g_records_processed
                                         + 1;
               insert_kr_emp_accruals;
            ELSE
               g_records_skipped    := g_records_skipped
                                       + 1;
            END IF;

            -- Check commit loop
            g_commit_count                       := g_commit_count
                                                    + 1;

            IF g_commit_count = g_commit_point
            THEN
               COMMIT;
               g_commit_count    := 0;
               fnd_file.put_line( fnd_file.LOG
                                , TO_CHAR( SYSDATE, 'DD-MON-YYYY HH24:MI:SS' )
                                  || ' -> '
                                  || g_records_processed
                                  || ' Records Processed' );
            END IF;
         EXCEPTION
            WHEN error_record
            THEN
               g_records_errored    := g_records_errored
                                       + 1;
            WHEN term_record
            THEN
               -- Subtract one as this record is NOT to be processed
               g_records_read    := g_records_read
                                    - 1;
            WHEN OTHERS
            THEN
               ttec_error_logging.process_error
                                              ( g_application_code
                                              , g_interface
                                              , g_package
                                              , v_module
                                              , g_error_status
                                              , SQLCODE
                                              , SQLERRM
                                              , g_label1
                                              , v_loc
                                              , g_label2
                                              , g_kr_emp_data.employee_number );
               g_records_errored    := g_records_errored
                                       + 1;
         END;
      END LOOP;

      fnd_file.put_line( fnd_file.LOG
                       , TO_CHAR( SYSDATE, 'DD-MON-YYYY HH24:MI:SS' )
                         || ' -> Exiting Main Loop' );
      v_loc                               := 160;
      -- final commit
      COMMIT;
      -- Save process info to temp table
      ttec_kr_utils_ss.save_process_run_time( g_request_id );
      v_loc                               := 170;

      -- Purge Process Run Times table of old data
      --DELETE      cust.ttec_kr_process_times --code commented by RXNETHI-ARGANO, 05/05/23
	  DELETE      apps.ttec_kr_process_times --code added by RXNETHI-ARGANO, 05/05/23
            WHERE creation_date < SYSDATE
                                  - g_keep_run_times;

      -- Update process control record for Kronos
      IF g_fail_flag
      THEN
         v_process_status    := 'ERROR';
      ELSE
         v_process_status    := 'SUCCESS';
      END IF;

      v_loc                               := 180;

      --UPDATE cust.ttec_kr_accrual_control --code commented by RXNETHI-ARGANO, 05/MAY/2023
	  UPDATE apps.ttec_kr_accrual_control --code added by RXNETHI-ARGANO, 05/MAY/2023
         SET actual_completion_date = SYSDATE
           , process_status = v_process_status
       WHERE accrual_control_id = v_control_id;

      COMMIT;
   EXCEPTION
      WHEN INVALID_CURSOR
      THEN
         ttec_error_logging.process_error( g_application_code
                                         , g_interface
                                         , g_package
                                         , v_module
                                         , g_failure_status
                                         , SQLCODE
                                         , 'Invalid Cursor'
                                         , g_label1
                                         , v_loc
                                         , 'Records Read'
                                         , g_records_read );
         g_fail_flag    := TRUE;
         g_fail_msg     := SQLERRM;
      WHEN OTHERS
      THEN
         ttec_error_logging.process_error( g_application_code
                                         , g_interface
                                         , g_package
                                         , v_module
                                         , g_failure_status
                                         , SQLCODE
                                         , SQLERRM
                                         , g_label1
                                         , v_loc
                                         , 'Records Read'
                                         , g_records_read );
         g_fail_flag    := TRUE;
         g_fail_msg     := SQLERRM;
   END main;

   --
   -- PROCEDURE conc_mgr_wrapper
   --
   -- Description: This is a wrapper procedure to be called directly from the Concurrent
   --   Mgr.  It will set Globals from input parameters and will output the final log.
   --   This approach will allow the Main process to be ran/tested from the Conc Mgr or SQL.
   --
   PROCEDURE conc_mgr_wrapper(
      errbuf                OUT      VARCHAR2
    , retcode               OUT      NUMBER
    , p_business_group_id   IN       VARCHAR2
    , p_bucket_number       IN       NUMBER
    , p_buckets             IN       NUMBER )
   IS
      v_start_timestamp             DATE := SYSDATE;
      e_cleanup_err                 EXCEPTION;
      --v_module                      cust.ttec_error_handling.module_name%TYPE
      --                                                  := 'conc_mgr_wrapper'; --code commented by RXNETHI-ARGANO,05/05/23
	  v_module                      apps.ttec_error_handling.module_name%TYPE
                                                        := 'conc_mgr_wrapper'; --code added by RXNETHI-ARGANO,05/05/23
      v_loc                         NUMBER;
   BEGIN
      -- Submit the Main Process
      main( p_business_group_id, p_bucket_number, p_buckets );

      -- Log Counts
      BEGIN
         -- Write to Log
         fnd_file.new_line( fnd_file.LOG, 1 );
         fnd_file.put_line( fnd_file.LOG, 'COUNTS' );
         fnd_file.put_line
                ( fnd_file.LOG
                , '---------------------------------------------------------' );
         fnd_file.put_line( fnd_file.LOG
                          , '# Read                  : '
                            || g_records_read );
         fnd_file.put_line( fnd_file.LOG
                          , '  # Processed           : '
                            || g_records_processed );
         fnd_file.put_line( fnd_file.LOG
                          , '  # No Accruals         : '
                            || g_records_skipped );
         fnd_file.put_line( fnd_file.LOG
                          , '  # Errored             : '
                            || g_records_errored );
         fnd_file.put_line
                 ( fnd_file.LOG
                 , '---------------------------------------------------------' );
         fnd_file.new_line( fnd_file.LOG, 2 );
         -- Write to Output
         fnd_file.put_line( fnd_file.output, 'COUNTS' );
         fnd_file.put_line
                 ( fnd_file.output
                 , '---------------------------------------------------------' );
         fnd_file.put_line( fnd_file.output
                          , '# Read                  : '
                            || g_records_read );
         fnd_file.put_line( fnd_file.output
                          , '  # Processed           : '
                            || g_records_processed );
         fnd_file.put_line( fnd_file.output
                          , '  # No Accruals         : '
                            || g_records_skipped );
         fnd_file.put_line( fnd_file.output
                          , '  # Errored             : '
                            || g_records_errored );
         fnd_file.put_line
                 ( fnd_file.output
                 , '---------------------------------------------------------' );
         fnd_file.new_line( fnd_file.output, 2 );

         IF g_records_errored > 0
         THEN
            retcode    := 1;   -- Lable CR with WARNING
         END IF;
      EXCEPTION
         WHEN OTHERS
         THEN
            fnd_file.put_line( fnd_file.LOG, '   Error reporting Counts' );
            retcode    := 1;
      END;

      -- Log Errors / Warnings
      BEGIN
         -- Critical Failures from this Package
         ttec_error_logging.log_error_details
                            ( p_application        => g_application_code
                            , p_interface          => g_interface
                            , p_message_type       => g_failure_status
                            , p_message_label      => 'CRITICAL ERRORS - FAILURE'
                            , p_request_id         => g_request_id );
         -- Errors from this Package
         ttec_error_logging.log_error_details
                         ( p_application        => g_application_code
                         , p_interface          => g_interface
                         , p_message_type       => g_error_status
                         , p_message_label      => 'SKIPPED Records Due to Errors'
                         , p_request_id         => g_request_id );
         -- Warnings from this Package
         ttec_error_logging.log_error_details
            ( p_application        => g_application_code
            , p_interface          => g_interface
            , p_message_type       => g_warning_status
            , p_message_label      => 'Additional Warning Messages (records not Skipped)'
            , p_request_id         => g_request_id );
      EXCEPTION
         WHEN OTHERS
         THEN
            fnd_file.put_line( fnd_file.LOG
                             , '   Error Reporting Errors / Warnings' );
            retcode    := 1;
      END;

      -- Cleanup Log Table
      BEGIN
         -- Purge old Logging Records for this Interface
         ttec_error_logging.purge_log_errors
                                       ( p_application      => g_application_code
                                       , p_interface        => g_interface
                                       , p_keep_days        => g_keep_days );
      EXCEPTION
         WHEN OTHERS
         THEN
            fnd_file.put_line( fnd_file.LOG, 'Error Cleaning up Log tables' );
            fnd_file.put_line( fnd_file.LOG, SQLCODE
                                || ': '
                                || SQLERRM );
            retcode    := 2;
            errbuf     := SQLERRM;
      END;

      IF g_fail_flag
      THEN
         fnd_file.put_line
                         ( fnd_file.LOG
                         , 'Refer to Output for Detailed Errors and Warnings' );
         retcode    := 2;
         errbuf     := g_fail_msg;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         fnd_file.put_line( fnd_file.LOG, SQLCODE
                             || ': '
                             || SQLERRM );
         retcode    := 2;
         errbuf     := SQLERRM;
   END conc_mgr_wrapper;
END ttec_kr_accrual_outbound_SS;
/
show errors;
/