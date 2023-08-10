create or replace PACKAGE BODY ttec_phl_element_links_pkg AS
/* $Header: <file_name> 1.0 2005/07/21 mdodge ship $ */

/*== START ================================================================================================*\
  Author:  Michelle Dodge
    Date:  June 12, 2008
    Desc:  This package is for the purpose of creating the Element Entries for the new Philippine Recurring
           Elemenbts for all necessary Philippine employee assignments.

  Modification History:

  Mod#  Date        Author      Description (Include Ticket#)
 -----  ----------  ----------  ----------------------------------------------
   001  06/12/2008  M. Dodge    Initial Creation
   002  16/MAY/2023 RXNETHI-ARGANO  R12.2 Upgrade Remediation
\*== END ==================================================================================================*/

  -- Testing Variables - NOT FOR PROD
  t_employee_number_low   NUMBER; --      := 2000331;
  t_employee_number_high  NUMBER; --      := 2000331;

  -- Global Variables
  g_validate           BOOLEAN       := FALSE;
  g_session_date       DATE          := TRUNC(SYSDATE);
  g_batch_name_prefix  VARCHAR2(25)  := 'PHL_IMP_';
  g_batch_name         VARCHAR2(25);
  g_business_group_id  NUMBER        := 1517;
  g_batch_source       VARCHAR2(3)   := 'BPO';
  g_entry_type         VARCHAR2(1)   := 'E';             -- Element Entry

  /*
  START R12.2 Upgrade Remediation
  code commented by RXNETHI-ARGANO,16/05/23
  g_mgmt_payroll        hr.pay_all_payrolls_f.payroll_name%TYPE := 'PHL Management';
  g_non_mgmt_payroll    hr.pay_all_payrolls_f.payroll_name%TYPE := 'PHL Non-Management';
  g_mgmt_payroll_id     hr.pay_all_payrolls_f.payroll_id%TYPE;
  g_non_mgmt_payroll_id hr.pay_all_payrolls_f.payroll_id%TYPE;
  */
  --code added by RXNETHI-ARGANO,16/05/23
  g_mgmt_payroll        apps.pay_all_payrolls_f.payroll_name%TYPE := 'PHL Management';
  g_non_mgmt_payroll    apps.pay_all_payrolls_f.payroll_name%TYPE := 'PHL Non-Management';
  g_mgmt_payroll_id     apps.pay_all_payrolls_f.payroll_id%TYPE;
  g_non_mgmt_payroll_id apps.pay_all_payrolls_f.payroll_id%TYPE;
  --END R12.2 Upgrade Remediation
  -- Global Count Variables for logging information
  g_new_amort_cnt      NUMBER        := 0;
  g_new_allow_cnt      NUMBER        := 0;
  g_conv_stg_cnt       NUMBER        := 0;
  g_nonconv_stg_cnt    NUMBER        := 0;

  g_new_stg_cnt        NUMBER        := 0;
  g_bad_asgs_cnt       NUMBER        := 0;
  g_bad_payroll_cnt    NUMBER        := 0;
  g_bad_eles_cnt       NUMBER        := 0;

  g_conv_bee_cnt       NUMBER        := 0;

--  g_batch_sequence       hr.pay_batch_lines.batch_sequence%TYPE := 0;

  g_batch_run_number     NUMBER  := 0;

PROCEDURE insert_stage( p_employee_number   IN VARCHAR2
                      , p_bpo_element_name  IN VARCHAR2
                      , p_value2            IN VARCHAR2
                      , p_value3            IN VARCHAR2 DEFAULT NULL
                      , p_value4            IN VARCHAR2 DEFAULT NULL
                      , p_value6            IN VARCHAR2 DEFAULT NULL ) IS

  l_api_name           VARCHAR2(50) := 'ttec_phl_element_links_pkg.insert_stage';
--  l_api_name           VARCHAR2(50) := 'pay_batch_element_entry_api.create_batch_line';

BEGIN

  --INSERT INTO cust.ttec_phl_bpo_recur_bee_stg --code commented by RXNETHI-ARGANO,16/05/23
  INSERT INTO apps.ttec_phl_bpo_recur_bee_stg   --code added by RXNETHI-ARGANO,16/05/23
    ( employee_number
    , bpo_element_name
    , value2
    , value3
    , value4
    , value6
    , processed_flag
    )
  VALUES
    ( p_employee_number
    , p_bpo_element_name
    , p_value2
    , p_value3
    , p_value4
    , p_value6
    , 'N'
    );

EXCEPTION
  WHEN OTHERS THEN
    ttec_phl_paygroup_asg_pkg.log_message
      ( g_batch_run_number
      , l_api_name                  -- p_api_name
      , 'F'                         -- p_status
      , SQLCODE                     -- p_error_number
      , SQLERRM                     -- p_error_message
      , fnd_message.get             -- p_extended_error_message
      , 'Emp #: '||p_employee_number||
        '; BPO Element: '||p_bpo_element_name||
        '; Value2: '||p_value2||
        '; Value3: '||p_value3||
        '; Value4: '||p_value4||
        '; Value6: '||p_value6  );
END insert_stage;


--
-- convert_to_stage
--   This procedure will process all records in both the Earnings element working
--   table and the Loans Elements working table and convert them into identical structures
--   inserted into the staging table.
--
PROCEDURE convert_to_stage IS

  l_api_name           VARCHAR2(50) := 'ttec_phl_element_links_pkg.convert_to_stage';
--  l_api_name           VARCHAR2(50) := 'pay_batch_element_entry_api.create_batch_line';

  l_bpo_element_name   VARCHAR2(30);
  l_value              VARCHAR2(30);

  CURSOR get_recur_amort IS
    SELECT ra.emp_no
         , ra.bpo_element_name
         , ra.amortization
         , ra.date_started
         , ra.loan_amount
         , ra.payment_term
         , ra.rowid
      --FROM cust.ttec_phl_bpo_recur_amort_wk ra  --code commented by RXNETHI-ARGANO,16/05/23
      FROM apps.ttec_phl_bpo_recur_amort_wk ra  --code added by RXNETHI-ARGANO,16/05/23
     WHERE NVL(ra.processed_flag,'N') = 'N'
       AND ra.emp_no BETWEEN NVL(t_employee_number_low, ra.emp_no )
                         AND NVL(t_employee_number_high, ra.emp_no );  -- Testing ONLY

  CURSOR get_recur_allow IS
    SELECT ra.emp_no
         , ra.meal_allowance
         , ra.rice_subsidy
         , ra.phone_allowance
         , ra.meal_allowance_taxable
         , ra.travel_allowance
         , ra.language_allowance
         , ra.living_allowance
         , ra.rowid
      --FROM cust.ttec_phl_bpo_recur_allow_wk ra  --code commented by RXNETHI-ARGANO,16/05/23
      FROM apps.ttec_phl_bpo_recur_allow_wk ra  --code added by RXNETHI-ARGANO,16/05/23
     WHERE NVL(ra.processed_flag,'N') = 'N'
       AND ra.emp_no BETWEEN NVL(t_employee_number_low, ra.emp_no )
                         AND NVL(t_employee_number_high, ra.emp_no );  -- Testing ONLY

BEGIN

  FOR recur_amort_rec IN get_recur_amort LOOP
    BEGIN

      g_new_amort_cnt := get_recur_amort%ROWCOUNT;

      -- Create a record in the Stage table with each Value field
      -- properly assigned.
      insert_stage( recur_amort_rec.emp_no
                  , recur_amort_rec.bpo_element_name
                  , recur_amort_rec.date_started
                  , recur_amort_rec.loan_amount
                  , recur_amort_rec.amortization
                  , recur_amort_rec.payment_term );

      -- Flag the temp table record as processed
      --UPDATE cust.ttec_phl_bpo_recur_amort_wk  --code commented by RXNETHI-ARGANO,16/05/23
      UPDATE apps.ttec_phl_bpo_recur_amort_wk    --code added by RXNETHI-ARGANO,16/05/23
         SET processed_flag = 'Y'
       WHERE ROWID = recur_amort_rec.rowid;

    EXCEPTION
      WHEN OTHERS THEN
        ttec_phl_paygroup_asg_pkg.log_message
          ( g_batch_run_number
          , l_api_name                  -- p_api_name
          , 'F'                         -- p_status
          , SQLCODE                     -- p_error_number
          , SQLERRM                     -- p_error_message
          , fnd_message.get             -- p_extended_error_message
          , 'Emp #: '||recur_amort_rec.emp_no||
            '; BPO Element: '||recur_amort_rec.bpo_element_name||
            '; Date Start: '||recur_amort_rec.date_started||
            '; Loan Amount: '||recur_amort_rec.loan_amount||
            '; Amortization: '||recur_amort_rec.amortization||
            '; Term: '||recur_amort_rec.payment_term );
    END;
  END LOOP;

  FOR recur_allow_rec IN get_recur_allow LOOP
    BEGIN

      g_new_allow_cnt := get_recur_allow%ROWCOUNT;

      -- Create a record in the Stage table for each of the
      -- Non Null element columns

      -- Add Meal Allowance and Meal Allowance Taxable
      IF NVL(recur_allow_rec.meal_allowance,0) != 0 OR
         NVL(recur_allow_rec.meal_allowance_taxable,0) != 0 THEN

        l_value := NVL(recur_allow_rec.meal_allowance,0) +
                   NVL(recur_allow_rec.meal_allowance_taxable,0);

        l_bpo_element_name := 'MEAL ALLOWANCE';
        insert_stage( recur_allow_rec.emp_no
                    , l_bpo_element_name
                    , l_value );
      END IF;

      IF NVL(recur_allow_rec.rice_subsidy,0) != 0 THEN
        l_bpo_element_name := 'RICE SUBSIDY';
        l_value := recur_allow_rec.rice_subsidy;

        insert_stage( recur_allow_rec.emp_no
                    , l_bpo_element_name
                    , l_value );
      END IF;

      IF NVL(recur_allow_rec.phone_allowance,0) != 0 THEN
        l_bpo_element_name := 'PHONE ALLOWANCE';
        l_value := recur_allow_rec.phone_allowance;

        insert_stage( recur_allow_rec.emp_no
                    , l_bpo_element_name
                    , l_value );
      END IF;

      IF NVL(recur_allow_rec.travel_allowance,0) != 0 THEN
        l_bpo_element_name := 'TRAVEL ALLOWANCE';
        l_value := recur_allow_rec.travel_allowance;

        insert_stage( recur_allow_rec.emp_no
                    , l_bpo_element_name
                    , l_value );
      END IF;

      IF NVL(recur_allow_rec.language_allowance,0) != 0 THEN
        l_bpo_element_name := 'LANGUAGE ALLOWANCE';
        l_value := recur_allow_rec.language_allowance;

        insert_stage( recur_allow_rec.emp_no
                    , l_bpo_element_name
                    , l_value );
      END IF;

      IF NVL(recur_allow_rec.living_allowance,0) != 0 THEN
        l_bpo_element_name := 'LIVING ALLOWANCE';
        l_value := recur_allow_rec.living_allowance;

        insert_stage( recur_allow_rec.emp_no
                    , l_bpo_element_name
                    , l_value );
      END IF;

      -- Flag the temp table record as processed
      --UPDATE cust.ttec_phl_bpo_recur_allow_wk  --code commented by RXNETHI-ARGANO,16/05/23
      UPDATE apps.ttec_phl_bpo_recur_allow_wk    --code added by RXNETHI-ARGANO,16/05/23
         SET processed_flag = 'Y'
       WHERE ROWID = recur_allow_rec.rowid;

    EXCEPTION
      WHEN OTHERS THEN
        ttec_phl_paygroup_asg_pkg.log_message
          ( g_batch_run_number
          , l_api_name                  -- p_api_name
          , 'F'                         -- p_status
          , SQLCODE                     -- p_error_number
          , SQLERRM                     -- p_error_message
          , fnd_message.get             -- p_extended_error_message
          , 'Emp #: '||recur_allow_rec.emp_no||
            '; BPO Element: '||l_bpo_element_name||
            '; Value: '||l_value );
    END;
  END LOOP;

EXCEPTION
  WHEN OTHERS THEN
    ttec_phl_paygroup_asg_pkg.log_message
      ( g_batch_run_number
      , l_api_name                  -- p_api_name
      , 'F'                         -- p_status
      , SQLCODE                     -- p_error_number
      , SQLERRM                     -- p_error_message
      , fnd_message.get             -- p_extended_error_message
      , NULL );
END convert_to_stage;

--
-- lookup_asgn_info
--   This procedure will identify and update the Assignment ID and Assignment Number
--   for all records in the staging table from the BPO provided employee number.  It chooses the
--   active assignment record at run time.
--
PROCEDURE lookup_asgn_info IS

  l_api_name           VARCHAR2(50) := 'ttec_phl_element_links_pkg.lookup_asgn_info';
--  l_api_name           VARCHAR2(50) := 'pay_batch_element_entry_api.create_batch_line';

  l_asgn_id         NUMBER;
  l_asgn_no         VARCHAR2(15);
  l_payroll_id      NUMBER;
  l_bad_payroll_cnt NUMBER;
  l_effective_date  DATE;

  CURSOR get_employee IS
    SELECT UNIQUE employee_number
      --FROM cust.ttec_phl_bpo_recur_bee_stg   --code commented by RXNETHI-ARGANO,16/05/23
      FROM apps.ttec_phl_bpo_recur_bee_stg     --code added by RXNETHI-ARGANO,16/05/23
     WHERE NVL(processed_flag,'N') = 'N'
       AND employee_number BETWEEN NVL(t_employee_number_low, employee_number )
                               AND NVL(t_employee_number_high, employee_number )  -- Testing ONLY
    ORDER BY employee_number;

BEGIN

  -- Get Count of New Staging records to process
  SELECT COUNT(*)
    INTO g_new_stg_cnt
    --FROM cust.ttec_phl_bpo_recur_bee_stg  --code commented by RXNETHI-ARGANO,16/05/23
    FROM apps.ttec_phl_bpo_recur_bee_stg  --code added by RXNETHI-ARGANO,16/05/23
   WHERE NVL(processed_flag,'N') = 'N'
     AND employee_number BETWEEN NVL(t_employee_number_low, employee_number )
                             AND NVL(t_employee_number_high, employee_number );

  FOR employee_rec IN get_employee LOOP
    BEGIN

      l_asgn_id := NULL;
      l_asgn_no := NULL;

      -- Get Assignment Number and ID for each employee
      SELECT paa.assignment_id, paa.assignment_number, paa.payroll_id
        INTO l_asgn_id, l_asgn_no, l_payroll_id
        /*
		START R12.2 Upgrade Remediation
		code commented by RXNETHI-ARGANO,16/05/23
		FROM hr.per_all_people_f pap
           , hr.per_all_assignments_f paa
        */
		--code added by RXNETHI-ARGANO,16/05/23
		FROM apps.per_all_people_f pap
           , apps.per_all_assignments_f paa
		--END R12.2 Upgrade Remediation
	   WHERE pap.business_group_id = g_business_group_id
         AND pap.employee_number = employee_rec.employee_number
         AND SYSDATE BETWEEN pap.effective_start_date AND pap.effective_end_date
         AND paa.person_id = pap.person_id
         AND SYSDATE BETWEEN paa.effective_start_date AND paa.effective_end_date;

      -- Get Effective Date for Recurring Element Entry based on Employee Assignment
      SELECT MIN(paa.effective_start_date)
        INTO l_effective_date
        --FROM hr.per_all_assignments_f paa  --code commented by RXNETHI-ARGANO,16/05/23
        FROM apps.per_all_assignments_f paa  --code added by RXNETHI-ARGANO,16/05/23
       WHERE paa.assignment_id = l_asgn_id
         AND paa.effective_end_date >= TO_DATE('01-JAN-2008','DD-MON-YYYY');

      IF l_effective_date < TO_DATE('01-JAN-2008','DD-MON-YYYY') THEN
        l_effective_date := TO_DATE('01-JAN-2008','DD-MON-YYYY');
      END IF;

      -- Stop processing Employees with incorrect Payroll here so that BEE Batch will
      -- not have issues with them.
      IF l_payroll_id NOT IN (g_mgmt_payroll_id, g_non_mgmt_payroll_id) THEN

        -- Get Count of Asgn records for this employee
        SELECT COUNT(*)
          INTO l_bad_payroll_cnt
          --FROM cust.ttec_phl_bpo_recur_bee_stg  --code commented by RXNETHI-ARGANO,16/05/23
          FROM apps.ttec_phl_bpo_recur_bee_stg    --code added by RXNETHI-ARGANO,16/05/23
         WHERE employee_number = employee_rec.employee_number
           AND NVL(processed_flag,'N') = 'N';

        g_bad_payroll_cnt := g_bad_payroll_cnt + l_bad_payroll_cnt;

        ttec_phl_paygroup_asg_pkg.log_message
          ( g_batch_run_number
          , l_api_name                  -- p_api_name
          , 'F'                         -- p_status
          , NULL                        -- p_error_number
          , 'Employee not assigned to new Payroll' -- p_error_message
          , 'Employee not assigned to new Payroll' -- p_extended_error_message
          , 'Emp #: '||employee_rec.employee_number||
            '; Asgn ID: '||l_asgn_id||
            '; Asgn #: '||l_asgn_no );

      ELSE
        -- Update ALL records in Staging table for this employee
        --UPDATE cust.ttec_phl_bpo_recur_bee_stg  --code commented by RXNETHI-ARGANO,16/05/23
        UPDATE apps.ttec_phl_bpo_recur_bee_stg    --code added by RXNETHI-ARGANO,16/05/23
           SET assignment_id = l_asgn_id
             , assignment_number = l_asgn_no
             , effective_date = l_effective_date
             , processed_flag = '1'            -- In Process
         WHERE employee_number = employee_rec.employee_number
           AND NVL(processed_flag,'N') = 'N';
      END IF;

    EXCEPTION
      WHEN OTHERS THEN
        ttec_phl_paygroup_asg_pkg.log_message
          ( g_batch_run_number
          , l_api_name                  -- p_api_name
          , 'F'                         -- p_status
          , SQLCODE                     -- p_error_number
          , SQLERRM                     -- p_error_message
          , fnd_message.get             -- p_extended_error_message
          , 'Emp #: '||employee_rec.employee_number||
            '; Asgn ID: '||l_asgn_id||
            '; Asgn #: '||l_asgn_no );
    END;
  END LOOP;

EXCEPTION
  WHEN OTHERS THEN
    ttec_phl_paygroup_asg_pkg.log_message
      ( g_batch_run_number
      , l_api_name                  -- p_api_name
      , 'F'                         -- p_status
      , SQLCODE                     -- p_error_number
      , SQLERRM                     -- p_error_message
      , fnd_message.get             -- p_extended_error_message
      , NULL );
END lookup_asgn_info;

--
-- lookup_element_info
--   This procedure will identify and update the Element_Type_ID for all records in the
--   staging table, using the mapping table to map the BPO Element Name to the Oracle Element Name.
--
PROCEDURE lookup_element_info IS

  l_api_name           VARCHAR2(50) := 'ttec_phl_element_links_pkg.lookup_element_info';
--  l_api_name           VARCHAR2(50) := 'pay_batch_element_entry_api.create_batch_line';

  --l_element_type_id    hr.pay_element_types_f.element_type_id%TYPE;  --code commented by RXNETHI-ARGANO,16/05/23
  l_element_type_id    apps.pay_element_types_f.element_type_id%TYPE;  --code added by RXNETHI-ARGANO,16/05/23

  --Custom Exceptions
  e_nonmapped_element  EXCEPTION;

  CURSOR get_element IS
    SELECT UNIQUE em.element_name, rb.bpo_element_name
      /*
	  START R12.2 Upgrade Remediation
	  code commented by RXNETHI-ARGANO,16/05/23
	  FROM cust.ttec_phl_bpo_element_map_ext em
         , cust.ttec_phl_bpo_recur_bee_stg rb
      */
	  --code added by RXNETHI-ARGANO,16/05/23
	  FROM apps.ttec_phl_bpo_element_map_ext em
         , apps.ttec_phl_bpo_recur_bee_stg rb
	  --END R12.2 Upgrade Remediation
	 WHERE em.bpo_element_name (+) = rb.bpo_element_name
       AND NVL(processed_flag,'N') = '1';

BEGIN

  FOR element_rec IN get_element LOOP
    -- Lookup Element Type ID
    BEGIN

      IF element_rec.element_name IS NULL THEN
        RAISE e_nonmapped_element;
      END IF;

      l_element_type_id := NULL;

      SELECT element_type_id
        INTO l_element_type_id
        --FROM hr.pay_element_types_f  --code commented by RXNETHI-ARGANO,16/05/23
        FROM apps.pay_element_types_f  --code added by RXNETHI-ARGANO,16/05/23
       WHERE business_group_id = g_business_group_id
         AND element_name = element_rec.element_name;

      -- Update ALL records in Staging table for this element
      --UPDATE cust.ttec_phl_bpo_recur_bee_stg  --code commented by RXNETHI-ARGANO,16/05/23
      UPDATE apps.ttec_phl_bpo_recur_bee_stg    --code added by RXNETHI-ARGANO,16/05/23
         SET element_type_id = l_element_type_id
           , processed_flag = '2'                  -- In Process 2nd Stage
       WHERE bpo_element_name = element_rec.bpo_element_name
         AND NVL(processed_flag,'N') = '1';

    EXCEPTION
      WHEN e_nonmapped_element THEN
        ttec_phl_paygroup_asg_pkg.log_message
          ( g_batch_run_number
          , l_api_name                  -- p_api_name
          , 'F'                         -- p_status
          , NULL                        -- p_error_number
          , 'BPO Element not Mapped to Oracle Element'  -- p_error_message
          , 'BPO Element not Mapped to Oracle Element'  -- p_extended_error_message
          , 'BPO Element Name: '||element_rec.bpo_element_name );
      WHEN OTHERS THEN
        ttec_phl_paygroup_asg_pkg.log_message
          ( g_batch_run_number
          , l_api_name                  -- p_api_name
          , 'F'                         -- p_status
          , SQLCODE                     -- p_error_number
          , SQLERRM                     -- p_error_message
          , fnd_message.get             -- p_extended_error_message
          , 'BPO Element Name: '||element_rec.bpo_element_name||
            'Element Name: '||element_rec.element_name );
    END;
  END LOOP;

EXCEPTION
  WHEN OTHERS THEN
    ttec_phl_paygroup_asg_pkg.log_message
      ( g_batch_run_number
      , l_api_name                  -- p_api_name
      , 'F'                         -- p_status
      , SQLCODE                     -- p_error_number
      , SQLERRM                     -- p_error_message
      , fnd_message.get             -- p_extended_error_message
      , NULL );
END lookup_element_info;

--
-- load_bee_tables
--   This procedure will create a BEE Batch Header record and Bee Batch Line records for
--   all successfully prepped records in the staging table.
--
PROCEDURE load_bee_tables IS

  l_api_name           VARCHAR2(50);

  l_batch_id               NUMBER;
  l_batch_line_id          NUMBER;
  l_bh_ovn                 NUMBER;
  l_bl_ovn                 NUMBER;

  l_effective_date         DATE          := g_session_date;
  l_effective_start_date   DATE          := g_session_date;

  CURSOR get_bee_lines IS
    SELECT assignment_id
         , assignment_number
         , effective_date
         , element_type_id
         , value2
         , value3
         , value4
         , value6
         , rowid
      --FROM cust.ttec_phl_bpo_recur_bee_stg  --code commented by RXNETHI-ARGANO,16/05/23
      FROM apps.ttec_phl_bpo_recur_bee_stg    --code added by RXNETHI-ARGANO,16/05/23
     WHERE NVL(processed_flag,'N') = '2'
       AND employee_number BETWEEN NVL(t_employee_number_low, employee_number )
                               AND NVL(t_employee_number_high, employee_number );  -- Testing ONLY

BEGIN

  l_api_name := 'pay_batch_element_entry_api.create_batch_header';

  -- Calc unique Batch Name
  g_batch_name := g_batch_name_prefix||to_char(SYSDATE, 'YYYYMMDDHH24MISS');

  FOR bee_line_rec IN get_bee_lines LOOP

    -- Only create BEE Header if at least one BEE Line
    IF get_bee_lines%ROWCOUNT = 1 THEN
      -- Create BEE Header
      pay_batch_element_entry_api.create_batch_header
        ( p_validate                      => g_validate
        , p_session_date                  => g_session_date
        , p_batch_name                    => g_batch_name
        , p_business_group_id             => g_business_group_id
        , p_batch_source                  => g_batch_source
        , p_batch_id                      => l_batch_id
        , p_object_version_number         => l_bh_ovn
        );
    END IF;

    l_api_name := 'pay_batch_element_entry_api.create_batch_line';

    BEGIN
      -- Create BEE Lines from Staging Table
      pay_batch_element_entry_api.create_batch_line
      ( p_validate                      => g_validate
      , p_session_date                  => g_session_date
      , p_batch_id                      => l_batch_id
      , p_assignment_id                 => bee_line_rec.assignment_id
      , p_assignment_number             => bee_line_rec.assignment_number
--      , p_batch_sequence                => g_batch_sequence
      , p_effective_date                => bee_line_rec.effective_date
      , p_effective_start_date          => bee_line_rec.effective_date
      , p_element_type_id               => bee_line_rec.element_type_id
      , p_entry_type                    => g_entry_type
      , p_value_2                       => bee_line_rec.value2
      , p_value_3                       => bee_line_rec.value3
      , p_value_4                       => bee_line_rec.value4
      , p_value_6                       => bee_line_rec.value6
      , p_batch_line_id                 => l_batch_line_id
      , p_object_version_number         => l_bl_ovn
      );

      --UPDATE cust.ttec_phl_bpo_recur_bee_stg  --code commented by RXNETHI-ARGANO,16/05/23
      UPDATE apps.ttec_phl_bpo_recur_bee_stg    --code added by RXNETHI-ARGANO,16/05/23
         SET processed_flag = 'Y'
       WHERE rowid = bee_line_rec.rowid
         AND NVL(processed_flag,'N') = '2';

    EXCEPTION
      WHEN OTHERS THEN
        ttec_phl_paygroup_asg_pkg.log_message
          ( g_batch_run_number
          , l_api_name                  -- p_api_name
          , 'F'                         -- p_status
          , SQLCODE                     -- p_error_number
          , SQLERRM                     -- p_error_message
          , fnd_message.get             -- p_extended_error_message
          , 'Batch Name: '||g_batch_name||
            '; Batch Line ID: '||l_batch_line_id||
            '; Batch Line OVN: '||l_bl_ovn||
            '; Asgn ID: '||bee_line_rec.assignment_id||
            '; Asng #: '||bee_line_rec.assignment_number||
            '; Element ID: '||bee_line_rec.element_type_id||
            '; Value2: '||bee_line_rec.value2||
            '; Value3: '||bee_line_rec.value3||
            '; Value4: '||bee_line_rec.value4||
            '; Value6: '||bee_line_rec.value6 );
    END;
  END LOOP;

EXCEPTION
  WHEN OTHERS THEN
    ttec_phl_paygroup_asg_pkg.log_message
      ( g_batch_run_number
      , l_api_name                  -- p_api_name
      , 'F'                         -- p_status
      , SQLCODE                     -- p_error_number
      , SQLERRM                     -- p_error_message
      , fnd_message.get             -- p_extended_error_message
      , 'Batch Name: '||g_batch_name||
        '; Batch ID: '||l_batch_id||
        '; OVN: '||l_bh_ovn );
END load_bee_tables;

--
-- Main
--   This is the main procedure that will be called to Create Recurring Element Entries for both the
--   new Amortization and Allowance items.
--
PROCEDURE main IS

  l_api_name           VARCHAR2(50) := 'ttec_phl_element_links_pkg.main';
--  l_api_name           VARCHAR2(50) := 'pay_batch_element_entry_api.create_batch_line';

  l_batch_run_number   NUMBER       := 0;
  l_conv_stg_cnt       NUMBER       := 0;
  l_nonconv_stg_cnt    NUMBER       := 0;

  CURSOR get_allow_ext IS
    SELECT RTRIM(LTRIM(EMP_NO))               emp_no
         , RTRIM(LTRIM(LAST_NAME))            last_name
         , RTRIM(LTRIM(FIRST_NAME))           first_name
         , RTRIM(LTRIM(MIDDLE_INITIAL))       middle_initial
         , RTRIM(LTRIM(SITE))                 site
         , RTRIM(LTRIM(STATUS))               status
         , MEAL_ALLOWANCE                     meal_allowance
         , RICE_SUBSIDY                       rice_subsidy
         , PHONE_ALLOWANCE                    phone_allowance
         , MEAL_ALLOWANCE_TAXABLE             meal_allowance_taxable
         , TRAVEL_ALLOWANCE                   travel_allowance
         , LANGUAGE_ALLOWANCE                 language_allowance
         , LIVING_ALLOWANCE                   living_allowance
         , 'N'                                processed_flag
      FROM ttec_phl_bpo_recur_allow_ext;

  CURSOR get_amort_ext IS
    SELECT RTRIM(LTRIM(EMP_NO))               emp_no
         , RTRIM(LTRIM(LAST_NAME))            last_name
         , RTRIM(LTRIM(FIRST_NAME))           first_name
         , RTRIM(LTRIM(MIDDLE_INITIAL))       middle_initial
         , RTRIM(LTRIM(SITE))                 site
         , RTRIM(LTRIM(STATUS))               status
         , RTRIM(LTRIM(BPO_ELEMENT_NAME))     bpo_element_name
         , AMORTIZATION                       amortization
         , TO_DATE(DATE_STARTED,'MM/DD/YYYY') date_started
         , LOAN_AMOUNT                        loan_amount
         , PAYMENT_TERM                       payment_term
         , 'N'                                processed_flag
      FROM ttec_phl_bpo_recur_amort_ext;

BEGIN

  -- Set the batch run number if not already set.
  IF g_batch_run_number = 0 THEN
    SELECT NVL(MAX(batch_run_number), 0) + 1
      INTO l_batch_run_number
      --FROM hr.hr_api_batch_message_lines;  --code commented by RXNETHI-ARGANO,16/05/23
      FROM apps.hr_api_batch_message_lines;  --code added by RXNETHI-ARGANO,16/05/23
  END IF;

  g_batch_run_number := l_batch_run_number;

  -- Get New Payroll ID's
  g_mgmt_payroll_id     := ttec_phl_paygroup_asg_pkg.get_payroll_id(g_business_group_id, g_mgmt_payroll);
  g_non_mgmt_payroll_id := ttec_phl_paygroup_asg_pkg.get_payroll_id(g_business_group_id, g_non_mgmt_payroll);

  -- Load Temp Tables
  FOR allow_ext_rec IN get_allow_ext LOOP
    BEGIN
      INSERT INTO ttec_phl_bpo_recur_allow_wk
      VALUES allow_ext_rec;

    EXCEPTION
      WHEN OTHERS THEN
        ttec_phl_paygroup_asg_pkg.log_message
          ( g_batch_run_number
          , l_api_name                  -- p_api_name
          , 'F'                         -- p_status
          , SQLCODE                     -- p_error_number
          , SQLERRM                     -- p_error_message
          , 'Error loading Allowance table from External Table'  -- p_extended_error_message
          , NULL );
    END;
  END LOOP;

  FOR amort_ext_rec IN get_amort_ext LOOP
    BEGIN
      INSERT INTO ttec_phl_bpo_recur_amort_wk
      VALUES amort_ext_rec;

    EXCEPTION
      WHEN OTHERS THEN
        ttec_phl_paygroup_asg_pkg.log_message
          ( g_batch_run_number
          , l_api_name                  -- p_api_name
          , 'F'                         -- p_status
          , SQLCODE                     -- p_error_number
          , SQLERRM                     -- p_error_message
          , 'Error loading Amortization table from External Table'  -- p_extended_error_message
          , NULL );
    END;
  END LOOP;

  -- Convert Temp Tables to Staging Table
  convert_to_stage;
  COMMIT;

  -- Get Additional Working Table Counts
  SELECT COUNT(*)
    INTO g_nonconv_stg_cnt
    FROM ttec_phl_bpo_recur_amort_wk
   WHERE NVL(processed_flag,'N') = 'N'
     AND emp_no BETWEEN NVL(t_employee_number_low, emp_no )
                    AND NVL(t_employee_number_high, emp_no );

  SELECT COUNT(*)
    INTO g_conv_stg_cnt
    FROM ttec_phl_bpo_recur_amort_wk
   WHERE NVL(processed_flag,'N') = 'Y'
     AND emp_no BETWEEN NVL(t_employee_number_low, emp_no )
                    AND NVL(t_employee_number_high, emp_no );

  SELECT COUNT(*)
    INTO l_nonconv_stg_cnt
    FROM ttec_phl_bpo_recur_allow_wk
   WHERE NVL(processed_flag,'N') = 'N'
     AND emp_no BETWEEN NVL(t_employee_number_low, emp_no )
                    AND NVL(t_employee_number_high, emp_no );

  SELECT COUNT(*)
    INTO l_conv_stg_cnt
    FROM ttec_phl_bpo_recur_allow_wk
   WHERE NVL(processed_flag,'N') = 'Y'
     AND emp_no BETWEEN NVL(t_employee_number_low, emp_no )
                    AND NVL(t_employee_number_high, emp_no );

  g_nonconv_stg_cnt := g_nonconv_stg_cnt + l_nonconv_stg_cnt;
  g_conv_stg_cnt    := g_conv_stg_cnt + l_conv_stg_cnt;

  -- Lookup Assignment Info
  lookup_asgn_info;
  COMMIT;

  SELECT COUNT(*)
    INTO g_bad_asgs_cnt
    --FROM cust.ttec_phl_bpo_recur_bee_stg  --code commented by RXNETHI-ARGANO,16/05/23
    FROM apps.ttec_phl_bpo_recur_bee_stg    --code added by RXNETHI-ARGANO,16/05/23
   WHERE NVL(processed_flag,'N') = 'N'
     AND employee_number BETWEEN NVL(t_employee_number_low, employee_number )
                             AND NVL(t_employee_number_high, employee_number );

  -- Lookup Element Info
  lookup_element_info;
  COMMIT;

  SELECT COUNT(*)
    INTO g_bad_eles_cnt
    --FROM cust.ttec_phl_bpo_recur_bee_stg  --code commented by RXNETHI-ARGANO,16/05/23
    FROM apps.ttec_phl_bpo_recur_bee_stg    --code added by RXNETHI-ARGANO,16/05/23
   WHERE NVL(processed_flag,'N') = '1'
     AND employee_number BETWEEN NVL(t_employee_number_low, employee_number )
                             AND NVL(t_employee_number_high, employee_number );

  -- Load BEE Tables
  load_bee_tables;
  COMMIT;

  SELECT COUNT(*)
    INTO g_conv_bee_cnt
    --FROM cust.ttec_phl_bpo_recur_bee_stg  --code commented by RXNETHI-ARGANO,16/05/23
    FROM apps.ttec_phl_bpo_recur_bee_stg    --code added by RXNETHI-ARGANO,16/05/23
   WHERE NVL(processed_flag,'N') = 'Y'
     AND employee_number BETWEEN NVL(t_employee_number_low, employee_number )
                             AND NVL(t_employee_number_high, employee_number );

EXCEPTION
  WHEN OTHERS THEN
    ttec_phl_paygroup_asg_pkg.log_message
      ( g_batch_run_number
      , l_api_name                  -- p_api_name
      , 'F'                         -- p_status
      , SQLCODE                     -- p_error_number
      , SQLERRM                     -- p_error_message
      , fnd_message.get             -- p_extended_error_message
      , NULL );

    ROLLBACK;
END main;

--
-- conc_mgr_wrapper
--   This is a wrapper procedure to be called directly from the Concurrent
--   Mgr.  It will set Test Globals from input parameters and will output the final log.
--   This approach will allow the Main process to be ran/tested from a SQL prompt and
--   the Cong Mgr.
--
PROCEDURE conc_mgr_wrapper( p_error_msg      OUT VARCHAR2
                          , p_error_code     OUT VARCHAR2
                          , p_emp_no_low     IN  NUMBER
                          , p_emp_no_high    IN  NUMBER ) IS

  CURSOR get_error_message IS
    SELECT UNIQUE error_message
      FROM hr_api_batch_message_lines
     WHERE batch_run_number = g_batch_run_number
       AND status = 'F'
    ORDER BY error_message;

  error_message_rec get_error_message%ROWTYPE;

  CURSOR get_errors(p_err_mess VARCHAR2) IS
    SELECT source_row_information
      FROM hr_api_batch_message_lines
     WHERE batch_run_number = g_batch_run_number
       AND status = 'F'
       AND error_message = p_err_mess;

  error_rec get_errors%ROWTYPE;

BEGIN

  -- Set Global Test Variables
  t_employee_number_low  := p_emp_no_low;
  t_employee_number_high := p_emp_no_high;

  fnd_file.new_line(fnd_file.log, 1);
  fnd_file.put_line(fnd_file.log, 'Emp # Low : '||t_employee_number_low);
  fnd_file.put_line(fnd_file.log, 'Emp # High: '||t_employee_number_high);
  fnd_file.new_line(fnd_file.log, 1);

  -- Submit the Main Process
  main;

  -- Log Errors
  BEGIN

    fnd_file.put_line(fnd_file.log, 'BEE Batch Name: '||g_batch_name);

    IF g_batch_run_number = 0 THEN
      fnd_file.put_line(fnd_file.log, 'Message Batch #: No Messages Generated');
    ELSE
      fnd_file.put_line(fnd_file.log, 'Message Batch #: '||g_batch_run_number);
    END IF;

    g_bad_asgs_cnt := g_bad_asgs_cnt - g_bad_payroll_cnt;

    fnd_file.new_line(fnd_file.log,1);
    fnd_file.put_line(fnd_file.log,'COUNTS');
    fnd_file.put_line(fnd_file.log,'---------------------------------------------------------');
    fnd_file.put_line(fnd_file.log,'# of Loan records to process                 : '||g_new_amort_cnt);
    fnd_file.put_line(fnd_file.log,'# of Earnings records to process             : '||g_new_allow_cnt||
                                   '   (Note: Multiple elements per record)');
    fnd_file.put_line(fnd_file.log,'   # of Loan / Earnings records Converted    : '||g_conv_stg_cnt);
    fnd_file.put_line(fnd_file.log,'   # of Loan / Earnings records Not Converted: '||g_nonconv_stg_cnt);
    fnd_file.new_line(fnd_file.log,1);
    fnd_file.put_line(fnd_file.log,'# of Element Assignments to Process   : '||g_new_stg_cnt);
    fnd_file.put_line(fnd_file.log,'   # with Unknown Assignment Info     : '||g_bad_asgs_cnt);
    fnd_file.put_line(fnd_file.log,'   # not assigned to new Payrolls     : '||g_bad_payroll_cnt);
    fnd_file.put_line(fnd_file.log,'   # with Unknown Oracle Element Info : '||g_bad_eles_cnt);
    fnd_file.put_line(fnd_file.log,'   # Converted to Bee Batch Tables    : '||g_conv_bee_cnt);
    fnd_file.put_line(fnd_file.log,'---------------------------------------------------------');

    fnd_file.new_line(fnd_file.output,1);
    fnd_file.put_line(fnd_file.output,'COUNTS');
    fnd_file.put_line(fnd_file.output,'---------------------------------------------------------');
    fnd_file.put_line(fnd_file.output,'# of Loan records to process                 : '||g_new_amort_cnt);
    fnd_file.put_line(fnd_file.output,'# of Earnings records to process             : '||g_new_allow_cnt||
                                      '   (Note: Multiple elements per record)');
    fnd_file.put_line(fnd_file.output,'   # of Loan / Earnings records Converted    : '||g_conv_stg_cnt);
    fnd_file.put_line(fnd_file.output,'   # of Loan / Earnings records Not Converted: '||g_nonconv_stg_cnt);
    fnd_file.new_line(fnd_file.output,1);
    fnd_file.put_line(fnd_file.output,'# of Element Assignments to Process   : '||g_new_stg_cnt);
    fnd_file.put_line(fnd_file.output,'   # with Unknown Assignment Info     : '||g_bad_asgs_cnt);
    fnd_file.put_line(fnd_file.output,'   # not assigned to new Payrolls     : '||g_bad_payroll_cnt);
    fnd_file.put_line(fnd_file.output,'   # with Unknown Oracle Element Info : '||g_bad_eles_cnt);
    fnd_file.put_line(fnd_file.output,'   # Converted to Bee Batch Tables    : '||g_conv_bee_cnt);
    fnd_file.put_line(fnd_file.output,'---------------------------------------------------------');

    fnd_file.new_line(fnd_file.log,1);
    fnd_file.new_line(fnd_file.log,1);
    fnd_file.put_line(fnd_file.log,'Refer to Output for Detailed Errors and Warnings');
    fnd_file.new_line(fnd_file.log, 1);

    fnd_file.new_line(fnd_file.output,1);
    fnd_file.new_line(fnd_file.output,1);
    fnd_file.put_line(fnd_file.output,'ERRORS');
    fnd_file.put_line(fnd_file.output,'--------------------');

    OPEN get_error_message;
    LOOP
      FETCH get_error_message
        INTO error_message_rec;
      EXIT WHEN get_error_message%NOTFOUND;

      fnd_file.put_line(fnd_file.output,error_message_rec.error_message);

      FOR error_rec IN get_errors(error_message_rec.error_message) LOOP
        fnd_file.put_line(fnd_file.output,'      '||error_rec.source_row_information);
      END LOOP;

    END LOOP;

    IF get_error_message%ROWCOUNT = 0 THEN
      fnd_file.put_line(fnd_file.output,'No Errors to Report');
    END IF;

    CLOSE get_error_message;
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, '   Error Reporting Detailed Errors');
  END;

EXCEPTION
  WHEN OTHERS THEN
    fnd_file.put_line(fnd_file.log, SQLCODE||': '||SQLERRM);
END;

END ttec_phl_element_links_pkg;
/
show errors;
/