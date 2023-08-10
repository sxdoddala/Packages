create or replace PACKAGE BODY TTEC_PHL_LEGISLATIVE_INFO_PKG AS
/* $Header: ttec_phl_legislative_info_pkg.pkb/ 1.0 2008/06/25 mdodge ship $ */

/*== START ================================================================================================*\
  Author:  Michelle Dodge
    Date:  June 25, 2008
    Desc:  This package is intended to be ran once to Move the legislative infor from the person DFF
           to the Statutory Info KFF on their current or latest assignment.

  Modification History:

  Mod#  Date        Author      Description (Include Ticket#)
 -----  ----------  ----------  ----------------------------------------------
   001  06/25/2008  M Dodge     Initial Creation
   002  17/MAY/2023 RXNETHI-ARGANO  R12.2 Upgrade Remediation
\*== END ==================================================================================================*/

  -- Testing Variables - NOT FOR PROD
  /*
  START R12.2 Upgrade Remediation
  code commented by RXNETHI-ARGANO,17/05/23
  t_employee_number_low   hr.per_all_people_f.employee_number%TYPE := 2000000;
  t_employee_number_high  hr.per_all_people_f.employee_number%TYPE := 2100000;
  */
  --code added by RXNETHI-ARGANO,17/05/23
  t_employee_number_low   apps.per_all_people_f.employee_number%TYPE := 2000000;
  t_employee_number_high  apps.per_all_people_f.employee_number%TYPE := 2100000;
  --END R12.2 Upgrade Remediation
  t_test_mode             BOOLEAN      := TRUE;

  -- Global Constants
  --g_bus_grp_id           hr.hr_all_organization_units.business_group_id%TYPE := 1517;  --code commented by RXNETHI-ARGANO,17/05/23
  g_bus_grp_id           apps.hr_all_organization_units.business_group_id%TYPE := 1517;  --code added by RXNETHI-ARGANO,17/05/23
  g_update_mode          VARCHAR2(15) := 'CORRECTION';

  g_app_short_name       fnd_application.application_short_name%TYPE := 'PER';
  g_key_flex_name        fnd_id_flexs.id_flex_name%TYPE := 'Soft Coded KeyFlexfield';
  g_structure_code       fnd_id_flex_structures.id_flex_structure_code%TYPE := 'PH_STATUTORY_INFO';

  g_key_flex_code        fnd_id_flexs.id_flex_code%TYPE;
  g_structure_num        fnd_id_flex_structures.id_flex_num%TYPE;
  g_validation_date      DATE    := TRUNC(SYSDATE);
  g_no_segments          NUMBER;

  g_validate_update_asg  BOOLEAN := FALSE;
  g_batch_run_number     NUMBER  := 0;

  -- Global Count Variables for logging information
  g_total_emp_cnt        NUMBER  := 0;
  g_success_emp_cnt      NUMBER  := 0;
  g_fail_emp_cnt         NUMBER  := 0;
  g_cnt                  NUMBER  := 0;
  g_commit_cnt           NUMBER  := 1000;   -- # of records to commit.

--
-- PROCEDURE log_message
--
-- Description: User the hr_batch_message_line_api to log a error / warning message
--   to the HR_API_BATCH_MESSAGE_LINES table.
--
-- Arguments:
--      In: p_batch_run_number   -- Unique Number identifying Messages for this run
--          p_api_name           -- API Call that raised error / warning being logged.
--          p_status             -- 'S' = Success; 'F' = Failure
--          p_error_number       -- Error Number (SQLCODE) identifying error raised
--          p_error_message      -- Error Message (SQLERRM) identifying error raised
--          p_extended_error_message
--          p_source_row_info    -- Info identifying row that errored.
--
PROCEDURE log_message ( p_batch_run_number        IN NUMBER
                      , p_api_name                IN VARCHAR2
                      , p_status                  IN VARCHAR2
                      , p_error_number            IN NUMBER
                      , p_error_message           IN VARCHAR2
                      , p_extended_error_message  IN VARCHAR2
                      , p_source_row_info         IN VARCHAR2 ) IS

  PRAGMA AUTONOMOUS_TRANSACTION;

BEGIN

  INSERT INTO hr_api_batch_message_lines
  VALUES ( hr_api_batch_message_lines_s.nextval
         , p_api_name
         , p_batch_run_number
         , p_status
         , p_error_message
         , p_error_number
         , p_extended_error_message
         , p_source_row_info
         , NULL );

  COMMIT;

EXCEPTION
  WHEN OTHERS THEN
    NULL;
END log_message;

--
-- PROCEDURE initialize_global
--
-- Description: Set global variables for the Soft Coding KeyFlex
--
PROCEDURE initialize_global IS

  l_api_name         VARCHAR2(50) := 'ttec_phl_legislative_info_pkg.initialize_global';
  l_proc_name        VARCHAR2(20) := 'INITIALIZE_GLOBAL';

  l_application_id   fnd_application.application_id%TYPE;

BEGIN
  -- Get the Key Flex Code
  SELECT application_id, id_flex_code
    INTO l_application_id, g_key_flex_code
    FROM fnd_id_flexs
   WHERE id_flex_name = g_key_flex_name;

  -- Get the Structure Number for 'PH_STATUTORY_INFO'
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
    log_message
      ( p_batch_run_number       => g_batch_run_number
      , p_api_name               => l_api_name
      , p_status                 => 'F'
      , p_error_number           => SQLCODE
      , p_error_message          => SQLERRM
      , p_extended_error_message => fnd_message.get
      , p_source_row_info        => 'ERROR Initializing Global Variables' );

    -- ReRaise the Error
    RAISE;
END initialize_global;

--
-- FUNCTION format_tax_id
--
-- Description: This function will take an input string and try to reformat it to the
--              stardard tax id structure of xxx-xxx-xxx where x is a numeric.
--
--              The following formats will be reformatted (x = numeric in all formats)
--                xxxxxxxxx
--                xxx-xxx-xxx-000
--
FUNCTION format_tax_id( p_tax_id_str IN  VARCHAR2 ) RETURN VARCHAR2 IS

  l_trans_str  VARCHAR2(50);
  l_new_tax_id VARCHAR2(11);

BEGIN

  l_new_tax_id := p_tax_id_str;
  l_trans_str := TRANSLATE(p_tax_id_str,'0123456789','1111111111');

  IF l_trans_str = '111111111' THEN
    l_new_tax_id := SUBSTR(p_tax_id_str,1,3)||'-'||SUBSTR(p_tax_id_str,4,3)||'-'||SUBSTR(p_tax_id_str,7,3);
  ELSIF l_trans_str = '111-111-111-111' AND SUBSTR(p_tax_id_str,12,4) = '-000' THEN
    l_new_tax_id := SUBSTR(p_tax_id_str,1,11);
  END IF;

  RETURN l_new_tax_id;

EXCEPTION
  WHEN OTHERS THEN
    RETURN p_tax_id_str;
END format_tax_id;

--
-- FUNCTION build_soft_coding_kff
--
-- Description: This function will take an input DFF and KFF arrays.  It will lookup the
--              current soft_coding KeyFlex and override segments from the Not Null segments
--              of the DFF.
--
--FUNCTION build_sc_kff ( p_sc_keyflex_id IN         hr.per_all_assignments_f.soft_coding_keyflex_id%TYPE
--code commented by RXNETHI-ARGANO,17/05/23
FUNCTION build_sc_kff ( p_sc_keyflex_id IN         apps.per_all_assignments_f.soft_coding_keyflex_id%TYPE
--code added by RXNETHI-ARGANO,17/05/23
                      , p_dff_segments  IN         fnd_flex_ext.SegmentArray
                      , p_kff_segments  OUT        fnd_flex_ext.SegmentArray )
RETURN BOOLEAN IS

  l_api_name       VARCHAR2(50) := 'ttec_phl_legislative_info_pkg.build_sc_kff';
  l_proc_name      VARCHAR2(20) := 'BUILD_SC_KFF';

  l_valid     BOOLEAN;
  l_data_set  NUMBER;

BEGIN

  -- Get the Segments for the current Soft Coding KeyFlex ID
  IF p_sc_keyflex_id IS NULL THEN

    --Initialize the p_kff_segments
    FOR i IN 1 .. g_no_segments LOOP
      p_kff_segments(i) := NULL;
    END LOOP;

    l_valid := TRUE;

  ELSE
    l_valid := fnd_flex_ext.get_segments( application_short_name => g_app_short_name
                                        , key_flex_code          => g_key_flex_code
                                        , structure_number       => g_structure_num
                                        , combination_id         => p_sc_keyflex_id
                                        , n_segments             => g_no_segments
                                        , segments               => p_kff_segments
                                        , data_set               => l_data_set );
  END IF;

  IF NOT l_valid THEN
    log_message
      ( p_batch_run_number       => g_batch_run_number
      , p_api_name               => l_api_name
      , p_status                 => 'F'
      , p_error_number           => SQLCODE
      , p_error_message          => l_proc_name||': '||fnd_message.get
      , p_extended_error_message => fnd_message.get
      , p_source_row_info        => 'Soft Coding Keyflex ID: '|| p_sc_keyflex_id );

    RETURN FALSE;
  END IF;

  -- Override KFF Segments with NOT NULL segments from DFF
  FOR i IN 1 .. g_no_segments LOOP
    IF p_dff_segments(i) IS NOT NULL THEN
      p_kff_segments(i) := p_dff_segments(i);
    END IF;
  END LOOP;

  RETURN TRUE;

EXCEPTION
  WHEN OTHERS THEN
    log_message
      ( p_batch_run_number       => g_batch_run_number
      , p_api_name               => l_api_name
      , p_status                 => 'F'
      , p_error_number           => SQLCODE
      , p_error_message          => SQLERRM
      , p_extended_error_message => fnd_message.get
      , p_source_row_info        => 'Soft Coding Keyflex ID: '|| p_sc_keyflex_id );

    RETURN FALSE;
END build_sc_kff;

--
-- PROCEDURE get_sc_flex_id
--
-- Description: This procedure will take the input KFF Segment Array and call the FND_FLEX_EXT
--              package which will return the ID if it already exists or build it and return the
--              new ID.  It will also check Cross validation and Security rules and validate the
--              combination.
--
PROCEDURE get_sc_flex_id( p_kff_segments   IN  fnd_flex_ext.SegmentArray
                        --, p_sc_keyflex_id  OUT hr.per_all_assignments_f.soft_coding_keyflex_id%TYPE ) IS
                        --code commented by RXNETHI-ARGANO,17/05/23
						, p_sc_keyflex_id  OUT apps.per_all_assignments_f.soft_coding_keyflex_id%TYPE ) IS
						--code added by RXNETHI-ARGANO,17/05/23
  PRAGMA AUTONOMOUS_TRANSACTION;

  l_api_name       VARCHAR2(50) := 'ttec_phl_legislative_info_pkg.get_sc_flex_id';
  l_proc_name      VARCHAR2(20) := 'GET_SC_FLEX_ID';

  l_valid     BOOLEAN;
  l_data_set  NUMBER;

BEGIN
  -- Get the Combination ID for the Newly built Soft Coding KeyFlex Segment Array
  l_valid := fnd_flex_ext.get_combination_id( application_short_name => g_app_short_name
                                            , key_flex_code          => g_key_flex_code
                                            , structure_number       => g_structure_num
                                            , validation_date        => g_validation_date
                                            , n_segments             => g_no_segments
                                            , segments               => p_kff_segments
                                            , combination_id         => p_sc_keyflex_id
                                            , data_set               => l_data_set );

  IF NOT l_valid THEN
    log_message
      ( p_batch_run_number       => g_batch_run_number
      , p_api_name               => l_api_name
      , p_status                 => 'F'
      , p_error_number           => SQLCODE
      , p_error_message          => l_proc_name||': '||fnd_message.get
      , p_extended_error_message => fnd_message.get
      , p_source_row_info        => 'Segment1: '||p_kff_segments(1)||'; '||
                                    'Segment2: '||p_kff_segments(2)||'; '||
                                    'Segment3: '||p_kff_segments(3)||'; '||
                                    'Segment4: '||p_kff_segments(4)||'; '||
                                    'Segment5: '||p_kff_segments(5)||'; '||
                                    'Segment6: '||p_kff_segments(6) );
  END IF;

  -- Must COMMIT to unlock newly created KFF ID (if created)
  COMMIT;

EXCEPTION
  WHEN OTHERS THEN
    log_message
      ( p_batch_run_number       => g_batch_run_number
      , p_api_name               => l_api_name
      , p_status                 => 'F'
      , p_error_number           => SQLCODE
      , p_error_message          => SQLERRM
      , p_extended_error_message => fnd_message.get
      , p_source_row_info        => 'Segment1: '||p_kff_segments(1)||'; '||
                                    'Segment2: '||p_kff_segments(2)||'; '||
                                    'Segment3: '||p_kff_segments(3)||'; '||
                                    'Segment4: '||p_kff_segments(4)||'; '||
                                    'Segment5: '||p_kff_segments(5)||'; '||
                                    'Segment6: '||p_kff_segments(6) );

    ROLLBACK;
END get_sc_flex_id;

--
-- PROCEDURE update_asg
--
-- Description: This procedure will use the hr_assignment_api to Update the Soft Coded Flexfield ID
--   on the input assignment record with the specified OVN.  It will use the CORRECTION mode.
--
PROCEDURE update_asg( p_effective_date IN DATE
                    /*
					START R12.2 Upgrade Remediation
					code commented by RXNETHI-ARGANO,17/05/23
					, p_assignment_id  IN hr.per_all_assignments_f.assignment_id%TYPE
                    , p_ovn            IN hr.per_all_assignments_f.object_version_number%TYPE
                    , p_sc_keyflex_id  IN hr.per_all_assignments_f.soft_coding_keyflex_id%TYPE
                    */
					--code added by RXNETHI-ARGANO,17/05/23
					, p_assignment_id  IN apps.per_all_assignments_f.assignment_id%TYPE
                    , p_ovn            IN apps.per_all_assignments_f.object_version_number%TYPE
                    , p_sc_keyflex_id  IN apps.per_all_assignments_f.soft_coding_keyflex_id%TYPE
					--END R12.2 Upgrade Remediation
					, p_update_mode    IN VARCHAR2 ) IS

  l_api_name       VARCHAR2(50) := 'ttec_phl_legislative_info_pkg.update_asg';
  l_proc_name      VARCHAR2(20) := 'UPDATE_ASG';

  l_object_version_number        NUMBER        := p_ovn;
  l_soft_coding_keyflex_id       NUMBER        := p_sc_keyflex_id;

  l_cagr_grade_def_id            NUMBER;
  l_cagr_concatenated_segments   VARCHAR2(50);
  l_concatenated_segments        VARCHAR2(50);
  l_comment_id                   NUMBER;
  l_effective_start_date         DATE;
  l_effective_end_date           DATE;
  l_no_managers_warning          BOOLEAN;
  l_other_manager_warning        BOOLEAN;
  l_hourly_salaried_warning      BOOLEAN;
  l_gsp_post_process_warning     VARCHAR2(2000);

BEGIN

  hr_assignment_api.update_emp_asg
    ( p_validate                     => g_validate_update_asg
    , p_effective_date               => p_effective_date
    , p_datetrack_update_mode        => p_update_mode
    , p_assignment_id                => p_assignment_id
    , p_object_version_number        => l_object_version_number
    , p_cagr_grade_def_id            => l_cagr_grade_def_id
    , p_cagr_concatenated_segments   => l_cagr_concatenated_segments
    , p_concatenated_segments        => l_concatenated_segments
    , p_soft_coding_keyflex_id       => l_soft_coding_keyflex_id
    , p_comment_id                   => l_comment_id
    , p_effective_start_date         => l_effective_start_date
    , p_effective_end_date           => l_effective_end_date
    , p_no_managers_warning          => l_no_managers_warning
    , p_other_manager_warning        => l_other_manager_warning
    , p_hourly_salaried_warning      => l_hourly_salaried_warning
    , p_gsp_post_process_warning     => l_gsp_post_process_warning
    );

  -- Check for Warnings Returned and Log for review
  IF l_no_managers_warning THEN
    log_message
      ( g_batch_run_number
      , l_api_name                  -- p_api_name
      , 'W'                         -- p_status
      , NULL                        -- p_error_number
      , 'No Manager - Old Organization'  -- p_error_message
      , 'No Manager - Old Organization'  -- p_extended_error_message
      , 'Asg ID: '    ||p_assignment_id        ||'; '||
        'OVN: '       ||l_object_version_number||'; '||
        'Eff Date: '  ||p_effective_date       ||'; '||
        'Mode: '      ||p_update_mode          ||'; '||
        'Soft Coding KeyFlex ID: '||l_soft_coding_keyflex_id );
  END IF;
  IF l_other_manager_warning THEN
    log_message
      ( g_batch_run_number
      , l_api_name                  -- p_api_name
      , 'W'                         -- p_status
      , NULL                        -- p_error_number
      , 'Manager already exists in Organization'  -- p_error_message
      , 'Manager already exists in Organization'  -- p_extended_error_message
      , 'Asg ID: '    ||p_assignment_id        ||'; '||
        'OVN: '       ||l_object_version_number||'; '||
        'Eff Date: '  ||p_effective_date       ||'; '||
        'Mode: '      ||p_update_mode          ||'; '||
        'Soft Coding KeyFlex ID: '||l_soft_coding_keyflex_id );
  END IF;
  IF l_hourly_salaried_warning THEN
    log_message
      ( g_batch_run_number
      , l_api_name                  -- p_api_name
      , 'W'                         -- p_status
      , NULL                        -- p_error_number
      , 'Invalid Salary Basis or Hourly Salaried Code'  -- p_error_message
      , 'Invalid Salary Basis or Hourly Salaried Code'  -- p_extended_error_message
      , 'Asg ID: '    ||p_assignment_id        ||'; '||
        'OVN: '       ||l_object_version_number||'; '||
        'Eff Date: '  ||p_effective_date       ||'; '||
        'Mode: '      ||p_update_mode          ||'; '||
        'Soft Coding KeyFlex ID: '||l_soft_coding_keyflex_id );
  END IF;
  IF l_gsp_post_process_warning IS NOT NULL THEN
    log_message
      ( g_batch_run_number
      , l_api_name                  -- p_api_name
      , 'W'                         -- p_status
      , NULL                        -- p_error_number
      , 'GSP Post Process Warning: '||l_gsp_post_process_warning  -- p_error_message
      , 'GSP Post Process Warning: '||l_gsp_post_process_warning  -- p_extended_error_message
      , 'Asg ID: '    ||p_assignment_id        ||'; '||
        'OVN: '       ||l_object_version_number||'; '||
        'Eff Date: '  ||p_effective_date       ||'; '||
        'Mode: '      ||p_update_mode          ||'; '||
        'Soft Coding KeyFlex ID: '||l_soft_coding_keyflex_id );
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    log_message
      ( g_batch_run_number
      , l_api_name                  -- p_api_name
      , 'W'                         -- p_status
      , SQLCODE                     -- p_error_number
      , SQLERRM                     -- p_error_message
      , fnd_message.get             -- p_extended_error_message
      , 'Asg ID: '    ||p_assignment_id        ||'; '||
        'OVN: '       ||l_object_version_number||'; '||
        'Eff Date: '  ||p_effective_date       ||'; '||
        'Mode: '      ||p_update_mode          ||'; '||
        'Soft Coding KeyFlex ID: '||l_soft_coding_keyflex_id );

    --Reraise Error so error count is properly updated.
    RAISE;
END update_asg;

--
-- PROCEDURE Main
--
-- Description: This is the front end procedure that will be called to copy the legislative information
--              for each PHL employee from the person DFF to the Statutory Info KFF on their assignment.
--
PROCEDURE main IS

  l_api_name       VARCHAR2(50) := 'ttec_phl_legislative_info_pkg.main';
  l_proc_name      VARCHAR2(20) := 'MAIN';

  l_dff_segments   fnd_flex_ext.SegmentArray;
  l_kff_segments   fnd_flex_ext.SegmentArray;

  l_asgn_id        per_all_assignments_f.assignment_id%TYPE;
  l_effective_date per_all_assignments_f.effective_start_date%TYPE;
  l_ovn            per_all_assignments_f.object_version_number%TYPE;
  l_old_keyflex_id per_all_assignments_f.soft_coding_keyflex_id%TYPE;
  l_new_keyflex_id per_all_assignments_f.soft_coding_keyflex_id%TYPE;

  l_valid          BOOLEAN;

  e_cust_error     EXCEPTION;

  CURSOR get_phl_emp IS
    SELECT UNIQUE
           pap.person_id
         , pap.employee_number
      FROM per_all_people_f pap
         , per_all_assignments_f paa
     WHERE pap.business_group_id = g_bus_grp_id
       AND pap.attribute_category = g_bus_grp_id
       AND paa.person_id = pap.person_id
       AND paa.effective_end_date >= '01-JAN-2008'
       AND pap.employee_number BETWEEN NVL(t_employee_number_low, pap.employee_number )
                                   AND NVL(t_employee_number_high, pap.employee_number )  -- Testing ONLY
    ORDER BY pap.employee_number;

BEGIN

  -- Set the batch run number if not already set.
  IF g_batch_run_number = 0 THEN
    SELECT NVL(MAX(batch_run_number), 0) + 1
      INTO g_batch_run_number
      --FROM hr.hr_api_batch_message_lines;  --code commented by RXNETHI-ARGANO,17/05/23
      FROM apps.hr_api_batch_message_lines;  --code added by RXNETHI-ARGANO,17/05/23
  END IF;

  -- Set DFF Constants
  l_dff_segments(1) := 'TeleTech Philippines';
  l_dff_segments(6) := 'Semi-Month';

  -- Initialize Global Constants for this Soft Coding KeyFlexfield
  initialize_global;

  FOR phl_emp_rec IN get_phl_emp LOOP

    -- Initialize Variables for new Record
    l_dff_segments(2) := NULL;
    l_dff_segments(3) := NULL;
    l_dff_segments(4) := NULL;
    l_dff_segments(5) := NULL;

    -- Initialize KFF Segments to NULL
    FOR i IN 1 .. g_no_segments LOOP
      l_kff_segments(i) := NULL;
    END LOOP;

    l_asgn_id         := NULL;
    l_effective_date  := NULL;
    l_ovn             := NULL;
    l_old_keyflex_id  := NULL;
    l_new_keyflex_id  := NULL;

    g_total_emp_cnt := g_total_emp_cnt + 1;

    BEGIN
      BEGIN
        -- Load DFF Segments from Person record
        SELECT pap.attribute7
             , pap.attribute8
             , pap.attribute9
             , pap.attribute11
          INTO l_dff_segments(2)
             , l_dff_segments(4)
             , l_dff_segments(3)
             , l_dff_segments(5)
          FROM per_all_people_f pap
         WHERE pap.person_id = phl_emp_rec.person_id
           AND pap.business_group_id = g_bus_grp_id
           AND pap.effective_start_date =
               ( SELECT MAX(pap2.effective_start_date)
                   FROM per_all_people_f pap2
                  WHERE person_id = phl_emp_rec.person_id
                    AND business_group_id = g_bus_grp_id )
           AND pap.effective_end_date >= '01-JAN-2008';

        -- Reformat for common formatting differences
        l_dff_segments(2) := format_tax_id( l_dff_segments(2) );

      EXCEPTION
        WHEN OTHERS THEN
          log_message
            ( p_batch_run_number       => g_batch_run_number
            , p_api_name               => l_api_name
            , p_status                 => 'F'
            , p_error_number           => SQLCODE
            , p_error_message          => SQLERRM
            , p_extended_error_message => fnd_message.get
            , p_source_row_info        => 'Emp No: '      ||phl_emp_rec.employee_number||'; '||
                                          'Tax ID: '      ||l_dff_segments(2)          ||'; '||
                                          'HDMF #: '      ||l_dff_segments(4)          ||'; '||
                                          'PhilHealth #: '||l_dff_segments(3)          ||'; '||
                                          'Tax Code: '    ||l_dff_segments(5) );

          RAISE e_cust_error;
      END;

      BEGIN
        -- Get Assignment Info and KFF ID
        SELECT paa.assignment_id
             , paa.soft_coding_keyflex_id
             , paa.effective_start_date effective_date
             , paa.object_version_number ovn
          INTO l_asgn_id
             , l_old_keyflex_id
             , l_effective_date
             , l_ovn
          FROM per_all_assignments_f paa
         WHERE paa.person_id = phl_emp_rec.person_id
           AND paa.business_group_id = g_bus_grp_id
           AND paa.effective_start_date =
               ( SELECT MAX(paa2.effective_start_date)
                   FROM per_all_assignments_f paa2
                  WHERE paa2.person_id = phl_emp_rec.person_id
                    AND paa2.business_group_id = g_bus_grp_id )
           AND paa.effective_end_date >= '01-JAN-2008';

      EXCEPTION
        WHEN OTHERS THEN
          log_message
            ( p_batch_run_number       => g_batch_run_number
            , p_api_name               => l_api_name
            , p_status                 => 'F'
            , p_error_number           => SQLCODE
            , p_error_message          => SQLERRM
            , p_extended_error_message => fnd_message.get
            , p_source_row_info        => 'Emp No: '      ||phl_emp_rec.employee_number||'; '||
                                          'Asgn ID: '     ||l_asgn_id                  ||'; '||
                                          'KeyFlex ID: '  ||l_old_keyflex_id );

          RAISE e_cust_error;
      END;

      -- Build KFF Segments
      l_valid := build_sc_kff( p_sc_keyflex_id => l_old_keyflex_id
                             , p_dff_segments  => l_dff_segments
                             , p_kff_segments  => l_kff_segments );

      IF NOT l_valid THEN
        RAISE e_cust_error;
      END IF;

      -- Get KFF Combination ID
      get_sc_flex_id( p_kff_segments   => l_kff_segments
                    , p_sc_keyflex_id  => l_new_keyflex_id );

      IF l_new_keyflex_id IS NULL THEN
        RAISE e_cust_error;
      END IF;

      -- Update Assignment
      update_asg( p_effective_date => l_effective_date
                , p_assignment_id  => l_asgn_id
                , p_ovn            => l_ovn
                , p_sc_keyflex_id  => l_new_keyflex_id
                , p_update_mode    => g_update_mode );

      -- Evaluate COMMIT Point
      IF g_cnt = g_commit_cnt THEN
        IF NOT t_test_mode THEN
          COMMIT;                 -- No Auto Commit in Test Mode
        ELSE
          ROLLBACK;
        END IF;

        g_cnt := 0;
      ELSE
        g_cnt := g_cnt + 1;
      END IF;

      g_success_emp_cnt := g_success_emp_cnt + 1;

    EXCEPTION
      -- Already captured error.  End this record and go to next.
      WHEN e_cust_error THEN
        g_fail_emp_cnt := g_fail_emp_cnt + 1;
      WHEN OTHERS THEN
        g_fail_emp_cnt := g_fail_emp_cnt + 1;
    END;
  END LOOP;

  -- COMMIT final records processed.
  IF NOT t_test_mode THEN
    COMMIT;                 -- No Auto Commit in Test Mode
  ELSE
    ROLLBACK;
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    -- Log SQLERRM error
    log_message
      ( p_batch_run_number       => g_batch_run_number
      , p_api_name               => l_api_name
      , p_status                 => 'F'
      , p_error_number           => SQLCODE
      , p_error_message          => SQLERRM
      , p_extended_error_message => fnd_message.get
      , p_source_row_info        => NULL );

END main;

--
-- PROCEDURE conc_mgr_wrapper
--
-- Description: This is a wrapper procedure to be called directly from the Concurrent
--   Mgr.  It will set Test Globals from input parameters and will output the final log.
--   This approach will allow the Main process to be ran/tested from the Conc Mgr.
--
PROCEDURE conc_mgr_wrapper( p_error_msg      OUT VARCHAR2
                          , p_error_code     OUT VARCHAR2
                          , p_emp_no_low     IN  NUMBER
                          , p_emp_no_high    IN  NUMBER
                          , p_test_mode      IN  VARCHAR2 ) IS

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
       AND error_message = p_err_mess
    ORDER BY source_row_information;

  error_rec get_errors%ROWTYPE;

  CURSOR get_warn_message IS
    SELECT UNIQUE extended_error_message
      FROM hr_api_batch_message_lines
     WHERE batch_run_number = g_batch_run_number
       AND status = 'W'
    ORDER BY extended_error_message;

  warn_message_rec get_warn_message%ROWTYPE;

  CURSOR get_warns(p_warn_mess VARCHAR2) IS
    SELECT source_row_information
      FROM hr_api_batch_message_lines
     WHERE batch_run_number = g_batch_run_number
       AND status = 'W'
       AND extended_error_message = p_warn_mess
    ORDER BY source_row_information;

  warn_rec get_warns%ROWTYPE;

BEGIN

  -- Set Global Test Variables
  IF p_test_mode = 'N'
    THEN t_test_mode := FALSE;
  ELSE t_test_mode := TRUE;
  END IF;

  t_employee_number_low  := p_emp_no_low;
  t_employee_number_high := p_emp_no_high;

  fnd_file.new_line(fnd_file.log, 1);
  fnd_file.put_line(fnd_file.log, 'Emp # Low : '||t_employee_number_low);
  fnd_file.put_line(fnd_file.log, 'Emp # High: '||t_employee_number_high);
  fnd_file.put_line(fnd_file.log, 'Test Mode?: '||p_test_mode);
  fnd_file.new_line(fnd_file.log,1);

  -- Submit the Main Process
  main;

  -- Log Counts
  BEGIN
    IF g_batch_run_number = 0 THEN
      fnd_file.put_line(fnd_file.log, 'Message Batch #: No Messages Generated');
    ELSE
      fnd_file.put_line(fnd_file.log, 'Message Batch #: '||g_batch_run_number);
    END IF;

    fnd_file.new_line(fnd_file.log,1);
    fnd_file.put_line(fnd_file.log,'COUNTS');
    fnd_file.put_line(fnd_file.log,'---------------------------------------------------------');
    fnd_file.put_line(fnd_file.log,'# Employees Processed       : '||g_total_emp_cnt);
    fnd_file.put_line(fnd_file.log,'   # Successful             : '||g_success_emp_cnt);
    fnd_file.put_line(fnd_file.log,'   # Failed                 : '||g_fail_emp_cnt);
    fnd_file.put_line(fnd_file.log,'---------------------------------------------------------');
    fnd_file.new_line(fnd_file.log,2);

    fnd_file.put_line(fnd_file.output,'COUNTS');
    fnd_file.put_line(fnd_file.output,'---------------------------------------------------------');
    fnd_file.put_line(fnd_file.output,'# Employees Processed: '||g_total_emp_cnt);
    fnd_file.put_line(fnd_file.output,'   # Successful      : '||g_success_emp_cnt);
    fnd_file.put_line(fnd_file.output,'   # Failed          : '||g_fail_emp_cnt);
    fnd_file.put_line(fnd_file.output,'---------------------------------------------------------');
    fnd_file.new_line(fnd_file.output,2);

  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, '   Error reporting Counts');
  END;

  -- Log Errors
  BEGIN
    fnd_file.put_line(fnd_file.log,'Refer to Output for Detailed Errors and Warnings');
    fnd_file.new_line(fnd_file.log, 1);

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

      fnd_file.new_line(fnd_file.output,1);

    END LOOP;

    IF get_error_message%ROWCOUNT = 0 THEN
      fnd_file.put_line(fnd_file.output,'No Errors to Report');
    END IF;

    CLOSE get_error_message;
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, '   Error Reporting Detailed Errors');
  END;

  BEGIN
    fnd_file.new_line(fnd_file.output,1);
    fnd_file.put_line(fnd_file.output,'WARNINGS');
    fnd_file.put_line(fnd_file.output,'--------------------');

    OPEN get_warn_message;
    LOOP
      FETCH get_warn_message
       INTO warn_message_rec;
      EXIT WHEN get_warn_message%NOTFOUND;

      fnd_file.put_line(fnd_file.output,warn_message_rec.extended_error_message);

      FOR warn_rec IN get_warns(warn_message_rec.extended_error_message) LOOP
        fnd_file.put_line(fnd_file.output,'      '||warn_rec.source_row_information);
      END LOOP;

    END LOOP;

    IF get_warn_message%ROWCOUNT = 0 THEN
      fnd_file.put_line(fnd_file.output,'No Warnings to Report');
    END IF;

    CLOSE get_warn_message;
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, '   Error Reporting Detailed Warnings');
  END;

EXCEPTION
  WHEN OTHERS THEN
    fnd_file.put_line(fnd_file.log, SQLCODE||': '||SQLERRM);
END conc_mgr_wrapper;

END TTEC_PHL_LEGISLATIVE_INFO_PKG;
/
show errors;
/