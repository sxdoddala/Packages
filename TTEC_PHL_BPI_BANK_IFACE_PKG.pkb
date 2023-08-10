create or replace PACKAGE BODY      TTEC_PHL_BPI_BANK_IFACE_PKG AS
/* $Header: ttec_phl_bpo_bank_iface_pkg.pkb/ 1.0 2008/06/30 mdodge ship $ */

/*== START ================================================================================================*\
  Author:  Michelle Dodge
    Date:  June 30, 2008
    Desc:  This package is intended to be ran once (?) to load BPI employee bank details into their
           Personal Payment Methods.

  Modification History:

  Mod#  Date        Author      Description (Include Ticket#)
 -----  ----------  ----------  ----------------------------------------------
   001  06/30/2008  M Dodge     Initial Creation
   1.1  02/02/2012  C. Chan     TTSD I#1224513 - Organization can have more than one pay method - depends on the payroll id
   2.0  09/19/2018  C. Chan     Add Bank Name to be able to upload employee bank account for a different bank
    1.0 05/03/2023  MXKEERTHI(ARGANO)      R12.2 Upgrade Remediation
\*== END ==================================================================================================*/

  -- Testing Variables - NOT FOR PROD
  t_test_mode             BOOLEAN      := TRUE;

  -- Error Constants
  --START R12.2 Upgrade Remediation
	  /*
		Commented code by MXKEERTHI-ARGANO, 05/03/2023
      g_application_code      cust.ttec_error_handling.application_code%TYPE := 'PAY';
  g_interface             cust.ttec_error_handling.interface%TYPE        := 'PHL Bank Iface';
  g_package               cust.ttec_error_handling.program_name%type     := 'ttec_phl_bpi_bank_iface_pkg';
	   */
	  --code Added  by MXKEERTHI-ARGANO, 05/03/2023
	  g_application_code      APPS.ttec_error_handling.application_code%TYPE := 'PAY';
  g_interface             APPS.ttec_error_handling.interface%TYPE        := 'PHL Bank Iface';
  g_package               APPS.ttec_error_handling.program_name%type     := 'ttec_phl_bpi_bank_iface_pkg';
	  --END R12.2.10 Upgrade remediation


  c_status_warning		  VARCHAR2(7)	:= 'WARNING';
  c_status_failure		  VARCHAR2(7)	:= 'FAILURE';

  -- Global Constants
  --g_bus_grp_id            hr.hr_all_organization_units.business_group_id%TYPE := 1517;   -- commented Code by MXKEERTHI-ARGANO,05/03/2023
  g_bus_grp_id            APPS.hr_all_organization_units.business_group_id%TYPE := 1517;   --code Added  by MXKEERTHI-ARGANO,05/03/2023
  g_run_date              DATE         := TRUNC(SYSDATE);
  --g_bank_name             VARCHAR2(30) := 'Bank of the Philippines'; /* 2.0 */
  g_bank_name             VARCHAR2(100) := '';   /* 2.0 */
  g_percentage            NUMBER       := 100;
  g_priority              NUMBER       := 1;

  g_validate              BOOLEAN      := FALSE;
  g_batch_id              NUMBER       := 0;

  g_org_pay_method_name   VARCHAR2(20) := 'Direct Deposit';
  g_org_payment_method_id NUMBER;
  g_territory_code        VARCHAR2(50) := 'PH';

  -- KFF Variables
  g_app_short_name       fnd_application.application_short_name%TYPE := 'PAY';
  g_key_flex_name        fnd_id_flexs.id_flex_name%TYPE := 'Bank Details KeyFlexField';
  g_structure_code       fnd_id_flex_structures.id_flex_structure_code%TYPE := 'PH_BANK_DETAILS';

  g_key_flex_code        fnd_id_flexs.id_flex_code%TYPE;
  g_structure_num        fnd_id_flex_structures.id_flex_num%TYPE;
  g_no_segments          NUMBER;

  -- Working File System Filenames
  g_hdr_filename          VARCHAR2(50) := 'ttec_phl_bank_iface_hdr_ext.csv';
  g_dtl_filename          VARCHAR2(50) := 'ttec_phl_bank_iface_dtl_ext.csv';

  g_fail_flag             BOOLEAN      := FALSE;
  g_fail_msg              VARCHAR2(50);

  -- Global Count Variables for logging information
  g_total_cnt             NUMBER       := 0;

  g_total_emp_cnt         NUMBER       := 0;
  g_success_emp_cnt       NUMBER       := 0;
  g_fail_emp_cnt          NUMBER       := 0;

  g_cnt                   NUMBER       := 0;
  g_commit_cnt            NUMBER       := 1000;   -- # of records to commit.

--
-- PROCEDURE initialize
--
-- Description: This procedure will lookup and set necessary global variables.
--
PROCEDURE initialize IS
  -- l_module  cust.ttec_error_handling.module_name%TYPE := 'initialize'; --Commented code by MXKEERTHI-ARGANO, 05/08/2023
   l_module  apps.ttec_error_handling.module_name%TYPE := 'initialize';  --code added by MXKEERTHI-ARGANO, 05/08/2023



  l_application_id   fnd_application.application_id%TYPE;

BEGIN
  -- Get the Org Payment Method ID and Territory Code for new Personal Payment Methods
  SELECT org_payment_method_id
    INTO g_org_payment_method_id
    FROM pay_org_payment_methods_f
   WHERE business_group_id = g_bus_grp_id
     AND org_payment_method_name = g_org_pay_method_name;

  g_territory_code := 'PH';

  -- Get the Key Flex Code
  SELECT application_id, id_flex_code
    INTO l_application_id, g_key_flex_code
    FROM fnd_id_flexs
   WHERE id_flex_name = g_key_flex_name;

  -- Get the Structure Number for 'PH_BANK_DETAILS'
  SELECT id_flex_num
    INTO g_structure_num
    FROM fnd_id_flex_structures
   WHERE application_id = l_application_id
     AND id_flex_code = g_key_flex_code
     AND id_flex_structure_code = g_structure_code;

  -- Get Number of Segments
  SELECT COUNT(*)
    INTO g_no_segments
    FROM fnd_id_flex_segments
   WHERE application_id = l_application_id
     AND id_flex_code = g_key_flex_code
     AND id_flex_num = g_structure_num;

EXCEPTION
  WHEN OTHERS THEN
    -- Log SQLERRM error
    --cust.ttec_process_error --Commented code by MXKEERTHI-ARGANO, 05/08/2023
    apps.ttec_process_error --Added code by MXKEERTHI-ARGANO, 05/08/2023
      ( application_code => g_application_code
      , interface        => g_interface
      , program_name     => g_package
      , module_name      => l_module
      , status           => c_status_failure
      , error_code       => SQLCODE
      , error_message    => SQLERRM );

  -- Critical Error - Re-Raise and Fail
  RAISE;
END initialize;

--
-- PROCEDURE load_bank_iface
--
-- Description: This procedure will load the Header and Detail records from the
--   External Tables into the Working tables.
--
PROCEDURE load_bank_iface IS

 -- l_module  cust.ttec_error_handling.module_name%TYPE := 'load_bank_iface';  ----cust.ttec_process_error  --Commented code by MXKEERTHI-ARGANO, 05/03/2023
l_module  APPS.ttec_error_handling.module_name%TYPE := 'load_bank_iface';--code Added  by MXKEERTHI-ARGANO, 05/03/2023
BEGIN

  -- Generate the Next Batch ID
  SELECT ttec_phl_bank_iface_hdr_s.nextval
    INTO g_batch_id
    FROM dual;

  -- Load Header Record
  INSERT INTO ttec_phl_bank_iface_hdr
    ( SELECT g_batch_id
           , TO_DATE(file_creation_date,'DDMMYYYY')
           , record_count
           , 'N'
        FROM ttec_phl_bank_iface_hdr_ext );

  -- Load Detail Records
  INSERT INTO ttec_phl_bank_iface_dtl
    ( SELECT g_batch_id
           , RTRIM(LTRIM(employee_number))
           , RTRIM(LTRIM(TRANSLATE( account_name
                                  , '¿¿¿¿¿¿¿¿¿¿¿¿¿¿¿"¿¿¿¿¿¿¿¿¿¿¿"'
                                  , 'aaaaeeeeiiiooouuuuAAAAEEEEIIIOOOUUUUcCoOoONn oa ' )))
           , account_number
           , account_type
           , NULL
           , 'N'
        FROM ttec_phl_bank_iface_dtl_ext );

EXCEPTION
  WHEN OTHERS THEN
    -- Log SQLERRM error
	--cust.ttec_process_error  --Commented code by MXKEERTHI-ARGANO, 05/03/2023
    APPS.ttec_process_error  --code Added  by MXKEERTHI-ARGANO, 05/03/2023
      ( application_code => g_application_code
      , interface        => g_interface
      , program_name     => g_package
      , module_name      => l_module
      , status           => c_status_failure
      , error_code       => SQLCODE
      , error_message    => SQLERRM );

END load_bank_iface;

--
-- PROCEDURE get_bank_kff_id
--
-- Description: This procedure will take the input KFF Segment Array and call the FND_FLEX_EXT
--              package which will return the ID
--
PROCEDURE get_bank_kff_id( p_account_number IN  ttec_phl_bank_iface_dtl.account_number%TYPE
                         , p_account_type   IN  ttec_phl_bank_iface_dtl.account_type%TYPE
                         , p_account_name   IN  VARCHAR2
                         --, p_keyflex_id     OUT hr.per_all_assignments_f.soft_coding_keyflex_id%TYPE ) IS   	--Commented code by MXKEERTHI-ARGANO, 05/03/2023
						 , p_keyflex_id     OUT hr.per_all_assignments_f.soft_coding_keyflex_id%TYPE ) IS    	--code added by MXKEERTHI-ARGANO, 05/03/2023
  --,l_module  cust.ttec_error_handling.module_name%TYPE := 'get_bank_kff_id'; IS   	--Commented code by MXKEERTHI-ARGANO, 05/03/2023
  l_module  APPS.ttec_error_handling.module_name%TYPE := 'get_bank_kff_id';  -- code Added by MXKEERTHI-ARGANO, 05/03/2023
  l_proc_name      VARCHAR2(20) := 'GET_BANK_KFF_ID';

  l_kff_segments   fnd_flex_ext.SegmentArray;
  l_valid          BOOLEAN;
  l_data_set       NUMBER;

BEGIN
  -- Set the Array segments
  l_kff_segments(1) := g_bank_name;
  l_kff_segments(2) := p_account_number;
  l_kff_segments(3) := NULL;                -- Bank Branch
  l_kff_segments(4) := NULL;                -- Branch Code
  l_kff_segments(5) := p_account_type;
  l_kff_segments(6) := p_account_name;

  -- Get the Combination ID for the Newly built Soft Coding KeyFlex Segment Array
  l_valid := fnd_flex_ext.get_combination_id( application_short_name => g_app_short_name
                                            , key_flex_code          => g_key_flex_code
                                            , structure_number       => g_structure_num
                                            , validation_date        => g_run_date
                                            , n_segments             => g_no_segments
                                            , segments               => l_kff_segments
                                            , combination_id         => p_keyflex_id
                                            , data_set               => l_data_set );

  IF NOT l_valid THEN
    p_keyflex_id := NULL;
    --cust.ttec_process_error --		Commented code by MXKEERTHI-ARGANO, 05/03/2023
    APPS.ttec_process_error --		CODE AADDED  by MXKEERTHI-ARGANO, 05/03/2023
      ( application_code => g_application_code
      , interface        => g_interface
      , program_name     => g_package
      , module_name      => l_module
      , status           => c_status_failure
      , error_code       => SQLCODE
      , error_message    => SQLERRM
      , label1           => 'Segment1'
      , reference1       => l_kff_segments(1)
      , label2           => 'Segment2'
      , reference2       => l_kff_segments(2)
      , label3           => 'Segment3'
      , reference3       => l_kff_segments(3)
      , label4           => 'Segment4'
      , reference4       => l_kff_segments(4)
      , label5           => 'Segment5'
      , reference5       => l_kff_segments(5)
      , label6           => 'Segment6'
      , reference6       => l_kff_segments(6) );

  END IF;

EXCEPTION
  WHEN OTHERS THEN
    p_keyflex_id := NULL;
    --cust.ttec_process_error --		Commented code by MXKEERTHI-ARGANO, 05/03/2023
    APPS.ttec_process_error--		CODE AADDED  by MXKEERTHI-ARGANO, 05/03/2023
    ( application_code => g_application_code
      , interface        => g_interface
      , program_name     => g_package
      , module_name      => l_module
      , status           => c_status_failure
      , error_code       => SQLCODE
      , error_message    => SQLERRM
      , label1           => 'Segment1'
      , reference1       => l_kff_segments(1)
      , label2           => 'Segment2'
      , reference2       => l_kff_segments(2)
      , label3           => 'Segment3'
      , reference3       => l_kff_segments(3)
      , label4           => 'Segment4'
      , reference4       => l_kff_segments(4)
      , label5           => 'Segment5'
      , reference5       => l_kff_segments(5)
      , label6           => 'Segment6'
      , reference6       => l_kff_segments(6)
      );

END get_bank_kff_id;

--
-- PROCEDURE update_pay_method
--
-- Description: This procedure will update the Bank Details on existing and future dated
--              Personal Payment Methods.
--
PROCEDURE update_pay_method( p_update_mode       IN VARCHAR2
                           , p_effective_date    IN DATE
                           , p_payment_method_id IN pay_personal_payment_methods_f.personal_payment_method_id%TYPE
                           , p_ovn               IN pay_personal_payment_methods_f.object_version_number%TYPE
                           , p_bank_name         IN VARCHAR2
                           , p_account_number    IN VARCHAR2
                           , p_bank_branch       IN VARCHAR2
                           , p_branch_code       IN VARCHAR2
                           , p_account_type      IN VARCHAR2
                           , p_account_name      IN VARCHAR2 ) IS

--l_module  cust.ttec_error_handling.module_name%TYPE := 'update_pay_method';--		Commented code by MXKEERTHI-ARGANO, 05/03/2023
    l_module  APPS.ttec_error_handling.module_name%TYPE := 'update_pay_method'; --		CODE ADDED  by MXKEERTHI-ARGANO, 05/03/2023

  l_ovn                           NUMBER := p_ovn;
  l_external_account_id           NUMBER;
  l_effective_start_date          DATE;
  l_effective_end_date            DATE;
  l_comment_id                    NUMBER;

BEGIN

  hr_personal_pay_method_api.update_personal_pay_method
    ( p_validate                      => g_validate
    , p_effective_date                => p_effective_date
    , p_datetrack_update_mode         => p_update_mode
    , p_personal_payment_method_id    => p_payment_method_id
    , p_object_version_number         => l_ovn
    , p_percentage                    => g_percentage
    , p_priority                      => g_priority
    , p_segment1                      => p_bank_name
    , p_segment2                      => p_account_number
    , p_segment3                      => p_bank_branch
    , p_segment4                      => p_branch_code
    , p_segment5                      => p_account_type
    , p_segment6                      => p_account_name
    , p_comment_id                    => l_comment_id
    , p_external_account_id           => l_external_account_id
    , p_effective_start_date          => l_effective_start_date
    , p_effective_end_date            => l_effective_end_date
    );

EXCEPTION
  WHEN OTHERS THEN
    -- Log SQLERRM error
    RAISE;
END update_pay_method;

--
-- PROCEDURE create_pay_method
--
-- Description: This procedure will create the employee Personal Payment Method with Bank
--              Details for the existing Assignment ID which does not already have a
--              Personal Payment Method.
--
PROCEDURE create_pay_method( p_assignment_id     IN per_all_assignments_f.assignment_id%TYPE
                           , p_bank_name         IN VARCHAR2
                           , p_account_number    IN VARCHAR2
                           , p_bank_branch       IN VARCHAR2
                           , p_branch_code       IN VARCHAR2
                           , p_account_type      IN VARCHAR2
                           , p_account_name      IN VARCHAR2 ) IS
 -- l_module  cust.ttec_error_handling.module_name%TYPE := 'create_pay_method';	--Commented code by MXKEERTHI-ARGANO, 05/03/2023
  l_module  APPS.ttec_error_handling.module_name%TYPE := 'create_pay_method';  ----CoDE Added by MXKEERTHI-ARGANO, 05/03/2023

  l_personal_payment_method_id    NUMBER;
  l_external_account_id           NUMBER;
  l_object_version_number         NUMBER;
  l_effective_start_date          DATE;
  l_effective_end_date            DATE;
  l_comment_id                    NUMBER;
  l_org_payment_method_id         NUMBER; /* V 1.1 */

BEGIN

  /* V 1.1 Begin*/
  BEGIN
    SELECT popmufv.org_payment_method_id
      INTO l_org_payment_method_id
      FROM pay_org_pay_method_usages_f_v popmufv, per_all_assignments_f paaf
     WHERE popmufv.payroll_id = paaf.payroll_id
       AND popmufv.TYPE = 'Direct Deposit'
       AND paaf.assignment_id = p_assignment_id
       AND TRUNC (SYSDATE) BETWEEN popmufv.effective_start_date
                               AND popmufv.effective_end_date
       AND TRUNC (SYSDATE) BETWEEN paaf.effective_start_date
                               AND paaf.effective_end_date;


  EXCEPTION WHEN OTHERS THEN
     l_org_payment_method_id  := g_org_payment_method_id;
  END;
  /* V1.1 End */

  hr_personal_pay_method_api.create_personal_pay_method
    ( p_validate                      => g_validate
    , p_effective_date                => g_run_date
    , p_assignment_id                 => p_assignment_id
    , p_org_payment_method_id         => l_org_payment_method_id /* V1.1 */ --g_org_payment_method_id
    , p_percentage                    => g_percentage
    , p_priority                      => g_priority
    , p_territory_code                => g_territory_code
    , p_segment1                      => p_bank_name
    , p_segment2                      => p_account_number
    , p_segment3                      => p_bank_branch
    , p_segment4                      => p_branch_code
    , p_segment5                      => p_account_type
    , p_segment6                      => p_account_name

    , p_personal_payment_method_id    => l_personal_payment_method_id
    , p_external_account_id           => l_external_account_id
    , p_object_version_number         => l_object_version_number
    , p_effective_start_date          => l_effective_start_date
    , p_effective_end_date            => l_effective_end_date
    , p_comment_id                    => l_comment_id
    );

EXCEPTION
  WHEN OTHERS THEN
    -- Log SQLERRM error
    RAISE;
END create_pay_method;

--
-- PROCEDURE Main
--
-- Description: This is the front end procedure that will be called to create the Personal Payment
--              Method for PHL Employees from the BPI Bank File provided.
--
PROCEDURE main IS
  --l_module  cust.ttec_error_handling.module_name%TYPE := 'main';  --commented code by MXKEERTHI-ARGANO, 05/03/2023
  l_module  APPS.ttec_error_handling.module_name%TYPE := 'main';  --code Added  by MXKEERTHI-ARGANO, 05/03/2023

  l_hdr_cnt        NUMBER       := 0;
  l_dtl_cnt        NUMBER       := 0;
  l_update_mode    VARCHAR2(20);
  l_err_flag       BOOLEAN;
  l_bank_kff_id    NUMBER;
  l_status         VARCHAR2(10);     -- REPEAT  - In Prior Batch
                                     -- NO DIFF - Not in Prior Batch but matches Oracle Data
                                     -- SUCCESS - Updated or Created without any errors.
                                     -- FAILED  - At least one PM failed during Creation and/or Update

  e_no_new_batch   EXCEPTION;

  CURSOR get_phl_emp IS
    SELECT bpid.rowid
         , bpid.employee_number
         , bpid.account_name
         , bpid.account_number
         , bpid.account_type
      FROM ttec_phl_bank_iface_dtl bpid
     WHERE bpid.batch_id = g_batch_id
       AND processed_flag = 'N'
    ORDER BY bpid.employee_number;

  CURSOR get_emp_assigns ( p_emp_no IN VARCHAR2) IS
    SELECT tab.assignment_id
         , ( SELECT COUNT(*)
		       --FROM hr.pay_personal_payment_methods_f ppm  --Commented code  by MXKEERTHI-ARGANO, 05/03/2023
               FROM APPS.pay_personal_payment_methods_f ppm  --code Added  by MXKEERTHI-ARGANO, 05/03/2023
              WHERE ppm.assignment_id = tab.assignment_id
                AND ppm.effective_end_date > g_run_date ) cnt_pms
      FROM ( SELECT UNIQUE paa.assignment_id
	           --FROM hr.per_all_assignments_f paa, hr.per_all_people_f pap --Commented code  by MXKEERTHI-ARGANO, 05/03/2023
               FROM apps.per_all_assignments_f paa, apps.per_all_people_f pap --code Added  by MXKEERTHI-ARGANO, 05/03/2023


              WHERE pap.employee_number = p_emp_no
                AND pap.business_group_id = g_bus_grp_id
                AND g_run_date BETWEEN pap.effective_start_date AND pap.effective_end_date
                AND paa.person_id = pap.person_id
                AND paa.effective_end_date > g_run_date ) tab;

  emp_assigns_rec get_emp_assigns%ROWTYPE;

  CURSOR get_pay_methods ( p_assignment_id IN NUMBER ) IS
    SELECT ppm.personal_payment_method_id
         , ppm.object_version_number
         , ppm.effective_start_date
         , ppm.external_account_id
		  --FROM hr.pay_personal_payment_methods_f ppm  --Commented code  by MXKEERTHI-ARGANO, 05/03/2023
      FROM APPS.pay_personal_payment_methods_f ppm  --code Added  by MXKEERTHI-ARGANO, 05/03/2023
      WHERE ppm.assignment_id = p_assignment_id
       AND ppm.business_group_id = g_bus_grp_id
       AND ppm.effective_end_date > g_run_date;

  pay_methods_rec get_pay_methods%ROWTYPE;

BEGIN

  -- Lookup Global Variables
  initialize;

  -- Load External Table into Working Tables.
  load_bank_iface;
  COMMIT;

  IF g_batch_id = 0 THEN
    RAISE e_no_new_batch;
  END IF;

  -- Validate Batch Counts
  BEGIN
    SELECT record_count, file_creation_date
      INTO l_hdr_cnt, g_run_date
      FROM ttec_phl_bank_iface_hdr
     WHERE batch_id = g_batch_id;

    SELECT COUNT(*)
      INTO l_dtl_cnt
      FROM ttec_phl_bank_iface_dtl
     WHERE batch_id = g_batch_id;

    IF l_hdr_cnt > l_dtl_cnt THEN
	  -- cust.ttec_process_error --Commented code  by MXKEERTHI-ARGANO, 05/03/2023
        apps.ttec_process_error --code Added  by MXKEERTHI-ARGANO, 05/03/2023
       ( application_code => g_application_code
        , interface        => g_interface
        , program_name     => g_package
        , module_name      => l_module
        , status           => c_status_failure
        , error_code       => NULL
        , error_message    => (l_hdr_cnt - l_dtl_cnt)||' Missing or Not Loaded Bank Records'
        , label1           => 'Header Count'
        , reference1       => l_hdr_cnt
        , label2           => 'Detail Count'
        , reference2       => l_dtl_cnt );
    ELSIF l_hdr_cnt < l_dtl_cnt THEN
	 -- cust.ttec_process_error --Commented code  by MXKEERTHI-ARGANO, 05/03/2023
        apps.ttec_process_error --code Added  by MXKEERTHI-ARGANO, 05/03/2023
        ( application_code => g_application_code
        , interface        => g_interface
        , program_name     => g_package
        , module_name      => l_module
        , status           => c_status_failure
        , error_code       => NULL
        , error_message    => (l_dtl_cnt - l_hdr_cnt)||' Extra Records exist in Excess of Header Count'
        , label1           => 'Header Count'
        , reference1       => l_hdr_cnt
        , label2           => 'Detail Count'
        , reference2       => l_dtl_cnt );
    END IF;
  END;

  -- Set File Counts
  g_total_cnt := l_dtl_cnt;

  FOR phl_emp_rec IN get_phl_emp LOOP

    g_total_emp_cnt := g_total_emp_cnt + 1;
    l_err_flag      := FALSE;
    l_status        := 'NO DIFF';

    -- Get Bank Details KFF ID to compare against PayMethod
    get_bank_kff_id( p_account_number => phl_emp_rec.account_number
                   , p_account_type   => phl_emp_rec.account_type
                   , p_account_name   => phl_emp_rec.account_name
                   , p_keyflex_id     => l_bank_kff_id );

    -- Get CURRENT and FUTURE Employee Assignments
    OPEN get_emp_assigns(phl_emp_rec.employee_number);
    LOOP
      FETCH get_emp_assigns
       INTO emp_assigns_rec;
      EXIT WHEN get_emp_assigns%NOTFOUND;

      -- Get CURRENT and FUTURE Payment Method's (if exists)
      OPEN get_pay_methods(emp_assigns_rec.assignment_id);
      LOOP
        FETCH get_pay_methods
         INTO pay_methods_rec;
        EXIT WHEN get_pay_methods%NOTFOUND;

        -- Compare New Bank Details to Old and Determine if an Update is necessary.
        IF pay_methods_rec.external_account_id != l_bank_kff_id THEN

          -- Update current PM and Correct Future Dated
          IF pay_methods_rec.effective_start_date < g_run_date THEN
            -- Use UPDATE mode if this is the only PM, use UPDATE_CHANGE_INSERT if future PMs
            IF emp_assigns_rec.cnt_pms = 1 THEN
              l_update_mode := 'UPDATE';
            ELSE
              l_update_mode := 'UPDATE_CHANGE_INSERT';
            END IF;
          ELSE
            l_update_mode := 'CORRECTION';
          END IF;

          BEGIN
            -- Update existing Pay Methods
            update_pay_method( p_update_mode       => l_update_mode
                             , p_effective_date    => GREATEST(g_run_date, pay_methods_rec.effective_start_date)
                             , p_payment_method_id => pay_methods_rec.personal_payment_method_id
                             , p_ovn               => pay_methods_rec.object_version_number
                             , p_bank_name         => g_bank_name
                             , p_account_number    => phl_emp_rec.account_number
                             , p_bank_branch       => NULL
                             , p_branch_code       => NULL
                             , p_account_type      => phl_emp_rec.account_type
                             , p_account_name      => phl_emp_rec.account_name );

            l_status := 'SUCCESS';
            IF NOT t_test_mode THEN
              COMMIT;                 -- No Auto Commit in Test Mode
            ELSE
              ROLLBACK;
            END IF;

          EXCEPTION
            WHEN OTHERS THEN
              l_err_flag := TRUE;

              --cust.ttec_process_error --Commented code by MXKEERTHI-ARGANO, 05/08/2023
              apps.ttec_process_error --Added code by MXKEERTHI-ARGANO, 05/08/2023
                ( application_code => g_application_code
                , interface        => g_interface
                , program_name     => g_package
                , module_name      => l_module
                , status           => c_status_failure
                , error_code       => SQLCODE
                , error_message    => 'Error Updating Bank Details: '||SQLERRM
                , label1           => 'Emp No'
                , reference1       => phl_emp_rec.employee_number
                , label2           => 'Asgn ID'
                , reference2       => emp_assigns_rec.assignment_id
                , label3           => 'Pay Meth ID'
                , reference3       => pay_methods_rec.personal_payment_method_id
                , label4           => 'OVN'
                , reference4       => pay_methods_rec.object_version_number
                , label5           => 'Mode'
                , reference5       => l_update_mode
                , label6           => 'Acct No'
                , reference6       => phl_emp_rec.account_number
                , label7           => 'Acct Type'
                , reference7       => phl_emp_rec.account_type
                , label8           => 'Acct Name'
                , reference8       => phl_emp_rec.account_name );

            ROLLBACK;
          END;
        END IF;
      END LOOP;

      IF get_pay_methods%ROWCOUNT = 0 THEN
        BEGIN
          -- Create a Pay Method for the Assignment
          create_pay_method( p_assignment_id     => emp_assigns_rec.assignment_id
                           , p_bank_name         => g_bank_name
                           , p_account_number    => phl_emp_rec.account_number
                           , p_bank_branch       => NULL
                           , p_branch_code       => NULL
                           , p_account_type      => phl_emp_rec.account_type
                           , p_account_name      => phl_emp_rec.account_name );

          l_status := 'SUCCESS';
          IF NOT t_test_mode THEN
            COMMIT;                 -- No Auto Commit in Test Mode
          ELSE
            ROLLBACK;
          END IF;

        EXCEPTION
          WHEN OTHERS THEN
            l_err_flag := TRUE;
			 -- cust.ttec_process_error --Commented code  by MXKEERTHI-ARGANO, 05/03/2023
             apps.ttec_process_error --code Added  by MXKEERTHI-ARGANO, 05/03/2023
            ( application_code => g_application_code
              , interface        => g_interface
              , program_name     => g_package
              , module_name      => l_module
              , status           => c_status_failure
              , error_code       => SQLCODE
              , error_message    => 'Could not create New Pay Method: '||SQLERRM
              , label1           => 'Emp No'
              , reference1       => phl_emp_rec.employee_number
              , label2           => 'Asgn ID'
              , reference2       => emp_assigns_rec.assignment_id );

          ROLLBACK;
        END;
      END IF;

      CLOSE get_pay_methods;
    END LOOP;

    IF get_emp_assigns%ROWCOUNT = 0 THEN
      l_err_flag := TRUE;
       -- cust.ttec_process_error --Commented code  by MXKEERTHI-ARGANO, 05/03/2023
        apps.ttec_process_error --code Added  by MXKEERTHI-ARGANO, 05/03/2023
        ( application_code => g_application_code
        , interface        => g_interface
        , program_name     => g_package
        , module_name      => l_module
        , status           => c_status_failure
        , error_code       => SQLCODE
        , error_message    => 'No Active or Future Assignment Exists for Employee: '||SQLERRM
        , label1           => 'Employee Number'
        , reference1       => phl_emp_rec.employee_number );
    END IF;

    CLOSE get_emp_assigns;

    IF l_err_flag THEN
      g_fail_emp_cnt    := g_fail_emp_cnt + 1;
      l_status := 'FAILED';
    ELSE
      g_success_emp_cnt := g_success_emp_cnt + 1;
    END IF;

    UPDATE ttec_phl_bank_iface_dtl
       SET processed_flag = 'Y'
         , status = l_status
     WHERE rowid = phl_emp_rec.rowid;

    COMMIT;

  END LOOP;

  -- Update Batch as Processed
  UPDATE ttec_phl_bank_iface_hdr
     SET processed_flag = 'Y'
   WHERE batch_id = g_batch_id;

  -- COMMIT final records processed.
  COMMIT;

EXCEPTION
  WHEN e_no_new_batch THEN
    g_fail_flag := TRUE;
    g_fail_msg := 'A new Batch File is not loaded to be processed';
     -- cust.ttec_process_error --Commented code  by MXKEERTHI-ARGANO, 05/03/2023
     apps.ttec_process_error --code Added  by MXKEERTHI-ARGANO, 05/03/2023
     ( application_code => g_application_code
      , interface        => g_interface
      , program_name     => g_package
      , module_name      => l_module
      , status           => c_status_failure
      , error_code       => NULL
      , error_message    => g_fail_msg );
  WHEN OTHERS THEN
    g_fail_flag := TRUE;
    g_fail_msg  := SQLERRM;

    -- Log SQLERRM error
	 -- cust.ttec_process_error --Commented code  by MXKEERTHI-ARGANO, 05/03/2023
     apps.ttec_process_error --code Added  by MXKEERTHI-ARGANO, 05/03/2023
     ( application_code => g_application_code
      , interface        => g_interface
      , program_name     => g_package
      , module_name      => l_module
      , status           => c_status_failure
      , error_code       => SQLCODE
      , error_message    => SQLERRM );
END main;

--
-- FUNCTION build_detail_message
--
-- Description: This Function will take a rowid from the cust.ttec_error_handling table
--   and build a message string to display in Log and Output files.
--
FUNCTION build_detail_message(p_rowid ROWID) RETURN VARCHAR2 IS

  l_message VARCHAR2(250);

  TYPE LabelArray     IS TABLE OF VARCHAR2(50) INDEX BY BINARY_INTEGER;
  TYPE ReferenceArray IS TABLE OF VARCHAR2(250) INDEX BY BINARY_INTEGER;

  l_label_array     LabelArray;
  l_reference_array ReferenceArray;

BEGIN
  SELECT label1,  reference1
       , label2,  reference2
       , label3,  reference3
       , label4,  reference4
       , label5,  reference5
       , label6,  reference6
       , label7,  reference7
       , label8,  reference8
       , label9,  reference9
       , label10, reference10
       , label11, reference11
       , label12, reference12
       , label13, reference13
       , label14, reference14
       , label15, reference15
    INTO l_label_array(1),  l_reference_array(1)
       , l_label_array(2),  l_reference_array(2)
       , l_label_array(3),  l_reference_array(3)
       , l_label_array(4),  l_reference_array(4)
       , l_label_array(5),  l_reference_array(5)
       , l_label_array(6),  l_reference_array(6)
       , l_label_array(7),  l_reference_array(7)
       , l_label_array(8),  l_reference_array(8)
       , l_label_array(9),  l_reference_array(9)
       , l_label_array(10), l_reference_array(10)
       , l_label_array(11), l_reference_array(11)
       , l_label_array(12), l_reference_array(12)
       , l_label_array(13), l_reference_array(13)
       , l_label_array(14), l_reference_array(14)
       , l_label_array(15), l_reference_array(15)
    --FROM cust.ttec_error_handling  --Commented code by MXKEERTHI-ARGANO, 05/08/2023
    FROM apps.ttec_error_handling  --Commented code by MXKEERTHI-ARGANO, 05/08/2023
   WHERE rowid = p_rowid;

   FOR i IN 1 .. 15 LOOP
     IF l_label_array(i) IS NOT NULL THEN
       l_message := l_message || l_label_array(i) || ': '|| l_reference_array(i) ||'; ';
     END IF;
   END LOOP;

   RETURN l_message;

EXCEPTION
  WHEN OTHERS THEN
    fnd_file.put_line(fnd_file.log, SQLCODE||': '||SQLERRM);
    RETURN l_message;
END build_detail_message;

--
-- PROCEDURE conc_mgr_wrapper
--
-- Description: This is a wrapper procedure to be called directly from the Concurrent
--   Mgr.  It will set Test Globals from input parameters and will output the final log.
--   This approach will allow the Main process to be ran/tested from the Conc Mgr.
--
PROCEDURE conc_mgr_wrapper( p_error_msg      OUT VARCHAR2
                          , p_error_code     OUT VARCHAR2
                          , p_directory      IN  VARCHAR2
                          , p_filename       IN  VARCHAR2
                          , p_bankname       IN  VARCHAR2 /* 2.0 */
                          , p_keep_data      IN  NUMBER
                          , p_keep_logs      IN  NUMBER
                          , p_test_mode      IN  VARCHAR2 ) IS

  l_detail_message  VARCHAR2(250);
  l_timestamp       DATE := SYSDATE;

  e_cleanup_err     EXCEPTION;

  CURSOR get_message_types IS
    SELECT c_status_failure message_type     -- Errors
      FROM dual
    UNION
    SELECT c_status_warning                  -- Warnings
      FROM dual
    ORDER BY 1;

  CURSOR get_error_messages (p_stat VARCHAR2) IS
    SELECT UNIQUE module_name, error_message
	 --  FROM cust.ttec_error_handling --Commented code  by MXKEERTHI-ARGANO, 05/03/2023
        FROM APPS.ttec_error_handling --code Added  by MXKEERTHI-ARGANO, 05/03/2023

     WHERE application_code = g_application_code
       AND interface = g_interface
       AND program_name = g_package
       AND status = p_stat
       AND creation_date >= l_timestamp
    ORDER BY module_name, error_message;

  error_message_rec get_error_messages%ROWTYPE;

  CURSOR get_errors(p_stat VARCHAR2, p_module VARCHAR2, p_err_mess VARCHAR2) IS
    SELECT rowid
	 --  FROM cust.ttec_error_handling --Commented code  by MXKEERTHI-ARGANO, 05/03/2023
        FROM APPS.ttec_error_handling --code Added  by MXKEERTHI-ARGANO, 05/03/2023
     WHERE application_code = g_application_code
       AND interface = g_interface
       AND program_name = g_package
       AND status = p_stat
       AND module_name = p_module
       AND error_message = p_err_mess
       AND creation_date >= l_timestamp
    ORDER BY reference1,  reference2,  reference3,  reference4,  reference5
           , reference6,  reference7,  reference8,  reference9,  reference10
           , reference11, reference12, reference13, reference14, reference15;

  error_rec get_errors%ROWTYPE;

BEGIN

  -- Copy the 1st line of the Input file to a Header File (External Table)
  UTL_FILE.fcopy( p_directory
                , p_filename
                , p_directory
                , g_hdr_filename
                , 1
                , 1 );

  -- Copy all other lines of the Input file to a Detail File (External Table)
  UTL_FILE.fcopy( p_directory
                , p_filename
                , p_directory
                , g_dtl_filename
                , 2 );


  -- Set Global Test Variables
  IF p_test_mode = 'N'
    THEN t_test_mode := FALSE;
  ELSE t_test_mode := TRUE;
  END IF;

  g_bank_name := p_bankname; /* 2.0 */

  fnd_file.new_line(fnd_file.log, 1);
  fnd_file.put_line(fnd_file.log, 'File Directory: '||p_directory);
  fnd_file.put_line(fnd_file.log, 'Filename:       '||p_filename);
  fnd_file.put_line(fnd_file.log, 'Test Mode?:     '||p_test_mode);
  fnd_file.new_line(fnd_file.log,1);

        /* V 1.1 the following is needed for view to see data */
      INSERT INTO fnd_sessions
           VALUES (USERENV ('SESSIONID'), TRUNC (SYSDATE));
      dbms_session.set_nls('NLS_LANGUAGE','AMERICAN');
      /* V 1.1 end */

  -- Submit the Main Process
  main;

  -- Report Batch ID for reference.
  fnd_file.put_line(fnd_file.log, 'Bank Batch ID: '||g_batch_id);

  -- Log Counts
  BEGIN

    fnd_file.new_line(fnd_file.log,1);
    fnd_file.put_line(fnd_file.log,'COUNTS');
    fnd_file.put_line(fnd_file.log,'---------------------------------------------------------');
    fnd_file.put_line(fnd_file.log,'# Records in BPI File       : '||g_total_cnt);
    fnd_file.put_line(fnd_file.log,'# Employees Processed       : '||g_total_emp_cnt);
    fnd_file.put_line(fnd_file.log,'   # Successful             : '||g_success_emp_cnt);
    fnd_file.put_line(fnd_file.log,'   # Failed                 : '||g_fail_emp_cnt);
    fnd_file.put_line(fnd_file.log,'---------------------------------------------------------');
    fnd_file.new_line(fnd_file.log,2);

    fnd_file.put_line(fnd_file.output,'COUNTS');
    fnd_file.put_line(fnd_file.output,'---------------------------------------------------------');
    fnd_file.put_line(fnd_file.output,'# Records in BPI File       : '||g_total_cnt);
    fnd_file.put_line(fnd_file.output,'# Employees Processed: '||g_total_emp_cnt);
    fnd_file.put_line(fnd_file.output,'   # Successful      : '||g_success_emp_cnt);
    fnd_file.put_line(fnd_file.output,'   # Failed          : '||g_fail_emp_cnt);
    fnd_file.put_line(fnd_file.output,'---------------------------------------------------------');
    fnd_file.new_line(fnd_file.output,2);

    IF g_fail_emp_cnt > 0 THEN
      p_error_code := 1;        -- Lable CR with WARNING
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, '   Error reporting Counts');
      p_error_code := 1;
  END;

  -- Log Errors / Warnings
  FOR message_type_rec IN get_message_types LOOP
    BEGIN
      IF message_type_rec.message_type = c_status_failure THEN
        fnd_file.put_line(fnd_file.log,'Refer to Output for Detailed Errors and Warnings');
        fnd_file.new_line(fnd_file.log, 1);

        fnd_file.put_line(fnd_file.output,'ERRORS');
        fnd_file.put_line(fnd_file.output,'--------------------');
      ELSE
        fnd_file.new_line(fnd_file.output,1);
        fnd_file.put_line(fnd_file.output,'WARNINGS');
        fnd_file.put_line(fnd_file.output,'--------------------');
      END IF;

      OPEN get_error_messages(message_type_rec.message_type);
      LOOP
        FETCH get_error_messages
         INTO error_message_rec;
        EXIT WHEN get_error_messages%NOTFOUND;

        -- Set CR Warning if at least 1 error exists
        IF message_type_rec.message_type = c_status_failure THEN
          p_error_code := 1;
        END IF;

        fnd_file.put_line(fnd_file.output,error_message_rec.error_message);

        FOR error_rec IN get_errors( message_type_rec.message_type
                                   , error_message_rec.module_name
                                   , error_message_rec.error_message )
        LOOP
          l_detail_message := build_detail_message(error_rec.rowid);
          fnd_file.put_line(fnd_file.output,'      '||l_detail_message);
        END LOOP;

        IF message_type_rec.message_type = c_status_failure THEN
          fnd_file.new_line(fnd_file.output,1);
        END IF;

      END LOOP;

      IF get_error_messages%ROWCOUNT = 0 THEN
        IF message_type_rec.message_type = c_status_failure THEN
          fnd_file.put_line(fnd_file.output,'No Errors to Report');
        ELSE
          fnd_file.put_line(fnd_file.output,'No Warnings to Report');
        END IF;
      END IF;

      CLOSE get_error_messages;
    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, '   Error Reporting Errors / Warnings');
        p_error_code := 1;
    END;
  END LOOP;

  -- Remove Temp Data Files
  BEGIN
    -- Delete Header and Detail Files created (External Tables)
    UTL_FILE.fremove( p_directory
                    , p_filename );

--    UTL_FILE.fremove( p_directory
--                    , g_hdr_filename );

--    UTL_FILE.fremove( p_directory
--                    , g_dtl_filename );

  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, SQLCODE||': '||SQLERRM);
      RAISE e_cleanup_err;
  END;

  -- Cleanup Batch Data Tables and Log Table
  BEGIN
    -- Purge Old Detail Records
    DELETE FROM ttec_phl_bank_iface_dtl
     WHERE batch_id IN
           ( SELECT batch_id
               FROM ttec_phl_bank_iface_hdr
              WHERE file_creation_date < TRUNC(SYSDATE) - p_keep_data );

    -- Purge Old Header Records
    DELETE FROM ttec_phl_bank_iface_hdr
     WHERE file_creation_date < TRUNC(SYSDATE) - p_keep_data;

    -- Purge Old Log Records
    DELETE FROM ttec_error_handling
     WHERE application_code = g_application_code
       AND interface = g_interface
       AND program_name = g_package
       AND creation_date < TRUNC(SYSDATE) - p_keep_logs;

  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Error Cleaning up Data and Log tables');
      fnd_file.put_line(fnd_file.log, SQLCODE||': '||SQLERRM);
      p_error_code := 2;
      p_error_msg  := SQLERRM;
  END;

  IF g_fail_flag THEN
    p_error_code := 2;
    p_error_msg := g_fail_msg;
  END IF;

  IF NOT t_test_mode THEN
    COMMIT;                 -- No Auto Commit in Test Mode
  ELSE
    ROLLBACK;
  END IF;

EXCEPTION
  WHEN e_cleanup_err THEN
    fnd_file.put_line(fnd_file.log, 'Error Cleaning Up Working Files');
    p_error_code := 1;
  WHEN OTHERS THEN
    fnd_file.put_line(fnd_file.log, SQLCODE||': '||SQLERRM);
    p_error_code := 2;
    p_error_msg  := SQLERRM;
END conc_mgr_wrapper;

END TTEC_PHL_BPI_BANK_IFACE_PKG;
/
show errors;
/